//
//  CS_tapi_statuses_update_with_media.h
//  ChatSeal
//
//  Created by Francis Grolemund on 5/19/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeedAPI.h"

@interface CS_tapi_statuses_update_with_media : CS_twitterFeedAPI
-(BOOL) setPostAsSafeEntry:(NSString *) seid withImagePNGData:(NSData *) dToPost andTweetText:(NSString *) text;
-(BOOL) markAsReplyToTweet:(NSString *) origTweetId fromUser:(NSString *) screenName;

-(NSString *) safeEntryId;
-(BOOL) isOverDailyUploadLimit;
-(NSString *) postedTweetId;
-(NSUInteger) mediaRateLimitRemaining;
-(time_t) mediaRateLimitResetTime;
@end
