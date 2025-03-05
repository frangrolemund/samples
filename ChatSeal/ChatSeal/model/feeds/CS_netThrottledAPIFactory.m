//
//  CS_netThrottledAPIFactory.m
//  ChatSeal
//
//  Created by Francis Grolemund on 3/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_netThrottledAPIFactory.h"
#import "ChatSeal.h"
#import "CS_feedShared.h"

//  THREADING-NOTES:
//  - internal locking is provided.
//  - this factory is associated with one or more feeds and is the entry/exit point for every API that is processed
//    in this model and can be called from any thread.
//  - the throttle definition objects are intentionally LOCK FREE in order to keep them simple and because everything can
//    be made to route through the API factory anyway.

// - constants
static const NSTimeInterval CS_NTAF_CONCURRENT_LIMITED = -1.0f;
static NSString *CS_NTAF_STATS_DEFINITIONS             = @"defs";
static NSString *CS_NTAF_STATS_REQUEST_DATES           = @"reqd";

// - forward declarations
@interface CS_netThrottledAPIFactory (internal) <CS_netFeedCreatorDelegateAPI>
-(BOOL) checkIfOpenWithError:(NSError **) err;
-(BOOL) saveThrottleStatsWithError:(NSError **) err;
@end

// - for storing a single definition
@interface _S_throttle_definition : NSObject <NSCoding>
+(_S_throttle_definition *) definitionForClass:(Class) c inCategory:(cs_cnt_throttle_category_t) category withLimit:(NSUInteger) limit andInterval:(NSTimeInterval) interval;
-(BOOL) isConcurrentThrottled;
-(BOOL) hasCapacityAvailableAtPercentage:(float) pctOfLimit withEvenDistribution:(BOOL) evenlyDistributed;
-(CS_netFeedAPI *) throttledAPIWithRateTracking:(BOOL) rateTracked usingCreator:(CS_netFeedCreatorDelegateHandle *) creatorHandle;
-(void) mergeInExternalContent:(_S_throttle_definition *) otherDef;
-(void) accountForAPIDestruction;
-(void) artificiallyThrottleForOneCycle;
-(void) reconfigureThrottleToLimit:(NSUInteger) limit andRemaining:(NSUInteger) numRemaining;
@property (nonatomic, retain) NSString *className;
@property (nonatomic, assign) cs_cnt_throttle_category_t throttleCategory;
@property (nonatomic, assign) cs_cnt_throttle_category_t centralThrottleCategory;
@property (nonatomic, assign) NSUInteger throttleLimit;
@property (nonatomic, assign) NSTimeInterval throttleInterval;
@end

/***************************
 CS_netThrottledAPIFactory
 ***************************/
@implementation CS_netThrottledAPIFactory
/*
 *  Object attributes.
 */
{
    NSMutableDictionary             *mdDefinitions;
    NSMutableArray                  *maRequestDates;
    BOOL                            isOpen;
    NSURL                           *uThrottleFile;
    CS_centralNetworkThrottle       *netThrottle;
    float                           fLimitAdjustmentPct;
    CS_netFeedCreatorDelegateHandle *creatorHandle;
}

/*
 *  Initialize the object.
 */
-(id) initWithNetworkThrottle:(CS_centralNetworkThrottle *) throttle
{
    self = [super init];
    if (self) {
        mdDefinitions       = [[NSMutableDictionary alloc] init];
        maRequestDates      = [[NSMutableArray alloc] initWithCapacity:CS_CNT_THROTTLE_COUNT];
        for (NSUInteger i = 0; i < CS_CNT_THROTTLE_COUNT; i++) {
            [maRequestDates addObject:[NSDate dateWithTimeIntervalSince1970:0]];
        }
        isOpen              = NO;
        uThrottleFile       = nil;
        netThrottle         = [throttle retain];
        fLimitAdjustmentPct = 1.0f;
        creatorHandle       = [[CS_netFeedCreatorDelegateHandle alloc] initWithCreatorDelegate:self];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [creatorHandle stopAllDelegateNotifications];
    [creatorHandle release];
    creatorHandle = nil;
    
    [mdDefinitions release];
    mdDefinitions = nil;
    
    [maRequestDates release];
    maRequestDates = nil;
    
    [uThrottleFile release];
    uThrottleFile = nil;
    
    [netThrottle release];
    netThrottle = nil;
    
    [super dealloc];
}

/*
 *  This simple check will determine whether the stats file is wired up for persistence.
 */
-(BOOL) hasStatsFileDefined
{
    @synchronized (self) {
        if (uThrottleFile) {
            return YES;
        }
    }
    return NO;
}

/*
 *  Return the open state of this factory.
 */
-(BOOL) isOpen
{
    @synchronized (self) {
        if (!isOpen) {
            return [self checkIfOpenWithError:nil];
        }
        return YES;
    }
}

/*
 *  Assign a file location for storing/retrieving throttled API stats.
 */
-(BOOL) setThrottleStatsFile:(NSURL *) statsFile withError:(NSError **) err
{
    @synchronized (self) {
        if (isOpen) {
            return YES;
        }
        
        if (!uThrottleFile || ![uThrottleFile isEqual:statsFile]) {
            [uThrottleFile release];
            uThrottleFile = [statsFile retain];
        }
        
        if (![self checkIfOpenWithError:err]) {
            return NO;
        }
        return YES;
    }
}

/*
 *  This method is provided to limit the APIs managed by a factory instance to some percentage of the
 *  maximum limits.  Some services like Twitter are managed through a central app instance on the device, which
 *  I assume means that a person could conceivably be using part of that limit in another Twitter app, so I don't want to
 *  risk a scenario where I use way more than what a device is permitted.
 */
-(void) setThrottleLimitAdjustmentPercentage:(float) pct
{
    // - this should only be done before the object has been opened for the first time.
    @synchronized (self) {
        if (isOpen) {
            return;
        }
    }

    if (pct > 1.0f) {
        pct = 1.0f;
    }
    if (pct < 0.0f) {
        pct = 0.0f;
    }
    fLimitAdjustmentPct = pct;
}

/*
 *  Creators of the factory will define limits for each type of class that is managed.
 */
-(void) addAPIThrottleDefinitionForClass:(Class) c inCategory:(cs_cnt_throttle_category_t) category withLimit:(NSUInteger) limit perInterval:(NSTimeInterval) interval
{
    // - this should only be done before the object has been opened for the first time.
    @synchronized (self) {
        if (isOpen) {
            return;
        }
        
        _S_throttle_definition *defn = [_S_throttle_definition definitionForClass:c inCategory:category withLimit:limit andInterval:interval];
        if (![mdDefinitions objectForKey:defn.className]) {
            [mdDefinitions setObject:defn forKey:defn.className];
        }
    }
}

/*
 *  Creators of the factory will define limits for each type of class that is managed.
 *  - this API is specifically targeted at streaming APIs that can only have a single instance per application running at a time.
 */
-(void) addAPIThrottleDefinitionForClass:(Class) c inCategory:(cs_cnt_throttle_category_t) category withConcurrentLimit:(NSUInteger) limit
{
    [self addAPIThrottleDefinitionForClass:c inCategory:category withLimit:limit perInterval:CS_NTAF_CONCURRENT_LIMITED];
}

/*
 *  Generate an API object that can be used for making throttled requests.
 *  - To make it very clear when throttling occurs and avoid the need to check the error, I'm returning
 *    the throttled flag as a quick indicator and a reminder that is a potential outcome of this request.
 */
-(CS_netFeedAPI *) apiForName:(NSString *) name andRequestEvenDistribution:(BOOL) evenlyDistributed andReturnWasThrottled:(BOOL *) wasThrottled withError:(NSError **) err
{
    @synchronized (self) {
        if (![self checkIfOpenWithError:err]) {
            if (wasThrottled) {
                *wasThrottled = NO;
            }
            return nil;
        }
        
        // - find the definition.
        _S_throttle_definition *def = [mdDefinitions objectForKey:name];
        if (!def) {
            NSLog(@"CS-ALERT: Unknown API name %@.", name);
            [CS_error fillError:err withCode:CSErrorInvalidArgument];
            if (wasThrottled) {
                *wasThrottled = NO;
            }
            return nil;
        }
        
        // - when a request is throttled centraly in a different category
        //   we'll allow it to pass the throttle's basic 'isActive' qualification, but only
        //   if we're in the current active category.
        BOOL allowNonActive = NO;
        if (def.centralThrottleCategory != def.throttleCategory) {
            if (netThrottle.activeThrottleCategory == def.throttleCategory) {
                allowNonActive = YES;
            }
        }
        
        // - basic check of the feed API type to make sure this is even reasonable right now.
        if (![netThrottle canStartPendingRequestInCategory:def.centralThrottleCategory andAllowNonActiveCategory:allowNonActive] ||
            ![def hasCapacityAvailableAtPercentage:fLimitAdjustmentPct withEvenDistribution:evenlyDistributed]) {
            [CS_error fillError:err withCode:CSErrorFeedLimitExceeded];
            if (wasThrottled) {
                *wasThrottled = YES;
            }
            return nil;
        }
            
        // - we need to create a new API for the given type.
        CS_netFeedAPI *nfa = [def throttledAPIWithRateTracking:YES usingCreator:creatorHandle];
        if (!nfa) {
            [CS_error fillError:err withCode:CSErrorAborted andFailureReason:@"Failure to generate feed API."];
            if (wasThrottled) {
                *wasThrottled = NO;
            }
            return nil;
        }
        
        // - update the request date for this category so that later feed sorts take it into consideration.
        if (def.throttleCategory < [maRequestDates count]) {
            [maRequestDates replaceObjectAtIndex:def.throttleCategory withObject:[NSDate date]];
        }
        
        NSError *tmp = nil;
        if (![self saveThrottleStatsWithError:&tmp]) {
            // - normally we will ignore this inability to save stats because is effect on throttling is fairly minimal as we're
            //   still tracking stats in this process.
            // - if, however the system is very low on storage, that suggests the API will also fail and we should probably
            //   throttle it to be safe and not contribute to an already questionable scenario.
            if ([ChatSeal isLowStorageAConcern]) {
                if (err) {
                    *err = tmp;
                }
                if (wasThrottled) {
                    *wasThrottled = NO;
                }
                return nil;
            }
        }
        
        return nfa;
    }
}

/*
 *  Generate an API object that can be used for making throttled requests.
 *  - To make it very clear when throttling occurs and avoid the need to check the error, I'm returning
 *    the throttled flag as a quick indicator and a reminder that is a potential outcome of this request.
 */
-(CS_netFeedAPI *) apiForName:(NSString *) name andReturnWasThrottled:(BOOL *) wasThrottled withError:(NSError **) err
{
    return [self apiForName:name andRequestEvenDistribution:NO andReturnWasThrottled:wasThrottled withError:err];
}

/*
 *  Re-create an API objet using the given request.
 */
-(CS_netFeedAPI *) apiForExistingRequest:(NSURLRequest *) req
{
    @synchronized (self) {
        if (![self checkIfOpenWithError:nil]) {
            return nil;
        }
        
        // - walk through all the definitions, looking for a candidate.
        for (_S_throttle_definition *def in mdDefinitions.allValues) {
            CS_netFeedAPI *api = [def throttledAPIWithRateTracking:NO usingCreator:creatorHandle];
            if ([api matchesRequest:req]) {
                return api;
            }
        }
    }
    return nil;
}

/*
 *  Because the factory hands out all the requests, it will also track when we last processed an item in the given category.
 *  - This is important because it will allow us to sort the feeds in ascending order from oldest request to newest and
 *    favor the ones that haven't been serviced recently.
 */
-(NSDate *) lastRequestDateForCategory:(cs_cnt_throttle_category_t) category
{
    @synchronized (self) {
        if (!isOpen) {
            return nil;
        }
        
        if (category < [maRequestDates count]) {
            NSDate *d = [maRequestDates objectAtIndex:category];
            return [[d retain] autorelease];
        }
    }
    
    // - if none are provided, assume the request date is now to not give this factory preferential treatment.
    return [NSDate date];
}

/*
 *  Perform a quick check to see if the throttle will even permit this API to be scheduled.
 */
-(BOOL) hasCapacityForAPIByName:(NSString *) name withEvenDistribution:(BOOL) evenlyDistributed andAllowAnyCategory:(BOOL) allowAny
{
    @synchronized (self) {
        if (![self checkIfOpenWithError:nil]) {
            return NO;
        }
        
        // - find the definition.
        _S_throttle_definition *def = [mdDefinitions objectForKey:name];
        if (!def) {
            NSLog(@"CS-ALERT: Unknown API name %@.", name);
            return NO;
        }
        
        // - when a request is throttled centraly in a different category
        //   we'll allow it to pass the throttle's basic 'isActive' qualification, but only
        //   if we're in the current active category.
        BOOL allowNonActive = allowAny;
        if (def.centralThrottleCategory != def.throttleCategory) {
            if (netThrottle.activeThrottleCategory == def.throttleCategory) {
                allowNonActive = YES;
            }
        }
        
        // - basic check of the feed API type to make sure this is even reasonable right now.
        if (![netThrottle canStartPendingRequestInCategory:def.centralThrottleCategory andAllowNonActiveCategory:allowNonActive] ||
            ![def hasCapacityAvailableAtPercentage:fLimitAdjustmentPct withEvenDistribution:evenlyDistributed]) {
            return NO;
        }
    }
    return YES;
}

/*
 *  Update the factory so that the given API will be throttled for one full cycle, usually because the 
 *  owning service has pushed back on us.
 */
-(void) throttleAPIForOneCycle:(CS_netFeedAPI *) api
{
    @synchronized (self) {
        if (![self checkIfOpenWithError:nil]) {
            return;
        }
        
        // - find the definition.
        NSString *sName = NSStringFromClass([api class]);
        if (!sName) {
            return;
        }
        
        NSLog(@"CS: Processing forced throttle of %@ for one cycle.", sName);
        _S_throttle_definition *def = [mdDefinitions objectForKey:sName];
        if (!def) {
            NSLog(@"CS-ALERT: Unknown API request for forced throttle: %@.", sName);
            return;
        }
     
        // - and force it to throttle itself.
        [def artificiallyThrottleForOneCycle];
        [self saveThrottleStatsWithError:nil];
    }
}

/*
 *  Adjust the limits of the given API based on better data than what we had when we started.
 */
-(void) reconfigureThrottleForAPIByName:(NSString *) name toLimit:(NSUInteger) limit andRemaining:(NSUInteger) numRemaining
{
    @synchronized (self) {
        if (![self checkIfOpenWithError:nil]) {
            return;
        }

        // - find the definition.
        _S_throttle_definition *def = [mdDefinitions objectForKey:name];
        if (!def) {
            NSLog(@"CS-ALERT: Unknown API request for forced throttle: %@.", name);
            return;
        }
        
        // - I'm not saving anything here because these limits will be re-retrieved later.
        [def reconfigureThrottleToLimit:limit andRemaining:numRemaining];
    }
}

@end

/***********************************
 CS_netThrottledAPIFactory (internal)
 ***********************************/
@implementation CS_netThrottledAPIFactory (internal)
/*
 *  Attempt to open the output file.
 *  - ASSUMES the lock is held.
 */
-(BOOL) checkIfOpenWithError:(NSError **) err
{
    // - we can never manufacture new API requests without a vault.
    if (![ChatSeal isVaultOpen]) {
        [CS_error fillError:err withCode:CSErrorVaultRequired];
        return NO;
    }
    
    // - already open?
    if (isOpen) {
        return YES;
    }
    
    // - ensure that we have definitions or the file doesn't really make sense.
    if (![mdDefinitions count]) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        return NO;
    }
    
    // - does the file even exist?
    if ([[NSFileManager defaultManager] fileExistsAtPath:[uThrottleFile path]]) {
        NSDictionary *dictLoaded = [CS_feedCollectorUtil secureLoadConfigurationFromFile:uThrottleFile withError:err];
        if (!dictLoaded) {
            // - I don't want a corrupted throttle file to ever contribute to a person's inability to get content
            //   so if we cannot load it and the system appears stable, I'm going to overwrite the throttle stats, which
            //   I think is safe enough to do since we only use a small fraction of the capacity.
            if (![ChatSeal isLowStorageAConcern]) {
                NSLog(@"CS: Throttle stats access interrupted, allowing overwrite.  (%@)", (err && *err) ? [*err localizedDescription] : @"");
                isOpen = YES;
                return YES;
            }
            
            // - low storage scenarios have to be carefully navigated.
            return NO;
        }
        
        // - now we need to merge stats with what was on disk.
        NSArray *arrReqDates = (NSArray *) [dictLoaded objectForKey:CS_NTAF_STATS_REQUEST_DATES];
        if ([arrReqDates count] == [maRequestDates count]) {
            [maRequestDates removeAllObjects];
            [maRequestDates addObjectsFromArray:arrReqDates];
        }
        
        NSDictionary *dictDefs = (NSDictionary *) [dictLoaded objectForKey:CS_NTAF_STATS_DEFINITIONS];
        for (NSString *sName in dictDefs.allKeys) {
            // - we're going to discard definitions that are no longer supported by this app.
            if (![mdDefinitions objectForKey:sName]) {
                continue;
            }
            _S_throttle_definition *tdefSaved   = [dictDefs objectForKey:sName];
            _S_throttle_definition *tdefCurrent = [mdDefinitions objectForKey:sName];
            [tdefCurrent mergeInExternalContent:tdefSaved];
        }
    }
    else {
        // - if the file doesn't yet exist, ensure that we can at least save it once or there is no way
        //   throttling can work.
        if (![self saveThrottleStatsWithError:err]) {
            return NO;
        }
    }
    isOpen = YES;
    return YES;
}

/*
 *  Save the current stats to disk.
 *  - ASSUMES the lock is held.
 */
-(BOOL) saveThrottleStatsWithError:(NSError **) err
{
    // - I track the request dates separately instead of computing them to speed up the sorts that
    //   occur in the collector.
    NSMutableDictionary *mdThrottleData = [NSMutableDictionary dictionary];
    [mdThrottleData setObject:mdDefinitions forKey:CS_NTAF_STATS_DEFINITIONS];
    [mdThrottleData setObject:maRequestDates forKey:CS_NTAF_STATS_REQUEST_DATES];
    
    return [CS_feedCollectorUtil secureSaveConfiguration:mdThrottleData asFile:uThrottleFile withError:err];
}

/*
 *  The creator handle that accompanies every API object will execute this delegate method implicitly
 *  whenever an API is about to be deallocated so that we can unaccount for it.
 */
-(void) willDeallocateAPI:(CS_netFeedAPI *)nfa
{
    if (!nfa) {
        return;
    }
    
    @synchronized (self) {
        _S_throttle_definition *def = [mdDefinitions objectForKey:NSStringFromClass(nfa.class)];
        [def accountForAPIDestruction];
    }
}
@end


/**************************
 _S_throttle_definition
 **************************/
static NSString *PSNT_THRDEF_CLASS_KEY    = @"class";
static NSString *PSNT_THRDEF_CAT_KEY      = @"throttleCategory";
static NSString *PSNT_THRDEF_LIMIT_KEY    = @"throttleLimit";
static NSString *PSNT_THRDEF_INTERVAL_KEY = @"throttleInterval";
static NSString *PSNT_THRDEF_STATS_KEY    = @"throttleStats";
@implementation _S_throttle_definition
/*
 *  Object attributes.
 */
{
    NSUInteger                       numConcurrentAPIs;
    NSMutableArray                   *maRateLimitedAPIs;
}
@synthesize className;
@synthesize throttleCategory;
@synthesize centralThrottleCategory;
@synthesize throttleLimit;
@synthesize throttleInterval;

/*
 *  Create a mew throttle definition object.
 */
+(_S_throttle_definition *) definitionForClass:(Class) c inCategory:(cs_cnt_throttle_category_t) category withLimit:(NSUInteger) limit andInterval:(NSTimeInterval) interval
{
    _S_throttle_definition *defn = [[_S_throttle_definition alloc] init];
    defn.className                = NSStringFromClass(c);
    defn.throttleCategory         = category;
    CS_netFeedAPI *nfa           = [[ c alloc] initWithCreatorHandle:nil inCategory:category];
    defn.centralThrottleCategory  = nfa.centralThrottleCategory;
    [nfa release];
    defn.throttleLimit            = limit;
    defn.throttleInterval         = interval;
    return [defn autorelease];
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        className         = nil;
        throttleLimit     = 0;
        throttleCategory  = CS_CNT_THROTTLE_TRANSIENT;
        throttleInterval  = 0.0f;
        numConcurrentAPIs = 0;
        maRateLimitedAPIs = nil;
    }
    return self;
}

/*
 *  Initialize and decode the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        className         = [[aDecoder decodeObjectForKey:PSNT_THRDEF_CLASS_KEY] retain];
        throttleCategory  = (cs_cnt_throttle_category_t) [aDecoder decodeIntegerForKey:PSNT_THRDEF_CAT_KEY];
        throttleLimit     = (NSUInteger) [aDecoder decodeIntegerForKey:PSNT_THRDEF_LIMIT_KEY];
        throttleInterval  = (NSTimeInterval) [aDecoder decodeDoubleForKey:PSNT_THRDEF_INTERVAL_KEY];
        numConcurrentAPIs = 0;
        maRateLimitedAPIs = nil;
        if (throttleInterval >= 0.0f) {         // don't use isConcurrentThrottled because that will allocate the array.
            NSArray *arr = [aDecoder decodeObjectForKey:PSNT_THRDEF_STATS_KEY];
            if (arr) {
                maRateLimitedAPIs = [[NSMutableArray alloc] initWithArray:arr];
            }
        }
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [className release];
    className = nil;
    
    [maRateLimitedAPIs release];
    maRateLimitedAPIs = nil;
    
    [super dealloc];
}

/*
 *  Encode the content in this object.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:className forKey:PSNT_THRDEF_CLASS_KEY];
    [aCoder encodeInteger:(NSInteger) throttleCategory forKey:PSNT_THRDEF_CAT_KEY];
    [aCoder encodeInteger:(NSInteger) throttleLimit forKey:PSNT_THRDEF_LIMIT_KEY];
    [aCoder encodeDouble:(double) throttleInterval forKey:PSNT_THRDEF_INTERVAL_KEY];
    
    // - concurrent APIs are only throttled per app instance, not across instances, so there
    //   is nothing to persist for them.
    if (![self isConcurrentThrottled]) {
        [aCoder encodeObject:maRateLimitedAPIs forKey:PSNT_THRDEF_STATS_KEY];
    }
}

/*
 *  Concurrent access throttling is intended to ensure that apps respect the limits applied to
 *  a single application instance (mostly for streaming).
 */
-(BOOL) isConcurrentThrottled
{
    if (throttleInterval < 0.0f) {
        return YES;
    }
    else {
        if (!maRateLimitedAPIs) {
            maRateLimitedAPIs = [[NSMutableArray alloc] init];
        }
        return NO;
    }
}

/*
 *  Return the current time as a simple interval we can use for comparison.
 */
-(int32_t) currentTimeAsInterval
{
     return (int32_t) [NSDate timeIntervalSinceReferenceDate];
}

/*
 *  This method will request that the definition determine if capacity is available for executing a new
 *  API.
 *  - NOTE: an 'even distribution' is only a coarse approximation to prevent any API from being exchausted
 *          prematurely.
 */
-(BOOL) hasCapacityAvailableAtPercentage:(float) pctOfLimit withEvenDistribution:(BOOL) evenlyDistributed
{
    // - concurrent accesses only deal with live objects in the app because they restrict how
    //   many can be active at once, but once the app dies, the connections necessarily terminate.
    NSUInteger adjustedLimit = (NSUInteger) ((float) throttleLimit * pctOfLimit);
    adjustedLimit            = MAX(adjustedLimit, 1);
    if ([self isConcurrentThrottled]) {
        if (numConcurrentAPIs < adjustedLimit) {
            return YES;
        }
    }
    else {
        // - non-concurrent accesses are based on time since last access.
        int32_t tCur = [self currentTimeAsInterval];
        tCur        -= (int32_t) throttleInterval;
        
        // - first cull the items that are older than the interval
        int32_t tLowest = 0;
        NSMutableIndexSet *mis = [NSMutableIndexSet indexSet];
        for (NSUInteger i = 0; i < [maRateLimitedAPIs count]; i++) {
            NSNumber *n = [maRateLimitedAPIs objectAtIndex:i];
            if (n.intValue < (int) tCur) {
                [mis addIndex:i];
                continue;
            }
            
            // - remember the list is sorted, so the first one inside the interval is a good reason to stop.
            tLowest = n.intValue;
            break;
        }
        
        if ([mis count]) {
            [maRateLimitedAPIs removeObjectsAtIndexes:mis];
        }
        
        // - now check that we're within acceptable limits
        //   ...but see if the adjusted limit should be changed based on an even distribution.
        if (evenlyDistributed && [maRateLimitedAPIs count]) {
            // ...I'm being _extra_ careful here because a problem throttling is a reason to get booted from Twitter.  This cannot ever
            //    get out of range or we're screwed.
            tCur = [self currentTimeAsInterval];
            double pct = MIN(((double) tCur - (double) tLowest)/(double) throttleInterval, 1.0);
            if (pct < 0.0) {
                NSLog(@"CS-ALERT: Unexpected even throttle percentange = %4.2f", pct);
                pct = 1.0;      //  just revert back to the standard non-even distribution.
            }
            adjustedLimit = (NSUInteger) ((double) adjustedLimit * pct);
        }

        // - check that we're under our limit.
        if ([maRateLimitedAPIs count] < adjustedLimit) {
            return YES;
        }
    }
    return NO;
}

/*
 *  Track a throttled API request.
 */
-(CS_netFeedAPI *) throttledAPIWithRateTracking:(BOOL) rateTracked usingCreator:(CS_netFeedCreatorDelegateHandle *) creatorHandle
{
    Class apiClass = NSClassFromString(className);
    if (!apiClass) {
        return nil;
    }
    
    //  NOTE:  The model for the lifetime of these APIs is that this factory definition intentionally never retains a handle
    //         to them in order to allow their normal deallocation codepath to fire when they are no longer used.  I
    //         was concerned that doing my accounting in anything but the dealloc method would introduce possibiliies
    //         for inconsitencies in odd corner locations.  That API object is allowed to even outlive this
    //         object, which is the reason for the creator handle that only holds a weak reference to me that I can
    //         clear out in my own dealloc codepath.
    BOOL isConcurrentLimited = [self isConcurrentThrottled];
    CS_netFeedAPI *api = [[apiClass alloc] initWithCreatorHandle:isConcurrentLimited ? creatorHandle : nil inCategory:throttleCategory];
    
    // - concurrent APIs are by-definition intended to prevent multiple accesses by the same
    //   application so they do not require persistence, but some tracking in-memory.
    if (isConcurrentLimited) {
        numConcurrentAPIs++;
    }
    else {
        // - we may not always want to track the rate if we're just doing a quick check of support for an existing API.
        if (rateTracked) {
            int32_t tCur = [self currentTimeAsInterval];
            [maRateLimitedAPIs addObject:[NSNumber numberWithInt:tCur]];
        }
    }
    return [api autorelease];
}

/*
 *  Merge the content from another throttle defintion object into this one.
 */
-(void) mergeInExternalContent:(_S_throttle_definition *) otherDef
{
    if (![self.className isEqualToString:otherDef.className]) {
        return;
    }
    
    // - merges are only necessary for non-concurrently-throttled APIs.
    if ([self isConcurrentThrottled]) {
        return;
    }
    
    // - add all the time intervals in the other into our list and keep them
    //   sorted.
    if (otherDef->maRateLimitedAPIs) {
        [maRateLimitedAPIs addObjectsFromArray:otherDef->maRateLimitedAPIs];
        [maRateLimitedAPIs sortUsingComparator:^NSComparisonResult(NSNumber *obj1, NSNumber *obj2){
            return [obj1 compare:obj2];
        }];
    }
}

/*
 *  An API we previously allocated is about to be discarded.
 */
-(void) accountForAPIDestruction
{
    // - this is only useful for throttled APIs because they are tracked only in memory.
    // - rate limited APIs don't care about the context, only that it occurred.
    if ([self isConcurrentThrottled]) {
        numConcurrentAPIs--;
    }
}

/*
 *  If this is a rate-limited API, ensure it cannot be used for a full cycle.
 */
-(void) artificiallyThrottleForOneCycle
{
    if ([self isConcurrentThrottled]) {
        return;
    }

    // - fill up the rate limit history so that we won't get any more requests.
    [maRateLimitedAPIs removeAllObjects];
    for (NSUInteger i = 0; i < MIN(throttleLimit, 9999); i++) {
        [maRateLimitedAPIs addObject:[NSNumber numberWithInt:[self currentTimeAsInterval]]];
    }
}

/*
 *  Reconfigure this definition to new limits.
 */
-(void) reconfigureThrottleToLimit:(NSUInteger) limit andRemaining:(NSUInteger) numRemaining
{
    if ([self isConcurrentThrottled]) {
        return;
    }
    
    // - do not increase the limit because extra capacity may change the behavior of the app and I don't
    //   want the online services to change that for me.
    if (limit < throttleLimit) {
        NSLog(@"CS-ALERT: Adjusting throttle limit of %@ from %u to %u.", self.className, (unsigned) throttleLimit, (unsigned) limit);
        throttleLimit = limit;
    }
    
    // - ensure that we match how many are remaining.
    if (limit != numRemaining) {
        NSUInteger expected = MIN(limit - numRemaining, 999);
        while ([maRateLimitedAPIs count] < expected) {
            [maRateLimitedAPIs addObject:[NSNumber numberWithInt:[self currentTimeAsInterval]]];
        }
    }
}
@end
