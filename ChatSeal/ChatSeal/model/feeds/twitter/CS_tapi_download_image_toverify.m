//
//  CS_tapi_download_image_toverify.m
//  ChatSeal
//
//  Created by Francis Grolemund on 5/31/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tapi_download_image_toverify.h"
#import "ChatSeal.h"

//  THREADING-NOTES:
//  - although locking is generally not important for APIs, we must include it here
//    to appropriately handle the background notification which occurs on the main thread.


// - forward declarations
@interface CS_tapi_download_image_toverify (internal)
-(void) notifyDidMoveToBackground;
-(UIBackgroundTaskIdentifier) bti;
-(void) setBti:(UIBackgroundTaskIdentifier) nBTI;
-(void) haltAllBackgroundProcessing;
@end

/********************************
 CS_tapi_download_image_toverify
 ********************************/
@implementation CS_tapi_download_image_toverify
/*
 *  Object attributes.
 */
{
    BOOL                        isChecked;
    BOOL                        isConfirmed;           //  the requested items is _confirmed_ unknown and useful.
    BOOL                        isAnalyzedByFeed;
    UIBackgroundTaskIdentifier  bti;
}

/*
 *  Initialize the object.
 */
-(id) initWithCreatorHandle:(CS_netFeedCreatorDelegateHandle *)cdh inCategory:(cs_cnt_throttle_category_t)category
{
    self = [super initWithCreatorHandle:cdh inCategory:category];
    if (self) {
        isChecked        = NO;
        isConfirmed      = NO;
        isAnalyzedByFeed = NO;
        bti              = UIBackgroundTaskInvalid;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [self haltAllBackgroundProcessing];
    [super dealloc];
}

/*
 *  Return the category in the central throttle to allocate from.
 */
-(cs_cnt_throttle_category_t) centralThrottleCategory
{
    // - we want to compete for the same resources in the central throttle as
    //   any standard upload or download with these because this will
    //   take some time and bandwidth to complete.
    return CS_CNT_THROTTLE_DOWNLOAD;
}

/*
 *  Before we generate a request, make sure we mark ourselves as recipient of background notifications.
 */
-(NSURLRequest *) generateRequestWithError:(NSError **)err
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyDidMoveToBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    return [super generateRequestWithError:err];
}

/*
 *  This method is VERY important for the verification process because it is going to attempt to identify
 *  the owning seal as soon as possible.  When we fail to get verification, it gives us to the opportunity
 *  save on approximatly 98% of the network bandwidth by cancelling the pending request instead of waiting
 *  until the end.
 *  - return NO to cancel the request.
 */
-(void) didReceiveData:(NSData *) d fromSessionDataTask:(NSURLSessionTask *) task withExpectedTotal:(int64_t) totalToTransfer
{
    // - only save data for the message when it seems reasonable to use it.
    if (!isChecked || isConfirmed) {
        [super didReceiveData:d fromSessionDataTask:task withExpectedTotal:totalToTransfer];
    }
    
    // - once we get a good check, do no more work.
    if (isChecked) {
        return;
    }
    
    // - the quick identification is designed to only use the minimum amount of data to figure out if we can decode
    //   this message or if we had previously decoded it.  The idea is to stop downloading as quickly as possible
    //   when the message is not useful.
    NSData *dToTest                     = [self resultData];
    RSISecureMessageIdentification *smi = [RealSecureImage quickPackedContentIdentification:dToTest];
    if (smi.willNeverMatch || smi.message) {
        isChecked = YES;
        if (smi.willNeverMatch || !smi.message.sealId || (smi.message.hash && [ChatSeal isPackedMessageHashCurrentlyKnown:smi.message.hash])) {
            [self cancelPendingRequestForLackOfSeal:task];
        }
        else {
            // - the message is unknown and something we should acquire.
            isConfirmed = YES;
        }
    }
}

/*
 *  The confirmed flag indicates whether this item is both identified as something we can open and something that we should open.
 */
-(BOOL) isConfirmed
{
    return isConfirmed;
}

/*
 *  Returns whether the confirmation state has been analyzed or not.
 */
-(BOOL) hasBeenAnalyzed
{
    return isAnalyzedByFeed;
}

/*
 *  Mark this item as analyzed to minimize work done on it.
 */
-(void) markAsAnalyzed
{
    isAnalyzedByFeed = YES;
}

/*
 *  When the API is formally complete, ensure that any pending background work is done.
 */
-(void) completeAPIWithSessionTask:(NSURLSessionTask *)task andError:(NSError *)err
{
    [super completeAPIWithSessionTask:task andError:err];
    [self haltAllBackgroundProcessing];
}

@end

/********************************************
 CS_tapi_download_image_toverify (internal)
 ********************************************/
@implementation CS_tapi_download_image_toverify (internal)
/*
 *  Return the active background task identifier.
 */
-(UIBackgroundTaskIdentifier) bti
{
    @synchronized (self) {
        return bti;
    }
}

/*
 *  Assign the active background task identifier.
 */
-(void) setBti:(UIBackgroundTaskIdentifier) nBTI
{
    @synchronized (self) {
        if (nBTI != bti) {
            if (bti != UIBackgroundTaskInvalid) {
                [[UIApplication sharedApplication] endBackgroundTask:bti];
            }
            bti = nBTI;
        }
    }
}

/*
 *  One routine for stopping all background work.
 */
-(void) haltAllBackgroundProcessing
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.bti = UIBackgroundTaskInvalid;
}

/*
 *  The app is backgrounded so this is good time to start our keepalive processing.
 */
-(void) notifyDidMoveToBackground
{
    // - when we're about to move to the background, start a background task to keep this going just a bit longer.
    if (self.bti == UIBackgroundTaskInvalid) {
        self.bti = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"phs_transient_verify" expirationHandler:^(void) {
            self.bti = UIBackgroundTaskInvalid;
        }];
    }
}
@end
