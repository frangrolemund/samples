//
//  CS_tapi_users_lookup.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/8/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tapi_users_lookup.h"
#import "ChatSeal.h"

//  THREADING-NOTES:
//  - These API object instances are consistent with the threading rules defined for CS_netFeedAPI and as such
//    do not require custom internal locking.

/***********************
 CS_tapi_users_lookup
 REF: https://dev.twitter.com/docs/api/1.1/get/users/lookup
 ***********************/
@implementation CS_tapi_users_lookup
/*
 *  Object attributes.
 */
{
    NSMutableArray *maScreenNames;
}

/*
 *  This API is restricted from accepting more than a set number per request.
 */
+(NSUInteger) maxUsersPerRequest
{
    return 100;
}

/*
 *  Initialize the object.
 */
-(id) initWithCreatorHandle:(CS_netFeedCreatorDelegateHandle *)cdh inCategory:(cs_cnt_throttle_category_t)category
{
    self = [super initWithCreatorHandle:cdh inCategory:category];
    if (self) {
        maScreenNames = [[NSMutableArray alloc] init];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [maScreenNames release];
    maScreenNames = nil;
    
    [super dealloc];
}

/*
 *  Assign the list of screen names that should be retrieved.
 */
-(void) setScreenNames:(NSArray *) aNames
{
    [maScreenNames removeAllObjects];
    [maScreenNames addObjectsFromArray:aNames];
}

/*
 *  Return the list of screen names that are managed by this API.
 */
-(NSArray *) screenNames
{
    return [NSArray arrayWithArray:maScreenNames];
}

/*
 *  Return the service entrypoint.
 */
-(NSURL *) resourceURL
{
    return [NSURL URLWithString:@"https://api.twitter.com/1.1/users/lookup.json"];
}

/*
 *  Use the supplied parameters to build a new request for the caller.
 */
-(NSURLRequest *) generateRequestWithError:(NSError **)err
{
    if (![maScreenNames count]) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        [self alertLogForRequiredParameters];
        return nil;
    }
    
    NSMutableDictionary *mdParms = [NSMutableDictionary dictionary];
    NSArray *maLimited           = [maScreenNames subarrayWithRange:NSMakeRange(0, MIN([maScreenNames count], [CS_tapi_users_lookup maxUsersPerRequest]))];
    NSString *sNameList          = [maLimited componentsJoinedByString:@","];
    
    [mdParms setObject:sNameList forKey:@"screen_name"];
    [mdParms setObject:CS_TWITTERAPI_COMMON_FALSE forKey:@"include_entities"];
    
    return [self generateTwitterRequestForMethod:CS_TWIT_RM_POST andParameters:mdParms];
}

/*
 *  When results are returned this produces a list of all the parsed user definitions.
 */
-(NSArray *) resultDataUserDefinitions
{
    NSObject *obj = [self resultDataConvertedFromJSON];
    if (![obj isKindOfClass:[NSArray class]]) {
        return nil;
    }
    
    NSMutableArray *maRet = [NSMutableArray array];
    NSArray *arrUserInfo = (NSArray *) obj;
    for (NSObject *objUser in arrUserInfo) {
        if (![objUser isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        
        CS_tapi_user_looked_up *tulu = [CS_tapi_user_looked_up userFromTapiDictionary:(NSDictionary *) objUser];
        if (tulu) {
            [maRet addObject:tulu];
        }
    }
    return maRet;
}
@end