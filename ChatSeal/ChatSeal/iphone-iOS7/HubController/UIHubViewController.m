//
//  UIHubViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 9/20/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UIHubViewController.h"
#import "ChatSeal.h"
#import "UIGettingStartedViewController.h"
#import "UIMessageOverviewViewController.h"
#import "UISealVaultViewController.h"
#import "UIChatSealNavigationController.h"
#import "UIMessageDetailViewControllerV2.h"
#import "UIHubMessageDetailAnimationController.h"
#import "UIDynamicTypeCompliantEntity.h"
#import "UIVaultFailureOverlayView.h"
#import "UIImageGeneration.h"
#import "UIFeedsOverviewViewController.h"
#import "UIAdvancedSelfSizingTools.h"
#import "UIPrivacyViewController.h"
#import "UIDebugLogViewController.h"

//  - constants
static const NSTimeInterval UIHVC_STD_TAB_DISPLAY = 0.4f;
static const CGFloat        UIHVC_INVIS_OFFSET    = 2048.0f;
typedef enum
{
    UIHVC_TAB_MESSAGES = 0,
    UIHVC_TAB_VAULT    = 1,
    UIHVC_TAB_FEEDS    = 2,
    
    UIHVC_TAB_COUNT,
    
    UIHVC_TAB_DEBUG    = UIHVC_TAB_COUNT,
    
    UIHVC_TAB_WITH_DEBUG_COUNT
} uihvc_tab_item_t;

//  - forward declarations
@interface UIHubViewController (internal) <UITabBarDelegate, UIChatSealCustomNavTransitionDelegate, UIDynamicTypeCompliantEntity>
-(void) selectTabAtIndex:(uihvc_tab_item_t) newIndex withAnimation:(BOOL) animated withNewMessage:(ChatSealMessage *) psm andCompletion:(void(^)(void)) completionBlock;
-(void) displayPrimaryViewController:(UIViewController *) vcPrimary withAnimation:(BOOL) animated andCompletion:(void(^)(void)) completionBlock;
-(void) notifyViewControllerAndPresentedOfDynamicTypeChange:(UIViewController *) vc;
-(void) notifyApplicationURLChanged;
-(void) actUponStartupURL:(NSURL *) u;
-(void) updateAlertBadgeForTab:(uihvc_tab_item_t) tab;
-(void) notifyWillResign;
-(void) notifyWillEnterForeground;
+(void) reconfigureSearchBarsForDynamicType;
-(void) updateDynamicTypeDuringInit:(BOOL) isInit;
@end

//  - category for wiring up nav controller behavior.
@interface UIGettingStartedViewController (override)
@end

//  - shared with screens that manage transitions within the hub.
@interface UIHubViewController (hubRelatedTransition)
-(void) prepareForTransition;
-(CGRect) tabsRectForOpening:(BOOL) isOpening;
-(void) setAllHubContentVisible:(BOOL) isVisible;
-(UIView *) containerView;
@end

// - manage the vault and respond to failures.
@interface UIHubViewController (vaultManagement) <UIVaultFailureOverlayViewDelegate>
-(void) lowStorageResolved;
-(void) attemptToOpenVaultIfAvailableAndNotOpen;
-(void) setVaultLockedErrorVisible:(BOOL) isVisible;
@end

/************************
 UIHubViewController
 ************************/
@implementation UIHubViewController
/*
 *  Object attributes
 */
{
    BOOL                            tabsVisible;
    BOOL                            realContentVisible;
    uihvc_tab_item_t                selectedIndex;
    UIViewController                *vcCurrent;                 // assign only
    UIViewController                *vcTabs[UIHVC_TAB_WITH_DEBUG_COUNT];
    BOOL                            isTransitioning;
    BOOL                            hasAppeared;
    UIView                          *vwSnapTabs;
    BOOL                            allowDynamicTypeUpdates;
    BOOL                            hasPendingDynamicTypeUpdate;
    UIView                          *vwForegroundTransitionCover;
}
@synthesize vwContainer;
@synthesize vwTabBG;
@synthesize tbTabs;
@synthesize lcContainerHeight;
@synthesize lcLeftEdge;
@synthesize lcRightEdge;
@synthesize vfoVaultOverlay;
@synthesize bPrivacy;

/*
 *  Initialize the module.
 */
+(void) initialize
{
    [UIHubViewController reconfigureSearchBarsForDynamicType];
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        tabsVisible                 = NO;
        realContentVisible          = YES;
        selectedIndex               = UIHVC_TAB_WITH_DEBUG_COUNT;
        vcCurrent                   = nil;
        vcTabs[0]                   = vcTabs[1] = vcTabs[2] = vcTabs[3] = nil;
        isTransitioning             = NO;
        hasAppeared                 = NO;
        vwSnapTabs                  = nil;
        allowDynamicTypeUpdates     = YES;
        hasPendingDynamicTypeUpdate = NO;
        vwForegroundTransitionCover = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [vwContainer release];
    vwContainer = nil;
    
    [tbTabs release];
    tbTabs = nil;
    
    [vwTabBG release];
    vwTabBG = nil;
    
    [lcContainerHeight release];
    lcContainerHeight = nil;
    
    [lcLeftEdge release];
    lcLeftEdge = nil;
    
    [lcRightEdge release];
    lcRightEdge = nil;
    
    [vfoVaultOverlay release];
    vfoVaultOverlay = nil;
    
    [vwSnapTabs release];
    vwSnapTabs = nil;
    
    vcCurrent = nil;
    
    for (int i = 0; i < UIHVC_TAB_WITH_DEBUG_COUNT; i++) {
        [vcTabs[i] release];
        vcTabs[i] = nil;
    }
    
    [bPrivacy release];
    bPrivacy = nil;
    
    [super dealloc];
}

/*
 *  Configure the view.
 */
-(void) viewDidLoad
{
    [super viewDidLoad];
    
    // - when using the debug log, make sure the tab is configured.
#ifdef CHATSEAL_DEBUG_LOG_TAB
    UITabBarItem *tbi = [[[UITabBarItem alloc] initWithTitle:@"Debug Log" image:[UIImage imageNamed:@"740-gear.png"] tag:UIHVC_TAB_DEBUG] autorelease];
    NSMutableArray *maTabs = [NSMutableArray arrayWithArray:self.tbTabs.items];
    [maTabs addObject:tbi];
    [self.tbTabs setItems:maTabs animated:NO];
#endif
    
    // - the messages are always shown first
    tbTabs.delegate = self;
    
    // - wire up the overlay delegate
    vfoVaultOverlay.delegate = self;
    [vfoVaultOverlay setUseFrostedEffect:NO];
    
    // - watch for dynamic type changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDynamicTypeNotificationReceived) name:UIContentSizeCategoryDidChangeNotification object:nil];
    
    // - and low storage to be addressed
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(lowStorageResolved) name:kChatSealNotifyLowStorageResolved object:nil];
    
    // - and appliation URL updates
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyApplicationURLChanged) name:kChatSealNotifyApplicationURLUpdated object:nil];
    
    // - manage backgrounding and how it plays with dynamic type updates
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyWillResign) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    // - update dynamic type if necessary
    self.bPrivacy.alpha = 0.0f;
    [self updateDynamicTypeDuringInit:YES];
}

/*
 *  Modify the view constraints based on the current tab state.
 */
-(void) updateViewConstraints
{
    [super updateViewConstraints];
    
    CGFloat tabHeight = CGRectGetHeight(tbTabs.frame);
    lcContainerHeight.constant = (tabsVisible ? 0.0f : -tabHeight);
    
    // - when the real content is hidden as we're animating, it needs to be pushed off screen
    //   so that those views can still be used to take snapshots as they get updated.
    lcLeftEdge.constant = (realContentVisible ? 0.0f : -UIHVC_INVIS_OFFSET);
    lcRightEdge.constant = (realContentVisible ? 0.0f : UIHVC_INVIS_OFFSET);
}

/*
 *  We've received a memory warning.
 */
-(void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    // - when this occurs, we're going to discard any tabs that aren't active to save on RAM.
    for (NSUInteger i = 0; i < UIHVC_TAB_WITH_DEBUG_COUNT; i++) {
        if (vcTabs[i] != vcCurrent) {
            [vcTabs[i] release];
            vcTabs[i] = nil;
        }
    }
}

/*
 *  Show/hide the tabs.
 */
-(void) setTabsVisible:(BOOL) isVisible withNewMessage:(ChatSealMessage *) psm forStartupDisplay:(BOOL) isForStartup
{
    tabsVisible = isVisible;
    if ([vfoVaultOverlay isFailureVisible]) {
        return;
    }
    [self updateAlertBadges];
    [UIView animateWithDuration:UIHVC_STD_TAB_DISPLAY animations:^(void){
        [self updateViewConstraints];
        [self.view layoutIfNeeded];
        bPrivacy.alpha = isVisible ? NO : YES;
    } completion:^(BOOL finished){
        uihvc_tab_item_t newItem;
        BOOL animated = NO;
        NSURL *uApp = [ChatSeal cachedStartupURL];
        [ChatSeal setCachedStartupURL:nil];
        if (!isForStartup && [ChatSeal hasVault] && ((![ChatSeal hasExperiencedMessaging] && [ChatSeal wasVaultJustCreated]) || uApp)) {
            newItem  = UIHVC_TAB_VAULT;
            animated = YES;
        }
        else {
            uApp    = nil;
            newItem = UIHVC_TAB_MESSAGES;
            if (psm) {
                animated = YES;
            }
        }
        [self selectTabAtIndex:newItem withAnimation:animated withNewMessage:psm andCompletion:^(void) {
            [self actUponStartupURL:uApp];
        }];
    }];
}

/*
 *  Return the current state of the tabs.
 */
-(BOOL) tabsAreVisible
{
    return tabsVisible;
}

/*
 *  The tabs have alerts on them when interesting events occur.
 */
-(void) updateAlertBadges
{
    // - work through each tab one at a time, but realize that those
    //   view controllers may not exist yet.
    for (uihvc_tab_item_t i = 0; i < UIHVC_TAB_WITH_DEBUG_COUNT; i++) {
        [self updateAlertBadgeForTab:i];
    }
}

/*
 *  Because the feeds are updated much more frequently than anything else, this specific method can 
 *  be used to update only that badge.
 */
-(void) updateFeedAlertBadge
{
    [self updateAlertBadgeForTab:UIHVC_TAB_FEEDS];
}

/*
 *  Return a handle to the active view controller.
 */
-(UIViewController *) currentViewController
{
    return [[vcCurrent retain] autorelease];
}

/*
 *  Return the height of the tabs.
 */
-(CGFloat) tabBarHeight
{
    return CGRectGetHeight(tbTabs.bounds);
}

/*
 *  This is a convenience method for determining if the given view controller is currently being displayed by
 *  the hub.
 */
-(BOOL) isViewControllerTopOfTheHub:(UIViewController *) vc
{
    if (vc.parentViewController) {
        if (self.navigationController.topViewController == self) {
            if (vcCurrent == vc) {
                return YES;
            }
        }
        else {
            if (self.navigationController.topViewController == vc) {
                return YES;
            }
        }
    }
    return NO;
}

/*
 *  Show the privacy button after startup
 */
-(void) delayedShowPrivacy
{
    [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
        bPrivacy.alpha = tabsVisible ? 0.0f : 1.0f;
    }];
}

/*
 *  When we're first starting the app, try to open the vault when it
 *  exists.  If this cannot occur, we'll have to report the failure.
 */
-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // - first time only.
    if (!hasAppeared) {
        // - try to open the vault, which will act upon the startup URL
        //   if it is able to.
        [self attemptToOpenVaultIfAvailableAndNotOpen];
        
        // - determine the character of this view based on the
        //   vault availability
        [self selectTabAtIndex:UIHVC_TAB_MESSAGES withAnimation:NO withNewMessage:nil andCompletion:nil];

        // - if we haven't yet acted upon the app URL, do so now.
        NSURL *uAppURL = [ChatSeal cachedStartupURL];
        [ChatSeal setCachedStartupURL:nil];
        if (![ChatSeal isVaultOpen] && uAppURL) {
            [self actUponStartupURL:uAppURL];
        }
        
        [self performSelector:@selector(delayedShowPrivacy) withObject:nil afterDelay:1.0f];
        hasAppeared = YES;
    }
}

/*
 *  Track rotation events.
 */
-(void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    // - when the vault cannot be unlocked, make sure the placeholder is regenerated during rotations
    if ([vfoVaultOverlay isFailureVisible]) {
        [self setVaultLockedErrorVisible:YES];
    }
}

/*
 *  Because of the way we implemented the hub, the view controllers' navigation items don't control the navigation bar after they
 *  are constructed.  This will force an update after the fact.
 */
-(void) syncNavigationItemFromTopViewController:(UIViewController *) vc withAnimation:(BOOL) animated
{
    if (![self isViewControllerTopOfTheHub:vc]) {
        return;
    }
    
    if (![self.navigationItem.title isEqualToString:vc.navigationItem.title]) {
        [self.navigationItem setTitle:vc.navigationItem.title];
    }
    
    if (self.navigationItem.leftBarButtonItem != vc.navigationItem.leftBarButtonItem) {
        [self.navigationItem setLeftBarButtonItem:vc.navigationItem.leftBarButtonItem animated:animated];
    }
    
    if (self.navigationItem.rightBarButtonItem != vc.navigationItem.rightBarButtonItem) {
        [self.navigationItem setRightBarButtonItem:vc.navigationItem.rightBarButtonItem animated:animated];
    }
}

/*
 *  Display the privacy policy.
 */
-(IBAction) doPrivacy:(id)sender
{
    [UIPrivacyViewController displayPrivacyNoticeFromViewController:self asModal:YES];
}

@end


/*******************************
 UIHubViewController (internal)
 *******************************/
@implementation UIHubViewController (internal)

/*
 *  Change the selection on the tabs
 */
-(void) selectTabAtIndex:(uihvc_tab_item_t) newIndex withAnimation:(BOOL) animated withNewMessage:(ChatSealMessage *) psm andCompletion:(void(^)(void)) completionBlock
{
    // - don't allow the tab to be changed mid-transition.
    // - I am accepting that we will not trigger the completion block in this case because we did not actually do the work.
    if (isTransitioning || [vfoVaultOverlay isFailureVisible]) {
        return;
    }
    
    //  - and only change to valid tab ids.
    if (newIndex < [tbTabs.items count]) {
        // - first select the item.
        UITabBarItem *tbi   = [tbTabs.items objectAtIndex:newIndex];
        tbTabs.selectedItem = tbi;
        selectedIndex       = newIndex;
        
        // - now load the backing view and display it.
        UIViewController *vcChange    = nil;
        switch (newIndex) {
            case UIHVC_TAB_MESSAGES:
                if ([ChatSeal hasExperiencedMessaging]) {
                    if (![vcCurrent isKindOfClass:[UIMessageOverviewViewController class]]) {
                        if (![vcTabs[UIHVC_TAB_MESSAGES] isKindOfClass:[UIMessageOverviewViewController class]]) {
                            [vcTabs[UIHVC_TAB_MESSAGES] release];
                            vcTabs[UIHVC_TAB_MESSAGES] = [[ChatSeal viewControllerForStoryboardId:@"UIMessageOverviewViewController"] retain];
                        }
                        vcChange = vcTabs[UIHVC_TAB_MESSAGES];
                    }
                    
                    // - set the new message, but before the view is visible so that the animation works
                    //   correctly.
                    [(UIMessageOverviewViewController *) vcTabs[UIHVC_TAB_MESSAGES] setNewMessage:psm];
                }
                else {
                    if (![vcCurrent isKindOfClass:[UIGettingStartedViewController class]]) {
                        if (![vcTabs[UIHVC_TAB_MESSAGES] isKindOfClass:[UIGettingStartedViewController class]]) {
                            [vcTabs[UIHVC_TAB_MESSAGES] release];
                            vcTabs[UIHVC_TAB_MESSAGES] = [[ChatSeal viewControllerForStoryboardId:@"UIGettingStartedViewController"] retain];
                        }
                        vcChange = vcTabs[UIHVC_TAB_MESSAGES];
                    }
                }
                break;
                
            case UIHVC_TAB_VAULT:
                if (![vcCurrent isKindOfClass:[UISealVaultViewController class]]) {
                    if (!vcTabs[UIHVC_TAB_VAULT]) {
                        vcTabs[UIHVC_TAB_VAULT] = [[ChatSeal viewControllerForStoryboardId:@"UISealVaultViewController"] retain];
                    }
                    vcChange = vcTabs[UIHVC_TAB_VAULT];
                }
                break;
                
            case UIHVC_TAB_FEEDS:
                if (![vcCurrent isKindOfClass:[UIFeedsOverviewViewController class]]) {
                    if (!vcTabs[UIHVC_TAB_FEEDS]) {
                        vcTabs[UIHVC_TAB_FEEDS] = [[ChatSeal viewControllerForStoryboardId:@"UIFeedsOverviewViewController"] retain];
                    }
                    vcChange = vcTabs[UIHVC_TAB_FEEDS];
                }
                break;
                
            case UIHVC_TAB_DEBUG:
                if (![vcCurrent isKindOfClass:[UIDebugLogViewController class]]) {
                    if (!vcTabs[UIHVC_TAB_DEBUG]) {
                        vcTabs[UIHVC_TAB_DEBUG] = [[ChatSeal viewControllerForStoryboardId:@"UIDebugLogViewController"] retain];
                    }
                    vcChange = vcTabs[UIHVC_TAB_DEBUG];
                }
                break;
                
            default:
                NSLog(@"CS:  Invalid tab request.");
                break;
        }
        
        // - it is possible that we're already where we need to be so don't change unnecessarily
        if (vcChange) {
            // - when we're changing tabs, make sure we never do so when there is active content in the
            //   current one because that would just screw everything up.
            if (vcCurrent) {
                if (vcCurrent.presentedViewController || [self.navigationController.viewControllers count] > 1) {
                    return;
                }
            }
            
            if ([vcChange conformsToProtocol:@protocol(UIHubManagedViewController)] &&
                [vcChange respondsToSelector:@selector(viewControllerWillBecomeActiveTab)]) {
                [(id<UIHubManagedViewController>)vcChange performSelector:@selector(viewControllerWillBecomeActiveTab) withObject:nil];
            }
            [self displayPrimaryViewController:vcChange withAnimation:animated andCompletion:^(void) {
                [self updateAlertBadges];
                
                // - trigger the completion for the tab change.
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
}

/*
 *  This method will change the active view controller in the contents container and optionally fade it 
 *  into view.
 */
-(void) displayPrimaryViewController:(UIViewController *) vcPrimary withAnimation:(BOOL) animated andCompletion:(void(^)(void)) completionBlock
{
    if (vcPrimary == vcCurrent) {
        return;
    }
    
    // - always default to hiding the new view.
    vcPrimary.view.alpha = 0.0f;

    //  - add the new view to the hierarchy.
    [self addChildViewController:vcPrimary];
    vcPrimary.view.frame             = vwContainer.bounds;
    vcPrimary.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [vwContainer addSubview:vcPrimary.view];
    [vwContainer sendSubviewToBack:vcPrimary.view];
    
    // - and update the navigation item we're looking at
    self.navigationItem.title              = vcPrimary.navigationItem.title;
    self.navigationItem.leftBarButtonItem  = vcPrimary.navigationItem.leftBarButtonItem;
    self.navigationItem.rightBarButtonItem = vcPrimary.navigationItem.rightBarButtonItem;
    
    //  - if there is a prior view, then begin its transition now
    UIViewController *vcLastVisible = nil;
    if (vcCurrent) {
        [vcCurrent willMoveToParentViewController:nil];
        vcLastVisible = vcCurrent;
    }
    
    //  - define the transition that will occur after everything is done.
    void (^transitionCompletion)(BOOL completed) = ^(BOOL completed) {
        // - remove the prior view from the hierarchy.
        [vcLastVisible.view removeFromSuperview];
        [vcLastVisible removeFromParentViewController];
        
        // - this is always called after the transition.
        [vcPrimary didMoveToParentViewController:self];
        vcCurrent = vcPrimary;
        
        // - finally execute the caller's completion
        if (completionBlock) {
            completionBlock();
        }
        
        // - make sure the view controller is notified.
        if ([vcCurrent conformsToProtocol:@protocol(UIHubManagedViewController)] &&
            [vcCurrent respondsToSelector:@selector(viewControllerDidBecomeActiveTab)]) {
            [vcCurrent performSelector:@selector(viewControllerDidBecomeActiveTab) withObject:nil];
        }
        
        isTransitioning = NO;
        tbTabs.userInteractionEnabled = YES;
    };
    
    // - if there is animation that will occur, do that first before completing the transition.
    isTransitioning               = YES;
    tbTabs.userInteractionEnabled = NO;
    if (animated) {
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            vcPrimary.view.alpha     = 1.0f;
            vcLastVisible.view.alpha = 0.0f;
        } completion:transitionCompletion];
    }
    else {
        vcPrimary.view.alpha = 1.0f;
        transitionCompletion(YES);
    }
}

/*
 *  Detect selection changes so we can change the tabs.
 */
-(void) tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item
{
    [self selectTabAtIndex:(uihvc_tab_item_t) item.tag withAnimation:NO withNewMessage:nil andCompletion:nil];
}

/*
 *  Return the animation controller for custom transitions.
 */
-(id<UIChatSealNavItemAnimatedTransitioning>) navItemInController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC
{
    // - a very limited subset are custom.
    if (operation == UINavigationControllerOperationPush && [toVC isKindOfClass:[UIMessageDetailViewControllerV2 class]]) {
        // - that animation hack to overcome the tabview dependence isn't useful for this transition.
        tbTabs.hidden     = NO;
        vwSnapTabs.hidden = YES;
        return [[[UIHubMessageDetailAnimationController alloc] initWithInteractiveController:nil] autorelease];
    }
    
    // - just perform the default animation.
    return nil;
}

/*
 *  Make sure that a given view controller and its subordinates are notified.
 */
-(void) notifyViewControllerAndPresentedOfDynamicTypeChange:(UIViewController *) vc
{
    while (vc) {
        if ([vc conformsToProtocol:@protocol(UIDynamicTypeCompliantEntity)]) {
            [(id<UIDynamicTypeCompliantEntity>)vc updateDynamicTypeNotificationReceived];
        }
        vc = vc.presentedViewController;
    }
}

/*
 *  Detect dynamic type changes.
 */
-(void) updateDynamicTypeNotificationReceived
{
    if (!allowDynamicTypeUpdates){
        hasPendingDynamicTypeUpdate = YES;
        if (vwForegroundTransitionCover) {
            UIWindow *win = [[UIApplication sharedApplication] keyWindow];
            [win addSubview:vwForegroundTransitionCover];
            [win bringSubviewToFront:vwForegroundTransitionCover];
        }
        return;
    }
    
    // - no more pending.
    hasPendingDynamicTypeUpdate = NO;
    
    // - make sure all search bars are updated because we can't change them
    //   any other way.
    [UIHubViewController reconfigureSearchBarsForDynamicType];
    
    // - notify the tabs
    for (int i = 0; i < UIHVC_TAB_WITH_DEBUG_COUNT; i++) {
        [self notifyViewControllerAndPresentedOfDynamicTypeChange:vcTabs[i]];
    }
    
    // - and any pushed-on items in the list.
    NSArray *arrVCs = [self.navigationController viewControllers];
    for (NSUInteger i = 1; i < [arrVCs count]; i++) {
        [self notifyViewControllerAndPresentedOfDynamicTypeChange:[arrVCs objectAtIndex:i]];
    }
    
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        [vfoVaultOverlay updateDynamicTypeNotificationReceived];
    }
    
    [self updateDynamicTypeDuringInit:NO];
}

/*
 *  This notification is triggered when the app receives a new URL.
 */
-(void) notifyApplicationURLChanged
{
    NSURL *uStartup = [ChatSeal cachedStartupURL];
    [ChatSeal setCachedStartupURL:nil];
    [self actUponStartupURL:uStartup];
}

/*
 *  When the startup URL is assigned, we need to determine how to proceed with it.
 */
-(void) actUponStartupURL:(NSURL *) u
{
    if (!u) {
        return;
    }
    
    uihvc_tab_item_t tabItem = UIHVC_TAB_MESSAGES;
    if ([ChatSeal isVaultOpen]) {
        tabItem = UIHVC_TAB_VAULT;
    }
    
    [self selectTabAtIndex:tabItem withAnimation:NO withNewMessage:nil andCompletion:^(void) {
        // - re-direct the request onto the active tab if it supports processing.
        if (vcCurrent && [vcCurrent respondsToSelector:@selector(viewControllerShouldProcessApplicationURL:)]) {
            [vcCurrent performSelector:@selector(viewControllerShouldProcessApplicationURL:) withObject:u];
        }
    }];
}

/*
 *  Update a single alert badge.
 */
-(void) updateAlertBadgeForTab:(uihvc_tab_item_t) tab
{
    // - this update request could occur from any thread, so make sure it is always performed on the main one.
    void (^updateBlock)(void) = ^(void) {
        // - work through each tab one at a time, but realize that those
        //   view controllers may not exist yet.
        NSArray *arrTabs          = tbTabs.items;
        UITabBarItem *tbiSelected = tbTabs.selectedItem;
        if (tab < [arrTabs count]) {
            UITabBarItem *tbi   = [arrTabs objectAtIndex:tab];
            BOOL isActive       = (tbi == tbiSelected) ? YES : NO;
            NSString *badgeText = nil;
            if (tbi) {
                switch (tab) {
                    case UIHVC_TAB_MESSAGES:
                        badgeText = [UIMessageOverviewViewController currentTextForTabBadgeThatIsActive:isActive];
                        break;
                        
                    case UIHVC_TAB_VAULT:
                        badgeText = [UISealVaultViewController currentTextForTabBadgeThatIsActive:isActive];
                        break;
                        
                    case UIHVC_TAB_FEEDS:
                        badgeText = [UIFeedsOverviewViewController currentTextForTabBadgeThatIsActive:isActive];
                        break;
                        
                    default:
                        badgeText = nil;
                        break;
                }
                tbi.badgeValue = badgeText;
            }
        }
    };
    
    // - if this doesn't occur on the UI thread, it can result in strange delayed behavior.
    if ([[NSThread currentThread] isEqual:[NSThread mainThread]]) {
        updateBlock();
    }
    else {
        [[NSOperationQueue mainQueue] addOperationWithBlock:updateBlock];
    }
}

/*
 *  For some inexplicable reason, the presence of the tab control will hose up the default
 *  animation transition in the navigation bar.  When we're pushing this view controller, we'll briefly
 *  make a copy of the tabs that can be used to display the transition without affecting the navigation.
 */
-(void) navigationWillPushThisViewController
{
    [vwSnapTabs release];
    vwSnapTabs                        = [[self.view resizableSnapshotViewFromRect:CGRectInset(tbTabs.frame, 0, -1) afterScreenUpdates:NO withCapInsets:UIEdgeInsetsZero] retain];
    vwSnapTabs.userInteractionEnabled = NO;
    vwSnapTabs.center                 = tbTabs.center;
    [self.view addSubview:vwSnapTabs];
    tbTabs.hidden                     = YES;
}

/*
 *  The view is gone and if we used placeholder tabs, discard them now.
 */
-(void) viewDidDisappear:(BOOL)animated
{
    if (vwSnapTabs) {
        [vwSnapTabs removeFromSuperview];
        [vwSnapTabs release];
        vwSnapTabs    = nil;
        tbTabs.hidden = NO;
    }
}

/*
 *  The app is moving to the background.
 */
-(void) notifyWillResign
{
    // - we don't allow dynamic type updates while in the background because
    //   table changes aren't always applied and that can leave odd blank cells in place.
    allowDynamicTypeUpdates = NO;
    
    // - when we change the dynamic type size in 8.0, the transition is a bit abrupt when
    //   returning.  This view will allow us to fade-in nicely.
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        UIWindow *win               = [[UIApplication sharedApplication] keyWindow];
        CGSize sz                   = win.bounds.size;
        if (sz.width > 0.0f && sz.height > 0.0f) {
            UIGraphicsBeginImageContextWithOptions(sz, YES, 0.0f);
            [win drawViewHierarchyInRect:CGRectMake(0.0f, 0.0f, sz.width, sz.height) afterScreenUpdates:NO];
            UIImage *img                = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            [vwForegroundTransitionCover release];
            vwForegroundTransitionCover = nil;
            if (img) {
                UIImageView *ivTmp          = [[UIImageView alloc] initWithImage:img];
                ivTmp.frame                 = CGRectMake(0.0f, 0.0f, sz.width, sz.height);
                ivTmp.contentMode           = UIViewContentModeCenter;
                vwForegroundTransitionCover = ivTmp;
            }
        }
    }
}

/*
 *  The app is going to enter the foreground again.
 */
-(void) notifyWillEnterForeground
{
    allowDynamicTypeUpdates = YES;
    if (hasPendingDynamicTypeUpdate) {
        [self updateDynamicTypeNotificationReceived];
        
        // - when we're coming into the foreground, fade out the transition screen
        //   if one exists.
        if (vwForegroundTransitionCover) {
            UIView *vwTmp               = [vwForegroundTransitionCover autorelease];
            vwForegroundTransitionCover = nil;
            UIWindow *win               = [[UIApplication sharedApplication] keyWindow];
            if (!vwTmp.superview) {
                [win addSubview:vwTmp];
            }
            [win bringSubviewToFront:vwTmp];
            [UIView animateWithDuration:1.25f animations:^(void) {
                vwTmp.alpha = 0.0f;
            }completion:^(BOOL finished) {
                [vwTmp removeFromSuperview];
            }];
        }
    }
    else {
        // - not necessary without the dynamic type update.
        [vwForegroundTransitionCover removeFromSuperview];
        [vwForegroundTransitionCover release];
        vwForegroundTransitionCover = nil;
    }
}

/*
 *  Search bars don't have a direct method for configuring their text, so we'll do it with the appearance.
 *  - NOTE: in order for this update to be propagated to the owning views, they need to detach, then reattach
 *          the views contained inside.
 */
+(void) reconfigureSearchBarsForDynamicType
{
    // - wasn't common prior to 8.0
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        return;
    }
    
    UIFont *font = [UIAdvancedSelfSizingTools constrainedFontForPreferredSettingsAndTextStyle:UIFontTextStyleBody];
    [[UITextField appearanceWhenContainedIn:[UISearchBar class], nil] setDefaultTextAttributes:[NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName]];
}

/*
 *  Update dynamic type labels in this view.
 */
-(void) updateDynamicTypeDuringInit:(BOOL) isInit
{
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        return;
    }
    [UIAdvancedSelfSizingTools constrainTextButton:self.bPrivacy withPreferredSettingsAndTextStyle:UIFontTextStyleBody andMinimumSize:[ChatSeal minimumButtonFontSize] duringInitialization:isInit];
}

@end

/******************************************
 UIGettingStartedViewController (override)
 ******************************************/
@implementation UIGettingStartedViewController (override)
/*
 *  Override the navigation controller handle so that the sub-items can easily integrate with it.
 */
-(UINavigationController *) navigationController
{
    return [[self parentViewController] navigationController];
}
@end


/**********************************************
 UIHubViewController (messageDetailTransition)
 **********************************************/
@implementation UIHubViewController (messageDetailTransition)
/*
 *  Prepare for a hub-oriented transition.
 */
-(void) prepareForTransition
{
    [self.view layoutIfNeeded];
    
    // - when we take snapshots of the tabs, there are a lot of things going on, the most
    //   important of which is their translucency.  This can cause problems when we're
    //   snapshotting them during transitions because some of the background is displayed
    //   without the translucency effect in place.  In order to ensure that we get a good
    //   snapshot in all scenarios, this background will be displayed behind it to
    //   discard the default transparency effects of the tabs.
    // - The tabs are very tricky because they are hooked to the content view and the
    //   content view is snapshot asynchronously from the transition.
    vwTabBG.backgroundColor = [UIColor whiteColor];
}

/*
 *  Return the offset used to make the content invisible, but still snapshottable.
 */
-(CGRect) tabsRectForOpening:(BOOL) isOpening
{
    return CGRectMake(isOpening ? 0.0f : -UIHVC_INVIS_OFFSET, CGRectGetHeight(self.view.bounds) - CGRectGetHeight(tbTabs.bounds),
                      CGRectGetWidth(self.view.bounds), CGRectGetHeight(tbTabs.bounds));
}

/*
 *  Show/hide all the hub content.
 */
-(void) setAllHubContentVisible:(BOOL) isVisible
{
    // - let the constraints handle the updates because doing manual layout ends
    //   up disabling constraint support in the sub-views, which we don't want.
    realContentVisible        = isVisible;
    [self.view setNeedsUpdateConstraints];
    self.view.backgroundColor = isVisible ? [UIColor whiteColor] : [UIColor clearColor];
    if (isVisible) {
        vwTabBG.backgroundColor = [UIColor clearColor];
    }
}

/*
 *  Return the view used as a container for all operations.
 */
-(UIView *) containerView;
{
    return [[vwContainer retain] autorelease];
}

@end

/**************************************
 UIHubViewController (vaultManagement)
 **************************************/
@implementation UIHubViewController (vaultManagement)
/*
 *  Try to open the vault
 */
-(void) attemptToOpenVaultIfAvailableAndNotOpen
{
    if ([ChatSeal hasVault] && ![ChatSeal isVaultOpen]) {
        NSError *err = nil;
        if ([ChatSeal openVaultWithPassword:nil andError:&err]) {
            // - if the cache has been cleared, re-create it when we start up.
            [ChatSeal messageListForSearchCriteria:nil withItemIdentification:nil andError:nil];
            [self setVaultLockedErrorVisible:NO];
            
            // - select the current tab
            [self selectTabAtIndex:UIHVC_TAB_MESSAGES withAnimation:NO withNewMessage:nil andCompletion:nil];
            
            // - if the tabs had been shown before, make sure they are shown now.
            if (tabsVisible) {
                [self setTabsVisible:YES withNewMessage:nil forStartupDisplay:YES];
            }
        }
        else {
            // - NOTE:  If this returns an 'Authentication Failed' with a nil password, it generally means the app key has changed due
            //          to an unintentional vault re-creation.
            NSLog(@"PS-FATAL:  Failed to open the seal vault.  %@", [err localizedDescription]);
            [self setVaultLockedErrorVisible:YES];
        }
    }
}

/*
 *  Show/hide the vault failure message.
 */
-(void) setVaultLockedErrorVisible:(BOOL) isVisible
{
    if (isVisible) {
        [vfoVaultOverlay showFailureWithTitle:NSLocalizedString(@"Seal Vault is Locked", nil)
                                      andText:NSLocalizedString(@"Your personal content could not be unlocked because of an unexpected problem.", nil)
                                 andAnimation:YES];
    }
    else {
        [vfoVaultOverlay hideFailureWithAnimation:YES];
    }
}

/*
 *  Generate a failure placeholder for the overlay.
 */
+(UIImage *) generateVaultFailurePlaceholderOfSize:(CGSize)szPlaceholder withInsets:(UIEdgeInsets)insets andContext:(NSObject *)ctx
{
    return nil;
}

/*
 *  Generate a failure placeholder for the overlay.
 */
-(UIImage *) placeholderImageForOverlay:(UIVaultFailureOverlayView *)overlay
{
    return [UIHubViewController generateVaultFailurePlaceholderOfSize:[ChatSeal appWindowDimensions]
                                                           withInsets:UIEdgeInsetsMake(CGRectGetMaxY(self.navigationController.navigationBar.frame), 0.0f, 0.0f, 0.0f)
                                                           andContext:nil];
}

/*
 *  When a low storage scenario is fixed, try to reopen the vault.
 */
-(void) lowStorageResolved
{
    if ([vfoVaultOverlay isFailureVisible]) {
        [self attemptToOpenVaultIfAvailableAndNotOpen];
    }
}

@end
