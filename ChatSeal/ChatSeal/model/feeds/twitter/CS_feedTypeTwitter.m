//
//  CS_feedTypeTwitter.m
//  ChatSeal
//
//  Created by Francis Grolemund on 3/24/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Accounts/Accounts.h>
#import "ChatSealFeedCollector.h"
#import "CS_feedTypeTwitter.h"
#import "CS_twitterFeed.h"
#import "CS_feedShared.h"
#import "CS_tweetTrackingDB.h"
#import "CS_feedCollectorUtil.h"
#import "ChatSeal.h"
#import "CS_tapi_shared.h"
#import "CS_twitterFriendshipState.h"
#import "CS_twitterFeed_history_item.h"
#import "CS_twitterFeed_shared.h"
#import "CS_twitterFeed_pending_db.h"
#import "UITwitterFriendAdditionViewController.h"

//  THREADING-NOTES:
//  - internal locking is provided.

// - types
struct _status_def {
    NSString *resource;
    NSString *api;
    NSString *localClass;
};

// - constants.
NSString *kChatSealFeedTypeTwitter = @"com.realproven.ps.feed.twitter";
static NSString *CS_FTW_DB_KEY     = @"db";

// - locals
static NSURL *uTwitterTypeBase     = nil;
static NSString *sTweetDBName      = nil;

// - forward declarations
@interface CS_feedTypeTwitter (internal) <CS_twitterFriendshipStateDelegate>
-(void) recomputeFeedArrayWithAccountStore:(ACAccountStore *) as andType:(ACAccountType *) at andReturningToDelete:(NSArray **) arrToDelete;
-(BOOL) reloadExistingFeeds;
-(BOOL) reloadExistingFeedsIfNecessary;
+(NSURL *) twitterTypeURL;
+(NSURL *) tweetDBURL;
-(CS_tweetTrackingDB *) tweetDBWithError:(NSError **) err;
-(BOOL) saveCurrentTweetDBWithError:(NSError **) err;
-(CS_twitterFriendshipState *) myFriends;
-(BOOL) tryToProcessCandidateTweet:(NSString *) tweetId withContext:(CS_candidateTweetContext *) ctx usingFeeds:(NSArray *) feeds;
+(CS_tapi_tweetRange *) rangeFromUserTimelineAPI:(CS_tapi_statuses_user_timeline *) api;
-(void) checkForFollowingStateDrivers;
@end

/************************
 CS_feedTypeTwitter
 ************************/
@implementation CS_feedTypeTwitter
/*
 *  Object attributes.
 */
{
    BOOL                      isQueryPending;
    BOOL                      isQueried;
    BOOL                      isAuthorized;
    BOOL                      isValid;
    NSMutableArray            *maFeeds;
    BOOL                      hasLoadedInitialFeeds;
    CS_tweetTrackingDB        *tweetDB;
    CS_twitterFriendshipState *tfsFriends;
    BOOL                      cachedHasSeals;
    BOOL                      cachedShouldShowFollowWarning;
}

/*
 *  This routine is intended to centralize all the Twitter host-related checks.
 */
+(BOOL) isValidTwitterHost:(NSString *) sHost
{
    static NSString *known_twitter_hosts[] = {@"twitter.com",
                                              @"twimg.com",
                                              nil};
    
    if (!sHost) {
        return NO;
    }
    sHost = [sHost lowercaseString];
    for (NSUInteger i = 0; known_twitter_hosts[i]; i++) {
        NSRange r = [sHost rangeOfString:known_twitter_hosts[i]];
        if (r.location != NSNotFound && r.location + r.length == sHost.length) {
            return YES;
        }
    }
    return NO;
}

/*
 *  Initialize the object.
 */
-(id) initWithDelegate:(id<ChatSealFeedTypeDelegate>) d
{
    self = [super initWithDelegate:d];
    if (self) {
        isQueryPending                = NO;
        isQueried                     = NO;
        isAuthorized                  = NO;
        isValid                       = NO;
        hasLoadedInitialFeeds         = NO;
        maFeeds                       = [[NSMutableArray alloc] init];
        tweetDB                       = nil;
        tfsFriends                    = nil;
        cachedHasSeals                = [ChatSeal hasSeals];
        cachedShouldShowFollowWarning = NO;
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
 *  Return a textual description of this feed type.
 */
-(NSString *) description
{
    return NSLocalizedString(@"Twitter", nil);
}

/*
 *  Return the string constant type for this class.
 */
-(NSString *) typeId
{
    return kChatSealFeedTypeTwitter;
}

/*
 *  This host will be used to determine network availability.
 */
-(NSString *) typeHostName
{
    return @"twitter.com";
}

/*
 *  Return whether this type of feed is configured and stored in the common settings.
 */
-(BOOL) isManagedBySettings
{
    return YES;
}

/*
 *  Returns whether this feed has been authorized by the system.
 */
-(BOOL) isAuthorized
{
    @synchronized (self) {
        return (isValid && isAuthorized) || !isQueried;
    }
}

/*
 *  Refresh the authorization state on this object with the given collector.
 */
-(void) refreshAuthorizationWithCompletion:(void (^)(void)) completionBlock
{
    ACAccountStore *as = [[self collectorForFeedType:self] accountStore];
    if (as) {
        @synchronized (self) {
            // - don't prevent simultaneous queries.
            if (isQueryPending) {
                if (completionBlock) {
                    completionBlock();
                }
                return;
            }
            isValid        = YES;
            isQueryPending = YES;
            if (!tfsFriends) {
                tfsFriends          = [[CS_twitterFriendshipState alloc] init];
                tfsFriends.delegate = self;
            }
        }
        
        ACAccountType *at  = [as accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
        [as requestAccessToAccountsWithType:at options:nil completion:^(BOOL granted, NSError *err) {
            @synchronized (self) {
                isQueryPending = NO;
                isQueried      = YES;
                isAuthorized   = granted;
                if (!granted && err) {
                    NSLog(@"CS: Failed to receive Twitter account access.  %@", [err localizedDescription]);
                }
            }

            // - recompute the feed array outside the lock because we need to make calls into the
            //   rest of the hierarchy.
            NSArray *arrToDelete = nil;
            [self recomputeFeedArrayWithAccountStore:as andType:at andReturningToDelete:&arrToDelete];
            
            // - figure out if any feeds to be deleted have pending tweets.
            if ([arrToDelete count]) {
                @synchronized (self) {
                    CS_tweetTrackingDB *ttdb = [self tweetDBWithError:nil];
                    for (ChatSealFeed *feed in arrToDelete) {
                        [ttdb deletePendingTweetsWithContext:[feed feedId]];
                    }
                    [self saveCurrentTweetDBWithError:nil];
                }
            }
            
            // - when feeds must be deleted, ensure it happens outside this object's lock to maintain consistency
            //   with the prescribed threading rules.
            for (ChatSealFeed *feed in arrToDelete) {
                [[self collectorForFeedType:self] cancelAllRequestsForFeed:feed];
                [self discardAllTimelineRequestsFromFeed:(CS_twitterFeed *) feed];
                [[self myFriends] discardAllLocalUserStateForFeed:feed];
                [self reassignPendingItemsFromFeed:(CS_twitterFeed *) feed priorToDeletion:YES];
                [feed destroyFeedPersistentData];
            }
            
            // - see if we can shift any candidates to any of the open feeds.
            [self checkForCandidateAssignments];
            
            // - this completion cannot occur within the critical section or we'll deadlock
            //   because the collector must always take the first lock, not us.
            if (completionBlock) {
                completionBlock();
            }
        }];
    }
    else {
        if (completionBlock) {
            completionBlock();
        }
    }
}

/*
 *  Return the feeds associated with this type.
 */
-(NSArray *) feeds
{
    @synchronized (self) {
        if (![self reloadExistingFeedsIfNecessary]) {
            return nil;
        }
        return [NSArray arrayWithArray:maFeeds];
    }
}

/*
 *  The purpose of this method is to analyze the supplied request and see if it came from us and if 
 *  it did then return the necessary objects to handle its resolution.
 */
-(CS_netFeedAPIRequest *) canGenerateAPIRequestFromRequest:(NSURLRequest *) req
{
    NSArray *arrToCheck = nil;
    @synchronized (self) {
        NSString *sHost               = req.URL.host;
        if (![CS_feedTypeTwitter isValidTwitterHost:sHost]) {
            return nil;
        }
        
        if (![self reloadExistingFeedsIfNecessary]) {
            return nil;
        }
        
        arrToCheck = [NSArray arrayWithArray:maFeeds];
    }
    
    // - if we generated this, we should find it.
    for (CS_twitterFeed *tf in arrToCheck) {
        CS_netFeedAPIRequest *reqAPI = [tf canGenerateAPIRequestFromRequest:req];
        if (reqAPI) {
            return reqAPI;
        }
    }
    
    // - under very rare circumstances - like the Oauth token changed while this
    //   process was dead, we'll give the feeds one last chance to identify it and
    //   save the work they started.
    for (CS_twitterFeed *tf in arrToCheck) {
        CS_netFeedAPIRequest *reqAPI = [tf canApproximateAPIRequestFromOrphanedRequest:req];
        if (reqAPI) {
            return reqAPI;
        }
    }
    
    return nil;
}

/*
 *  We only support saving the feed data when this type is valid.
 *  - it is OK to save when the type is not authorized because we may want
 *    to move its content off.
 */
-(BOOL) canSaveFeed:(ChatSealFeed *)feed
{
    @synchronized (self) {
        return isQueried && isValid;
    }
}

/*
 *  Return a factory object that is suitable for throttling the Twitter feed requests.
 *  - Twitter allows throttling to be per-account, which is also the way we're defining a 'feed' here, so
 *    each feed has its own factory instance.
 */
-(CS_netThrottledAPIFactory *) apiFactoryForFeed:(ChatSealFeed *)feed
{
    CS_netThrottledAPIFactory *factory             = [[CS_netThrottledAPIFactory alloc] initWithNetworkThrottle:[[self collectorForFeedType:self] centralThrottle]];
    [factory setThrottleLimitAdjustmentPercentage:0.5f];           // - don't consume all the device's possible service capacity.
    
    static const NSTimeInterval PSFTT_TI_STD_WINDOW = (15.0 * 60.0);
    
    // - add all the classes and their limits as defined by the Twitter documentation.
    //   NOTE: uploading is very special because if there are two requests simultaneously, we'll get into big problems with the service.  Therefore
    //         we're limiting it to 1 at a time and adding additional throttling inside the feed implementation.
    [factory addAPIThrottleDefinitionForClass:[CS_tapi_statuses_show class] inCategory:CS_CNT_THROTTLE_TRANSIENT withLimit:180 perInterval:PSFTT_TI_STD_WINDOW];
    [factory addAPIThrottleDefinitionForClass:[CS_tapi_user class] inCategory:CS_CNT_THROTTLE_REALTIME withConcurrentLimit:1];
    [factory addAPIThrottleDefinitionForClass:[CS_tapi_download_image class] inCategory:CS_CNT_THROTTLE_DOWNLOAD withLimit:15 perInterval:PSFTT_TI_STD_WINDOW];
    [factory addAPIThrottleDefinitionForClass:[CS_tapi_statuses_update_with_media class] inCategory:CS_CNT_THROTTLE_UPLOAD withConcurrentLimit:1];                      //  there can _never_ be more than 1
    [factory addAPIThrottleDefinitionForClass:[CS_tapi_download_image_toverify class] inCategory:CS_CNT_THROTTLE_TRANSIENT withLimit:180 perInterval:PSFTT_TI_STD_WINDOW];
    [factory addAPIThrottleDefinitionForClass:[CS_tapi_users_lookup class] inCategory:CS_CNT_THROTTLE_TRANSIENT withLimit:180 perInterval:PSFTT_TI_STD_WINDOW];
    [factory addAPIThrottleDefinitionForClass:[CS_tapi_application_rate_limit_status class] inCategory:CS_CNT_THROTTLE_TRANSIENT withLimit:180 perInterval:PSFTT_TI_STD_WINDOW];
    [factory addAPIThrottleDefinitionForClass:[CS_tapi_friendships_lookup class] inCategory:CS_CNT_THROTTLE_TRANSIENT withLimit:15 perInterval:PSFTT_TI_STD_WINDOW];
    [factory addAPIThrottleDefinitionForClass:[CS_tapi_friendships_show class] inCategory:CS_CNT_THROTTLE_TRANSIENT withLimit:180 perInterval:PSFTT_TI_STD_WINDOW];
    [factory addAPIThrottleDefinitionForClass:[CS_tapi_friendships_create class] inCategory:CS_CNT_THROTTLE_TRANSIENT withLimit:180 perInterval:PSFTT_TI_STD_WINDOW];
    [factory addAPIThrottleDefinitionForClass:[CS_tapi_blocks_destroy class] inCategory:CS_CNT_THROTTLE_TRANSIENT withLimit:30 perInterval:PSFTT_TI_STD_WINDOW];        // the limit is not defined in the docs
    [factory addAPIThrottleDefinitionForClass:[CS_tapi_mutes_users_destroy class] inCategory:CS_CNT_THROTTLE_TRANSIENT withLimit:30 perInterval:PSFTT_TI_STD_WINDOW];   // the limit is not defined in the docs
    [factory addAPIThrottleDefinitionForClass:[CS_tapi_statuses_home_timeline class] inCategory:CS_CNT_THROTTLE_TRANSIENT withLimit:15 perInterval:PSFTT_TI_STD_WINDOW];
    [factory addAPIThrottleDefinitionForClass:[CS_tapi_statuses_user_timeline class] inCategory:CS_CNT_THROTTLE_TRANSIENT withLimit:180 perInterval:PSFTT_TI_STD_WINDOW];
    [factory addAPIThrottleDefinitionForClass:[CS_tapi_account_verify_credentials class] inCategory:CS_CNT_THROTTLE_TRANSIENT withLimit:15 perInterval:PSFTT_TI_STD_WINDOW];
    [factory addAPIThrottleDefinitionForClass:[CS_tapi_statuses_mentions_timeline class] inCategory:CS_CNT_THROTTLE_TRANSIENT withLimit:15 perInterval:PSFTT_TI_STD_WINDOW];
    [factory addAPIThrottleDefinitionForClass:[CS_tapi_statuses_lookup class] inCategory:CS_CNT_THROTTLE_TRANSIENT withLimit:180 perInterval:PSFTT_TI_STD_WINDOW];
    [factory addAPIThrottleDefinitionForClass:[CS_tapi_users_show class] inCategory:CS_CNT_THROTTLE_TRANSIENT withLimit:180 perInterval:PSFTT_TI_STD_WINDOW];
    
    return [factory autorelease];
}

/*
 *  These are the mappings into the status result set for checking our API definitions.
 */
-(const struct _status_def *) statusCheckDefinitions
{
    // - the intent here is to make it relatively easy to keep this in synch with any new APIs I add even
    //   though the strings are sort of goofy that are returned from the status API in some cases.
    // - NOTE: look at https://dev.twitter.com/docs/api/1.1/get/application/rate_limit_status for resource names
    static struct _status_def checkDefs[] = {
        {@"statuses", @"/statuses/show/:id", @"CS_tapi_statuses_show"},
        // CS_tapi_user does not have a rate limit
        // CS_tapi_download_image does not have a rate limit
        // CS_tapi_statuses_update_with_media does not have a rate limit
        // CS_tapi_download_image_toverify does not have a rate limit
        {@"users", @"/users/lookup", @"CS_tapi_users_lookup"},
        {@"application", @"/application/rate_limit_status", @"CS_tapi_application_rate_limit_status"},
        {@"friendships", @"/friendships/lookup", @"CS_tapi_friendships_lookup"},
        {@"friendships", @"/friendships/show", @"CS_tapi_friendships_show"},
        // CS_tapi_friendships_create does not have a rate limit
        // CS_tapi_blocks_destroy doesn't appear to have a rate limit count, even though it is apparently rate limited.
        // CS_tapi_mutes_users_destroy doesn't appear to have a rate limit count, even though it is apparently rate limited.
        {@"statuses", @"/statuses/home_timeline", @"CS_tapi_statuses_home_timeline"},
        {@"statuses", @"/statuses/user_timeline", @"CS_tapi_statuses_user_timeline"},
        {@"account", @"/account/verify_credentials", @"CS_tapi_account_verify_credentials"},
        {@"statuses", @"/statuses/mentions_timeline", @"CS_tapi_statuses_mentions_timeline"},
        {@"statuses", @"/statuses/lookup", @"CS_tapi_statuses_lookup"},
        {@"users", @"/users/show/:id", @"CS_tapi_users_show"},
        {nil, nil, nil}
    };
    return checkDefs;
}

/*
 *  Ensure the factory has the latest limits applied so that it will never expand beyond what is permitted.
 *  - This is located right here because we need to keep this work in synch with the factory generation!
 */
-(void) updateFactoryLimitsWithStatus:(CS_tapi_application_rate_limit_status *) apiStatus inFeed:(ChatSealFeed *) feed
{
    if (![apiStatus isAPISuccessful]) {
        return;
    }
    
    NSObject *obj = [apiStatus resultDataConvertedFromJSON];
    if (![obj isKindOfClass:[NSDictionary class]]) {
        NSLog(@"CS-ALERT: Twitter feed status is returning unexpected data.");
        return;
    }
    
    NSDictionary *dict = (NSDictionary *) obj;
    dict               = [dict objectForKey:@"resources"];
    if (!dict) {
        NSLog(@"CS-ALERT: Twitter feed status returned no resources.");
        return;
    }
    
    const struct _status_def *checkDefs = [self statusCheckDefinitions];

    // - loop through all the definitions we must check and update the throttle for each.
    for (NSUInteger i = 0; checkDefs[i].resource != nil; i++) {
        NSDictionary *dictResource = [dict objectForKey:checkDefs[i].resource];
        if (!dictResource) {
            NSLog(@"CS-ALERT: the resource %@ was not found during Twitter feed status synch.", checkDefs[i].resource);
            continue;
        }
        
        NSDictionary *dictStats = [dictResource objectForKey:checkDefs[i].api];
        if (!dictStats) {
            NSLog(@"CS-ALERT: the stats were not found for %@ during Twitter feed status synch.", checkDefs[i].api);
            continue;
        }
        
        NSNumber *nLimit  = [dictStats objectForKey:@"limit"];
        NSNumber *nRemain = [dictStats objectForKey:@"remaining"];
        if (!nRemain) {
            nRemain = nLimit;
        }
        [feed reconfigureThrottleForAPIByName:checkDefs[i].localClass toLimit:[nLimit unsignedIntegerValue] andRemaining:[nRemain unsignedIntegerValue]];
    }
}

/*
 *  This is used to get the resources we need for API verification to be sent over to the application/rate_limit_status API.
 */
-(NSArray *) requiredTwitterAPIResources
{
    NSMutableSet *msSet                 = [NSMutableSet set];
    const struct _status_def *checkDefs = [self statusCheckDefinitions];
    for (NSUInteger i = 0; checkDefs[i].resource != NULL; i++) {
        [msSet addObject:checkDefs[i].resource];
    }
    return [msSet allObjects];
}

/*
 *  Return a suitable account for the given feed.
 */
-(ACAccount *) accountForFeed:(CS_twitterFeed *) feed
{
    ACAccountStore *as = [[self collectorForFeedType:self] accountStore];
    return [as accountWithIdentifier:[feed acAccountIdentifier]];
}

/*
 *  This method is used to inform the type that the given id is now considered complete and should not be processed further at any point.
 */
-(BOOL) setTweetIdAsCompleted:(NSString *) tweetId withError:(NSError **) err
{
    @synchronized (self) {
        CS_tweetTrackingDB *ttdb = [self tweetDBWithError:err];
        if (!ttdb) {
            return NO;
        }
        
        [ttdb setTweetAsCompleted:tweetId];
        return [self saveCurrentTweetDBWithError:err];
    }
}

/*
 *  Untrack a tweet in the database.
 */
-(BOOL) untrackTweetId:(NSString *) tweetId withError:(NSError **) err
{
    @synchronized (self) {
        CS_tweetTrackingDB *ttdb = [self tweetDBWithError:err];
        if (!ttdb) {
            return NO;
        }
        
        [ttdb untrackTweet:tweetId];
        return [self saveCurrentTweetDBWithError:err];
    }
}

/*
 *  Determine if the provided id is one of the local users.
 */
-(BOOL) isUserIdMine:(NSString *) userId
{
    NSArray *arrTmpFeeds = nil;
    @synchronized (self) {
        if (![self reloadExistingFeedsIfNecessary]) {
            return NO;
        }
        arrTmpFeeds = [NSArray arrayWithArray:maFeeds];
    }
    
    for (CS_twitterFeed *tf in arrTmpFeeds) {
        if ([userId isEqualToString:tf.userId]) {
            return YES;
        }
    }
    return NO;
}

/*
 *  Determine if the provided tweet is being tracked.
 */
-(BOOL) isTweetTrackedInAnyFeed:(NSString *) tweetId
{
    @synchronized (self) {
        CS_tweetTrackingDB *ttdb = [self tweetDBWithError:nil];
        if (!ttdb) {
            return NO;
        }

        return [ttdb isTweetTracked:tweetId];
    }
}

/*
 *  This method will try to track a Tweet.  
 *  - it returns NO if not allowed.
 */
-(BOOL) doesCentralTweetTrackingPermitTweet:(NSString *) tweetId toBeProcessedByFeed:(ChatSealFeed *) feed
{
    @synchronized (self) {
        CS_tweetTrackingDB *ttdb = [self tweetDBWithError:nil];
        if (!ttdb) {
            return NO;
        }
    
        if ([ttdb isTweetTracked:tweetId]) {
            return NO;
        }
        
        [ttdb setTweet:tweetId asPendingWithContext:[feed feedId]];
        NSError *tmp = nil;
        if (![self saveCurrentTweetDBWithError:&tmp]) {
            NSLog(@"CS: Failed to save central tweet tracking database.  %@", [tmp localizedDescription]);
        }
    }
    return YES;
}

/*
 *  The type manages the friendship state and indicates when there are problems to deal with.
 */
-(csft_friendship_state_t) friendshipState
{
    // - we are always going to show my friends regardless of whether the feeds are active or not because
    //   that information is useful for the user to know about.
    return [[self myFriends] friendshipStateInType:self];
}

/*
 *  Return my list of friends.
 */
-(NSArray *) feedFriends
{
    return [[self myFriends] feedFriendsInType:self];
}

/*
 *  Return a custom title for friendship display.
 */
-(NSString *) friendsDisplayTitle
{
    return NSLocalizedString(@"Twitter Friends", nil);
}

/*
 *  The default profile image is stored in the app so we have something to show without a network.
 */
-(UIImage *) friendDefaultProfileImage
{
    return [UIImage imageNamed:@"twitter_default_profile.png"];
}

/*
 *  Determine if this feed needs to perform high-priority updates.
 */
-(BOOL) hasHighPriorityWorkToPerform
{
    return [[self myFriends] hasHighPriorityWorkToPerformInType:self];
}

/*
 *  The types may do additional processing before their associated feeds.  We'll take this opportunity to
 *  try to keep our friendship state database up to date.
 */
-(BOOL) processFeedTypeRequestsInThrottleCategory:(cs_cnt_throttle_category_t)category usingFeed:(ChatSealFeed *)feed
{
    // - only do work in the transient category
    if (category != CS_CNT_THROTTLE_TRANSIENT) {
        return YES;
    }
    return [[self myFriends] processFeedTypeRequestsUsingFeed:feed inType:self];
}

/*
 *  We just got some friendship results.  If they are good, update our friendship state.
 */
-(void) updateFriendshipsWithResultMasks:(NSDictionary *) dictMasks fromFeed:(ChatSealFeed *) feed
{
    [[self myFriends] updateFriendshipsWithResultMasks:dictMasks fromFeed:feed inType:self];
}

/*
 *  Ignore the friend identified by the given account.
 */
-(BOOL) ignoreFriendByAccountId:(NSString *)acctId
{
    return [[self myFriends] ignoreFriendByAccountId:acctId];
}

/*
 *  Restore the friends in the array.
 */
-(void) restoreFriendsAccountIds:(NSArray *)arrFriends
{
    [[self myFriends] restoreFriendsAccountIds:arrFriends];
}

/*
 *  Return the view controller that is appropriate for friend management.
 */
-(UIFriendManagementViewController *) friendManagementViewController
{
    return [ChatSeal viewControllerForStoryboardId:@"UITwitterFriendViewController"];
}

/*
 *  Return a dictionary of feed objects to their associated connection refinements.
 */
-(NSArray *) localFeedsConnectionStatusWithFriend:(ChatSealFeedFriend *) feedFriend
{
    return [[self myFriends] localFeedsConnectionStatusWithFriend:feedFriend inType:self];
}

/*
 *  Return an updated feed friend object if things have changed.
 */
-(ChatSealFeedFriend *) refreshFriendFromFriend:(ChatSealFeedFriend *) feedFriend
{
    return [[self myFriends] refreshFriendFromFriend:feedFriend inType:self];
}

/*
 *  Sometimes we want a friend version to be updated because we made a modification, do so now.
 */
-(void) incrementFriendVersionForScreenName:(NSString *) myFriend
{
    [[self myFriends] incrementUserVersionForScreenName:myFriend];
}

/*
 *  When a feed is enabled, but has pending friend lookups to perform, we have to assume that 
 *  its content is stale and we don't want to use that data until it can be confirmed.
 */
-(void) markFriendDeficienciesAsStaleForFeed:(CS_twitterFeed *) feed
{
    [[self myFriends] markFriendDeficienciesAsStaleForFeed:feed inType:self];
}

/*
 *  When we get a targeted update for one of our friendships, this is our chance to make sure the friendship state is updated.
 */
-(void) updateTargetedFriendshipWithResults:(CS_tapi_friendships_show *) apiShow fromFeed:(ChatSealFeed *) feed
{
    [[self myFriends] updateTargetedFriendshipWithResults:apiShow fromFeed:feed inType:self];
}

/*
 *  Compute the recommended course of action for a given feed to connect with a friend.
 */
-(CS_tfsFriendshipAdjustment *) recommendedAdjustmentForFeed:(ChatSealFeed *) feed withFriend:(ChatSealFeedFriend *) feedFriend
{
    return [[self myFriends] recommendedAdjustmentForFeed:feed withFriend:feedFriend];
}

/*
 *  Change the following state for the given feed/friend combination.
 */
-(void) setFeed:(CS_twitterFeed *) feed withFollowing:(BOOL) isFollowing forFriendName:(NSString *) friendName
{
    [[self myFriends] setFeed:feed withFollowing:isFollowing forFriendName:friendName];
}

/*
 *  Change the blocking state for a given feed/friend combination.
 */
-(void) setFeed:(CS_twitterFeed *) feed asBlocking:(BOOL) isBlocking forFriendName:(NSString *) friendName
{
    [[self myFriends] setFeed:feed asBlocking:isBlocking forFriendName:friendName];
}

/*
 *  Flag that this feed has been blocked by a friend, which we can only learn by trying to follow them.
 */
-(void) markFeed:(CS_twitterFeed *) feed asBlockedByFriendWithName:(NSString *) friendName
{
    [[self myFriends] markFeed:feed asBlockedByFriendWithName:friendName];
}

/*
 *  Reconcile the state from one of my feeds to a target friend.
 */
-(void) reconcileKnownFriendshipStateFromFeed:(CS_twitterFeed *) feed toFriend:(NSString *) friendName withPendingTask:(id<CS_twitterFeed_highPrio_task>) task
{
    [[self myFriends] reconcileKnownFriendshipStateFromFeed:feed toFriend:friendName withPendingTask:task];
}

/*
 *  Return the friendship state for the given friend in the given feed.
 */
-(CS_tapi_friendship_state *) stateForFriendByName:(NSString *) screenName inFeed:(CS_twitterFeed *) feed
{
    return [[self myFriends] stateForFriendByName:screenName inFeed:feed];
}

/*
 *  Determine if my friend is following me.
 */
-(BOOL) isFriend:(NSString *) friendName followingMyFeed:(CS_twitterFeed *) feed
{
    return [[self myFriends] isFriend:friendName followingMyFeed:feed];
}

/*
 *  Determine if there is any obvious reason why I cannot read my friend's feed.
 */
-(BOOL) canMyFeed:(CS_twitterFeed *) feed readMyFriend:(NSString *) friendName
{
    return [[self myFriends] canMyFeed:feed readMyFriend:friendName];
}

/*
 *  Return the connectivity states for all the friends in the given feed.
 */
-(NSDictionary *) statesForAllReachableFriendsInFeed:(CS_twitterFeed *) feed
{
    return [[self myFriends] statesForAllReachableFriendsInFeed:feed];
}

/*
 *  Every post includes a linked list with it that includes some past posts with the seal so that we
 *  have a shot at finding old content.
 */
-(void) processPostedMessageHistory:(NSArray *) arrHist fromSourceFeed:(CS_twitterFeed *)sourceFeed
{
    if (![arrHist count]) {
        return;
    }
    
    NSArray *feeds = [self feeds];
    
    // - the goal here is to iterate over the items and find a feed that can host each one.
    // - all of these tweets are 'proven' because they are sealed with this seal.
    BOOL saveOrphans  = NO;
    BOOL foundTargets = NO;
    for (CS_twitterFeed_history_item *hi in arrHist) {
        BOOL itemProcessed  = NO;
        if ((itemProcessed = [self tryToProcessCandidateTweet:hi.tweetId withContext:[CS_candidateTweetContext contextForScreenName:hi.screenName andPhoto:nil andProvenUseful:YES] usingFeeds:feeds]) == YES) {
            foundTargets = YES;
        }
        
        // - when a source feed is provided, we'll use that as a backup option.
        if (!itemProcessed && sourceFeed && [sourceFeed isEnabled]) {
            [sourceFeed saveTweetForProcessing:hi.tweetId withPhoto:nil fromUser:hi.screenName andFlagAsKnownUseful:YES];
            itemProcessed = YES;
            foundTargets  = YES;
        }
        
        // - put any orphaned items into the central list.
        if (!itemProcessed) {
            @synchronized (self) {
                if ([[self tweetDBWithError:nil] flagTweet:hi.tweetId asCandidateFromFriend:hi.screenName withPhoto:nil andProvenUseful:YES andForceIt:NO]) {
                    saveOrphans = YES;
                }
            }
        }
    }
    
    // - when we've found at least one target, that means we may be able to process the content.
    if (foundTargets) {
        [[self collectorForFeedType:self] scheduleHighPriorityUpdateIfPossible];
    }

    // - save off the tweet database if we added orphaned tweets.
    if (saveOrphans) {
        @synchronized (self) {
            // ...errors aren't critical here because these orphans are really just a nice to have list for keeping
            //    in contact.
            [self saveCurrentTweetDBWithError:nil];
        }
    }
}

/*
 *  Save a candidate tweet for the given friend, but only if they exist.
 *  - returns NO if the candidate could not be saved.
 */
-(BOOL) saveOrReplaceAsCandidateTweet:(NSString *) tweetId fromFriend:(NSString *) friendName withPhoto:(NSURL *) uPhoto asProvenUseful:(BOOL) isUseful
{
    NSArray *friends = [ChatSeal friendsForFeedsOfType:[self typeId]];
    BOOL found = NO;
    for (ChatSealIdentityFriend *oneFriend in friends) {
        if ([friendName isEqualToString:oneFriend.location.feedAccount]) {
            found = YES;
            break;
        }
    }

    // - we don't have a friend that can be associated with this, so it probably doesn't make sense for the type to track it.
    if (!found) {
        return NO;
    }
    
    @synchronized (self) {
        CS_tweetTrackingDB *db = [self tweetDBWithError:nil];
        if (!db) {
            return NO;
        }
        
        // - record the tweet in the database as a candidate and force the change because this may come from
        //    a pending item we want to convert.
        if ([db flagTweet:tweetId asCandidateFromFriend:friendName withPhoto:uPhoto andProvenUseful:isUseful andForceIt:YES]) {
            [self saveCurrentTweetDBWithError:nil];
        }
    }
    return YES;
}

/*
 *  These locations were received for this type and may offer some extra information.
 */
-(void) processReceivedFeedLocations:(NSArray *) locs
{
    // - convert over to history item format.
    NSMutableArray *maToProcess = [NSMutableArray array];
    for (ChatSealFeedLocation *oneLoc in locs) {
        // - the custom context should always be a string of the tweet id.
        if ([oneLoc.customContext isKindOfClass:[NSString class]]) {
            [maToProcess addObject:[CS_twitterFeed_history_item itemForTweet:(NSString *) oneLoc.customContext andScreenName:oneLoc.feedAccount]];
        }
    }
    
    // - just let the standard history processing routine handle them.
    [self processPostedMessageHistory:maToProcess fromSourceFeed:nil];
}

/*
 *  Check if we're allowed to make the given request for a user timeline.
 */
-(BOOL) isUserTimelineRequest:(CS_tapi_statuses_user_timeline *) api allowedForFeed:(CS_twitterFeed *) feed
{
    // - the friendshp state tracks which feeds are actively attempting requests and will prevent duplicate requests in those ranges to avoid
    //   duplicating the same mining activities.
    return [[self myFriends] isTimelineRequestPermittedForFriend:[api screenName] andRange:[CS_feedTypeTwitter rangeFromUserTimelineAPI:api] fromFeed:feed];
}

/*
 *  Complete the given user timeline request.
 */
-(void) completeUserTimelineRequest:(CS_tapi_statuses_user_timeline *) api fromFeed:(CS_twitterFeed *) feed
{
    // - first, if successful, we want to allow the other feeds to mark their ranges as completed.
    if ([api isAPISuccessful]) {
        NSArray *arrFeeds = [self feeds];
        if ([arrFeeds count] > 1) {
            for (CS_twitterFeed *otherFeed in arrFeeds) {
                //  NOTE: this occurs whether the other feed is usable or enabled, which will prevent it from being
                //        out of synch when it comes online later.
                if (![feed isEqual:otherFeed]) {
                    [otherFeed markTimelineRangeAsProcessedFromAPI:api];
                }
            }
        }
    }
    
    // - last, update the friendship state so that it no longer prevents requests in this range.
    [[self myFriends] completeTimelineRequestForFriend:api.screenName andRange:[CS_feedTypeTwitter rangeFromUserTimelineAPI:api]];
}

/*
 *  Discard any pending requests for timeline updates.
 */
-(void) discardAllTimelineRequestsFromFeed:(CS_twitterFeed *) feed
{
    [[self myFriends] discardAllTimelineRequestsFromFeed:feed];
}

/*
 *  The given feed is either going offline or will be deleted, so we want to make sure its content gets picked up and processed.
 */
-(void) reassignPendingItemsFromFeed:(CS_twitterFeed *) feed priorToDeletion:(BOOL) willDelete
{
    // - we always reassign fully-identified content becuase the type can just hand it back later if the feed comes back online.
    NSArray *arrPending = [feed extractPendingItemsWithFullIdentification:YES];
    BOOL doSave         = NO;
    BOOL checkCandidates= NO;
    @synchronized (self) {
        if ([arrPending count]) {
            CS_tweetTrackingDB *ttdb = [self tweetDBWithError:nil];
            for (CS_tweetPending *tp in arrPending) {
                [ttdb flagTweet:tp.tweetId asCandidateFromFriend:tp.screenName withPhoto:tp.photoURL andProvenUseful:tp.isConfirmed andForceIt:YES];
            }
            checkCandidates = YES;
            doSave          = YES;
        }
    }
    
    // - find a target for any content that is not fully identified, but only if there is more than one feed, implying we can move to it.
    NSArray *arrFeeds = [self feeds];
    if ([arrFeeds count] > (willDelete ? 0 : 1)) {              // ... when deleting the feed in question will already be gone from the list.
        CS_twitterFeed *targetFeed = nil;
        for (CS_twitterFeed *tf in [self feeds]) {
            if (tf == feed) {
                continue;
            }
            
            // - pick the best feed we can find to receive the new content.
            if (!targetFeed ||
                (![targetFeed isEnabled] && [tf isEnabled]) ||
                (![targetFeed isViableMessagingTarget] && [tf isViableMessagingTarget])) {
                targetFeed = tf;
            }
        }
        
        // - the only time we'll forcibly move to a disabled feed is when we're deleting.
        if (![targetFeed isEnabled] && !willDelete) {
            return;
        }
        
        // - figure out if there is anything to transfer and move it over.
        arrPending = [feed extractPendingItemsWithFullIdentification:NO];
        if ([arrPending count]) {
            [targetFeed addPendingItemsToFeed:arrPending];
            doSave = YES;
        }
    }
    
    // - if we made any changes, save the database.
    if (doSave) {
        @synchronized (self) {
            [self saveCurrentTweetDBWithError:nil];
        }
    }
    
    // - if we transferred content to the candidate list, do a quick scan to see if
    //   another feed can receive it.
    if (checkCandidates) {
        [self checkForCandidateAssignments];
    }
}

/*
 *  Candidate tweets are stored and we try to eventually deal with them.  This method will
 *  look in our candidate list and see if any can be assigned right now.  
 *  - DO NOT hold the lock around this!
 */
-(void) checkForCandidateAssignments
{
    NSDictionary *dictCandidates = nil;
    NSArray      *arrFeeds       = nil;
    @synchronized (self) {
        dictCandidates = [[self tweetDBWithError:nil] allCandidates];
        if ([dictCandidates count]) {
            arrFeeds = [self feeds];
        }
    }
    
    // - if any candidates exist, this is a good time to check to see if we can process
    //   them now.
    __block BOOL candidatesWereFound = NO;
    if ([dictCandidates count]) {
        [dictCandidates enumerateKeysAndObjectsUsingBlock:^(NSString *tweetId, CS_candidateTweetContext *ctx, BOOL *stop) {
            if ([self tryToProcessCandidateTweet:tweetId withContext:ctx usingFeeds:arrFeeds]) {
                candidatesWereFound = YES;
            }
        }];
    }
    
    // - finally, if we did some candidate work, then schedule an immediate update
    if (candidatesWereFound) {
        [[self collectorForFeedType:self] scheduleHighPriorityUpdateIfPossible];
    }
}

/*
 *  This method will determine if the given feed can receive lists of candidates from other feeds that may be disabled.
 *  - this only occurs if all other feeds are disabled because otherwise we know that the reassignment already occurred.
 */
-(void) checkIfOtherPendingCanBeTransferredToFeed:(CS_twitterFeed *) feed
{
    // - if the requested feed is broken, don't bother.
    if (![feed isViableMessagingTarget]) {
        return;
    }
    
    // - now check to make sure there is something else that may have pending content.
    NSArray *arrFeeds = [self feeds];
    if ([arrFeeds count] < 2) {
        return;
    }
    
    BOOL allDisabled  = YES;
    for (ChatSealFeed *tmpFeed in arrFeeds) {
        if ([feed isEqual:tmpFeed]) {
            continue;
        }
        if ([tmpFeed isEnabled]) {
            allDisabled = NO;
            break;
        }
    }
    
    if (!allDisabled) {
        return;
    }
    
    // - now iterate over them all and see what we find.
    BOOL doSave = NO;
    for (CS_twitterFeed *tf in arrFeeds) {
        if ([feed isEqual:tf]) {
            continue;
        }
        
        // - figure out if there is anything to transfer and move it over.
        NSArray *arrPending = [tf extractPendingItemsWithFullIdentification:NO];
        if ([arrPending count]) {
            [feed addPendingItemsToFeed:arrPending];
            doSave = YES;
        }
    }
    
    // - if we made any changes, save the database.
    if (doSave) {
        @synchronized (self) {
            [self saveCurrentTweetDBWithError:nil];
        }
    }
}

/*
 *  When we have no external friends in the database, we should watch our feeds to make sure we're following someone
 *  and warn when we're not.
 */
-(BOOL) doesFriendshipDatabaseSupportFollowingWarning
{
    cachedShouldShowFollowWarning = [[self myFriends] doesFriendshipDatabaseSupporFollowingWarning];
    cachedHasSeals                = [ChatSeal hasSeals];
    return cachedShouldShowFollowWarning;
}

/*
 *  When seals are added/deleted, we should determine if we should figure out if dependencies of the feed
 *  should be reevaluated.
 */
-(void) vaultSealStateHasBeenUpdated
{
    // - the only one right now is whether a feed is marked as needing to follow someone.
    [self checkForFollowingStateDrivers];
}

/*
 *  Check the friendship state to see if replying is a good idea.
 */
-(BOOL) canUseTwitterReplyToFriend:(NSString *) friendName fromMyFeed:(CS_twitterFeed *) feed whenUsingSeal:(NSString *) sealId
{
    return [[self myFriends] canUseTwitterReplyToFriend:friendName fromMyFeed:feed whenUsingSeal:sealId];
}

/*
 *  Whether the friendship screen allows us to insert new friendships manually.
 */
-(BOOL) canAddFriendsManually
{
    // - I originally didn't make this available in favor of a 'proven' approach to friends, but what happened was there were certain
    //   scenarios where we wouldn't be able to manage those connections because I wasn't automatically sharing feed names
    //   in messages and during seal exchanges.  If I don't know what their feed is, I have no way of looking for messages.  This offers
    //   a way to educate the person in the event they're in one of those special situations and allow them to make progress.
    return YES;
}

/*
 *  Return a view controller that can add friends.
 */
-(UIFriendAdditionViewController *) friendAdditionViewController
{
    return [[[UITwitterFriendAdditionViewController alloc] init] autorelease];
}

/*
 *  Are we currently tracking the given friend?
 */
-(BOOL) isTrackingFriendByName:(NSString *) friendName
{
    return [[self myFriends] isTrackingFriendByName:friendName];
}

/*
 *  Begin tracking someone who we don't necessarily trust yet.
 */
-(void) trackUnprovenFriendByName:(NSString *) friendName andInitializeWith:(CS_tapi_user_looked_up *) userInfo
{
    [[self myFriends] trackUnprovenFriendByName:friendName andInitializeWith:userInfo];
}

@end


/************************************
 CS_feedTypeTwitter (internal)
 ************************************/
@implementation CS_feedTypeTwitter (internal)
/*
 *  Ensure the list of feeds is kept up to date.
 */
-(void) recomputeFeedArrayWithAccountStore:(ACAccountStore *) as andType:(ACAccountType *) at andReturningToDelete:(NSArray **) arrToDelete
{
    NSMutableArray *maExisting = nil;
    CS_twitterFeed *feedPrimer = nil;
    @synchronized (self) {
        if (![self reloadExistingFeedsIfNecessary]) {
            return;
        }
        
        // - it doesn't make sense to continue updating the list of feeds if we aren't authorized to consult
        //   the list of accounts.
        if (!isAuthorized) {
            return;
        }
        
        // - the intent here is to create new feeds when we detect some now exist that did not before
        //   and cull feeds that had no activity when they are removed.
        maExisting = [NSMutableArray arrayWithArray:maFeeds];
        
        // - pull a primary feed that we can use for caching.
        feedPrimer = [maExisting firstObject];
    }
    
    // - reset all the ACAccount identifiers so that they are recomputed from the actual content of the store, which
    //   will catch cases where they disappeared since the last recomputation.
    // - NOTE: by setting this here, we won't be able to successfully issue API requests until the feed is revalidated
    //         below in the new list of accounts.
    for (CS_twitterFeed *feed in maExisting) {
        [feed setACAccountIdentifier:nil];
    }
    
    // - first identify whether accounts are new or existing.
    NSMutableArray *maAdded = nil;
    NSArray *arrAccounts    = [as accountsWithAccountType:at];
    for (ACAccount *curAccount in arrAccounts) {
        NSString *sFeedId = [CS_twitterFeed feedIdForAccount:curAccount];
        
        // - see if we already have this one.
        BOOL exists = NO;
        for (CS_twitterFeed *feed in maExisting) {
            if ([sFeedId isEqualToString:feed.feedId]) {
                [maExisting removeObject:feed];
                [feed setACAccountIdentifier:curAccount.identifier];
                [feed setBackingIdentityIsAvailable:YES];
                exists = YES;
                break;
            }
        }
        
        // - we do not, so attempt to instantiate it.
        if (!exists) {
            CS_twitterFeed *tf = [CS_twitterFeed feedForAccount:curAccount andDelegate:self andDictionary:nil];
            NSError *err = nil;
            if (![tf setUserId:curAccount.username withError:&err]) {
                // - I decided to not abort the feed reload because of this failure because it is only with a single
                //   feed.  It is possible that this problem will correct itself in time.
                NSLog(@"CS: Unable to save the feed %@.  %@", sFeedId, [err localizedDescription]);
            }
            
            // - save off the location that was added
            if (!maAdded) {
                maAdded = [NSMutableArray array];
            }
            [maAdded addObject:[ChatSealFeedLocation locationForType:[self typeId] andAccount:tf.userId]];
            
            // - and save the feed we just created.
            @synchronized (self) {
                [tf prefillSharedContentDuringCreationFromFeed:feedPrimer];
                [maFeeds addObject:tf];
            }
        }
    }
    
    // - now whatever remains in the existing array are accounts that have been discarded, so
    //   we need to make sure that they are not being used before destroying them permanently.
    NSMutableArray *maToDelete = [NSMutableArray array];
    for (ChatSealFeed *feed in maExisting) {
        if ([feed hasRequiredPendingActivity]) {
            [feed setBackingIdentityIsAvailable:NO];
        }
        else {
            [maToDelete addObject:feed];
            @synchronized (self) {
                [maFeeds removeObject:feed];
            }
        }
    }
    
    // - return the feed items we should discard permanently and allow them to
    //   be deleted outside the lock.
    if (arrToDelete) {
        *arrToDelete = maToDelete;
    }
    
    // - if we added any feeds, make sure that they are not tracked as friends.
    // - NOTE: you may think that we could just go directly over to our friendship information here, which
    //   would be nice, except the fact that the identity database is the primary authority for friendship so we need
    //   to ask it to check on the relationships before we make any decisions.
    if (maAdded) {
        //  ... if we got a hit, then we need to make sure that we address this as soon as possible.
        if ([ChatSeal deleteAllFriendsForFeedsInLocations:maAdded]) {
            [[self collectorForFeedType:self] scheduleHighPriorityUpdateIfPossible];
        }
    }
}

/*
 *  Reload the existing feeds from disk.
 *  - ASSUMES the lock is held.
 */
-(BOOL) reloadExistingFeeds
{
    NSError *err            = nil;
    NSDictionary *dExisting = [ChatSealFeed configurationsForFeedsOfType:[self typeId] withError:&err];
    if (!dExisting) {
        // - when we are unable to read from disk, that is a more serious problem
        NSLog(@"CS: Unable to enumerate the existing Twitter feeds.  %@", [err localizedDescription]);
        return NO;
    }
 
    // - for each feed that has a matching type on disk, create an object to track it.
    for (NSString *feedId in [dExisting allKeys]) {
        NSDictionary *dictData = [dExisting objectForKey:feedId];
        if (dictData) {
            // NOTE: the account identifier will not be set with this method, this assumes the feed still requires configuration
            //       from the ACAccountStore to be useful.
            CS_twitterFeed *tf = [CS_twitterFeed feedForAccountId:feedId andDelegate:self andDictionary:dictData];
            [maFeeds addObject:tf];
        }
    }
    
    return YES;
}

/*
 *  Reload the existing feeds from disk if they haven't yet been loaded.
 *  - ASSUMES the lock is held.
 */
-(BOOL) reloadExistingFeedsIfNecessary
{
    if (!hasLoadedInitialFeeds) {
        if (![self reloadExistingFeeds]) {
            isValid = NO;
            return NO;
        }
        hasLoadedInitialFeeds = YES;
    }
    
    // - load up our friendship state if we get a chance too.
    if (!tfsFriends) {
        tfsFriends          = [[CS_twitterFriendshipState alloc] init];
        tfsFriends.delegate = self;
    }

    return YES;
}

/*
 *  Handle the closing of the feed type.
 */
-(void) close
{
    NSArray *arrTmpFeeds = nil;
    @synchronized (self) {
        arrTmpFeeds = [NSArray arrayWithArray:maFeeds];
        [maFeeds release];
        maFeeds = nil;
        
        [tweetDB release];
        tweetDB = nil;
        
        tfsFriends.delegate = nil;
        [tfsFriends release];
        tfsFriends = nil;
        
        [super close];
    }
    
    // - issue these outside the lock.
    for (ChatSealFeed *feed in arrTmpFeeds) {
        [feed close];
    }
}

/*
 *  Return a base URL for all Twitter type storage.
 */
+(NSURL *) twitterTypeURL
{
    if (![ChatSeal isVaultOpen]) {
        return nil;
    }
    
    @synchronized (kChatSealFeedTypeTwitter) {
        if (!uTwitterTypeBase) {
            NSError *err      = nil;
            NSString *sSalted = [ChatSeal safeSaltedPathString:kChatSealFeedTypeTwitter withError:&err];
            if (!sSalted) {
                NSLog(@"CS: Failed to generate a Twitter storage URL name.  %@", [err localizedDescription]);
                return nil;
            }
            uTwitterTypeBase = [[[ChatSealFeedType feedTypeURL] URLByAppendingPathComponent:sSalted] retain];
        }
        if (uTwitterTypeBase && ![[NSFileManager defaultManager] fileExistsAtPath:[uTwitterTypeBase path]]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:[uTwitterTypeBase path] withIntermediateDirectories:YES attributes:nil error:nil];
        }
        return [[uTwitterTypeBase retain] autorelease];
    }
}

/*
 *  Return the URL for the tweet database.
 */
+(NSURL *) tweetDBURL
{
    if (![ChatSeal isVaultOpen]) {
        return nil;
    }
    
    // - in order to maintain privacy, we'll generate a good salted name for this.
    @synchronized (kChatSealFeedTypeTwitter) {
        NSURL *uBase = [CS_feedTypeTwitter twitterTypeURL];
        if (!uBase) {
            return nil;
        }
        if (!sTweetDBName) {
            NSError *err = nil;
            sTweetDBName = [[ChatSeal safeSaltedPathString:@"t-tdb" withError:&err] retain];
            if (!sTweetDBName) {
                NSLog(@"CS: Failed to generate a tweet db name.  %@", [err localizedDescription]);
                return nil;
            }
        }
        return [uBase URLByAppendingPathComponent:sTweetDBName];
    }
}

/*
 *  Return the current tweet tracking database.
 *  - ASSUMES the lock is held.
 */
-(CS_tweetTrackingDB *) tweetDBWithError:(NSError **) err
{
    if (!tweetDB) {
        NSURL *uDB = [CS_feedTypeTwitter tweetDBURL];
        if ([[NSFileManager defaultManager] fileExistsAtPath:[uDB path]]) {
            NSDictionary *dict = [CS_feedCollectorUtil secureLoadConfigurationFromFile:uDB withError:err];
            if (!dict) {
                return nil;
            }
            NSObject *obj = [dict objectForKey:CS_FTW_DB_KEY];
            if (obj && [obj isKindOfClass:[CS_tweetTrackingDB class]]) {
                tweetDB = [(CS_tweetTrackingDB *) obj retain];
            }
            else {
                NSLog(@"CS-ALERT: Unexpected bad format tracking database.");
                tweetDB = [[CS_tweetTrackingDB alloc] init];
            }
        }
        else {
            tweetDB = [[CS_tweetTrackingDB alloc] init];
        }
    }
    return  [[tweetDB retain] autorelease];
}

/*
 *  Save the active database.
 *  - ASSUMES the lock is held.
 */
-(BOOL) saveCurrentTweetDBWithError:(NSError **) err
{
    if (tweetDB) {
        NSURL *uDB = [CS_feedTypeTwitter tweetDBURL];
        return [CS_feedCollectorUtil secureSaveConfiguration:[NSDictionary dictionaryWithObject:tweetDB forKey:CS_FTW_DB_KEY] asFile:uDB withError:err];
    }
    
    [CS_error fillError:err withCode:CSErrorFeedInvalid];
    return NO;
}

/*
 *  Return a temporary handle to the friendship state database that respects the locking in this object.
 */
-(CS_twitterFriendshipState *) myFriends
{
    CS_twitterFriendshipState *sRet = nil;
    @synchronized (self) {
        sRet = [[tfsFriends retain] autorelease];
    }
    
    // - don't adjust this under lock or there will be a deadlock at some point.
    if (![sRet hasBaseURL]) {
        [sRet setBaseTypeURL:[CS_feedTypeTwitter twitterTypeURL]];
    }

    return sRet;
}

/*
 *  This method is fired when the first update completes.
 */
-(void) initialFriendshipUpdateHasOccurredForState:(CS_twitterFriendshipState *) fs
{
    // - just make sure the following state is kept in synch.
    [self checkForFollowingStateDrivers];
}

/*
 *  Notify everyone that friendships are updated.
 */
-(void) friendshipsUpdatedForState:(CS_twitterFriendshipState *)fs
{
    NSArray *arrFeeds            = nil;
    
    @synchronized (self) {
        if (![self reloadExistingFeedsIfNecessary]) {
            return;
        }
        arrFeeds       = [NSArray arrayWithArray:maFeeds];
    }
    
    // - first directly let each feed know so it is clear it applies
    //   to this type.
    for (CS_twitterFeed *feed in arrFeeds) {
        [feed notifyFriendshipsHaveBeenUpdated];
    }
    
    // - and more generally let the other interested parties know it.
    [ChatSeal notifyFriendshipsUpdated];
    
    // - see if we can shift any candidates.
    [self checkForCandidateAssignments];
    
    // - see if the following state needs to be recomputed.
    [self checkForFollowingStateDrivers];
}

/*
 * Attempt to begin processing a candidate tweet.
 */
-(BOOL) tryToProcessCandidateTweet:(NSString *) tweetId withContext:(CS_candidateTweetContext *) ctx usingFeeds:(NSArray *) feeds
{
    // - figure out if any of my feeds can connect.
    CS_twitterFeed *tfBest = [[self myFriends] bestLocalFeedForReadingFriend:ctx.screenName usingFeedList:feeds];
    if (tfBest) {
        [tfBest saveTweetForProcessing:tweetId withPhoto:ctx.photoURL fromUser:ctx.screenName andFlagAsKnownUseful:ctx.isProvenUseful];
        return YES;
    }
    return NO;
}

/*
 *  Return a range that makes sense for calculations from the provided user timeline API.  
 *  - the range will always have min/max values even if the API does not.
 */
+(CS_tapi_tweetRange *) rangeFromUserTimelineAPI:(CS_tapi_statuses_user_timeline *) api
{
    CS_tapi_tweetRange *tr = [CS_tapi_tweetRange emptyRange];
    if (api.sinceTweetId) {
        tr.minTweetId = api.sinceTweetId;
    }
    else {
        tr.minTweetId = [CS_tapi_tweetRange absoluteMinimum];
    }
    
    if (api.maxTweetId) {
        tr.maxTweetId = api.maxTweetId;
    }
    else {
        tr.maxTweetId = [NSString stringWithFormat:@"%llu", (unsigned long long) -1];
    }
    return tr;
}

/*
 *  Determine if the feeds' following state indicators should be recomputed.
 */
-(void) checkForFollowingStateDrivers
{
    if (cachedHasSeals == [ChatSeal hasSeals] &&
        cachedShouldShowFollowWarning == [[self myFriends] doesFriendshipDatabaseSupporFollowingWarning]) {
        return;
    }
    
    // - notify any interested parties that the feeds have been updated.
    for (ChatSealFeed *feed in [self feeds]) {
        [ChatSealFeedCollector issueUpdateNotificationForFeed:feed];
    }
    
    // - make sure the feed alert badge is updated.
    [[ChatSeal applicationHub] updateFeedAlertBadge];
}
@end
