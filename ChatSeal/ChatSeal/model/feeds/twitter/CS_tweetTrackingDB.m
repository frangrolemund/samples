//
//  CS_tweetTrackingDB.m
//  ChatSeal
//
//  Created by Francis Grolemund on 5/27/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tweetTrackingDB.h"

//  THREADING-NOTES:
//  - no locking is provided because this is used in the context of the Twitter feed/type objects.

// - types
typedef unsigned long long tweet_id_t;

// - constants
static const NSUInteger CS_TTD_IDLEN            = sizeof(tweet_id_t);
static const NSUInteger CS_TTD_BUF_EXPAND_COUNT = 16;
static NSString         *CS_TTD_PENDING_KEY     = @"twPend";
static NSString         *CS_TTD_NUM_COMP_KEY    = @"twNumComp";
static NSString         *CS_TTD_COMPLETE_KEY    = @"twComp";
static NSString         *CS_TTD_CANDIDATES_KEY  = @"twCand";
static const NSUInteger CS_TTD_MAX_SEEK_COUNT   = sizeof(uint32_t) * 8;
static const NSUInteger CS_TTD_CAND_MAX         = 100;
static const NSUInteger CS_TTD_CAND_ADJUST_CT   = 10;

// - forward declarations
@interface CS_tweetTrackingDB (internal)
-(tweet_id_t) tweetIdFromString:(NSString *) tweetId;
-(BOOL) completedTweetExists:(tweet_id_t) tid;
-(void) deleteCompletedTweet:(tweet_id_t) tid;
-(void) insertCompletedTweet:(tweet_id_t) tid;
@end

/***********************
 CS_tweetTrackingDB
 ***********************/
@implementation CS_tweetTrackingDB
/*
 *  Object attributes.
 */
{
    NSMutableDictionary *mdPending;
    
    // - NOTE: the completed set is a raw buffer to minimize the storage required for it since we may have a lot of tracked tweets over time.
    NSUInteger          numCompleted;
    NSMutableData       *mdCompleted;
    
    NSMutableDictionary *mdCandidates;
}

/*
 *  Return the maximum number of candidate tweets.
 */
+(NSUInteger) maxCandidateTweets
{
    return CS_TTD_CAND_MAX;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        mdPending    = [[NSMutableDictionary alloc] init];
        numCompleted = 0;
        mdCompleted  = nil;
        mdCandidates = nil;
    }
    return self;
}

/*
 *  Initialize the object from an archive.
 */
-(id) initWithCoder:(NSCoder *) aDecoder
{
    self = [super init];
    if (self) {
        mdPending    = nil;
        numCompleted = 0;
        mdCompleted  = nil;
        
        // - decode if possible.
        mdPending    = [[aDecoder decodeObjectForKey:CS_TTD_PENDING_KEY] retain];
        numCompleted = (NSUInteger) [aDecoder decodeIntegerForKey:CS_TTD_NUM_COMP_KEY];
        if (numCompleted) {
            mdCompleted = [[aDecoder decodeObjectForKey:CS_TTD_COMPLETE_KEY] retain];
        }
        mdCandidates  = [[aDecoder decodeObjectForKey:CS_TTD_CANDIDATES_KEY] retain];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [mdPending release];
    mdPending = nil;
    
    [mdCompleted release];
    mdCompleted  = nil;
    numCompleted = 0;
    
    [mdCandidates release];
    mdCandidates = nil;
    
    [super dealloc];
}

/*
 *  Encode this object to an archive.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:mdPending forKey:CS_TTD_PENDING_KEY];
    [aCoder encodeInteger:(NSInteger) numCompleted forKey:CS_TTD_NUM_COMP_KEY];
    if (numCompleted) {
        [aCoder encodeObject:mdCompleted forKey:CS_TTD_COMPLETE_KEY];
    }
    [aCoder encodeObject:mdCandidates forKey:CS_TTD_CANDIDATES_KEY];
}

/*
 *  Mark a tweet as pending, deleting it from the completed set, if necessary.
 *  - the tweet will not be removed as a candiate until we are completely done 
 *    with it.
 *  - NOTE: candidates are not affected by this call because a pending tweet could
 *          become unpending at some later date.
 */
-(void) setTweet:(NSString *) tweetId asPendingWithContext:(NSObject *) ctx
{
    if (!ctx) {
        ctx = [NSNull null];
    }
    
    tweet_id_t tid = [self tweetIdFromString:tweetId];

    // - assign to pending.
    [mdPending setObject:ctx forKey:[NSNumber numberWithUnsignedLongLong:tid]];
    
    // - ensure it is deleted in the completed set.
    [self deleteCompletedTweet:tid];
}

/*
 *  Mark a tweet as completed, which means it must be discarded from the pending
 *  set and added to the completed set.
 */
-(void) setTweetAsCompleted:(NSString *) tweetId
{
    tweet_id_t tid = [self tweetIdFromString:tweetId];
    
    // - delete from pending
    [mdPending removeObjectForKey:[NSNumber numberWithUnsignedLongLong:tid]];
    
    // - add to the completed set.
    [self insertCompletedTweet:tid];
    
    // - delete from candidates because the tweet is done.
    [mdCandidates removeObjectForKey:tweetId];
}

/*
 *  Determine if the given tweet is being tracked by this database.
 */
-(BOOL) isTweetTracked:(NSString *) tweetId
{
    tweet_id_t tid = [self tweetIdFromString:tweetId];
    
    // - check if it is in pending.
    if ([mdPending objectForKey:[NSNumber numberWithUnsignedLongLong:tid]]) {
        return YES;
    }
    
    // - check if it is completed
    return [self completedTweetExists:tid];
}

/*
 *  Figure out if the tweet has been completed.
 */
-(BOOL) isTweetCompleted:(NSString *) tweetId
{
    tweet_id_t tid = [self tweetIdFromString:tweetId];
    return [self completedTweetExists:tid];
}

/*
 *  If the tweet is pending then return its context.
 */
-(NSObject *) contextForPendingTweet:(NSString *) tweetId
{
    tweet_id_t tid = [self tweetIdFromString:tweetId];
    return [[[mdPending objectForKey:[NSNumber numberWithUnsignedLongLong:tid]] retain] autorelease];
}

/*
 *  Return the number of tweets that are being tracked.
 */
-(NSUInteger) count
{
    return [mdPending count] + numCompleted;
}

/*
 *  The tweet id should be untracked in both the pending and completed sets.
 *  NOTE: we don't delete from candidates implicitly here because it is reasonable to
 *        to stop tracking a tweet that we'd previously marked as pending, but candidates
 *        are forever for the most part.
 */
-(void) untrackTweet:(NSString *) tweetId
{
    tweet_id_t tid = [self tweetIdFromString:tweetId];
    
    // - remove from pending.
    [mdPending removeObjectForKey:[NSNumber numberWithUnsignedLongLong:tid]];
    
    // - remove from completed.
    [self deleteCompletedTweet:tid];
}

/*
 *  Remove all pending tweets from this database for the given context.
 */
-(void) deletePendingTweetsWithContext:(NSObject *) ctx
{
    NSMutableArray *maToDelete = [NSMutableArray array];
    for (NSNumber *tid in mdPending) {
        NSString *ctxExisting = [mdPending objectForKey:tid];
        if ([ctxExisting isEqual:ctx]) {
            [maToDelete addObject:tid];
        }
    }
    
    // - delete any that we found.
    if ([maToDelete count]) {
        [mdPending removeObjectsForKeys:maToDelete];
    }
}

/*
 *  Tweets that are potentially useful can be flagged as candidates for further processing 
 *  later, but are saved because the friend is inaccessible at the moment.
 *  - returns YES if the tweet is newly flagged.
 */
-(BOOL) flagTweet:(NSString *) tweetId asCandidateFromFriend:(NSString *) screenName withPhoto:(NSURL *) photo andProvenUseful:(BOOL) isUseful andForceIt:(BOOL) forceFlag
{
    if (!tweetId || !screenName || ([self isTweetTracked:tweetId] && !forceFlag)) {
        return NO;
    }
    
    if (forceFlag) {
        [self untrackTweet:tweetId];
    }
    
    if (!mdCandidates) {
        mdCandidates = [[NSMutableDictionary alloc] init];
    }
    
    // - a candidate is really just a tweet and a screen name where it originated which
    //   we'll attempt to process at some point.
    if (![mdCandidates objectForKey:tweetId]) {
        [mdCandidates setObject:[CS_candidateTweetContext contextForScreenName:screenName andPhoto:photo andProvenUseful:isUseful] forKey:tweetId];
        
        // - I don't want to keep an infininite number of candidate items because we could get a lot and
        //   at some point we can't reasonably check them all.  Also, assuming we get more from certain friends,
        //   the linked list will point to the old ones anyway.
        if ([mdCandidates count] > CS_TTD_CAND_MAX) {
            NSArray *arrAllKeys = [mdCandidates allKeys];
            arrAllKeys = [arrAllKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *k1, NSString *k2) {
                return [k1 compare:k2 options:NSNumericSearch];
            }];
            
            // - these are now in ascending order, so trim the end so we have an array of oldest to delete with.
            NSUInteger target = [arrAllKeys count] - (CS_TTD_CAND_MAX - CS_TTD_CAND_ADJUST_CT);
            arrAllKeys = [arrAllKeys subarrayWithRange:NSMakeRange(0, target)];
            [mdCandidates removeObjectsForKeys:arrAllKeys];
        }
        
        return YES;
    }
    
    return NO;
}

/*
 *  Return the full list of candiates.
 */
-(NSDictionary *) allCandidates
{
    NSMutableDictionary *mdRet = nil;
    if (mdCandidates) {
        mdRet = [NSMutableDictionary dictionaryWithDictionary:mdCandidates];
        
        // - don't include pending tweets.
        if ([mdPending count]) {
            for (NSNumber *n in mdPending.allKeys) {
                [mdRet removeObjectForKey:[NSString stringWithFormat:@"%llu", (unsigned long long) n.unsignedLongLongValue]];
            }
        }
    }    
    return mdRet;
}

@end

/********************************
 CS_tweetTrackingDB (internal)
 ********************************/
@implementation CS_tweetTrackingDB (internal)
/*
 *  Convert the string version of the tweet id into a proper 64-bit value.
 *  - Twitter claims that int64_t is sufficient, but we're going to use an uint64_t
 *    equivalent because the extra precision costs us nothing.
 */
-(tweet_id_t) tweetIdFromString:(NSString *) tweetId
{
    tweet_id_t ret = 0;
    if (tweetId) {
        NSScanner *scanner = [NSScanner scannerWithString:tweetId];
        if (![scanner scanUnsignedLongLong:&ret]) {
            return 0;
        }
    }
    return ret;
}

/*
 *  Identify where the tweet is in the current completed set and optionally
 *  only return a value if the values are equal.
 */
-(uint8_t *) positionForTweet:(tweet_id_t) tid andForceExisting:(BOOL) forceExisting
{
    uint8_t    *pBegin  = (uint8_t *) mdCompleted.mutableBytes;
    NSUInteger lowPos   = 0;
    NSUInteger highPos  = numCompleted;
    NSUInteger count    = 0;
    while (lowPos < highPos) {
        // - this is a binary search, so start halfway between the two ends.
        NSUInteger midWay = lowPos + ((highPos - lowPos) >> 1);
        uint8_t *ptr      = pBegin + (midWay * CS_TTD_IDLEN);
        tweet_id_t tidCur = 0;
        memcpy(&tidCur, ptr, CS_TTD_IDLEN);
        
        // - check what we have here.
        if (tidCur == tid) {
            // - we found it, nothing else that needs to be done.
            return ptr;
        }
        
        // - the tweet is after this one
        if (tidCur < tid) {
            lowPos = (midWay == lowPos) ? highPos : midWay;
        }
        
        // - the tweet is before this one
        if (tidCur > tid) {
            highPos = (midWay == lowPos) ? lowPos : midWay;
        }
        
        // - when we're at the end and we can return a position, do so
        if (!forceExisting && lowPos == highPos) {
            return ptr;
        }
        
        // - since this is a binary search, I expect this to generally be pretty
        //   efficient, but if it isn't I need to know.
        count++;
        if (count > CS_TTD_MAX_SEEK_COUNT) {
            NSLog(@"CS-ALERT: Unexpected excessive tweet seek path.");
            return NULL;
        }
    }
    
    // - no existing tweet position
    return NULL;
}

/*
 *  Checks if the tweet exists in teh completed set.
 */
-(BOOL) completedTweetExists:(tweet_id_t) tid
{
    return [self positionForTweet:tid andForceExisting:YES] ? YES : NO;
}

/*
 *  Delete the completed tweet from the set if it exists.
 */
-(void) deleteCompletedTweet:(tweet_id_t) tid
{
    if (!numCompleted) {
        return;
    }
    
    uint8_t *pos = [self positionForTweet:tid andForceExisting:YES];
    if (!pos) {
        return;
    }
    
    // - adjust the buffer so that the tweet is removed.
    uint8_t *pBegin = (uint8_t *) mdCompleted.mutableBytes;
    uint8_t *pEnd   = pBegin + (numCompleted * CS_TTD_IDLEN);
    uint8_t *pAfter = pos  + CS_TTD_IDLEN;
    
    // - zero-out the item, just to be very sure it won't be used.
    bzero(pos, CS_TTD_IDLEN);
    
    // - now move the content after over top it.
    if (pAfter < pEnd) {
        memmove(pos, pAfter, pEnd - pAfter);
        bzero(pEnd - CS_TTD_IDLEN, CS_TTD_IDLEN);
    }
    
    // - decrement the total number in the buffer.
    numCompleted--;
   
    // - and adjust the buffer size downward as necessary.
    if (numCompleted) {
        NSUInteger maxExtra  = CS_TTD_BUF_EXPAND_COUNT * CS_TTD_IDLEN;
        NSUInteger curNeeded = numCompleted * CS_TTD_IDLEN;
        if (curNeeded + maxExtra < [mdCompleted length]) {
            [mdCompleted setLength:curNeeded + maxExtra];
        }
    }
    else {
        [mdCompleted release];
        mdCompleted = nil;
    }
}

/*
 *  Inserts the completed tweet if it doesn't already exist in the set.
 */
-(void) insertCompletedTweet:(tweet_id_t) tid
{
    // - make sure that our buffer is large enough to accommodate the tweet.
    if ((numCompleted + 1) * CS_TTD_IDLEN >= [mdCompleted length]) {
        NSUInteger newLen = ((numCompleted + CS_TTD_BUF_EXPAND_COUNT) * CS_TTD_IDLEN);
        if (mdCompleted) {
            [mdCompleted setLength:newLen];
        }
        else {
            mdCompleted = [[NSMutableData alloc] initWithLength:newLen];
        }
    }
    
    // - find the location for the tweet in the buffer
    uint8_t *pos = [self positionForTweet:tid andForceExisting:NO];
    
    // - figure out how to put the tweet into the buffer.
    if (pos) {
        tweet_id_t tidCur = 0;
        memcpy(&tidCur, pos, CS_TTD_IDLEN);
        
        // - does it already exist...nothing to do.
        if (tid == tidCur) {
            return;
        }
        
        // - ok, we need to move content.
        uint8_t *pBegin  = (uint8_t *) mdCompleted.mutableBytes;
        uint8_t *pEnd    = pBegin + (numCompleted * CS_TTD_IDLEN);
        uint8_t *pToCopy = NULL;
        if (tidCur < tid) {
            // - copy the new tweet after the current position.
            pToCopy = pos + CS_TTD_IDLEN;
        }
        else {
            // - copy the new tweet before the current position.
            pToCopy = pos;
        }
        
        // - if we need to insert space, do so now.
        if (pToCopy < pEnd) {
            memmove(pToCopy + CS_TTD_IDLEN, pToCopy, pEnd - pToCopy);
        }
        memcpy(pToCopy, &tid, CS_TTD_IDLEN);
    }
    else {
        // ...no position indicates that we need to save it at the front of the buffer because this
        //    is the first time.
        memcpy(mdCompleted.mutableBytes, &tid, CS_TTD_IDLEN);
    }
    
    // - increment the number completed now that the content is in there.
    numCompleted++;
}
@end

/***************************
 CS_candidateTweetContext
 ***************************/
@implementation CS_candidateTweetContext
@synthesize screenName;
@synthesize photoURL;
@synthesize isProvenUseful;

/*
 *  Initialize the object.
 */
-(id) initWithScreenName:(NSString *) sn andPhoto:(NSURL *) url andProvenUseful:(BOOL) useful
{
    self = [super init];
    if (self) {
        self.screenName     = [sn retain];
        self.photoURL       = url;
        self.isProvenUseful = useful;
    }
    return self;
}

/*
 *  Return a new context.
 */
+(CS_candidateTweetContext *) contextForScreenName:(NSString *) screenName andPhoto:(NSURL *) url andProvenUseful:(BOOL) isUseful
{
    return [[[CS_candidateTweetContext alloc] initWithScreenName:screenName andPhoto:url andProvenUseful:isUseful] autorelease];
}

/*
 *  Initialize from an archive.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        screenName      = [[aDecoder decodeObject] retain];
        photoURL        = [[aDecoder decodeObject] retain];
        char tmp = 0;
        [aDecoder decodeValueOfObjCType:@encode(char) at:&tmp];
        isProvenUseful = (BOOL) tmp;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [screenName release];
    screenName = nil;
    
    [photoURL release];
    photoURL = nil;
    
    [super dealloc];
}

/*
 *  Encode the object to an archive.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:screenName];
    [aCoder encodeObject:photoURL];
    char tmp = (char) isProvenUseful;
    [aCoder encodeValueOfObjCType:@encode(char) at:&tmp];
}
@end