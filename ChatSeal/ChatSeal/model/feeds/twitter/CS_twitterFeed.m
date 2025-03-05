//
//  CS_twitterFeed.m
//  ChatSeal
//
//  Created by Francis Grolemund on 3/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Accounts/Accounts.h>
#import "CS_twitterFeed.h"
#import "CS_twitterFeed_shared.h"
#import "CS_twitterFeed_highPrio_friendsQuery.h"
#import "CS_twitterFeed_highPrio_friendRefresh.h"
#import "CS_twitterFeed_highPrio_friendValidate.h"
#import "CS_twitterFeed_highPrio_follow.h"
#import "CS_twitterFeed_highPrio_unblock.h"
#import "CS_twitterFeed_highPrio_unmute.h"
#import "CS_twitterFeed_seal_history.h"

//  THREADING-NOTES:
//  - internal locking is provided.

// - constants
static NSString         *CS_TF_LASTTOKEN_KEY        = @"lastToken";
static NSString         *CS_TF_MEDATIME_KEY         = @"mediaTimeout";
static NSString         *CS_TF_HIGHPRIO_KEY         = @"highPrioTasks";
static NSString         *CS_TF_TWEETHIST_KEY        = @"tweetHist";
static NSString         *CS_TF_ID_STR_KEY           = @"id_str";
static time_t           CS_TF_UPLOAD_DELAY          = 15;                    //  keep some time between uploads because Twitter doesn't like a flurry of quick requests.
static NSInteger        CS_TF_FRIEND_COUNT_UNSET    = -1;

@interface CS_twitterFeed (implementation) <ChatSealFeedImplementation>
-(NSString *) mediaTimeoutAsStringWithAutoTomorrow:(BOOL) autoGenTomorrow;
@end

/*************************
 CS_twitterFeed
 *************************/
@implementation CS_twitterFeed
/*
 *  Object attributes.
 */
{
    NSString                        *acAccountIdentifier;
    NSMutableDictionary             *mdConfiguration;
    BOOL                            inPostPreparation;
    CS_tapi_user                    *tapiRealtime;
    CS_twitterFeed_pending_db       *pendingDB;
    time_t                          tLastUpload;
    BOOL                            hasRetrievedMyRateLimits;
    BOOL                            shouldCheckForInvalidFriends;
    NSMutableArray                  *maHighPrioNonPersistentTasks;
    CS_twitterFeed_transient_mining *tftmMiningState;
    BOOL                            hasVerifiedMyTwitterId;
    NSInteger                       friendsCount;
}

/*
 *  Initialize the object.
 */
-(id) initWithAccountDerivedId:(NSString *)sFeedId andDelegate:(id<ChatSealFeedDelegate>)d andDictionary:(NSDictionary *)dict
{
    self = [super initWithAccountDerivedId:sFeedId andDelegate:d andDictionary:dict];
    if (self) {
        acAccountIdentifier      = nil;
        if (!mdConfiguration) {
            mdConfiguration = [[NSMutableDictionary alloc] init];
        }
        inPostPreparation               = NO;
        tapiRealtime                    = nil;
        tLastUpload                     = 0;
        hasRetrievedMyRateLimits        = NO;
        shouldCheckForInvalidFriends    = ![self isEnabled];                //  if this is enabled now, assume we've been using it and the data is recent.
        maHighPrioNonPersistentTasks    = nil;
        tftmMiningState                 = nil;
        hasVerifiedMyTwitterId          = NO;
        friendsCount                    = CS_TF_FRIEND_COUNT_UNSET;         //  this value should not be persisted so that it always optimistically shows no status error.
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
 *  Compute a unique id for a feed given the account information.
 */
+(NSString *) feedIdForAccount:(ACAccount *) account
{
    if (!account) {
        return nil;
    }
    
    NSString *sRet = @"twitter.";
    return [sRet stringByAppendingString:account.username];
}

/*
 *  Instantiate an existing feed with the provided id.
 */
+(CS_twitterFeed *) feedForAccountId:(NSString *) sFeedId andDelegate:(id<ChatSealFeedDelegate>) delegate andDictionary:(NSDictionary *) dict
{
    return [[[CS_twitterFeed alloc] initWithAccountDerivedId:sFeedId andDelegate:delegate andDictionary:dict] autorelease];
}

/*
 *  Instantiate a new feed object for the account.
 */
+(CS_twitterFeed *) feedForAccount:(ACAccount *) account andDelegate:(id<ChatSealFeedDelegate>) delegate andDictionary:(NSDictionary *) dict
{
    NSString *sFeedId      = [CS_twitterFeed feedIdForAccount:account];
    CS_twitterFeed *tfRet = [[[CS_twitterFeed alloc] initWithAccountDerivedId:sFeedId andDelegate:delegate andDictionary:dict] autorelease];
    [tfRet setACAccountIdentifier:account.identifier];
    return tfRet;
}
/*
 *  Until there are more feed types, I want to keep this error message in synch in the couple places it is used.
 */
+(NSString *) genericNoAuthError
{
    return NSLocalizedString(@"You must allow ChatSeal to use your Twitter accounts in Settings to exchange personal messages.", nil);
}

/*
 *  Assign ACAccount identifier to this feed for retrieving credentials later.
 */
-(void) setACAccountIdentifier:(NSString *) identifier
{
    @synchronized (self) {
        if (acAccountIdentifier != identifier) {
            // - whenever the account identifier changes, we must assume this is a refresh
            //   of this feed, which could require that we synch up with what an external app
            //   has been doing.
            hasRetrievedMyRateLimits = NO;
            [acAccountIdentifier release];
            acAccountIdentifier = [identifier retain];
        }
    }
}

/*
 *  Return the ACAccount identifier for credential identification.
 */
-(NSString *) acAccountIdentifier
{
    @synchronized (self) {
        return [[acAccountIdentifier retain] autorelease];
    }
}

/*
 *  Return a user-visible name for this feed instance.
 */
-(NSString *) displayName
{
    NSString *sUser = [self userId];
    return [NSString stringWithFormat:@"@%@", sUser];
}

/*
 *  Return the Internet-unique location for this feed.
 */
-(ChatSealFeedLocation *) locationWhenUsingSeal:(NSString *) sid
{
    // - we can find the twitter account just by knowing this is Twitter and having the
    //   user id.
    ChatSealFeedLocation *ret = [ChatSealFeedLocation locationForType:[self typeId] andAccount:[self userId]];
    
    // - try to add some context to this item so that someone using it can also get a feel for our last content too.
    if (sid) {
        NSArray *arrHist = [self tweetHistoryForSeal:sid andOwnerScreenName:ret.feedAccount];
        if ([arrHist count]) {
            CS_twitterFeed_history_item *hi = [arrHist lastObject];
            ret.customContext               = hi.tweetId;               //  no need for this to be complicated.  The location already stores the name.
        }
    }
    return ret;
}

/*
 *  Compute whether it makes sense to display a warning about not following anyone.
 */
-(BOOL) shouldDisplayNoFollowWarning
{
    if (![self friendsCount] && [self hasFriendsCount] && [ChatSeal hasSeals] && [[self twitterType] doesFriendshipDatabaseSupportFollowingWarning]) {
        return YES;
    }
    return NO;
}

/*
 *  Indicate whether this feed should be flagged in the UI.
 */
-(BOOL) isInWarningState
{
    if ([super isInWarningState]) {
        return YES;
    }
    if ([self isMediaUploadThrottled] || [self shouldDisplayNoFollowWarning]) {
        return YES;
    }
    return NO;
}

/*
 *  Verification status is only used when we're going to be hindered during uploads.
 */
-(BOOL) shouldDisplayVerificationStatus
{
    if (![self numericTwitterId] && [ChatSeal hasVault] && [self hasRequiredPendingActivity]) {
        return YES;
    }
    return NO;
}

/*
 *  Customized status text for Twitter feeds.
 */
-(NSString *) statusText
{
    if (![self isBackingIdentityAvailable]) {
        return NSLocalizedString(@"Feed is deleted in Settings.", nil);
    }
    else if (![self isEnabled]) {
        return NSLocalizedString(@"Feed is turned off.", nil);
    }
    else if (![self isAuthorized]) {
        return NSLocalizedString(@"Disallowed in Settings.", nil);
    }
    else if (![self isPasswordValid]) {
        return NSLocalizedString(@"Reenter password in Settings.", nil);
    }
    else if ([[self feedType] areFeedsNetworkReachable]) {
        @synchronized (self) {
            if ([self isMediaUploadThrottled]) {
                return NSLocalizedString(@"Twitter limit reached.", nil);
            }
            else if ([self shouldDisplayVerificationStatus]) {
                // - I'm not going to display anything here because the intent is that
                //   this is generally a short-lived state.   I also don't think
                //   when we're 'waiting' it is a good idea to publicize that fact.
                return [super statusText];
            }
            else if ([self shouldDisplayNoFollowWarning]) {
                return NSLocalizedString(@"You should follow a friend.", nil);
            }
        }
    }
    return [super statusText];
}

/*
 *  Customize the corrective action text for Twitter feeds.
 */
-(NSString *) correctiveText
{
    if (![self isValid] || [self isDeleted]) {
        return NSLocalizedString(@"This feed no longer exists in the Twitter configuration of Settings.", nil);
    }
    else if ([self isEnabled]) {
        if (![self isAuthorized]) {
            return [CS_twitterFeed genericNoAuthError];
        }
        else if (![self isPasswordValid]) {
            return NSLocalizedString(@"You must reenter your feed password in the Twitter configuration of Settings.", nil);
        }
        else if (![[self feedType] areFeedsNetworkReachable]) {
            if ([[self currentPostingProgress] count]) {
                return NSLocalizedString(@"You must adjust your network Settings to allow Twitter access before you can resume posting your personal messages.", nil);
            }
            else {
                return NSLocalizedString(@"You must adjust your network Settings to allow Twitter access before you can exchange personal messages.", nil);
            }
        }
        else {
            @synchronized (self) {
                if ([self isMediaUploadThrottled]) {
                    NSString *sFmt = NSLocalizedString(@"At the request of Twitter, your posts on this feed will resume after %@.", nil);
                    return [NSString stringWithFormat:sFmt, [self mediaTimeoutAsStringWithAutoTomorrow:YES]];
                }
                else if ([self shouldDisplayVerificationStatus] && [[self currentPostingProgress] count]) {
                    return NSLocalizedString(@"Message posting will proceed after this feed connects with Twitter for the first time.", nil);
                }
                else if ([self shouldDisplayNoFollowWarning]) {
                    return NSLocalizedString(@"This feed will not find personal messages until you follow your friends on Twitter.", nil);
                }
            }
        }
    }
    return [super correctiveText];
}

/*
 *  Return an appropriate feed address view for this type.
 */
-(UIFormattedFeedAddressView *) addressView
{
    UIFormattedFeedAddressView *ffavRet = [[[UIFormattedTwitterFeedAddressView alloc] init] autorelease];
    [ffavRet setAddressText:[self displayName]];
    return ffavRet;
}

/*
 *  Enable/disable the feed.
 */
-(BOOL) setEnabled:(BOOL)enabled withError:(NSError **)err
{
    BOOL wasEnabled = [super isEnabled];
    if (![super setEnabled:enabled withError:err]) {
        return NO;
    }
    
    // - when we re-enable the feed, we should re-retrieve its rate limits to ensure that
    //   they are up to date.
    // - also see if we should clear out friend metrics.
    BOOL shouldMarkFriendsAsStale = NO;
    @synchronized (self) {
        if (!wasEnabled && enabled) {
            hasRetrievedMyRateLimits = NO;
        }
        
        // ...the condition for marking friend data as stale is very precise because
        //    otherwise we risk losing it needlessly.
        if (shouldCheckForInvalidFriends && !wasEnabled && enabled) {
            shouldMarkFriendsAsStale = YES;
        }
    }
    
    // - if the feed wasn't enabled when the app was started, and we just enabled it,
    //   we need to clear out our friend metrics.
    if (shouldMarkFriendsAsStale) {
        [[self twitterType] markFriendDeficienciesAsStaleForFeed:self];
    }
    
    // - final things with the newly enabled/disabled feed.
    if (enabled != wasEnabled) {
        if (enabled) {
            // - when we just got enabled, maybe a match can be made.
            [[self twitterType] checkForCandidateAssignments];
            
            // - also see if there was an all-disabled scenario where we might be able to get content.
            [[self twitterType] checkIfOtherPendingCanBeTransferredToFeed:self];
        }
        else {
            // - if we just disabled our feed make sure any pending timeline requests are released
            //   so that other feeds can pull their ranges.
            // - technically these should be addressed when the cancelled requests return, but I'm not
            //   taking chances here.
            [[self twitterType] discardAllTimelineRequestsFromFeed:self];
            
            // ..also reassign my pending work.
            [[self twitterType] reassignPendingItemsFromFeed:self priorToDeletion:NO];
        }
    }
    
    return YES;
}

/*
 *  This API is issued by the type with the intention of requesting that the next time the feed may 
 *  perform transient operations that it processes the friends list and sends the results back to the feed.
 */
-(void) requestHighPriorityLookupForFriends:(NSArray *) friendsList
{
    if (![friendsList count]) {
        return;
    }
    [self saveHighPriorityTask:[CS_twitterFeed_highPrio_friendsQuery taskForFriends:friendsList] andStartImmediately:NO];
}

/*
 *  This API is used to allow the caller initiate a request a quick refresh the relationship of this
 *  feed to the given friend, specifically.
 *  - NOTE: this is not persisted with the feed because there is no need to rush through this refresh on the next app startup.
 */
-(void) requestHighPriorityRefreshForFriend:(NSString *) screenName
{
    if (!screenName) {
        return;
    }
    [self saveHighPriorityTask:[CS_twitterFeed_highPrio_friendRefresh taskForFriend:screenName] andStartImmediately:YES];
}

/*
 *  Remove the refresh request for the given friend.
 */
-(void) cancelHighPriorityRefreshForFriend:(NSString *) screenName
{
    if (!screenName) {
        return;
    }
    [self cancelHighPriorityTask:[CS_twitterFeed_highPrio_friendRefresh taskForFriend:screenName]];
}

/*
 *  Request that we follow the given friend.
 */
-(void) requestHighPriorityFollowForFriend:(NSString *) screenName
{
    if (!screenName) {
        return;
    }
    [self saveHighPriorityTask:[CS_twitterFeed_highPrio_follow taskForFriend:screenName] thatActsUponFriend:screenName andStartImmediately:YES];
}

/*
 *  Request that we unblock the given feed.
 */
-(void) requestHighPriorityUnblockForFriend:(NSString *) screenName
{
    if (!screenName) {
        return;
    }
    [self saveHighPriorityTask:[CS_twitterFeed_highPrio_unblock taskForFriend:screenName] thatActsUponFriend:screenName andStartImmediately:YES];
}

/*
 *  Indicates whether there is an active realtime feed that might be getting information more quickly.
 */
-(BOOL) hasRealtimeSupport
{
    @synchronized (self) {
        return [tapiRealtime isReturningData];
    }
}

/*
 *  Request that we unmute the given feed.
 */
-(void) requestHighPriorityUnmuteForFriend:(NSString *) screenName
{
    if (!screenName) {
        return;
    }
    [self saveHighPriorityTask:[CS_twitterFeed_highPrio_unmute taskForFriend:screenName] thatActsUponFriend:screenName andStartImmediately:YES];
}

/*
 *  Let this object know that friendship information has changed.
 */
-(void) notifyFriendshipsHaveBeenUpdated
{
    [[self activeMiningState] markFriendshipsAreUpdated];
}

/*
 *  When a feed is just created, it may have the opportunity pre-fill some things it shares
 *  among its peers.  Do that here.
 */
-(void) prefillSharedContentDuringCreationFromFeed:(CS_twitterFeed *) feedOther
{
    if (!feedOther) {
        return;
    }
    
    // - the only shared thing at the moment are the mining stats.
    [[self activeMiningState] prefillSharedContentDuringCreationFromMining:[feedOther activeMiningState]];
}

/*
 *  Determine if this feed could reasonably expect to schedule the given API.
 */
-(BOOL) isLikelyToScheduleAPIByName:(NSString *) name withEventDistribution:(BOOL) evenlyDistributed
{
    if (![self isViableMessagingTarget] || ![[self twitterType] areFeedsNetworkReachable]) {
        return NO;
    }
    return [self hasCapacityForAPIByName:name withEvenDistribution:evenlyDistributed andAllowAnyCategory:YES];
}

/*
 *  Request a high-priority validation to occur.
 */
-(void) requestHighPriorityValidationForFriend:(NSString *) screenName withCompletion:(void(^)(CS_tapi_user_looked_up *result)) completion
{
    if (!screenName) {
        return;
    }
    [self saveHighPriorityTask:[CS_twitterFeed_highPrio_friendValidate taskForFriend:screenName withCompletion:completion] andStartImmediately:YES];
}

/*
 *  Cancel an existing high-priority validation request.
 */
-(void) cancelHighPriorityValidationForFriend:(NSString *) screenName
{
    if (!screenName) {
        return;
    }
    [self cancelHighPriorityTask:[CS_twitterFeed_highPrio_friendValidate taskForFriend:screenName withCompletion:nil]];
}

@end

/********************************
 CS_twitterFeed (internal)
 ********************************/
@implementation CS_twitterFeed (internal)
/*
 *  Return the oauth_token for the given request, which is used to identify the
 *  owning feed instance because we don't expect the token to change from when we last issued it.
 */
+(NSString *) tokenForRequest:(NSURLRequest *) req
{
    NSDictionary *dict  = [req allHTTPHeaderFields];
    NSString     *sAuth = (NSString *) [dict objectForKey:@"Authorization"];
    if (sAuth) {
        NSRange rangeBegin = [sAuth rangeOfString:@"oauth_token=\""];
        if (rangeBegin.location != NSNotFound) {
            NSUInteger start = rangeBegin.location + rangeBegin.length - 1;
            NSRange rangeEnd = [sAuth rangeOfString:@"\"," options:0 range:NSMakeRange(start, sAuth.length - start)];
            if (rangeEnd.location != NSNotFound) {
                start = rangeBegin.location + rangeBegin.length;
                return [sAuth substringWithRange:NSMakeRange(start, rangeEnd.location - start)];
            }
        }
        else {
            // - this should never happen as long as Twitter uses OAuth for its authorization, but if something
            //   changes, look to that header because that is an important detail.
            // - without this, we need a way of identifying prior requests that are issued before the app is
            //   backgrounded.
            NSLog(@"CS-ALERT: Unexpected missing token in Twitter request.");
        }
    }
    else {
        NSLog(@"CS-ALERT: Unexpected lack of authorization in Twitter request.");
    }
    return nil;
}

/*
 *  Assign a new last token.
 */
-(void) setLastToken:(NSString *) token
{
    @synchronized (self) {
        NSString *lastToken = [mdConfiguration objectForKey:CS_TF_LASTTOKEN_KEY];
        if (token != lastToken && ![token isEqualToString:lastToken]) {
            if (token) {
                [mdConfiguration setObject:token forKey:CS_TF_LASTTOKEN_KEY];
            }
            else {
                [mdConfiguration removeObjectForKey:CS_TF_LASTTOKEN_KEY];
            }
            
            // - it is OK if this isn't saved because the last token is really just used
            //   as a way to ensure we can process pending requests after the process
            //   is restarted.  If they fall on the floor, that is Ok.
            [self saveDeferredUntilEndOfCycle];
        }
    }
}

/*
 *  Return the last token.
 */
-(NSString *) lastToken
{
    @synchronized (self) {
        return [[[mdConfiguration objectForKey:CS_TF_LASTTOKEN_KEY] retain] autorelease];
    }
}

/*
 *  Save a new media upload timeout value.
 *  - ASSUMES the lock is held.
 */
-(void) setMediaUploadTimeout:(time_t) timeout
{
    if (timeout) {
        [mdConfiguration setObject:[NSNumber numberWithUnsignedLongLong:(unsigned long long) timeout] forKey:CS_TF_MEDATIME_KEY];
        NSDate *dt = [NSDate dateWithTimeIntervalSince1970:timeout];
        NSLog(@"CS: Feed media limit throttled until %@.", [NSDateFormatter localizedStringFromDate:dt dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterLongStyle]);
    }
    else {
        [mdConfiguration removeObjectForKey:CS_TF_MEDATIME_KEY];
    }
    
    // - I'm a little torn over using this potentially unreliable save, but since this
    //   method may be called multiple times if there are many APIs outstanding, then
    //   I think it is best to risk it since the worst that can happen is we start up again
    //   and get the upload timeout again - hopefully without our Twitter access being revoked for
    //   whatever infraction caused this timeout.
    [self saveDeferredUntilEndOfCycle];
}

/*
 *  Return the media upload timeout that is currently assigned.
 */
-(time_t) mediaUploadTimeout
{
    @synchronized (self) {
        NSNumber *nTimeout = [mdConfiguration objectForKey:CS_TF_MEDATIME_KEY];
        if (nTimeout) {
            return (time_t) [nTimeout unsignedLongLongValue];
        }
        return 0;
    }
}

/*
 *  Return my own type as an official Twitter object.
 */
-(CS_feedTypeTwitter *) twitterType
{
    ChatSealFeedType *ft = [super typeForFeed:self];
    if ([ft isKindOfClass:[CS_feedTypeTwitter class]]) {
        return (CS_feedTypeTwitter *) ft;
    }
    return nil;
}

/*
 *  Returns whether this feed is currently preparing for posting.
 *  - ASSUMES the lock is held.
 */
-(BOOL) inPostPreparation
{
    return inPostPreparation;
}

/*
 *  Set the value of post preparation.
 *  - ASSUMES the lock is held.
 */
-(void) setInPostPreparation:(BOOL) ipp
{
    inPostPreparation = ipp;
}

/*
 *  Returns the value of the active realtime stream.
 *  - ASSUMES the lock is held.
 */
-(CS_tapi_user *) tapiRealtime
{
    return [[tapiRealtime retain] autorelease];
}

/*
 *  Set the value of the tapi realtime stream that is in use.
 *  - ASSUMES the lock is held.
 */
-(void) setTapiRealtime:(CS_tapi_user *) tu
{
    if (tapiRealtime != tu) {
        [tapiRealtime release];
        tapiRealtime = [tu retain];
    }
}

/*
 *  Return the active value for the configuration.
 *  - ASSUMES the lock is held.
 */
-(NSMutableDictionary *) mdConfiguration
{
    return [[mdConfiguration retain] autorelease];
}

/*
 *  Assign a new pending database.
 *  - ASSUMES the lock is held.
 */
-(void) setPendingDB:(CS_twitterFeed_pending_db *) pdb
{
    if (pendingDB != pdb) {
        [pendingDB release];
        pendingDB = [pdb retain];
    }
}

/*
 *  Return the current pending database.
 *  - ASSUMES the lock is held.
 */
-(CS_twitterFeed_pending_db *) pendingDB
{
    return [[pendingDB retain] autorelease];
}

/*
 *  Checks if we're throttled for uploads.
 */
-(BOOL) isMediaUploadThrottled
{
    // - the media timeout value is returned by Twitter (or inferred) to indicate that
    //   there is no more capacity for the user at the moment.
    if (time(NULL) < [self mediaUploadTimeout]) {
        return YES;
    }
    return NO;
}

/*
 *  This time value should be updated when an upload operation starts or stops.
 */
-(void) updateLastUploadTime
{
    @synchronized (self) {
        tLastUpload = time(NULL);
    }
}

/*
 *  Twitter appears to really dislike too many uploads occurring in a short window of time so in order
 *  to prevent it from smacking down this app, we're going to add another layer of throttle to the uploads in
 *  particular that ensure they always have some delay between successive attempts.
 */
-(BOOL) isTwitterUploadThrottled
{
    @synchronized (self) {
        if (time(NULL) - tLastUpload > CS_TF_UPLOAD_DELAY) {
            return NO;
        }
        return YES;
    }
}

/*
 *  Returns whether we've made our request for Twitter rate limits.
 */
-(BOOL) hasRetrievedMyRateLimits
{
    @synchronized (self) {
        return hasRetrievedMyRateLimits;
    }
}

/*
 *  Assigns the flag indicating we've retrieved our rate limits.
 */
-(void) setHasRetrievedMyRateLimits
{
    @synchronized (self) {
        hasRetrievedMyRateLimits = YES;
    }
}

/*
 *  This flag is only used briefly and until we get a good friend response back.
 */
-(void) resetStaleFriendFlag
{
    @synchronized (self) {
        shouldCheckForInvalidFriends = NO;
    }
}

/*
 *  Return the array of high priority tasks for the given type.
 *  - ASSUMES the lock is held.
 */
-(NSMutableArray *) highPriorityTasksAsPersistent:(BOOL) persistent
{
    if (persistent) {
        NSMutableArray *maHP = [mdConfiguration objectForKey:CS_TF_HIGHPRIO_KEY];
        if (!maHP) {
            maHP = [NSMutableArray array];
            [mdConfiguration setObject:maHP forKey:CS_TF_HIGHPRIO_KEY];
        }
        return maHP;
    }
    else {
        if (!maHighPrioNonPersistentTasks) {
            maHighPrioNonPersistentTasks = [[NSMutableArray alloc] init];
        }
        return [[maHighPrioNonPersistentTasks retain] autorelease];
    }
}

/*
 *  Save a new high priority task for this feed to process.
 *  - when saving, we will never duplicate an existing task and if an inverse of this
 *    task exists, we will delete that first.
 */
-(void) saveHighPriorityTask:(id<CS_twitterFeed_highPrio_task>)task andStartImmediately:(BOOL)startImmediately
{
    [self saveHighPriorityTask:task thatActsUponFriend:nil andStartImmediately:startImmediately];
}

/*
 *  Save a new high priority task for this feed to process.
 *  - when saving, we will never duplicate an existing task and if an inverse of this
 *    task exists, we will delete that first.
 *  - if a screen name for a friend is provided, we'll reconcile their state automatically with the task.
 */
-(void) saveHighPriorityTask:(id<CS_twitterFeed_highPrio_task>) task thatActsUponFriend:(NSString *) screenName andStartImmediately:(BOOL) startImmediately
{
    if (!task) {
        return;
    }
    
    @synchronized (self) {
        // - first figure out where we're  going to save this new task.
        NSMutableArray *maArrayForTask = nil;
        BOOL shouldSave                = NO;
        if ([task conformsToProtocol:@protocol(CS_twitterFeed_highPrioPersist_task)]) {
            // ...persist this request because it must be completed.
            maArrayForTask = [self highPriorityTasksAsPersistent:YES];
            shouldSave = YES;
        }
        else {
            // ...save in the non-persistent array.
            maArrayForTask = [self highPriorityTasksAsPersistent:NO];
        }
        
        // - first make sure that there are no inverse or equivalent operations already pending because
        //   either scenario implies we'll be doing redundant work.
        NSMutableIndexSet *mis = nil;
        for (NSUInteger i = 0; i < [maArrayForTask count]; i++) {
            // - first figure out if this item is something that we shouldn't process any longer.
            id<CS_twitterFeed_highPrio_task> oldTask = [maArrayForTask objectAtIndex:i];
            if ([oldTask isEqualToTask:task]) {
                if (!mis) {
                    mis = [NSMutableIndexSet indexSet];
                }
                [mis addIndex:i];
            }
        }
        
        // - remove any that we identified.
        if ([mis count]) {
            [maArrayForTask removeObjectsAtIndexes:mis];
        }
        
        // - now add the task to the array if we haven't nulled it out with an inverse operation.
        [maArrayForTask addObject:task];
        
        // - if this is a persistent task, we need to save it.
        if (shouldSave) {
            // - this should be an immediate save because these kinds of operations are intended to be reliably
            //   scheduled, usually for the purpose of correcting a problem with the feed.
            [self saveConfigurationWithError:nil];
        }
    }
    
    // - when a friend's name is provided, we'll send the task up through the type to
    //   reconcile the current user state.
    if (screenName) {
        [[self twitterType] reconcileKnownFriendshipStateFromFeed:self toFriend:screenName withPendingTask:task];
    }
    
    // - when asked to start immediately, kick the collector.
    if (startImmediately) {
        [[self collector] scheduleHighPriorityUpdateIfPossible];
    }
}

/*
 *  Find and cancel a task.
 */
-(void) cancelHighPriorityTask:(id<CS_twitterFeed_highPrio_task>) task
{
    if (!task) {
        return;
    }
    
    @synchronized (self) {
        // - first determine where to look.
        NSMutableArray *maArrayForTask = nil;
        BOOL shouldSave                = NO;
        if ([task conformsToProtocol:@protocol(CS_twitterFeed_highPrioPersist_task)]) {
            // ...persist this request because it must be completed.
            maArrayForTask = [self highPriorityTasksAsPersistent:YES];
            shouldSave = YES;
        }
        else {
            // ...save in the non-persistent array.
            maArrayForTask = [self highPriorityTasksAsPersistent:NO];
        }

        // - now see if we can find the old task.
        for (NSUInteger i = 0; i < [maArrayForTask count]; i++) {
            id<CS_twitterFeed_highPrio_task> curTask = [maArrayForTask objectAtIndex:i];
            if ([curTask isEqualToTask:task]) {
                [maArrayForTask removeObjectAtIndex:i];
                if (shouldSave) {
                    // - this should be an immediate save because these kinds of operations are intended to be reliably
                    //   scheduled, usually for the purpose of correcting a problem with the feed.
                    [self saveConfigurationWithError:nil];
                }
                break;
            }
        }
    }
}

/*
 *  Return the history object.
 *  - ASSUMES the lock is held.
 */
-(CS_twitterFeed_seal_history *) sealTweetHistory
{
    CS_twitterFeed_seal_history *hist = [mdConfiguration objectForKey:CS_TF_TWEETHIST_KEY];
    if (!hist) {
        hist = [[[CS_twitterFeed_seal_history alloc] init] autorelease];
        [mdConfiguration setObject:hist forKey:CS_TF_TWEETHIST_KEY];
    }
    return [[hist retain] autorelease];
}

/*
 *  Add a new producer history item for the given seal.
 */
-(void) addPostedTweetHistoryForSeal:(NSString *) sealId withTweet:(NSString *) tweetId andOwnerScreenName:(NSString *) screenName andAsSealOwner:(BOOL) isOwner
{
    @synchronized (self) {
        [[self sealTweetHistory] addPostedTweetHistoryForSeal:sealId withTweet:tweetId andOwnerScreenName:screenName andAsSealOwner:isOwner];
    }
}

/*
 *  Add a new consumer history item for the given seal.
 */
-(void) addConsumerHistoryForSeal:(NSString *) sealId withTweet:(NSString *) tweetId andOwnerScreenName:(NSString *) screenName
{
    @synchronized (self) {
        [[self sealTweetHistory] addConsumerHistoryForSeal:sealId withTweet:tweetId andOwnerScreenName:screenName];
    }
}

/*
 *  Return the tweet history for the given seal.
 */
-(NSArray *) tweetHistoryForSeal:(NSString *) sealId andOwnerScreenName:(NSString *) screenName
{
    @synchronized (self) {
        return [[self sealTweetHistory] historyForSeal:sealId andOwnerScreenName:screenName];
    }
}

/*
 *  Return the last tweet id that we received from the seal owner.
 */
-(CS_twitterFeed_history_item *) priorTweetFromOwnerOfSeal:(NSString *) sealId
{
    @synchronized (self) {
        return [[self sealTweetHistory] priorTweetFromOwnerOfSeal:sealId];
    }
}

/*
 *  Discard a consumer history item.
 */
-(void) discardConsumerHistoryForSeal:(NSString *) sealId
{
    @synchronized (self) {
        [[self sealTweetHistory] discardConsumerHistoryForSeal:sealId];
    }
}

/*
 *  When we deliver items, use this extended version of the API as opposed to the base so that we can track history
 *  when it makes sense.
 */
-(void) moveDeliveringSafeEntry:(NSString *)safeEntryId asTweetId:(NSString *) tweetId toCompleted:(BOOL)isCompleted
{
    // - only when we're completed and this is a seal owner will we add some history here.
    if (isCompleted) {
        CS_postedMessage *pm = [[self collector] postedMessageForSafeEntry:safeEntryId];
        if (pm) {
            //  ... you don't need to save here because the base move will save later.
            [self addPostedTweetHistoryForSeal:pm.sealId withTweet:tweetId andOwnerScreenName:[self userId] andAsSealOwner:pm.isSealOwned];
        }
    }
    
    // - no matter what, we'll always go up through the base so that the feed knows it completed its task.
    [super moveDeliveringSafeEntry:safeEntryId toCompleted:isCompleted];
}

/*
 *  Return the object that manages all proactive tweet data mining for this feed.
 */
-(CS_twitterFeed_transient_mining *) activeMiningState
{
    @synchronized (self) {
        if (!tftmMiningState) {
            NSURL *u        = [self feedDirectoryURL];
            tftmMiningState = [[CS_twitterFeed_transient_mining alloc] initWithFeedDirectory:u];
        }
        return [[tftmMiningState retain] autorelease];
    }
}

/*
 *  Return the list of friendship states for this feed.
 */
-(NSDictionary *) statesForAllReachableFriends
{
    return [[self twitterType] statesForAllReachableFriendsInFeed:self];
}

/*
 *  Return the numeric id representation of the Twitter account.
 */
-(NSString *) numericTwitterId
{
    @synchronized (self) {
        return [mdConfiguration objectForKey:CS_TF_ID_STR_KEY];
    }
}

/*
 *  Assign the numeric id representation of the Twitter account.
 */
-(void) setNumericTwitterId:(NSString *) id_str
{
    BOOL newIdAdded = NO;
    @synchronized (self) {
        if (id_str) {
            if (![mdConfiguration objectForKey:CS_TF_ID_STR_KEY]) {
                newIdAdded = YES;
            }
            hasVerifiedMyTwitterId = YES;
            [mdConfiguration setObject:id_str forKey:CS_TF_ID_STR_KEY];
            
            // - save this immediately because it is important to performing uploads.
            [self saveConfigurationWithError:nil];
        }
        else {
            hasVerifiedMyTwitterId = NO;
            [mdConfiguration removeObjectForKey:CS_TF_ID_STR_KEY];
            [self saveDeferredUntilEndOfCycle];
        }
    }
    
    //  - if we just added a new id, make sure any high-priority uploads are processed because
    //    they would have been blocked up until now.
    if (newIdAdded) {
        [self notifyMajorFeedUpdateHasOccurredAndShouldUpdateBadge:NO];
        [[self collector] scheduleHighPriorityUpdateIfPossible];
    }
}

/*
 *  Return whether we've yet verified the feed's associated Twitter numeric id or not
 *  - this happens once per app initialization just to be certain of its content.
 */
-(BOOL) hasVerifiedMyTwitterId
{
    @synchronized (self) {
        return hasVerifiedMyTwitterId;
    }
}

/*
 *  Assign the Twitter id verification flag.
 */
-(void) setHasVerifiedMyTwitterId
{
    @synchronized (self) {
        hasVerifiedMyTwitterId = YES;
    }
}

/*
 *  Coordinate all user timeline requests through the type to prevent redundant requests by feeds.
 */
-(BOOL) isUserTimelineRequestAllowed:(CS_tapi_statuses_user_timeline *) api
{
    return [[self twitterType] isUserTimelineRequest:api allowedForFeed:self];
}

/*
 *  Every user timeline request needs to be completed through the type so that it can adjust its conflict prevention records.
 */
-(void) completeUserTimelineRequest:(CS_tapi_statuses_user_timeline *) api
{
    return [[self twitterType] completeUserTimelineRequest:api fromFeed:self];
}

/*
 *  Assign the friends count.
 */
-(void) setFriendsCount:(NSInteger) count
{
    BOOL shouldNotify = NO;
    @synchronized (self) {
        if (count != friendsCount && (friendsCount != CS_TF_FRIEND_COUNT_UNSET || !count)) {
            shouldNotify = YES;
        }
        friendsCount = count;
    }
    
    // - the friends count changed so that means the feed has new content.
    if (shouldNotify) {
        [ChatSealFeedCollector issueUpdateNotificationForFeed:self];
        [[ChatSeal applicationHub] updateFeedAlertBadge];        
    }
}

/*
 *  Indicates whether we've received a friends count yet.
 */
-(BOOL) hasFriendsCount
{
    @synchronized (self) {
        return (friendsCount == CS_TF_FRIEND_COUNT_UNSET) ? NO : YES;
    }
}

/*
 *  Return the active friends count.
 */
-(NSInteger) friendsCount
{
    @synchronized (self) {
        return friendsCount;
    }
}
@end

/**************************************
 CS_twitterFeed (implementation)
 **************************************/
@implementation CS_twitterFeed (implementation)
/*
 *  Return the current media timeout value as a string.
 */
-(NSString *) mediaTimeoutAsStringWithAutoTomorrow:(BOOL) autoGenTomorrow
{
    time_t mut           = [self mediaUploadTimeout];
    if (!mut) {
        if (autoGenTomorrow) {
            // - this should not happen as a rule, but just to
            mut = time(NULL) + (60 * 60 * 24);
        }
        else {
            return nil;
        }
    }
    NSDate *dt           = [NSDate dateWithTimeIntervalSince1970:mut];
    NSString *sFormatted = nil;
    NSCalendar *cal      = [NSCalendar currentCalendar];
    NSUInteger medDay    = [cal ordinalityOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitEra forDate:dt];
    NSUInteger nowDay    = [cal ordinalityOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitEra forDate:[NSDate date]];
    if (medDay == nowDay) {
        sFormatted = [NSDateFormatter localizedStringFromDate:dt dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterLongStyle];
    }
    else {
        sFormatted = [NSDateFormatter localizedStringFromDate:dt dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle];
    }
    return sFormatted;
}

/*
 *  If there is anything important in the pipeline, return a YES.
 */
-(BOOL) hasHighPriorityWorkToPerform
{
    if ([super hasHighPriorityWorkToPerform]) {
        return YES;
    }
        
    // - any pending message items to evaluate?
    if ([self hasHighPriorityDownloads]) {
        return YES;
    }
    
    @synchronized (self) {
        // - do we need to check out our id?
        if (![self numericTwitterId] && !hasVerifiedMyTwitterId) {
            return YES;
        }
    
        // - has the type offloaded any of its friend lookup work onto us?
        if ([[self highPriorityTasksAsPersistent:YES] count]) {
            return YES;
        }
        
        if ([[self highPriorityTasksAsPersistent:NO] count]) {
            return YES;
        }        
    }
    
    // - any mining to complete?
    if ([[self activeMiningState] hasHighPriorityWorkToPerformInFeed:self]) {
        return YES;
    }
    
    return NO;
}

/*
 *  The idea here is that the Twitter feed identifies outstanding work it would like to perform if it had
 *  the opportunity and then requests permission to do it, if it can.   We have to assume that we may not
 *  accomplish all our requested tasks in one cycle.
 */
-(BOOL) processFeedRequestsInThrottleCategory:(cs_cnt_throttle_category_t) category onlyAsHighPriority:(BOOL)onlyHighPrio
{
    //  !!REMEMBER!!
    //  - The only time to ever return NO from this method is when the request was throttled.
    
    switch (category) {
        case CS_CNT_THROTTLE_UPLOAD:
            return [self processFeedRequestsForUpload];
            break;
            
        case CS_CNT_THROTTLE_DOWNLOAD:
            return [self processFeedRequestsForDownload];
            break;
            
        case CS_CNT_THROTTLE_REALTIME:
            return [self processFeedRequestsForRealtime];
            break;
            
        case CS_CNT_THROTTLE_TRANSIENT:
            return [self processFeedRequestsForTransientOnlyInHighPriority:onlyHighPrio];
            break;
            
        default:
            return YES;         //  assume no throttle for unknown types.
    }
}

/*
 *  Return whether there is more work to be done with this feed.
 */
-(BOOL) hasRequiredPendingActivity
{
    if ([super hasRequiredPendingActivity]) {
        return YES;
    }
    return NO;
}

/*
 *  The base class has loaded extra configuration for this object.
 *  - NO lock required because this happens during initialization.
 */
-(void) customConfigurationHasBeenLoaded:(NSDictionary *) dict
{
    if (!mdConfiguration) {
        mdConfiguration = [[NSMutableDictionary alloc] init];
    }
    
    // -  pull-in all the content from the dictionary, but ensure mutability
    //    is retained.
    [mdConfiguration removeAllObjects];
    [mdConfiguration addEntriesFromDictionary:dict];
}

/*
 *  Return the current custom configuration so we can save this feed to disk.
 */
-(NSDictionary *) customConfiguration
{
    return [[mdConfiguration retain] autorelease];
}

/*
 *  Make sure the pending download progress reflects the current state of the app.
 */
-(void) configurePendingDownloadProgress
{
    [self configurePendingTweetProgress];
}

/*
 *  Determine if this feed was the one that generated the request.
 *  - This method is used to recreate an API that was running before the app exited and may
 *    have been running in the background.  Generally, this is never called and is somewhat 
 *    expensive for general operation.
 */
-(CS_netFeedAPIRequest *) canGenerateAPIRequestFromRequest:(NSURLRequest *)req
{
    // - it is important to always start by identifying the feed first and then the API or
    //   the scanning process for the API could be wasted, which is bad if we have lots of APIs.
    // - for Twitter feeds, the feed ownership is linked to the OAuth token.
    NSString *reqToken = [CS_twitterFeed tokenForRequest:req];
    if (!reqToken) {
        return nil;
    }
    
    //  ...the last token may not be set if we never sent any requests.
    NSString *feedToken = [self lastToken];
    if (!feedToken) {
        // - I toyed with the idea of generating a last token on the fly by manufacturing a request, but
        //   that seems like overkill considering the fact that under nearly every scenario, if we sent
        //   the request the token will exist.  If for some reason the token does not exist because
        //   of a previous failure to save, I'm not sure I want this feed processing the result anyway.
        return nil;
    }
    
    // - the tokens are not equal, so this feed won't be the recipient.
    if (![reqToken isEqualToString:feedToken]){
        return nil;
    }
    
    // - now scan the APIs to see if one of them matches for this purpose.
    CS_netFeedAPI *api = [self apiForExistingRequest:req];
    if (api) {
        return [CS_netFeedAPIRequest requestForFeed:self andAPI:api];
    }
    
    return nil;
}

/*
 *  Determine if this feed was the one that generated the request, but try to look at the
 *  request data as an indicator.
 */
-(CS_netFeedAPIRequest *) canApproximateAPIRequestFromOrphanedRequest:(NSURLRequest *)req
{
    CS_netFeedAPI *api = [self apiForExistingRequest:req];
    if ([api isKindOfClass:[CS_tapi_statuses_update_with_media class]]) {
        // - for uploads we're going to see if it is possible that the
        //   safe id is something we're tracking ourselves.
        CS_tapi_statuses_update_with_media *updm = (CS_tapi_statuses_update_with_media *) api;
        if ([self isTrackingSafeEntry:updm.safeEntryId]) {
            return [CS_netFeedAPIRequest requestForFeed:self andAPI:api];
        }
    }
    return nil;
}

/*
 *  Close the feed and release all its content.
 */
-(void) close
{
    @synchronized (self) {
        [super close];
        
        [acAccountIdentifier release];
        acAccountIdentifier = nil;
        
        [mdConfiguration release];
        mdConfiguration = nil;
        
        [tapiRealtime release];
        tapiRealtime = nil;
        
        [pendingDB release];
        pendingDB = nil;
                        
        [maHighPrioNonPersistentTasks release];
        maHighPrioNonPersistentTasks = nil;
        
        [tftmMiningState release];
        tftmMiningState = nil;
    }
}

/*
 *  This method allows us to check service throttling in the feeds on a per-category basis, which
 *  is useful when we're just limiting upload capacity.
 */
-(BOOL) isFeedServiceThrottledInCategory:(cs_cnt_throttle_category_t)category
{
    if ([super isFeedServiceThrottledInCategory:category]) {
        return YES;
    }
    
    // - only check for upload capacity problems, which could occur if the media timeout
    //   must expire first.
    if (category == CS_CNT_THROTTLE_UPLOAD) {
        if ([self isMediaUploadThrottled]) {
            return YES;
        }
    }
    return NO;
}

/*
 *  Take this opportunity to coordinate with the type and get credentials for the API.
 */
-(BOOL) pipelineAuthenticateAPI:(CS_netFeedAPI *)api
{
    // - we're never going to support anything but proper Twitter classes.
    if (![api isKindOfClass:[CS_twitterFeedAPI class]]) {
        return NO;
    }
    
    // - now I need to contact the type and ask it for an account.
    ChatSealFeedType *ft = [self typeForFeed:self];
    if (!ft || ![ft isKindOfClass:[CS_feedTypeTwitter class]]) {
        return NO;
    }
    
    CS_feedTypeTwitter *tft = (CS_feedTypeTwitter *) ft;
    ACAccount *account       = [tft accountForFeed:self];
    if (!account) {
        return NO;
    }
    
    // - set the credentials on the API with the account information.
    [(CS_twitterFeedAPI *) api setCredentials:account];
    return YES;
}

/*
 *  When the API is scheduled for delivery in the session, this API is called, which for background
 *  sessions should be the best indication that the background daemon is now tracking it reliably.
 */
-(void) pipelineAPIWasScheduled:(CS_netFeedAPI *)api
{
    // - Every time this method is called, I'm going to save off the oauth_token so that we can identify this feed easily later.
    // - This must occur after scheduling because we know that the request has already been generated so it will have an Oauth
    //   token.
    NSString *newReqToken = [CS_twitterFeed tokenForRequest:[api requestWithError:nil]];
    if (newReqToken) {
        self.lastToken = newReqToken;
    }
    
    // - custom behavior per-category
    // - use the 'throttleCategory', not the 'centralThrottleCategory' because the former will let us know
    //   which of our internal modules created the request, not where it was throttled.
    switch (api.throttleCategory) {
        case CS_CNT_THROTTLE_UPLOAD:
            [self apiWasScheduledForUpload:api];
            break;
            
        default:
            break;
    }    
}

/*
 *  Progress in a given API is reported here.
 */
-(void) pipelineAPIProgress:(CS_netFeedAPI *) api
{
    if ([api isKindOfClass:[CS_tapi_statuses_update_with_media class]]) {
        // - track the progress of every post because it will allow us to reflect it in the UI.
        CS_tapi_statuses_update_with_media *tuwm = (CS_tapi_statuses_update_with_media *) api;
        [self updateSafeEntry:tuwm.safeEntryId postProgressWithSent:api.bytesSent andTotalToSend:api.totalBytesToSend];
    }
    else if ([api isKindOfClass:[CS_tapi_download_image class]]) {
        // - ensure we track the active progress for the item.
        [self updateProgressForPendingItemAPI:(CS_tapi_download_image *) api];
        
        // - verify requires we track its state a bit more.
        if ([api isKindOfClass:[CS_tapi_download_image_toverify class]]) {
            CS_tapi_download_image_toverify *tdiv = (CS_tapi_download_image_toverify *) api;
            if ([tdiv isConfirmed] && ![tdiv hasBeenAnalyzed]) {
                [self updateMessageStateIfPossibleForVerifyAPI:tdiv];
            }
        }
    }
}

/*
 *  Manage the completion of the API, which should include data.
 */
-(void) pipelineDidCompleteAPI:(CS_netFeedAPI *) api
{
    if (![api isKindOfClass:[CS_twitterFeedAPI class]]) {
        NSLog(@"CS-ALERT: Unexpected API type received for Twitter resolution.  %@", [[api class] description]);
        return;
    }

    // - check for password problems.
    CS_twitterFeedAPI *tapi = (CS_twitterFeedAPI *) api;
    if (![tapi isAPISuccessful] && tapi.HTTPStatusCode == CS_TWIT_UNAUTHORIZED && [(CS_twitterFeedAPI *) tapi shouldNotAuthorizedBeInterpretedAsPasswordFailure]) {
        // - when our password expires here, try to get the work completed elsewhere.
        [[self twitterType] reassignPendingItemsFromFeed:self priorToDeletion:NO];
        [self setPasswordExpired:YES];
    }
    else if (![tapi isAPISuccessful] && tapi.HTTPStatusCode == CS_TWIT_THROTTLED) {
        // - when we receive this particular response, we need to back off or risk
        //   pissing off Twitter.   At this point, the right choice is to tell the
        //   feed's API factory to throttle requests for a full cycle.
        [self throttleAPIForOneCycle:api];
    }
    else if (![self isPasswordValid]) {
        // - if we got this far and our password was previously expired, un-expire it.
        [self setPasswordExpired:NO];
        
        // - and see if there is an opportunity to get pending content now.
        [[self twitterType] checkIfOtherPendingCanBeTransferredToFeed:self];
    }

    // - redirect custom handling to the throttle category that issued it, which must ALWAYS happen
    //   or we'll leak the items.
    switch (api.throttleCategory) {
        case CS_CNT_THROTTLE_UPLOAD:
            [self completeFeedRequestForUpload:(CS_twitterFeedAPI *) api];
            break;
            
        case CS_CNT_THROTTLE_TRANSIENT:
            [self completeFeedRequestForTransient:(CS_twitterFeedAPI *) api];
            break;
            
        case CS_CNT_THROTTLE_DOWNLOAD:
            [self completeFeedRequestForDownload:(CS_twitterFeedAPI *) api];
            break;
            
        case CS_CNT_THROTTLE_REALTIME:
            [self completeFeedRequestForRealtime:(CS_twitterFeedAPI *) api];
            break;
            
        default:
            NSLog(@"CS-ALERT: Unexpected API category received.");
            break;
    }
}

/*
 *  When posting a message, this optional implementation method can be used to include our own stuff
 *  in there.
 */
-(void) addCustomUserContentForMessage:(NSMutableDictionary *)mdUserData packedWithSeal:(NSString *)sealId
{
    BOOL needsFilter = ![ChatSeal canShareFeedsDuringExchanges];
    NSArray *arr = [self tweetHistoryForSeal:sealId andOwnerScreenName:needsFilter ? [self userId] : nil];
    if ([arr count]) {
        [mdUserData setObject:arr forKey:CS_TF_TWEETHIST_KEY];
    }
}

/*
 *  When we get new messages
 */
-(void) processCustomUserContentReceivedFromMessage:(NSDictionary *) dUserData packedWithSeal:(NSString *) sealId
{
    NSArray *arr = [dUserData objectForKey:CS_TF_TWEETHIST_KEY];
    if (arr) {
        [[self twitterType] processPostedMessageHistory:arr fromSourceFeed:self];
    }
}
@end