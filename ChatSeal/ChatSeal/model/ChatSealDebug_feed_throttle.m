//
//  ChatSealDebug_feed_throttle.m
//  ChatSeal
//
//  Created by Francis Grolemund on 4/2/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "ChatSealDebug_feed_throttle.h"
#import "ChatSeal.h"
#import "CS_centralNetworkThrottle.h"
#import "CS_netThrottledAPIFactory.h"
#import "CS_netFeedAPI.h"

#ifdef CHATSEAL_DEBUGGING_ROUTINES
// - these are copied from the central throttle source so that we can accurately test overall limits.
static const NSUInteger PSD_FT_MAX_UPDOWNLOADS  = 1;
static const NSUInteger PSD_FT_MAX_TRANSIENT    = 15;
static const NSUInteger PSD_FT_MAX_REALTIME     = 2;
static const NSTimeInterval PSD_FT_STD_INTERVAL = 3;
static const NSUInteger PSD_FT_CONCUR_TEST      = 3;
static const NSUInteger PSD_FT_RATE_TEST        = 20;
static const NSTimeInterval PSD_FT_FORCED_INT   = 10;
static const NSUInteger PSD_FT_MAX_FORCED       = 100;
static const NSTimeInterval PSD_FT_EVEN_INT     = 10;
static const NSUInteger PSD_FT_EVEN             = 10;       //  1 per second.
#endif

// - forward declarations
@interface ChatSealDebug_feed_throttle (internal)
+(BOOL) beginFullFeedThrottleTesting;
@end

@interface PSD_API_A : CS_netFeedAPI
@end

@interface PSD_API_B : CS_netFeedAPI
@end

@interface PSD_API_stream : CS_netFeedAPI
@end

@interface PSD_API_C : CS_netFeedAPI
@end

@interface PSD_API_D : CS_netFeedAPI
@end

/****************************
 ChatSealDebug_feed_throttle
 ****************************/
@implementation ChatSealDebug_feed_throttle
/*
 *  Test the feed throttling facilities.
 */
+(void) beginFeedThrottleTesting
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"FEED-THR:  Starting feed throttling testing.");
    if ([ChatSealDebug_feed_throttle beginFullFeedThrottleTesting]) {
        NSLog(@"FEED-THR:  All tests completed successfully.");
    }
#endif
}
@end


/****************************************
 ChatSealDebug_feed_throttle (internal)
 ****************************************/
@implementation ChatSealDebug_feed_throttle (internal)
#ifdef CHATSEAL_DEBUGGING_ROUTINES
/*
 *  Generate a bogus URL.
 */
+(NSURL *) fakeURL
{
    NSUUID *uuid = [NSUUID UUID];
    NSString *sURL = [NSString stringWithFormat:@"http://fake.com/%@", [uuid UUIDString]];
    return [NSURL URLWithString:sURL];
}

/*
 *  Allocate a new API factory.
 */
+(CS_netThrottledAPIFactory *) allocFactoryForNetworkThrottle:(CS_centralNetworkThrottle *) cnt andStatsFile:(NSURL *) uStats
{
    CS_netThrottledAPIFactory *ntaf = [[[CS_netThrottledAPIFactory alloc] initWithNetworkThrottle:cnt] autorelease];
    if ([ntaf hasStatsFileDefined]) {
        NSLog(@"ERROR: The stats file is set and should not be.");
        return nil;
    }
    
    [ntaf addAPIThrottleDefinitionForClass:[PSD_API_stream class] inCategory:CS_CNT_THROTTLE_DOWNLOAD withConcurrentLimit:PSD_FT_CONCUR_TEST];
    [ntaf addAPIThrottleDefinitionForClass:[PSD_API_A class] inCategory:CS_CNT_THROTTLE_TRANSIENT withLimit:PSD_FT_RATE_TEST perInterval:PSD_FT_STD_INTERVAL];
    [ntaf addAPIThrottleDefinitionForClass:[PSD_API_B class] inCategory:CS_CNT_THROTTLE_TRANSIENT withLimit:PSD_FT_RATE_TEST perInterval:PSD_FT_STD_INTERVAL];
    [ntaf addAPIThrottleDefinitionForClass:[PSD_API_C class] inCategory:CS_CNT_THROTTLE_TRANSIENT withLimit:PSD_FT_MAX_FORCED perInterval:PSD_FT_FORCED_INT];
    [ntaf addAPIThrottleDefinitionForClass:[PSD_API_D class] inCategory:CS_CNT_THROTTLE_TRANSIENT withLimit:PSD_FT_EVEN perInterval:PSD_FT_EVEN_INT];
    
    NSError *err = nil;
    if (![ntaf setThrottleStatsFile:uStats withError:&err]) {
        NSLog(@"ERROR: Failed to assign the throttle stats file.  %@", [err localizedDescription]);
        return nil;
    }
    
    if (![ntaf hasStatsFileDefined]) {
        NSLog(@"ERROR: failed to identify that the stats file is now defined.");
        return nil;
    }
    
    if (![ntaf isOpen]) {
        NSLog(@"ERROR: failed to identify that the file is now open.");
        return nil;
    }
    return [ntaf retain];
}

/*
 *  Test the more interesting throttling concepts including those that revolve around limits on the APIs returned.
 */
+(BOOL) runTest_3IntegratedThrottleWithLimits
{
    NSLog(@"FEED-THR:  TEST-03:  Beginning integrated throttle limit testing.");
    CS_centralNetworkThrottle *cnt = [[[CS_centralNetworkThrottle alloc] init] autorelease];
    NSError *err = nil;
    if (![cnt openWithError:&err]) {
        NSLog(@"ERROR: Failed to open the central network throttle.  %@", [err localizedDescription]);
        return NO;
    }
    [cnt assignInitialStatePendingDownloadURLs:[NSArray array]];
    [cnt assignInitialStatePendingUploadURLs:[NSArray array]];
    
    NSURL *uFile = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    uFile        = [uFile URLByAppendingPathComponent:@"throttle-concur-test"];
    [[NSFileManager defaultManager] removeItemAtURL:uFile error:nil];
    CS_netThrottledAPIFactory *ntaf = [[ChatSealDebug_feed_throttle allocFactoryForNetworkThrottle:cnt andStatsFile:uFile] autorelease];
    if (!ntaf) {
        return NO;
    }
    
    NSLog(@"FEED-THR:  TEST-03:  - checking concurrent limits.");
    BOOL wasThrottled = NO;
    [cnt setActiveThrottleCategory:CS_CNT_THROTTLE_DOWNLOAD];
    for (NSUInteger i = 0; i < 100; i++) {
        @autoreleasepool {
            NSObject *obj = [ntaf apiForName:@"PSD_API_stream" andReturnWasThrottled:nil withError:&err];
            if (!obj || ![obj isKindOfClass:[PSD_API_stream class]]) {
                NSLog(@"ERROR: Failed to get a concurrent object in iteration %u.  %@", (unsigned) i, [err localizedDescription]);
                return NO;
            }
            
            // - simulate tracking of that API
            NSURL *u = [ChatSealDebug_feed_throttle fakeURL];
            
            [cnt startPendingURLRequest:u inCategory:CS_CNT_THROTTLE_DOWNLOAD];
            
            // - and check that the request is throttled.
            wasThrottled = NO;
            obj = [ntaf apiForName:@"PSD_API_stream" andReturnWasThrottled:&wasThrottled withError:&err];
            if (obj || !wasThrottled) {
                NSLog(@"ERROR: failed to enforce throttling in the central category from the factory for concurrent streams.");
            }
            
            // - let the central object forget about it now.
            [cnt completePendingURLRequest:u inCategory:CS_CNT_THROTTLE_DOWNLOAD];

            // - now attempt allocate more up to the API limit
            for (NSUInteger j = 0; j < PSD_FT_CONCUR_TEST-1; j++) {
                obj = [ntaf apiForName:@"PSD_API_stream" andReturnWasThrottled:nil withError:&err];
                if (!obj || ![obj isKindOfClass:[PSD_API_stream class]]) {
                    NSLog(@"ERROR: Failed to get a secondary concurrent object in iteration %u.  %@", (unsigned) j, [err localizedDescription]);
                    return NO;
                }
            }
            
            // - and retrieve one more, which should also fail.
            wasThrottled = NO;
            obj = [ntaf apiForName:@"PSD_API_stream" andReturnWasThrottled:&wasThrottled withError:&err];
            if (obj || !wasThrottled) {
                NSLog(@"ERROR: failed to enforce throttling in the api factory for concurrent streams..");
            }
        }
    }
    
    NSLog(@"FEED-THR:  TEST-03:  - checking rate limits.");
    uFile = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    uFile = [uFile URLByAppendingPathComponent:@"throttle-rate-test"];
    [[NSFileManager defaultManager] removeItemAtURL:uFile error:nil];
    [cnt setActiveThrottleCategory:CS_CNT_THROTTLE_TRANSIENT];
    for (NSUInteger i = 0; i < 5; i++) {
        @autoreleasepool {
            CS_netThrottledAPIFactory *ntafRate = [[ChatSealDebug_feed_throttle allocFactoryForNetworkThrottle:cnt andStatsFile:uFile] autorelease];
            if (!ntafRate) {
                return NO;
            }
            
            // - test that after reopening in later iterations that we are rate limited.
            if (i > 0) {
                NSObject *obj = [ntafRate apiForName:@"PSD_API_B" andReturnWasThrottled:&wasThrottled withError:&err];
                if (obj || !wasThrottled) {
                    NSLog(@"ERROR: Failed to see throttling of an initial throttling message after starting up in iteration %u.", (unsigned)i);
                    return NO;
                }
        
                // - ensure that we can continue.
                sleep((unsigned) PSD_FT_STD_INTERVAL + 1);
            }
            
            NSLog(@"FEED-THR:  TEST-03:  ...rate iteration %u.", (unsigned) i);            
            
            // - now issue a bunch of calls, which should all pass.
            for (NSUInteger j = 0; j < PSD_FT_RATE_TEST; j++) {
                NSObject *obj = [ntafRate apiForName:@"PSD_API_B" andReturnWasThrottled:&wasThrottled withError:&err];
                if (!obj) {
                    NSLog(@"ERROR: Failed to generate a new rate-limited API instance in iteration %u.  %@", (unsigned) j, [err localizedDescription]);
                    return NO;
                }
            }
            
            // - this one should fail.
            NSObject *obj = [ntafRate apiForName:@"PSD_API_B" andReturnWasThrottled:&wasThrottled withError:&err];
            if (obj || !wasThrottled) {
                NSLog(@"ERROR: Failed to get a final throttling message after starting up in iteration %u.", (unsigned)i);
                return NO;
            }
            
            // - the other should be ok.
            obj = [ntafRate apiForName:@"PSD_API_A" andReturnWasThrottled:&wasThrottled withError:&err];
            if (!obj) {
                NSLog(@"ERROR: Failed to generate an API instance for the one that had not activity.");
                return NO;
            }
        }
    }
    
    NSLog(@"FEED-THR:  TEST-03:  - verifying that even distribution works.");
    NSUInteger count = 0;
    NSTimeInterval tiLast = 0;
    [cnt setActiveThrottleCategory:CS_CNT_THROTTLE_TRANSIENT];    
    for (;count < PSD_FT_EVEN;) {
        NSObject *obj = [ntaf apiForName:@"PSD_API_D" andRequestEvenDistribution:YES andReturnWasThrottled:&wasThrottled withError:&err];
        NSTimeInterval tiCur = [NSDate date].timeIntervalSince1970;
        if (obj) {
            if (tiCur - tiLast < ((PSD_FT_EVEN_INT/(NSTimeInterval) PSD_FT_EVEN)*0.99)) {
                NSLog(@"ERROR: the time interval is too short for even distribution = %4.2f", tiCur - tiLast);
                return NO;
            }
            NSLog(@"- got an object.");
            count++;
            tiLast = tiCur;
        }
        else {
            if (tiCur - tiLast > PSD_FT_EVEN_INT) {
                NSLog(@"ERROR: it is taking too long.");
                return NO;
            }
        }
    }

    NSLog(@"FEED-THR:  TEST-03:  Integrated limit testing completed successfully.");
    return YES;
}

/*
 *  Test the basic concepts with the generic API without bumping into limits yet.
 */
+(BOOL) runTest_2GenericAPIThrottle
{
    NSLog(@"FEED-THR:  TEST-02:  Beginning generic API throttle testing.");
    
    CS_centralNetworkThrottle *cnt = [[[CS_centralNetworkThrottle alloc] init] autorelease];
    NSError *err = nil;
    if (![cnt openWithError:&err]) {
        NSLog(@"ERROR: Failed to open the central network throttle.  %@", [err localizedDescription]);
        return NO;
    }
    [cnt assignInitialStatePendingDownloadURLs:[NSArray array]];
    [cnt assignInitialStatePendingUploadURLs:[NSArray array]];
    
    NSURL *uFile = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    uFile        = [uFile URLByAppendingPathComponent:@"throttle-generic-test"];
    [[NSFileManager defaultManager] removeItemAtURL:uFile error:nil];
    CS_netThrottledAPIFactory *ntaf = [ChatSealDebug_feed_throttle allocFactoryForNetworkThrottle:cnt andStatsFile:uFile];
    if (!ntaf) {
        return NO;
    }
    
    // - let it go so that we can recreate it below.
    [ntaf release];
    
    NSLog(@"FEED-THR:  TEST-02:  - requesting API instances.");
    NSDate *dLast = nil;
    for (NSUInteger i = 0; i < 10; i++) {
        BOOL wasThrottled = NO;
        NSDate *dBefore = nil;
        NSDate *dAfter = nil;
        @autoreleasepool {
            CS_netThrottledAPIFactory *ntafTmp = [[ChatSealDebug_feed_throttle allocFactoryForNetworkThrottle:cnt andStatsFile:uFile] autorelease];
            if (!ntafTmp) {
                return NO;
            }
            
            [cnt setActiveThrottleCategory:CS_CNT_THROTTLE_DOWNLOAD];
            dBefore = [ntafTmp lastRequestDateForCategory:CS_CNT_THROTTLE_DOWNLOAD];
            NSDate *dNow = [NSDate date];
            if (dLast && ([dLast compare:dBefore] != NSOrderedDescending || [dLast compare:dNow] != NSOrderedAscending)) {
                NSLog(@"ERROR: the last request date is not valid after re-opening.");
                return NO;
            }
            NSObject *obj = [ntafTmp apiForName:@"PSD_API_stream" andReturnWasThrottled:&wasThrottled withError:&err];
            if (!obj) {
                NSLog(@"ERROR: failed to get a stream instance in iteration %u.  %@", (unsigned) i, [err localizedDescription]);
                return NO;
            }
            if (![obj isKindOfClass:[PSD_API_stream class]]) {
                NSLog(@"ERROR: the stream instance handle is invalid in iteration %u.", (unsigned) i);
                return NO;
            }
            dAfter = [ntafTmp lastRequestDateForCategory:CS_CNT_THROTTLE_DOWNLOAD];
            
            if ([dBefore compare:dAfter] != NSOrderedAscending) {
                NSLog(@"ERROR: the stream request did not update the request date.");
            }
            
            obj = [ntafTmp apiForName:@"foobar" andReturnWasThrottled:&wasThrottled withError:nil];
            if (obj) {
                NSLog(@"ERROR: returned an handle for an invalid in stance in iteration %u", (unsigned) i);
                return NO;
            }
            
            if (wasThrottled) {
                NSLog(@"ERROR: incorrectly identified a failure as a throttle event.");
                return NO;
            }
            
            [cnt setActiveThrottleCategory:CS_CNT_THROTTLE_TRANSIENT];
            dBefore = [ntafTmp lastRequestDateForCategory:CS_CNT_THROTTLE_TRANSIENT];
            obj = [ntafTmp apiForName:@"PSD_API_A" andReturnWasThrottled:&wasThrottled withError:&err];
            if (!obj) {
                NSLog(@"ERROR: failed to get an API-A instance in iteration %u.  %@", (unsigned) i,  [err localizedDescription]);
                return NO;
            }
            if (![obj isKindOfClass:[PSD_API_A class]]) {
                NSLog(@"ERROR: the API-A instance handle is invalid in iteration %u.", (unsigned) i);
                return NO;
            }
            dAfter = [ntafTmp lastRequestDateForCategory:CS_CNT_THROTTLE_TRANSIENT];
            if ([dBefore compare:dAfter] != NSOrderedAscending) {
                NSLog(@"ERROR: the API-A request did not update the request date.");
            }
            
            dBefore = [ntafTmp lastRequestDateForCategory:CS_CNT_THROTTLE_TRANSIENT];
            obj = [ntafTmp apiForName:@"PSD_API_B" andReturnWasThrottled:&wasThrottled withError:&err];
            if (!obj) {
                NSLog(@"ERROR: failed to get an API-B instance in iteration %u.  %@", (unsigned) i, [err localizedDescription]);
                return NO;
            }
            if (![obj isKindOfClass:[PSD_API_B class]]) {
                NSLog(@"ERROR: the API-B instance handle is invalid in iteration %u.", (unsigned) i);
                return NO;
            }
            dAfter = [ntafTmp lastRequestDateForCategory:CS_CNT_THROTTLE_TRANSIENT];
            if ([dBefore compare:dAfter] != NSOrderedAscending) {
                NSLog(@"ERROR: the API-B request did not update the request date.");
            }
            dLast = [dAfter retain];
        }
        
        [dLast autorelease];
    }
    
    NSLog(@"FEED-THR:  TEST-02:  - verifying forced throttling.");
    CS_netThrottledAPIFactory *ntafTmp = [[ChatSealDebug_feed_throttle allocFactoryForNetworkThrottle:cnt andStatsFile:uFile] autorelease];
    if (!ntafTmp) {
        return NO;
    }
    
    time_t tBegin = 0;
    for (NSUInteger i = 0; i < 10; i++) {
        BOOL wasThrottled;
        PSD_API_C *ac = (PSD_API_C *) [ntafTmp apiForName:@"PSD_API_C" andReturnWasThrottled:&wasThrottled withError:&err];
        if (!ac) {
            NSLog(@"ERROR: Failed to retrieve PSD_API_C instance %u.  %@", (unsigned) i, [err localizedDescription]);
            return NO;
        }
        
        // - for the last one, use it to force-throttle the factory.
        if (i == 9) {
            tBegin = time(NULL);
            [ntafTmp throttleAPIForOneCycle:ac];
        }
    }
    
    for (NSUInteger i = 0; i < PSD_FT_FORCED_INT * 2; i++) {
        BOOL wasThrottled = NO;
        PSD_API_C *ac = (PSD_API_C *) [ntafTmp apiForName:@"PSD_API_C" andReturnWasThrottled:&wasThrottled withError:&err];
        if (ac) {
            break;
        }
        if (!wasThrottled) {
            NSLog(@"ERROR: API was not throttled as expected.");
            return NO;
        }
        NSLog(@"- APi was throttled artificially.");
        sleep(1);
    }
    
    PSD_API_C *ac = (PSD_API_C *) [ntafTmp apiForName:@"PSD_API_C" andReturnWasThrottled:NULL withError:&err];
    if (!ac) {
        NSLog(@"ERROR: Failed to unthrottle the API again.");
        return NO;
    }
    
    time_t tDiff = time(NULL) - tBegin;
    if (tDiff < PSD_FT_FORCED_INT) {
        NSLog(@"ERROR: The factory was unthrottled too soon (%u versus %u seconds).", (unsigned) tDiff, (unsigned) PSD_FT_FORCED_INT);
        return NO;
    }
    
    
    NSLog(@"FEED-THR:  TEST-02:  Generic API testing completed successfully.");
    return YES;
}

/*
 *  Give the central throttle a decent test of its features.
 */
+(BOOL) runTest_1CentralThrottle
{
    NSLog(@"FEED-THR:  TEST-01:  Beginning central throttle testing.");
    CS_centralNetworkThrottle *cnt = [[[CS_centralNetworkThrottle alloc] init] autorelease];
    NSError *err = nil;
    if (![cnt openWithError:&err]) {
        NSLog(@"ERROR: Failed to open the central network throttle.  %@", [err localizedDescription]);
        return NO;
    }
        
    NSLog(@"FEED-THR:  TEST-01:  - verifying that throttle types are observed");
    for (cs_cnt_throttle_category_t cat = 0; cat < CS_CNT_THROTTLE_COUNT; cat++) {
        [cnt setActiveThrottleCategory:cat];
        
        for (cs_cnt_throttle_category_t catCheck = 0; catCheck < CS_CNT_THROTTLE_COUNT; catCheck++) {
            if (cat == catCheck) {
                continue;
            }
            
            if ([cnt canStartPendingRequestInCategory:catCheck]) {
                NSLog(@"ERROR: The central throttle is allowing a new pending request for category %d with active one at %d.", catCheck, cat);
                return NO;
            }
        }
    }
    
    NSLog(@"FEED-THR:  TEST-01:  - checking that startup limits are enforced");
    NSMutableArray *maUpload   = [NSMutableArray array];
    for (NSUInteger i = 0; i < PSD_FT_MAX_UPDOWNLOADS; i++) {
        [maUpload addObject:[ChatSealDebug_feed_throttle fakeURL]];
    }
    
    NSMutableArray *maDownload = [NSMutableArray array];
    for (NSUInteger i = 0; i < PSD_FT_MAX_UPDOWNLOADS; i++) {
        [maDownload addObject:[ChatSealDebug_feed_throttle fakeURL]];
    }
    
    [cnt assignInitialStatePendingUploadURLs:maUpload];
    [cnt assignInitialStatePendingDownloadURLs:maDownload];
    
    NSURL *uTest = [ChatSealDebug_feed_throttle fakeURL];
    [cnt setActiveThrottleCategory:CS_CNT_THROTTLE_UPLOAD];
    if ([cnt startPendingURLRequest:uTest inCategory:CS_CNT_THROTTLE_UPLOAD]) {
        NSLog(@"ERROR: Failed to restrict upload additions.");
        return NO;
    }
    
    [cnt setActiveThrottleCategory:CS_CNT_THROTTLE_DOWNLOAD];
    if ([cnt startPendingURLRequest:uTest inCategory:CS_CNT_THROTTLE_DOWNLOAD]) {
        NSLog(@"ERROR: Failed to restrict download additions.");
        return NO;
    }
    
    for (NSURL *u in maUpload) {
        [cnt completePendingURLRequest:u inCategory:CS_CNT_THROTTLE_UPLOAD];
    }
    
    for (NSURL *u in maDownload) {
        [cnt completePendingURLRequest:u inCategory:CS_CNT_THROTTLE_DOWNLOAD];
    }
    
    NSLog(@"FEED-THR:  TEST-01:  - verifying general limiting behavior");
    NSMutableArray *arrTmp = [NSMutableArray array];
    for (cs_cnt_throttle_category_t cat = 0; cat < CS_CNT_THROTTLE_COUNT; cat++) {
        [cnt setActiveThrottleCategory:cat];
        NSUInteger limit = 0;
        switch (cat) {
            case CS_CNT_THROTTLE_UPLOAD:
                limit = PSD_FT_MAX_UPDOWNLOADS;
                break;
                
            case CS_CNT_THROTTLE_DOWNLOAD:
                limit = PSD_FT_MAX_UPDOWNLOADS;
                break;
                
            case CS_CNT_THROTTLE_TRANSIENT:
                limit = PSD_FT_MAX_TRANSIENT;
                break;
                
            case CS_CNT_THROTTLE_REALTIME:
                limit = PSD_FT_MAX_REALTIME;
                break;
                
            default:
                limit = 0;
                break;
        }
        
        for (NSUInteger i = 0; i < limit; i++) {
            NSURL *uTmp = [ChatSealDebug_feed_throttle fakeURL];
            [arrTmp addObject:uTmp];
            if (![cnt startPendingURLRequest:uTmp inCategory:cat]) {
                NSLog(@"ERROR: Failed to start a pending request in category %d.", cat);
                return NO;
            }
        }
        
        // - try to start one extra, should fail.
        if ([cnt startPendingURLRequest:[ChatSealDebug_feed_throttle fakeURL] inCategory:cat]) {
            NSLog(@"ERROR: Started more requests than we can handle.");
            return NO;
        }
        
        for (NSURL *u in arrTmp) {
            [cnt completePendingURLRequest:u inCategory:cat];
        }
        [arrTmp removeAllObjects];
    }
    
    NSLog(@"FEED-THR:  TEST-01:  Central throttle testing completed successfully.");
    return YES;
}


#endif
/*
 *  Test all aspects of feed throttling.
 */
+(BOOL) beginFullFeedThrottleTesting
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    if(![ChatSealDebug_feed_throttle runTest_1CentralThrottle] ||
       ![ChatSealDebug_feed_throttle runTest_2GenericAPIThrottle] ||
       ![ChatSealDebug_feed_throttle runTest_3IntegratedThrottleWithLimits]) {
        return NO;
    }
#endif
    return YES;
}
@end

/******************
 PSD_API_A
 ******************/
@implementation PSD_API_A
@end

/******************
 PSD_API_B
 ******************/
@implementation PSD_API_B
@end


/******************
 PSD_API_stream
 ******************/
@implementation PSD_API_stream
@end

/******************
 PSD_API_C
 ******************/
@implementation PSD_API_C
@end

/******************
 PSD_API_D
 ******************/
@implementation PSD_API_D
@end

