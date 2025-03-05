//
//  CS_tfsFriendshipAdjustment.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/22/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tfsFriendshipAdjustment.h"
#import "CS_tfsMessagingDeficiency.h"
#import "CS_twitterFeed.h"
#import "ChatSeal.h"
#import "CS_feedShared.h"

// - local types
typedef enum {
    CS_TFS_FAA_OK          = 0,                 // no problems exist.
    CS_TFS_FAA_ENABLE_FEED,                     // turn on the feed.
    CS_TFS_FAA_FIX_FEED_ERROR,                  // the person is going to need to fix the error elsewhere.
    CS_TFS_FAA_UNBLOCK,                         // unblock my friend.
    CS_TFS_FAA_FOLLOW,                          // follow the person
    CS_TFS_FAA_GET_TWITTER_APP,                 // get the Twitter app in order to accept the friend.
    CS_TFS_FAA_ACCEPT_FRIEND,                   // accept the friend
    CS_TFS_FAA_UNMUTE,                          // un-mute the friend
    CS_TFS_FAA_WAIT_FOLLOW_ACCEPT,              // waiting for my friend to accept my follow request.
    CS_TFS_FAA_WAIT_UNBLOCK_ME,                 // waiting for my friend to unblock me.
    CS_TFS_FAA_BLOCK_ME_FOLLOW,                 // my friend is blocking me and I should try to follow.
    CS_TFS_FAA_THEY_SHOULD_FOLLOW,              // my friend should follow me.
} cs_tfs_fa_adjustment_t;

// - forward declarations
@interface CS_tfsFriendshipAdjustment (internal)
-(void) analyzeForAdjustmentsWithDeficiency:(CS_tfsMessagingDeficiency *) def;
-(void) setCorrectiveButtonText:(NSString *) cbt;
-(void) setStatusText:(NSString *) st;
-(void) setCorrectiveText:(NSString *) ct;
-(void) setTwitterOpenURLFormat:(NSString *) fmt;
-(BOOL) isTwitterAppAvailable;
-(BOOL) launchAppStoreForTwitter;
-(BOOL) applyEnablementAdjustmentForFriend:(NSString *) myFriend withError:(NSError **) err;
-(CS_feedTypeTwitter *) twitterType;
-(BOOL) applyFollowAdjustmentForFriend:(NSString *) myFriend withError:(NSError **) err;
-(void) fillActionForWaitFollow;
-(BOOL) applyUnblockAdjustmentForFriend:(NSString *) myFriend withError:(NSError **) err;
-(BOOL) applyGetTwitterWithError:(NSError **) err;
-(BOOL) applyAcceptFollowForFriend:(NSString *) myFriend withError:(NSError **) err;
-(BOOL) applyUnmuteForFriend:(NSString *) myFriend withError:(NSError **) err;
@end

/*******************************
 CS_tfsFriendshipAdjustment
 *******************************/
@implementation CS_tfsFriendshipAdjustment
/*
 *  Object attributes
 */
{
    CS_twitterFeed          *localFeed;
    
    cs_tfs_fa_adjustment_t  correctiveAction;
    BOOL                    hasDetailToDisplay;
    BOOL                    isWarning;
    BOOL                    requiresTwitterApp;
    NSString                *correctiveButtonText;
    NSString                *statusText;
    NSString                *correctiveText;
    NSString                *twitterOpenURLFormat;
    BOOL                    shouldAutomaticallyRefresh;
}

/*
 *  Initialize this object.
 *  - NOTE: the deficiency may be nil if there are no connection problems to address!
 */
-(id) initWithDeficiency:(CS_tfsMessagingDeficiency *) def forLocalFeed:(ChatSealFeed *)feed
{
    self = [super init];
    if (self) {
        localFeed                  = [feed isKindOfClass:[CS_twitterFeed class]] ? (CS_twitterFeed *) [feed retain] : nil;
        correctiveAction           = CS_TFS_FAA_OK;
        hasDetailToDisplay         = NO;
        isWarning                  = NO;
        requiresTwitterApp         = NO;
        correctiveButtonText       = nil;
        statusText                 = nil;
        correctiveText             = nil;
        twitterOpenURLFormat       = nil;
        shouldAutomaticallyRefresh = NO;
        [self analyzeForAdjustmentsWithDeficiency:def];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [localFeed release];
    localFeed = nil;
    
    [correctiveButtonText release];
    correctiveButtonText = nil;
    
    [statusText release];
    statusText = nil;
    
    [correctiveText release];
    correctiveText = nil;
    
    [twitterOpenURLFormat release];
    twitterOpenURLFormat = nil;
    
    [super dealloc];
}

/*
 *  This is a simple check to see if two adjustments refer to the same entity.
 */
-(BOOL) reflectsTheSameFeedAs:(CS_tfsFriendshipAdjustment *)faOther
{
    if (faOther &&
        localFeed == faOther->localFeed) {
        return YES;
    }
    return NO;
}

/*
 *  Determine if two adjustments are advocating the same update.
 */
-(BOOL) recommendsTheSameAdjustmentAs:(CS_tfsFriendshipAdjustment *)faOther
{
    if (faOther &&
        correctiveAction == faOther->correctiveAction) {
        return YES;
    }
    return NO;
}

/*
 *  Determine if this object is equal to another.
 */
-(BOOL) isEqual:(id)object
{
    if (![object isKindOfClass:[CS_tfsFriendshipAdjustment class]] || !object) {
        return NO;
    }
    CS_tfsFriendshipAdjustment *faOther = (CS_tfsFriendshipAdjustment *) object;
    if ([self reflectsTheSameFeedAs:faOther] &&
        [self recommendsTheSameAdjustmentAs:faOther]) {
        return YES;
    }
    return NO;
}

/*
 *  Returns whether the enclosed feed is enabled or not.
 */
-(BOOL) isFeedEnabled
{
    return [localFeed isEnabled];
}

/*
 *  Return the screen name for this adjustment.
 */
-(NSString *) screenName
{
    return [localFeed userId];
}

/*
 *  Return a short description of the corrective action.
 */
-(NSString *) statusText
{
    return [[statusText retain] autorelease];
}

/*
 *  Return whether this is in a warning state.
 */
-(BOOL) isWarning
{
    return isWarning;
}

/*
 *  This flag allows you to override the update logic for this adjustment.  If
 *  it is unset, the default computations will be performed.
 *
 */
-(void) setCanBenefitFromRegularUpdates:(BOOL) forceUpdates
{
    shouldAutomaticallyRefresh = forceUpdates;
}

/*
 *  Determines if periodic updates of the friendship relationship could 
 *  maybe change the nature of this adjustment.
 */
-(BOOL) canBenefitFromRegularUpdates
{
    // - refreshes only make sense if the feed is currently enabled.
    if (![localFeed isViableMessagingTarget]) {
        return NO;
    }
    
    // - if the auto-refresh flag was set externally by other data points,
    //   return immediately.
    if (shouldAutomaticallyRefresh) {
        return YES;
    }
    
    // ...otherwise we're going to compute it based on the adjustment to be made.
    
    // - for the blocking states, the updates are not to query explicitly for a block flag, but
    //   rather to query for the presence of other flags (either follow or followed-by) that
    //   suggest that the blocking is gone.
    // - we query here explicitly and not just rely on the realtime state because we won't know
    //   when they follow us because the realtime stream won't report that.
    if (correctiveAction == CS_TFS_FAA_BLOCK_ME_FOLLOW ||
        correctiveAction == CS_TFS_FAA_WAIT_UNBLOCK_ME) {
        return YES;
    }
    
    // - while we're waiting for them to accept my follow request, we can
    //   improve the UI by querying
    if (correctiveAction == CS_TFS_FAA_WAIT_FOLLOW_ACCEPT) {
        // - the main indicator is that realtime support, which will return follow
        //   changes, so we don't need to query when that thing is running.
        return ![localFeed hasRealtimeSupport];
    }
    
    // - when this friend wants to follow us, we'll see if it was addressed externally.
    if (correctiveAction == CS_TFS_FAA_ACCEPT_FRIEND || correctiveAction == CS_TFS_FAA_GET_TWITTER_APP) {
        return YES;
    }
    
    // - when they are not yet following me, we probably should include that because it could produce a follow request.
    if (correctiveAction == CS_TFS_FAA_THEY_SHOULD_FOLLOW) {
        return YES;
    }
    
    return NO;
}

/*
 *  Return a longer description of the corrective action that must be performed.
 */
-(NSString *) correctiveTextForFriend:(ChatSealFeedFriend *) feedFriend
{
    if (!correctiveText) {
        return nil;
    }

    // - build a name to display.
    NSString *friendFullName = nil;
    if (feedFriend) {
        friendFullName = [self descriptiveNameForFeedFriend:feedFriend];
    }
    
    // - if we got nothing back, then produce something that can be used.
    if (!friendFullName) {
        NSRange r = [correctiveText rangeOfString:@"%@"];
        if (r.location == 0) {
            friendFullName = NSLocalizedString(@"Your friend", nil);
        }
        else {
            friendFullName = NSLocalizedString(@"your friend", nil);
        }
    }
    
    return [NSString stringWithFormat:correctiveText, friendFullName];
}

/*
 *  Indicates whether there is a more detailed sub-detail screen that can explain the changes.
 */
-(BOOL) hasDetailToDisplay
{
    return hasDetailToDisplay;
}

/*
 *  Determine if there is a corrective action that the app can help with here.
 */
-(BOOL) hasCorrectiveAction
{
    return (correctiveButtonText ? YES : NO);
}

/*
 *  Adjustments that require updates to the feed may have one button that is generated
 *  to allow a quick change.  An absence of any text indicates that there is no corrective action.
 */
-(NSString *) correctiveButtonTextForFriend:(ChatSealFeedFriend *) feedFriend
{
    if (!correctiveButtonText) {
        return nil;
    }
    
    // - this is a minor course correction when Twitter isn't installed yet.
#if !TARGET_IPHONE_SIMULATOR
    if (correctiveAction == CS_TFS_FAA_ACCEPT_FRIEND &&
        ![self isTwitterAppAvailable]) {
        return NSLocalizedString(@"Install Twitter", nil);
    }
#endif
    
    // - get a name to replace in the button text.
    NSString *friendFullName = nil;
    if (feedFriend) {
        friendFullName = [self descriptiveNameForFeedFriend:feedFriend];
    }
    
    // - if nothing was generated, produce something we can use.
    if (!friendFullName) {
        friendFullName = NSLocalizedString(@"Your Friend", nil);
    }
    
    return [NSString stringWithFormat:correctiveButtonText, friendFullName];
}

/*
 *  This API is used to initiate an adjustment.
 */
-(BOOL) applyAdjustmentForFriend:(NSString *) screenName withError:(NSError **) err
{
    if (!localFeed) {
        [CS_error fillError:err withCode:CSErrorFeedInvalid];
        return NO;
    }
    
    switch (correctiveAction) {
        case CS_TFS_FAA_OK:
        case CS_TFS_FAA_FIX_FEED_ERROR:
        case CS_TFS_FAA_WAIT_UNBLOCK_ME:
        case CS_TFS_FAA_WAIT_FOLLOW_ACCEPT:
            // - nothing to do.
            return YES;
            break;
            
        case CS_TFS_FAA_ENABLE_FEED:
            return [self applyEnablementAdjustmentForFriend:screenName withError:err];
            break;
            
        case CS_TFS_FAA_FOLLOW:
        case CS_TFS_FAA_BLOCK_ME_FOLLOW:
            return [self applyFollowAdjustmentForFriend:screenName withError:err];
            break;
            
        case CS_TFS_FAA_UNBLOCK:
            return [self applyUnblockAdjustmentForFriend:screenName withError:err];
            break;
            
        case CS_TFS_FAA_GET_TWITTER_APP:
            return [self applyGetTwitterWithError:err];
            break;
            
        case CS_TFS_FAA_ACCEPT_FRIEND:
            return [self applyAcceptFollowForFriend:screenName withError:err];
            break;
            
        case CS_TFS_FAA_UNMUTE:
            return [self applyUnmuteForFriend:screenName withError:err];
            break;
            
        default:
            // - when we didn't handle it, this has to be an error.
            [CS_error fillError:err withCode:CSErrorFeedNotSupported];
            return NO;
            break;
    }
}

/*
 *  Using the internal feed, request a friend update.
 */
-(void) requestConnectionUpdateForFriend:(ChatSealFeedFriend *) feedFriend
{
    // - we'll only do this when there's a good chance it will work
    if ([localFeed isViableMessagingTarget]) {
        [localFeed requestHighPriorityRefreshForFriend:feedFriend.userId];
    }
}

/*
 *  Cancel a pending friend update.
 */
-(void) cancelConnectionUpdateForFriend:(ChatSealFeedFriend *) feedFriend
{
    [localFeed cancelHighPriorityRefreshForFriend:feedFriend.userId];
}

/*
 *  Return the recommended best adjustment for my friend.
 */
-(CS_tfsFriendshipAdjustment *) highestPriorityAdjustmentForFriend:(ChatSealFeedFriend *) feedFriend
{
    if (feedFriend && localFeed) {
        return [[self twitterType] recommendedAdjustmentForFeed:localFeed withFriend:feedFriend];
    }
    return nil;
}

/*
 *  Return a common friend name string that we can use for descriptive text.
 */
-(NSString *) descriptiveNameForFeedFriend:(ChatSealFeedFriend *) feedFriend
{
    if (feedFriend.friendNameOrDescription) {
        return feedFriend.friendNameOrDescription;
    }
    else {
        return [NSString stringWithFormat:@"@%@", feedFriend.userId];
    }
}

@end

/**************************************
 CS_tfsFriendshipAdjustment (internal)
 **************************************/
@implementation CS_tfsFriendshipAdjustment (internal)
/*
 *  Figure out if there are things that should be fixed.
 */
-(void) analyzeForAdjustmentsWithDeficiency:(CS_tfsMessagingDeficiency *) def
{
    // - Scenario 1: determine if the feed is enabled.
    isWarning = def.allFeedsAreDisabled;
    if (localFeed && !localFeed.isEnabled) {
        correctiveAction = CS_TFS_FAA_ENABLE_FEED;
        self.statusText  = NSLocalizedString(@"Feed is turned off.", nil);
        self.correctiveText       = nil;
        self.correctiveButtonText = NSLocalizedString(@"Turn On", nil);
        return;
    }
    
    
    // - the default scenario is that everything is OK.
    self.statusText           = NSLocalizedString(@"This feed is well-connected.", nil);
    isWarning                 = NO;
    self.correctiveText       = nil;
    self.correctiveButtonText = nil;
    
    if (!def || !localFeed) {
        return;
    }
    
    // - the warning state is almost entirely tied to the broken state, which is consistent with
    //   the way that the overall friendship state is computed.
    isWarning = def.isBroken;
    
    // - Scenario 2: determine if the feed is damaged somehow.
    if (![localFeed isViableMessagingTarget]) {
        correctiveAction           = CS_TFS_FAA_FIX_FEED_ERROR;
        isWarning                  = YES;                       //  - this is exceptional, but I want this to match the feeds overview.
        self.statusText            = [localFeed statusText];
        self.correctiveText        = [localFeed correctiveText];
        self.correctiveButtonText  = nil;                       //  there is nothing that can be done.
        return;
    }
    
    // - Scenario 3: they have blocked me.
    if ([def isBlockingMyAccount]) {
        isWarning                      = YES;
        self.statusText                = NSLocalizedString(@"Your friend is blocking you.", nil);
        if ([def isWaitingForFollowAccept]) {
            correctiveAction           = CS_TFS_FAA_WAIT_UNBLOCK_ME;
            self.correctiveText        = NSLocalizedString(@"You have asked to follow %@, who is blocking you.  You can continue rebuilding your connections when they allow your request.", nil);
            self.correctiveButtonText  = nil;
        }
        else {
            correctiveAction           = CS_TFS_FAA_BLOCK_ME_FOLLOW;
            self.correctiveText        = NSLocalizedString(@"%@ has blocked your account.  You will not be able to chat until they allow you to follow them.", nil);
            self.correctiveButtonText  = NSLocalizedString(@"Follow %@", nil);
        }
        return;
    }
    
    // - Scenario 4: determine if I've blocked my friend
    if ([def isBlocked]) {
        correctiveAction           = CS_TFS_FAA_UNBLOCK;
        self.statusText            = NSLocalizedString(@"You have blocked your friend.", nil);
        self.correctiveText        = NSLocalizedString(@"%@ is blocked and cannot chat until you unblock them.", nil);
        self.correctiveButtonText  = NSLocalizedString(@"Unblock %@", nil);
        return;
    }
    
    // - Scenario 5: we are not following a protected seal owner.
    if ([def isNotFollowingProtectedSealOwner]) {
        if ([def isWaitingForFollowAccept]) {
            [self fillActionForWaitFollow];
        }
        else {
            correctiveAction           = CS_TFS_FAA_FOLLOW;
            self.statusText            = NSLocalizedString(@"You must follow your friend.", nil);
            self.correctiveText        = NSLocalizedString(@"%@ has shared a seal with you, but their account is protected.  You cannot chat until you follow them.", nil);
            self.correctiveButtonText  = NSLocalizedString(@"Follow %@", nil);
        }
        return;
    }
    
    // - Scenario 6: this account is protected and we have an outstanding friend request.
    if ([def isProtectedWithFriendRequest]) {
        self.statusText            = NSLocalizedString(@"Your friend wants to follow you.", nil);
        self.correctiveText        = NSLocalizedString(@"%@ would like to follow your protected Twitter account.  You cannot chat until you accept their request online or with the Twitter app.", nil);
        if ([self isTwitterAppAvailable]) {
            correctiveAction           = CS_TFS_FAA_ACCEPT_FRIEND;
#if !TARGET_IPHONE_SIMULATOR
            self.twitterOpenURLFormat  = @"twitter://user?screen_name=%@";
            self.correctiveButtonText  = NSLocalizedString(@"Launch Twitter", nil);
#endif
        }
        else {
            correctiveAction           = CS_TFS_FAA_GET_TWITTER_APP;
#if !TARGET_IPHONE_SIMULATOR
            self.correctiveButtonText  = NSLocalizedString(@"Install Twitter", nil);
#endif
        }
        return;
    }
    
    // - Scenario 7: this account is muted.
    if ([def isMuting]) {
        correctiveAction           = CS_TFS_FAA_UNMUTE;
        self.statusText            = NSLocalizedString(@"You have muted your friend.", nil);
        self.correctiveText        = NSLocalizedString(@"%@ is muted, which may prevent you from chatting with them.", nil);
        self.correctiveButtonText  = NSLocalizedString(@"Unmute %@", nil);
        return;
    }
    
    // - Scenario 8: we should follow.
    if ([def isRecvRestricted]) {
        if ([def isWaitingForFollowAccept]) {
            [self fillActionForWaitFollow];
        }
        else {
            correctiveAction           = CS_TFS_FAA_FOLLOW;
            self.statusText            = NSLocalizedString(@"You should follow your friend.", nil);
            if ([def isFriendProtected]) {
                self.correctiveText = NSLocalizedString(@"%@ has a protected account.  You may have problems chatting unless you follow them.", nil);
            }
            else {
                self.correctiveText = NSLocalizedString(@"ChatSeal finds personal messages from your friends more quickly when you follow their Twitter accounts.", nil);
            }
            self.correctiveButtonText  = NSLocalizedString(@"Follow %@", nil);
        }
        return;
    }
    
    // - Scenario 9: they should follow us.
    if ([def isSendRestricted]) {
        correctiveAction          = CS_TFS_FAA_THEY_SHOULD_FOLLOW;
        self.statusText           = NSLocalizedString(@"Your friend is not following you.", nil);
        self.correctiveButtonText = nil;
        if ([def iAmProtectedSealOwnerAndTheyNoFollow]) {
            self.correctiveText = NSLocalizedString(@"%@ is not following your protected Twitter account, which will prevent them from receiving your personal messages.", nil);
            isWarning           = YES;
        }
        else {
            self.correctiveText = NSLocalizedString(@"%@ is not following your Twitter account, which may prevent them from receiving your personal messages.", nil);
            isWarning           = NO;
        }
    }
    
    // - Scenario 10: the feed is unqueried and we need to wait for it to complete.
    if ([def isUnqueried]) {
        self.statusText           = def.shortDescription;
        self.correctiveButtonText = nil;
        self.correctiveText       = nil;
        isWarning                 = NO;
    }
}

/*
 *  Assign the corrective button text.+
 */
-(void) setCorrectiveButtonText:(NSString *) cbt
{
    if (cbt != correctiveButtonText) {
        [correctiveButtonText release];
        correctiveButtonText = [cbt retain];
    }
}

/*
 *  Assign the short textual description for this item.
 */
-(void) setStatusText:(NSString *)st
{
    if (statusText != st) {
        [statusText release];
        statusText = [st retain];
    }
}

/*
 *  Assign the longer corrective text description for this item.
 */
-(void) setCorrectiveText:(NSString *) ct
{
    if (correctiveText != ct) {
        [correctiveText release];
        correctiveText = [ct retain];
    }
    hasDetailToDisplay = (correctiveText ? YES : NO);
}

/*
 *  This assumes that when this is converted, the friend's screen name will be used to manufacture a good
 *  link in the app.
 */
-(void) setTwitterOpenURLFormat:(NSString *) fmt
{
    if (twitterOpenURLFormat != fmt) {
        [twitterOpenURLFormat release];
        twitterOpenURLFormat = [fmt retain];
    }
    requiresTwitterApp = (twitterOpenURLFormat ? YES : NO);
}

/*
 *  Check if the Twitter app is available on the local device.
 */
-(BOOL) isTwitterAppAvailable
{
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter://"]];
}

/*
 *  Launch the app store app to convince the person to install Twitter.
 */
-(BOOL) launchAppStoreForTwitter
{
    if ([self isTwitterAppAvailable]) {
        return NO;
    }
    return [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"itms-apps://itunes.com/apps/twitter"]];
}

/*
 *  Correct a feed problem by enabling it.
 */
-(BOOL) applyEnablementAdjustmentForFriend:(NSString *) myFriend withError:(NSError **) err
{
    if (![localFeed setEnabled:YES withError:err]) {
        return NO;
    }
    
    // - if everything worked we need to update our friend's version and fire
    //   the notification so the UIs are reloaded.
    [[self twitterType] incrementFriendVersionForScreenName:myFriend];
    [localFeed fireFriendshipUpdateNotification];
    return YES;
}

/*
 *  Return the feed type as a Twitter-specific instance.
 */
-(CS_feedTypeTwitter *) twitterType
{
    ChatSealFeedType *ft = [localFeed feedType];
    if (![ft isKindOfClass:[CS_feedTypeTwitter class]]) {
        return nil;
    }
    return (CS_feedTypeTwitter *) ft;
}

/*
 *  Correct a feed by following a friend.
 */
-(BOOL) applyFollowAdjustmentForFriend:(NSString *) myFriend withError:(NSError **) err
{
    // - its going to take a while before we know if this will work, so no need to return an error.
    [localFeed requestHighPriorityFollowForFriend:myFriend];
    return YES;
}

/*
 *  When we're waiting on a friend to accept our follow request, we need to have common 
 *  behavior.
 */
-(void) fillActionForWaitFollow
{
    // - the warning state is dictated by the caller so that we can highlight the critical
    //   breakages in the same way.
    correctiveAction           = CS_TFS_FAA_WAIT_FOLLOW_ACCEPT;
    self.statusText            = NSLocalizedString(@"Your friend needs to accept.", nil);
    self.correctiveText        = NSLocalizedString(@"You have asked to follow %@, but they haven't yet accepted your request.", nil);
    self.correctiveButtonText  = nil;
}

/*
 *  Correct a feed by unblocking it.
 */
-(BOOL) applyUnblockAdjustmentForFriend:(NSString *) myFriend withError:(NSError **) err
{
    // - we won't know the success of this until it returns.
    [localFeed requestHighPriorityUnblockForFriend:myFriend];
    return YES;
}

/*
 *  Correct a feed by first getting the Twitter app.
 */
-(BOOL) applyGetTwitterWithError:(NSError **) err
{
    if (correctiveAction != CS_TFS_FAA_GET_TWITTER_APP) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        return NO;
    }
    
    if (![self launchAppStoreForTwitter]) {
        [CS_error fillError:err withCode:CSErrorCannotNotLaunchAppStore];
        return NO;
    }
    
    return YES;
}

/*
 *  Correct a feed by accepting a follow request.
 */
-(BOOL) applyAcceptFollowForFriend:(NSString *) myFriend withError:(NSError **) err
{
    if (correctiveAction != CS_TFS_FAA_ACCEPT_FRIEND) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        return NO;
    }
    
    if (![self isTwitterAppAvailable] ||
        !twitterOpenURLFormat || ![[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:twitterOpenURLFormat, myFriend]]]) {
        [CS_error fillError:err withCode:CSErrorCannotLaunchTwitterApp];
        return NO;
    }
    
    return YES;
}

/*
 *  Correct a feed by unmuting a friend.
 */
-(BOOL) applyUnmuteForFriend:(NSString *) myFriend withError:(NSError **) err
{
    // - we won't know the success of this until it returns.
    [localFeed requestHighPriorityUnmuteForFriend:myFriend];
    return YES;
}

@end
