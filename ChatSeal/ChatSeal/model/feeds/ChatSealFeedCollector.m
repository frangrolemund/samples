//
//  ChatSealFeedCollector.m
//  ChatSeal
//
//  Created by Francis Grolemund on 3/24/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Accounts/Accounts.h>
#import "ChatSealFeedCollector.h"
#import "ChatSeal.h"
#import "CS_feedTypeTwitter.h"
#import "CS_feedShared.h"
#import "CS_sessionManager.h"
#import "CS_postedMessageDB.h"

//  THREADING-NOTES:
//  - internal locking is provided.
//  - as described in this object's header, locks are intentionally not held when calling into either types or the sessions.

// - constants
static NSString *PSFC_STD_COLL_CONFIG           = @"collector";
static NSString *PSFC_STD_COLL_POSTED           = @"posted";
static NSString *PSFC_STD_UPDATE_KEY            = @"lastUpd";
static NSString *PSFC_STD_UPDATE_FEEDS_KEY      = @"updFeeds";
static const NSUInteger PSFC_STD_REFRESH_DELAY  = 60 * 3;
static const NSUInteger PSFC_STD_TIMER_DELAY    = 5;
static const NSUInteger PSFC_STD_HIGHPRIO_DELAY = PSFC_STD_TIMER_DELAY;

// - forward declarations
@interface ChatSealFeedCollector (internal) <ChatSealFeedTypeDelegate>
+(NSURL *) feedCollectionURLWithoutCreation;
+(NSURL *) feedPostedMessageDBURL;
-(void) processNextPendingFeedTypeWithNotification:(BOOL) fireNotification andCompletion:(psfCollectorCompletionBlock) completionBlock;
+(NSURL *) feedCollectionConfigurationFile;
-(BOOL) loadCollectorDataWithError:(NSError **) err;
-(BOOL) saveCollectorDataWithError:(NSError **) err;
-(BOOL) checkOpenWithCompletion:(psfCollectorCompletionBlock) completionBlock;
-(void) requeryFeedPermissionsWithNotification:(BOOL) fireNotification andCompletion:(psfCollectorCompletionBlock) completionBlock;
-(void) updateFeedsForDeletedMessageOrSeal:(NSString *) itemId asMessage:(BOOL) isMessage;
-(void) notifySealInvalidated:(NSNotification *) notification;
-(void) notifySealImported:(NSNotification *) notification;
-(void) timerFired;
-(void) refreshActiveFeedsInTypes:(NSArray *) arrToRefresh withHighPriorityRestriction:(BOOL) onlyHighPrio andCompletion:(void(^)(void)) completionBlock;
-(void) performHighPriorityProcessingIfNecessary;
-(NSDate *) dateOfLastRefresh;
-(void) sortFeeds:(NSMutableArray *) maFeeds forProcessingInCategory:(cs_cnt_throttle_category_t) cat;
-(void) sortFeedsForRealtimeProcessing:(NSMutableArray *) maFeeds;
-(void) notifySealCreated:(NSNotification *)notification;
-(void) checkForDormantState;
@end

@interface ChatSealFeedCollector (session) <CS_sessionManagerDelegate>
@end

/****************************
 ChatSealFeedCollector
 ****************************/
@implementation ChatSealFeedCollector
/*
 *  Object attributes.
 */
{
    BOOL                       isOpen;
    BOOL                       hasBeenQueriedAtLeastOnce;
    CS_centralNetworkThrottle *cntNetThrottle;
    ACAccountStore             *asFeedAccounts;
    NSMutableArray             *maFeedTypes;
    NSMutableArray             *maPendingFeedTypes;
    NSMutableDictionary        *mdCollectorData;
    CS_sessionManager         *smManagers[CS_SMSQ_COUNT];
    NSOperationQueue           *opqCollector;
    BOOL                       inRefresh;
    CS_postedMessageDB        *postedMessages;
    NSTimer                    *tmCollectorUpdates;
    BOOL                       needsHighPriorityUpdate;
    BOOL                       inHighPriorityProcessing;
    BOOL                       hasBeenRefreshedAtLeastOnce;
    NSDate                     *dtLastHighPrio;
    NSUInteger                 numImportedSinceLastDormant;
}

/*
 *  Destroy all the configuration and feed accounting.
 */
+(BOOL) destroyAllFeedsWithError:(NSError **) err
{
    NSURL *u     = [ChatSealFeedCollector feedCollectionURL];
    NSError *tmp = nil;
    if (![[NSFileManager defaultManager] removeItemAtURL:u error:&tmp]) {
        [CS_error fillError:err withCode:CSErrorFilesystemAccessError andFailureReason:[tmp localizedDescription]];
        return NO;
    }
    return YES;
}

/*
 *  Return the location where feed data is stored.
 */
+(NSURL *) feedCollectionURL
{
    NSURL *u = [ChatSealFeedCollector feedCollectionURLWithoutCreation];
    if (![[NSFileManager defaultManager] fileExistsAtPath:[u path]]) {
        NSError *err = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtURL:u withIntermediateDirectories:YES attributes:nil error:&err]) {
            NSLog(@"CS: Failed to create the feed directory.");
            return nil;
        }
    }
    return u;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        isOpen                    = NO;
        hasBeenQueriedAtLeastOnce = NO;
        asFeedAccounts            = nil;
        maFeedTypes               = nil;
        maPendingFeedTypes        = nil;
        mdCollectorData           = nil;
        postedMessages            = nil;
        for (ps_sm_session_quality_t qual = 0; qual < CS_SMSQ_COUNT; qual++) {
            smManagers[qual] = nil;
        }
        numImportedSinceLastDormant = 0;
        
        // - the collector uses an operation queue for refreshing, but we don't want a ton
        //   of outstanding threads.
        opqCollector                             = [[NSOperationQueue alloc] init];
        opqCollector.maxConcurrentOperationCount = 1;
        tmCollectorUpdates          = nil;
        needsHighPriorityUpdate     = NO;
        inHighPriorityProcessing    = NO;
        hasBeenRefreshedAtLeastOnce = NO;
        dtLastHighPrio              = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    if (isOpen) {
        // - the reason for this is to ensure that the delegates are unset in the aggregated
        //   objects before we get to this point because otherwise, a thread that is racing
        //   for the delegate could get to it right before we close it here in dealloc, but
        //   couldn't retain it because we're already destroying the object.
        NSLog(@"CS-ALERT: The active feed collector must be closed before deallocation.");
    }
    [self close];
    
    [opqCollector cancelAllOperations];
    [opqCollector release];
    opqCollector = nil;
    
    [super dealloc];
}

/*
 *  Determine if the feed collector has been opened at least once before, but do
 *  so without opening or using it.
 */
-(BOOL) isConfigured
{
    @synchronized (self) {
        NSURL *u = [ChatSealFeedCollector feedCollectionURLWithoutCreation];
        if ([[NSFileManager defaultManager] fileExistsAtPath:[u path]]) {
            // - the really important detail is the configuration flag in the user defaults because
            //   it tracks explicitly when we've guided the user through the approval process.
            if ([ChatSeal collectorFirstTimeCompletedFlag]) {
                return YES;
            }
        }
    }
    return NO;
}

/*
 *  Determines if the collector has been requeried for feed permissions at least once.
 */
-(BOOL) hasBeenAuthQueried
{
    BOOL ret = NO;
    @synchronized (self) {
        ret = hasBeenQueriedAtLeastOnce;
    }
    return ret;
}

/*
 *  Returns the authorization state for this object.
 */
-(BOOL) isAuthorized
{
    if (![self isConfigured]) {
        return NO;
    }
    
    NSArray *arrTypes = nil;
    @synchronized (self) {
        arrTypes = [NSArray arrayWithArray:maFeedTypes];
    }
    
    // - if any of the types are authorized then we can assume we have
    //   some authorization, at least.
    for (ChatSealFeedType *ft in arrTypes) {
        if ([ft isAuthorized]) {
            return YES;
        }
    }
    return NO;
}

/*
 *  This is intended as a quick check to see if feeds exist.
 */
-(BOOL) hasAnyFeeds
{
    NSArray *arrTypes = nil;
    @synchronized (self) {
        arrTypes = [NSArray arrayWithArray:maFeedTypes];
    }

    for (ChatSealFeedType *ft in arrTypes) {
        NSArray *arrFeeds = [ft feeds];
        if ([arrFeeds count]) {
            return YES;
        }
    }
    return NO;
}

/*
 *  Returns whether the collector is currently open.
 */
-(BOOL) isOpen
{
    @synchronized (self) {
        return isOpen;
    }
}

/*
 *  Open the collector or first initialize it.
 *  - the question of whether to query permissions now or not depends on whether you want the
 *    Twitter authorization routines to fire and possibly pop warning alerts.
 */
-(void) openAndQuery:(BOOL) doQuery withCompletion:(psfCollectorCompletionBlock) completionBlock
{
    BOOL wasFirstConfiguration = NO;
    @synchronized (self) {
        if (isOpen) {
            if (completionBlock) {
                completionBlock(self, YES, nil);
            }
            return;
        }
        
        NSError *tmp = nil;
        
        // - if we have a vault, but it isn't open, that is a problem and we cannot continue because
        //   we won't have access to load the encrypted feed configurations from disk.
        if ([ChatSeal hasVault] && ![ChatSeal isVaultOpen]) {
            if (completionBlock) {
                [CS_error fillError:&tmp withCode:CSErrorVaultNotInitialized];
                completionBlock(self, NO, tmp);
            }
        }
        
        // - when the collector isn't configured, we need to create a location for it to use for storing data.
        if (![self isConfigured]) {
            NSURL *u = [ChatSealFeedCollector feedCollectionURL];
            if (![[NSFileManager defaultManager] createDirectoryAtPath:[u path] withIntermediateDirectories:YES attributes:nil error:&tmp]) {
                if (completionBlock) {
                    NSError *err = nil;
                    [CS_error fillError:&err withCode:CSErrorFilesystemAccessError andFailureReason:[tmp localizedDescription]];
                    completionBlock(self, NO, err);
                    return;
                }
            }
            wasFirstConfiguration = YES;
        }
        
        // - load the posted message database once and keep it around becase it is useful to have one central location for
        //   that data.
        postedMessages = [[CS_postedMessageDB databaseFromURL:[ChatSealFeedCollector feedPostedMessageDBURL] withError:&tmp] retain];
        if (!postedMessages) {
            if (completionBlock) {
                completionBlock(self, NO, tmp);
            }
            return;
        }
        
        // - load the throttle configuration
        if (!cntNetThrottle) {
            cntNetThrottle = [[CS_centralNetworkThrottle alloc] init];
            if (![cntNetThrottle openWithError:&tmp]) {
                if (completionBlock) {
                    completionBlock(self, NO, tmp);
                }
                [cntNetThrottle release];
                cntNetThrottle = nil;
                return;
            }
        }
        
        // - load the configuration that exists before continuing.
        if (![self loadCollectorDataWithError:&tmp]) {
            if (completionBlock) {
                completionBlock(self, NO, tmp);
            }
            return;
        }
        
        // - the feed types need to be created before the session managers or pending
        //   downloads won't be able to resolve their sources.
        if (!maFeedTypes) {
            // - NOTE:  there is no choice here about whether these types are created.  It is expected
            //          that the types at least exist, even if they are disabled or not authorized because
            //          they will be responsible for tracking each of their individual feeds.
            // - use the implementation variable below to warn you when your type isn't supported.
            maFeedTypes                                               = [[NSMutableArray alloc] init];
            id<CS_sharedChatSealFeedTypeImplementation> validFeedType = [[[CS_feedTypeTwitter alloc] initWithDelegate:self] autorelease];
            [maFeedTypes addObject:validFeedType];
            // - do a quick sanity test on the feeds.
            for (ChatSealFeedType *ft in maFeedTypes) {
                if (![ft hasMinimumImplementation]) {
                    NSLog(@"CS-ALERT: There is a partially implemented feed type.");
                }
            }
        }
        
        // - build the session managers that will handle requests.
        for (ps_sm_session_quality_t qual = 0; qual < CS_SMSQ_COUNT; qual++) {
            if (!smManagers[qual]) {
                smManagers[qual]          = [[CS_sessionManager alloc] initWithSessionQuality:qual];
                smManagers[qual].delegate = self;
            }
            if (![smManagers[qual] openWithError:&tmp]) {
                if (completionBlock) {
                    completionBlock(self, NO, tmp);
                }
                return;
            }
        }

        // - the first time the collector is finished its processing is important because we'll
        //   be checking authorization next.
        if (![ChatSeal collectorFirstTimeCompletedFlag]) {
            [ChatSeal setCollectorFirstTimeFlag:YES];
        }
        
        // - setup the notification to watch seal changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifySealInvalidated:) name:kChatSealNotifySealInvalidated object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifySealImported:) name:kChatSealNotifySealImported object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifySealImported:) name:kChatSealNotifySealRenewed object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifySealCreated:) name:kChatSealNotifySealCreated object:nil];
        
        // - the collector does some regular types of activitities that are best dealt with by a timer.
        tmCollectorUpdates = [[NSTimer timerWithTimeInterval:PSFC_STD_TIMER_DELAY target:self selector:@selector(timerFired) userInfo:nil repeats:YES] retain];
        [[NSRunLoop mainRunLoop] addTimer:tmCollectorUpdates forMode:NSRunLoopCommonModes];
        
        // - don't lead with a high priority update.
        dtLastHighPrio = [[NSDate date] retain];
        isOpen = YES;
    }
    
    // - when we first configure the collector, pass any feed locations we may have received from seal transfer onto the types
    //   for processing to make sure we more quickly receive our first messages.
    if (wasFirstConfiguration) {
        NSArray *arrAllIdentities = [ChatSeal availableIdentitiesWithError:nil];
        NSMutableArray *maToProc  = nil;
        if ([arrAllIdentities count]) {
            for (ChatSealIdentity *ident in arrAllIdentities) {
                NSArray *arrLocs = [ident friendFeedLocations];
                for (ChatSealFeedLocation *loc in arrLocs) {
                    if (!loc.customContext) {
                        continue;
                    }
                    
                    if (!maToProc) {
                        maToProc = [NSMutableArray array];
                    }
                    [maToProc addObject:loc];
                }
            }
            
            if (maToProc) {
                [self processReceivedFeedLocations:maToProc];
            }
        }
    }

    // - query the account status?
    if (doQuery) {
        [self requeryFeedPermissionsWithNotification:NO andCompletion:completionBlock];
    }
    else {
        if (completionBlock) {
            completionBlock(self, YES, nil);
        }
        return;
    }
}

/*
 *  Requery the permissions for accessing the different feed types.
 */
-(void) requeryFeedPermissionsWithCompletion:(psfCollectorCompletionBlock) completionBlock
{
    [self requeryFeedPermissionsWithNotification:YES andCompletion:completionBlock];
}

/*
 *  Returns whether the feed types are being actively queried.
 */
-(BOOL) isQueryingFeedPermissions
{
    @synchronized (self) {
        return (maPendingFeedTypes ? YES : NO);
    }
}

/*
 *  The feeds in the collector expect to be kicked periodically to do work that is
 *  necessary for them.   This method is used for that purpose, probably in response
 *  to a timer event.
 */
-(BOOL) refreshActiveFeedsAndAdvancePendingOperationsWithError:(NSError **) err
{
    // - we cannot do anything without a vault.
    if (![ChatSeal hasVault]) {
        [self checkForDormantState];
        [CS_error fillError:err withCode:CSErrorVaultRequired];
        return NO;
    }
    
    // - keep the critical section relatively small, just long enough to
    //   get feed handles we can work with.
    NSArray *aTmpTypes = nil;
    @synchronized (self) {
        if (!isOpen) {
            [self checkForDormantState];
            [CS_error fillError:err withCode:CSErrorInvalidArgument];
            return NO;
        }
        
        // - assign the update date, but we won't worry about saving it right now
        //   since it will be saved as soon as we get into the refresh.
        [mdCollectorData setObject:[NSDate date] forKey:PSFC_STD_UPDATE_KEY];
        
        // - only allow a single refresh of any type to occur at a time.
        if (inRefresh || inHighPriorityProcessing) {
            return YES;
        }
        
        // - just grab the current types to continue.
        aTmpTypes                   = [NSArray arrayWithArray:maFeedTypes];
        inRefresh                   = YES;
        hasBeenRefreshedAtLeastOnce = YES;
    }
    
    // - refresh the feeds.
    [self refreshActiveFeedsInTypes:aTmpTypes withHighPriorityRestriction:NO andCompletion:^(void) {
        // - make sure that we can trigger another one of these.
        @synchronized (self) {
            inRefresh = NO;
        }
        
        // - let any interested parties know of the update.
        [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kChatSealNotifyFeedRefreshCompleted object:self];
        }];
        
        // - if there is a need to start high-priority work while this was happening,
        //   do so now.
        [self performHighPriorityProcessingIfNecessary];
    }];
    return YES;
}

/*
 *  Return the textual description of the last time the feeds were refreshed.
 */
-(NSString *) lastFeedRefreshResult
{
    NSDate *dtUpdated = nil;
    NSNumber *nFeeds  = nil;
    @synchronized (self) {
        if (!isOpen) {
            return nil;
        }

        dtUpdated = [mdCollectorData objectForKey:PSFC_STD_UPDATE_KEY];
        nFeeds    = [mdCollectorData objectForKey:PSFC_STD_UPDATE_FEEDS_KEY];
    }
    
    NSString *sFmt   = NSLocalizedString(@"Last Update:  %@", nil);
    if (nFeeds && nFeeds.unsignedIntegerValue) {
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        
        // - first figure out the day to print.
        NSDate *dtNow        = [NSDate date];
        if (!dtUpdated) {
            dtUpdated = dtNow;
        }
        NSString *sDate      = nil;
        if (dtNow.timeIntervalSince1970 - dtUpdated.timeIntervalSince1970 < (60 * 60 * 48)) {
            NSDateComponents *dcLast = [[NSCalendar currentCalendar] components:NSCalendarUnitDay fromDate:dtUpdated];
            NSDateComponents *dcCur  = [[NSCalendar currentCalendar] components:NSCalendarUnitDay fromDate:dtNow];
            if (dcLast.day == dcCur.day) {
                sDate = NSLocalizedString(@"Today", nil);
            }
            else {
                sDate = NSLocalizedString(@"Yesterday", nil);
            }
        }
        else {
            [df setDateStyle:NSDateFormatterMediumStyle];
            [df setTimeStyle:NSDateFormatterNoStyle];
            sDate = [df stringFromDate:dtUpdated];
        }
        
        // - now the time.
        [df setDateStyle:NSDateFormatterNoStyle];
        [df setTimeStyle:NSDateFormatterShortStyle];
        NSString *sTime = [df stringFromDate:dtUpdated];
        [df release];
        NSString *sDesc                        = NSLocalizedString(@"%@ at %@", nil);
        sDesc                                  = [NSString stringWithFormat:sDesc, sDate, sTime];
        return [NSString stringWithFormat:sFmt, sDesc];
    }
    else {
        return [NSString stringWithFormat:sFmt, nFeeds ? NSLocalizedString(@"No feeds are online.", nil) : NSLocalizedString(@"Not updated yet.", nil)];
    }
}

/*
 *  Close the feed collector.
 */
-(void) close
{
    NSMutableArray *maTmpTypes = [NSMutableArray array];
    NSMutableArray *maTmpMgrs  = [NSMutableArray array];
    @synchronized (self) {
        isOpen = NO;
        
        [dtLastHighPrio release];
        dtLastHighPrio = nil;
        
        [tmCollectorUpdates invalidate];
        [tmCollectorUpdates release];
        tmCollectorUpdates = nil;
        
        // - don't watch any longer for seal changes.
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        
        // - grab the objects so that we can explicitly close them.
        [maTmpTypes addObjectsFromArray:maPendingFeedTypes];
        [maTmpTypes addObjectsFromArray:maFeedTypes];
        [maPendingFeedTypes release];
        maPendingFeedTypes = nil;
        [maFeedTypes release];
        maFeedTypes = nil;
        
        [mdCollectorData release];
        mdCollectorData = nil;

        // - grab the session managers so they can be explicitly closed also.
        // - all of the session managers need to be discarded last in case the
        //   feeds had some last work they tried to accomplish.
        for (ps_sm_session_quality_t qual = 0; qual < CS_SMSQ_COUNT; qual++) {
            if (smManagers[qual]) {
                [maTmpMgrs addObject:smManagers[qual]];
            }
        }
        
        [postedMessages release];
        postedMessages = nil;
        
        [cntNetThrottle close];
        [cntNetThrottle release];
        cntNetThrottle = nil;
        
        // - make sure the account store is discarded last because
        //   there may be outstanding references associated with it.
        [asFeedAccounts release];
        asFeedAccounts = nil;
    }
    
    // - explicitly close these types, but outside our lock.
    for (ChatSealFeedType *ft in maTmpTypes) {
        ft.delegate = nil;
        [ft close];
    }
    
    // - same with the sessions.
    for (CS_sessionManager *sm in maTmpMgrs) {
        sm.delegate = nil;
        [sm close];
    }
}

/*
 *  Return the feed types available for access.
 */
-(NSArray *) availableFeedTypes
{
    @synchronized (self) {
        return [NSArray arrayWithArray:maFeedTypes];
    }
}

/*
 *  Return the feed for the given type.
 */
-(ChatSealFeedType *) typeForId:(NSString *) typeId
{
    @synchronized (self) {
        for (ChatSealFeedType *ft in maFeedTypes) {
            if ([ft.typeId isEqualToString:typeId]) {
                return [[ft retain] autorelease];
            }
        }
    }
    return nil;
}

/*
 *  Return the feeds in the system as a sorted list that can be returned to the caller
 */
-(NSArray *) availableFeedsAsSortedList
{
    // - keep the critical section small and don't call into the objects.
    NSArray *arrTmpTypes = nil;
    @synchronized (self) {
        arrTmpTypes = [NSArray arrayWithArray:maFeedTypes];
    }
    
    // - grab the whole list of feeds.
    NSMutableArray *arrRet = [NSMutableArray array];
    for (ChatSealFeedType *ft in arrTmpTypes) {
        NSArray *arr = [ft feeds];
        [arrRet addObjectsFromArray:arr];
    }
    
    // - the feed id is a great source for sorting because it is based on the type and the
    //   user id.
    [arrRet sortUsingComparator:^NSComparisonResult(ChatSealFeed *f1, ChatSealFeed *f2) {
        NSString *s1 = [f1 feedId];
        NSString *s2 = [f2 feedId];
        if (s1 && s2) {
            return [s1 compare:s2];
        }
        else if (s1) {
            return NSOrderedDescending;
        }
        else if (s2) {
            return NSOrderedAscending;
        }
        else {
            return NSOrderedSame;
        }
    }];
    
    return arrRet;
}

/*
 *  Return the feed that matches the given id.
 */
-(ChatSealFeed *) feedForId:(NSString *) feedId
{
    // - keep the critical section small and don't call into the objects.
    NSArray *arrTmpTypes = nil;
    @synchronized (self) {
        arrTmpTypes = [NSArray arrayWithArray:maFeedTypes];
    }
    
    // - now query each feed one at a time.
    for (ChatSealFeedType *ft in arrTmpTypes) {
        NSArray *arr = [ft feeds];
        for (ChatSealFeed *feed in arr) {
            if ([feed.feedId isEqualToString:feedId]) {
                return [[feed retain] autorelease];
            }
        }
    }
    
    return nil;
}

/*
 *  Figure out how many entries are outstanding for the given message.
 */
-(NSUInteger) numberOfPendingPostsForMessage:(NSString *) messageId
{
    // - keep the critical section small and don't call into the objects.
    NSArray *arrTmpTypes = nil;
    @synchronized (self) {
        if (!isOpen) {
            return 0;
        }
        
        arrTmpTypes = [NSArray arrayWithArray:maFeedTypes];
    }
    
    // - for each type, grab its feeds and query each for their list of safe entries.
    NSUInteger numPending = 0;
    for (ChatSealFeedType *ft in arrTmpTypes) {
        NSArray *arr = [ft feeds];
        for (ChatSealFeed *feed in arr) {
            NSArray *arrPending = [feed pendingSafeEntriesToPost];
            for (NSString *safeEntryId in arrPending) {
                // - again, keep our critical section small and only around the posted message database.
                @synchronized (self) {
                    CS_postedMessage *pm = [postedMessages postedMessageForSafeEntryId:safeEntryId];
                    if (pm && [pm.messageId isEqualToString:messageId]) {
                        numPending++;
                    }
                }
            }
        }
    }
    return numPending;
 
}

/*
 *  When a message is deleted, the feed collector can update its internal databases
 *  to accommodate the change.
 */
-(void) updateFeedsForDeletedMessage:(NSString *) messageId
{
    [self updateFeedsForDeletedMessageOrSeal:messageId asMessage:YES];
}

/*
 *  Any friends that are currently being ignored in the given locations should
 *  be no longer ignored.
 */
-(void) restoreFriendsInLocations:(NSArray *) arrLocations
{
    if (![arrLocations count]) {
        return;
    }
    
    NSArray *arrTypes     = [self availableFeedTypes];
    NSMutableArray *maTmp = [NSMutableArray array];
    for (ChatSealFeedType *ft in arrTypes) {
        // - for this type, add all the accounts from the locations that match.
        [maTmp removeAllObjects];
        for (ChatSealFeedLocation *loc in arrLocations) {
            if ([loc.feedType isEqualToString:ft.typeId]) {
                [maTmp addObject:loc.feedAccount];
            }
        }
        
        // - if we found any locations for this type, send them on so the type
        //   can stop ignoring them.
        if ([maTmp count]) {
            [ft restoreFriendsAccountIds:maTmp];
        }
    }
}

/*
 *  The provided locations were received and this is our opportunity to
 *  check them for possible context that can help in message retrieval.
 */
-(void) processReceivedFeedLocations:(NSArray *) arrLocations
{
    if (![arrLocations count]) {
        return;
    }
    
    // - first build arrays for each type.
    NSMutableDictionary *mdMap = [NSMutableDictionary dictionary];
    for (ChatSealFeedLocation *csfl in arrLocations) {
        if (!csfl.customContext) {
            continue;
        }
        
        NSMutableArray *maTypeLocs = [mdMap objectForKey:csfl.feedType];
        if (!maTypeLocs) {
            maTypeLocs = [NSMutableArray array];
            [mdMap setObject:maTypeLocs forKey:csfl.feedType];
        }
        [maTypeLocs addObject:csfl];
    }
    
    // - now process them one at a time
    [mdMap enumerateKeysAndObjectsUsingBlock:^(NSString *feedType, NSMutableArray *maLocs, BOOL *stop) {
        ChatSealFeedType *ft = [self typeForId:feedType];
        if (ft && [ft respondsToSelector:@selector(processReceivedFeedLocations:)]) {
            [ft performSelector:@selector(processReceivedFeedLocations:) withObject:maLocs];
        }
    }];
}
@end


/**********************************
 ChatSealFeedCollector (internal)
 **********************************/
@implementation ChatSealFeedCollector (internal)
/*
 *  Return the feed collection URL but do not create it if it doesn't exist.
 */
+(NSURL *) feedCollectionURLWithoutCreation
{
    NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
    return [u URLByAppendingPathComponent:@"feeds"];
}

/*
 *  Return the URL for the posted message items.
 */
+(NSURL *) feedPostedMessageDBURL
{
    NSURL *u = [ChatSealFeedCollector feedCollectionURL];
    return [u URLByAppendingPathComponent:PSFC_STD_COLL_POSTED];
}

/*
 *  Retrieve the next feed type and begin processing it.
 */
-(void) processNextPendingFeedTypeWithNotification:(BOOL) fireNotification andCompletion:(psfCollectorCompletionBlock) completionBlock
{
    ChatSealFeedType *ft = nil;
    @synchronized (self) {
        if ([maPendingFeedTypes count] == 0) {
            return;
        }
        ft = [[[maPendingFeedTypes lastObject] retain] autorelease];
        [maPendingFeedTypes removeObject:ft];
    }

    [ft refreshAuthorizationWithCompletion:^(void) {
        // - the first time, the object will not exist in the array.
        BOOL doContinue   = NO;
        NSArray *tmpTypes = nil;
        @synchronized (self) {
            if (![maFeedTypes containsObject:ft]) {
                [maFeedTypes addObject:ft];
            }
            
            // - if there are more pending items, just grab the next one, otherwise
            //   we can be done.
            if ([maPendingFeedTypes count]) {
                doContinue = YES;
            }
            else {
                [maPendingFeedTypes release];
                maPendingFeedTypes = nil;
                
                // - save off the types so that we can update their feeds outside the
                //   lock.
                tmpTypes = [NSArray arrayWithArray:maFeedTypes];

                // - we're done.
                [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
                    if ([self isOpen] && completionBlock) {
                        completionBlock(self, YES, nil);
                    }
                    if (fireNotification) {
                        [[NSNotificationCenter defaultCenter] postNotificationName:kChatSealNotifyFeedTypesUpdated object:nil];
                    }
                    
                    // - if we've not refreshed the feeds' content yet, do that now, which will give us a very quick
                    //   initial refresh during app startup.
                    @synchronized (self) {
                        hasBeenQueriedAtLeastOnce = YES;
                        if (!hasBeenRefreshedAtLeastOnce) {
                            [self refreshActiveFeedsAndAdvancePendingOperationsWithError:nil];
                        }
                    }
                }];
            }
        }
        
        // - update each of the feeds so that they allow access temporarily
        //   in an effort to allow them to correct invalid password failures.
        for (ChatSealFeedType *existingType in tmpTypes) {
            NSArray *arrFeeds = [existingType feeds];
            for (ChatSealFeed *oneFeed in arrFeeds) {
                [oneFeed setPermitTemporaryAccessWithExpiredPassword];
            }
        }
 
        // - if there are more to process, do so now, but outside the lock so that we're
        //   clearly not holding it when we again jump into the type.
        if (doContinue) {
            [self processNextPendingFeedTypeWithNotification:fireNotification andCompletion:completionBlock];
        }
    }];
}

/*
 *  Coordinate with the feed types to get the active collector.
 */
-(ChatSealFeedCollector *) collectorForFeedType:(ChatSealFeedType *) ft
{
    // - retain this reference in the autorelease pool so that outstanding requests remain valid.
    return [[self retain] autorelease];
}

/*
 *  Return the filename for the feed collection configuration.
 */
+(NSURL *) feedCollectionConfigurationFile
{
    NSURL *u = [ChatSealFeedCollector feedCollectionURL];
    return [u URLByAppendingPathComponent:PSFC_STD_COLL_CONFIG];
}

/*
 *  Load the existing collector content from disk.
 *  - ASSUMES the lock is held.
 */
-(BOOL) loadCollectorDataWithError:(NSError **) err
{
    if (mdCollectorData) {
        [CS_error fillError:err withCode:CSErrorAborted andFailureReason:@"Invalid collector request."];
        return NO;
    }

    NSDictionary *dictLoaded = nil;
    
    // - when there is no vault, there is no way to save the content.
    if ([ChatSeal hasVault]) {
        NSURL *uFile = [ChatSealFeedCollector feedCollectionConfigurationFile];
        if ([[NSFileManager defaultManager] fileExistsAtPath:[uFile path]]) {
            dictLoaded = [CS_feedCollectorUtil secureLoadConfigurationFromFile:uFile withError:err];
            if (!dictLoaded) {
                return NO;
            }
        }
        
    }

    mdCollectorData = [[NSMutableDictionary alloc] initWithDictionary:dictLoaded ? dictLoaded : [NSDictionary dictionary]];
    return YES;
}

/*
 *  Save the collector data to disk.
 *  - ASSUMES the lock is held.
 */
-(BOOL) saveCollectorDataWithError:(NSError **) err
{
    if (!mdCollectorData) {
        [CS_error fillError:err withCode:CSErrorAborted andFailureReason:@"Invalid collector request."];
        return NO;
    }
    
    // - we cannot save anything until a vault exists.
    if (![ChatSeal hasVault]) {
        return YES;
    }
    
    NSURL *uFile = [ChatSealFeedCollector feedCollectionConfigurationFile];
    return [CS_feedCollectorUtil secureSaveConfiguration:mdCollectorData asFile:uFile withError:err];
}

/*
 *  Check whether the collector is currently open and can be used.
 *  - ASSUMES the lock is held.
 */
-(BOOL) checkOpenWithCompletion:(psfCollectorCompletionBlock) completionBlock
{
    if (!isOpen) {
        if (completionBlock) {
            NSError *err = nil;
            [CS_error fillError:&err withCode:CSErrorInvalidArgument];
            completionBlock(self, NO, err);
        }
        return NO;
    }
    return YES;
}

/*
 *  Requery the feed permissions and optionally fire a notification when that has been completed.
 */
-(void) requeryFeedPermissionsWithNotification:(BOOL) fireNotification andCompletion:(psfCollectorCompletionBlock) completionBlock
{
    @synchronized (self) {
        if (![self checkOpenWithCompletion:completionBlock]) {
            return;
        }
        
        if (maPendingFeedTypes) {
            if (completionBlock) {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
                    NSError *err = nil;
                    [CS_error fillError:&err withCode:CSErrorOperationPending];
                    completionBlock(self, NO, err);
                }];
            }
            return;
        }
        
        // - move all the active account types over as pending until they are verified.
        if ([maFeedTypes count]) {
            maPendingFeedTypes = [[NSMutableArray alloc] initWithArray:maFeedTypes];
        }
    }
    
    // - re-query each of the feed types
    [self processNextPendingFeedTypeWithNotification:fireNotification andCompletion:completionBlock];
}

/*
 *  Update the feeds so that they no longer track the given message and/or seal.
 */
-(void) updateFeedsForDeletedMessageOrSeal:(NSString *) itemId asMessage:(BOOL) isMessage
{
    // - keep the critical section small and don't call into the sub-types.
    NSArray *arrEntries  = nil;
    NSArray *arrTmpTypes = nil;
    BOOL    isPostponed  = NO;
    @synchronized (self) {
        if (!isOpen) {
            return;
        }
        
        // - get the right list of entries from the posted message database.
        if (isMessage) {
            arrEntries = [postedMessages prepareSafeEntriesForMessageDeletion:itemId];
        }
        else {
            arrEntries = [postedMessages prepareSafeEntriesForSealInvalidation:itemId andReturningPostponed:&isPostponed];
        }
        
        arrTmpTypes = [NSArray arrayWithArray:maFeedTypes];
    }
    
    // - update each feed separately so that it can keep its own database in order.
    BOOL forceFeedRefresh = NO;
    for (ChatSealFeedType *ft in arrTmpTypes) {
        // - notify the type that seal content has been changed.
        if ([ft respondsToSelector:@selector(vaultSealStateHasBeenUpdated)]) {
            [ft performSelector:@selector(vaultSealStateHasBeenUpdated)];
        }
        
        // - nothing to do.
        if (![arrEntries count]) {
            continue;
        }
        
        // - then deal with each feed.
        NSArray *arr = [ft feeds];
        for (ChatSealFeed *feed in arr) {
            if (isMessage || !isPostponed) {
                [feed deleteStateForSafeEntries:arrEntries];
                
                // - once we delete the remaining pending content for the feed, if it has no identity
                //   then we probably should force a feed refresh to ensure it gets deleted.
                if (![feed isBackingIdentityAvailable] &&
                    ![feed hasRequiredPendingActivity]) {
                    forceFeedRefresh = YES;
                }
            }
            else {
                [feed moveSafeEntriesToPostponed:arrEntries];
            }
        }
    }
    
    // - when we've just deleted content in the feed and it has nothing remaining, we will
    //   discard it.
    if (forceFeedRefresh) {
        [self requeryFeedPermissionsWithCompletion:nil];
    }
}

/*
 *  A seal has been invalidated, so we need to ensure that the collector is updated to ignore the
 *  seal during its activities.
 */
-(void) notifySealInvalidated:(NSNotification *) notification
{
    NSArray *arr = [notification.userInfo objectForKey:kChatSealNotifySealArrayKey];
    for (NSString *sealId in arr) {
        [self updateFeedsForDeletedMessageOrSeal:sealId asMessage:NO];
    }
}

/*
 *  A seal was just imported so we need to make sure that we move its entries from postponed over to pending
 *  so they can start transferring again.
 *  - both a renewal of an existing seal (that may have expired) or a seal that was deleted and reimported must be
 *    processed here so that we start up anything that didn't complete before.
 */
-(void) notifySealImported:(NSNotification *)notification
{
    // - keep the critical section small and don't call into the sub-types.
    NSArray *arrEntries  = nil;
    NSArray *arrTmpTypes = nil;
    @synchronized (self) {
        if (!isOpen) {
            return;
        }
        
        // - first find all the entries for the given seal.
        NSArray *arr            = [notification.userInfo objectForKey:kChatSealNotifySealArrayKey];
        NSMutableSet *msEntries = [NSMutableSet set];
        for (NSString *sealId in arr) {
            NSArray *arrTmp = [postedMessages safeEntriesForSealId:sealId];
            if ([arrTmp count]) {
                [msEntries addObjectsFromArray:arrTmp];
            }
        }
        
        arrEntries = [msEntries allObjects];
        arrTmpTypes = [NSArray arrayWithArray:maFeedTypes];
    }
    
    // - now move those items back into pending from postponed.
    for (ChatSealFeedType *ft in arrTmpTypes) {
        // - notify the type that seal content has been changed.
        if ([ft respondsToSelector:@selector(vaultSealStateHasBeenUpdated)]) {
            [ft performSelector:@selector(vaultSealStateHasBeenUpdated)];
        }
        
        // - nothing to do.
        if (![arrEntries count]) {
            continue;
        }
        
        // - and then deal with each feed.
        NSArray *arrFeeds = [ft feeds];
        for (ChatSealFeed *feed in arrFeeds) {
            [feed movePostponedSafeEntriesToPending:arrEntries];
        }
    }
}

/*
 *  A seal has been created.
 */
-(void) notifySealCreated:(NSNotification *)notification
{
    for (ChatSealFeedType *ft in [self availableFeedTypes]) {
        if ([ft respondsToSelector:@selector(vaultSealStateHasBeenUpdated)]) {
            [ft performSelector:@selector(vaultSealStateHasBeenUpdated)];
        }
    }
}

/*
 *  The collector's timer was fired so we can do some of the regular processing that needs to occur.
 */
-(void) timerFired
{
    // - it shouldn't be the case that we're in the collector when there is no vault, but races have caused
    //   that to occur in the past.  In order to avoid senseless processing, we'll check for vault access before
    //   doing anything with the feeds.
    if (![ChatSeal isVaultOpen]) {
        return;
    }
    
    BOOL requiresRefresh  = NO;
    BOOL requiredHighPrio = NO;
    @synchronized (self) {
        if (isOpen && [maPendingFeedTypes count] == 0) {
            // - now see if we should refresh the feeds, which happens periodically
            if (!inRefresh && !inHighPriorityProcessing) {
                if (needsHighPriorityUpdate || -[dtLastHighPrio timeIntervalSinceNow] > PSFC_STD_HIGHPRIO_DELAY) {
                    requiredHighPrio = YES;
                }
                else {
                    NSDate *dtLastRefresh = [self dateOfLastRefresh];
                    if (!hasBeenRefreshedAtLeastOnce || (!dtLastRefresh || -[dtLastRefresh timeIntervalSinceNow] > PSFC_STD_REFRESH_DELAY)) {
                        requiresRefresh = YES;
                    }
                }
            }
        }
    }
    
    // - if a refresh should happen, do it now 
    if (requiredHighPrio) {
        [self scheduleHighPriorityUpdateIfPossible];
    }
    else if (requiresRefresh) {
        [self refreshActiveFeedsAndAdvancePendingOperationsWithError:nil];
    }
}

/*
 *  Using the supplied types, refresh the associated feeds using the operation queue.
 */
-(void) refreshActiveFeedsInTypes:(NSArray *) arrToRefresh withHighPriorityRestriction:(BOOL) onlyHighPrio andCompletion:(void(^)(void)) completionBlock
{
    // - pull the feeds outside the lock because that requires a call into each type
    NSMutableDictionary *mdTypes = [NSMutableDictionary dictionary];
    NSMutableArray *maFeeds      = [NSMutableArray array];
    for (ChatSealFeedType<CS_sharedChatSealFeedTypeImplementation> *ft in arrToRefresh) {
        // - the type id will be useful in a moment.
        NSString *feedType    = [ft typeId];
        
        // - figure out which feeds require processing.
        for (ChatSealFeed *feed in [ft feeds]) {
            // - this is easy.  If it is disabled or not authorized, do nothing at all.
            if (!feed.isEnabled || !feed.isAuthorized) {
                continue;
            }
            
            // - the decision whether to focus on high priority work includes the reachability flag because
            //   these checks occur frequently and we don't want to be constantly trying to use the feeds
            //   when the network is offline.
            if (onlyHighPrio && (![ft areFeedsNetworkReachable] || (![feed hasHighPriorityWorkToPerform] && ![ft hasHighPriorityWorkToPerform]))) {
                continue;
            }
            
            // - if the feed can do work, then let's get started.
            [maFeeds addObject:feed];
            
            // - we only save types for feeds that can be used because otherwise the types cannot
            //   offload processing.
            if (![mdTypes objectForKey:feedType]) {
                if ([ft isAuthorized] && [ft respondsToSelector:@selector(processFeedTypeRequestsInThrottleCategory:usingFeed:)] &&
                    (!onlyHighPrio || ([ft respondsToSelector:@selector(hasHighPriorityWorkToPerform)] && [ft hasHighPriorityWorkToPerform]))) {
                    [mdTypes setObject:ft forKey:feedType];
                }
            }
        }
    }
    
    // - no feeds, then abort
    if (![maFeeds count]) {
        if (completionBlock) {
            completionBlock();
        }
        [self checkForDormantState];
        return;
    }
    
    // - this works because of the expectations outlined in the header that every object
    //   manage its own locking.
    [opqCollector addOperationWithBlock:^(void) {
        // - open up the current thread for API access.
        [ChatSealFeed openFeedAccessGateToAPIsToCurrentThread];
        
        
        // - the idea here is to work through the different categories of
        //   network activity and allow the longest-waiting feeds a chance
        //   to update now.
        for (cs_cnt_throttle_category_t cat = (cs_cnt_throttle_category_t) 0; [maFeeds count] && cat < CS_CNT_THROTTLE_COUNT; cat++) {
#ifdef CHATSEAL_DEBUG_DONT_POST_MESSAGES
            if (cat == CS_CNT_THROTTLE_UPLOAD) {
                continue;
            }
#endif
            
            // - first make a temporary copy of the feed types so that we can modify them.
            NSMutableDictionary *mdThrottleTypes = nil;
            if ([ChatSealFeedType isThrottleCategorySupportedForProcessing:cat]) {
                mdThrottleTypes = [NSMutableDictionary dictionaryWithDictionary:mdTypes];
            }
            
            // - sort the pending array to ensure fairness.
            if (cat == CS_CNT_THROTTLE_REALTIME) {
                // - realtime feeds need to be sorted according to how much they've received in the past so
                //   that we allocate streams where they'll do the most good, since we have a limited capacity.
                [self sortFeedsForRealtimeProcessing:maFeeds];
            }
            else {
                [self sortFeeds:maFeeds forProcessingInCategory:cat];
            }
            
            // - adjust the central throttle to only allow requests through this category to
            //   catch throttling errors
            @synchronized (self) {
                [mdCollectorData setObject:[NSNumber numberWithUnsignedInteger:[maFeeds count]] forKey:PSFC_STD_UPDATE_FEEDS_KEY];
                [self saveCollectorDataWithError:nil];
                [cntNetThrottle setActiveThrottleCategory:cat];
            }
            
            // - now iterate over the array, allowing each item to perform its required activites until one gets throttled in
            //   this category.
            for (ChatSealFeed *feed in maFeeds) {
                //  ...we don't use a feed that is disabled
                if (![feed isEnabled]) {
                    continue;
                }
                
                // ...or one that isn't reachable.
                if (![[feed feedType] areFeedsNetworkReachable]) {
                    continue;
                }
                
                // ...a feed that is internally throttled is going to be ignored for the most part, unless we're giving
                //    it one shot to make a connection.
                if ([feed isFeedServiceThrottledInCategory:cat]) {
                    if ([feed isPasswordValid] ||
                        (cat != CS_CNT_THROTTLE_TRANSIENT && cat != CS_CNT_THROTTLE_REALTIME) ||
                        ![feed shouldPermitServiceWithExpiredPassword]) {
                        continue;
                    }
                }
                
                // - see if we have a type that requires processing and let it use the feed temporarily
                if ([mdThrottleTypes count]) {
                    NSString *tid                                                   = feed.typeId;
                    ChatSealFeedType<CS_sharedChatSealFeedTypeImplementation> *csft = [mdThrottleTypes objectForKey:tid];
                    if (csft) {
                        if ([csft processFeedTypeRequestsInThrottleCategory:cat usingFeed:feed]) {
                            [mdThrottleTypes removeObjectForKey:tid];
                        }
                    }
                }
                
                // - check validity before and after because we aren't holding a big lock over the collector.
                // - I'm not sure that it makes sense to use the throttle return flag for anything in particular because
                //   one feed's throttling is really not necessarily related to another unless it is done by the central
                //   throttle.
                [feed processFeedRequestsInThrottleCategory:cat onlyAsHighPriority:onlyHighPrio];
                
                // - if the feed had content to save, do so now after it has completed its tasks.
                NSError *err = nil;
                if (![feed saveIfDeferredWorkIsPendingWithError:&err]) {
                    NSLog(@"CS: Failed to save feed state.  %@", [err localizedDescription]);
                }
                
                // - update the last refresh on the type
                [[feed feedType] updateLastRefresh];
            }
        }
        
        // - close the gate again
        [ChatSealFeed closeFeedAccessGateToAPIsToCurrentThread];
        
        if (completionBlock) {
            completionBlock();
        }
        
        // - check if we're now dormant.
        [self checkForDormantState];
    }];
}

/*
 *  Begin high-priority processing work.
 */
-(void) performHighPriorityProcessingIfNecessary
{
    // - we cannot do anything without a vault.
    if (![ChatSeal hasVault]) {
        return;
    }
    
    NSArray *aTmpTypes = nil;
    @synchronized (self) {
        if (!isOpen || !needsHighPriorityUpdate || inRefresh) {
            return;
        }
        
        // - should not happen, but we need to be very sure here to avoid
        //   going nuts scheduling in the operation queue.
        if (inHighPriorityProcessing) {
            return;
        }
        
        [dtLastHighPrio release];
        dtLastHighPrio           = [[NSDate date] retain];
        
        needsHighPriorityUpdate  = NO;
        inHighPriorityProcessing = YES;
        
        aTmpTypes = [NSArray arrayWithArray:maFeedTypes];
    }
    
    // - schedule the refresh with only high-priority feeds.
    [self refreshActiveFeedsInTypes:aTmpTypes withHighPriorityRestriction:YES andCompletion:^(void) {
        @synchronized (self) {
            // - the last thing is to get the sessions moving forward if possible.
            for (ps_sm_session_quality_t qual = 0; qual < CS_SMSQ_COUNT; qual++) {
                if (smManagers[qual]) {
                    [smManagers[qual] processHighPriorityItems];
                }
            }
            
            // - make sure that we can trigger another one of these and then update the session managers.
            inHighPriorityProcessing = NO;
        }
    }];
}

/*
 *  The last refresh date is important because it drives how soon we'll begin a new full refresh cycle
 *  for the feeds.
 *  - ASSUMES the lock is held.
 */
-(NSDate *) dateOfLastRefresh
{
    // - we're using the types as an indicator for the last refresh and omitting that, the content in
    //   the configuration.
    NSDate *dtRet = nil;
    for (ChatSealFeedType *ft in maFeedTypes) {
        NSDate *dtTmp = [ft lastRefresh];
        if (!dtRet || (dtTmp && [dtRet compare:dtTmp] == NSOrderedDescending)) {
            dtRet = dtTmp;
        }
    }
    
    // - the fallback is the last refresh in the collector, which may be used right after startup.
    if (!dtRet) {
        dtRet = [[[mdCollectorData objectForKey:PSFC_STD_UPDATE_KEY] retain] autorelease];
    }
    return dtRet;
}

/*
 *  The standard sort order is in ascending order for date of last refresh.
 */
-(void) sortFeeds:(NSMutableArray *) maFeeds forProcessingInCategory:(cs_cnt_throttle_category_t) cat
{
    [maFeeds sortUsingComparator:^NSComparisonResult(ChatSealFeed *f1, ChatSealFeed *f2) {
        NSDate *d1 = [f1 lastRequestDateForCategory:cat];
        NSDate *d2 = [f2 lastRequestDateForCategory:cat];
        if (d1 && d2) {
            return [d1 compare:d2];
        }
        else if (d1) {
            return NSOrderedAscending;
        }
        else{
            return NSOrderedDescending;
        }
    }];
}

/*
 *  Realtime feeds are sorted according to popularity because we want to
 *  favor the ones that will do us the most good.
 */
-(void) sortFeedsForRealtimeProcessing:(NSMutableArray *) maFeeds
{
    [maFeeds sortUsingComparator:^NSComparisonResult(ChatSealFeed *f1, ChatSealFeed *f2) {
        // - primarily, we want to focus on feeds that have received content in the past so
        //   that we always allocate realtime streams from those popular sources.
        NSUInteger f1Val = f1.numberOfMessagesReceived;
        NSUInteger f2Val = f2.numberOfMessagesReceived;
        
        // - if we haven't received anything yet, use the overall processed count as an indicator
        //   because that may suggest where content will arrive.
        if (!f1Val && !f2Val) {
            f1Val = f1.numberOfMessagesProcessed;
            f2Val = f2.numberOfMessagesProcessed;
        }
        
        if (f1Val < f2Val) {
            return NSOrderedDescending;
        }
        else if (f1Val > f2Val) {
            return NSOrderedAscending;
        }
        else {
            return NSOrderedSame;
        }
    }];
}

/*
 *  When the collector is running, we periodically will check for it to go dormant so that we can detemrine when to 
 *  signal the delegate.
 */
-(void) checkForDormantState
{
    // - when there is any refresh happening or there are still active requests being processed,
    //   we are not dormant.
    NSUInteger importCount = 0;
    @synchronized (self) {
        // - can't be dormant when we're doing refresh or high-priority work.
        if (inRefresh || inHighPriorityProcessing) {
            return;
        }
        
        // - are their requests in the queue?
        for (ps_sm_session_quality_t desiredQuality = 0; desiredQuality < CS_SMSQ_COUNT; desiredQuality++) {
            // - realtime streams never go dormant.
            if (desiredQuality == CS_SMSQ_REALTIME_HIGH_VOLUME) {
                continue;
            }
            
            // - if there is anything pending in the session manager, it isn't time yet.
            if ([smManagers[desiredQuality] hasPendingRequests]) {
                return;
            }
        }
        
        // - save off the number of messages imported during this refresh cycle.
        importCount                 = numImportedSinceLastDormant;
        numImportedSinceLastDormant = 0;
    }
    
    // - if we got this far, everything went dormant.   Now is the time to update the interested parties.
    [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kChatSealNotifyFeedCollectionDormant object:self userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInteger:importCount] forKey:KChatSealNotifyFeedCollectionDormantMessagesKey]];
    }];
}
@end

/**********************************
 ChatSealFeedCollector (shared)
 **********************************/
@implementation ChatSealFeedCollector (shared)

/*
 *  Let any interested parties know that the feed was updated.
 */
+(void) issueUpdateNotificationForFeed:(ChatSealFeed *) feed
{
    NSDictionary *dictUser = [NSDictionary dictionaryWithObject:feed forKey:kChatSealNotifyFeedUpdateFeedKey];
    if ([[NSThread currentThread] isEqual:[NSThread mainThread]]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kChatSealNotifyFeedUpdate object:nil userInfo:dictUser];
    }
    else {
        // - make sure this always gets posted with the main thread since the UI is often the recipient.
        [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kChatSealNotifyFeedUpdate object:nil userInfo:dictUser];
        }];
    }
}

/*
 *  Return the common account store that is used for all system-account-related operations.
 */
-(ACAccountStore *) accountStore
{
    @synchronized (self) {
        if (!asFeedAccounts) {
            asFeedAccounts = [[ACAccountStore alloc] init];
        }
        return [[asFeedAccounts retain] autorelease];
    }
}


/*
 *  Return a reference to the central throttle for the collector.
 */
-(CS_centralNetworkThrottle *) centralThrottle
{
    @synchronized (self) {
        return [[cntNetThrottle retain] autorelease];
    }
}

/*
 *  This method is used to start processing a new API inside the collector.
 */
-(BOOL) addRequestAPI:(CS_netFeedAPI *) api forFeed:(ChatSealFeed<ChatSealFeedImplementation> *) feed inCategory:(cs_cnt_throttle_category_t) category
                               andReturnWasThrottled:(BOOL *) wasThrottled withError:(NSError **) err
{
    if (!api || !feed) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        if (wasThrottled) {
            *wasThrottled = NO;
        }
        return NO;
    }
    
    CS_sessionManager *smTarget = nil;
    @synchronized (self) {
        if (!isOpen) {
            [CS_error fillError:err withCode:CSErrorFeedCollectionNotOpen];
            if (wasThrottled) {
                *wasThrottled = NO;
            }
            return NO;
        }
        
        ps_sm_session_quality_t desiredQuality = CS_SMSQ_LOW_VOLUME;
        switch (category) {
            case CS_CNT_THROTTLE_DOWNLOAD:
                desiredQuality = CS_SMSQ_PERSISTENT;
                break;
                
            case CS_CNT_THROTTLE_UPLOAD:
                desiredQuality = CS_SMSQ_PERSISTENT;
                break;
                
            case CS_CNT_THROTTLE_REALTIME:
                desiredQuality = CS_SMSQ_REALTIME_HIGH_VOLUME;
                break;
                
            case CS_CNT_THROTTLE_TRANSIENT:
                desiredQuality = CS_SMSQ_LOW_VOLUME;
                break;
                
            default:
                [CS_error fillError:err withCode:CSErrorInvalidArgument];
                return NO;
                break;
        }
        
        smTarget = [[smManagers[desiredQuality] retain] autorelease];
    }
        
    // - the throttling actually occurs inside the session manager because it has to get the URL request anyway and that is a good time
    //   to attempt the central throttling for it.
    return [smTarget addRequest:[CS_netFeedAPIRequest requestForFeed:feed andAPI:api] inCategory:category usingThrottle:cntNetThrottle
          returningWasThrottled:wasThrottled withError:err];
}

/*
 *  Save a new entry to the central database.
 */
-(NSString *) saveAndReturnPostedSafeEntry:(ChatSealMessageEntry *) entry withError:(NSError **) err
{
    @synchronized (self) {
        if (!postedMessages) {
            return nil;
        }
        
        CS_postedMessage *pm = [postedMessages addPostedMessageForEntry:entry withError:err];
        if (!pm) {
            return nil;
        }
        return pm.safeEntryId;
    }
}

/*
 *  Do a lookup on the message database for a given entry.
 */
-(CS_postedMessage *) postedMessageForSafeEntry:(NSString *) safeEntryId
{
    @synchronized (self) {
        NSError *err            = nil;
        if (!postedMessages) {
            if (![ChatSeal isLowStorageAConcern]) {
                NSLog(@"CS: Failed to load the posted message database.  %@ (%@).", [err localizedDescription], [err localizedFailureReason]);                
            }
            return nil;
        }
        return [postedMessages postedMessageForSafeEntryId:safeEntryId];
    }
}

/*
 *  Given an array of posted message progress objects, fill out their content based on the database.
 */
-(void) fillPostedMessageProgressItems:(NSArray *) arr
{
    @synchronized (self) {
        if (!postedMessages) {
            return;
        }
        [postedMessages fillPostedMessageProgressItems:arr];
    }
}

/*
 *  Fill a single posted message progress item.
 */
-(void) fillPostedMessageProgressItem:(ChatSealPostedMessageProgress *) prog
{
    @synchronized (self) {
        if (!postedMessages) {
            return;
        }
        CS_postedMessage *pm = [postedMessages postedMessageForSafeEntryId:prog.safeEntryId];
        if (pm) {
            [prog setMessageId:pm.messageId andEntryId:pm.entryId];
        }
    }
}

/*
 *  High priority updates are intended to only begin under very specific circumstances where we must perform
 *  work that shouldn't wait until the next official refresh cycle.
 */
-(void) scheduleHighPriorityUpdateIfPossible
{
    BOOL scheduleNow = NO;
    @synchronized (self) {
        if (!isOpen) {
            return;
        }
        
        needsHighPriorityUpdate = YES;
        if (!inRefresh && !inHighPriorityProcessing) {
            scheduleNow = YES;
        }
    }
    
    // - if there is nothing else going on, then begin the high priority update.
    if (scheduleNow) {
        [self performHighPriorityProcessingIfNecessary];
    }
}

/*
 *  For each of the session
 */
-(void) cancelAllRequestsForFeed:(ChatSealFeed *) feed
{
    @synchronized (self) {
        if (!feed || !isOpen) {
            return;
        }
        for (ps_sm_session_quality_t qual = 0; qual < CS_SMSQ_COUNT; qual++) {
            if (!smManagers[qual]) {
                continue;
            }
            [smManagers[qual] cancelAllRequestsForFeed:feed];
        }
    }
}

/*
 *  A new message was imported by a feed in the collector.
 */
-(void) trackMessageImportEvent
{
    @synchronized (self) {
        numImportedSinceLastDormant++;
    }
}
@end

/******************************
 ChatSeallFeedCollector (session)
 ******************************/
@implementation ChatSealFeedCollector (session)
/*
 *  An outstanding request has completed so make sure the central throttle is updated with the information.
 */
-(void) sessionManager:(CS_sessionManager *)sessionManager didCompleteThrottledRequestForURL:(NSURL *)url inCategory:(cs_cnt_throttle_category_t)cat
{
    @synchronized (self) {
        [cntNetThrottle completePendingURLRequest:url inCategory:cat];
    }
    
    // - when we complete any request, attempt to schedule additional high-priority items as needed.
    [self scheduleHighPriorityUpdateIfPossible];
    
    // - and check if we're now dormant.
    [self checkForDormantState];
}

/*
 *  When a session manager has no record of a task, which can occur during startup, the collector has to track down the owning feed.
 */
-(CS_netFeedAPIRequest *) sessionManager:(CS_sessionManager *)sessionManager needsRequestForExistingTask:(NSURLSessionTask *)task
{
    NSMutableArray *arrComplete = [NSMutableArray array];
    @synchronized (self) {
        // - I'm going to check both existing and pending items because at this point, authorization is not important, we
        //   need to track down the owner.
        [arrComplete addObjectsFromArray:maFeedTypes];
        [arrComplete addObjectsFromArray:maPendingFeedTypes];
    }
    
    for (ChatSealFeedType *ft in arrComplete) {
        CS_netFeedAPIRequest *ret = [ft canGenerateAPIRequestFromRequest:task.originalRequest];
        if (ret) {
            return ret;
        }
    }
    return nil;
}

/*
 *  When the persistent session starts up, it has to reload all its pending URLs first so that we can update the central throttle.
 */
-(void) sessionManager:(CS_sessionManager *)sessionManager didReloadUploadURLs:(NSArray *) arrUploadURLs andDownloadURLs:(NSArray *) arrDownloadURLs
{
    @synchronized (self) {
        // - only the persistent session manager will have knowledge of pending download/upload activity
        if (sessionManager == smManagers[CS_SMSQ_PERSISTENT]) {
            [cntNetThrottle assignInitialStatePendingUploadURLs:arrUploadURLs];
            [cntNetThrottle assignInitialStatePendingDownloadURLs:arrDownloadURLs];
        }
        else {
            NSLog(@"CS-ALERT: Unexpected collector startup configuration request.");
        }
    }
}

/*
 *  When the session manager issues this method, we should try to schedule a round of
 *  high priority updates that will eventually force its pending queue to be addressed.
 */
-(void) sessionManagerRequestsHighPriorityUpdates:(CS_sessionManager *)sessionManager
{
    [self scheduleHighPriorityUpdateIfPossible];
}
@end
