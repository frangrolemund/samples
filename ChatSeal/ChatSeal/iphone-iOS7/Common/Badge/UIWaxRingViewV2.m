//
//  UIWaxRingViewV2.m
//  ChatSeal
//
//  Created by Francis Grolemund on 9/3/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIWaxRingViewV2.h"
#import "UIColorWatcherView.h"
#import "UIAlphaContext.h"
#import "UIImageGeneration.h"
#import "ChatSeal.h"

// - constants.
static const CGFloat UISRV_PCT_CENTER            = 0.7000f;
static const CGFloat UISRV_PCT_NARROW            = 0.0364f;
static const CGFloat UIWRV_HIRES_SIDE_SZ         = 256.0f;
static const CGFloat UIWRV_PAINTCODE_CANVAS_SIDE = 256.0f;
static const CGFloat UIWRV_INNER_RING_ROT        = -0.75f;
static const CGFloat UIWRV_OUTER_RING_ROT        = 0.5f;

// - locals
static UIImage *innerRingMaskImage   = nil;
static UIImage *outerRingMaskImage   = nil;

// - forward declarations
@interface UIWaxRingViewV2 (internal)
+(UIImage *) generateMaskForOuterRing:(BOOL) isOuter;
+(void) generateSharedMasks;
-(void) applyStandardMaskingToView:(UIView *) vw;
-(void) applyRingTransform;
-(void) setMaskOnLayerForRing;
-(void) drawRingForDecoyInRect:(CGRect) rc asValid:(BOOL) isValid;
+(UIBezierPath *) pathForBounds:(CGSize) szBounds asOuter:(BOOL) isOuter;
@end

/****************************
 UIWaxRingViewV2
 ****************************/
@implementation UIWaxRingViewV2
/*
 *  Object attributes.
 */
{
    BOOL          outerRing;
    UIView        *vwRing;
    BOOL          isSmall;
    BOOL          isLocked;
}

/*
 *  Pre-cache the image resources used to produce these rings.
 */
+(void) verifyResources
{
    [self generateSharedMasks];    
}

/*
 *  Return the percentage the center consumes from the overall bounds of the object.
 */
+(CGFloat) centerPercentage
{
    return UISRV_PCT_CENTER;
}

/*
 *  The percentage the narrow ring is compared to the width.
 */
+(CGFloat) narrowRingPercentage
{
    return UISRV_PCT_NARROW;
}

/*
 *  Initialize the object.
 *  - the inner ring is a wider ring and the outer is a narrow ring.
 */
-(id) initAsOuterRing:(BOOL) isOuter
{
    self = [super init];
    if (self) {
        isSmall                      = NO;
        isLocked                     = NO;
        outerRing                    = isOuter;
        vwRing                       = [[UIColorWatcherView alloc] init];
        vwRing.layer.shouldRasterize = YES;
        [self applyStandardMaskingToView:vwRing];        
        [self addSubview:vwRing];        
        
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [vwRing release];
    vwRing = nil;
    
    [super dealloc];
}
/*
 *  Assign the z position of the view.
 */
-(void) setZPosition:(CGFloat) zPosition
{
    self.layer.zPosition = zPosition;
}

/*
 *  Assign the color used for the rings.
 */
-(void) setRingColor:(UIColor *)color
{
    vwRing.backgroundColor = color;
}

/*
 *  When we set the frame on the ring, set the frame on the sub-views so that
 *  it doesn't have to occur in layout.
 */
-(void) setFrame:(CGRect)frame
{
    [super setFrame:frame];
    vwRing.frame = self.bounds;
}

/*
 *  Lay out the shadow and ring.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    [self applyRingTransform];
}

/*
 *  When displaying content in a small form factor, it is important to change the way that these images are
 *  scaled in the layers or they'll look like shit.  This doesn't happen much so we can accept the
 *  cost when it is absolutely necessary.
 */
-(void) prepareForSmallDisplay
{
    isSmall                              = YES;
    vwRing.layer.mask.minificationFilter = kCAFilterTrilinear;
}

/*
 *  A seal is either locked or unlocked.
 */
-(void) setLocked:(BOOL) newIsLocked;
{
    if (newIsLocked != isLocked) {
        isLocked = newIsLocked;
        [self setNeedsLayout];
        [self layoutIfNeeded];
    }
}

/*
 *  Draw the contents of this ring in the given rectangle using the applied transforms.
 */
-(void) drawForDecoyInRect:(CGRect) rc asValid:(BOOL) isValid
{
    // - ensure the transforms are applied
    [self applyRingTransform];
    
    CGContextSaveGState(UIGraphicsGetCurrentContext());
    
    // - transform by the offset of this object.
    CGContextConcatCTM(UIGraphicsGetCurrentContext(), CGAffineTransformMakeTranslation(CGRectGetMinX(rc), CGRectGetMinY(rc)));

    // - draw the items.
    rc = CGRectMake(0.0f, 0.0f, CGRectGetWidth(rc), CGRectGetHeight(rc));
    [self drawRingForDecoyInRect:rc asValid:isValid];
    
    CGContextRestoreGState(UIGraphicsGetCurrentContext());
}

/*
 *  Coordinate the mask sizing animations with the given animation.
 */
-(void) coordinateMaskSizingWithBoundsAnimation:(CAAnimation *) anim
{
    CALayer *mask = vwRing.layer.mask;
    if (mask) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [ChatSeal duplicateBoundsFromAnimation:anim onLayer:mask toTargetRect:self.bounds];
        [CATransaction commit];
    }
}
@end

/****************************
 UIWaxRingViewV2 (internal)
 ****************************/
@implementation UIWaxRingViewV2 (internal)
/*
 *  Generate one of the masks used to show the foreground rings.
 */
+(UIImage *) generateMaskForOuterRing:(BOOL) isOuter
{
    //  - the purpose of this mask is to obscure the inner ring in both
    //    the background image and the shadow, so it is fairly easy to generate.
    UIAlphaContext *ac = [UIAlphaContext contextWithSize:CGSizeMake(UIWRV_HIRES_SIDE_SZ, UIWRV_HIRES_SIDE_SZ)];
    if (!ac.context) {
        NSLog(@"CS:  Failed to create a mask context for seal wax display.");
    }
    
    CGFloat width  = ac.pxWidth;
    CGFloat height = ac.pxHeight;
    
    CGContextTranslateCTM(ac.context, 0.0f, height);
    CGContextScaleCTM(ac.context, 1.0f, -1.0f);
    
    CGContextSetBlendMode(ac.context, kCGBlendModeCopy);
    CGContextSetFillColorWithColor(ac.context, [[UIColor clearColor] CGColor]);
    CGContextFillRect(ac.context, CGRectMake(0.0f, 0.0f, width, height));
    CGContextSetFillColorWithColor(ac.context, [[UIColor whiteColor] CGColor]);
    
    UIBezierPath *bp = [UIWaxRingViewV2 pathForBounds:CGSizeMake(width, width) asOuter:isOuter];
    UIGraphicsPushContext(ac.context);
    [bp fill];
    UIGraphicsPopContext();
    
    return ac.image;
}

/*
 *  Create the masks used to create the wax.
 *  - NOTE:  I found through a process of trial and error that the best approach is to
 *    use clipping masks instead of trying to explicity draw the bitmap for the foreground layer.  It is
 *    way too costly to do during layout and masking is fairly efficient for these kinds of simple shapes and
 *    allows us to easily change the color, which is really the point of the wax.
 */
+(void) generateSharedMasks
{
    //  - Again, these masks must be precise because the edges must be precise.
    if (!innerRingMaskImage) {
        innerRingMaskImage = [[UIWaxRingViewV2 generateMaskForOuterRing:NO] retain];
    }
    if (!outerRingMaskImage) {
        outerRingMaskImage = [[UIWaxRingViewV2 generateMaskForOuterRing:YES] retain];
    }
}

/*
 *  Both sub-layers are managed identically.
 */
-(void) applyStandardMaskingToView:(UIView *) vw
{
    vw.layer.contentsGravity = kCAGravityResizeAspectFill;
    vw.layer.contentsScale   = [UIScreen mainScreen].scale;
    
    // - the mask is special for each type.
    CALayer *lMask        = [[CALayer alloc] init];
    lMask.contentsScale   = [UIScreen mainScreen].scale;
    lMask.contentsGravity = kCAGravityResizeAspectFill;
    vw.layer.mask         = lMask;
    [lMask release];
}

/*
 *  Adjust the placement of the rings.
 *  - this is necessary so that the turn position can be animated.  If it put in the layout alone
 *    animations will be interrupted.
 */
-(void) applyRingTransform
{
    // - always apply the bounds (never the frame) before setting transforms.
    // - setting the frame apparently messes with the transforms by way of the center, which I'm
    //   not 100% clear on.
    CGRect rcCurBounds = CGRectMake(0.0f, 0.0f, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
    vwRing.bounds      = rcCurBounds;

    // - set the transforms.
    CGFloat rotPct          = 0.0f;
    if (outerRing) {
        rotPct = UIWRV_OUTER_RING_ROT;
    }
    else {
        rotPct = UIWRV_INNER_RING_ROT;
    }
    vwRing.transform = CGAffineTransformMakeRotation(isLocked ? (((CGFloat) M_PI * 2.0f) * rotPct) : 0.0f);
    
    // - the masks are set based on which ring will be visible.
    [self setMaskOnLayerForRing];
}

/*
 *  Based on how this is configured, set the mask to either show
 *  the inner ring or the outer ring.
 */
-(void) setMaskOnLayerForRing
{
    CGRect rcBounds = self.bounds;
    if (CGRectGetWidth(rcBounds) < 1.0f) {
        return;
    }
    
    // - apply the appropriate images
    CALayer *mask        = vwRing.layer.mask;
    mask.backgroundColor = NULL;
    if (!mask.contents) {
        if (outerRing) {
            mask.contents    = (id) [outerRingMaskImage CGImage];
        }
        else {
            mask.contents    = (id) [innerRingMaskImage CGImage];
        }
    }

    // - the dimensions are generally easy because the mask should
    //   extend to the edges.
    mask.frame = rcBounds;
}

/*
 *  Draw the ring for the decoy image.
 */
-(void) drawRingForDecoyInRect:(CGRect) rc asValid:(BOOL) isValid
{
    CGContextSaveGState(UIGraphicsGetCurrentContext());
    
    // - get the transform and accurate frame.
    CGAffineTransform atRing = vwRing.transform;
    vwRing.transform         = CGAffineTransformIdentity;
    CGRect rcFrame           = vwRing.frame;
    vwRing.transform         = atRing;

    // - apply the transform we'll be using.
    CGContextTranslateCTM(UIGraphicsGetCurrentContext(), CGRectGetWidth(rc)/2.0f, CGRectGetHeight(rc)/2.0f);
    CGContextConcatCTM(UIGraphicsGetCurrentContext(), atRing);
    CGContextTranslateCTM(UIGraphicsGetCurrentContext(), -CGRectGetWidth(rc)/2.0f, -CGRectGetHeight(rc)/2.0f);
    
    // - draw the background
    if (isValid) {
        // - apply the clipping path before we draw anything, but remember it is upside down
        CGContextTranslateCTM(UIGraphicsGetCurrentContext(), 0.0f, CGRectGetHeight(rc));
        CGContextScaleCTM(UIGraphicsGetCurrentContext(), CGRectGetWidth(rc)/CGRectGetWidth(rcFrame), -CGRectGetHeight(rc)/CGRectGetHeight(rcFrame));
        CGContextClipToMask(UIGraphicsGetCurrentContext(), rcFrame, (CGImageRef) vwRing.layer.mask.contents);
        
        [vwRing.backgroundColor setFill];
        UIRectFill(rcFrame);
    }
    else {
        // - when invalid, we'll just stroke the item.
        [[ChatSeal defaultInvalidSealColor] setStroke];
        CGContextSetLineWidth(UIGraphicsGetCurrentContext(), 1.0f/[UIScreen mainScreen].scale);         //  a fine line.
        UIBezierPath *bp = [UIWaxRingViewV2 pathForBounds:rc.size asOuter:outerRing];
        [bp stroke];
    }
    
    CGContextRestoreGState(UIGraphicsGetCurrentContext());
}

/*
 *  Allocate a standardized inner ring Bezier path.
 */
+(UIBezierPath *) standardInnerPath
{
    //// InnerBezier2 Drawing
    UIBezierPath* innerBezier2Path = UIBezierPath.bezierPath;
    [innerBezier2Path moveToPoint: CGPointMake(140.1f, 235.57f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(137.28f, 230.52f) controlPoint1: CGPointMake(138.31f, 233.68f) controlPoint2: CGPointMake(137.78f, 233.21f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(139.89f, 221.93f) controlPoint1: CGPointMake(136.72f, 227.42f) controlPoint2: CGPointMake(137.56f, 223.97f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(146.28f, 218.95f) controlPoint1: CGPointMake(141.48f, 220.53f) controlPoint2: CGPointMake(144.74f, 219.25f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(193.76f, 193.51f) controlPoint1: CGPointMake(163.68f, 215.47f) controlPoint2: CGPointMake(180.28f, 207.0f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(193.76f, 61.99f) controlPoint1: CGPointMake(230.08f, 157.19f) controlPoint2: CGPointMake(230.08f, 98.31f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(139.37f, 35.44f) controlPoint1: CGPointMake(178.5f, 46.73f) controlPoint2: CGPointMake(159.26f, 37.88f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(138.48f, 35.31f) controlPoint1: CGPointMake(137.93f, 35.27f) controlPoint2: CGPointMake(137.08f, 36.53f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(142.39f, 31.21f) controlPoint1: CGPointMake(139.14f, 34.72f) controlPoint2: CGPointMake(142.11f, 31.81f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(143.75f, 25.67f) controlPoint1: CGPointMake(143.2f, 29.5f) controlPoint2: CGPointMake(143.67f, 26.88f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(141.39f, 19.32f) controlPoint1: CGPointMake(143.84f, 24.25f) controlPoint2: CGPointMake(143.66f, 21.25f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(138.32f, 16.22f) controlPoint1: CGPointMake(139.07f, 17.34f) controlPoint2: CGPointMake(135.69f, 15.98f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(207.2f, 48.55f) controlPoint1: CGPointMake(163.45f, 18.54f) controlPoint2: CGPointMake(187.95f, 29.31f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(207.2f, 206.95f) controlPoint1: CGPointMake(250.93f, 92.29f) controlPoint2: CGPointMake(250.93f, 163.21f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(147.17f, 238.11f) controlPoint1: CGPointMake(190.22f, 223.92f) controlPoint2: CGPointMake(169.15f, 234.31f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(140.1f, 235.57f) controlPoint1: CGPointMake(144.92f, 238.5f) controlPoint2: CGPointMake(142.08f, 237.63f)];
    [innerBezier2Path closePath];
    [innerBezier2Path moveToPoint: CGPointMake(118.93f, 224.02f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(116.16f, 230.22f) controlPoint1: CGPointMake(117.29f, 225.63f) controlPoint2: CGPointMake(116.18f, 228.23f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(118.1f, 235.41f) controlPoint1: CGPointMake(116.15f, 231.95f) controlPoint2: CGPointMake(116.99f, 233.87f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(122.11f, 239.6f) controlPoint1: CGPointMake(120.0f, 238.06f) controlPoint2: CGPointMake(124.73f, 239.73f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(48.8f, 206.95f) controlPoint1: CGPointMake(95.44f, 238.2f) controlPoint2: CGPointMake(69.17f, 227.32f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(48.8f, 48.55f) controlPoint1: CGPointMake(5.07f, 163.21f) controlPoint2: CGPointMake(5.07f, 92.29f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(114.4f, 16.57f) controlPoint1: CGPointMake(67.21f, 30.15f) controlPoint2: CGPointMake(90.43f, 19.49f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(120.21f, 18.37f) controlPoint1: CGPointMake(115.91f, 16.39f) controlPoint2: CGPointMake(118.61f, 17.07f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(123.6f, 25.67f) controlPoint1: CGPointMake(123.01f, 20.64f) controlPoint2: CGPointMake(123.63f, 22.51f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(121.03f, 32.84f) controlPoint1: CGPointMake(123.58f, 28.18f) controlPoint2: CGPointMake(122.35f, 30.92f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(114.87f, 35.68f) controlPoint1: CGPointMake(119.95f, 34.4f) controlPoint2: CGPointMake(116.62f, 35.43f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(62.24f, 61.99f) controlPoint1: CGPointMake(95.62f, 38.41f) controlPoint2: CGPointMake(77.05f, 47.18f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(62.24f, 193.51f) controlPoint1: CGPointMake(25.92f, 98.31f) controlPoint2: CGPointMake(25.92f, 157.19f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(122.32f, 220.58f) controlPoint1: CGPointMake(78.95f, 210.22f) controlPoint2: CGPointMake(100.45f, 219.25f)];
    [innerBezier2Path addCurveToPoint: CGPointMake(118.93f, 224.02f) controlPoint1: CGPointMake(124.68f, 220.72f) controlPoint2: CGPointMake(121.21f, 221.76f)];
    [innerBezier2Path closePath];
    
    return innerBezier2Path;
}

/*
 *  Allocate a standardized outer ring Bezier path.
 */
+(UIBezierPath *) standardOuterPath
{
    //// OuterBezier2 Drawing
    UIBezierPath* outerBezier2Path = UIBezierPath.bezierPath;
    [outerBezier2Path moveToPoint: CGPointMake(135.18f, 251.71f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(136.15f, 249.26f) controlPoint1: CGPointMake(135.88f, 251.09f) controlPoint2: CGPointMake(136.17f, 249.88f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(135.22f, 247.12f) controlPoint1: CGPointMake(136.13f, 248.62f) controlPoint2: CGPointMake(135.62f, 247.47f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(133.56f, 245.87f) controlPoint1: CGPointMake(134.52f, 246.5f) controlPoint2: CGPointMake(132.65f, 245.91f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(211.44f, 211.44f) controlPoint1: CGPointMake(161.88f, 244.54f) controlPoint2: CGPointMake(189.81f, 233.06f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(211.44f, 44.56f) controlPoint1: CGPointMake(257.52f, 165.36f) controlPoint2: CGPointMake(257.52f, 90.64f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(136.69f, 10.32f) controlPoint1: CGPointMake(190.61f, 23.73f) controlPoint2: CGPointMake(163.93f, 12.32f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(134.6f, 9.45f) controlPoint1: CGPointMake(135.55f, 10.23f) controlPoint2: CGPointMake(135.14f, 9.79f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(133.02f, 6.89f) controlPoint1: CGPointMake(133.28f, 8.64f) controlPoint2: CGPointMake(133.02f, 7.53f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(134.42f, 3.94f) controlPoint1: CGPointMake(133.02f, 5.83f) controlPoint2: CGPointMake(133.71f, 4.29f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(136.85f, 3.31f) controlPoint1: CGPointMake(135.05f, 3.64f) controlPoint2: CGPointMake(135.94f, 3.25f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(216.39f, 39.61f) controlPoint1: CGPointMake(165.83f, 5.36f) controlPoint2: CGPointMake(194.23f, 17.46f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(216.39f, 216.39f) controlPoint1: CGPointMake(265.2f, 88.43f) controlPoint2: CGPointMake(265.2f, 167.57f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(133.67f, 252.87f) controlPoint1: CGPointMake(193.42f, 239.35f) controlPoint2: CGPointMake(163.74f, 251.52f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(135.18f, 251.71f) controlPoint1: CGPointMake(132.77f, 252.91f) controlPoint2: CGPointMake(133.95f, 252.78f)];
    [outerBezier2Path closePath];
    [outerBezier2Path moveToPoint: CGPointMake(126.82f, 246.81f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(127.82f, 249.28f) controlPoint1: CGPointMake(127.79f, 247.58f) controlPoint2: CGPointMake(127.8f, 248.36f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(126.85f, 251.97f) controlPoint1: CGPointMake(127.84f, 250.27f) controlPoint2: CGPointMake(127.89f, 250.98f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(124.92f, 252.96f) controlPoint1: CGPointMake(125.95f, 252.83f) controlPoint2: CGPointMake(125.64f, 252.98f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(39.61f, 216.39f) controlPoint1: CGPointMake(93.96f, 252.2f) controlPoint2: CGPointMake(63.24f, 240.01f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(39.61f, 39.61f) controlPoint1: CGPointMake(-9.2f, 167.57f) controlPoint2: CGPointMake(-9.2f, 88.43f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(125.02f, 3.04f) controlPoint1: CGPointMake(63.26f, 15.96f) controlPoint2: CGPointMake(94.03f, 3.77f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(127.3f, 3.18f) controlPoint1: CGPointMake(126.32f, 3.0f) controlPoint2: CGPointMake(128.53f, 3.63f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(125.71f, 4.3f) controlPoint1: CGPointMake(126.99f, 3.07f) controlPoint2: CGPointMake(126.28f, 3.44f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(124.92f, 6.69f) controlPoint1: CGPointMake(125.21f, 5.05f) controlPoint2: CGPointMake(124.71f, 5.95f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(125.47f, 8.58f) controlPoint1: CGPointMake(125.11f, 7.35f) controlPoint2: CGPointMake(124.84f, 8.13f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(127.28f, 9.73f) controlPoint1: CGPointMake(126.52f, 9.33f) controlPoint2: CGPointMake(127.51f, 9.66f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(124.94f, 10.04f) controlPoint1: CGPointMake(125.08f, 10.4f) controlPoint2: CGPointMake(126.15f, 10.01f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(44.56f, 44.56f) controlPoint1: CGPointMake(95.77f, 10.79f) controlPoint2: CGPointMake(66.82f, 22.3f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(44.56f, 211.44f) controlPoint1: CGPointMake(-1.52f, 90.64f) controlPoint2: CGPointMake(-1.52f, 165.36f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(125.23f, 245.97f) controlPoint1: CGPointMake(66.9f, 233.77f) controlPoint2: CGPointMake(95.96f, 245.28f)];
    [outerBezier2Path addCurveToPoint: CGPointMake(126.82f, 246.81f) controlPoint1: CGPointMake(125.8f, 245.98f) controlPoint2: CGPointMake(126.06f, 246.2f)];
    [outerBezier2Path closePath];
    
    return outerBezier2Path;
}

/*
 *  Generate a path for the given bounds.
 */
+(UIBezierPath *) pathForBounds:(CGSize) szBounds asOuter:(BOOL) isOuter
{
    UIBezierPath *ret = nil;
    if (isOuter) {
        ret = [UIWaxRingViewV2 standardOuterPath];
    }
    else {
        ret = [UIWaxRingViewV2 standardInnerPath];
    }
    
    // - make sure the path is scaled for the output
    [ret applyTransform:CGAffineTransformMakeScale(szBounds.width/UIWRV_PAINTCODE_CANVAS_SIDE, szBounds.width/UIWRV_PAINTCODE_CANVAS_SIDE)];
    
    // - and apply the standard effects
    ret.lineCapStyle  = kCGLineCapRound;
    ret.lineJoinStyle = kCGLineJoinRound;
    
    return ret;
}

@end
