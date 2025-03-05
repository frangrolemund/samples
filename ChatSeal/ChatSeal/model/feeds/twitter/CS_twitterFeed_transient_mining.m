//
//  CS_twitterFeed_transient_mining.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/5/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeed_transient_mining.h"
#import "CS_twitterFeed_shared.h"
#import "CS_twmGenericUser_miningStats.h"
#import "CS_twmFriend_miningStats.h"
#import "CS_twmFeedOwner_miningStats.h"
#import "CS_feedCollectorUtil.h"
#import "CS_twmFeedMentions_miningStats.h"

//  THREADING-NOTES:
//  - internal locking is provided.

// - constants
static const NSUInteger CS_TF_TM_DEFAULT_REALTIME_COUNT = (NSUInteger) -1;
static NSString         *CS_TF_TM_MENTIONS_STATS        = @"-- mentions --";            // must be an invalid Twitter screen name.

// - forward declarations
@interface CS_twitterFeed_transient_mining (internal)
-(void) loadIfNecessary;
-(CS_twmFeedOwner_miningStats *) statsForFeed:(CS_twitterFeed *) feed;
-(CS_twmFriend_miningStats *) statsForFriend:(NSString *) screenName;
-(CS_twmFriend_miningStats *) statsForScreenName:(NSString *) screenName;
-(void) recomputeFriendshipStatesFromFeed:(CS_twitterFeed *) feed;
-(void) saveDeferredUntilEndOfCycle;
-(void) saveIfNecessary;
-(BOOL) isThrottleMaxedOutInFeed:(CS_twitterFeed *) feed;
@end


/***********************************
 CS_twitterFeed_transient_mining
 ***********************************/
@implementation CS_twitterFeed_transient_mining
/*
 *  Object attributes.
 */
{
    NSURL               *uFile;
    NSMutableDictionary *mdMiningStats;
    BOOL                needsFriendshipUpdate;
    BOOL                hasHadInitialUpdate;
    BOOL                saveIsRequired;
    NSMutableArray      *maReachableStats;
    NSMutableArray      *maPriorityStats;
    BOOL                isRealtimeOnline;
    NSUInteger          lastRealtimeCount;
    BOOL                realtimeDataSupportsAForwardQuery;
}

/*
 *  Initialize the object.
 *  NOTE: since these stats aren't critical for operation, I'm going to separate them out
 *        to prevent them from impacting the main file and maybe allow me a little flexibility
 *        when saving.
 */
-(id) initWithFeedDirectory:(NSURL *) u
{
    self = [super init];
    if (self) {
        saveIsRequired                    = NO;
        uFile                             = [[u URLByAppendingPathComponent:[ChatSealFeed standardMiningFilename]] retain];
        mdMiningStats                     = nil;
        [self loadIfNecessary];
        needsFriendshipUpdate             = YES;
        hasHadInitialUpdate               = NO;
        maReachableStats                  = nil;
        maPriorityStats                   = nil;
        isRealtimeOnline                  = NO;
        lastRealtimeCount                 = CS_TF_TM_DEFAULT_REALTIME_COUNT;
        realtimeDataSupportsAForwardQuery = YES;                    //  default to this just so we are sure to always query forward first.
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [mdMiningStats release];
    mdMiningStats = nil;
    
    [uFile release];
    uFile = nil;
    
    [maReachableStats release];
    maReachableStats = nil;
    
    [maPriorityStats release];
    maPriorityStats = nil;
    
    [super dealloc];
}

/*
 *  Record that we need new friendship information before we can do anything with this object.
 */
-(void) markFriendshipsAreUpdated
{
    @synchronized (self) {
        needsFriendshipUpdate = YES;
    }
}

/*
 *  Return whether there is high-priority work to perform.
 */
-(BOOL) hasHighPriorityWorkToPerformInFeed:(CS_twitterFeed *) feed
{
    // - determine if we should first update our friendship states before doing anything.
    BOOL needsUpdate          = NO;
    NSUInteger countConnected = 0;
    @synchronized (self) {
        needsUpdate    = needsFriendshipUpdate;
        countConnected = [maReachableStats count];
    }
    
    // - now update them if necessary.
    if (needsUpdate) {
        [self recomputeFriendshipStatesFromFeed:feed];
    }
    
    // - the objective is to make this flag very clear so that we don't waste our time
    //   computing it every second, especially if there are a lot of friends to query.
    @synchronized (self) {
        // - the only time we're going to request high priority attention is when friend connectivity has
        //   improved.
        if (needsUpdate && countConnected < [maReachableStats count]) {
            hasHadInitialUpdate = NO;           // - just reset this flag which usually gates high-priority updates
            return YES;
        }
        
        // - most of the time we won't perform high-priority work to minimize needless thrash.
        return NO;
    }
}

/*
 *  Perform processing for transient mining.
 */
-(BOOL) processFeedTypeRequestsUsingFeed:(CS_twitterFeed *) feed asOnlyHighPriority:(BOOL) onlyHighPrio
{
    // - we aren't going to use high-priority updates for the time being unless we've had no updates.
    // - I don't think the friendship state update should be part of this determination because it
    //   can get fired for a lot of different reasons and frequently.
    BOOL friendsChanged = NO;
    @synchronized (self) {
        if (onlyHighPrio && hasHadInitialUpdate) {
            [self saveIfNecessary];
            return YES;
        }
        friendsChanged = needsFriendshipUpdate;
    }
    
    // - friendship states are important to how this makes the decision about priortizing mining.
    if (friendsChanged) {
        [self recomputeFriendshipStatesFromFeed:feed];
    }
    
    // - if there is no capacity, don't continue because the following computations will not be necessary and
    //   we can save on processing.
    if ([self isThrottleMaxedOutInFeed:feed]) {
        [self saveIfNecessary];
        return NO;
    }
    
    // - do some of this under lock.
    NSArray *arrTmpProc = nil;
    @synchronized (self) {
        // - once during every refresh cycle, we're going to re-sort the stats array to give other stats the
        //   opportunity to get service.
        if (!onlyHighPrio || !hasHadInitialUpdate || !maPriorityStats) {
            [maPriorityStats release];
            maPriorityStats = [[NSMutableArray alloc] initWithArray:maReachableStats];
            [maPriorityStats sortUsingComparator:^NSComparisonResult(CS_twmGenericUser_miningStats *u1, CS_twmGenericUser_miningStats *u2) {
                NSUInteger p1 = u1.statPriority;
                NSUInteger p2 = u2.statPriority;
                if (p1 < p2) {
                    return NSOrderedDescending;
                }
                else if (p2 < p1) {
                    return NSOrderedAscending;
                }
                else {
                    // - when the basic priority is equivalent between stats, we're going to use
                    //   the popularity of the statistics (how many messages were retrieved) as a secondary
                    //   indicator to help us favor the places where we most often find content.
                    p1 = u1.statPopularity;
                    p2 = u2.statPopularity;
                    if (p1 < p2) {
                        return NSOrderedDescending;
                    }
                    else if (p2 < p1) {
                        return NSOrderedAscending;
                    }
                }
                return NSOrderedSame;
            }];
        }
        
        // - make a copy of the sorted array and stats objects.
        arrTmpProc = [NSArray arrayWithArray:maPriorityStats];
    }
    
    // - now, outside the lock, start updating the stats.
    BOOL wasThrottled = NO;
    for (CS_twmGenericUser_miningStats *ms in arrTmpProc) {
        if ([ms isKindOfClass:[CS_twmFeedOwner_miningStats class]]) {
            // - the feed owner gets the majority of the capacity and is going to have as much opportunity
            //   as possible to get his content pulled.
            // - we'll not check return codes because both of these allocate from different pools of API.
            [(CS_twmFeedOwner_miningStats *) ms performMiningRequestsUsingFeed:feed asForwardRequest:!isRealtimeOnline || realtimeDataSupportsAForwardQuery];
        }
        else {
            // - when these secondary requests fail, there is nothing left.
            if (![ms performMiningRequestsUsingFeed:feed] && [ms isKindOfClass:[CS_twmFriend_miningStats class]]) {
                wasThrottled = YES;
                break;
            }
            
            // - if we're in the background, the most we'll mine is one friend at a time.
            if (![ChatSeal isApplicationForeground] && [ms isKindOfClass:[CS_twmFriend_miningStats class]]) {
                break;
            }
        }
    }
    
    // - if there is still capacity, then we should try the optional updates now, which are old gaps
    //   in the timeline that we might have a chance of filling-in.
    // - optional requests are never issued in the background.
    if (!wasThrottled && [ChatSeal isApplicationForeground]) {
        for (CS_twmGenericUser_miningStats *ms in arrTmpProc) {
            // - when these secondary requests fail, there is nothing left.
            if (![ms performOptionalMiningRequestsUsingFeed:feed]) {
                wasThrottled = YES;
                break;
            }
        }
    }
    
    // - once we make it completely through, we should assume the initial update was executed, even if it wasn't
    //   successful.
    @synchronized (self) {
        hasHadInitialUpdate               = YES;
        realtimeDataSupportsAForwardQuery = YES;        // - always return to forward querying when we're complete in case the value isn't set next time.
        
        // - save the changes as necessary.
        [self saveIfNecessary];
    }
    
    return !wasThrottled;
}

/*
 *  Process the results of the transient mining request.
 */
-(void) completeTimelineProcesing:(CS_tapi_statuses_timeline_base *) api usingFeed:(CS_twitterFeed *) feed
{
    CS_twmGenericUser_miningStats *ms = nil;
    @synchronized (self) {
        if ([api isKindOfClass:[CS_tapi_statuses_user_timeline class]]) {
            ms = [self statsForScreenName:[(CS_tapi_statuses_user_timeline *) api screenName]];
        }
        else if ([api isKindOfClass:[CS_tapi_statuses_mentions_timeline class]]) {
            ms = [[[mdMiningStats objectForKey:CS_TF_TM_MENTIONS_STATS] retain] autorelease];
        }
        else {
            ms = [self statsForFeed:feed];
        }
    }
    
    // - pass the results onto the given stat collection.
    if ([ms completeTimelineAPI:api usingFeed:feed]) {
        @synchronized (self) {
            [self saveDeferredUntilEndOfCycle];
        }
    }
}

/*
 *  When realtime mining is online we can make some different decisions about how requests are handled.
 */
-(void) setRealtimeMiningIsOnline:(BOOL) isOnline
{
    @synchronized (self) {
        isRealtimeOnline = isOnline;
    }
}

/*
 *  The count of realtime content events processed will help us understand how active the home timeline is.
 */
-(void) setRealtimeContentEventsProcessed:(NSUInteger) numProcessed
{
    @synchronized (self) {
        // - when the realtime feed retrieves new tweets, it is an indication that we should be looking
        //   ahead in the timeline to keep it all in sync.
        //   ... but don't change the direction the first time.  We want that to always occur
        if (lastRealtimeCount != CS_TF_TM_DEFAULT_REALTIME_COUNT) {
            realtimeDataSupportsAForwardQuery = (numProcessed != lastRealtimeCount) ? YES : NO;
        }
        lastRealtimeCount = numProcessed;
    }
}

/*
 *  Using the API, block out the range specified in it as if it was completed.
 */
-(void) markTimelineRangeAsProcessedFromAPI:(CS_tapi_statuses_timeline_base *) api
{
    // - only a friend's feed is supported.
    if (![api isKindOfClass:[CS_tapi_statuses_user_timeline class]]) {
        return;
    }
    
    // NOTE: This kind of method is possible because we don't treat feeds as separate messaging zones.
    //       The idea is pull messages from many sources and aggregate them into a single message database, which means that
    //       if one feed successfully queries for a user timeline, the other feeds can assume that the content is good and
    //       come to similar conclusions.  This is an important feature because it also cuts down on traffic.
    
    CS_tapi_statuses_user_timeline *ut = (CS_tapi_statuses_user_timeline *) api;
    @synchronized (self) {
        CS_twmGenericUser_miningStats *ms = [self statsForScreenName:ut.screenName];
        if (!ms || ![ms isKindOfClass:[CS_twmFriend_miningStats class]]) {
            return;
        }
        
        // - now just make sure the mining stats are updated.
        [ms updateOnlyHistoryWithAPI:ut];
    }
}

/*
 *  Prefill state from another mining object.
 */
-(void) prefillSharedContentDuringCreationFromMining:(CS_twitterFeed_transient_mining *) miningOther
{
    // - our object isn't yet in the active queue, so there should never be contention for us, but we'll
    //   lock from outside-in anyway.
    @synchronized (miningOther) {
        @synchronized (self) {
            if (miningOther) {
                [miningOther->mdMiningStats enumerateKeysAndObjectsUsingBlock:^(NSString *screenName, CS_twmGenericUser_miningStats *stats, BOOL *stop) {
                    if (![stats isKindOfClass:[CS_twmFriend_miningStats class]] || [mdMiningStats objectForKey:screenName]) {
                        return;
                    }
                    
                    // - we only copy friends because the other types are specific to the feed.
                    CS_twmGenericUser_miningStats *msCopy = [[(CS_twmFriend_miningStats *) stats copy] autorelease];
                    if (msCopy) {
                        [mdMiningStats setObject:msCopy forKey:screenName];
                    }
                }];
            }
        }
    }
}
@end

/******************************************
 CS_twitterFeed_transient_mining (internal)
 ******************************************/
@implementation CS_twitterFeed_transient_mining (internal)

/*
 *  Load the stats from disk.
 *  - ASSUMES the lock is held.
 */
-(void) loadIfNecessary
{
    // - if the file URL is not set, we can't really make decisions about what to do here.
    if (mdMiningStats || !uFile) {
        return;
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[uFile path]]) {
        NSError *err  = nil;
        NSObject *obj = [CS_feedCollectorUtil secureLoadConfigurationFromFile:uFile withError:&err];
        if ([obj isKindOfClass:[NSMutableDictionary class]]) {
            mdMiningStats = [(NSMutableDictionary *) obj retain];
            [mdMiningStats enumerateKeysAndObjectsUsingBlock:^(NSString *screenName, CS_twmGenericUser_miningStats *ms, BOOL *stop) {
                //  - we do this to avoid having multiple copies of the same screen name.  The original
                //    will be in the dictionary.
                [ms assignPostLoadScreenName:screenName];
            }];
            return;
        }
        
        //  - I thought about this and if the stats could not be loaded, I'm going to allow them to be overwritten because
        //    they can be regenerated.  I think it is probably better to gracefully adapt rather than cause everything else
        //    to fail.
        NSLog(@"CS: Unexpected failure to load mining statistics.  %@", err ? [err localizedDescription] : @"");
    }

    // - default behavior.
    mdMiningStats = [[NSMutableDictionary alloc] init];
    [self saveDeferredUntilEndOfCycle];
}

/*
 *  Return the mining stats for the given feed owner.
 *  - ASSUMES the lock is held.
 */
-(CS_twmFeedOwner_miningStats *) statsForFeed:(CS_twitterFeed *) feed
{
    NSString *screenName              = [feed userId];
    CS_twmGenericUser_miningStats *ms = [mdMiningStats objectForKey:screenName];
    if (!ms || ![ms isKindOfClass:[CS_twmFeedOwner_miningStats class]]) {
        ms = [[[CS_twmFeedOwner_miningStats alloc] initWithScreenName:screenName] autorelease];
        [mdMiningStats setObject:ms forKey:screenName];
        [self saveDeferredUntilEndOfCycle];
    }
    return (CS_twmFeedOwner_miningStats *) [[ms retain] autorelease];
}

/*
 *  Return the mining stats for the given name.
 *  - ASSUMES the lock is held.
 */
-(CS_twmFriend_miningStats *) statsForFriend:(NSString *) screenName
{
    CS_twmGenericUser_miningStats *ms = [mdMiningStats objectForKey:screenName];
    if (!ms || ![ms isKindOfClass:[CS_twmFriend_miningStats class]]) {
        ms = [[[CS_twmFriend_miningStats alloc] initWithScreenName:screenName] autorelease];
        [mdMiningStats setObject:ms forKey:screenName];
        [self saveDeferredUntilEndOfCycle];
    }
    return (CS_twmFriend_miningStats *) [[ms retain] autorelease];
}

/*
 *  Return the mining stats for the given name.
 *  - ASSUMES the lock is held.
 */
-(CS_twmGenericUser_miningStats *) statsForScreenName:(NSString *) screenName
{
    return (CS_twmGenericUser_miningStats *) [mdMiningStats objectForKey:screenName];
}

/*
 *  The friendship states are important so that we can accurately prioritize the 
 *  service we give to each account.
 */
-(void) recomputeFriendshipStatesFromFeed:(CS_twitterFeed *) feed
{
    // NOTE:  if friends disappear because they are being ignored, we won't delete them here because
    //        that doesn't mean we shouldn't continue to learn about them and their importance.  These stats
    //        have value because they help prioritize how our work is done.
    
    // - the point of this is to ensure we keep the intelligence close to where it is being used instead of always pulling
    //   data from the friendship database, which could potentially be slow.
    NSDictionary *dictFriends = [feed statesForAllReachableFriends];
    @synchronized (self) {
        // - this array organizes the stats that are associated with Twitter timelines we can contact.
        if (maReachableStats) {
            [maReachableStats removeAllObjects];
        }
        else {
            maReachableStats = [[NSMutableArray alloc] init];
        }
        
        // - scan through the list of reachable friends that intersect with our available stats.
        [dictFriends enumerateKeysAndObjectsUsingBlock:^(NSString *screenName, CS_tapi_friendship_state *fs, BOOL *stop) {
            CS_twmGenericUser_miningStats *ms = [self statsForFriend:screenName];
            [ms updateFriendshipState:fs];
            [maReachableStats addObject:ms];
        }];
        
        // - add the feed and mentions stats as well.
        CS_twmGenericUser_miningStats *ms = [self statsForFeed:feed];
        if (ms) {
            [maReachableStats addObject:ms];
        }
         
        ms = [mdMiningStats objectForKey:CS_TF_TM_MENTIONS_STATS];
        if (!ms) {
            ms = [[[CS_twmFeedMentions_miningStats alloc] initWithScreenName:CS_TF_TM_MENTIONS_STATS] autorelease];
            [mdMiningStats setObject:ms forKey:CS_TF_TM_MENTIONS_STATS];
            [self saveDeferredUntilEndOfCycle];
        }
        [maReachableStats addObject:ms];
        
        // - when we processed friends, that means our stats probably need updated.
        if ([dictFriends count]) {
            [self saveDeferredUntilEndOfCycle];
        }
        
        needsFriendshipUpdate = NO;
    }    
}

/*
 *  Mark this object as requiring a save.
 *  - ASSUMES the lock is held.
 */
-(void) saveDeferredUntilEndOfCycle
{
    saveIsRequired = YES;
}

/*
 *  Save content.
 */
-(void) saveIfNecessary
{
    @synchronized (self) {
        if (!saveIsRequired || !uFile) {
            return;
        }
        
        NSError *err = nil;
        saveIsRequired = NO;
        if (![CS_feedCollectorUtil secureSaveConfiguration:mdMiningStats asFile:uFile withError:&err]) {
            NSLog(@"CS: Failed to save mining stats at %@.  %@", uFile, [err localizedDescription]);
        }
    }
}

/*
 *  Determine if the APIs are all exhausted.
 */
-(BOOL) isThrottleMaxedOutInFeed:(CS_twitterFeed *) feed
{
    if (![feed hasCapacityForAPIByName:@"CS_tapi_statuses_home_timeline" withEvenDistribution:NO] &&
        ![feed hasCapacityForAPIByName:@"CS_tapi_statuses_user_timeline" withEvenDistribution:NO]) {
        return YES;
    }
    return NO;
}
@end
