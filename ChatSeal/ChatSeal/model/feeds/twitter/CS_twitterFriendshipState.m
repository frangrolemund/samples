//
//  CS_twitterFriendshipState.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/7/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFriendshipState.h"
#import "CS_twitterFeed_shared.h"
#import "ChatSeal.h"
#import "CS_tfsUserData.h"
#import "CS_feedCollectorUtil.h"
#import "CS_tfsFriendshipAdjustment.h"
#import "CS_tfsPendingUserTimelineRequest.h"

//  THREADING-NOTES:
//  - internal locking is provided.

//  GENERAL-NOTES:
//  - this object works off the principle that it will encourage mutual following between two people.  Most issues can be addressed by the user being reported-to, but
//    in at least one scenario we'll let them know if their friend isn't following them so that they can encourage the connection.  Whatever the situation, we're trying to
//    not flag every single problem as a critical failure so that it doesn't feel like everything is always in a broken state.
//  - the state in this object is intended to not flag problems unless they are proven, which means the absence of any of the supporting data allows
//    the user to assume things are working fine.  The absolute last thing we ever want is to issue false-positives.

// - constants
static const time_t     CS_TFS_INITIAL_UPDATE_DELAY = 5;
static const time_t     CS_TFS_UPDATE_PERIOD        = (10 * 60);
static NSString        *CS_TFS_KEY_LASTACCT         = @"lastAcct";
static NSString        *CS_TFS_KEY_USERS            = @"users";
static NSString        *CS_TFS_KEY_IGNORE           = @"noFriends";
static const NSUInteger CS_TFS_FORCE_REFRESH_VER    = (NSUInteger) -1;
static const NSUInteger CS_TFS_MAX_PROFILE_PER_UPD  = 2;
static const NSTimeInterval CS_TF_PROF_IMAGE_DELAY  = 30;

@interface CS_twitterFriendshipState (internal) <ChatSealFeedFriendDelegate>
-(CS_tfsUserData *) retrieveOrCreateUserForScreenName:(NSString *) screenName asMe:(BOOL) isMe andWasCreated:(BOOL *) wasCreated;
-(void) discardUserWithScreenName:(NSString *) screenName;
-(NSMutableArray *) localUsers;
-(NSArray *) allFriendKeys;
-(BOOL) computeIfRefreshIsAppropriateInType:(CS_feedTypeTwitter *) twitterFeedType;
-(NSUInteger) numberOfExpectedProfileImages;
-(void) requestProfileImagesIfRequired;
-(BOOL) attemptToScheduleUserQueriesUsingFeed:(ChatSealFeed *) feed;
-(void) processUserQueryResuls:(CS_tapi_users_lookup *) tul;
-(NSURL *) urlDatabase;
-(void) saveFriendshipStateAndForceCachedStateRecalc:(BOOL) forceRecalc;
-(void) loadFriendshipState;
-(void) rebuildFriendshipStateWithLocalUsers:(NSSet *) sUsers;
-(void) forceFriendshipRecalculation;
-(NSSet *) availableFeedsForProcessingFromType:(CS_feedTypeTwitter *) twitterFeedType;
-(void) recomputeCachedStateIfNecessaryUsingFeeds:(NSSet *) sNewActive;
-(void) discardFriendProfileImageInUser:(CS_tfsUserData *) udata;
-(void) saveFriendProfileImageData:(NSData *) dProfileImage inUser:(CS_tfsUserData *) udata;
-(ChatSealFeedFriend *) feedFriendForUserData:(CS_tfsUserData *) udata inType:(CS_feedTypeTwitter *) twitterFeedType;
-(void) updateFriend:(CS_tfsUserData *) udataFriend andNotifyInFeed:(CS_twitterFeed *) feed;
-(void) removeAllTrackingForFriend:(NSString *) friendName andIgnore:(BOOL) ignore andSaveWhenDone:(BOOL) doSave;
-(BOOL) markFriendsAsDeletedInArray:(NSArray *) arrNames;
@end

/*******************************
 CS_twitterFriendshipState
 *******************************/
@implementation CS_twitterFriendshipState
/*
 * Object attributes
 */
{
    // - the state database.
    cs_tfs_account_id_t     lastAccount;
    NSMutableDictionary     *mdUserData;            // only save off the values and recreate the keys.
    NSMutableSet            *msIgnoreFriends;

    // - intermediate working state.
    BOOL                    isLoaded;
    NSURL                   *urlTwitterBase;
    NSURL                   *urlDatabase;
    NSMutableDictionary     *mdAccountToUser;
    NSMutableSet            *msMyUserIds;
    NSUInteger              numFriends;
    BOOL                    isInitialRefresh;
    time_t                  lastRefresh;
    NSUInteger              friendListVersion;
    NSMutableArray          *maPendingUserQuery;
    BOOL                    recomputeFriends;
    NSMutableSet            *msActiveUserFeeds;
    csft_friendship_state_t cachedFriendshipState;
    NSMutableDictionary     *mdBrokenFriends;
    NSUInteger              numConsistentlyCachedProfileImages;
    uint16_t                numPendingProfileDownloads;
    NSMutableArray          *maPendingFriendTimelineRequests;
    NSDate                  *dtProfileImageDelay;
}
@synthesize delegate;

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        lastAccount                        = 0;
        delegate                           = nil;
        mdUserData                         = [[NSMutableDictionary alloc] init];
        
        urlTwitterBase                     = nil;
        urlDatabase                        = nil;
        mdAccountToUser                    = [[NSMutableDictionary alloc] init];
        msMyUserIds                        = [[NSMutableSet alloc] init];
        numFriends                         = 0;
        isInitialRefresh                   = YES;
        lastRefresh                        = time(NULL);
        friendListVersion                  = CS_TFS_FORCE_REFRESH_VER;
        maPendingUserQuery                 = nil;
        isLoaded                           = NO;
        recomputeFriends                   = YES;
        msActiveUserFeeds                  = [[NSMutableSet alloc] init];
        cachedFriendshipState              = CSFT_FS_REFINE;                // we never use NONE here.
        mdBrokenFriends                    = [[NSMutableDictionary alloc] init];
        msIgnoreFriends                    = [[NSMutableSet alloc] init];
        numConsistentlyCachedProfileImages = 0;
        numPendingProfileDownloads         = 0;
        maPendingFriendTimelineRequests    = nil;
        dtProfileImageDelay                = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    delegate = nil;
    [mdUserData release];
    mdUserData = nil;
    
    [mdAccountToUser release];
    mdAccountToUser = nil;
    
    [msMyUserIds release];
    msMyUserIds = nil;
    
    [maPendingUserQuery release];
    maPendingUserQuery = nil;
    
    [urlDatabase release];
    urlDatabase = nil;
    
    [urlTwitterBase release];
    urlTwitterBase = nil;
    
    [msActiveUserFeeds release];
    msActiveUserFeeds = nil;
    
    [mdBrokenFriends release];
    mdBrokenFriends = nil;
    
    [msIgnoreFriends release];
    msIgnoreFriends = nil;
    
    [maPendingFriendTimelineRequests release];
    maPendingFriendTimelineRequests = nil;
    
    [dtProfileImageDelay release];
    dtProfileImageDelay = nil;
    
    [super dealloc];
}

/*
 *  Assign the base type URL to the friendship state.
 */
-(void) setBaseTypeURL:(NSURL *) uBase
{
    @synchronized (self) {
        if (![uBase isEqual:urlTwitterBase]) {
            [urlTwitterBase release];
            urlTwitterBase = [uBase retain];
            [urlDatabase release];
            urlDatabase = nil;
            
            // - try to load the friendship state initially.
            [self loadFriendshipState];
        }
    }
}

/*
 *  Returns whether a base URL exists for this friendship state.
 */
-(BOOL) hasBaseURL
{
    @synchronized (self) {
        return (urlTwitterBase ? YES : NO);
    }
}

/*
 *  Return the computed friendship state for the object.
 */
-(csft_friendship_state_t) friendshipStateInType:(CS_feedTypeTwitter *) twitterFeedType
{
    // - It is important that this value is _always computed_ based on the best information we have available in
    //   the database because when feeds are disabled, that ends up impacting what kinds of relationships we can have and
    //   ultimately how connections are resolved between people.
    NSSet *sTmpActive = [self availableFeedsForProcessingFromType:twitterFeedType];
    @synchronized (self) {
        // - make changes if necessary.
        [self recomputeCachedStateIfNecessaryUsingFeeds:sTmpActive];

        // - and return the cached value
        return cachedFriendshipState;
    }
}

/*
 *  Return the list of friends that are available through this type.
 */
-(NSArray *) feedFriendsInType:(CS_feedTypeTwitter *) twitterFeedType
{
    NSMutableArray *maFriends = [NSMutableArray array];
    NSSet          *sTmpActive = [self availableFeedsForProcessingFromType:twitterFeedType];
    @synchronized (self) {
        if (numFriends) {
            // - make sure that the state is up to date before continuing.
            [self recomputeCachedStateIfNecessaryUsingFeeds:sTmpActive];
            
            // - now build the return results.
            for (CS_tfsUserData *udata in mdUserData.allValues) {
                if (udata.isMe || [msIgnoreFriends containsObject:udata.screenName]) {
                    continue;
                }
                
                // - build a feed friend object to return.
                ChatSealFeedFriend *csff = [self feedFriendForUserData:udata inType:twitterFeedType];
                
                // - and add to the return array.
                [maFriends addObject:csff];
            }
        }
    }
    
    // - the last thing will be to sort the content in the array
    [maFriends sortUsingComparator:^NSComparisonResult(ChatSealFeedFriend *f1, ChatSealFeedFriend *f2){
        if (f1.isIdentified && f2.isIdentified) {
            return [f1.friendNameOrDescription compare:f2.friendNameOrDescription];
        }
        else if (f1.isIdentified) {
            return NSOrderedAscending;
        }
        else {
            return NSOrderedDescending;
        }
    }];
    
    return maFriends;
}

/*
 *  Return whether we should request an immediate change to update our content.
 */
-(BOOL) hasHighPriorityWorkToPerformInType:(CS_feedTypeTwitter *) twitterFeedType
{
    // - also, if the network is down, don't bother.
    if (![twitterFeedType areFeedsNetworkReachable]) {
        return NO;
    }

    @synchronized (self) {
        // - if there are already pending items to query, it is a no-brainer.
        if ([maPendingUserQuery count]) {
            return YES;
        }
    }
    
    // - see if we're in need of a refresh cycle.
    if ([self computeIfRefreshIsAppropriateInType:twitterFeedType]) {
        return YES;
    }
    
    // - if we just recomputed, we may have a new set of profile images to grab.
    @synchronized (self) {
        if (numConsistentlyCachedProfileImages != [self numberOfExpectedProfileImages]) {
            return YES;
        }
    }

    return NO;
}

/*
 *  Analyze the friendships in the Twitter feeds.
 *  - Return YES if we were able to do what we needed to do without getting hung up or throttled.
 */
-(BOOL) processFeedTypeRequestsUsingFeed:(ChatSealFeed *) feed inType:(CS_feedTypeTwitter *) twitterFeedType
{
    //  NOTE:  The methodology here is to always assume that the most recently computed state is accurate until it is proven false.   So, if we got a state, we're going
    //         to use it until we have a complete new state.  If we don't have a state, we'll assume that the friendship state is good.
    
    // - when a feed cannot accept API requests, we aren't even going to try to process requests with it.
    if (![feed isViableMessagingTarget] || ![twitterFeedType areFeedsNetworkReachable]) {
        return NO;
    }
    
    // - make sure the profile images are requested, which occur outside the normal auth path.
    [self requestProfileImagesIfRequired];

    // - friendship state is something that is completely optional and offerred only as a convenience to try to keep people connected, so
    //   we are only going to update it when absolutely necessary.
    if (![self hasHighPriorityWorkToPerformInType:twitterFeedType]) {
        return YES;
    }
    
    // - now begin working on the data retrieval tasks.
    if (![self attemptToScheduleUserQueriesUsingFeed:feed]) {
        return NO;
    }
    
    return YES;
}

/*
 *  A feed has responded with some friendship data we can add to our internal state.
 *  - this takes a dictionary of masks as returned by the CS_tapi_friendships_lookup API.
 */
-(void) updateFriendshipsWithResultMasks:(NSDictionary *) dictMasks fromFeed:(ChatSealFeed *) feed inType:(CS_feedTypeTwitter *) twitterFeedType
{
    // - nothing we can do, the API failed.
    if (!dictMasks) {
        return;
    }
    
    BOOL wasChanged           = NO;
    @synchronized (self) {
        //  we need to pull the user data for the given feed.
        CS_tfsUserData *myUser = [self retrieveOrCreateUserForScreenName:feed.userId asMe:YES andWasCreated:NULL];
        for (NSString *screenName in dictMasks.allKeys) {
            CS_tapi_friendship_state *fs = [dictMasks objectForKey:screenName];
            CS_tfsUserData *udata        = [self retrieveOrCreateUserForScreenName:screenName asMe:NO andWasCreated:NULL];
            if ([myUser addFriendshipState:fs forFriend:udata]) {
                wasChanged = YES;
            }
        }
        
        // - if we updated the state, make sure to save.
        if (wasChanged) {
            [self saveFriendshipStateAndForceCachedStateRecalc:YES];
        }
    }
}

/*
 *  Don't track health for a given friend id.
 */
-(BOOL) ignoreFriendByAccountId:(NSString *) acctId
{
    @synchronized (self) {
        if ([msIgnoreFriends containsObject:acctId]) {
            return YES;
        }
        [self removeAllTrackingForFriend:acctId andIgnore:YES andSaveWhenDone:YES];
    }
    return YES;
}

/*
 *  Stop ignoring one or more friends.
 */
-(void) restoreFriendsAccountIds:(NSArray *) arrFriends
{
    @synchronized (self) {
        if (![arrFriends count]) {
            return;
        }
        NSUInteger count = [msIgnoreFriends count];
        [msIgnoreFriends minusSet:[NSSet setWithArray:arrFriends]];
        if (count != [msIgnoreFriends count]) {
            NSLog(@"CS: Local friends have been restored, refreshing friendship state.");
            lastRefresh       = 0;
            friendListVersion = CS_TFS_FORCE_REFRESH_VER;
            [self saveFriendshipStateAndForceCachedStateRecalc:YES];
        }
    }
}

/*
 *  Return a dictionary of feed names to their associated connection refinements.
 */
-(NSArray *) localFeedsConnectionStatusWithFriend:(ChatSealFeedFriend *) feedFriend inType:(CS_feedTypeTwitter *) twitterFeedType
{
    NSArray *arrFeeds     = [twitterFeedType feeds];
    NSMutableArray *maRet = [NSMutableArray array];
    
    // first make sure that at least one of these is viable.
    BOOL hasViableFeed    = NO;
    for (ChatSealFeed *f in arrFeeds) {
        if ([f isViableMessagingTarget]) {
            hasViableFeed = YES;
            break;
        }
    }
    
    @synchronized (self) {
        CS_tfsUserData *udataFriend = [mdUserData objectForKey:feedFriend.userId];
        for (ChatSealFeed *f in arrFeeds) {
            CS_tfsUserData *udata             = [mdUserData objectForKey:[f userId]];
            CS_tfsMessagingDeficiency *def    = nil;
            if (hasViableFeed) {
                def = [udata deficiencyForFriendWithKey:udataFriend.accountKey];            //  may be nil if none exist!
            }
            else {
                def = [CS_tfsMessagingDeficiency deficiencyForAllFeedsDisabled];
            }
            CS_tfsFriendshipAdjustment *toAdj = [[[CS_tfsFriendshipAdjustment alloc] initWithDeficiency:def forLocalFeed:f] autorelease];
            if (!def && udata.userAccountIsProtected) {
                // - when there is no adjustment, but we have a protected account, we will want to flag this adjustment as being
                //   a regular update one so that we detect friendship requests.
                CS_tapi_friendship_state *state = [udata stateForFriendByKey:udataFriend.accountKey];
                if (state && ![state isFollowedBy]) {
                    [toAdj setCanBenefitFromRegularUpdates:YES];
                }
            }
            [maRet addObject:toAdj];
        }
    }
    
    // - sort the return data
    [maRet sortUsingComparator:^NSComparisonResult(CS_tfsFriendshipAdjustment *fa1, CS_tfsFriendshipAdjustment *fa2) {
        return [fa1.screenName compare:fa2.screenName];
    }];
    
    return maRet;
}

/*
 *  Generate a single recommended adjustment for a given feed.
 */
-(CS_tfsFriendshipAdjustment *) recommendedAdjustmentForFeed:(ChatSealFeed *) feed withFriend:(ChatSealFeedFriend *) feedFriend
{
    @synchronized (self) {
        CS_tfsUserData *udataFriend       = [mdUserData objectForKey:feedFriend.userId];
        CS_tfsUserData *udata             = [mdUserData objectForKey:[feed userId]];
        CS_tfsMessagingDeficiency *def    = [udata deficiencyForFriendWithKey:udataFriend.accountKey];         // may be nil
        CS_tfsFriendshipAdjustment *toAdj = [[[CS_tfsFriendshipAdjustment alloc] initWithDeficiency:def forLocalFeed:feed] autorelease];
        if (!def && udata.userAccountIsProtected) {
            // - when there is no adjustment, but we have a protected account, we will want to flag this adjustment as being
            //   a regular update one so that we detect friendship requests.
            CS_tapi_friendship_state *state = [udata stateForFriendByKey:udataFriend.accountKey];
            if (state && ![state isFollowedBy]) {
                [toAdj setCanBenefitFromRegularUpdates:YES];
            }
        }
        return toAdj;
    }
}

/*
 *  Update the following state for the feed/friend combination.
 */
-(void) setFeed:(CS_twitterFeed *) feed withFollowing:(BOOL) isFollowing forFriendName:(NSString *) friendName
{
    @synchronized (self) {
        // - we aren't going to track data for people who aren't yet trusted, which is why we don't create the friend.
        CS_tfsUserData *udataFriend = [mdUserData objectForKey:friendName];
        if (udataFriend) {
            CS_tfsUserData *udata = [self retrieveOrCreateUserForScreenName:[feed userId] asMe:YES andWasCreated:nil];
            if ([udata setFriendByKey:udataFriend.accountKey asFollowing:isFollowing]) {
                [self updateFriend:udataFriend andNotifyInFeed:feed];
            }
        }
    }
}

/*
 *  Update the blocking state for the feed/friend combination.
 */
-(void) setFeed:(CS_twitterFeed *) feed asBlocking:(BOOL) isBlocking forFriendName:(NSString *) friendName
{
    @synchronized (self) {
        // - we aren't going to track data for people who aren't yet trusted, which is why we don't create the friend.
        CS_tfsUserData *udataFriend = [mdUserData objectForKey:friendName];
        if (udataFriend) {
            CS_tfsUserData *udata = [self retrieveOrCreateUserForScreenName:[feed userId] asMe:YES andWasCreated:nil];
            if ([udata setFriendByKey:udataFriend.accountKey asBlocking:isBlocking]) {
                [self updateFriend:udataFriend andNotifyInFeed:feed];
            }
        }
    }
}

/*
 *  Mark a particular friend as blocking us.
 */
-(void) markFeed:(CS_twitterFeed *) feed asBlockedByFriendWithName:(NSString *) friendName
{
    @synchronized (self) {
        // - we aren't going to track data for people who aren't yet trusted, which is why we don't create the friend.
        CS_tfsUserData *udataFriend = [mdUserData objectForKey:friendName];
        if (udataFriend) {
            CS_tfsUserData *udata = [self retrieveOrCreateUserForScreenName:[feed userId] asMe:YES andWasCreated:nil];
            if ([udata markFriendByKeyAsBlockingMyFeed:udataFriend.accountKey]) {
                [self updateFriend:udataFriend andNotifyInFeed:feed];
            }
        }
    }
}

/*
 *  Reconcile the state from one of my feeds to a target friend.
 *  - NOTE: this is only intended to be used when we are just about certain there is a friendship record that can be quickly found.  This
 *          is not a good approach for a lot of records.
 */
-(void) reconcileKnownFriendshipStateFromFeed:(CS_twitterFeed *) feed toFriend:(NSString *) friendName withPendingTask:(id<CS_twitterFeed_highPrio_task>) task
{
    @synchronized (self) {
        CS_tfsUserData *udataFriend = [mdUserData objectForKey:friendName];
        if (udataFriend) {
            CS_tfsUserData *udata = [self retrieveOrCreateUserForScreenName:[feed userId] asMe:YES andWasCreated:nil];
            if ([udata reconcileFriendByName:friendName andKey:udataFriend.accountKey withPendingTask:task]) {
                [self updateFriend:udataFriend andNotifyInFeed:feed];
            }
        }
    }
}

/*
 *  Return the state for the given friend in the given feed.
 */
-(CS_tapi_friendship_state *) stateForFriendByName:(NSString *) screenName inFeed:(CS_twitterFeed *) feed
{
    @synchronized (self) {
        CS_tfsUserData *udataFriend = [mdUserData objectForKey:screenName];
        if (udataFriend) {
            CS_tfsUserData *udata = [self retrieveOrCreateUserForScreenName:[feed userId] asMe:YES andWasCreated:nil];
            return [udata stateForFriendByKey:udataFriend.accountKey];
        }
    }
    return nil;
}

/*
 *  Return an updated feed friend object if things have changed.
 */
-(ChatSealFeedFriend *) refreshFriendFromFriend:(ChatSealFeedFriend *) feedFriend inType:(CS_feedTypeTwitter *) twitterFeedType
{
    if (!feedFriend) {
        return nil;
    }
    
    @synchronized (self) {
        CS_tfsUserData *udata = [mdUserData objectForKey:feedFriend.userId];
        
        // - save time and only recreate one of these if something has changed.
        if (udata && udata.userVersion != feedFriend.friendVersion) {
            feedFriend = [self feedFriendForUserData:udata inType:twitterFeedType];
        }
        return feedFriend;
    }
}

/*
 *  Update the version number on one of my friends.
 */
-(void) incrementUserVersionForScreenName:(NSString *) screenName
{
    if (!screenName) {
        return;
    }
    
    @synchronized (self) {
        CS_tfsUserData *udata = [mdUserData objectForKey:screenName];
        if (udata) {
            udata.userVersion++;
        }
    }
}

/*
 *  Under very special circumstances, we'll allow deficiencies to be cleared out because we can't trust them.
 */
-(void) markFriendDeficienciesAsStaleForFeed:(CS_twitterFeed *) feed inType:(CS_feedTypeTwitter *) twitterFeedType
{
    NSString *sName = [feed userId];
    if (!sName) {
        return;
    }
    
    @synchronized (self) {
        CS_tfsUserData *udata = [mdUserData objectForKey:sName];
        if ([udata isMe]) {
            NSArray *arrKeys = [udata discardAllHealthIssuesAndReturnFriends];
            if (arrKeys && [arrKeys count]) {
                for (NSNumber *n in arrKeys) {
                    CS_tfsUserData *udataFriend = [mdAccountToUser objectForKey:n];
                    udataFriend.userVersion++;
                }
                [self saveFriendshipStateAndForceCachedStateRecalc:YES];
            }
        }
    }
}

/*
 *  When we get updates for a given friend, try to merge-in the modifications.
 */
-(void) updateTargetedFriendshipWithResults:(CS_tapi_friendships_show *) apiFriend fromFeed:(ChatSealFeed *) feed inType:(CS_feedTypeTwitter *) twitterFeedType
{
    // - nothing we can do, the API failed.
    if (![apiFriend isAPISuccessful]) {
        return;
    }
    
    CS_tapi_friendship_state *fs = [apiFriend resultTargetState];
    @synchronized (self) {
        //  we need to pull the user data for the given feed.
        CS_tfsUserData *myUser = [self retrieveOrCreateUserForScreenName:feed.userId asMe:YES andWasCreated:NULL];
        CS_tfsUserData *udata  = [self retrieveOrCreateUserForScreenName:apiFriend.targetScreenName asMe:NO andWasCreated:NULL];
        if ([myUser addFriendshipState:fs forFriend:udata]) {
            [feed fireFriendshipUpdateNotification];
            [self saveFriendshipStateAndForceCachedStateRecalc:YES];
        }
    }
}

/*
 *  Determine if my friend is following me.
 */
-(BOOL) isFriend:(NSString *) friendName followingMyFeed:(CS_twitterFeed *) feed
{
    NSString *myName = [feed userId];
    @synchronized (self) {
        CS_tfsUserData *myUser       = [mdUserData objectForKey:myName];
        CS_tfsUserData *udata        = [mdUserData objectForKey:friendName];
        if (myUser && udata && !udata.isDeleted) {
            CS_tapi_friendship_state *fs = [myUser stateForFriendByKey:udata.accountKey];
            if ([fs isFollowedBy]) {
                return YES;
            }
        }
    }
    return NO;
}

/*
 *  Determine if there is anything preventing me from reading my friend's feed.
 */
-(BOOL) canMyFeed:(CS_twitterFeed *) feed readMyFriend:(NSString *) friendName
{
    NSString *myName = [feed userId];
    @synchronized (self) {
        CS_tfsUserData *myUser       = [mdUserData objectForKey:myName];
        CS_tfsUserData *udata        = [mdUserData objectForKey:friendName];
        if (myUser && udata) {
            if (udata.isDeleted) {
                return NO;
            }
            CS_tapi_friendship_state *fs = [myUser stateForFriendByKey:udata.accountKey];
            if ([fs isBlockingMyAccount] ||
                ([fs isProtected] && ![fs isFollowing])) {
                return NO;
            }
        }
    }
    return YES;
}

/*
 *  Return all the connectivity states for the friends in the given feed.
 */
-(NSDictionary *) statesForAllReachableFriendsInFeed:(CS_twitterFeed *) feed
{
    NSString *myName = [feed userId];
    if (!myName) {
        return nil;
    }
    @synchronized (self) {
        CS_tfsUserData *myUser = [mdUserData objectForKey:myName];
        if (!myUser) {
            return nil;
        }
       
        NSMutableDictionary *mdRet = [NSMutableDictionary dictionary];
        NSDictionary *dictFriends  = [myUser allReachableFriends];
        if (![dictFriends count]) {
            return mdRet;
        }
        
        [dictFriends enumerateKeysAndObjectsUsingBlock:^(NSNumber *nKey, CS_tapi_friendship_state *state, BOOL *stop) {
            CS_tfsUserData *uTmp = [mdAccountToUser objectForKey:nKey];
            if (uTmp && ![uTmp isMe] && !uTmp.isDeleted) {
                [mdRet setObject:state forKey:uTmp.screenName];
            }
        }];
        return mdRet;
    }
}

/*
 *  Return a feed that can read my friend's content.
 */
-(CS_twitterFeed *) bestLocalFeedForReadingFriend:(NSString *) friendName usingFeedList:(NSArray *) feedList
{
    // - search through our local feeds until we find our guy.
    @synchronized (self) {
        CS_tfsUserData *udataFriend = [mdUserData objectForKey:friendName];
        if (!udataFriend) {
            return nil;
        }
        
        NSNumber *n = udataFriend.accountKey;
        for (NSString *myUID in msMyUserIds) {
            CS_tfsUserData *udata        = [mdUserData objectForKey:myUID];
            CS_tapi_friendship_state *fs = [udata stateForFriendByKey:n];
            if ([fs isReadable]) {
                // - if the state is good, make sure the feed can be used.
                for (CS_twitterFeed *tf in feedList) {
                    if ([[tf userId] isEqualToString:[udata screenName]]) {
                        if ([tf isViableMessagingTarget]) {
                            return tf;
                        }
                        break;
                    }
                }
            }
        }
    }
    return nil;
}

/*
 *  We're going to non-persistently track all user timeline requests so that duplicate or overlapping ones are never issued.
 *  - NOTE: we EXPECT the range to not have concrete values and no nils.
 */
-(BOOL) isTimelineRequestPermittedForFriend:(NSString *) friendName andRange:(CS_tapi_tweetRange *) range fromFeed:(CS_twitterFeed *) feed
{
    // - we really need good data or the pending queue could get gummed up quick.
    if (!friendName || !range || !feed.userId) {
        return NO;
    }
    
    // - we DO NOT persist these requests because they are only intended to prevent duplicates when there are more than one feed.
    @synchronized (self) {
        if (!maPendingFriendTimelineRequests) {
            maPendingFriendTimelineRequests = [[NSMutableArray alloc] init];
        }
        
        for (CS_tfsPendingUserTimelineRequest *req in maPendingFriendTimelineRequests) {
            if ([req.screenName isEqualToString:friendName] && [req.requestedRange isIntersectedBy:range]) {
                return NO;
            }
        }
        
        // - no intersections found, so we can add a new one to the list.
        [maPendingFriendTimelineRequests addObject:[CS_tfsPendingUserTimelineRequest requestForScreenName:friendName andRange:range fromLocalUser:feed.userId]];
    }
    
    return YES;
}

/*
 *  When  a user timeline request commpletes, make sure it is untracked so that others can be made.
 */
-(void) completeTimelineRequestForFriend:(NSString *) friendName andRange:(CS_tapi_tweetRange *) range
{
    @synchronized (self) {
        for (NSUInteger i = 0; i < [maPendingFriendTimelineRequests count]; i++) {
            CS_tfsPendingUserTimelineRequest *req = [maPendingFriendTimelineRequests objectAtIndex:i];
            if (![req.screenName isEqualToString:friendName]) {
                continue;
            }
     
            // - when we find the exact screen name and range, delete it and return.
            if ([req.requestedRange isEqualToRange:range]) {
                [maPendingFriendTimelineRequests removeObjectAtIndex:i];
                return;
            }
            
        }
    }
}

/*
 *  Any pending user timeline requests for the given feed are discarded, usually when the feed is deleted or disabled.
 */
-(void) discardAllTimelineRequestsFromFeed:(CS_twitterFeed *) feed
{
    @synchronized (self) {
        NSMutableIndexSet *mis = [NSMutableIndexSet indexSet];
        for (NSUInteger i = 0; i < [maPendingFriendTimelineRequests count]; i++) {
            CS_tfsPendingUserTimelineRequest *req = [maPendingFriendTimelineRequests objectAtIndex:i];
            if ([req.localUser isEqualToString:feed.userId]) {
                [mis addIndex:i];
            }
        }
        
        // - delete any we found
        if ([mis count]) {
            [maPendingFriendTimelineRequests removeObjectsAtIndexes:mis];
        }
    }
}

/*
 *  Check if we have friends.
 */
-(BOOL) doesFriendshipDatabaseSupporFollowingWarning
{
    @synchronized (self) {
        if (!isInitialRefresh && !numFriends) {
            return YES;
        }
    }
    return NO;
}

/*
 *  Determine if it is a good idea if we use a reply syntax when sending back to this friend.
 */
-(BOOL) canUseTwitterReplyToFriend:(NSString *) friendName fromMyFeed:(CS_twitterFeed *) feed whenUsingSeal:(NSString *) sealId
{
    // - Twitter replies are very particular things.  If we reply to a friend, no one else who follows me will see it on their
    //   home timeline, which means it is very focused and not well-suited to mining multiple feeds at the same time.
    // - We need to make sure it is going to be a benefit for connecting people.
    
    ChatSealIdentity *ident = [ChatSeal identityForSeal:sealId withError:nil];
    NSArray *friendLocs     = [ident friendFeedLocations];
    
    @synchronized (self) {
        // ...it never makes sense if we're protected because people won't see a protected account's mentions if they're not
        //    following already, in which case, what does it matter then?
        CS_tfsUserData *udata = [mdUserData objectForKey:[feed userId]];
        if (!udata || [udata userAccountIsProtected]) {
            return NO;
        }
        
        // ...if any of the seal owner's feeds is already following me, then do not reply because they won't see it if they
        //    aren't the reply target.
        for (ChatSealFeedLocation *loc in friendLocs) {
            CS_tfsUserData *udataFriend  = [mdUserData objectForKey:loc.feedAccount];
            CS_tapi_friendship_state *fs = nil;
            if (udataFriend) {
                fs = [udata stateForFriendByKey:[udataFriend accountKey]];
                if (fs.isFollowedBy) {
                    return NO;
                }
            }
        }
    }
    
    // - allow it if everything else is satsified.
    return YES;
}

/*
 *  Determine if we're tracking the given friend.
 *  - this does not include ignored friends in the test.
 *  - this performs an exhaustive test as a case-insensitive compare to be sure we don't have collisions.
 */
-(BOOL) isTrackingFriendByName:(NSString *) friendName
{
    friendName = [friendName lowercaseString];
    @synchronized (self) {
        for (CS_tfsUserData *udata in mdUserData.allValues) {
            NSString *sTmp = udata.screenName;
            if ([friendName isEqualToString:[sTmp lowercaseString]] && ![msIgnoreFriends containsObject:sTmp]) {
                return YES;
            }
        }
    }
    return NO;
}

/*
 *  Begin tracking a new friend.
 */
-(void) trackUnprovenFriendByName:(NSString *) friendName andInitializeWith:(CS_tapi_user_looked_up *) userInfo
{
    if (!friendName) {
        return;
    }
    
    @synchronized (self) {
        BOOL wasCreated = NO;
        [msIgnoreFriends removeObject:friendName];
        CS_tfsUserData *udata = [self retrieveOrCreateUserForScreenName:friendName asMe:NO andWasCreated:&wasCreated];
        if (udata && wasCreated) {
            // - when user info is passed, we'll prepopulate the friend to save some time.
            if (userInfo) {
               [udata updateWithUserProfile:userInfo];
            }
            
            // - make sure our local count is updated.
            numFriends++;
            
            // - make sure the next refresh forces a repopulation
            friendListVersion = CS_TFS_FORCE_REFRESH_VER;
            
            NSNumber *nKey                = udata.accountKey;
            NSArray *arrFriend            = [NSArray arrayWithObject:nKey];
            CS_tfsMessagingDeficiency *md = nil;
            for (CS_tfsUserData *udataLocal in [self localUsers]) {
                // - it is important to track unqueried health issues because we need to know if
                //   these friends are useful for mining and/or connectivity.
                [udataLocal addUnqueriedHealthIssuesForNewFriends:arrFriend];
                
                CS_tfsMessagingDeficiency *mdTmp = [udataLocal deficiencyForFriendWithKey:nKey];
                md                               = [CS_tfsMessagingDeficiency unionOfDeficiency:md withDeficiency:mdTmp];
            }
            
            // - there should be a deficiency to flag with this friend until we get the first results back.
            if (md) {
                [mdBrokenFriends setObject:md forKey:nKey];
            }
            
            // - no need to recalc the cached state yet because there is no connectivity for this friend yet.
            [self saveFriendshipStateAndForceCachedStateRecalc:NO];
        }
    }
}

/*
 *  This will delete everything associated with a given feed.
 */
-(void) discardAllLocalUserStateForFeed:(ChatSealFeed *) feed
{
    NSString *name = [feed userId];
    @synchronized (self) {
        if ([mdUserData objectForKey:name]) {
            [self discardUserWithScreenName:name];
            [self saveFriendshipStateAndForceCachedStateRecalc:YES];
        }
    }
}
@end

/*************************************
 CS_twitterFriendshipState (internal)
 *************************************/
@implementation CS_twitterFriendshipState (internal)
/*
 *  Returns the user for the given screen name.
 *  - ASSUMES the lock is held.
 */
-(CS_tfsUserData *) retrieveOrCreateUserForScreenName:(NSString *) screenName asMe:(BOOL) isMe andWasCreated:(BOOL *) wasCreated
{
    CS_tfsUserData *ret = [mdUserData objectForKey:screenName];
    BOOL flagCreated    = NO;
    if (!ret) {
        // - the goal here is to only ever have a single copy of the screen name string because
        //   it could get costly to store these if the person has a lot of friends.
        ret = [CS_tfsUserData userDataForScreenName:screenName asAccount:++lastAccount andIsMe:isMe];
        [mdUserData setObject:ret forKey:screenName];
        [mdAccountToUser setObject:ret forKey:ret.accountKey];
        flagCreated = YES;
    }
    
    if (wasCreated) {
        *wasCreated = flagCreated;
    }
    
    return ret;
}

/*
 *  Fully discard the given user.
 *  - ASSUMES the lock is held.
 */
-(void) discardUserWithScreenName:(NSString *) screenName
{
    CS_tfsUserData *udata = [mdUserData objectForKey:screenName];
    if (udata) {
        [mdAccountToUser removeObjectForKey:udata.accountKey];
        if (udata.cachedProfileHash) {
            [self discardFriendProfileImageInUser:udata];
        }
    }
    [mdUserData removeObjectForKey:screenName];
}

/*
 *  Get the list of local users.
 *  - ASSUMES the lock is held.
 */
-(NSMutableArray *) localUsers
{
    NSMutableArray *maRet = [NSMutableArray array];
    for (NSString *screenName in msMyUserIds) {
        CS_tfsUserData *udata = [self retrieveOrCreateUserForScreenName:screenName asMe:YES andWasCreated:NULL];
        if (udata) {
            [maRet addObject:udata];
        }
    }
    return maRet;
}

/*
 *  Returns the account keys of only my friends.
 *  - ASSUMES the lock is held.
 */
-(NSArray *) allFriendKeys
{
    NSMutableArray *maRet = [NSMutableArray arrayWithArray:mdAccountToUser.allKeys];
    
    // - remove the local users, but do not query the localUsers method because that
    //   implicitly creates them if they do not exist.
    for (NSString *screenName in msMyUserIds) {
        CS_tfsUserData *udata = [mdUserData objectForKey:screenName];
        NSNumber *nAcctKey    = udata.accountKey;
        if (nAcctKey) {
            [maRet removeObject:nAcctKey];
        }
    }
    
    return maRet;
}

/*
 *  This method will look at the best data we have and determine if we should refresh the friendshp state
 *  items.
 *  - returns YES when a refresh should be performed.
 */
-(BOOL) computeIfRefreshIsAppropriateInType:(CS_feedTypeTwitter *) twitterFeedType
{
    // - the idea here is if the list of friends has changed or my list of accounts has changed, we should
    //   update the friendship states.
    
    // - first figure out the list of feed names because they need to be considered at the same time
    //   as my friends.
    NSMutableSet *msTmpMyFeeds = [NSMutableSet set];
    NSArray *arrFeeds          = [twitterFeedType feeds];
    for (ChatSealFeed *feed in arrFeeds) {
        // - for Twitter the user id is the screen name and can be used for all queries.
        [msTmpMyFeeds addObject:[feed userId]];
    }

    // - now with my user list and the current friend version, I can rule out a lot of different update scenarios.
    NSUInteger curFriendVersion = [ChatSeal friendsListVersionForFeedsOfType:kChatSealFeedTypeTwitter];
    BOOL shouldRebuildFriends   = NO;
    BOOL didRebuildAccounts     = NO;
    BOOL wasInitial             = NO;
    @synchronized (self) {
        // - load the state if possible
        if (!isLoaded) {
            [self loadFriendshipState];
        }
        
        // - when the list of users has not changed and the friend versions are the same or we aren't yet scheduled
        //   for a state scan, just ignore this request.
        if ((isInitialRefresh && (time(NULL) - lastRefresh) < CS_TFS_INITIAL_UPDATE_DELAY && ![ChatSeal wasVaultJustCreated]) ||
            ([msTmpMyFeeds isEqualToSet:msMyUserIds] &&
              curFriendVersion == friendListVersion &&
              (time(NULL) - lastRefresh) < CS_TFS_UPDATE_PERIOD)) {
            return NO;
        }
     
        [self forceFriendshipRecalculation];
        wasInitial        = isInitialRefresh;
        isInitialRefresh  = NO;
        lastRefresh       = time(NULL);
        if (friendListVersion != curFriendVersion) {
            shouldRebuildFriends = YES;
        }
        friendListVersion = curFriendVersion;

        // - update the user accounts based on what we just found.
        if (![msTmpMyFeeds isEqualToSet:msMyUserIds]) {
            // ...we need to do two important things here.  Any new users need
            // to be explicitly deleted if they were once friends because that will
            // hose up all our accounting.  We also need to delete any users who no longer
            // exist because there's no need to track them.
            
            // ...delete old friends who are new users (this is a rare scenario when my account was followed and then gets added).
            NSMutableSet *msNew = [NSMutableSet setWithSet:msTmpMyFeeds];
            [msNew minusSet:msMyUserIds];
            for (NSString *sId in msNew) {
                [self removeAllTrackingForFriend:sId andIgnore:NO andSaveWhenDone:NO];
            }

            // ...now delete all the stale local users.
            [msMyUserIds minusSet:msTmpMyFeeds];
            for (NSString *sId in msMyUserIds) {
                [self discardUserWithScreenName:sId];
            }
            [msMyUserIds removeAllObjects];
            
            //   ...now add the new content.
            [msMyUserIds addObjectsFromArray:[msTmpMyFeeds allObjects]];
            for (NSString *sUid in msNew) {
                CS_tfsUserData *udata = [self retrieveOrCreateUserForScreenName:sUid asMe:YES andWasCreated:NULL];
                [udata flagAsProven];
            }
            didRebuildAccounts = YES;
        }
    }

    // - if we got this far, we need to get a list of friends, but this can be somewhat expensive to
    //   perform so do it sparingly.
    NSArray *arrFriends = nil;
    if (shouldRebuildFriends) {
        arrFriends = [ChatSeal friendsForFeedsOfType:kChatSealFeedTypeTwitter];
    }
    
    NSMutableArray *maFriendsToCheck = [NSMutableArray array];
    NSMutableArray *maNewFriends     = [NSMutableArray array];
    BOOL ret                         = NO;

    // - Ok, so do the final updates of the friend list and pending content because we know we must do something here.
    @synchronized (self) {
        // - when we have a new set of friends, we will need to update the master user database first.
        if (shouldRebuildFriends) {
            // - we need to count the friends that aren't in the black list.
            numFriends = 0;
            
            // - we're creating a new user database based on the intersection of the two data sets.
            NSMutableDictionary *mdTmp = [NSMutableDictionary dictionary];
            for (ChatSealIdentityFriend *identFriend in arrFriends) {
                NSString *screenName  = identFriend.location.feedAccount;
                
                // - don't track friends that are supposed to be ignored.
                if ([msIgnoreFriends containsObject:screenName]) {
                    if ([mdUserData objectForKey:screenName]) {
                        didRebuildAccounts = YES;
                    }
                    continue;
                }
                
                BOOL wasCreated       = NO;
                CS_tfsUserData *udata = [self retrieveOrCreateUserForScreenName:screenName asMe:NO andWasCreated:&wasCreated];
                if (wasCreated) {
                    didRebuildAccounts = YES;
                    [maNewFriends addObject:udata.accountKey];
                }
                [udata updateWithFriendInfo:identFriend];
                [mdTmp setObject:udata forKey:screenName];
                numFriends++;
                
                // - we can flag this friend as proven because the idividual was retrieved from the identity database, which is only
                //   updated through seal-related activities.
                [udata flagAsProven];
            }

            // ...don't forget the local users.
            for (NSString *uid in msMyUserIds) {
                BOOL wasCreated = NO;
                CS_tfsUserData *udata = [self retrieveOrCreateUserForScreenName:uid asMe:YES andWasCreated:&wasCreated];
                if (wasCreated) {
                    didRebuildAccounts = YES;
                    [udata flagAsProven];
                }
                [mdTmp setObject:udata forKey:uid];
            }
            
            // - and make sure that any friends that no longer have an associated seal are still tracked.
            //   ...because we _never_ delete friends unless a person ignores them.  Friends are an anchor to ChatSeal.  If you
            //      are reminded about your friends, you may return to use the app.
            // - NOTE: these users MUST NEVER be flagged as proven because sometimes they exist because they were manually created.
            for (CS_tfsUserData *udataTmp in mdUserData.allValues) {
                if (!udataTmp.isMe && ![mdTmp objectForKey:udataTmp.screenName]) {
                    [mdTmp setObject:udataTmp forKey:udataTmp.screenName];
                    numFriends++;
                }
            }
            
            // - replace the old one with the new one.
            [mdUserData release];
            mdUserData = [mdTmp retain];
            
            // - and rebuild the account index.
            [mdAccountToUser removeAllObjects];
            for (CS_tfsUserData *udata in mdUserData.allValues) {
                [mdAccountToUser setObject:udata forKey:udata.accountKey];
            }
            
            // - and update the local users' connections
            NSArray *arrAccountKeys = mdAccountToUser.allKeys;
            for (CS_tfsUserData *udata in [self localUsers]) {
                [udata discardFriendshipStatesForAccountsNotInArray:arrAccountKeys];
                
                // - it is important to track unqueried health issues because we need to know if
                //   these friends are useful for mining and/or connectivity.
                [udata addUnqueriedHealthIssuesForNewFriends:maNewFriends];
            }
        }
        
        // - make sure that no matter what, we start fresh with our pending work.
        [maPendingUserQuery release];
        maPendingUserQuery = nil;
        
        // - make sure that when we add accounts that the relevant frienship state is recomputed
        if (didRebuildAccounts) {
            [self saveFriendshipStateAndForceCachedStateRecalc:YES];
        }
        
        // - if we have no friends, this state calculation isn't necessary because it is entirely about managing our friendships.
        if (numFriends) {
            // - the pending list are the users that we need to gather some information on in order to
            //   assess relationships.
            maPendingUserQuery = [[NSMutableArray arrayWithArray:[mdUserData allKeys]] retain];
            
            // - we're going to ask each feed to get friend information for us.
            [maFriendsToCheck addObjectsFromArray:maPendingUserQuery];
            [maFriendsToCheck removeObjectsInArray:msMyUserIds.allObjects];
            ret = YES;
        }
    }
    
    // - now request all the feeds and start prepping them for friend retrieval
    if (maFriendsToCheck.count) {
        for (ChatSealFeed *feed in twitterFeedType.feeds) {
            CS_twitterFeed *tf = (CS_twitterFeed *) feed;
            [tf requestHighPriorityLookupForFriends:maFriendsToCheck];
        }
    }
    
    // - first refresh is done.
    if (wasInitial) {
        if ([self.delegate respondsToSelector:@selector(initialFriendshipUpdateHasOccurredForState:)]) {
            [self.delegate performSelector:@selector(initialFriendshipUpdateHasOccurredForState:) withObject:self];
        }
    }

    // - returns whether we should perform a refresh.
    return ret;
}

/*
 *  Return the number of profile images we expect to see cached.
 *  - ASSUMES the lock is held.
 */
-(NSUInteger) numberOfExpectedProfileImages
{
    return [mdUserData count] - [msMyUserIds count];
}

/*
 *  Check if we need to update any profile images.
 */
-(void) requestProfileImagesIfRequired
{
    @synchronized (self) {
        if (numConsistentlyCachedProfileImages == [self numberOfExpectedProfileImages] ||
            numPendingProfileDownloads == CS_TFS_MAX_PROFILE_PER_UPD) {
            return;
        }
        
        // - when there is a profile image delay that means we encountered a problem and it required that we stop doing this for a bit.
        if (dtProfileImageDelay) {
            if ([dtProfileImageDelay compare:[NSDate date]] == NSOrderedDescending) {
                return;
            }
        }
        [dtProfileImageDelay release];
        dtProfileImageDelay = nil;

        // - we're going to only do these a bit at a time.
        NSArray *arrUsers = mdUserData.allValues;
        for (NSUInteger i = 0; i < [arrUsers count] && numPendingProfileDownloads < CS_TFS_MAX_PROFILE_PER_UPD; i++) {
            CS_tfsUserData *udata = [arrUsers objectAtIndex:i];
            if (udata.isMe || [udata hasRecentProfileImage] || udata.profileImageDownloadPending) {
                continue;
            }
            
            // - found one, let's request it.
            NSString *sProfile = udata.profileImage;
            if (!sProfile) {
                continue;
            }
            
            // - and convert to the larger version.
            NSString *sBiggerProfile = [sProfile stringByReplacingOccurrencesOfString:@"_normal." withString:@"_bigger."];
            NSURL *uProfile          = [NSURL URLWithString:sBiggerProfile ? sBiggerProfile : sProfile];
            
            // - this doesn't need to go through the normal channels of authentication, so we can just use the basic network
            //   support.
            NSString *sName                   = udata.screenName;
            udata.profileImageDownloadPending = YES;
            [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:uProfile]
                                               queue:[NSOperationQueue mainQueue]
                                   completionHandler:^(NSURLResponse *response, NSData *data, NSError *errConn) {
                                       
               @synchronized (self) {
                   numPendingProfileDownloads--;
                   CS_tfsUserData *udataUpdate = [mdUserData objectForKey:sName];
                   if (!udataUpdate) {
                       return;
                   }

                   // - make sure this is set back or we'll not download the image after a failure.
                   udataUpdate.profileImageDownloadPending = NO;
                   
                   // - now process the response.
                   if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                       NSHTTPURLResponse *respHTTP = (NSHTTPURLResponse *) response;
                       if (respHTTP.statusCode == CS_TWIT_RC_OK) {
                           // - save off the image, but validate it.
                           UIImage *img = [UIImage imageWithData:data];
                           if (!img) {
                               return;
                           }
                           
                           // - make sure it didn't change while we were updating it.
                           if ([udataUpdate.profileImage isEqualToString:sProfile]) {
                               [self saveFriendProfileImageData:data inUser:udataUpdate];
                           }
                       }
                       else if (respHTTP.statusCode == CS_TWIT_NOT_FOUND) {
                           // - don't try to update this again.
                           [udataUpdate setProfileImage:nil];
                       }
                       else {
                           // - set up a delay so that we back off for a bit.
                           [dtProfileImageDelay release];
                           dtProfileImageDelay = [[NSDate dateWithTimeIntervalSinceNow:CS_TF_PROF_IMAGE_DELAY] retain];
                       }
                   }
               }
            }];
            
            // - keep the pending count updated so that we don't overburden the system.
            numPendingProfileDownloads++;
        }
    }
}

/*
 *  If there are pending user items to query, start working on that.
 *  - if there is nothing to do or everything was handled, return YES.
 */
-(BOOL) attemptToScheduleUserQueriesUsingFeed:(ChatSealFeed *) feed
{
    // - the main challenge is that we may have more users than can fit into a single query, in which case we'll
    //   have to split them up into multiple requests, all the while respecting the synchronization requirements.
    for (;;) {
        NSArray *aToSchedule = nil;
        @synchronized (self) {
            if (![maPendingUserQuery count]) {
                return YES;
            }

            aToSchedule = [maPendingUserQuery subarrayWithRange:NSMakeRange(0, MIN([CS_tapi_users_lookup maxUsersPerRequest], [maPendingUserQuery count]))];
        }
        
        // - attempt to build a request.
        CS_tapi_users_lookup *tul = (CS_tapi_users_lookup *) [feed apiForName:@"CS_tapi_users_lookup" andReturnWasThrottled:nil withError:nil];
        if (!tul) {
            return NO;
        }
        [tul setScreenNames:aToSchedule];
        
        // - the completion block will be used here to ensure we get the results before the feed does.
        [tul setCustomCompletionBlock:^(CS_netFeedAPI *api, ChatSealFeed *owningFeed) {
            [self processUserQueryResuls:(CS_tapi_users_lookup *) api];
        }];

        // - try to schedule it.
        if (![feed addCollectorRequestWithAPI:tul andReturnWasThrottled:nil withError:nil]) {
            return NO;
        }
        
        // - now remove the items we scheduled from the pending query.
        @synchronized (self) {
            [maPendingUserQuery removeObjectsInArray:aToSchedule];
        }
    }
    
    // - just for completeness.
    return YES;
}

/*
 *  When user query results are returned, we'll pull them into our database.
 */
-(void) processUserQueryResuls:(CS_tapi_users_lookup *) tul
{
    BOOL wasChanged = NO;
    @synchronized (self) {
        // - check for failure first because that should be dealt with quickly
        if (![tul isAPISuccessful]) {
            // - when the query results in no results, we need to flag those users as deleted.
            NSArray *arrNames = [tul screenNames];
            if (tul.HTTPStatusCode == CS_TWIT_NOT_FOUND) {
                if ([self markFriendsAsDeletedInArray:arrNames]) {
                    [self saveFriendshipStateAndForceCachedStateRecalc:YES];
                }
            }
            
            // - nothing else can be done
            return;
        }

        // - Ok, fold-in the results.
        NSMutableArray *maChangedProt      = [NSMutableArray array];
        NSArray *arrUsers                  = [tul resultDataUserDefinitions];
        NSMutableArray *maUsersWithResults = [NSMutableArray array];
        for (CS_tapi_user_looked_up *tulu in arrUsers) {
            CS_tfsUserData *udata = [self retrieveOrCreateUserForScreenName:tulu.screenName asMe:[msMyUserIds containsObject:tulu.screenName] ? YES : NO andWasCreated:NULL];
            
            // ...make sure we know what was done.
            if (udata.userAccountIsProtected != tulu.isProtected) {
                [maChangedProt addObject:udata];
            }
            [maUsersWithResults addObject:tulu.screenName];
            
            // ...save the content in the object.
            NSString *profileImage = [udata profileImage];
            if ([udata updateWithUserProfile:tulu]) {
                wasChanged = YES;
                
                // ...if the profile image was updated, then we need to make sure that we know to recache it.
                if (![profileImage isEqualToString:[udata profileImage]] &&
                    udata.cachedProfileHash) {
                    numConsistentlyCachedProfileImages--;
                }
            }
        }
        
        BOOL forceRecalc = NO;
        
        // - if any of our requests were not answered, make sure we update those users as now deleted.
        NSArray *arrRequested = tul.screenNames;
        if ([arrRequested count] != [maUsersWithResults count]) {
            NSMutableArray *maToProc = [NSMutableArray arrayWithArray:arrRequested];
            [maToProc removeObjectsInArray:maUsersWithResults];
            if ([self markFriendsAsDeletedInArray:maToProc]) {
                wasChanged  = YES;
                forceRecalc = YES;
            }
        }
        
        // - If any of our friends changed their protection flag, update the local users.
        if ([maChangedProt count]) {
            forceRecalc = YES;
            for (CS_tfsUserData *myUser in [self localUsers]) {
                if ([myUser updateProtectionStateFromFriends:maChangedProt]) {
                    wasChanged = YES;
                }
            }
        }
        
        // - and save the results when something changes and only
        //   force a big recalculation of the friendship state when protection is modified.
        if (wasChanged) {
            [self saveFriendshipStateAndForceCachedStateRecalc:forceRecalc];
        }
    }
}

/*
 *  Returns a URL for the database.
 *  - ASSUMES the lock is held.
 */
-(NSURL *) urlDatabase
{
    // - in order to maintain privacy, we're going to generate a good salted name for this.
    if (!urlDatabase) {
        if (![ChatSeal isVaultOpen] || !urlTwitterBase) {
            return nil;
        }
        NSError *err    = nil;
        NSString *sName = [ChatSeal safeSaltedPathString:@"t-friends" withError:&err];
        if (!sName) {
            NSLog(@"CS: Failed to generate a friend database name.  %@", [err localizedDescription]);
            return  nil;
        }
        urlDatabase = [[urlTwitterBase URLByAppendingPathComponent:sName] retain];
    }
    return [[urlDatabase retain] autorelease];
}

/*
 *  Save our active friendship state database.
 *  - ASSUMES the lock is held.
 */
-(void) saveFriendshipStateAndForceCachedStateRecalc:(BOOL) forceRecalc
{
    NSMutableDictionary *mdToSave = [NSMutableDictionary dictionary];
    [mdToSave setObject:[NSNumber numberWithUnsignedInteger:lastAccount] forKey:CS_TFS_KEY_LASTACCT];
    if (mdUserData.count) {
        [mdToSave setObject:mdUserData.allValues forKey:CS_TFS_KEY_USERS];
    }
    if (msIgnoreFriends.count) {
        [mdToSave setObject:msIgnoreFriends forKey:CS_TFS_KEY_IGNORE];
    }

    // - there's not much that can be done if we fail to save, but we can at least avoid doing
    //   a reload.
    if ([CS_feedCollectorUtil secureSaveConfiguration:mdToSave asFile:[self urlDatabase] withError:nil]) {
        isLoaded = YES;
    }
    
    // - we don't recalc on every modification because some don't influence the friend relationships.
    if (forceRecalc) {
        [self forceFriendshipRecalculation];
    }
    
    // - notify the delegate that things were changed.`
    // - I realize that I'm calling back into the feed with the lock held.
    if (self.delegate) {
        [self.delegate performSelector:@selector(friendshipsUpdatedForState:) withObject:self];
    }
}

/*
 *  Load the friendship state database.
 *  - ASSUMES the lock is held.
 */
-(void) loadFriendshipState
{
    NSObject *obj = [CS_feedCollectorUtil secureLoadConfigurationFromFile:[self urlDatabase] withError:nil];
    if (!obj || ![obj isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
    NSDictionary *dict  = (NSDictionary *) obj;
    NSNumber *nLastAcct = [dict objectForKey:CS_TFS_KEY_LASTACCT];
    if (nLastAcct) {
        lastAccount = (cs_tfs_account_id_t) nLastAcct.unsignedIntegerValue;
    }
    
    // - the users require that we rebuild all the interdependent data.
    [mdUserData removeAllObjects];
    [msMyUserIds removeAllObjects];
    [mdAccountToUser removeAllObjects];
    numFriends        = 0;
    isLoaded          = YES;
    if (!isInitialRefresh) {
        // - force a refresh if it took a while to load the first time.
        lastRefresh = 0;
    }
    
    NSMutableSet *msCached = (NSMutableSet *) [[[ChatSeal secureCachedBaseNamesInCategory:[ChatSealFeedType friendProfilesCacheCategory]] mutableCopy] autorelease];
    NSArray *arrUsers      = [dict objectForKey:CS_TFS_KEY_USERS];
    numConsistentlyCachedProfileImages = 0;
    if (arrUsers) {
        for (CS_tfsUserData *udata in arrUsers) {
            [mdUserData setObject:udata forKey:udata.screenName];
            
            // - first make sure we have an accurate hash value to start with.
            NSString *toCheck = udata.cachedProfileHash;
            if (!toCheck) {
                toCheck   = [udata generateProfileHash];
            }
            
            // - now see if it is in the cache currently so we can keep the profile up to date.
            if (toCheck && ![msCached containsObject:toCheck]) {
                udata.cachedProfileHash = nil;
            }
            else {
                udata.cachedProfileHash = toCheck;
                if (toCheck) {
                    // - make sure that we only update the number of cached profile images
                    //   when we have the most recent.
                    if ([udata hasRecentProfileImage]) {
                        numConsistentlyCachedProfileImages++;
                    }
                    [msCached removeObject:toCheck];
                }
            }
            
            [mdAccountToUser setObject:udata forKey:udata.accountKey];
            if (udata.isMe) {
                [msMyUserIds addObject:udata.screenName];
            }
            else {
                numFriends++;
            }
        }
    }
    
    // - for any images no longer in the cache, we should discard them.
    for (NSString *sCached in msCached) {
        [ChatSeal invalidateCacheItemWithBaseName:sCached andCategory:[ChatSealFeedType friendProfilesCacheCategory]];
    }
    
    // - grab ignore friends.
    [msIgnoreFriends removeAllObjects];
    NSSet *sIgnore = [dict objectForKey:CS_TFS_KEY_IGNORE];
    if (sIgnore) {
        [msIgnoreFriends setSet:sIgnore];
    }
}

/*
 *  Rebuild the friendship state in this object.
 *  - ASSUMES the lock is held.
 */
-(void) rebuildFriendshipStateWithLocalUsers:(NSSet *) sUsers
{
    // - start by saving off all the health issues that require resolution.
    [msActiveUserFeeds removeAllObjects];
    [mdBrokenFriends removeAllObjects];
    __block BOOL isBroken = NO;
    for (NSString *screenName in sUsers) {
        [msActiveUserFeeds addObject:screenName];
        CS_tfsUserData *udata = [mdUserData objectForKey:screenName];           // do not auto-create here.
        if (udata) {
            // - get the list of health issues.
            NSDictionary *dHealthIssues = [udata friendshipHealthIssues];
            
            // - now I need to merge these into a global state.
            [dHealthIssues enumerateKeysAndObjectsUsingBlock:^(NSNumber *nKey, CS_tfsMessagingDeficiency *md, BOOL *stop) {
                CS_tfsMessagingDeficiency *mdOld = [mdBrokenFriends objectForKey:nKey];
                if (mdOld && md) {
                    md = [CS_tfsMessagingDeficiency unionOfDeficiency:mdOld withDeficiency:md];
                }
                [mdBrokenFriends setObject:md forKey:nKey];
                isBroken |= [md isBroken];
            }];
        }
    }
    
    // - when there are no users provided, but we know we have some, we need to manufacture
    //   failures for all our friends.
    if ([msActiveUserFeeds count] == 0 && [msMyUserIds count] > 0 && numFriends) {
        isBroken = YES;        
    }

    // - update the cached friendship flag, but never display 'NONE' because we're going to allow
    //   the user to manage the empty list.
    if (isBroken) {
        cachedFriendshipState = CSFT_FS_BROKEN;
    }
    else {
        cachedFriendshipState = CSFT_FS_REFINE;
    }
    
    // - and record that friendships are recomputed.
    recomputeFriends = NO;
}

/*
 *  This method forces the friendship state to be re-generated.
 *  - ASSUMES the lock is held.
 */
-(void) forceFriendshipRecalculation
{
    [msActiveUserFeeds removeAllObjects];
    recomputeFriends = YES;
}

/*
 *  Return the list of feeds that can be used for processing tasks.
 *  - THE LOCK SHOULD NOT BE HELD!
 */
-(NSSet *) availableFeedsForProcessingFromType:(CS_feedTypeTwitter *) twitterFeedType
{
    NSMutableSet *msTmpActive = [NSMutableSet set];
    for (ChatSealFeed *feed in [twitterFeedType feeds]) {
        // - when a feed cannot be used for messaging, that fact is important to use when determining if we can reach friends.
        if ([feed isViableMessagingTarget]) {
            [msTmpActive addObject:feed.userId];
        }
    }
    return msTmpActive;
}

/*
 *  If it makes sense, recompute the cached feed state.
 *  - ASSUMES the lock is held.
 */
-(void) recomputeCachedStateIfNecessaryUsingFeeds:(NSSet *) sNewActive
{
    // - when the list of feeds changes, we need to recompute the cached value.
    if (recomputeFriends || ![sNewActive isEqualToSet:msActiveUserFeeds]) {
        [self rebuildFriendshipStateWithLocalUsers:sNewActive];
    }
}

/*
 *  Delete an old friend profile image from disk.
 *  - ASSUMES the lock is held.
 */
-(void) discardFriendProfileImageInUser:(CS_tfsUserData *) udata
{
    if (!urlTwitterBase || !udata || !udata.cachedProfileHash) {
        return;
    }
    
    // - only the profile images that are up to date decrement the overall total.
    if ([udata hasRecentProfileImage]) {
        numConsistentlyCachedProfileImages--;
    }
    
    [ChatSeal invalidateCacheItemWithBaseName:udata.cachedProfileHash andCategory:[ChatSealFeedType friendProfilesCacheCategory]];
    udata.cachedProfileHash = nil;
}

/*
 *  Cache a user profile image.
 *  - ASSUMES the lock is held.
 */
-(void) saveFriendProfileImageData:(NSData *) dProfileImage inUser:(CS_tfsUserData *) udata
{
    if (!dProfileImage || !udata) {
        return;
    }
    
    NSString *sNewHash = [udata generateProfileHash];
    if ([ChatSeal saveSecureCachedData:dProfileImage withBaseName:sNewHash andCategory:[ChatSealFeedType friendProfilesCacheCategory]]) {
        udata.userVersion++;

        // - replace the old cached item, but only if it doesn't already exist.
        if (![sNewHash isEqualToString:udata.cachedProfileHash]) {
            [self discardFriendProfileImageInUser:udata];
            udata.cachedProfileHash = sNewHash;
            numConsistentlyCachedProfileImages++;
        }
        
        // - we want to update the state database and get the notification, but don't drive the recalculation because
        //   we didn't change any relationships with this image update.
        [self saveFriendshipStateAndForceCachedStateRecalc:NO];
    }
}

/*
 *  Retrn a profile image for the given friend at the request of a ChatSealFeedFriend consumer.
 */
-(UIImage *) profileImageForFriend:(ChatSealFeedFriend *)feedFriend withContext:(NSObject *)ctx
{
    if (!ctx) {
        return nil;
    }
    
    NSData *d = (NSData *) [ChatSeal secureCachedDataWithBaseName:(NSString *) ctx andCategory:[ChatSealFeedType friendProfilesCacheCategory]];
    if (!d) {
        //  - it is possible the context is out of date, in which case, we'll look up this friend under the lock.
        @synchronized (self) {
            CS_tfsUserData *ud = [mdUserData objectForKey:feedFriend.userId];
            if (ud && ud.cachedProfileHash) {
                d = (NSData *) [ChatSeal secureCachedDataWithBaseName:ud.cachedProfileHash andCategory:[ChatSealFeedType friendProfilesCacheCategory]];
            }
        }
    }

    // - return a profile image when we've returned it.
    return d ? [UIImage imageWithData:d] : nil;
}

/*
 *  Generate a feed friend for the given user.
 *  - ASSUMES the lock is held.
 */
-(ChatSealFeedFriend *) feedFriendForUserData:(CS_tfsUserData *) udata inType:(CS_feedTypeTwitter *) twitterFeedType
{
    // - build a feed friend object to return.
    ChatSealFeedFriend *csff = [ChatSealFeedFriend friendForFeedType:twitterFeedType andUserId:udata.screenName forDelegate:self withContext:udata.cachedProfileHash];
    
    // - identify the deficiency record.
    CS_tfsMessagingDeficiency *md               = nil;
    static CS_tfsMessagingDeficiency *mdNoFeeds = nil;
    if ([msActiveUserFeeds count]) {
        md = [mdBrokenFriends objectForKey:udata.accountKey];
    }
    else {
        if (!mdNoFeeds) {
            mdNoFeeds = [CS_tfsMessagingDeficiency deficiencyForAllFeedsDisabled];
        }
        md = [CS_tfsMessagingDeficiency deficiencyForAllFeedsDisabled];
    }
    
    // - fill-in the state.
    if ([md isBroken]) {
        csff.isBroken = YES;
    }
    csff.isDeleted = udata.isDeleted;
    
    // ...add the detail for it.
    NSString *simpleTwitterLocation = [NSString stringWithFormat:@"@%@", udata.screenName];
    csff.isIdentified               = udata.isVerified;
    csff.isTrusted                  = udata.isProven;
    csff.friendNameOrDescription    = (udata.isVerified && udata.fullName) ? udata.fullName : simpleTwitterLocation;
    csff.friendLocation             = (udata.isVerified && udata.fullName) ? udata.location : simpleTwitterLocation;
    
    // - the detail should reflect the best information we have on why messaging may be interrupted.
    NSString *sDetail = nil;
    if ([md isSubOptimal]) {
        sDetail = [md shortDescription];
    }
    else if (!udata.isVerified) {
        sDetail = NSLocalizedString(@"Waiting for identification.", nil);
    }

    csff.friendDetailDescription = sDetail;
    
    // - pass back a version value to make it easy to know when updates are necessary.
    csff.friendVersion = udata.userVersion;

    return csff;
}

/*
 *  Handle a friend update and let any interested parties know about it.
 *  - ASSUMES the lock is held.
 */
-(void) updateFriend:(CS_tfsUserData *) udataFriend andNotifyInFeed:(CS_twitterFeed *) feed
{
    udataFriend.userVersion++;
    [feed fireFriendshipUpdateNotification];
    [self saveFriendshipStateAndForceCachedStateRecalc:YES];
}

/*
 *  Remove the given friend from all lists.
 *  _ ASSUMES the lock is held.
 */
-(void) removeAllTrackingForFriend:(NSString *) friendName andIgnore:(BOOL) ignore andSaveWhenDone:(BOOL) doSave
{
    // - remove the user from the list being tracked at the moment.
    CS_tfsUserData *udata = [mdUserData objectForKey:friendName];
    if (udata && numFriends && !udata.isMe) {
        NSNumber *nKey = udata.accountKey;
        
        [mdBrokenFriends removeObjectForKey:nKey];
        
        for (udata in [self localUsers]) {
            [udata discardFriendshipStateForKey:nKey];
        }
        
        [self discardUserWithScreenName:friendName];
        numFriends--;
    }
    
    // - when there is a change, make sure the global state is saved and recomputed.
    if (ignore) {
        [msIgnoreFriends addObject:friendName];
    }
    else {
        [msIgnoreFriends removeObject:friendName];
    }
    
    // - save if requested.
    if (doSave) {
        [self saveFriendshipStateAndForceCachedStateRecalc:YES];
    }
}

/*
 *  Iterate over the array and mark all friends that exist as deleted.
 *  - ASSUMES the lock is held.
 *  - returns YES if a change was made.
 */
-(BOOL) markFriendsAsDeletedInArray:(NSArray *) arrNames
{
    BOOL wasChanged        = NO;
    NSMutableArray *maKeys = nil;
    for (NSString *sName in arrNames) {
        CS_tfsUserData *udata = [mdUserData objectForKey:sName];
        if (udata) {
            if (!maKeys) {
                maKeys = [NSMutableArray array];
            }
            [maKeys addObject:udata.accountKey];
            udata.isDeleted = YES;
            wasChanged      = YES;
        }
    }
    
    // - when we found some, we need to also make sure that our local users are
    //   updated by discarding all friendship information.
    if ([maKeys count]) {
        for (NSString *sLocalName in msMyUserIds) {
            CS_tfsUserData *uLocal = [mdUserData objectForKey:sLocalName];
            if (uLocal) {
                // - discarding friendship state is a serious business and I don't
                //   want to mistake two variants of the same type of method so I'm
                //   going to do this manually.  I don't expect a lot of these anyway.
                for (NSNumber *n in maKeys) {
                    [uLocal discardFriendshipStateForKey:n];
                    wasChanged = YES;
                }
            }
        }
    }
    
    return wasChanged;
}

@end
