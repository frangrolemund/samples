//
//  CS_tapi_users_show.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/30/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tapi_users_show.h"
#import "CS_error.h"

/*********************************
 CS_tapi_users_show
 REF: https://dev.twitter.com/docs/api/1.1/get/users/show
 *********************************/
@implementation CS_tapi_users_show
/*
 *  Object attributes.
 */
{
    NSString *screenName;
}

/*
 *  Initialize the object.
 */
-(id) initWithCreatorHandle:(CS_netFeedCreatorDelegateHandle *)cdh inCategory:(cs_cnt_throttle_category_t)category
{
    self = [super initWithCreatorHandle:cdh inCategory:category];
    if (self) {
        screenName = nil;
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
    
    [super dealloc];
}

/*
 *  Assign the screen name that should be retrieved.
 */
-(void) setScreenName:(NSString *) name
{
    if (screenName != name) {
        [screenName release];
        screenName = [name retain];
    }
}

/*
 *  Return the screen names that is managed by this API.
 */
-(NSString *) screenName
{
    return [[screenName retain] autorelease];
}

/*
 *  Return the service entrypoint.
 */
-(NSURL *) resourceURL
{
    return [NSURL URLWithString:@"https://api.twitter.com/1.1/users/show.json"];
}

/*
 *  Use the supplied parameters to build a new request for the caller.
 */
-(NSURLRequest *) generateRequestWithError:(NSError **)err
{
    if (!screenName) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        [self alertLogForRequiredParameters];
        return nil;
    }
    
    NSMutableDictionary *mdParms = [NSMutableDictionary dictionary];
    [mdParms setObject:screenName forKey:@"screen_name"];
    [mdParms setObject:CS_TWITTERAPI_COMMON_FALSE forKey:@"include_entities"];
    
    return [self generateTwitterRequestForMethod:CS_TWIT_RM_GET andParameters:mdParms];
}

/*
 *  Generate a user profile from the result data.
 */
-(CS_tapi_user_looked_up *) resultDataAsUserInfo
{
    NSObject *obj = [self resultDataConvertedFromJSON];
    if (!obj || ![obj isKindOfClass:[NSDictionary class]]) {
        return nil;
    }    
    return [CS_tapi_user_looked_up userFromTapiDictionary:(NSDictionary *) obj];
}
@end
