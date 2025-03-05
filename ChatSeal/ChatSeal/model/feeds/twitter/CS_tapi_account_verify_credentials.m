//
//  CS_tapi_account_verify_credentials.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/12/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tapi_account_verify_credentials.h"

//  THREADING-NOTES:
//  - These API object instances are consistent with the threading rules defined for CS_netFeedAPI and as such
//    do not require custom internal locking.

/****************************************
 CS_tapi_account_verify_credentials
 ****************************************/
@implementation CS_tapi_account_verify_credentials
/*
 *  Object attributes.
 */
{
}

/*
 *  Initialize the object.
 */
-(id) initWithCreatorHandle:(CS_netFeedCreatorDelegateHandle *)cdh inCategory:(cs_cnt_throttle_category_t)category
{
    self = [super initWithCreatorHandle:cdh inCategory:category];
    if (self) {
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [super dealloc];
}

/*
 *  Return the service entrypoint.
 */
-(NSURL *) resourceURL
{
    return [NSURL URLWithString:@"https://api.twitter.com/1.1/account/verify_credentials.json"];
}

/*
 *  Use the supplied parameters to build a new request for the caller.
 */
-(NSURLRequest *) generateRequestWithError:(NSError **)err
{
    NSMutableDictionary *mdParms = [NSMutableDictionary dictionary];
    [mdParms setObject:CS_TWITTERAPI_COMMON_FALSE forKey:@"include_entities"];
    [mdParms setObject:CS_TWITTERAPI_COMMON_FALSE forKey:@"skip_status"];
    return [self generateTwitterRequestForMethod:CS_TWIT_RM_GET andParameters:mdParms];
}

/*
 *  Return the numeric id from the result data.
 */
-(void) parseNumericIdStr:(NSString **) numericIdStr andFriendsCount:(NSNumber **) friendsCount
{
    NSObject *obj = [self resultDataConvertedFromJSON];
    if (!obj || ![obj isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
    NSString *tmp = [(NSDictionary *) obj objectForKey:@"id_str"];
    if (numericIdStr) {
        *numericIdStr = [[tmp retain] autorelease];
    }
    
    NSNumber *nFriends = [(NSDictionary *) obj objectForKey:@"friends_count"];
    if (friendsCount) {
        *friendsCount = [[nFriends retain] autorelease];
    }
}

@end
