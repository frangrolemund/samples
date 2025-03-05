//
//  UIGenericAccessViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 4/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIGenericAccessViewController.h"
#import "ChatSeal.h"
#import "UIAdvancedSelfSizingTools.h"

// - constants
static const CGFloat UIGAVC_STD_CORNER = 7.0f;

// - forward declarations
@interface UIGenericAccessViewController (internal) <UIViewControllerTransitioningDelegate>
-(void) setCompletionBlock:(genericAccessCompletion) cb;
-(void) animateTransitionTo:(BOOL) toAnim withDuration:(NSTimeInterval) duration withCompletion:(void(^)(void)) animCompletionBlock;
-(void) displayAppropriateSubdialogForAccess;
-(void) assignSeparatorImage;
-(void) reconfigureTextItemsForDynamicTypeAsInit:(BOOL) isInit;
@end

// - the custom transition code.
@interface UIGenericAccessAnimiationController : NSObject<UIViewControllerAnimatedTransitioning>
@end

/********************************
 UIGenericAccessViewController
 ********************************/
@implementation UIGenericAccessViewController
/*
 *  Object attributes
 */
{
    genericAccessCompletion completionBlock;
    BOOL                    isLocked;
}
@synthesize delegate;
@synthesize lAuthTitle;
@synthesize lAuthDesc;
@synthesize lLockedTitle;
@synthesize lLockedDesc;
@synthesize vwShadow;
@synthesize vwAuthorize;
@synthesize vwLocked;
@synthesize ivAdvAuth;
@synthesize ivAdvLock;
@synthesize bAuthorize;
@synthesize bOK;

/*
 *  Create an instance of this view controller.
 */
+(UIGenericAccessViewController *) instantateViewControllerWithAccessCompletion:(genericAccessCompletion) completionBlock
{
    UIGenericAccessViewController *gavRet = (UIGenericAccessViewController *) [ChatSeal viewControllerForStoryboardId:@"UIGenericAccessViewController"];
    [gavRet setCompletionBlock:completionBlock];
    return gavRet;
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        completionBlock             = nil;
        isLocked                    = NO;
        self.modalPresentationStyle = UIModalPresentationCustom;
        self.transitioningDelegate  = self;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    // - the delegate is intentionally retained!
    [delegate release];
    delegate = nil;
    
    [self setCompletionBlock:nil];
    
    [lAuthTitle release];
    lAuthTitle = nil;
    
    [lAuthDesc release];
    lAuthDesc = nil;
    
    [lLockedTitle release];
    lLockedTitle = nil;
    
    [lLockedDesc release];
    lLockedDesc = nil;
    
    [vwShadow release];
    vwShadow = nil;
    
    [vwAuthorize release];
    vwAuthorize = nil;
    
    [vwLocked release];
    vwLocked = nil;
    
    [ivAdvLock release];
    ivAdvLock = nil;
    
    [ivAdvAuth release];
    ivAdvAuth = nil;
    
    [bAuthorize release];
    bAuthorize = nil;
    
    [bOK release];
    bOK = nil;
    
    [super dealloc];
}

/*
 *  Configure the object.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // - load up the fields.
    lAuthTitle.text   = [delegate authTitle];
    lAuthDesc.text    = [delegate authDescription];
    lLockedTitle.text = [delegate lockedTitle];
    lLockedDesc.text  = [delegate lockedDescription];
    [self reconfigureTextItemsForDynamicTypeAsInit:YES];
    
    // - show either auth or locked depending on whether we're set up or not.
    [self displayAppropriateSubdialogForAccess];
    
    // - the shadow layer must be placed way at the back or we'll get clipping during the flip animations
    vwShadow.layer.transform = CATransform3DMakeTranslation(0.0f, 0.0f, -1000.0f);
    
    // - apply the rounded border to the two sub-views
    vwLocked.layer.cornerRadius    = UIGAVC_STD_CORNER;
    vwAuthorize.layer.cornerRadius = UIGAVC_STD_CORNER;
    
    // - the background for the sub-views is intentionally simple to make it clear to read and the standard
    //   alert doesn't play with frosting it anyway.
    vwLocked.backgroundColor    = [ChatSeal defaultLowChromeFrostedColor];
    vwAuthorize.backgroundColor = [ChatSeal defaultLowChromeFrostedColor];
    vwShadow.backgroundColor    = [ChatSeal defaultLowChromeShadowColor];
    
    // - add the separator to highlight the button.
    [self assignSeparatorImage];
}

/*
 *  Execute the final completion block and close this view.
 */
-(IBAction)doCloseTheView
{
    if (completionBlock) {
        completionBlock();
        [self setCompletionBlock:nil];
    }
}

/*
 *  Perform authorization.
 */
-(IBAction)doAuthorize
{
    bAuthorize.enabled = NO;
    if (self.delegate && [self.delegate respondsToSelector:@selector(accessViewControllerAuthContinuePressed:)]) {
        [self.delegate performSelector:@selector(accessViewControllerAuthContinuePressed:) withObject:self];
    }
    else {
        [self flipToLocked];
    }
}

/*
 *  Flip the sub-views so that the locked view is displayed.
 */
-(void) flipToLocked
{
    if (isLocked) {
        return;
    }
    
    //  - first we're going to take snapshots of each one that can be used for their interim forms
    vwAuthorize.hidden = NO;
    vwLocked.hidden    = NO;
    
    UIView *vwSnapAuth = [vwAuthorize snapshotViewAfterScreenUpdates:YES];
    vwSnapAuth.center  = vwAuthorize.center;
    UIView *vwSnapLock = [vwLocked snapshotViewAfterScreenUpdates:YES];
    vwSnapLock.center  = vwLocked.center;
    
    // - now hide the originals temporarily.
    vwAuthorize.hidden = YES;
    vwLocked.hidden    = YES;
    
    // ...and add the snapshots so that the locked is at the back and facing away.
    vwSnapLock.layer.doubleSided = NO;
    [self.view addSubview:vwSnapLock];
    vwSnapAuth.layer.doubleSided = NO;
    [self.view addSubview:vwSnapAuth];
    
    // ...animate between them, restoring the original locked screen when the animation completes.
    [CATransaction begin];
    [CATransaction setAnimationDuration:0.35f];
    
    [CATransaction setCompletionBlock:^(void){
        [vwSnapAuth removeFromSuperview];
        [vwSnapLock removeFromSuperview];
        vwLocked.hidden = NO;
    }];
    
    NSValue *transformFrontFacing = [NSValue valueWithCATransform3D:CATransform3DMakeTranslation(0.0f, 0.0f, 1000.0f)];         //  move far from origin to prevent clipping
    NSValue *transformLookingBack = [NSValue valueWithCATransform3D:CATransform3DConcat(CATransform3DMakeRotation((CGFloat) M_PI, 0.0, 1.0f, 0.0f),
                                                                                        CATransform3DMakeTranslation(0.0f, 0.0f, -500.0f))];
    CABasicAnimation *ba = [CABasicAnimation animationWithKeyPath:@"transform"];
    ba.fromValue         = transformLookingBack;
    ba.toValue           = transformFrontFacing;
    [vwSnapLock.layer addAnimation:ba forKey:@"transform"];
    vwSnapLock.layer.transform = [transformFrontFacing CATransform3DValue];
    
    ba = [CABasicAnimation animationWithKeyPath:@"transform"];
    ba.fromValue         = transformFrontFacing;
    ba.toValue           = transformLookingBack;
    [vwSnapAuth.layer addAnimation:ba forKey:@"transform"];
    vwSnapAuth.layer.transform = [transformLookingBack CATransform3DValue];
    
    [CATransaction commit];
    
    isLocked = YES;
}

/*
 *  The system's dynamic type sizes were changed.
 */
-(void) updateDynamicTypeNotificationReceived
{
    [self reconfigureTextItemsForDynamicTypeAsInit:NO];
}

@end

/*********************************************
 UIGenericAccessViewController (internal)
 *********************************************/
@implementation UIGenericAccessViewController (internal)
/*
 *  Assign the completion block for when access processing is done.
 */
-(void) setCompletionBlock:(genericAccessCompletion) cb
{
    if (cb != completionBlock){
        Block_release(completionBlock);
        completionBlock = nil;
        if (cb) {
            completionBlock = Block_copy(cb);
        }
    }
}


/*
 *  Return a presentation transition animation.
 */
-(id<UIViewControllerAnimatedTransitioning>) animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{
    return [[[UIGenericAccessAnimiationController alloc] init] autorelease];
}

/*
 *  Return a dismissla transition animation.
 */
-(id<UIViewControllerAnimatedTransitioning>) animationControllerForDismissedController:(UIViewController *)dismissed
{
    return [[[UIGenericAccessAnimiationController alloc] init] autorelease];
}


/*
 *  Handle the customn transition animation.
 */
-(void) animateTransitionTo:(BOOL) toAnim withDuration:(NSTimeInterval) duration withCompletion:(void(^)(void)) animCompletionBlock
{
    CGAffineTransform atTiny  = CGAffineTransformMakeScale(0.0f, 0.0f);
    CGAffineTransform at3Qtr  = CGAffineTransformMakeScale(0.75f, 0.75f);
    if (toAnim) {
        vwShadow.alpha        = 0.0f;
        vwAuthorize.alpha     = 0.0f;
        vwLocked.alpha        = 0.0f;
        vwAuthorize.transform = atTiny;
        vwLocked.transform    = atTiny;
    }
    
    [UIView animateWithDuration:duration delay:0.0f usingSpringWithDamping:0.8f initialSpringVelocity:1.0f options:UIViewAnimationOptionCurveEaseOut animations:^(void){
        if (toAnim) {
            vwShadow.alpha = 1.0f;
            vwAuthorize.transform = CGAffineTransformIdentity;
            vwAuthorize.alpha     = 1.0f;
            vwLocked.transform    = CGAffineTransformIdentity;
            vwLocked.alpha        = 1.0f;
        }
        else {
            vwShadow.alpha        = 0.0f;
            vwAuthorize.alpha     = 0.0f;
            vwLocked.alpha        = 0.0f;
            vwAuthorize.transform = at3Qtr;
            vwLocked.transform    = at3Qtr;
        }
    } completion:^(BOOL finished){
        if (animCompletionBlock) {
            animCompletionBlock();
        }
    }];    
}

/*
 *  Show/hide the dialogs based on access.
 */
-(void) displayAppropriateSubdialogForAccess
{
    BOOL showLocked = NO;
    if (self.delegate && [self.delegate respondsToSelector:@selector(accessViewControllerShouldShowLockedOnStartup:)]) {
        showLocked = [self.delegate accessViewControllerShouldShowLockedOnStartup:self];
    }

    isLocked           = showLocked;
    vwAuthorize.hidden = showLocked;
    vwLocked.hidden    = !showLocked;
}

/*
 *  Create a separator image between the button and the rest of the content.
 */
-(void) assignSeparatorImage
{
    CGFloat sepHeight = CGRectGetHeight(ivAdvAuth.bounds);
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1.0f, sepHeight), NO, 0.0f);
    CGContextClearRect(UIGraphicsGetCurrentContext(), CGRectMake(0.0f, 0.0f, 1.0f, sepHeight));
    CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), [[UIColor lightGrayColor] CGColor]);
    CGContextFillRect(UIGraphicsGetCurrentContext(), CGRectMake(0.0f, 0.0f, 1.0f, 0.5f));
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    img = [img resizableImageWithCapInsets:UIEdgeInsetsMake(1.0f, 0.0f, sepHeight - 1.0f, 0.0f)];
    UIGraphicsEndImageContext();
    
    ivAdvAuth.image = img;
    ivAdvLock.image = img;
}

/*
 *  Reconfigure the the text items to make them size with dynamic type changes.
 */
-(void) reconfigureTextItemsForDynamicTypeAsInit:(BOOL) isInit
{
    // - this wasn't the norm before 8.0 so I won't do it there.
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        return;
    }
    
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lAuthTitle withPreferredSettingsAndTextStyle:UIFontTextStyleHeadline andMinimumSize:19.0f duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lAuthDesc withPreferredSettingsAndTextStyle:UIFontTextStyleSubheadline andMinimumSize:17.0f duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lLockedTitle withPreferredSettingsAndTextStyle:UIFontTextStyleHeadline andMinimumSize:19.0f duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lLockedDesc withPreferredSettingsAndTextStyle:UIFontTextStyleSubheadline andMinimumSize:17.0f duringInitialization:isInit];

    [UIAdvancedSelfSizingTools constrainTextButton:self.bAuthorize withPreferredSettingsAndTextStyle:UIFontTextStyleBody andMinimumSize:[ChatSeal minimumButtonFontSize] duringInitialization:isInit];
    
    // ...OK must be a bold version of the standard font.
    self.bOK.titleLabel.font = [UIFont boldSystemFontOfSize:self.bAuthorize.titleLabel.font.pointSize];
    [self.bOK.titleLabel invalidateIntrinsicContentSize];
}

@end

/*********************************************
 UIGenericAccessAnimiationController
 *********************************************/
@implementation UIGenericAccessAnimiationController
/*
 *  Return the duration of the transition.
 */
-(NSTimeInterval) transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext
{
    UIViewController *vcTo   = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    if ([vcTo isKindOfClass:[UIGenericAccessViewController class]]) {
        return 0.5f;
    }
    else {
        return 0.8f;
    }
}

/*
 *  Animate the transition to/from the photo access view controller.
 */
-(void) animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    UIViewController *vcFrom = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *vcTo   = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIView *vwTo             = nil;
    if ([ChatSeal isIOSVersionBEFORE8]) {
        vwTo                 = vcTo.view;
    }
    else {
        vwTo                 = [transitionContext viewForKey:UITransitionContextToViewKey];
    }
    
    // - we're either movint to or from the photo access controller.
    BOOL isTo = NO;
    if ([vcTo isKindOfClass:[UIGenericAccessViewController class]]) {
        [[transitionContext containerView] addSubview:vwTo];
        vwTo.frame                                     = [transitionContext containerView].bounds;
        vwTo.autoresizingMask                          = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        vwTo.translatesAutoresizingMaskIntoConstraints = YES;
        isTo                                           = YES;
    }
    else {
        // - we've already been placed on top, so no need to insert sub-views any more.
        vwTo.frame = [transitionContext finalFrameForViewController:vcTo];
    }
    
    // - perform the animation from/to the view controller
    [(UIGenericAccessViewController *) (isTo ? vcTo : vcFrom) animateTransitionTo:isTo withDuration:[self transitionDuration:transitionContext] withCompletion:^(void){
        [transitionContext completeTransition:YES];
    }];
    
}

@end

