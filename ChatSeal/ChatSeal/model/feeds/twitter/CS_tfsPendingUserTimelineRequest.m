//
//  CS_tfsPendingUserTimelineRequest.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tfsPendingUserTimelineRequest.h"
#import "CS_tapi_tweetRange.h"

/*************************************
 CS_tfsPendingUserTimelineRequest
 *************************************/
@implementation CS_tfsPendingUserTimelineRequest
/*
 *  Object attributes
 */
{
}
@synthesize screenName;
@synthesize requestedRange;
@synthesize localUser;

/*
 *  Initialize the object.
 */
-(id) initWithScreenName:(NSString *) name andRange:(CS_tapi_tweetRange *) r forLocalUser:(NSString *) lu
{
    self = [super init];
    if (self) {
        screenName     = [name retain];
        requestedRange = [r retain];
        localUser      = [lu retain];
    }
    return self;
}

/*
 *  Generate a new pending request object.
 */
+(CS_tfsPendingUserTimelineRequest *) requestForScreenName:(NSString *)screenName andRange:(CS_tapi_tweetRange *)range fromLocalUser:(NSString *)localUser
{
    return [[[CS_tfsPendingUserTimelineRequest alloc] initWithScreenName:screenName andRange:range forLocalUser:localUser] autorelease];
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [screenName release];
    screenName = nil;
    
    [requestedRange release];
    requestedRange = nil;
    
    [localUser release];
    localUser = nil;
    
    [super dealloc];
}

@end
