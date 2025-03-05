//
//  CS_tapi_friendships_lookup.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/10/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tapi_friendships_lookup.h"
#import "ChatSeal.h"

//  THREADING-NOTES:
//  - These API object instances are consistent with the threading rules defined for CS_netFeedAPI and as such
//    do not require custom internal locking.

/****************************
 CS_tapi_friendships_lookup
 REF: https://dev.twitter.com/docs/api/1.1/get/friendships/lookup
 ****************************/
@implementation CS_tapi_friendships_lookup
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
    return [NSURL URLWithString:@"https://api.twitter.com/1.1/friendships/lookup.json"];
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
    NSArray *maLimited           = [maScreenNames subarrayWithRange:NSMakeRange(0, MIN([maScreenNames count], [CS_tapi_friendships_lookup maxUsersPerRequest]))];
    NSString *sNameList          = [maLimited componentsJoinedByString:@","];
    [mdParms setObject:sNameList forKey:@"screen_name"];
    
    return [self generateTwitterRequestForMethod:CS_TWIT_RM_GET andParameters:mdParms];
}

/*
 *  Parse out the results of the friendships from this API.
 */
-(NSDictionary *) friendResultMasks
{
    if (![self isAPISuccessful]) {
        return nil;
    }
    
    NSObject *obj = [self resultDataConvertedFromJSON];
    if (!obj) {
        return nil;
    }
    
    if (![obj isKindOfClass:[NSArray class]]) {
        NSLog(@"CS-ALERT: Twitter friendship results are in an unexpected format.");
        return nil;
    }
    
    NSMutableDictionary *mdRet = [NSMutableDictionary dictionary];
    for (NSObject *fItem in (NSArray *) obj) {
        if (![fItem isKindOfClass:[NSDictionary class]]) {
            NSLog(@"CS-ALERT: Twitter friendship result is in an unexpected format.");
            return nil;
        }
        
        NSDictionary *dict = (NSDictionary *) fItem;
        NSString *name     = [dict objectForKey:@"screen_name"];
        if (!name) {
            NSLog(@"CS-ALERT: Twitter friendship result has no name.");
            return nil;
        }
        NSObject *conn     = [dict objectForKey:@"connections"];
        if (conn && [conn isKindOfClass:[NSArray class]]) {
            [mdRet setObject:[CS_tapi_friendship_state stateWithConnections:(NSArray *) conn] forKey:name];
        }
    }
    return mdRet;
}

@end