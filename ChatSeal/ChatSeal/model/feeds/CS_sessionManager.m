//
//  CS_sessionManager.m
//  ChatSeal
//
//  Created by Francis Grolemund on 4/4/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_sessionManager.h"
#import "ChatSeal.h"
#import "CS_feedShared.h"
#import "CS_preparingNetFeedAPIRequest.h"

//  THREADING-NOTES:
//  - internal locking is provided.
//  - the delegate management is thread safe and is assumed to be unset by the owner of this object before the object is destroyed.
//  - it is assumed that an API object is only ever accessed on a single thread at a time and after it is first submitted here, it only
//    executes on the operation queue threads associated with this manager when interesting events occur.  This fact allows the APIs to
//    be coded without concern for thread safety.
//  - API request objects are constant, so once you get a reference to them, you don't need to worry about their feed/api combination
//    being changed out from under you.  Also, they have no internal locking because their values do not change.
//  - I am assuming that although multiple threads could deliver results to an API, depending on the threading approach in the session, these
//    events must occur serially in order to guarantee a reproducible pattern described in the documentation.  In other words, it should not
//    be possible to receive a completion event on a task before the data-received event.  This means that locking an API itself should never
//    be necessary as there is only ever one thread that ever refers to it here and we advise that API handles are never stored.
//  - For nearly all cases, explicit locking should not be required in the session-delegated data access methods because we don't want to
//    hold locks when issuing feed delegated pipeline events.

// - constants
static NSString     *CS_SM_PREP_REQUEST_URL = @"chatseal://preparing.request";
static NSUInteger   CS_SM_PREP_ABORT_TIME   = 10;
static NSUInteger   CS_SM_PREP_DESTROY_TIME = 20;
static NSString     *CS_BG_SESSION_ID       = @"com.realproven.chatseal.bgsession";

// - forward declarations
@interface CS_sessionManager (internal) <CS_netFeedAPISessionDelegate>
+(NSURL *) uploadTemporaryDirectoryAndCreateIfNeeded:(BOOL) doCreate;
+(NSURL *) uploadFileURLWithId:(NSString *) uploadFileId;
-(BOOL) configureForLowVolumeWithError:(NSError **) err;
-(BOOL) configureForPersistenceWithError:(NSError **) err;
-(BOOL) configureForRealtimeHighVolumeWithError:(NSError **) err;
-(CS_netFeedAPIRequest *) requestForTask:(NSURLSessionTask *) task;
-(NSArray *) urlArrayForPendingTasks:(NSArray *) arrPending andFilterByCategory:(cs_cnt_throttle_category_t) category;
+(NSURL *) downloadCacheURLForSessionQuality:(ps_sm_session_quality_t) quality withError:(NSError **) err;
-(NSURL *) moveFileToTemporaryLocation:(NSURL *) uFile withError:(NSError **) err;
-(BOOL) scheduleRequest:(CS_netFeedAPIRequest *) request inCategory:(cs_cnt_throttle_category_t) category usingThrottle:(CS_centralNetworkThrottle *) throttle
  returningWasThrottled:(BOOL *) wasThottled withError:(NSError **) err;
-(BOOL) waitForPreparationOfRequest:(CS_netFeedAPIRequest *) request inCategory:(cs_cnt_throttle_category_t) category usingThrottle:(CS_centralNetworkThrottle *) throttle returningWasThrottled:(BOOL *) wasThottled withError:(NSError **) err;
-(void) completeAPI:(CS_netFeedAPI *) api inFeed:(ChatSealFeed *) feed asThrottledRequestURL:(NSURL *) u;
@end

@interface CS_sessionManager (session) <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>
@end

@interface CS_netFeedAPI (shared)
-(void) issueCustomCompletionForFeed:(ChatSealFeed *) feed;
@end

/***************************
 CS_sessionManager
 ***************************/
@implementation CS_sessionManager
/*
 *  Object attributes.
 */
{
    ps_sm_session_quality_t        sessionQuality;
    
    NSOperationQueue               *opQSession;
    NSURLSession                   *managedSession;
    NSMutableDictionary            *mdPendingRequests;
    id<CS_sessionManagerDelegate> delegate;
    NSMutableArray                 *maPreparingRequests;
}

/*
 *  Initialize the object.
 */
-(id) initWithSessionQuality:(ps_sm_session_quality_t) quality
{
    self = [super init];
    if (self) {
        sessionQuality      = quality;
        opQSession          = nil;
        managedSession      = nil;
        delegate            = nil;
        mdPendingRequests   = nil;
        maPreparingRequests = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    self.delegate = nil;
    [self close];
    [super dealloc];
}

/*
 *  Set the delegate.
 */
-(void) setDelegate:(id<CS_sessionManagerDelegate>)delAssign
{
    @synchronized (self) {
        // - assign, not retain!
        delegate = delAssign;
    }
}

/*
 *  Return the delegate for processing.
 */
-(id<CS_sessionManagerDelegate>) delegate
{
    @synchronized (self) {
        // - although the delegate isn't retained while it is stored,
        //   we're going to retain it here tempoarily so that it can be used
        //   for the duration of its call without fear of being deallocated.
        // - as long as the owner is a
        return [[delegate retain] autorelease];
    }
}

/*
 *  Return the configured session quality for this object.
 */
-(ps_sm_session_quality_t) quality
{
    return sessionQuality;
}

/*
 *  Open and configure the session for operation.
 */
-(BOOL) openWithError:(NSError **) err
{
    BOOL ret = YES;

    @synchronized (self) {
        if (managedSession) {
            return YES;
        }
        
        if (!opQSession) {
            opQSession = [[NSOperationQueue alloc] init];
        }
        
        if (!mdPendingRequests) {
            mdPendingRequests = [[NSMutableDictionary alloc] init];
        }
        
        if (!maPreparingRequests) {
            maPreparingRequests = [[NSMutableArray alloc] init];
        }
        
        // - the cache for downloads is intentionally short-lived because once the session marks
        //   it as complete, there is no record remaining about the context for its presence there.
        // - if the file is important, it must be re-downloaded.
        NSURL *u = [CS_sessionManager downloadCacheURLForSessionQuality:sessionQuality withError:err];
        if (!u) {
            return NO;
        }
        [[NSFileManager defaultManager] removeItemAtURL:u error:nil];
        
        
        // - build a session object that matches the quality guarantees.
        switch (sessionQuality) {
            case CS_SMSQ_LOW_VOLUME:
                ret = [self configureForLowVolumeWithError:err];
                break;
                
            case CS_SMSQ_PERSISTENT:
                ret = [self configureForPersistenceWithError:err];
                break;
                
            case CS_SMSQ_REALTIME_HIGH_VOLUME:
                ret = [self configureForRealtimeHighVolumeWithError:err];
                break;
                
            default:
                [CS_error fillError:err withCode:CSErrorInvalidArgument];
                return NO;
                break;
        }
        return ret;
    }
}

/*
 *  Close the session.
 */
-(void) close
{
    @synchronized (self) {
        [mdPendingRequests release];
        mdPendingRequests = nil;
        
        [managedSession invalidateAndCancel];
        [managedSession release];
        managedSession = nil;
        
        [opQSession release];
        opQSession = nil;
        
        for (CS_preparingNetFeedAPIRequest *prep in maPreparingRequests) {
            [prep.api abortRequestPreparation];
        }
        [maPreparingRequests release];
        maPreparingRequests = nil;
    }
}

/*
 *  Add a request to the enclosed session.
 */
-(BOOL) addRequest:(CS_netFeedAPIRequest *) request inCategory:(cs_cnt_throttle_category_t) category usingThrottle:(CS_centralNetworkThrottle *) throttle
                                          returningWasThrottled:(BOOL *) wasThottled withError:(NSError **) err
{
    // - setting up a request for scheduling and waiting for preparation requires that we lock our data!
    BOOL isScheduled = NO;
    @synchronized (self) {
        if (!managedSession) {
            [CS_error fillError:err withCode:CSErrorFeedCollectionNotOpen andFailureReason:@"The session is not open."];
            if (wasThottled) {
                *wasThottled = NO;
            }
            return NO;
        }
        
        // - requests are initially prepared for URL generation, which can be useful if they
        //   require extra effort before they can be issued.
        if (![request.api prepareToGenerateRequest]) {
            if (wasThottled) {
                *wasThottled = NO;
            }
            [CS_error fillError:err withCode:CSErrorIncompleteFeedRequest andFailureReason:@"Failed to prepare request for processing."];
            return NO;
        }
        
        // - it is possible that a request is not yet ready to be issued, so we'll check first.  If it isn't, it will be filed to a background
        //   queue to wait for it to prepare itself.
        if ([request.api isPreparedToGenerateRequest]) {
            isScheduled = [self scheduleRequest:request inCategory:category usingThrottle:throttle returningWasThrottled:wasThottled withError:err];
        }
        else {
            // - NOTE: this approach of waiting for the request to prepare may not scale well for a lot of simultaneous things, so use this sparingly.
            return [self waitForPreparationOfRequest:request inCategory:category usingThrottle:throttle returningWasThrottled:wasThottled withError:err];
        }
    }
    
    // - when we successfully schedule the request, make sure the feed is notified of it, but make sure
    //   it is done outside the lock per the requirements for locking in this infrastructure.
    if (isScheduled) {
        if ([request.feed respondsToSelector:@selector(pipelineAPIWasScheduled:)]) {
            [request.feed performSelector:@selector(pipelineAPIWasScheduled:) withObject:request.api];
        }
    }
    return isScheduled;
}

/*
 *  The session manager expects that its owner periodically call this high priority update method to ensure that
 *  anything that is pending is pushed forward.
 */
-(void) processHighPriorityItems
{
    // - this is where we check on any requests that are being prepared.
    NSMutableArray *maScheduled = [NSMutableArray array];
    NSMutableArray *maToAbort   = [NSMutableArray array];
    @synchronized (self) {
        if (![maPreparingRequests count]) {
            return;
        }

        for (CS_preparingNetFeedAPIRequest *prep in maPreparingRequests) {
            NSError *tmp = nil;
            if (!prep.isCompleted && [prep.api isPreparedToGenerateRequest]) {
                BOOL wasThrottled        = NO;
                prep.api.sessionDelegate = nil;
                if ([self scheduleRequest:prep inCategory:prep.category usingThrottle:prep.throttle returningWasThrottled:&wasThrottled withError:&tmp]) {
                    [maScheduled addObject:prep];
                }
                else {
                    [prep setAbortedWithError:tmp];
                    [maToAbort addObject:prep];
                }
            }
            else {
                if (time(NULL) - prep.creationTime > CS_SM_PREP_ABORT_TIME) {
                    [CS_error fillError:&tmp withCode:CSErrorIncompleteFeedRequest andFailureReason:@"Preparation did not occur in a timely manner."];
                    [prep setAbortedWithError:tmp];
                    [maToAbort addObject:prep];
                }
            }
        }
        
        // - remove everything we scheduled.
        [maPreparingRequests removeObjectsInArray:maScheduled];
        
        // - remove any aborted items if they have exceeded their destruction timeout.
        for (CS_preparingNetFeedAPIRequest *prepAbort in maToAbort) {
            // - if the API is past its deletion period, do that now
            if (time(NULL) - prepAbort.creationTime > CS_SM_PREP_DESTROY_TIME) {
                [maPreparingRequests removeObject:prepAbort];
            }
        }
    }
    
    // - let the feed know about any items that were aborted, but outside the lock.
    for (CS_preparingNetFeedAPIRequest *prepAbort in maToAbort) {
        // - if the feed responds to completion notifications, let it know about it and ensure the central throttle is updated.
        if (![prepAbort isCompleted]) {
            [self completeAPI:prepAbort.api inFeed:prepAbort.feed asThrottledRequestURL:[NSURL URLWithString:CS_SM_PREP_REQUEST_URL]];
            prepAbort.isCompleted = YES;
        }
    }
    
    // - the last thing is to notify the feed of all the scheduled items.
    for (CS_preparingNetFeedAPIRequest *prepSched in maScheduled) {
        if ([prepSched.feed respondsToSelector:@selector(pipelineAPIWasScheduled:)]) {
            [prepSched.feed performSelector:@selector(pipelineAPIWasScheduled:) withObject:prepSched.api];
        }
    }
}

/*
 *  Cancel all pending requests for the given feed.
 */
-(void) cancelAllRequestsForFeed:(ChatSealFeed *) feed
{
    @synchronized (self) {
        [mdPendingRequests enumerateKeysAndObjectsUsingBlock:^(NSNumber *nTaskId, CS_netFeedAPIRequest *req, BOOL *stop) {
            if ([feed isEqual:req.feed]) {
                [req.task cancel];
            }
        }];
    }
}

/*
 *  Determines if this session manager has pending items in its queue.
 */
-(BOOL) hasPendingRequests
{
    @synchronized (self) {
        if ([mdPendingRequests count] || [maPreparingRequests count]) {
            return YES;
        }
        return NO;
    }
}

@end


/******************************
 CS_sessionManager (internal)
 ******************************/
@implementation CS_sessionManager (internal)
/*
 *  Return a temporary directory URL where we can store content.
 */
+(NSURL *) uploadTemporaryDirectoryAndCreateIfNeeded:(BOOL) doCreate
{
    NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
    u        = [u URLByAppendingPathComponent:@"sessionUploads"];
    if (doCreate) {
        if (![[NSFileManager defaultManager] fileExistsAtPath:[u path]]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:[u path] withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    return u;
}

/*
 *  Return a URL for performing uploads.
 */
+(NSURL *) uploadFileURLWithId:(NSString *) uploadFileId
{
    NSURL *u = [CS_sessionManager uploadTemporaryDirectoryAndCreateIfNeeded:YES];
    return [u URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.body", uploadFileId]];
}

/*
 *  The most common kind of session is a low-volume session and is intended for non-persistent actions that
 *  may be repeated and can occur over an iPhone data plan.
 *  - ASSUMES the lock is held.
 */
-(BOOL) configureForLowVolumeWithError:(NSError **) err
{
    // - low volume sessions could have a lot of things happening, so we don't want to spawn a lot of threads
    //   unnecessarily.
    [opQSession setMaxConcurrentOperationCount:5];
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.timeoutIntervalForRequest  = 15.0;
    config.timeoutIntervalForResource = 60.0;
    config.allowsCellularAccess       = YES;
    
    managedSession                    = [[NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:opQSession] retain];
    managedSession.sessionDescription = @"low-volume";
    
    return YES;
}

/*
 *  A persistent, or background, session will be run in a separate process and wake this one up when it
 *  completes.  Uploads and downloads are good candidates for this kind of connection because they will occur
 *  even if this app is not living.
  *  - ASSUMES the lock is held.
 */
-(BOOL) configureForPersistenceWithError:(NSError **) err
{
    // - I don't want to overburden the main process with these types of heavy requests.
    [opQSession setMaxConcurrentOperationCount:5];
    
    NSURLSessionConfiguration *config = nil;
    if ([[NSURLSessionConfiguration class] respondsToSelector:@selector(backgroundSessionConfigurationWithIdentifier:)]) {
        config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:CS_BG_SESSION_ID];
    }
    else {
        // - deprecated in 8.0
        config = [NSURLSessionConfiguration backgroundSessionConfiguration:CS_BG_SESSION_ID];
    }
    config.timeoutIntervalForRequest  = 60.0;
    config.timeoutIntervalForResource = 60.0 * 30.0;
    config.allowsCellularAccess       = YES;
    
    managedSession                    = [[NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:opQSession] retain];
    managedSession.sessionDescription = @"persistent";
    
    // - the persistent sessions need to identify their pending tasks before we are allowed to schedule
    //   any more through the central throttle.
    [managedSession getTasksWithCompletionHandler:^(NSArray *notApplicableDataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        // - NOTE: data tasks are not supported on background sessions, so we're not going to process them here.
        NSArray *arrDownloads     = [self urlArrayForPendingTasks:downloadTasks andFilterByCategory:CS_CNT_THROTTLE_DOWNLOAD];
        NSArray *arrUploads       = [self urlArrayForPendingTasks:uploadTasks andFilterByCategory:CS_CNT_THROTTLE_UPLOAD];
        id<CS_sessionManagerDelegate> tmpDelegate = self.delegate;
        if (tmpDelegate) {
            [tmpDelegate sessionManager:self didReloadUploadURLs:arrUploads andDownloadURLs:arrDownloads];
        }
    }];
    
    return YES;
}

/*
 *  A realtime session is expected to get a constant stream of data for higher levels of interactivity.
 *  - ASSUMES the lock is held.
 */
-(BOOL) configureForRealtimeHighVolumeWithError:(NSError **) err
{
    // - I'm adding a limit here just to keep it manageable, but there really doesn't need to be as a rule.
    [opQSession setMaxConcurrentOperationCount:25];
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.timeoutIntervalForRequest  = 60.0 * 60.0;
    config.timeoutIntervalForResource = 60.0 * 60.0 * 24.0;
    config.allowsCellularAccess       = YES;

    // NOTE: I originally considered making this a Wi-Fi only, but realized that at least in the case of Twitter that
    //       realtime connections allow the app to really respond much better to things that are happening.
    
    managedSession                    = [[NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:opQSession] retain];
    managedSession.sessionDescription = @"realtime";
    
    return YES;
}

/*
 *  Locate an existing request object for the given task.
 */
-(CS_netFeedAPIRequest *) requestForTask:(NSURLSessionTask *) task
{
    // - must obviously take the lock when checking for a pending request.
    CS_netFeedAPIRequest *ret = nil;
    @synchronized (self) {
        if (!managedSession) {
            return nil;
        }
        ret = [[[mdPendingRequests objectForKey:[NSNumber numberWithUnsignedInteger:task.taskIdentifier]] retain] autorelease];
    }
    
    // - if the request doesn't exist, it could mean that we're starting up again after the app was backgrounded, so we
    //   need to manufacture a new request object on the fly inside the collector.
    // - but, this can only happen with persistent sessions
    if (!ret && sessionQuality == CS_SMSQ_PERSISTENT) {
        ret = [self.delegate sessionManager:self needsRequestForExistingTask:task];
        if (ret) {
            @synchronized (self) {
                [ret.api setActiveRequest:task.originalRequest];
                ret.task = task;
                [mdPendingRequests setObject:ret forKey:[NSNumber numberWithUnsignedInteger:task.taskIdentifier]];
                
                // - we cannot modify this existing API again.
                [ret.api setRequestLocked];
            }
        }
    }
    
    // - when we couldn't find an origin for the task, it doesn't make sense to allow it to proceed because it will never
    //   be used.
    if (!ret) {
        NSLog(@"CS-ALERT: Discarding untracked task %lu for %@.", (unsigned long) task.taskIdentifier, task.originalRequest.URL);
        [task cancel];
    }
    
    return ret;
}

/*
 *  Return an array with all the URLs for the given list of pending tasks.
 */
-(NSArray *) urlArrayForPendingTasks:(NSArray *) arrPending andFilterByCategory:(cs_cnt_throttle_category_t) category
{
    NSMutableArray *maRet = [NSMutableArray array];
    for (NSURLSessionTask *st in arrPending) {
        CS_netFeedAPIRequest *nfr = [self requestForTask:st];
        if (nfr && nfr.api.throttleCategory == category) {
            NSURL *urlRequest = [nfr.api requestWithError:nil].URL;
            if (urlRequest) {
                [maRet addObject:urlRequest];
            }
        }
    }
    return maRet;
}

/*
 *  The download cache is a directory that can store downloads temporarily, but intentionally does not exist between
 *  executions because the files contained inside it are not tracked.
 */
+(NSURL *) downloadCacheURLForSessionQuality:(ps_sm_session_quality_t) quality withError:(NSError **) err
{
    NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:err];
    if (!u) {
        return nil;
    }
    
    NSString *name = nil;
    switch (quality) {
        case CS_SMSQ_LOW_VOLUME:
            name = @"LowVol";
            break;
            
        case CS_SMSQ_PERSISTENT:
            name = @"Persist";
            break;
            
        case CS_SMSQ_REALTIME_HIGH_VOLUME:
            name = @"HighVol";
            break;
            
        default:
            return nil;
            break;
    }
    
    u = [u URLByAppendingPathComponent:[NSString stringWithFormat:@"com.realproven.ChatSeal.dl%@", name]];
    if (![[NSFileManager defaultManager] fileExistsAtPath:[u path]]) {
        if (![[NSFileManager defaultManager] createDirectoryAtPath:[u path] withIntermediateDirectories:YES attributes:nil error:err]) {
            return nil;
        }
    }
    return u;
}

/*
 *  Move the given file to a temporary location and return the result.
 */
-(NSURL *) moveFileToTemporaryLocation:(NSURL *) uFile withError:(NSError **) err
{
    NSError *tmp = nil;
    NSURL *uBase = [CS_sessionManager downloadCacheURLForSessionQuality:sessionQuality withError:&tmp];
    if (!uBase) {
        [CS_error fillError:err withCode:CSErrorFilesystemAccessError andFailureReason:[tmp localizedDescription]];
        return nil;
    }
    
    NSUUID *uuidTarget = [NSUUID UUID];
    NSURL *uTarget     = [uBase URLByAppendingPathComponent:uuidTarget.UUIDString];
    if (![[NSFileManager defaultManager] moveItemAtURL:uFile toURL:uTarget error:&tmp]) {
        [CS_error fillError:err withCode:CSErrorFilesystemAccessError andFailureReason:[tmp localizedDescription]];
        return nil;
    }
    return uTarget;
}

/*
 *  An API is not issued on the network until it has been scheduled.  This method will handle the scheduling logistics.
 *  - ASSUMES the lock is held
 */
-(BOOL) scheduleRequest:(CS_netFeedAPIRequest *) request inCategory:(cs_cnt_throttle_category_t) category usingThrottle:(CS_centralNetworkThrottle *) throttle
  returningWasThrottled:(BOOL *) wasThottled withError:(NSError **) err
{
    NSURLRequest *urlRequest = [request.api requestWithError:err];
    if (!urlRequest) {
        if (wasThottled) {
            *wasThottled = NO;
        }
        return NO;
    }
    
    // ...prevent further modifications to the API after we generate its request.
    [request.api setRequestLocked];
    
    // - this is where the rubbler meets the road with the centralized throttling.
    @synchronized (throttle) {
        // - when we generate pending requests, we hold a position in the central throttle
        //   while we are doing so and that must be converted over to a proper request URL
        //   before we continue.
        if ([request isKindOfClass:[CS_preparingNetFeedAPIRequest class]]) {
            [throttle completePendingURLRequest:[NSURL URLWithString:CS_SM_PREP_REQUEST_URL] inCategory:request.api.centralThrottleCategory];
        }
        
        // - it is possible we're using an alternate category intentionally.
        BOOL allowNonActive                       = NO;
        cs_cnt_throttle_category_t activeCategory = throttle.activeThrottleCategory;
        if (request.api.throttleCategory != request.api.centralThrottleCategory) {
            if (activeCategory == request.api.throttleCategory) {
                allowNonActive = YES;
            }
        }
        
        // - the special case where an API was prepared separately.
        if (request.needsPreparation) {
            [throttle setActiveThrottleCategory:request.api.centralThrottleCategory];
        }
        
        // - allocate a position in the central throttle.
        BOOL wasStarted = [throttle startPendingURLRequest:urlRequest.URL inCategory:request.api.centralThrottleCategory andAllowNonActiveCategory:allowNonActive];
        
        // - make sure that the active category is reset after a special case preparation.
        if (request.needsPreparation) {
            [throttle setActiveThrottleCategory:activeCategory];
        }
        
        // - if this failed, it was throttled.
        if (!wasStarted) {
            if (wasThottled) {
                *wasThottled = YES;
            }
            return NO;
        }
    }
    
    NSURLSessionTask *task = nil;
    @try {
        if (category == CS_CNT_THROTTLE_DOWNLOAD) {
            task = [managedSession downloadTaskWithRequest:urlRequest];
        }
        else if (category == CS_CNT_THROTTLE_UPLOAD) {
            // - upload tasks must have an HTTPBody already defined in the request so that
            //   we can persist it before the upload
            NSString *apiId = [request.api requestId];
            if (!urlRequest.HTTPBody || !apiId) {
                if (wasThottled) {
                    *wasThottled = NO;
                }
                [CS_error fillError:err withCode:CSErrorIncompleteFeedRequest andFailureReason:@"Missing HTTPBody in NSURLRequest."];
                return NO;
            }
            
            // - we have a body, so write it to disk before we continue.
            NSURL *u = [CS_sessionManager uploadFileURLWithId:apiId];
            if (![urlRequest.HTTPBody writeToURL:u atomically:YES]) {
                if (wasThottled) {
                    *wasThottled = NO;
                }
                [CS_error fillError:err withCode:CSErrorFilesystemAccessError andFailureReason:@"Failed to write HTTP request body to disk."];
                return NO;
            }
            
            // - now we can use the upload task the way it was intended because we have a body on disk.
            task = [managedSession uploadTaskWithRequest:urlRequest fromFile:u];
            
            // - if we failed to start the upload, make sure that the temporary file is discarded.
            if (!task) {
                [[NSFileManager defaultManager] removeItemAtURL:u error:nil];
            }
        }
        else {
            task = [managedSession dataTaskWithRequest:urlRequest];
        }
    }
    @catch (NSException *exception) {
        [CS_error fillError:err withCode:CSErrorFeedNotSupported andFailureReason:[exception description]];
        if (wasThottled) {
            *wasThottled = NO;
        }
        return NO;
    }
    
    if (!task) {
        [CS_error fillError:err withCode:CSErrorFeedNotSupported andFailureReason:@"Unable to create a new session task."];
        if (wasThottled) {
            *wasThottled = NO;
        }
        return NO;
    }
    
    // - save off a reference by task identifier so we can route it correctly later.
    request.task = task;
    [mdPendingRequests setObject:request forKey:[NSNumber numberWithUnsignedInteger:task.taskIdentifier]];
    [task resume];
    return YES;
}

/*
 *  Requests that aren't yet prepared will need to sit for a few moments until they get what they need to proceed.
 *  - ASSUMES the lock is held.
 */
-(BOOL) waitForPreparationOfRequest:(CS_netFeedAPIRequest *) request inCategory:(cs_cnt_throttle_category_t) category
                      usingThrottle:(CS_centralNetworkThrottle *) throttle returningWasThrottled:(BOOL *) wasThottled withError:(NSError **) err
{
    // - we need to reserve space in the throttle first
    if (![throttle startPendingURLRequest:[NSURL URLWithString:CS_SM_PREP_REQUEST_URL] inCategory:request.api.centralThrottleCategory]) {
        if (wasThottled) {
            *wasThottled = YES;
        }
        return NO;
    }
    
    // - now save off the request so that we can watch it.
    CS_preparingNetFeedAPIRequest *prep = [CS_preparingNetFeedAPIRequest prepareRequest:request inCategory:category usingThrottle:throttle];
    prep.api.sessionDelegate             = self;
    [maPreparingRequests addObject:prep];
    
    return YES;
}

/*
 *  This single method is used to complete all APIs, regardless of where they originate.
 */
-(void) completeAPI:(CS_netFeedAPI *) api inFeed:(ChatSealFeed *) feed asThrottledRequestURL:(NSURL *) u
{
    // - let the collector know first so that it can open the throttle again.
    [self.delegate sessionManager:self didCompleteThrottledRequestForURL:u inCategory:api.centralThrottleCategory];
    
    // - explicitly unthrottle it so that we don't have to wait for autorelease to do the work for us because
    //   then we'll be racing with it when we start the next download.
    [api unthrottleAPI];
    
    // - issue the completion block first if necessary.
    [api issueCustomCompletionForFeed:feed];
    
    // - if the feed responds to completion notifications, let it know about it.
    if ([feed respondsToSelector:@selector(pipelineDidCompleteAPI:)]) {
        [feed pipelineDidCompleteAPI:api];
    }
    
    // - if this was an upload request api, we may need to delete the temporary file.
    if ([api throttleCategory] == CS_CNT_THROTTLE_UPLOAD) {
        NSString *apiId = [api requestId];
        if (apiId) {
            NSURL *uUploadFile = [CS_sessionManager uploadFileURLWithId:apiId];
            if ([[NSFileManager defaultManager] fileExistsAtPath:[uUploadFile path]] &&
                ![[NSFileManager defaultManager] removeItemAtURL:uUploadFile error:nil]) {
                NSLog(@"CS: Failed to delete the temporary upload file at %@.", [u path]);
            }
        }
    }
}

/*
 *  When preparation is complete, request that the collector move the request forward.
 */
-(void) preparationIsCompletedInAPI:(CS_netFeedAPI *)api
{
    [delegate sessionManagerRequestsHighPriorityUpdates:self];
}
@end

/******************************
 CS_sessionManager (session)
 ******************************/
@implementation CS_sessionManager (session)
/*
 *  An authentication challenge was made by the server.
 */
-(void) URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
    //  - this isn't used at the moment, but I wanted to lock-in support for the default handling
    //    so that it is clear I can continue to use this when more complicated authentication is required
    //    later for certain feeds.
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

/*
 *  All events associated with the background URL session are done so we need to be sure to let the main application know 
 *  about it.
 */
-(void) URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    @synchronized (self) {
        // - this only makes sense for the persistent sessions.
        if (!managedSession || sessionQuality != CS_SMSQ_PERSISTENT) {
            return;
        }
        
        // - we cached the completion handler when the app started.
        [ChatSeal completeBackgroundSession];
    }
}

/*
 *  A task has completed or failed.
 *  !!NOTE!!
 *  - This is the most important delegate method this manager responds to because it is the only way that we can properly 
 *    account for everything that occurs in the system.
 */
-(void) URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    CS_netFeedAPIRequest *request = [self requestForTask:task];
    if (!request) {
        return;
    }
    [request.api completeAPIWithSessionTask:task andError:error];
    
    // - now tie up the remaining accounting tasks.
    [self completeAPI:request.api inFeed:request.feed asThrottledRequestURL:task.originalRequest.URL];
    
    // - remove the request from the tracked list because it is offically done.
    @synchronized (self) {
        [mdPendingRequests removeObjectForKey:[NSNumber numberWithUnsignedInteger:task.taskIdentifier]];
    }
}

/*
 *  Track the progress of an upload.
 */
-(void) URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    CS_netFeedAPIRequest *request = [self requestForTask:task];
    if (!request) {
        return;
    }
    
    [request.api setTotalBytesToSend:totalBytesExpectedToSend];
    [request.api setNumBytesSent:totalBytesSent];
    
    if ([request.feed respondsToSelector:@selector(pipelineAPIProgress:)]) {
        [request.feed pipelineAPIProgress:request.api];
    }
}

/*
 *  When one of the non-persistent tasks receives content, we need to make sure the data is saved where it belongs.
 */
-(void) URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    CS_netFeedAPIRequest *request = [self requestForTask:dataTask];
    if (!request) {
        return;
    }
    
    // - now update the API with the returned content.
    int64_t expectedTotal = 0;
    if (request.api.throttleCategory == CS_CNT_THROTTLE_UPLOAD) {
        expectedTotal = dataTask.countOfBytesExpectedToSend;
    }
    else {
        expectedTotal = dataTask.countOfBytesExpectedToReceive;
    }
    
    // - we give the API the task in order to pass along the right of cancellation, which it may do.
    [request.api didReceiveData:data fromSessionDataTask:dataTask withExpectedTotal:expectedTotal];
    
    // - then notify the feed so that it can track progress, but not on the uploads because that occurs
    //   elsewhere.
    if (request.api.throttleCategory != CS_CNT_THROTTLE_UPLOAD && [request.feed respondsToSelector:@selector(pipelineAPIProgress:)]) {
        [request.feed pipelineAPIProgress:request.api];
    }
}

/*
 *  Track download progress.
 */
-(void) URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    CS_netFeedAPIRequest *request = [self requestForTask:downloadTask];
    
    // - first update the stats in the API.
    [request.api setNumBytesRecv:totalBytesWritten];
    [request.api setTotalBytesToRecv:totalBytesExpectedToWrite];
    
    // - then notify the feed so that it can track progress.
    if ([request.feed respondsToSelector:@selector(pipelineAPIProgress:)]) {
        [request.feed pipelineAPIProgress:request.api];
    }
}

/*
 *  A download was resumed.
 */
-(void) URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    // - This isn't useful for our purposes.
}

/*
 *  Identify when download tasks complete and make sure that the feed knows about them.
 */
-(void) URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    CS_netFeedAPIRequest *request = [self requestForTask:downloadTask];
    if (!request) {
        return;
    }
    
    // - the file is temporary so we're going to move it over to a common location before continuing.
    NSError *err = nil;
    NSURL *uTmp  = [self moveFileToTemporaryLocation:location withError:&err];
    if (!uTmp) {
        NSLog(@"CS: Failed to move a downloaded item to the cache.  %@", [err localizedDescription]);
        [downloadTask cancel];
        return;
    }

    // - assign the URL to the API and we'll deal with it in the completion handler.
    [request.api setDownloadResultURL:uTmp];
}

@end
