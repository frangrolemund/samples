//
//  CS_tapi_statuses_timeline_base.h
//  ChatSeal
//
//  Created by Francis Grolemund on 8/5/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeedAPI.h"
#import "CS_tapi_tweetRange.h"

typedef void (^CS_tapi_timeline_enumerationBlock)(NSString *tweetId, NSURL *url);

@interface CS_tapi_statuses_timeline_base : CS_twitterFeedAPI

-(void) setMaxCount:(NSUInteger) count;
-(void) setMaxTweetId:(NSString *) maxId;
-(NSString *) maxTweetId;
-(void) setSinceTweetId:(NSString *) sinceId;
-(NSString *) sinceTweetId;

-(NSMutableDictionary *) commonAttributes;
-(CS_tapi_tweetRange *) enumerateResultDataWithBlock:(CS_tapi_timeline_enumerationBlock) enumerationBlock;
@end
