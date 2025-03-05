//
//  CS_tapi_statuses_show.h
//  ChatSeal
//
//  Created by Francis Grolemund on 3/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeedAPI.h"

@interface CS_tapi_statuses_show : CS_twitterFeedAPI
-(void) setTweetId:(NSString *) tweetId;
-(void) setTrimUser:(BOOL) trimUser;
-(void) setIncludeMyRetweet:(BOOL) includeRetweet;
-(void) setIncludeEntities:(BOOL) includeEntities;
@end
