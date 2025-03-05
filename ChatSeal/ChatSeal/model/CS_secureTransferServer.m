//
//  CS_secureTransferServer.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/22/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#include <sys/socket.h>
#include <netinet/in.h>
#include <dns_sd.h>
#import "CS_secureTransferServer.h"
#import "ChatSeal.h"
#import "CS_secureConnection.h"
#import "CS_securePayload.h"
#import "CS_basicServer.h"
#import "CS_serviceRadar.h"
#import "ChatSealBaseStation.h"
#import "ChatSealFeedCollector.h"

// - constants
static const int            CS_ST_NUM_PWD_BYTES     = 20;
static const NSTimeInterval CS_ST_REQUEST_TIMEOUT   = 10.0;
static const NSTimeInterval CS_ST_FULL_XFER_TIMEOUT = CS_ST_REQUEST_TIMEOUT + 50.0f;


// - types
typedef enum {
    CS_STSS_NOT_STARTED = 0,
    CS_STSS_WAITING,
    CS_STSS_TRANSFERRING,
    CS_STSS_TRANSFER_CONFIRM,
    CS_STSS_NEED_PWD_REGEN
} phs_st_server_state_t;

// - forward declarations
@interface CS_secureTransferServer (internal)
-(void) releasePassword;
-(BOOL) regeneratePasswordWithError:(NSError **) err;
-(void) completeSecureClientExchange:(BOOL) withRegen;
-(void) abortSecureClientExchangeWithRegen:(BOOL) withRegen;
-(void) errorCloseSecureClientExchangeWithRegen:(BOOL) withRegen andError:(NSError *) err;
+(NSURL *) urlForService:(NSString *) service andPassword:(NSString *) pwd;
-(void) notifyState:(ps_bs_transfer_state_t) transferState withProgress:(CGFloat) progress andError:(NSError *) err;
@end

// - server-related delegate notifications
@interface CS_secureTransferServer (server) <CS_basicServerDelegate>
@end

// - client connection state changes
@interface CS_secureTransferServer (serverToClient) <CS_secureConnectionDelegate>
@end

// - allow us to construct secure connections to the clients.
@interface CS_secureConnection (shared)
-(id) initWithConnectionToClient:(CS_basicIOConnection *) clientConn usingPassword:(NSString *) pwd;
@end

/*************************
 CS_secureTransferServer
 *************************/
@implementation CS_secureTransferServer
/*
 *  Object attributes
 */
{
    phs_st_server_state_t currentState;    
    NSString              *sealServiceName;
    NSString              *sealIdForTransfer;
    CS_basicServer       *server;
    NSString              *currentPassword;
    CS_secureConnection  *secureClientConnection;
    BOOL                  pauseFurtherTransferHandling;
}

/*
 *  Return the string prefix for URLs that identifies the secure protocol.
 */
+(NSString *) secureProtocolName
{
    return @"chatseal";
}

/*
 *  Initialize the object.
 */
-(id) initWithService:(NSString *) service forSealId:(NSString *) sid
{
    self = [super init];
    if (self) {
        currentState                 = CS_STSS_NOT_STARTED;
        sealServiceName              = [service retain];
        sealIdForTransfer            = [sid retain];
        currentPassword              = nil;
        server                       = nil;
        secureClientConnection       = nil;
        pauseFurtherTransferHandling = NO;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [self stopAllSecureTransfer];
    
    [sealIdForTransfer release];
    sealIdForTransfer = nil;
    
    [sealServiceName release];
    sealServiceName = nil;
    
    [super dealloc];
}

/*
 *  Create the secure transfer server and begin waiting for connections.
 */
-(BOOL) startSecureTransferWithError:(NSError **) err
{
    //  - don't double start.
    if (currentState != CS_STSS_NOT_STARTED) {
        return YES;
    }
    
    //  - until I intentionally do it, I don't want to accidentally call this from an operation queue because
    //    that could be unpredictable.
    if (![NSThread isMainThread]) {
        NSLog(@"CS-ALERT:  Attempting to start the secure transfer server on a background thread.");
        [CS_error fillError:err withCode:CSErrorInvalidSecureRequest andFailureReason:@"Invalid thread for secure transfer."];
        return NO;
    }
    
    // - validate the seal to ensure it is good.
    NSError *tmp      = nil;
    if (![RealSecureImage sealExists:sealIdForTransfer withError:&tmp]) {
        [CS_error fillError:err withCode:CSErrorSecureServiceNotEnabled andFailureReason:[tmp localizedDescription]];
        return NO;
    }
 
    // - build a server on any available port.
    server          = [[CS_basicServer alloc] initWithPort:0];
    server.delegate = self;
    if (![server startServerWithError:&tmp]) {
        server.delegate = nil;
        [server release];
        server = nil;
        [CS_error fillError:err withCode:CSErrorSecureServiceNotEnabled andFailureReason:[tmp localizedDescription]];
        return NO;
    }
    
    currentState = CS_STSS_NEED_PWD_REGEN;
    return YES;
}

/*
 *  Returns whether the server is online.
 */
-(BOOL) isOnline
{
    return (currentState == CS_STSS_NOT_STARTED ? NO : YES);
}

/*
 *  Halt further transfer with this server.
 */
-(void) stopAllSecureTransfer
{
    if (server) {
        server.delegate = nil;
        [server stopServer];
        [server release];
        server = nil;
    }
    
    [self abortSecureClientExchangeWithRegen:NO];
    
    [self releasePassword];
    currentState = CS_STSS_NOT_STARTED;
}

/*
 *  The port on which the server exists.
 */
-(uint16_t) port
{
    return [server serverPort];
}

/*
 *  The server will provide the URL required to connect to it.
 */
-(NSURL *) secureURL
{
    // - either the password exists and we're just waiting for a connection
    //   or it needs regenerated.  In all other cases, we can't return a secure URL
    //   because it doesn't make sense.
    if (currentState == CS_STSS_WAITING || currentState == CS_STSS_NEED_PWD_REGEN) {
        if (!currentPassword) {
            NSError *err = nil;
            if (![self regeneratePasswordWithError:&err]) {
                NSLog(@"CS: Unable to return a valid secure seal transfer URL.  %@", [err localizedDescription]);
                return nil;
            }
        }
        // - make sure we always move to waiting when the password is recreated
        currentState = CS_STSS_WAITING;
    }

    // - when both these items are available, return the URL.
    if (sealServiceName && currentPassword) {
        // - build a URL with the password and the service name.
        return [CS_secureTransferServer urlForService:sealServiceName andPassword:currentPassword];
    }
    return nil;
}

/*
 *  Returns whether the provided URL is a valid URL for secure transfer with ChatSeal.
 */
+(BOOL) isValidSecureURL:(NSURL *) url
{
    NSString *secProto = [CS_secureTransferServer secureProtocolName];
    NSString *sScheme = [url scheme];
    if (!sScheme || ![secProto isEqualToString:sScheme]) {
        return NO;
    }
    
    NSString *path = [url path];
    if (!path || ![path isEqualToString:@"/g"]) {
        return NO;
    }    
    
    NSString *host = [url host];
    NSString *sSample = [RealSecureImage secureServiceNameFromString:@"!"];
    if (!host || [host length] != [sSample length] + 1) {
        return NO;
    }
    
    NSString *sTmp    = [host substringToIndex:1];
    if (!sTmp || ![sTmp isEqualToString:[CS_serviceRadar servicePrefixHasVault]]) {
        return NO;
    }
    
    NSString *sPwd = [url query];
    if (!sPwd || [sPwd length] != CS_ST_NUM_PWD_BYTES * 2) {
        return NO;
    }
    
    return YES;
}

/*
 *  Returns whether the server is actively transferring a seal to a remote client.
 */
-(BOOL) isSecureTransferInProgress
{
    if (currentState == CS_STSS_TRANSFERRING || currentState == CS_STSS_TRANSFER_CONFIRM) {
        return YES;
    }
    return NO;
}

/*
 *  Pause/resume seal transfer request handling.
 */
-(void) setTransferHandlingPaused:(BOOL) isPaused
{
    pauseFurtherTransferHandling = isPaused;
}

@end

/************************************
 CS_secureTransferServer (internal)
 ************************************/
@implementation CS_secureTransferServer (internal)
/*
 *  Release the active password.
 */
-(void) releasePassword
{
    [currentPassword release];
    currentPassword = nil;
}

/*
 *  Recreate the service password.
 */
-(BOOL) regeneratePasswordWithError:(NSError **) err
{
    [self releasePassword];
    
    //  - generate a password for communicating with this
    //    instance of the service
    unsigned char pwdBytes[CS_ST_NUM_PWD_BYTES];
    if (SecRandomCopyBytes(kSecRandomDefault, CS_ST_NUM_PWD_BYTES, pwdBytes) != errSecSuccess) {
        [CS_error fillError:err withCode:CSErrorSecureServiceNotEnabled andFailureReason:@"The secure password could not be generated."];
        return NO;
        
    }
    NSMutableString *sPwd = [[NSMutableString alloc] initWithCapacity:CS_ST_NUM_PWD_BYTES*2];
    for (int i = 0; i < CS_ST_NUM_PWD_BYTES; i++) {
        @try {
            [sPwd appendFormat:@"%02X", (unsigned char) (pwdBytes[i])];
        }
        @catch (NSException *exception) {
            [sPwd release];
            [CS_error fillError:err withCode:CSErrorSecureServiceNotEnabled andFailureReason:@"The secure password could not be generated."];
            return NO;
        }
    }
    currentPassword = sPwd;
    return YES;
}

/*
 *  Complete the secure client exchange and set the state back to normal.
 */
-(void) completeSecureClientExchange:(BOOL) withRegen
{
    secureClientConnection.delegate = nil;
    [secureClientConnection release];
    secureClientConnection = nil;
    currentState           = withRegen ? CS_STSS_NEED_PWD_REGEN : CS_STSS_WAITING;
    if (withRegen) {
        [self releasePassword];
        [[NSNotificationCenter defaultCenter] postNotificationName:kChatSealNotifySecureURLHasChanged object:self];
    }
}

/*
 *  Abort the transfer to the client because of an error.
 */
-(void) abortSecureClientExchangeWithRegen:(BOOL) withRegen
{
    if (secureClientConnection) {
        [self completeSecureClientExchange:withRegen];
        NSLog(@"CS: A secure client connection has been aborted.");
        [self notifyState:CS_BSTS_ABORTED withProgress:0.0f andError:nil];
    }
}

/*
 *  Close a secure client exchange because of an error.
 */
-(void) errorCloseSecureClientExchangeWithRegen:(BOOL) withRegen andError:(NSError *) err
{
    if (secureClientConnection) {
        [self completeSecureClientExchange:withRegen];
        NSLog(@"CS: A secure client connection has failed.");
        [self notifyState:CS_BSTS_ERROR withProgress:0.0f andError:err];
    }
}

/*
 *  Return an appropriate URL for the given service and password.
 */
+(NSURL *) urlForService:(NSString *) service andPassword:(NSString *) pwd
{
    NSString *secProto = [CS_secureTransferServer secureProtocolName];
    NSString *sURL = [NSString stringWithFormat:@"%@://%@/g?%@", secProto, service, pwd];
    return [NSURL URLWithString:sURL];
}

/*
 *  This method will send the general purpose notification about transfer state to anyone who
 *  listens.
 */
-(void) notifyState:(ps_bs_transfer_state_t) transferState withProgress:(CGFloat) progress andError:(NSError *) err
{
    if (currentState == CS_STSS_TRANSFER_CONFIRM) {
        progress = 1.0f;
    }
    
    NSMutableDictionary *mdUserInfo = [NSMutableDictionary dictionary];
    [mdUserInfo setObject:[NSNumber numberWithInt:transferState] forKey:kChatSealNotifyKeyTransferState];
    [mdUserInfo setObject:[NSNumber numberWithFloat:(float) progress] forKey:kChatSealNotifyKeyTransferProgress];
    if (err) {
        [mdUserInfo setObject:err forKey:kChatSealNotifyKeyTransferError];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kChatSealNotifySealTransferStatus object:self userInfo:mdUserInfo];
}
@end

/************************************
 CS_secureTransferServer (server)
 ************************************/
@implementation CS_secureTransferServer (server)
/*
 *  Use this method to control when the server should determine if new 
 *  connections exist.
 */
-(BOOL) shouldCheckForNewConnectionsInServer:(CS_basicServer *) server
{
    // - no current client, then don't worry about it.
    if (!secureClientConnection) {
        return YES;
    }
    
    // - when the active state is 'waiting' it is important
    //   that we give the client enough time to send the initial request to us.
    // - but at this point we want to be careful to handle a denial of service
    //   scenario by aborting connections that go nowhere.
    if (currentState == CS_STSS_WAITING) {
        if ([secureClientConnection timeIntervalSinceConnection] < CS_ST_REQUEST_TIMEOUT) {
            // - wait a bit longer because we haven't timed out yet.
            return NO;
        }
        
        // - when we're waiting and there is no pending data and a timeout occurs, the
        //   connection cannot be used.
        NSError *tmp = nil;
        [CS_error fillError:&tmp withCode:CSErrorSecureTransferFailed andFailureReason:@"Connection timeout."];
        [self errorCloseSecureClientExchangeWithRegen:NO andError:tmp];
    }
    return YES;
}

/*
 *  Use this method to control whether a viable connection is allowed to
 *  be accepted by this secure server.  Rejecting the request will
 *  close the connection immediately.
 */
-(BOOL) shouldAllowConnectionFromClientInServer:(CS_basicServer *) server
{
    // - when this server is doing anything other than waiting, we reject all requests
    //   because it implies that either we're transferring, in which case we can't allow
    //   overlapping requests with the same password, or the server isn't ready to
    //   be accessed.   
    if (!pauseFurtherTransferHandling && currentState == CS_STSS_WAITING) {
        return YES;
    }
    return NO;
}

/*
 *  When the server receives connections, this method will report them.
 */
-(void) connectionReceived:(CS_basicIOConnection *) conn inServer:(CS_basicServer *) server
{
    // - we need to convert the basic connection over to a secure one that includes encryption to secure the data.
    secureClientConnection          = [[CS_secureConnection alloc] initWithConnectionToClient:conn usingPassword:currentPassword];
    secureClientConnection.delegate = self;
    NSError           *err          = nil;
    if ([secureClientConnection connectWithError:&err]) {
        [self notifyState:CS_BSTS_STARTING withProgress:0.0f andError:nil];
    }
    else {
        NSLog(@"CS: The client connection could not be fully formed.   %@", [err localizedDescription]);
        [self errorCloseSecureClientExchangeWithRegen:NO andError:err];
    }
}

/*
 *  Enforce timeout behavior for connected clients.
 */
-(void) acceptProcessingCompletedInServer:(CS_basicServer *)server
{
    if (secureClientConnection && [secureClientConnection timeIntervalSinceConnection] > CS_ST_FULL_XFER_TIMEOUT) {
        if (currentState != CS_STSS_TRANSFER_CONFIRM) {
            NSLog(@"CS: The active client connection has timed out.");
            [self abortSecureClientExchangeWithRegen:YES];
        }
    }
}

@end

/********************************************
 CS_secureTransferServer (serverToClient)
 ********************************************/
@implementation CS_secureTransferServer (serverToClient)
/*
 *  The client connection has been disconnected.
 */
-(void) secureConnectionDisconnected:(CS_secureConnection *)ioConn
{
    if (currentState == CS_STSS_WAITING || currentState == CS_STSS_TRANSFERRING) {
        NSLog(@"CS: There was an incomplete seal transfer detected.");
        NSError *tmp = nil;
        [CS_error fillError:&tmp withCode:CSErrorSecureTransferFailed andFailureReason:@"Disconnected prematurely."];
        [self errorCloseSecureClientExchangeWithRegen:YES andError:tmp];
    }
    else {
        [self completeSecureClientExchange:YES];
    }
}

/*
 *  There is incoming data for the server to process.
 */
-(void) secureConnectionHasData:(CS_secureConnection *)ioConn
{
    NSData *dIncoming = nil;
    NSError *err      = nil;
    if (secureClientConnection == ioConn) {
        dIncoming = [secureClientConnection checkForDataWithError:&err];
    }
    else {
        [CS_error fillError:&err withCode:CSErrorSecureTransferFailed andFailureReason:@"Unexpected secure client connection mismatch."];
        return;
    }
    
    // - when the data couldn't be retrieved, we need to abort the active connection, which
    //   can happen if a valid client uses an old URL to connect, for instance, because the
    //   request payload couldn't be decrypted successfully.
    if (!dIncoming) {
        // - it is highly unlikely we received this particular delegate notification without there
        //   being data, so this failure is probably a decryption failure because the connection password changed.
        NSLog(@"CS: Invalid seal transfer data received, possible malicious activity.");
        [self abortSecureClientExchangeWithRegen:currentState == CS_STSS_WAITING ? NO : YES];
        return;
    }
    
    // - decide what to do with the data depending on our current state.
    if (currentState == CS_STSS_WAITING) {
        // - now validate the incoming request.
        NSURL *u = [CS_secureTransferServer urlForService:sealServiceName andPassword:currentPassword];
        if (![CS_securePayload isSealRequestPayload:dIncoming validForURL:u]) {
            NSLog(@"CS: Invalid seal request received, possible malicious activity.");
            [self abortSecureClientExchangeWithRegen:NO];
            return;
        }

        // - the request is good, so send over the seal.
        // - NOTE:  we need to regenerate the URL after each one of these failures because
        //          the password payload has already been sent over and we should really
        //          not trust any further exchanges with the old password.
        NSData *dSealPayload = [CS_securePayload sealTransferPayloadForSealId:sealIdForTransfer withError:&err];
        if (!dSealPayload) {
            NSLog(@"CS: Failed to prepare the seal %@ for transfer.  %@", sealIdForTransfer, [err localizedDescription]);
            [self errorCloseSecureClientExchangeWithRegen:YES andError:err];
            return;
        }
        
        if (![secureClientConnection sendData:dSealPayload withError:&err]) {
            NSLog(@"CS: Failed to send the seal %@ over the secure connection.  %@", sealIdForTransfer, [err localizedDescription]);
            [self errorCloseSecureClientExchangeWithRegen:YES andError:err];
            return;
        }
    
        // - update our state now and make sure that the first transfer progress message is sent.
        currentState = CS_STSS_TRANSFERRING;
        [self secureConnectionDataSendProgress:secureClientConnection ofPct:[NSNumber numberWithFloat:0.0f]];
    }
    else if (currentState == CS_STSS_TRANSFERRING) {
        BOOL isNewSealForClient = NO;
        NSURL *u                = [CS_secureTransferServer urlForService:sealServiceName andPassword:currentPassword];
        NSArray *arrReqFeeds    = nil;
        if (![CS_securePayload isSealReceiptPayload:dIncoming validForURL:u returningIsNew:&isNewSealForClient andRequestorFeeds:&arrReqFeeds]) {
            NSLog(@"CS: Invalid seal receipt response received, possible malicious activity.");
            [self abortSecureClientExchangeWithRegen:YES];
            return;
        }
        
        // - make sure we always get the final progress message whether or not the stream sends one.
        [self secureConnectionDataSendProgress:secureClientConnection ofPct:[NSNumber numberWithFloat:1.0f]];

        // - when the seal was indeed new for the client, update our local identity to update the number of
        //   shared seals.
        ChatSealIdentity *psi = [ChatSeal identityForSeal:sealIdForTransfer withError:&err];
        if (!psi) {
            NSLog(@"CS: Failed to find the seal identity for %@ after completing transfer.  %@", sealIdForTransfer, [err localizedDescription]);
            [self errorCloseSecureClientExchangeWithRegen:YES andError:err];
            return;
        }
        if (isNewSealForClient) {
            [psi incrementSealGivenCount];
            [self notifyState:CS_BSTS_COMPLETED_NEWUSER withProgress:1.0f andError:nil];
        }
        else {
            [psi markSealWasReSharedWithAFriend];
            [self notifyState:CS_BSTS_COMPLETED_DUPLICATE withProgress:1.0f andError:nil];
        }
        currentState = CS_STSS_TRANSFER_CONFIRM;
        [self completeSecureClientExchange:YES];
        
        // - make sure the global transfer state reflects this success
        [ChatSeal setSealTransferCompleteIfNecessary];
        
        // - save off the feeds if they were returned.
        if (arrReqFeeds) {
            if (!psi) {
                psi = [ChatSeal identityForSeal:sealIdForTransfer withError:nil];
            }
            [psi updateFriendFeedLocations:arrReqFeeds];
            
            // - make sure that a seal transfer will restore friends we previously ignored.
            [[ChatSeal applicationFeedCollector] restoreFriendsInLocations:arrReqFeeds];
        }
    }
    else {
        // - we're in an unexpected state, so this should not continue.
        NSLog(@"CS: Unexpected secure server data request received, possible malicious activity.");
        [self abortSecureClientExchangeWithRegen:YES];
        return;
    }
}

/*
 *  Report on the progress of the transfer.
 */
-(void) secureConnectionDataSendProgress:(CS_secureConnection *)ioConn ofPct:(NSNumber *)pctComplete
{
    if (currentState == CS_STSS_TRANSFERRING) {
        [self notifyState:CS_BSTS_SENDING_SEAL_PROGRESS withProgress:pctComplete.floatValue andError:nil];
    }
}

/*
 *  A failure has occurred with the client connection.
 */
-(void) secureConnectionFailed:(CS_secureConnection *)ioConn
{
    NSError *err = nil;
    if ([ioConn isConnectionOKWithError:&err]) {
        NSLog(@"CS: The secure connection failed, but is still marked as OK, which is odd.");
        [self abortSecureClientExchangeWithRegen:YES];
    }
    else {
        NSLog(@"CS: A connection failure occurred with a remote device.   %@", [err localizedDescription]);
        [self errorCloseSecureClientExchangeWithRegen:YES andError:err];
    }
}
@end