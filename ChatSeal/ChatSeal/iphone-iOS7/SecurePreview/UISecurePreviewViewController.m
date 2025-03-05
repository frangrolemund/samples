//
//  UISecurePreviewViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 11/21/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UISecurePreviewViewController.h"
#import "ChatSeal.h"
#import "UIChatSealNavigationController.h"
#import "UIChatSealNavigationInteractiveTransition.h"
#import "UISecurePreviewAnimationController.h"
#import "UIMessageDetailViewControllerV2.h"

// - constants
static const NSTimeInterval UISPV_SCREEN_SAVER_TIMEOUT = 60.0f;

// - types
typedef enum {
    UISPV_DS_HIDDEN_INIT = 0,
    UISPV_DS_BLUR_BG,
    UISPV_DS_BLUR_DISAPPEAR,
    UISPV_DS_BLUR_SCREENSAVER,
    UISPV_DS_SECURE
} uispv_display_state_t;

// - forward declarations
@interface UISecurePreviewViewController (internal) <UIChatSealCustomNavTransitionDelegate>
-(void) commonConfiguration;
-(void) changeNavigationVisibility;
-(void) setNavigationHidden:(BOOL) isHidden;
-(void) presentImageWithSecureDisplay:(BOOL) enabled;
-(void) setSecureDisplayEnabled:(BOOL) enabled;
-(void) notifyWillResignActive;
-(void) notifyDidBecomeActive;
-(void) notifyDidEnterBackground;
-(void) cancelScreenSaver;
-(void) enableScreenSaver;
-(void) screenSaverFired;
-(void) shakeRedisplayImage;
-(void) notifyScreenshotTaken;
-(void) notifySealInvalidated:(NSNotification *) notification;
-(void) completeSealInvalidation;
@end

@interface UISecurePreviewViewController (shared)
-(void) prepareForNavigationTransition;
-(void) addKeyframesForTransitionToThisView:(BOOL) toThisView;
-(void) navigationTransitionWasCancelled;
-(void) navigationWasCompletedToViewController:(UIViewController *) vc;
@end

/****************************
 UISecurePreviewViewController
 ****************************/
@implementation UISecurePreviewViewController
/*
 *  Object attributes.
 */
{
    UIImage                                    *secureImage;
    UIImage                                    *placeholderImage;
    UIChatSealNavigationInteractiveTransition  *interactiveController;
    BOOL                                       isTransitioning;
    BOOL                                       isNavigationHidden;
    UITapGestureRecognizer                     *tgrHideNavigation;
    UIImageView                                *ivSecure;
    uispv_display_state_t                      displayState;
    NSTimer                                    *timerScreenSaver;
    BOOL                                       isSecureDisplayEnabled;
    ChatSealMessage                            *msgExisting;
    BOOL                                       isSealInvalidated;
    BOOL                                       useInitialFade;
    BOOL                                       navWasHidden;
    BOOL                                       hasAppeared;
}
@synthesize ivBackground;

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
 *  Free the object
 */
-(void) dealloc
{
    [ivBackground release];
    ivBackground = nil;
    
    [secureImage release];
    secureImage = nil;
    
    [placeholderImage release];
    placeholderImage = nil;
    
    [interactiveController release];
    interactiveController = nil;
    
    [tgrHideNavigation release];
    tgrHideNavigation = nil;
    
    [ivSecure release];
    ivSecure = nil;
    
    [timerScreenSaver release];
    timerScreenSaver = nil;
    
    [msgExisting release];
    msgExisting = nil;
    
    [super dealloc];
}

/*
 *  Configure the view.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // - set up the background
    [ivBackground setImage:placeholderImage];
    
    // - instantiate a custom interactive controller so we can disable the gesture during
    //   transitions.
    interactiveController = [[UIChatSealNavigationInteractiveTransition alloc] initWithViewController:self];
    [interactiveController setAllowTransitionToStart:NO];
    
    // - allow the user to tap on the view to hide the navigation.
    tgrHideNavigation                         = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(changeNavigationVisibility)];
    tgrHideNavigation.numberOfTapsRequired    = 1;
    tgrHideNavigation.numberOfTouchesRequired = 1;
    [self.view addGestureRecognizer:tgrHideNavigation];
    
    // - create the secure image view that will show the content.
    ivSecure                        = [[UIImageView alloc] initWithFrame:self.view.bounds];
    ivSecure.autoresizingMask       = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    ivSecure.alpha                  = useInitialFade ? 0.0f : 1.0f;
    ivSecure.userInteractionEnabled = NO;
    ivSecure.image                  = secureImage;
    ivSecure.contentMode            = UIViewContentModeScaleAspectFit;
    [self.view addSubview:ivSecure];
    
    // - set up the notifications for keeping the image secure
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyScreenshotTaken) name:UIApplicationUserDidTakeScreenshotNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifySealInvalidated:) name:kChatSealNotifySealInvalidated object:nil];
}

/*
 *  Make sure that only the interactive controller's gesture is enabled.
 */
-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // - capture the initial state of the nav bar
    if (!hasAppeared) {
        hasAppeared  = YES;
        navWasHidden = self.navigationController.navigationBarHidden;
        
        // - we always want to show the nav bar initially upon display.
        if (navWasHidden) {
            [self.navigationController setNavigationBarHidden:NO animated:YES];
        }
    }
    
    // - don't automatically re-present the screensaver
    if (displayState != UISPV_DS_BLUR_SCREENSAVER) {
        [self presentImageWithSecureDisplay:YES];
    }
    
    // - when the seal must be invalidated, return to the prior view.
    if (isSealInvalidated) {
        [self performSelector:@selector(completeSealInvalidation) withObject:nil afterDelay:0.25f];
    }
}

/*
 *  We're about to pop this view controller back to the detail.
 */
-(void) navigationWillPopThisViewController
{
    // - if we are in screensaver mode, make sure that is discarded before returning
    if (displayState == UISPV_DS_BLUR_SCREENSAVER) {
        [self presentImageWithSecureDisplay:YES];
    }
    
    // - make sure the nav bar is returned to where it should be before returning.
    if (navWasHidden) {
        if (!self.navigationController.navigationBarHidden) {
            [self.navigationController setNavigationBarHidden:YES animated:YES];
        }
    }
    else {
        if (self.navigationController.navigationBarHidden) {
            [self.navigationController setNavigationBarHidden:NO animated:YES];
        }
    }
}

/*
 *  Will disappear.
 */
-(void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self cancelScreenSaver];
    if (displayState != UISPV_DS_BLUR_SCREENSAVER) {
        displayState = UISPV_DS_BLUR_DISAPPEAR;
        [self presentImageWithSecureDisplay:NO];
    }
}

/*
 *  The secure image view must be 'prepared' in order to ensure it will be released successfully.
 */
-(void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

/*
 *  Assign the secure image to the view.
 */
-(void) setSecureImage:(UIImage *) image withPlaceholder:(UIImage *) imgPlaceholder andOwningMessage:(ChatSealMessage *) psm
{
    if (secureImage != image) {
        [secureImage release];
        secureImage = [image retain];
    }
    
    if (placeholderImage != imgPlaceholder) {
        [placeholderImage release];
        placeholderImage = [imgPlaceholder retain];
        [ivBackground setImage:imgPlaceholder];
    }
    
    if (msgExisting != psm) {
        [msgExisting release];
        msgExisting = [psm retain];
    }
    
    ivSecure.image = image;
}

/*
 *  The initial fade transitions from the placeholder to the secure image, but that may not always make sense.
 */
-(void) setInitialFadeEnabled:(BOOL) enabled
{
    useInitialFade = enabled;
}

/*
 *  The motion was cancelled.
 */
-(void) motionCancelled:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    [super motionCancelled:motion withEvent:event];
    if (motion == UIEventSubtypeMotionShake) {
        [self shakeRedisplayImage];
    }
}

/*
 *  The motion ended.
 */
-(void) motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    [super motionEnded:motion withEvent:event];
    if (motion == UIEventSubtypeMotionShake) {
        [self shakeRedisplayImage];
    }
}

@end

/****************************************
 UISecurePreviewViewController (internal)
 ****************************************/
@implementation UISecurePreviewViewController (internal)
/*
 *  Initial setup for the object.
 */
-(void) commonConfiguration
{
    self.title             = NSLocalizedString(@"Personal Photo", nil);
    interactiveController  = nil;
    isTransitioning        = NO;
    isNavigationHidden     = NO;
    displayState           = UISPV_DS_HIDDEN_INIT;
    isSecureDisplayEnabled = NO;
    msgExisting            = nil;
    isSealInvalidated      = NO;
    useInitialFade         = YES;
    hasAppeared            = NO;
    navWasHidden           = NO;
}

/*
 *  Return the animation controller for interactive transitions.
 */
-(id<UIChatSealNavItemAnimatedTransitioning>) navItemInController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC
{
    if ([fromVC isKindOfClass:[UIMessageDetailViewControllerV2 class]] || [toVC isKindOfClass:[UIMessageDetailViewControllerV2 class]]) {
        return [[[UISecurePreviewAnimationController alloc] initWithInteractiveController:(operation == UINavigationControllerOperationPop) ? interactiveController : nil] autorelease];
    }
    return nil;
}

/*
 *  Show/hide the navigation bar.
 */
-(void) changeNavigationVisibility
{
    if (displayState == UISPV_DS_BLUR_SCREENSAVER) {
        return;
    }
    isNavigationHidden = !isNavigationHidden;
    [self setNavigationHidden:isNavigationHidden];
}

/*
 *  Turn the navigation bar on/off.
 */
-(void) setNavigationHidden:(BOOL) isHidden
{
    [self.navigationController setNavigationBarHidden:isHidden animated:YES];
    [[UIApplication sharedApplication] setStatusBarHidden:isHidden withAnimation:UIStatusBarAnimationFade];
}

/*
 *  Immediately enable/disable the secure display and manage the associated
 *  screen saver timer.
 */
-(void) setSecureDisplayEnabled:(BOOL) enabled
{
    // - enable/disable the secure display.
    isSecureDisplayEnabled = enabled;
    [self cancelScreenSaver];
    if (enabled) {
        self.navigationItem.prompt = nil;
        
        // - create the screen saver timer to ensure that this never runs so long that it messes
        //   up the screen.
        [self enableScreenSaver];
        
        // - make sure the current state is assigned.
        displayState = UISPV_DS_SECURE;
    }
    ivSecure.alpha = enabled ? 1.0f : 0.0f;
}

/*
 *  Enable/disable secure display.
 */
-(void) presentImageWithSecureDisplay:(BOOL) enabled
{
    [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
        [self setSecureDisplayEnabled:enabled];
    }];
}

/*
 *  The app is about to become non-active.
 */
-(void) notifyWillResignActive
{
    displayState = UISPV_DS_BLUR_BG;
    [self presentImageWithSecureDisplay:NO];
}

/*
 *  The app just became active.
 */
-(void) notifyDidBecomeActive
{
    if (displayState == UISPV_DS_BLUR_BG ||
        displayState == UISPV_DS_BLUR_DISAPPEAR ||
        displayState == UISPV_DS_BLUR_SCREENSAVER) {
        [self presentImageWithSecureDisplay:YES];
    }
}

/*
 *  The app is fully in the background now, so make sure the secure display
 *  is completely gone.
 */
-(void) notifyDidEnterBackground
{
    displayState = UISPV_DS_BLUR_BG;
    [self setSecureDisplayEnabled:NO];
}

/*
 *  Cancel the screen saver.
 */
-(void) cancelScreenSaver
{
    [timerScreenSaver invalidate];
    [timerScreenSaver release];
    timerScreenSaver = nil;
}

/*
 *  Enable the screen saver.
 */
-(void) enableScreenSaver
{
    [self cancelScreenSaver];
    timerScreenSaver = [[NSTimer timerWithTimeInterval:UISPV_SCREEN_SAVER_TIMEOUT target:self selector:@selector(screenSaverFired) userInfo:nil repeats:NO] retain];
    [[NSRunLoop mainRunLoop] addTimer:timerScreenSaver forMode:NSRunLoopCommonModes];
}

/*
 *  The screen saver has fired, so we need to disable the 
 *  view.
 */
-(void) screenSaverFired
{
    [self cancelScreenSaver];
    displayState = UISPV_DS_BLUR_SCREENSAVER;
    [self presentImageWithSecureDisplay:NO];
    self.navigationItem.prompt = NSLocalizedString(@"Shake to reveal the photo.", nil);
    [self setNavigationHidden:NO];
}

/*
 *  Redisplay the image with a shake or extend the timer.
 */
-(void) shakeRedisplayImage
{
    if (displayState == UISPV_DS_BLUR_SCREENSAVER) {
        [self presentImageWithSecureDisplay:YES];
    }
    else {
        [self enableScreenSaver];
    }
}

/*
 *  When a screenshot is taken during a preview, make sure -
 */
-(void) notifyScreenshotTaken
{
    // - when there is a modal view controller in front of this one, there is no
    //   need to protect the person.
    // - when this view is not active because the nav stack is pushed on top of it
    //   there is also no need for this guy to process it.
    if (self.presentedViewController || !self.view.superview) {
        return;
    }
    [ChatSeal checkForSealRevocationForScreenshotWhileReadingMessage:msgExisting];
}

/*
 *  When a seal is invalidated, we may need to do something here if it is the one
 *  we're currently looking at.
 */
-(void) notifySealInvalidated:(NSNotification *) notification
{
    // - no message?, then it must be ours.
    if (!msgExisting) {
        return;
    }
    
    // - check the identity and make sure that it isn't owned by us.
    ChatSealIdentity *ident = [msgExisting identityWithError:nil];
    if (!ident) {
        return;
    }
    
    // - now compare the seal ids and ignore if it isn't this seal.
    NSArray *arr = [notification.userInfo objectForKey:kChatSealNotifySealArrayKey];
    if (!arr || ![arr containsObject:ident.sealId]) {
        return;
    }
    
    isSealInvalidated = YES;
    
    // - if this view is visible, then close it right now.
    if (!self.presentedViewController && self.view.superview) {
        [self completeSealInvalidation];
    }
}

/*
 *  When the seal is invalidated, pop back to the previous view controller.
 */
-(void) completeSealInvalidation
{
    [self.navigationController popViewControllerAnimated:YES];
    isSealInvalidated = NO;
}

@end

/***************************************
 UISecurePreviewViewController (shared)
 ***************************************/
@implementation UISecurePreviewViewController (shared)

/*
 *  This method is called before the navigation animations begin.
 */
-(void) prepareForNavigationTransition
{
    // - track the transitioning state
    isTransitioning           = YES;
    [interactiveController setAllowTransitionToStart:NO];
}

/*
 *  Add keyframes for the transition.
 */
-(void) addKeyframesForTransitionToThisView:(BOOL) toThisView
{
    if (toThisView) {
        self.view.alpha = 0.0f;
    }
    CGFloat duration = 0.25f;
    CGFloat start    = 0.0f;
    if (toThisView) {
        start = 0.75f;
    }
    else {
        start = 0.0f;
    }
    [UIView addKeyframeWithRelativeStartTime:start relativeDuration:duration animations:^(void) {
        self.view.alpha = (toThisView ? 1.0f : 0.0f);
    }];
}

/*
 *  Complete the transition in a standard way.
 */
-(void) commonTransitionCompletion
{
    [interactiveController setAllowTransitionToStart:YES];
    isTransitioning           = NO;
    self.view.backgroundColor = [UIColor blackColor];
}

/*
 *  The interactive transition animation has been cancelled.
 */
-(void) navigationTransitionWasCancelled
{
    [self commonTransitionCompletion];
}

/*
 *  The navigation has completed back to the prior view.
 */
-(void) navigationWasCompletedToViewController:(UIViewController *) vc
{
    [self commonTransitionCompletion];
    if (![vc isKindOfClass:[UISecurePreviewViewController class]] && isNavigationHidden) {
        isNavigationHidden = NO;
        [self setNavigationHidden:isNavigationHidden];
    }
}
@end