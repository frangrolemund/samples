//
//  CS_tapi_statuses_home_timeline.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/5/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tapi_statuses_home_timeline.h"
#import "ChatSeal.h"

//  THREADING-NOTES:
//  - These API object instances are consistent with the threading rules defined for CS_netFeedAPI and as such
//    do not require custom internal locking.

// - constants
static const NSUInteger CS_TAPI_HT_MAX_COUNT = 100;             //  less than the publicized maximum for home timeline requests because that will return an immense amount of data.

/******************************
 CS_tapi_statuses_home_timeline
 REF: https://dev.twitter.com/docs/api/1.1/get/statuses/home_timeline
 ******************************/
@implementation CS_tapi_statuses_home_timeline
/*
 *  Initializet the object.
 */
-(id) initWithCreatorHandle:(CS_netFeedCreatorDelegateHandle *)cdh inCategory:(cs_cnt_throttle_category_t)category
{
    self = [super initWithCreatorHandle:cdh inCategory:category];
    if (self) {
        [self setMaxCount:CS_TAPI_HT_MAX_COUNT];
    }
    return self;
}

/*
 *  Return the service entrypoint.
 */
-(NSURL *) resourceURL
{
    return [NSURL URLWithString:@"https://api.twitter.com/1.1/statuses/home_timeline.json"];
}

/*
 *  Use the supplied parameters to build a new request for the caller.
 */
-(NSURLRequest *) generateRequestWithError:(NSError **)err
{
    NSMutableDictionary *mdParms = [self commonAttributes];
    if (!mdParms) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        [self alertLogForRequiredParameters];
        return nil;
    }
    
    return [self generateTwitterRequestForMethod:CS_TWIT_RM_GET andParameters:mdParms];
}

@end
