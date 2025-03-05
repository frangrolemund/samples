//
//  UISealShareViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/17/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealShareViewController.h"
#import "UIChatSealNavigationController.h"
#import "UISealExchangeAnimationController.h"
#import "UISealAcceptViewController.h"
#import "ChatSealQREncode.h"
#import "ChatSeal.h"
#import "ChatSealBaseStation.h"
#import "AlertManager.h"
#import "ChatSealFeedCollector.h"
#import "UIDynamicTypeCompliantEntity.h"
#import "UIAdvancedSelfSizingTools.h"

// - constants
static const NSUInteger UISSV_ABORT_WARN = 5;
static const NSUInteger UISSV_FAIL_WARN  = 5;
static const CGFloat    UISSV_STD_PAD    = 20.0f;

// - forward declarations
@interface UISealShareViewController (internal) <UIChatSealCustomNavTransitionDelegate, UIAlertViewDelegate, UIDynamicTypeCompliantEntity>
-(void) commonConfiguration;
-(void) setQRCodeIsVisible:(BOOL) isVisible withAnimation:(BOOL) animated;
-(void) notifyDidChangeURL;
-(void) notifyTransferStatus:(NSNotification *) notification;
-(void) recomputeScanningText;
-(void) notifyNetworkOrUserChange:(NSNotification *) notification;
-(void) updateFeedPermissionFlag;
-(void) completeViewAppearanceWithCodeOrWarning;
-(void) showQRCodeForScanningWithAnimation;
-(void) reconfigureLabelsForDynamicTypeAsInit:(BOOL) isInit;
-(BOOL) updatePreferredWidths;
@end

// - shared declarations
@interface UISealExchangeController (shared)
+(UIViewController *) sealAcceptViewControllerForConfiguration:(UISealExchangeConfiguration *) config;
+(void) prepareForExchangeTargetDisplay:(UIViewController<UISealExchangeFlipTarget> *) vc asScanner:(BOOL) isScanning andAssumeMultiUse:(BOOL) multiUse;
+(void) completeExchangeNavigationAfterDidAppearForController:(UIViewController<UISealExchangeFlipTarget> *) vc;
+(void) setSealTransferStateForViewController:(UIViewController<UISealExchangeFlipTarget> *) vc asEnabled:(BOOL) isEnabled;
@end

/*****************************
 UISealShareViewController
 *****************************/
@implementation UISealShareViewController
/*
 *  Object attributes.
 */
{
    UISealExchangeConfiguration *exchangeConfig;
    BOOL                        hasAppeared;
    BOOL                        isQRCodeVisible;
    BOOL                        wasANewSeal;
    NSUInteger                  numAborts;
    NSUInteger                  numFailures;
    BOOL                        shouldAskFeedPermission;
}
@synthesize vwTopLayoutContainer;
@synthesize lcTopContraint;
@synthesize ssqSealContainer;
@synthesize vwScanningShade;
@synthesize lScanningInstructions;
@synthesize qrQRDisplay;
@synthesize sstStatusView;
@synthesize lFirstTimeInstructions;
@synthesize lcSealWidth;

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
    
    [vwTopLayoutContainer release];
    vwTopLayoutContainer = nil;
    
    [lcTopContraint release];
    lcTopContraint = nil;
    
    [ssqSealContainer release];
    ssqSealContainer = nil;
    
    [vwScanningShade release];
    vwScanningShade = nil;
    
    [lScanningInstructions release];
    lScanningInstructions = nil;
    
    [qrQRDisplay release];
    qrQRDisplay = nil;
    
    [sstStatusView release];
    sstStatusView = nil;
    
    [lFirstTimeInstructions release];
    lFirstTimeInstructions = nil;
    
    [exchangeConfig release];
    exchangeConfig = nil;
    
    [lcSealWidth release];
    lcSealWidth = nil;
    
    [super dealloc];
}

/*
 *  View is loaded
 */
-(void) viewDidLoad
{
    [super viewDidLoad];
    
    // - the top layout constraint (mine) is something that was useful in 7.1 to ensure proper animation
    //   when flipping between share and accept, but is not as useful under 8.0.
    if ([ChatSeal isIOSVersionGREQUAL8]) {
        [self.view removeConstraint:lcTopContraint];
        self.lcTopContraint = nil;
        
        // - use the top layout guide in 8.0.
        NSLayoutConstraint *lc = [NSLayoutConstraint constraintWithItem:self.vwTopLayoutContainer attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.topLayoutGuide attribute:NSLayoutAttributeBottom multiplier:1.0f constant:0.0f];
        [self.view addConstraint:lc];
    }
    
    // - begin by sizing the seal so that it looks great on all devices.
    lcSealWidth.constant = (CGFloat) floor([ChatSeal portraitWidth] - (UISSV_STD_PAD * 2.0f));
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    
    // - do some common configuration for this target.
    [UISealExchangeController prepareForExchangeTargetDisplay:self asScanner:NO andAssumeMultiUse:YES];
    
    // - initially set the background colors.
    vwScanningShade.backgroundColor = [ChatSeal defaultLowChromeDarkShadowColor];
    vwScanningShade.alpha           = 0.0f;
    
    [sstStatusView setTransferStatus:nil withAnimation:NO];
    
    lScanningInstructions.text       = nil;
    [ChatSeal defaultLowChromeShadowTextLabelConfiguration:lScanningInstructions];
    lScanningInstructions.alpha     = 0.0f;
    
    // - wire up the seal display.
    [ssqSealContainer setIdentity:exchangeConfig.sealIdentity];
    
    // - make sure nothing is visible yet.
    [self setQRCodeIsVisible:NO withAnimation:NO];
    
    // - the first time instructions fill that region at the top and balance the overall design, I think.
    [self recomputeScanningText];
    lFirstTimeInstructions.text      = lScanningInstructions.text;
    lFirstTimeInstructions.textColor = [UIColor darkGrayColor];
    
    // - update the fonts in the labels as necessary.
    [self reconfigureLabelsForDynamicTypeAsInit:YES];
    
    // - in iOS7, we need to update the preferred widths up front or this won't look good in landscape
    //   iniitally
    if ([ChatSeal isIOSVersionBEFORE8]) {
        [self updatePreferredWidths];
    }
}

/*
 *  The view has appeared.
 */
-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // - in order to make this look like it is just a single view that is being swapped, we're
    //   going to actually modify the view controller stack at this point.
    [UISealExchangeController completeExchangeNavigationAfterDidAppearForController:self];
 
    // - wire up the notifications we use to track sharing progress.
    if (!hasAppeared) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyDidChangeURL) name:kChatSealNotifySecureURLHasChanged object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyTransferStatus:) name:kChatSealNotifySealTransferStatus object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyNetworkOrUserChange:) name:kChatSealNotifyNearbyUserChange object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyNetworkOrUserChange:) name:kChatSealNotifyNetworkChange object:nil];
    }
    
    // - promote the seal.
    NSError *err = nil;
    if (![[ChatSeal applicationBaseStation] setPromotedSeal:exchangeConfig.sealIdentity.sealId withError:&err]) {
        NSLog(@"CS: Failed to promote the active seal.  %@", [err localizedDescription]);
    }
    
    // - do the final tasks necessary to show the QR code.
    [self completeViewAppearanceWithCodeOrWarning];
}

/*
 *  Layout has occurred.
 */
-(void) viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    // - and the preferred text widths
    if ([self updatePreferredWidths]) {
        // - force autolayout to be executed again when we change constraints.
        [self.view layoutSubviews];
    }
}

/*
 *  Update the constraints on the view.
 */
-(void) updateViewConstraints
{
    [super updateViewConstraints];
    
    // - always update the top margin.
    // - we aren't using a layout guide here because like the accept view, there is a problem with that
    //   and custom transitions at the moment.  We'll just create our own.
    lcTopContraint.constant = CGRectGetMaxY(self.navigationController.navigationBar.frame);
}

/*
 *  The view has disappeared.
 */
-(void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // - hide the QR code
    [self setQRCodeIsVisible:NO withAnimation:NO];
    
    // - silence the beacon for the current seal.
    NSError *err = nil;
    if (![[ChatSeal applicationBaseStation] setPromotedSeal:nil withError:&err]) {
        NSLog(@"CS: The promotion state for the active seal could not be disabled completely.   %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    }
}

/*
 *  A rotation is about to occur.
 */
-(void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    // - make sure the top layout is adjusted.
    [self.view setNeedsUpdateConstraints];
}

/*
 *  Creator configuration for this view.
 */
-(void) setConfiguration:(UISealExchangeConfiguration *)config
{
    if (exchangeConfig != config) {
        [exchangeConfig release];
        exchangeConfig = [config retain];
        wasANewSeal    = (exchangeConfig.sealIdentity.sealGivenCount ? NO : YES);
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
 *  When operating modally, dismiss this view.
 */
-(void) doModalDone
{
    if (exchangeConfig.completionBlock) {
        exchangeConfig.completionBlock(exchangeConfig.sealsShared > 0 ? YES : NO);
    }
    else {
        [self dismissViewControllerAnimated:YES completion:nil];        
    }
}

/*
 *  Swap to the accept screen.
 */
-(void) doSwapModes
{
    UIViewController *vc = [UISealExchangeController sealAcceptViewControllerForConfiguration:exchangeConfig];
    [self.navigationController pushViewController:vc animated:YES];
}
@end


/*************************************
 UISealShareViewController (internal)
 *************************************/
@implementation UISealShareViewController (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    exchangeConfig          = nil;
    hasAppeared             = NO;
    isQRCodeVisible         = NO;
    wasANewSeal             = NO;
    numAborts               = 0;
    numFailures             = 0;
    [self updateFeedPermissionFlag];
    
    // - set the title
    self.title = NSLocalizedString(@"Share My Seal", nil);
}

/*
 *  Return a proper animation controller when the target is the other exchange view..
 */
-(id<UIChatSealNavItemAnimatedTransitioning>) navItemInController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC
{
    if (fromVC == self && [toVC isKindOfClass:[UISealAcceptViewController class]]) {
        return [[[UISealExchangeAnimationController alloc] init] autorelease];
    }
    return nil;
}

/*
 *  Show/hide the QR code.
 */
-(void) setQRCodeIsVisible:(BOOL) isVisible withAnimation:(BOOL) animated
{
    if (isVisible) {
        [self recomputeScanningText];
    }
    
    isQRCodeVisible = isVisible;
    
    CGFloat visibleAlpha = isVisible ? 1.0f : 0.0f;
    
    if (animated) {
        // - rotate the seal to start/end the process.
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] delay:isVisible ? 0.0f : [UISealShareQRView timeUntilFadeBeginsForMakingVisible:NO]
                            options:0 animations:^(void) {
                                [ssqSealContainer setLocked:!isVisible];
                            }completion:nil];
        
        // - fade the shade and scanning instructions in/out.
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] delay:isVisible ? [ChatSeal standardItemFadeTime] : 0.0f options:0 animations:^(void) {
            vwScanningShade.alpha        = visibleAlpha;
            lScanningInstructions.alpha  = visibleAlpha;
            sstStatusView.alpha          = 1.0f - visibleAlpha;
            lFirstTimeInstructions.alpha = 0.0f;
        }completion:^(BOOL finished) {
            if (isVisible) {
                // - when the QR code is fully visible, clear out the
                //   temporary transfer status text that was there before.
                [sstStatusView setTransferStatus:nil withAnimation:NO];
            }
        }];
    }
    else {
        [ssqSealContainer setLocked:!isVisible];
        vwScanningShade.alpha        = visibleAlpha;
        lScanningInstructions.alpha  = visibleAlpha;
        sstStatusView.alpha          = 1.0f - visibleAlpha;
        if (isVisible) {
            [sstStatusView setTransferStatus:nil withAnimation:NO];
        }
    }
    
    // - manage the QR display separately.
    [qrQRDisplay setQRCodeVisible:isVisible withAnimation:animated];
}

/*
 *  The secure URL has been modified, so our QR code must change also.
 */
-(void) notifyDidChangeURL
{
    // - if the QR code is currently visible, we need to force its regeneration.
    if (isQRCodeVisible) {
        [qrQRDisplay regenerateQRCode];
    }
}

/*
 *  Do the final cleanup after seal transfer.
 */
-(void) sealTransferIsFinalized
{
    [self setQRCodeIsVisible:YES withAnimation:YES];
}

/*
 *  Manage the process that occurs when the new user
 */
-(void) sealTransferHasCompletedWithNewUser:(BOOL) isNewUser
{
    numAborts   = 0;
    numFailures = 0;
    if (isNewUser) {
        exchangeConfig.sealsShared = exchangeConfig.sealsShared + 1;
    }
    [ChatSeal vibrateDeviceIfPossible];
    [self sealTransferIsFinalized];
}

/*
 *  This method is issued to keep this view updated about ongoing transfers.
 */
-(void) notifyTransferStatus:(NSNotification *) notification
{
    NSNumber *nState = [notification.userInfo objectForKey:kChatSealNotifyKeyTransferState];
    if (!nState) {
        return;
    }
    
    NSError *err = nil;
    switch (nState.integerValue) {
        case CS_BSTS_STARTING:
            [sstStatusView setTransferStatus:NSLocalizedString(@"Preparing to share your seal.", nil) withAnimation:YES];
            [self setQRCodeIsVisible:NO withAnimation:YES];
            break;
            
        case CS_BSTS_SENDING_SEAL_PROGRESS:
            [sstStatusView setTransferStatus:NSLocalizedString(@"Securely sharing your seal.", nil) withAnimation:YES];
            break;
            
        case CS_BSTS_ERROR:
            err = [notification.userInfo objectForKey:kChatSealNotifyKeyTransferError];
            NSLog(@"CS: Seal transfer failure.  %@", err ? [err localizedDescription] : @"No error text returned.");
            [sstStatusView setTransferStatus:NSLocalizedString(@"Transfer failed.", nil) withAnimation:YES];
            numFailures++;
            if (numFailures > UISSV_FAIL_WARN) {
                NSString *sFmt  = NSLocalizedString(@"Your %@ is having trouble communicating with your friend's device.  Please verify you both have your wireless settings fully enabled.", nil);
                NSString *sText = [NSString stringWithFormat:sFmt, [UIDevice currentDevice].model];
                if (!shouldAskFeedPermission) {
                    [AlertManager displayErrorAlertWithTitle:NSLocalizedString(@"Seal Transfer Interrupted", nil) andText:sText andDelegate:self];
                }
                numFailures = 0;
            }
            else {
                [self sealTransferIsFinalized];
            }
            break;
            
        case CS_BSTS_ABORTED:
            [sstStatusView setTransferStatus:NSLocalizedString(@"Transfer failed.", nil) withAnimation:YES];
            numAborts++;
            if (numAborts >= UISSV_ABORT_WARN) {
                [[ChatSeal applicationBaseStation] setSealTransferPaused:YES];
                NSString *sFmt  = NSLocalizedString(@"Your %@ has prevented some possibly malicious attempts to access it.  You may want to share your seal at another time.", nil);
                NSString *sText = [NSString stringWithFormat:sFmt, [UIDevice currentDevice].model];
                if (!shouldAskFeedPermission) {
                    [AlertManager displayErrorAlertWithTitle:NSLocalizedString(@"Seal Transfer Interrupted", nil) andText:sText andDelegate:self];
                }
                numAborts = 0;
            }
            else {
                [self sealTransferIsFinalized];
            }
            break;
            
        case CS_BSTS_COMPLETED_NEWUSER:
            [sstStatusView setTransferStatus:NSLocalizedString(@"Completed.", nil) withAnimation:YES];
            [self sealTransferHasCompletedWithNewUser:YES];
            break;
            
        case CS_BSTS_COMPLETED_DUPLICATE:
            [sstStatusView setTransferStatus:NSLocalizedString(@"Completed.", nil) withAnimation:YES];
            [self sealTransferHasCompletedWithNewUser:NO];
            break;
    }
    
    // - manage the navigation buttons so that the person can't accidentally
    //   cancel the transfer.
    if (nState.integerValue == CS_BSTS_STARTING) {
        [UISealExchangeController setSealTransferStateForViewController:self asEnabled:NO];
    }
    else if (nState.integerValue != CS_BSTS_SENDING_SEAL_PROGRESS) {
        [UISealExchangeController setSealTransferStateForViewController:self asEnabled:YES];
    }
}

/*
 *  An alert is only shown in one special case with transfer failures/aborts.
 */
-(void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // - this is a generic network error.
    [[ChatSeal applicationBaseStation] setSealTransferPaused:NO];
    [self sealTransferIsFinalized];
}

/*
 *  Figure out the best kind of text to display for scanning purposes.
 */
-(void) recomputeScanningText
{
    // - when the text is currently on-screen, fade the change.
    if (isQRCodeVisible && lScanningInstructions.text) {
        UIView *vw = [lScanningInstructions.superview resizableSnapshotViewFromRect:lScanningInstructions.frame afterScreenUpdates:NO withCapInsets:UIEdgeInsetsZero];
        lScanningInstructions.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [lScanningInstructions addSubview:vw];
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            vw.alpha = 0.0f;
        }completion:^(BOOL finished) {
            [vw removeFromSuperview];
        }];
    }
    
    // - now figure out what the new text should include.
    // - the point of these instructions is to let the person know how their network is configured
    //   and help a first time user through this process.
    ps_bs_proximity_state_t curProx = [[ChatSeal applicationBaseStation] proximityWirelessState];
    BOOL isExperienced              = [ChatSeal hasTransferredASeal];
    NSUInteger numNear              = [[ChatSeal applicationBaseStation] newUserCount] + [[ChatSeal applicationBaseStation] vaultReadyUserCount];
    NSString *sText                 = nil;
    if (numNear) {
        if (isExperienced) {
            if (wasANewSeal && exchangeConfig.sealIdentity.sealGivenCount > 0) {
                sText = NSLocalizedString(@"Your messages will remain personal.", nil);
            }
            else {
                if (numNear == 1) {
                    sText = NSLocalizedString(@"Someone nearby can scan this seal.", nil);
                }
                else {
                    sText = NSLocalizedString(@"Others nearby can scan this seal.", nil);
                }
            }
        }
        else {
            sText = NSLocalizedString(@"Your friend must scan this seal.", nil);
        }
    }
    else {
        if (curProx == CS_BSCS_DISABLED) {
            sText = NSLocalizedString(@"Ensure your wireless settings are turned on.", nil);
        }
        else {
            sText = NSLocalizedString(@"Move near a friend to share this seal with them.", nil);
        }
    }
    lScanningInstructions.text = sText;
}

/*
 *  When either the network or nearby user count changes, we need
 *  to potentially update the scanning text.
 */
-(void) notifyNetworkOrUserChange:(NSNotification *) notification
{
    // - we'll recompute the text when first showing it, so only
    //   do this if it is currently visible.
    if (isQRCodeVisible) {
        [self recomputeScanningText];
    }
}

/*
 *  Update the flag used to track whether we need to ask for permission to share feeds.
 */
-(void) updateFeedPermissionFlag
{
    shouldAskFeedPermission = (![ChatSeal hasPresentedFeedShareWarning]) && [[ChatSeal applicationFeedCollector] isConfigured];
}

/*
 *  Perform the final tasks related to the view appearing.
 */
-(void) completeViewAppearanceWithCodeOrWarning
{
    // - the first time we display this share view we want to give the user a chance
    //   to disallow the transfer of feed names with the seal.
    if (shouldAskFeedPermission) {
        [ChatSeal displayFeedShareWarningIfNecessaryWithDescription:YES andCompletion:^(void) {
            shouldAskFeedPermission = NO;
            [self performSelector:@selector(showQRCodeForScanningWithAnimation) withObject:nil afterDelay:0.1f];
        }];
    }
    else {
        // - show the initial QR code.
        [self showQRCodeForScanningWithAnimation];
    }
    
    hasAppeared = YES;
}

/*
 *  Display the QR code.
 */
-(void) showQRCodeForScanningWithAnimation
{
    [self setQRCodeIsVisible:YES withAnimation:YES];
}

/*
 *  A dynamic type update has been received.
 */
-(void) updateDynamicTypeNotificationReceived
{
    [self reconfigureLabelsForDynamicTypeAsInit:NO];
    [sstStatusView updateDynamicTypeNotificationReceived];
}

/*
 *  Reconfigure the labels to use dynamic type fonts.
 */
-(void) reconfigureLabelsForDynamicTypeAsInit:(BOOL) isInit
{
    // - not supported in iOS7
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        return;
    }
    
    // - size the different labels.
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lFirstTimeInstructions withPreferredSettingsAndTextStyle:UIFontTextStyleBody andMinimumSize:1.0f duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lScanningInstructions withPreferredSettingsAndTextStyle:UIFontTextStyleBody andMinimumSize:1.0f duringInitialization:isInit];
}

/*
 *  Update preferred text widths
 */
-(BOOL) updatePreferredWidths
{
    // - I usually like to use the layout to drive the preferred width, but in iOS7 that doesn't
    //   suffice in lanscape mode since we don't get a chance initially to force that before content is displayed.
    //   Fortunately, I know that the left/right margins are the same in each of these and extend to the edges of the screen.
    CGFloat padWidth       = CGRectGetMinX(lScanningInstructions.frame);
    CGFloat preferredWidth = (CGFloat) floor(CGRectGetWidth(vwTopLayoutContainer.frame) - (padWidth * 2.0f));
    BOOL wasUpdated        = NO;
    if ((int) preferredWidth != (int) lScanningInstructions.preferredMaxLayoutWidth) {
        lScanningInstructions.preferredMaxLayoutWidth = preferredWidth;
        [lScanningInstructions invalidateIntrinsicContentSize];
        wasUpdated = YES;
    }
    if ((int) preferredWidth != (int) lFirstTimeInstructions.preferredMaxLayoutWidth) {
        lFirstTimeInstructions.preferredMaxLayoutWidth = preferredWidth;
        [lFirstTimeInstructions invalidateIntrinsicContentSize];
        wasUpdated = YES;
    }
    if ((int) preferredWidth != (int) sstStatusView.preferredMaxLayoutWidth) {
        sstStatusView.preferredMaxLayoutWidth = preferredWidth;
        [sstStatusView invalidateIntrinsicContentSize];
        wasUpdated = YES;
    }
    
    // - update the layout.
    if (wasUpdated) {
        [self.view setNeedsLayout];
    }
    
    return wasUpdated;
}
@end