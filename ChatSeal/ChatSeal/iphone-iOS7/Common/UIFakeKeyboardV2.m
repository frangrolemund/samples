//
//  UIFakeKeyboardV2.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/30/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UIFakeKeyboardV2.h"
#import "ChatSeal.h"
#import "UIImageGeneration.h"
#import "AppDelegateV2.h"

// - constants
static NSString *UIFK_STD_KEYBOARD_WINCLASS = @"UITextEffectsWindow";
static NSString *UIFK_STD_IOS_KB_CONTCLASS  = @"ContainerView";
static NSString *UIFK_STD_IOS_KB_VIEWCLASS  = @"HostView";


// - the fake keyboard is managed entirely by a single
//   view controller in the global window.
@interface UIFakeKeyboardV2ViewController : UIViewController
-(void) setKeyboardMaskingEnabled:(BOOL) isEnabled;
-(void) processKeyboardNotification:(NSNotification *) notification;
-(void) setKeyboardEffectImage:(UIImage *) img;
-(UIImage *) currentKeyboardEffectImage;
-(void) setKeyboardVisible:(BOOL) isVisible;
-(CGSize) keyboardSize;
-(UIView *) keyboardSnapshot;
-(BOOL) verifySnapshotIsReady;
-(BOOL) saveAKeyboardSnapshotUnconditionally:(BOOL) snapUnconditionally;
-(void) applyObscuringMask:(BOOL) maskOn toWindow:(UIWindow *) win;
@end

// - local data
static UIWindow *winFakeKB = nil;

/**********************
 UIFakeKeyboardV2
 **********************/
@implementation UIFakeKeyboardV2
/*
 *  Return the application window.
 */
+(UIWindow *) appWindow
{
    AppDelegateV2 *appD = (AppDelegateV2 *)[UIApplication sharedApplication].delegate;
    return [[appD.window retain] autorelease];
}

/*
 *  The view controller for the global fake keyboard window.
 */
+(UIFakeKeyboardV2ViewController *) kbViewController
{
    // - if the fake keyboard doesn't exist yet, we need to create one.
    if (!winFakeKB) {
        winFakeKB                          = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        winFakeKB.windowLevel              = 1000.0f;
        winFakeKB.userInteractionEnabled   = NO;
        UIFakeKeyboardV2ViewController *vc = [[UIFakeKeyboardV2ViewController alloc] init];
        vc.view.backgroundColor            = [UIColor clearColor];
        winFakeKB.rootViewController       = vc;
        [vc release];
        
        [winFakeKB makeKeyAndVisible];                            // add the new one to the array.
        [[UIFakeKeyboardV2 appWindow] makeKeyAndVisible];         // but restore the prior state.
    }
    
    return (UIFakeKeyboardV2ViewController *) [winFakeKB rootViewController];
}

/*
 *  Enable/disable the masking of the real keyboard.
 */
+(void) setKeyboardMaskingEnabled:(BOOL) isEnabled
{
    if ([[NSThread currentThread] isEqual:[NSThread mainThread]]) {
        if (isEnabled || winFakeKB) {
            [[UIFakeKeyboardV2 kbViewController] setKeyboardMaskingEnabled:isEnabled];
        }
    }
    else {
        NSLog(@"CS-ALERT: The fake keyboard is being used from a background thread.");
    }
}

/*
 *  Append a keyboard effect to the background, if applicable.
 */
+(void) updateKeyboardEffectFromView:(UIView *) vw
{
    UIImage *img = [UIImageGeneration imageFromView:vw withScale:1.0f];
    img          = [ChatSeal generateFrostedImageOfType:CS_FS_LIGHT fromImage:img atScale:1.0f];
    [[UIFakeKeyboardV2 kbViewController] setKeyboardEffectImage:img];
}

/*
 *  Return the current image used for generating the frosted keyboard effect.
 */
+(UIImage *) currentKeyboardEffectImage
{
    return [[UIFakeKeyboardV2 kbViewController] currentKeyboardEffectImage];
}

/*
 *  Show/hide the fake keyboard.
 */
+(void) setKeyboardVisible:(BOOL) isVisible
{
    [[UIFakeKeyboardV2 kbViewController] setKeyboardVisible:isVisible];
}

/*
 *  Return the size of the fake keyboard.
 */
+(CGSize) keyboardSize
{
    return [[UIFakeKeyboardV2 kbViewController] keyboardSize];
}

/*
 *  Return a snapshot of the current keyboard.
 */
+(UIView *) keyboardSnapshot
{
    return [[UIFakeKeyboardV2 kbViewController] keyboardSnapshot];
}

/*
 *  Verify that the fake keyboard has an up to date snapshot.
 *  - this is included because it is a mistake to ever generate snapshots in response 
 *    to rotation events because they will delay the animation enough to cause the default
 *    goofy rotation shift to occur.  It is much better to verify the fake keyboard right before
 *    it will be made visible in a subsequent animation block.
 */
+(BOOL) verifySnapshotIsReady
{
    return [[UIFakeKeyboardV2 kbViewController] verifySnapshotIsReady];
}

/*
 *  In order to guarantee we have an accurate screenshot of the keyboard, this routine will force it
 *  to be recreated.
 */
+(void) forceAKeyboardSnapshotUpdate
{
    [[UIFakeKeyboardV2 kbViewController] saveAKeyboardSnapshotUnconditionally:YES];
}

@end

/******************************
 UIFakeKeyboardV2ViewController
 ******************************/
@implementation UIFakeKeyboardV2ViewController
/*
 *  Object attributes.
 */
{
    BOOL        isMaskingOn;
    UIView      *vwContainer;
    UIView      *vwSnapshot;
    UIView      *vwSnapshotClipView;
    UIImageView *ivClipBackground;
    BOOL        isKeyboardVisible;
    UIView      *vwKeyboardMask;
    BOOL        isRealKeyboardHiding;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        isMaskingOn           = NO;
        vwSnapshotClipView    = nil;
        ivClipBackground      = nil;
        vwSnapshot            = nil;
        isKeyboardVisible     = YES;
        vwContainer           = nil;
        vwKeyboardMask        = nil;
        isRealKeyboardHiding  = NO;
        
        // - the notifications are always on, we may just not choose to do anything with them.
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processKeyboardNotification:) name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processKeyboardNotification:) name:UIKeyboardDidShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processKeyboardNotification:) name:UIKeyboardWillHideNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processKeyboardNotification:) name:UIKeyboardDidHideNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processKeyboardNotification:) name:UIKeyboardWillChangeFrameNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processKeyboardNotification:) name:UIKeyboardWillChangeFrameNotification object:nil];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [vwSnapshot release];
    vwSnapshot = nil;
    
    [ivClipBackground release];
    ivClipBackground = nil;
    
    [vwSnapshotClipView release];
    vwSnapshotClipView = nil;
    
    [vwContainer release];
    vwContainer = nil;
    
    [vwKeyboardMask release];
    vwKeyboardMask = nil;
    
    [super dealloc];
}

/*
 *  Configure the view.
 */
-(void) viewDidLoad
{
    [super viewDidLoad];
    
    // - top-level view controllers don't modify their bounds during rotations, so I'm
    //   creating a container in here that will be adjusted automatically to ensure we
    //   can always get accurate dimensions.
    vwContainer                  = [[UIView alloc] initWithFrame:self.view.bounds];
    vwContainer.backgroundColor  = [UIColor clearColor];
    vwContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:vwContainer];
    
    // - the snapshot clipping view ensures all we see is the keyboard and nothing else.
    vwSnapshotClipView                = [[UIView alloc] initWithFrame:CGRectZero];
    vwSnapshotClipView.clipsToBounds  = YES;
    ivClipBackground                  = [[UIImageView alloc] initWithFrame:CGRectZero];
    ivClipBackground.backgroundColor  = [UIColor whiteColor];
    ivClipBackground.contentMode      = UIViewContentModeBottom;
    [vwSnapshotClipView addSubview:ivClipBackground];
    [vwContainer addSubview:vwSnapshotClipView];
    
    // - we're going to use standard layer masking to cause the keyboard to not be shown.
    vwKeyboardMask = [[UIView alloc] init];
    vwKeyboardMask.backgroundColor = [UIColor clearColor];
}

/*
 *  Position the clipping view.
 */
-(void) layoutClipView
{
    // - compute the dimensions of the keyboard.
    CGSize tmpKBSize = CGSizeZero;
    CGFloat snapHeight = CGRectGetHeight(vwSnapshot.bounds);
    for (UIView *vw in vwSnapshot.subviews) {
        CGFloat reqHeight = snapHeight - CGRectGetMinY(vw.frame);
        if (reqHeight > tmpKBSize.height) {
            tmpKBSize.height = reqHeight;
        }
        
        if (CGRectGetMaxX(vw.frame) > tmpKBSize.width) {
            tmpKBSize.width = CGRectGetMaxX(vw.frame);
        }
    }
    
    // - now lay out the clipping view so that it is at the bottom of this view.
    CGRect rcKBFrame = CGRectMake((CGRectGetWidth(vwContainer.bounds)-tmpKBSize.width)/2.0f, CGRectGetHeight(vwContainer.bounds)-tmpKBSize.height, tmpKBSize.width, tmpKBSize.height);
    if (!isKeyboardVisible) {
        rcKBFrame = CGRectOffset(rcKBFrame, 0.0f, tmpKBSize.height);
    }
    vwSnapshotClipView.frame = rcKBFrame;
    ivClipBackground.frame   = vwSnapshotClipView.bounds;
    vwSnapshot.center        = CGPointMake(tmpKBSize.width/2.0f, tmpKBSize.height - (CGRectGetHeight(vwSnapshot.bounds)/2.0f));
}

/*
 *  Adjust the clipping rectangle.
 */
-(void) viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self layoutClipView];
}


/*
 *  Detach the active snapshot.
 */
-(void) releaseTheCurrentSnapshot
{
    [vwSnapshot removeFromSuperview];
    [vwSnapshot release];
    vwSnapshot             = nil;
}

/*
 *  Hide the fake keyboard during rotations or it will confuse things.
 */
-(void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self releaseTheCurrentSnapshot];
    winFakeKB.hidden       = YES;
}

/*
 *  Re-show the keyboard after rotations.
 */
-(void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    winFakeKB.hidden = NO;
    [[UIFakeKeyboardV2 appWindow] makeKeyAndVisible];         // ensure the main app window is key, however.
}

/*
 *  Whenever the windows' alpha value is changed, there may be a frame between when 
 *  when one is hidden and the other is presented.  Therefore we always delay
 *  the hiding process until we know the other has had a chance to be shown.
 */
-(void) delayedHideOfActiveKeyboard
{
    if (isMaskingOn) {
        [self applyObscuringMask:YES toWindow:[self currentKeyboard]];
    }
    else {
        self.view.hidden = YES;
    }
}

/*
 *  Enable/disable the masking of the real keyboard.
 */
-(void) setKeyboardMaskingEnabled:(BOOL)isEnabled
{
    isMaskingOn      = isEnabled;
    
    // - don't swap over the different views while the hiding is under way.
    //   of being hidden.
    if (!isMaskingOn && isRealKeyboardHiding) {
        return;
    }
    
    // - show/hide the views.
    if (isEnabled) {
        [self setKeyboardVisible:YES];
    }
    
    // - handle enablement/visibility of the real keyboard.
    [self currentKeyboard].userInteractionEnabled = !isEnabled;
    if (isEnabled) {
        self.view.hidden = NO;
    }
    else {
        [self applyObscuringMask:NO toWindow:[self currentKeyboard]];
    }
    [self performSelector:@selector(delayedHideOfActiveKeyboard) withObject:nil afterDelay:0.05f];
}

/*
 *  Assign an effect image to the keyboard.
 */
-(void) setKeyboardEffectImage:(UIImage *) img
{
    ivClipBackground.image = img;
}

/*
 *  Return the current effect image in-use by the keyboard snapshot.
 */
-(UIImage *) currentKeyboardEffectImage
{
    return [[ivClipBackground.image retain] autorelease];
}

/*
 *  Show/hide the keyboard by moving it on/off screen.
 */
-(void) setKeyboardVisible:(BOOL) isVisible
{
    isKeyboardVisible = isVisible;
    [self saveAKeyboardSnapshotUnconditionally:NO];
    [self layoutClipView];
}

/*
 *  Return a handle to the keyboard window.
 */
-(UIWindow *) currentKeyboard
{
    for (UIWindow *win in [UIApplication sharedApplication].windows) {
        if ([NSStringFromClass(win.class) isEqualToString:UIFK_STD_KEYBOARD_WINCLASS]) {
            return win;
        }
    }
    return nil;
}

/*
 *  Determines if the the keyboard has content to snapshot.
 */
-(BOOL) keyboardHasContent
{
    if ([[[self currentKeyboard] subviews] count] > 0) {
        return YES;
    }
    return NO;
}

/*
 *  Take an accurate snapshot of the keyboard.
 */
-(UIView *) snapshotTheKeyboard
{
    if (![self keyboardHasContent]) {
        return nil;
    }
    
    UIWindow *win = [self currentKeyboard];
    CGFloat  tmpA = win.alpha;
    BOOL     tmpH = win.hidden;
    BOOL tmpMask  = isMaskingOn;
    
    //  - make sure visibility is never a reason for a screen shot to be missed.
    win.alpha = 1.0f;
    win.hidden = NO;
    [self applyObscuringMask:NO toWindow:win];
    
    UIView *ret = [[[UIView alloc] initWithFrame:win.bounds] autorelease];
    
    // - With the ugprades in iOS8, we need to be a bit more specific about the exact location
    //   of the views we intend to snapshot, hence the string searches below.
    // - we can't snapshot the window because it is potentially animating the sub-views and they
    //   may be partially captured.
    for (UIView *vw in win.subviews) {
        UIView *vwSnap = nil;
        NSRange rText;
        if ([ChatSeal isIOSVersionBEFORE8]) {
            // - in iOS7 there is a single view that has the right dimensions right under the
            //   owning window.
            rText = [NSStringFromClass([vw class]) rangeOfString:UIFK_STD_IOS_KB_VIEWCLASS];
            if (rText.location != NSNotFound) {
                vwSnap       = [vw snapshotViewAfterScreenUpdates:NO];
                vwSnap.frame = vw.frame;
                [ret addSubview:vwSnap];
            }
        }
        else {
            // - in iOS8, we need to dig a bit deeper.
            rText = [NSStringFromClass([vw class]) rangeOfString:UIFK_STD_IOS_KB_CONTCLASS];
            if (rText.location != NSNotFound && vw.subviews.count) {
                for (UIView *vwSub in vw.subviews) {
                    rText = [NSStringFromClass([vwSub class]) rangeOfString:UIFK_STD_IOS_KB_VIEWCLASS];
                    if (rText.location != NSNotFound) {
                        vwSnap       = [vwSub snapshotViewAfterScreenUpdates:NO];
                        vwSnap.frame = vwSub.frame;
                        [ret addSubview:vwSnap];
                        break;
                    }
                }
            }
        }
    }
    
    if (tmpMask) {
        [self applyObscuringMask:YES toWindow:win];
    }
    win.alpha  = tmpA;
    win.hidden = tmpH;
    
    return ret;
}

/*
 *  Replace the existing keyboard snapshot.
 */
-(BOOL) saveAKeyboardSnapshotUnconditionally:(BOOL) snapUnconditionally
{
    // - determine if we already have a snapshot that
    //   matches the current keyboard to save on needless
    //   processing.
    if (!snapUnconditionally) {
        UIWindow *win = [self currentKeyboard];
        if ((int) CGRectGetWidth(win.bounds) == (int) CGRectGetWidth(vwSnapshot.bounds)) {
            return YES;
        }
    }
    
    [self releaseTheCurrentSnapshot];
    vwSnapshot = [[self snapshotTheKeyboard] retain];
    if (vwSnapshot) {
        [vwSnapshotClipView addSubview:vwSnapshot];
        [self layoutClipView];
        return YES;
    }
    else {
        NSLog(@"CS: Failed to snapshot the kb.");
    }
    return NO;
}

/*
 *  Generic processing routine for keeping the real keyboard occupied
 */
-(void) processKeyboardNotification:(NSNotification *) notification
{
    // - there is a special case where we don't want to turn off masking while
    //   the keyboard is hiding.
    if ([notification.name isEqualToString:UIKeyboardWillHideNotification]) {
        isRealKeyboardHiding = YES;
    }
    else {
        BOOL wasHiding       = isRealKeyboardHiding;
        isRealKeyboardHiding = NO;
        if (wasHiding && !isMaskingOn) {
            // - we need to re-run this method because it was ignored while the keyboard was being
            //   moved.
            [self setKeyboardMaskingEnabled:NO];
        }
    }
    
    // - the alpha on the keyboard will change between notifications, so make sure it is always kept up to date.
    if (isMaskingOn || isRealKeyboardHiding) {
        [self applyObscuringMask:YES toWindow:[self currentKeyboard]];
    }
}

/*
 *  Return the size of the fake keyboard.
 */
-(CGSize) keyboardSize
{
    return vwSnapshotClipView.bounds.size;
}

/*
 *  Return a copy of the active fake keyboard view.
 */
-(UIView *) keyboardSnapshot
{
    return [vwSnapshotClipView snapshotViewAfterScreenUpdates:YES];
}

/*
 *  Verify the snapshot is ready for use.
 */
-(BOOL) verifySnapshotIsReady
{
    return [self saveAKeyboardSnapshotUnconditionally:NO];
}

/*
 *  Turn the keyboard mask
 */
-(void) applyObscuringMask:(BOOL) maskOn toWindow:(UIWindow *) win
{
    if (maskOn) {
        if (!win.layer.mask) {
            win.layer.mask = vwKeyboardMask.layer;
        }
        vwKeyboardMask.layer.frame = win.layer.bounds;
    }
    else {
        win.layer.mask = nil;
    }
}

@end