//
//  CS_serviceRadar.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/20/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_serviceRadar.h"
#import "ChatSeal.h"
#import "CS_serviceRegistrationV2.h"
#import <dns_sd.h>
#import <sys/types.h>
#import <sys/socket.h>
#import <net/if.h>
#import <CommonCrypto/CommonDigest.h>
#import "CS_serviceResolved.h"

// - constants
static const NSTimeInterval CS_SR_RESOLVE_PERIOD     = 10.0f;
static const NSUInteger     CS_SR_MAX_ACTIVE_RESOLVE = 5;          //  to not overburden the device.

// - forward declarations
@interface CS_service (internal)
+(CS_service *) serviceRecordWithInterface:(uint32_t) interfaceIndex andName:(NSString *) serviceName andType:(NSString *) type andDomain:(NSString *) domain;
-(void) setIsBluetooth:(BOOL) bt;
-(void) setInterfaceIndex:(uint32_t) idx;
-(void) setServiceName:(NSString *) sn;
-(void) setRegType:(NSString *) rt;
-(void) setReplyDomain:(NSString *) rd;
@end

@interface CS_service (shared)
-(void) setIsLocal:(BOOL) l;
@end

@interface CS_serviceRadar (internal) <CS_serviceResolvedDelegate>
-(void) processResult;
-(void) releaseRadarSocket;
-(void) browseReplyWithErrorCode:(DNSServiceErrorType) errorCode andFlags:(DNSServiceFlags) flags andInterface:(uint32_t) interfaceIndex andService:(const char *) serviceName
                         andType:(const char *) regtype andDomain:(const char *) replyDomain;
-(void) processReplyWithFlags:(DNSServiceFlags) flags andInterface:(uint32_t) interfaceIndex andService:(const char *) svc andType:(const char *) regtype
                    andDomain:(const char *) replyDomain;
-(void) processPendingResolutionsUpToLimit;
@end

/*
 *  The DNS browse socket needs to retain the info argument.
 */
static const void *CS_srd_DNSSocketRetainInfo(const void *info)
{
    id obj = (id) info;
    if ([obj isKindOfClass:[CS_serviceRadar class]]) {
        [obj retain];
    }
    return info;
}

/*
 *  The DNS browse socket needs to release the info argument.
 */
static void CS_srd_DNSSocketReleaseInfo(const void *info)
{
    id obj = (id) info;
    if ([obj isKindOfClass:[CS_serviceRadar class]]) {
        [obj release];
    }
}

/*
 *  The callback from the bonjour socket to get its data.
 */
void CS_sr_DNSServiceBrowse_Ready(CFSocketRef s, CFSocketCallBackType callbackType, CFDataRef address, const void *data, void *info)
{
    //  - force the callback to process the reply
    if (info && [(id) info isKindOfClass:[CS_serviceRadar class]]) {
        [(CS_serviceRadar *) info processResult];
    }
}

/*
 *  When browsing, this function receives the results.
 */
void CS_sr_DNSServiceBrowseReply(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode, const char *serviceName, const char *regtype, const char *replyDomain, void *context)
{
    if (context && [(id) context isKindOfClass:[CS_serviceRadar class]]) {
        [(CS_serviceRadar *) context browseReplyWithErrorCode:errorCode andFlags:flags andInterface:interfaceIndex andService:serviceName andType:regtype andDomain:replyDomain];
    }
}

/*************************
 CS_serviceRadar
 *************************/
@implementation CS_serviceRadar
/*
 *  Object attributes.
 */
{
    DNSServiceErrorType lastDNSError;
    void                *dnsRef;
    CFSocketRef         browseSocket;
    NSDate              *dtStarted;
    NSMutableArray      *maPendingResolution;
    NSMutableArray      *maActiveResolution;
}
@synthesize delegate;

/*
 *  The length of a service prefix.
 */
+(NSUInteger) servicePrefixLength;
{
    return 1;
}

/*
 *  The prefix used when the user has a vault.
 */
+(NSString *) servicePrefixHasVault
{
    return @"+";
}

/*
 *  The prefix used when the user has no vault yet.
 */
+(NSString *) servicePrefixNewUser
{
    return @"*";
}

/*
 *  Object initialization.
 */
-(id) init
{
    self = [super init];
    if (self) {
        lastDNSError        = kDNSServiceErr_NotInitialized;
        dnsRef              = NULL;
        browseSocket        = NULL;
        delegate            = nil;
        dtStarted           = nil;
        maPendingResolution = [[NSMutableArray alloc] init];
        maActiveResolution  = [[NSMutableArray alloc] init];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [self stopScanning];
    
    [dtStarted release];
    dtStarted = nil;
    
    [maPendingResolution release];
    maPendingResolution = nil;
    
    [maActiveResolution release];
    maActiveResolution = nil;
    
    [super dealloc];
}

/*
 *  Start looking for registered services.
 */
-(BOOL) beginScanningWithError:(NSError **) err
{
    DNSServiceErrorType svcErr = DNSServiceBrowse((DNSServiceRef *) &dnsRef, kDNSServiceFlagsIncludeP2P, kDNSServiceInterfaceIndexAny, [CS_serviceRegistrationV2 serviceRegType],
                                                  NULL, CS_sr_DNSServiceBrowseReply, self);
    lastDNSError = svcErr;
    if (svcErr != kDNSServiceErr_NoError) {
        [CS_error fillError:err withCode:CSErrorRadarFailure forBonjourFailure:svcErr];
        return NO;
    }
    
    CFSocketContext sockContext = {0, self, CS_srd_DNSSocketRetainInfo, CS_srd_DNSSocketReleaseInfo, NULL};
    browseSocket = CFSocketCreateWithNative(kCFAllocatorDefault, (CFSocketNativeHandle) DNSServiceRefSockFD((DNSServiceRef) dnsRef), kCFSocketReadCallBack,
                                            CS_sr_DNSServiceBrowse_Ready, &sockContext);
    if (!browseSocket) {
        lastDNSError = kDNSServiceErr_Invalid;
        [CS_error fillError:err withCode:CSErrorRadarFailure andFailureReason:@"Failed to build the CF wrapper for the Bonjour beacon socket."];
        [self releaseRadarSocket];
        return NO;
    }
    
    CFRunLoopSourceRef rls = CFSocketCreateRunLoopSource(NULL, browseSocket, 0);
    if (rls) {
        dtStarted    = [[NSDate date] retain];
        lastDNSError = kDNSServiceErr_NoError;
        CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopCommonModes);
        CFRelease(rls);
        return YES;
    }
    else {
        lastDNSError = kDNSServiceErr_ServiceNotRunning;
        [CS_error fillError:err withCode:CSErrorRadarFailure andFailureReason:@"Failed to create a run loop source for the Bonjour beacon socket."];
        [self releaseRadarSocket];
        return NO;
    }
}

/*
 *  Halt all scanning operations.
 */
-(void) stopScanning
{
    delegate = nil;
    [self releaseRadarSocket];
    
    // - halt all active resolutions
    for (CS_serviceResolved *sr in maActiveResolution) {
        [sr stopResolution];
    }
    [maActiveResolution removeAllObjects];
}

/*
 *  Return the online state of the radar, which will be important for
 */
-(BOOL) isOnline
{
    return (lastDNSError == kDNSServiceErr_NoError ? YES : NO);
}

/*
 *  A service was added.
 */
-(void) radar:(CS_serviceRadar *)radar serviceAdded:(CS_service *)service
{
    if (delegate && [delegate respondsToSelector:@selector(radar:serviceAdded:)]) {
        [delegate performSelector:@selector(radar:serviceAdded:) withObject:radar withObject:service];
    }
}

/*
 *  A service was removed.
 */
-(void) radar:(CS_serviceRadar *)radar serviceRemoved:(CS_service *)service
{
    if (delegate && [delegate respondsToSelector:@selector(radar:serviceRemoved:)]) {
        [delegate performSelector:@selector(radar:serviceRemoved:) withObject:radar withObject:service];
    }
}

/*
 *  A failure has occurred.
 */
-(void) radar:(CS_serviceRadar *) radar failedWithError:(NSError *) err
{
    if (delegate && [delegate respondsToSelector:@selector(radar:failedWithError:)]) {
        [delegate performSelector:@selector(radar:failedWithError:) withObject:radar withObject:err];
    }
}

@end


/****************************
 CS_serviceRadar (internal)
 ****************************/
@implementation CS_serviceRadar (internal)
/*
 *  Process the result on the browse reference.
 */
-(void) processResult
{
    if (dnsRef) {
        DNSServiceProcessResult(dnsRef);
    }
}

/*
 *  Release the socket used for the radar.
 */
-(void) releaseRadarSocket
{
    lastDNSError = kDNSServiceErr_NotInitialized;
    if (browseSocket) {
        CFSocketInvalidate(browseSocket);
        CFRelease(browseSocket);
        browseSocket = NULL;
    }
    
    if (dnsRef) {
        DNSServiceRefDeallocate((DNSServiceRef) dnsRef);
        dnsRef = NULL;
    }
}

/*
 *  Process a browse reply and report it to the delegate.
 */
-(void) browseReplyWithErrorCode:(DNSServiceErrorType) errorCode andFlags:(DNSServiceFlags) flags andInterface:(uint32_t) interfaceIndex andService:(const char *) serviceName andType:(const char *) regtype andDomain:(const char *) replyDomain;
{
    //  - when there is an error, record it.
    if (errorCode != kDNSServiceErr_NoError) {
        //  - free the socket and try again later.
        [self releaseRadarSocket];
        lastDNSError = errorCode;
        NSError *err = nil;
        [CS_error fillError:&err withCode:CSErrorRadarFailure forBonjourFailure:errorCode];
        [self radar:self failedWithError:err];
        return;
    }
    
    //  - a service name is necessary
    if (!serviceName) {
        return;
    }
    
    //  - analyze the modified service entry.
    [self processReplyWithFlags:flags andInterface:interfaceIndex andService:serviceName andType:regtype andDomain:replyDomain];
}

/*
 *  Process the service reply now that it is validated.
 */
-(void) processReplyWithFlags:(DNSServiceFlags) flags andInterface:(uint32_t) interfaceIndex andService:(const char *) svc andType:(const char *) regtype
                    andDomain:(const char *) replyDomain
{
    BOOL isBluetooth = NO;
    if (interfaceIndex == kDNSServiceInterfaceIndexP2P) {
        isBluetooth = YES;
    }
    
    NSString *svcName    = nil;
    NSString *svcRegType = nil;
    NSString *svcDomain  = nil;
    @try {
        //  - we are going to require that service names that are one greater than
        //    a SHA-1 hash.
        svcName = [NSString stringWithUTF8String:svc];
        if ([svcName length] != [RealSecureImage lengthOfSecureServiceName] + [CS_serviceRadar servicePrefixLength]) {
            return;
        }
        svcRegType = [NSString stringWithUTF8String:regtype];
        svcDomain  = [NSString stringWithUTF8String:replyDomain];
    }
    @catch (NSException *exception) {
        NSLog(@"CS: Unexpected radar reply exception.  %@", [exception description]);
        return;
    }
    
    // - when we're adding a new service and it is right after startup, we're going to explicitly resolve it before
    //   we commit to its existence.  This is to address a rare scenario I've seen on the phones where we get what
    //   appears to be stale cached Bonjour data, possibly from services that were destroyed quickly without de-registration.
    if ((flags & kDNSServiceFlagsAdd) && (-[dtStarted timeIntervalSinceNow] < CS_SR_RESOLVE_PERIOD)) {
        CS_serviceResolved *srNew = [CS_serviceResolved resolveWithService:svcName andRegType:svcRegType andDomain:svcDomain asBluetooth:isBluetooth withIndex:interfaceIndex];
        [maPendingResolution addObject:srNew];
        [self processPendingResolutionsUpToLimit];
    }
    else {
        // - generate a new service entity.
        CS_service *svcNew = [CS_service serviceRecordWithInterface:interfaceIndex andName:svcName andType:svcRegType andDomain:svcDomain];
        [svcNew setIsBluetooth:isBluetooth];
        
        // - now report this to the delegate
        if (flags & kDNSServiceFlagsAdd) {
            [svcNew setBrowseDate:[NSDate date]];
            [self radar:self serviceAdded:svcNew];
        }
        else {
            [self radar:self serviceRemoved:svcNew];
        }
    }
}

/*
 *  Service resolution succeeded, so we can pass it on to the delegate now.
 */
-(void) serviceResolutionSucceeded:(CS_serviceResolved *)resolve
{
    if ([maActiveResolution containsObject:resolve]) {
        CS_service *svcNew = [CS_service serviceRecordWithInterface:resolve.interfaceIndex andName:resolve.serviceName andType:resolve.serviceRegType andDomain:resolve.serviceDomain];
        [svcNew setIsBluetooth:resolve.isBluetooth];
        [svcNew setBrowseDate:[NSDate date]];
        [self radar:self serviceAdded:svcNew];
        resolve.delegate = nil;
        [resolve stopResolution];
        [maActiveResolution removeObject:resolve];
        [self processPendingResolutionsUpToLimit];
    }
}

/*
 *  Service resolution failed, so we know this one isn't any good.
 */
-(void) serviceResolutionFailed:(CS_serviceResolved *)resolve withError:(NSError *)err
{
    if ([maActiveResolution containsObject:resolve]) {
        resolve.delegate = nil;
        [resolve stopResolution];
        [maActiveResolution removeObject:resolve];
        [self processPendingResolutionsUpToLimit];
    }
}

/*
 *  Pull resolutions that haven't started yet and put them in the active queue while 
 *  observing the maximum active limit.
 */
-(void) processPendingResolutionsUpToLimit
{
    while ([maPendingResolution count] && [maActiveResolution count] < CS_SR_MAX_ACTIVE_RESOLVE) {
        CS_serviceResolved *sr = [maPendingResolution objectAtIndex:0];
        
        // - it is entirely possible that we won't be able to resolve
        //   this service, which is the point of this processing, so just silently discard it if
        //   we can't even begin.
        sr.delegate = self;
        if ([sr beginResolutionWithError:nil]) {
            [maActiveResolution addObject:sr];
        }
        else {
            sr.delegate = nil;
        }
        [maPendingResolution removeObjectAtIndex:0];
    }
}

@end


/***************
 CS_service
 ***************/
@implementation CS_service
/*
 *  Object attributes
 */
{
    BOOL     isLocal;
    BOOL     isBluetooth;
    uint32_t interfaceIndex;
    NSString *serviceName;
    NSString *regType;
    NSString *replyDomain;
    NSDate   *dtBrowsed;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        isLocal        = NO;
        isBluetooth    = NO;
        interfaceIndex = (uint32_t) -1;
        serviceName    = nil;
        regType        = nil;
        replyDomain    = nil;
        dtBrowsed      = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [serviceName release];
    serviceName = nil;
    
    [regType release];
    regType = nil;
    
    [replyDomain release];
    replyDomain = nil;
    
    [dtBrowsed release];
    dtBrowsed = nil;
    
    [super dealloc];
}

/*
 *  Return whether this service is being exported from the local device.
 */
-(BOOL) isLocal
{
    return isLocal;
}

/*
 *  The index of the interface.
 */
-(uint32_t) interfaceIndex
{
    return interfaceIndex;
}

/*
 *  Return whether this is a new user service.
 */
-(BOOL) isNewUser
{
    if ([serviceName length] > [CS_serviceRadar servicePrefixLength]) {
        if ([[serviceName substringToIndex:[CS_serviceRadar servicePrefixLength]] isEqualToString:[CS_serviceRadar servicePrefixNewUser]]) {
            return YES;
        }
    }
    return NO;
}

/*
 *  Return whether this is a bluetooth service registration.
 */
-(BOOL) isBluetooth
{
    return isBluetooth;
}

/*
 *  Return the name of the service.
 */
-(NSString *) serviceName
{
    return [[serviceName retain] autorelease];
}

/*
 *  Return the service's registration type.
 */
-(NSString *) regType
{
    return [[regType retain] autorelease];
}

/*
 *  Return the service's reply domain.
 */
-(NSString *) replyDomain
{
    return [[replyDomain retain] autorelease];
}

/*
 *  Compares this object to another.
 */
-(BOOL) isEqual:(id)object
{
    if (![object isKindOfClass:[CS_service class]]) {
        return NO;
    }
    
    CS_service *svcOther = (CS_service *) object;
    if ([serviceName isEqualToString:svcOther.serviceName] &&
        [replyDomain isEqualToString:svcOther.replyDomain] &&
        interfaceIndex == svcOther.interfaceIndex) {
        return YES;
    }
    return NO;
}

/*
 *  Return the date this service was browsed.
 */
-(NSDate *) browseDate
{
    return [[dtBrowsed retain] autorelease];
}

/*
 *  Assign the date this service was browsed.
 */
-(void) setBrowseDate:(NSDate *) dt
{
    if (dt != dtBrowsed) {
        [dtBrowsed release];
        dtBrowsed = [dt retain];
    }
}
@end

/****************************
 CS_service (shared)
 ****************************/
@implementation CS_service (shared)
/*
 *  Assign the local flag to the service record.
 */
-(void) setIsLocal:(BOOL) l
{
    isLocal = l;
}
@end

/****************************
 CS_service (internal)
 ****************************/
@implementation CS_service (internal)
/*
 *  Initialize the object.
 */
+(CS_service *) serviceRecordWithInterface:(uint32_t) interfaceIndex andName:(NSString *) serviceName andType:(NSString *) type andDomain:(NSString *) domain
{
    CS_service *serviceRec = [[[CS_service alloc] init] autorelease];
    serviceRec.interfaceIndex = interfaceIndex;
    serviceRec.serviceName    = serviceName;
    serviceRec.regType        = type;
    serviceRec.replyDomain    = domain;
    return serviceRec;
}

/*
 *  Set the bluetooth behavior on the service.
 */
-(void) setIsBluetooth:(BOOL) bt
{
    isBluetooth = bt;
}

/*
 *  Assign the interface index.
 */
-(void) setInterfaceIndex:(uint32_t) idx
{
    interfaceIndex = idx;
}

/*
 *  Assign the service name.
 */
-(void) setServiceName:(NSString *) sn
{
    if (serviceName != sn) {
        [serviceName release];
        serviceName = [sn retain];
    }
}

/*
 *  Assign the registration type
 */
-(void) setRegType:(NSString *) rt
{
    if (regType != rt) {
        [regType release];
        regType = [rt retain];
    }
}

/*
 *  Assign the reply domain.
 */
-(void) setReplyDomain:(NSString *) rd
{
    if (replyDomain != rd) {
        [replyDomain release];
        replyDomain = [rd retain];
    }
}
@end