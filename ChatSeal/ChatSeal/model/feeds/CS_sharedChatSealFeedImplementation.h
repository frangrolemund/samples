//
//  CS_sharedChatSealFeedImplementation.h
//  ChatSeal
//
//  Created by Francis Grolemund on 5/27/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

// - shared, internal declarations for external classes.
// ...to organize the required features for feed implementations.
@class CS_netFeedAPIRequest;
@protocol ChatSealFeedImplementation <NSObject>
-(BOOL) processFeedRequestsInThrottleCategory:(cs_cnt_throttle_category_t) category onlyAsHighPriority:(BOOL) onlyHighPrio;
-(BOOL) hasRequiredPendingActivity;
-(CS_netFeedAPIRequest *) canGenerateAPIRequestFromRequest:(NSURLRequest *) req;
-(CS_netFeedAPIRequest *) canApproximateAPIRequestFromOrphanedRequest:(NSURLRequest *) req;
-(void) close;
-(BOOL) isFeedServiceThrottledInCategory:(cs_cnt_throttle_category_t) category;
-(BOOL) hasHighPriorityWorkToPerform;
@optional
-(void) customConfigurationHasBeenLoaded:(NSDictionary *) dict;
-(NSDictionary *) customConfiguration;
-(void) configurePendingDownloadProgress;
-(BOOL) pipelineAuthenticateAPI:(CS_netFeedAPI *) api;
-(void) pipelineAPIWasScheduled:(CS_netFeedAPI *) api;
-(void) pipelineAPIProgress:(CS_netFeedAPI *) api;
-(void) pipelineDidCompleteAPI:(CS_netFeedAPI *) api;
-(void) addCustomUserContentForMessage:(NSMutableDictionary *) mdUserData packedWithSeal:(NSString *) sealId;
-(void) processCustomUserContentReceivedFromMessage:(NSDictionary *) dUserData packedWithSeal:(NSString *) sealId;
@end
