//
//  CS_netFeedAPI.m
//  ChatSeal
//
//  Created by Francis Grolemund on 3/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_netFeedAPI.h"
#import "ChatSeal.h"

//  THREADING-NOTES:
//  - These API object instances must never be retained and only used when provided in a pipeline callback.  The reason
//    is to try to ensure they are only ever used on a single thread at a time and require no locking internally.
//  - The creator delegate handle that each API receives does include locking because the same creator (CS_netThrottledAPIFactory)
//    will be used for every API that it manufactures and that factory can be accessed on many different threads.   

// - constants
static const NSUInteger CS_NF_MAX_JSON_SOURCE = 1024*512;

// - forward declarations
@interface CS_netFeedAPI (shared)
-(void) issueCustomCompletionForFeed:(ChatSealFeed *) feed;
@end

@interface CS_netFeedCreatorDelegateHandle (internal)
-(void) notifyDelegateOfDeallocationForAPI:(CS_netFeedAPI *) api;
@end


/*****************
 CS_netFeedAPI
 ******************/
@implementation CS_netFeedAPI
/*
 *  Object attributes.
 */
{
    CS_netFeedCreatorDelegateHandle *delHandle;
    cs_cnt_throttle_category_t       throttleCategory;
    NSURLRequest                     *request;
    NSMutableData                    *mdReturnData;
    NSError                          *errCompletion;
    BOOL                             requestLocked;
    int64_t                          totalBytesToRecv;
    int64_t                          numBytesRecv;
    int64_t                          totalBytesToSend;
    int64_t                          numBytesSent;
    NSURL                            *uDownloadedResult;
    CS_netFeedAPICompletionBlock     completionBlock;
}
@synthesize sessionDelegate;

/*
 *  Initialize the object.
 */
-(id) initWithCreatorHandle:(CS_netFeedCreatorDelegateHandle *) cdh inCategory:(cs_cnt_throttle_category_t) category
{
    self = [super init];
    if (self) {
        // - the purpose in having a container for the delegate is so that
        //   both the real delegate and this object can avoid a retain loop
        //   that would prevent deallocation of this object.
        delHandle            = [cdh retain];
        throttleCategory     = category;
        request              = nil;
        mdReturnData         = nil;
        errCompletion        = nil;
        requestLocked        = NO;
        totalBytesToRecv     = -1;
        numBytesRecv         = 0;
        totalBytesToSend     = -1;
        numBytesSent         = 0;
        uDownloadedResult    = nil;
        sessionDelegate      = nil;
        completionBlock      = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    sessionDelegate = nil;
    [self setCustomCompletionBlock:nil];
    
    [self unthrottleAPI];
    [request release];
    request = nil;
    
    [mdReturnData release];
    mdReturnData = nil;
    
    [errCompletion release];
    errCompletion = nil;
    
    [uDownloadedResult release];
    uDownloadedResult = nil;
    
    [super dealloc];
}

/*
 *  Explicitly disconnect from the throttle.
 */
-(void) unthrottleAPI
{
    @synchronized (self) {
        [delHandle notifyDelegateOfDeallocationForAPI:self];
        [delHandle release];
        delHandle = nil;
    }
}

/*
 *  Determine if this API has generated an active request yet.
 */
-(BOOL) hasActiveRequest
{
    if (request) {
        return YES;
    }
    return NO;
}

/*
 *  The generated request for the API.
 */
-(NSURLRequest *) requestWithError:(NSError **) err
{
    if (!request) {
        request = [[self generateRequestWithError:err] retain];
        if (!request) {
            return nil;
        }
    }
    return [[request retain] autorelease];
}

/*
 *  Erase the cached request object.
 */
-(void) clearActiveRequest
{
    if (requestLocked) {
        return;
    }
    [request release];
    request = nil;
}

/*
 *  Return the throttling category for this API, which should have been set as it was created.
 */
-(cs_cnt_throttle_category_t) throttleCategory
{
    return throttleCategory;
}

/*
 *  It is possible to have an API get assigned to a different category in the central throttle alone, which
 *  allows it to use a different bucket allocation.  This is generally not something you want to do, but
 *  can be useful, in particular with requests that should be more carefully throttled like transient ones
 *  that should be treated as download tasks.
 */
-(cs_cnt_throttle_category_t) centralThrottleCategory
{
    return [self throttleCategory];
}

/*
 *  Every API must implement this method to return a valid request for collection.
 */
-(NSURLRequest *) generateRequestWithError:(NSError **) err
{
    [CS_error fillError:err withCode:CSErrorInvalidArgument];
    return nil;
}

/*
 *  This generic API will fire a message to help down track down invalid parameters for an API.
 */
-(void) alertLogForRequiredParameters
{
    NSLog(@"CS-ALERT: NET-API request %@ is missing required parameters.", [[self class] description]);
}

/*
 *  This generic API will fire a message when the result set of a given API is inconsistent with expecations.
 */
-(void) alertLogResultSetInconsistency
{
    NSLog(@"CS-ALERT: NET-API response %@ is inconsistent with expectations.", [[self class] description]);
}

/*
 *  Subclasses can use this method to determine if this API could have generated the provided request, but
 *  that is very dependent on the type of API so it is not handled here.
 */
-(BOOL) matchesRequest:(NSURLRequest *) req
{
    return NO;
}

/*
 *  Save off a request that was generated elsewhere.
 */
-(void) setActiveRequest:(NSURLRequest *) req
{
    if (!requestLocked && request != req) {
        [request release];
        request = [req retain];
    }
}

/*
 *  When the session data task notifies us that we have data, we need to add it
 *  to our running content.
 *  - return a NO from this method to cancel the request.
 */
-(void) didReceiveData:(NSData *) d fromSessionDataTask:(NSURLSessionTask *) task withExpectedTotal:(int64_t) totalToTransfer
{
    if (!mdReturnData) {
        mdReturnData = [[NSMutableData alloc] init];
    }
    
    // - for data APIs, we'll infer the number of bytes transferred.
    numBytesRecv    += d.length;
    totalBytesToRecv = totalToTransfer;

    // - the docs suggest using the enumerate API below to avoid flattening the data
    //   before returning it.    
    [d enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *stop) {
        // - don't allow this object to grow without bounds.
        if ([mdReturnData length] + byteRange.length > CS_NF_MAX_JSON_SOURCE) {
            NSLog(@"CS-ALERT: Unexpected excessive data in NET-API request %@.", [[self class] description]);
            *stop = YES;
            if ([mdReturnData length] >= CS_NF_MAX_JSON_SOURCE) {
                return;
            }
            byteRange.length = CS_NF_MAX_JSON_SOURCE - [mdReturnData length];
        }
        
        // - now append the content.
        if (byteRange.length) {
            [mdReturnData appendBytes:bytes length:byteRange.length];
        }
    }];
}

/*
 *  Return the response data.
 */
-(NSData *) resultData
{
    return [[mdReturnData retain] autorelease];
}

/*
 *  Try to convert the downloaded data into a usable object from JSON.
 */
-(id) resultDataConvertedFromJSON
{
    if (!mdReturnData) {
        return nil;
    }
    return [self convertDataFromJSON:mdReturnData];
}

/*
 *  Try to convert a buffer of data to JSON.
 */
-(id) convertDataFromJSON:(NSData *) d
{
    // - attempt the conversion.
    @try {
        return [NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingAllowFragments error:nil];
    }
    @catch (NSException *exception) {
        NSLog(@"CS-ALERT: API de-serialization failure.  %@", [exception description]);
        return nil;
    }
}

/*
 *  This method is called when the API completes, but in general, we don't have much we can do with the task 
 *  itself because it is possible that this feed API is not associated with HTTP, so the per-feed implementation
 *  needs to work out the best way to store the results for its purposes.
 */
-(void) completeAPIWithSessionTask:(NSURLSessionTask *) task andError:(NSError *)err
{
    //  NOTE:
    //  - when the connection fails, we'll get an error code of NSURLErrorNetworkConnectionLost
    if (err != errCompletion) {
        [errCompletion release];
        errCompletion = [err retain];
    }
    
    // - we're done and should be at 100%
    totalBytesToRecv = numBytesRecv;
    totalBytesToSend = numBytesSent;
}

/*
 *  Mark the API with a failure error condition.
 */
-(void) markAPIAsAbortedWithError:(NSError *) err
{
    if (err != errCompletion) {
        [errCompletion release];
        errCompletion = [err retain];
    }
    totalBytesToRecv = -1;
    totalBytesToSend = -1;
}

/*
 *  Returns whether the API was successfully executed.
 */
-(BOOL) isAPISuccessful
{
    if (errCompletion) {
        return NO;
    }
    return YES;
}

/*
 *  When the API fails to complete because of a network-oriented error, which doesn't take into
 *  account any API results, the last error code can be retrieved here.
 */
-(NSError *) networkCompletionErrorCode
{
    return [[errCompletion retain] autorelease];
}

/*
 *  When the request is locked, that means new ones will not be generated.
 */
-(void) setRequestLocked
{
    requestLocked = YES;
}

/*
 *  Assign the number of bytes we expect to receive.
 */
-(void) setTotalBytesToRecv:(int64_t) toRecv
{
    totalBytesToRecv = toRecv;
}

/*
 *  Assign the count of bytes that have been read to this point.
 */
-(void) setNumBytesRecv:(int64_t) numRecv
{
    numBytesRecv = numRecv;
}

/*
 *  Return the number of bytes received by the API.
 */
-(int64_t) bytesRecv
{
    return numBytesRecv;
}

/*
 *  Return the number of bytes we expect to receive by the API.
 */
-(int64_t) totalBytesToRecv
{
    return totalBytesToRecv;
}

/*
 *  Assign the number of bytes we expect to send.
 */
-(void) setTotalBytesToSend:(int64_t) toSend
{
    totalBytesToSend = toSend;
}

/*
 *  Retrieve the number of bytes actually sent.
 */
-(void) setNumBytesSent:(int64_t) numSent
{
    numBytesSent = numSent;
}

/*
 *  Return the number of bytes we have sent.
 */
-(int64_t) bytesSent
{
    return numBytesSent;
}

/*
 *  Return the total number of bytes we expect to send.
 */
-(int64_t) totalBytesToSend
{
    return totalBytesToSend;
}

/*
 *  Assign the result URL from the API.
 */
-(void) setDownloadResultURL:(NSURL *) url
{
    if (uDownloadedResult != url) {
        [uDownloadedResult release];
        uDownloadedResult = [url retain];
    }
}

/*
 *  When we reload requests after the app restarts (usually uploads/downloads), this method
 *  is called in case you want to do some custom configuration on it based on the request data.
 */
-(void) configureWithExistingRequest:(NSURLRequest *) req
{
}

/*
 *  A single API can have an attached completion block that is executed right before the feed is notified
 *  of the completion.
 */
-(void) setCustomCompletionBlock:(CS_netFeedAPICompletionBlock) cb
{
    if (cb != completionBlock) {
        // - persistent APIs like download cannot have a completion block because they may be recreated without it.
        // - realtime APIs will never shut down if things are working, so we don't allow them to depend on completion.
        if (self.throttleCategory != CS_CNT_THROTTLE_TRANSIENT && self.throttleCategory != CS_CNT_THROTTLE_UPLOAD) {
            NSLog(@"CS-ALERT: Unsupported API custom completion block assignment on unsupported throttle category in %@.", [[self class] description]);
            return;
        }
        
        if (completionBlock) {
            Block_release(completionBlock);
            completionBlock = nil;
        }
        
        if (cb) {
            completionBlock = Block_copy(cb);
        }
    }
}

/*
 *  Retrieve the URL for the download.
 */
-(NSURL *) downloadResultURL
{
    return [[uDownloadedResult retain] autorelease];
}

/*
 *  Return a unique id for this API request.  If not provided, it will not be allowed with some API paths.
 */
-(NSString *) requestId
{
    return nil;
}

/*
 *  Every API will receive this method call immediately before a request is generated and may use that
 *  opportunity to either start some longer-running preparation or initialze itself.
 *  - if preparation returns NO, the API is discarded immeidately.
 */
-(BOOL) prepareToGenerateRequest
{
    return YES;
}

/*
 *  If an API requires additional work before it can generate a request, it can return NO from
 *  this method when queried.  The only nuance is that if it doesn't prepare itself in a timely fashion, 
 *  it may be aborted because it is hanging onto throttle resources.
 */
-(BOOL) isPreparedToGenerateRequest
{
    return YES;
}

/*
 *  When an API takes too long to prepare itself, it may be aborted by the session manager 
 *  that owns it.  You can use this opportunity to halt anything outstanding.
 */
-(void) abortRequestPreparation
{
}

/*
 *  If this API requires extended preparation, notify its delegate when that completes to
 *  finish up in a timely manner.
 */
-(void) notifyPreparationCompleted
{
    if (sessionDelegate) {
        [sessionDelegate performSelector:@selector(preparationIsCompletedInAPI:) withObject:self];
        sessionDelegate = nil;
    }
}
@end


/************************
 CS_netFeedAPI (shared)
 ************************/
@implementation CS_netFeedAPI (shared)
/*
 *  Issue the completion block for this API if it is set.
 */
-(void) issueCustomCompletionForFeed:(ChatSealFeed *) feed
{
    if (!completionBlock) {
        return;
    }
    completionBlock(self, feed);
    [self setCustomCompletionBlock:nil];
}
@end


/*******************************
 CS_netFeedCreatorDelegateHandle
 *******************************/
@implementation CS_netFeedCreatorDelegateHandle
/*
 *  Object attributes.
 */
{
    id<CS_netFeedCreatorDelegateAPI> delegate;
}

/*
 *  Initialize the object.
 */
-(id) initWithCreatorDelegate:(id<CS_netFeedCreatorDelegateAPI>) creatorDelegate
{
    self = [super init];
    if (self) {
        delegate = creatorDelegate;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [self stopAllDelegateNotifications];
    [super dealloc];
}

/*
 *  Don't forward any more notifications from the delegate.
 */
-(void) stopAllDelegateNotifications
{
    @synchronized (self) {
        delegate = nil;
    }
}

@end

/******************************************
 CS_netFeedCreatorDelegateHandle (internal)
 ******************************************/
@implementation CS_netFeedCreatorDelegateHandle (internal)
/*
 *  Safely notify the creator that destruction is imminent.
 */
-(void) notifyDelegateOfDeallocationForAPI:(CS_netFeedAPI *) api
{
    @synchronized (self) {
        if (delegate) {
            [delegate performSelector:@selector(willDeallocateAPI:) withObject:api];
        }
    }
}

@end
