//
//  CS_basicIOConnection.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/23/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#include <sys/socket.h>
#import "CS_basicIOConnection.h"
#import "CS_serviceRadar.h"
#import "ChatSeal.h"
#import "CS_serviceResolved.h"

// - constants
static const NSUInteger CS_BOI_READ_BLOCK_SIZE     = (16 * 1024);
static const NSUInteger CS_BIO_MAX_REQUEST_PAYLOAD = (512 * 1024);

// - types
typedef enum {
    CS_BIO_CS_DISCONNECTED = 0,
    CS_BIO_CS_INIT         = 1,
    CS_BIO_CS_RESOLVED     = 2,
    CS_BIO_CS_CONNECTED    = 3,
    CS_BIO_CS_DATA         = 4,
    CS_BIO_CS_CLOSED       = 5
} phs_bio_connection_state_t;


// - forward declarations
@interface CS_basicIOConnection (internal) <NSStreamDelegate, CS_serviceResolvedDelegate>
-(BOOL) setErrorStateTo:(NSError *) err andReturnInValue:(NSError **) ret;
-(void) configureReadStream:(CFReadStreamRef) readStream andWriteStream:(CFWriteStreamRef) writeStream;
-(BOOL) tryToSendPendingDataWithError:(NSError **) err;
-(BOOL) tryToReadIncomingDataWithError:(NSError **) err;
-(void) markClosedConnection;
-(BOOL) sendUnlimitedData:(NSData *) d withError:(NSError **) err;
-(BOOL) isStreamConnected:(NSStream *) stream;
-(BOOL) sendRawData:(NSData *) d withError:(NSError **) err;
@end

/*************************
 CS_basicIOConnection
 *************************/
@implementation CS_basicIOConnection
/*
 *  Object attributes
 */
{
    phs_bio_connection_state_t connectionState;
    NSError                    *lastError;
    CS_service                 *service;
    CS_serviceResolved         *serviceResolved;
    int                        socketExisting;
    uint16_t                   localPort;
    NSOutputStream             *osWrite;
    NSInputStream              *isRead;
    NSDate                     *dtConnected;
    NSMutableData              *mdPendingOutput;
    NSUInteger                 actualPartialCount;
    NSMutableData              *mdPartialRead;
    NSMutableArray             *maReadBlocks;
    NSUInteger                 totalDataToSend;
    NSUInteger                 dataSent;
}
@synthesize delegate;

/*
 *  The size of a single block when reading content.
 */
+(NSUInteger) ioBlockSize
{
    return CS_BOI_READ_BLOCK_SIZE;
}

/*
 *  Return the maximum size a payload request can be.
 */
+(NSUInteger) maximumPayload
{
    return CS_BIO_MAX_REQUEST_PAYLOAD;
}

/*
 *  Initialize the object, assigning default values.
 */
-(id) initCommon
{
    self = [super init];
    if (self) {
        connectionState     = CS_BIO_CS_DISCONNECTED;
        lastError           = nil;
        service             = nil;
        serviceResolved     = nil;
        osWrite             = nil;
        isRead              = nil;
        socketExisting      = -1;
        localPort           = 0;
        dtConnected         = nil;
        mdPendingOutput     = [[NSMutableData alloc] init];
        actualPartialCount  = 0;
        totalDataToSend     = 0;
        dataSent            = 0;
        mdPartialRead       = [[NSMutableData alloc] init];
        maReadBlocks        = [[NSMutableArray alloc] init];
    }
    return self;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    return [self initCommon];
}

/*
 *  Initialize the object.
 */
-(id) initWithConnectionToService:(CS_service *) svc
{
    self = [self initCommon];
    if (self) {
        service = [svc retain];
    }
    return self;
}

/*
 *  Initialize the object.
 */
-(id) initWithSocket:(int) fd
{
    self = [self initCommon];
    if (self) {
        socketExisting = fd;
    }
    return self;
}

/*
 *  Initialize the object.
 */
-(id) initLocalConnectionWithPort:(uint16_t) port
{
    self = [self initCommon];
    if (self) {
        localPort = port;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    delegate = nil;
    
    [self disconnect];

    [serviceResolved release];
    serviceResolved = nil;
    
    [service release];
    service = nil;
    
    [lastError release];
    lastError = nil;
    
    [mdPendingOutput release];
    mdPendingOutput = nil;
    
    [mdPartialRead release];
    mdPartialRead = nil;
    
    [maReadBlocks release];
    maReadBlocks = nil;
    
    [super dealloc];
}

/*
 *  Connect using the defined attributes.
 */
-(BOOL) connectWithError:(NSError **) err
{
    // - one chance to make this work.
    NSError *tmp = nil;
    if (connectionState != CS_BIO_CS_DISCONNECTED) {
        [CS_error fillError:&tmp withCode:CSErrorConnectionFailure andFailureReason:@"A connection attempt has already been made."];
        [self setErrorStateTo:tmp andReturnInValue:err];
        return NO;
    }
    connectionState = CS_BIO_CS_INIT;
    
    // - connection depends on what is available.
    // - either it is a Bonjour service or just completing the
    //   initialization to an existing socket file descriptor.
    if (service) {
        //  NOTE:  I tried caching the resolved hosts/ports and found that at least with transient networks, like with Bluetooth, there
        //         would be network instability after a failure.  A network error would result in the whole thing being torn down and
        //         losing access to it.  On the other hand, a re-resolution of the interface could recover it.  In the interest of
        //         reliability, every connection is resolved every time.
        serviceResolved          = [[CS_serviceResolved resolveWithService:service.serviceName andRegType:service.regType andDomain:service.replyDomain
                                                                asBluetooth:service.isBluetooth withIndex:service.interfaceIndex] retain];
        serviceResolved.delegate = self;
        if (![serviceResolved beginResolutionWithError:&tmp]) {
            [self setErrorStateTo:tmp andReturnInValue:err];
            [serviceResolved release];
            serviceResolved = nil;
            return NO;
        }
    }
    else {
        // - there are one of two options, either we have an existing socket or we're
        //   going to connect locally to a known port.
        CFReadStreamRef readStream   = NULL;
        CFWriteStreamRef writeStream = NULL;
        if (socketExisting != -1) {
            CFStreamCreatePairWithSocket(kCFAllocatorDefault, socketExisting, &readStream, &writeStream);
            socketExisting = -1;
        }
        else {
            CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (CFStringRef) @"localhost", localPort, &readStream, &writeStream);
        }

        if (CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue)) {
            [self configureReadStream:readStream andWriteStream:writeStream];
        }
        else {
            CFReadStreamClose(readStream);
            CFRelease(readStream);
            CFWriteStreamClose(writeStream);
            CFRelease(writeStream);
            [CS_error fillError:&tmp withCode:CSErrorConnectionFailure andFailureReason:@"Failed to set auto-close on socket."];
            [self setErrorStateTo:tmp andReturnInValue:err];
            return NO;
        }
    }
    
    dtConnected = [[NSDate date] retain];
    return YES;
}

/*
 *  Disconnect from the remote device.
 */
-(void) disconnect
{
    // - make sure the service resolution stops since it is no longer required.
    [serviceResolved stopResolution];
    
    // - if the socket was never fully opened, we need to be sure
    //   that it is closed or there will be a leak.
    if (socketExisting != -1) {
        shutdown(socketExisting, SHUT_RDWR);
        close(socketExisting);
    }

    isRead.delegate = nil;
    [isRead removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [isRead close];
    [isRead release];
    isRead = nil;

    osWrite.delegate = nil;
    [osWrite removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [osWrite close];
    [osWrite release];
    osWrite = nil;

    [self markClosedConnection];
    
    // - do this last because it may get recursively called to disconnect.
    [self stream:isRead handleEvent:NSStreamEventEndEncountered];
}

/*
 *  Return the amount of time since the connection was formed.
 */
-(NSTimeInterval) timeIntervalSinceConnection
{
    return -[dtConnected timeIntervalSinceNow];
}

/*
 *  Send data through the connection.
 */
-(BOOL) sendData:(NSData *) d withError:(NSError **) err
{
    NSUInteger len = [d length];
    if (!d || len > CS_BIO_MAX_REQUEST_PAYLOAD) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        return NO;
    }
    return [self sendUnlimitedData:d withError:err];
}

/*
 *  Reports whether there is data to be read.
 */
-(BOOL) hasDataForRead
{
    if ([maReadBlocks count]) {
        return YES;
    }
    return NO;
}

/*
 *  Reports whether there is more I/O to be completed on this connection.
 */
-(BOOL) hasPendingIO
{
    if ([mdPendingOutput length]) {
        return YES;
    }
    return NO;
}

/*
 *  Determines if the connection is well-formed and usable.
 */
-(BOOL) isConnectionOKWithError:(NSError **) err
{
    if (lastError) {
        [CS_error fillError:err withCode:lastError.code andFailureReason:[lastError localizedFailureReason]];
        return NO;
    }
    
    if (connectionState == CS_BIO_CS_DISCONNECTED) {
        [CS_error fillError:err withCode:CSErrorConnectionFailure andFailureReason:@"Not yet connected."];
        return NO;
    }
    
    if (connectionState == CS_BIO_CS_CLOSED) {
        [CS_error fillError:err withCode:CSErrorConfigurationFailure andFailureReason:@"Connection is closed."];
        return NO;
    }
    
    return YES;
}

/*
 *  Check whether data exists in the connection.
 */
-(NSData *) checkForDataWithError:(NSError **) err
{
    // - when there is unread data, just return that.
    if ([maReadBlocks count]) {
        NSData *ret = [maReadBlocks objectAtIndex:0];
        [[ret retain] autorelease];
        [maReadBlocks removeObjectAtIndex:0];
        return ret;
    }
    
    // - do a quick check to see if we have problems in the streams
    if (lastError) {
        [CS_error fillError:err withCode:lastError.code andFailureReason:[lastError localizedFailureReason]];
        return nil;
    }
    
    // - just a generic error
    [CS_error fillError:err withCode:CSErrorNetworkReadFailure andFailureReason:@"No data available."];
    return nil;
}

/*
 *  Return whether the connection is complete and available for data access.
 */
-(BOOL) isConnected
{
    if ((connectionState == CS_BIO_CS_CONNECTED || connectionState == CS_BIO_CS_DATA) && !lastError) {
        // - more precise check using the stream itself, which is the final authority.
        if ([self isStreamConnected:isRead] && [self isStreamConnected:osWrite]) {
            return YES;
        }
    }
    return NO;
}

/*
 *  This connection has completed.
 */
-(void) basicConnectionConnected:(CS_basicIOConnection *) ioConn
{
    if (delegate && [delegate respondsToSelector:@selector(basicConnectionConnected:)]) {
        [delegate performSelector:@selector(basicConnectionConnected:) withObject:ioConn];
    }
}

/*
 *  Report progress in receiving data.
 */
-(void) basicConnectionDataRecvProgress:(CS_basicIOConnection *) ioConn ofPct:(NSNumber *) pctComplete
{
    if (delegate && [delegate respondsToSelector:@selector(basicConnectionDataRecvProgress:ofPct:)]) {
        [delegate performSelector:@selector(basicConnectionDataRecvProgress:ofPct:) withObject:ioConn withObject:pctComplete];
    }
}

/*
 *  Report the progress of send data.
 */
-(void) basicConnectionDataSendProgress:(CS_basicIOConnection *) ioConn ofPct:(NSNumber *) pctComplete
{
    if (delegate && [delegate respondsToSelector:@selector(basicConnectionDataSendProgress:ofPct:)]) {
        [delegate performSelector:@selector(basicConnectionDataSendProgress:ofPct:) withObject:ioConn withObject:pctComplete];
    }
}

/*
 *  This connection has data.
 */
-(void) basicConnectionHasData:(CS_basicIOConnection *) ioConn
{
    if (delegate && [delegate respondsToSelector:@selector(basicConnectionHasData:)]) {
        [delegate performSelector:@selector(basicConnectionHasData:) withObject:ioConn];
    }
}

/*
 *  This connection has encountered a failure.
 */
-(void) basicConnectionFailed:(CS_basicIOConnection *) ioConn
{
    if (delegate && [delegate respondsToSelector:@selector(basicConnectionFailed:)]) {
        [delegate performSelector:@selector(basicConnectionFailed:) withObject:ioConn];
    }
}

/*
 *  This connection was disconnected.
 */
-(void) basicConnectionDisconnected:(CS_basicIOConnection *) ioConn
{
    if (delegate && [delegate respondsToSelector:@selector(basicConnectionDisconnected:)]) {
        [delegate performSelector:@selector(basicConnectionDisconnected:) withObject:ioConn];
    }
}

@end


/********************************
 CS_basicIOConnection (internal)
 ********************************/
@implementation CS_basicIOConnection (internal)
/*
 *  Assign the generic error state and return the same in the return value.
 */
-(BOOL) setErrorStateTo:(NSError *) err andReturnInValue:(NSError **) ret;
{
    [lastError release];
    lastError = [err retain];
    if (ret) {
        *ret = err;
    }
    
    // - make sure the delegate knows about the error
    if (err) {
        [self basicConnectionFailed:self];
    }
    return NO;
}


/*
 *  Configure the input/output streams.
 */
-(void) configureReadStream:(CFReadStreamRef) readStream andWriteStream:(CFWriteStreamRef) writeStream
{
    isRead           = (NSInputStream *)readStream;
    isRead.delegate  = self;
    [isRead scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    osWrite          = (NSOutputStream *)writeStream;
    osWrite.delegate = self;
    [osWrite scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    // - open the streams for business.
    [isRead open];
    [osWrite open];
}

/*
 *  All stream-related events are passed through this delegate protocol.
 */
-(void) stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    // - we apparently receive these without an argument for some reason.
    if (!aStream) {
        return;
    }
    
    // - NOTE: I'm grabbing a reference to the stream and this object before I begin processing it because any one of these delegate callbacks
    //   could conceivably force a disconnect or destruction of this object, so I don't want to try to use it after it is gone.
    [[aStream retain] autorelease];
    [[self retain] autorelease];
    
    // - quickly detect errors and report them.
    NSError *tmp = nil;
    if (aStream == isRead || aStream == osWrite) {
        if (eventCode & NSStreamEventErrorOccurred) {
            NSError *streamError = [aStream streamError];
            [CS_error fillError:&tmp withCode:aStream == isRead ? CSErrorNetworkReadFailure : CSErrorNetworkWriteFailure andFailureReason:[streamError description]];
            [self setErrorStateTo:tmp andReturnInValue:nil];
        }
    }
    
    // - connection completed
    if (aStream == isRead || aStream == osWrite) {
        if (eventCode & NSStreamEventOpenCompleted) {
            if (isRead.streamStatus == NSStreamStatusOpen &&
                osWrite.streamStatus == NSStreamStatusOpen &&
                connectionState < CS_BIO_CS_CONNECTED) {
                connectionState = CS_BIO_CS_CONNECTED;
                [self basicConnectionConnected:self];
            }
        }
    }
    
    // - bytes available
    if (aStream == isRead) {
        if (eventCode & NSStreamEventHasBytesAvailable) {
            connectionState = CS_BIO_CS_DATA;
            if (![self tryToReadIncomingDataWithError:&tmp]) {
                [self setErrorStateTo:tmp andReturnInValue:nil];
            }
        }
    }
    
    // - space available.
    if (aStream == osWrite) {
        if (eventCode & NSStreamEventHasSpaceAvailable) {
            connectionState = CS_BIO_CS_DATA;
            if (![self tryToSendPendingDataWithError:&tmp]) {
                [self setErrorStateTo:tmp andReturnInValue:nil];
            }
        }
    }
    
    // - disconnected
    if (aStream == isRead || aStream == osWrite) {
        if (eventCode & NSStreamEventEndEncountered) {
            if (connectionState != CS_BIO_CS_CLOSED) {
                [self markClosedConnection];
                [self basicConnectionDisconnected:self];
            }
        }
    }
}

/*
 *  Try to pass data through the output stream.
 */
-(BOOL) tryToSendPendingDataWithError:(NSError **) err
{
    // - no data to send or we're working on forming the connection.
    if (![mdPendingOutput length] || connectionState == CS_BIO_CS_INIT || connectionState == CS_BIO_CS_RESOLVED || connectionState == CS_BIO_CS_CONNECTED) {
        return YES;
    }
    
    // - if we're in any other state except data, this is an error
    if (connectionState != CS_BIO_CS_DATA) {
        [CS_error fillError:err withCode:CSErrorNetworkWriteFailure andFailureReason:@"The connection is invalid."];
        return NO;
    }
    
    // - alright, try to send as much as possible.
    while ([mdPendingOutput length]) {
        // - no capacity on the write end, then try again later.
        if (![osWrite hasSpaceAvailable]) {
            break;
        }
        
        NSInteger sentLength = [osWrite write:(const uint8_t *) mdPendingOutput.bytes maxLength:[mdPendingOutput length]];
        if (sentLength == -1) {
            [CS_error fillError:err withCode:CSErrorNetworkWriteFailure andFailureReason:@"Unable to send data."];
            return NO;
        }
        
        // - just not enough space, so don't worry about it.
        if (sentLength == 0) {
            break;
        }
        
        dataSent += (NSUInteger) sentLength;
        dataSent = MIN(dataSent, totalDataToSend);
        
        // - we need to restructure the output buffer.
        NSUInteger fullLength = [mdPendingOutput length];
        uint8_t *buf          = (uint8_t *) mdPendingOutput.mutableBytes;
        NSUInteger toMove     = fullLength - (NSUInteger) sentLength;
        if (toMove) {
            memmove(buf, buf + sentLength, toMove);
        }
        [mdPendingOutput setLength:toMove];
        if (totalDataToSend > 0) {
            [self basicConnectionDataSendProgress:self ofPct:[NSNumber numberWithFloat:(float)((CGFloat) dataSent/ (CGFloat) totalDataToSend)]];
        }
    }
    
    // - when we hit 100%, reset the count so that
    //   the next payload has an accurate value.
    if (dataSent == totalDataToSend) {
        dataSent = totalDataToSend = 0;
    }
    
    return YES;
}

/*
 *  Attempt to read data from the input stream.
 */
-(BOOL) tryToReadIncomingDataWithError:(NSError **) err
{
    // - if we're in any other state except data, this is an error
    if (connectionState != CS_BIO_CS_DATA) {
        [CS_error fillError:err withCode:CSErrorNetworkReadFailure andFailureReason:@"The connection is invalid."];
        return NO;
    }

    // - continue to read as long as there is content.
    while ([isRead hasBytesAvailable]) {
        if ([mdPartialRead length] - actualPartialCount < CS_BOI_READ_BLOCK_SIZE) {
            [mdPartialRead setLength:actualPartialCount + CS_BOI_READ_BLOCK_SIZE];
        }
        
        uint8_t *buf      = [mdPartialRead mutableBytes];
        NSInteger numRead = [isRead read:buf + actualPartialCount maxLength:CS_BOI_READ_BLOCK_SIZE];
        if (numRead == -1) {
            [CS_error fillError:err withCode:CSErrorNetworkReadFailure andFailureReason:@"Failure to read data."];
            return NO;
        }
        
        //  - no bytes read usually occurs at the end of the stream
        if (numRead == 0) {
            break;
        }
        
        actualPartialCount += (NSUInteger) numRead;
        
        // - see if we have data buffers to save off.
        BOOL addedData = NO;
        while (actualPartialCount >= sizeof(uint32_t)) {
            uint32_t len = ((uint32_t) buf[0] << 24) | ((uint32_t) buf[1] << 16) | ((uint32_t) buf[2] << 8) | (uint32_t) buf[3];
            // - this is serious and we need to abort right now.
            if (len > CS_BIO_MAX_REQUEST_PAYLOAD) {
                NSError *tmp = nil;
                [CS_error fillError:&tmp withCode:CSErrorMaliciousActivity andFailureReason:@"Client protocol failure (1)."];
                [self setErrorStateTo:tmp andReturnInValue:err];
                [self disconnect];
                return NO;
            }
            
            // - send the status update
            NSUInteger bytesOfCurrent = actualPartialCount - sizeof(uint32_t);
            if (bytesOfCurrent > len) {
                bytesOfCurrent = len;
            }
            [self basicConnectionDataRecvProgress:self ofPct:[NSNumber numberWithFloat:len > 0.0f ? (float)bytesOfCurrent/(float)len : 100.0f]];
            
            // - not enough data yet.
            if (actualPartialCount - sizeof(uint32_t) < len) {
                break;
            }
            
            // - save off a new buffer.
            NSData *dSaved     = [NSData dataWithBytes:buf+sizeof(uint32_t) length:len];
            [maReadBlocks addObject:dSaved];
            addedData          = YES;
            uint32_t toDiscard = sizeof(uint32_t) + len;
            if (toDiscard < actualPartialCount) {
                memmove(buf, buf+toDiscard, actualPartialCount-toDiscard);
            }
            actualPartialCount -= toDiscard;
            [mdPartialRead setLength:actualPartialCount];
        }
        
        //  -only send one of these notifications.
        if (addedData) {
            [self basicConnectionHasData:self];
        }
    }
    
    return YES;
}

/*
 *  Label the connection as closed.
 */
-(void) markClosedConnection
{
    connectionState = CS_BIO_CS_CLOSED;
    [dtConnected release];
    dtConnected = nil;
}

/*
 *  Intentionally don't size-check the data before sending it to aid in testing.
 */
-(BOOL) sendUnlimitedData:(NSData *) d withError:(NSError **) err
{
    // - every payload includes a length prefix to assist with decoding.
    uint32_t len = (uint32_t) [d length];
    uint8_t  lenBuf[4];
    lenBuf[0] = (len >> 24) & 0xFF;
    lenBuf[1] = (len >> 16) & 0xFF;
    lenBuf[2] = (len >> 8)  & 0xFF;
    lenBuf[3] = (len & 0xFF);
    NSMutableData *mdOutput = [NSMutableData dataWithCapacity:len + sizeof(uint32_t)];
    [mdOutput appendBytes:lenBuf length:sizeof(uint32_t)];
    [mdOutput appendData:d];
    
    // - now send out the raw buffer.
    return [self sendRawData:mdOutput withError:err];
}

/*
 *  Append the given data and do not add the length prefix, also provided mainly for testing.
 */
-(BOOL) sendRawData:(NSData *) d withError:(NSError **) err
{
    if (!d) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        return NO;
    }
    
    totalDataToSend += [d length];
    [mdPendingOutput appendData:d];
    // - now see if there is capacity now to send it out.
    NSError *tmp = nil;
    if (![self tryToSendPendingDataWithError:&tmp]) {
        [self setErrorStateTo:tmp andReturnInValue:err];
        return NO;
    }
    return YES;
}

/*
 *  Returns whether the stream is usable.
 */
-(BOOL) isStreamConnected:(NSStream *) stream
{
    NSStreamStatus status = stream.streamStatus;
    if (status == NSStreamStatusOpen    ||
        status == NSStreamStatusReading ||
        status == NSStreamStatusWriting ||
        status == NSStreamStatusAtEnd) {
        return YES;
    }
    return NO;
}

/*
 *  The service was resolved to a host/port successfully.
 */
-(void) serviceResolutionSucceeded:(CS_serviceResolved *)resolve
{
    if (resolve != serviceResolved) {
        NSLog(@"CS: Unexpected service resolution callback.");
        return;
    }
    
    //  - the resolution produced a host
    connectionState    = CS_BIO_CS_RESOLVED;
    
    //  - now attempt to form a connection to the server.
    CFReadStreamRef readStream = NULL;
    CFWriteStreamRef writeStream = NULL;
    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (CFStringRef) serviceResolved.serviceHost, serviceResolved.servicePort, &readStream, &writeStream);
    [self configureReadStream:readStream andWriteStream:writeStream];
}

/*
 *  The service failed to be resolved in the DNS database.
 */
-(void) serviceResolutionFailed:(CS_serviceResolved *)resolve withError:(NSError *)err
{
    [self setErrorStateTo:err andReturnInValue:nil];
}
@end
