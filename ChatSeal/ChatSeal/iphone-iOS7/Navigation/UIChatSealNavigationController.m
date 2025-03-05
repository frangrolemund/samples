//
//  UIChatSealNavigationController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/4/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UIChatSealNavigationController.h"
#import "UIChatSealNavigationInteractiveTransition.h"
#import "ChatSeal.h"
#import "AlertManager.h"
#import "UIHubViewController.h"
#import "UIChatSealNavBarTitleView.h"
#import "UIChatSealNavigationBar.h"

// - constants
static const CGFloat UICSNC_RESERVED_BAR_WIDTH   = 86.0f;           //  don't draw in this space on the bar.

// - forward declarations
@interface UIChatSealNavigationController (internal) <UINavigationControllerDelegate>
-(void) commonConfiguration;
-(void) rebuildNavBarBackgroundIfNecessary;
-(void) buildNavBarToResembleLaunch;
-(BOOL) doesViewControllerUseCustomTransitions:(UIViewController *) vc;
@end

/*********************************
 UIChatSealNavigationController
 *********************************/
@implementation UIChatSealNavigationController
/*
 *  Object attributes
 */
{
    BOOL hasAppeared;
    BOOL appPrimary;
    BOOL isRotating;
    BOOL hasCompletedAFullStyling;
    BOOL hasStartedTransitionDelay;
}

/*
 *  Initialize this module.
 */
+(void) initialize
{
    [[UINavigationBar appearance] setTitleTextAttributes:[NSDictionary dictionaryWithObject:[UIChatSealNavBarTitleView standardTitleFont] forKey:NSFontAttributeName]];
}

/*
 *  Manage the creation process and set up its delegate automatically.
 */
+(UINavigationController *) instantantiateNavigationControllerWithRoot:(UIViewController *) vc
{
    UIChatSealNavigationController *nc = [[[UIChatSealNavigationController alloc] initWithRootViewController:vc] autorelease];
    return nc;
}

/*
 *  Initialize the object.
 */
-(id) initWithRootViewController:(UIViewController *)rootViewController
{
    self = [super initWithNavigationBarClass:[UIChatSealNavigationBar class] toolbarClass:[UIToolbar class]];
    if (self) {
        [self commonConfiguration];
        [self pushViewController:rootViewController animated:NO];
    }
    return self;
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonConfiguration];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    self.delegate = nil;
    [super dealloc];
}

/*
 *  When we need to know about push operations, this can be used.
 */
-(void) pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    // - if the new view controller implements the navigation delegate we need to be able to forward it.
    if ([self doesViewControllerUseCustomTransitions:viewController]) {
        self.delegate = self;
    }
    
    // - when the top view controller implements the navigation delegate we need to be able
    //   to forward it.
    UIViewController *vc = [self topViewController];
    if ([self doesViewControllerUseCustomTransitions:vc]) {
        self.delegate = self;
        if ([vc respondsToSelector:@selector(navigationWillPushThisViewController)]) {
            [(id<UIChatSealCustomNavTransitionDelegate>) vc navigationWillPushThisViewController];
        }
    }
    [super pushViewController:viewController animated:animated];
}

/*
 *  There are times we want to know when the current view controller will be dismissed, but before
 *  it begins.  This will check and notifify the delegate accordingly.
 */
-(UIViewController *) popViewControllerAnimated:(BOOL)animated
{
    // - if the top view controller implements the navigation delegate, we need to be able to forward it.
    UIViewController *vc = [self topViewController];
    if ([self doesViewControllerUseCustomTransitions:vc]) {
        self.delegate = self;
        if ([vc respondsToSelector:@selector(navigationWillPopThisViewController)]) {
            [(id<UIChatSealCustomNavTransitionDelegate>) vc navigationWillPopThisViewController];
        }
    }
    
    // - if the view controller we're returning to implements the navigation delegate, we need to be able to forward it.
    NSArray *arrVC = [self viewControllers];
    if ([arrVC count] > 1 && [self doesViewControllerUseCustomTransitions:(UIViewController *) [arrVC objectAtIndex:[arrVC count]-2]]) {
        self.delegate = self;
    }
    
    return [super popViewControllerAnimated:animated];
}

/*
 *  The view has been loaded.
 */
-(void) viewDidLoad
{
    [super viewDidLoad];
    
    // - the default for translucency changes when we assign a background image for the nav bar
    //   so we'll explicitly assign this.
    self.navigationBar.translucent = YES;
}

/*
 *  When the view has first appeared, this method is issued.
 */
-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    // - begin integrating the vault into the UI.
    if (appPrimary && !hasAppeared && [ChatSeal isVaultOpen]) {
        // - only show the tabs after this view has appeared because it will allow us to naturally transition over
        //   from the loading screen to the working app.
        [[ChatSeal applicationHub] setTabsVisible:YES withNewMessage:nil forStartupDisplay:YES];
    }
    [(UIChatSealNavigationBar *) self.navigationBar setLayoutRebuildEnabled:YES];
    hasAppeared = YES;
}

/*
 *  Indicate whether a navigation controller is the primary one for the application.
 */
-(void) setIsApplicationPrimary
{
    appPrimary = YES;
}

/*
 *  Give the view controllers managed by this nav controller an opportunity to
 *  update their dynamic type.
 */
-(void) updateDynamicTypeNotificationReceived
{
    for (UIViewController *vc in self.viewControllers) {
        if ([vc conformsToProtocol:@protocol(UIDynamicTypeCompliantEntity)]) {
            [(id<UIDynamicTypeCompliantEntity>)vc updateDynamicTypeNotificationReceived];
        }
    }
}

/*
 *  We're about to rotate the device.
 */
-(void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [(UIChatSealNavigationBar *) self.navigationBar setLayoutRebuildEnabled:NO];
    isRotating = YES;
}

/*
 *  Animate to a new orientation.
 */
-(void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    // - this is a great place to rebuild the background image because by this point the dimensions of the nav
    //   bar have been assigned.
    isRotating = NO;
    [(UIChatSealNavigationBar *) self.navigationBar setLayoutRebuildEnabled:YES];
    [self rebuildNavBarBackgroundIfNecessary];
}

/*
 *  Layout has occurred.
 */
-(void) viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    // - we must always check the nav bar when layouts occur, just to be sure, but if we're going to rotate, we'll get another
    //   chance in a moment.
    if (!isRotating) {
        if (appPrimary && !hasCompletedAFullStyling) {
            if (!hasStartedTransitionDelay) {
                // - the delay is based on whether we've experienced messaging because if the getting started animation is playing, it will be hosed
                //   up by this animation.
                [self performSelector:@selector(rebuildNavBarBackgroundIfNecessary) withObject:nil afterDelay:[ChatSeal hasExperiencedMessaging] ? 0.6f : 1.0f];
                [self buildNavBarToResembleLaunch];
            }
            hasStartedTransitionDelay = YES;
        }
        else {
            [self rebuildNavBarBackgroundIfNecessary];
        }
    }
    
    // - the title view is only relevant during app startup since we can get potentially better formatting and
    //   the same style with the default title support
    if (appPrimary && !hasCompletedAFullStyling) {
        // - check if the title is different here.
        NSString *itemTitle    = self.navigationBar.topItem.title;
        UIView *vwCurTitleView = self.navigationBar.topItem.titleView;
        if ([vwCurTitleView isKindOfClass:[UIChatSealNavBarTitleView class]]) {
            UIChatSealNavBarTitleView *nbtv = (UIChatSealNavBarTitleView *) vwCurTitleView;
            if (![nbtv.title isEqualToString:itemTitle]) {
                vwCurTitleView = nil;
            }
        }
        else {
            vwCurTitleView = nil;
        }
                
        // - when we have a title view, make sure its maximum width is assigned.
        [(UIChatSealNavBarTitleView *) vwCurTitleView setMaxTextWidth:CGRectGetWidth(self.navigationBar.bounds) - UICSNC_RESERVED_BAR_WIDTH];
    }
}

@end


/*******************************************
 UIChatSealNavigationController (internal)
 *******************************************/
@implementation UIChatSealNavigationController (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    hasAppeared               = NO;
    appPrimary                = NO;
    isRotating                = NO;
    hasCompletedAFullStyling  = NO;
    hasStartedTransitionDelay = NO;
}

/*
 *  Return the custom animation transition.
 */
-(id<UIViewControllerAnimatedTransitioning>) navigationController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC
{
    id<UIViewControllerAnimatedTransitioning> retObj = nil;
    if ([fromVC conformsToProtocol:@protocol(UIChatSealCustomNavTransitionDelegate)]) {
        retObj = [(id<UIChatSealCustomNavTransitionDelegate>) fromVC navItemInController:navigationController animationControllerForOperation:operation fromViewController:fromVC toViewController:toVC];
    }
    
    if (!retObj && [toVC conformsToProtocol:@protocol(UIChatSealCustomNavTransitionDelegate)]) {
        retObj = [(id<UIChatSealCustomNavTransitionDelegate>) toVC navItemInController:navigationController animationControllerForOperation:operation fromViewController:fromVC toViewController:toVC];
    }
    return retObj;
}

/*
 *  Return the custom interactive transition
 */
-(id<UIViewControllerInteractiveTransitioning>) navigationController:(UINavigationController *)navigationController interactionControllerForAnimationController:(id<UIViewControllerAnimatedTransitioning>)animationController
{
    UIChatSealNavigationInteractiveTransition *ret = nil;
    if ([animationController conformsToProtocol:@protocol(UIChatSealNavItemAnimatedTransitioning)]) {
        ret = [(id<UIChatSealNavItemAnimatedTransitioning>) animationController interactiveController];
        if (ret) {
            self.interactivePopGestureRecognizer.enabled = NO;
        }
    }
    return ret;
}

/*
 *  Navigation has been completed.
 */
-(void) navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    // - when this happens, we need to determine if the new view controller requires interactive transition support
    //   and if not, then disable the delegate because the presence of the delegate with the animationControllerForOperation does not
    //   actually produce the default interactive pop we want.
    if (![self doesViewControllerUseCustomTransitions:viewController]) {
        self.delegate = nil;
        self.interactivePopGestureRecognizer.enabled = YES;
    }
}

/*
 *  Rebuild the background of the nav bar if it has changed dimension.
 */
-(void) rebuildNavBarBackgroundIfNecessary
{
    if ([self.navigationBar isKindOfClass:[UIChatSealNavigationBar class]]) {
        // - assign the new image.
        if (appPrimary && !hasCompletedAFullStyling) {
            // - the first time we do this in the full app, we're going to add an additional animation to the sequence.
            if ([ChatSeal isApplicationForeground]) {
                UIView *vwSnap = [self.view resizableSnapshotViewFromRect:CGRectMake(0.0f, 0.0f,
                                                                                     CGRectGetWidth(self.view.bounds), CGRectGetMaxY(self.navigationBar.frame)) afterScreenUpdates:YES withCapInsets:UIEdgeInsetsZero];
                [self.view addSubview:vwSnap];
                [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                    vwSnap.alpha = 0.0f;
                } completion:^(BOOL finished) {
                    [vwSnap removeFromSuperview];
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
                        // - so that we can coordinate with the end of the first animation.
                        [[NSNotificationCenter defaultCenter] postNotificationName:kChatSealNotifyInitialStylingCompleted object:nil];
                    }];
                }];
            }
            
            // - pull the title view we applied so that the right kind fades-in.
            self.navigationBar.topItem.titleView = nil;
        }
        
        // - assign the content.
        [(UIChatSealNavigationBar *) self.navigationBar assignStandardNavStyleInsideNavigationController:self];
        hasCompletedAFullStyling = YES;
    }
}

/*
 *  When we first launch we want the nav bar to look just like the launch bar so that we can transition from the 'encrypted' title to the 
 *  general purpose one.
 */
-(void) buildNavBarToResembleLaunch
{
    if (self.navigationItem.titleView) {
        return;
    }
    
    if ([self.navigationBar isKindOfClass:[UIChatSealNavigationBar class]]) {
        [(UIChatSealNavigationBar *) self.navigationBar assignLaunchCompatibleNavStyle];
    }
}

/*
 *  Check the view controller to see if we can expect it to use custom transitioning.
 */
-(BOOL) doesViewControllerUseCustomTransitions:(UIViewController *) vc
{
    return [vc conformsToProtocol:@protocol(UIChatSealCustomNavTransitionDelegate)];
}
@end