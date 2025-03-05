//
//  ChatSealBaseStation.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/20/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import "ChatSealBaseStation.h"
#import "CS_serviceRegistrationV2.h"
#import "CS_serviceRadar.h"
#import "ChatSeal.h"
#import "CS_secureTransferServer.h"
#import "CS_secureConnection.h"
#import "CS_netstatus.h"
#import "CS_serviceHost.h"

// - constants
NSString *kChatSealNotifyKeyTransferState    = @"PSTSState";
NSString *kChatSealNotifyKeyTransferProgress = @"PSTSProgress";
NSString *kChatSealNotifyKeyTransferError    = @"PSTSError";

// - forward declarations
@interface ChatSealBaseStation (internal) <CS_netstatusDelegate, CBCentralManagerDelegate>
-(void) releaseBeacon;
-(void) releaseSealServer;
-(BOOL) configureBeaconForSeal:(NSString *) sealId withError:(NSError **) err;
-(NSUInteger) countOfUsersThatAreNew:(BOOL) areNew;
-(void) enableBluetoothState;
-(void) disableBluetoothState;
-(BOOL) startRadarWithError:(NSError **) err;
-(void) stopRadar;
-(CS_serviceHost *) hostForURL:(NSURL *) u withError:(NSError **) err;
-(void) postUserNotificationUpdate;
@end

// - for tracking the beacon health.
@interface ChatSealBaseStation (beacon) <CS_serviceRegistrationV2Delegate>
@end

// - for sharing with the service object.
@interface CS_service (shared)
-(void) setIsLocal:(BOOL) l;
@end

// - for tracking the radar results.
@interface ChatSealBaseStation (radar) <CS_serviceRadarDelegate>
-(void) timerDelayedAddition:(NSTimer *) timer;
@end

// - shared with the identity object.
@interface ChatSealRemoteIdentity (shared)
-(id) initWithService:(CS_service *) service andURL:(NSURL *) secureURL;
@end

/******************************
 ChatSealBaseStation
 ******************************/
@implementation ChatSealBaseStation
/*
 *  Object attributes
 */
{
    CS_serviceRegistrationV2 *beacon;
    CS_serviceRadar          *radar;
    CS_secureTransferServer  *sealServer;
    CS_netstatus             *netStatus;
    NSString                 *promotedSealId;
    BOOL                     isNewUserDevice;
    CBCentralManager         *centralManager;
    CBCentralManagerState    bluetoothState;
    
    NSMutableDictionary      *mdServiceList;
    NSMutableSet             *msMyServices;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        beacon                  = nil;
        radar                   = nil;
        sealServer              = nil;
        promotedSealId          = nil;
        isNewUserDevice         = YES;
        mdServiceList           = [[NSMutableDictionary alloc] init];
        netStatus               = [[CS_netstatus alloc] initForLocalWifiOnly:YES];          //  only useful for proximity detection.
        netStatus.delegate      = self;
        bluetoothState          = CBCentralManagerStateUnknown;
        centralManager          = nil;
        msMyServices            = [[NSMutableSet alloc] init];
        
        // - we should be checking the network status at all times.
        [netStatus startStatusQuery];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [self disableBluetoothState];
    
    netStatus.delegate = nil;
    [netStatus haltStatusQuery];
    [netStatus release];
    netStatus = nil;
    
    [self setBroadcastingEnabled:NO withError:nil];
    
    [promotedSealId release];
    promotedSealId = nil;
    
    [mdServiceList release];
    mdServiceList = nil;
    
    [msMyServices release];
    msMyServices = nil;
    
    [super dealloc];
}

/*
 *  Set the new user state, which reflects how the beacon 
 *  broadcasts this device's vault availability.
 */
-(BOOL) setNewUserState:(BOOL) isNewUser withError:(NSError **) err
{
    if (isNewUser != isNewUserDevice) {
        isNewUserDevice = isNewUser;
        if (!isNewUser) {
            [promotedSealId release];
            promotedSealId = nil;
        }
        
        // - only reconfigure the beacon when it is set, otherwise
        //   we should assume broadcasting is off.
        if (beacon) {
            [self releaseBeacon];
            return [self configureBeaconForSeal:nil withError:err];
        }
    }
    return YES;
}

/*
 *  Assign a promoted seal to the object.
 */
-(BOOL) setPromotedSeal:(NSString *) sealId withError:(NSError **) err
{
    if (sealId != promotedSealId) {
        [promotedSealId release];
        promotedSealId = [sealId retain];
        
        // - only reconfigure the beacon if it is set, otherwise
        //   we should assume broadcasting is off
        if (beacon) {
            [self releaseBeacon];
            [self releaseSealServer];
            return [self configureBeaconForSeal:sealId withError:err];
        }
    }
    return YES;
}

/*
 *  Turn overall broadcasting on/off in the base station, which both
 *  disables the ability to scan for services as well as promote our own
 *  state.
 */
-(BOOL) setBroadcastingEnabled:(BOOL) isEnabled withError:(NSError **)err
{
    if (isEnabled) {
        if (![self startRadarWithError:err]) {
            return NO;
        }
        
        // - build a beacon if one doesn't exist.
        if (!beacon) {
            return [self configureBeaconForSeal:promotedSealId withError:err];
        }
    }
    else {
        [self releaseBeacon];
        
        [self stopRadar];
        
        [self releaseSealServer];
        
        // - when the radar is discarded, that discards the Bounjour DNS browsing session.
        //   Because of this fact, we need to always discard all of our cached services because
        //   their included interface ids will like be invalid with new browsing sessions.  The
        //   documentation provided for DNS discovery indicates that resolving a service with
        //   anything more than the generic catchall interface index requires the data to be fresh.
        // - it is critical that the data we do have here is accurate or connections will prove
        //   to be unreliable.
        [mdServiceList removeAllObjects];
    }
    return YES;
}

/*
 *  Determine if the base station is working correctly.
 */
-(BOOL) isBroadcastingSuccessfully
{
    if (radar && beacon) {
        if ([radar isOnline] && [beacon isOnline]) {
            // - if we haven't got a record of our own beacon yet,
            //   then it isn't fully online.
            NSString *svc = [beacon serviceName];
            if (![mdServiceList objectForKey:svc]) {
                return NO;
            }
            
            // - if there is no promoted seal or the server is up, then
            //   we're good to go.
            if (!promotedSealId || [sealServer isOnline]) {
                return YES;
            }
        }
    }
    return NO;
}

/*
 *  Return the number of new users.
 */
-(NSUInteger) newUserCount
{
    return [self countOfUsersThatAreNew:YES];
}

/*
 *  Return the number of users with active vaults.
 */
-(NSUInteger) vaultReadyUserCount
{
    return [self countOfUsersThatAreNew:NO];
}

/*
 *  This method returns the URL that is necessary to use for transferring seals between
 *  devices.  This URL is modified after each successful transfer with alternate encryption
 *  keys to ensure maximum security.
 *  - returns nil if there is no active seal for transfer or there is a transfer in progress.
 */
-(NSURL *) secureSealTransferURL
{
    return [sealServer secureURL];
}

/*
 *  Returns whether the provided URL is valid for secure transfer.
 */
-(BOOL) isValidSecureTransferURL:(NSURL *) url
{
    return [CS_secureTransferServer isValidSecureURL:url];
}

/*
 *  Connect with the given URL to the secure transfer server.
 *  - takes the URL returned by the secureSealTransferURL method.
 */
-(ChatSealRemoteIdentity *) connectForSecureSealTransferWithURL:(NSURL *) url andError:(NSError **) err
{
    // - find the host associated with this URL and make sure it can support downloads
    CS_serviceHost *serviceHost = [self hostForURL:url withError:err];
    if (!serviceHost) {
        return nil;
    }
    
    // - now figure out the best way to connect to it.
    CS_service *svcBest = [serviceHost bestServiceForConnection];
    if (!svcBest) {
        [CS_error fillError:err withCode:CSErrorUnknownService andFailureReason:@"Unexpected bad service interface."];
        return nil;
    }
    
    // - return a new remote identity tied to the service record.
    // - I think this approach is preferrable to passing-in the full host definition because the remote identity
    //   is a transient object and can be quickly recreated upon failure, but the host definition may be changing
    //   quickly.
    return [[[ChatSealRemoteIdentity alloc] initWithService:svcBest andURL:url] autorelease];
}

/*
 *  Returns whether a transfer is in progress between the base station and a remote client.
 */
-(BOOL) isSecureTransferInProgress
{
    if (sealServer && [sealServer isSecureTransferInProgress]) {
        return YES;
    }
    return NO;
}

/*
 *  The proximity wireless subsystem refers to the capability to locate and communicate with
 *  local devices.
 */
-(ps_bs_proximity_state_t) proximityWirelessState
{
    BOOL hasLocalWireless = [netStatus hasConnectivity];
    
    // - the best wireless option is standard Wi-Fi, but we'll report bluetooth behavior if it is available.
    if (hasLocalWireless) {
        [self disableBluetoothState];
        return CS_BSCS_ENABLED;
    }
    else {
        // - the only way we'll ever show the official disabled state is when we know
        //   it conclusively from a device that can report on Bluetooth behavior.
        //   Otherwise, it makes a lot of sense to assume Bluetooth is on and give guidance in that
        //   area.
        if (bluetoothState == CBCentralManagerStatePoweredOff) {
            return CS_BSCS_DISABLED;
        }
        else {
            if (bluetoothState == CBCentralManagerStateUnknown) {
                [self enableBluetoothState];
            }
        }
    }
    return CS_BSCS_DEGRADED;
}

/*
 *  It is possible that due to a wireless problem, a URL is scanned by the device but the local entity
 *  hasn't been found yet.  This returns an indication of whether we can expect connections to succeed.
 */
-(BOOL) hasProximityDataForConnectionToURL:(NSURL *) url
{
    if ([self hostForURL:url withError:nil]) {
        return YES;
    }
    return NO;
}

/*
 *  Pause/resume seal transfer, which will reject any incoming connections when in a paused state.
 */
-(void) setSealTransferPaused:(BOOL) isPaused
{
    [sealServer setTransferHandlingPaused:isPaused];
}

@end

/*******************************
 ChatSealBaseStation (internal)
 *******************************/
@implementation ChatSealBaseStation (internal)
/*
 *  Free the beacon object.
 */
-(void) releaseBeacon
{
    beacon.delegate = nil;
    [beacon release];
    beacon          = nil;
}

/*
 *  Free the secure transfer server.
 */
-(void) releaseSealServer
{
    [sealServer stopAllSecureTransfer];
    [sealServer release];
    sealServer = nil;
}

/*
 *  Create a beacon for the given seal.
 */
-(BOOL) configureBeaconForSeal:(NSString *) sealId withError:(NSError **)err
{
    // - just don't stomp on an existing one.
    [self releaseBeacon];
    [self releaseSealServer];
    
    // - I don't want to divulge anything about the vault itself, so an empty vault, versus one without an
    //   active seal, versus one with an active seal are all identical in format.
    // - Also, the intent is to always produce a random value for the service name so that people can never infer
    //   anything about the identity of a user in the local proximity network.
    NSUUID *uuid       = [NSUUID UUID];
    NSString *baseName = [RealSecureImage secureServiceNameFromString:[uuid UUIDString]];
    NSString *service  = [NSString stringWithFormat:@"%@%@", (isNewUserDevice ? [CS_serviceRadar servicePrefixNewUser] : [CS_serviceRadar servicePrefixHasVault]), baseName];
    
    // - when a seal id is provided, we'll assume it is to be promoted for
    //   external retrieval, otherwise we'll create a generic registration
    //   that shows the state of this device.
    if (sealId) {
        sealServer = [[CS_secureTransferServer alloc] initWithService:service forSealId:sealId];
        if (![sealServer startSecureTransferWithError:err]) {
            [self releaseSealServer];
            return NO;
        }
        beacon = [[CS_serviceRegistrationV2 alloc] initWithService:service andPort:[sealServer port]];
    }
    else {
        // - when there is no seal, the goal is to simply publicize whether we're
        //   a new user or not.
        beacon = [[CS_serviceRegistrationV2 alloc] initWithService:service andPort:(uint16_t) -1];
    }
    
    // - make sure we receive updates from our beacon.
    beacon.delegate = self;
    
    // - turn on the beacon.
    NSError *tmp = nil;
    if (![beacon registerWithError:&tmp]) {
        [self releaseSealServer];
        NSLog(@"CS: The application beacon failed to be registered.  %@", [tmp localizedDescription]);
        [CS_error fillError:err withCode:CSErrorBeaconFailure andFailureReason:[tmp localizedDescription]];
        return NO;
    }
    
    // - because al of the accounting in the base station is based on the receipt of DNS information, we
    //   can technically know about more than one service simultaneously, so we'll use this set as a
    //   reference point for identifying our own.
    [msMyServices addObject:service];

    // - make sure everyone knows about the change in the secure URL.
    [[NSNotificationCenter defaultCenter] postNotificationName:kChatSealNotifySecureURLHasChanged object:self];
    
    // - all good.
    return YES;
}

/*
 *  The status of the network connection has changed.
 */
-(void) netStatusChanged:(CS_netstatus *)netStatus
{
    // - make sure this always happens on the main thread.
    [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kChatSealNotifyNetworkChange object:self];
    }];
}

/*
 *  Return a count of the detected services that are new/not-new
 */
-(NSUInteger) countOfUsersThatAreNew:(BOOL) areNew
{
    // - there is a scenario that occurs when we do a lot of service creation/destruction
    //   where a person is transitioning between one state like publishing they have a vault to
    //   actually exporting a seal.  We don't want to doubly-count those kind of people, so this
    //   count is going to factor when the item was browsed (is-hardened) into its determination.
    // - the objective is to be a bit less particular when there is only a single other user, but
    //   require a hardness distinction for any more than that.
    BOOL       hasAtLeastOne = NO;
    NSUInteger ret           = 0;
    BOOL       hasWireless   = [netStatus hasConnectivity];
    for (CS_serviceHost *sh in mdServiceList.allValues) {
        // - ignore my own entry and ones that don't match the new criteria.
        if (sh.isLocalHost || (sh.isNewUser != areNew)) {
            continue;
        }
        
        // - now determine whether we should assume
        //   wireless support is an option.
        if (hasWireless) {
            if (sh.hasWireless || sh.hasBluetooth) {
                hasAtLeastOne = YES;
                if ([sh isHardened]) {
                    ret++;
                }
            }
        }
        else {
            if (sh.hasBluetooth) {
                hasAtLeastOne = YES;
                if ([sh isHardened]) {
                    ret++;
                }
            }
        }
    }
    
    // - if we found at least one, but none were hardened, we'll assume there is one
    //   to ensure that a person's first time experience isn't delayed.
    if (ret == 0 && hasAtLeastOne) {
        ret++;
    }
    
    return ret;
}

/*
 *  Track the local bluetooth device state where possible to let the user know whether they
 *  can expect connectivity.
 */
-(void) centralManagerDidUpdateState:(CBCentralManager *)central
{
    ps_bs_proximity_state_t state = [self proximityWirelessState];
    bluetoothState                = central.state;
    
    // - if the new bluetooth state has changed our wireless state, notify everyone who
    //   is interested.
    if (state != [self proximityWirelessState]) {
        [self netStatusChanged:nil];
    }
}

/*
 *  Turn bluetooth scanning on.
 */
-(void) enableBluetoothState
{
    if (centralManager) {
        return;
    }
    centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:CBCentralManagerOptionShowPowerAlertKey]];
}

/*
 *  Turn bluetooth scanning off.
 */
-(void) disableBluetoothState
{
    centralManager.delegate = nil;
    [centralManager release];
    centralManager = nil;
    bluetoothState = CBCentralManagerStateUnknown;
}

/*
 *  Attempt to start the radar.
 */
-(BOOL) startRadarWithError:(NSError **) err
{
    if (!radar) {
        radar          = [[CS_serviceRadar alloc] init];
        radar.delegate = self;
        if (![radar beginScanningWithError:err]) {
            NSLog(@"CS: The application radar failed to begin scanning.");
            return NO;
        }
    }
    return YES;
}

/*
 *  Stop the active radar.
 */
-(void) stopRadar
{
    radar.delegate = nil;
    [radar stopScanning];
    [radar release];
    radar = nil;
}

/*
 *  Attempt to find a host for the given URL.
 */
-(CS_serviceHost *) hostForURL:(NSURL *) u withError:(NSError **) err
{
    CS_serviceHost *svcHost = [mdServiceList objectForKey:u.host];
    if (!svcHost || svcHost.interfaceCount == 0 || svcHost.isNewUser) {
        [CS_error fillError:err withCode:CSErrorUnknownService];
        return nil;
    }
    return svcHost;
}

/*
 *  Post a user update to the nofication center.
 */
-(void) postUserNotificationUpdate
{
    // - make sure this always happens on the main thread.
    [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kChatSealNotifyNearbyUserChange object:self];
    }];
}

@end

/*******************************
 ChatSealBaseStation (beacon)
 *******************************/
@implementation ChatSealBaseStation (beacon)
/*
 *  Report that service registration succeeded.
 */
-(void) serviceRegistrationCompleted:(CS_serviceRegistrationV2 *)service
{
    // - I was reporting this in the log, but I'm not sure it is a good thing because
    //   we change the beacon so constantly and the networking is always going to be intermittent.
    // - Am I really going to parse logs to figure out why you and your friends couldn't connnect?
}

/*
 *  Report when service registration failed.
 */
-(void) serviceRegistrationFailed:(CS_serviceRegistrationV2 *)service
{
    NSLog(@"CS: Failed to online the application beacon. (beacon = %p, dns-error = %d)", beacon, [beacon lastDNSError]);
}
@end

/*********************************
 ChatSealBaseStation (radar)
 *********************************/
@implementation ChatSealBaseStation (radar)

/*
 *  Notify anyone listening of a new record addition.
 */
-(void) timerDelayedAddition:(NSTimer *) timer
{
    if (![timer isValid]) {
        return;
    }
    
    // - if the radar is now gone, that means it was disabled while the timer was waiting and we don't
    //   want to notify anyone.
    if (radar) {
        [self postUserNotificationUpdate];
    }
}

/*
 *  The radar has located another service on the local network.
 */
-(void) radar:(CS_serviceRadar *)radar serviceAdded:(CS_service *)service
{
    // - special tracking for our own registration
    BOOL isMine = [msMyServices containsObject:service.serviceName];
    
    // - save all services in a common location.
    [service setIsLocal:isMine];
    CS_serviceHost *sHost = [mdServiceList objectForKey:service.serviceName];
    BOOL isNewRecord       = NO;
    if (!sHost) {
        isNewRecord = YES;
        sHost = [[[CS_serviceHost alloc] init] autorelease];
        [mdServiceList setObject:sHost forKey:service.serviceName];
    }
    [sHost addService:service];
    
    // - when the number of vault users changes, let any interested parties know.
    if (isNewRecord && !isMine) {
        // - for the first one beyond our own that is added, we'll immediately notify any listeners, others
        //   we'll delay until the hardness can be confirmed.
        NSUInteger numOther = 0;
        for (CS_serviceHost *sh in mdServiceList.allValues) {
            if (![sh isLocalHost]) {
                numOther++;
            }
        }
        
        if (numOther == 1) {
            [self postUserNotificationUpdate];
        }
        else {
            NSTimer *tmDelay = [NSTimer timerWithTimeInterval:[CS_serviceHost hardnessInterval] target:self selector:@selector(timerDelayedAddition:) userInfo:self repeats:NO];
            [[NSRunLoop mainRunLoop] addTimer:tmDelay forMode:NSRunLoopCommonModes];
        }
    }
 }

/*
 *  A service on the local network has been removed.
 */
-(void) radar:(CS_serviceRadar *)radar serviceRemoved:(CS_service *)service
{
    // - look for the item to remove.
    CS_serviceHost *sHost = [mdServiceList objectForKey:service.serviceName];
    if (sHost) {
        BOOL wasLocal = [sHost isLocalHost];
        [sHost removeService:service];
        
        // - when both are removed, just remove the object.
        if (sHost.interfaceCount == 0) {
            [mdServiceList removeObjectForKey:service.serviceName];
            [msMyServices removeObject:service.serviceName];
            if (!wasLocal) {
                [self postUserNotificationUpdate];
            }
        }
    }
}

/*
 *  When the radar encounters a major failure, this is triggered.
 */
-(void) radar:(CS_serviceRadar *)radar failedWithError:(NSError *)err
{
    // - prevent recursion in here.
    static BOOL handlingFailure = NO;
    if (handlingFailure) {
        return;
    }
    
    handlingFailure = YES;
    NSLog(@"CS: %@  %@", [err localizedDescription], [err localizedFailureReason]);
    [self stopRadar];
    
    NSError *tmp = nil;
    if (![self startRadarWithError:&tmp]) {
        NSLog(@"CS: The radar could not be restarted successfully.  %@", [tmp localizedDescription]);
    }
    
    handlingFailure = NO;
}

@end
