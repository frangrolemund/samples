//
//  CS_tapi_parse_tweet_response.h
//  ChatSeal
//
//  Created by Francis Grolemund on 8/5/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CS_tapi_parse_tweet_response : NSObject
+(BOOL) isStandardStatusResponse:(NSObject *) obj;
-(BOOL) fillImageTweetFromObject:(NSObject *) obj;
@property (nonatomic, readonly) NSString *tweetId;
@property (nonatomic, readonly) NSURL    *imageURL;
@property (nonatomic, readonly) NSString *screenName;
@property (nonatomic, readonly) NSString *tweetText;
@end
