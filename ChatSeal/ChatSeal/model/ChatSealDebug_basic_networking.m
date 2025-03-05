//
//  ChatSealDebug_basic_networking.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "ChatSealDebug_basic_networking.h"
#import "ChatSeal.h"
#import "CS_basicServer.h"
#import "CS_basicIOConnection.h"

#define PHSD_USE_GCOV 0
#if PHSD_USE_GCOV
extern void __gcov_flush();
#endif

// - manages the test according to specific parameters.
@interface PHSD_bn_testSession : NSObject
-(id) initWithServer:(CS_basicServer *) bs;
-(void) reset;
-(BOOL) beginTestingSession;
-(void) endTestingSession;
-(BOOL) sendData:(NSData *) d toServer:(BOOL) toServer withError:(NSError **) err;
-(BOOL) sendUnlimitedDataAsync:(NSData *) d toServer:(BOOL) toServer withError:(NSError **) err;
-(BOOL) sendRawDataAsync:(NSData *) d toServer:(BOOL) toServer withError:(NSError **) err;
-(BOOL) sendString:(NSString *) s toServer:(BOOL) toServer withError:(NSError **) err;
-(BOOL) hasDataToRecv;
-(NSData *) recvDataFromServer:(BOOL) fromServer;
-(NSString *) recvStringFromServer:(BOOL) fromServer;
-(BOOL) confirmData:(NSData *) d toServer:(BOOL) toServer;
-(BOOL) confirmString:(NSString *) s toServer:(BOOL) toServer;
-(BOOL) isConnectedToServer:(BOOL) toServer;
-(NSTimeInterval) timeSinceConnectionToServer:(BOOL) toServer;
-(BOOL) areConnectionsOk;
-(NSData *) randomPayloadOfLength:(NSUInteger) len;
-(void) setReportDataEvent:(BOOL) reportData;
@end

// - keep the delegate methods off to the side.
@interface PHSD_bn_testSession (ioDelegate) <CS_basicServerDelegate, CS_basicIOConnectionDelegate>
-(BOOL) pumpTheRunLoop;
@end

// - forward declarations
@interface ChatSealDebug_basic_networking (internal)
+(BOOL) runTestsWithSession:(PHSD_bn_testSession *) session;
@end

// - shared with the basic I/O object to allow for more complete testing.
@interface CS_basicIOConnection (internal)
-(BOOL) sendUnlimitedData:(NSData *) d withError:(NSError **) err;
-(BOOL) sendRawData:(NSData *) d withError:(NSError **) err;
@end

/********************************
 ChatSealDebug_basic_networking
 ********************************/
@implementation ChatSealDebug_basic_networking
/*
 *  Test the behavior of basic networking.
 *  - This test is intended to be run synchronously, but we'll need to be a little creative to
 *    overcome its dependence on the run loop.   
 */
+(void) beginBasicNetworkingTesting
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"NET-DEBUG:  Starting basic network I/O testing.");
    
    // - we are going to run this on a background thread so that it can have its own self-contained
    //   run loop that we can advance ourselves and be sure that this can work on non-main threads
    NSOperationQueue *opQ = [[NSOperationQueue alloc] init];
    NSBlockOperation *bo = [NSBlockOperation blockOperationWithBlock:^(void) {
        NSLog(@"NET-DEBUG:  Creating the server.");
        NSError *err = nil;
        CS_basicServer *bs = [[[CS_basicServer alloc] initWithPort:0] autorelease];
        if (![bs startServerWithError:&err]) {
            NSLog(@"ERROR: Failed to start the server.  %@", [err localizedDescription]);
            return;
        }
        NSLog(@"NET-DEBUG:  The server is listening on port %u.", [bs serverPort]);
        
        PHSD_bn_testSession *session = [[PHSD_bn_testSession alloc] initWithServer:bs];
        if ([ChatSealDebug_basic_networking runTestsWithSession:session]) {
            NSLog(@"NET-DEBUG:  All tests completed successfully.");
        }
        [session release];
    }];
    [opQ addOperation:bo];
    [bo waitUntilFinished];
    [opQ release];
    
    #if PHSD_USE_GCOV
    __gcov_flush();
    #endif
#endif
}
@end


/*******************************************
 ChatSealDebug_basic_networking (internal)
 *******************************************/
@implementation ChatSealDebug_basic_networking (internal)
/*
 *  Verify simple send/receive behavior.
 */
+(BOOL) runTest_01BasicSendRecv:(PHSD_bn_testSession *) session
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"NET-DEBUG:  TEST-01: Basic send/receive testing.");
    [session reset];
    [session setReportDataEvent:YES];
    if (![session beginTestingSession]) {
        return NO;
    }
    
    NSLog(@"NET-DEBUG:  -- verifying connections are OK.");
    if (![session areConnectionsOk]) {
        NSLog(@"ERROR:  The connections are invalid!");
        return NO;
    }
    
    NSTimeInterval tiBeginClient = [session timeSinceConnectionToServer:YES];
    NSTimeInterval tiBeginServer = [session timeSinceConnectionToServer:NO];
    
    NSLog(@"NET-DEBUG:  -- confirming simple I/O works");
    if (![session confirmString:@"Hello" toServer:YES] ||
        ![session confirmString:@"World" toServer:NO]) {
        return NO;
    }
    
    NSLog(@"NET-DEBUG:  -- confirming maximum I/O works");
    NSData *dSample = [session randomPayloadOfLength:[CS_basicIOConnection maximumPayload]-1];
    if (![session confirmData:dSample toServer:YES]) {
        return NO;
    }
    
    NSLog(@"NET-DEBUG:  -- verifying time intervals.");
    if (tiBeginClient > [session timeSinceConnectionToServer:YES] ||
        tiBeginServer > [session timeSinceConnectionToServer:NO]) {
        NSLog(@"ERROR:  The time intervals are invalid.");
        return NO;
    }
    
    [session endTestingSession];
    
    NSLog(@"NET-DEBUG:  -- verifying connections not-OK.");
    if ([session areConnectionsOk]) {
        NSLog(@"ERROR:  The connections are OK and should not be!");
        return NO;
    }
#endif
    return YES;
}

/*
 *  Verify I/O limits
 */
+(BOOL) runTest_02Limits:(PHSD_bn_testSession *) session
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"NET-DEBUG:  TEST-02: Limit testing.");
    [session reset];
    if (![session beginTestingSession]) {
        return NO;
    }
    
    NSLog(@"NET-DEBUG   -- verifying that large buffers are normally rejected during send.");
    NSMutableData *md = [NSMutableData dataWithLength:1024*1024];
    uint8_t *ptr = (uint8_t *) md.mutableBytes;
    for (NSUInteger i = 0; i < [md length]; i++) {
        ptr[i] = (i % 255);
    }
    if ([session sendData:md toServer:YES withError:nil]) {
        NSLog(@"ERROR: The send routine should not have succeeded!");
        return NO;
    }
    
    NSTimeInterval tiConn = [session timeSinceConnectionToServer:YES];
    
    NSLog(@"NET-DEBUG   -- verifying that that the other end will reject large buffers.");
    NSError *err = nil;
    if (![session sendUnlimitedDataAsync:md toServer:YES withError:&err]) {
        NSLog(@"ERROR: Failed to send the unlimited data to the server.  %@", [err localizedDescription]);
        return NO;
    }
    
    while ([session pumpTheRunLoop]) {
        NSTimeInterval tiCur = [session timeSinceConnectionToServer:YES];
        if (tiCur - tiConn > 5.0f) {
            NSLog(@"ERROR: The test is taking too long.");
            return NO;
        }
        
        if (![session areConnectionsOk]) {
            NSLog(@"NET-DEBUG:  -- detected expected failure");
            break;
        }
    }
    
    [session endTestingSession];
#endif
    return YES;
}

/*
 *  Append a length value to the given buffer.
 */
+(void) appendLength:(NSUInteger) len toBuffer:(NSMutableData *) mdBuffer
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    uint8_t lenBuf[4];
    lenBuf[0] = (len >> 24) & 0xFF;
    lenBuf[1] = (len >> 16) & 0xFF;
    lenBuf[2] = (len >> 8)  & 0xFF;
    lenBuf[3] = (len & 0xFF);
    [mdBuffer appendBytes:lenBuf length:sizeof(uint32_t)];
#endif
}

/*
 *  Send the payloads.
 */
+(BOOL) sendAndVerifyPayloadsInArray:(NSArray *) arr fromIndex:(NSUInteger) idx withCount:(NSUInteger) count usingSession:(PHSD_bn_testSession *) session toServer:(BOOL) toServer
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    // - the idea here is to send all the data for a given payload in one big blob to force
    //   the server to split it back apart.  This will require that we immitate the basic I/O
    //   protocol.
    // - this is important because we don't ultimately know how the network transfer will occur and
    //   this will allow us so simulate a staggered exchange.
    NSMutableData *mdBigGroup = [NSMutableData data];
    NSLog(@"NET-DEBUG:  -- sending payload %lu to %lu", (unsigned long) idx, (unsigned long) (idx + count - 1));
    for (NSUInteger i = idx; i < idx + count; i++) {
        NSData *dPayload = [arr objectAtIndex:i];
        
        // - when there is a beginning block, then we're going to send the second half to complete it.
        NSUInteger lenPayload = [dPayload length];
        NSUInteger offset     = 0;
        if (i == idx && idx > 0) {
            offset      = (lenPayload / 2);
            lenPayload -= offset;
        }
        else {
            // - otherwise, add the length on first.
            [ChatSealDebug_basic_networking appendLength:lenPayload toBuffer:mdBigGroup];
        }
        
        // - now the bytes
        const uint8_t *buf = (const uint8_t *) dPayload.bytes;
        [mdBigGroup appendBytes:&(buf[offset]) length:lenPayload];
    }
    
    // - when there are items after this one, we'll also send the first half of the next block to give a partial result.
    if (idx + count < [arr count]) {
        NSData *dPayload = [arr objectAtIndex:idx + count];
        NSUInteger len = [dPayload length];
        [ChatSealDebug_basic_networking appendLength:len toBuffer:mdBigGroup];
        [mdBigGroup appendBytes:dPayload.bytes length:len/2];
    }
    
    // - send it over to the server.
    NSError *err = nil;
    if (![session sendRawDataAsync:mdBigGroup toServer:toServer withError:&err]) {
        NSLog(@"ERROR:  Failed to send the raw payload data to the server.  %@", [err localizedDescription]);
        return NO;
    }
    
    // - now verify everything we sent, with the exception of the little bit extra.
    NSUInteger verifyIdx = idx;
    while ([session pumpTheRunLoop]) {
        if (![session isConnectedToServer:toServer]) {
            NSLog(@"ERROR:  The connection to the server has failed.");
            return NO;
        }
        
        if (![session areConnectionsOk]) {
            NSLog(@"ERROR:  The connections are no longer OK!");
            return NO;
        }
        
        while ([session hasDataToRecv]) {
            NSData *dRecv = [session recvDataFromServer:!toServer];
            if (!dRecv) {
                return NO;
            }
            
            if (verifyIdx >= idx + count) {
                NSLog(@"ERROR:  There is too much data on the receiving end.");
                return NO;
            }
            
            NSData *dPayload = [arr objectAtIndex:verifyIdx];
            if (![dRecv isEqualToData:dPayload]) {
                NSLog(@"ERROR:  The payload at index %lu could not be verified.", (unsigned long) verifyIdx);
                return NO;
            }
            verifyIdx++;
        }
        
        if (verifyIdx == idx + count) {
            break;
        }
    }
#endif
    return YES;
}

/*
 *  Verify multiple-payload support.
 */
+(BOOL) runTest_03MultiPayload:(PHSD_bn_testSession *) session
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"NET-DEBUG:  TEST-03: Multi-payload testing.");
    [session reset];
    [session setReportDataEvent:YES];
    if (![session beginTestingSession]) {
        return NO;
    }
    
    static const NSUInteger  PHSD_MP_NUM_GROUPS = 3;
    NSUInteger blockSize     = [CS_basicIOConnection ioBlockSize];
    NSUInteger maxPayload    = [CS_basicIOConnection maximumPayload];
    NSUInteger payloadInc    = (blockSize + 131) / PHSD_MP_NUM_GROUPS;              //  make it an odd size.
    NSUInteger numIterations = (maxPayload / payloadInc);
    
    NSLog(@"NET-DEBUG:  -- generating %lu random payloads", (unsigned long) numIterations);
    NSMutableArray *maPayloads = [NSMutableArray array];
    for (NSUInteger i = 0; i < numIterations; i++) {
        [maPayloads addObject:[session randomPayloadOfLength:((i + 1) * payloadInc)]];     // don't use exact powers of two to ensure that odd limits are verified.
    }
    
    NSLog(@"NET-DEBUG:  -- sending sending the payloads in %lu groups", (unsigned long) PHSD_MP_NUM_GROUPS);
    NSUInteger toSend   = numIterations / PHSD_MP_NUM_GROUPS;
    NSUInteger curStart = 0;
    for (NSUInteger j = 0; j < PHSD_MP_NUM_GROUPS; j++) {
        if (j == PHSD_MP_NUM_GROUPS - 1) {
            // make sure we get the last collection.
            toSend = numIterations - curStart;
        }
        // - send a group over and wait for it to be successful.
        if (![ChatSealDebug_basic_networking sendAndVerifyPayloadsInArray:maPayloads fromIndex:curStart withCount:toSend usingSession:session toServer:YES]) {
            return NO;
        }
        curStart += toSend;
    }
    
    [session endTestingSession];
#endif
    return YES;
}

/*
 *  Verify that sending a bad length in a payload doesn't screw up the receiving connection.
 */
+(BOOL) runTest_04BadLength:(PHSD_bn_testSession *) session
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"NET-DEBUG:  TEST-04: Bad length testing.");
    [session reset];
    if (![session beginTestingSession]) {
        return NO;
    }
    
    NSLog(@"NET-DEBUG:  -- sending just a few bytes...");
    uint8_t buf[5] = {0x00, 0x00, 0x81, 0x55, 0xFA};
    NSData *d      = [NSData dataWithBytes:buf length:5];
    
    NSError *err = nil;
    if (![session sendRawDataAsync:d toServer:YES withError:&err]) {
        NSLog(@"ERROR:  Failed to send the raw data.  %@", [err localizedDescription]);
        return NO;
    }
    
    NSTimeInterval tiStart  = [session timeSinceConnectionToServer:YES];
    NSTimeInterval tiToWait = 20;
    NSLog(@"NET-DEBUG:  -- polling for a %lu seconds", (unsigned long) tiToWait);
    while ([session pumpTheRunLoop]) {
        if (![session isConnectedToServer:YES]) {
            NSLog(@"ERROR:  The connection to the server has failed.");
            return NO;
        }
        
        if (![session areConnectionsOk]) {
            NSLog(@"ERROR:  The connections are no longer OK!");
            return NO;
        }
       
        if ([session hasDataToRecv]) {
            NSLog(@"ERROR:  The session should never have had data to receive!");
            return NO;
        }
        
        if ([session timeSinceConnectionToServer:YES] - tiStart > tiToWait) {
            break;
        }
    }
    NSLog(@"NET-DEBUG:  -- the session stayed dormant.");
    
    [session endTestingSession];

#endif
    return YES;
}

/*
 *  Verify that a lot of activity back and forth on the connection doesn't cause problems.
 */
+(BOOL) runTest_05LongRun:(PHSD_bn_testSession *) session
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    static NSUInteger PHSD_BN_LONGRUN_ITER     = 1000;
    static NSUInteger PHSD_BN_LONGRUN_PAYLOADS = 100;
    
    NSLog(@"NET-DEBUG:  TEST-05: Long run iteration testing.");
    [session reset];
    if (![session beginTestingSession]) {
        return NO;
    }
    
    NSUInteger maxPayload = [CS_basicIOConnection maximumPayload];
    NSMutableArray *maPayloads = [NSMutableArray array];
    for (NSUInteger lri = 0; lri < PHSD_BN_LONGRUN_ITER; lri++) {
        @autoreleasepool {
            NSLog(@"NET-DEBUG:  -- beginning long run iteration %lu", (unsigned long) lri);
            // - create the payloads
            [maPayloads removeAllObjects];
            for (NSUInteger i = 0; i < PHSD_BN_LONGRUN_PAYLOADS; i++) {
                [maPayloads addObject:[session randomPayloadOfLength:maxPayload/2 + ((NSUInteger) rand() % (maxPayload/4))]];
            }
            
            // - send them back and forth.
            NSLog(@"NET-DEBUG:  -- sending payloads back and forth");
            for (NSUInteger i = 0; i < PHSD_BN_LONGRUN_PAYLOADS; i++) {
                NSData *payload = [maPayloads objectAtIndex:i];
                if (![session confirmData:payload toServer:(i % 2) == 0 ? YES : NO]) {
                    return NO;
                }
            }
            
            // - send them in groups
            NSLog(@"NET-DEBUG:  -- sending groups to server");
            NSUInteger groupSize = PHSD_BN_LONGRUN_PAYLOADS / 15;
            for (NSUInteger i = 0; i < PHSD_BN_LONGRUN_PAYLOADS; i+=groupSize) {
                NSUInteger toSend = groupSize;
                if (i + toSend > PHSD_BN_LONGRUN_PAYLOADS) {
                    toSend = PHSD_BN_LONGRUN_PAYLOADS - i;
                }
                if (![ChatSealDebug_basic_networking sendAndVerifyPayloadsInArray:maPayloads fromIndex:i withCount:toSend usingSession:session toServer:YES]) {
                    return NO;
                }
            }
            
            NSLog(@"NET-DEBUG:  -- sending groups to client");
            for (NSUInteger i = 0; i < PHSD_BN_LONGRUN_PAYLOADS; i+=groupSize) {
                NSUInteger toSend = groupSize;
                if (i + toSend > PHSD_BN_LONGRUN_PAYLOADS) {
                    toSend = PHSD_BN_LONGRUN_PAYLOADS - i;
                }
                if (![ChatSealDebug_basic_networking sendAndVerifyPayloadsInArray:maPayloads fromIndex:i withCount:toSend usingSession:session toServer:YES]) {
                    return NO;
                }
            }
            
            // - send them back and forth.
            NSLog(@"NET-DEBUG:  -- sending payloads back and forth");
            for (NSUInteger i = 0; i < PHSD_BN_LONGRUN_PAYLOADS; i++) {
                NSData *payload = [maPayloads objectAtIndex:i];
                if (![session confirmData:payload toServer:(i % 2) == 0 ? NO : YES]) {
                    return NO;
                }
            }
        }
    }
#endif
    return YES;
}

/*
 *  Begin testing with the provided session object.
 */
+(BOOL) runTestsWithSession:(PHSD_bn_testSession *) session
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    if (![ChatSealDebug_basic_networking runTest_01BasicSendRecv:session] ||
        ![ChatSealDebug_basic_networking runTest_02Limits:session]        ||
        ![ChatSealDebug_basic_networking runTest_03MultiPayload:session]  ||
        ![ChatSealDebug_basic_networking runTest_04BadLength:session]     ||
        ![ChatSealDebug_basic_networking runTest_05LongRun:session]       ||
        NO) {
        return NO;
    }
#endif
    return YES;
}
@end

/*********************************
 PHSD_bn_testSession
 *********************************/
#ifdef CHATSEAL_DEBUGGING_ROUTINES
@implementation PHSD_bn_testSession
/*
 *  Object attributes
 */
{
    BOOL                    inErrorState;
    CS_basicServer         *server;
    
    CS_basicIOConnection   *ioClientToServer;
    CS_basicIOConnection   *ioServerToClient;
    BOOL                    reportData;
}

/*
 *  Initialize the object.
 */
-(id) initWithServer:(CS_basicServer *) bs
{
    self = [super init];
    if (self) {
        inErrorState     = NO;
        server           = [bs retain];
        server.delegate  = self;
        ioClientToServer = nil;
        ioServerToClient = nil;
        reportData       = NO;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [self reset];
    server.delegate = nil;
    [server release];
    server = nil;
    
    [super dealloc];
}

/*
 *  Reset the session for further testing.
 */
-(void) reset
{
    inErrorState = NO;
    reportData   = NO;
    
    ioClientToServer.delegate = nil;
    [ioClientToServer disconnect];
    [ioClientToServer release];
    ioClientToServer = nil;
    
    ioServerToClient.delegate = nil;
    [ioServerToClient disconnect];
    [ioServerToClient release];
    ioServerToClient = nil;
}

/*
 *  Start the testing process, which will create a client and
 *  server connection.
 */
-(BOOL) beginTestingSession
{
    NSError *err = nil;
    if (inErrorState || ioClientToServer || ioServerToClient) {
        NSLog(@"ERROR: Failed to begin the testing session because of an invalid initial state.");
        return NO;
    }
    
    ioClientToServer          = [[CS_basicIOConnection alloc] initLocalConnectionWithPort:server.serverPort];
    ioClientToServer.delegate = self;
    if (![ioClientToServer connectWithError:&err]) {
        NSLog(@"ERROR: Failed to connect the client to the server.  %@", [err localizedDescription]);
        inErrorState = YES;
        return NO;
    }
    
    while ([self pumpTheRunLoop]) {
        if (inErrorState || (ioClientToServer.isConnected && ioServerToClient.isConnected)) {
            break;
        }
    }
    
    return !inErrorState;
}

/*
 *  Complete testing with a clean shutdown of the two halves.
 */
-(void) endTestingSession
{
    [ioClientToServer disconnect];
    
    while ([self pumpTheRunLoop]) {
        if (inErrorState || (!ioClientToServer.isConnected && !ioServerToClient.isConnected)) {
            break;
        }
    }
    
    [ioServerToClient disconnect];    
}

/*
 *  Send data synchronously from one side to the other.
 */
-(BOOL) sendData:(NSData *) d toServer:(BOOL) toServer withError:(NSError **)err
{
    if (inErrorState) {
        NSLog(@"ERROR:  Failed to send while in an error state.");
        return NO;
    }
    
    BOOL ret = YES;
    if (toServer) {
        ret = [ioClientToServer sendData:d withError:err];
    }
    else {
        ret = [ioServerToClient sendData:d withError:err];
    }
    
    if (!ret) {
        return NO;
    }
    
    while ([self pumpTheRunLoop]) {
        if (inErrorState) {
            break;
        }
        
        if (toServer) {
            if ([ioServerToClient hasDataForRead]) {
                break;
            }
        }
        else {
            if ([ioClientToServer hasDataForRead]) {
                break;
            }
        }
    }
    
    return !inErrorState;
}

/*
 *  The point of this method is to quickly send data to the server, but don't pump the run loop because
 *  the test requires more attention there.
 */
-(BOOL) sendUnlimitedDataAsync:(NSData *) d toServer:(BOOL) toServer withError:(NSError **) err
{
    if (inErrorState) {
        NSLog(@"ERROR:  Failed to send while in an error state.");
        return NO;
    }
    
    if (toServer) {
        return [ioClientToServer sendUnlimitedData:d withError:err];
    }
    else {
        return [ioServerToClient sendUnlimitedData:d withError:err];
    }
}

/*
 *  Send a raw data buffer over to the server.
 *  NOTE:  This can cause big problems during decoding if the lengths are not correct!
 */
-(BOOL) sendRawDataAsync:(NSData *) d toServer:(BOOL) toServer withError:(NSError **) err
{
    if (inErrorState) {
        NSLog(@"ERROR:  Failed to send while in an error state.");
        return NO;
    }
    
    if (toServer) {
        return [ioClientToServer sendRawData:d withError:err];
    }
    else {
        return [ioServerToClient sendRawData:d withError:err];
    }
}

/*
 *  Send a string from one side to the other.
 */
-(BOOL) sendString:(NSString *) s toServer:(BOOL) toServer withError:(NSError **)err
{
    return [self sendData:[s dataUsingEncoding:NSASCIIStringEncoding] toServer:toServer withError:err];
}

/*
 *  Checks the connections to see if data is pending.
 */
-(BOOL) hasDataToRecv
{
    if ([ioClientToServer hasDataForRead] || [ioServerToClient hasDataForRead]) {
        return YES;
    }
    return NO;
}

/*
 *  Receive data synchronously from the given entity.
 */
-(NSData *) recvDataFromServer:(BOOL) fromServer
{
    if (inErrorState) {
        NSLog(@"ERROR:  Failed to recv while in an error state.");
        return nil;
    }
    
    NSData *dRet = nil;
    NSError *err = nil;
    if (fromServer) {
        dRet = [ioClientToServer checkForDataWithError:&err];
    }
    else {
        dRet = [ioServerToClient checkForDataWithError:&err];
    }
    
    if (!dRet) {
        NSLog(@"ERROR: Failed to find data when we expected.   %@", [err localizedDescription]);
    }
    return dRet;
}

/*
 *  Receive a string from the given entity.
 */
-(NSString *) recvStringFromServer:(BOOL) fromServer
{
    NSData *d = [self recvDataFromServer:fromServer];
    if (d) {
        @try {
            NSString *s = [[[NSString alloc] initWithData:d encoding:NSASCIIStringEncoding] autorelease];
            return s;
        }
        @catch (NSException *exception) {
            NSLog(@"ERROR:  There was an exception while decoding data from the connection.  %@", [exception description]);
            // do nothing.
        }
    }
    return nil;
}

/*
 *  Confirm that content can be passed successfully between the two ends.
 */
-(BOOL) confirmData:(NSData *) d toServer:(BOOL) toServer
{
    NSError *err = nil;
    if (![self sendData:d toServer:toServer withError:&err]) {
        NSLog(@"ERROR: Failed to send data %@.  %@", toServer ? @"to the server" : @"to the client", [err localizedDescription]);
        inErrorState = YES;
        return NO;
    }
    
    NSData *dRet = [self recvDataFromServer:!toServer];
    if (!dRet) {
        NSLog(@"ERROR: Data was not recieved from the %@ and was expected to be.", toServer ? @"client" : @"server");
        return NO;
    }
    
    if (![d isEqualToData:dRet]) {
        NSLog(@"ERROR: The data blocks are not equal!");
        return NO;
    }
    
    return !inErrorState;
}

/*
 *  Confirm that content can be passed successfully between the two ends.
 */
-(BOOL) confirmString:(NSString *) s toServer:(BOOL) toServer
{
    return [self confirmData:[s dataUsingEncoding:NSASCIIStringEncoding] toServer:toServer];
}

/*
 *  Determine the connection state.
 */
-(BOOL) isConnectedToServer:(BOOL) toServer
{
    if (toServer) {
        return [ioClientToServer isConnected];
    }
    else {
        return [ioServerToClient isConnected];
    }
}

/*
 *  Figure out how long we've been connected.
 */
-(NSTimeInterval) timeSinceConnectionToServer:(BOOL) toServer
{
    if (toServer) {
        return [ioClientToServer timeIntervalSinceConnection];
    }
    else {
        return [ioServerToClient timeIntervalSinceConnection];
    }
}

/*
 *  Do a check on the connections to make sure they are valid.
 */
-(BOOL) areConnectionsOk
{
    if (!inErrorState &&
        [ioClientToServer isConnectionOKWithError:nil] &&
        [ioServerToClient isConnectionOKWithError:nil]) {
        return YES;
    }
    return NO;
}

/*
 *  Return a payload of the given length with random data.
 */
-(NSData *) randomPayloadOfLength:(NSUInteger) len
{
    NSMutableData *mdRet = [NSMutableData dataWithLength:len];
    uint8_t *buf = mdRet.mutableBytes;
    for (NSUInteger i = 0; i < len; i++) {
        buf[i] = (uint8_t) (i % 256);
    }
    return mdRet;
}

/*
 *  Turn reporting on/off for data receipts.
 */
-(void) setReportDataEvent:(BOOL) rd
{
    reportData = rd;
}

@end

/***********************************
 PHSD_bn_testSession (ioDelegate)
 ***********************************/
@implementation PHSD_bn_testSession (ioDelegate)
/*
 *  This method is used to process one group of pending items in the current run loop.
 */
-(BOOL) pumpTheRunLoop
{
    BOOL ret = [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.25f]];
    if (!ret) {
        NSLog(@"ERROR: Unexpected runloop pump failure!");
    }
    return ret;
}

/*
 *  A new connection is available to the client.
 */
-(void) connectionReceived:(CS_basicIOConnection *)conn inServer:(CS_basicServer *)server
{
    NSLog(@"NET-DEBUG:  -- accept connection in the server");
    if (ioServerToClient) {
        NSLog(@"ERROR: An existing connection already exists.");
        inErrorState = YES;
        return;
    }
    ioServerToClient          = [conn retain];
    ioServerToClient.delegate = self;
    
    NSError *err = nil;
    if (![ioServerToClient connectWithError:&err]) {
        NSLog(@"ERROR: Failed to fully open the server connection to the client.  %@" , [err localizedDescription]);
        inErrorState = YES;
        return;
    }
}

/*
 *  A connection is formed.
 */
-(void) basicConnectionConnected:(CS_basicIOConnection *)ioConn
{
    NSLog(@"NET-DEBUG:  -- connection %@", ioConn == ioClientToServer ? @"client-to-server" : @"server-to-client");
}

/*
 *  A connection failure has occurred.
 */
-(void) basicConnectionFailed:(CS_basicIOConnection *)ioConn
{
    NSLog(@"NET-DEBUG:  -- FAIL from %@", ioConn == ioClientToServer ? @"client-to-server" : @"server-to-client");
    inErrorState = YES;
}

/*
 *  Report the recv progress of the connection.
 */
-(void) basicConnectionDataRecvProgress:(CS_basicIOConnection *)ioConn ofPct:(NSNumber *)pctComplete
{
    if (reportData) {
        if (isnan(pctComplete.floatValue)) {
            NSLog(@"NET-DEBUG: ERROR: Received an invalid percentage value.");
            inErrorState = YES;
        }        
        NSLog(@"NET-DEBUG:  -- data received at %2.2f%%", pctComplete.floatValue * 100.0f);
    }
}

/*
 *  Report the send progress of the connection.
 */
-(void) basicConnectionDataSendProgress:(CS_basicIOConnection *)ioConn ofPct:(NSNumber *)pctComplete
{
    if (reportData) {
        if (isnan(pctComplete.floatValue)) {
            NSLog(@"NET-DEBUG: ERROR: Received an invalid percentage value.");
            inErrorState = YES;
        }
        NSLog(@"NET-DEBUG:  -- data sent at %2.2f%%", pctComplete.floatValue * 100.0f);
    }
}

/*
 *  Report data receipts.
 */
-(void) basicConnectionHasData:(CS_basicIOConnection *)ioConn
{
    if (reportData) {
        NSLog(@"NET-DEBUG:  -- %@ has received data.", ioConn == ioClientToServer ? @"client" : @"server");
    }
}

/*
 *  A connection is broken.
 */
-(void) basicConnectionDisconnected:(CS_basicIOConnection *)ioConn
{
    NSLog(@"NET-DEBUG:  -- disconnected %@", ioConn == ioClientToServer ? @"client-to-server" : @"server-to-client");
}
@end
#endif
