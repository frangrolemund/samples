//
//  ChatSealDebug.h
//  ChatSeal
//
//  Created by Francis Grolemund on 5/2/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

//#define CHATSEAL_DEBUGGING_ROUTINES 1
//#ifdef CHATSEAL_DEBUGGING_ROUTINES
////    #define CHATSEAL_DEBUG_LOG_TAB 1
////    #define CHATSEAL_DEBUG_TWITTER_API_FREQ 1
////    #ifdef CHATSEAL_DEBUG_TWITTER_API_FREQ
////        #define CHATSEAL_DEBUG_DORMANT_NOTIFY 1
////    #endif
////    #define CHATSEAL_DEBUG_DISPLAY_LAUNCH_GENERATOR 1
////    #define CHATSEAL_DEBUG_DONT_POST_MESSAGES 1
////    #define CHATSEAL_GENERATE_APP_PALETTE_IMG 1
////    #define CHATSEAL_RUNNING_CONTRIVED_SCENARIO 1
//#endif

@class ChatSealMessage;
@interface ChatSealDebug : NSObject
+(void) reportStatus;
+(BOOL) saveImage:(UIImage *) image withBaseName:(NSString *) base;
+(void) appendRandomContentToMessage:(ChatSealMessage *) psm withNumberOfItems:(NSUInteger) numItems;
+(void) destructivelyVerifyMessagingInfrastructure;
+(void) beginBasicNetworkingTesting;
+(void) beginSealExchangeTesting;
+(void) beginFeedThrottleTesting;
+(void) beginTweetTrackingTesting;
+(void) beginTwitterMiningHistoryTesting;
+(void) beginTweetTextTesting;
+(void) buildScreenshotScenario;
@end
