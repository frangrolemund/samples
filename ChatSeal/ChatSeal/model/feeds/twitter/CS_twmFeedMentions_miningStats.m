//
//  CS_twmFeedMentions_miningStats.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/13/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twmFeedMentions_miningStats.h"
#import "CS_twitterFeed_shared.h"

//  THREADING-NOTES:
//  - this object provides locking because it performs its updates outside the transient mining lock.

// - forward declarations
@interface CS_twmFeedMentions_miningStats (internal)
-(void) commonConfiguration;
@end

/*******************************
 CS_twmFeedMentions_miningStats
 *******************************/
@implementation CS_twmFeedMentions_miningStats
/*
 *  Object attributes.
 */
{
    BOOL       inRequest;
    BOOL       doForward;
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
    // - mentions come right after the home timeline.
    return ((NSUInteger) -1) - 1;
}

/*
 *  Make the mining requests that must occur for this object during
 *  a normal refresh.
 *  - return NO when all the requests are throttled.
 */
-(BOOL) performMiningRequestsUsingFeed:(CS_twitterFeed *)feed
{
    // - REMEMBER: this is an OVERRIDE of the base because a feed owner has special requirements.
    [[self statsLock] lock];
    if (inRequest) {
        return YES;
    }
    [[self statsLock] unlock];
    
    
    // NOTE: the importance of mentions is that it allows us to know if one of our consumers has replied to us but we're not
    //       yet following them.  In this timeline, we have an opportunity to pick up those kinds of messages and then incorporate them
    //       into our friends list.
    
    // - there isn't much capacity for this API so use an even distribution.
    BOOL wasThrottled                  = NO;
    CS_tapi_statuses_mentions_timeline *mt = (CS_tapi_statuses_mentions_timeline *) [feed evenlyDistributedApiForName:@"CS_tapi_statuses_mentions_timeline" andReturnWasThrottled:&wasThrottled withError:nil];
    if (!mt) {
        return !wasThrottled;
    }

    //  - the forward/backward flag is very important because it could end up wasting a lot of resources to scan backwards if we're not sure.
    if (doForward || ![self hasPriorGapsInHistory]) {
        [self populateAPIForMostRecentRequest:mt];
    }
    else {
        [self populateAPIForPastGapsOrMostRecentRequest:mt];
    }
    
    // - try to schedule it
    if (![feed addCollectorRequestWithAPI:mt andReturnWasThrottled:&wasThrottled withError:nil]) {
        return !wasThrottled;
    }
    
    // - only permit one at a time.
    [[self statsLock] lock];
    inRequest = YES;
    doForward = !doForward;         //  just alternate in the mentions to try to get everything.
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
 CS_twmFeedMentions_miningStats (internal)
 **************************************/
@implementation CS_twmFeedMentions_miningStats (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    inRequest = NO;
    doForward = YES;
}
@end

