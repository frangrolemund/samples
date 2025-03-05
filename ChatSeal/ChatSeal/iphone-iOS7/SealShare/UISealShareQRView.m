//
//  UISealShareQRView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 2/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealShareQRView.h"
#import "ChatSeal.h"
#import "ChatSealQREncode.h"
#import "ChatSealBaseStation.h"
#import "UISealWaxViewV2.h"
#import "AlertManager.h"

// - constants
static const CGFloat UISSQ_STD_PAD_PCT = 0.05f;
static const CGFloat UISSQ_STD_PAD     = 10.0f;

// - forward declarations
@interface UISealShareQRView (internal)
+(NSTimeInterval) adjustedAnimationTimeForSealPop:(BOOL) isPopping;
-(void) commonConfiguration;
@end

/**************************
 UISealShareQRView
 **************************/
@implementation UISealShareQRView
/*
 *  Object attributes
 */
{
    BOOL        isVisible;
    UIView      *vwQRContainer;
    NSURL       *uLastCode;
    UIImageView *ivQRCode;
    UILabel     *lQRDisplayError;
}

/*
 *  Return a value indicating how long it will take before the fade processing begins so that we can coordinate
 *  with it externally.
 */
+(NSTimeInterval) timeUntilFadeBeginsForMakingVisible:(BOOL) willBeVisible
{
    if (willBeVisible) {
        return 0.0f;
    }
    else {
        return [UISealShareQRView adjustedAnimationTimeForSealPop:NO];
    }
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
    [vwQRContainer release];
    vwQRContainer = nil;
    
    [ivQRCode release];
    ivQRCode = nil;
    
    [lQRDisplayError release];
    lQRDisplayError = nil;
    
    [uLastCode release];
    uLastCode = nil;
    
    [super dealloc];
}

/*
 *  Show/hide the QR code.
 */
-(void) setQRCodeVisible:(BOOL) vis withAnimation:(BOOL) animated
{
    if (vis) {
        [self regenerateQRCode];
    }
    isVisible = vis;

    NSTimeInterval tiPopTime = [UISealShareQRView adjustedAnimationTimeForSealPop:isVisible];
    if (animated) {
        if (isVisible) {
            // - when showing the QR code, we start by fading-in so the person
            //   gets a feel for what they're seeing.
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                vwQRContainer.alpha = 1.0f;
            } completion:^(BOOL finished) {
                if (isVisible) {
                    // - now we need to pop the QR code from the center if we didn't get a conflicting request.
                    [UIView animateWithDuration:tiPopTime animations:^(void) {
                        [CATransaction begin];
                        [CATransaction setAnimationDuration:tiPopTime];
                        [CATransaction setAnimationTimingFunction:[ChatSeal standardTimingFunctionForSealPop:YES]];
                        [self setNeedsLayout];
                        [self layoutIfNeeded];
                        [CATransaction commit];
                    }];
                }
            }];
        }
        else {
            // - when hiding the QR code, we're going to reverse the animation, first un-popping it.
            [UIView animateWithDuration:tiPopTime animations:^(void) {
                [CATransaction begin];
                [CATransaction setAnimationDuration:tiPopTime];
                [CATransaction setAnimationTimingFunction:[ChatSeal standardTimingFunctionForSealPop:NO]];
                [self setNeedsLayout];
                [self layoutIfNeeded];
                [CATransaction commit];
            } completion:^(BOOL finished) {
                // - now fade-out, if we didn't get a conflicting request.
                if (!isVisible) {
                    [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                        vwQRContainer.alpha = 0.0f;
                    }];
                }
            }];
        }
    }
    else {
        vwQRContainer.alpha = isVisible ? 1.0f : 0.0f;
        [self setNeedsLayout];
        [self layoutIfNeeded];
    }
}

/*
 *  Perform layout on the view.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    // - figure out which display is going to be used here.
    CGRect rcBounds      = self.bounds;
    CGFloat targetRadius = 0.0f;
    if (isVisible) {
        vwQRContainer.frame = CGRectInset(rcBounds, CGRectGetWidth(rcBounds) * UISSQ_STD_PAD_PCT, CGRectGetHeight(rcBounds) * UISSQ_STD_PAD_PCT);
        ivQRCode.frame      = vwQRContainer.bounds;
        targetRadius        = 0.0f;
    }
    else {
        CGFloat diam   = [UISealWaxViewV2 centerDiameterFromRect:self.bounds];
        vwQRContainer.frame = CGRectMake((CGRectGetWidth(rcBounds) - diam)/2.0f, (CGRectGetHeight(rcBounds) - diam)/2.0f,
                                         diam, diam);
        ivQRCode.frame      = CGRectInset(vwQRContainer.bounds, -CGRectGetWidth(vwQRContainer.bounds)/4.0f, -CGRectGetHeight(vwQRContainer.bounds)/4.0f);
        targetRadius        = diam/2.0f;
    }
    
    // - always animate the radius because when it is visible it will always require it.
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"cornerRadius"];
    anim.duration          = [CATransaction animationDuration];
    anim.timingFunction    = [CATransaction animationTimingFunction];
    if (ivQRCode.layer.presentationLayer) {
        anim.fromValue = [NSNumber numberWithFloat:((float)((CALayer *) ivQRCode.layer.presentationLayer).cornerRadius)];
    }
    else {
        anim.fromValue = [NSNumber numberWithFloat:(float)(ivQRCode.layer.cornerRadius)];
    }
    anim.toValue = [NSNumber numberWithFloat:(float)targetRadius];
    [vwQRContainer.layer addAnimation:anim forKey:@"cornerRadius"];
    vwQRContainer.layer.cornerRadius = targetRadius;
    [CATransaction commit];
}

/*
 *  Force an immediate regeneration of the QR code.
 */
-(void) regenerateQRCode
{
    // - when the current code is visible, we need to fade it out.
    if (isVisible) {
        UIView *vwSnap          = [vwQRContainer snapshotViewAfterScreenUpdates:YES];
        vwSnap.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [vwQRContainer addSubview:vwSnap];
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            vwSnap.alpha = 0.0f;
        } completion:^(BOOL finished) {
            [vwSnap removeFromSuperview];
        }];
    }
    
    // - now regenerate the QR code.
    NSError *err = nil;
    NSURL *u     = [[ChatSeal applicationBaseStation] secureSealTransferURL];
    if (uLastCode && [uLastCode isEqual:u]) {
        return;
    }
    UIImage *img = nil;
    if (u) {
        img = [ChatSealQREncode encodeQRString:[u absoluteString]
                                      asVersion:CS_QRE_VERSION_AUTO
                                       andLevel:CS_QRE_EC_QUT
                                        andMask:CS_QRE_MP_COMPUTE
                             andTargetDimension:256.0f
                                      withError:&err];
    }
    else {
        [CS_error fillError:&err withCode:CSErrorSecureServiceNotEnabled];
    }
    
    // - when showing the item, make sure the display error is adjusted.
    if (img) {
        ivQRCode.image         = img;
        lQRDisplayError.hidden = YES;
        [uLastCode release];
        uLastCode              = [u retain];
    }
    else {
        lQRDisplayError.hidden = NO;
        NSLog(@"CS: Failed to display the QR code for sharing.  %@", [err localizedDescription]);
    }
}

@end

/*****************************
 UISealShareQRView (internal)
 *****************************/
@implementation UISealShareQRView (internal)
/*
 *  We'll adjust the pop/unpop animation time a bit for our purposes here.
 */
+(NSTimeInterval) adjustedAnimationTimeForSealPop:(BOOL) isPopping
{
    return [ChatSeal animationDurationForSealPop:isPopping] * 1.5f;
}

/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    isVisible            = NO;
    uLastCode            = nil;
    
    self.backgroundColor = [UIColor clearColor];
    
    // - we're making a container for the QR code because the code should always appear to fill the region, even
    //   when it is small and circular.
    vwQRContainer                     = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, UISSQ_STD_PAD * 4.0, UISSQ_STD_PAD * 4.0f)];
    vwQRContainer.backgroundColor     = [UIColor whiteColor];
    vwQRContainer.clipsToBounds       = YES;
    vwQRContainer.layer.borderColor   = [[UIColor blackColor] CGColor];
    CGFloat scale                     = [UIScreen mainScreen].scale;
    vwQRContainer.layer.borderWidth   = 1.0f;
    vwQRContainer.layer.shadowOpacity = 1.0f;
    vwQRContainer.layer.shadowOffset  = CGSizeMake(scale/2.0f, scale/2.0f);
    vwQRContainer.alpha               = 0.0f;
    [self addSubview:vwQRContainer];
    
    // - create a view to display the image of the QR code.
    ivQRCode             = [[UIImageView alloc] init];
    ivQRCode.contentMode = UIViewContentModeScaleAspectFit;
    [vwQRContainer addSubview:ivQRCode];
    
    // - if an error occurs, this simple label will describe it.
    lQRDisplayError                  = [[UILabel alloc] initWithFrame:CGRectInset(vwQRContainer.frame, UISSQ_STD_PAD, UISSQ_STD_PAD)];
    lQRDisplayError.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    lQRDisplayError.font             = [UIFont systemFontOfSize:17.0f];
    lQRDisplayError.textColor        = [ChatSeal defaultWarningColor];
    lQRDisplayError.textAlignment    = NSTextAlignmentCenter;
    lQRDisplayError.text             = [AlertManager standardErrorTextWithText:NSLocalizedString(@"Your %@ is unable to share your seal.", nil)];
    lQRDisplayError.hidden           = YES;
    lQRDisplayError.numberOfLines    = 0;
    [vwQRContainer addSubview:lQRDisplayError];
}
@end