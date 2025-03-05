//
//  CS_preparingNetFeedAPIRequest.m
//  ChatSeal
//
//  Created by Francis Grolemund on 5/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_preparingNetFeedAPIRequest.h"
#import "CS_netFeedAPI.h"

/*****************************************
 CS_preparingNetFeedAPIRequest
 *****************************************/
@implementation CS_preparingNetFeedAPIRequest
/*
 *  Object attributes
 */
{
    time_t                     tCreated;
    cs_cnt_throttle_category_t category;
    CS_centralNetworkThrottle *throttle;
    BOOL                       isAborted;
}
@synthesize isCompleted;

/*
 *  Initialize the object.
 */
-(CS_preparingNetFeedAPIRequest *) initWithRequest:(CS_netFeedAPIRequest *) req inCategory:(cs_cnt_throttle_category_t) cat usingThrottle:(CS_centralNetworkThrottle *) thr
{
    self = [super initWithFeed:req.feed andAPI:req.api];
    if (self) {
        category    = cat;
        throttle    = [thr retain];
        tCreated    = time(NULL);
        isAborted   = NO;
        isCompleted = NO;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [throttle release];
    throttle = nil;
    
    [super dealloc];
}

/*
 *  Generate a preparing request and return it.
 */
+(CS_preparingNetFeedAPIRequest *) prepareRequest:(CS_netFeedAPIRequest *) req inCategory:(cs_cnt_throttle_category_t) category usingThrottle:(CS_centralNetworkThrottle *) throttle
{
    return [[[CS_preparingNetFeedAPIRequest alloc] initWithRequest:req inCategory:category usingThrottle:throttle] autorelease];
}

/*
 *  Mark this request as aborted.
 */
-(void) setAbortedWithError:(NSError *) err
{
    if (!isAborted) {
        [self.api markAPIAsAbortedWithError:err];
        isAborted = YES;
    }
}

/*
 *  Return the aborted state.
 */
-(BOOL) isAborted
{
    return isAborted;
}

/*
 *  Return the category.
 */
-(cs_cnt_throttle_category_t) category
{
    return category;
}

/*
 *  Return the throttle.
 */
-(CS_centralNetworkThrottle *) throttle
{
    return [[throttle retain] autorelease];
}

/*
 *  Return the time of creation.
 */
-(time_t) creationTime
{
    return tCreated;
}

/*
 *  These requests are special in that they require preparation and should be 
 *  identified as such.
 */
-(BOOL) needsPreparation
{
    return YES;
}

@end
