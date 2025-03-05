//
//  CS_twmGenericUser_miningStats.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/8/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twmGenericUser_miningStats.h"
#import "CS_twitterFeed_shared.h"
#import "CS_twmMiningStatsHistory.h"

//  THREADING-NOTES:
//  - this object provides locking because it performs its updates outside the transient mining lock.

// - constants
static const uint32_t       CS_TWM_PRIO_NOFOLLOW        = 10;
static const uint32_t       CS_TWM_PRIO_SEALOWNER       = 5;
static const uint32_t       CS_TWM_PRIO_TRUSTED         = 10;
static const NSUInteger     CS_TWM_PRIO_TIME_BALANCE    = 5;       // every 5 seconds, we increase priority by 1 unit.
static NSString            *CS_TWM_HIST_KEY             = @"h";
static NSString            *CS_TWM_FOUND_KEY            = @"f";

// - forward declarations
@interface CS_twmGenericUser_miningStats (_userInternal)
-(void) _commonConfiguration;
-(CS_twmMiningStatsHistory *) history;
@end

/******************************
 CS_tmGenericUser_miningStats
 ******************************/
@implementation CS_twmGenericUser_miningStats
/*
 *  Object attributes.
 */
{
    NSString                    *screenName;
    NSRecursiveLock             *lckStats;
    
    uint32_t                    computedPriority;
    CS_twmMiningStatsHistory    *statsHistory;
    NSInteger                   foundCount;
}

/*
 *  Initialize the object.
 */
-(id) initWithScreenName:(NSString *) name andHistory:(CS_twmMiningStatsHistory *) otherHist
{
    self = [super init];
    if (self) {
        screenName   = [name retain];             //  do not save this, because it will be assigned when decoded
        statsHistory = [otherHist copy];
        [self _commonConfiguration];
    }
    return self;
}

/*
 *  Initialize using a different object.
 */
-(id) initWithMiningStats:(CS_twmGenericUser_miningStats *) stats
{
    return [self initWithScreenName:stats.screenName andHistory:stats ? stats->statsHistory : nil];
}

/*
 *  Initialize the object.
 */
-(id) initWithScreenName:(NSString *) name
{
    return [self initWithScreenName:name andHistory:nil];
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        screenName   = nil;                       //  use the assignPostLoadScreenName
        statsHistory = [[aDecoder decodeObjectForKey:CS_TWM_HIST_KEY] retain];
        foundCount   = [aDecoder decodeIntegerForKey:CS_TWM_FOUND_KEY];
        [self _commonConfiguration];
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
    
    [statsHistory release];
    statsHistory = nil;
    
    [lckStats release];
    lckStats = nil;
    
    [super dealloc];
}

/*
 *  Encode the object to an archive.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [lckStats lock];
    [aCoder encodeObject:statsHistory forKey:CS_TWM_HIST_KEY];
    if (foundCount) {
        [aCoder encodeInteger:foundCount forKey:CS_TWM_FOUND_KEY];
    }
    [lckStats unlock];
}

/*
 *  Create a copy of these stats.
 */
-(id) copyWithZone:(NSZone *)zone
{
    return [[CS_twmGenericUser_miningStats allocWithZone:zone] initWithScreenName:screenName andHistory:statsHistory];
}

/*
 *  Return the screen name.
 */
-(NSString *) screenName;
{
    NSString *ret = nil;
    [lckStats lock];
    ret = [[screenName retain] autorelease];
    [lckStats unlock];
    
    return ret;
}

/*
 *  After we load the stats, we'll store the screen names
 *  so that we can run the queries, but there will only be
 *  one copy.
 */
-(void) assignPostLoadScreenName:(NSString *) name
{
    [lckStats lock];
    if (name != screenName) {
        [screenName release];
        screenName = [name retain];
    }
    [lckStats unlock];
}

/*
 *  The priority of a particular stat influences its position inside the sequence of operations during a refresh.
 *  - the higher the better.
 */
-(NSUInteger) statPriority
{
    NSUInteger ret = 0;
    [lckStats lock];
    ret = computedPriority;
    
    // ...add in some element of the time interval since the last update so that the ones that haven't been updated
    //    recently take some precedence.
    NSTimeInterval tiLast = [statsHistory timeIntervalSinceLastUpdate];
    NSUInteger nPrioUpd   = (((NSUInteger) tiLast) & 0xFFFF) / CS_TWM_PRIO_TIME_BALANCE;
    ret                  += nPrioUpd;
    
    [lckStats unlock];
    
    return ret;
}

/*
 *  The popularity of a statistic depends on whether it ever finds any content.
 */
-(NSUInteger) statPopularity
{
    NSUInteger ret = 0;
    [lckStats lock];
    ret = (NSUInteger) MAX(0, foundCount);
    [lckStats unlock];
    return ret;
}

/*
 *  Update the friendship state for this object.
 */
-(void) updateFriendshipState:(CS_tapi_friendship_state *) friendshipState
{
    [lckStats lock];
    
    computedPriority &= 0xFFFF0000;
    if (!friendshipState.isFollowing) {
        // - increase priority when I am not following so that we mine their feed aggressively
        computedPriority += CS_TWM_PRIO_NOFOLLOW;
    }
    
    if (!friendshipState.iAmSealOwner) {
        // - if they are a seal owner, we're going to increase their priority so that we favor consumption.
        computedPriority += CS_TWM_PRIO_SEALOWNER;
    }
    
    if (friendshipState.isTrusted) {
        // - trusted friends are always retrieved before untrusted ones.
        computedPriority += CS_TWM_PRIO_TRUSTED;
    }
    
    [lckStats unlock];
}

/*
 *  Make the mining requests that must occur for this object during
 *  a normal refresh.
 *  - return NO when all the requests are throttled.
 */
-(BOOL) performMiningRequestsUsingFeed:(CS_twitterFeed *) feed
{
    return YES;
}

/*
 *  Make any optional requests for this object that could improve its
 *  view of its timeline.
 *  - return NO when all the requests are throttled.
 */
-(BOOL) performOptionalMiningRequestsUsingFeed:(CS_twitterFeed *) feed
{
    return YES;
}

/*
 *  Gather and organize the results of the timeline request.
 *  - return YES if data was changed that should be saved.
 */
-(BOOL) completeTimelineAPI:(CS_tapi_statuses_timeline_base *) api usingFeed:(CS_twitterFeed *) feed
{
    // - don't do any analysis with an invalid result.
    if (![api isAPISuccessful]) {
        return NO;
    }
    
    __block NSInteger savedCount = 0;
    CS_tapi_tweetRange *tweetRange = [api enumerateResultDataWithBlock:^(NSString *tweetId, NSURL *url) {
        // - NOTE: we won't use the user id to filter the tweet here to save on the cost of the queries and
        //         the list of tweets we sent is already tracked anyway.
        // - NOTE: it is not always the case that the screen name in this object is the only one that will
        //         be retrieved by a standard timeline result set.  For example in either the home or mentions
        //         timelines, we could get any screen name, even ones we don't know about.
        [feed saveTweetForProcessing:tweetId withPhoto:url fromUser:nil andFlagAsKnownUseful:NO];
        savedCount++;
    }];
    
    if (!tweetRange) {
        return NO;
    }
    
    // - update the history for stats based on what we found, which will help us decide how to proceed next time around.
    // - NOTE: a range with unset values indicates nothing was found.
    [lckStats lock];
    [[self history] updateHistoryWithRange:tweetRange fromAPI:api];
    foundCount += savedCount;
    [lckStats unlock];
    
    return YES;
}

/*
 *  Return a handle to the internal lock.
 */
-(NSRecursiveLock *) statsLock
{
    return [[lckStats retain] autorelease];
}

/*
 *  Fill the API with the enclosed stats to make a forward request on the timeline.
 */
-(void) populateAPIForMostRecentRequest:(CS_tapi_statuses_timeline_base *) api
{
    [lckStats lock];
    [[self history] populateAPIForMostRecentRequest:api];
    [lckStats unlock];
}

/*
 *  Fill the API with the enclosed stats to make an optional backward request on the timeline.
 */
-(BOOL) populateAPIForPastGapsOrMostRecentRequest:(CS_tapi_statuses_timeline_base *)api
{
    BOOL ret = NO;
    [lckStats lock];
    ret = [[self history] populateAPIForPastGapsOrMostRecentRequest:api];
    [lckStats unlock];
    return ret;
}

/*
 *  Returns whether the history includes gaps of content that wasn't retrieved.
 */
-(BOOL) hasPriorGapsInHistory
{
    BOOL ret = NO;
    [lckStats lock];
    ret = [[self history] hasPriorGapsInHistory];
    [lckStats unlock];
    return ret;
}

/*
 *  Using the API, update the history to reflect the proper range, but do no processing of the content.
 */
-(void) updateOnlyHistoryWithAPI:(CS_tapi_statuses_timeline_base *) api
{
    // - don't do any analysis with an invalid result.
    if (![api isAPISuccessful]) {
        return;
    }
    
    CS_tapi_tweetRange *tweetRange = [api enumerateResultDataWithBlock:nil];
    if (tweetRange) {
        // - update the history for stats based on what we found, which will help us decide how to proceed next time around.
        // - NOTE: a range with unset values indicates nothing was found.
        [lckStats lock];
        [[self history] updateHistoryWithRange:tweetRange fromAPI:api];
        [lckStats unlock];
    }
}
@end

/**********************************************
 CS_twmGenericUser_miningStats (_userInternal)
 **********************************************/
@implementation CS_twmGenericUser_miningStats (_userInternal)
/*
 *  Configure the object.
 */
-(void) _commonConfiguration
{
    // - I'm using a bare lock here to keep the critical sections as small as possible since this is accessed
    //   quite a lot for sorts and updates.
    lckStats   = [[NSRecursiveLock alloc] init];
    foundCount = 0;
}

/*
 *  Returns the history storage object.
 *  - ASSUMES the lock is held.
 */
-(CS_twmMiningStatsHistory *) history
{
    if (!statsHistory) {
        statsHistory = [[CS_twmMiningStatsHistory alloc] init];
    }
    return statsHistory;
}
@end
