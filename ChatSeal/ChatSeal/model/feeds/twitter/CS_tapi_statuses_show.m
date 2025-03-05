//
//  CS_tapi_statuses_show.m
//  ChatSeal
//
//  Created by Francis Grolemund on 3/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tapi_statuses_show.h"
#import "ChatSeal.h"

//  THREADING-NOTES:
//  - These API object instances are consistent with the threading rules defined for CS_netFeedAPI and as such
//    do not require custom internal locking.

// - forward declarations
@interface CS_tapi_statuses_show (internal)
@end

/***************************
 CS_tapi_statuses_show
 REF: https://dev.twitter.com/docs/api/1.1/get/statuses/show/%3Aid
 ***************************/
@implementation CS_tapi_statuses_show
/*
 *  Object atrributes
 */
{
    NSString *parmTweetId;
    BOOL     parmTrimUser;
    BOOL     parmIncludeRetweet;
    BOOL     parmIncludeEntities;
}

/*
 *  Initialize the object.
 */
-(id) initWithCreatorHandle:(CS_netFeedCreatorDelegateHandle *)cdh inCategory:(cs_cnt_throttle_category_t)category
{
    self = [super initWithCreatorHandle:cdh inCategory:category];
    if (self) {
        parmTweetId         = nil;
        parmTrimUser        = NO;
        parmIncludeRetweet  = NO;
        parmIncludeEntities = YES;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [parmTweetId release];
    parmTweetId = nil;
    
    [super dealloc];
}

/*
 *  Return the service entrypoint.
 */
-(NSURL *) resourceURL
{
    return [NSURL URLWithString:@"https://api.twitter.com/1.1/statuses/show.json"];
}

/*
 *  (REQUIRED) Assign a Tweet id to this API.
 */
-(void) setTweetId:(NSString *) tweetId
{
    if (parmTweetId != tweetId) {
        [self clearActiveRequest];
        [parmTweetId release];
        parmTweetId = [tweetId retain];
    }
}

/*
 *  (OPTIONAL) When set to trim user, only a numerical author id is returned, not the entire user object.
 */
-(void) setTrimUser:(BOOL) trimUser
{
    if (parmTrimUser != trimUser) {
        [self clearActiveRequest];
        parmTrimUser = trimUser;
    }
}

/*
 *  (OPTIONAL) When set to include my retweet, an additional object is returned when retweeted by the authenticated user.
 */
-(void) setIncludeMyRetweet:(BOOL) includeRetweet
{
    if (parmIncludeRetweet != includeRetweet) {
        [self clearActiveRequest];
        parmIncludeRetweet = includeRetweet;
    }
}


/*
 *  (OPTIONAL) Indicate whether the entities node is included in the result.
 */
-(void) setIncludeEntities:(BOOL) includeEntities
{
    if (parmIncludeEntities != includeEntities) {
        [self clearActiveRequest];
        parmIncludeEntities = includeEntities;
    }
}

/*
 *  Use the supplied parameters to build a new request for the caller.
 */
-(NSURLRequest *) generateRequestWithError:(NSError **)err
{
    if (!parmTweetId) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];        
        [self alertLogForRequiredParameters];
        return nil;
    }
    
    NSMutableDictionary *mdParms = [NSMutableDictionary dictionary];
    
    if (parmTweetId) {
        [mdParms setObject:parmTweetId forKey:@"id"];
    }
    
    if (parmTrimUser) {
        [mdParms setObject:CS_TWITTERAPI_COMMON_TRUE forKey:@"trim_user"];
    }
    
    if (parmIncludeRetweet) {
        [mdParms setObject:CS_TWITTERAPI_COMMON_TRUE forKey:@"include_my_retweet"];
    }
    
    if (!parmIncludeRetweet) {
        [mdParms setObject:CS_TWITTERAPI_COMMON_FALSE forKey:@"include_entities"];
    }
    
    return [self generateTwitterRequestForMethod:CS_TWIT_RM_GET andParameters:mdParms];
}

@end


/**************************************
 CS_tapi_statuses_show (internal)
 **************************************/
@implementation CS_tapi_statuses_show (internal)

@end
