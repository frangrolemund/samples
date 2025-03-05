//
//  CS_tapi_statuses_timeline_base.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/5/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tapi_statuses_timeline_base.h"
#import "CS_tapi_parse_tweet_response.h"

//  THREADING-NOTES:
//  - These API object instances are consistent with the threading rules defined for CS_netFeedAPI and as such
//    do not require custom internal locking.

/***********************************
 CS_tapi_statuses_timeline_base
 REF: https://api.twitter.com/1.1/statuses/home_timeline.json
 ***********************************/
@implementation CS_tapi_statuses_timeline_base
/*
 *  Object attributes.
 */
{
    NSUInteger  maxCount;
    NSString    *maxTweetId;
    NSString    *sinceTweetId;
}

/*
 *  Initialize the object.
 */
-(id) initWithCreatorHandle:(CS_netFeedCreatorDelegateHandle *)cdh inCategory:(cs_cnt_throttle_category_t)category
{
    self = [super initWithCreatorHandle:cdh inCategory:category];
    if (self) {
        maxCount     = 0;
        maxTweetId   = nil;
        sinceTweetId = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [maxTweetId release];
    maxTweetId = nil;
    
    [sinceTweetId release];
    sinceTweetId = nil;
    
    [super dealloc];
}

/*
 *  Assign the max count.
 */
-(void) setMaxCount:(NSUInteger) count
{
    maxCount = count;
}

/*
 *  Assign the max tweet to retrieve.
 */
-(void) setMaxTweetId:(NSString *) maxId
{
    if (maxId != maxTweetId) {
        [maxTweetId release];
        maxTweetId = [maxId retain];
    }
}

/*
 *  Return the maximum id requested in the API.
 */
-(NSString *) maxTweetId
{
    return [[maxTweetId retain] autorelease];
}

/*
 *  Assign the lowest tweet to retrieve.
 */
-(void) setSinceTweetId:(NSString *) sinceId
{
    if (sinceId != sinceTweetId) {
        [sinceTweetId release];
        sinceTweetId = [sinceId retain];
    }
}

/*
 *  Return the since-id requested by the API.
 */
-(NSString *) sinceTweetId
{
    return [[sinceTweetId retain] autorelease];
}

/*
 *  Build a dictionary of the attributes common to all these timeline APIs.
 */
-(NSMutableDictionary *) commonAttributes
{
    NSMutableDictionary *mdCommon = [NSMutableDictionary dictionary];
    
    if (maxCount) {
        [mdCommon setObject:[NSString stringWithFormat:@"%lu", (unsigned long) maxCount] forKey:@"count"];
    }
    
    if (sinceTweetId) {
        [mdCommon setObject:sinceTweetId forKey:@"since_id"];
    }
    
    if (maxTweetId) {
        [mdCommon setObject:maxTweetId forKey:@"max_id"];
    }

    // - these items are always the same.
    // - NOTE: we always trim the user because it adds a lot of extra redundant data to these queries and
    //         it has minimal use as a filter anyway because we don't know which Twitter accounts our friends
    //         might use and it only serves a purpose when filtering things we posted, and even that is a fairly
    //         minor test.
    [mdCommon setObject:CS_TWITTERAPI_COMMON_TRUE forKey:@"trim_user"];
    [mdCommon setObject:CS_TWITTERAPI_COMMON_FALSE forKey:@"exclude_replies"];
    [mdCommon setObject:CS_TWITTERAPI_COMMON_FALSE forKey:@"contributor_details"];
    [mdCommon setObject:CS_TWITTERAPI_COMMON_TRUE  forKey:@"include_entities"];
    
    return mdCommon;
}

/*
 *  Return a customized description.
 */
-(NSString *) description
{
    return [NSString stringWithFormat:@"%@ (%@ --> %@)", [super description], [self sinceTweetId], [self maxTweetId]];
}

/*
 *  Use the result data and enumerate all the entities.
 *  - return the range of tweets that were processed, whether or not any were used.
 *  - when nothing was found, a range with no values is returned.
 */
-(CS_tapi_tweetRange *) enumerateResultDataWithBlock:(CS_tapi_timeline_enumerationBlock) enumerationBlock
{
    if (![self isAPISuccessful]) {
        return nil;
    }
    
    NSObject *obj = [self resultDataConvertedFromJSON];
    if (!obj || ![obj isKindOfClass:[NSArray class]]) {
        return nil;
    }
    
    
    // - parse through the tweets in this timeline.
    CS_tapi_parse_tweet_response *ptr   = nil;
    CS_tapi_tweetRange           *ret   = [CS_tapi_tweetRange emptyRange];
    NSArray *arrTweets                  = (NSArray *) obj;
    NSUInteger count                    = 0;
    for (obj in arrTweets) {
        if (![obj isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        
        if (!ptr) {
            ptr = [[[CS_tapi_parse_tweet_response alloc] init] autorelease];
        }
        
        if ([ptr fillImageTweetFromObject:obj]) {
            // - the user-id is never used here because for these types of queries, the user data adds
            //   considerable cost to the result set and I can get by with out the information.
            if (enumerationBlock) {
                enumerationBlock(ptr.tweetId, ptr.imageURL);
            }
        }
        
        // - succeed or fail, the tweet id will be populated if it exists and the first one
        //   will suffice because we're always given them in sorted order.
        if (ptr.tweetId && !ret.maxTweetId) {
            ret.maxTweetId = ptr.tweetId;
        }
        
        // - the minimum will just be the last one.
        ret.minTweetId = ptr.tweetId;
        count++;
    }
    
    return ret;
}

@end
