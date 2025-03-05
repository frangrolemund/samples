//
//  CS_secureConnection.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/23/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_secureConnection.h"
#import "ChatSeal.h"
#import "CS_serviceRadar.h"
#import "CS_basicIOConnection.h"

// - constants
static const uint16_t CS_SCONN_CRYPTO_VERSION = 1;

// - forward declarations
@interface CS_secureConnection (internal) <CS_basicIOConnectionDelegate>
-(BOOL) sendUnlimitedUnencryptedData:(NSData *) d withError:(NSError **) err;
@end

// - shared interfaces with the consumers of this data.
@interface CS_secureConnection (shared)
-(id) initWithConnectionToService:(CS_service *) svc usingPassword:(NSString *) pwd;
-(id) initWithConnectionToClient:(CS_basicIOConnection *) clientConn usingPassword:(NSString *) pwd;
-(BOOL) fillStandardBadObjectError:(NSError **) err;
@end

// - for testing.
@interface CS_basicIOConnection (internal)
-(BOOL) sendUnlimitedData:(NSData *) d withError:(NSError **) err;
@end

/******************************
 CS_secureConnection
 ******************************/
@implementation CS_secureConnection
/*
 *  Object attributes.
 */
{
    // - the choice to make this an aggregate class was intentional because
    //   the IO connection must be explicitly disconnected before it is released
    //   in order to break the retain loop between it and the runloop where it
    //   operates.   If I inherited, the caller would have to know that, which I
    //   considered to be an unacceptable requirement.
    CS_basicIOConnection *netConnection;
    BOOL                  isServerSide;
    NSString              *password;
}
@synthesize delegate;

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        netConnection = nil;
        isServerSide  = YES;
        password      = nil;
        delegate      = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    delegate = nil;
    netConnection.delegate = nil;
    [netConnection disconnect];
    [netConnection release];
    netConnection = nil;
    
    [password release];
    password = nil;
    
    [super dealloc];
}

/*
 *  Connect to the remote entity.
 */
-(BOOL) connectWithError:(NSError **) err
{
    if (netConnection) {
        return [netConnection connectWithError:err];
    }
    
    // - this should not happen when we initialize the right way.
    [self fillStandardBadObjectError:err];
    return NO;
}

/*
 *  Returns whether the connection is valid.
 */
-(BOOL) isConnectionOKWithError:(NSError **) err
{
    if (netConnection) {
        return [netConnection isConnectionOKWithError:err];
    }
    [self fillStandardBadObjectError:err];
    return NO;
}

/*
 *  Return the elapsed time since the connection was formed.
 */
-(NSTimeInterval) timeIntervalSinceConnection
{
    return [netConnection timeIntervalSinceConnection];
}

/*
 *  Send data through the connection to the other side.
 */
-(BOOL) sendData:(NSData *) d withError:(NSError **) err
{
    if (netConnection) {
        if (!d) {
            [CS_error fillError:err withCode:CSErrorInvalidArgument];
            return NO;
        }
        
        NSError *tmp       = nil;
        NSData *dEncrypted = [RealSecureImage encryptArray:[NSArray arrayWithObject:d] forVersion:CS_SCONN_CRYPTO_VERSION usingPassword:password withError:&tmp];
        if (!dEncrypted) {
            [CS_error fillError:err withCode:CSErrorInvalidSecureRequest andFailureReason:[tmp localizedDescription]];
        }
        
        return [netConnection sendData:dEncrypted withError:err];
    }
    
    // - this should not happen when we initialize the right way.
    [self fillStandardBadObjectError:err];
    return NO;
}

/*
 *  Returns whether there is pending data to retrieve from the connection.
 */
-(BOOL) hasDataForRead
{
    if (netConnection) {
        return [netConnection hasDataForRead];
    }
    return NO;
}

/*
 *  Returns whether there is still data to write to the server.
 */
-(BOOL) hasPendingIO
{
    if (netConnection) {
        return [netConnection hasPendingIO];
    }
    return NO;
}

/*
 *  Returns data if it exists in this connection.
 */
-(NSData *) checkForDataWithError:(NSError **) err
{
    if (netConnection) {
        NSError *tmp = nil;
        NSData *dEncrypted = [netConnection checkForDataWithError:&tmp];
        if (!dEncrypted) {
            [CS_error fillError:err withCode:CSErrorInvalidSecureRequest andFailureReason:[tmp localizedDescription]];
            return nil;
        }

        NSArray *arr = [RealSecureImage decryptIntoArray:dEncrypted forVersion:CS_SCONN_CRYPTO_VERSION usingPassword:password withError:&tmp];
        if (!arr || [arr count] != 1 || ![[arr objectAtIndex:0] isKindOfClass:[NSData class]]) {
            [CS_error fillError:err withCode:CSErrorInvalidSecureRequest andFailureReason:[tmp localizedDescription]];
            return nil;
        }
        
        return (NSData *) [arr objectAtIndex:0];
    }
    
    // - this should not happen when we initialize the right way.
    [self fillStandardBadObjectError:err];
    return nil;
}

/*
 * A full-duplex connection completed.
 */
-(void) secureConnectionConnected:(CS_secureConnection *) ioConn
{
    // - pass it onto our delegate
    if (delegate && [delegate respondsToSelector:@selector(secureConnectionConnected:)]) {
        [delegate performSelector:@selector(secureConnectionConnected:) withObject:ioConn];
    }
}

/*
 *  Data exists on the connection.
 */
-(void) secureConnectionHasData:(CS_secureConnection *) ioConn
{
    // - pass it onto our delegate
    if (delegate && [delegate respondsToSelector:@selector(secureConnectionHasData:)]) {
        [delegate performSelector:@selector(secureConnectionHasData:) withObject:ioConn];
    }
}

/*
 *  Report the data receive transfer progress.
 */
-(void) secureConnectionDataRecvProgress:(CS_secureConnection *) ioConn ofPct:(NSNumber *) pctComplete;
{
    // - pass it onto our delegate
    if (delegate && [delegate respondsToSelector:@selector(secureConnectionDataRecvProgress:ofPct:)]) {
        [delegate performSelector:@selector(secureConnectionDataRecvProgress:ofPct:) withObject:ioConn withObject:pctComplete];
    }
}
/*
 *  Report the data send transfer progress.
 */
-(void) secureConnectionDataSendProgress:(CS_secureConnection *) ioConn ofPct:(NSNumber *) pctComplete;
{
    // - pass it onto our delegate
    if (delegate && [delegate respondsToSelector:@selector(secureConnectionDataSendProgress:ofPct:)]) {
        [delegate performSelector:@selector(secureConnectionDataSendProgress:ofPct:) withObject:ioConn withObject:pctComplete];
    }
}


/*
 *  A failure occurred on the connection.
 */
-(void) secureConnectionFailed:(CS_secureConnection *) ioConn
{
    // - pass it onto our delegate
    if (delegate && [delegate respondsToSelector:@selector(secureConnectionFailed:)]) {
        [delegate performSelector:@selector(secureConnectionFailed:) withObject:ioConn];
    }
}

/*
 * A full-duplex connection was ended.
 */
-(void) secureConnectionDisconnected:(CS_secureConnection *) ioConn
{
    // - pass it onto our delegate
    if (delegate && [delegate respondsToSelector:@selector(secureConnectionDisconnected:)]) {
        [delegate performSelector:@selector(secureConnectionDisconnected:) withObject:ioConn];
    }
}

/*
 *  Disconnect the secure connection.
 */
-(void) disconnect
{
    [netConnection disconnect];
}

/*
 *  Check to see if the complete connection is formed.
 */
-(BOOL) isConnected
{
    if (netConnection) {
        return [netConnection isConnected];
    }
    return NO;
}
@end

/*************************************
 CS_secureConnection (internal)
 *************************************/
@implementation CS_secureConnection (internal)

/*
 * A full-duplex connection completed.
 */
-(void) basicConnectionConnected:(CS_basicIOConnection *)ioConn
{
    [self secureConnectionConnected:self];
}

/*
 *  Report data receive progress.
 */
-(void) basicConnectionDataRecvProgress:(CS_basicIOConnection *)ioConn ofPct:(NSNumber *)pctComplete
{
    [self secureConnectionDataRecvProgress:self ofPct:pctComplete];
}

/*
 *  Report data send progress.
 */
-(void) basicConnectionDataSendProgress:(CS_basicIOConnection *)ioConn ofPct:(NSNumber *)pctComplete
{
    [self secureConnectionDataSendProgress:self ofPct:pctComplete];
}


/*
 *  Data exists on the connection.
 */
-(void) basicConnectionHasData:(CS_basicIOConnection *)ioConn
{
    [self secureConnectionHasData:self];
}

/*
 *  A failure occurred on the connection.
 */
-(void) basicConnectionFailed:(CS_basicIOConnection *)ioConn
{
    [self secureConnectionFailed:self];
}

/*
 * A full-duplex connection was ended.
 */
-(void) basicConnectionDisconnected:(CS_basicIOConnection *)ioConn
{
    [self secureConnectionDisconnected:self];
}

/*
 *  This is used for testing.
 */
-(BOOL) sendUnlimitedUnencryptedData:(NSData *) d withError:(NSError **) err
{
    return [netConnection sendUnlimitedData:d withError:err];
}

@end

/*************************************
 CS_secureConnection (shared)
 *************************************/
@implementation CS_secureConnection (shared)

/*
 *  Initialize the object.
 */
-(id) initWithConnectionToService:(CS_service *) svc usingPassword:(NSString *) pwd
{
    self = [self init];
    if (self) {
        netConnection          = [[CS_basicIOConnection alloc] initWithConnectionToService:svc];
        netConnection.delegate = self;
        password               = [pwd retain];
        isServerSide           = NO;
    }
    return self;
}

/*
 *  Initialize the object.
 */
-(id) initWithConnectionToClient:(CS_basicIOConnection *) clientConn usingPassword:(NSString *) pwd
{
    self = [self init];
    if (self) {
        netConnection          = [clientConn retain];
        netConnection.delegate = self;
        password               = [pwd retain];
        isServerSide           = YES;
    }
    return self;
}

/*
 *  Populate the error to use for a bad object.
 */
-(BOOL) fillStandardBadObjectError:(NSError **) err
{
    [CS_error fillError:err withCode:CSErrorInvalidSecureRequest andFailureReason:@"No connection parameters."];
    return NO;
}
@end
