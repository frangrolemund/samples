//
//  CS_sharedChatSealFeedType.h
//  ChatSeal
//
//  Created by Francis Grolemund on 5/27/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

// ...for connnecting the type to the collector.
@protocol ChatSealFeedTypeDelegate <NSObject>
-(ChatSealFeedCollector *) collectorForFeedType:(ChatSealFeedType *) ft;
@end

// ...interact internally with the type.
@class CS_netFeedAPIRequest;
@interface ChatSealFeedType (shared) <ChatSealFeedTypeDelegate, ChatSealFeedDelegate>
+(BOOL) isThrottleCategorySupportedForProcessing:(cs_cnt_throttle_category_t) cat;
-(id) initWithDelegate:(id<ChatSealFeedTypeDelegate>) d;
-(void) setDelegate:(id<ChatSealFeedTypeDelegate>) delegate;
-(CS_netFeedAPIRequest *) canGenerateAPIRequestFromRequest:(NSURLRequest *) req;
-(void) close;
-(BOOL) areFeedsNetworkReachable;
-(NSString *) networkReachabilityError;
-(void) updateLastRefresh;
@end
