//
//  CS_tapi_application_rate_limit_status.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/9/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tapi_application_rate_limit_status.h"

//  THREADING-NOTES:
//  - These API object instances are consistent with the threading rules defined for CS_netFeedAPI and as such
//    do not require custom internal locking.

/****************************************
 CS_tapi_application_rate_limit_status
 REF: https://dev.twitter.com/docs/api/1.1/get/application/rate_limit_status
 ****************************************/
@implementation CS_tapi_application_rate_limit_status
/*
 *  Object attributes.
 */
{
    NSMutableArray *maResources;
}

/*
 *  Initialize the object.
 */
-(id) initWithCreatorHandle:(CS_netFeedCreatorDelegateHandle *)cdh inCategory:(cs_cnt_throttle_category_t)category
{
    self = [super initWithCreatorHandle:cdh inCategory:category];
    if (self) {
        maResources = [[NSMutableArray alloc] init];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [maResources release];
    maResources = nil;
    
    [super dealloc];
}

/*
 *  Optionally assign specific resource types to gather.
 */
-(void) setResources:(NSArray *) resourceNames
{
    [maResources removeAllObjects];
    [maResources addObjectsFromArray:resourceNames];
}

/*
 *  Return the service entrypoint.
 */
-(NSURL *) resourceURL
{
    return [NSURL URLWithString:@"https://api.twitter.com/1.1/application/rate_limit_status.json"];
}

/*
 *  Use the supplied parameters to build a new request for the caller.
 */
-(NSURLRequest *) generateRequestWithError:(NSError **)err
{
    NSMutableDictionary *mdParms = [NSMutableDictionary dictionary];
    if ([maResources count]) {
        NSString *sNameList = [maResources componentsJoinedByString:@","];
        [mdParms setObject:sNameList forKey:@"resources"];
    }

    return [self generateTwitterRequestForMethod:CS_TWIT_RM_GET andParameters:mdParms];
}

@end
