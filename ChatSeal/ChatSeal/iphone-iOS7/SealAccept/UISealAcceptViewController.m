//
//  UISealAcceptViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/17/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <CoreMotion/CoreMotion.h>
#import "UISealAcceptViewController.h"
#import "UIChatSealNavigationController.h"
#import "UISealExchangeAnimationController.h"
#import "UISealShareViewController.h"
#import "ChatSeal.h"
#import "ChatSealBaseStation.h"
#import "AlertManager.h"
#import "UIQRScanner.h"
#import "UINewSealCell.h"
#import "UITimerView.h"
#import "UISealAcceptSignalView.h"
#import "UISealAcceptFailureAlertView.h"
#import "UISealSelectionViewController.h"
#import "UINewSealViewController.h"
#import "ChatSealFeedCollector.h"
#import "UIDynamicTypeCompliantEntity.h"
#import "UIAdvancedSelfSizingTools.h"

// - constants
static const NSTimeInterval UISAV_SEAL_DISPLAY_TIME       = 1.5f;
static const NSTimeInterval UISAV_CONN_ERR_DISPLAY_TIME   = 1.0f;
static const NSTimeInterval UISAV_CONN_FAIL_DISPLAY_TIME  = 4.0f;
static const NSUInteger     UISAV_NUM_XFER_ERR_TO_DISPLAY = 5;
static const NSTimeInterval UISAV_TRANSFER_PULSE_PERIOD   = 1.25f;
static const NSUInteger     UISAV_NUM_REM_FAIL_TO_DISPLAY = 2;
static const NSTimeInterval UISAV_PROX_FAIL_TIMEOUT       = 5;
static const time_t         UISAV_INACTIVITY_TIMEOUT      = 60;
static const CGFloat        UISAV_TOP_MARGIN_PAD          = 8.0f;

// - forward declarations
@interface UISealAcceptViewController (internal) <UIChatSealCustomNavTransitionDelegate, UIDynamicTypeCompliantEntity>
-(void) commonConfiguration;
-(BOOL) setScanningIsEnabled:(BOOL) isEnabled withAnimation:(BOOL) animated andError:(NSError **) err;
-(void) discardSealTransferAndPrepareForAnother:(BOOL) prepareForAnother;
-(void) showImportedSealWithId:(NSString *) sealId andAnimation:(BOOL) animated;
-(void) showAcceptFailureViewAsConnectionProblem:(BOOL) isConnectionIssue;
-(void) hideAcceptFailureViewWithAnimation:(BOOL) animated;
-(void) notifyWillEnterBackground:(NSNotification *) notification;
-(void) notifyBackgrounded:(NSNotification *) notification;
-(void) notifyWillEnterForeground;
-(void) notifyForegrounded:(NSNotification *) notification;
-(void) notifyBasestationUpdate;
-(BOOL) isSatisfiedFirstTimeUser;
-(void) shiftToTransferStatus:(BOOL) toTransfer;
-(void) moveToSealSharingMode;
-(void) updateSealAcceptedStatus;
-(void) fadeHintWithAnimation:(BOOL) animated;
-(void) fadeScanningBehaviorWithAnimation:(BOOL) animated;
-(void) beginAppearanceScanningWithAnimation:(BOOL) animated;
-(void) gyroDeviceHasBecomeInactive;
-(void) gyroDeviceHasBecomeActive;
-(void) startGyroDetection;
-(void) stopGyroDetection;
-(void) resetGyroDetectionTimeout;
-(void) processGyroEventWithData:(CMGyroData *) gyroData;
-(void) setProgressVisible:(BOOL) isVisible withPercentage:(CGFloat) pct;
-(void) discardHintTimer;
-(void) slideNewHintIfNecessary;
-(void) prepareForDelayedHintComputationWithShortDelay:(BOOL) asShortDelay;
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL) isInit;
-(BOOL) updatePreferredWidths;
@end

// - shared declarations
@interface UISealExchangeController (shared)
+(UIViewController *) sealShareViewControllerForConfiguration:(UISealExchangeConfiguration *) config;
+(void) prepareForExchangeTargetDisplay:(UIViewController<UISealExchangeFlipTarget> *) vc asScanner:(BOOL) isScanning andAssumeMultiUse:(BOOL) multiUse;
+(void) completeExchangeNavigationAfterDidAppearForController:(UIViewController<UISealExchangeFlipTarget> *) vc;
+(void) setSealTransferStateForViewController:(UIViewController<UISealExchangeFlipTarget> *) vc asEnabled:(BOOL) isEnabled;
+(void) setPreventReturnNavigationForViewController:(UIViewController<UISealExchangeFlipTarget> *) vc asEnabled:(BOOL) isEnabled;
+(void) reconfigureExchangeTargetDisplay:(UIViewController<UISealExchangeFlipTarget> *) vc asScanner:(BOOL) isScanning andAssumeMultiUse:(BOOL) multiUse;
@end

// - scanner-related tasks.
@interface UISealAcceptViewController (scanner) <UIQRScannerDelegate>
@end

// - seal transfer tasks.
@interface UISealAcceptViewController (remote) <ChatSealRemoteIdentityDelegate>
-(void) updateAcceptedSealsForRemoteIdentity:(ChatSealRemoteIdentity *) identity andSealId:(NSString *) sealId;
-(void) transferPulseTimer:(NSTimer *) timer;
@end

// - radar view tasks
@interface UISealAcceptViewController (radarView) <UISealAcceptRadarViewDelegate>
@end

/*******************************
 UISealAcceptViewController
 *******************************/
@implementation UISealAcceptViewController
/*
 *  Object attributes.
 */
{
    UISealExchangeConfiguration  *exchangeConfig;
    BOOL                         hasAppeared;
    UIQRScanner                  *scanner;
    ChatSealRemoteIdentity      *remoteSeal;
    NSURL                        *lastGoodURL;
    BOOL                         inTransferErrorState;
    UITimerView                  *tvSealDisplay;
    NSString                     *sealIdDisplay;
    BOOL                         isRotating;
    UISealAcceptSignalView       *sasvCurSignal;
    UISealAcceptFailureAlertView *safaFailAlert;
    NSUInteger                   numTransferErrors;
    BOOL                         inBackground;
    NSTimer                      *tmTransferPulse;
    NSUInteger                   numRemoteFailures;
    BOOL                         hasProximityFailure;
    NSTimeInterval               tiProximityFailureStarted;
    NSLayoutConstraint           *lcTopControls;
    CMMotionManager              *motionManager;
    NSOperationQueue             *opQGyroUpdate;
    NSRecursiveLock              *lckGyro;
    time_t                       lastGoodGyroUpdate;            // access only with lckGyro
    BOOL                         isInactive;                    // access only with lckGyro
    NSTimer                      *tmDelayedHintTimer;
    BOOL                         timerWasUpdated;
}
@synthesize vwScanningControls;
@synthesize vwRadarOverlay;
@synthesize lOverview;
@synthesize lTransferOverview;
@synthesize pvTransfer;
@synthesize lImporting;

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
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self discardSealTransferAndPrepareForAnother:NO];
    [self setScanningIsEnabled:NO withAnimation:NO andError:nil];
    
    [vwScanningControls release];
    vwScanningControls = nil;
    
    vwRadarOverlay.delegate = nil;
    [vwRadarOverlay release];
    vwRadarOverlay = nil;
    
    [lOverview release];
    lOverview = nil;
    
    [lTransferOverview release];
    lTransferOverview = nil;
    
    [pvTransfer release];
    pvTransfer = nil;
    
    [sasvCurSignal release];
    sasvCurSignal = nil;
    
    [safaFailAlert release];
    safaFailAlert = nil;
    
    [exchangeConfig release];
    exchangeConfig = nil;
    
    [lastGoodURL release];
    lastGoodURL = nil;
    
    [lcTopControls release];
    lcTopControls = nil;
    
    [self stopGyroDetection];
    [motionManager release];
    motionManager = nil;
    
    [opQGyroUpdate release];
    opQGyroUpdate = nil;
    
    [lckGyro release];
    lckGyro = nil;
    
    [lImporting release];
    lImporting = nil;
    
    [self discardHintTimer];
    
    [super dealloc];
}

/*
 *  View is loaded
 */
-(void) viewDidLoad
{
    [super viewDidLoad];
    
    // - NOTE: the first time somone accepts a seal is going to be special because
    //   it is intended to not overcomplicate their experience.  There will be no
    //   way to share your own seal here, just a way to get a single seal imported
    //   quickly and see what happens.
    
    // - do some common configuration for this target.
    [UISealExchangeController prepareForExchangeTargetDisplay:self asScanner:YES andAssumeMultiUse:!exchangeConfig.isFirstTime];
    
    // - hide the identification colors from the views in the NIB
    self.view.backgroundColor          = [UIColor blackColor];
    vwScanningControls.backgroundColor = [UIColor blackColor];          // to make this rotate nicely with a video stream above it.
    self.lOverview.textColor           = [ChatSeal defaultDarkShadowTextCompliment];
    
    // - hide the overview initially.
    self.lOverview.alpha      = 0.0f;
    
    // - and the failure text.
    [vwRadarOverlay setScannerOverlayText:nil inColor:nil withAnimation:NO];
    
    // - make sure the transfer status and importing text show up
    [ChatSeal defaultLowChromeShadowTextLabelConfiguration:self.lTransferOverview];
    self.lTransferOverview.alpha     = 0.0f;
    [ChatSeal defaultLowChromeShadowTextLabelConfiguration:self.lImporting];
    self.lImporting.alpha            = 0.0f;
    [self setProgressVisible:NO withPercentage:0.0f];
    self.pvTransfer.progress         = 0.0f;
    
    // - watch the backgrounding/foregrounding notifications to manage the animations.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyWillEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyBackgrounded:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyForegrounded:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyBasestationUpdate) name:kChatSealNotifyNetworkChange object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyBasestationUpdate) name:kChatSealNotifyNearbyUserChange object:nil];    
    
    // - make sure the overview reflects the number of scanned seals, even when returning.
    [self updateSealAcceptedStatus];
    
    // - reconfigure dynamic type.
    [self reconfigureLabelsForDynamicTypeDuringInit:YES];
}

/*
 *  Creator configuration for this view.
 */
-(void) setConfiguration:(UISealExchangeConfiguration *)config
{
    if (exchangeConfig != config) {
        [exchangeConfig release];
        exchangeConfig = [config retain];
    }
}

/*
 *  Return the active configuration.
 */
-(UISealExchangeConfiguration *) configuration
{
    return [[exchangeConfig retain] autorelease];
}

/*
 *  The view has appeared.
 */
-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // - first-time tasks.
    if (!hasAppeared) {
        // - in order to make this look like it is just a single view that is being swapped, we're
        //   going to actually modify the view controller stack at this point.
        [UISealExchangeController completeExchangeNavigationAfterDidAppearForController:self];
    }
    
    //  NOTE: I am intentionally not asking permission to share feed names here, although the 'share' screen
    //        does because I think it is less critical for a consumer to share feeds and I'm inclined to allow
    //        them the opportunity to do it on their own terms in the Feeds Overview.
    hasAppeared = YES;
    [self beginAppearanceScanningWithAnimation:YES];
}

/*
 *  The view is about to disappear.
 */
-(void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // - discard active transfers
    [self discardSealTransferAndPrepareForAnother:YES];
    
    // - always hide the scanned seal before disappearing.
    [self showImportedSealWithId:nil andAnimation:YES];
    
    // - and the error alert view
    [self hideAcceptFailureViewWithAnimation:YES];
    
    // - don't display a new hint.
    [self discardHintTimer];
 
    // - always make sure the nav bar stays in synch even if we disabled it briefly.
    [UISealExchangeController setPreventReturnNavigationForViewController:self asEnabled:YES];
}

/*
 *  The view has disappeared.
 */
-(void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // - make sure all pending operations are discarded
    [[ChatSeal uiPopulationQueue] cancelAllOperations];
    
    // - turn off the scanner.
    [self setScanningIsEnabled:NO withAnimation:NO andError:nil];
    [self fadeHintWithAnimation:NO];
}

/*
 *  When we are done with this view controller, make certain that the gyro is stopped
 *  or we'll leak because of the retain loop.
 */
-(void) didMoveToParentViewController:(UIViewController *)parent
{
    [super didMoveToParentViewController:parent];
    if (!parent) {
        [self stopGyroDetection];
    }
}

/*
 *  Update the constraints on this view.
 */
-(void) updateViewConstraints
{
    [super updateViewConstraints];
    
    // - there is an odd issue during customn transitions where the top layout guide isn't
    //   correctly adjusted before layout occurs.  Since this view needs to lay out based on where
    //   that guide is, that causes a problem during mode swaps.
    // - I tried using the edgesForExtendedLayout, but that unfortunately causes an immediate re-layout
    //   at the wrong time during the custom transition, breaking the animation.
    // - This approach here is to explicitly manage the top constraint.
    if (!lcTopControls) {
        lcTopControls = [[NSLayoutConstraint constraintWithItem:vwScanningControls attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1.0f constant:0.0f] retain];
        [self.view addConstraint:lcTopControls];
    }
    
    // - adjust the distance based on the nav bar.
    lcTopControls.constant = CGRectGetMaxY(self.navigationController.navigationBar.frame);
}

/*
 *  Do additional layout.
 */
-(void) viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    // - we're going to reorient the scanner explicitly so that it doesn't have the rotation transition
    //   which doesn't look nice with it.  The goal is to make that video stay pretty much rock solid during
    //   the device rotation.
    UIInterfaceOrientation orientation = self.backwardsCompatibleInterfaceOrientation;
    CGAffineTransform at               = CGAffineTransformIdentity;
    CGRect            rcScanner        = CGRectMake(0.0f, 0.0f, CGRectGetWidth(vwScanningControls.bounds), CGRectGetHeight(vwScanningControls.bounds));
    switch (orientation) {
        case UIInterfaceOrientationPortrait:
        case UIInterfaceOrientationUnknown:
            at = CGAffineTransformIdentity;
            break;
            
        case UIInterfaceOrientationPortraitUpsideDown:
            at = CGAffineTransformMakeRotation((CGFloat) M_PI);
            break;
            
        case UIInterfaceOrientationLandscapeLeft:
            at        = CGAffineTransformMakeRotation((CGFloat) (M_PI/2.0f));
            rcScanner = CGRectMake(0.0f, 0.0f, rcScanner.size.height, rcScanner.size.width);
            break;
            
        case UIInterfaceOrientationLandscapeRight:
            at        = CGAffineTransformMakeRotation((CGFloat) -(M_PI/2.0f));
            rcScanner = CGRectMake(0.0f, 0.0f, rcScanner.size.height, rcScanner.size.width);
            break;
    }
    
    [UIView performWithoutAnimation:^(void) {
        scanner.transform = CGAffineTransformIdentity;
        scanner.bounds    = rcScanner;
        scanner.transform = at;
        scanner.center    = CGPointMake(CGRectGetWidth(vwScanningControls.bounds)/2.0f, CGRectGetHeight(vwScanningControls.bounds)/2.0f);        
    }];
    
    // - make sure the text items have their preferred widths updated.
    if ([self updatePreferredWidths]) {
        // - force autolayout to be executed again when we change constraints.
        [self.view layoutSubviews];
    }
    
    // - make sure the cut-out for the overlay is below the text that describes how to
    //   use this view.
    [vwRadarOverlay setTopMarginHeight:CGRectGetMaxY(lOverview.frame) + UISAV_TOP_MARGIN_PAD];
    
    // - if there is a failure being displayed, make sure it is reoriented.
    safaFailAlert.frame = [vwRadarOverlay scanningTargetRegion];
}

/*
 *  A rotation is about to occur.
 */
-(void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    // - remove the current signal (fading it looks dumb)
    [sasvCurSignal removeFromSuperview];
    [sasvCurSignal release];
    sasvCurSignal = nil;
    
    // - when we rotate, we're going to hide that hint so that it can come in to its
    //   rotation-appropriate place afterwards.
    isRotating = YES;
    [self fadeHintWithAnimation:YES];
    [vwRadarOverlay prepareForRotation];
}

/*
 *  During animations, we need to update the layout constraints so that the top one stays in synch.
 */
-(void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self.view setNeedsUpdateConstraints];
}

/*
 *  Rotation has just completed.
 */
-(void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    isRotating = NO;

    [self prepareForDelayedHintComputationWithShortDelay:YES];
    [vwRadarOverlay completeRotation];
}

/*
 *  When operating modally, dismiss this view.
 */
-(void) doModalDone
{
    // - it is critical that we stop the gyro detection here because otherwise there will be a retain loop
    //   that is never broken.
    [self stopGyroDetection];
    
    // - complete the modal display.
    if (exchangeConfig.completionBlock) {
        exchangeConfig.completionBlock(exchangeConfig.sealsAcceptedPerHost.count > 0 ? YES : NO);
    }
    else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

/*
 *  Swap over to the seal share personality.
 */
-(void) doSwapModes
{
    if (exchangeConfig.sealIdentity || [ChatSeal activeSeal]) {
        [self moveToSealSharingMode];
    }
    else {
        // - figure out if we should select or create a seal.
        UIViewController *vcToPresent = nil;
        if ([UISealSelectionViewController selectionIsPossibleWithError:nil]) {
            vcToPresent = [UISealSelectionViewController viewControllerForMessageSealSelection:NO withSelectionCompletionBlock:^(BOOL hasActiveSeal) {
                [self dismissViewControllerAnimated:YES completion:^(void) {
                    if (hasActiveSeal) {
                        [self moveToSealSharingMode];
                    }
                }];
            }];
        }
        else {
            vcToPresent = [UINewSealViewController viewControllerWithCreationCompletionBlock:^(BOOL isCancelled, NSString *newSealId) {
                [self dismissViewControllerAnimated:YES completion:^(void) {
                    if (!isCancelled && newSealId) {
                        [self moveToSealSharingMode];
                    }
                }];
            } andAutomaticallyMakeActive:YES];
        }
        
        // - present the proper modal dialog.
        [self presentViewController:vcToPresent animated:YES completion:nil];
    }
}

@end

/**************************************
 UISealAcceptViewController (internal)
 **************************************/
@implementation UISealAcceptViewController (internal)
/*
 *  Configure the view.
 */
-(void) commonConfiguration
{
    exchangeConfig            = nil;
    hasAppeared               = NO;
    scanner                   = nil;
    remoteSeal                = nil;
    lastGoodURL               = nil;
    inTransferErrorState      = NO;
    sealIdDisplay             = nil;
    tvSealDisplay             = nil;
    isRotating                = NO;
    sasvCurSignal             = nil;
    safaFailAlert             = nil;
    numTransferErrors         = 0;
    numRemoteFailures         = 0;
    inBackground              = NO;
    tmTransferPulse           = nil;
    hasProximityFailure       = NO;
    tiProximityFailureStarted = 0;
    lcTopControls             = nil;
    motionManager             = nil;
    lastGoodGyroUpdate        = 0;
    isInactive                = NO;
    lckGyro                   = nil;
    tmDelayedHintTimer        = nil;
    timerWasUpdated           = NO;
    
    self.title = NSLocalizedString(@"Accept Seal", nil);
}

/*
 *  Return a proper animation controller when the target is the other exchange view..
 */
-(id<UIChatSealNavItemAnimatedTransitioning>) navItemInController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC
{
    if (fromVC == self && [toVC isKindOfClass:[UISealShareViewController class]]) {
        return [[[UISealExchangeAnimationController alloc] init] autorelease];
    }
    return nil;
}

/*
 *  Turn scanning on/off.
 */
-(BOOL) setScanningIsEnabled:(BOOL) isEnabled withAnimation:(BOOL) animated andError:(NSError **) err
{
    if (isEnabled) {
        NSError *tmp = nil;
        if (![UIQRScanner isCameraAvailable]) {
            [CS_error fillError:&tmp withCode:CSErrorQRCaptureFailure andFailureReason:@"Camera is disabled."];
            [self qrScanner:nil didFailWithError:tmp];
            if (err) {
                *err = tmp;
            }
            return NO;
        }
        
        // - build a scanner if it doesn't yet exist.
        if (!scanner) {
            scanner          = [[UIQRScanner alloc] initWithFrame:vwScanningControls.bounds];
            scanner.delegate = self;
            [vwScanningControls addSubview:scanner];
            [vwScanningControls sendSubviewToBack:scanner];
            if (animated) {
                scanner.alpha = 0.0f;
            }
        }
        
        // - try to start the scanner.
        if (![scanner startScanningWithError:&tmp]) {
            [self stopGyroDetection];
            [self qrScanner:scanner didFailWithError:tmp];
            if (err) {
                *err = tmp;
            }
            return NO;
        }
        vwRadarOverlay.delegate = self;
        
        // - begin tracking gyro updates.
        [self startGyroDetection];
        
        // - and display it appropriately.
        if (animated) {
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                scanner.alpha = 1.0f;
            }];
        }
        else {
            scanner.alpha = 1.0f;
        }
    }
    else {
        // - the last thing to do is to completely discard the scanner so that
        //   we start fresh next time.
        void (^completionBlock)(BOOL) = ^(BOOL finished){
            [scanner setDelegate:nil];
            [scanner stopScanning];
            [scanner removeFromSuperview];
            [scanner release];
            scanner = nil;
            vwRadarOverlay.delegate = nil;
        };
        
        // - turn off the scanner and then discard it.
        if (animated) {
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                scanner.alpha = 0.0f;
            } completion:completionBlock];
        }
        else {
            scanner.alpha = 0.0f;
            completionBlock(YES);
        }
    }
    
    return YES;
}

/*
 *  Discard the seal transfer object.
 */
-(void) discardSealTransferAndPrepareForAnother:(BOOL) prepareForAnother
{
    if (prepareForAnother) {
        // - move the text over to the standard overview text
        [self shiftToTransferStatus:NO];
        
        // - make sure QR scanning is re-enabled.
        [scanner setQRInterpretationEnabled:YES];
        
        // - make sure the swap modes button is enabled again.
        [UISealExchangeController setSealTransferStateForViewController:self asEnabled:YES];
    }
    
    // - always re-enable the nav bar regardless of what happens.
    [UISealExchangeController setPreventReturnNavigationForViewController:self asEnabled:YES];    
    
    [tmTransferPulse invalidate];
    [tmTransferPulse release];
    tmTransferPulse = nil;
    
    remoteSeal.delegate = nil;
    [remoteSeal release];
    remoteSeal = nil;
}

/*
 *  Given a seal id, show its seal on the display.
 */
-(void) showImportedSealWithId:(NSString *) sealId andAnimation:(BOOL) animated
{
    if (sealId) {
        [self hideAcceptFailureViewWithAnimation:YES];
    }
    
    // - when we're asking to just show the same seal again, make sure its timer is updated.
    if (sealIdDisplay && [sealIdDisplay isEqualToString:sealId]) {
        [tvSealDisplay restartTimer];
        return;
    }
    
    // - always discard the current seal.
    if (tvSealDisplay) {
        if (animated) {
            UIView *vwOldDisplay = tvSealDisplay;
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                vwOldDisplay.alpha = 0.0f;
            }completion:^(BOOL finished) {
                [vwOldDisplay removeFromSuperview];
                if ([self isSatisfiedFirstTimeUser]) {
                    [self doModalDone];
                }
            }];
        }
        else {
            [tvSealDisplay removeFromSuperview];
        }
        [tvSealDisplay haltTimerAndForceCompletion:NO];
        [tvSealDisplay release];
        tvSealDisplay = nil;
        
        [sealIdDisplay release];
        sealIdDisplay = nil;
    }
    
    // - if we're going to show a different seal, create and show it now.
    if (sealId) {
        CGRect rcTarget                 = [vwRadarOverlay scanningTargetRegion];
        UINewSealCell *nscSealDisplay   = [[[ChatSeal sealCellForId:sealId andHeight:CGRectGetHeight(rcTarget)] retain] autorelease];
        nscSealDisplay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        if (!nscSealDisplay) {
            return;
        }
        tvSealDisplay = [[UITimerView alloc] initWithFrame:rcTarget];
        [tvSealDisplay addSubview:nscSealDisplay];
        
        tvSealDisplay.alpha            = 0.0f;
        [nscSealDisplay setLocked:YES];
        [nscSealDisplay setCenterRingVisible:NO];
        [vwScanningControls addSubview:tvSealDisplay];
        [vwScanningControls bringSubviewToFront:tvSealDisplay];
        if (animated) {
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                tvSealDisplay.alpha = 1.0f;
            }];
        }
        else {
            tvSealDisplay.alpha = 1.0f;
        }
        
        sealIdDisplay = [sealId retain];
        [tvSealDisplay setTimeout:UISAV_SEAL_DISPLAY_TIME withCompletion:^(void) {
            [self showImportedSealWithId:nil andAnimation:YES];
        }];
        [tvSealDisplay restartTimer];
    }
}

/*
 *  Display the accept failure view, which is displayed when network issues prevent transfer.
 */
-(void) showAcceptFailureViewAsConnectionProblem:(BOOL) isConnectionIssue
{
    // - make sure there isn't a seal being displayed.
    [self showImportedSealWithId:nil andAnimation:YES];
    
    // - if we're already showing one, see if it is the same style and just refresh it.
    if (safaFailAlert && safaFailAlert.isConnectionFailureDisplay == isConnectionIssue) {
        [safaFailAlert restartTimer];
        return;
    }
    
    // - always start by destroying the existing one if we're shifting over.
    [self hideAcceptFailureViewWithAnimation:YES];
    
    // - now create a new one
    CGRect rcTarget     = [vwRadarOverlay scanningTargetRegion];
    safaFailAlert       = [[UISealAcceptFailureAlertView alloc] initWithFrame:rcTarget andAsConnectionFailure:isConnectionIssue];
    safaFailAlert.alpha = 0.0f;
    [vwScanningControls addSubview:safaFailAlert];
    [vwScanningControls bringSubviewToFront:safaFailAlert];
    [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
        safaFailAlert.alpha = 1.0f;
    }];
    [safaFailAlert setTimeout:isConnectionIssue ? UISAV_CONN_ERR_DISPLAY_TIME : UISAV_CONN_FAIL_DISPLAY_TIME withCompletion:^(void) {
        [self hideAcceptFailureViewWithAnimation:YES];
    }];
    [safaFailAlert restartTimer];
}

/*
 *  Hide the accept failure view.
 */
-(void) hideAcceptFailureViewWithAnimation:(BOOL) animated
{
    if (safaFailAlert) {
        if (animated) {
            UIView *vwTmp = safaFailAlert;
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                vwTmp.alpha = 0.0f;
            }completion:^(BOOL finished) {
                [vwTmp removeFromSuperview];
            }];
        }
        else {
            [safaFailAlert removeFromSuperview];
        }
        [safaFailAlert haltTimerAndForceCompletion:NO];
        [safaFailAlert release];
        safaFailAlert = nil;
    }
}

/*
 *  The app is about to be backgrounded.
 */
-(void) notifyWillEnterBackground:(NSNotification *) notification
{
    inBackground = YES;
}

/*
 *  When this view is backgrounded, we need to stop animation and hide any temporary decals so that
 *  the right behavior can be restored if we foreground again.
 */
-(void) notifyBackgrounded:(NSNotification *) notification
{
    // - I'm intentionally discarding the seal transfer when moving to the background
    //   because it should be a fast process as a rule and it only complicates things when we try to
    //   handle it in a backgrounded app.
    [self discardSealTransferAndPrepareForAnother:YES];

    // - turn of the scanner.
    [self fadeScanningBehaviorWithAnimation:NO];
}

/*
 *  We're about to enter the foreground.
 */
-(void) notifyWillEnterForeground
{
    if (![self presentedViewController]) {
        // - this is important because we want to wait until the AVFoundation library also processes the
        //   foreground notification and updates its state about which devices are Restricted from Settings.  Otherwise
        //   we end up getting called first and it causes this code to fail because the state isn't yet updated.
        [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
            [self beginAppearanceScanningWithAnimation:YES];
        }];
    }
}

/*
 *  When this view is foregrounded, make sure the radar is re-enabled.
 */
-(void) notifyForegrounded:(NSNotification *) notification
{
    inBackground = NO;
}

/*
 *  Returns whether we're doing this for the first time and got a seal.
 */
-(BOOL) isSatisfiedFirstTimeUser
{
    if (exchangeConfig.isFirstTime && [exchangeConfig.sealsAcceptedPerHost count]) {
        return YES;
    }
    return NO;
}

/*
 *  Move to/from transfer status.
 */
-(void) shiftToTransferStatus:(BOOL) toTransfer
{
    [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
        if (toTransfer) {
            lOverview.alpha = 0.0f;
        }
        else {
            lTransferOverview.alpha = 0.0f;
            lImporting.alpha        = 0.0f;
        }
    } completion:^(BOOL finished) {
        BOOL hideOverview = (toTransfer || !scanner || ![scanner isScanningAvailable]);
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            lTransferOverview.alpha = hideOverview ? 1.0f : 0.0f;
            lImporting.alpha        = 0.0f;
            lOverview.alpha         = hideOverview ? 0.0f : 1.0f;
        }];
    }];
}

/*
 *  Switch over to seal sharing.
 */
-(void) moveToSealSharingMode
{
    if (!exchangeConfig.sealIdentity) {
        NSError *err             = nil;
        ChatSealIdentity *ident = [ChatSeal activeIdentityWithError:&err];
        if (!ident) {
            NSLog(@"CS: Failed to retrieve an active seal identity.  %@", [err localizedDescription]);
            [AlertManager displayFatalAlertWithLowSpaceDetectionUsingTitle:NSLocalizedString(@"Unable to Share", nil)
                                                                   andText:NSLocalizedString(@"Your %@ is unable to access your default seal.", nil)];
            return;
        }
        exchangeConfig.sealIdentity = ident;
    }

    // - make sure that the gyro is stopped because the retain loop won't be broken.
    [self stopGyroDetection];
    
    // - show the seal share screen.
    UIViewController *vc = [UISealExchangeController sealShareViewControllerForConfiguration:exchangeConfig];
    [self.navigationController pushViewController:vc animated:YES];
}

/*
 *  Update the status text in the overview to reflect the number of accepted seals.
 */
-(void) updateSealAcceptedStatus
{
    // - don't change anything when there are no seals yet accepted.
    if (!exchangeConfig.newSealsAccepted) {
        return;
    }
    
    NSString *sNewOverview = nil;
    if (exchangeConfig.isFirstTime) {
        sNewOverview = NSLocalizedString(@"You can now chat privately.", nil);
    }
    else {
        if (exchangeConfig.newSealsAccepted == 1) {
            sNewOverview = NSLocalizedString(@"You have accepted a new seal.", nil);
        }
        else {
            NSString *sFmt = NSLocalizedString(@"You have accepted %u new seals.", nil);
            sNewOverview   = [NSString stringWithFormat:sFmt, exchangeConfig.newSealsAccepted];
        }
    }
    lOverview.text = sNewOverview;
}

/*
 *  Fade out the hint.
 */
-(void) fadeHintWithAnimation:(BOOL) animated
{
    if (sasvCurSignal) {
        UIView *vwTmp = sasvCurSignal;
        sasvCurSignal = nil;
        
        if (animated) {
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                vwTmp.alpha = 0.0f;
            } completion:^(BOOL finished) {
                [vwTmp removeFromSuperview];
                [vwTmp release];
            }];
        }
        else {
            [vwTmp removeFromSuperview];
            [vwTmp release];
        }
    }
}

/*
 *  Stop scanning for the moment.
 */
-(void) fadeScanningBehaviorWithAnimation:(BOOL) animated
{
    [self showImportedSealWithId:nil andAnimation:animated];
    [self hideAcceptFailureViewWithAnimation:animated];
    [self fadeHintWithAnimation:animated];
    [self setScanningIsEnabled:NO withAnimation:animated andError:nil];
    [vwRadarOverlay setScannerOverlayText:nil inColor:nil withAnimation:animated];
}

/*
 *  This method is called when the view appears to start scanning.
 */
-(void) beginAppearanceScanningWithAnimation:(BOOL) animated
{
    // - if we can start scanning, then a big part of this screen's behavior is possible.
    if ([self setScanningIsEnabled:YES withAnimation:animated andError:nil]) {
        // - when the view has fully appeared for the first time, show the
        //   overview text.
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            lOverview.alpha = 1.0f;
        } completion:nil];

        // - show the current connectivity hint.
        [self prepareForDelayedHintComputationWithShortDelay:YES];
    }
}

/*
 *  The device has become inactive after it has sat around for a while.
 */
-(void) gyroDeviceHasBecomeInactive
{
    [self fadeScanningBehaviorWithAnimation:YES];
}

/*
 *  The device has become active after a period of inactivity.
 */
-(void) gyroDeviceHasBecomeActive
{
    if (!inBackground) {
        if (![self presentedViewController]) {
            [self beginAppearanceScanningWithAnimation:YES];
        }
    }
}

/*
 *  Start detecting gyro updates so that we can shut down the camera after some period
 *  of inactivity.
 */
-(void) startGyroDetection
{
    // - this doesn't make sense on the simulator so we won't even bother there.
#if !TARGET_IPHONE_SIMULATOR
    if (!motionManager) {
        lckGyro                                   = [[NSRecursiveLock alloc] init];
        motionManager                             = [[CMMotionManager alloc] init];
        motionManager.gyroUpdateInterval          = 0.25f;          // we don't need much.
        opQGyroUpdate                             = [[NSOperationQueue alloc] init];
        opQGyroUpdate.maxConcurrentOperationCount = 1;
    }
    
    // - make sure that the gyro doesn't dismiss us right away when returning from the background.
    [self resetGyroDetectionTimeout];
    [motionManager startGyroUpdatesToQueue:opQGyroUpdate withHandler:^(CMGyroData *gyroData, NSError *error) {
        [self processGyroEventWithData:gyroData];
    }];
#endif
}

/*
 *  Stop detecting gyro updates.
 */
-(void) stopGyroDetection
{
    [motionManager stopGyroUpdates];
    [opQGyroUpdate cancelAllOperations];
}

/*
 *  Begin a new timeout period when the gyro is enabled.
 */
-(void) resetGyroDetectionTimeout
{
    // - NOTE: the lock is necessary because this data is shared between the main thread
    //         and the background operation queue.
    [lckGyro lock];
    lastGoodGyroUpdate = time(NULL);
    isInactive         = NO;
    [lckGyro unlock];
}

/*
 *  Handle a single gyro processing event.
 */
-(void) processGyroEventWithData:(CMGyroData *) gyroData
{
    // - NOTE: the lock is necessary because this event inside our custom operation queue just for this
    //         screen.
    [lckGyro lock];
    
    // - If the gyro is experiencing some movement, we'll assume this screen should stay active.
    if (!gyroData || gyroData.rotationRate.x > 1.0f || gyroData.rotationRate.y > 1.0f || gyroData.rotationRate.z > 1.0f) {
        // - were we inactive just a moment ago?
        if (isInactive) {
            [self performSelectorOnMainThread:@selector(gyroDeviceHasBecomeActive) withObject:nil waitUntilDone:NO];
        }
        [self resetGyroDetectionTimeout];
    }
    else {
        // - figure out if we've timed out.
        BOOL timedOut = NO;
        if (time(NULL) - lastGoodGyroUpdate > UISAV_INACTIVITY_TIMEOUT) {
            timedOut = YES;
        }
        
        // - did we just become inactive?
        if (isInactive != timedOut) {
            [self performSelectorOnMainThread:@selector(gyroDeviceHasBecomeInactive) withObject:nil waitUntilDone:NO];
        }
        
        // - save the new state.
        isInactive = timedOut;
    }
    
    [lckGyro unlock];
}

/*
 *  Manage the progress bar.
 */
-(void) setProgressVisible:(BOOL) isVisible withPercentage:(CGFloat) pct
{
    if (hasAppeared) {
        if (isVisible) {
            pvTransfer.hidden = NO;
            pvTransfer.alpha = 0.0f;
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                pvTransfer.alpha = 1.0f;
            }];
            [pvTransfer setProgress:(float) pct animated:YES];
        }
        else {
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                pvTransfer.alpha = 0.0f;
            } completion:^(BOOL finished) {
                pvTransfer.progress = (float) pct;
                pvTransfer.hidden   = YES;
            }];
        }
    }
    else {
        pvTransfer.hidden   = !isVisible;
        pvTransfer.progress = (float) pct;
        pvTransfer.alpha    = isVisible ? 1.0f : 0.0f;
    }
}

/*
 *  The base station has been updated.
 */
-(void) notifyBasestationUpdate
{
    // - update the current hint.
    [self prepareForDelayedHintComputationWithShortDelay:NO];
}

/*
 *  Discard the hint timer so that we don't fire it any longer.
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
    [self slideNewHintIfNecessary];
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
 *  Generate a transform for hiding/showing a particular frame.
 */
-(CGAffineTransform) slideTransformToHidden:(BOOL) isHidden forFrame:(CGRect) rc
{
    CGAffineTransform atShearRight = CGAffineTransformMake(1.0, 0.0, -0.5f, 1.0, 0.0, 0.0);
    CGAffineTransform atShearLeft  = CGAffineTransformMake(1.0, 0.0, 0.5f, 1.0, 0.0, 0.0);
    CGAffineTransform atRet        = CGAffineTransformIdentity;
    
    // - figure out the shear first.
    if (!isHidden && UIInterfaceOrientationIsLandscape(self.backwardsCompatibleInterfaceOrientation)) {
        atRet = atShearLeft;
    }
    else {
        atRet = atShearRight;
    }
    
    // - now determine where we're going.
    CGFloat rcWidth = CGRectGetWidth(rc);
    if (isHidden || UIInterfaceOrientationIsLandscape(self.backwardsCompatibleInterfaceOrientation)) {
        // - off to or in from the left.
        atRet = CGAffineTransformTranslate(atRet, -(rcWidth * 2.0f), 0.0f);
    }
    else {
        // - in from the right if we're in portrait.
        atRet = CGAffineTransformTranslate(atRet, (CGRectGetWidth(vwScanningControls.bounds) - rcWidth) + (rcWidth * 2.0f), 0.0f);
    }
    
    return atRet;
}

/*
 *  Display a new hint for the user if necessary.
 */
-(void) slideNewHintIfNecessary
{
    // - generate a new signal view first.
    UISealAcceptSignalView *sasv = [[[UISealAcceptSignalView alloc] initWithFrame:[vwRadarOverlay activeSignalTargetRegion]] autorelease];
    
    BOOL showNew = NO;
    BOOL hideOld = NO;
    
    // - see if there are new changes to be made.
    if ((!sasvCurSignal || ![sasvCurSignal isEqualToSignal:sasv]) && [scanner isScanningAvailable]) {
        showNew = YES;
    }

    // - now figure out if we need to hide the old one.
    if (showNew || isRotating || remoteSeal) {
        hideOld = YES;
    }
    
    // - nothing to do, then just return
    if (!showNew && !hideOld) {
        return;
    }
    
    NSTimeInterval animTime = [ChatSeal standardHintSlideTime] * 2.0f;

    // - first hide the old
    if (isRotating) {
        // - rotating, just remove the current one.
        [sasvCurSignal removeFromSuperview];
        [sasvCurSignal release];
        sasvCurSignal = nil;
    }
    else {
        UISealAcceptSignalView *sasvTmp = sasvCurSignal;
        sasvCurSignal                   = nil;
        CGAffineTransform at = [self slideTransformToHidden:YES forFrame:sasvTmp.frame];
        [UIView animateWithDuration:animTime animations:^(void) {
            sasvTmp.transform = at;
        }completion:^(BOOL finished) {
            [sasvTmp removeFromSuperview];
            [sasvTmp release];
        }];
    }
    
    // - nothing to show, that is fine.
    if (!showNew) {
        return;
    }
    
    // - now show the new
    sasvCurSignal = [sasv retain];
    [vwScanningControls addSubview:sasvCurSignal];
    sasvCurSignal.transform = [self slideTransformToHidden:NO forFrame:sasvCurSignal.frame];
    [UIView animateWithDuration:animTime animations:^(void) {
        sasvCurSignal.transform = CGAffineTransformIdentity;
    }];
}

/*
 *  The user's default dynamic type size was changed.
 */
-(void) updateDynamicTypeNotificationReceived
{
    [self reconfigureLabelsForDynamicTypeDuringInit:NO];
}

/*
 *  Reconfigure the labels in this view to respect dynamic type.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL) isInit
{
    // - not supported under iOS7.
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        return;
    }
    
    // - when initializing, we want the labels to be multi-line so
    //   that we can fit the larger strings.
    if (isInit) {
        self.lOverview.numberOfLines         = 0;
        self.lTransferOverview.numberOfLines = 0;
        self.lImporting.numberOfLines        = 0;
    }
    
    // - assign the label fonts.
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lOverview withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lTransferOverview withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lImporting withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
    
    // - and the radar
    [vwRadarOverlay reconfigureDynamicTypeForInit:isInit];

    // - NOTE: the signal doesn't need to be regenerated because it will
    //         regenerate itself when the networking comes back online.
    
    // - and the failure overlay.
    
}

/*
 *  Update preferred text widths
 */
-(BOOL) updatePreferredWidths
{
    BOOL wasUpdated        = NO;
    CGFloat preferredWidth = CGRectGetWidth(self.lOverview.frame);
    if ((int) preferredWidth != (int) self.lOverview.preferredMaxLayoutWidth) {
        self.lOverview.preferredMaxLayoutWidth = preferredWidth;
        [self.lOverview invalidateIntrinsicContentSize];
        wasUpdated = YES;
    }
    
    preferredWidth = CGRectGetWidth(self.lTransferOverview.frame);
    if ((int) preferredWidth != (int) self.lTransferOverview.preferredMaxLayoutWidth) {
        self.lTransferOverview.preferredMaxLayoutWidth = preferredWidth;
        [self.lTransferOverview invalidateIntrinsicContentSize];
        wasUpdated = YES;
    }

    preferredWidth = CGRectGetWidth(self.lImporting.frame);
    if ((int) preferredWidth != (int) self.lImporting.preferredMaxLayoutWidth) {
        self.lImporting.preferredMaxLayoutWidth = preferredWidth;
        [self.lImporting invalidateIntrinsicContentSize];
        wasUpdated = YES;
    }
    
    return wasUpdated;
}
@end

/*************************************
 UISealAcceptViewController (scanner)
 *************************************/
@implementation UISealAcceptViewController (scanner)
/*
 *  Scanning has started.
 */
-(void) qrScannerDidStart:(UIQRScanner *)scanner
{
    [self shiftToTransferStatus:NO];
}

/*
 *  Scanning produced a new code.
 */
-(void) qrScanner:(UIQRScanner *)inputScanner didScanCode:(NSString *)content
{
    // - ignore scan results when we haven't yet appeared.
    if (!hasAppeared) {
        return;
    }
    
    // - ignore scan results when we're moving to the background
    if (inBackground) {
        return;
    }
    
    // - ignore scan results when there is a seal incoming
    if (remoteSeal) {
        return;
    }
    
    // - the objective here is to do a minimum amount of work per-code that is received.
    NSURL *uContent = [NSURL URLWithString:content];
    if (![[ChatSeal applicationBaseStation] isValidSecureTransferURL:uContent]) {
        [vwRadarOverlay setTimedColorState:[ChatSeal defaultAppFailureColor] asPulsed:NO];
        return;
    }
    
    // - the URL can only be used once successfully and once we begin we don't want to race
    //   with the other device if it doesn't update its display quickly enough.
    if ([uContent isEqual:lastGoodURL]) {
        if (inTransferErrorState) {
            [self showAcceptFailureViewAsConnectionProblem:NO];
        }
        return;
    }
    
    // - always reset the transfer error state when we have a new URL.
    inTransferErrorState = NO;
    numRemoteFailures    = 0;
    
    // - see if we already scanned from this service, which we can check as long as they remain
    //   on their sharing screen.
    NSString *host = uContent.host;
    if (host) {
        NSString *sealId = [exchangeConfig.sealsAcceptedPerHost objectForKey:host];
        if (sealId) {
            [self showImportedSealWithId:sealId andAnimation:YES];
            return;             
        }
    }
    
    // - stop scanning if this is our first time and we got a seal.
    if ([self isSatisfiedFirstTimeUser]) {
        return;
    }
    
    // - determine if we can expect the connection to succeed, which may not happen if
    //   we have wireless problems
    if (![[ChatSeal applicationBaseStation] hasProximityDataForConnectionToURL:uContent]) {
        // - only show the proximity failure after we give it a little time because the
        //   service could be coming online as we speak.
        NSTimeInterval tiNewReference = [[NSDate date] timeIntervalSince1970];
        if (hasProximityFailure) {
            if (tiNewReference - tiProximityFailureStarted > UISAV_PROX_FAIL_TIMEOUT) {
                [self showAcceptFailureViewAsConnectionProblem:YES];
            }
        }
        else {
            hasProximityFailure       = YES;
            tiProximityFailureStarted = tiNewReference;
        }
        return;
    }
    
    // - no proximity failure, so turn off the timer.
    hasProximityFailure       = NO;
    tiProximityFailureStarted = 0;
    
    // - now we are pretty sure that things can proceed so start the processing.
    remoteSeal = [[[ChatSeal applicationBaseStation] connectForSecureSealTransferWithURL:uContent andError:nil] retain];
    if (!remoteSeal) {
        numTransferErrors++;
        if (numTransferErrors > UISAV_NUM_XFER_ERR_TO_DISPLAY) {
            [self showAcceptFailureViewAsConnectionProblem:NO];
        }
        return;
    }
    
    remoteSeal.delegate = self;
    NSError *err = nil;
    if (![remoteSeal beginSecureImportProcessing:&err]) {
        NSLog(@"CS: Unable to securely connect to the remote identity service.  %@", [err localizedDescription]);
        [remoteSeal release];
        remoteSeal = nil;
        numTransferErrors++;
        if (numTransferErrors > UISAV_NUM_XFER_ERR_TO_DISPLAY) {
            [self showAcceptFailureViewAsConnectionProblem:NO];
        }
        return;
    }
    
    // - turn off QR scanning for now because we're going to be busy, and this
    //   tends to bog down the older device.
    [scanner setQRInterpretationEnabled:NO];
    
    // - disable the swap modes button now to prevent accidents.
    [UISealExchangeController setSealTransferStateForViewController:self asEnabled:NO];
    
    // - the transfer looks like it will proceed, make sure there is nothing being shown any longer and get down
    //   to business.
    tmTransferPulse   = [[NSTimer timerWithTimeInterval:UISAV_TRANSFER_PULSE_PERIOD target:self selector:@selector(transferPulseTimer:) userInfo:nil repeats:YES] retain];
    [[NSRunLoop mainRunLoop] addTimer:tmTransferPulse forMode:NSRunLoopCommonModes];
    [self transferPulseTimer:nil];
    numTransferErrors = 0;
    [self hideAcceptFailureViewWithAnimation:YES];
    [self showImportedSealWithId:nil andAnimation:YES];
    [lastGoodURL release];
    lastGoodURL = [uContent retain];
    [self shiftToTransferStatus:YES];
    [self fadeHintWithAnimation:YES];    
}

/*
 *  Scanning has failed.
 */
-(void) qrScanner:(UIQRScanner *)qrs didFailWithError:(NSError *)err
{
    NSLog(@"CS: The seal scanner has failed to start.  %@", [err localizedDescription]);
    NSString *sText = nil;
    if (!scanner || [scanner isScanningRestricted]) {
        sText = NSLocalizedString(@"Check your camera Restrictions in Settings.", nil);
    }
    else {
        sText = [AlertManager standardErrorTextWithText:NSLocalizedString(@"Your camera is not working correctly.", nil)];
    }
    
    [vwRadarOverlay setScannerOverlayText:sText inColor:[UIColor lightGrayColor] withAnimation:hasAppeared];
    [self setScanningIsEnabled:NO withAnimation:hasAppeared andError:nil];
}
@end

/***********************************
 UISealAcceptViewController (remote)
 ***********************************/
@implementation UISealAcceptViewController (remote)
/*
 *  Seal transfer has failed.
 */
-(void) remoteIdentityTransferFailed:(ChatSealRemoteIdentity *)identity withError:(NSError *)err
{
    NSLog(@"CS: Remote seal transfer failure.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    [self discardSealTransferAndPrepareForAnother:YES];
    [self setProgressVisible:NO withPercentage:0.0f];
    
    // - let the person know that something odd happened, but only display an error if the problem keeps occurring.
    [vwRadarOverlay setTimedColorState:[ChatSeal defaultWarningColor] asPulsed:NO];
    numRemoteFailures++;
    if (numRemoteFailures > UISAV_NUM_REM_FAIL_TO_DISPLAY) {
        // - once we display this failure, we need to avoid this server
        //   and allow the failure to be shown.
        inTransferErrorState = YES;
        [self showAcceptFailureViewAsConnectionProblem:NO];
    }
    else {
        // - allow the URL to be reused because we didn't succeed with this
        //   server under the maximum limit of failures.
        [lastGoodURL release];
        lastGoodURL = nil;
    }
    
    // - show the hint again.
    [self prepareForDelayedHintComputationWithShortDelay:YES];
}

/*
 * Update the display to show transfer progress.
 */
-(void) remoteIdentityTransferProgress:(ChatSealRemoteIdentity *)identity withPercentageDone:(NSNumber *)pctComplete
{
    // - because import actually take a few moments, we're going to modify the % complete to be a fraction of the total
    //   to allow the final import to show some status.
    CGFloat pct = pctComplete.floatValue;
    pct = pct * 0.9f;
    [self setProgressVisible:YES withPercentage:pct];
}

/*
 *  Update the display when import begins.
 */
-(void) remoteIdentityBeginningImport:(ChatSealRemoteIdentity *)identity
{
    [UISealExchangeController setPreventReturnNavigationForViewController:self asEnabled:NO];
    [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
        lTransferOverview.alpha = 0.0f;
    } completion:^(BOOL finished) {
        if (remoteSeal) {
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                lImporting.alpha = 1.0f;
            }];
        }
    }];
}

/*
 *  Update the scanned list for the given identity and seal.
 */
-(void) updateAcceptedSealsForRemoteIdentity:(ChatSealRemoteIdentity *) identity andSealId:(NSString *) sealId
{
    NSString *host = nil;
    host           = identity.secureURL.host;
    if (host && sealId) {
        [exchangeConfig.sealsAcceptedPerHost setObject:sealId forKey:host];
    }
    numRemoteFailures = 0;
    
    // - if this is the first time, we're going to convert over to a 'Done' button
    if (exchangeConfig.isFirstTime) {
        [UISealExchangeController reconfigureExchangeTargetDisplay:self asScanner:YES andAssumeMultiUse:YES];
    }
    
    // - update the text in the overview to show the number of scanned seals since they know how this view works now.
    [self updateSealAcceptedStatus];
}

/*
 *  We successfully transferred the seal.
 */
-(void) remoteIdentityTransferCompletedSuccessfully:(ChatSealRemoteIdentity *)identity withSealId:(NSString *)sealId
{
    [self setProgressVisible:NO withPercentage:0.0f];
    exchangeConfig.newSealsAccepted++;
    [self updateAcceptedSealsForRemoteIdentity:identity andSealId:sealId];
    [self discardSealTransferAndPrepareForAnother:YES];
    [self showImportedSealWithId:sealId andAnimation:YES];
    [self prepareForDelayedHintComputationWithShortDelay:YES];
}

/*
 *  The remote identity was imported, but it already exists.
 *  - this state is allowed because it serves a purpose of updating an existing seal when it occurs.
 */
-(void) remoteIdentityTransferCompletedWithDuplicateSeal:(ChatSealRemoteIdentity *)identity withSealId:(NSString *)sealId
{
    [self setProgressVisible:NO withPercentage:0.0f];
    [self updateAcceptedSealsForRemoteIdentity:identity andSealId:sealId];
    [self discardSealTransferAndPrepareForAnother:YES];
    [self showImportedSealWithId:sealId andAnimation:YES];
    [self prepareForDelayedHintComputationWithShortDelay:YES];
}

/*
 *  The purpose of this timer is to give some indication that transfers are occurring.
 */
-(void) transferPulseTimer:(NSTimer *) timer
{
    [vwRadarOverlay setTimedColorState:[UIColor colorWithWhite:0.8f alpha:1.0f] asPulsed:YES];
}
@end

/**************************************
 UISealAcceptViewController (radarView)
 **************************************/
@implementation UISealAcceptViewController (radarView)
/*
 *  When the radar updates its targets, make sure the
 *  local views are coordinated.
 */
-(void) radarTargetsWereUpdated:(UISealAcceptRadarView *)radarView
{
    CGRect rcScanTarget = radarView.scanningTargetRegion;
    tvSealDisplay.frame = rcScanTarget;
    sasvCurSignal.frame = radarView.activeSignalTargetRegion;
    safaFailAlert.frame = rcScanTarget;
}
@end
