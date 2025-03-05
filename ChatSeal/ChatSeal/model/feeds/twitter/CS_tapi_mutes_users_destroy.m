//
//  CS_tapi_mutes_users_destroy.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/30/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tapi_mutes_users_destroy.h"
#import "ChatSeal.h"

//  THREADING-NOTES:
//  - These API object instances are consistent with the threading rules defined for CS_netFeedAPI and as such
//    do not require custom internal locking.

/************************************
 CS_tapi_mutes_users_destroy
 REF: https://dev.twitter.com/docs/api/1.1/post/mutes/users/destroy
 ************************************/
@implementation CS_tapi_mutes_users_destroy
/*
 *  Object attributes
 */
{
    NSString *targetName;
}

/*
 *  Initialize the object.
 */
-(id) initWithCreatorHandle:(CS_netFeedCreatorDelegateHandle *)cdh inCategory:(cs_cnt_throttle_category_t)category
{
    self = [super initWithCreatorHandle:cdh inCategory:category];
    if (self) {
        targetName = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [targetName release];
    targetName = nil;
    
    [super dealloc];
}

/*
 *  Assign a target screen name for this API.
 */
-(void) setTargetScreenName:(NSString *) screenName
{
    if (targetName != screenName) {
        [targetName release];
        targetName = [screenName retain];
    }
}

/*
 *  Return the taget we were querying.
 */
-(NSString *) targetScreenName
{
    return [[targetName retain] autorelease];
}

/*
 *  Return the service entrypoint.
 */
-(NSURL *) resourceURL
{
    return [NSURL URLWithString:@"https://api.twitter.com/1.1/mutes/users/destroy.json"];
}

/*
 *  Use the supplied parameters to build a new request for the caller.
 */
-(NSURLRequest *) generateRequestWithError:(NSError **)err
{
    if (!targetName) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        [self alertLogForRequiredParameters];
        return nil;
    }
    
    NSMutableDictionary *mdParms = [NSMutableDictionary dictionary];
    [mdParms setObject:targetName forKey:@"screen_name"];
    
    return [self generateTwitterRequestForMethod:CS_TWIT_RM_POST andParameters:mdParms];
}
@end
