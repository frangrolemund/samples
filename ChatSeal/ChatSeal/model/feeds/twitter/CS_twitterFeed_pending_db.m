//
//  CS_twitterFeed_pending_db.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/2/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

//  THREADING-NOTES:
//  - no locking is provided because the pending logic always locks around its accesses.

#import "CS_twitterFeed_pending_db.h"
#import "CS_feedCollectorUtil.h"
#import "ChatSeal.h"
#import "CS_tapi_statuses_lookup.h"

// - forward declarations
@interface CS_twitterFeed_pending_db (internal)
-(void) sortPendingIfNecessary;
-(void) deriveUnknownURLFlagFromPending;
-(void) close;
-(void) saveDatabase;
-(void) abortPendingTweetPhotoLookups:(NSArray *) arrTweetIds withDelay:(BOOL) applyDelay;
-(void) markTweetFailedAndCheckForPhotoLookup:(CS_tweetPending *) tp;
@end

@interface CS_tweetPending (internal)
-(id) initWithTweet:(NSString *) tid;
-(void) setPhotoURL:(NSURL *) uPhoto;
-(void) setDelayDate:(NSDate *) dt;
-(void) setIsConfirmed:(BOOL) isConf;
-(void) setScreenName:(NSString *) sn;
-(BOOL) shouldProcessPendingIfWantConfirmed:(BOOL) wantConf andMatchingFlag:(BOOL) isConf;
-(void) markFailedAndAllowProcessing;
-(void) prepareForExtraction;
@end

/*****************************
 CS_twitterFeed_pending_db
 *****************************/
@implementation CS_twitterFeed_pending_db
/*
 *  Object attributes
 */
{
    NSURL               *uFile;
    NSMutableDictionary *mdPending;
    NSMutableArray      *aSortedPending;
    BOOL                hasPendingWithoutURLs;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        uFile                 = nil;
        mdPending             = nil;
        aSortedPending        = nil;
        hasPendingWithoutURLs = NO;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [self close];
    [super dealloc];
}

/*
 *  Open the object if it exists or prepare it if it doesnt.
 */
-(BOOL) openFromURL:(NSURL *) u withError:(NSError **) err;
{
    [self close];
    
    if (!u) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        return NO;
    }
    
    // - if the file exists, then we need to try to load it
    //   securely.
    if ([[NSFileManager defaultManager] fileExistsAtPath:[u path]]) {
        NSDictionary *dTmp = [CS_feedCollectorUtil secureLoadConfigurationFromFile:u withError:err];
        if (!dTmp) {
            return NO;
        }
        mdPending = [[NSMutableDictionary alloc] initWithDictionary:dTmp];
    }
    else {
        mdPending = [[NSMutableDictionary alloc] init];
    }
    uFile = [u retain];
    
    return YES;
}

/*
 *  Explicitly save the database.
 *  - NOTE: I think this is probably best because there are going to be situations where I have multiple changes
 *          and I want to really avoid thrashing the hell out of the database.
 */
-(void) save
{
    [self saveDatabase];
}

/*
 *  Add a new tweet to the database for pending consideration later.
 *  ATTENTION: The provided screen name should be considered generally unreliable in all but some very specific circumstances because
 *             it could be the result of a repost of an existing tweet.
 *  - return YES if a change was made.
 */
-(BOOL) addPendingTweet:(NSString *) tweetId forScreenName:(NSString *) screenName withEmbeddedPhoto:(NSURL *) uPhoto andDelayUntil:(NSDate *) dt
{
    CS_tweetPending *tp              = nil;
    tp = [mdPending objectForKey:tweetId];
    if (tp && tp.photoURL) {
        // - we already have a complete item.
        return NO;
    }
    
    // - no, then save the content.
    if (!tp) {
        tp = [[[CS_tweetPending alloc] initWithTweet:tweetId] autorelease];
        [mdPending setObject:tp forKey:tweetId];
    }
    tp.photoURL   = uPhoto;
    tp.delayDate  = dt;
    tp.screenName = screenName;
    [aSortedPending release];
    aSortedPending = nil;
    return YES;
}

/*
 *  Return the pending item for the given id.
 */
-(CS_tweetPending *) pendingForTweet:(NSString *) tweetId
{
    if (tweetId) {
        return (CS_tweetPending *) [[[mdPending objectForKey:tweetId] retain] autorelease];
    }
    return nil;
}

/*
 *  Find the next best tweet to work on.
 */
-(CS_tweetPending *) nextPendingTweetWithPhotoAsConfirmed:(BOOL) isConfirmed
{
    [self sortPendingIfNecessary];
    for (CS_tweetPending *tp in aSortedPending) {
        // - determine if the pending item is a good candidate.
        if (![tp shouldProcessPendingIfWantConfirmed:YES andMatchingFlag:isConfirmed]) {
            continue;
        }
        return [[tp retain] autorelease];
    }
    return nil;
}

/*
 *  Return all the tweet ids that need photos identified up to the maximum count.
 */
-(NSArray *) pendingTweetIdsWithoutPhotosAndMaxCount:(NSUInteger) count
{
    if (!hasPendingWithoutURLs) {
        return nil;
    }
    
    NSMutableArray *maRet = [NSMutableArray array];
    
    // - make sure we only work from sorted content.
    [self sortPendingIfNecessary];
    for (CS_tweetPending *tp in aSortedPending) {
        if (tp.isBeingProcessed) {
            continue;
        }
        
        if (tp.photoURL) {
            continue;
        }
        
        if (tp.shouldDelayProcessing) {
            continue;
        }
        
        [maRet addObject:tp.tweetId];
        tp.isBeingProcessed = YES;
        if ([maRet count] == count) {
            break;
        }
    }
    
    return maRet;
}

/*
 *  For each of the ids, abort any pending lookups.
 */
-(void) abortPendingTweetPhotoLookups:(NSArray *) arrTweetIds
{
    [self abortPendingTweetPhotoLookups:arrTweetIds withDelay:NO];
}

/*
 *  When we get a response, we have a chance to update the content.
 *  - returns YES when we were able to identify tweets that require processing.
 */
-(BOOL) completePendingTweetPhotoLookupsWithAPI:(CS_tapi_statuses_lookup *) api andReturnInvalid:(NSArray **) arrInvalidTweets
{
    __block BOOL someIdentified = NO;
    if ([api isAPISuccessful]) {
        __block NSMutableArray *maInvalid   = nil;
        [api enumerateResultDataWithBlock:^(NSString *tweetId, NSString *screenName, NSURL *url) {
            if (url) {
                // - we're saving the screen name with the pending item here because it allows us to better identify the source and possibly allow us
                //   to push the tweet up to the type to watch for connectivity.
                CS_tweetPending *tp = [mdPending objectForKey:tweetId];
                tp.isBeingProcessed = NO;
                tp.photoURL         = url;
                tp.screenName       = screenName;
                someIdentified      = YES;
            }
            else {
                // - when we don't get a URL, that means the tweet has been deleted in all likelihood and we shouldn't
                //   deal with it any longer.
                [self discardPendingTweet:tweetId];
                if (arrInvalidTweets && !maInvalid) {
                    maInvalid = [NSMutableArray array];
                }
                [maInvalid addObject:tweetId];
            }
        }];
        
        // - if the caller wants a list of now invalid tweets, send them back.
        if (maInvalid) {
            *arrInvalidTweets = maInvalid;
            [self deriveUnknownURLFlagFromPending];
        }
        
        // - make sure this database is updated when it changes.
        if (someIdentified || [maInvalid count]) {
            [self save];
        }
    }
    else {
        // - if the API failed, we need to step back for a bit and let things settle out.
        [self abortPendingTweetPhotoLookups:api.tweetIds withDelay:YES];
    }
    return someIdentified;
}

/*
 *  Mark the tweet as useful because it can be unlocked.
 */
-(void) setTweetIsConfirmedUseful:(NSString *) tweetId
{
    CS_tweetPending *tp = [mdPending objectForKey:tweetId];
    if (tp) {
        tp.isConfirmed = YES;
    }
}

/*
 *  Delete a tweet that is pending in the database.
 */
-(void) discardPendingTweet:(NSString *)tweetId
{
    CS_tweetPending *tp     = [mdPending objectForKey:tweetId];
    [aSortedPending removeObject:tp];
    [mdPending removeObjectForKey:tweetId];
}

/*
 *  Return a list of all pending ids.
 */
-(NSArray *) allPending
{
    return [mdPending allKeys];
}

/*
 *  Returns whether any in the database still require processing.
 */
-(BOOL) hasHighPriorityPendingNotProcessing
{
    for (CS_tweetPending *tp in mdPending.allValues) {
        // - high-priority only cares about whether there is something there, not the actual confirmation
        //   state, which is more of a network category distinction.
        if ([tp shouldProcessPendingIfWantConfirmed:NO andMatchingFlag:NO]) {
            return YES;
        }
    }
    return NO;
}

/*
 *  This method can be used to flag a tweet as failed.
 */
-(void) markPendingTweetFailedAndAllowProcessing:(NSString *) tweetId
{
    CS_tweetPending *tp = [self pendingForTweet:tweetId];
    [self markTweetFailedAndCheckForPhotoLookup:tp];
}

/*
 *  Pull out pending items according to the criteria with the understanding they are to be transferred elsewhere.
 */
-(NSArray *) extractPendingItemsWithFullIdentification:(BOOL) fullyIdentified
{
    if (![mdPending count]) {
        return nil;
    }
    
    __block NSMutableArray *maToDelete = nil;
    __block NSMutableArray *maToReturn = nil;
    [mdPending enumerateKeysAndObjectsUsingBlock:^(NSString *tweetId, CS_tweetPending *tp, BOOL *stop){
        // - only pull out the ones that match the filter criteria.
        if ((fullyIdentified && tp.screenName) || (!fullyIdentified && !tp.screenName)) {
            if (!maToDelete) {
                maToDelete = [[NSMutableArray alloc] init];
            }
            [maToDelete addObject:tweetId];
            
            if (!maToReturn) {
                maToReturn = [[NSMutableArray alloc] init];
            }
            [tp prepareForExtraction];
            [maToReturn addObject:tp];
        }
    }];
    
    [maToDelete autorelease];
    [maToReturn autorelease];
    
    if (maToDelete) {
        [mdPending removeObjectsForKeys:maToDelete];
        [aSortedPending release];
        aSortedPending = nil;
    }
    
    return maToReturn;
}

/*
 *  Add the list of pending items to the current list.
 */
-(void) addPendingItemsForProcessing:(NSArray *) arrPending
{
    for (CS_tweetPending *tp in arrPending) {
        if (![mdPending objectForKey:tp.tweetId]) {
            [mdPending setObject:tp forKey:tp.tweetId];
        }
    }
    
    [aSortedPending release];
    aSortedPending = nil;
}

@end

/****************************************
 CS_twitterFeed_pending_db (internal)
 ****************************************/
@implementation CS_twitterFeed_pending_db (internal)
/*
 *  Sort the tweets chronologically if we haven't already.
 */
-(void) sortPendingIfNecessary
{
    // - we're going to return the tweets in descending order so that
    //   we always process them chronologically from most recent to oldest.
    if (!aSortedPending) {
        aSortedPending                = [[NSMutableArray arrayWithArray:mdPending.allValues] retain];
        [aSortedPending sortUsingComparator:^NSComparisonResult(CS_tweetPending *tp1, CS_tweetPending *tp2) {
            return [tp2.tweetId compare:tp1.tweetId options:NSNumericSearch];
        }];
        
        // - flag any that don't have URLs.
        [self deriveUnknownURLFlagFromPending];
    }
}

/*
 *  Compute if we have any that don't have URLs.
 */
-(void) deriveUnknownURLFlagFromPending
{
    hasPendingWithoutURLs = NO;
    for (CS_tweetPending *tp in aSortedPending) {
        if (!tp.photoURL) {
            hasPendingWithoutURLs = YES;
        }
    }
}

/*
 *  Close the object.
 */
-(void) close
{
    [uFile release];
    uFile = nil;
    
    [mdPending release];
    mdPending = nil;
    
    [aSortedPending release];
    aSortedPending = nil;
}

/*
 *  Save the database in the vault.
 */
-(void) saveDatabase
{
    if (!mdPending) {
        return;
    }

    NSError *err = nil;
    if (![CS_feedCollectorUtil secureSaveConfiguration:mdPending asFile:uFile withError:&err]) {
        NSLog(@"CS: Failed to save pending feed content.  %@", [err localizedDescription]);
    }
}

/*
 *  Abort pending lookups.
 */
-(void) abortPendingTweetPhotoLookups:(NSArray *) arrTweetIds withDelay:(BOOL) applyDelay
{
    for (NSString *tid in arrTweetIds) {
        CS_tweetPending *tp = [mdPending objectForKey:tid];
        if (applyDelay) {
            [tp markFailedAndAllowProcessing];
        }
        else {
            [tp setIsBeingProcessed:NO];
        }
    }
}

/*
 *  Flag a tweet as failed and ensure that the database detects the change in the pending queue.
 */
-(void) markTweetFailedAndCheckForPhotoLookup:(CS_tweetPending *) tp
{
    if (tp) {
        [tp markFailedAndAllowProcessing];
        if (!tp.photoURL) {
            hasPendingWithoutURLs = YES;
        }
    }
}

@end