//
//  CS_basicServer.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#include <sys/socket.h>
#include <netinet/in.h>
#include <dns_sd.h>
#import "CS_basicServer.h"
#import "ChatSeal.h"
#import "CS_basicIOConnection.h"

// - forward declarations
@interface CS_basicServer (internal)
-(int) socketForV4:(BOOL) isV4 andPort:(uint16_t) port withError:(NSError **) err;
-(BOOL) socketHasContent:(int) sock;
-(int) nonBlockingAcceptOnSocket:(int) sock asV4:(BOOL) isV4;
-(void) cleanSocketShutdown:(int) sock;
-(void) serverAcceptTimer;
@end

/************************
 CS_basicServer
 ************************/
@implementation CS_basicServer
/*
 *  Object attributes
 */
{
    uint16_t serverPort;
    int      sockV4;
    int      sockV6;
    NSTimer  *tmAcceptTimer;
}
@synthesize delegate;

/*
 *  Initialize the object.
 */
-(id) initWithPort:(uint16_t)port
{
    self = [super init];
    if (self) {
        // - if the port is zero, that means we can just let it auto-assign one
        serverPort    = port;
        sockV4        = -1;
        sockV6        = -1;
        tmAcceptTimer = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [self stopServer];
    [super dealloc];
}

/*
 *  Start the server and allow it to begin receiving requests.
 */
-(BOOL) startServerWithError:(NSError **) err
{
    // - already started?
    if (tmAcceptTimer) {
        return YES;
    }
    
    // - we need to create two sockets, one for v4 and one for v6.
    //  - although this describes one socket, it is actually two
    //    that are routed through the same accept routine - one for
    //    IPv4 and one for IPv6.
    
    //  - build v4 first and figure out which port it has acquired.
    sockV4 = [self socketForV4:YES andPort:serverPort withError:err];
    if (sockV4 == -1) {
        return NO;
    }
    
    struct sockaddr_in sai;
    socklen_t lenAddr = sizeof(sai);
    memset(&sai, 0, sizeof(sai));
    if (getsockname(sockV4, (struct sockaddr *) &sai, &lenAddr) != 0) {
        [CS_error fillError:err withCode:CSErrorSecureServiceNotEnabled andFailureReason:@"Failed to retrieve the port for the v4 server socket."];
        return NO;
    }
    serverPort = ntohs(sai.sin_port);
    
    //  - now build v6
    sockV6 = [self socketForV4:NO andPort:serverPort withError:err];
    if (sockV6 == -1) {
        close(sockV4);
        sockV4 = -1;
        return NO;
    }
    
    // - and start the accept timer.
    tmAcceptTimer = [[NSTimer timerWithTimeInterval:0.5f target:self selector:@selector(serverAcceptTimer) userInfo:nil repeats:YES] retain];
    [[NSRunLoop currentRunLoop] addTimer:tmAcceptTimer forMode:NSRunLoopCommonModes];
    
    return YES;
}

/*
 *  Return the port the server is listening upon.
 */
-(uint16_t) serverPort
{
    return serverPort;
}

/*
 *  Stop the server.
 *  - This MUST be called or this object will never be deallocated because of the retain loop with its timer.
 */
-(void) stopServer
{
    [tmAcceptTimer invalidate];
    [tmAcceptTimer release];
    tmAcceptTimer = nil;
    
    [self cleanSocketShutdown:sockV4];
    sockV4   = -1;
    [self cleanSocketShutdown:sockV6];
    sockV6   = -1;

    serverPort = 0;
}

/*
 *  This method is used to determine if the server socket should be 
 *  checked to see if it is ready for a new connection.   Otherwise, the
 *  any connected devices are simply left in the backlog until we get a chance
 *  to evaluate them.
 *  - I'm adopting my own protocol so that the server can be inherited-from instead
 *    of using the delegate approach when an object doesn't readily exist.
 */
-(BOOL) shouldCheckForNewConnectionsInServer:(CS_basicServer *) server
{
    if (delegate && [delegate respondsToSelector:@selector(shouldCheckForNewConnectionsInServer:)]) {
        return [delegate shouldCheckForNewConnectionsInServer:server];
    }
    
    // - the default is to always check for new connections.
    return YES;
}

/*
 *  When a client has connected, this will allow us to immediately close it without processing 
 *  the request further.
 *  - I'm adopting my own protocol so that the server can be inherited-from instead
 *    of using the delegate approach when an object doesn't readily exist.
 */
-(BOOL) shouldAllowConnectionFromClientInServer:(CS_basicServer *) server
{
    if (delegate && [delegate respondsToSelector:@selector(shouldAllowConnectionFromClientInServer:)]) {
        return [delegate shouldAllowConnectionFromClientInServer:server];
    }
    
    //- the default is to always pull off new connections
    return YES;
}

/*
 *  A new connection was received.
 *  - I'm adopting my own protocol so that the server can be inherited-from instead
 *    of using the delegate approach when an object doesn't readily exist.
 */
-(void) connectionReceived:(CS_basicIOConnection *)conn inServer:(CS_basicServer *)server
{
    if (delegate && [delegate respondsToSelector:@selector(connectionReceived:inServer:)]) {
        [delegate performSelector:@selector(connectionReceived:inServer:) withObject:conn withObject:server];
    }
}

/*
 *  This methiod allows the delegate to get regular timer events without starting a secondary timer itself.
 */
-(void) acceptProcessingCompletedInServer:(CS_basicServer *) server;
{
    if (delegate && [delegate respondsToSelector:@selector(acceptProcessingCompletedInServer:)]) {
        [delegate performSelector:@selector(acceptProcessingCompletedInServer:) withObject:server];
    }
}
@end


/**************************
 CS_basicServer (internal)
 **************************/
@implementation CS_basicServer (internal)
/*
 *  Allocate a new server socket.
 */
-(int) socketForV4:(BOOL) isV4 andPort:(uint16_t) port withError:(NSError **) err
{
    int sockFD = 0;
    if (isV4) {
        sockFD = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
    }
    else {
        sockFD = socket(PF_INET6, SOCK_STREAM, IPPROTO_TCP);
    }
    if (sockFD == -1) {
        NSString *failReason = [NSString stringWithFormat:@"Failed to create the %@ server socket.", isV4 ? @"v4" : @"v6"];
        [CS_error fillError:err withCode:CSErrorSecureServiceNotEnabled andFailureReason:failReason];
        return -1;
    }
    
    int oneValue = 1;
    if (setsockopt(sockFD, SOL_SOCKET, SO_NOSIGPIPE, &oneValue, sizeof(oneValue)) != 0) {
        [self cleanSocketShutdown:sockFD];
        NSString *failReason = [NSString stringWithFormat:@"Failed to disable sigpipe on the %@ server socket.", isV4 ? @"v4" : @"v6"];
        [CS_error fillError:err withCode:CSErrorSecureServiceNotEnabled andFailureReason:failReason];
        return -1;
    }
    
    // - restrict v6 sockets to only that protocol.
    if (!isV4) {
        if (setsockopt(sockFD, IPPROTO_IPV6, IPV6_V6ONLY, &oneValue, sizeof(oneValue)) != 0) {
            [self cleanSocketShutdown:sockFD];
            NSString *failReason = [NSString stringWithFormat:@"Failed to set the preferred protocol on the %@ server socket.", isV4 ? @"v4" : @"v6"];
            [CS_error fillError:err withCode:CSErrorSecureServiceNotEnabled andFailureReason:failReason];
            return -1;
        }
    }
    
    struct sockaddr *sai = NULL;
    socklen_t lenAddr = 0;
    struct sockaddr_in sai4;
    struct sockaddr_in6 sai6;
    
    if (isV4) {
        lenAddr         = sizeof(sai4);
        memset(&sai4, 0, lenAddr);
        sai4.sin_family = AF_INET;
        sai4.sin_len    = (__uint8_t) lenAddr;
        sai4.sin_port   = htons(port);
        sai = (struct sockaddr *)&sai4;
    }
    else {
        lenAddr          = sizeof(sai6);
        memset(&sai6, 0, lenAddr);
        sai6.sin6_family = AF_INET6;
        sai6.sin6_len    = (__uint8_t) lenAddr;
        sai6.sin6_port   = htons(port);
        sai = (struct sockaddr *)&sai6;
    }
    
    if (bind(sockFD, (const struct sockaddr *) sai, lenAddr) != 0) {
        [self cleanSocketShutdown:sockFD];
        NSString *failReason = [NSString stringWithFormat:@"Failed to bind the %@ server socket.", isV4 ? @"v4" : @"v6"];
        [CS_error fillError:err withCode:CSErrorSecureServiceNotEnabled andFailureReason:failReason];
        return -1;
    }
    
    if (listen(sockFD, 16) != 0) {
        [self cleanSocketShutdown:sockFD];
        NSString *failReason = [NSString stringWithFormat:@"Failed to listen on the %@ server socket.", isV4 ? @"v4" : @"v6"];
        [CS_error fillError:err withCode:CSErrorSecureServiceNotEnabled andFailureReason:failReason];
        return -1;
    }
    
    return sockFD;
}

/*
 *  Check a socket to see if it contains data.
 */
-(BOOL) socketHasContent:(int) sock
{
    if (sock == -1) {
        return NO;
    }
    
    fd_set fdsRead, fdsRestrict;
    FD_ZERO(&fdsRead);
    FD_SET(sock, &fdsRead);
    FD_COPY(&fdsRead, &fdsRestrict);
    
    struct timeval tvToWait;
    tvToWait.tv_sec  = 0;
    tvToWait.tv_usec = 1000;
    if (select(sock+1, &fdsRead, NULL, &fdsRestrict, &tvToWait) == 0) {
        return NO;
    }
    return YES;
}

/*
 *  Tries to accept on the socket, but only if content is available.
 */
-(int) nonBlockingAcceptOnSocket:(int) sock asV4:(BOOL) isV4;
{
    if (![self socketHasContent:sock]) {
        return -1;
    }
    
    socklen_t           len = 0;
    struct sockaddr_in  sai4;
    struct sockaddr_in6 sai6;
    struct sockaddr     *sai;
    if (isV4) {
        len = sizeof(sai4);
        sai = (struct sockaddr *) &sai4;
    }
    else {
        len = sizeof(sai6);
        sai = (struct sockaddr *) &sai6;
    }
    return accept(sock, sai, &len);
}

/*
 *  Shut down the socket in a clean way.
 */
-(void) cleanSocketShutdown:(int) sock
{
    if (sock != -1) {
        shutdown(sock, SHUT_RDWR);
        close(sock);
    }
}

/*
 *  Perform a regular check of the server to see if there are pending connections.
 *  - I did it this way instead of using the run loop because I didn't want the Foundation
 *    to do anything for this automatically.  It is important for the server tasks in this
 *    app that they occur in a very predictable way an often in a serialized manner.
 */
-(void) serverAcceptTimer
{
    // - figure out if an existing client requires more time.
    if ([self shouldCheckForNewConnectionsInServer:self]) {
        // - now we're going to start processing any ore all incoming sockets.
        BOOL askedToAllow = NO;
        BOOL shouldAccept = NO;
        // - start pulling off sockets
        for (;;) {
            int newSock = [self nonBlockingAcceptOnSocket:sockV4 asV4:YES];
            if (newSock == -1) {
                newSock = [self nonBlockingAcceptOnSocket:sockV6 asV4:NO];
            }
            
            // - nothing was found on the socket.
            if (newSock == -1) {
                break;
            }
            
            // - query the delegate to see if we're supposed to allow these right now.
            if (!askedToAllow) {
                shouldAccept = [self shouldAllowConnectionFromClientInServer:self];
            }
            
            // - if we need to accept the connection, we must then build an object to
            //   contain it.
            if (shouldAccept) {
                CS_basicIOConnection *bio = [[[CS_basicIOConnection alloc] initWithSocket:newSock] autorelease];
                [self connectionReceived:bio inServer:self];
                
            }
            else {
                // - no, we're going to disconnect everything that connects
                [self cleanSocketShutdown:newSock];
            }
        }
    }
    
    // - make sure the delegate knows we just completed another pass of the server processing.
    [self acceptProcessingCompletedInServer:self];
}

@end
