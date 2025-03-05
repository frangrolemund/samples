//
//  ChatSealDebug_seal_networking.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/23/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "ChatSealDebug_seal_networking.h"
#import "ChatSeal.h"
#import "ChatSealBaseStation.h"
#import "CS_securePayload.h"
#import "CS_secureConnection.h"

// - constants
#ifdef CHATSEAL_DEBUGGING_ROUTINES
static const NSUInteger PHSD_STD_TEST_TIMEOUT = 60;
#endif

// - forward declarations
@interface ChatSealDebug_seal_networking (internal)
+(BOOL) beginSealClientRequestTesting;
@end

// - track changes in progress.
@interface PHSD_identity_delegate : NSObject <ChatSealRemoteIdentityDelegate>
-(id) initWithReporting:(BOOL) doReporting;
-(BOOL) isSuccess;
-(BOOL) isFailure;
@end

// - testing APIs.
@interface ChatSealRemoteIdentity (internal)
-(CS_secureConnection *) secureConnection;
@end

// - testing APIs.
@interface CS_secureConnection (internal)
-(BOOL) sendUnlimitedUnencryptedData:(NSData *) d withError:(NSError **) err;
@end

/******************************
 ChatSealDebug_seal_networking
 ******************************/
@implementation ChatSealDebug_seal_networking

/*
 *  This test is intended to begin the process of hitting the server beacon and acquiring 
 *  copies of the seal repeatedly and with inserted disruptions to test its reliability during
 *  attack.
 */
+(void) beginSealExchangeTesting
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"NET-DEBUG:  Starting seal exchange testing.");
    if ([ChatSealDebug_seal_networking beginSealClientRequestTesting]) {
        NSLog(@"NET-DEBUG:  All tests completed successfully.");
    }
#endif
}
@end

/*****************************************
 ChatSealDebug_seal_networking (internal)
 *****************************************/
@implementation ChatSealDebug_seal_networking (internal)
/*
 *  Pump the main runloop once to advance the async networking.
 */
+(BOOL) pumpTheRunLoop
{
    return [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.25f]];
}

/*
 *  Promote the active seal for distribution.
 */
+(BOOL) runTest_1PromoteSeal
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSString *activeSeal = [ChatSeal activeSeal];
    if (!activeSeal) {
        NSLog(@"ERROR:  An active seal is required to test seal exchange.");
        return NO;
    }
    
    NSLog(@"NET-DEBUG:  TEST-01:  Promoting the active seal %@.", activeSeal);
    NSError *err = nil;
    if (![[ChatSeal applicationBaseStation] setPromotedSeal:activeSeal withError:&err]) {
        NSLog(@"ERROR:  Failed to promote the active seal.  %@", [err localizedDescription]);
        return NO;
    }
    
    // - wait for the beacon to come online.
    NSLog(@"NET-DEBUG:  -- waiting for beacon online.");
    while ([ChatSealDebug_seal_networking pumpTheRunLoop]) {
        if ([[ChatSeal applicationBaseStation] isBroadcastingSuccessfully]) {
            break;
        }
    }
#endif
    return YES;
}
/*
 *  Verify request payload validation.
 */
+(BOOL) runTest_2VerifyPayload
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    @autoreleasepool {
        NSLog(@"NET-DEBUG:  TEST-02:  Verifying payload validation.");
        NSURL *uExported = [[ChatSeal applicationBaseStation] secureSealTransferURL];
        if (!uExported) {
            NSLog(@"ERROR:  Failed to receive a valid transfer url.");
            return NO;
        }
        
        NSError *err     = nil;
        NSData *dRequest = [CS_securePayload sealRequestPayloadForSecureURL:uExported withError:&err];
        if (!dRequest) {
            NSLog(@"ERROR:  Failed to generate a good payload.  %@", [err localizedDescription]);
            return NO;
        }
        
        if (![CS_securePayload isSealRequestPayload:dRequest validForURL:uExported]) {
            NSLog(@"ERROR:  The payload could not be verified!");
            return NO;
        }
        
        NSMutableData *mdAlt = [NSMutableData dataWithData:dRequest];
        uint8_t *req         = (uint8_t *) [mdAlt mutableBytes];
        req[1]               = ~req[1];
        
        if ([CS_securePayload isSealRequestPayload:mdAlt validForURL:uExported]) {
            NSLog(@"ERROR:  The payload was valid and shouldn't have been!");
            return NO;
        }
        
        req[1]               = ~req[1];
        if (![CS_securePayload isSealRequestPayload:mdAlt validForURL:uExported]) {
            NSLog(@"ERROR:  The payload was should have been valid but wasn't after being fixed!");
            return NO;
        }
        
        // - verify we get random behavior each time.
        NSData *dAltRequest = [CS_securePayload sealRequestPayloadForSecureURL:uExported withError:&err];
        if (!dAltRequest) {
            NSLog(@"ERROR: Failed to generate an alternate payload.  %@", [err localizedDescription]);
            return NO;
        }
        
        if ([dRequest isEqualToData:dAltRequest]) {
            NSLog(@"ERROR: The alternate payload is somehow equal to the original!");
            return NO;
        }        
    }
#endif
    return YES;
}

/*
 *  Perform a single seal transfer operation.
 */
+(BOOL) connectAndConfirmSealTransferWithReporting:(BOOL) doReport
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    @autoreleasepool {
        NSURL *uExported = [[ChatSeal applicationBaseStation] secureSealTransferURL];
        if (!uExported) {
            NSLog(@"ERROR:  Failed to receive a valid transfer url.");
            return NO;
        }
        
        if (doReport) {
            NSLog(@"NET-DEBUG:  -- connecting to the remote server.");
        }
        NSError *err                      = nil;
        PHSD_identity_delegate *idDel     = [[[PHSD_identity_delegate alloc] initWithReporting:doReport] autorelease];
        ChatSealRemoteIdentity *remoteId = [[ChatSeal applicationBaseStation] connectForSecureSealTransferWithURL:uExported andError:&err];
        if (!remoteId) {
            NSLog(@"ERROR:  Failed to connect to the remote server.  %@.", [err localizedDescription]);
            return NO;
        }
        remoteId.delegate                 = idDel;
        if (![remoteId beginSecureImportProcessing:&err]) {
            NSLog(@"ERROR:  Failed to begin the secure import processing.");
            return NO;
        }
        [remoteId retain];
        
        // - now simulate the activity of the runloop
        while ([ChatSealDebug_seal_networking pumpTheRunLoop]) {
            if ([remoteId isComplete] && ![idDel isFailure]) {
                break;
            }
        }
        [remoteId release];
        
        // - figure out whether this was a success or failure.
        if ([idDel isFailure]) {
            NSLog(@"ERROR:  The transfer failed!");
            return NO;
        }
        
        // - make sure the secure URL has changed.
        NSURL *uNewExported = [[ChatSeal applicationBaseStation] secureSealTransferURL];
        if (!uNewExported) {
            NSLog(@"ERROR:  Failed to receive a valid transfer url.");
            return NO;
        }
        if ([uExported isEqual:uNewExported]) {
            NSLog(@"ERROR:  The export URL was not changed after the test completed.");
            return NO;
        }
    }
#endif
    return YES;
}

/*
 *  Request a single seal.
 */
+(BOOL) runTest_3SimpleRequest
{
    BOOL ret = YES;
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"NET-DEBUG:  TEST-03:  Requesting a single seal.");
    ret = [ChatSealDebug_seal_networking connectAndConfirmSealTransferWithReporting:YES];
#endif
    return ret;
}

/*
 *  Verify that the server can accept bad URLs.
 *  - this requires that we hack the protocol a bit to get into the server.
 */
+(BOOL) verifyServerWithBadURL
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"NET-DEBUG:  -- verifying the server will reject bad URLs.");
    
    NSURL *uExported = [[ChatSeal applicationBaseStation] secureSealTransferURL];
    if (!uExported) {
        NSLog(@"ERROR:  Failed to receive a valid transfer url.");
        return NO;
    }
    NSError *err     = nil;
    NSData *dRequest = [CS_securePayload sealRequestPayloadForSecureURL:[NSURL URLWithString:@"http://foo.bar"] withError:&err];
    if (!dRequest) {
        NSLog(@"ERROR:  Failed to generate a bogus secure request payload.");
        return NO;
    }
    
    ChatSealRemoteIdentity *remoteId = [[ChatSeal applicationBaseStation] connectForSecureSealTransferWithURL:uExported andError:&err];
    if (!remoteId) {
        NSLog(@"ERROR:  Failed to connect to the remote server.  %@.", [err localizedDescription]);
        return NO;
    }
    
    CS_secureConnection *secConn = [remoteId secureConnection];
    if (![secConn connectWithError:&err]) {
        NSLog(@"ERROR:  Failed to connect to the remote server.  %@", [err localizedDescription]);
        return NO;
    }
    
    if (![secConn sendData:dRequest withError:&err]) {
        NSLog(@"ERROR:  Failed to send the request to the remote server.  %@", [err localizedDescription]);
        return NO;
    }
    
    time_t tBegin = time(NULL);
    [remoteId retain];
    secConn.delegate = nil;
    while ([ChatSealDebug_seal_networking pumpTheRunLoop]) {
        if (![secConn isConnectionOKWithError:nil]) {
            break;
        }
        if (time(NULL) - tBegin > PHSD_STD_TEST_TIMEOUT) {
            [remoteId release];
            NSLog(@"ERROR:  The server failed to respond correctly to the invalid URL request!");
            return NO;
        }
    }
    [remoteId release];
    
    NSURL *uNewExported = [[ChatSeal applicationBaseStation] secureSealTransferURL];
    if (![uExported isEqual:uNewExported]) {
        NSLog(@"ERROR:  The server did not retain the existing transfer URL as expected.");
        return NO;
    }
#endif
    return YES;
}

/*
 *  Verify that the server will recover after receiving a disconnection.
 *  - more protocol hacking.
 */
+(BOOL) verifyServerRequestDisconnect
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"NET-DEBUG:  -- verifying the server will recover after a disconnection.");
    NSURL *uExported = [[ChatSeal applicationBaseStation] secureSealTransferURL];
    if (!uExported) {
        NSLog(@"ERROR:  Failed to receive a valid transfer url.");
        return NO;
    }
    NSError *err     = nil;
    NSData *dRequest = [CS_securePayload sealRequestPayloadForSecureURL:uExported withError:&err];
    if (!dRequest) {
        NSLog(@"ERROR:  Failed to generate a bogus secure request payload.");
        return NO;
    }
    
    ChatSealRemoteIdentity *remoteId = [[ChatSeal applicationBaseStation] connectForSecureSealTransferWithURL:uExported andError:&err];
    if (!remoteId) {
        NSLog(@"ERROR:  Failed to connect to the remote server.  %@.", [err localizedDescription]);
        return NO;
    }
    
    CS_secureConnection *secConn = [remoteId secureConnection];
    if (![secConn connectWithError:&err]) {
        NSLog(@"ERROR:  Failed to connect to the remote server.  %@", [err localizedDescription]);
        return NO;
    }
    
    if (![secConn sendData:dRequest withError:&err]) {
        NSLog(@"ERROR:  Failed to send the request to the remote server.  %@", [err localizedDescription]);
        return NO;
    }
    
    time_t tBegin = time(NULL);
    [remoteId retain];
    secConn.delegate = nil;
    BOOL wasDisconnected = NO;
    while ([ChatSealDebug_seal_networking pumpTheRunLoop]) {
        if (![secConn isConnectionOKWithError:nil] && ![[ChatSeal applicationBaseStation] isSecureTransferInProgress]) {
            break;
        }
        // - once all the data has been sent to the server, we're going to disconnect to
        //   see how it responds.
        if (!wasDisconnected) {
            if ([secConn isConnected]) {
                if (![secConn hasPendingIO] && [[ChatSeal applicationBaseStation] isSecureTransferInProgress]) {
                    [secConn disconnect];
                    wasDisconnected = YES;
                }
            }
        }
        if (time(NULL) - tBegin > PHSD_STD_TEST_TIMEOUT) {
            [remoteId release];
            NSLog(@"ERROR:  The server failed to respond correctly to the valid request with disconnect!");
            return NO;
        }
    }
    [remoteId release];
    
    NSURL *uNewExported = [[ChatSeal applicationBaseStation] secureSealTransferURL];
    if ([uExported isEqual:uNewExported]) {
        NSLog(@"ERROR:  The server did not regenerate the transfer URL as expected.");
        return NO;
    }
#endif
    return YES;
}

/*
 *  Verify that the server can recover after a connection fails (due to a large data buffer).
 * - more protocol hacking.
 */
+(BOOL) verifyServerRequestAttack
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"NET-DEBUG:  -- verifying the server will recover after an invalid buffer is sent.");
    NSURL *uExported = [[ChatSeal applicationBaseStation] secureSealTransferURL];
    if (!uExported) {
        NSLog(@"ERROR:  Failed to receive a valid transfer url.");
        return NO;
    }
    NSError *err     = nil;
    ChatSealRemoteIdentity *remoteId = [[ChatSeal applicationBaseStation] connectForSecureSealTransferWithURL:uExported andError:&err];
    if (!remoteId) {
        NSLog(@"ERROR:  Failed to connect to the remote server.  %@.", [err localizedDescription]);
        return NO;
    }
    
    CS_secureConnection *secConn = [remoteId secureConnection];
    if (![secConn connectWithError:&err]) {
        NSLog(@"ERROR:  Failed to connect to the remote server.  %@", [err localizedDescription]);
        return NO;
    }
    
    NSData *mdInvalidRequest = [NSMutableData dataWithLength:[CS_basicIOConnection maximumPayload] + 1];
    if (![secConn sendUnlimitedUnencryptedData:mdInvalidRequest withError:&err]) {
        NSLog(@"ERROR:  Failed to send the request to the remote server.  %@", [err localizedDescription]);
        return NO;
    }
    
    time_t tBegin = time(NULL);
    [remoteId retain];
    secConn.delegate = nil;
    while ([ChatSealDebug_seal_networking pumpTheRunLoop]) {
        if (![secConn isConnectionOKWithError:nil]) {
            break;
        }
        if (time(NULL) - tBegin > PHSD_STD_TEST_TIMEOUT) {
            [remoteId release];
            NSLog(@"ERROR:  The server failed to respond correctly to the valid request with disconnect!");
            return NO;
        }
    }
    [remoteId release];
    
    NSURL *uNewExported = [[ChatSeal applicationBaseStation] secureSealTransferURL];
    if ([uExported isEqual:uNewExported]) {
        NSLog(@"ERROR:  The server did not regenerate the transfer URL as expected.");
        return NO;
    }
    
    
#endif
    return YES;
}

/*
 *  Verify that the server does the right thing when we attack it with bad content.
 */
+(BOOL) runTest_4VerifyServerRecovery
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"NET-DEBUG:  TEST-04:  Verifying the server can recover from failures and unexpected data.");
    if (![ChatSealDebug_seal_networking verifyServerWithBadURL]  ||
        ![ChatSealDebug_seal_networking verifyServerRequestDisconnect] ||
        ![ChatSealDebug_seal_networking verifyServerRequestAttack]) {
        return NO;
    }
#endif
    return YES;
}

/*
 *  Stop/start the beacon so we can test with a new service registration.
 */
+(BOOL) verifyRecreateBeacon
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSString *activeSeal = [ChatSeal activeSeal];
    if (!activeSeal) {
        NSLog(@"ERROR:  An active seal is required to test seal exchange.");
        return NO;
    }
    
    NSLog(@"NET-DEBUG:  -- Re-promoting the active seal %@.", activeSeal);
    NSError *err = nil;
    if (![[ChatSeal applicationBaseStation] setPromotedSeal:nil withError:&err]) {
        NSLog(@"ERROR:  Failed to un-promote the active seal.  %@", [err localizedDescription]);
        return NO;
    }
    
    // - wait for the beacon to come online.
    while ([ChatSealDebug_seal_networking pumpTheRunLoop]) {
        if ([[ChatSeal applicationBaseStation] isBroadcastingSuccessfully]) {
            break;
        }
    }
    
    if (![[ChatSeal applicationBaseStation] setPromotedSeal:activeSeal withError:&err]) {
        NSLog(@"ERROR:  Failed to un-promote the active seal.  %@", [err localizedDescription]);
        return NO;
    }
    
    // - wait for the beacon to come online.
    while ([ChatSealDebug_seal_networking pumpTheRunLoop]) {
        if ([[ChatSeal applicationBaseStation] isBroadcastingSuccessfully]) {
            break;
        }
    }
    
#endif
    return YES;
}

/*
 *  Verify that long-running testing can be performed on the connection.
 */
+(BOOL) runTest_5VerifyLongRunning
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"NET-DEBUG:  TEST-05:  Verifying that many seals can be distributed with the same active server.");
    for (NSUInteger i = 0; i < 100; i++) {
        @autoreleasepool {
            NSLog(@"NET-DEBUG:  -- starting test iteration %lu", (unsigned long) i);
            if (i > 0 && i % 10 == 0) {
                if (![ChatSealDebug_seal_networking verifyRecreateBeacon]) {
                    return NO;
                }
            }
            
            if (![ChatSealDebug_seal_networking connectAndConfirmSealTransferWithReporting:YES]) {
                return NO;
            }
            
            if (![ChatSealDebug_seal_networking verifyServerRequestAttack]) {
                return NO;
            }
        }
    }
#endif
    return YES;
    
}

/*
 *  Un-promote the active seal.
 */
+(BOOL) runTest_Finish
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSError *err = nil;
    NSLog(@"NET-DEBUG:  TEST-XX:  Turning off seal promotion.");
    if (![[ChatSeal applicationBaseStation] setPromotedSeal:nil withError:&err]) {
        NSLog(@"ERROR:  Failed to un-promote the seal.  %@", [err localizedDescription]);
        return NO;
    }
#endif
    return YES;
}

/*
 *  Start up the asynchonous requests to test client access of the seal vault.
 */
+(BOOL) beginSealClientRequestTesting
{
    BOOL ret = YES;
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    ret = !(![ChatSealDebug_seal_networking runTest_1PromoteSeal]          ||
            ![ChatSealDebug_seal_networking runTest_2VerifyPayload]        ||
            ![ChatSealDebug_seal_networking runTest_3SimpleRequest]        ||
            ![ChatSealDebug_seal_networking runTest_4VerifyServerRecovery] ||
            ![ChatSealDebug_seal_networking runTest_5VerifyLongRunning]    ||
            NO);

    // - always turn off the promotion, regardless of the error state.
    if (![ChatSealDebug_seal_networking runTest_Finish]) {
        ret = NO;
    }
#endif
    return ret;
}
@end

/***************************
 PHSD_identity_delegate
 ***************************/
@implementation PHSD_identity_delegate
/*
 *  Object attributes.
 */
{
    BOOL isReporting;
    BOOL isSuccess;
    BOOL isFailure;
}

/*
 *  Initialize the object.
 */
-(id) initWithReporting:(BOOL) doReporting
{
    self = [super init];
    if (self) {
        isReporting = doReporting;
        isSuccess   = NO;
        isFailure   = NO;
    }
    return self;
}

/*
 *  Returns whether this delegate received a successful completion.
 */
-(BOOL) isSuccess
{
    return isSuccess;
}

/*
 *  Returns whether this delegate received a failure.
 */
-(BOOL) isFailure
{
    return isFailure;
}

/*
 *  When the remote transfer begins, this method is called.
 */
-(void) remoteIdentityTransferStarted:(ChatSealRemoteIdentity *)identity
{
    if (isReporting) {
        NSLog(@"NET-DEBUG:  -- remote transfer has started.");
    }
}

/*
 *  When the remote transfer fails, this method is called.
 */
-(void) remoteIdentityTransferFailed:(ChatSealRemoteIdentity *)identity withError:(NSError *)err
{
    if (isReporting) {
        NSLog(@"NET-DEBUG:  -- remote transfer failed!  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    }
    isFailure = YES;
}

/*
 *  Report transfer progress.
 */
-(void) remoteIdentityTransferProgress:(ChatSealRemoteIdentity *)identity withPercentageDone:(NSNumber *)pctComplete
{
    if (isReporting) {
        NSLog(@"NET-DEBUG:  -- remote transfer is at %02.2f%%", pctComplete.floatValue * 100.0f);
    }
}

/*
 *  Report that the transfer completed.
 */
-(void) remoteIdentityTransferCompletedSuccessfully:(ChatSealRemoteIdentity *)identity withSealId:(NSString *)sealId
{
    if (isReporting) {
        NSLog(@"NET-DEBUG:  -- imported seal %@.", sealId);
    }
    isSuccess = YES;
}

/*
 *  Report that the transfer completed.
 */
-(void) remoteIdentityTransferCompletedWithDuplicateSeal:(ChatSealRemoteIdentity *)identity withSealId:(NSString *)sealId
{
    [self remoteIdentityTransferCompletedSuccessfully:identity withSealId:sealId];
}

@end