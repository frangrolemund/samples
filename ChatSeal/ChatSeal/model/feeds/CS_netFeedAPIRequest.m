//
//  CS_netFeedAPIRequest.m
//  ChatSeal
//
//  Created by Francis Grolemund on 5/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_netFeedAPIRequest.h"

/****************************
 CS_netFeedAPIRequest
 ****************************/
@implementation CS_netFeedAPIRequest
/*
 *  Object attributes
 */
{
    ChatSealFeed  *feed;
    CS_netFeedAPI *api;
}
@synthesize task;

/*
 *  Initialize the object.
 */
-(id) initWithFeed:(ChatSealFeed *) initFeed andAPI:(CS_netFeedAPI *) initAPI
{
    self = [super init];
    if (self) {
        feed = [initFeed retain];
        api  = [initAPI retain];
        task = nil;
    }
    return self;
}

/*
 *  Return a new feed request object.
 */
+(CS_netFeedAPIRequest *) requestForFeed:(ChatSealFeed *) feed andAPI:(CS_netFeedAPI *) api
{
    CS_netFeedAPIRequest *reqRet = [[[CS_netFeedAPIRequest alloc] initWithFeed:feed andAPI:api] autorelease];
    return reqRet;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [feed release];
    feed = nil;
    
    [api release];
    api = nil;
    
    [task release];
    task = nil;
    
    [super dealloc];
}

/*
 *  Return the stored feed.
 */
-(ChatSealFeed *) feed
{
    return [[feed retain] autorelease];
}

/*
 *  Return the stored API
 */
-(CS_netFeedAPI *) api
{
    return [[api retain] autorelease];
}

/*
 *  The basic request needs no preparation.
 */
-(BOOL) needsPreparation
{
    return NO;
}
@end
