//
//  CS_tapi_statuses_lookup.h
//  ChatSeal
//
//  Created by Francis Grolemund on 8/19/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeedAPI.h"

typedef void (^CS_tapi_statuses_enumerationBlock)(NSString *tweetId, NSString *screenName, NSURL *url);

@interface CS_tapi_statuses_lookup : CS_twitterFeedAPI
+(NSUInteger) maxStatusesPerRequest;
-(BOOL) setTweetIds:(NSArray *) tids;
-(NSArray *) tweetIds;
-(void) enumerateResultDataWithBlock:(CS_tapi_statuses_enumerationBlock) enumerationBlock;
@end
