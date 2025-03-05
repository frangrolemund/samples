//
//  CS_twitterFeed_seal_history.h
//  ChatSeal
//
//  Created by Francis Grolemund on 8/4/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CS_twitterFeed_history_item.h"

@interface CS_twitterFeed_seal_history : NSObject <NSCoding>
-(void) addPostedTweetHistoryForSeal:(NSString *) sealId withTweet:(NSString *) tweetId andOwnerScreenName:(NSString *) screenName andAsSealOwner:(BOOL) isOwner;
-(void) addConsumerHistoryForSeal:(NSString *) sealId withTweet:(NSString *) tweetId andOwnerScreenName:(NSString *) screenName;
-(NSArray *) historyForSeal:(NSString *) sealId andOwnerScreenName:(NSString *) screenName;
-(CS_twitterFeed_history_item *) priorTweetFromOwnerOfSeal:(NSString *) sealId;
-(void) discardConsumerHistoryForSeal:(NSString *) sealId;
@end
