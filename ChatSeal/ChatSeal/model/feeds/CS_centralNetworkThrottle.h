//
//  CS_centralNetworkThrottle.h
//  ChatSeal
//
//  Created by Francis Grolemund on 3/31/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

// - networking is divided into categories to provide different levels of control
//   to ensure that the available bandwidth is not over-consumed and the things that must
//   occur, do.
typedef enum {
    CS_CNT_THROTTLE_UPLOAD    = 0,      //  - we process these in category order and uploading (posting) messages must take precedence
    CS_CNT_THROTTLE_TRANSIENT = 1,
    CS_CNT_THROTTLE_DOWNLOAD  = 2,
    CS_CNT_THROTTLE_REALTIME  = 3,
    
    CS_CNT_THROTTLE_COUNT
} cs_cnt_throttle_category_t;

@interface CS_centralNetworkThrottle : NSObject
-(BOOL) openWithError:(NSError **) err;
-(void) assignInitialStatePendingUploadURLs:(NSArray *) arr;
-(void) assignInitialStatePendingDownloadURLs:(NSArray *) arr;
-(void) close;
-(void) setActiveThrottleCategory:(cs_cnt_throttle_category_t) cat;
-(cs_cnt_throttle_category_t) activeThrottleCategory;
-(BOOL) canStartPendingRequestInCategory:(cs_cnt_throttle_category_t) cat;
-(BOOL) canStartPendingRequestInCategory:(cs_cnt_throttle_category_t) cat andAllowNonActiveCategory:(BOOL) allowNonActive;
-(BOOL) startPendingURLRequest:(NSURL *) u inCategory:(cs_cnt_throttle_category_t) cat;
-(BOOL) startPendingURLRequest:(NSURL *) u inCategory:(cs_cnt_throttle_category_t) cat andAllowNonActiveCategory:(BOOL) allowNonActive;
-(void) completePendingURLRequest:(NSURL *) u inCategory:(cs_cnt_throttle_category_t) cat;
@end
