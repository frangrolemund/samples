//
//  tdriver_bonjourServer.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 12/9/14.
//  Copyright (c) 2014 Francis Grolemund. All rights reserved.
//

#import "tdriver_bonjourServer.h"
#import "CS_basicServer.h"
#import "CS_basicIOConnection.h"
#import "CS_serviceRegistrationV2.h"
#import "tdriver_bonjourClient.h"

// - constants

@interface tdriver_bonjourServer (server) <CS_basicServerDelegate, CS_serviceRegistrationV2Delegate, CS_basicIOConnectionDelegate>
@end

@implementation tdriver_bonjourServer
/*
 *  Object attributes.
 */
{
    NSString                 *serverName;
    CS_basicServer           *server;
    CS_serviceRegistrationV2 *reg;
    CS_basicIOConnection     *client;
}

/*
 *  Initialize the object.
 */
-(id) initWithServiceName:(NSString *) name
{
    self = [super init];
    if (self) {
        serverName = [name retain];
        server     = [[CS_basicServer alloc] initWithPort:40001];
        server.delegate = self;
        NSError *err = nil;
        if ([server startServerWithError:&err]) {
            reg = [[CS_serviceRegistrationV2 alloc] initWithService:serverName andPort:server.serverPort];
            reg.delegate = self;
            if (![reg registerWithError:&err]) {
                NSLog(@"ERROR: failed to register the server.  %@", [err localizedDescription]);
            }            
        }
        else {
            NSLog(@"ERROR: failed to start the server.  %@", [err localizedDescription]);
        }

    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [serverName release];
    serverName = nil;
 
    [self close];
    [super dealloc];
}

/*
 *  Close the server.
 */
-(void) close
{
    [reg dealloc];
    reg = nil;
    
    [server stopServer];
    [server release];
    server = nil;
    
    [client release];
    client = nil;
}
@end

@implementation tdriver_bonjourServer (server)
-(void) connectionReceived:(CS_basicIOConnection *)conn inServer:(CS_basicServer *)server
{
    NSLog(@"NOTICE: got a new client connection as %p", conn);
    [client release];
    client = [conn retain];
    client.delegate = self;
    NSError *err = nil;
    if (![client connectWithError:&err]) {
        NSLog(@"ERROR: failed to connect the client!  %@", [err localizedDescription]);
        [client disconnect];
        [client release];
        client = nil;
    }
}

-(void) serviceRegistrationCompleted:(CS_serviceRegistrationV2 *)service
{
    NSLog(@"NOTICE: service registration completed as %@", service.serviceName);
}

-(void) serviceRegistrationFailed:(CS_serviceRegistrationV2 *)service
{
    NSLog(@"ERROR: service registration failed.");
}

-(void) basicConnectionDisconnected:(CS_basicIOConnection *)ioConn
{
    NSLog(@"NOTICE: client connnection %p disconnected.", ioConn);
    [client release];
    client = nil;
}

-(void) basicConnectionFailed:(CS_basicIOConnection *)ioConn
{
    NSLog(@"NOTICE: client connection %p failed.", ioConn);
    [client disconnect];
    [client release];
    client = nil;
}

-(void) basicConnectionDataRecvProgress:(CS_basicIOConnection *)ioConn ofPct:(NSNumber *)pctComplete
{
    NSLog(@"NOTICE: connection %p receiving data at %d%%.", ioConn, (int) (pctComplete.floatValue * 100.0f));
}

-(void) basicConnectionDataSendProgress:(CS_basicIOConnection *)ioConn ofPct:(NSNumber *)pctComplete
{
    NSLog(@"NOTICE: connection %p sending data at %d%%.", ioConn, (int) (pctComplete.floatValue * 100.0f));
}

-(void) basicConnectionHasData:(CS_basicIOConnection *)ioConn
{
    NSError *err = nil;
    NSLog(@"NOTICE: connection %p has data to process.", ioConn);
    NSData *d = [client checkForDataWithError:&err];
    if (!d) {
        NSLog(@"ERROR: connection %p could not get data.  %@", ioConn, [err localizedDescription]);
        [client disconnect];
        [client release];
        client = nil;
    }
    
    if (![tdriver_bonjourClient isPayloadValid:d]) {
        NSLog(@"ERROR: received data on %p is not valid.", ioConn);
        [client disconnect];
        [client release];
        client = nil;
    }
    
    NSLog(@"NOTICE: returning data on %p", ioConn);
    d = [tdriver_bonjourClient sampleDataPayload];
    if (![client sendData:d withError:&err]) {
        NSLog(@"ERROR: failed to send data on %p. %@", ioConn, [err localizedDescription]);
        [client disconnect];
        [client release];
        client = nil;
    }
}
@end
