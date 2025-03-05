//
//  CS_twitterFeed_history_item.h
//  ChatSeal
//
//  Created by Francis Grolemund on 8/4/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CS_twitterFeed_history_item : NSObject <NSCoding>
+(CS_twitterFeed_history_item *) itemForTweet:(NSString *) tweetId andScreenName:(NSString *) screenName;
-(NSString *) tweetId;
-(NSString *) screenName;
@end
