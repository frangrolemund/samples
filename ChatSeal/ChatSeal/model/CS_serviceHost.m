//
//  CS_serviceHost.m
//  ChatSeal
//
//  Created by Francis Grolemund on 2/7/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

// - constants
static const NSUInteger     CS_SH_MAX_INTERFACES = 10;          //  It is preferrable to have anything network-attached have some commonsense limits.
static const NSTimeInterval CS_SH_HARDNESS_BAR   = 5.0f;        //  In seconds.

#import "CS_serviceHost.h"
#import "CS_serviceRadar.h"

/*********************
 CS_serviceHost
 *********************/
@implementation CS_serviceHost
/*
 *  Object attributes.
 */
{
    NSMutableArray *maServices;
}

/*
 *  Return the amount of time that must elapse before we can assume that 
 *  a host is hardened.
 */
+(NSTimeInterval) hardnessInterval
{
    return CS_SH_HARDNESS_BAR;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        maServices = [[NSMutableArray alloc] init];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [maServices release];
    maServices = nil;
    
    [super dealloc];
}

/*
 *  Add the given service record to this host.
 */
-(void) addService:(CS_service *) svc
{
    // - limit exposure to a DNS attack, which I'd like to believe is impossible, but just in case.
    if ([maServices count] == CS_SH_MAX_INTERFACES) {
        return;
    }
    
    NSUInteger idx = [maServices indexOfObject:svc];
    if (idx == NSNotFound) {
        // - do a quick check to ensure we're not confusing this
        //   host definition with conflicting entries.
        if ([maServices count] > 0) {
            CS_service *svcOld = [maServices objectAtIndex:0];
            if (svc.isLocal != svcOld.isLocal ||
                svc.isNewUser != svcOld.isNewUser ||
                ![svc.serviceName isEqualToString:svcOld.serviceName]) {
                NSLog(@"CS-ALERT: Incompatible service definitions are being stored in the same host object (%@ != %@).", svc.serviceName, svcOld.serviceName);
            }
        }
        
        [maServices addObject:svc];
    }
    else {
        // - before replacing the existing service, we need
        //   to make sure the browse date is updated because
        //   we didn't actually delete it.
        CS_service *svcOld = [maServices objectAtIndex:idx];
        [svc setBrowseDate:svcOld.browseDate];
        [maServices removeObjectAtIndex:idx];
        [maServices addObject:svc];
    }
}

/*
 *  Discard the recorded service record.
 */
-(void) removeService:(CS_service *) svc
{
    [maServices removeObject:svc];
}

/*
 *  Scan the included services and return the preferred one for
 *  outbound connections.
 */
-(CS_service *) bestServiceForConnection
{
    // - the objective here is to get the oldest connection, which implies
    //   some reliability and favor wireless where possible.
    // - I'm targetting wireless because it will have more throughput than
    //   bluetooth.
    CS_service *svcBest = nil;
    for (CS_service *svc in maServices) {
        if (svcBest == nil ||
            (svcBest.isBluetooth && !svc.isBluetooth) ||
            [svcBest.browseDate compare:svc.browseDate] == NSOrderedDescending) {
            svcBest = svc;
        }
    }
    return svcBest;
}

/*
 *  Returns whether this is my own host definition.
 */
-(BOOL) isLocalHost
{
    if ([maServices count] > 0) {
        CS_service *svc = [maServices objectAtIndex:0];
        return svc.isLocal;
    }
    return NO;
}

/*
 *  Returns whether this host represents a new user definition.
 */
-(BOOL) isNewUser
{
    if ([maServices count] > 0) {
        CS_service *svc = [maServices objectAtIndex:0];
        return svc.isNewUser;
    }
    return NO;
}

/*
 *  Return the number of service interfaces tracked by this object.
 */
-(NSUInteger) interfaceCount
{
    return [maServices count];
}

/*
 *  Returns whether at least one wireless interface exists.
 */
-(BOOL) hasWireless
{
    for (CS_service *svc in maServices) {
        if (!svc.isBluetooth) {
            return YES;
        }
    }
    return NO;
}

/*
 *  Returns whether at least one bluetooth interface exists.
 */
-(BOOL) hasBluetooth
{
    for (CS_service *svc in maServices) {
        if (svc.isBluetooth) {
            return YES;
        }
    }
    return NO;
}

/*
 *  Figure out if this host has been around long enough to assume it
 *  is constant.
 */
-(BOOL) isHardened
{
    NSDate *dtOldest = nil;
    for (CS_service *svc in maServices) {
        NSDate *dtBrowse = svc.browseDate;
        if (!dtOldest || [dtOldest compare:dtBrowse] == NSOrderedDescending) {
            dtOldest = dtBrowse;
        }
    }
    
    // - now compare the date to right now to see whether this host is fairly reliable
    if (dtOldest && (-[dtOldest timeIntervalSinceNow] > CS_SH_HARDNESS_BAR)) {
        return YES;
    }
    else {
        return NO;
    }
}
@end

