//
//  CS_twmFeedOwner_miningStats.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/8/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twmFeedOwner_miningStats.h"
#import "CS_twitterFeed_shared.h"

//  THREADING-NOTES:
//  - this object provides locking because it performs its updates outside the transient mining lock.

// - constants
static const NSUInteger CS_TWM_FO_MAX_BACK_QUERIES = 3;

// - forward declarations
@interface CS_twmFeedOwner_miningStats (internal)
-(void) commonConfiguration;
@end

/*******************************
 CS_tmFeedOwner_miningStats
 *******************************/
@implementation CS_twmFeedOwner_miningStats
/*
 *  Object attributes.
 */
{
    BOOL       inRequest;
    NSUInteger numBackQueries;
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
 *  The priority of a particular stat influences its position inside the sequence of operations during a refresh.
 *  - the higher the better.
 */
-(NSUInteger) statPriority
{
    // - a feed owner has the highest priority to ensure it is always refreshed.  The model is that we
    //   promote is one in which our timeline is an aggregated look at all my friends so that we
    //   can avoid the more costly invidual user queries as a rule.
    return (NSUInteger) -1;
}

/*
 *  Make the mining requests that must occur for this object during
 *  a normal refresh.
 *  - return NO when all the requests are throttled.
 */
-(BOOL) performMiningRequestsUsingFeed:(CS_twitterFeed *)feed asForwardRequest:(BOOL) isForward
{
    // - REMEMBER: this is an OVERRIDE of the base because a feed owner has special requirements.
    [[self statsLock] lock];
        if (inRequest) {
            return YES;
        }
    
        // - when we've performed a number of back queries in a row, we want to make sure
        //   we always get a forward request in once in a while just to be sure that we never
        //   miss something.
        if (numBackQueries == CS_TWM_FO_MAX_BACK_QUERIES) {
            isForward = YES;
        }
    [[self statsLock] unlock];
    
    // - there isn't much capacity for this API so use an even distribution.
    BOOL wasThrottled                  = NO;
    CS_tapi_statuses_home_timeline *ht = (CS_tapi_statuses_home_timeline *) [feed evenlyDistributedApiForName:@"CS_tapi_statuses_home_timeline" andReturnWasThrottled:&wasThrottled withError:nil];
    if (!ht) {
        return !wasThrottled;
    }
    
    //  - the forward/backward flag is very important because it could end up wasting a lot of resources to scan backwards if we're not sure..
    if (isForward) {
        [self populateAPIForMostRecentRequest:ht];
    }
    else {
        [self populateAPIForPastGapsOrMostRecentRequest:ht];
    }
    
    // - the back-query count is used to ensure that we don't perform them at the expense of the current home timeline and recent content.
    [[self statsLock] lock];
    if (isForward) {
        numBackQueries = 0;
    }
    else {
        numBackQueries++;
    }
    [[self statsLock] unlock];

    
    // - try to schedule it
    if (![feed addCollectorRequestWithAPI:ht andReturnWasThrottled:&wasThrottled withError:nil]) {
        return !wasThrottled;
    }
    
    // - only permit one at a time.
    [[self statsLock] lock];
        inRequest = YES;
    [[self statsLock] unlock];
    
    return YES;
}

/*
 *  Make any optional requests for this object that could improve its
 *  view of its timeline.
 *  - return NO when all the requests are throttled.
 */
-(BOOL) performOptionalMiningRequestsUsingFeed:(CS_twitterFeed *) feed
{
    // - there are no optional requests for a feed owner.
    return YES;
}

/*
 *  An API we issued has been completed.
 */
-(BOOL) completeTimelineAPI:(CS_tapi_statuses_timeline_base *)api usingFeed:(CS_twitterFeed *)feed
{
    // - just make sure that the single request flag is unset.
    [[self statsLock] lock];
        inRequest = NO;
    [[self statsLock] unlock];
    return [super completeTimelineAPI:api usingFeed:feed];
}
@end

/**************************************
 CS_twmFeedOwner_miningStats (internal)
 **************************************/
@implementation CS_twmFeedOwner_miningStats (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    inRequest      = NO;
    numBackQueries = 0;
}
@end
