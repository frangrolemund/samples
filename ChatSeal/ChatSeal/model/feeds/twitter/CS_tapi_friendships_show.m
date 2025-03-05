//
//  CS_tapi_friendships_show.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tapi_friendships_show.h"
#import "ChatSeal.h"

//  THREADING-NOTES:
//  - These API object instances are consistent with the threading rules defined for CS_netFeedAPI and as such
//    do not require custom internal locking.

/****************************
 CS_tapi_friendships_show
 REF: https://dev.twitter.com/docs/api/1.1/get/friendships/show
 ****************************/
@implementation CS_tapi_friendships_show
/*
 *  Object attributes
 */
{
    NSString *sourceName;
    NSString *targetName;
}

/*
 *  Initialize the object.
 */
-(id) initWithCreatorHandle:(CS_netFeedCreatorDelegateHandle *)cdh inCategory:(cs_cnt_throttle_category_t)category
{
    self = [super initWithCreatorHandle:cdh inCategory:category];
    if (self) {
        sourceName = nil;
        targetName = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [sourceName release];
    sourceName = nil;
    
    [targetName release];
    targetName = nil;
    
    [super dealloc];
}


/*
 *  Assign a source screen name for this API.
 */
-(void) setSourceScreenName:(NSString *) screenName
{
    if (sourceName != screenName) {
        [sourceName release];
        sourceName = [screenName retain];
    }
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
    return [NSURL URLWithString:@"https://api.twitter.com/1.1/friendships/show.json"];
}

/*
 *  Use the supplied parameters to build a new request for the caller.
 */
-(NSURLRequest *) generateRequestWithError:(NSError **)err
{
    if (!sourceName || !targetName) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        [self alertLogForRequiredParameters];
        return nil;
    }
    
    NSMutableDictionary *mdParms = [NSMutableDictionary dictionary];
    [mdParms setObject:sourceName forKey:@"source_screen_name"];
    [mdParms setObject:targetName forKey:@"target_screen_name"];
    
    return [self generateTwitterRequestForMethod:CS_TWIT_RM_GET andParameters:mdParms];
}

/*
 *  Return a friendship state object for the requested target.
 */
-(CS_tapi_friendship_state *) resultTargetState
{
    if (![self isAPISuccessful]) {
        return nil;
    }
    
    NSObject *objRet = [self resultDataConvertedFromJSON];
    if (!objRet || ![objRet isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    objRet           = [(NSDictionary *) objRet objectForKey:@"relationship"];
    if (!objRet || ![objRet isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSDictionary *dict = [(NSDictionary *) objRet objectForKey:@"source"];
    return [CS_tapi_friendship_state stateOfTargetFromSource:dict];
}

@end
