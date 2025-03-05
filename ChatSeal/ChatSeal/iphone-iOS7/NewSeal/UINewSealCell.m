//
//  UINewSealCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/6/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "UINewSealCell.h"
#import "UISealClippingContainer.h"
#import "ChatSeal.h"

// - forward declarations
@interface UINewSealCell (internal)
-(void) commonConfiguration;
-(void) drawLockedSealImageInRect:(CGRect) rc;
@end

/*********************
 UINewSealCell
 *********************/
@implementation UINewSealCell
/*
 *  Object attributes
 */
{
    RSISecureSeal_Color_t   sealColor;
    UISealWaxViewV2         *swvFront;
    BOOL                    sealIsVisible;
    UISealClippingContainer *sccSealView;
    CGFloat                 currentRotation;
    CGFloat                 centerRotation;
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
 *  Initialize the object.
 */
-(id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
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
    [swvFront release];
    swvFront = nil;
    
    [sccSealView release];
    sccSealView = nil;

    [super dealloc];
}

/*
 *  Set the color of the seal wax.
 */
-(void) setSealColor:(RSISecureSeal_Color_t) color
{
    sealColor = color;
    
    [swvFront removeFromSuperview];
    [swvFront release];
    swvFront = nil;
    
    swvFront = [[ChatSeal sealWaxInForeground:YES andColor:color] retain];
    if (swvFront) {
        swvFront.frame = self.bounds;
        [self.contentView addSubview:swvFront];
        swvFront.layer.zPosition = 10.0f;
    }
    sccSealView.layer.zPosition = 0.0f;
}

/*
 *  Return the current seal color.
 */
-(RSISecureSeal_Color_t) sealColor
{
    return sealColor;
}

/*
 *  Configure the enclosed seal image view according to what exists
 *  elsewhere.
 */
-(void) configureSealImageFromView:(UISealImageViewV2 *) sealImageView
{
    [sccSealView copyAllAttributesFromSealView:sealImageView];
}

/*
 *  Assign the image to the seal.
 */
-(void) setSealImage:(UIImage *) image
{
    [sccSealView setSealImage:image];
}

/*
 *  Show/hide the seal image.
 */
-(void) setSealImageVisible:(BOOL) isVisible
{
    if (isVisible) {
        sccSealView.alpha = 1.0f;
    }
    else {
        sccSealView.alpha = 0.0f;
    }
    sealIsVisible = isVisible;
}

/*
 *  Layout the views.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    swvFront.frame = self.bounds;
    sccSealView.frame = self.bounds;
    [CATransaction commit];
    
    // - make sure that the animations are coordinated.
    // - NOTE: I learned through a long process of investigation that the primary
    //   issue here is that the masks on the wax layers are not animated in time with
    //   their superlayer.   In order to coordinate this from one place, I've decided
    //   to do everything here.  The main item to coordinate is the wax, although we need to
    //   also deal with the photo also.
    CAAnimation *anim = [ChatSeal boundsAnimationForLayer:self.layer];
    if (anim) {
        [swvFront layoutIfNeeded];
        [swvFront coordinateMaskSizingWithBoundsAnimation:anim];
        [sccSealView layoutIfNeeded];
        [sccSealView coordinateSizingWithBoundsAnimation:anim];
    }
}

/*
 *  Lock/unlock the seal.
 */
-(void) setLocked:(BOOL) isLocked
{
    [swvFront setLocked:isLocked];
}

/*
 *  This will show/hide all the contents.
 */
-(void) setAllContentsVisible:(BOOL) isVisible withAnimation:(BOOL) animated
{
    CGFloat displayAlpha = 1.0f;
    if (!isVisible) {
        displayAlpha = 0.0f;
    }

    CGFloat sealAlpha = displayAlpha;
    if (!sealIsVisible) {
        sealAlpha = 0.0f;
    }
    
    void (^displayContents)(void) = ^(void) {
        sccSealView.alpha = sealAlpha;
        swvFront.alpha  = displayAlpha;
    };
    
    void (^unhideItems)() = ^() {
        sccSealView.hidden = !isVisible;
        swvFront.hidden    = !isVisible;
    };
    
    if (animated) {
        [CATransaction begin];
        [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
        if (isVisible) {
            unhideItems();
        }
        else {
            [CATransaction setCompletionBlock:^(void){
                unhideItems();
            }];
        }
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            displayContents();
        }];
        [CATransaction commit];
    }
    else {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        displayContents();
        unhideItems();
        [CATransaction commit];
    }
}

/*
 *  Turn the no-photo text on/off
 */
-(void) setNoPhotoVisible:(BOOL) isVisible withAnimation:(BOOL)animated
{
    [sccSealView setNoPhotoVisible:isVisible withAnimation:animated];
}

/*
 *  Adjust the rotation for the object.
 */
-(void) applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    self.transform = CGAffineTransformMakeRotation(currentRotation);
    
    CGFloat trueCenterRotation = centerRotation - currentRotation;
    sccSealView.transform = CGAffineTransformMakeRotation(trueCenterRotation);
}

/*
 *  Assign the current rotation because the layout caches the attributes.
 */
-(void) setCurrentRotation:(CGFloat) rotation
{
    [self setCurrentRotation:rotation andCenterRotation:rotation];
}

/*
 *  Set the position of the center area, but not relative to the overall rotation of
 *  this object.
 */
-(void) setCenterRotation:(CGFloat) rotation
{
    [self setCurrentRotation:currentRotation andCenterRotation:rotation];
}

/*
 *  Set the current rotation and the center.
 */
-(void) setCurrentRotation:(CGFloat)rotation andCenterRotation:(CGFloat) newCenter
{
    currentRotation = rotation;
    centerRotation  = newCenter;
    [self applyLayoutAttributes:nil];
}

/*
 *  When we know that this will be shown very small, it is important to add a couple
 *  extra configuration options that aren't usually in effect.
 */
-(void) prepareForSmallDisplay
{
    [swvFront prepareForSmallDisplay];
}

/*
 *  Start the gloss animation.
 */
-(void) triggerGlossEffect
{
    [sccSealView triggerGlossEffect];
}

/*
 *  Turn the center ring on/off.
 */
-(void) setCenterRingVisible:(BOOL) isVisible
{
    [swvFront setCenterVisible:isVisible];
}

/*
 *  Draw the current cell in the current context for the purposes of creating a 
 *  stock decoy image.
 */
-(void) drawCellForDecoyInRect:(CGRect) rc
{
    CGContextSaveGState(UIGraphicsGetCurrentContext());
    
    // - draw the seal image.
    CGContextSaveGState(UIGraphicsGetCurrentContext());
    CGContextBeginPath(UIGraphicsGetCurrentContext());
    CGFloat diam       = [UISealWaxViewV2 centerDiameterFromRect:rc] - 2.0f;        // -2.0 so the ring overlays.
    CGRect rcSealImage = CGRectIntegral(CGRectInset(rc, (CGRectGetWidth(rc) - diam)/2.0f, (CGRectGetHeight(rc)-diam)/2.0f));
    CGContextAddEllipseInRect(UIGraphicsGetCurrentContext(), rcSealImage);
    CGContextClip(UIGraphicsGetCurrentContext());
    UIImage *img  = [sccSealView sealImage];
    if (img) {
        // - the seal image is actually inset more than in the real view, but I sort of
        //   like how that animates when I tap on the message because it appears the button
        //   pops up.
        // - I spent my time tracking this down and found that I could expand this image and minimize most of that
        //   effect, but there is always a small bit of rounding that will occur due to the fact that there are two different
        //   approaches to showing that image.   Rather than make it close but not quite perfect, which will appear to be a mistake,
        //   I'm going to adapt the design so that it capitalizes on that behavior.
        [img drawInRect:rcSealImage blendMode:kCGBlendModeNormal alpha:1.0f];
    }
    else {
        // - when drawing the locked version, we draw a white background to make the fade
        //   nicer when moving from locked to unlocked in the overview.
        [[UIColor whiteColor] setFill];
        CGContextFillEllipseInRect(UIGraphicsGetCurrentContext(), rc);
        
        [self drawLockedSealImageInRect:rcSealImage];
    }
    CGContextRestoreGState(UIGraphicsGetCurrentContext());
    
    // - draw the foreground.
    [swvFront drawForDecoyRect:rc];
    
    CGContextRestoreGState(UIGraphicsGetCurrentContext());
}

/*
 *  A dynamic type update was received.
 */
-(void) updateDynamicTypeNotificationReceived
{
    [sccSealView updateDynamicTypeNotificationReceived];
}

/*
 *  There are times where a simpler approach to displaying the seal image is desired, particularly
 *  when animation is involved.  This will ensure that the more complex transforms of the seal editor
 *  aren't used.
 */
-(void) flagAsSimpleImageDisplayOnly
{
    [sccSealView convertToSimpleDisplay];
}

@end


/*************************
 UINewSealCell (internal)
 *************************/
@implementation UINewSealCell (internal)
/*
 *  Configure the cell.
 */
-(void) commonConfiguration
{
    self.clipsToBounds   = NO;              //  so the shadow on the wax isn't clipped.
    sealColor            = RSSC_INVALID;
    sealIsVisible        = YES;
    self.backgroundColor = [UIColor clearColor];
    currentRotation      = 0.0f;
    centerRotation       = 0.0f;
    
    sccSealView = [[UISealClippingContainer alloc] initWithFrame:self.bounds];
    [sccSealView hitClipToInsideWax];
    [self.contentView addSubview:sccSealView];
}

/*
 *  Draw the seal image that is used when a seal doesn't exist and we're trying to
 *  label this as locked.
 */
-(void) drawLockedSealImageInRect:(CGRect) rc
{
    // - the lock was created on a 50x50 canvas, so we need to translate in order to get the
    //   right effect.
    CGContextSaveGState(UIGraphicsGetCurrentContext());
    
    /// Color Declarations
    UIColor* commonColor = [ChatSeal defaultInvalidSealColor];
    CGFloat canvasScale  = CGRectGetWidth(rc) / 50.0f;
    CGFloat lineWidth    = 1.0f / [UIScreen mainScreen].scale;  //(1.0f / [UIScreen mainScreen].scale)*(1/canvasScale);            // increase the line width to compensate for the scaling.
    
    CGContextTranslateCTM(UIGraphicsGetCurrentContext(), rc.origin.x, rc.origin.y);
    CGContextScaleCTM(UIGraphicsGetCurrentContext(), canvasScale, canvasScale);
    
    //// Rounded Rectangle 3 Drawing
    UIBezierPath* roundedRectangle3Path = [UIBezierPath bezierPathWithRoundedRect: CGRectMake(13.5, 21.5, 23, 18) cornerRadius: 3];
    [commonColor setStroke];
    roundedRectangle3Path.lineWidth = lineWidth * 1.75f;
    [roundedRectangle3Path stroke];
    
    
    //// Bezier Drawing
    UIBezierPath* bezierPath = [UIBezierPath bezierPath];
    [bezierPath moveToPoint: CGPointMake(33, 17.15f)];
    [bezierPath addLineToPoint: CGPointMake(33, 21.31f)];
    [bezierPath addLineToPoint: CGPointMake(33, 22)];
    [bezierPath addLineToPoint: CGPointMake(32.43f, 22)];
    [bezierPath addLineToPoint: CGPointMake(17.57f, 22)];
    [bezierPath addLineToPoint: CGPointMake(17, 22)];
    [bezierPath addLineToPoint: CGPointMake(17, 21.31f)];
    [bezierPath addLineToPoint: CGPointMake(17, 17.15f)];
    [bezierPath addCurveToPoint: CGPointMake(22.14f, 10) controlPoint1: CGPointMake(17, 13.71f) controlPoint2: CGPointMake(19.53f, 10.8f)];
    [bezierPath addLineToPoint: CGPointMake(27.86f, 10)];
    [bezierPath addCurveToPoint: CGPointMake(33, 17.15f) controlPoint1: CGPointMake(30.78f, 10.52f) controlPoint2: CGPointMake(33, 13.71f)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(32, 17)];
    [bezierPath addCurveToPoint: CGPointMake(28, 11) controlPoint1: CGPointMake(31.74f, 14.54f) controlPoint2: CGPointMake(30.27f, 11.57f)];
    [bezierPath addLineToPoint: CGPointMake(22, 11)];
    [bezierPath addCurveToPoint: CGPointMake(18.14f, 17.15f) controlPoint1: CGPointMake(19.9f, 11.86f) controlPoint2: CGPointMake(18.14f, 14.48f)];
    [bezierPath addLineToPoint: CGPointMake(18.14f, 21.31f)];
    [bezierPath addLineToPoint: CGPointMake(18, 21)];
    [bezierPath addLineToPoint: CGPointMake(32, 21)];
    [bezierPath addLineToPoint: CGPointMake(31.86f, 21.31f)];
    [bezierPath addLineToPoint: CGPointMake(32, 17)];
    [bezierPath closePath];
    bezierPath.miterLimit = 7.5;
    
    [commonColor setFill];
    [bezierPath fill];
    
    
    //// Oval Drawing
    UIBezierPath* ovalPath = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(22, 26, 6, 6)];
    [commonColor setFill];
    [ovalPath fill];
    
    
    //// Rectangle Drawing
    UIBezierPath* rectanglePath = [UIBezierPath bezierPathWithRect: CGRectMake(24.5, 30.5, 1, 4)];
    [commonColor setFill];
    [rectanglePath fill];
    [commonColor setStroke];
    rectanglePath.lineWidth = lineWidth;
    [rectanglePath stroke];
    
    
    
    CGContextRestoreGState(UIGraphicsGetCurrentContext());
}
@end
