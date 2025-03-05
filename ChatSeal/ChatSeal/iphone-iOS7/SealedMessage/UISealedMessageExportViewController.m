//
//  UISealedMessageExportViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/4/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UISealedMessageExportViewController.h"
#import "ChatSeal.h"
#import "UIChatSealNavigationController.h"
#import "UISealedMessageExportAnimationController.h"
#import "UIMessageDetailViewControllerV2.h"
#import "UIChatSealNavigationInteractiveTransition.h"
#import "ChatSealWeakOperation.h"
#import "UIFakeKeyboardV2.h"
#import "UISealedMessageDeliveryAnimationController.h"
#import "AlertManager.h"
#import "UIDynamicTypeCompliantEntity.h"
#import "UIAdvancedSelfSizingTools.h"

//  - constants
static const CGFloat UISMEV_STD_PAD_PCT  = 0.05f;
static const int     UISMEV_STD_FAKE_TAG = 1000;

typedef enum {
    UISMEV_GT_NONE      = 0,
    UISMEV_GT_PENDING,
    UISMEV_GT_SECURE,
    UISMEV_GT_ERR_SPACE,
    UISMEV_GT_ERR_OTH
} uismev_guidance_type_t;

//  - forward declarations
@interface UISealedMessageExportViewController (internal) <UIChatSealCustomNavTransitionDelegate, UIDynamicTypeCompliantEntity>
-(void) commonConfiguration;
-(void) setConfiguration:(UISealedMessageExportConfigData *) config;
-(NSString *) sealIdForExport;
-(void) regenerateAndConfigureEnvelopeForFinalState;
-(void) notifyPreviousOfKeyboardLocation;
-(void) assignCommonFrostedBackground;
-(void) updateFrostedImage;
-(CGFloat) navigationMaxY;
-(CGPoint) centerOfContent;
-(CGSize) maximumDimensionsForEnvelope;
-(void) sealGestureTapped:(UITapGestureRecognizer *) tgr;
-(void) checkForCompliantEnvelope;
-(void) doCancel;
-(void) setGenerationOperation:(NSOperation *) op;
-(void) beginMessageGenerationFromConfig;
-(void) discardNewSealedMessagePermanently;
-(void) messageCompletionWithReturn:(BOOL) retCode andError:(NSError *) err;
-(void) showGuidanceOfType:(uismev_guidance_type_t) gt;
-(void) notifyStorageIssueResolved;
-(void) removeFakeKeyboardCopy;
-(void) snapshotCurrentFakeKeyboardForReturn;
-(BOOL) postMessageOrDisplayError;
-(void) disablePostBecauseOfBadFeed;
-(void) notifyFeedsUpdated;
-(void) reconfigureDynamicTypeElementsDuringInit:(BOOL) isInit;
@end

//  - shared with the animation controller
@interface UISealedMessageExportViewController (shared)
-(void) setWorkingControlsToVisible:(BOOL) areVisible;
-(void) animateNavigationTransitionToThisView:(BOOL) toThisView withDuration:(NSTimeInterval) duration andCompletion:(void(^)(void)) completionBlock;
-(void) navigationTransitionWasCancelled;
-(void) navigationWasCompletedToViewController:(UIViewController *) vc;
-(void) animateDeliveryTransitionToDetail:(UIMessageDetailViewControllerV2 *) mdvc withDuration:(NSTimeInterval) duration andCompletion:(void(^)(void)) completionBlock;
@end

// - shared with the message view that opened this sub-view
@interface UIMessageDetailViewControllerV2 (shared)
-(void) completedExportAbortReturn;
-(void) recalibrateToolbarWithViewDimensions:(CGSize) viewDims;
-(void) updateKeyboardEffectImage;
-(void) prepareForMessageDeliveryWithDimensions:(CGSize) viewDims;
-(void) displayRecentlyDeliveredLastEntry;
-(CGPoint) envelopeOrigin;
+(void) configureProxyTextView:(UITextView *) tv withText:(NSString *) text;
@end

/***************************************
 UISealedMessageExportViewController
 ***************************************/
@implementation UISealedMessageExportViewController
/*
 *  Object attributes
 */
{
    UISealedMessageExportConfigData             *callerConfig;
    UISealedMessageEnvelopeViewV2               *envelope;
    UIInterfaceOrientation                      envelopeOrientation;
    UIInterfaceOrientation                      frostedOrientation;
    UITextView                                  *tvHidden;
    BOOL                                        isTransitioning;
    UIChatSealNavigationInteractiveTransition  *interactiveController;
    UIView                                      *vwContentColor;
    CGFloat                                     lastNavMaxY;
    UITapGestureRecognizer                      *tgrSeal;
    NSOperation                                 *opMsgGeneration;
    UIView                                      *vwFakeContainer;
    BOOL                                        useDeliveryTransitionAnimation;
    BOOL                                        failureToExport;
    BOOL                                        envelopeNotCompliantDueToFontChange;
}
@synthesize ivFrosted;
@synthesize vwFrostedContainer;
@synthesize vwContent;
@synthesize lcTopGuidance;
@synthesize bPostMessage;
@synthesize vwGuidance;
@synthesize lPreparing;
@synthesize aivProgress;
@synthesize lSecure;
@synthesize lErrSpace;
@synthesize lErrOther;
@synthesize vwExportActions;

/*
 *  Create an instance of the view controller for navigation pushing.
 */
+(UISealedMessageExportViewController *) instantateViewControllerWithConfiguration:(UISealedMessageExportConfigData *) config
{
    UISealedMessageExportViewController *vc = (UISealedMessageExportViewController *) [ChatSeal viewControllerForStoryboardId:@"UISealedMessageExportViewController"];
    [vc setConfiguration:config];
    return vc;
}

/*
 *  Initialize the object
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
    [self setGenerationOperation:nil];
    
    [tvHidden release];
    tvHidden = nil;
    
    [ivFrosted release];
    ivFrosted = nil;
    
    [vwFrostedContainer release];
    vwFrostedContainer = nil;
    
    [vwContent release];
    vwContent = nil;
    
    [vwContentColor release];
    vwContentColor = nil;
    
    [envelope release];
    envelope = nil;
    
    [callerConfig release];
    callerConfig = nil;
    
    [interactiveController release];
    interactiveController = nil;
    
    [lcTopGuidance release];
    lcTopGuidance = nil;
    
    [bPostMessage release];
    bPostMessage = nil;
    
    [tgrSeal release];
    tgrSeal = nil;
    
    [vwGuidance release];
    vwGuidance = nil;
    
    [vwExportActions release];
    vwExportActions = nil;
    
    [vwFakeContainer release];
    vwFakeContainer = nil;
    
    [lPreparing release];
    lPreparing = nil;
    
    [aivProgress release];
    aivProgress = nil;
    
    [lSecure release];
    lSecure = nil;
    
    [lErrOther release];
    lErrOther = nil;
    
    [lErrSpace release];
    lErrSpace = nil;
    
    [super dealloc];
}

/*
 *  Configure the view.
 */
-(void) viewDidLoad
{
    [super viewDidLoad];
    
    // - configure the navigation bar
    self.title = NSLocalizedString(@"Sealed Message", nil);

    // - the content view always fades-in to start
    vwContent.alpha = 0.0f;
    
    // - make a background color for the content that won't be visible initially
    vwContentColor                  = [[UIView alloc] initWithFrame:vwContent.bounds];
    vwContentColor.backgroundColor  = [UIColor whiteColor];
    vwContentColor.alpha            = 0.0f;
    vwContentColor.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [vwContent addSubview:vwContentColor];
    [vwContent sendSubviewToBack:vwContentColor];

    // - put the envelope into the content view.
    [vwContent addSubview:envelope];
    
    // - when the view is initially loaded, if there was prior keyboard focus, we don't want
    //   the tools to slide out of the way while the transition is occurring, so we'll create a proxy
    //   responder that can force the keyboard to stay in position
    // - the other thing is that we need to keep the first responder so that we can get a good snapshot
    //   of the keyboard after a rotation.
    if (callerConfig.keyboardIsVisible) {
        tvHidden      = [[UITextView alloc] initWithFrame:CGRectMake(-500.0f, -500.0f, 1, 1)];
        [self.view addSubview:tvHidden];
        [UIMessageDetailViewControllerV2 configureProxyTextView:tvHidden withText:callerConfig.detailActiveItem];
        [tvHidden becomeFirstResponder];
    }
    
    // - when using an interactive controller, we may need to animate our own keyboard view
    vwFakeContainer = [[UIView alloc] init];
    vwFakeContainer.backgroundColor = [UIColor clearColor];
    [self.view addSubview:vwFakeContainer];
    
    // - instantiate a custom interactive controller so we can disable the gesture during
    //   transitions.
    interactiveController = [[UIChatSealNavigationInteractiveTransition alloc] initWithViewController:self];
    [interactiveController setAllowTransitionToStart:NO];
    vwFrostedContainer.alpha = 0.0f;
    [self assignCommonFrostedBackground];
    
    // - configure dynamic type
    [self reconfigureDynamicTypeElementsDuringInit:YES];
    
    // - the working controls are disabled by default
    [self setWorkingControlsToVisible:NO];
    
    // - tap to open the envelope.
    tgrSeal                      = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(sealGestureTapped:)];
    tgrSeal.numberOfTapsRequired = 1;
    [self.view addGestureRecognizer:tgrSeal];
    
    // - when there is a delegate, that is a signal that we're working modally.
    if (callerConfig.delegate) {
        UIBarButtonItem *bbiCancel             = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(doCancel)];
        self.navigationItem.rightBarButtonItem = bbiCancel;
        [bbiCancel release];
    }
    
    // - set the custom text for the two error messages
    //   NOTE:  the UISealedMessageExportGuidanceView will ensure the layout width stays in synch with the container.
    NSString *sErr = [NSString stringWithFormat:NSLocalizedString(@"Your %@'s storage is almost full.  Please free some space in order to deliver this message.", nil),
                      [[UIDevice currentDevice] model]];
    lErrSpace.text      = sErr;
    lErrSpace.textColor = [ChatSeal defaultWarningColor];
    sErr                = [NSString stringWithFormat:NSLocalizedString(@"Your %@ is unable to secure this message.  Please try again the next time you restart this device.", nil),
                           [[UIDevice currentDevice] model]];
    lErrOther.text      = sErr;
    lErrOther.textColor = [ChatSeal defaultWarningColor];
    
    // - start generating the message
    [self showGuidanceOfType:UISMEV_GT_NONE];
    [self beginMessageGenerationFromConfig];
}

/*
 *  We need to take our initial snapshot of the content right before we move to a new parent so that 
 *  the navigation bar is accurate.
 */
-(void) willMoveToParentViewController:(UIViewController *)parent
{
    [super willMoveToParentViewController:parent];
    [envelope prepareForAnimationWithMaximumDimensions:[self maximumDimensionsForEnvelope] usingSeal:[self sealIdForExport]];
}

/*
 *  Since the message view dismisses the keyboard to not screw up animations, we need to
 *  let it know where its tools should be explicitly.
 */
-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    // - this is sort of an odd kind of thing, but in order to get the predictive text to be right, we need two updates to
    //   the current field, one to set the general text and one to set the pointer to the end.
    [tvHidden setSelectedRange:NSMakeRange(tvHidden.text.length, 0)];
    [self notifyPreviousOfKeyboardLocation];
}

/*
 *  If the keyboard is left up during rotations, we'll get the crappy default, long animation occurring, so
 *  resign and recapture on the other side.
 */
-(void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [tvHidden resignFirstResponder];
}

/*
 *  Move the envelope to where it will be after rotation.
 */
-(void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    if (!isTransitioning) {
        [envelope moveToSealLocked:YES centeredAt:[self centerOfContent] withMaximumDimensions:[self maximumDimensionsForEnvelope]];
    }
}

/*
 *  Make sure we re-acquire focus so that we get a good snapshot of the keyboard before returning.
 */
-(void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    [tvHidden becomeFirstResponder];
}

/*
 *  Update the constraints
 */
-(void) updateViewConstraints
{
    // - in order to make this work well with the prior view, I'm keeping the behavior of going under the top
    //   navigation bar, but that causes some problems when laying out the content.  I'm updating the
    //   constraint for the guidance text to always be tied to the height of the navigation bar.
    // - to make sure we remove the old constraint correctly, we'll assume we don't know who owns it.
    if ([self.lcTopGuidance.firstItem isKindOfClass:[UIView class]]) {
        [((UIView *)self.lcTopGuidance.firstItem).superview removeConstraint:self.lcTopGuidance];
    }
    if ([self.lcTopGuidance.secondItem isKindOfClass:[UIView class]]) {
        [((UIView *)self.lcTopGuidance.secondItem).superview removeConstraint:self.lcTopGuidance];
    }
    self.lcTopGuidance = [NSLayoutConstraint constraintWithItem:vwGuidance attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.navigationController.navigationBar attribute:NSLayoutAttributeBottom multiplier:1.0f constant:16.0f];
    [self.navigationController.navigationBar.superview addConstraint:self.lcTopGuidance];
    
    // - this must be called last to maintain consistency.
    [super updateViewConstraints];
}

/*
 *  This method is triggered when the user wishes to post the message.
 */
-(IBAction)doPostMessage:(id)sender
{
    // - make sure that we reliably post to the feed, which means persisting the entry in the feed's pending list
    if (![self postMessageOrDisplayError]) {
        return;
    }
    
    // - update the sent message count
    if (callerConfig.message) {
        NSError *err = nil;
        ChatSealIdentity *ident = [callerConfig.message identityWithError:&err];
        if (ident) {
            [ident incrementSentCount];
        }
        else {
            NSLog(@"CS:  Failed to locate an identity for the newly posted message %@.  %@", callerConfig.message.messageId, [err localizedDescription]);
        }
    }
    
    // - when this is a new message we'll possibly send it to the delegate.
    ChatSealMessage *psm = nil;
    if (!callerConfig.appendedEntry) {
        psm = [[callerConfig.message retain] autorelease];
    }
    
    // - complete the process by NULLing out the message objects so
    //   it isn't discarded upon view controller deletion, but this
    //   must occur before we inform the delegate or our view will disappear and
    //   start destroying it.
    callerConfig.message       = nil;
    callerConfig.appendedEntry = nil;
    
    // - if there is a delegate, then this was modal and we need to let the
    //   caller manage the dismissal.
    if (callerConfig.delegate) {
        [ChatSeal setMessageFirstExperienceIfNecessary];
        if ([callerConfig.delegate respondsToSelector:@selector(messageDetail:didCompleteWithMessage:)]) {
            [callerConfig.delegate performSelector:@selector(messageDetail:didCompleteWithMessage:) withObject:callerConfig.caller withObject:psm];
        }
    }
    else {
        // - when there is no delegate, that means we appended to an existing message and
        //   it should be 'delivered' before returning.
        useDeliveryTransitionAnimation = YES;
        [tvHidden resignFirstResponder];
        [self.navigationController popViewControllerAnimated:YES];
    }
}

/*
 *  The view is about to disappear.
 */
-(void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // - under iOS8, the keyboard isn't dismissed until after returning from the view controller, but
    //   we want to manage that ourselves.
    if ([ChatSeal isIOSVersionGREQUAL8] && !self.presentedViewController) {
        [tvHidden resignFirstResponder];
    }
    
    // - if we're disappearing permanently, make sure any pending message is discarded.
    if (!self.presentedViewController) {        
        // - cancel the operation that may be running to generate the message
        //   so that it knows that the window is going away.
        [self setGenerationOperation:nil];
        
        // - if the new message still exists in our tracking object, that means it
        //   must be discarded since it couldn't be delivered.
        [self discardNewSealedMessagePermanently];
    }
}
@end


/**********************************************
 UISealedMessageExportViewController (internal)
 **********************************************/
@implementation UISealedMessageExportViewController (internal)

/*
 *  Do initial object configuration.
 */
-(void) commonConfiguration
{
    isTransitioning                     = YES;                  //  always assume we transition initially.
    tvHidden                            = nil;
    envelope                            = nil;
    interactiveController               = nil;
    lastNavMaxY                         = -1.0f;
    opMsgGeneration                     = nil;
    useDeliveryTransitionAnimation      = NO;
    failureToExport                     = NO;
    envelopeNotCompliantDueToFontChange = NO;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyStorageIssueResolved) name:kChatSealNotifyLowStorageResolved object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyFeedsUpdated) name:kChatSealNotifyFeedTypesUpdated object:nil];
}

/*
 *  This message export window only produces animation transitions with the navigation controller.
 */
-(id<UIChatSealNavItemAnimatedTransitioning>) navItemInController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC
{
    // - the standard transition is preferred in some cases, especially when popping back to the root.
    if (useDeliveryTransitionAnimation) {
        return [[[UISealedMessageDeliveryAnimationController alloc] init] autorelease];
    }
    else {
        return [[[UISealedMessageExportAnimationController alloc] initWithInteractiveController:(operation == UINavigationControllerOperationPop) ? interactiveController : nil] autorelease];
    }
}

/*
 *  This is called right before we pop the view controller off the stack.
 */
-(void) navigationWillPopThisViewController
{
    if (useDeliveryTransitionAnimation) {
        return;
    }
    
    if (callerConfig.keyboardIsVisible) {
        [UIFakeKeyboardV2 forceAKeyboardSnapshotUpdate];
    }
    [self checkForCompliantEnvelope];
}

/*
 *  Assign the content this view controller will seal.
 */
-(void) setConfiguration:(UISealedMessageExportConfigData *) config;
{
    [callerConfig release];
    callerConfig        = [config retain];
    envelope            = [[callerConfig.caller envelopeForCurrentState] retain];
    envelopeOrientation = self.backwardsCompatibleInterfaceOrientation;
}

/*
 *  Figure out the seal id to use for exporting content.
 */
-(NSString *) sealIdForExport
{
    NSString *sRet = nil;
    if (callerConfig.message) {
        sRet = callerConfig.message.sealId;
    }
    else {
        if (callerConfig.preferredSealId) {
            sRet = callerConfig.preferredSealId;
        }
        else {
            sRet = [ChatSeal activeSeal];
        }
    }
    return sRet;
}

/*
 *  Recreate the envelope and swap it into where the existing one is.
 *
 */
-(void) regenerateAndConfigureEnvelopeForFinalState
{
    // - create the new envelope
    UISealedMessageEnvelopeViewV2 *newEnv = [[callerConfig.caller envelopeForCurrentStateWithTargetHeight:CGRectGetHeight(self.view.bounds)] retain];
    newEnv.hidden = YES;
    [vwContent addSubview:newEnv];
    [newEnv prepareForAnimationWithMaximumDimensions:[self maximumDimensionsForEnvelope] usingSeal:[self sealIdForExport]];
    envelopeOrientation = self.backwardsCompatibleInterfaceOrientation;

    
    // - do this as a transaction or we'll get a brief flicker during the swap in some cases.
    [CATransaction begin];
    
    // ...discard the previous one.
    [envelope removeFromSuperview];
    [envelope release];
    envelope = nil;
    
    // ...re-run the transforms immediately to ensure that everything is ready.
    envelope = newEnv;
    envelope.hidden = NO;
    [envelope moveToFinalStateWithAllRequiredTransformsCenteredAt:[self centerOfContent] withMaximumDimensions:[self maximumDimensionsForEnvelope]];
    
    [CATransaction commit];
}

/*
 *  In order to ensure that the previous view controller is always kept in synch with the keyboard location, so
 *  its edit tools are located correctly, we'll tell it what we expect when major events occur.
 */
-(void) notifyPreviousOfKeyboardLocation
{
    [callerConfig.caller recalibrateToolbarWithViewDimensions:self.view.bounds.size];
}

/*
 *  Assign the frosted background using the one generated for the keyboard.
 */
-(void) assignCommonFrostedBackground
{
    ivFrosted.image = [UIFakeKeyboardV2 currentKeyboardEffectImage];
    if (ivFrosted.image) {
        ivFrosted.backgroundColor = [UIColor clearColor];
    }
    else {
        ivFrosted.backgroundColor = [UIColor colorWithRed:0.95f green:0.95f blue:0.95f alpha:1.0f];
    }
    frostedOrientation = self.backwardsCompatibleInterfaceOrientation;
}

/*
 *  Assign a frosted image to the background that we can fade-in from.
 */
-(void) updateFrostedImage
{
    [callerConfig.caller updateKeyboardEffectImage];
    [self assignCommonFrostedBackground];
    
    // - make sure the transitioning keyboard view is up to date
    if (isTransitioning) {
        [self snapshotCurrentFakeKeyboardForReturn];
    }
}

/*
 *  Compute the maximum Y location for the navigation controller to be used for sizing
 *  the content.
 */
-(CGFloat) navigationMaxY
{
    //  - there are times during this process that the navigation controller is nil if we
    //    are in the middle of a transition, which is why the location is cached
    if (self.navigationController.navigationBar) {
        lastNavMaxY = CGRectGetMaxY(self.navigationController.navigationBar.frame);
        return lastNavMaxY;
    }
    else if (lastNavMaxY > 0.0f) {
        return lastNavMaxY;
    }
    return 0.0f;
}

/*
 *  Return the center point for the content.
 */
-(CGPoint) centerOfContent
{
    CGFloat navH    = [self navigationMaxY];
    CGFloat height  = CGRectGetHeight(self.view.bounds) - navH;
    CGPoint ptBase  = CGPointMake((CGRectGetWidth(self.view.bounds)/2.0f), navH + (height / 2.0f));
    return ptBase;
}

/*
 *  Return the envelope maximum dimensions.
 */
-(CGSize) maximumDimensionsForEnvelope
{
    CGSize szRet  = self.view.bounds.size;

    // - if this is called before the view is attached to the superview,
    //   then the orientation adjustments aren't included.
    if (!self.view.superview && [ChatSeal isIOSVersionBEFORE8] && UIInterfaceOrientationIsLandscape(self.backwardsCompatibleInterfaceOrientation)) {
        CGFloat tmp  = szRet.width;
        szRet.width  = szRet.height;
        szRet.height = tmp;
    }

    CGFloat navH  = [self navigationMaxY];
    szRet.height -= navH;
    
    // - the padding is determined by the height because that space must be inside the nav bar, but only
    //   in portrait mode because landscape is much smaller to begin with and has a lot of whitespace on
    //   the sides that doesn't exist in portrait.
    if (UIInterfaceOrientationIsPortrait(self.backwardsCompatibleInterfaceOrientation)) {
        CGFloat pad = szRet.height * UISMEV_STD_PAD_PCT;
        szRet.width  -= (pad * 2.0f);
        szRet.height -= (pad * 2.0f);
    }
    
    // - return the adjusted dimensions
    return szRet;
}

/*
 *  This method is called whenever the screen is tapped and we need to
 *  determine if the seal is tapped.
 */
-(void) sealGestureTapped:(UITapGestureRecognizer *) tgr
{
    // - don't allow this if we're in mid-transition because it will hose things up.
    if (isTransitioning) {
        return;
    }
    
    CGPoint loc = [tgr locationInView:envelope];
    if ([envelope isPointInSealIcon:loc]) {
        [UIFakeKeyboardV2 forceAKeyboardSnapshotUpdate];
        [self checkForCompliantEnvelope];
        [envelope sealIconTapped];
        isTransitioning = YES;
        [self.navigationController popViewControllerAnimated:YES];
    }
}

/*
 *  When the orientation changes, the envelope will need to be updated before returning to 
 *  the prior view.  This method will check for that scenario and update it accordingly.
 */
-(void) checkForCompliantEnvelope
{
    // - through trial and error I found that trying to take snapshots during the transition animations doesn't
    //   work reliably.
    if (envelopeNotCompliantDueToFontChange || UIInterfaceOrientationIsPortrait(self.backwardsCompatibleInterfaceOrientation) != UIInterfaceOrientationIsPortrait(envelopeOrientation)) {
        envelopeNotCompliantDueToFontChange = NO;
        envelopeOrientation                 = self.backwardsCompatibleInterfaceOrientation;
        [self notifyPreviousOfKeyboardLocation];
        [self regenerateAndConfigureEnvelopeForFinalState];
    }
}

/*
 *  If this is a new message, the view hiearchy was presented modally and can be cancelled.
 *  - NOTE:  Remember that this can be issued after the seal was first created.
 */
-(void) doCancel
{
    if (callerConfig.delegate &&
        callerConfig.caller &&
        [callerConfig.delegate respondsToSelector:@selector(messageDetailShouldCancel:)]) {
        [callerConfig.delegate performSelector:@selector(messageDetailShouldCancel:) withObject:callerConfig.caller];
    }
}

/*
 *  Assign the generation operation
 */
-(void) setGenerationOperation:(NSOperation *) op
{
    if (op != opMsgGeneration) {
        [opMsgGeneration cancel];
        [opMsgGeneration release];
        opMsgGeneration = [op retain];
        if (opMsgGeneration) {
            [[ChatSeal vaultOperationQueue] addOperation:opMsgGeneration];
        }
    }
}

/*
 *  Start the message generation processing.
 */
-(void) beginMessageGenerationFromConfig
{
    // - never allow a second to be started this way
    if (opMsgGeneration) {
        return;
    }
    
    // - if the animation completes prematurely, we still won't be able to continue unless the generation
    //   succeeds.
    bPostMessage.enabled = NO;
    ChatSealWeakOperation *wop = [ChatSealWeakOperation weakOperationWrapper];
    NSBlockOperation *bo = [NSBlockOperation blockOperationWithBlock:^(void) {
        // - now encrypt and save it.
        NSError *err   = nil;
        BOOL ret       = YES;
        if (callerConfig.message) {
            callerConfig.messageIsNew  = NO;
            callerConfig.appendedEntry = [callerConfig.message addNewEntryOfType:callerConfig.messageType withContents:callerConfig.items onCreationDate:nil andError:&err];
            if (!callerConfig.appendedEntry) {
                ret = NO;
            }
        }
        else {
            // - create a decoy and then the message.
            UIImage *decoy            = nil;
            callerConfig.messageIsNew = YES;
            if (callerConfig.preferredSealId) {
                decoy                = [ChatSeal standardDecoyForSeal:callerConfig.preferredSealId];
                callerConfig.message = [ChatSeal createMessageOfType:callerConfig.messageType usingSeal:callerConfig.preferredSealId
                                                                    withDecoy:decoy andData:callerConfig.items andError:&err];
            }
            else {
                decoy                = [ChatSeal standardDecoyForActiveSeal];
                callerConfig.message = [ChatSeal createMessageOfType:callerConfig.messageType withDecoy:decoy andData:callerConfig.items andError:&err];
            }
            
            if (!callerConfig.message) {
                ret = NO;
            }
        }
        
        // - only complete the export when this isn't cancelled and succeeded
        [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
            [self messageCompletionWithReturn:ret && ![wop isCancelled] andError:err];
        }];
    }];
    [wop setOperation:bo];
    [self setGenerationOperation:bo];
    [self showGuidanceOfType:UISMEV_GT_PENDING];
    bPostMessage.enabled = NO;
}

/*
 *  There are times, right before we return to the prior window, that we need to make sure that any new message contents
 *  are removed.  Generally, this shouldn't be called, but will be during cancellation and the return trip to the 
 *  prior window.
 */
-(void) discardNewSealedMessagePermanently
{
    NSError *err = nil;
    if (callerConfig.appendedEntry) {
        if (![callerConfig.message destroyEntry:callerConfig.appendedEntry withError:&err]) {
            NSLog(@"CS: Failed to discard the sealed message reply.  %@(%@)", [err localizedDescription], [err localizedFailureReason]);
        }
        callerConfig.appendedEntry = nil;
    }
    else {
        if (callerConfig.messageIsNew && callerConfig.message) {
            if (![callerConfig.message destroyNewMessageWithError:&err]) {
                NSLog(@"CS: Failed to discard the new message.  %@(%@)", [err localizedDescription], [err localizedFailureReason]);
            }
            callerConfig.message = nil;
        }
    }
}

/*
 *  This method is called on the main thread from the operation to signal that the message processing is completed.
 */
-(void) messageCompletionWithReturn:(BOOL) retCode andError:(NSError *) err
{
    failureToExport = !retCode;
    if (retCode) {
        [self showGuidanceOfType:UISMEV_GT_SECURE];
        bPostMessage.enabled = YES;
    }
    else {
        [self showGuidanceOfType:[ChatSeal isLowStorageAConcern] ? UISMEV_GT_ERR_SPACE : UISMEV_GT_ERR_OTH];
        [self discardNewSealedMessagePermanently];
        NSLog(@"CS: Failed to secure the message.  %@", [err localizedDescription]);
    }
    [self setGenerationOperation:nil];
}

/*
 *  Display guidance for the user.
 */
-(void) showGuidanceOfType:(uismev_guidance_type_t) gt
{
    [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void){
        lPreparing.alpha  = (gt == UISMEV_GT_PENDING ? 1.0f : 0.0f);
        if (gt == UISMEV_GT_PENDING) {
            [aivProgress startAnimating];
        }
        else {
            [aivProgress stopAnimating];
        }
        
        // - the secure guidance is at tag 2
        lSecure.alpha   = (gt == UISMEV_GT_SECURE ? 1.0f : 0.0f);
        
        // - the space error is at tag 3
        lErrSpace.alpha = (gt == UISMEV_GT_ERR_SPACE ? 1.0f : 0.0f);
        
        // - the generic 'other' error is at tag 4
        lErrOther.alpha = (gt == UISMEV_GT_ERR_OTH ? 1.0f : 0.0f);
    }];
}

/*
 *  Before the app enters the foreground from being dormant and low storage is now fixed, this is issued.
 */
-(void) notifyStorageIssueResolved
{
    // - this is a very precise scenario that to try to recover from a failure
    //   to seal the message because there was no space left on disk.
    if (failureToExport && !opMsgGeneration) {
        [self beginMessageGenerationFromConfig];
    }
}

/*
 *  Discard the copy of the fake keyboard.
 */
-(void) removeFakeKeyboardCopy
{
    UIView *vw = [vwFakeContainer viewWithTag:UISMEV_STD_FAKE_TAG];
    [vw removeFromSuperview];
}

/*
 *  Update the view being animated currently with the fake keyboard.
 */
-(void) snapshotCurrentFakeKeyboardForReturn
{
    if (!callerConfig.keyboardIsVisible) {
        return;
    }
    
    [self removeFakeKeyboardCopy];
    UIView *vw = [UIFakeKeyboardV2 keyboardSnapshot];
    vw.center  = CGPointMake(CGRectGetWidth(vw.bounds)/2.0f, CGRectGetHeight(vw.bounds)/2.0f);
    [vwFakeContainer addSubview:vw];
}

/*
 *  Attempt to post the message to the chosen feed and react to the result.
 */
-(BOOL) postMessageOrDisplayError
{
    if (!callerConfig.message || !callerConfig.targetFeed) {
        return NO;
    }
    
    NSString *sErrTitle = NSLocalizedString(@"Post Interrupted", nil);
    NSString *sErrMsg   = NSLocalizedString(@"A problem occurred while preparing your message for delivery.", nil);
    
    NSError *err                     = nil;
    if (![callerConfig.message pinSecureContent:&err]) {
        [AlertManager displayFatalAlertWithLowSpaceDetectionUsingTitle:sErrTitle
                                                               andText:sErrMsg];
        NSLog(@"CS: Failed to pin the message before posting.  %@", [err localizedDescription]);
        return NO;
    }
    
    // - we're going to issue this under the message lock because the entry could go stale if
    //   it had to be retrieved explicitly and that would hose up our tracking in the feed.
    BOOL ret = [callerConfig.message performBlockUnderMessageLock:^BOOL(NSError **tmp) {
        // - first get a message entry to send over to the feed.
        ChatSealMessageEntry *meCreated = callerConfig.appendedEntry;
        if (!meCreated) {
            meCreated = [callerConfig.message entryForIndex:0 withError:tmp];
            if (!meCreated) {
                NSLog(@"CS: Failed to retrieve the first entry for the new message during posting.  %@", [err localizedDescription]);
                return NO;
            }
        }
        
        // - now attempt to post it.
        if ([callerConfig.targetFeed postMessage:meCreated withError:tmp]) {
            [callerConfig.message setDefaultFeedForMessage:callerConfig.targetFeed.feedId];
            return YES;
        }
        else {
            return NO;
        }
    }withError:&err];

    [callerConfig.message unpinSecureContent];
    
    // - handle any errors that occurred.
    if (!ret) {
        // - a problem occurred, so we can't continue and may have to update this screen's UI.
        if ([callerConfig.targetFeed isValid]) {
            NSLog(@"CS: Failed to post message to target feed %@.  %@", callerConfig.targetFeed.feedId, [err localizedDescription]);
            
            // - I thought a bit about whether a fatal error is warranted here, but I think it really should be because if I can't save to
            //   that feed directory there is something completely unexpected happening and I can't imagine what it might be.
            // - That kind of failure must really be rare or it will rapidly turn into a problem.
            [AlertManager displayErrorAlertWithTitle:sErrTitle andText:sErrMsg];
        }
        else {
            // - the feed is now invalid, so we need to deal with it.
            [self disablePostBecauseOfBadFeed];
        }
    }
    
    return ret;
}

/*
 *  When a feed becomes invalid because it was deleted when the app was backgrounded, we cannot allow
 *  the user to proceed.
 */
-(void) disablePostBecauseOfBadFeed
{
    // - no more feed button.
    [bPostMessage setEnabled:NO];
 
    // - modify the error and display it.
    lErrOther.text     = NSLocalizedString(@"The feed you selected is now unavailable.  Please return to the message to choose a different one.", nil);
    [self showGuidanceOfType:UISMEV_GT_ERR_OTH];    
    callerConfig.targetFeed = nil;
}

/*
 *  When the feed we chose is now invalid, we have to reselect one.
 */
-(void) notifyFeedsUpdated
{
    if (callerConfig.targetFeed && ![callerConfig.targetFeed isValid]) {
        [self disablePostBecauseOfBadFeed];
    }
}

/*
 *  We got a dynamic type update.
 */
-(void) updateDynamicTypeNotificationReceived
{
    // - this flag allows us to know if we need to re-format the content of the envelope before opening it for a return trip
    //   to the detail screen.
    envelopeNotCompliantDueToFontChange = YES;
    [self reconfigureDynamicTypeElementsDuringInit:NO];
}

/*
 *  Reconfigure all elements that are impacted by dynamic type.
 */
-(void) reconfigureDynamicTypeElementsDuringInit:(BOOL) isInit
{
    // - before iOS8, it was uncommon to have a lot of dynamic type.
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        return;
    }
    
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lPreparing withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lSecure withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lErrSpace withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lErrOther withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextButton:self.bPostMessage withPreferredSettingsAndTextStyle:UIFontTextStyleBody andMinimumSize:[ChatSeal minimumButtonFontSize] duringInitialization:isInit];
}

@end

/**********************************************
 UISealedMessageExportViewController (shared)
 **********************************************/
@implementation UISealedMessageExportViewController (shared)

/*
 *  Compute the start time based on where the animation will occur and whether we're running backwards.
 */
-(CGFloat) startTimeForPushOperation:(BOOL) isPush andOffset:(CGFloat) pushOffset andDuration:(CGFloat) duration
{
    CGFloat ret = 0.0f;
    if (isPush) {
        ret = pushOffset;
    }
    else {
        //  - we need to flip the animation curve over so that we're achiving our final state
        //    when the push animation started.
        ret = (1.0f - (pushOffset + duration));
    }
    return (ret < 0.0f ? 0.0f : ret);
}

/*
 *  Show/hide the working controls, which are the ones used to send the message.
 */
-(void) setWorkingControlsToVisible:(BOOL) areVisible
{
    vwGuidance.alpha      = (areVisible ? 1.0f : 0.0f);
    vwExportActions.alpha = (areVisible ? 1.0f : 0.0f);
}

// ------------------------------------------------
// FRAME ONE - original state
// NOTE:  For each of these animations, it is critical
//        that the inverse operation be described in the
//        same location as the original one or the timing
//        will be off beetween the two.
// ------------------------------------------------
/*
 *  Animate the frosted glass into display.
 */
-(void) subAnimateFrostedRegionDuringFoldingForPushOperation:(BOOL) isPush
{
    CGFloat duration = 0.2f;           //  target of .5 sec
    CGFloat toAlpha  = 0.0f;
    if (isPush) {
        toAlpha = 1.0f;
    }
    CGFloat start = [self startTimeForPushOperation:isPush andOffset:0.0f andDuration:duration];
    [UIView addKeyframeWithRelativeStartTime:start relativeDuration:duration animations:^(void){
        vwFrostedContainer.alpha = toAlpha;
    }];
}

/*
 *  Create the keyframe for the overall content region behavior.
 */
-(void) subAnimateContentRegionForPushOperation:(BOOL) isPush
{
    CGFloat duration = isPush ? 0.2f : 0.08f;           //  target of .5 sec or .2 sec
    CGFloat toAlpha  = 0.0f;
    if (isPush) {
        toAlpha = 1.0f;
    }
    CGFloat start = [self startTimeForPushOperation:isPush andOffset:0.0f andDuration:duration];
    [UIView addKeyframeWithRelativeStartTime:start relativeDuration:duration animations:^(void){
        vwContent.alpha = toAlpha;
    }];
}

/*
 *  Transition one is when the bubbles are visible over the tools and the previous window is completely obscured.
 */
-(void) animateExportTransitionOneForPushOperation:(BOOL) isPush
{
    [self subAnimateFrostedRegionDuringFoldingForPushOperation:isPush];
    [self subAnimateContentRegionForPushOperation:isPush];
}

// ------------------------------------------------
// FRAME TWO - aspect accurate paper, keyboard gone
// ------------------------------------------------

/*
 *  Move to the paper dimensions.
 */
-(void) subAnimatePaperForPushOperation:(BOOL) isPush
{
    // - start by sizing the paper.
    CGFloat duration = 0.2f;           // target of .5 sec
    CGFloat offset   = 0.12f;
    CGFloat start = [self startTimeForPushOperation:isPush andOffset:offset andDuration:duration];
    [UIView addKeyframeWithRelativeStartTime:start relativeDuration:duration animations:^(void){
        if (isPush) {
            [envelope moveToAspectAccuratePaperCenteredAt:[self centerOfContent] withMaximumDimensions:[self maximumDimensionsForEnvelope] withPush:YES];
        }
        else {
            [envelope moveToOriginalState];
        }
    }];
    
    // - swap-in the alternate views at the very end that will facilitate folding, but only when we're
    //   pushing.  The pop must occur at a different time.
    if (isPush) {
        [UIView addKeyframeWithRelativeStartTime:start + duration relativeDuration:0.0f animations:^(void) {
            [envelope setFakePaperFoldsVisible:isPush];
        }];
    }
}

/*
 *  Create the keyframe for the keyboard.
 */
-(void) subAnimateKeyboardForPushOperation:(BOOL) isPush
{
    CGFloat duration = 0.16f;            // target of .4 sec
    CGFloat start    = [self startTimeForPushOperation:isPush andOffset:0.2f andDuration:duration];
    [UIView addKeyframeWithRelativeStartTime:start relativeDuration:duration animations:^(void){
        if (isPush) {
            if (callerConfig.keyboardIsVisible) {
                [UIFakeKeyboardV2 setKeyboardVisible:NO];
            }
        }
        else {
            // an interactive transition apparently doesn't work cross-window, so we have to
            // use a view within this window hierarchy.
            vwFakeContainer.center = CGPointMake(CGRectGetWidth(self.view.bounds)/2.0f, CGRectGetHeight(self.view.bounds) - (CGRectGetHeight(vwFakeContainer.bounds)/2.0f));
        }
    }];
}

/*
 *  Transition two is when the message is adapted into a sheet of paper and the keyboard slides out of the way.
 */
-(void) animateExportTransitionTwoForPushOperation:(BOOL) isPush
{
    [self subAnimatePaperForPushOperation:isPush];
    [self subAnimateKeyboardForPushOperation:isPush];
}

// ------------------------------------------------
// FRAME THREE - paper is folded
// ------------------------------------------------

/*
 *  The keyframe for doing the paper folding.
 */
-(void) subAnimateFoldPaperForPushOperation:(BOOL) isPush
{
    CGFloat offset   = 0.4f;
    CGFloat duration = 0.3f;            // target of .75 sec
    CGFloat start    = [self startTimeForPushOperation:isPush andOffset:offset andDuration:duration];
    [UIView addKeyframeWithRelativeStartTime:start relativeDuration:duration animations:^(void){
        if (isPush) {
            [envelope moveToFoldedEnvelopeCenteredAt:[self centerOfContent] withMaximumDimensions:[self maximumDimensionsForEnvelope]];
        }
        else {
            [envelope moveToAspectAccuratePaperCenteredAt:[self centerOfContent] withMaximumDimensions:[self maximumDimensionsForEnvelope] withPush:NO];
        }
    }];
    
    // - swap-in the alternate views at the very end that will facilitate unfolding, but only when we're
    //   popping.  The push must occur at a different time.
    if (!isPush) {
        [UIView addKeyframeWithRelativeStartTime:start + duration relativeDuration:0.0f animations:^(void) {
            [envelope setFakePaperFoldsVisible:isPush];
        }];
    }
}

/*
 *  Transition three is when the paper is folded into an envelope.
 */
-(void) animateExportTransitionThreeForPushOperation:(BOOL) isPush
{
    [self subAnimateFoldPaperForPushOperation:isPush];
}

// ------------------------------------------------
// FRAME FOUR - envelope is locked
// ------------------------------------------------

/*
 *  Create the keyframes for the envelope's sealed state.
 */
-(void) subAnimateLockedEnvelopeForPushOperation:(BOOL) isPush
{
    CGFloat duration = 0.12f;           // target of .3 sec
    CGFloat start    = [self startTimeForPushOperation:isPush andOffset:0.7f andDuration:duration];
    [UIView addKeyframeWithRelativeStartTime:start relativeDuration:duration animations:^(void){
        [envelope moveToSealVisible:isPush];
    }];
    
    start = [self startTimeForPushOperation:isPush andOffset:0.85f andDuration:duration];
    [UIView addKeyframeWithRelativeStartTime:start relativeDuration:duration animations:^(void){
        [envelope moveToSealLocked:isPush centeredAt:[self centerOfContent] withMaximumDimensions:[self maximumDimensionsForEnvelope]];
    }];
}

/*
 *  Transition four is when the seal is locked into the envelope.
 */
-(void) animateExportTransitionFourForPushOperation:(BOOL) isPush
{
    [self subAnimateLockedEnvelopeForPushOperation:isPush];
}

// ------------------------------------------------
// FRAME FIVE - the rest of the window adapts around the new envelope
// ------------------------------------------------

/*
 *  At the very end, the content will obscure the previous frosted glass.
 */
-(void) subAnimateContentFinalColorForPushOperation:(BOOL) isPush
{
    CGFloat duration = 0.15f;           // target of .3 sec
    CGFloat toAlpha  = 0.0f;
    if (isPush) {
        toAlpha = 1.0f;
    }
    CGFloat start = [self startTimeForPushOperation:isPush andOffset:0.75f andDuration:duration];
    [UIView addKeyframeWithRelativeStartTime:start relativeDuration:duration animations:^(void){
        vwContentColor.alpha = toAlpha;
    }];
}

/*
 *  Show the button to send the message and the text describing the completed state.
 */
-(void) subAnimateWorkingControlsReadyForPushOperation:(BOOL) isPush
{
    CGFloat duration = 0.15f;
    CGFloat start    = [self startTimeForPushOperation:isPush andOffset:0.85f andDuration:duration];
    [UIView addKeyframeWithRelativeStartTime:start relativeDuration:duration animations:^(void){
        [self setWorkingControlsToVisible:isPush];
    }];
}

/*
 *  Transition five is when the envelope becomes abstract on the screen with simple lines and
 *  effectively merges into this view.
 */
-(void) animateExportTransitionFiveForPushOperation:(BOOL) isPush
{
    [self subAnimateContentFinalColorForPushOperation:isPush];
    [self subAnimateWorkingControlsReadyForPushOperation:isPush];
}

/*
 *  Manage the navigation transition for this view.
 */
-(void) animateNavigationTransitionToThisView:(BOOL) toThisView withDuration:(NSTimeInterval) duration andCompletion:(void(^)(void)) completionBlock
{
    // - track the transitioning state
    isTransitioning = YES;
    [interactiveController setAllowTransitionToStart:NO];

    if (toThisView) {
        [UIView performWithoutAnimation:^(void) {
            [envelope moveToOriginalState];
        }];
    }
    else {
        // - make sure that if the keyboard as changed, the previous view is udpated.
        [self notifyPreviousOfKeyboardLocation];
        
        // - also, if the keyboard changed, the envelope's origin must be adjusted.
        [envelope modifyEnvelopeOrigin:[callerConfig.caller envelopeOrigin]];
        
        //  - position the fake container now so that the animation has something to work with.
        CGSize sz             = [UIFakeKeyboardV2 keyboardSize];
        vwFakeContainer.frame = CGRectMake(0.0f, CGRectGetHeight(self.view.bounds), sz.width, sz.height);
        
        // - before returning make sure the frosted image gets updated before its animation fires
        if (UIInterfaceOrientationIsPortrait(self.backwardsCompatibleInterfaceOrientation) != UIInterfaceOrientationIsPortrait(frostedOrientation)) {
            // - this must be done after this method is executed so that the layout is completed on the prior window
            //   before the frosted image shot is taken.
            [self performSelectorOnMainThread:@selector(updateFrostedImage) withObject:nil waitUntilDone:NO];
        }
        else {
            [self snapshotCurrentFakeKeyboardForReturn];
        }
    }
    
    // - perform the animations on the different elements.
    [UIView animateKeyframesWithDuration:duration delay:0.0f options:0 animations:^(void) {
        [self animateExportTransitionOneForPushOperation:toThisView];
        [self animateExportTransitionTwoForPushOperation:toThisView];
        [self animateExportTransitionThreeForPushOperation:toThisView];
        [self animateExportTransitionFourForPushOperation:toThisView];
        [self animateExportTransitionFiveForPushOperation:toThisView];
    } completion:^(BOOL finished) {
        [envelope completeEnvelopeTransitionDisplay];
        if (completionBlock) {
            completionBlock();
        }
        [interactiveController setAllowTransitionToStart:YES];
        isTransitioning = NO;
    }];
    
    // - we need to set the persistent state at the end so that in the event of an interactive
    //   abort our controls are set correctly.
    if (!toThisView) {
        [envelope moveToSealLocked:YES centeredAt:[self centerOfContent] withMaximumDimensions:[self maximumDimensionsForEnvelope]];
    }
}

/*
 *  When an interactive transition is cancelled, this method is called.
 */
-(void) navigationTransitionWasCancelled
{
    [self removeFakeKeyboardCopy];
}

/*
 *  When we're about to complete the transition, this method is called to allow 
 *  any final handover of control to occur.
 */
-(void) navigationWasCompletedToViewController:(UIViewController *) vc
{
    //  - the only one we really care about is the message detail view controller that
    //    spawned this.
    if (![vc isKindOfClass:[UIMessageDetailViewControllerV2 class]]) {
        return;
    }

    // - when the keyboard is being used to simulate the return state, we need
    //   to notify the prior window so that it can re-capture focus after all
    //   animations are done.
    if (callerConfig.keyboardIsVisible) {
        if (useDeliveryTransitionAnimation) {
            [UIFakeKeyboardV2 setKeyboardMaskingEnabled:NO];
        }
        else {
            [(UIMessageDetailViewControllerV2 *) vc completedExportAbortReturn];
        }
    }
}

/*
 *  When we append to an existing message and we're in a navigation hierarchy that goes back to the hub, the
 *  right option is to not pop to the hub, but instead pop back to the detail view controller.  This will 
 *  perform a simple little push of the envelope off screen to mimic the delivery process.
 *  - the objective here is to make repeated new message entries very quick to create.
 */
-(void) animateDeliveryTransitionToDetail:(UIMessageDetailViewControllerV2 *) mdvc withDuration:(NSTimeInterval) duration andCompletion:(void(^)(void)) completionBlock
{
    // - this is intentionally a very simple kind of process to keep it
    //   efficient and not annoying.
    // - the envelope slides off the screen with a bit of shear as the background fades out
    //   before returning to the detail view for final processing.
    
    // - make sure the toolbar is positioned since it hasn't been able to
    //   for a bit
    [mdvc prepareForMessageDeliveryWithDimensions:self.view.bounds.size];
    
    // - the envelope is going to shear off to the right.
    CGAffineTransform atShear     = CGAffineTransformMake(1.0, 0.0, 0.5f, 1.0, 0.0, 0.0);
    CGAffineTransform atDelivered = CGAffineTransformTranslate(atShear, CGRectGetWidth(self.view.bounds) * 1.5f, 0.0f);
    
    vwFrostedContainer.hidden = YES;
    
    // - now do the animation in keyframes
    [UIView animateKeyframesWithDuration:duration delay:0.0f options:0 animations:^(void) {
        [UIView addKeyframeWithRelativeStartTime:0.0f relativeDuration:0.75f animations:^(void) {
            envelope.transform = atDelivered;
        }];
        [UIView addKeyframeWithRelativeStartTime:0.0f relativeDuration:0.25f animations:^(void) {
            vwGuidance.alpha = 0.0f;
            vwExportActions.alpha = 0.0f;
        }];
        [UIView addKeyframeWithRelativeStartTime:0.6f relativeDuration:0.4f animations:^(void) {
            vwContent.alpha = 0.0f;
        }];
    }completion:^(BOOL finished) {
        // - this must run in order to complete the transition.
        if (completionBlock) {
            completionBlock();
        }
        
        // - when the transaction is complete, we need to then add the new items to the prior view.
        [mdvc displayRecentlyDeliveredLastEntry];
    }];
}

@end
