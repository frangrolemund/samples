//
//  ChatSealFeed.m
//  ChatSeal
//
//  Created by Francis Grolemund on 3/24/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "ChatSeal.h"
#import "ChatSealFeed.h"
#import "ChatSealFeedType.h"
#import "ChatSealFeedCollector.h"
#import "CS_netThrottledAPIFactory.h"
#import "CS_feedShared.h"
#import "CS_postedMessageState.h"
#import "ChatSealMessage.h"
#import "CS_sha.h"

//  THREADING-NOTES:
//  - internal locking is provided.

// - constants
static NSString *PSF_FEED_CONFIG       = @"config";
static NSString *PSF_FEED_STATS        = @"stats";
static NSString *PSF_STD_ID_KEY        = @"feedId";
static NSString *PSF_STD_TYPE_KEY      = @"feedType";
static NSString *PSF_STD_ENABLED_KEY   = @"enabled";
static NSString *PSF_STD_USERID_KEY    = @"userId";
static NSString *PSF_STD_PWDEXP_KEY    = @"pwdExpired";
static NSString *PSF_STD_CUSCFG_KEY    = @"customCfg";
static NSString *PSF_STD_WORK_KEY      = @"workEntries";
static NSString *PSF_STD_TERM_KEY      = @"termEntries";
static NSString *PSF_STD_NOIDENT_KEY   = @"noBackingIdent";
static NSString *PSF_STD_NUM_POSTED    = @"numPosted;";
static NSString *PSF_STD_NUM_RECVD     = @"numReceived;";
static int64_t   PSF_STD_COMPLETE_STAT = -1;
static NSString *PSF_STD_GATE_KEY      = @"psG";
static NSString *PSF_STD_POST_HIST_KEY = @"postedHist";
static NSString *PSF_STD_SEND_FEED_KEY = @"sendFeed";

// - forward declarations
@interface ChatSealFeed (internal)
+(BOOL) saveFeedConfiguration:(NSDictionary *) dict intoDirectory:(NSURL *) uDirectory withError:(NSError **) err;
+(NSDictionary *) loadFeedConfigurationFromDirectory:(NSURL *) uDirectory withError:(NSError **) err;
-(void) replaceDataWithData:(NSDictionary *) dAlternateData;
-(BOOL) verifyStatsAreValidWithError:(NSError **) err;
-(id<ChatSealFeedDelegate>) delegate;
-(BOOL) addNewPendingSafeEntry:(NSString *) safeEntryId withMsgDescription:(NSString *) msgDesc andError:(NSError **) err;
-(NSArray *) deleteStateForSafeEntries:(NSArray *) arrEntries inSubArrayKey:(NSString *) key;
-(BOOL) moveSafeEntry:(NSString *) safeEntryId toState:(cs_postedmessage_state_t) newState;
-(void) moveAllMatchingSafeEntries:(NSArray *) arrEntries toState:(cs_postedmessage_state_t) newState;
-(BOOL) verifyUpToDateProgress;
-(void) recomputeProgressWithNotification:(BOOL) doNotify;
-(void) setUploadStatsForSafeEntry:(NSString *) safeEntryId withNumSent:(int64_t) numSent andTotalToSend:(int64_t) toSend;
-(void) notifyObserversOfPostedMesageProgress:(ChatSealPostedMessageProgress *) pmp;
-(CS_netFeedAPI *) apiForName:(NSString *) name withEvenDistribution:(BOOL) evenlyDistributed andReturnWasThrottled:(BOOL *) wasThrottled withError:(NSError **) err;
@end

/*********************
 ChatSealFeed
 *********************/
@implementation ChatSealFeed
/*
 *  Object attributes
 */
{
    NSString                    *sFeedFileName;
    NSMutableDictionary         *mdFeedData;
    CS_netThrottledAPIFactory   *apiFactory;
    id<ChatSealFeedDelegate>    delegate;
    BOOL                        isValid;
    BOOL                        allowTemporaryAccess;
    NSMutableDictionary         *mdUploadStats;
    NSMutableDictionary         *mdDownloadStats;
    ChatSealFeedProgress        *currentProgress;
    NSUInteger                  completedUploads;
    NSUInteger                  completedDownloads;
    BOOL                        isPostingEnabled;
    BOOL                        isSaveDeferred;
}


/*
 *  Load the on-disk configurations for the given feed types.
 */
+(NSDictionary *) configurationsForFeedsOfType:(NSString *) feedType withError:(NSError **) err
{
    // - when there is no vault, there can be no existing feeds.
    if (![ChatSeal hasVault]) {
        return [NSDictionary dictionary];
    }
    
    // - if we have a vault, but it isn't open, this is a problem.
    if (![ChatSeal isVaultOpen]) {
        [CS_error fillError:err withCode:CSErrorVaultNotInitialized];
        return nil;
    }
    
    NSMutableDictionary *mdRet = [NSMutableDictionary dictionary];
    NSURL *uFeedDirectory      = [ChatSealFeedCollector feedCollectionURL];
    NSArray *arrPossible       = [ChatSeal sortedDirectoryListForURL:uFeedDirectory withError:nil];
    if (!arrPossible) {
        [CS_error fillError:err withCode:CSErrorFilesystemAccessError andFailureReason:@"Failed to enumerate the on-disk feeds."];
        return nil;
    }
    
    for (NSURL *u in arrPossible) {
        // - not a hash directory name.
        if ([[u lastPathComponent] length] != [RealSecureImage lengthOfSafeSaltedStringAsHex:YES]) {
            continue;
        }
        
        // - a failure to read anything could be serious and we don't want to accidentally overwrite anything.
        NSDictionary *dict = [self loadFeedConfigurationFromDirectory:u withError:err];
        if (!dict) {
            return nil;
        }
        
        NSString *sType = [dict objectForKey:PSF_STD_TYPE_KEY];
        if (sType && [sType isEqualToString:feedType]) {
            [mdRet setObject:dict forKey:[dict objectForKey:PSF_STD_ID_KEY]];
        }
    }
    
    return mdRet;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    if (mdFeedData || apiFactory) {
        // - the delegate relationships are very important and if one of the
        //   other objects wants to use this on a thread other than where it is being
        //   released, we can race for its life.  Make sure you close before releasing
        //   and the right relationships will be maintained.
        NSLog(@"CS-ALERT: Feeds must be closed before deallocation.");
    }
    [self close];
    [super dealloc];
}

/*
 *  In the interest of enforcing absolutely fair access to the available network bandwidth, I'm adding
 *  a hard gate in front of the APIs on any thread that attempts to schedule and is not currently
 *  authorized.  The gate must be opened explicitly for it to allow passage.
 */
+(void) openFeedAccessGateToAPIsToCurrentThread
{
    [[[NSThread currentThread] threadDictionary] setObject:[NSNumber numberWithBool:YES] forKey:PSF_STD_GATE_KEY];
}

/*
 *  Close the access gate.
 */
+(void) closeFeedAccessGateToAPIsToCurrentThread
{
    [[[NSThread currentThread] threadDictionary] removeObjectForKey:PSF_STD_GATE_KEY];
}

/*
 *  When address items are displayed in a list, this is the standard height.
 */
+(CGFloat) standardFontHeightForSelection
{
    // - NOTE: we don't use dynamic type for this because we want to control how the
    //         icon is displayed and it may look bad at smaller sizes.
    return 18.0f;
}

/*
 *  All feeds should use the same naming, regardless of their mining strategy.
 */
+(NSString *) standardMiningFilename
{
    return @"mining";
}

/*
 *  Enable/disable the feed.
 */
-(BOOL) setEnabled:(BOOL) enabled withError:(NSError **) err
{
    BOOL hasChanged = NO;
    @synchronized (self) {
        NSMutableDictionary *mdTmp = [NSMutableDictionary dictionaryWithDictionary:mdFeedData];
        if (enabled != [(NSNumber *) [mdFeedData objectForKey:PSF_STD_ENABLED_KEY] boolValue]) {
            hasChanged = YES;
        }
        [mdFeedData setObject:[NSNumber numberWithBool:enabled] forKey:PSF_STD_ENABLED_KEY];
        if (![self saveConfigurationWithError:err]) {
            [self replaceDataWithData:mdTmp];
            return NO;
        }
    }
    
    if (hasChanged) {
        [self notifyMajorFeedUpdateHasOccurredAndShouldUpdateBadge:YES];
        
        // - if we just enabled the feed, we're going to try to start up any high priority items right now.
        if (enabled) {
            [self requestHighPriorityAttention];
        }
        else {
            // - otherwise, make sure everything that is running is cancelled.
            [[self collector] cancelAllRequestsForFeed:self];
        }
    }
    
    return YES;
}

/*
 *  Return whether the feed is currently enabled.
 */
-(BOOL) isEnabled
{
    @synchronized (self) {
        if (![self isBackingIdentityAvailable]) {
            return NO;
        }
        
        NSNumber *nExisting = [mdFeedData objectForKey:PSF_STD_ENABLED_KEY];
        if (nExisting && [nExisting boolValue]) {
            return YES;
        }
    }
    return NO;
}

/*
 *  Retrieve the currently-assigned user id for the feed.
 */
-(NSString *) userId
{
    @synchronized (self) {
        return [mdFeedData objectForKey:PSF_STD_USERID_KEY];
    }
}

/*
 *  Return a unique object that describes the Internet location of this feed in 
 *  a way that the feed can identify it later.
 *  - the seal id may or may not be provided and is potentially useful for generating
 *    a seal-specific context for the location.
 */
-(ChatSealFeedLocation *) locationWhenUsingSeal:(NSString *)sid
{
    NSLog(@"CS-ALERT: Override the location method in the feed.");
    return nil;
}

/*
 *  Return the authorization state of the feed.
 */
-(BOOL) isAuthorized
{
    return [[self typeForFeed:self] isAuthorized];
}

/*
 *  Return my owning collector.
 */
-(ChatSealFeedCollector *) collector
{
    return [self collectorForFeed:self];
}

/*
 *  Return the type id for this feed.
 */
-(NSString *) typeId
{
    return [[self typeForFeed:self] typeId];
}

/*
 *  Return a handle to the feed type.
 */
-(ChatSealFeedType *) feedType
{
    return [self typeForFeed:self];
}

/*
 *  This should be a unique id for the feed that is tied to its service and the login so that we can
 *  always hash to the same file.
 */
-(NSString *) feedId
{
    @synchronized (self) {
        return [mdFeedData objectForKey:PSF_STD_ID_KEY];
    }
}

/*
 *  Return a feed description for debugging.
 */
-(NSString *) description
{
    return [NSString stringWithFormat:@"ChatSealFeed: %@", [self feedId]];
}

/*
 *  Return a description for this feed's type.
 */
-(NSString *) typeDescription
{
    return [[self typeForFeed:self] description];
}

/*
 *  The feed display name is how the feed should be shown in the UI, either in the address bar or in the feed collections.
 */
-(NSString *) displayName
{
    NSLog(@"CS-ALERT: Override the display name method in the feed.");
    return nil;
}

/*
 *  Feed objects that exist are generally considered to be valid, except in the case where their persistent data is destroyed
 *  which means they aren't to be used any longer.
 */
-(BOOL) isValid
{
    @synchronized (self) {
        return isValid;
    }
}

/*
 *  Check the equality of this feed to another.
 */
-(BOOL) isEqual:(id)object
{
    if ([object isKindOfClass:[ChatSealFeed class]] &&
        [[self feedId] isEqualToString:[(ChatSealFeed *) object feedId]]) {
        return YES;
    }
    return NO;
}

/*
 *  When a feed is used to either send or receive a message, this value is incremented.
 */
-(NSUInteger) numberOfMessagesProcessed
{
    @synchronized (self) {
        NSNumber *nPosted = [mdFeedData objectForKey:PSF_STD_NUM_POSTED];
        NSNumber *nRecvd  = [mdFeedData objectForKey:PSF_STD_NUM_RECVD];
        return [nPosted unsignedIntegerValue] + [nRecvd unsignedIntegerValue];
    }
}

/*
 *  Return the number of messages received by this feed.
 */
-(NSUInteger) numberOfMessagesReceived
{
    @synchronized (self) {
        NSNumber *nRecvd  = [mdFeedData objectForKey:PSF_STD_NUM_RECVD];
        return [nRecvd unsignedIntegerValue];
    }
}


/*
 *  This value is used to provide an overall progress of the feed that is currently 
 *  performing activities that have a good chance at resulting in message exchanges.
 *  - return 1.0 if there is nothing currently to do.
 */
-(ChatSealFeedProgress *) currentFeedProgress
{
    // - make sure we have something to show.
    if ([self verifyUpToDateProgress]) {
        [self recomputeProgressWithNotification:NO];
    }
    
    @synchronized (self) {
        return [[currentProgress retain] autorelease];
    }
}

/*
 *  This test is used to determine if the feed can support messaging requests, which means that
 *  it must be in perfect operating condition.
 */
-(BOOL) isViableMessagingTarget
{
    // - NOTE: we don't check the password validity here because I think it is reasonable to
    //         post a message to a feed that maybe doesn't have an updated password.
    return ([self userId] && [self isValid] && [self isEnabled] && [self isAuthorized] && [self isPasswordValid]);
}

/*
 *  A feed can choose to throttle its own service without affecting any other feeds.   This
 *  flag indicates if the feed is temporarily offline due to an issue that requires 
 *  either time to pass or some other action (like update password) to occur.
 */
-(BOOL) isFeedServiceThrottled
{
    if (![self isPasswordValid] ||
        [self isFeedServiceThrottledInCategory:CS_CNT_THROTTLE_UPLOAD] ||
        [self isFeedServiceThrottledInCategory:CS_CNT_THROTTLE_DOWNLOAD] ||
        [self isFeedServiceThrottledInCategory:CS_CNT_THROTTLE_TRANSIENT] ||
        [self isFeedServiceThrottledInCategory:CS_CNT_THROTTLE_REALTIME]) {
        return YES;
    }
    return NO;
}

/*
 *  Has the feed been deleted?
 */
-(BOOL) isDeleted
{
    return ![self isBackingIdentityAvailable];
}

/*
 *  If this method returns any text, that indicates the feed is not operating correctly.
 */
-(NSString *) statusText
{
    if (![self isValid]) {
        return NSLocalizedString(@"Feed is stale.", nil);
    }
    else if ([self isDeleted]) {
        return NSLocalizedString(@"Feed is deleted.", nil);
    }
    else if (![self isEnabled] || ![self isAuthorized]) {
        return NSLocalizedString(@"Feed is turned off.", nil);
    }
    else if (![self isPasswordValid]) {
        return NSLocalizedString(@"Password is expired.", nil);
    }
    else if (![[self typeForFeed:self] areFeedsNetworkReachable]) {
        return [[self typeForFeed:self] networkReachabilityError];
    }
    return nil;
}

/*
 *  When the feed cannot be used as target, we can display corrective action for it.
 */
-(NSString *) correctiveText
{
    if (![self isViableMessagingTarget]) {
        if (![self isEnabled]) {
            if ([self isBackingIdentityAvailable]) {
                return NSLocalizedString(@"Turn on this feed to use it for personal messages.", nil);
            }
            else {
                return NSLocalizedString(@"This feed has been deleted.", nil);
            }
        }
        else if (![self isAuthorized]) {
            return NSLocalizedString(@"This feed is not authorized for use.", nil);
        }
        else {
            return NSLocalizedString(@"This feed is experiencing problems and is unavailable for messages.", nil);            
        }
    }
    else if (![[self feedType] areFeedsNetworkReachable]) {
        return NSLocalizedString(@"You must connect to the Internet in Settings before you can exchange personal messages.", nil);
    }
    return nil;
}

/*
 *  This method is used to identify whether the feed status should be shown as a warning or
 *  as a standard status line.
 */
-(BOOL) isInWarningState
{
    if (![self isValid] || ![self isEnabled] || ![self isAuthorized] || ![self isPasswordValid] ||
        ![[self typeForFeed:self] areFeedsNetworkReachable]) {
        return YES;
    }
    return NO;
}

/*
 *  A very common problem is that a feed could have its password expired, in which case we want to
 *  accurately track that fact.
 */
-(BOOL) isPasswordValid
{
    @synchronized (self) {
        // - I'm inverting this boolean because it is easier to assume the password is valid
        //   by default with an 'expired' key as opposed to tracking explicit validity.
        NSNumber *n = [mdFeedData objectForKey:PSF_STD_PWDEXP_KEY];
        if (n) {
            return ![n boolValue];
        }
        return YES;
    }
}

/*
 *  Each feed needs to be able to create a custom address view.
 */
-(UIFormattedFeedAddressView *) addressView
{
    NSLog(@"CS-ALERT: Override the address view method in the feed.");
    return nil;
}

/*
 *  Post a message to the feed for delivery.
 *  - the sub-classes will need to work through the shared interface to gain access to
 *    the pending message list.
 */
-(BOOL) postMessage:(ChatSealMessageEntry *) entry withError:(NSError **) err
{
    // - when the feed isn't valid, that means it disappeared.  Also, if it is somehow disabled,
    //   we're going to disallow posting because that is clearly something we didn't want used.
    if (![self isValid] || ![self isEnabled]) {
        [CS_error fillError:err withCode:CSErrorFeedInvalid];
        return NO;
    }
    
    // - first save the entry centrally because the supporting data is a little heavy compared to the state
    NSString *safeEntryId = [[self collector] saveAndReturnPostedSafeEntry:entry withError:err];
    if (!safeEntryId) {
        return NO;
    }
    
    // - figure out what kind of description to use here.
    NSString *msgDesc   = nil;
    NSUInteger numItems = [entry numItems];
    BOOL hasImage      = NO;
    for (NSUInteger i = 0; i < numItems; i++) {
        NSString *tmp = [entry itemAsStringAtIndex:i];
        if (!tmp) {
            hasImage = YES;
        }
        if (!msgDesc) {
            msgDesc = [tmp substringToIndex:MIN(256, [tmp length])];
            if (msgDesc.length < tmp.length) {
                msgDesc = [msgDesc stringByAppendingString:@"..."];
            }
        }
    }
    
    // - when there is no description, manufacture one.
    if (!msgDesc) {
        if (hasImage) {
            msgDesc = NSLocalizedString(@"A personal photo.", nil);
        }
        else {
            // - this honestly shouldn't happen, but in the event of an error
            //   I want to try to minimize the shock a bit.
            msgDesc = NSLocalizedString(@"Something personal.", nil);
        }
    }
    
    // - now save the entry in our own pending list for processing when
    //   the opportunity arises.
    if ([self addNewPendingSafeEntry:safeEntryId withMsgDescription:msgDesc andError:err]) {
        [self requestHighPriorityAttention];
        return YES;
    }
    return NO;
}

/*
 *  Return the list of items we're currently posting.  
 *  - generally it is a good idea to get the list once and then wait for notifications
 *    to get granular progress updates.
 */
-(NSArray *) currentPostingProgress
{
    NSMutableArray *maRet = [NSMutableArray array];
    
    // - first get the current progress items.
    @synchronized (self) {
        NSMutableArray *maWork = [mdFeedData objectForKey:PSF_STD_WORK_KEY];
        if (!maWork) {
            return maRet;
        }

        // - sort the array in ascending order by date.
        NSArray *arrWork = [maWork sortedArrayUsingComparator:^NSComparisonResult(CS_postedMessageState *s1, CS_postedMessageState *s2) {
            return [s1 compare:s2];
        }];
        
        // - now we need to manufacture the items.
        for (CS_postedMessageState *state in arrWork) {
            [maRet addObject:[[[ChatSealPostedMessageProgress alloc] initWithState:state] autorelease]];
        }
    }
    
    // - now find the associated messages for these items.
    [[self collector] fillPostedMessageProgressItems:maRet];
    
    // - and return the full collection.
    return maRet;
}

/*
 *  When this flag is set, the feed will not actively process pending items requiring posting, but still identify that they exist.
 *  - NOTE: this flag really should be non-persistent because it is only for UI coordination and shouldn't survive an app restart.
 */
-(void) setPendingPostProcessingEnabled:(BOOL) enabled
{
    @synchronized (self) {
        isPostingEnabled = enabled;
    }
}

/*
 *  Build a new progress object based on the requested safe id.
 */
-(ChatSealPostedMessageProgress *) updatedProgressForSafeEntryId:(NSString *) safeId
{
    if (!safeId) {
        return nil;
    }
    
    ChatSealPostedMessageProgress *pmp = nil;
    @synchronized (self) {
        NSMutableArray *maWork = [mdFeedData objectForKey:PSF_STD_WORK_KEY];
        if (!maWork) {
            return nil;
        }

        for (CS_postedMessageState *state in maWork) {
            if ([state.safeEntryId isEqualToString:safeId]) {
                pmp = [[[ChatSealPostedMessageProgress alloc] initWithState:state] autorelease];
                break;
            }
        }
    }
    
    if (pmp) {
        [[self collector] fillPostedMessageProgressItem:pmp];
    }
    
    return pmp;
}

/*
 *  Delete a post that hopefully hasn't started yet.
 */
-(void) deletePendingPostForSafeEntryId:(NSString *) safeId
{
    ChatSealPostedMessageProgress *pmp = nil;
    @synchronized (self) {
        NSMutableArray *maWork = [mdFeedData objectForKey:PSF_STD_WORK_KEY];
        if (!maWork) {
            return;
        }
        
        for (CS_postedMessageState *state in maWork) {
            if ([state.safeEntryId isEqualToString:safeId]) {
                if (state.state == CS_PMS_PENDING) {
                    pmp = [[[ChatSealPostedMessageProgress alloc] initWithState:state] autorelease];
                    [maWork removeObject:state];
                    [mdUploadStats removeObjectForKey:safeId];
                    [self saveConfigurationWithError:nil];
                }
                break;
            }
        }
    }
    
    // - when the item was deleted, we must notify anyone that was watching it or the overall progress.
    if (pmp) {
        [[self collector] fillPostedMessageProgressItem:pmp];
        [pmp markAsFakeCompleted];
        [self notifyObserversOfPostedMesageProgress:pmp];
        [self recomputeProgressWithNotification:NO];
        [self notifyMajorFeedUpdateHasOccurredAndShouldUpdateBadge:YES];
    }
}

/*
 *  Generate a consistent block of text for displaying the number of messages exchanged.
 */
-(NSString *) localizedMessagesExchangedText
{
    NSUInteger numProcessed = [self numberOfMessagesProcessed];
#if CHATSEAL_RUNNING_CONTRIVED_SCENARIO
    numProcessed = 51;
#endif
    NSString *status        = nil;
    if (numProcessed == 0) {
        status = NSLocalizedString(@"No messages delivered.", nil);
    }
    else if (numProcessed == 1) {
        status = NSLocalizedString(@"One message delivered.", nil);
    }
    else {
        status = NSLocalizedString(@"%u messages delivered.", nil);
        status = [NSString stringWithFormat:status, numProcessed];
    }
    return status;
}
@end


/*************************
 ChatSealFeed (internal)
 *************************/
@implementation ChatSealFeed (internal)
/*
 *  Save feed configuration to the given location.
 *  - ASSUMES the lock is held.
 */
+(BOOL) saveFeedConfiguration:(NSDictionary *) dict intoDirectory:(NSURL *) uDirectory withError:(NSError **) err
{
    if (!uDirectory) {
        [CS_error fillError:err withCode:CSErrorFilesystemAccessError andFailureReason:@"Failed to get a good feed directory."];
        return NO;
    }
    
    NSURL *uFile     = [uDirectory URLByAppendingPathComponent:PSF_FEED_CONFIG];
    return [CS_feedCollectorUtil secureSaveConfiguration:dict asFile:uFile withError:err];
}

/*
 *  Load the feed configuration from the given location.
 *  - ASSUMES the lock is held.
 */
+(NSDictionary *) loadFeedConfigurationFromDirectory:(NSURL *) uDirectory withError:(NSError **) err
{
    if (!uDirectory) {
        [CS_error fillError:err withCode:CSErrorFilesystemAccessError andFailureReason:@"Failed to get a good feed directory."];
        return nil;
    }
    
    // - we cannot load without a vault because there is no app key yet.
    if (![ChatSeal hasVault]) {
        [CS_error fillError:err withCode:CSErrorVaultRequired];
        return nil;
    }
    
    NSURL *uFile              = [uDirectory URLByAppendingPathComponent:PSF_FEED_CONFIG];
    NSDictionary *dictDecoded = [CS_feedCollectorUtil secureLoadConfigurationFromFile:uFile withError:err];
    if (dictDecoded) {
        if (![dictDecoded objectForKey:PSF_STD_ID_KEY] || ![dictDecoded objectForKey:PSF_STD_TYPE_KEY]) {
            [CS_error fillError:err withCode:CSErrorArchivalError andFailureReason:@"Invalid feed archive format."];
            return nil;
        }
    }
    return dictDecoded;
}

/*
 *  Replace the contents of the dictionary with alternate data.
 *  - ASSUMES the lock is held.
 */
-(void) replaceDataWithData:(NSDictionary *) dAlternateData
{
    [mdFeedData removeAllObjects];
    [mdFeedData addEntriesFromDictionary:dAlternateData];
}

/*
 *  Ensure that the throttle stats file can be opened.
 *  - ASSUMES lock is held.
 */
-(BOOL) verifyStatsAreValidWithError:(NSError **) err
{
    if (![apiFactory hasStatsFileDefined]) {
        // - I'm intentionally not going to allow this to work without defining a stats file.
        if (![apiFactory setThrottleStatsFile:[[self feedDirectoryURL] URLByAppendingPathComponent:PSF_FEED_STATS] withError:err]) {
            return NO;
        }
    }
    return YES;
}

/*
 *  Return the current delegate
 */
-(id<ChatSealFeedDelegate>) delegate
{
    @synchronized (self) {
        // - even though we never retain the delegate internally, it must be
        //   retained in the autorelease pool to prevent it from disappearing after
        //   we return it.
        return [[delegate retain] autorelease];
    }
}

/*
 *  Add a new pending safe entry to this object's state for delivery.
 */
-(BOOL) addNewPendingSafeEntry:(NSString *) safeEntryId withMsgDescription:(NSString *) msgDesc andError:(NSError **) err
{
    // - we'll be saving stats.
    [self verifyUpToDateProgress];
    
    BOOL ret = NO;
    @synchronized (self) {
        NSObject *obj          = [mdFeedData objectForKey:PSF_STD_WORK_KEY];
        NSMutableArray *maWork = nil;
        if ([obj isKindOfClass:[NSMutableArray class]]) {
            maWork = (NSMutableArray *) obj;
        }
        else {
            maWork = [NSMutableArray array];
        }
        
        CS_postedMessageState *msgState = [CS_postedMessageState stateForSafeEntry:safeEntryId];
        msgState.msgDescription         = msgDesc;
        [maWork addObject:msgState];
        [mdFeedData setObject:maWork forKey:PSF_STD_WORK_KEY];
        [self setUploadStatsForSafeEntry:safeEntryId withNumSent:0 andTotalToSend:0];
        ret = [self saveConfigurationWithError:err];
    }
    
    // - adding a new entry will always update progress.
    [self recomputeProgressWithNotification:YES];
    return ret;
}

/*
 *  Update the feed data array.
 *  - ASSUMES the lock is held.
 *  - returns the deleted states or nil if nothing was deleted
 */
-(NSArray *) deleteStateForSafeEntries:(NSArray *) arrSafeEntries inSubArrayKey:(NSString *) key
{
    BOOL doSave           = NO;
    NSMutableArray *maRet = [NSMutableArray array];
    NSMutableArray *maTmp = [mdFeedData objectForKey:key];
    if (maTmp) {
        NSMutableIndexSet *mis = [NSMutableIndexSet indexSet];
        for (NSUInteger i = 0; i < [maTmp count]; i++) {
            CS_postedMessageState *pms = [maTmp objectAtIndex:i];
            if ([arrSafeEntries containsObject:pms.safeEntryId]) {
                [maRet addObject:pms];
                [mdUploadStats removeObjectForKey:pms.safeEntryId];
                [mis addIndex:i];
            }
        }
        if ([mis count]) {
            [maTmp removeObjectsAtIndexes:mis];
            doSave = YES;
        }
    }
    return doSave ? maRet : nil;
}

/*
 *  Move an existing entry from where it is right now to a new state.
 */
-(BOOL) moveSafeEntry:(NSString *) safeEntryId toState:(cs_postedmessage_state_t) newState
{
    BOOL shouldSave = NO;
    @synchronized (self) {
        NSMutableArray *maWork = [mdFeedData objectForKey:PSF_STD_WORK_KEY];
        if (!maWork) {
            maWork = [NSMutableArray array];
            [mdFeedData setObject:maWork forKey:PSF_STD_WORK_KEY];
            shouldSave = YES;
        }
        NSMutableArray *maTerm = [mdFeedData objectForKey:PSF_STD_TERM_KEY];
        if (!maTerm) {
            maTerm = [NSMutableArray array];
            [mdFeedData setObject:maTerm forKey:PSF_STD_TERM_KEY];
            shouldSave = YES;
        }
        
        // - check the pending content first because that is most likely
        //   the origin of a state change.
        for (CS_postedMessageState *pms in maWork) {
            // - it only makes sense to postpone items that haven't started yet
            //   because if they are in progress, we might as well allow them to
            //   keep going if they might succeeed.
            if (newState == CS_PMS_POSTPONED && pms.state != CS_PMS_PENDING) {
                continue;
            }
            
            if ([pms.safeEntryId isEqualToString:safeEntryId]) {
                pms.state       = newState;
                pms.numSent     = -1;
                pms.totalToSend = -1;
                if (newState == CS_PMS_COMPLETED || newState == CS_PMS_POSTPONED) {
                    if (newState == CS_PMS_COMPLETED) {
                        // - when the message is completed, increment posted count, but never
                        //   save the item any longer because it consumes storage and processing capacity.
                        NSNumber *n = [mdFeedData objectForKey:PSF_STD_NUM_POSTED];
                        n           = [NSNumber numberWithUnsignedInteger:[n unsignedIntegerValue] + 1];
                        [mdFeedData setObject:n forKey:PSF_STD_NUM_POSTED];
                    }
                    else {
                        // - the pending item is only saved when it couldn't be completed.
                        [maTerm addObject:pms];
                    }
                    
                    // - always remove from the work array.
                    [maWork removeObject:pms];
                }
                shouldSave = YES;
                break;
            }
        }
        
        // - if we didn't find it, then look in the terminal array
        if (!shouldSave && newState != CS_PMS_POSTPONED) {
            for (CS_postedMessageState *pms in maTerm) {
                // - it doesn't make sense to ever return a completed entry back to
                //   pending.
                if (newState == CS_PMS_PENDING && pms.state != CS_PMS_POSTPONED) {
                    continue;
                }
                
                if ([pms.safeEntryId isEqualToString:safeEntryId]) {
                    pms.state = newState;
                    if (newState != CS_PMS_COMPLETED && newState != CS_PMS_POSTPONED) {
                        pms.numSent     = -1;
                        pms.totalToSend = -1;
                        [maWork addObject:pms];
                        [maTerm removeObject:pms];
                    }
                    shouldSave = YES;
                    break;
                }
            }
        }
        return shouldSave;
    }
}

/*
 *  Move all the tracked entries to a given new state.
 */
-(void) moveAllMatchingSafeEntries:(NSArray *) arrSafeEntries toState:(cs_postedmessage_state_t) newState
{
    @synchronized (self) {
        // - shift all these entries over to a postponed state because
        //   they are going to require a seal to continue.
        BOOL doSave = NO;
        for (NSString *safeEntryId in arrSafeEntries) {
            if ([self moveSafeEntry:safeEntryId toState:newState]) {
                doSave = YES;
            }
        }
        
        // - if we made updates, save the changes now.
        if (doSave) {
            [self saveConfigurationWithError:nil];
        }
    }
}

/*
 *  Ensure that the progress dictionaries are loaded and the overall value is initially computed.
 */
-(BOOL) verifyUpToDateProgress
{
    BOOL recompute    = NO;
    BOOL initDownload = NO;
    @synchronized (self) {
        if (!mdUploadStats) {
            mdUploadStats = [[NSMutableDictionary alloc] init];
            
            NSMutableArray *maWork = [mdFeedData objectForKey:PSF_STD_WORK_KEY];
            for (CS_postedMessageState *pms in maWork) {
                // - both pending and delivering are included to get a full picture.
                [self setUploadStatsForSafeEntry:pms.safeEntryId withNumSent:pms.numSent andTotalToSend:pms.totalToSend];
                recompute = YES;
            }
        }
        
        if (!mdDownloadStats) {
            mdDownloadStats = [[NSMutableDictionary alloc] init];
            initDownload    = YES;
            recompute       = YES;
        }
    }
    
    // - if the download stats aren't yet configured then initialize them through the implementation.
    if (initDownload) {
        if ([self respondsToSelector:@selector(configurePendingDownloadProgress)]) {
            [self performSelector:@selector(configurePendingDownloadProgress) withObject:nil];
        }
    }
    
    // - any changes, then recompute.
    return recompute;
}

/*
 *  Recompute the overall progress value for this feed.
 */
-(void) recomputeProgressWithNotification:(BOOL) doNotify
{
    [self verifyUpToDateProgress];
    @synchronized (self) {
        [currentProgress release];
        currentProgress = [[ChatSealFeedProgress alloc] init];
        if ([mdUploadStats count] || [mdDownloadStats count]) {
            NSUInteger totalCounted = 0;
            currentProgress.overallProgress = 0.0;
            currentProgress.scanProgress    = 0.0;
            currentProgress.postingProgress = 0.0;
            
            // - compute the effect of uploads on the progress.
            for (NSNumber *n in mdUploadStats.allValues) {
                currentProgress.overallProgress += n.floatValue;
                currentProgress.postingProgress += n.floatValue;
                totalCounted++;
            }
            
            if ([mdUploadStats count]) {
                currentProgress.postingProgress += (double) completedUploads;
                currentProgress.postingProgress /= ((double) [mdUploadStats count] + completedUploads);
            }
            else {
                currentProgress.postingProgress = 1.0f;
            }
            
            // - now compute download impact.
            for (NSNumber *n in mdDownloadStats.allValues) {
                currentProgress.overallProgress += n.floatValue;
                currentProgress.scanProgress    += n.floatValue;
                totalCounted++;
            }
            
            if ([mdDownloadStats count]) {
                currentProgress.scanProgress += (double) completedDownloads;
                currentProgress.scanProgress /= (double) ([mdDownloadStats count] + completedDownloads);
            }
            else {
                currentProgress.scanProgress = 1.0f;
            }
            
            // - when items disappear from the two dictionaries, we still
            //   track their contribution until everything is done.
            totalCounted        += (completedDownloads + completedUploads);
            currentProgress.overallProgress += ((double) (completedUploads + completedDownloads));
            currentProgress.overallProgress /= (double) totalCounted;
        }
        else {
            completedUploads   = 0;
            completedDownloads = 0;
        }
    }
    
    // - notify the rest of the app when necessary.
    if (doNotify) {
        [ChatSealFeedCollector issueUpdateNotificationForFeed:self];
    }
}

/*
 *  Assign a single upload stat in the progress dictionary.
 *  - ASSUMES the lock is held.
 */
-(void) setUploadStatsForSafeEntry:(NSString *) safeEntryId withNumSent:(int64_t) numSent andTotalToSend:(int64_t) toSend
{
    if (!safeEntryId) {
        return;
    }
    
    if (numSent == PSF_STD_COMPLETE_STAT) {
        [mdUploadStats removeObjectForKey:safeEntryId];
        completedUploads++;
    }
    else {
        float progress = 0.0f;
        if (toSend) {
            progress = (float)((double)numSent/(double)toSend);
        }
        [mdUploadStats setObject:[NSNumber numberWithFloat:progress] forKey:safeEntryId];
    }
}

/*
 *  Notify listeners of new progress.
 */
-(void) notifyObserversOfPostedMesageProgress:(ChatSealPostedMessageProgress *) pmp
{
    // - post the notification.
    [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kChatSealNotifyFeedPostProgress
                                                            object:nil
                                                          userInfo:[NSDictionary dictionaryWithObject:pmp forKey:kChatSealNotifyFeedPostProgressItemKey]];
    }];
}

/*
 *  This is the generic API request method.
 */
-(CS_netFeedAPI *) apiForName:(NSString *) name withEvenDistribution:(BOOL) evenlyDistributed andReturnWasThrottled:(BOOL *) wasThrottled withError:(NSError **) err
{
    // - ensure that the gate is open and warn if it isn't.  If you get this
    //   you're scheduling outside the standard refresh path.
    if (![[[NSThread currentThread] threadDictionary] objectForKey:PSF_STD_GATE_KEY]) {
        NSLog(@"CS-ALERT: Disallowed API access during non-refresh cycle.  (%@)", name);
        if (wasThrottled) {
            *wasThrottled = YES;
        }
        [CS_error fillError:err withCode:CSErrorFeedNotSupported];
        return nil;
    }
    
    BOOL tmpEnabled     = [self isEnabled];
    BOOL tmpAuthorized  = [self isAuthorized];
    CS_netFeedAPI *ret = nil;
    @synchronized (self) {
        if (!tmpEnabled || !tmpAuthorized) {
            // - I'm translating this into a throttling action because this is a known state, not an error.
            if (wasThrottled) {
                *wasThrottled = YES;
            }
            [CS_error fillError:err withCode:CSErrorFeedDisabled];
            return nil;
        }
        
        if (![self shouldPermitServiceWithExpiredPassword]) {
            if (wasThrottled) {
                *wasThrottled = NO;
            }
            [CS_error fillError:err withCode:CSErrorFeedPasswordExpired];
            return nil;
        }
        
        // - after we pass the gate once, don't allow it again when the password is expired.
        allowTemporaryAccess = NO;
        
        // - if the factory exists, build an API instance.
        if (apiFactory) {
            if (![self verifyStatsAreValidWithError:err]) {
                return nil;
            }
            ret = [apiFactory apiForName:name andRequestEvenDistribution:evenlyDistributed andReturnWasThrottled:wasThrottled withError:err];
        }
        else {
            [CS_error fillError:err withCode:CSErrorFeedNotSupported andFailureReason:@"No API factory."];
        }
    }
    
    // - authentication must occur as soon as the API is built because some APIs like upload
    //   may need the account information before the request is 'officially' generated.
    // - do this outside the lock because the authenticate call may call back into other elements
    //   of this implementation.
    if (ret && [self respondsToSelector:@selector(pipelineAuthenticateAPI:)]) {
        if (![self pipelineAuthenticateAPI:ret]) {
            if (wasThrottled) {
                *wasThrottled = YES;
            }
            [CS_error fillError:err withCode:CSErrorFeedLimitExceeded];
            return nil;
        }
    }
    
    return ret;
}

@end

/*********************
 ChatSealFeed (shared)
 *********************/
@implementation ChatSealFeed (shared)
/*
 *  Initialize the object.
 */
-(id) initWithAccountDerivedId:(NSString *) sFeedId andDelegate:(id<ChatSealFeedDelegate>) d
{
    return [self initWithAccountDerivedId:sFeedId andDelegate:d andDictionary:nil];
}

/*
 *  Initialize the object.
 */
-(id) initWithAccountDerivedId:(NSString *) sFeedId andDelegate:(id<ChatSealFeedDelegate>) d andDictionary:(NSDictionary *) dFeedData
{
    self = [super init];
    if (self) {
        sFeedFileName            = nil;
        delegate                 = d;
        isValid                  = YES;
        allowTemporaryAccess     = NO;
        mdUploadStats            = nil;
        mdDownloadStats          = nil;
        currentProgress          = nil;
        completedDownloads       = 0;
        completedUploads         = 0;
        isPostingEnabled         = YES;
        isSaveDeferred           = NO;
        if (dFeedData) {
            mdFeedData               = [[NSMutableDictionary alloc] initWithDictionary:dFeedData];
            
            // - if the sub-class wants to know about its custom configuration, pull that out now.
            if ([self respondsToSelector:@selector(customConfigurationHasBeenLoaded:)]) {
                NSObject *obj            = [dFeedData objectForKey:PSF_STD_CUSCFG_KEY];
                NSDictionary *dictCustom = nil;
                if (obj && [obj isKindOfClass:[NSDictionary class]]) {
                    dictCustom = (NSDictionary *) obj;
                }
                else {
                    dictCustom = [NSDictionary dictionary];
                }
                
                [self customConfigurationHasBeenLoaded:dictCustom];
            }

            // - since all this configuration data is mutable, it doesn't make sense for me
            //   to keep it in the superclass, so we'll just hand it off to the sub-class for
            //   save keeping.   This is the only time we ever load configuration so we can
            //   be sure they'll stay in synch.
            [mdFeedData removeObjectForKey:PSF_STD_CUSCFG_KEY];
        }
        else {
            mdFeedData         = [[NSMutableDictionary alloc] init];
            [mdFeedData setObject:sFeedId forKey:PSF_STD_ID_KEY];
            [mdFeedData setObject:[[self typeForFeed:self] typeId] forKey:PSF_STD_TYPE_KEY];
            [mdFeedData setObject:[NSNumber numberWithBool:YES] forKey:PSF_STD_ENABLED_KEY];
        }
        apiFactory = [[self apiFactoryForFeed:self] retain];
    }
    return self;
}

/*
 *  Assign the delegate to the feed, which is used to allow it to coordinate with its owning type.
 */
-(void) setDelegate:(id<ChatSealFeedDelegate>)newD
{
    @synchronized (self) {
        // - assign, not retain!
        delegate = newD;
    }
}

/*
 *  Destroy all the backing data for the feed.
 */
-(void) destroyFeedPersistentData
{
    @synchronized (self) {
        isValid  = NO;
        NSURL *u = [self feedDirectoryURL];
        if (u) {
            NSError *err = nil;
            if ([[NSFileManager defaultManager] fileExistsAtPath:[u path]]) {
                if (![[NSFileManager defaultManager] removeItemAtURL:u error:&err]) {
                    NSLog(@"CS: Failed to delete the feed directory %@.  %@", [u path], [err localizedDescription]);
                }
            }
        }
    }
}

/*
 *  Return the URL for storing feed data.
 */
-(NSURL *) feedDirectoryURL
{
    NSURL *u = [ChatSealFeedCollector feedCollectionURL];
    NSString *sFeedId = [self feedId];
    if (!sFeedId || !sFeedId.length) {
        NSLog(@"CS-ALERT: Feed implementation is incomplete.");
        return nil;
    }
    
    if (!sFeedFileName) {
        // - the vault is required so that we can produce a safe-salted string for the feed file.
        if (![ChatSeal hasVault]) {
            return nil;
        }
        
        // - my intent is to prevent an outside party from knowing anything really significant about
        //   the feeds.  I can't do much about their size, but I can minimize any inferences about what is
        //   contained in them or where they are directed.
        sFeedFileName = [[ChatSeal safeSaltedPathString:sFeedId withError:nil] retain];
        if (!sFeedFileName) {
            NSLog(@"CS: Failed to return a valid feed configuration filename.");
            return nil;
        }
    }
    
    u = [u URLByAppendingPathComponent:sFeedFileName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:[u path]]) {
        NSError *err = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtURL:u withIntermediateDirectories:YES attributes:nil error:&err]) {
            NSLog(@"CS: Failed to create the feed directory at %@.  %@", [u path], [err localizedDescription]);
            return nil;
        }
    }
    return u;
}

/*
 *  Save the configuration data for this feed explicitly.
 */
-(BOOL) saveConfigurationWithError:(NSError **) err
{
    @synchronized (self) {
        // - make sure it is a good idea to save.
        if (!isValid || ![self canSaveFeed:self]) {
            [CS_error fillError:err withCode:CSErrorFeedNotSupported];
            return NO;
        }
        
        // - when there is no vault, we cannot save anything because there will be no app key, but that is OK because initially
        //   there isn't much to worry about.
        if (![ChatSeal hasVault]) {
            return YES;
        }

        // - create a copy because we don't want to retain the custom configuration in the superclass.
        NSMutableDictionary *mdToSave = [NSMutableDictionary dictionaryWithDictionary:mdFeedData];
        
        // - see if there is extra configuration to save.
        NSDictionary *dict = nil;
        if ([self respondsToSelector:@selector(customConfiguration)]) {
            dict = [self customConfiguration];
        }
        if (dict) {
            [mdToSave setObject:dict forKey:PSF_STD_CUSCFG_KEY];
        }
        else {
            [mdToSave removeObjectForKey:PSF_STD_CUSCFG_KEY];
        }
        
        // - I'm resetting the deferred save here because I don't want to keep trying this if there was an error.  We
        //   could get into a costly loop in the event of a problem otherwise.
        isSaveDeferred = NO;
        
        // - and save it securely.
        return [ChatSealFeed saveFeedConfiguration:mdToSave intoDirectory:[self feedDirectoryURL] withError:err];
    }
}

/*
 *  Mark this feed as having content to save, but only do so at the end of the refresh cycle.
 */
-(void) saveDeferredUntilEndOfCycle
{
    @synchronized (self) {
        isSaveDeferred = YES;
    }
}

/*
 *  If there is a deferred save required, do so now.
 */
-(BOOL) saveIfDeferredWorkIsPendingWithError:(NSError **) err
{
    @synchronized (self) {
        if (isSaveDeferred) {
            return [self saveConfigurationWithError:err];
        }
    }
    return YES;
}

/*
 *  This method will check to see if the given API can be scheduled in the throttle.
 */
-(BOOL) hasCapacityForAPIByName:(NSString *) name withEvenDistribution:(BOOL)evenlyDistributed
{
    return [self hasCapacityForAPIByName:name withEvenDistribution:evenlyDistributed andAllowAnyCategory:NO];
}

/*
 *  This method will check to see if the given API can be scheduled in the throttle.
 */
-(BOOL) hasCapacityForAPIByName:(NSString *) name withEvenDistribution:(BOOL) evenlyDistributed andAllowAnyCategory:(BOOL) allowAny
{
    @synchronized (self) {
        if (![self verifyStatsAreValidWithError:nil]) {
            return NO;
        }
        return [apiFactory hasCapacityForAPIByName:name withEvenDistribution:evenlyDistributed andAllowAnyCategory:allowAny];
    }
}

/*
 *  Return an api for the given name using the local factory to generate it.
 */
-(CS_netFeedAPI *) apiForName:(NSString *) name andReturnWasThrottled:(BOOL *) wasThrottled withError:(NSError **) err
{
    return [self apiForName:name withEvenDistribution:NO andReturnWasThrottled:wasThrottled withError:err];
}

/*
 *  Return an api for the given name, but require that it follows an even distribution over its throttle period.
 *  - this is to avoid the default behavior of allowing APIs to be scheduled all up front in the time slice, but 
 *    get starved at the end when they've exceeded capacity.
 */
-(CS_netFeedAPI *) evenlyDistributedApiForName:(NSString *) name andReturnWasThrottled:(BOOL *) wasThrottled withError:(NSError **) err
{
    return [self apiForName:name withEvenDistribution:YES andReturnWasThrottled:wasThrottled withError:err];
}

/*
 *  Try to determine if one of our existing APIs was the source for this request.
 */
-(CS_netFeedAPI *) apiForExistingRequest:(NSURLRequest *) req
{
    @synchronized (self) {
        if (![self verifyStatsAreValidWithError:nil]) {
            return nil;
        }
        CS_netFeedAPI *api = [apiFactory apiForExistingRequest:req];
        [api configureWithExistingRequest:req];
        return api;
    }
}

/*
 *  If the feed's service lets us know we have over-requested, we need to respect that
 *  and immediately back off.  The way to do this is to tell the factory to reset the throttle
 *  on requests for one full cycle.
 */
-(void) throttleAPIForOneCycle:(CS_netFeedAPI *) api
{
    @synchronized (self) {
        [apiFactory throttleAPIForOneCycle:api];
    }
}

/*
 *  Adjust the factory so that it uses a new limit.  This should in-general only be used with better data than what
 *  was used to hard code the original limits.
 */
-(void) reconfigureThrottleForAPIByName:(NSString *) name toLimit:(NSUInteger) limit andRemaining:(NSUInteger) numRemaining
{
    @synchronized (self) {
        [apiFactory reconfigureThrottleForAPIByName:name toLimit:limit andRemaining:numRemaining];
    }
}

/*
 *  The API factory will conveniently store when it last handed out an API request object
 *  in each of the supported categories.
 */
-(NSDate *) lastRequestDateForCategory:(cs_cnt_throttle_category_t) category
{
    @synchronized (self) {
        NSDate *dRet = [apiFactory lastRequestDateForCategory:category];
        if (!dRet) {
            dRet = [NSDate date];
        }
        return dRet;
    }
}

/*
 *  Assign a user id to the feed.
 */
-(BOOL) setUserId:(NSString *) uid withError:(NSError **) err
{
    @synchronized (self) {
        NSMutableDictionary *mdTmp = [NSMutableDictionary dictionaryWithDictionary:mdFeedData];
        if (uid) {
            NSString *sExisting = [mdFeedData objectForKey:PSF_STD_USERID_KEY];
            if (sExisting && ![sExisting isEqualToString:uid]) {
                // - once a feed has a user id, we will not permit it to be reset because that
                //   implies a second feed in this model.
                [CS_error fillError:err withCode:CSErrorFeedNotSupported];
                return NO;
            }
            [mdFeedData setObject:uid forKey:PSF_STD_USERID_KEY];
        }
        else {
            [mdFeedData removeObjectForKey:PSF_STD_USERID_KEY];
        }
        if (![self saveConfigurationWithError:err]) {
            [self replaceDataWithData:mdTmp];
            return NO;
        }
    }
    return YES;
}

/*
 *  Enqueue the requested API for processing by the collector.
 */
-(BOOL) addCollectorRequestWithAPI:(CS_netFeedAPI *) api andReturnWasThrottled:(BOOL *) wasThrottled withError:(NSError **) err
{
    if (!api) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        return NO;
    }
    
    // - and ask that it process it.
    return [[self collectorForFeed:self] addRequestAPI:api forFeed:self inCategory:api.throttleCategory andReturnWasThrottled:wasThrottled withError:err];
}

/*
 *  Return the feed type associated with this feed.
 */
-(ChatSealFeedType *) typeForFeed:(ChatSealFeed *) feed
{
    return [self.delegate performSelector:@selector(typeForFeed:) withObject:feed];
}

/*
 *  Return the collector for this feed.
 */
-(ChatSealFeedCollector *) collectorForFeed:(ChatSealFeed *) feed
{
    return [self.delegate performSelector:@selector(collectorForFeed:) withObject:feed];
}

/*
 *  Determines if we're allowed to save the given feed.
 */
-(BOOL) canSaveFeed:(ChatSealFeed *) feed
{
    return [self.delegate canSaveFeed:feed];
}

/*
 *  Ask the delegate for an API factory object that can be used for making requests.
 */
-(CS_netThrottledAPIFactory *) apiFactoryForFeed:(ChatSealFeed *) feed
{
    return [self.delegate apiFactoryForFeed:feed];
}

/*
 *  When a feed has undelivered content, it is important that you return an affirmative response here
 *  to prevent the feed from being deleted if it is discarded from the account list.
 */
-(BOOL) hasRequiredPendingActivity
{
    @synchronized (self) {
        // - any pending posts?
        NSMutableArray *maWork = [mdFeedData objectForKey:PSF_STD_WORK_KEY];
        if ([maWork count]) {
            return YES;
        }
        
        // - anything postponed?
        // - NOTE: I thought about not including postponed entries, but if the seal is deleted or invalidated
        //         but the message is not, then we should keep the feed around to track the pending work.  If
        //         the message is later discarded, then all of the associated work will be discarded and we
        //         can delete the feed.  On the other hand, if the seal is re-scanned, then we should be able
        //         to restart any outstanding activity.
        NSMutableArray *maTerm = [mdFeedData objectForKey:PSF_STD_TERM_KEY];
        for (CS_postedMessageState *tState in maTerm) {
            if (tState.state == CS_PMS_POSTPONED) {
                return YES;
            }
        }
        return NO;
    }
}

/*
 *  In some circumstances (like restarting after a long download), we will not have the necessary
 *  request objects to complete the routing back to their feeds.  These must be recreated based on 
 *  their content or they cannot be completed and will be discarded.  Implement this method
 *  to identify them.
 */
-(CS_netFeedAPIRequest *) canGenerateAPIRequestFromRequest:(NSURLRequest *) req
{
    NSLog(@"CS-ALERT: Override the can generate API request method in the feed.");
    return nil;
}

/*
 *  This is an _optional_ and fairly obscure entrypoint within the feed that can be used when
 *  the first pass at identifying restarted requests fails, but we know the type is good.  Each
 *  feed can take a different look at it based on what it finds in the request.
 */
-(CS_netFeedAPIRequest *) canApproximateAPIRequestFromOrphanedRequest:(NSURLRequest *) req
{
    return nil;
}

/*
 *  Every feed must be explicitly closed before it is discarded in order to ensure
 *  it has an opportunity to safely clear its delegate relationships with child objects.
 */
-(void) close
{
    @synchronized (self) {
        [self setDelegate:nil];
        
        [sFeedFileName release];
        sFeedFileName = nil;
        
        [mdFeedData release];
        mdFeedData = nil;
        
        [apiFactory release];
        apiFactory = nil;
        
        [mdUploadStats release];
        mdUploadStats = nil;
        
        [mdDownloadStats release];
        mdDownloadStats = nil;
        
        [currentProgress release];
        currentProgress = nil;
    }
}

/*
 *  This method allows us to granularly check the throttle state per-category.
 */
-(BOOL) isFeedServiceThrottledInCategory:(cs_cnt_throttle_category_t) category
{
    return NO;
}

/*
 *  This method is used by the collector do determine if the feed should be allowed
 *  to receive cycles to perform additional work outside the standard refresh
 *  codepath.  Anything that cannot wait until the next refresh should cause a 
 *  YES to be returned.  Subclasses may override with additional criteria.
 */
-(BOOL) hasHighPriorityWorkToPerform
{
    // - if we're in the background, don't bother because we don't have a lot of time.
    if (![ChatSeal isApplicationForeground]) {
        return NO;
    }
    
    @synchronized (self) {
        // - if there is a pending save, make sure that gets processed because
        //   the best place is on the background update thread.
        if (isSaveDeferred) {
            return YES;
        }
        
        NSMutableArray *maWork = [mdFeedData objectForKey:PSF_STD_WORK_KEY];
        if (!maWork) {
            return NO;
        }
        
        for (CS_postedMessageState *pmsTmp in maWork) {
            if (pmsTmp.state == CS_PMS_PENDING) {
                return YES;
            }
        }
    }
    return NO;
}

/*
 *  Feeds get their opportunity to do outstanding work through this method, which is called from
 *  the collector periodically.
 *  - the only time you should return NO from this method is if the request was throttled, in which
 *    case, we may short-circuit further investigation in that category.
 *  - the onlyHighPriority flag can be used to make better decisions about what is being done to prioritize
 *    processing.
 */
-(BOOL) processFeedRequestsInThrottleCategory:(cs_cnt_throttle_category_t) category onlyAsHighPriority:(BOOL) onlyHighPrio
{
    return YES;
}

/*
 *  Change the flag in the feed that tracks whether the password is expired.
 */
-(void) setPasswordExpired:(BOOL) isExpired
{
    BOOL hasChanged = NO;
    @synchronized (self) {
        if (isExpired != [(NSNumber *) [mdFeedData objectForKey:PSF_STD_PWDEXP_KEY] boolValue]) {
            hasChanged = YES;
        }
        [mdFeedData setObject:[NSNumber numberWithBool:isExpired] forKey:PSF_STD_PWDEXP_KEY];
        
        // - there's not much we can do if this cannot be saved and the good news is that it
        //   is relatively easy to retest this later.
        [self saveDeferredUntilEndOfCycle];
    }
    
    if (hasChanged) {
        [self notifyMajorFeedUpdateHasOccurredAndShouldUpdateBadge:YES];
    }
}

/*
 *  Return the group of pending entries that have yet to be fully posted.
 */
-(NSArray *) pendingSafeEntriesToPost
{
    @synchronized (self) {
        NSMutableArray *maRet = [NSMutableArray array];
        NSArray *arr          = [mdFeedData objectForKey:PSF_STD_WORK_KEY];
        for (CS_postedMessageState *state in arr) {
            [maRet addObject:state.safeEntryId];
        }
        return maRet;
    }
}

/*
 *  Remove all the state for the given entries because they're going away.
 */
-(void) deleteStateForSafeEntries:(NSArray *) arrSafeEntries
{
    NSArray *arrDeleted = nil;
    @synchronized (self) {
        arrDeleted = [self deleteStateForSafeEntries:arrSafeEntries inSubArrayKey:PSF_STD_WORK_KEY];
        if ([self deleteStateForSafeEntries:arrSafeEntries inSubArrayKey:PSF_STD_TERM_KEY] ||
            arrDeleted) {
            [self saveConfigurationWithError:nil];
        }
    }
    
    // - make sure the progress reflects the new state when in-progress items are deleted.
    if (arrDeleted) {
        for (CS_postedMessageState *pms in arrDeleted) {
            ChatSealPostedMessageProgress *pmp = [[[ChatSealPostedMessageProgress alloc] initWithState:pms] autorelease];
            [[self collector] fillPostedMessageProgressItem:pmp];
            [pmp markAsFakeCompleted];
            [self notifyObserversOfPostedMesageProgress:pmp];
        }
        [self recomputeProgressWithNotification:NO];
        [self notifyMajorFeedUpdateHasOccurredAndShouldUpdateBadge:YES];
    }
}

/*
 *  When a non-owned seal is deleted, we won't destroy pending content, but mark it
 *  as postponed until we can get a new copy of the seal.
 */
-(void) moveSafeEntriesToPostponed:(NSArray *) arrSafeEntries
{
    [self moveAllMatchingSafeEntries:arrSafeEntries toState:CS_PMS_POSTPONED];
}

/*
 *  When entries are in a postponed state, move them back into pending.
 */
-(void) movePostponedSafeEntriesToPending:(NSArray *) arrSafeEntries
{
    [self moveAllMatchingSafeEntries:arrSafeEntries toState:CS_PMS_PENDING];
}

/*
 *  Determine if we have anything to post and if so, whether it can be accomplished right now.
 *  - this may legitimately return nil if there is nothing in the pipeline.
 */
-(CS_packedMessagePost *) generateNextPendingMessagePost
{
    // - first make sure the central throttle can accommodate a new upload, otherwise
    //   there is no sense it spending the time to build it.
    CS_centralNetworkThrottle *cnt = [[self collector] centralThrottle];
    if (![cnt canStartPendingRequestInCategory:CS_CNT_THROTTLE_UPLOAD]) {
        return nil;
    }

    // - keep this critical section very small and don't call-into anything else, especially
    //   the collector inside of it.
    CS_postedMessageState *toPost = nil;
    @synchronized (self) {
        // - if posting is turned off at the moment, just treat this as nothing to do.
        if (!isPostingEnabled){
            return nil;
        }
        
        // - try to figure out what is in our work queue.
        NSMutableArray *maWork = [mdFeedData objectForKey:PSF_STD_WORK_KEY];
        if (!maWork) {
            return nil;
        }
        
        for (CS_postedMessageState *pmsTmp in maWork) {
            if (pmsTmp.state == CS_PMS_PENDING) {
                toPost = [[pmsTmp retain] autorelease];
                break;
            }
        }
        if (!toPost) {
            return nil;
        }
    }
    
    CS_postedMessage *pm = [[self collector] postedMessageForSafeEntry:toPost.safeEntryId];
    if (!pm) {
        // - technically this should never happen, but I suppose it could in the event that
        //   there was a low-storage event.
        return nil;
    }
    
    ChatSealMessage *msg = [ChatSeal messageForId:pm.messageId];
    if (!msg) {
        if (![ChatSeal isLowStorageAConcern]) {
            NSLog(@"CS: Unexpected message retrieval failure for %@.", pm.messageId);
        }
        return nil;
    }
    
    NSError *tmp = nil;
    if (![msg pinSecureContent:&tmp]) {
        NSLog(@"CS: Failed to pin the secure message %@.  %@", pm.messageId, [tmp localizedDescription]);
        return nil;
    }
    
    // - this information can be useful for identifying the context in which this message is being sent so that
    //   the caller can make different decisions based on origin.
    NSString *sid = [pm sealId];
    BOOL isOwner  = [pm isSealOwned];
        
    NSMutableDictionary *mdUserData = [NSMutableDictionary dictionary];
    
    // - when we pack the message, we're going to include a list of all the local user's feeds that were used
    //   in the past with this seal, but only if the feed sharing flag is enabled.  I don't think it is responsible
    //   to _ever_ assume we can pass other feeds along with this if the person explicitly indicated that they do not
    //   desire that behavior because that could force the app to generate relationships that the two parties do not
    //   want developed.
    if ([ChatSeal canShareFeedsDuringExchanges]) {
        NSMutableArray *maFeedLocations = [NSMutableArray array];
        ChatSealIdentity *ident = [msg identityWithError:nil];
        if (ident) {
            NSArray *arrPosted = [ident feedPostingHistory];
            if (arrPosted && [arrPosted count]) {
                // - we need to convert these into locations and even then only locations that
                //   are not equivalent to the current one being used to send this message.
                NSArray *arrMyFeeds             = nil;
                for (NSString *feedId in arrPosted) {
                    if ([feedId isEqualToString:[self feedId]]) {
                        continue;
                    }
                    
                    if (!arrMyFeeds) {
                        arrMyFeeds = [[self collector] availableFeedsAsSortedList];
                    }
                    
                    for (ChatSealFeed *csf in arrMyFeeds) {
                        if ([feedId isEqualToString:csf.feedId]) {
                            // - we only ever pass along enabled feeds!
                            if ([csf isEnabled]) {
                                ChatSealFeedLocation *csfl = [csf locationWhenUsingSeal:sid];
                                [maFeedLocations addObject:csfl];
                            }
                            break;
                        }
                    }
                }
            }
            
            // - only save the post history when we have content.
            if ([maFeedLocations count]) {
                [mdUserData setObject:maFeedLocations forKey:PSF_STD_POST_HIST_KEY];
            }
        }        
    }
    
    // ...the exception is the feed we're posting to because it stands to reason that one must assume that the feed
    //    where this shows up is self-evident, regardless of the sharing flag.
    // ...it is important that we include this, instead of derive it from the feed itself because that derived data
    //    could be faked if this message is reposted, which is definitely not what we want to have happen.
    ChatSealFeedLocation *csfl = [ChatSealFeedLocation locationForType:[self typeId] andAccount:[self userId]];
    [mdUserData setObject:csfl forKey:PSF_STD_SEND_FEED_KEY];
    
    // - see if the derived class wants to add anything.
    if ([self respondsToSelector:@selector(addCustomUserContentForMessage:packedWithSeal:)]) {
        [self performSelector:@selector(addCustomUserContentForMessage:packedWithSeal:) withObject:mdUserData withObject:sid];
    }
    
    // - use the aggregate method in the message so that it handles the entry locking for us in a clean way.
    CS_packedMessagePost *pmPost = [[[CS_packedMessagePost alloc] initWithSafeEntry:pm.safeEntryId andSeal:sid andIsOwner:isOwner] autorelease];
    pmPost.packedMessage          = [msg sealedMessageForEntryId:pm.entryId includingUserData:[mdUserData count] ? mdUserData : nil withError:&tmp];
    if (!pmPost.packedMessage) {
        NSLog(@"CS: Failed to pack the entry %@.  %@", pm.entryId, [tmp localizedDescription]);
        pmPost = nil;
    }
    
    // - make sure the message is unpinned.
    [msg unpinSecureContent];
    
    return pmPost;
}

/*
 *  Update the state of the entry.
 */
-(void) movePendingSafeEntryToDelivering:(NSString *) safeEntryId
{
    if ([self moveSafeEntry:safeEntryId toState:CS_PMS_DELIVERING]) {
        NSError *err = nil;
        if (![self saveConfigurationWithError:&err]) {
            NSLog(@"CS: Failed to save the feed dataset for message delivering update.  %@", [err localizedDescription]);
        }
    }
}

/*
 *  Update the state of the safe entry from delivery back to pending or to completed.
 */
-(void) moveDeliveringSafeEntry:(NSString *) safeEntryId toCompleted:(BOOL) isCompleted
{
    BOOL recompute = NO;
    if ([self moveSafeEntry:safeEntryId toState:isCompleted ? CS_PMS_COMPLETED : CS_PMS_PENDING]) {
        @synchronized (self) {
            [self setUploadStatsForSafeEntry:safeEntryId withNumSent:isCompleted ? PSF_STD_COMPLETE_STAT : 0 andTotalToSend:isCompleted ? PSF_STD_COMPLETE_STAT : 0];
            recompute = YES;
        }
        NSError *err = nil;
        if (![self saveConfigurationWithError:&err]) {
            NSLog(@"CS: Failed to save the feed dataset for message delivering update.  %@", [err localizedDescription]);
        }
    }
    
    // - recompute the progress when it is necessary.
    if (recompute) {
        [self recomputeProgressWithNotification:YES];
    }
}

/*
 *  Determine if this feed is tracking the provided safe entry.
 */
-(BOOL) isTrackingSafeEntry:(NSString *) safeEntryId
{
    @synchronized (self) {
        NSMutableArray *maWork = [mdFeedData objectForKey:PSF_STD_WORK_KEY];
        NSMutableArray *maTerm = [mdFeedData objectForKey:PSF_STD_TERM_KEY];
        for (CS_postedMessageState *state in maWork) {
            if ([safeEntryId isEqualToString:state.safeEntryId]) {
                return YES;
            }
        }
        for (CS_postedMessageState *state in maTerm) {
            if ([safeEntryId isEqualToString:state.safeEntryId]) {
                return YES;
            }
        }
    }
    return NO;
}

/*
 *  Should the feed be used despite the fact its password is marked as expired?
 */
-(BOOL) shouldPermitServiceWithExpiredPassword
{
    if ([self isPasswordValid]) {
        return YES;
    }
    
    @synchronized (self) {
        return allowTemporaryAccess;
    }
}

/*
 *  When this flag is set, the feed can be used for a single API request
 *  even if the password is expired.  This is to attempt to revalidated it.
 */
-(void) setPermitTemporaryAccessWithExpiredPassword
{
    @synchronized (self) {
        allowTemporaryAccess = YES;
    }
}

/*
 *  When the identity associated with a feed is deleted, but the feed cannot be because
 *  it still has pending work to complete, we must set this flag to prevent further
 *  work from being applied to it.
 */
-(void) setBackingIdentityIsAvailable:(BOOL) isAvailable
{
    BOOL hasChanged = NO;
    @synchronized (self) {
        if (isAvailable) {
            if ([mdFeedData objectForKey:PSF_STD_NOIDENT_KEY]) {
                [mdFeedData removeObjectForKey:PSF_STD_NOIDENT_KEY];
                hasChanged = YES;
            }
        }
        else {
            if (![mdFeedData objectForKey:PSF_STD_NOIDENT_KEY]) {
                [mdFeedData setObject:[NSNumber numberWithBool:YES] forKey:PSF_STD_NOIDENT_KEY];
                hasChanged = YES;
            }
        }
        
        // - saving here is really just a convenient caching approach for startup, but there's not
        //   much we can do if it fails because usually it means the identity is gone anyway.
        if (hasChanged) {
            NSError *err = nil;
            if (![self saveConfigurationWithError:&err]) {
                NSLog(@"CS: Failed to save feed configuration after backing identity update.  %@", [err localizedDescription]);
            }
        }
    }
    
    if (hasChanged) {
        [self notifyMajorFeedUpdateHasOccurredAndShouldUpdateBadge:YES];
    }
}

/*
 *  Returns whether the identity associated with the feed exists, or this feed is only being
 *  used as a container for the moment to store pending work that hasn't completed.
 */
-(BOOL) isBackingIdentityAvailable
{
    @synchronized (self) {
        NSNumber *nExisting = [mdFeedData objectForKey:PSF_STD_NOIDENT_KEY];
        if (nExisting && [nExisting boolValue]) {
            return NO;
        }
        return YES;
    }
}

/*
 *  Let any interested parties know that this feed just modified its friendship information.
 */
-(void) fireFriendshipUpdateNotification
{
    NSDictionary *dict = [NSDictionary dictionaryWithObject:self forKey:kChatSealNotifyFeedFriendshipFeedKey];
    [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kChatSealNotifyFeedFriendshipUpdated object:nil userInfo:dict];
    }];
}

/*
 *  Return the number of messages that have been successfully posted.
 */
-(NSUInteger) numberOfMessagesPosted
{
    @synchronized (self) {
        NSNumber *nPosted = [mdFeedData objectForKey:PSF_STD_NUM_POSTED];
        if (nPosted) {
            return [nPosted unsignedIntegerValue];
        }
        return 0;
    }
}

/*
 *  When we get some notification of a feed being updated, make sure the entry progress is likewise tracked.
 */
-(void) updateSafeEntry:(NSString *) safeEntryId postProgressWithSent:(int64_t) numSent andTotalToSend:(int64_t) toSend
{
    BOOL updated = NO;
    [self verifyUpToDateProgress];
    ChatSealPostedMessageProgress *pmp = nil;
    @synchronized (self) {
        NSMutableArray *maWork = [mdFeedData objectForKey:PSF_STD_WORK_KEY];
        for (CS_postedMessageState *state in maWork) {
            if ([safeEntryId isEqualToString:state.safeEntryId]) {
                // - this data is non-persistent because it is only useful for a short time and
                //   will be recreated on-demand.
                state.numSent     = numSent;                
                state.totalToSend = toSend;
                pmp               = [[[ChatSealPostedMessageProgress alloc] initWithState:state] autorelease];
                [self setUploadStatsForSafeEntry:state.safeEntryId withNumSent:numSent andTotalToSend:toSend];
                updated           = YES;
                break;
            }
        }
    }
    
    // - when something changed, make sure that the progress is updated and the
    //   rest of the app knows it happened.
    if (updated) {
        [self recomputeProgressWithNotification:YES];
    }
    
    // - we also provide a more granular notification to allow the feed detail to show the progress
    //   without it getting out of control.
    if (pmp) {
        // - fill the missing content from the collector.
        [[self collector] fillPostedMessageProgressItem:pmp];
        
        // - post the notification.
        [self notifyObserversOfPostedMesageProgress:pmp];
    }
}

/*
 *  Increment the total number of messages received.
 */
-(void) incrementMessageCountReceived
{
    @synchronized (self) {
        NSNumber *n = [mdFeedData objectForKey:PSF_STD_NUM_RECVD];
        [mdFeedData setObject:[NSNumber numberWithUnsignedInteger:[n unsignedIntegerValue] + 1] forKey:PSF_STD_NUM_RECVD];
        [self saveDeferredUntilEndOfCycle];
    }
    [self notifyMajorFeedUpdateHasOccurredAndShouldUpdateBadge:NO];
}

/*
 *  The dervied class is starting a new pending download operation.
 */
-(void) beginPendingDownloadForTag:(NSString *) tag
{
    [self updatePendingDownloadForTag:tag withProgressRecv:0 andTotalToRecv:0];
}

/*
 *  The derived classes use this method to ensure that the overall feed progress is updated with changes.  
 */
-(void) updatePendingDownloadForTag:(NSString *) tag withProgressRecv:(int64_t) numRecv andTotalToRecv:(int64_t) toRecv
{
    if (!tag) {
        return;
    }
    
    // - ensure we have basic data storage.
    [self verifyUpToDateProgress];
    
    // - now make the necessary changes.
    @synchronized (self) {
        if (numRecv == PSF_STD_COMPLETE_STAT) {
            if ([mdDownloadStats objectForKey:tag]) {
                [mdDownloadStats removeObjectForKey:tag];
                completedDownloads++;
            }
        }
        else {
            float progress = 0.0f;
            if (toRecv) {
                progress = (float)((double)numRecv/(double)toRecv);
            }
            [mdDownloadStats setObject:[NSNumber numberWithFloat:progress] forKey:tag];
        }
    }

    // - recompute and let the rest of the app know about it.
    [self recomputeProgressWithNotification:YES];
}

/*
 *  The dervied classes use this method to ensure that the overall feed progress is updated with changes.
 */
-(void) completePendingDownloadForTag:(NSString *) tag
{
    [self updatePendingDownloadForTag:tag withProgressRecv:PSF_STD_COMPLETE_STAT andTotalToRecv:PSF_STD_COMPLETE_STAT];
}

/*
 *  Use this method to direct the collector to start working on a possible high-priority task, which
 *  is commonly an upload or download.
 */
-(void) requestHighPriorityAttention
{
    [[self collector] scheduleHighPriorityUpdateIfPossible];
}

/*
 *  Issue a notification that a big change has happened in the feed, which should be reported to the user.
 */
-(void) notifyMajorFeedUpdateHasOccurredAndShouldUpdateBadge:(BOOL) updateBadge
{
    [ChatSealFeedCollector issueUpdateNotificationForFeed:self];
    if (updateBadge) {
        [[ChatSeal applicationHub] updateFeedAlertBadge];
    }
}

/*
 *  This method is intended to mange the message import so that we can also pull interesting additional feed-related
 *  data that was passed to us with the message.
 */
-(ChatSealMessage *) importMessageIntoVault:(NSData *) dMessage andReturnOriginFeed:(ChatSealFeedLocation **) originFeed withError:(NSError **) err
{
    // - we're going to request the additional data also because it has context that can be useful later.
    NSObject *objUserData = nil;
    ChatSealMessage *csm  = nil;
    csm                   = [ChatSeal importMessageIntoVault:dMessage andSetDefaultFeed:[self feedId] andReturnUserData:&objUserData withError:err];
    if (csm) {
        // - now see if we can use the user data.
        NSArray *arrLocs           = nil;
        ChatSealFeedLocation *csfl = nil;
        if (objUserData && [objUserData isKindOfClass:[NSDictionary class]]) {
            arrLocs = [(NSDictionary *) objUserData objectForKey:PSF_STD_POST_HIST_KEY];
            csfl    = [(NSDictionary *) objUserData objectForKey:PSF_STD_SEND_FEED_KEY];
            if (originFeed) {
                *originFeed = [[csfl retain] autorelease];
            }
            
            // - if there is other user data, give the derived class a chance to see it.
            if ([self respondsToSelector:@selector(processCustomUserContentReceivedFromMessage:packedWithSeal:)]) {
                [self performSelector:@selector(processCustomUserContentReceivedFromMessage:packedWithSeal:) withObject:objUserData withObject:csm.sealId];
            }
            
            // - if we got locations, give the type a chance to process them.
            if ([arrLocs count]) {
                if ([[self typeForFeed:self] respondsToSelector:@selector(processReceivedFeedLocations:)]) {
                    [[self typeForFeed:self] performSelector:@selector(processReceivedFeedLocations:) withObject:arrLocs];
                }
            }
        }

        // ...update the remote feed locations, if possible.
        // NOTE: YOU DO NOT want to ever pass in the feed location to this method to add it to the list (I tried that)
        //       because it is not objective.  If the feed finds a message and posts something where the message was found, it will
        //       not prevent reposts of the same image from identifying bogus friends.   The only safe place to derive that information is
        //       from the message content.
        if ([arrLocs count] || csfl) {
            if (csfl) {
                NSMutableArray *maLocs = [NSMutableArray arrayWithObject:csfl];
                if (arrLocs) {
                    [maLocs addObjectsFromArray:arrLocs];
                }
                arrLocs = maLocs;
            }
            [[csm identityWithError:nil] updateFriendFeedLocations:arrLocs];
        }
        
        // - notify the collector so that can track that this occurred.
        [[self collector] trackMessageImportEvent];
    }
    return csm;
}
@end

/****************************
 CS_packedMessagePost
 ****************************/
@implementation CS_packedMessagePost
@synthesize safeEntryId;
@synthesize packedMessage;
@synthesize sealId;
@synthesize isSealOwner;

/*
 *  Initialize the object.
 */
-(id) initWithSafeEntry:(NSString *) e andSeal:(NSString *) sid andIsOwner:(BOOL) isOwned
{
    self = [super init];
    if (self) {
        safeEntryId   = [e retain];
        sealId        = [sid retain];
        isSealOwner   = isOwned;
        packedMessage = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [safeEntryId release];
    safeEntryId = nil;
    
    [sealId release];
    sealId = nil;
    
    [packedMessage release];
    packedMessage = nil;
    
    [super dealloc];
}
@end
