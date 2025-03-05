//
//  ChatSealIdentity.m
//  ChatSeal
//
//  Created by Francis Grolemund on 12/26/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "ChatSealIdentity.h"
#import "CS_cacheSeal.h"
#import "ChatSeal.h"
#import "ChatSealMessage.h"
#import "CS_diskCache.h"
#import "ChatSealVaultPlaceholder.h"
#import "ChatSealFeedLocation.h"

// - constants
static NSString *PSI_IDENT_DB_FILE                  = @"idents";
static NSString *PSI_IDENT_KEY_CREATE               = @"created";
static NSString *PSI_IDENT_KEY_OWNER                = @"owner";
static NSString *PSI_IDENT_KEY_OWNERDT              = @"ownerDate";
static NSString *PSI_IDENT_KEY_SENT                 = @"sent";
static NSString *PSI_IDENT_KEY_RECV                 = @"recv";
static NSString *PSI_IDENT_KEY_GIVEN                = @"givn";
static NSString *PSI_IDENT_KEY_SCSHOTS              = @"sshots";
static NSString *PSI_IDENT_KEY_EXPIREDATE           = @"expiresDate";
static NSString *PSI_IDENT_KEY_EXPDAYS              = @"expires";
static NSString *PSI_IDENT_KEY_LASTSENDDATE         = @"sendDate";
static NSString *PSI_IDENT_KEY_FEED                 = @"feed";
static NSString *PSI_IDENT_KEY_FEED_HISTORY         = @"postedFeedHist";
static NSString *PSI_IDENT_KEY_FRIEND_FEEDS         = @"friendFeeds";
static const NSUInteger PSI_IDENT_EXPIRE_WARN_DAYS  = 3;
static const NSUInteger PSI_IDENT_MAX_POSTED_HIST   = 5;                   // keep only the N most recent ones.

// - local variables
static NSMutableDictionary *mdIdentities                = nil;
static BOOL                isValidated                  = NO;
static NSMutableDictionary *mdFriendsPerFeedTypeVersion = nil;

// - forward declarations
@interface ChatSealIdentity (internal)
+(NSDictionary *) secureIdentityDictionaryWithError:(NSError **) err;
+(BOOL) saveSecureIdentityDictionary:(NSDictionary *) secObj withError:(NSError **) err;
+(BOOL) validateIdentityDatabaseWithError:(NSError **) err;
+(BOOL) saveIdentityDatabase;
-(BOOL) loadStateForCachedSeal:(CS_cacheSeal *) cs withError:(NSError **) err;
+(BOOL) createIdentityDatabaseForSeal:(NSString *) sealId withError:(NSError **) err;
-(NSString *) computedExpirationTextAndDisplayAsWarning:(BOOL *) isWarning;
+(void) updateFeedTypeVersionsForTypesInSet:(NSSet *) sTypes;
@end

// - shared declarations
@interface ChatSealIdentity (shared)
+(NSString *) createIdentityWithImage:(UIImage *) imgSeal andColor:(RSISecureSeal_Color_t) color andError:(NSError **) err;
+(NSString *) importIdentityWithData:(NSData *) dExported usingPassword:(NSString *) pwd andError:(NSError **) err;
+(BOOL) permanentlyDestroyIdentity:(NSString *) sealId withError:(NSError **) err;
+(id) identityForSealId:(NSString *) sid withError:(NSError **) err;
+(id) identityForCacheSeal:(CS_cacheSeal *) cs withError:(NSError **) err;
@end

// - the internal objects.
// - NOTE: these attributes must be ATOMICally updated to keep this safe between ChatSealIdentity instances.
@interface _CS_identity : NSObject <NSCoding>
{
    NSDate *dtCreated;
}
-(NSDate *) dateCreated;
-(void) updateExpirationDate;
@property (atomic, retain)      NSString       *ownerName;
@property (atomic, retain)      NSDate         *dtOwnerUpdated;
@property (atomic, assign)      NSUInteger     sentCount;
@property (atomic, assign)      NSUInteger     recvCount;
@property (atomic, assign)      NSUInteger     givenCount;
@property (atomic, assign)      NSUInteger     screenshotsTaken;
@property (atomic, assign)      NSUInteger     expireDays;
@property (atomic, retain)      NSDate         *dtOfExpiration;
@property (atomic, retain)      NSDate         *dtMsgSent;
@property (atomic, retain)      NSString       *defaultFeed;
@property (atomic, readonly)    NSMutableArray *postedFeeds;
@property (atomic, readonly)    NSMutableSet   *friendFeeds;
@end

@interface ChatSealIdentityFriend (internal)
-(id) initWithLocation:(ChatSealFeedLocation *) location andOwnedIdentity:(BOOL) isOwnedIdentity;
@end

/************************
 ChatSealIdentity
 ************************/
@implementation ChatSealIdentity
/*
 *  Object attributes.
 */
{
    NSString      *sealId;
    CS_cacheSeal *cachedSeal;
    _CS_identity *identAttribs;
}

/*
 *  Initialize this module.
 */
+(void) initialize
{
    mdIdentities                = [[NSMutableDictionary alloc] init];
    mdFriendsPerFeedTypeVersion = [[NSMutableDictionary alloc] init];
}

/*
 *  This is a faster-performing owner name conversion for the given seal id without
 *  requiring an explicit object construction because these names are potentially used
 *  more often.
 */
+(NSString *) ownerNameForSeal:(NSString *) sealId
{
    @synchronized (mdIdentities) {
        NSError *err = nil;
        if ([ChatSealIdentity validateIdentityDatabaseWithError:&err]) {
            _CS_identity *ident = [mdIdentities objectForKey:sealId];
            if (ident) {
                return ident.ownerName;
            }
        }
        else {
            NSLog(@"CS:  Failed to validate the identity database.  %@", [err localizedDescription]);
        }
    }
    return nil;
}

/*
 *  Standardized sorting for identities when we show seals in a list.
 */
+(void) sortIdentityArrayForDisplay:(NSMutableArray *) maIdents
{
    [maIdents sortWithOptions:0 usingComparator:^NSComparisonResult(ChatSealIdentity *idObj1, ChatSealIdentity *idObj2) {
        // - sort first by ownership
        if (idObj1.sealId &&
            idObj2.sealId &&
            idObj1.isOwned != idObj2.isOwned) {
            if (idObj1.isOwned) {
                return NSOrderedAscending;
            }
            else {
                return NSOrderedDescending;
            }
        }
        
        // - sort by date next
        NSDate *dtCr1      = [idObj1 dateCreated];
        NSTimeInterval ti1 = [dtCr1 timeIntervalSinceReferenceDate];
        NSDate *dtCr2      = [idObj2 dateCreated];
        NSTimeInterval ti2 = [dtCr2 timeIntervalSinceReferenceDate];
        
        // - I think it makes the most sense to put the recent seals at the top, particularly in my list because it make the new
        //   active one prominent when the view is first displayed.
        if (ti1 < ti2) {
            return NSOrderedDescending;
        }
        else if (ti1 > ti2) {
            return NSOrderedAscending;
        }
        return NSOrderedSame;
    }];
}

/*
 *  Return the list of friends that are compatible with the given feed type.
 */
+(NSArray *) friendsForFeedsOfType:(NSString *) feedType
{
    @synchronized (mdIdentities) {
        // - make sure the identities are available.
        if (!isValidated) {
            if (![ChatSealIdentity validateIdentityDatabaseWithError:nil]) {
                return nil;
            }
        }

        NSMutableDictionary *mdRet = [NSMutableDictionary dictionary];
        for (NSString *sealId in mdIdentities.allKeys) {
            _CS_identity *ident = [mdIdentities objectForKey:sealId];
            for (ChatSealFeedLocation *oneLoc in ident.friendFeeds) {
                if (![feedType isEqualToString:oneLoc.feedType]) {
                    continue;
                }
                
                CS_cacheSeal *cs = [CS_cacheSeal sealForId:sealId];
                if (!cs) {
                    continue;
                }
                
                NSString *locationKey            = [oneLoc.feedType stringByAppendingString:oneLoc.feedAccount];
                ChatSealIdentityFriend *myFriend = [mdRet objectForKey:locationKey];
                
                // - consumers have higher requirements for maintaining the friendship and are
                //   therefore given priority in the friendship array.
                // - I think this concept is actually very consistent with how I view the seal owner (producer) in the
                //   relationship.  My assumption is that they are producing content and their readers should bear the
                //   responsibility for ensuring the path to the consumer is clear.
                BOOL isOwned = cs.isOwned;
                if (!myFriend || (!isOwned && myFriend.isSealOwnerInRelationship)) {
                    [mdRet setObject:[[[ChatSealIdentityFriend alloc] initWithLocation:oneLoc andOwnedIdentity:isOwned] autorelease] forKey:locationKey];
                }
            }
        }
        
        return [mdRet allValues];
    }
}

/*
 *  We're going to store a version number per feed type friend update so that it is easy to quickly determine
 *  if temporary state is out of date.
 */
+(NSUInteger) friendsListVersionForFeedsOfType:(NSString *) feedType
{
    @synchronized (mdFriendsPerFeedTypeVersion) {
        if (feedType) {
            NSNumber *n = nil;
            if ((n = [mdFriendsPerFeedTypeVersion objectForKey:feedType])) {
                return [n unsignedIntegerValue];
            }
        }
        return 0;
    }
}


/*
 *  Delete the friends that match the given locations.
 *  - Returns YES if we deleted any friends.
 */
+(BOOL) deleteAllFriendsForFeedsInLocations:(NSArray *) arrLocations
{
    NSMutableSet *msModifedTypes = nil;
    @synchronized (mdIdentities) {
        // - make sure the identities are available.
        if (!isValidated) {
            if (![ChatSealIdentity validateIdentityDatabaseWithError:nil]) {
                return NO;
            }
        }
        
        // - for each location we received, check each identity to see if
        //   it exists.
        for (ChatSealFeedLocation *loc in arrLocations) {
            for (NSString *sealId in mdIdentities.allKeys) {
                _CS_identity *ident = [mdIdentities objectForKey:sealId];
                
                // - if we find an identity with that friend, we need to discard it here
                //   and then let the collector know later that the friend is now stale.
                if ([ident.friendFeeds containsObject:loc]) {
                    if (!msModifedTypes) {
                        msModifedTypes = [NSMutableSet set];
                    }
                    [msModifedTypes addObject:loc.feedType];
                    [ident.friendFeeds removeObject:loc];
                }
            }
        }
    }
    
    // - when we delete friends, this is a fairly significant change and requires that
    //   all the types rethink their caches.
    if (msModifedTypes) {
        [ChatSealIdentity updateFeedTypeVersionsForTypesInSet:msModifedTypes];
        [ChatSealIdentity saveIdentityDatabase];
        return YES;
    }
    return NO;
}

/*
 *  A very quick test to see if seals exist in the database.
 */
+(BOOL) hasSeals
{
    @synchronized (mdIdentities) {
        return [mdIdentities count] ? YES : NO;
    }
}

/*
 *  Initialize the object.
 */
-(id) initWithSeal:(NSString *) sid
{
    self = [super init];
    if (self) {
        sealId     = [sid retain];
        cachedSeal = nil;
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
    
    [cachedSeal release];
    cachedSeal = nil;
    
    [identAttribs release];
    identAttribs = nil;
    
    [super dealloc];
}

/*
 *  Return the seal id for this identity.
 */
-(NSString *) sealId
{
    @synchronized (self) {
        return [[sealId retain] autorelease];
    }
}

/*
 *  Return the externally-visible seal id.
 */
-(NSString *) safeSealId
{
    @synchronized (self) {
        return [cachedSeal safeSealId];
    }
}

/*
 *  Return the indication whether this identity is fully known.
 */
-(BOOL) isKnown
{
    @synchronized (self) {
        return [cachedSeal isKnown];
    }
}

/*
 *  Return whether this identity is owned.
 */
-(BOOL) isOwned
{
    @synchronized (self) {
        return [cachedSeal isOwned];
    }
}

/*
 *  Return the seal color.
 */
-(RSISecureSeal_Color_t) color
{
    @synchronized (self) {
        if (cachedSeal) {
            return [cachedSeal color];
        }
        else {
            return RSSC_INVALID;
        }
    }
}

/*
 *  Return the safe seal image, that can't be used to reverse engineer its
 *  scrambler key.
 */
-(UIImage *) safeImage
{
    @synchronized (self) {
        return [cachedSeal safeImage];
    }
}

/*
 *  Return the table image for the seal.
 */
-(UIImage *) tableImage
{
    @synchronized (self) {
        return [cachedSeal tableImage];
    }
}

/*
 *  Return the undecorated image used to display vault seals.
 */
-(UIImage *) vaultImage
{
    @synchronized (self) {
        return [cachedSeal vaultImage];
    }
}

/*
 *  Return status for the identity.
 */
-(NSString *) computedStatusTextAndDisplayAsWarning:(BOOL *) isWarning
{
    @synchronized (self) {
        // - figure out what the text should indicate
        NSString *ret    = nil;
        BOOL     retWarn = NO;
        if ([self isOwned]) {
            if ([self sealGivenCount] == 0) {
                ret     = NSLocalizedString(@"Seal is not shared.", nil);
                retWarn = NO;
            }
            else {
                ret = [self computedExpirationTextAndDisplayAsWarning:&retWarn];
            }
        }
        else {
            if ([self isExpired] || [self isRevoked]) {
                ret     = NSLocalizedString(@"Your friend must re-share.", nil);
                retWarn = NO;
            }
        }
        
        //  NOTE:  when you return text that results in a warning, it is important to go
        //  find the block of code that addresses that concern and execute [ChatSeal updateAlertBadges]
        //  after that occurs to ensure that the vault seals are updated with new content or
        //  the person won't be able to easily clear the alert.
        
        
        //  - pass back the warning flag if provided.
        if (isWarning) {
            *isWarning = retWarn;
        }
        
        return ret;
    }
}

/*
 *  Returns whether there is an expiration warning to display.
 */
-(BOOL) isExpirationWarningVisible
{
    @synchronized (self) {
        BOOL hasWarn = NO;
        if ([self computedExpirationTextAndDisplayAsWarning:&hasWarn] && hasWarn) {
            return YES;
        }
        return NO;
    }
}

/*
 *  Determines if this identity is the currently active one.
 */
-(BOOL) isActive
{
    NSString *activeSeal = [ChatSeal activeSeal];
    return (activeSeal && [activeSeal isEqualToString:self.sealId]);
}

/*
 *  Turn the active state of this identity on/off.
 */
-(BOOL) setActive:(BOOL) enabled withError:(NSError **) err
{
    return [ChatSeal setActiveSeal:(enabled ? [self sealId] : nil) withError:err];
}

/*
 *  Return the date this seal was created (or imported).
 */
-(NSDate *) dateCreated
{
    @synchronized (self) {
        return [identAttribs dateCreated];
    }
}

/*
 *  Return the owner's name.
 */
-(NSString *) ownerName
{
    @synchronized (self) {
        return [identAttribs ownerName];
    }
}

/*
 *  Assign an owner name, but only if it is newer than the 
 *  current one.
 *  - returns YES if the owner name was assigned.
 */
-(BOOL) setOwnerName:(NSString *) name ifBeforeDate:(NSDate *) dtCompare
{
    BOOL ret = NO;
    @synchronized (self) {
        if (!dtCompare) {
            dtCompare = [NSDate date];
        }
        NSDate *dtOwner = [identAttribs dtOwnerUpdated];
        if (dtOwner && [dtOwner compare:dtCompare] == NSOrderedDescending) {
            return NO;
        }
        
        // - when the date of comparison is newer than the prior one, we'll update owner, which
        //   is intended to allow us to adapt to the most recent owner name included in messages.
        if (name != identAttribs.ownerName && ![name isEqualToString:identAttribs.ownerName]) {
            identAttribs.ownerName = name;
            ret                    = YES;
        }
        identAttribs.dtOwnerUpdated = dtCompare;
    }
    [ChatSealIdentity saveIdentityDatabase];
    
    // - make sure the placeholder database is kept up to date.
    [ChatSealVaultPlaceholder saveVaultSealPlaceholderData];
    return ret;
}

/*
 *  Return the sent count.
 */
-(void) incrementSentCount
{
    [self addToSentCount:1];
}

/*
 *  Add counts onto the number of sent messages.
 */
-(void) addToSentCount:(NSUInteger) addCount
{
    @synchronized (self) {
        identAttribs.sentCount += addCount;
        if ([self isOwned]) {
            [identAttribs updateExpirationDate];
            identAttribs.dtMsgSent = [NSDate date];
            [ChatSeal updateAlertBadges];
        }
    }
    [ChatSealIdentity saveIdentityDatabase];
}

/*
 *  Return the recv count.
 */
-(void) incrementRecvCount
{
    [self addToRecvCount:1];
}

/*
 *  Add counts onto the number of received messages.
 */
-(void) addToRecvCount:(NSUInteger) addCount
{
    @synchronized (self) {
        identAttribs.recvCount += addCount;
    }
    [ChatSealIdentity saveIdentityDatabase];
}

/*
 *  Update the seal expiration date.
 */
-(void) updateExpirationWithGivenCount:(BOOL) updateGiven
{
    @synchronized (self) {
        if (updateGiven) {
            identAttribs.givenCount++;
        }
        
        // - update the local expiration date so that we can
        //   reliably track whether we should warn the user.
        [identAttribs updateExpirationDate];
    }
    [ChatSealIdentity saveIdentityDatabase];
    
    
    // - make sure the badges reflect the new state
    [ChatSeal updateAlertBadges];
    
}

/*
 *  Increment the number of times the seal was given to someone.
 */
-(void) incrementSealGivenCount
{
    [self updateExpirationWithGivenCount:YES];
}

/*
 *  When a seal was re-shared with a friend that already has it, we still want 
 *  to know.
 */
-(void) markSealWasReSharedWithAFriend
{
    [self updateExpirationWithGivenCount:NO];
}

/*
 *  Return the count of total usage.
 */
-(NSUInteger) totalUsageCount
{
    @synchronized (self) {
        return identAttribs.sentCount + identAttribs.recvCount;
    }
}

/*
 *  Return the total number of secure items sent with this identity.
 */
-(NSUInteger) sentCount
{
    @synchronized (self) {
        return identAttribs.sentCount;        
    }
}

/*
 *  Return the total number of secure items received with this identity.
 */
-(NSUInteger) recvCount
{
    @synchronized (self) {
        return identAttribs.recvCount;
    }
}

/*
 *  Return the number of times the seal was given to someone else successfully.
 */
-(NSUInteger) sealGivenCount
{
    @synchronized (self) {
        return identAttribs.givenCount;
    }
}

/*
 *  Return the number of times a screenshot was taken of content from this seal.
 */
-(NSUInteger) screenshotsTaken
{
    @synchronized (self) {
        return identAttribs.screenshotsTaken;
    }
}

/*
 *  Every time a seal owner sends a new message we can use the expiration timer
 *  to figure out when our friends' seals will expire and let the person know.
 */
-(NSDate *) nextExpirationDate
{
    @synchronized (self) {
        if ([self isOwned]) {
            return identAttribs.dtOfExpiration;
        }
        return nil;
    }
}

/*
 *  Return the number of days of inactivity before a seal expires.
 */
-(NSUInteger) sealExpirationTimoutInDaysWithError:(NSError **) err
{
    @synchronized (self) {
        return [cachedSeal sealExpirationTimoutInDaysWithError:err];
    }
}

/*
 *  Assign the expiration timeout for this identity's seal.
 */
-(BOOL) setExpirationTimeoutInDays:(NSUInteger) days withError:(NSError **) err
{
    @synchronized (self) {
        if ([cachedSeal setExpirationTimeoutInDays:days withError:err]) {
            // - do not update the expiration date itself here because the only
            //   way to get that over to others' devices is through sharing or
            //   message sharing.   We don't want to give a seal owner the wrong
            //   impression about what changing the expiration does.
            identAttribs.expireDays = days;
            [ChatSealIdentity saveIdentityDatabase];
            return YES;
        }
        else {
            return NO;
        }
    }
}

/*
 *  Returns whether this seal is invalidated (expired or revoked).
 */
-(BOOL) isInvalidated
{
    @synchronized (self) {
        if (cachedSeal && [cachedSeal getRevoked] != PHSCSP_RR_STILL_VALID) {
            return YES;
        }
        return NO;
    }
}

/*
 *  Return whether this identity has been revoked.
 */
-(BOOL) isRevoked
{
    @synchronized (self) {
        if (cachedSeal && [cachedSeal getRevoked] == PHSCSP_RR_REVOKED) {
            return YES;
        }
        return NO;
    }
}

/*
 *  Return whether this identity has been expired.
 */
-(BOOL) isExpired
{
    @synchronized (self) {
        if (cachedSeal && [cachedSeal getRevoked] == PHSCSP_RR_EXPIRED) {
            return YES;
        }
        return NO;
    }
}

/*
 *  Do a deep dive and figure out if this identity should be revoked.
 */
-(BOOL) checkForRevocationWithScreenshotTaken
{
    @synchronized (self) {
        if ([cachedSeal getRevoked] != PHSCSP_RR_STILL_VALID) {
            return YES;
        }
        else {
            // - always save the number of screenshots taken of content protected by this seal
            if (![self isOwned]) {
                identAttribs.screenshotsTaken++;
                [ChatSealIdentity saveIdentityDatabase];
            }
            
            // - now figure out if the seal should be revoked.
            phs_cacheSeal_revoke_reason_t revokeReason = [cachedSeal checkForRevocationWithScreenshotTaken];
            return (revokeReason == PHSCSP_RR_STILL_VALID) ? NO : YES;
        }
    }
}

/*
 *  Do a deep dive and figure out if this identity should be expired.
 */
-(BOOL) checkForExpiration
{
    @synchronized (self) {
        if ([cachedSeal getRevoked] != PHSCSP_RR_STILL_VALID) {
            return YES;
        }
        else {
            // - we never check expiration on an owned seal
            if ([self isOwned]) {
                return NO;
            }
            
            // - now figure out if the seal should be expired.
            phs_cacheSeal_revoke_reason_t revokeReason = [cachedSeal checkForExpiration];
            return (revokeReason == PHSCSP_RR_STILL_VALID) ? NO : YES;
        }
    }
}

/*
 *  Determine if the screenshot revocation flag is set on the seal.
 */
-(BOOL) isRevocationOnScreenshotEnabledWithError:(NSError **) err
{
    @synchronized (self) {
        return [cachedSeal isRevocationOnScreenshotEnabledWithError:err];
    }
}

/*
 *  Set the screenshot revocation flag on the seal.
 */
-(BOOL) setRevokeOnScreenshotEnabled:(BOOL) enabled withError:(NSError **) err
{
    @synchronized (self) {
        return [cachedSeal setRevokeOnScreenshotEnabled:enabled withError:err];
    }
}

/*
 *  Return whether this identity is something we can invalidate via screenshot or by expiration
 */
-(BOOL) canBeInvalidatedByState
{
    if ([self isRevoked]) {
        return NO;
    }
    
    if ([self isOwned]) {
        return NO;
    }
    return YES;
}

/*
 *  Assign an expiration date to the seal associated with this identity.
 *  - This should only be used for testing!
 */
-(BOOL) setExpirationDateExplicitly:(NSDate *) dtExpires withError:(NSError **) err
{
    @synchronized (self) {
        return [cachedSeal setExpirationDate:dtExpires withError:err];        
    }
}

/*
 *  Determine if this object is equal to another identity.
 */
-(BOOL) isEqual:(id)object
{
    if (![object isKindOfClass:[ChatSealIdentity class]]) {
        return NO;
    }
    
    ChatSealIdentity *psiOther = (ChatSealIdentity *) object;
    if (![self.sealId isEqualToString:psiOther.sealId]) {
        return NO;
    }
    
    NSString *myOwner    = self.ownerName;
    NSString *theirOwner = psiOther.ownerName;
    if (!myOwner != !theirOwner ||
        (myOwner && ![myOwner isEqualToString:theirOwner])) {
        return NO;
    }
    
    return YES;
}

/*
 *  Assign a default feed to this identity.
 */
-(void) setDefaultFeed:(NSString *) feedId
{
    @synchronized (self) {
        identAttribs.defaultFeed = feedId;
        
        // - only bother if we have something.
        if (feedId) {
            //  - the idea with the posted feeds is to keep the most recent ones
            //    at the front.
            [identAttribs.postedFeeds removeObject:feedId];
            [identAttribs.postedFeeds insertObject:feedId atIndex:0];
            NSUInteger count = identAttribs.postedFeeds.count;
            if (count > PSI_IDENT_MAX_POSTED_HIST) {
                [identAttribs.postedFeeds removeObjectsInRange:NSMakeRange(PSI_IDENT_MAX_POSTED_HIST, count - PSI_IDENT_MAX_POSTED_HIST)];
            }
        }
    }
    [ChatSealIdentity saveIdentityDatabase];
}

/*
 *  Retrieve the seal's default feed for outgoing messages.
 */
-(NSString *) defaultFeed
{
    @synchronized (self) {
        return identAttribs.defaultFeed;
    }
}

/*
 *  Retrieve a list of all feeds that have been used with this seal to post messages.
 */
-(NSArray *) feedPostingHistory
{
    @synchronized (self) {
        return [NSArray arrayWithArray:identAttribs.postedFeeds];
    }
}

/*
 *  When we receive feed locations from a friend, add them to our current cache so that
 *  we can use that as a tool for locating friends more easily.
 */
-(void) updateFriendFeedLocations:(NSArray *) arrLocations
{
    NSMutableSet *msUpdatedTypes = [NSMutableSet set];
    @synchronized (self) {
        NSUInteger count = [identAttribs.friendFeeds count];
        [identAttribs.friendFeeds addObjectsFromArray:arrLocations];
        if (count < identAttribs.friendFeeds.count) {
            for (ChatSealFeedLocation *loc in arrLocations) {
                [msUpdatedTypes addObject:loc.feedType];
            }
        }
    }
    
    // - when we added a friend to our identity, we'll need to update the friends list version and update the database.
    if ([msUpdatedTypes count]) {
        [ChatSealIdentity updateFeedTypeVersionsForTypesInSet:msUpdatedTypes];
        [ChatSealIdentity saveIdentityDatabase];
    }
}

/*
 *  Return the list of feed locations for my friends.
 */
-(NSArray *) friendFeedLocations
{
    @synchronized (self) {
        return [identAttribs.friendFeeds allObjects];
    }
}

@end

/*******************************
 ChatSealIdentity (internal)
 *******************************/
@implementation ChatSealIdentity (internal)
/*
 *  Return the secure identity object from disk.
 */
+(NSDictionary *) secureIdentityDictionaryWithError:(NSError **) err
{
    NSError *tmp = nil;
    NSURL *u = [RealSecureImage absoluteURLForVaultFile:PSI_IDENT_DB_FILE withError:&tmp];
    if (!u) {
        [CS_error fillError:err withCode:CSErrorArchivalError andFailureReason:tmp ? [tmp localizedDescription] : nil];
        return nil;
    }
    
    // - when the file doesn't exist, we can just assume it is empty.
    if (![[NSFileManager defaultManager] fileExistsAtPath:[u path]]) {
        return [NSDictionary dictionary];
    }
    
    // - load the file.
    RSISecureData *sdIdent = nil;
    if (![RealSecureImage readVaultURL:u intoData:&sdIdent withError:&tmp]) {
        [CS_error fillError:err withCode:CSErrorArchivalError andFailureReason:tmp ? [tmp localizedDescription] : nil];
        return nil;
    }
    
    // - and unarchive it.
    NSDictionary *dRet = nil;
    @try {
        NSObject *obj = [NSKeyedUnarchiver unarchiveObjectWithData:sdIdent.rawData];
        if (![obj isKindOfClass:[NSDictionary class]]) {
            [CS_error fillError:err withCode:CSErrorArchivalError andFailureReason:@"Archive format failure."];
            return nil;
        }
        dRet = (NSDictionary *) obj;
    }
    @catch (NSException *exception) {
        [CS_error fillError:err withCode:CSErrorArchivalError andFailureReason:[exception description]];
        return nil;
    }
    return dRet;
}

/*
 *  Save the secure identity object to disk.
 */
+(BOOL) saveSecureIdentityDictionary:(NSDictionary *) secObj withError:(NSError **) err
{
    // - generate the archive first as a data file.
    NSData *dRet = nil;
    @try {
        dRet = [NSKeyedArchiver archivedDataWithRootObject:secObj];
    }
    @catch (NSException *exception) {
        NSLog(@"CS:  The identity archive generated an exception.  %@", [exception description]);
        [CS_error fillError:err withCode:CSErrorArchivalError andFailureReason:[exception description]];
        return NO;
    }
    
    //  - now save it to the vault.
    NSError *tmp = nil;
    if (![RealSecureImage writeVaultData:dRet toFile:PSI_IDENT_DB_FILE withError:&tmp]) {
        [CS_error fillError:err withCode:CSErrorArchivalError andFailureReason:tmp ? [tmp localizedDescription] : nil];
        return NO;
    }
    return YES;
}

/*
 *  Ensure that the identity database is loaded and ready for action.
 */
+(BOOL) validateIdentityDatabaseWithError:(NSError **) err
{
    @synchronized (mdIdentities) {
        // - the vault check should always come first regardless of what our cache says because
        //   it is the true source of identity content.
        if (![RealSecureImage hasVault]) {
            [CS_error fillError:err withCode:CSErrorVaultNotInitialized];
            return NO;
        }
        
        if (isValidated) {
            return YES;
        }
        
        [mdIdentities removeAllObjects];

        NSDictionary *dSecEntities = [ChatSealIdentity secureIdentityDictionaryWithError:err];
        if (!dSecEntities) {
            return NO;
        }
        
        [mdIdentities addEntriesFromDictionary:dSecEntities];
        isValidated = YES;
    }
    return YES;
}

/*
 *  Save the current identity database to disk.
 */
+(BOOL) saveIdentityDatabase
{
    if (![RealSecureImage hasVault]) {
        NSLog(@"CS:  Failed to save the identity database because the vault is not available.");
        return NO;
    }
    
    @synchronized (mdIdentities) {
        NSError *tmp = nil;
        if (![ChatSealIdentity saveSecureIdentityDictionary:mdIdentities withError:&tmp]) {
            NSLog(@"CS:  Failed to save the identity databse with updated statistics.  %@", [tmp localizedDescription]);
            return NO;
        }
    }
    return YES;
}

/*
 *  Load the internal state based on the seal id.
 */
-(BOOL) loadStateForCachedSeal:(CS_cacheSeal *) cs withError:(NSError **) err
{
    @synchronized (mdIdentities) {
        // - make sure the identity is available.
        if (!isValidated) {
            if (![ChatSealIdentity validateIdentityDatabaseWithError:err]) {
                return NO;
            }
        }
        
        // - make sure the cached seal is available.
        if (!cs) {
            cs = [CS_cacheSeal sealForId:sealId];
            if (!cs) {
                [CS_error fillError:err withCode:CSErrorInvalidSeal andFailureReason:@"Failed to load core seal identity."];
                return NO;
            }
        }
        [cachedSeal release];
        cachedSeal = [cs retain];
        
        // - now load the seal usage attributes that are stored as its 'proven' identity.
        identAttribs = [[mdIdentities objectForKey:sealId] retain];
        if (!identAttribs) {
            // - since the identities are validated, I'll recreate the identity for the seal since
            //   all of it is 'proven' content that can be regenerated.
            // - this generally won't happen unless the identities file is somehow deleted, but I don't think
            //   that error is necessarily a critical failure, and may even be a feature at some point.
            NSLog(@"CS:  Recreating missing identity for seal %@.", sealId);
            identAttribs = [[_CS_identity alloc] init];
            [mdIdentities setObject:identAttribs forKey:sealId];
            [ChatSealIdentity saveIdentityDatabase];
        }
    }
    return YES;
}

/*
 *  Create the identity database for the seal and save it.
 */
+(BOOL) createIdentityDatabaseForSeal:(NSString *) sealId withError:(NSError **) err
{
    _CS_identity *ident = [[[_CS_identity alloc] init] autorelease];
    @synchronized (mdIdentities) {
        [mdIdentities setObject:ident forKey:sealId];
        if (![ChatSealIdentity saveIdentityDatabase]) {
            [mdIdentities removeObjectForKey:sealId];
            return NO;
        }
    }
    return YES;
}

/*
 *  Determines if we should display an expiration warning to the user.
 */
-(NSString *) computedExpirationTextAndDisplayAsWarning:(BOOL *) isWarning
{
    NSString *ret     = nil;
    BOOL retWarn      = NO;
    NSDate *dtExpires = [self nextExpirationDate];
    if (dtExpires) {
        NSCalendar *cal   = [NSCalendar currentCalendar];
        NSUInteger expire = [cal ordinalityOfUnit:NSDayCalendarUnit inUnit:NSEraCalendarUnit forDate:dtExpires];
        NSUInteger dayNow = [cal ordinalityOfUnit:NSDayCalendarUnit inUnit:NSEraCalendarUnit forDate:[NSDate date]];
        NSUInteger num    = expire - dayNow;
        if (dayNow <= expire) {
            if (num < PSI_IDENT_EXPIRE_WARN_DAYS) {
                if (num == 0) {
                    ret = NSLocalizedString(@"Expires today.", nil);
                    retWarn = YES;
                }
                else if (num == 1) {
                    // - this is special because when a seal has a one day expiration period, we don't want
                    //   to keep warning them once they send their message.
                    BOOL alreadyWarned = NO;
                    if (identAttribs.expireDays == 1) {
                        NSUInteger daySent = 0;
                        if (identAttribs.dtMsgSent) {
                            daySent = [cal ordinalityOfUnit:NSDayCalendarUnit inUnit:NSEraCalendarUnit forDate:identAttribs.dtMsgSent];
                            if (daySent == dayNow) {
                                alreadyWarned = YES;
                            }
                        }
                    }
                    
                    if (!alreadyWarned) {
                        ret     = NSLocalizedString(@"Expires tomorrow.", nil);
                        retWarn = YES;
                    }
                }
                else {
                    NSString *tmp = NSLocalizedString(@"Expires in %lu days.", nil);
                    ret = [NSString stringWithFormat:tmp, (unsigned long) num];
                    retWarn = YES;
                }
            }
        }
        else {
            ret     = NSLocalizedString(@"Seal has expired.", nil);
            retWarn = YES;
        }
    }
    
    // - send back the expiration content, if applicable.
    if (isWarning) {
        *isWarning = retWarn;
    }
    return ret;
}

/*
 *  Modify the feed type version numbers for the given items.
 */
+(void) updateFeedTypeVersionsForTypesInSet:(NSSet *)sTypes
{
    @synchronized (mdFriendsPerFeedTypeVersion) {
        for (NSString *sFeedId in sTypes) {
            // - it is intended that we effectively always start by numbering with one because when nothing
            //   exists, the version will be zero.
            NSNumber *n = [mdFriendsPerFeedTypeVersion objectForKey:sFeedId];
            [mdFriendsPerFeedTypeVersion setObject:[NSNumber numberWithUnsignedInteger:[n unsignedIntegerValue] + 1] forKey:sFeedId];
        }
    }
}
@end

/*****************************
 ChatSealIdentity (shared)
 *****************************/
@implementation ChatSealIdentity (shared)
/*
 *  Create and return a new identity object.
 */
+(id) identityForSealId:(NSString *) sid withError:(NSError **) err
{
    ChatSealIdentity *psi = [[[ChatSealIdentity alloc] initWithSeal:sid] autorelease];
    if ([psi loadStateForCachedSeal:nil withError:err]) {
        return psi;
    }
    return nil;
}

/*
 *  Create and return a new identity object for the given cached seal item.
 */
+(id) identityForCacheSeal:(CS_cacheSeal *) cs withError:(NSError **) err
{
    if (!cs) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        return nil;
    }
    ChatSealIdentity *psi = [[[ChatSealIdentity alloc] initWithSeal:cs.sealId] autorelease];
    if ([psi loadStateForCachedSeal:cs withError:err]) {
        return psi;
    }
    return nil;
}

/*
 *  Create a new seal identity, which is a combination of the encryption attributes, inferred proven attributes and counts associated
 *  with the individual.
 */
+(NSString *) createIdentityWithImage:(UIImage *) imgSeal andColor:(RSISecureSeal_Color_t) color andError:(NSError **) err
{
    @synchronized (mdIdentities) {
        // - ensure the overall database is loaded
        if (![ChatSealIdentity validateIdentityDatabaseWithError:err]) {
            return nil;
        }
        
        // - create the seal and its associated identity.
        NSError *tmp = nil;
        NSString *sid = [RealSecureImage createSealWithImage:imgSeal andColor:color andError:&tmp];
        if (sid) {
            // - if the seal was created, generate a new identity and cache it.
            if ([ChatSealIdentity createIdentityDatabaseForSeal:sid withError:&tmp]) {
                [CS_cacheSeal precacheSealForId:sid];
                [ChatSeal notifySealActivityByName:kChatSealNotifySealCreated andSeal:sid];
            }
            else {
                [RealSecureImage deleteSealForId:sid andError:nil];
                sid = nil;
                [CS_error fillError:err withCode:CSErrorIdentityCreationFailure andFailureReason:[tmp localizedDescription]];
            }
        }
        else {
            [CS_error fillError:err withCode:CSErrorIdentityCreationFailure andFailureReason:[tmp localizedDescription]];
        }
        return sid;
    }
}

/*
 *  Import an existing seal identity into the system.
 */
+(NSString *) importIdentityWithData:(NSData *) dExported usingPassword:(NSString *) pwd andError:(NSError **) err
{
    @synchronized (mdIdentities) {
        // - ensure the overall database is loaded
        if (![ChatSealIdentity validateIdentityDatabaseWithError:err]) {
            return nil;
        }
        
        RSISecureSeal *ssImported = [RealSecureImage importSeal:dExported usingPassword:pwd withError:err];
        if (!ssImported) {
            return nil;
        }
        
        // - if the seal was imported, generate a new identity and cache it, but only
        //   if the identity database doesn't exist already
        NSError *tmp               = nil;
        NSString *sid              = [ssImported sealId];
        BOOL doSealProcessing      = YES;
        BOOL isExisting            = NO;
        if ([mdIdentities objectForKey:sid]) {
            isExisting = YES;
            
            // - the seal exists but was previously revoked, we need to make sure the cached item is updated.
            CS_cacheSeal *cs = [CS_cacheSeal sealForId:sid];
            if (cs && [cs getRevoked] == PHSCSP_RR_STILL_VALID) {
                // - the seal is already OK, so don't worry about it.
                doSealProcessing = NO;
            }
        }
        else {
            if (![ChatSealIdentity createIdentityDatabaseForSeal:sid withError:&tmp]) {
                [RealSecureImage deleteSealForId:sid andError:nil];
                sid = nil;
                [CS_error fillError:err withCode:CSErrorIdentityImportFailure andFailureReason:[tmp localizedDescription]];
            }
        }
        
        // - make sure the caches are up to date and the caller is notified.
        if (sid && doSealProcessing) {
            if (isExisting) {
                [CS_cacheSeal recacheSeal:ssImported];
            }
            else {
                [CS_cacheSeal retrieveAndCacheSealForId:sid usingSecureSecureObject:ssImported];
            }
            [ChatSealMessage recacheMessagesForSeal:ssImported];
            [ChatSeal notifySealActivityByName:isExisting ? kChatSealNotifySealRenewed : kChatSealNotifySealImported andSeal:sid];
            [ChatSeal updateAlertBadges];
        }
        return sid;
    }
}

/*
 *  Destroy this identity, including its seal, cache and attributes.
 */
+(BOOL) permanentlyDestroyIdentity:(NSString *) sealId withError:(NSError **) err
{
    @synchronized (mdIdentities) {
        if (![ChatSealIdentity validateIdentityDatabaseWithError:err]) {
            return NO;
        }
        
        BOOL ret = [RealSecureImage deleteSealForId:sealId andError:err];
        if (ret) {
            // - update the friends' feed version numbers so that data is requeried.
            _CS_identity *ident = [mdIdentities objectForKey:sealId];
            if (ident) {
                @synchronized (mdFriendsPerFeedTypeVersion) {
                    for (ChatSealFeedLocation *loc in ident.friendFeeds) {
                        NSNumber *n = [mdFriendsPerFeedTypeVersion objectForKey:loc.feedType];
                        if (n) {
                            [mdFriendsPerFeedTypeVersion setObject:[NSNumber numberWithUnsignedInteger:[n unsignedIntegerValue] + 1] forKey:loc.feedType];
                        }
                    }
                }
            }
            
            // - make sure the cache epoch is incremented to prevent old
            //   caches from being used.
            [ChatSeal incrementCurrentCacheEpoch];
            
            // - discard the caches
            [CS_cacheSeal discardSealForId:sealId];
            [ChatSealMessage permanentlyLockAllMessagesForSeal:sealId];
            
            // - and the identity attributes, which I'm going to permit
            //   an error here since there isn't much that can be done once
            //   the seal is successfully deleted.
            [mdIdentities removeObjectForKey:sealId];
            [ChatSealIdentity saveIdentityDatabase];
            
            // - we may have just deleted a seal that was revoked, so there is no alert now.
            [ChatSeal updateAlertBadges];
        }
        return ret;
    }
}

@end

/**********************
 _CS_identity
 **********************/
@implementation _CS_identity
@synthesize ownerName;
@synthesize dtOwnerUpdated;
@synthesize sentCount;
@synthesize recvCount;
@synthesize givenCount;
@synthesize screenshotsTaken;
@synthesize dtOfExpiration;
@synthesize expireDays;
@synthesize dtMsgSent;
@synthesize defaultFeed;
@synthesize postedFeeds;
@synthesize friendFeeds;

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        dtCreated         = [[NSDate date] retain];
        ownerName         = nil;
        dtOwnerUpdated    = nil;
        sentCount         = 0;
        recvCount         = 0;
        givenCount        = 0;
        screenshotsTaken  = 0;
        dtOfExpiration    = nil;
        expireDays        = [RSISecureSeal defaultSelfDestructDays];
        dtMsgSent         = nil;
        defaultFeed       = nil;
        postedFeeds       = [[NSMutableArray alloc] init];
        friendFeeds       = [[NSMutableSet alloc] init];
    }
    return self;
}

/*
 * Decode the object
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [self init];
    if (self) {
        @try {
            [dtCreated release];
            dtCreated              = [[aDecoder decodeObjectForKey:PSI_IDENT_KEY_CREATE] retain];
            self.ownerName         = [aDecoder decodeObjectForKey:PSI_IDENT_KEY_OWNER];
            self.dtOwnerUpdated    = [aDecoder decodeObjectForKey:PSI_IDENT_KEY_OWNERDT];
            self.sentCount         = (NSUInteger) [aDecoder decodeIntegerForKey:PSI_IDENT_KEY_SENT];
            self.recvCount         = (NSUInteger) [aDecoder decodeIntegerForKey:PSI_IDENT_KEY_RECV];
            self.givenCount        = (NSUInteger) [aDecoder decodeIntegerForKey:PSI_IDENT_KEY_GIVEN];
            self.screenshotsTaken  = (NSUInteger) [aDecoder decodeIntegerForKey:PSI_IDENT_KEY_SCSHOTS];
            self.dtOfExpiration    = [aDecoder decodeObjectForKey:PSI_IDENT_KEY_EXPIREDATE];
            self.expireDays        = (NSUInteger) [aDecoder decodeIntegerForKey:PSI_IDENT_KEY_EXPDAYS];
            self.dtMsgSent         = [aDecoder decodeObjectForKey:PSI_IDENT_KEY_LASTSENDDATE];
            self.defaultFeed       = [aDecoder decodeObjectForKey:PSI_IDENT_KEY_FEED];
            NSMutableArray *ma     = [aDecoder decodeObjectForKey:PSI_IDENT_KEY_FEED_HISTORY];
            [self.postedFeeds removeAllObjects];
            if (ma) {
                [self.postedFeeds addObjectsFromArray:ma];
            }
            NSMutableSet *ms       = [aDecoder decodeObjectForKey:PSI_IDENT_KEY_FRIEND_FEEDS];
            [self.friendFeeds removeAllObjects];
            if (ms) {
                [self.friendFeeds addObjectsFromArray:[ms allObjects]];
            }
        }
        @catch (NSException *exception) {
            // - disallow exceptions
            NSLog(@"CS:  Unexpected identity exception during decoding.  %@", [exception description]);
        }
    }
    return self;
}

/*
 *  Encode the object.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:dtCreated forKey:PSI_IDENT_KEY_CREATE];
    [aCoder encodeObject:self.ownerName forKey:PSI_IDENT_KEY_OWNER];
    [aCoder encodeObject:self.dtOwnerUpdated forKey:PSI_IDENT_KEY_OWNERDT];
    [aCoder encodeInteger:(NSInteger) self.sentCount forKey:PSI_IDENT_KEY_SENT];
    [aCoder encodeInteger:(NSInteger) self.recvCount forKey:PSI_IDENT_KEY_RECV];
    [aCoder encodeInteger:(NSInteger) self.givenCount forKey:PSI_IDENT_KEY_GIVEN];
    [aCoder encodeInteger:(NSInteger) self.screenshotsTaken forKey:PSI_IDENT_KEY_SCSHOTS];
    [aCoder encodeObject:self.dtOfExpiration forKey:PSI_IDENT_KEY_EXPIREDATE];
    [aCoder encodeInteger:(NSInteger)self.expireDays forKey:PSI_IDENT_KEY_EXPDAYS];
    [aCoder encodeObject:self.dtMsgSent forKey:PSI_IDENT_KEY_LASTSENDDATE];
    [aCoder encodeObject:self.defaultFeed forKey:PSI_IDENT_KEY_FEED];
    [aCoder encodeObject:self.postedFeeds forKey:PSI_IDENT_KEY_FEED_HISTORY];
    [aCoder encodeObject:self.friendFeeds forKey:PSI_IDENT_KEY_FRIEND_FEEDS];
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [dtCreated release];
    dtCreated = nil;
    
    [ownerName release];
    ownerName = nil;
    
    [dtOwnerUpdated release];
    dtOwnerUpdated = nil;
    
    [dtOfExpiration release];
    dtOfExpiration = nil;
    
    [dtMsgSent release];
    dtMsgSent = nil;
    
    [defaultFeed release];
    defaultFeed = nil;
    
    [postedFeeds release];
    postedFeeds = nil;
    
    [friendFeeds release];
    friendFeeds = nil;
    
    [super dealloc];
}

/*
 *  Return the creation date.
 */
-(NSDate *) dateCreated
{
    if (!dtCreated) {
        dtCreated = [[NSDate date] retain];
    }
    return [[dtCreated retain] autorelease];
}

/*
 *  Using the current date and expiration days, update the date of expiration.
 */
-(void) updateExpirationDate
{
    NSUInteger curExpireDays = self.expireDays;
    if (curExpireDays) {
        self.dtOfExpiration = [[NSDate date] dateByAddingTimeInterval:(NSTimeInterval)(curExpireDays * 24 * 60 * 60)];
    }
}

@end

/*********************************
 ChatSealIdentityFriend
 *********************************/
@implementation ChatSealIdentityFriend
/*
 *  Object attributes.
 */
{
    ChatSealFeedLocation *loc;
    BOOL                 isSealOwner;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        loc         = nil;
        isSealOwner = NO;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [loc release];
    loc = nil;
    
    [super dealloc];
}

/*
 *  Return the location for this friend.
 */
-(ChatSealFeedLocation *) location
{
    return [[loc retain] autorelease];
}

/*
 *  Return whether we own the identity that supplied this friend relationship.
 */
-(BOOL) isSealOwnerInRelationship
{
    return isSealOwner;
}

/*
 *  Return a debugging description for this object.
 */
-(NSString *) description
{
    return [NSString stringWithFormat:@"ChatSealIdentityFriend: %@ (%@) --> %s", self.location.feedAccount, self.location.feedType, self.isSealOwnerInRelationship ? "IDENTITY OWNED" : "consumer"];
}
@end

/**********************************
 ChatSealIdentityFriend (internal)
 **********************************/
@implementation ChatSealIdentityFriend (internal)

/*
 *  Initialize the object.
 */
-(id) initWithLocation:(ChatSealFeedLocation *) location andOwnedIdentity:(BOOL) isOwnedIdentity
{
    self = [self init];
    if (self) {
        loc         = [location retain];
        isSealOwner = isOwnedIdentity;
    }
    return self;
}

@end
