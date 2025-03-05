//
//  ChatSealRemoteIdentity.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/23/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "ChatSealRemoteIdentity.h"
#import "ChatSeal.h"
#import "CS_serviceRadar.h"
#import "CS_secureConnection.h"
#import "CS_securePayload.h"
#import "CS_secureTransferServer.h"
#import "UITimer.h"
#import "ChatSealFeedCollector.h"

// - types
typedef enum {
    CS_SRI_NOT_STARTED  = 0,
    CS_SRI_CONNECTING,
    CS_SRI_SENT_REQUEST,
    CS_SRI_IMPORTING_SEAL,
    CS_SRI_RECV_SEAL,
    CS_SRI_NOTIFY_COMPLETE,
    CS_SRI_ERROR
} phs_sri_import_state_t;

// - forward declarations
@interface ChatSealRemoteIdentity (internal) <CS_secureConnectionDelegate>
-(void) releaseSecureConnection;
-(void) abortSealImportWithError:(NSError *) err;
-(CS_secureConnection *) secureConnection;
-(void) timerFired:(UITimer *) timer;
-(void) manageSealImportWithExistingSeals:(NSArray *) arrExistingSeals andTransferData:(CS_secureSealTransferPayload *) stp;
-(void) manageSealConfirmationResposeWithIdentity:(ChatSealIdentity *) identity;
@end

// - initialization is very custom, and not exported.
@interface ChatSealRemoteIdentity (shared)
-(id) initWithService:(CS_service *) service andURL:(NSURL *) url;
@end

// - shared with the contained secure connection.
@interface CS_secureConnection (shared)
-(id) initWithConnectionToService:(CS_service *) svc usingPassword:(NSString *) pwd;
@end

/*************************
 ChatSealRemoteIdentity
 *************************/
@implementation ChatSealRemoteIdentity
/*
 *  Object attributes.
 */
{
    phs_sri_import_state_t importState;
    NSURL                  *secureURL;
    CS_secureConnection   *secConn;
    BOOL                   sealExists;
    NSString               *importedSealId;
    UITimer                *uitTimeout;
}
@synthesize delegate;

/*
 *  Free the object.
 */
-(void) dealloc
{
    delegate = nil;
    
    [uitTimeout invalidate];
    [uitTimeout release];
    uitTimeout = nil;
    
    [self releaseSecureConnection];
    [secureURL release];
    secureURL = nil;
    [importedSealId release];
    importedSealId = nil;
    [super dealloc];
}

/*
 *  This method is used to begin receiving and importing the seal from the remote 
 *  device.
 */
-(BOOL) beginSecureImportProcessing:(NSError **) err
{
    // - when processing is already occurring, return a valid state
    if (importState != CS_SRI_NOT_STARTED) {
        if (secConn) {
            return [secConn isConnectionOKWithError:err];
        }
        else {
            [CS_error fillError:err withCode:CSErrorIdentityTransferFailure andFailureReason:@"The connection is invalid."];
            return NO;
        }
    }
    
    // - start the processing by connecting and waiting for it to complete successfully before
    //   continuing.
    importState = CS_SRI_CONNECTING;
    NSError *tmp = nil;
    if (![secConn connectWithError:&tmp]) {
        importState = CS_SRI_ERROR;
        [CS_error fillError:err withCode:CSErrorIdentityTransferFailure andFailureReason:[tmp localizedDescription]];
        [self releaseSecureConnection];
        return NO;
    }
    
    // - start the connection timer
    uitTimeout = [[UITimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(timerFired:) userInfo:nil repeats:YES] retain];
    
    // - notify the delegate that we're going to get started.
    [self remoteIdentityTransferStarted:self];
    return YES;
}

/*
 *  Returns whether the processing is completed.
 */
-(BOOL) isComplete
{
    if ((importState == CS_SRI_NOTIFY_COMPLETE && !secConn) || importState == CS_SRI_ERROR) {
        return YES;
    }
    return NO;
}

/*
 *  The seal transfer has begun for the remote identity.
 */
-(void) remoteIdentityTransferStarted:(ChatSealRemoteIdentity *) identity
{
    if (delegate && [delegate respondsToSelector:@selector(remoteIdentityTransferStarted:)]) {
        [delegate performSelector:@selector(remoteIdentityTransferStarted:) withObject:identity];
    }
}

/*
 *  The seal transfer has failed.
 */
-(void) remoteIdentityTransferFailed:(ChatSealRemoteIdentity *) identity withError:(NSError *) err
{
    if (delegate && [delegate respondsToSelector:@selector(remoteIdentityTransferFailed:withError:)]) {
        [delegate performSelector:@selector(remoteIdentityTransferFailed:withError:) withObject:identity withObject:err];
    }
}

/*
 *  Notify the delegate of transfer progress.
 */
-(void) remoteIdentityTransferProgress:(ChatSealRemoteIdentity *) identity withPercentageDone:(NSNumber *) pctComplete
{
    if (delegate && [delegate respondsToSelector:@selector(remoteIdentityTransferProgress:withPercentageDone:)]) {
        [delegate performSelector:@selector(remoteIdentityTransferProgress:withPercentageDone:) withObject:self withObject:pctComplete];
    }
}

/*
 *  Notify the delegate that import is starting.
 */
-(void) remoteIdentityBeginningImport:(ChatSealRemoteIdentity *)identity
{
    if (delegate && [delegate respondsToSelector:@selector(remoteIdentityBeginningImport:)]) {
        [delegate performSelector:@selector(remoteIdentityBeginningImport:) withObject:self];
    }
}

/*
 *  The seal transfer completed successfully.
 */
-(void) remoteIdentityTransferCompletedSuccessfully:(ChatSealRemoteIdentity *) identity withSealId:(NSString *) sealId
{
    if (delegate && [delegate respondsToSelector:@selector(remoteIdentityTransferCompletedSuccessfully:withSealId:)]) {
        [delegate performSelector:@selector(remoteIdentityTransferCompletedSuccessfully:withSealId:) withObject:identity withObject:sealId];
    }
}

/*
 *  The seal transfer was unnecessary because we already have the seal.
 */
-(void) remoteIdentityTransferCompletedWithDuplicateSeal:(ChatSealRemoteIdentity *) identity withSealId:(NSString *) sealId
{
    if (delegate && [delegate respondsToSelector:@selector(remoteIdentityTransferCompletedWithDuplicateSeal:withSealId:)]) {
        [delegate performSelector:@selector(remoteIdentityTransferCompletedWithDuplicateSeal:withSealId:) withObject:identity withObject:sealId];
    }
}

/*
 *  Return the secure URL used to connect to this identity.
 */
-(NSURL *) secureURL
{
    return [[secureURL retain] autorelease];
}
@end


/*********************************
 ChatSealRemoteIdentity (internal)
 *********************************/
@implementation ChatSealRemoteIdentity (internal)
/*
 *  Discard the secure connection.
 */
-(void) releaseSecureConnection
{
    secConn.delegate = nil;
    [secConn release];
    secConn = nil;
}

/*
 *  The secure connection has completed successfully.
 */
-(void) secureConnectionConnected:(CS_secureConnection *)ioConn
{
    // - validate the behavior of the protocol.
    NSError *tmp = nil;
    if (importState != CS_SRI_CONNECTING) {
        [CS_error fillError:&tmp withCode:CSErrorIdentityImportFailure andFailureReason:@"Invalid post-connection state."];
        [self abortSealImportWithError:tmp];
        return;
    }
    
    // - now send the request for the seal.
    NSData *d = [CS_securePayload sealRequestPayloadForSecureURL:secureURL withError:&tmp];
    if (!d) {
        [CS_error fillError:&tmp withCode:CSErrorIdentityImportFailure andFailureReason:[tmp localizedDescription]];
        [self abortSealImportWithError:tmp];
        return;
    }
    
    if (![secConn sendData:d withError:&tmp]) {
        [CS_error fillError:&tmp withCode:CSErrorIdentityImportFailure andFailureReason:[tmp localizedDescription]];
        [self abortSealImportWithError:tmp];
        return;
    }
    importState = CS_SRI_SENT_REQUEST;
}

/*
 *  The connection is receiving data.
 */
-(void) secureConnectionDataRecvProgress:(CS_secureConnection *)ioConn ofPct:(NSNumber *)pctComplete
{
    if (ioConn == secConn && importState == CS_SRI_SENT_REQUEST) {
        [self remoteIdentityTransferProgress:self withPercentageDone:pctComplete];
    }
}

/*
 *  The secure connection has data that can be retrieved.
 */
-(void) secureConnectionHasData:(CS_secureConnection *)ioConn
{
    // - when we receive data and are not expecting it, we cannot trust the server.
    NSError *tmp = nil;
    if (importState != CS_SRI_SENT_REQUEST) {
        [CS_error fillError:&tmp withCode:CSErrorMaliciousActivity andFailureReason:@"Invalid protocol behavior from the remote device."];
        [self abortSealImportWithError:tmp];
        return;
    }
    
    NSError *tmpDetail = nil;
    NSData *dSealPayload = [secConn checkForDataWithError:&tmpDetail];
    if (!dSealPayload) {
        [CS_error fillError:&tmp withCode:CSErrorSecureTransferFailed andFailureReason:[tmpDetail localizedDescription]];
        [self abortSealImportWithError:tmp];
        return;
    }
    
    NSArray *arrExistingSeals = [ChatSeal availableSealsWithError:&tmpDetail];
    if (!arrExistingSeals) {
        // - it is possible we won't have seals because there is no vault yet.
        if ([ChatSeal hasVault]) {
            [CS_error fillError:&tmp withCode:CSErrorSecureTransferFailed andFailureReason:[tmpDetail localizedDescription]];
            [self abortSealImportWithError:tmp];
            return;
        }
        
        // - no vault, so just ignore the error.
        arrExistingSeals = [NSArray array];
    }
    
    // - parse the payload
    CS_secureSealTransferPayload *stp = [CS_securePayload parseSealTransferPayload:dSealPayload withError:&tmp];
    if (!stp) {
        [self abortSealImportWithError:tmp];
        return;
    }
    
    // - the import has to occur in an operation queue to ensure that it doesn't block the main thread
    //   during the expensive vault operations.
    [self manageSealImportWithExistingSeals:arrExistingSeals andTransferData:stp];
}

/*
 *  A failure occurred on the secure connection.
 */
-(void) secureConnectionFailed:(CS_secureConnection *)ioConn
{
    NSError *err = nil;
    if (![secConn isConnectionOKWithError:&err]) {
        [self abortSealImportWithError:err];
    }
}

/*
 *  The secure connection disconnected.
 */
-(void) secureConnectionDisconnected:(CS_secureConnection *)ioConn
{
    // - when the server disconnects, we'll assume everything is done
    if (importState == CS_SRI_RECV_SEAL || importState == CS_SRI_NOTIFY_COMPLETE) {
        [self releaseSecureConnection];        
        if (sealExists) {
            [self remoteIdentityTransferCompletedWithDuplicateSeal:self withSealId:[[importedSealId retain] autorelease]];
        }
        else {
            [self remoteIdentityTransferCompletedSuccessfully:self withSealId:[[importedSealId retain] autorelease]];
        }
    }
    else if (importState == CS_SRI_IMPORTING_SEAL) {
        //  do nothing, we're waiting on our end and technically we can consider this completed if it works.
    }
    else {
        NSError *err = nil;
        [CS_error fillError:&err withCode:CSErrorSecureTransferFailed andFailureReason:@"Server abort."];
        [self abortSealImportWithError:err];
    }
}

/*
 *  Abort the seal import process and report an error through the delegate.
 */
-(void) abortSealImportWithError:(NSError *) err
{
    // - if we already got the seal, we're not going to worry about reporting failures since
    //   we have what we need.  The remainder of the protocol exchange is only used by
    //   the server to keep its seal identity up to date.
    [self releaseSecureConnection];
    if (importState == CS_SRI_RECV_SEAL || importState == CS_SRI_NOTIFY_COMPLETE) {
        // - perform the default behavior when we disconnect cleanly.
        [self secureConnectionDisconnected:secConn];
    }
    else {
        [self remoteIdentityTransferFailed:self withError:err];
    }
}

/*
 *  Return the internal secure connection
 *  - this is just intended for testing.
 */
-(CS_secureConnection *) secureConnection
{
    return [[secConn retain] autorelease];
}

/*
 *  The connection timer has fired.
 */
-(void) timerFired:(UITimer *) timer
{
    BOOL timeout = NO;
    
    // - first figure out how much time has elapsed.
    NSTimeInterval ti = [secConn timeIntervalSinceConnection];
    if ((int) ti == 0) {
        // - the connection is invalid somehow.
        timeout = YES;
    }
    
    // - don't permit timeouts during import because that is happening
    //   inside an operation queue and interacting with our own vault.
    if (importState == CS_SRI_IMPORTING_SEAL) {
        return;
    }
    
    // - now figure out whether we should time out based on the import state
    // - the goal here is to not have an absolute time for the whole thing, but
    //   instead treat each stage more or less separately so that we are guaranteed to
    //   make some gradual progress
    switch (importState) {
        case CS_SRI_CONNECTING:
            if (ti > 15.0f) {
                timeout = YES;
            }
            break;
            
        case CS_SRI_SENT_REQUEST:
            if (ti > 25.0f) {
                timeout = YES;
            }
            break;
            
        case CS_SRI_RECV_SEAL:
            if (ti > 35.0f) {
                timeout = YES;
            }
            break;
            
        case CS_SRI_NOTIFY_COMPLETE:
            if (ti > 45.0f) {
                timeout = YES;
            }
            break;
            
        default:
            //  - ignore because this is probably an error.
            break;
    }
    
    if (timeout && secConn) {
        NSLog(@"CS: Remote identity timeout (state=%d).", importState);
        [self releaseSecureConnection];
        if (importState == CS_SRI_NOTIFY_COMPLETE) {
            // - we'll treat this as a success here because it technically is at this point.
            if (sealExists) {
                [self remoteIdentityTransferCompletedWithDuplicateSeal:self withSealId:importedSealId];
            }
            else {
                [self remoteIdentityTransferCompletedSuccessfully:self withSealId:importedSealId];
            }
        }
        else {
            NSError *err = nil;
            [CS_error fillError:&err withCode:CSErrorIdentityImportFailure andFailureReason:@"Connection timeout."];
            [self remoteIdentityTransferFailed:self withError:err];
        }
    }
}

/*
 *  Handle the seal import processing, which occurs in the global vault operation queue.
 */
-(void) manageSealImportWithExistingSeals:(NSArray *) arrExistingSeals andTransferData:(CS_secureSealTransferPayload *) stp
{
    importState = CS_SRI_IMPORTING_SEAL;
    [self remoteIdentityBeginningImport:self];

    // - I don't really intend this operation to ever be cancelled because once we have a seal, we might as well try
    //   our best to import it.  Therefore, I'm not tracking the operation.
    [[ChatSeal vaultOperationQueue] addOperationWithBlock:^(void) {
        // - perform the import.
        NSError *tmp          = nil;
        NSString *sidImported = [ChatSeal importSealFromData:stp.sealData withPassword:[CS_securePayload commonExportKey] andError:&tmp];
        [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
            if (!sidImported) {
                [self abortSealImportWithError:tmp];
                return;
            }
            
            importedSealId = [sidImported retain];
            
            // - mark the completion state (did the seal exist?)
            if ([arrExistingSeals containsObject:sidImported]) {
                sealExists = YES;
            }
            
            // - make sure the global transfer state reflects this success
            [ChatSeal setSealTransferCompleteIfNecessary];
            
            // - we officially have the seal with this object.
            importState = CS_SRI_RECV_SEAL;
            
            // - update the owner name, but the identity is currently being cached potentially
            //   so we might need to wait for a moment.
            // - the identity wasn't cached yet, so we need to wait on the pending operations in the
            //   queue until it finishes.
            ChatSealIdentity * (^updateIdentityBlock)(NSArray *arrOwnerFeeds) = ^(NSArray *arrOwnerFeeds) {
                ChatSealIdentity *cachedIdentity = [ChatSeal identityForSeal:sidImported withError:nil];
                if (cachedIdentity) {
                    if ([cachedIdentity setOwnerName:stp.sealOwner ifBeforeDate:nil]) {
                        // - the owner was updated, so we should recache messages to ensure
                        //   the text of the owner name is updated.
                        [ChatSealMessage recacheMessagesForSealId:sidImported];
                    }
                    [self manageSealConfirmationResposeWithIdentity:cachedIdentity];
                    [cachedIdentity updateFriendFeedLocations:arrOwnerFeeds];
                    
                    // - if we previously ignored a friend, passing a seal back again will reverse that.
                    NSArray *arrAllLocs = [cachedIdentity friendFeedLocations];
                    [[ChatSeal applicationFeedCollector] restoreFriendsInLocations:arrAllLocs];
                    
                    // - those locations may hold context about where to find content, so let the collector sort them out.
                    [[ChatSeal applicationFeedCollector] processReceivedFeedLocations:arrOwnerFeeds];                    
                }
                return cachedIdentity;
            };
            
            // ...try an immediate request for it before resorting to using the operation queue.
            if (!updateIdentityBlock(stp.sealOwnerFeeds)) {
                NSBlockOperation *bo = [NSBlockOperation blockOperationWithBlock:^(void) {
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
                        updateIdentityBlock(stp.sealOwnerFeeds);
                    }];
                }];
                NSArray *arr = [[ChatSeal vaultOperationQueue] operations];
                for (NSOperation *op in arr) {
                    [bo addDependency:op];
                }
                [[ChatSeal vaultOperationQueue] addOperation:bo];
            }
        }];
    }];
}

/*
 *  Once a seal has been fully imported and cached, we'll respond back to the server with the final state
 */
-(void) manageSealConfirmationResposeWithIdentity:(ChatSealIdentity *) identity
{
    // - build a response and send it back to the server
    // - I'd considered only doing this for a new seal, but my intent is to
    //   not divulge anything special about this exchange by adding conditional steps to the protocol.
    NSError *tmpDetail = nil;
    NSError *tmp = nil;
    NSData *dReply = [CS_securePayload sealReceiptPayloadForSecureURL:secureURL andReplyAsNew:!sealExists withError:&tmpDetail];
    if (!dReply || ![secConn sendData:dReply withError:&tmpDetail]) {
        [CS_error fillError:&tmp withCode:CSErrorSecureTransferFailed andFailureReason:[tmpDetail localizedDescription]];
        [self abortSealImportWithError:tmp];
        return;
    }
    importState = CS_SRI_NOTIFY_COMPLETE;
}

@end

/*********************************
 ChatSealRemoteIdentity (shared)
 *********************************/
@implementation ChatSealRemoteIdentity (shared)
/*
 *  Common initialization
 */
-(id) initCommon
{
    self = [super init];
    if (self) {
        importState = CS_SRI_NOT_STARTED;
        secConn     = nil;
        secureURL   = nil;
        sealExists  = NO;
        uitTimeout  = nil;
    }
    return self;
}

/*
 *  Initialize the object.
 */
-(id) initWithService:(CS_service *) service andURL:(NSURL *) url
{
    self = [self initCommon];
    if (self) {
        secureURL        = [url retain];
        secConn          = [[CS_secureConnection alloc] initWithConnectionToService:service usingPassword:url.query];
        secConn.delegate = self;
    }
    return self;
}
@end