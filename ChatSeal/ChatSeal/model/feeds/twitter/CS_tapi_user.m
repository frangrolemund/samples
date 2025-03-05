//
//  CS_tapi_user.m
//  ChatSeal
//
//  Created by Francis Grolemund on 4/7/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tapi_user.h"
#import "CS_tapi_parse_tweet_response.h"

//  THREADING-NOTES:
//  - These API object instances are consistent with the threading rules defined for CS_netFeedAPI and as such
//    do not require custom internal locking.

// - forward declarations
@interface CS_tapi_user (internal)
-(void) triggerStandardUserChange:(SEL) selector withDict:(NSDictionary *) dict;
-(void) processStreamItem:(NSDictionary *) dict;
@end

/**********************
 CS_tapi_user
 REF: https://dev.twitter.com/docs/api/1.1/get/user
 NOTES:
   - the 'delimited' argument is not used because it doesn't make sense with NSURLSession.
   - the 'stall_warnings' argument is not used because at the moment, I'm not sure I can do anything about that.
   - the 'with' argument will always be assigned 'followings' to ensure we get everything on our timeline.
   - the 'replies' argument doesn't make sense for how we're sending messages back and forth.  Consumers cannot reply to one another.
   - the 'locations' argument assumes personal information we may not have access to, and I think that is a bit of a slippery slope.
 **********************/
@implementation CS_tapi_user
/*
 *  Object attributes.
 */
{
    BOOL        gotData;
    NSUInteger  changeEvents;
}
@synthesize delegate;

/*
 *  Initialize the object.
 */
-(id) initWithCreatorHandle:(CS_netFeedCreatorDelegateHandle *)cdh inCategory:(cs_cnt_throttle_category_t)category
{
    self = [super initWithCreatorHandle:cdh inCategory:category];
    if (self) {
        delegate     = nil;
        changeEvents = 0;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    delegate = nil;
    [super dealloc];
}

/*
 *  Return the service entrypoint.
 */
-(NSURL *) resourceURL
{
    return [NSURL URLWithString:@"https://userstream.twitter.com/1.1/user.json"];
}

/*
 *  Use the supplied parameters to build a new request for the caller.
 */
-(NSURLRequest *) generateRequestWithError:(NSError **)err
{
    // NOTE:
    // - just to be explicit, we'll always pass with='followings'
    // - we're always going to 'stringify_friend_ids=true'
    
    // - at the moment, this API doesn't offer much in the way of filtering of the returned content, so
    //   we're only going to request the full list and filter on our end.
    NSMutableDictionary *mdParms = [NSMutableDictionary dictionary];
    [mdParms setObject:@"followings" forKey:@"with"];
    [mdParms setObject:CS_TWITTERAPI_COMMON_TRUE forKey:@"stringify_friend_ids"];
    
    return [self generateTwitterRequestForMethod:CS_TWIT_RM_GET andParameters:mdParms];
}

/*
 *  This method is called whenever the session manager receives new task-related data.
 */
-(void) didReceiveData:(NSData *) d fromSessionDataTask:(NSURLSessionTask *) task withExpectedTotal:(int64_t) totalToTransfer
{
    // - NOTE: we never want to call [super disReceiveDataFromSessionDataTask] here because
    //   that will aggregate all the content, which will save old things that we aren't using
    //   and be capped at a predefined limit in the base class.
    
    if (!d || d.length == 0) {
        return;
    }
    
    // - first get the JSON so we can see if it applies.
    NSObject *obj = [super convertDataFromJSON:d];
    if (!obj) {
        return;
    }
    
    gotData = YES;
    
    // - now we're going to filter and route according to three basic types of content
    if ([obj isKindOfClass:[NSDictionary class]]) {
        [self processStreamItem:(NSDictionary *) obj];
    }
    else if ([obj isKindOfClass:[NSArray class]]) {
        // - I don't know for sure this kind of scenario is possible, but it wouldn't surprise me, so I'm going to look for it as well.
        for (NSObject *item in (NSArray *) obj) {
            if ([item isKindOfClass:[NSDictionary class]]) {
                [self processStreamItem:(NSDictionary *) item];
            }
        }
    }
}

/*
 *  Figure out if we are getting anything back from this object, which implies it is working.
 */
-(BOOL) isReturningData
{
    return gotData;
}

/*
 *  Content change events are things that mark things that could influence what is found in the home timeline.
 */
-(NSUInteger) numberOfContentChangeEvents
{
    return changeEvents;
}
@end

/*************************
 CS_tapi_user (internal)
 *************************/
@implementation CS_tapi_user (internal)
/*
 *  For events that operate on a target entity, this will parse them and issue the selector.
 */
-(void) triggerStandardUserChange:(SEL) selector withDict:(NSDictionary *) dict
{
    NSObject *obj2 = [dict objectForKey:@"source"];
    NSNumber *fc   = [(NSDictionary *) obj2 objectForKey:@"friends_count"];
    
    obj2 = [dict objectForKey:@"target"];
    if ([obj2 isKindOfClass:[NSDictionary class]]) {
        NSObject *obj = [(NSDictionary *) obj2 objectForKey:@"screen_name"];
        if (obj && [obj isKindOfClass:[NSString class]] && [(NSString *) obj length] > 0) {
            if (delegate && [delegate respondsToSelector:selector]) {
                NSMethodSignature *sig   = [(NSObject *) delegate methodSignatureForSelector:selector];
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
                [invocation setSelector:selector];
                [invocation setArgument:&self atIndex:2];
                [invocation setArgument:&obj atIndex:3];
                [invocation setArgument:&fc atIndex:4];
                [invocation invokeWithTarget:delegate];
            }
        }
    }
}

/*
 *  Process one message from the stream.
 */
-(void) processStreamItem:(NSDictionary *) dict
{
    // - check for tweets, specifically image-oriented ones in PNG format because the point of this is to
    //   minimize unnecessary work.
    if ([CS_tapi_parse_tweet_response isStandardStatusResponse:dict]) {
        CS_tapi_parse_tweet_response *ptr = [[[CS_tapi_parse_tweet_response alloc] init] autorelease];
        if ([ptr fillImageTweetFromObject:dict]) {
            if (delegate && [delegate respondsToSelector:@selector(twitterStreamAPI:didFindImageTweet:withURL:fromUser:)]) {
                [delegate twitterStreamAPI:self didFindImageTweet:ptr.tweetId withURL:ptr.imageURL fromUser:ptr.screenName];
            }
        }
        
        // - getting any tweet at all is an indication we should probably scan manually.
        changeEvents++;
        return;
    }
    
    // - check for deletion notifications.
    NSObject *obj = [dict objectForKey:@"delete"];
    if (obj && [obj isKindOfClass:[NSDictionary class]]) {
        NSObject *obj2 = [(NSDictionary *) obj objectForKey:@"status"];
        if (obj2 && [obj2 isKindOfClass:[NSDictionary class]]) {
            obj = [(NSDictionary *) obj2 objectForKey:@"id_str"];
            if (obj && [obj isKindOfClass:[NSString class]]) {
                if (delegate && [delegate respondsToSelector:@selector(twitterStreamAPI:didDetectDeletionOfTweet:)]) {
                    [delegate twitterStreamAPI:self didDetectDeletionOfTweet:(NSString *) obj];
                }
            }
            else {
                [self alertLogResultSetInconsistency];
            }
        }
        return;
    }
    
    // - check for specific notifications for a friend update.
    obj = [dict objectForKey:@"event"];
    if (obj && [obj isKindOfClass:[NSString class]] && [(NSString *) obj isEqualToString:@"follow"]) {
        [self triggerStandardUserChange:@selector(twitterStreamAPI:didFollowUser:withFriendsCount:) withDict:dict];
        // - when we follow someone new, our home timeline is likely to have changed.
        changeEvents++;
        return;
    }
    
    if (obj && [obj isKindOfClass:[NSString class]] && [(NSString *) obj isEqualToString:@"unfollow"]) {
        [self triggerStandardUserChange:@selector(twitterStreamAPI:didUnfollowUser:withFriendsCount:) withDict:dict];
        return;
    }
    
    if (obj && [obj isKindOfClass:[NSString class]] && [(NSString *) obj isEqualToString:@"block"]) {
        [self triggerStandardUserChange:@selector(twitterStreamAPI:didBlockUser:withFriendsCount:) withDict:dict];
        return;
    }
    
    if (obj && [obj isKindOfClass:[NSString class]] && [(NSString *) obj isEqualToString:@"unblock"]) {
        [self triggerStandardUserChange:@selector(twitterStreamAPI:didUnblockUser:withFriendsCount:) withDict:dict];
        return;
    }
    
    // - the first thing the stream receives is the list of friends.
    obj = [dict objectForKey:@"friends_str"];
    if (obj && [obj isKindOfClass:[NSArray class]]) {
        NSArray *arr = (NSArray *) obj;
        if (delegate && [delegate respondsToSelector:@selector(twitterStreamAPI:didReceiveFriendsList:)]) {
            [delegate twitterStreamAPI:self didReceiveFriendsList:arr];
        }
        return;
    }
}
@end
