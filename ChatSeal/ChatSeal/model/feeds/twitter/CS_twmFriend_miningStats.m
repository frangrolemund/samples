//
//  CS_twmFriend_miningStats.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/9/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twmFriend_miningStats.h"
#import "CS_twitterFeed_shared.h"

// - forward declarations
@interface CS_twmFriend_miningStats (internal)
-(void) commonConfiguration;
-(BOOL) attemptToScheduleQueryAsForward:(BOOL) isForward withFeed:(CS_twitterFeed *) feed;
@end

/*********************************
 CS_twmFriend_miningStats
 *********************************/
@implementation CS_twmFriend_miningStats
/*
 *  Object attributes.
 */
{
    int8_t numOutstanding;
}

/*
 *  Initialize the object.
 */
-(id) initWithScreenName:(NSString *)screenName
{
    self = [super initWithScreenName:screenName];
    if (self) {
        [self commonConfiguration];
    }
    return self;
}

-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonConfiguration];
    }
    return self;
}

/*
 *  Copy this object.
 */
-(id) copyWithZone:(NSZone *)zone
{
    return [[CS_twmFriend_miningStats allocWithZone:zone] initWithMiningStats:self];
}

/*
 *  Make the mining requests that must occur for this object during
 *  a normal refresh.
 *  - return NO when all the requests are throttled.
 */
-(BOOL) performMiningRequestsUsingFeed:(CS_twitterFeed *) feed
{
    return [self attemptToScheduleQueryAsForward:YES withFeed:feed];
}

/*
 *  Make any optional requests for this object that could improve its
 *  view of its timeline.
 *  - return NO when all the requests are throttled.
 */
-(BOOL) performOptionalMiningRequestsUsingFeed:(CS_twitterFeed *) feed
{
    // - if there are no gaps, don't bother with these.
    if (![self hasPriorGapsInHistory]) {
        return YES;
    }
    
    // - try to retrieve old content.
    return [self attemptToScheduleQueryAsForward:NO withFeed:feed];
}

/*
 *  An API we issued has been completed.
 */
-(BOOL) completeTimelineAPI:(CS_tapi_statuses_timeline_base *)api usingFeed:(CS_twitterFeed *)feed
{
    if (![api isKindOfClass:[CS_tapi_statuses_user_timeline class]]) {
        NSLog(@"CS-ALERT: Unexpected non-user timeline request received.");
        return NO;
    }
    
    // - when a timeline request comes through, we need to make sure the type knows about it so
    //   that it doesn't throttle duplicates any longer.
    [feed completeUserTimelineRequest:(CS_tapi_statuses_user_timeline *) api];
    
    // - just make sure that the single request flag is unset.
    [[self statsLock] lock];
    if (numOutstanding) {
        numOutstanding--;
    }
    [[self statsLock] unlock];
    
    // - when this is a not-authorized failure, which very specifically happens when our friend is now protected and
    //   we didn't know about it, we're going to request an immediate update to clarify their state.
    //   stats right now.
    if (![api isAPISuccessful] && api.HTTPStatusCode == CS_TWIT_UNAUTHORIZED) {
        [feed requestHighPriorityRefreshForFriend:[self screenName]];
    }
    
    // - complete in the base to make sure everything is processed.
    return [super completeTimelineAPI:api usingFeed:feed];
}

@end

/************************************
 CS_twmFriend_miningStats (internal)
 ************************************/
@implementation CS_twmFriend_miningStats (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    numOutstanding = 0;
}

/*
 *  Schedule a new query.
 */
-(BOOL) attemptToScheduleQueryAsForward:(BOOL) isForward withFeed:(CS_twitterFeed *) feed
{
    // - don't bother if we don't have access to our friend.
    if (![[feed twitterType] canMyFeed:feed readMyFriend:[self screenName]]) {
        return YES;
    }
    
    [[self statsLock] lock];
    if (numOutstanding == 2 || ![self screenName]) {
        return YES;
    }
    [[self statsLock] unlock];

    // - I'm always evenly scheduling these even though there is lots of capacity because I don't want someone to be able to easily exhaust their capacity.
    // - REMEMBER these per-user queries are not our primary vehicle, the home timeline is.
    BOOL wasThrottled                  = NO;
    CS_tapi_statuses_user_timeline *ut = (CS_tapi_statuses_user_timeline *) [feed evenlyDistributedApiForName:@"CS_tapi_statuses_user_timeline" andReturnWasThrottled:&wasThrottled withError:nil];
    if (!ut) {
        return !wasThrottled;
    }
    
    // - figure out which direction to query.
    if (isForward) {
        [self populateAPIForMostRecentRequest:ut];
    }
    else {
        // - when we don't have old content to grab it doesn't make sense to continue.
        if (![self populateAPIForPastGapsOrMostRecentRequest:ut]) {
            return YES;
        }
    }
    
    // - schedule for a particular friend's account.
    [ut setScreenName:[self screenName]];
    
    // - make sure we're allowe to make this request to prevent duplicate requests between different
    //   feeds and wasted network bandwidth.
    if (![feed isUserTimelineRequestAllowed:ut]) {
        return YES;
    }
    
    // - try to schedule it
    if (![feed addCollectorRequestWithAPI:ut andReturnWasThrottled:&wasThrottled withError:nil]) {
        // - make sure we complete the timeline request when we can't schedule others for the same range!
        [feed completeUserTimelineRequest:ut];
        return !wasThrottled;
    }
    
    // - only permit at most two at a time, one primary, one optional.
    [[self statsLock] lock];
    numOutstanding++;
    [[self statsLock] unlock];
    
    return YES;
}
@end
