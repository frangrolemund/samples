//
//  CS_cacheSeal.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/21/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "CS_cacheSeal.h"
#import "ChatSeal.h"
#import "CS_diskCache.h"
#import "UINewSealCell.h"
#import "ChatSealVaultPlaceholder.h"
#import "UIImageGeneration.h"

// - constants
static NSString *CS_SEALCACHE_CATEGORY = @"seals";
static NSUInteger CS_MAX_LOCKED_IMAGES = 15;
static NSUInteger CS_MAX_VAULT_IMAGES  = 5;
static NSString *CS_CODE_SEALID        = @"sid";
static NSString *CS_CODE_SAFE_SEALID   = @"safeSid";
static NSString *CS_CODE_KNOWN         = @"known";
static NSString *CS_CODE_OWNED         = @"owned";
static NSString *CS_CODE_COLOR         = @"color";
static NSString *CS_CODE_REVOKED       = @"revoked";
static NSString *CS_SEALLIST_BASE      = @"seal-list";

// - local data
@class _CS_limited_image_cache;
static NSMutableDictionary *mdSealList          = nil;
static NSMutableDictionary *mdSealOps           = nil;
static _CS_limited_image_cache *licTableImages = nil;
static _CS_limited_image_cache *licVaultImages = nil;
static BOOL                isConsistent         = NO;
static UIImage             *imgSealMissing      = nil;

// - forward declarations
@interface CS_cacheSeal (internal) <NSCoding>
+(CS_cacheSeal *) emptySealForId:(NSString *) sealId;
-(void) setSafeImage:(UIImage *) img;
-(void) setSealId:(NSString *) sid;
-(void) setSafeSealId:(NSString *) ssid;
-(void) setIsKnown:(BOOL) flag;
-(void) setIsOwned:(BOOL) flag;
-(void) setColor:(RSISecureSeal_Color_t) c;
-(void) setRevokeReason:(phs_cacheSeal_revoke_reason_t) r;
+(BOOL) validateSealCacheWithError:(NSError **) err;
+(void) saveSealCache;
-(NSString *) safeImageName;
-(NSString *) tableImageName;
-(NSString *) vaultImageName;
+(UIImage *) lockedTableImageWithImage:(UIImage *) img andColor:(RSISecureSeal_Color_t) tableImageColor;
-(UIImage *) safeImageUsingSecureSeal:(RSISecureSeal *) ss;
-(UIImage *) tableImageUsingSecureSeal:(RSISecureSeal *) ss;
-(UIImage *) vaultImageUsingSecureSeal:(RSISecureSeal *) ss;
+(CS_cacheSeal *) retrieveAndCacheSealForId:(NSString *) sealId usingSecureObject:(RSISecureSeal *) secureSeal withError:(NSError **) err;
-(BOOL) updateRevocationStatusWithSeal:(RSISecureSeal *) ss andScreenshotTaken:(BOOL) isScreenshotted;
@end

// - for caching table and vault images.
@interface _CS_limited_image_cache : NSObject
-(id) initWithMaximum:(NSUInteger) maxCached;
-(UIImage *) imageForId:(NSString *) imageId;
-(void) cacheImage:(UIImage *) img forId:(NSString *) imageId;
-(void) discardImageForId:(NSString *) imageId;
-(void) clearCache;
@end

/*****************
 CS_cacheSeal
 - NOTE:  All accesses to this cache must be synchronized because
          it is accessed from operation queues as well.
 *****************/
@implementation CS_cacheSeal
/*
 *  Object attributes
 */
{
    NSString                      *sealId;
    NSString                      *safeSealId;
    UIImage                       *imgSafe;
    BOOL                          isKnown;
    BOOL                          isOwned;
    RSISecureSeal_Color_t         sealColor;
    phs_cacheSeal_revoke_reason_t revokeReason;
}

/*
 *  Initialize this module.
 */
+(void) initialize
{
    mdSealList      = [[NSMutableDictionary alloc] init];
    mdSealOps       = [[NSMutableDictionary alloc] init];
    licTableImages  = [[_CS_limited_image_cache alloc] initWithMaximum:CS_MAX_LOCKED_IMAGES];
    licVaultImages  = [[_CS_limited_image_cache alloc] initWithMaximum:CS_MAX_VAULT_IMAGES];
}

/*
 *  This method will store the provided seal in the cache if possible.
 */
+(void) precacheSealForId:(NSString *) sealId
{
    @synchronized (mdSealList) {
        [CS_cacheSeal validateSealCacheWithError:nil];
        
        // - the seal exists, so just return.
        if ([mdSealList objectForKey:sealId]) {
            return;
        }
        
        // - ok, we need to query the vault for it.
        if (![ChatSeal hasVault]) {
            return;
        }
        
        // - ready for the query, which will be in the background.
        @synchronized (mdSealOps) {
            NSBlockOperation *bo = [NSBlockOperation blockOperationWithBlock:^(void) {
                if ([CS_cacheSeal retrieveAndCacheSealForId:sealId usingSecureObject:nil withError:nil]) {
                    [CS_cacheSeal saveSealCache];
                }
                
                // - remove the operation from our list.
                [[NSOperationQueue mainQueue] addOperation:[NSBlockOperation blockOperationWithBlock:^(void) {
                    @synchronized (mdSealOps) {
                        [mdSealOps removeObjectForKey:sealId];
                    }
                }]];
            }];
            [mdSealOps setObject:bo forKey:sealId];
            [[ChatSeal vaultOperationQueue] addOperation:bo];
        }
    }
}

/*
 *  Free all the cached seal content.
 */
+(void) releaseAllCachedContent
{
    @synchronized (mdSealOps) {
        // - cancel any pending operations
        for (NSOperation *op in mdSealOps.allValues) {
            [op cancel];
        }
        [mdSealOps removeAllObjects];
    }
    
    // - release all the seals
    @synchronized (mdSealList) {
        [mdSealList removeAllObjects];
        
        [imgSealMissing release];
        imgSealMissing = nil;
    }
    
    @synchronized (licTableImages) {
        [licTableImages clearCache];
    }
    
    @synchronized (licVaultImages) {
        [licVaultImages clearCache];
    }
    
    // - whether or not this cache is consistent with the seal list.
    isConsistent = NO;
}

/*
 *  Force the cache to be rebuilt.
 */
+(void) forceCacheRecreation
{
    [ChatSeal incrementCurrentCacheEpoch];
    [CS_cacheSeal releaseAllCachedContent];
}

/*
 *  Return the cached item if it exists.
 */
+(CS_cacheSeal *) sealForId:(NSString *) sealId
{
    CS_cacheSeal *cs = nil;
    @synchronized (mdSealList) {
        [CS_cacheSeal validateSealCacheWithError:nil];
        cs = (CS_cacheSeal *) [mdSealList objectForKey:sealId];
        if (cs) {
            return [[cs retain] autorelease];
        }
    }
    return nil;
}

/*
 *  Return a cached item if it exists
 */
+(CS_cacheSeal *) sealForSafeId:(NSString *) safeId
{
    @synchronized (mdSealList) {
        [CS_cacheSeal validateSealCacheWithError:nil];
        for (CS_cacheSeal *cs in [mdSealList allValues]) {
            if ([safeId isEqualToString:cs.safeSealId]) {
                return [[cs retain] autorelease];
            }
        }
    }
    return nil;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        sealId       = nil;
        safeSealId   = nil;
        imgSafe      = nil;
        isKnown      = NO;
        isOwned      = NO;
        sealColor    = RSSC_INVALID;
        revokeReason = PHSCSP_RR_STILL_VALID;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [sealId release];
    sealId = nil;
    
    [safeSealId release];
    safeSealId = nil;
    
    [imgSafe release];
    imgSafe = nil;
    
    [super dealloc];
}

/*
 *  Retrieve the seal's id.
 */
-(NSString *) sealId
{
    @synchronized (self) {
        return [[sealId retain] autorelease];
    }
}

/*
 *  Retrieve the seal's safe id.
 */
-(NSString *) safeSealId
{
    @synchronized (self) {
        return [[safeSealId retain] autorelease];
    }
}

/*
 *  Because seal ids exist outside the vault and can be presented in different contexts, the question
 *  can arise whether or not they are available in this vault, which is what this flag conveys.  It 
 *  is used to identify a possible seal, but not one that we can fully qualify.
 */
-(BOOL) isKnown
{
    @synchronized (self) {
        return isKnown;
    }
}

/*
 *  Return the ownership for the seal.
 */
-(BOOL) isOwned
{
    @synchronized (self) {
        return isOwned;
    }
}

/*
 *  Return the seal's color.
 */
-(RSISecureSeal_Color_t) color
{
    @synchronized (self) {
        return sealColor;
    }
}

/*
 *  Return a safe seal image that can't be used to decode the 
 *  seal id.
 *  - this is usually not cached unless it is one of the owned seals because
 *    it could consume a lot of space for many of them.
 */
-(UIImage *) safeImage
{
    @synchronized (self) {
        UIImage *imgRet = [self safeImageUsingSecureSeal:nil];
        if (self.isOwned && !imgSafe) {
            imgSafe = [imgRet retain];
        }
        return imgRet;
    }
}

/*
 *  Return an image of the seal that can be used for simple display in the
 *  tables.
 */
-(UIImage *) tableImage
{
    @synchronized (self) {
        return [self tableImageUsingSecureSeal:nil];
    }
}

/*
 *  Return the seal image without a ring to be displayed in the vault.
 */
-(UIImage *) vaultImage
{
    @synchronized (self) {
        return [self vaultImageUsingSecureSeal:nil];
    }
}

/*
 *  Discard a seal for the given id from the cache along with 
 *  its image resources.
 */
+(void) discardSealForId:(NSString *) sealId
{
    // - look for a pending operation.
    NSOperation *op = nil;
    @synchronized (mdSealOps) {
        op = [[mdSealOps objectForKey:sealId] retain];
    }
    
    // - and cancel it if it exists/wait for it to finish
    //   completely.
    if (op) {
        [op cancel];
        [op waitUntilFinished];
        [op release];
    }

    // - now delete the seal data.
    NSString *sTableImage = nil;
    @synchronized (mdSealList) {
        // - now finish up by
        CS_cacheSeal *cs = [mdSealList objectForKey:sealId];
        @synchronized (cs) {
            NSString *sSafeImage = [cs safeImageName];
            [CS_diskCache invalidateSecureImageWithBaseName:sSafeImage andCategory:CS_SEALCACHE_CATEGORY];
            [cs setIsKnown:NO];
            sTableImage = [cs tableImageName];
        }
        [CS_diskCache invalidateSecureImageWithBaseName:sTableImage andCategory:CS_SEALCACHE_CATEGORY];
        [mdSealList removeObjectForKey:sealId];
        [self saveSealCache];
    }
    
    @synchronized (licTableImages) {
        [licTableImages discardImageForId:sealId];
    }
    
    @synchronized (licVaultImages) {
        [licVaultImages discardImageForId:sealId];
    }
}

/*
 *  Return an image for the locked seal.
 */
+(UIImage *) sealMissingTableImage
{
    @synchronized (mdSealList) {
        if (!imgSealMissing) {
            imgSealMissing = [[CS_cacheSeal lockedTableImageWithImage:nil andColor:RSSC_INVALID] retain];
        }
        return [[imgSealMissing retain] autorelease];
    }
}

/*
 *  Return a list of all the seals.
 */
+(NSArray *) availableSealsWithError:(NSError **) err
{
    @synchronized (mdSealList) {
        if (![CS_cacheSeal validateSealCacheWithError:err]) {
            return nil;
        }
        return [NSArray arrayWithArray:mdSealList.allValues];
    }
}

/*
 *  This method will retrieve and cache a seal synchronously.  If the secure object is not provided, it will
 *  be retrieved.
 */
+(CS_cacheSeal *) retrieveAndCacheSealForId:(NSString *) sealId usingSecureSecureObject:(RSISecureSeal *) secureSeal
{
    CS_cacheSeal *cs = [CS_cacheSeal retrieveAndCacheSealForId:sealId usingSecureObject:secureSeal withError:nil];
    if (cs) {
        [CS_cacheSeal saveSealCache];
    }
    return cs;
}

/*
 *  Ensure that the seal data is updated for a given seal, but retain the old cache object if possible.
 */
+(void) recacheSeal:(RSISecureSeal *) ss
{
    @synchronized (mdSealList) {
        if (ss) {
            CS_cacheSeal *cs = [CS_cacheSeal sealForId:ss.sealId];
            if (cs) {
                NSString *sName = nil;
                @synchronized (cs) {
                    cs.isKnown = YES;
                    cs.isOwned = ss.isOwned;
                    [cs updateRevocationStatusWithSeal:ss andScreenshotTaken:NO];
                    [CS_cacheSeal saveSealCache];
                    sName = [cs vaultImageName];
                }
                
                // - the vault image may have been recreated with a revoked seal image so
                //   we'll rebuild that one because its quality is most obvious.
                [CS_diskCache invalidateSecureImageWithBaseName:sName andCategory:CS_SEALCACHE_CATEGORY];
                
                @synchronized (licVaultImages) {
                    [licVaultImages discardImageForId:ss.sealId];
                }
                
                [cs vaultImageUsingSecureSeal:ss];
            }
            else {
                [CS_cacheSeal retrieveAndCacheSealForId:ss.sealId usingSecureSecureObject:ss];
            }
        }
    }
}

/*
 *  Equality test for the cached seal object.
 */
-(BOOL) isEqual:(id)object
{
    @synchronized (self) {
        if (sealId &&
            [object isKindOfClass:[CS_cacheSeal class]] &&
            [sealId isEqualToString:[(CS_cacheSeal *) object sealId]]) {
            return YES;
        }
        return NO;
    }
}

/*
 *  Validate this seal and update its internal state accordingly.
 */
-(void) validate
{
    // - make copies of the data because when we discard, the locks
    //   must be taken from the top down to avoid deadlocks.
    NSString *sid = nil;
    BOOL haveIt   = NO;
    @synchronized (self) {
        sid    = [[sealId retain] autorelease];
        haveIt = isKnown;
    }
    
    // - if this looks like a decent object, then check it in the vault.
    if (sid && haveIt) {
        if (![RealSecureImage sealExists:sid withError:nil]) {
            [CS_cacheSeal discardSealForId:sid];
        }
    }
}

/*
 *  Return the number of days of inactivity before a seal is revoked.
 *  - this is always a deep retrieval (not cached) because it is generally not
 *    made visible in lists of seals - only in the detail for any given seal.
 */
-(NSUInteger) sealExpirationTimoutInDaysWithError:(NSError **) err
{
    @synchronized (self) {
        if (sealId && isKnown && isOwned) {
            RSISecureSeal *ss = [RealSecureImage sealForId:sealId andError:nil];
            if (ss) {
                NSError *tmp      = nil;
                uint16_t timeout = [ss selfDestructTimeoutWithError:&tmp];
                if (timeout) {
                    return timeout;
                }
                else {
                    [CS_error fillError:err withCode:CSErrorSecurityFailure andFailureReason:[tmp localizedDescription]];
                }
            }
        }
        [CS_error fillError:err withCode:CSErrorInvalidSeal];
        return 0;
    }
}

/*
 *  Assign an expiration timeout on the seal.
 */
-(BOOL) setExpirationTimeoutInDays:(NSUInteger) days withError:(NSError **) err
{
    @synchronized (self) {
        if (sealId && isKnown && isOwned) {
            NSError *tmp      = nil;
            RSISecureSeal *ss = [RealSecureImage sealForId:sealId andError:&tmp];
            if (ss && [ss setSelfDestruct:(uint16_t) days withError:&tmp]) {
                return YES;
            }
            
            // - general failure to update.
            [CS_error fillError:err withCode:CSErrorSecurityFailure andFailureReason:[tmp localizedDescription]];
            return NO;
        }
        else {
            [CS_error fillError:err withCode:CSErrorInvalidSeal];
            return NO;
        }
    }
}

/*
 *  Returns whether the seal is revoked.
 */
-(phs_cacheSeal_revoke_reason_t) getRevoked
{
    @synchronized (self) {
        return revokeReason;
    }
}

/*
 *  Determines if the seal is still valid (ie. not revoked)
 */
-(BOOL) isValid;
{
    return ([self getRevoked] == PHSCSP_RR_STILL_VALID);
}

/*
 *  Perform a deep dive on the seal to determine if it should be revoked.
 */
-(phs_cacheSeal_revoke_reason_t) checkForRevocationWithScreenshotTaken
{
    @synchronized (self) {
        NSError *err      = nil;
        RSISecureSeal *ss = [RealSecureImage sealForId:self.sealId andError:&err];
        if (ss) {
            if ([self updateRevocationStatusWithSeal:ss andScreenshotTaken:YES]) {
                [CS_cacheSeal saveSealCache];
            }
        }
        else {
            NSLog(@"CS:  Failed to determine revocation status for seal %@.  %@", [self safeSealId], [err localizedDescription]);
        }
        return (revokeReason != PHSCSP_RR_STILL_VALID) ? YES : NO;
    }
}

/*
 *  Check if the seal should be expired.
 */
-(phs_cacheSeal_revoke_reason_t) checkForExpiration
{
    @synchronized (self) {
        NSError *err      = nil;
        RSISecureSeal *ss = [RealSecureImage sealForId:self.sealId andError:&err];
        if (ss) {
            if ([self updateRevocationStatusWithSeal:ss andScreenshotTaken:NO]) {
                [CS_cacheSeal saveSealCache];
            }
        }
        else {
            NSLog(@"CS:  Failed to determine expiration status for seal %@.  %@", [self safeSealId], [err localizedDescription]);
        }
        return (revokeReason != PHSCSP_RR_STILL_VALID) ? YES : NO;
    }
}

/*
 *  Assign an expiration to the included seal.
 *  - This is only intended to be used for testing!
 */
-(BOOL) setExpirationDate:(NSDate *) dtExpires withError:(NSError **) err
{
    @synchronized (self) {
        RSISecureSeal *ss = [RealSecureImage sealForId:self.sealId andError:err];
        if (ss) {
            return [ss setExpirationDate:dtExpires withError:err];
        }
        else {
            return NO;
        }
    }
}

/*
 *  Determine if the screenshot revocation flag is set on the seal.
 *  - this is always a deep retrieval (not cached) because it is generally not
 *    made visible in lists of seals - only in the detail for any given seal.
 */
-(BOOL) isRevocationOnScreenshotEnabledWithError:(NSError **) err
{
    @synchronized (self) {
        if (sealId && isKnown && isOwned) {
            RSISecureSeal *ss = [RealSecureImage sealForId:sealId andError:nil];
            if (ss) {
                NSError *tmp = nil;
                BOOL enabled = [ss isInvalidateOnSnapshotEnabledWithError:&tmp];
                if (!enabled) {
                    if (tmp) {
                        [CS_error fillError:err withCode:CSErrorSecurityFailure andFailureReason:tmp ? [tmp localizedDescription] : nil];
                    }
                    else if (err) {
                        *err = nil;
                    }
                }
                return enabled;
            }
        }
        [CS_error fillError:err withCode:CSErrorInvalidSeal];
        return NO;
    }
}

/*
 *  Set the screenshot revocation flag on the seal.
 */
-(BOOL) setRevokeOnScreenshotEnabled:(BOOL) enabled withError:(NSError **) err
{
    @synchronized (self) {
        if (sealId && isKnown && isOwned) {
            NSError *tmp      = nil;
            RSISecureSeal *ss = [RealSecureImage sealForId:sealId andError:&tmp];
            if (ss && [ss setInvalidateOnSnapshot:enabled withError:&tmp]) {
                return YES;
            }
            
            // - general failure to update.
            [CS_error fillError:err withCode:CSErrorSecurityFailure andFailureReason:[tmp localizedDescription]];
            return NO;
        }
        else {
            [CS_error fillError:err withCode:CSErrorInvalidSeal];
            return NO;
        }
    }
}

@end

/*************************
 CS_cacheSeal (internal)
 *************************/
@implementation CS_cacheSeal (internal)
/*
 *  Return an unpopulated seal object for the given id.
 */
+(CS_cacheSeal *) emptySealForId:(NSString *) sealId
{
    CS_cacheSeal *cs = [[[CS_cacheSeal alloc] init] autorelease];
    cs.sealId         = sealId;
    return cs;
}

/*
 *  Initialize the object with the decoder contents.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        @try {
            sealId       = [[aDecoder decodeObjectForKey:CS_CODE_SEALID] retain];
            imgSafe      = nil;
            safeSealId   = [[aDecoder decodeObjectForKey:CS_CODE_SAFE_SEALID] retain];
            isKnown      = [aDecoder decodeBoolForKey:CS_CODE_KNOWN];
            isOwned      = [aDecoder decodeBoolForKey:CS_CODE_OWNED];
            sealColor    = (RSISecureSeal_Color_t) [aDecoder decodeIntegerForKey:CS_CODE_COLOR];
            revokeReason = (phs_cacheSeal_revoke_reason_t) [aDecoder decodeIntegerForKey:CS_CODE_REVOKED];
        }
        @catch (NSException *exception) {
            // - disallow exceptions
            NSLog(@"CS:  Unexpected seal exception during decoding.  %@", [exception description]);
        }
    }
    return self;
}

/*
 *  Encode the object.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:sealId forKey:CS_CODE_SEALID];
    [aCoder encodeObject:safeSealId forKey:CS_CODE_SAFE_SEALID];
    [aCoder encodeBool:isKnown forKey:CS_CODE_KNOWN];
    [aCoder encodeBool:isOwned forKey:CS_CODE_OWNED];
    [aCoder encodeInteger:sealColor forKey:CS_CODE_COLOR];
    [aCoder encodeInteger:revokeReason forKey:CS_CODE_REVOKED];
}

/*
 *  Assign the seal id to this object.
 */
-(void) setSealId:(NSString *)sid
{
    if (sid != sealId) {
        [sealId release];
        sealId = [sid retain];
    }
}

/*
 *  Assign the safe seal id to this object.
 */
-(void) setSafeSealId:(NSString *) ssid
{
    if (ssid != safeSealId) {
        [safeSealId release];
        safeSealId = [ssid retain];
    }
}

/*
 *  Assign the safe image to this object.
 */
-(void) setSafeImage:(UIImage *)img
{
    if (img != imgSafe) {
        [imgSafe release];
        imgSafe = [img retain];
    }
}
                   
/*
 *  Change the known state of the seal.
 */
-(void) setIsKnown:(BOOL) flag
{
    isKnown = flag;
    if (!flag) {
        [imgSafe release];
        imgSafe   = nil;
        sealColor = RSSC_INVALID;
    }
}
                        
/*
 *  Change the owned state of the seal.
 */
-(void) setIsOwned:(BOOL) flag
{
    isOwned = flag;
}

/*
 *  Set the value of the seal color.
 */
-(void) setColor:(RSISecureSeal_Color_t) c
{
    sealColor = c;
}

/*
 *  Set the reason for seal revocation.
 */
-(void) setRevokeReason:(phs_cacheSeal_revoke_reason_t) r
{
    revokeReason = r;
}

/*
 *  Ensure the seal cache is loaded if it exists on disk.
 */
+(BOOL) validateSealCacheWithError:(NSError **) err
{
    if (isConsistent) {
        return YES;
    }
    
    @synchronized (mdSealList) {
        [mdSealList removeAllObjects];
        NSObject *obj = [CS_diskCache secureCachedDataWithBaseName:CS_SEALLIST_BASE andCategory:CS_SEALCACHE_CATEGORY];
        if (obj && [obj isKindOfClass:[NSArray class]]) {
            NSArray *arrCached = (NSArray *) obj;
            if ([arrCached count] == 2 && [[arrCached objectAtIndex:0] isKindOfClass:[NSNumber class]] &&
                [[arrCached objectAtIndex:1] isKindOfClass:[NSDictionary class]]) {
                NSNumber *nEpoch = [arrCached objectAtIndex:0];
                if (nEpoch.integerValue == [ChatSeal cacheEpoch]) {
                    [mdSealList addEntriesFromDictionary:(NSDictionary *) [arrCached objectAtIndex:1]];
                    isConsistent = YES;
                    return YES;
                }
            }
        }
        
        // - when the cached content is the wrong format, we need to invalidate it all and recreate it.
        [CS_diskCache invalidateCacheCategory:CS_SEALCACHE_CATEGORY];
        
        // - the cached content doesn't exist or isn't good, so recreate it.
        NSError *tmp = nil;
        if (![RealSecureImage hasVault]) {
            [CS_error fillError:err withCode:CSErrorVaultNotInitialized];
            return NO;
        }
        NSArray *arr = [RealSecureImage availableSealsWithError:&tmp];
        if (!arr) {
            NSLog(@"CS: Failed to retrieve the available seal list.  %@", [tmp localizedDescription]);
            if (err) {
                *err = tmp;
            }
            return NO;
        }
        for (NSString *sid in arr) {
            if (![CS_cacheSeal retrieveAndCacheSealForId:sid usingSecureObject:nil withError:&tmp]) {
                [mdSealList removeAllObjects];
                if (err) {
                    *err = tmp;
                }
                return NO;
            }
        }
        // - make sure we mark this as consistent so that we don't re-enter when we save.
        isConsistent = YES;
        
        // - save this for next time.
        [self saveSealCache];
    }
    return YES;
}

/*
 *  Save the local seal cache to disk.
 */
+(void) saveSealCache
{
    @synchronized (mdSealList) {
        [CS_diskCache saveSecureCachedData:[NSArray arrayWithObjects:[NSNumber numberWithInteger:[ChatSeal cacheEpoch]], mdSealList, nil]
                               withBaseName:CS_SEALLIST_BASE andCategory:CS_SEALCACHE_CATEGORY];
    }
    
    //  - this is a great place to update the placeholder database because we know the cache is always kept consistent.
    [ChatSealVaultPlaceholder saveVaultSealPlaceholderData];
}

/*
 *  Return the name of the safe image.
 */
-(NSString *) safeImageName
{
    if (safeSealId) {
        return [NSString stringWithFormat:@"%@-si", safeSealId];
    }
    return nil;
}

/*
 *  Return the name of the image used for tables.
 */
-(NSString *) tableImageName
{
    if (safeSealId) {
        return [NSString stringWithFormat:@"%@-ti", safeSealId];
    }
    return nil;
}

/*
 *  Return the name of the image used for vault images.
 */
-(NSString *) vaultImageName
{
    if (safeSealId) {
        return [NSString stringWithFormat:@"%@-vi", safeSealId];
    }
    return nil;
}

/*
 *  Generate an image for the seal when it is displayed in a table.
 */
+(UIImage *) lockedTableImageWithImage:(UIImage *) img andColor:(RSISecureSeal_Color_t) tableImageColor
{
    CGFloat standardSide = [ChatSeal standardSealSideForListDisplay];
    CGRect rcSeal        = CGRectMake(0.0f, 0.0f, standardSide, standardSide);
    UINewSealCell *nsc   = [ChatSeal sealCellForHeight:standardSide];
    [nsc setSealColor:tableImageColor];
    [nsc setCenterRingVisible:YES];
    [nsc setSealImage:img];
    [nsc setLocked:YES];

    // - we're going to allow the shadow to be clipped because otherwise the image won't line
    //   up with how the seal view will be drawn later.  
    CGFloat scale   = [UIScreen mainScreen].scale;
    CGSize  szImage = CGSizeMake(rcSeal.size.width, rcSeal.size.height);
    UIGraphicsBeginImageContextWithOptions(szImage, NO, scale);
    [nsc drawCellForDecoyInRect:rcSeal];
    UIImage *imgRet = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return imgRet;
}

/*
 *  Return a safe image optionally using the provided secure seal.
 */
-(UIImage *) safeImageUsingSecureSeal:(RSISecureSeal *) ss
{
    // - first try to return it if it is in memory.
    if (imgSafe) {
        return [[imgSafe retain] autorelease];
    }
    
    // - then look on disk in the persistent cache
    NSString *sName = [self safeImageName];
    if (sName) {
        UIImage *img = [CS_diskCache cachedSecureImageWithBaseName:sName andCategory:CS_SEALCACHE_CATEGORY];
        if (img) {
            return img;
        }
        
        // - last chance is to load it from the vault, which of course takes much longer.
        if (!ss) {
            ss = [ChatSeal sealForId:sealId withError:nil];
            if (!ss) {
                return nil;
            }
        }
        img = [ss safeSealImageWithError:nil];
        if (img) {
            [CS_diskCache saveSecureImage:img withBaseName:sName andCategory:CS_SEALCACHE_CATEGORY];
            return img;
        }
    }
    return nil;
}

/*
 *  Return a table image to use for displaying the seal.
 */
-(UIImage *) tableImageUsingSecureSeal:(RSISecureSeal *) ss
{
    if (!sealId || !isKnown) {
        return [CS_cacheSeal sealMissingTableImage];
    }
    
    @synchronized (licTableImages) {
        // - first look in memory in our limited cache
        UIImage *img = [licTableImages imageForId:sealId];
        if (img) {
            return [[img retain] autorelease];
        }
        
        // - then on disk.
        NSString *sName = [self tableImageName];
        img = [CS_diskCache cachedSecureImageWithBaseName:sName andCategory:CS_SEALCACHE_CATEGORY];
        if (!img) {
            // ...finally, fall back to the vault.
            img = [self safeImageUsingSecureSeal:ss];
            img = [CS_cacheSeal lockedTableImageWithImage:img andColor:sealColor];
            if (img) {
                [CS_diskCache saveSecureImage:img withBaseName:sName andCategory:CS_SEALCACHE_CATEGORY];
            }
        }
        
        // - update the in-memory cache if we found something.
        if (img) {
            [licTableImages cacheImage:img forId:sealId];
        }
        return img;
    }
}

/*
 *  Return an undecorated image from the seal to be used for vault display.
 */
-(UIImage *) vaultImageUsingSecureSeal:(RSISecureSeal *) ss
{
    if (!sealId || !isKnown) {
        return nil;
    }
    
    @synchronized (licVaultImages) {
        // - first look in memory in our limited cache
        UIImage *img = [licVaultImages imageForId:sealId];
        if (img) {
            return [[img retain] autorelease];
        }
        
        // - then on disk.
        NSString *sName = [self vaultImageName];
        img = [CS_diskCache cachedSecureImageWithBaseName:sName andCategory:CS_SEALCACHE_CATEGORY];
        if (!img) {
            // ...finally, fall back to the vault and scale it.
            img = [self safeImageUsingSecureSeal:ss];
            if (img.size.width) {
                CGFloat target  = [ChatSeal standardSealImageSideForVaultDisplay];
                CGFloat svScale = [UIScreen mainScreen].scale;
                CGFloat iScale  = (target * svScale) / (img.size.width * img.scale);
                img = [UIImageGeneration image:img scaledTo:iScale asOpaque:YES];
                if (img) {
                    [CS_diskCache saveSecureImage:img withBaseName:sName andCategory:CS_SEALCACHE_CATEGORY];
                }
            }
        }
        
        // - update the in-memory cache if we found something.
        if (img) {
            [licVaultImages cacheImage:img forId:sealId];
        }
        return img;
    }
}

/*
 *  This method will retrieve and cache a seal synchronously.  If the secure object is not provided, it will
 *  be retrieved.
 */
+(CS_cacheSeal *) retrieveAndCacheSealForId:(NSString *) sealId usingSecureObject:(RSISecureSeal *) secureSeal withError:(NSError **) err
{
    CS_cacheSeal *csRet = nil;
    NSError       *tmp   = nil;
    
    // - figure out if the seal already is cached
    @synchronized (mdSealList) {
        csRet = [mdSealList objectForKey:sealId];
        if (csRet) {
            return [[csRet retain] autorelease];
        }
    }
    
    // - if the seal wasn't provided, look for it now.
    if (!secureSeal) {
        if ([ChatSeal sealExists:sealId withError:&tmp]) {
            secureSeal = [ChatSeal sealForId:sealId withError:&tmp];
            if (!secureSeal) {
                NSLog(@"CS: Failed to retrieve seal id %@.  %@", sealId, [tmp localizedDescription]);
                if (err) {
                    *err = tmp;
                }
                return nil;
            }
        }
        else {
            NSLog(@"CS: Failed to locate seal id %@.  %@", sealId, [tmp localizedDescription]);
            if (err) {
                *err = tmp;
            }
            return nil;
        }
    }
    
    // - now pull the data from the object and store it
    RSISecureSeal_Color_t color;
    NSString              *safeId  = nil;
    if ((color = [secureSeal colorWithError:&tmp]) != RSSC_INVALID &&
        (safeId = [secureSeal safeSealIdWithError:&tmp]) != nil) {
        
        // - store the retrieved data.
        csRet              = [CS_cacheSeal emptySealForId:sealId];
        csRet.color        = color;
        csRet.isOwned      = [secureSeal isOwned];
        csRet.safeSealId   = safeId;
        csRet.isKnown      = YES;
        [csRet updateRevocationStatusWithSeal:secureSeal andScreenshotTaken:NO];
        csRet.safeImage    = [csRet safeImageUsingSecureSeal:secureSeal];
        [csRet tableImageUsingSecureSeal:secureSeal];           // force it to be cached.
        [csRet vaultImageUsingSecureSeal:secureSeal];
        csRet.safeImage    = nil;                               // don't leave this lying around because it is big.
        @synchronized (mdSealList) {
            // - save the object in the list for later.
            [mdSealList setObject:csRet forKey:sealId];
            
            // - return the new item.
            return [[csRet retain] autorelease];
        }
    }
    else {
        NSLog(@"CS: Failed to retrieve required seal data.  %@", [tmp localizedDescription]);
        if (err) {
            *err = tmp;
        }
        return nil;
    }
}

/*
 *  Determine the current revocation status on the seal.
 */
-(BOOL) updateRevocationStatusWithSeal:(RSISecureSeal *) ss andScreenshotTaken:(BOOL) isScreenshotted
{
    BOOL saveDatabase = NO;
    if (ss) {
        if ([ss isInvalidatedWithError:nil]) {
            // - already invalidated, but the cache is out of synch.
            if (revokeReason == PHSCSP_RR_STILL_VALID) {
                revokeReason = PHSCSP_RR_REVOKED;
                saveDatabase = YES;
            }
        }
        else {
            // - the cache is out of synch, this is valid
            if (revokeReason != PHSCSP_RR_STILL_VALID) {
                revokeReason = PHSCSP_RR_STILL_VALID;
                saveDatabase = YES;
            }

            // - check for invalidation due to screenshotting.
            if (isScreenshotted) {
                if ([ss invalidateForSnapshotWithError:nil]) {
                    revokeReason = PHSCSP_RR_REVOKED;
                    saveDatabase = YES;
                    [ChatSeal updateAlertBadges];
                }
            }
            
            // - and now check for expiration.
            if (revokeReason == PHSCSP_RR_STILL_VALID) {
                if ([ss invalidateExpiredWithError:nil]) {
                    revokeReason = PHSCSP_RR_EXPIRED;
                    saveDatabase = YES;
                    [ChatSeal updateAlertBadges];                    
                }
            }
        }
    }
    return saveDatabase;
}

@end

/**************************
 _CS_limited_image_cache
 **************************/
@implementation _CS_limited_image_cache
/*
 *  Object attributes.
 */
{
    NSMutableArray      *maIdList;
    NSMutableDictionary *mdCachedImages;
    NSUInteger          imageLimit;
}

/*
 *  Initialize the object.
 */
-(id) initWithMaximum:(NSUInteger) maxCached
{
    self = [super init];
    if (self) {
        imageLimit     = maxCached;
        maIdList       = [[NSMutableArray alloc] init];
        mdCachedImages = [[NSMutableDictionary alloc] init];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [maIdList release];
    maIdList = nil;
    
    [mdCachedImages release];
    mdCachedImages = nil;
    [super dealloc];
}

/*
 *  Check the cache for a given image.
 */
-(UIImage *) imageForId:(NSString *) imageId
{
    return (UIImage *) [mdCachedImages objectForKey:imageId];
}

/*
 *  Cache a new image and manage the overall size.
 */
-(void) cacheImage:(UIImage *) img forId:(NSString *) imageId
{
    if (!img || !imageId) {
        return;
    }
    
    [maIdList addObject:imageId];
    [mdCachedImages setObject:img forKey:imageId];
    
    if ([maIdList count] &&
        [maIdList count] > imageLimit) {
        NSString *tmp = [maIdList objectAtIndex:0];
        [mdCachedImages removeObjectForKey:tmp];
        [maIdList removeObjectAtIndex:0];
    }
}

/*
 *  Discard a single cached item.
 */
-(void) discardImageForId:(NSString *) imageId
{
    [mdCachedImages removeObjectForKey:imageId];
    [maIdList removeObject:imageId];
}

/*
 *  Remove the contents of the cache.
 */
-(void) clearCache
{
    [maIdList removeAllObjects];
    [mdCachedImages removeAllObjects];
}
@end
