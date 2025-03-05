//
//  CS_sharedChatSealFeedTypeImplementation.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/7/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CS_centralNetworkThrottle.h"

@protocol CS_sharedChatSealFeedTypeImplementation <NSObject>
@optional
-(BOOL) hasHighPriorityWorkToPerform;
-(BOOL) processFeedTypeRequestsInThrottleCategory:(cs_cnt_throttle_category_t) category usingFeed:(ChatSealFeed *) feed;        //  return YES if processing could be completed with the feed.
-(void) processReceivedFeedLocations:(NSArray *) locs;
-(void) vaultSealStateHasBeenUpdated;
@end
