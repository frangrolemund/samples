//
//  CS_tapi_friendships_create.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tapi_friendships_create.h"
#import "ChatSeal.h"

//  THREADING-NOTES:
//  - These API object instances are consistent with the threading rules defined for CS_netFeedAPI and as such
//    do not require custom internal locking.

/****************************
 CS_tapi_friendships_create
 REF: https://dev.twitter.com/docs/api/1.1/post/friendships/create
 ****************************/
@implementation CS_tapi_friendships_create
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
    return [NSURL URLWithString:@"https://api.twitter.com/1.1/friendships/create.json"];
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
    
    // - the docs indicate that this adds mobile notifications when I follow, which at the moment
    //   I don't think is a good idea.  I don't want to necessarily spam them with SMS messages whenever
    //   they get something from ChatSeal.
    [mdParms setObject:CS_TWITTERAPI_COMMON_FALSE forKey:@"follow"];
    
    return [self generateTwitterRequestForMethod:CS_TWIT_RM_POST andParameters:mdParms];
}

/*
 *  Determine if the follow request was successful.
 */
-(BOOL) didFollowSucceed
{
    // - the online docs indicate that a 403 may be returned if the friendship already exists.
    if (self.HTTPStatusCode == CS_TWIT_RC_OK || self.HTTPStatusCode == CS_TWIT_FORBIDDEN) {
        return YES;
    }
    return NO;
}

/*
 *  This is a very precise scenario only for friendship creation, but we're trying to
 *  keep the user updated with status.
 */
-(BOOL) didFollowFailBecauseTheyBlockedMe
{
    if (self.HTTPStatusCode == CS_TWIT_FORBIDDEN) {
        NSObject *obj = [self resultDataConvertedFromJSON];
        if (obj && [obj isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *) obj;
            obj                = [dict objectForKey:@"errors"];
            if ([obj isKindOfClass:[NSArray class]]) {
                NSArray *arr = (NSArray *) obj;
                for (obj in arr) {
                    if ([obj isKindOfClass:[NSDictionary class]]) {
                        dict = (NSDictionary *) obj;
                        NSObject *oCode = [dict objectForKey:@"code"];
                        if ([oCode isKindOfClass:[NSNumber class]]) {
                            // - a code 162 appears to be the one returned for a blocked attempt, although I had to
                            //   figure this out by trial and error.  It isn't officially documented.
                            if ([(NSNumber *) oCode integerValue] == 162) {
                                return YES;
                            }
                        }
                    }
                }
            }
        }
    }
    return NO;
}

@end
