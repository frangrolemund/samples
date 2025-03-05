//
//  CS_serviceRegistrationV2.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/20/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_serviceRegistrationV2.h"
#import "CS_error.h"
#import <dns_sd.h>

// - forward declarations
@interface CS_serviceRegistrationV2 (internal)
-(void) releaseSocketResources;
-(void) registrationReplyWithFlags:(DNSServiceFlags) flags andError:(DNSServiceErrorType) errorCode andName:(const char *) name andType:(const char *) regtype
                         andDomain:(const char *) domain;
@end

/*
 *  The callback from the bonjour socket to get its data.
 */
static void CS_sr_DNSService_Ready(CFSocketRef s, CFSocketCallBackType callbackType, CFDataRef address, const void *data, void *info)
{
    //  - force the callback to process the reply
    DNSServiceRef sdRef = (DNSServiceRef) info;
    if (sdRef) {
        DNSServiceProcessResult(sdRef);
    }
}

/*
 *  The callback that is issued whenever service registration either completes or fails.
 */
static void CS_sr_DNSServiceRegisterReply(DNSServiceRef sdRef, DNSServiceFlags flags, DNSServiceErrorType errorCode, const char *name, const char *regtype,
                                           const char *domain, void *context)
{
    if (context) {
        CS_serviceRegistrationV2 *svcR = (CS_serviceRegistrationV2 *) context;
        [svcR registrationReplyWithFlags:flags andError:errorCode andName:name andType:regtype andDomain:domain];
    }
}

/*************************
 CS_serviceRegistrationV2
 *************************/
@implementation CS_serviceRegistrationV2
/*
 *  Object attributes
 */
{
    NSString    *svcName;
    uint16_t    svcPort;
    void        *dnsRef;
    CFSocketRef dnsResponderSocket;
    
    int32_t     lastDNSError;
    
    NSString    *regName;
    NSString    *regType;
    NSString    *regDomain;
}
@synthesize delegate;

/*
 *  Return the Bonjour registration type for the service.
 */
+(const char *) serviceRegType
{
    return "_chatseal._tcp";
}

/*
 *  Initialize the object.
 */
-(id) initWithService:(NSString *) svc andPort:(uint16_t) port
{
    self = [super init];
    if (self) {
        svcName                 = [svc retain];
        svcPort                 = port;
        dnsRef                  = NULL;
        dnsResponderSocket      = NULL;
        lastDNSError            = kDNSServiceErr_NotInitialized;
        regName                 = nil;
        regType                 = nil;
        regDomain               = nil;
        delegate                = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    delegate = nil;
    
    [self releaseSocketResources];
    [svcName release];
    svcName = nil;
    
    [super dealloc];
}

/*
 *  Returns whether service is functionally registered.
 */
-(BOOL) isOnline
{
    return (lastDNSError == kDNSServiceErr_NoError ? YES : NO);
}

/*
 *  Return the name of the service that we used for initialization.
 */
-(NSString *) serviceName
{
    return [[svcName retain] autorelease];
}

/*
 *  Return the DNS-verified name and should be equal to the service name.
 */
-(NSString *) dnsVerifiedServiceName
{
    return [[regName retain] autorelease];
}

/*
 *  Register the service
 */
-(BOOL) registerWithError:(NSError **) err
{
    [self releaseSocketResources];
    lastDNSError = kDNSServiceErr_NoError;
    
    //  - first register the service
    //  - to get Bluetooth included, simply add the 'kDNSServiceFlagsIncludeP2P' in the registration.
    DNSServiceErrorType regErr = DNSServiceRegister((DNSServiceRef *) &dnsRef, kDNSServiceFlagsNoAutoRename | kDNSServiceFlagsIncludeP2P, kDNSServiceInterfaceIndexAny,
                                                    [svcName UTF8String], [CS_serviceRegistrationV2 serviceRegType], "", NULL, htons(svcPort), 0, NULL,
                                                    CS_sr_DNSServiceRegisterReply, self);
    if (regErr != kDNSServiceErr_NoError) {
        [CS_error fillError:err withCode:CSErrorSecureServiceNotEnabled forBonjourFailure:regErr];
        return NO;
    }
    
    //  - then wait for it to be completed so that we know how to proceed.
    CFSocketContext sockContext = {0, dnsRef, NULL, NULL, NULL};
    dnsResponderSocket          = CFSocketCreateWithNative(kCFAllocatorDefault, (CFSocketNativeHandle) DNSServiceRefSockFD((DNSServiceRef) dnsRef),
                                                           kCFSocketReadCallBack, CS_sr_DNSService_Ready, &sockContext);
    if (!dnsResponderSocket) {
        [self releaseSocketResources];
        [CS_error fillError:err withCode:CSErrorSecureServiceNotEnabled andFailureReason:@"Failed to build the CF wrapper for the Bonjour server socket."];
        return NO;
    }
    
    CFRunLoopSourceRef rls = CFSocketCreateRunLoopSource(NULL, dnsResponderSocket, 0);
    if (!rls) {
        [self releaseSocketResources];
        [CS_error fillError:err withCode:CSErrorSecureServiceNotEnabled andFailureReason:@"Failed to create a run loop source for the Bonjour server socket."];
        return NO;
    }
    CFRunLoopAddSource(CFRunLoopGetMain(), rls, kCFRunLoopCommonModes);
    CFRelease(rls);
    
    return YES;
}

/*
 *  Return the last reported DNS error.
 */
-(int32_t) lastDNSError
{
    return lastDNSError;
}

@end

/****************************
 CS_serviceRegistrationV2 (internal)
 ****************************/
@implementation CS_serviceRegistrationV2 (internal)
/*
 *  Manage the completion of service registration or log an error.
 */
-(void) registrationReplyWithFlags:(DNSServiceFlags) flags andError:(DNSServiceErrorType) errorCode andName:(const char *) name andType:(const char *) regtype
                         andDomain:(const char *) domain
{
    if (errorCode == kDNSServiceErr_NoError) {
        if (flags & kDNSServiceFlagsAdd) {
            [regName release];
            regName = [[NSString alloc] initWithUTF8String:name];
            [regType release];
            regType = [[NSString alloc] initWithUTF8String:regtype];
            [regDomain release];
            regDomain = [[NSString alloc] initWithUTF8String:domain];
            if (delegate && [delegate respondsToSelector:@selector(serviceRegistrationCompleted:)]) {
                [(NSObject *) delegate performSelectorOnMainThread:@selector(serviceRegistrationCompleted:) withObject:self waitUntilDone:NO];
            }
        }
    }
    else {
        [self releaseSocketResources];
        if (delegate && [delegate respondsToSelector:@selector(serviceRegistrationFailed:)]) {
            [(NSObject *) delegate performSelectorOnMainThread:@selector(serviceRegistrationFailed:) withObject:self waitUntilDone:NO];
        }
    }
    lastDNSError = errorCode;
}

/*
 *  Release the registration resources.
 */
-(void) releaseSocketResources
{
    if (dnsResponderSocket) {
        CFSocketInvalidate(dnsResponderSocket);
        CFRelease(dnsResponderSocket);
        dnsResponderSocket = NULL;
    }
    
    if (dnsRef) {
        DNSServiceRefDeallocate((DNSServiceRef) dnsRef);
        dnsRef = NULL;
    }
    
    [regName release];
    regName = nil;
    
    [regType release];
    regType = nil;
    
    [regDomain release];
    regDomain = nil;
}
@end
