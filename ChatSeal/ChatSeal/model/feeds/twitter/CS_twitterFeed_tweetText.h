//
//  CS_twitterFeed_tweetText.h
//  ChatSeal
//
//  Created by Francis Grolemund on 8/7/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CS_twitterFeed_tweetText : NSObject
+(NSString *) tweetTextForSealId:(NSString *) sid andNumericUserId:(NSString *) id_str;
+(BOOL) isTweetWithText:(NSString *) tweetText possibilyUsefulFromNumericUserId:(NSString *) id_str;
@end
