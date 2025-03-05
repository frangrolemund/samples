//
//  CS_preparingNetFeedAPIRequest.h
//  ChatSeal
//
//  Created by Francis Grolemund on 5/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_netFeedAPIRequest.h"
#import "CS_centralNetworkThrottle.h"

@class CS_centralNetworkThrottle;
@interface CS_preparingNetFeedAPIRequest : CS_netFeedAPIRequest
+(CS_preparingNetFeedAPIRequest *) prepareRequest:(CS_netFeedAPIRequest *) req inCategory:(cs_cnt_throttle_category_t) category usingThrottle:(CS_centralNetworkThrottle *) throttle;

-(void) setAbortedWithError:(NSError *) err;
@property (nonatomic, readonly) cs_cnt_throttle_category_t category;
@property (nonatomic, readonly) CS_centralNetworkThrottle *throttle;
@property (nonatomic, readonly) time_t                     creationTime;
@property (nonatomic, readonly) BOOL                       isAborted;
@property (nonatomic, assign)   BOOL                       isCompleted;
@end
