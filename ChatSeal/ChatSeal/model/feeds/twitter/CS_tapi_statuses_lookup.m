//
//  CS_tapi_statuses_lookup.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/19/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tapi_statuses_lookup.h"
#import "ChatSeal.h"
#import "CS_tapi_parse_tweet_response.h"

//  THREADING-NOTES:
//  - These API object instances are consistent with the threading rules defined for CS_netFeedAPI and as such
//    do not require custom internal locking.

/******************************
 CS_tapi_statuses_lookup
 REF: https://dev.twitter.com/docs/api/1.1/get/statuses/lookup
 ******************************/
@implementation CS_tapi_statuses_lookup
/*
 *  Object atrributes
 */
{
    NSMutableArray *parmToRetrieve;
}

/*
 *  Return the maximum number we can retrieve at a time.
 */
+(NSUInteger) maxStatusesPerRequest
{
    return 100;             // from the docs.
}

/*
 *  Initialize the object.
 */
-(id) initWithCreatorHandle:(CS_netFeedCreatorDelegateHandle *)cdh inCategory:(cs_cnt_throttle_category_t)category
{
    self = [super initWithCreatorHandle:cdh inCategory:category];
    if (self) {
        parmToRetrieve      = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [parmToRetrieve release];
    parmToRetrieve = nil;
    
    [super dealloc];
}

/*
 *  Return the service entrypoint.
 */
-(NSURL *) resourceURL
{
    return [NSURL URLWithString:@"https://api.twitter.com/1.1/statuses/lookup.json"];
}

/*
 *  (REQUIRED) Assign the list of tweet ids to this object.
 */
-(BOOL) setTweetIds:(NSArray *) tids
{
    [parmToRetrieve release];
    parmToRetrieve = nil;
    if (tids) {
        parmToRetrieve = [[NSMutableArray alloc] initWithArray:tids];
    }
    return (parmToRetrieve ? YES : NO);
}

/*
 *  Return the list of tweets we're processing.
 */
-(NSArray *) tweetIds
{
    return [[parmToRetrieve retain] autorelease];
}

/*
 *  Use the supplied parameters to build a new request for the caller.
 */
-(NSURLRequest *) generateRequestWithError:(NSError **)err
{
    if (![parmToRetrieve count]) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        [self alertLogForRequiredParameters];
        return nil;
    }
    
    // - this call is designed for tweet validation, which will work just like the timeline mining
    //   APIs.
    // - we aren't trimming the user in these lookups because they should be fairly infrequent and the user
    //   information will be important for allowing us to manage connectivity with friends.
    NSMutableDictionary *mdParms = [NSMutableDictionary dictionary];
    [mdParms setObject:[parmToRetrieve componentsJoinedByString:@","] forKey:@"id"];
    [mdParms setObject:CS_TWITTERAPI_COMMON_FALSE forKey:@"trim_user"];
    [mdParms setObject:CS_TWITTERAPI_COMMON_TRUE forKey:@"include_entities"];
    [mdParms setObject:CS_TWITTERAPI_COMMON_FALSE forKey:@"map"];
    return [self generateTwitterRequestForMethod:CS_TWIT_RM_GET andParameters:mdParms];
}

/*
 *  Enumerate the response for statuses.
 */
-(void) enumerateResultDataWithBlock:(CS_tapi_statuses_enumerationBlock) enumerationBlock
{
    if (!enumerationBlock || ![self isAPISuccessful]) {
        return;
    }
    
    // - parse through the tweets in this payload, returning the tweet and the image URL if it exists.
    CS_tapi_parse_tweet_response *ptr   = nil;
    NSArray *arrTweets                  = nil;
    NSObject *obj = [self resultDataConvertedFromJSON];
    if ([obj isKindOfClass:[NSArray class]]) {
        arrTweets = (NSArray *) obj;
    }
    else if ([obj isKindOfClass:[NSDictionary class]]) {
        // - sort of a weird organization, but whatever.
        obj = [(NSDictionary *) obj objectForKey:@"id"];
        if (obj && [obj isKindOfClass:[NSDictionary class]]) {
            arrTweets = [(NSDictionary *) obj allValues];
        }
    }

    for (obj in arrTweets) {
        if (![obj isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        
        if (!ptr) {
            ptr = [[[CS_tapi_parse_tweet_response alloc] init] autorelease];
        }
        
        // - it is fine if we get one that just can't be parsed.
        [ptr fillImageTweetFromObject:obj];
        if (ptr.tweetId) {
            [parmToRetrieve removeObject:ptr.tweetId];
            enumerationBlock(ptr.tweetId, ptr.screenName, ptr.imageURL);
        }
    }
    
    // - enumerate any that remain and weren't returned.
    for (NSString *remain in parmToRetrieve) {
        enumerationBlock(remain, nil, nil);
    }
}
@end
