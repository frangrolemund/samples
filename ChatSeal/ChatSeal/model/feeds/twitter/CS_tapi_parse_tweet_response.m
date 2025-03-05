//
//  CS_tapi_parse_tweet_response.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/5/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tapi_parse_tweet_response.h"
#import "CS_twitterFeedAPI.h"
#import "CS_twitterFeed_tweetText.h"

@implementation CS_tapi_parse_tweet_response
/*
 *  Object attributes
 */
{
}
@synthesize tweetId;
@synthesize imageURL;
@synthesize screenName;
@synthesize tweetText;

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        tweetId    = nil;
        imageURL   = nil;
        screenName = nil;
        tweetText  = nil;
    }
    return self;
}

/*
 *  Just release everything.
 */
-(void) reset
{
    [tweetId release];
    tweetId = nil;
    
    [imageURL release];
    imageURL = nil;
    
    [screenName release];
    screenName = nil;
    
    [tweetText release];
    tweetText = nil;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [self reset];
    [super dealloc];
}

/*
 *  Identifies whether the object likely represents a tweet status.
 */
+(BOOL) isStandardStatusResponse:(NSObject *) obj
{
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *) obj;
        if ([dict objectForKey:@"id_str"] &&
            [dict objectForKey:@"entities"] &&
            [dict objectForKey:@"text"]) {
            return YES;
        }
    }
    return NO;
}

/*
 *  This method specifically checks for a ChatSeal-compatible image tweet.
 */
-(BOOL) fillImageTweetFromObject:(NSObject *) obj;
{
    if (![obj isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    
    [self reset];
    
    NSDictionary *dict = (NSDictionary *) obj;
    obj            = [dict objectForKey:@"id_str"];
    NSObject *obj2 = [dict objectForKey:@"entities"];
    NSObject *text = [dict objectForKey:@"text"];
    if (obj && obj2 && text &&
        [obj isKindOfClass:[NSString class]] && [obj2 isKindOfClass:[NSDictionary class]] && [text isKindOfClass:[NSString class]]) {
        tweetId   = [(NSString *) obj retain];
        tweetText = [(NSString *) text retain];
        obj = [(NSDictionary *) obj2 objectForKey:@"media"];
        if (obj && [obj isKindOfClass:[NSArray class]]) {
            obj = [(NSArray *) obj lastObject];
            if ([obj isKindOfClass:[NSDictionary class]]) {
                obj2           = [(NSDictionary *) obj objectForKey:@"type"];
                NSObject *obj3 = [(NSDictionary *) obj objectForKey:@"media_url"];
                if (obj2 && obj3 &&
                    [obj2 isKindOfClass:[NSString class]] && [(NSString *) obj2 isEqualToString:@"photo"] &&
                    [obj3 isKindOfClass:[NSString class]]) {
                    
                    // - try to pull the id of the user who issued the tweet.
                    obj2             = [dict objectForKey:@"user"];
                    NSObject *id_str = nil;
                    if (obj2 && [obj2 isKindOfClass:[NSDictionary class]]) {
                        id_str     = [(NSDictionary *) obj2 objectForKey:@"id_str"];
                        screenName = [[(NSDictionary *) obj2 objectForKey:@"screen_name"] retain];
                    }
                    
                    // - if we see text in the tweet that suggests it could have been composed by this person with a seal we have
                    //   in common and the image appears valid, continue.
                    if ([id_str isKindOfClass:[NSString class]] &&
                        [CS_twitterFeed_tweetText isTweetWithText:tweetText possibilyUsefulFromNumericUserId:(NSString *) id_str] &&
                        [CS_twitterFeedAPI isChatSealValidImageURLString:(NSString *) obj3]) {
                        imageURL = [[NSURL URLWithString:(NSString *) obj3] retain];
                        return YES;
                    }
                }
            }
        }
    }
    return NO;
}

@end
