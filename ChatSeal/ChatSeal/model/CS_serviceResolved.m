//
//  CS_serviceResolve.m
//  ChatSeal
//
//  Created by Francis Grolemund on 2/10/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#include <sys/socket.h>
#import <dns_sd.h>
#import "CS_serviceResolved.h"
#import "ChatSeal.h"

// - forward declarations
@interface CS_serviceResolved (internal)
-(void) releaseDNSResources;
-(BOOL) checkForFailedResolution;
-(void) resolutionResponseWithErrorCode:(DNSServiceErrorType) errorCode andHost:(const char *) hosttarget andPort:(uint16_t) port andInterface:(uint32_t) iface;
@end

/*
 *  The DNS resolution socket needs to retain the info argument.
 */
static const void *CS_sr_DNSSocketRetainInfo(const void *info)
{
    id obj = (id) info;
    if ([obj isKindOfClass:[CS_serviceResolved class]]) {
        [obj retain];
    }
    return info;
}

/*
 *  The DNS resolution socket needs to release the info argument.
 */
static void CS_sr_DNSSocketReleaseInfo(const void *info)
{
    id obj = (id) info;
    if ([obj isKindOfClass:[CS_serviceResolved class]]) {
        [obj release];
    }
}

/*
 *  The DNS resolution socket has data ready.
 */
static void CS_sr_DNSSocketDataReady (CFSocketRef s, CFSocketCallBackType callbackType, CFDataRef address, const void *data, void *info)
{
    CS_serviceResolved *servResolve = (CS_serviceResolved *) info;
    if (!servResolve) {
        return;
    }
    // - when the resolution is an error, we need to abort
    [servResolve checkForFailedResolution];
}

/*
 *  Handle service resolution replies.
 */
static void CS_sr_DNSServiceResolveReply(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode, const char *fullname,
                                          const char *hosttarget, uint16_t port, uint16_t txtLen, const unsigned char *txtRecord, void *context)
{
    CS_serviceResolved *servResolve = (CS_serviceResolved *) context;
    if (!servResolve) {
        return;
    }
    [servResolve resolutionResponseWithErrorCode:errorCode andHost:hosttarget andPort:port andInterface:interfaceIndex];
}


/************************
 CS_serviceResolved
 ************************/
@implementation CS_serviceResolved
/*
 *  Object attributes
 */
{
    NSString    *serviceName;
    NSString    *serviceRegType;
    NSString    *serviceDomain;
    BOOL        serviceIsBluetooth;
    uint32_t    serviceInterface;
    
    void        *dnsRef;
    CFSocketRef dnsResolutionSocket;
    
    NSString    *serviceHost;
    uint16_t    servicePort;
}
@synthesize delegate;

/*
 *  Return a quick instance
 */
+(CS_serviceResolved *) resolveWithService:(NSString *) name andRegType:(NSString *) regType andDomain:(NSString *) domain asBluetooth:(BOOL) blueTooth
                                  withIndex:(uint32_t) index
{
    return [[[CS_serviceResolved alloc] initWithService:name andRegType:regType andDomain:domain asBluetooth:blueTooth withIndex:index] autorelease];
}

/*
 *  Initialize the object.
 */
-(id) initWithService:(NSString *) name andRegType:(NSString *) regType andDomain:(NSString *) domain asBluetooth:(BOOL) blueTooth withIndex:(uint32_t) index
{
    self = [super init];
    if (self) {
        serviceName        = [name retain];
        serviceRegType     = [regType retain];
        serviceDomain      = [domain retain];
        serviceIsBluetooth = blueTooth;
        serviceInterface   = index;
        serviceHost        = nil;
        servicePort        = (uint16_t) -1;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [self stopResolution];
    [serviceName release];
    serviceName = nil;
    
    [serviceDomain release];
    serviceDomain = nil;
    
    [serviceRegType release];
    serviceRegType = nil;
    
    [serviceHost release];
    serviceHost = nil;
    servicePort = (uint16_t) -1;
    
    [super dealloc];
}

/*
 *  Service resolution succeeded.
 */
-(void) serviceResolutionSucceeded:(CS_serviceResolved *) resolve
{
    // - I'm calling this directly because I don't want a chance that it will get routed through
    //   the runloop where this object is released.
    if (delegate && [delegate respondsToSelector:@selector(serviceResolutionSucceeded:)]) {
        [delegate serviceResolutionSucceeded:resolve];
    }
}

/*
 *  Service resolution failed.
 */
-(void) serviceResolutionFailed:(CS_serviceResolved *) resolve withError:(NSError *) err
{
    // - I'm calling this directly because I don't want a chance that it will get routed through
    //   the runloop where this object is released.
    if (delegate && [delegate respondsToSelector:@selector(serviceResolutionFailed:withError:)]) {
        [delegate serviceResolutionFailed:resolve withError:err];
    }
}

/*
 *  Attempt to start the resolution process.
 */
-(BOOL) beginResolutionWithError:(NSError **) err
{
    const char *name    = serviceName.UTF8String;
    const char *regtype = serviceRegType.UTF8String;
    const char *domain  = serviceDomain.UTF8String;
    
    // - use the specific interface that the browse reported instead of kDNSServiceInterfaceIndexAny to minimize the
    //   number of resolutions that will occur.
    DNSServiceErrorType svcErr = DNSServiceResolve((DNSServiceRef *) &dnsRef, serviceIsBluetooth ? kDNSServiceFlagsIncludeP2P : 0, serviceInterface,
                                                   name, regtype, domain, CS_sr_DNSServiceResolveReply, self);
    if (svcErr != kDNSServiceErr_NoError) {
        [CS_error fillError:err withCode:CSErrorConnectionFailure forBonjourFailure:svcErr];
        return NO;
    }
    
    CFSocketContext sockContext = {0, self, CS_sr_DNSSocketRetainInfo, CS_sr_DNSSocketReleaseInfo, NULL};
    dnsResolutionSocket = CFSocketCreateWithNative(kCFAllocatorDefault, (CFSocketNativeHandle) DNSServiceRefSockFD((DNSServiceRef) dnsRef), kCFSocketReadCallBack,
                                                   CS_sr_DNSSocketDataReady, &sockContext);
    if (!dnsResolutionSocket) {
        DNSServiceRefDeallocate(dnsRef);
        dnsRef = NULL;
        [CS_error fillError:err withCode:CSErrorConnectionFailure andFailureReason:@"Failed to build the CF wrapper for the Bonjour server socket."];
        return NO;
    }
    
    CFRunLoopSourceRef rls = CFSocketCreateRunLoopSource(NULL, dnsResolutionSocket, 0);
    if (!rls) {
        DNSServiceRefDeallocate(dnsRef);
        CFSocketInvalidate(dnsResolutionSocket);
        CFRelease(dnsResolutionSocket);
        dnsResolutionSocket = NULL;
        [CS_error fillError:err withCode:CSErrorConnectionFailure andFailureReason:@"Failed to create a run loop source for the Bonjour server socket."];
        return NO;
    }
    CFRunLoopAddSource(CFRunLoopGetMain(), rls, kCFRunLoopCommonModes);
    CFRelease(rls);
    return YES;
}

/*
 *  Halt the active resolution.
 */
-(void) stopResolution
{
    delegate = nil;
    [self releaseDNSResources];
}

/*
 *  Return the service name managed by this resolution request.
 */
-(NSString *) serviceName
{
    return [[serviceName retain] autorelease];
}

/*
 *  Return the service's registration type.
 */
-(NSString *) serviceRegType
{
    return [[serviceRegType retain] autorelease];
}

/*
 *  Return the domain of the service.
 */
-(NSString *) serviceDomain
{
    return [[serviceDomain retain] autorelease];
}

/*
 *  Return the resolved service host name.
 */
-(NSString *) serviceHost
{
    return [[serviceHost retain] autorelease];
}

/*
 *  Return the resolved service port.
 */
-(uint16_t) servicePort
{
    return servicePort;
}

/*
 *  Return the unique interface of the service as returned by the resolution.
 */
-(uint32_t) interfaceIndex
{
    return serviceInterface;
}

/*
 *  Returns whether this is expected to be a bluetooth-provided service.
 */
-(BOOL) isBluetooth
{
    return serviceIsBluetooth;
}

/*
 *  Returns whether this object is equal to another.
 */
-(BOOL) isEqual:(id)object
{
    if (!object || ![object isKindOfClass:[CS_serviceResolved class]]) {
        return NO;
    }
    
    CS_serviceResolved *resOther = (CS_serviceResolved *) object;
    if (serviceInterface != resOther->serviceInterface              ||
        ![serviceHost isEqualToString:resOther->serviceHost]        ||
        ![serviceRegType isEqualToString:resOther->serviceRegType]  ||
        ![serviceDomain isEqualToString:resOther->serviceDomain]    ||
        serviceIsBluetooth != resOther->serviceIsBluetooth) {
        return NO;
    }
    return YES;
}
@end


/******************************
 CS_serviceResolved (internal)
 ******************************/
@implementation CS_serviceResolved (internal)
/*
 *  DNS resolution data is available for processing, but this could mean the end of our
 *  process.
 */
-(BOOL) checkForFailedResolution
{
    DNSServiceErrorType errCode = DNSServiceProcessResult(dnsRef);
    if (errCode == kDNSServiceErr_NoError) {
        return YES;
    }
    else {
        NSError *tmp = nil;
        [CS_error fillError:&tmp withCode:CSErrorConnectionFailure forBonjourFailure:errCode];
        [self releaseDNSResources];
        [self serviceResolutionFailed:self withError:tmp];
        return NO;
    }
}

/*
 *  Process the DNS resolution response with the Bonjor-supplied host and target port.
 */
-(void) resolutionResponseWithErrorCode:(DNSServiceErrorType) errorCode andHost:(const char *) hosttarget andPort:(uint16_t) port andInterface:(uint32_t) iface
{
    // - discard the resolution items to prevent further notifications.
    [self releaseDNSResources];
    
    //  - keep the delegate informed.
    if (errorCode != kDNSServiceErr_NoError) {
        NSError *tmp = nil;
        [CS_error fillError:&tmp withCode:CSErrorConnectionFailure forBonjourFailure:errorCode];
        [self serviceResolutionFailed:self withError:tmp];
        return;
    }
    
    //  - the resolution produced a host
    @try {
        serviceHost = [[NSString stringWithUTF8String:hosttarget] retain];
    }
    @catch (NSException *exception) {
        NSLog(@"CS: Unexpected resolution exception.  %@", [exception description]);
        return;
    }
    servicePort      = ntohs(port);
    serviceInterface = iface;                   //  this may change as a result of the resolution, particularly with Bluetooth interfaces.
    [self serviceResolutionSucceeded:self];
}

/*
 *  Release the resources associated with DNS resolution.
 */
-(void) releaseDNSResources
{
    if (dnsResolutionSocket) {
        // - use a temporary variable because invalidating the socket may
        //   force a recursive call into this routine.
        CFSocketRef tmp     = dnsResolutionSocket;
        dnsResolutionSocket = NULL;
        CFSocketInvalidate(tmp);
        CFRelease(tmp);
    }
    
    if (dnsRef) {
        // - again, protect agains recursiion.
        void *tmpDNS = dnsRef;
        dnsRef       = NULL;
        DNSServiceRefDeallocate((DNSServiceRef) tmpDNS);
    }
}
@end
