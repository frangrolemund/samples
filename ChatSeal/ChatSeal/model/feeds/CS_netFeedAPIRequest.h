//
//  CS_netFeedAPIRequest.h
//  ChatSeal
//
//  Created by Francis Grolemund on 5/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ChatSealFeed;
@class CS_netFeedAPI;
@interface CS_netFeedAPIRequest : NSObject
-(id) initWithFeed:(ChatSealFeed *) initFeed andAPI:(CS_netFeedAPI *) initAPI;
+(CS_netFeedAPIRequest *) requestForFeed:(ChatSealFeed *) feed andAPI:(CS_netFeedAPI *) api;
@property (nonatomic, readonly) ChatSealFeed   *feed;
@property (nonatomic, readonly) CS_netFeedAPI  *api;
@property (nonatomic, readonly) BOOL           needsPreparation;
@property (nonatomic, retain) NSURLSessionTask *task;
@end
