//
//  CS_tapi_download_image.m
//  ChatSeal
//
//  Created by Francis Grolemund on 4/7/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tapi_download_image.h"
#import "CS_feedShared.h"

//  THREADING-NOTES:
//  - These API object instances are consistent with the threading rules defined for CS_netFeedAPI and as such
//    do not require custom internal locking.

// - constants
static NSString *CS_TAPI_DI_FORCE_LARGEST  = @":large";
static NSString *CS_TAPI_DI_TWEETID_HEADER = @"X-tid";

// - forward declarations
@interface CS_tapi_download_image (internal)
@end

/**************************
 CS_tapi_download_image
 **************************/
@implementation CS_tapi_download_image
/*
 *  Object attributes
 */
{
    NSString *sTweetId;
    NSURL    *uBaseImage;
    BOOL     wasCancelledWithNoSeal;
}

/*
 *  Initialize the object.
 */
-(id) initWithCreatorHandle:(CS_netFeedCreatorDelegateHandle *)cdh inCategory:(cs_cnt_throttle_category_t)category
{
    self = [super initWithCreatorHandle:cdh inCategory:category];
    if (self) {
        sTweetId               = nil;
        uBaseImage             = nil;
        wasCancelledWithNoSeal = NO;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [sTweetId release];
    sTweetId = nil;
    
    [uBaseImage release];
    uBaseImage = nil;
    
    [super dealloc];
}

/*
 *  When background APIs are reconfigured, ensure we have a valid tweet id available for
 *  post-processing.
 */
-(void) configureWithExistingRequest:(NSURLRequest *)req
{
    if (!sTweetId) {
        sTweetId = [[req.allHTTPHeaderFields objectForKey:CS_TAPI_DI_TWEETID_HEADER] retain];
    }
}


/*
 *  Return the service entrypoint.
 */
-(NSURL *) resourceURL
{
    // - since downloads actually can continue after the app exits and restarts,
    //   we cannot assume they will be configured with a URL image string initially.
    if ([self hasActiveRequest]) {
        NSURLRequest *req = [self requestWithError:nil];
        return req.URL;
    }
    else {
        if (!uBaseImage) {
            return nil;
        }
        
        // - we must ensure that only the largest image is used because it will have all the necessary image data.
        return [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [uBaseImage absoluteString], CS_TAPI_DI_FORCE_LARGEST]];
    }
}

/*
 *  Because this is an intended background API that can be restarted, this API is used to recreate it when the task
 *  is completed after an app restart.
 */
-(BOOL) matchesRequest:(NSURLRequest *)req
{
    NSURL *u       = req.URL;
    NSString *sURL = [u absoluteString];
    NSRange r      = [sURL rangeOfString:CS_TAPI_DI_FORCE_LARGEST];
    if (r.location == NSNotFound) {
        return NO;
    }
    return [CS_feedTypeTwitter isValidTwitterHost:u.host];
}

/*
 *  Any image download task requires the URL string to be specified first.
 */
-(void) setImageURL:(NSURL *) uImage forTweetId:(NSString *) tweetId
{
    if (uBaseImage != uImage) {
        [self clearActiveRequest];
        [uBaseImage release];
        uBaseImage = [uImage retain];
    }
    
    if (sTweetId != tweetId) {
        [self clearActiveRequest];
        [sTweetId release];
        sTweetId = [tweetId retain];
    }
}

/*
 *  This is intentionally very simple, we just need the integration with the Twitter
 *  authorization.
 */
-(NSURLRequest *) generateRequestWithError:(NSError **)err
{
    NSURLRequest *req = [self generateTwitterRequestForMethod:CS_TWIT_RM_GET andParameters:nil];
    
    // - we always append the tweet id to the header to ensure we
    //   can find this again after a restart.
    NSMutableURLRequest *mur = (NSMutableURLRequest *) [[req mutableCopy] autorelease];
    if (sTweetId) {
        [mur addValue:sTweetId forHTTPHeaderField:CS_TAPI_DI_TWEETID_HEADER];
    }
    
    // - return the updated item.
    return mur;
}

/*
 *  Mark this API as having been cancelled.
 */
-(void) cancelPendingRequestForLackOfSeal:(NSURLSessionTask *) task
{
    [task cancel];
    wasCancelledWithNoSeal = YES;
}

/*
 *  Indicates whether this API was cancelled.
 */
-(BOOL) isCancelledForLackingSeal
{
    return wasCancelledWithNoSeal;
}

/*
 *  Don't return partial results when the API was cancelled.
 */
-(NSData *) resultData
{
    if (![self isCancelledForLackingSeal]) {
        return [super resultData];
    }
    return nil;
}

/*
 *  Return the tweet id for this request.
 */
-(NSString *) tweetId
{
    return [[sTweetId retain] autorelease];
}

/*
 *  This API should never get our feed flagged as expired because a not-authorized could occur if
 *  the other guy is protected and we cannot reach him.
 */
-(BOOL) shouldNotAuthorizedBeInterpretedAsPasswordFailure
{
    // - while it is very possible a password failure will cause this also, we can't distinguish between the
    //   two so we'll have to wait for one of our own to fail to be sure about it.
    return NO;
}
@end

/************************************
 CS_tapi_download_image (internal)
 ************************************/
@implementation CS_tapi_download_image (internal)

@end