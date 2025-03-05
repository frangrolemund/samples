//
//  CS_sessionManager.h
//  ChatSeal
//
//  Created by Francis Grolemund on 4/4/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CS_centralNetworkThrottle.h"
#import "CS_netFeedAPIRequest.h"

typedef enum {
    CS_SMSQ_LOW_VOLUME              = 0,            // intended to be low-volume in terms of returned content.
    CS_SMSQ_PERSISTENT              = 1,            // downloads/uploads go here to occur in the background to ensure success.
    CS_SMSQ_REALTIME_HIGH_VOLUME    = 2,            // only Wi-Fi connections are supported because the volume is so high for streaming.

    CS_SMSQ_COUNT
} ps_sm_session_quality_t;

@class CS_sessionManager;
@protocol CS_sessionManagerDelegate <NSObject>
-(void) sessionManager:(CS_sessionManager *) sessionManager didCompleteThrottledRequestForURL:(NSURL *) url inCategory:(cs_cnt_throttle_category_t) cat;
-(CS_netFeedAPIRequest *) sessionManager:(CS_sessionManager *) sessionManager needsRequestForExistingTask:(NSURLSessionTask *) task;
-(void) sessionManager:(CS_sessionManager *)sessionManager didReloadUploadURLs:(NSArray *) arrUploadURLs andDownloadURLs:(NSArray *) arrDownloadURLs;
-(void) sessionManagerRequestsHighPriorityUpdates:(CS_sessionManager *)sessionManager;
@end

@protocol ChatSealFeedImplementation;
@interface CS_sessionManager : NSObject
-(id) initWithSessionQuality:(ps_sm_session_quality_t) quality;
-(ps_sm_session_quality_t) quality;
-(BOOL) openWithError:(NSError **) err;
-(void) close;
-(BOOL) addRequest:(CS_netFeedAPIRequest *) request inCategory:(cs_cnt_throttle_category_t) category usingThrottle:(CS_centralNetworkThrottle *) throttle
                                          returningWasThrottled:(BOOL *) wasThottled withError:(NSError **) err;
-(void) processHighPriorityItems;
-(void) cancelAllRequestsForFeed:(ChatSealFeed *) feed;
-(BOOL) hasPendingRequests;

@property (nonatomic, assign) id<CS_sessionManagerDelegate> delegate;
@end
