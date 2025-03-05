//
//  CS_netFeedAPI.h
//  ChatSeal
//
//  Created by Francis Grolemund on 3/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CS_centralNetworkThrottle.h"

// - the net feed API hierarchy is designed so that you can request them in a bunch of places
//   in the code without worrying about whether they will be properly accounted-for when they
//   are no longer necessary.   The creator handle is only useful to the factory, so it can be
//   generally ignored.
// - this is of course important because the whole point of throttling is to accurately track
//   activity.
// - NOTE: an *important* detail about these APIs is that we never explicitly retain/persist them because of the
//   risk of getting out of synch with the session handling them.  If that were to occur, it is very real
//   possibility that our ability to track them to completion through the throttling process would get out
//   of synch!  The model should be that a single feed track what it needs and then sends out one or more APIs
//   that contribute data.   You can save the data, just not the temporary existence of the API collecting it.
@class CS_netFeedAPI;
@protocol CS_netFeedCreatorDelegateAPI <NSObject>
-(void) willDeallocateAPI:(CS_netFeedAPI *) nfa;
@end
@interface CS_netFeedCreatorDelegateHandle : NSObject
-(id) initWithCreatorDelegate:(id<CS_netFeedCreatorDelegateAPI>) creatorDelegate;
-(void) stopAllDelegateNotifications;
@end

@protocol CS_netFeedAPISessionDelegate <NSObject>
-(void) preparationIsCompletedInAPI:(CS_netFeedAPI *) api;
@end

@class ChatSealFeed;
typedef void (^CS_netFeedAPICompletionBlock)(CS_netFeedAPI *api, ChatSealFeed *feed);

// - the ancestor for every API.
@interface CS_netFeedAPI : NSObject
@property (nonatomic, assign) id<CS_netFeedAPISessionDelegate> sessionDelegate;
-(id) initWithCreatorHandle:(CS_netFeedCreatorDelegateHandle *) cdh inCategory:(cs_cnt_throttle_category_t) category;
-(void) unthrottleAPI;
-(BOOL) hasActiveRequest;
-(NSURLRequest *) requestWithError:(NSError **) err;
-(cs_cnt_throttle_category_t) throttleCategory;
-(cs_cnt_throttle_category_t) centralThrottleCategory;
-(void) clearActiveRequest;
-(void) alertLogForRequiredParameters;
-(void) alertLogResultSetInconsistency;
-(void) setActiveRequest:(NSURLRequest *) req;
-(void) didReceiveData:(NSData *) d fromSessionDataTask:(NSURLSessionTask *) task withExpectedTotal:(int64_t) totalToTransfer;
-(void) completeAPIWithSessionTask:(NSURLSessionTask *) task andError:(NSError *) err;
-(void) markAPIAsAbortedWithError:(NSError *) err;
-(void) setRequestLocked;
-(void) setTotalBytesToRecv:(int64_t) toRecv;
-(void) setNumBytesRecv:(int64_t) numRecv;
-(void) setTotalBytesToSend:(int64_t) toSend;
-(void) setNumBytesSent:(int64_t) numSent;
-(void) setDownloadResultURL:(NSURL *) url;
-(void) configureWithExistingRequest:(NSURLRequest *) req;
-(void) setCustomCompletionBlock:(CS_netFeedAPICompletionBlock) completionBlock;

// - these are useful when getting the result from the API
-(NSData *) resultData;
-(id) resultDataConvertedFromJSON;
-(id) convertDataFromJSON:(NSData *) d;
-(BOOL) isAPISuccessful;
-(NSError *) networkCompletionErrorCode;
-(int64_t) bytesRecv;
-(int64_t) totalBytesToRecv;
-(int64_t) bytesSent;
-(int64_t) totalBytesToSend;
-(NSURL *) downloadResultURL;
-(void) notifyPreparationCompleted;

// - implement these sub-items.
-(NSURLRequest *) generateRequestWithError:(NSError **) err;
-(BOOL) matchesRequest:(NSURLRequest *) req;
-(NSString *) requestId;
-(BOOL) prepareToGenerateRequest;
-(BOOL) isPreparedToGenerateRequest;
-(void) abortRequestPreparation;
@end
