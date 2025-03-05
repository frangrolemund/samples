//
//  CS_netstatus.m
//  ChatSeal
//
//  Created by Francis Grolemund on 3/5/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <netinet/in.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import "CS_netstatus.h"

//  - forward declarations
@interface CS_netstatus (internal)
-(void) setFlags:(SCNetworkReachabilityFlags) flags;
@end

/*
 *  Called to retain an info object for a netstatus call
 */
static const void *CS_ns_retainInfo(const void *info)
{
    CS_netstatus *statusObj = (CS_netstatus *) info;
    [statusObj retain];
    return info;
}

/*
 *  Called to release an info object for a netstatus call.
 */
static void CS_ns_releaseInfo(const void *info)
{
    CS_netstatus *statusObj = (CS_netstatus *) info;
    [statusObj release];
}

/*
 *  This function is called when reachability status changes for the given target.
 */
static void CS_ns_netreachcallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
    CS_netstatus *statusObj = (CS_netstatus *) info;
    @synchronized (statusObj)
    {
        [statusObj setFlags:flags];
    }
}

/************************
 CS_netstatus
 ************************/
@implementation CS_netstatus
/*
 *  Object attributes.
 */
{
    BOOL                       isLocalWifiOnly;
    SCNetworkReachabilityRef   netReachQuery;
    SCNetworkReachabilityFlags netFlags;
}
@synthesize delegate;

/*
 *  Used to dump the network reachability flags in a more usable format.
 */
-(void) dumpFlagInformation
{
    NSLog(@"DEBUG: NETWORK REACHABILITY FLAGS");
    @synchronized (self)
    {
        if (!netFlags) {
            NSLog(@"DEBUG: - no network available.");
            return;
        }
        
        if (netFlags & kSCNetworkReachabilityFlagsTransientConnection) {
            NSLog(@"DEBUG: - transient connection.");
        }
        
        if (netFlags & kSCNetworkReachabilityFlagsReachable) {
            NSLog(@"DEBUG: - localhost is reachable.");
        }
        
        if (netFlags & kSCNetworkReachabilityFlagsConnectionRequired) {
            NSLog(@"DEBUG: - connection is required.");
        }
        
        if (netFlags & kSCNetworkReachabilityFlagsConnectionOnTraffic) {
            NSLog(@"DEBUG: - connection on traffic.");
        }
        
        if (netFlags & kSCNetworkReachabilityFlagsInterventionRequired) {
            NSLog(@"DEBUG: - intervention required to establish connection.");
        }
        
        if (netFlags & kSCNetworkReachabilityFlagsConnectionOnDemand) {
            NSLog(@"DEBUG: - connection on-demand");
        }
        
        if (netFlags & kSCNetworkReachabilityFlagsIsLocalAddress) {
            NSLog(@"DEBUG: - is local address");
        }
        
        if (netFlags & kSCNetworkReachabilityFlagsIsDirect) {
            NSLog(@"DEBUG: - network reachability is direct to the remote");
        }
        
        if (netFlags & kSCNetworkReachabilityFlagsIsWWAN) {
            NSLog(@"DEBUG: - network reachability through a cell network");
        }
        
        if (netFlags & kSCNetworkReachabilityFlagsConnectionAutomatic) {
            NSLog(@"DEBUG: - network connection is automatic");
        }
    }
}

/*
 *  Initialize the object.
 */
-(id) initForLocalWifiOnly:(BOOL) watchLocalWifi
{
    self = [super init];
    if (self) {
        isLocalWifiOnly = watchLocalWifi;
        netReachQuery   = NULL;
        netFlags        = 0;        
    }
    return self;    
}

/*
 *  Free the object
 */
-(void) dealloc
{
    delegate = nil;
    [self haltStatusQuery];
    [self setFlags:0];
    
    [super dealloc];
}

/*
 *  Begin querying for network information.
 */
-(BOOL) startStatusQuery
{
    BOOL ret = YES;
    if (netReachQuery) {
        return YES;
    }
    
    struct sockaddr_in wifiAddr;
    bzero(&wifiAddr, sizeof(wifiAddr));
    wifiAddr.sin_len = sizeof(wifiAddr);
    wifiAddr.sin_family = AF_INET;
    if (isLocalWifiOnly) {
        // - from the Reachability sample code from Apple, I learned that the Wifi support
        //   can be identified with the IN_LINKLOCALNETNUM address from <netinet/in.h>
        // - but the zero address works great for Internet-based connectivity tests.
        wifiAddr.sin_addr.s_addr = htonl(IN_LINKLOCALNETNUM);
    }
    
    netReachQuery = SCNetworkReachabilityCreateWithAddress(NULL, (const struct sockaddr *) &wifiAddr);
    SCNetworkReachabilityFlags firstFlags = 0;
    if (SCNetworkReachabilityGetFlags(netReachQuery, &firstFlags)) {
        [self setFlags:firstFlags];
        SCNetworkReachabilityContext context = {0, self, CS_ns_retainInfo, CS_ns_releaseInfo, NULL};
        SCNetworkReachabilitySetCallback(netReachQuery, CS_ns_netreachcallback, &context);
        SCNetworkReachabilityScheduleWithRunLoop(netReachQuery, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    }
    else {
        CFRelease(netReachQuery);
        netReachQuery = NULL;
        ret = NO;
    }
    return ret;
}

/*
 *  Stop the query operation.
 */
-(void) haltStatusQuery
{
    if (netReachQuery) {
        SCNetworkReachabilityUnscheduleFromRunLoop(netReachQuery, CFRunLoopGetMain(), kCFRunLoopCommonModes);
        SCNetworkReachabilitySetCallback(netReachQuery, NULL, NULL);
        CFRelease(netReachQuery);
        netReachQuery = NULL;
    }    
}

/*
 *  Returns a flag indicating whether there is sufficient connectivity
 */
-(BOOL) hasConnectivity
{
    //  - Bluetooth isn't reported with these flags and I haven't
    //    yet found a good way to report its status.
    @synchronized (self)
    {
        if (isLocalWifiOnly) {
            //  - It is important not to get confused by a cell-only
            //    connection reported with kSCNetworkReachabilityFlagsIsWWAN
            //    because it isn't useful for the kind of peer-to-peer networking
            //    we need to do here.
            if ((netFlags & kSCNetworkReachabilityFlagsReachable) &&
                (netFlags & kSCNetworkReachabilityFlagsIsDirect)) {
                return YES;
            }
        }
        else {
            // - for the Internet testing I just need to be sure that I have something, it doesn't
            //   matter if it is Wi-Fi or 3G.
            if (netFlags & kSCNetworkReachabilityFlagsReachable) {
                return YES;
            }
        }
        return NO;
    }
}

/*
 *  Issue the delegate notification.
 */
-(void) netStatusChanged:(CS_netstatus *)netStatus
{
    if (delegate && [delegate respondsToSelector:@selector(netStatusChanged:)]) {
        [(NSObject *) delegate performSelectorOnMainThread:@selector(netStatusChanged:) withObject:netStatus waitUntilDone:NO];
    }
}

@end

/************************
 CS_netstatus (internal)
 ************************/
@implementation CS_netstatus (internal)

/*
 *  Safely set the flags
 */
-(void) setFlags:(SCNetworkReachabilityFlags) flags
{
    BOOL changed = NO;
    @synchronized (self)
    {
        if (flags != netFlags) {
            changed = YES;
        }
        netFlags = flags;
    }
    
    // - notify the delegate if a modification was made.
    if (changed) {
        [self netStatusChanged:self];
    }
}

@end
