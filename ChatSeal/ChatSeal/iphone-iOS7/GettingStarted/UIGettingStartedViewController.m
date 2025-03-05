//
//  UIGettingStartedViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 9/20/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UIGettingStartedViewController.h"
#import "ChatSeal.h"
#import "UIMessageDetailViewControllerV2.h"
#import "UIChatSealNavigationController.h"
#import "UIHubViewController.h"
#import "ChatSealBaseStation.h"
#import "UISealExchangeController.h"
#import "UIDynamicTypeCompliantEntity.h"
#import "UIAdvancedSelfSizingTools.h"
#import "CS_netstatus.h"

// - constants
typedef enum {
    HINT_BEGIN              = 100,
    HINT_NO_WIRELESS        = HINT_BEGIN,
    HINT_HINT_OBSOLETE,                       //  - used to be for the degraded state
    HINT_WELCOME,
    HINT_SOMEONE_NEARBY,
    HINT_SEAL_NEARBY,
    HINT_HAVE_OTHER,
    HINT_HAVE_MINE,
    HINT_HAVE_MINESHARED,
    
    HINT_END,
    
    HINT_INVALID            = -1
} uigsv_hint_type_t;

static const int UIGSV_HINT_TITLE_TAG    = 10;
static const int UIGSV_HINT_SUBTITLE_TAG = 20;
static const CGFloat UIGSV_STD_SIDE_PAD  = 20.0f;

//  - forward declarations
@interface UIGettingStartedViewController (internal) <UIMessageDetailViewControllerV2Delegate, UIDynamicTypeCompliantEntity, CS_netstatusDelegate>
-(void) doComposeNewMessage;
-(void) saveHintContraints;
-(void) showHint:(uigsv_hint_type_t) newHint withCompletion:(void(^)(void)) completionBlock;
-(uigsv_hint_type_t) computeCurrentHint;
-(void) checkForStateChangeWithNewMessage:(ChatSealMessage *) csm;
-(void) notifyBasestationUpdate;
-(void) discardHintTimer;
-(void) prepareForDelayedHintComputationWithShortDelay:(BOOL) asShortDelay;
-(void) enableAcceptButtonForVaultState;
-(void) notifyMessageImported:(NSNotification *) notification;
-(void) reconfigureDynamicLabelsAsInit:(BOOL) isInit;
@end

/*******************************
 UIGettingStartedViewController
 *******************************/
@implementation UIGettingStartedViewController
/*
 *  Object attributes
 */
{
    uigsv_hint_type_t   currentHint;
    NSMutableDictionary *mdHintConstraints;
    BOOL                showingHint;
    BOOL                notificationsSet;
    NSTimer             *tmDelayedHintTimer;
    BOOL                timerWasUpdated;
    BOOL                isFirstExperience;
    CS_netstatus        *inetStatus;
}
@synthesize bAcceptSeal;

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        currentHint        = HINT_INVALID;
        mdHintConstraints  = nil;
        showingHint        = NO;
        notificationsSet   = NO;
        tmDelayedHintTimer = nil;
        timerWasUpdated    = NO;
        isFirstExperience  = ![ChatSeal hasVault];
        
        // - This screen is sort of special in that it must report on the state of local networking and
        //   the Internet, which may be separate if the person has Wi-Fi and Bluetooth disabled but is using cellular data.
        //   So we're going to create a network status object for tracking that Internet state just for this specific scenario.
        inetStatus          = [[CS_netstatus alloc] initForLocalWifiOnly:NO];
        inetStatus.delegate = self;
        [inetStatus startStatusQuery];
        
        // - prepare to request the proximity wireless state, which will fire up the bluetooth
        //   query where possible.
        [[ChatSeal applicationBaseStation] proximityWirelessState];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    notificationsSet = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [bAcceptSeal release];
    bAcceptSeal = nil;
    
    [mdHintConstraints release];
    mdHintConstraints = nil;
    
    [inetStatus haltStatusQuery];
    inetStatus.delegate = nil;
    [inetStatus release];
    inetStatus = nil;
    
    [super dealloc];
}

/*
 *  Configure the object.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];

    // - set up the navigation item data.
    self.title = NSLocalizedString(@"ChatSeal", nil);
    UIBarButtonItem *bbiRight = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:self action:@selector(doComposeNewMessage)];
    self.navigationItem.rightBarButtonItem = bbiRight;
    [bbiRight release];

    // - version 7.1 asserts when we apply unusual transforms (ie. shear) to views that have constraints, so we need to remove them
    //   while they are being animated and restore them later.
    if ([ChatSeal isIOSVersionBEFORE8]) {
        [self saveHintContraints];
    }
    
    // - make sure the accept button is suitably enabled.
    [self enableAcceptButtonForVaultState];
    
    // - configure dynamic type in the views as necessary
    [self reconfigureDynamicLabelsAsInit:YES];
}

/*
 *  Layout has occurred, either for the purposes of rotation or right before returning
 *  from a modal screen.  In either case, we need to make sure the text wraps for the
 *  current screen width.
 */
-(void) viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    // - iterate through all the hints and update the
    BOOL needsLayout = NO;
    for (uigsv_hint_type_t tag = HINT_BEGIN; tag < HINT_END; tag++) {
        UIView *vwHint = [self.view viewWithTag:tag];
        if (!vwHint) {
            continue;
        }
        
        // - most of the time, the hint itself hasn't been laid out yet, but
        //   we need it to apply its rules first before we set the max layout
        //   width on the text.
        [vwHint layoutIfNeeded];
        
        // - look through each sub-view and figure out if it is a label, and
        //   if so, then fix its text.
        for (UIView *vwSub in vwHint.subviews) {
            if (![vwSub isKindOfClass:[UILabel class]]) {
                continue;
            }
            
            UILabel *l    = (UILabel *) vwSub;
            CGFloat width = CGRectGetWidth(l.bounds);
            if ((int) width != (int) l.preferredMaxLayoutWidth) {
                l.preferredMaxLayoutWidth = width;
                [l setNeedsLayout];
                needsLayout = YES;
            }
        }
    }
    
    // - when we modified the layout of the labels, this will be needed again.
    if (needsLayout) {
        [self.view layoutIfNeeded];
    }
}

/*
 *  Don't permit the timer to exist past the point where this view is discarded.
 */
-(void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self discardHintTimer];
}

/*
 *  The view has appeared, so we may want to show the hint.
 */
-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (currentHint == HINT_INVALID) {
        [self prepareForDelayedHintComputationWithShortDelay:YES];
    }
}

/*
 *  Accept the nearby seal and present the scan screen.
 */
-(IBAction)doAcceptTheSeal:(id)sender
{
    UIViewController *vc = [UISealExchangeController modalSealAcceptViewControllerForIdentity:nil andEnforceFirstTimeSemantics:YES
                                                                               withCompletion:^(BOOL hasExchangedASeal) {
        [self enableAcceptButtonForVaultState];
        [self dismissViewControllerAnimated:YES completion:^(void) {
            if (hasExchangedASeal) {
                [[ChatSeal applicationHub] setTabsVisible:YES withNewMessage:nil forStartupDisplay:NO];
            }
        }];
    }];
    [self presentViewController:vc animated:YES completion:nil];
}

/*
 *  After the hub switches tabs, this is triggered.  Use this opportunity to 
 *  change the hint if necessary.
 */
-(void) viewControllerDidBecomeActiveTab
{
    [self prepareForDelayedHintComputationWithShortDelay:NO];
}

/*
 *  When the hub detects that a new application URL has been sent into this app, we'll
 *  take that opportunity to pop open the seal scanner if it makes sense.
 */
-(void) viewControllerShouldProcessApplicationURL:(NSURL *) url
{
    // - we are only going to present the scan screen when there is nothing else displayed
    //   because we don't want to lose their data.
    if (!self.presentedViewController) {
        [self performSelector:@selector(doAcceptTheSeal:) withObject:nil afterDelay:0.75f];
    }
}

@end

/*****************************************
 UIGettingStartedViewController (internal)
 *****************************************/
@implementation UIGettingStartedViewController (internal)
/*
 *  The right bar button was pressed, requesting that a new message be composed.
 */
-(void) doComposeNewMessage
{
    UIMessageDetailViewControllerV2 *mdvc = [[UIMessageDetailViewControllerV2 alloc] initWithExistingMessage:nil andForceAppend:YES];
    mdvc.delegate                         = self;
    UINavigationController *nc            = [UIChatSealNavigationController instantantiateNavigationControllerWithRoot:mdvc];
    [mdvc release];
    nc.modalTransitionStyle               = UIModalPresentationFullScreen;
    [self presentViewController:nc animated:YES completion:nil];
}

/*
 *   When we start up, make sure that all the hint constraints are retained because we'll
 *   be detaching them during animations.
 */
-(void) saveHintContraints
{
    mdHintConstraints = [[NSMutableDictionary alloc] init];
    for (uigsv_hint_type_t tag = HINT_BEGIN; tag < HINT_END; tag++) {
        NSMutableArray *maOneHint = [NSMutableArray array];
        UIView *vw = [self.view viewWithTag:tag];

        // - the background color is clear so that this view's background color shines through.
        vw.backgroundColor = [UIColor clearColor];
        vw.hidden          = YES;
        
        for (NSLayoutConstraint *constraint in self.view.constraints) {
            if (constraint.firstItem == vw || constraint.secondItem == vw) {
                [maOneHint addObject:constraint];
            }
        }
        [mdHintConstraints setObject:maOneHint forKey:[NSNumber numberWithInteger:tag]];
    }
}

/*
 *  Move the requested hint to either visible or invisible.
 */
-(void) slideHint:(uigsv_hint_type_t) hint toVisible:(BOOL) toVisible withCompletion:(void (^)(void)) completionBlock
{
    CGAffineTransform atShear    = CGAffineTransformMake(1.0, 0.0, -0.5f, 1.0, 0.0, 0.0);
    CGAffineTransform atBegin    = CGAffineTransformIdentity;
    CGAffineTransform atAnim     = CGAffineTransformIdentity;
    BOOL              hiddenState= NO;
    UIView *vwHint               = [self.view viewWithTag:hint];

    // - iOS7.1 will assert if we don't remove constraints before applying a shear to the view.
    NSMutableArray *maConstraints = nil;
    if ([ChatSeal isIOSVersionBEFORE8]) {
        maConstraints = [mdHintConstraints objectForKey:[NSNumber numberWithInteger:hint]];
        [self.view removeConstraints:maConstraints];
    }
    
    // - when sliding to visible, that assumes the hint is moved-in from the right,
    //   otherwise it is currently visible and shifted off to the left.
    if (toVisible) {
        atBegin     = CGAffineTransformConcat(atShear, CGAffineTransformMakeTranslation(CGRectGetWidth(vwHint.frame), 0.0f));
        atAnim      = CGAffineTransformIdentity;
        hiddenState = NO;
    }
    else {
        atBegin     = CGAffineTransformIdentity;
        atAnim      = CGAffineTransformConcat(atShear, CGAffineTransformMakeTranslation(-CGRectGetWidth(vwHint.frame), 0.0f));
        hiddenState = YES;
    }
    
    // - start off the view where it is supposed to begin
    vwHint.hidden    = NO;
    vwHint.transform = atBegin;
    
    // - and proceed with the animation.
    [UIView animateWithDuration:[ChatSeal standardHintSlideTime] delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^(void){
        vwHint.transform = atAnim;
    } completion:^(BOOL finished){
        vwHint.transform = CGAffineTransformIdentity;
        vwHint.hidden    = hiddenState;
        if (maConstraints) {
            [self.view addConstraints:maConstraints];
        }
        if (completionBlock) {
            completionBlock();
        }
    }];
}

/*
 *  Animate the display of a new hint.
 */
-(void) showHint:(uigsv_hint_type_t) newHint withCompletion:(void(^)(void)) completionBlock
{
    // - the assumption is that the hints are correctly positioned in
    //   the view with autolayout when this is called
    // - we're going to move them offscreen and just return them to
    //   where they started, which should avoid any craziness.
    
    // - nothing to do.
    if (newHint == currentHint) {
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    
    uigsv_hint_type_t oldHint = currentHint;
    
    // - save the value
    currentHint = newHint;
    
    // - if we're in the midst of an animation, just record the hint that
    //   we have to display and return - the completion handler will
    //   check for descrepancies later.
    if (showingHint) {
        return;
    }
    
    showingHint = YES;
    
    // - if there is an existing hint, slide it off screen.
    if (oldHint != HINT_INVALID) {
        [self slideHint:oldHint toVisible:NO withCompletion:nil];
    }
    
    // - and slide the new on on...
    [self slideHint:newHint toVisible:YES withCompletion:^(void){
        showingHint = NO;
        
        if (currentHint != newHint) {
            uigsv_hint_type_t tmp = currentHint;
            currentHint = newHint;
            [self showHint:tmp withCompletion:completionBlock];
            return;
        }
        
        // - complete the transition.
        if (completionBlock) {
            completionBlock();
        }
    }];
}

/*
 *  Compute the hint that should be visible based on the application state.
 */
-(uigsv_hint_type_t) computeCurrentHint
{
    // - if we have a vault, then we have some more advanced hints that can be offered
    if ([ChatSeal isVaultOpen]) {
        NSArray *arr   = [ChatSeal availableIdentitiesWithError:nil];
        NSUInteger numMine       = 0;
        NSUInteger numMineShared = 0;
        NSUInteger numOthers     = 0;
        for (ChatSealIdentity *ident in arr) {
            if (ident.isOwned) {
                numMine++;
                if (ident.sealGivenCount) {
                    numMineShared += ident.sealGivenCount;
                }
            }
            else {
                numOthers++;
            }
        }

        // - after a seal transfer the goal is to get the person to understand that
        //   messages originate from the feeds.
        if ([ChatSeal hasTransferredASeal]) {
            // - check for whether I have seals first because hints should favor the proactive
            //   individual.
            if (numMine) {
                if (numMineShared) {
                    return HINT_HAVE_MINESHARED;
                }
                else {
                    return HINT_HAVE_MINE;
                }
            }
            
            // - special scenario, I'm a new user that just pulled my friend's seal over,
            //   what do I do next?
            if (numOthers && !numMine) {
                return HINT_HAVE_OTHER;
            }
        }
        else {
            // - When I haven't transferred my new seal, we want to guide the person towards
            //   either composing with it or sharing it with someone.
            if (numMine) {
                return HINT_HAVE_MINE;
            }
        }
    }
    
    // - while we have a hint for showing the user that their networking is disabled,
    //   it is important that isn't the only test for because it is possible that bluetooth
    //   is still working and the local wireless test has no way of determining the quality
    //   of that connection.
    // - in other words, the presence of either new or vault-ready users outweighs the
    //   local wireless validation.
    NSUInteger numNewUsers                = [[ChatSeal applicationBaseStation] newUserCount];
    NSUInteger numVaultUsers              = [[ChatSeal applicationBaseStation] vaultReadyUserCount];
    ps_bs_proximity_state_t wirelessState = [[ChatSeal applicationBaseStation] proximityWirelessState];
    
    // - when there are vault users, they must have created a seal at one time
#if TARGET_IPHONE_SIMULATOR
    // - scanning isn't possible with the simulator.
    if (numVaultUsers) {
        numNewUsers++;
    }
    numVaultUsers = 0;
#endif

    if (numVaultUsers) {
        return HINT_SEAL_NEARBY;
    }
    
    // - otherwise, when there are just basic new users, we'll give an hint that we know
    //   about them and that they are important to this exchange.
    if (numNewUsers) {
        return HINT_SOMEONE_NEARBY;
    }
    
    // - when there is no wireless, and no users, we need to offer some advice here.
    if (wirelessState == CS_BSCS_DISABLED && !inetStatus.hasConnectivity) {
        return HINT_NO_WIRELESS;
    }
    
    // - otherwise, it is just one person with an app and nobody around.
    //   They must make a choice about how to begin.
    return HINT_WELCOME;
    
}

/*
 *  Determine if the state has changed and display the new hint if necessary.
 */
-(void) checkForStateChangeWithNewMessage:(ChatSealMessage *) csm
{
    if (!notificationsSet) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyBasestationUpdate) name:kChatSealNotifyNetworkChange object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyBasestationUpdate) name:kChatSealNotifyNearbyUserChange object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyMessageImported:) name:kChatSealNotifyMessageImported object:nil];
        notificationsSet = YES;
    }
    
    // - determine if the tabs should change because a seal was created/imported.
    UIHubViewController *hvc   = [ChatSeal applicationHub];
    if (![hvc tabsAreVisible] || csm) {
        if ([ChatSeal isVaultOpen]) {
            [hvc setTabsVisible:YES withNewMessage:csm forStartupDisplay:NO];
        }
    }
    
    // - update the hint, if necessary.
    if (!csm) {
        // - don't change the hint with a new message.
        [self showHint:[self computeCurrentHint] withCompletion:nil];
    }
}

/*
 *  The message detail screen is cancelling.
 */
-(void) messageDetailShouldCancel:(UIMessageDetailViewControllerV2 *)md
{
    // - when we cancel, the main thing is to show the tabs if we now have a seal and
    //   let the standard hint update occur afterwards.
    [self dismissViewControllerAnimated:YES completion:^(void){
        if ([ChatSeal isVaultOpen] && [ChatSeal activeSeal] && isFirstExperience) {
            isFirstExperience = NO;
            [[ChatSeal applicationHub] setTabsVisible:YES withNewMessage:nil forStartupDisplay:NO];
        }
    }];
}

/*
 *  The message detail screen created a new message.
 */
-(void) messageDetail:(UIMessageDetailViewControllerV2 *)md didCompleteWithMessage:(ChatSealMessage *)message
{
    [self dismissViewControllerAnimated:YES completion:^(void){
        [self checkForStateChangeWithNewMessage:message];
    }];
}

/*
 *  When the base station detects changes to the network, all of its notifications
 *  will route through here.
 */
-(void) notifyBasestationUpdate
{
    // - when we're presenting a modal view controller, don't recompute updates
    //   because it could show tabs and screw up the modal relationships.
    if (!self.presentedViewController) {
        [self prepareForDelayedHintComputationWithShortDelay:NO];
    }
}

/*
 *  Discard the active timer.
 */
-(void) discardHintTimer
{
    [tmDelayedHintTimer invalidate];
    [tmDelayedHintTimer release];
    tmDelayedHintTimer = nil;
    timerWasUpdated    = NO;
}

/*
 *  When the hint delay timer expires, we need to compute
 *  the new hint state.
 */
-(void) hintDelayTimerExpiration
{
    [self discardHintTimer];
    [self checkForStateChangeWithNewMessage:nil];
}

/*
 *  Prepare to compute a new hint state, but delay it for a moment.
 */
-(void) prepareForDelayedHintComputationWithShortDelay:(BOOL) asShortDelay
{
    CGFloat delay = asShortDelay ? 0.25f : 1.25f;
    if (tmDelayedHintTimer) {
        // - only permit a single timer update because I don't want a scenario
        //   where we end up with no updates at all because they'are happening so
        //   quickly.
        if (timerWasUpdated) {
            return;
        }
        
        timerWasUpdated = YES;
        [tmDelayedHintTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:delay]];
    }
    else {
        tmDelayedHintTimer = [[NSTimer timerWithTimeInterval:delay target:self selector:@selector(hintDelayTimerExpiration) userInfo:nil repeats:NO] retain];
        [[NSRunLoop mainRunLoop] addTimer:tmDelayedHintTimer forMode:NSRunLoopCommonModes];
    }
    
}

/*
 *  Enable the accept button if we don't have a vault, disable it if we do.
 */
-(void) enableAcceptButtonForVaultState
{
    [bAcceptSeal setEnabled:![ChatSeal isVaultOpen]];
}

/*
 *  A new message was just imported, in which case we should reevaluate the display of this view.
 */
-(void) notifyMessageImported:(NSNotification *)notification
{
    NSString *mid        = [notification.userInfo objectForKey:kChatSealNotifyMessageImportedMessageKey];
    ChatSealMessage *csm = [ChatSeal messageForId:mid];
    if (csm) {
        [self checkForStateChangeWithNewMessage:csm];
    }
}

/*
 *  A request to update the dynamic type was received.
 */
-(void) updateDynamicTypeNotificationReceived
{
    [self reconfigureDynamicLabelsAsInit:NO];
}

/*
 *  Reconfigure the labels in this view for dynamic type sizing.
 */
-(void) reconfigureDynamicLabelsAsInit:(BOOL) isInit
{
    // - not supported in iOS7
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        return;
    }
    
    CGFloat preferredWidth = MIN(CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds));
    preferredWidth        -= (UIGSV_STD_SIDE_PAD * 2.0f);

    // - cycle through every view
    for (uigsv_hint_type_t hint = HINT_BEGIN; hint < HINT_END; hint++) {
        UIView *vwHint = [self.view viewWithTag:hint];
        
        // - now look for all the text or button sub-views.
        for (UIView *vwHintItem in vwHint.subviews) {
            if ([vwHintItem isKindOfClass:[UILabel class]]) {
                // - we need to always reassign the max layout width for these or they won't be
                //   resized correctly once the font changes.
                [(UILabel *) vwHintItem setPreferredMaxLayoutWidth:preferredWidth];
                [(UILabel *) vwHintItem setNumberOfLines:0];
                
                // - really two options.
                if (vwHintItem.tag == UIGSV_HINT_TITLE_TAG) {
                    [UIAdvancedSelfSizingTools constrainTextLabel:(UILabel *) vwHintItem
                                withPreferredSettingsAndTextStyle:UIFontTextStyleBody
                                                     andSizeScale:1.5f
                                                   andMinimumSize:20.0f
                                             duringInitialization:isInit];
                }
                else if (vwHintItem.tag == UIGSV_HINT_SUBTITLE_TAG) {
                    [UIAdvancedSelfSizingTools constrainTextLabel:(UILabel *) vwHintItem
                                withPreferredSettingsAndTextStyle:UIFontTextStyleBody
                                                     andSizeScale:1.0f
                                                   andMinimumSize:15.0f
                                             duringInitialization:isInit];
                }
            }
            else if ([vwHintItem isKindOfClass:[UIButton class]]) {
                [UIAdvancedSelfSizingTools constrainTextButton:(UIButton *) vwHintItem withPreferredSettingsAndTextStyle:UIFontTextStyleBody andMinimumSize:[ChatSeal minimumButtonFontSize] duringInitialization:isInit];
            }
        }
    }
}

/*
 *  When Internet-based network status is modified, we'll get a delegate callback here.
 */
-(void) netStatusChanged:(CS_netstatus *)netStatus
{
    [self checkForStateChangeWithNewMessage:nil];
}

@end
