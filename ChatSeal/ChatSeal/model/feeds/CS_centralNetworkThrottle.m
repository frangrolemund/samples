//
//  CS_centralNetworkThrottle.m
//  ChatSeal
//
//  Created by Francis Grolemund on 3/31/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_centralNetworkThrottle.h"

//  THREADING-NOTES:
//  - internal locking is provided.
//  - this object is used during the initiation and completion of every single API request and can occur on
//    any thread in the app.  Specifically, the CS_netThrottledAPIFactory instances associated with each feed
//    will all route through this class to ensure that overall local network throttling is enforced.

// - constants
static const NSUInteger CS_CNT_MAX_UPLOAD_OR_DOWNLOAD = 1;           // bandwidth is very limited on a device so we only allow one of either at a time
static const NSUInteger CS_CNT_MAX_TRANSIENT          = 15;
static const NSUInteger CS_CNT_MAX_REALTIME           = 2;           // Realtime updates could bog down the device, keep these limited

// - forward declarations
@interface CS_centralNetworkThrottle (internal)
-(void) assignLongRunningInitialStateForCategory:(cs_cnt_throttle_category_t) cat withArray:(NSArray *) arr;
-(BOOL) canStartPendingRequestInCategoryWithoutLock:(cs_cnt_throttle_category_t)cat andAllowNonActive:(BOOL) allowNonActive;
@end

// - shared declarations
@interface CS_centralNetworkThrottle (shared)
-(void) setActiveThrottleCategory:(cs_cnt_throttle_category_t) cat;
@end

/******************************
 CS_centralNetworkThrottle
 ******************************/
@implementation CS_centralNetworkThrottle
/*
 *  Object attributes.
 */
{
    BOOL                       isOpen;
    cs_cnt_throttle_category_t activeCategory;
    NSMutableArray             *maPendingURLs[CS_CNT_THROTTLE_COUNT];
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        isOpen = NO;
        for (NSUInteger i = 0; i  < CS_CNT_THROTTLE_COUNT; i++) {
            maPendingURLs[i] = nil;
        }
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [self close];
    [super dealloc];
}

/*
 *  Open the throttle object and prepare it for use.
 */
-(BOOL) openWithError:(NSError **) err
{
    @synchronized (self) {
        if (isOpen) {
            return YES;
        }
        activeCategory = CS_CNT_THROTTLE_TRANSIENT;
        for (NSUInteger i = 0; i < CS_CNT_THROTTLE_COUNT; i++) {
            // - upload and download state must be externally configured because
            //   I intend them to be backgrounded and persistent.
            if (i != CS_CNT_THROTTLE_UPLOAD && i != CS_CNT_THROTTLE_DOWNLOAD) {
                maPendingURLs[i] = [[NSMutableArray alloc] init];
            }
        }
        return  YES;
    }
}

/*
 *  The central throttle will not permit any uploads to occur until the initial state
 *  of pending URLs is provided.  This should be a very simple thing to gather from the 
 *  NSURLSession object because if it is a background session, these can be queried.
 */
-(void) assignInitialStatePendingUploadURLs:(NSArray *) arr
{
    [self assignLongRunningInitialStateForCategory:CS_CNT_THROTTLE_UPLOAD withArray:arr];
}

/*
 *  The central throttle will not permit any uploads to occur until the initial state
 *  of pending URLs is provided.  This should be a very simple thing to gather from the
 *  NSURLSession object because if it is a background session, these can be queried.
 */
-(void) assignInitialStatePendingDownloadURLs:(NSArray *) arr
{
    [self assignLongRunningInitialStateForCategory:CS_CNT_THROTTLE_DOWNLOAD withArray:arr];
}

/*
 *  Close the throttle object.
 */
-(void) close
{
    @synchronized (self) {
        for (NSUInteger i = 0; i < CS_CNT_THROTTLE_COUNT; i++) {
            [maPendingURLs[i] release];
            maPendingURLs[i] = nil;
        }
        isOpen         = NO;
        activeCategory = CS_CNT_THROTTLE_COUNT;
    }
}
/*
 *  Before the collector gives feeds a chance to update their content, it will
 *  adjust the active category to block any competing requests from coming in.
 *  - NOTE: this also enforces a concept of doing things in blocks of similar content
 *    because the network bandwidth needs to be rationed carefully to avoid overuse.  When
 *    a category is not active and tries to be used, it will display a warning below to
 *    give the offending module a chance to be reorganized.  The collector works off the principle
 *    that we work on the most critical things first before indulging in less important requests.
 */
-(void) setActiveThrottleCategory:(cs_cnt_throttle_category_t) cat
{
    @synchronized (self) {
        if (cat > CS_CNT_THROTTLE_COUNT) {
            return;
        }
        activeCategory = cat;
    }
}

/*
 *  Return the active category.
 */
-(cs_cnt_throttle_category_t) activeThrottleCategory
{
    @synchronized (self) {
        return activeCategory;
    }
}

/*
 *  This is intended to be a quicker check of whether pending requests can be initiated without
 *  requiring an active URL first because the act of building the URL could be wasted effort.
 */
-(BOOL) canStartPendingRequestInCategory:(cs_cnt_throttle_category_t) cat
{
    return [self canStartPendingRequestInCategory:cat andAllowNonActiveCategory:NO];
}

/*
 *  This is intended to be a quicker check of whether pending requests can be initiated without
 *  requiring an active URL first because the act of building the URL could be wasted effort.
 *  - if the non-active flag is set to YES, we'll permit non-active categories to be checked without
 *    restriction because they are special cases.
 */
-(BOOL) canStartPendingRequestInCategory:(cs_cnt_throttle_category_t) cat andAllowNonActiveCategory:(BOOL) allowNonActive
{
    @synchronized (self) {
        return [self canStartPendingRequestInCategoryWithoutLock:cat andAllowNonActive:allowNonActive];
    }
}

/*
 *  The central throttle tracks pending requests by URL, which should generally be unique
 *  except for the POST requests, and I think with those, it is enough to know how many are
 *  outstanding.
 *  - the only way this returns NO is if the request should be throttled.
 */
-(BOOL) startPendingURLRequest:(NSURL *) u inCategory:(cs_cnt_throttle_category_t) cat
{
    return [self startPendingURLRequest:u inCategory:cat andAllowNonActiveCategory:NO];
}

/*
 *  The central throttle tracks pending requests by URL, which should generally be unique
 *  except for the POST requests, and I think with those, it is enough to know how many are
 *  outstanding.
 *  - the only way this returns NO is if the request should be throttled.
 */
-(BOOL) startPendingURLRequest:(NSURL *) u inCategory:(cs_cnt_throttle_category_t) cat andAllowNonActiveCategory:(BOOL) allowNonActive
{
    @synchronized (self) {
        if (!u) {
            return NO;
        }
        
        if (![self canStartPendingRequestInCategoryWithoutLock:cat andAllowNonActive:allowNonActive]) {
            return NO;
        }
        
        // - it appears there is room for the request, so we can continue.
        [maPendingURLs[cat] addObject:u];
    }
    
    return YES;
}

/*
 *  Every request must be completed explicitly in the central throttle in order to 
 *  permit others to be accepted.
 */
-(void) completePendingURLRequest:(NSURL *) u inCategory:(cs_cnt_throttle_category_t) cat
{
    @synchronized (self) {
        if (cat > CS_CNT_THROTTLE_COUNT) {
            return;
        }
        [maPendingURLs[cat] removeObject:u];
    }
}
@end

/************************************
 CS_centralNetworkThrottle (internal)
 ************************************/
@implementation CS_centralNetworkThrottle (internal)
/*
 *  Assign the startup state to the given category.
 */
-(void) assignLongRunningInitialStateForCategory:(cs_cnt_throttle_category_t) cat withArray:(NSArray *) arr
{
    if (cat >= CS_CNT_THROTTLE_COUNT) {
        return;
    }
    
    @synchronized (self) {
        if (!arr) {
            arr = [NSArray array];
        }
        
        if (maPendingURLs[cat]) {
            [maPendingURLs[cat] release];
            maPendingURLs[cat] = nil;
        }
        
        maPendingURLs[cat] = [[NSMutableArray arrayWithArray:arr] retain];
    }
}

/*
 *  This method checks for whether the given category can support a new request.
 *  - ASSUMES the lock is held.
 */
-(BOOL) canStartPendingRequestInCategoryWithoutLock:(cs_cnt_throttle_category_t)cat andAllowNonActive:(BOOL) allowNonActive
{
    // - this should never happen if the different feed implementations are respecting their
    //   API categories.  If this fires, then you need to rethink how you're interacting with
    //   the service.
    if (!allowNonActive && cat != activeCategory) {
        NSLog(@"CS-ALERT: Unexpected network category support request.  %d != %d", cat, activeCategory);
        return NO;
    }
    
    // - when the pending URLs are not configured, we need to throttle this request because
    //   we don't know how many are outstanding.
    if (!maPendingURLs[cat]) {
        NSLog(@"CS-ALERT: Partially configured central throttle state.");
        return NO;
    }
    
    // - now check the limits on the requests of each type.
    NSUInteger limit = 0;
    switch (cat) {
        case CS_CNT_THROTTLE_UPLOAD:
        case CS_CNT_THROTTLE_DOWNLOAD:
            limit = CS_CNT_MAX_UPLOAD_OR_DOWNLOAD;
            break;
            
        case CS_CNT_THROTTLE_TRANSIENT:
            limit = CS_CNT_MAX_TRANSIENT;
            break;
            
        case CS_CNT_THROTTLE_REALTIME:
            limit = CS_CNT_MAX_REALTIME;
            break;
            
        default:
            limit = 0;
            break;
    }
 
    // - upload/download are treated as a single bucket because of the limited resources on the
    //   device, it would be problematic to have a 300K upload happing at the same time as a 300K download.
    if (cat == CS_CNT_THROTTLE_UPLOAD || cat == CS_CNT_THROTTLE_DOWNLOAD) {
        if (maPendingURLs[CS_CNT_THROTTLE_UPLOAD] && maPendingURLs[CS_CNT_THROTTLE_DOWNLOAD]) {
            NSUInteger total = maPendingURLs[CS_CNT_THROTTLE_UPLOAD].count + maPendingURLs[CS_CNT_THROTTLE_DOWNLOAD].count;
            if (total >= limit) {
                return NO;
            }
        }
        else {
            NSLog(@"CS-ALERT: Partially configured central throttle state.");
            return NO;
        }
    }
    else {
        if (maPendingURLs[cat].count >= limit) {
            return NO;
        }
    }
    
    return YES;
}
@end
