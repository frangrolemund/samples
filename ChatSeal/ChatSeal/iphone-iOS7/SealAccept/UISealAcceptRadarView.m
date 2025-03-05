//
//  UISealAcceptRadarView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 2/14/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealAcceptRadarView.h"
#import "UIAlphaContext.h"
#import "ChatSeal.h"
#import "UITimerView.h"
#import "UIAdvancedSelfSizingTools.h"

// - constants
static const CGFloat        UISARV_STD_TARGET_PAD        = 2.0f;
static const CGFloat        UISARV_STD_RADAR_ALERT_ALPHA = 0.8f;
static const NSTimeInterval UISARV_STD_COLOR_FADE_TIME   = 0.75f;
static const NSTimeInterval UISARV_STD_PULSE_FADE_TIME   = 0.20f;
static const NSTimeInterval UISARV_STD_SCAN_DURATION     = 7.0f;
static const CGFloat        UISARV_STD_SIDE_PAD          = 5.0f;
static const CGFloat        UISARV_STD_CORNER_RAD_PCT    = 0.07f;
static const CGFloat        UISARV_STD_SCANNER_PAD       = 20.0f;

// - forward declarations
@interface UISealAcceptRadarView (internal)
-(void) commonConfiguration;
-(void) recomputeRadarMask;
-(UIColor *) standardRadarColor;
-(void) discardTimerView;
-(CGRect) computeTargetRect;
-(BOOL) isPortrait;
-(UIBezierPath *) pathForTarget;
@end

/***********************
 UISealAcceptRadarView
 ***********************/
@implementation UISealAcceptRadarView
/*
 *  Object attributes.
 */
{
    UIView      *vwContent;
    CGFloat     topMargin;
    UITimerView *tvBackground;
    UILabel     *lOverlay;
    BOOL        overlayOn;
}
@synthesize delegate;

/*
 *  The time it takes to make one complete scan around the radar.
 */
+(NSTimeInterval) scanCycleDuration
{
    return UISARV_STD_SCAN_DURATION;
}

/*
 *  Return the percentage of the side that the corner radius assumes.
 */
+(CGFloat) targetCornerRadiusPercentage
{
    return UISARV_STD_CORNER_RAD_PCT;
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
    delegate = nil;
    
    [lOverlay release];
    lOverlay = nil;
    
    [vwContent release];
    vwContent = nil;
    
    [self discardTimerView];
    [super dealloc];
}

/*
 *  Set the height of the top margin that is used for computing the
 *  scan window.
 *  - this is assigned in points.
 */
-(void) setTopMarginHeight:(CGFloat)tm
{
    topMargin = (CGFloat) ceil(tm);
    [self setNeedsLayout];
}

/*
 *  The signal target is a rectangle relative to the bounds of this view
 *  that is a location where a view can be placed to indicate external signal
 *  results.
 */
-(CGRect) activeSignalTargetRegion
{
    CGSize szBounds = self.bounds.size;
    CGRect rcTarget = [self computeTargetRect];
    CGPoint ptCenter = CGPointMake(CGRectGetMinX(rcTarget) + (CGRectGetWidth(rcTarget)/2.0f), CGRectGetMinY(rcTarget) + (CGRectGetHeight(rcTarget)/2.0f));
    
    //  ... recompute the signal region because it is relative to the bounds of this
    //      view and the masked items.
    if (szBounds.width > szBounds.height) {
        // - in landscape mode, the signal is on the left of the target
        CGFloat remain        = CGRectGetMinX(rcTarget);
        CGFloat side          = (remain - (UISARV_STD_SIDE_PAD * 2.0f));
        return CGRectMake((remain - side) / 2.0f, ptCenter.y - (side/2.0f), side, side);
    }
    else {
        // - in portrait mode, the signal is under the target
        CGFloat remain        = szBounds.height - CGRectGetMaxY(rcTarget);
        CGFloat side          = (remain - (UISARV_STD_SIDE_PAD * 2.0f));
        return CGRectMake(UISARV_STD_SIDE_PAD, CGRectGetMaxY(rcTarget) + UISARV_STD_SIDE_PAD, szBounds.width - (UISARV_STD_SIDE_PAD * 2.0f), side);
    }
}

/*
 *  The scanning target is the center of the radar display and is generally open
 */
-(CGRect) scanningTargetRegion
{
    CGRect rc = [self computeTargetRect];
    return CGRectIntegral(CGRectInset(rc, UISARV_STD_TARGET_PAD, UISARV_STD_TARGET_PAD));
}

/*
 *  Lay out the content.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    CGSize szBounds = self.bounds.size;
    
    // - recreate the mask if the bounds have changed.
    if (!vwContent.layer.mask ||
        (int) szBounds.width  != (int) CGRectGetWidth(vwContent.layer.mask.bounds) ||
        (int) szBounds.height != (int) CGRectGetHeight(vwContent.layer.mask.bounds)) {
        [self recomputeRadarMask];
    }
    
    // - make sure the overlay is positioned.
    lOverlay.frame = CGRectInset([self computeTargetRect], UISARV_STD_SCANNER_PAD, UISARV_STD_SCANNER_PAD);
}

/*
 *  Halt the timer when disconnecting this view from its parent.
 */
-(void) willMoveToSuperview:(UIView *)newSuperview
{
    if (!newSuperview) {
        [self discardTimerView];
    }
}

/*
 *  The radar scan target was changed.
 */
-(void) radarTargetsWereUpdated:(UISealAcceptRadarView *) radarView
{
    if (delegate && [delegate respondsToSelector:@selector(radarTargetsWereUpdated:)]) {
        [delegate performSelector:@selector(radarTargetsWereUpdated:) withObject:radarView];
    }
}

/*
 *  Assign a temporary color to this view and have that fade back into the standard color later.
 */
-(void) setTimedColorState:(UIColor *) c asPulsed:(BOOL) isPulsed
{
    [UIView animateWithDuration:[ChatSeal standardItemFadeTime] delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^(void) {
        tvBackground.backgroundColor = [c colorWithAlphaComponent:UISARV_STD_RADAR_ALERT_ALPHA];
    }completion:nil];
    [tvBackground setTimeout:isPulsed ? UISARV_STD_PULSE_FADE_TIME : UISARV_STD_COLOR_FADE_TIME];
    [tvBackground restartTimer];
}

/*
 *  Assign text to this view, generally for error reporting.
 */
-(void) setScannerOverlayText:(NSString *) text inColor:(UIColor *) c withAnimation:(BOOL) animated
{
    if (text) {
        if (!lOverlay) {
            lOverlay                           = [[UILabel alloc] init];
            lOverlay.font                      = [UIFont systemFontOfSize:17.0f];
            lOverlay.numberOfLines             = 0;
            lOverlay.adjustsFontSizeToFitWidth = NO;
            lOverlay.textAlignment             = NSTextAlignmentCenter;
            [self addSubview:lOverlay];
            [self reconfigureDynamicTypeForInit:YES];
            [self layoutIfNeeded];
        }
        lOverlay.text      = text;
        lOverlay.textColor = c;
        
        if (!overlayOn) {
            if (animated) {
                lOverlay.alpha = 0.0f;
                [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                    lOverlay.alpha = 1.0f;
                }];
            }
            else {
                lOverlay.alpha = 1.0f;
            }
            overlayOn = YES;            
        }
    }
    else {
        if (animated) {
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                lOverlay.alpha = 1.0f;
            } completion:^(BOOL finished) {
                lOverlay.text = nil;
            }];
        }
        else {
            lOverlay.alpha = 0.0f;
            lOverlay.text  = nil;
        }
        overlayOn = NO;
    }
}

/*
 *  Reconfigure the dynamic type in this view.
 */
-(void) reconfigureDynamicTypeForInit:(BOOL) isInit
{
    if (![ChatSeal isAdvancedSelfSizingInUse] || !lOverlay) {
        return;
    }
    [UIAdvancedSelfSizingTools constrainTextLabel:lOverlay withPreferredSettingsAndTextStyle:UIFontTextStyleBody andMinimumSize:17.0f duringInitialization:isInit];
}

/*
 *  Prepare to rotate this view.
 */
-(void) prepareForRotation
{
    if (overlayOn) {
        lOverlay.alpha = 0.0f;
    }
}

/*
 *  Complete view rotation.
 */
-(void) completeRotation
{
    if (overlayOn) {
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            lOverlay.alpha = 1.0f;
        }];
    }
}

@end

/*********************************
 UISealAcceptRadarView (internal)
 *********************************/
@implementation UISealAcceptRadarView (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    topMargin                     = 0.0f;
    overlayOn                     = NO;
    
    self.backgroundColor          = [UIColor clearColor];
    
    vwContent                     = [[UIView alloc] initWithFrame:self.bounds];
    vwContent.backgroundColor     = [UIColor clearColor];
    vwContent.autoresizingMask    = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:vwContent];
    
    tvBackground                  = [[UITimerView alloc] initWithFrame:self.bounds];
    tvBackground.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [vwContent addSubview:tvBackground];
    tvBackground.backgroundColor  = [self standardRadarColor];
    [tvBackground setTimeout:UISARV_STD_COLOR_FADE_TIME withCompletion:^(void) {
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^(void) {
            tvBackground.backgroundColor = [self standardRadarColor];
        }completion:nil];
    }];
    tvBackground.backgroundColor  = [self standardRadarColor];
}

/*
 *  Add a round rectangle path to the given context.
 */
-(void) addRoundRectPath:(CGRect) rc toContext:(CGContextRef) ctx withRadius:(CGFloat) radius
{
    CGContextBeginPath(ctx);
    CGContextMoveToPoint(ctx, CGRectGetMinX(rc) + radius, CGRectGetMinY(rc));
    
    CGFloat endX = CGRectGetMaxX(rc) - radius;
    CGFloat endY = CGRectGetMinY(rc);
    CGContextAddLineToPoint(ctx, endX, endY);
    CGContextAddArc(ctx, endX, endY + radius, radius, (CGFloat) (M_PI + M_PI_2), 0.0f, 0);

    endX = CGRectGetMaxX(rc);
    endY = CGRectGetMaxY(rc) - radius;
    CGContextAddLineToPoint(ctx, endX, endY);
    CGContextAddArc(ctx, endX - radius, endY, radius, 0.0f, (CGFloat) M_PI_2, 0);
    
    endX = CGRectGetMinX(rc) + radius;
    endY = CGRectGetMaxY(rc);
    CGContextAddLineToPoint(ctx, endX, endY);
    CGContextAddArc(ctx, endX, endY - radius, radius, (CGFloat) M_PI_2, (CGFloat) M_PI, 0);
    
    endX = CGRectGetMinX(rc);
    endY = CGRectGetMinY(rc) + radius;
    CGContextAddLineToPoint(ctx, endX, endY);
    CGContextAddArc(ctx, endX + radius, endY, radius, (CGFloat) M_PI, (CGFloat) M_PI + (CGFloat) M_PI_2, 0);
    
    CGContextClosePath(ctx);
}

/*
 *  Generating the mask for the radar is potentially expensive, so we'll only
 *  do it upon command from the owner of this view.
 */
-(void) recomputeRadarMask
{
    CGFloat scale      = [UIScreen mainScreen].scale;
    UIAlphaContext *ac = [[UIAlphaContext alloc] initWithSize:self.bounds.size andScale:scale];
    
    // - we're going to make this very simple to draw.
    CGContextSetBlendMode(ac.context, kCGBlendModeCopy);
    CGContextSetLineWidth(ac.context, 1.0f);
    CGContextTranslateCTM(ac.context, 0.0f, ac.pxHeight);
    CGContextScaleCTM(ac.context, 1.0f, -1.0f);
    
    // - start with a fully-visible region.
    UIColor *cTranslucent = [UIColor colorWithWhite:0.0f alpha:0.0f];
    CGContextSetFillColorWithColor(ac.context, [cTranslucent CGColor]);
    CGContextFillRect(ac.context, ac.pxBounds);
    
    // - now start cutting out pieces
    UIColor *cVisible = [UIColor whiteColor];
    
    // ...compute the target first since everything is relative to that.
    CGRect rcTarget = [self computeTargetRect];
    rcTarget        = CGRectMake(CGRectGetMinX(rcTarget) * scale, CGRectGetMinY(rcTarget) * scale,
                                 CGRectGetWidth(rcTarget) * scale, CGRectGetHeight(rcTarget) * scale);
    
    // ...draw the target last so that it overlays the radar
    CGContextSetFillColorWithColor(ac.context, [cVisible CGColor]);
    UIBezierPath *bp        = [self pathForTarget];
    CGFloat pathScale       = CGRectGetWidth(rcTarget)/CGRectGetWidth(bp.bounds);
    CGAffineTransform    at = CGAffineTransformIdentity;
    at                      = CGAffineTransformTranslate(at, rcTarget.origin.x, rcTarget.origin.y);
    at                      = CGAffineTransformScale(at, pathScale, pathScale);
    [bp applyTransform:at];
    UIGraphicsPushContext(ac.context);
    [bp fill];
    UIGraphicsPopContext();
    
    // - pull out the image mask and apply it to my view.
    UIImage *img         = ac.imageMask;
    CALayer *l           = [[CALayer alloc] init];
    l.frame              = self.bounds;
    l.contentsScale      = scale;
    l.contentsGravity    = kCAGravityCenter;
    l.contents           = (id) img.CGImage;
    vwContent.layer.mask = l;
    [l release];
    
    // - free the alpha context.
    [ac release];
    
    // - make sure the delegate learns of the target updates.
    [self radarTargetsWereUpdated:self];
}

/*
 *  Return the color for the radar under normal operating circumstances.
 */
-(UIColor *) standardRadarColor
{
    return [[ChatSeal defaultIconColor] colorWithAlphaComponent:0.5f];
}

/*
 *  Free the timer view.
 */
-(void) discardTimerView
{
    [tvBackground setTimeout:0.0f withCompletion:nil];
    [tvBackground haltTimerAndForceCompletion:NO];
    [tvBackground release];
    tvBackground = nil;
}

/*
 *  Compute the scanning target region.
 */
-(CGRect) computeTargetRect
{
    // - This approach is something I'd like to rethink at some point because is is an approximation to
    //   what the seal share does with the seal region.  Ideally, they'd use similar constraints to generate
    //   the target.
    CGSize szBounds = self.bounds.size;
    CGFloat shortSide = szBounds.width;
    if (shortSide > szBounds.height) {
        shortSide = szBounds.height - topMargin;
        shortSide *= 0.92f;
    }
    else {
        shortSide *= 0.8f;
    }
    
    CGRect rcTarget        = CGRectIntegral(CGRectMake((szBounds.width - shortSide)/2.0f, (szBounds.height - shortSide)/2.0f, shortSide, shortSide));
    if (CGRectGetMinY(rcTarget) < topMargin) {
        rcTarget.origin.y  = topMargin;
    }
 
    return rcTarget;
}

/*
 *  Returns whether this view is in a portrait orientation.
 */
-(BOOL) isPortrait
{
    return (self.bounds.size.width < self.bounds.size.height) ? YES : NO;
}

/*
 *  Return a path we can use to draw the target region.
 */
-(UIBezierPath *) pathForTarget
{
    // - just pull this straight from PaintCode.
    
    //// Bezier Drawing
    UIBezierPath* bezierPath = UIBezierPath.bezierPath;
    [bezierPath moveToPoint: CGPointMake(272.92f, 0.92f)];
    [bezierPath addCurveToPoint: CGPointMake(273.84f, 0.82f) controlPoint1: CGPointMake(273.29f, 0.77f) controlPoint2: CGPointMake(273.61f, 0.74f)];
    [bezierPath addCurveToPoint: CGPointMake(272.92f, 0.92f) controlPoint1: CGPointMake(275.37f, 1.38f) controlPoint2: CGPointMake(274.49f, 1.19f)];
    [bezierPath addCurveToPoint: CGPointMake(270.34f, 3.28f) controlPoint1: CGPointMake(272.16f, 1.23f) controlPoint2: CGPointMake(271.18f, 2.02f)];
    [bezierPath addCurveToPoint: CGPointMake(268.62f, 8.55f) controlPoint1: CGPointMake(269.25f, 4.93f) controlPoint2: CGPointMake(268.15f, 6.9f)];
    [bezierPath addCurveToPoint: CGPointMake(269.83f, 12.7f) controlPoint1: CGPointMake(269.03f, 10.0f) controlPoint2: CGPointMake(268.44f, 11.71f)];
    [bezierPath addCurveToPoint: CGPointMake(273.79f, 15.22f) controlPoint1: CGPointMake(272.13f, 14.35f) controlPoint2: CGPointMake(274.32f, 15.06f)];
    [bezierPath addCurveToPoint: CGPointMake(268.66f, 15.9f) controlPoint1: CGPointMake(268.96f, 16.71f) controlPoint2: CGPointMake(271.31f, 15.84f)];
    [bezierPath addCurveToPoint: CGPointMake(220.08f, 21.75f) controlPoint1: CGPointMake(252.36f, 16.32f) controlPoint2: CGPointMake(236.09f, 18.27f)];
    [bezierPath addLineToPoint: CGPointMake(330.69f, 21.75f)];
    [bezierPath addCurveToPoint: CGPointMake(294.5f, 16.52f) controlPoint1: CGPointMake(318.74f, 19.15f) controlPoint2: CGPointMake(306.64f, 17.41f)];
    [bezierPath addCurveToPoint: CGPointMake(289.89f, 14.62f) controlPoint1: CGPointMake(291.98f, 16.33f) controlPoint2: CGPointMake(291.09f, 15.35f)];
    [bezierPath addCurveToPoint: CGPointMake(286.42f, 8.98f) controlPoint1: CGPointMake(287.0f, 12.83f) controlPoint2: CGPointMake(286.42f, 10.38f)];
    [bezierPath addCurveToPoint: CGPointMake(289.51f, 2.5f) controlPoint1: CGPointMake(286.42f, 6.65f) controlPoint2: CGPointMake(287.95f, 3.25f)];
    [bezierPath addCurveToPoint: CGPointMake(294.86f, 1.11f) controlPoint1: CGPointMake(290.88f, 1.83f) controlPoint2: CGPointMake(292.85f, 0.97f)];
    [bezierPath addCurveToPoint: CGPointMake(381.72f, 21.75f) controlPoint1: CGPointMake(324.51f, 3.2f) controlPoint2: CGPointMake(353.88f, 10.08f)];
    [bezierPath addLineToPoint: CGPointMake(522.71f, 21.75f)];
    [bezierPath addCurveToPoint: CGPointMake(522.71f, 155.18f) controlPoint1: CGPointMake(522.71f, 21.75f) controlPoint2: CGPointMake(522.71f, 79.15f)];
    [bezierPath addCurveToPoint: CGPointMake(522.71f, 395.44f) controlPoint1: CGPointMake(559.46f, 230.81f) controlPoint2: CGPointMake(559.46f, 319.8f)];
    [bezierPath addCurveToPoint: CGPointMake(522.71f, 524.75f) controlPoint1: CGPointMake(522.71f, 469.41f) controlPoint2: CGPointMake(522.71f, 524.75f)];
    [bezierPath addLineToPoint: CGPointMake(391.07f, 524.75f)];
    [bezierPath addCurveToPoint: CGPointMake(282.95f, 549.91f) controlPoint1: CGPointMake(358.33f, 539.93f) controlPoint2: CGPointMake(318.32f, 548.32f)];
    [bezierPath addCurveToPoint: CGPointMake(291.17f, 547.35f) controlPoint1: CGPointMake(280.98f, 550.0f) controlPoint2: CGPointMake(288.48f, 549.72f)];
    [bezierPath addCurveToPoint: CGPointMake(293.31f, 541.97f) controlPoint1: CGPointMake(292.71f, 545.99f) controlPoint2: CGPointMake(293.35f, 543.33f)];
    [bezierPath addCurveToPoint: CGPointMake(291.27f, 537.25f) controlPoint1: CGPointMake(293.27f, 540.55f) controlPoint2: CGPointMake(292.14f, 538.02f)];
    [bezierPath addCurveToPoint: CGPointMake(287.61f, 534.51f) controlPoint1: CGPointMake(289.73f, 535.89f) controlPoint2: CGPointMake(285.61f, 534.61f)];
    [bezierPath addCurveToPoint: CGPointMake(347.08f, 524.75f) controlPoint1: CGPointMake(307.67f, 533.57f) controlPoint2: CGPointMake(327.64f, 530.32f)];
    [bezierPath addLineToPoint: CGPointMake(203.69f, 524.75f)];
    [bezierPath addCurveToPoint: CGPointMake(269.29f, 534.73f) controlPoint1: CGPointMake(225.11f, 530.88f) controlPoint2: CGPointMake(247.18f, 534.21f)];
    [bezierPath addCurveToPoint: CGPointMake(272.79f, 536.58f) controlPoint1: CGPointMake(270.55f, 534.76f) controlPoint2: CGPointMake(271.13f, 535.24f)];
    [bezierPath addCurveToPoint: CGPointMake(274.99f, 542.0f) controlPoint1: CGPointMake(274.91f, 538.27f) controlPoint2: CGPointMake(274.95f, 540.0f)];
    [bezierPath addCurveToPoint: CGPointMake(272.86f, 547.93f) controlPoint1: CGPointMake(275.03f, 544.19f) controlPoint2: CGPointMake(275.14f, 545.75f)];
    [bezierPath addCurveToPoint: CGPointMake(263.72f, 550.11f) controlPoint1: CGPointMake(270.88f, 549.82f) controlPoint2: CGPointMake(265.31f, 550.15f)];
    [bezierPath addCurveToPoint: CGPointMake(159.7f, 524.75f) controlPoint1: CGPointMake(226.44f, 549.2f) controlPoint2: CGPointMake(194.2f, 540.74f)];
    [bezierPath addLineToPoint: CGPointMake(24.03f, 524.75f)];
    [bezierPath addCurveToPoint: CGPointMake(24.03f, 386.77f) controlPoint1: CGPointMake(24.03f, 524.75f) controlPoint2: CGPointMake(24.03f, 465.04f)];
    [bezierPath addCurveToPoint: CGPointMake(24.03f, 163.85f) controlPoint1: CGPointMake(-7.34f, 315.98f) controlPoint2: CGPointMake(-7.34f, 234.64f)];
    [bezierPath addCurveToPoint: CGPointMake(24.03f, 21.75f) controlPoint1: CGPointMake(24.03f, 83.56f) controlPoint2: CGPointMake(24.03f, 21.75f)];
    [bezierPath addLineToPoint: CGPointMake(169.05f, 21.75f)];
    [bezierPath addCurveToPoint: CGPointMake(268.84f, 0.5f) controlPoint1: CGPointMake(200.93f, 8.39f) controlPoint2: CGPointMake(234.83f, 1.31f)];
    [bezierPath addCurveToPoint: CGPointMake(272.92f, 0.92f) controlPoint1: CGPointMake(270.08f, 0.47f) controlPoint2: CGPointMake(271.7f, 0.72f)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(470.31f, 78.3f)];
    [bezierPath addLineToPoint: CGPointMake(441.01f, 78.3f)];
    [bezierPath addLineToPoint: CGPointMake(441.01f, 107.7f)];
    [bezierPath addLineToPoint: CGPointMake(470.31f, 107.7f)];
    [bezierPath addLineToPoint: CGPointMake(470.31f, 78.3f)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(108.17f, 78.68f)];
    [bezierPath addLineToPoint: CGPointMake(78.87f, 78.68f)];
    [bezierPath addLineToPoint: CGPointMake(78.87f, 108.08f)];
    [bezierPath addLineToPoint: CGPointMake(108.17f, 108.08f)];
    [bezierPath addLineToPoint: CGPointMake(108.17f, 78.68f)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(478.85f, 69.37f)];
    [bezierPath addCurveToPoint: CGPointMake(478.85f, 115.37f) controlPoint1: CGPointMake(478.85f, 69.37f) controlPoint2: CGPointMake(478.85f, 115.37f)];
    [bezierPath addLineToPoint: CGPointMake(432.85f, 115.37f)];
    [bezierPath addLineToPoint: CGPointMake(432.85f, 69.37f)];
    [bezierPath addLineToPoint: CGPointMake(478.85f, 69.37f)];
    [bezierPath addLineToPoint: CGPointMake(478.85f, 69.37f)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(116.71f, 69.75f)];
    [bezierPath addCurveToPoint: CGPointMake(116.71f, 115.75f) controlPoint1: CGPointMake(116.71f, 69.75f) controlPoint2: CGPointMake(116.71f, 115.75f)];
    [bezierPath addLineToPoint: CGPointMake(70.71f, 115.75f)];
    [bezierPath addLineToPoint: CGPointMake(70.71f, 69.75f)];
    [bezierPath addLineToPoint: CGPointMake(116.71f, 69.75f)];
    [bezierPath addLineToPoint: CGPointMake(116.71f, 69.75f)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(128.03f, 57.6f)];
    [bezierPath addLineToPoint: CGPointMake(60.18f, 57.6f)];
    [bezierPath addLineToPoint: CGPointMake(60.18f, 126.75f)];
    [bezierPath addLineToPoint: CGPointMake(128.03f, 126.75f)];
    [bezierPath addLineToPoint: CGPointMake(128.03f, 57.6f)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(489.31f, 58.83f)];
    [bezierPath addLineToPoint: CGPointMake(421.46f, 58.83f)];
    [bezierPath addLineToPoint: CGPointMake(421.46f, 127.97f)];
    [bezierPath addLineToPoint: CGPointMake(489.31f, 127.97f)];
    [bezierPath addLineToPoint: CGPointMake(489.31f, 58.83f)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(277.39f, 255.31f)];
    [bezierPath addLineToPoint: CGPointMake(273.38f, 255.31f)];
    [bezierPath addCurveToPoint: CGPointMake(273.38f, 273.31f) controlPoint1: CGPointMake(273.38f, 255.31f) controlPoint2: CGPointMake(273.38f, 264.02f)];
    [bezierPath addLineToPoint: CGPointMake(255.38f, 273.31f)];
    [bezierPath addLineToPoint: CGPointMake(255.38f, 277.31f)];
    [bezierPath addLineToPoint: CGPointMake(273.38f, 277.31f)];
    [bezierPath addCurveToPoint: CGPointMake(273.38f, 295.31f) controlPoint1: CGPointMake(273.38f, 286.6f) controlPoint2: CGPointMake(273.38f, 295.31f)];
    [bezierPath addLineToPoint: CGPointMake(277.39f, 295.31f)];
    [bezierPath addCurveToPoint: CGPointMake(277.39f, 277.31f) controlPoint1: CGPointMake(277.39f, 295.31f) controlPoint2: CGPointMake(277.39f, 286.6f)];
    [bezierPath addLineToPoint: CGPointMake(295.39f, 277.31f)];
    [bezierPath addLineToPoint: CGPointMake(295.39f, 273.31f)];
    [bezierPath addLineToPoint: CGPointMake(277.39f, 273.31f)];
    [bezierPath addCurveToPoint: CGPointMake(277.39f, 255.31f) controlPoint1: CGPointMake(277.39f, 264.02f) controlPoint2: CGPointMake(277.39f, 255.31f)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(24.03f, 210.67f)];
    [bezierPath addCurveToPoint: CGPointMake(24.03f, 339.95f) controlPoint1: CGPointMake(13.18f, 253.03f) controlPoint2: CGPointMake(13.18f, 297.59f)];
    [bezierPath addCurveToPoint: CGPointMake(24.03f, 210.67f) controlPoint1: CGPointMake(24.03f, 297.81f) controlPoint2: CGPointMake(24.03f, 252.98f)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(522.71f, 196.62f)];
    [bezierPath addCurveToPoint: CGPointMake(522.71f, 298.57f) controlPoint1: CGPointMake(522.71f, 229.52f) controlPoint2: CGPointMake(522.71f, 264.36f)];
    [bezierPath addCurveToPoint: CGPointMake(522.71f, 354.0f) controlPoint1: CGPointMake(522.71f, 317.38f) controlPoint2: CGPointMake(522.71f, 336.0f)];
    [bezierPath addCurveToPoint: CGPointMake(522.71f, 196.62f) controlPoint1: CGPointMake(538.93f, 302.88f) controlPoint2: CGPointMake(538.93f, 247.73f)];
    [bezierPath addLineToPoint: CGPointMake(522.71f, 196.62f)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(108.64f, 440.33f)];
    [bezierPath addLineToPoint: CGPointMake(79.34f, 440.33f)];
    [bezierPath addLineToPoint: CGPointMake(79.34f, 469.73f)];
    [bezierPath addLineToPoint: CGPointMake(108.64f, 469.73f)];
    [bezierPath addLineToPoint: CGPointMake(108.64f, 440.33f)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(117.18f, 431.4f)];
    [bezierPath addCurveToPoint: CGPointMake(117.18f, 477.4f) controlPoint1: CGPointMake(117.18f, 431.4f) controlPoint2: CGPointMake(117.18f, 477.4f)];
    [bezierPath addLineToPoint: CGPointMake(71.18f, 477.4f)];
    [bezierPath addLineToPoint: CGPointMake(71.18f, 431.4f)];
    [bezierPath addLineToPoint: CGPointMake(117.18f, 431.4f)];
    [bezierPath addLineToPoint: CGPointMake(117.18f, 431.4f)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(128.28f, 420.29f)];
    [bezierPath addLineToPoint: CGPointMake(60.43f, 420.29f)];
    [bezierPath addLineToPoint: CGPointMake(60.43f, 489.43f)];
    [bezierPath addLineToPoint: CGPointMake(128.28f, 489.43f)];
    [bezierPath addLineToPoint: CGPointMake(128.28f, 420.29f)];
    [bezierPath closePath];
    
    bezierPath.lineCapStyle  = kCGLineCapRound;
    bezierPath.lineJoinStyle = kCGLineJoinRound;
    
    return bezierPath;
}
@end
