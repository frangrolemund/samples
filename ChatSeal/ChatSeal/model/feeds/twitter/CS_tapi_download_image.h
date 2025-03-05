//
//  CS_tapi_download_image.h
//  ChatSeal
//
//  Created by Francis Grolemund on 4/7/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeedAPI.h"

@interface CS_tapi_download_image : CS_twitterFeedAPI
-(void) setImageURL:(NSURL *) uImage forTweetId:(NSString *) tweetId;
-(void) cancelPendingRequestForLackOfSeal:(NSURLSessionTask *) task;
-(BOOL) isCancelledForLackingSeal;
-(NSString *) tweetId;
@end
