//
//  CS_tapi_statuses_user_timeline.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/6/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tapi_statuses_user_timeline.h"
#import "ChatSeal.h"

//  THREADING-NOTES:
//  - These API object instances are consistent with the threading rules defined for CS_netFeedAPI and as such
//    do not require custom internal locking.

// - constants
static const NSUInteger CS_TAPI_UT_MAX_COUNT = 200;


/**************************************
 CS_tapi_statuses_user_timeline
 REF: https://dev.twitter.com/docs/api/1.1/get/statuses/user_timeline
 **************************************/
@implementation CS_tapi_statuses_user_timeline
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
        [self setMaxCount:CS_TAPI_UT_MAX_COUNT];             //  from the docs
    }
    return self;
}

/*
 *  Set the screen name to use for the query.
 */
-(void) setScreenName:(NSString *) name
{
    if (screenName != name) {
        [screenName release];
        screenName = [name retain];
    }
}

/*
 *  Return the user associated with this query.
 */
-(NSString *) screenName
{
    return [[screenName retain] autorelease];
}

/*
 *  This API should never get our feed flagged as expired because a not-authorized could occur if
 *  the other guy is protected and we cannot reach him.
 */
-(BOOL) shouldNotAuthorizedBeInterpretedAsPasswordFailure
{
    // - while it is very possible a password failure will cause this also, we can't distinguish between the
    //   two so we'll have to wait for one of our own to fail to be sure about it.
    return NO;
}

/*
 *  Return the service entrypoint.
 */
-(NSURL *) resourceURL
{
    return [NSURL URLWithString:@"https://api.twitter.com/1.1/statuses/user_timeline.json"];
}

/*
 *  Use the supplied parameters to build a new request for the caller.
 */
-(NSURLRequest *) generateRequestWithError:(NSError **)err
{
    NSMutableDictionary *mdParms = [self commonAttributes];
    if (!screenName || !mdParms) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        [self alertLogForRequiredParameters];
        return nil;
    }
    
    [mdParms setObject:screenName forKey:@"screen_name"];
    [mdParms setObject:CS_TWITTERAPI_COMMON_FALSE forKey:@"include_rts"];           // retweets don't serve any purpose for ChatSeal.
    
    return [self generateTwitterRequestForMethod:CS_TWIT_RM_GET andParameters:mdParms];
}

/*
 *  Return a customized description.
 */
-(NSString *) description
{
    return [NSString stringWithFormat:@"%@: for %@ using %@ (%@ --> %@)", NSStringFromClass([self class]), screenName, [self credAccountName], [self sinceTweetId], [self maxTweetId]];
}

@end
