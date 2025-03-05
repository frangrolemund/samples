//
//  CS_twitterFeed_seal_history.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/4/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeed_seal_history.h"

//  THREADING-NOTES:
//  - there is no internal locking here.

// - constants
static const NSUInteger CSTF_SH_MAX_PRODUCER_HIST = 3;
static NSString         *CSTF_SH_HIST_KEY         = @"h";

// - forward declarations
@interface CS_twitterFeed_seal_history (internal)
-(NSString *) consumerKeyFromSeal:(NSString *) sealId;
-(void) addHistoryAsSealOwner:(BOOL) isSealOwner forSeal:(NSString *) sealId withTweet:(NSString *) tweetId andOwnerScreenName:(NSString *) screenName;
@end

/****************************
 CS_twitterFeed_seal_history
 ****************************/
@implementation CS_twitterFeed_seal_history
/*
 *  Object attributes
 */
{
    NSMutableDictionary *mdHistory;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        mdHistory = nil;
    }
    return self;
}

/*
 *  Initialize from an archive.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [self init];
    if (self) {
        mdHistory = [[aDecoder decodeObjectForKey:CSTF_SH_HIST_KEY] retain];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [mdHistory release];
    mdHistory = nil;
    
    [super dealloc];
}

/*
 *  Encode to an archive.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:mdHistory forKey:CSTF_SH_HIST_KEY];
}

/*
 *  Save history of a recent post.
 */
-(void) addPostedTweetHistoryForSeal:(NSString *) sealId withTweet:(NSString *) tweetId andOwnerScreenName:(NSString *) screenName andAsSealOwner:(BOOL) isOwner
{
    [self addHistoryAsSealOwner:isOwner forSeal:sealId withTweet:tweetId andOwnerScreenName:screenName];
}

/*
 *  Add consumer-specific history for the given seal.
 */
-(void) addConsumerHistoryForSeal:(NSString *) sealId withTweet:(NSString *) tweetId andOwnerScreenName:(NSString *) screenName
{
    // - slightly modify the key so that we can store a single record when we receive tweets from the owner.
    [self addHistoryAsSealOwner:NO forSeal:[self consumerKeyFromSeal:sealId] withTweet:tweetId andOwnerScreenName:screenName];
}

/*
 *  Return the history items for the given seal.
 *  - if the owner's screen name is provided, only return entries for that name.
 */
-(NSArray *) historyForSeal:(NSString *) sealId andOwnerScreenName:(NSString *) screenName
{
    NSObject *obj = [mdHistory objectForKey:sealId];
    if (!obj) {
        return nil;
    }
    
    // - figure out what we have to look at.
    NSMutableArray *maRet = [NSMutableArray array];
    NSArray *arrTmp       = nil;
    if ([obj isKindOfClass:[CS_twitterFeed_history_item class]]) {
        arrTmp = [NSArray arrayWithObject:obj];
    }
    else {
        arrTmp = (NSArray *) obj;
    }
    
    // - filter by screen name if necessary.
    if (screenName) {
        for (CS_twitterFeed_history_item *hi in arrTmp) {
            if ([hi.screenName isEqualToString:screenName]) {
                [maRet addObject:hi];
            }
        }
    }
    else {
        [maRet addObjectsFromArray:arrTmp];
    }
    return maRet;
}

/*
 *  When we're a consumer, retrieve the last tweet we received from the producer.
 */
-(CS_twitterFeed_history_item *) priorTweetFromOwnerOfSeal:(NSString *) sealId
{
    NSArray *arr = [self historyForSeal:[self consumerKeyFromSeal:sealId] andOwnerScreenName:nil];
    if (arr && [arr count]) {
        return [arr firstObject];
    }
    return nil;
}

/*
 *  Discard a consumer item.
 */
-(void) discardConsumerHistoryForSeal:(NSString *) sealId
{
    [mdHistory removeObjectForKey:[self consumerKeyFromSeal:sealId]];
}
@end

/***************************************
 CS_twitterFeed_seal_history (internal)
 ***************************************/
@implementation CS_twitterFeed_seal_history (internal)
/*
 *  Consumer records are differentiated from general histories because they 
 *  are intended to only be used for replies.  Both must be able to coexist so we'll
 *  differentiate the consumer ones with a slightly different key.
 */
-(NSString *) consumerKeyFromSeal:(NSString *) sealId
{
    return [@"*" stringByAppendingString:sealId];
}

/*
 *  Add tweet history.
 */
-(void) addHistoryAsSealOwner:(BOOL) isSealOwner forSeal:(NSString *) sealId withTweet:(NSString *) tweetId andOwnerScreenName:(NSString *) screenName
{
    if (!sealId) {
        return;
    }
    
    if (!mdHistory) {
        mdHistory = [[NSMutableDictionary alloc] init];
    }
    
    CS_twitterFeed_history_item *newItem = [CS_twitterFeed_history_item itemForTweet:tweetId andScreenName:screenName];
    
    // - producers store multiple items so that we give the consumers some information to backtrack.
    if (isSealOwner) {
        NSObject *obj                 = [mdHistory objectForKey:sealId];
        NSMutableArray *maSealHistory = nil;
        if ([obj isKindOfClass:[NSMutableArray class]]) {
            maSealHistory = (NSMutableArray *) obj;
        }
        else {
            maSealHistory = [NSMutableArray array];
            [mdHistory setObject:maSealHistory forKey:sealId];
        }
        
        // - now save the item
        [maSealHistory addObject:newItem];
        
        // - and provide a suitable limit
        NSUInteger curLen = [maSealHistory count];
        if (curLen > CSTF_SH_MAX_PRODUCER_HIST) {
            [maSealHistory removeObjectsInRange:NSMakeRange(0, curLen - CSTF_SH_MAX_PRODUCER_HIST)];
        }
    }
    else {
        // - consumers only need the last one for making replies.
        [mdHistory setObject:newItem forKey:sealId];
    }
}
@end
