//
//  UICleanCameraButtonV2.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/2/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "UICleanCameraButtonV2.h"
#import "ChatSeal.h"

// - constants
static const CGFloat UICCB_RING_WIDTH   = 6.0f;
static const CGFloat UICCB_NEGATE_WIDTH = 2.0f;
static const CGFloat UICCB_STD_SPACER   = 2.0f;

// - forward declarations
@interface UICleanCameraButtonV2 (internal)
-(void) bestCircleForView:(UIView *) vw;
-(void) setCenterDisabledMaskOn:(BOOL) isEnabled;
@end

/**************************
 UICleanCameraButtonV2
 **************************/
@implementation UICleanCameraButtonV2
/*
 *  Object attributes.
 */
{
    UIView          *vwCenter;
    UIImageView     *ivCamera;
    BOOL            useMask;
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        useMask                         = NO;
        self.backgroundColor            = [UIColor blackColor];
        self.layer.borderWidth          = UICCB_RING_WIDTH;
        vwCenter                        = [[UIView alloc] init];
        vwCenter.userInteractionEnabled = NO;
        [self addSubview:vwCenter];
        ivCamera                        = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"714-camera.png"]];
        ivCamera.userInteractionEnabled = NO;
        ivCamera.alpha                  = 0.0f;
        [self addSubview:ivCamera];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [vwCenter release];
    vwCenter = nil;
    
    [ivCamera release];
    ivCamera = nil;
    
    [super dealloc];
}

/*
 *  Do layout.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    // - change color depending on state.
    if (self.state == UIControlStateDisabled) {
        self.layer.borderColor   = [[UIColor lightGrayColor] CGColor];
        vwCenter.backgroundColor = [UIColor lightGrayColor];
    }
    else {
        self.layer.borderColor   = [[UIColor whiteColor] CGColor];
        if (self.state == UIControlStateHighlighted) {
            vwCenter.backgroundColor = [UIColor colorWithRed:51.0f/255.0f green:51.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
        }
        else {
            vwCenter.backgroundColor = [UIColor whiteColor];
        }
    }
    
    // - now size the elements
    vwCenter.frame = CGRectInset(self.bounds, UICCB_RING_WIDTH + UICCB_STD_SPACER, UICCB_RING_WIDTH + UICCB_STD_SPACER);
    ivCamera.bounds = CGRectMake(0.0f, 0.0f, ivCamera.image.size.width, ivCamera.image.size.height);
    ivCamera.center = vwCenter.center;
    
    // - we don't always show this button with a mask applied because most of the time it moves between enabled and
    //   disabled a lot.
    if (useMask) {
        [self setCenterDisabledMaskOn:YES];
    }
    else {
        [self setCenterDisabledMaskOn:NO];
    }
    
    // - and apply the corner radii
    [self bestCircleForView:self];
    [self bestCircleForView:vwCenter];
}

/*
 *  Change the icon on the button to reflect what is possible with it.
 */
-(void) setCameraActive:(BOOL) cameraIsActive
{
    CGFloat newAlpha = 0.0f;
    if (cameraIsActive) {
        newAlpha = 1.0f;
    }
    [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
        ivCamera.alpha = newAlpha;
    }];
}

/*
 *  Turn the unavailable mask support on/off to show when the button is not intended to work at all.
 */
-(void) setUnavailableMaskEnabled:(BOOL) isEnabled
{
    if (useMask != isEnabled) {
        useMask = isEnabled;
        
        UIView *vwSnap = [self snapshotViewAfterScreenUpdates:YES];
        [self addSubview:vwSnap];
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            vwSnap.alpha = 0.0f;
        } completion:^(BOOL finished) {
            [vwSnap removeFromSuperview];
        }];
        [self setNeedsLayout];
    }
}

@end


/********************************
 UICleanCameraButtonV2 (internal)
 ********************************/
@implementation UICleanCameraButtonV2 (internal)
/*
 *  Add the best corner radius possible for the given view.
 */
-(void) bestCircleForView:(UIView *) vw
{
    CGSize sz = vw.bounds.size;
    CGFloat side = 0.0f;
    if (sz.width < sz.height) {
        side = sz.width;
    }
    else {
        side = sz.height;
    }
    vw.layer.cornerRadius = side/2.0f;
}

/*
 *  Apply a custom mask to show that the center button is disabled.
 */
-(void) setCenterDisabledMaskOn:(BOOL) isEnabled
{
    if (isEnabled) {
        CGRect rcBounds = vwCenter.bounds;
        
        if (vwCenter.layer.mask || CGRectGetHeight(rcBounds) < 1.0f) {
            return;
        }
        
        CALayer *lMask      = [[[CALayer alloc] init] autorelease];
        lMask.frame         = vwCenter.bounds;
        lMask.contentsScale = [UIScreen mainScreen].scale;
        vwCenter.layer.mask = lMask;
        
        UIGraphicsBeginImageContextWithOptions(rcBounds.size, NO, 0.0f);
        CGContextSetBlendMode(UIGraphicsGetCurrentContext(), kCGBlendModeCopy);
        [[UIColor whiteColor] setFill];
        UIRectFill(rcBounds);
        
        CGFloat width  = CGRectGetWidth(rcBounds);
        CGFloat height = CGRectGetHeight(rcBounds);
        CGContextTranslateCTM(UIGraphicsGetCurrentContext(), width/2.0f, height/2.0f);
        CGContextRotateCTM(UIGraphicsGetCurrentContext(), (CGFloat)(M_PI/4.0));
        CGContextTranslateCTM(UIGraphicsGetCurrentContext(), -width/2.0f, -height/2.0f);
        
        [[UIColor colorWithWhite:1.0f alpha:0.1f] setFill];
        CGRect rcNegate = CGRectMake(width/2.0f - (UICCB_NEGATE_WIDTH/2.0f), 0.0f, UICCB_NEGATE_WIDTH, height);
        UIRectFill(rcNegate);
        
        UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
        lMask.contents = (id) [img CGImage];
        UIGraphicsEndImageContext();
    }
    else {
        vwCenter.layer.mask = nil;
    }
}
@end