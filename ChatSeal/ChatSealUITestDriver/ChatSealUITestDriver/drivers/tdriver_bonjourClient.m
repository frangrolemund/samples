//
//  tdriver_bonjourClient.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 12/10/14.
//  Copyright (c) 2014 Francis Grolemund. All rights reserved.
//

#import "tdriver_bonjourClient.h"
#import "CS_basicIOConnection.h"

// - constants
static const NSUInteger TBC_NUM_ITERATIONS = 50;

// - forward declarations.
@interface tdriver_bonjourClient (internal)
-(void) advanceTests;
-(void) completeTesting;
@end

@interface tdriver_bonjourClient (network) <CS_basicIOConnectionDelegate>

@end

@implementation tdriver_bonjourClient
/*
 *  Object attributes.
 */
{
    CS_service                          *service;
    id<tdriver_bonjourClientDelegate>   delegate;
    NSUInteger                          count;
    BOOL                                isRunning;
    CS_basicIOConnection                *conn;
    NSUInteger                          dataSeq;
    
}

/*
 *  Returns a sample payload of data.
 */
+(NSData *) sampleDataPayload
{
    NSMutableData *md = [NSMutableData dataWithLength:256*1024];
    SecRandomCopyBytes(kSecRandomDefault, [md length], md.mutableBytes);
    uint32_t sum = 0;
    uint8_t *ptr = (uint8_t *) md.mutableBytes;
    for (NSUInteger i = 0; i < [md length] - sizeof(sum); i++) {
        sum += ptr[i];
    }
    memcpy(&ptr[[md length] - sizeof(sum)], &sum, sizeof(sum));
    return md;
}

/*
 *  Returns whether the payload is valid.
 */
+(BOOL) isPayloadValid:(NSData *) d
{
    uint32_t sum = 0;
    uint8_t *ptr = (uint8_t *) d.bytes;
    for (NSUInteger i = 0; i < [d length] - sizeof(sum); i++) {
        sum += ptr[i];
    }
    uint32_t cmp = 0;
    memcpy(&cmp, &ptr[[d length] - sizeof(cmp)], sizeof(cmp));
    if (sum == cmp) {
        return YES;
    }
    else {
        return NO;
    }
}

/*
 *  Initialize with a given target service.
 */
-(id) initWithService:(CS_service *) svc andDelegate:(id<tdriver_bonjourClientDelegate>) d
{
    self = [super init];
    if (self) {
        service   = [svc retain];
        delegate  = d;
        isRunning = NO;
        dataSeq   = 0;
    }
    return self;
}

-(void) dealloc
{
    [self stopTests];
    
    [service release];
    service = nil;
    
    [conn release];
    conn = nil;
    
    [super dealloc];
}

/*
 *  Hammer the service with connectivity/data transfer tests.
 */
-(void) runTests
{
    if (isRunning) {
        return;
    }
    
    NSData *d = [tdriver_bonjourClient sampleDataPayload];
    if (![tdriver_bonjourClient isPayloadValid:d]) {
        NSLog(@"ERROR: the basic payload support is broken.");
        [self completeTesting];
        return;
    }
    [self advanceTests];
}

/*
 *  Complete the tests.
 */
-(void) stopTests
{
    delegate  = nil;
    isRunning = NO;
    
    [conn disconnect];
    [conn release];
    conn = nil;
}
@end

/*********************************
 tdriver_bonjourClient (internal)
 *********************************/
@implementation tdriver_bonjourClient (internal)

/*
 *  Move the tests forward.
 */
-(void) advanceTests
{
    isRunning = YES;
    if (!conn) {
        // - when we've run our course, time to stop.
        if (count > TBC_NUM_ITERATIONS) {
            [self completeTesting];
            return;
        }
        
        count++;
        conn = [[CS_basicIOConnection alloc] initWithConnectionToService:service];
        NSLog(@"NOTICE: Creating connection %u (%p)...", (unsigned) count, conn);
        conn.delegate = self;
        NSError *err = nil;
        if (![conn connectWithError:&err]) {
            NSLog(@"ERROR: failed to connect to the service.  %@", [err localizedDescription]);
            [self completeTesting];
            return;
        }        
    }
}

/*
 *  Finish the testing and notify the delegate.
 */
-(void) completeTesting
{
    [conn disconnect];
    [conn release];
    conn = nil;
    
    if (delegate) {
        [delegate performSelector:@selector(testingCompletedWithClient:) withObject:self];
    }
    [self stopTests];
    NSLog(@"NOTICE: All testing has been stopped.");
}

@end

/******************************
 tdriver_bonjourClient (network)
 ******************************/
@implementation tdriver_bonjourClient (network)
/*
 *  A connection has been made.
 */
-(void) basicConnectionConnected:(CS_basicIOConnection *) ioConn
{
    NSData *dPayload = [tdriver_bonjourClient sampleDataPayload];
    NSError *err = nil;
    if (![conn sendData:dPayload withError:&err]) {
        NSLog(@"ERROR: failed to send payload data on %p.  %@", ioConn, [err localizedDescription]);
        [self completeTesting];
        return;
    }
}

/*
 *  The connection has a payload.
 */
-(void) basicConnectionHasData:(CS_basicIOConnection *)ioConn
{
    NSError *err = nil;
    NSData *d = [ioConn checkForDataWithError:&err];
    if (!d) {
        NSLog(@"ERROR: failed to receive known data from the connection %p.  %@", ioConn, [err localizedDescription]);
        [self completeTesting];
        return;
    }
    
    if (![tdriver_bonjourClient isPayloadValid:d]) {
        NSLog(@"ERROR: the received data payload from the connection %p is invalid.", ioConn);
        [self completeTesting];
        return;
    }
    
    NSLog(@"NOTICE: the server sent a good return payload on connection %p", ioConn);
    [conn disconnect];
    [conn release];
    conn = nil;
    [self advanceTests];
}

/*
 *  Data has been received.
 */
-(void) basicConnectionDataRecvProgress:(CS_basicIOConnection *)ioConn ofPct:(NSNumber *)pctComplete
{
    NSLog(@"NOTICE: connection %p receiving data at %d%%.", ioConn, (int) (pctComplete.floatValue * 100.0f));
}

/*
 *  Data is being sent.
 */
-(void) basicConnectionDataSendProgress:(CS_basicIOConnection *)ioConn ofPct:(NSNumber *)pctComplete
{
    NSLog(@"NOTICE: connection %p sending data at %d%%.", ioConn, (int) (pctComplete.floatValue * 100.0f));
}

/*
 *  The connection has failed.
 */
-(void) basicConnectionFailed:(CS_basicIOConnection *) ioConn
{
    NSLog(@"ERROR: connection has failed!");
    [self completeTesting];
}

/*
 *  The connection has been disconnected.
 */
-(void) basicConnectionDisconnected:(CS_basicIOConnection *) ioConn
{
    NSLog(@"ERROR: Connection %p has disconnected.", ioConn);
    [self completeTesting];
}

@end
