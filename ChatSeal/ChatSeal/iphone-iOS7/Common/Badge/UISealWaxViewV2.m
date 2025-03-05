//
//  UISealWaxViewV2.m
//  ChatSeal
//
//  Created by Francis Grolemund on 9/3/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealWaxViewV2.h"
#import "UIWaxRingViewV2.h"
#import "ChatSeal.h"

// - constants
static const CGFloat UISWL_ZORDER_INNER = 2.0f;
static const CGFloat UISWL_ZORDER_MID   = 1.0f;
static const CGFloat UISWL_ZORDER_OUTER = 0.0f;

// - forward declarations
@interface UISealWaxViewV2 (internal)
-(void) commonConfiguration;
-(void) drawInnerRingInRect:(CGRect) rc;
@end

/***************
 UISealWaxViewV2
 ***************/
@implementation UISealWaxViewV2
/*
 *  Object attributes.
 */
{
    BOOL               isValidLookingWax;
    BOOL               isLocked;
    
    UIView             *vwCenter;
    CGFloat            lastCenterDiam;
    UIWaxRingViewV2    *wrvMid;
    UIWaxRingViewV2    *wrvOuter;
}
/*
 *  Initialize the class.
 */
+(void) initialize
{
    [UISealWaxViewV2 verifyResources];
}

/*
 *  Pre-cache necessary resources.
 */
+(void) verifyResources
{
    [UIWaxRingViewV2 verifyResources];
}

/*
 *  Return the diameter of the center cut-out area.
 */
+(CGFloat) centerDiameterFromRect:(CGRect) rc
{
    CGSize sz   = rc.size;
    CGFloat ret = 0.0;
    if (sz.width > sz.height) {
        ret = sz.width * [UIWaxRingViewV2 centerPercentage];
    }
    else {
        ret = sz.height * [UIWaxRingViewV2 centerPercentage];
    }
    return (CGFloat) floor(ret);
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
    [vwCenter release];
    vwCenter = nil;
    
    [wrvMid release];
    wrvMid = nil;
    
    [wrvOuter release];
    wrvOuter = nil;
    
    [super dealloc];
}

/*
 *  Return the diameter of the center cut-out area.
 */
-(CGFloat) centerDiameterFromCurrentBounds
{
    return [UISealWaxViewV2 centerDiameterFromRect:self.bounds];
}
/*
 *  Assign this as an valid/invalid item, which when invalid, generates a
 *  simplistic design that can be used as a missing seal sign.
 */
-(void) setSealWaxValid:(BOOL) isValidWax
{
    isValidLookingWax = isValidWax;
}

/*
 *  Assign the seal colors.
 */
-(void) setOuterColor:(UIColor *) cOuter andMidColor:(UIColor *) cMid andInnerColor:(UIColor *) cInner
{
    isValidLookingWax          = YES;
    vwCenter.layer.borderColor = [cInner CGColor];
    [wrvMid setRingColor:cMid];
    [wrvOuter setRingColor:cOuter];
}

/*
 *  Set the locked/unlocked state.
 */
-(void) setLocked:(BOOL)locked
{
    isLocked = locked;
    [wrvMid setLocked:locked];
    [wrvOuter setLocked:locked];
}

/*
 *  Return the current locked state.
 */
-(BOOL) locked
{
    return isLocked;
}

/*
 *  When displaying content in a small form factor, it is important to change the way that these images are
 *  scaled in the layers or they'll look like shit.
 */
-(void) prepareForSmallDisplay
{
    [wrvMid prepareForSmallDisplay];
    [wrvOuter prepareForSmallDisplay];
}

/*
 *  Show/hide the center ring.
 */
-(void) setCenterVisible:(BOOL) isVisible
{
    vwCenter.alpha = isVisible ? 1.0f : 0.0f;
}

/*
 *  Perform layout.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    CGSize szBounds = self.bounds.size;
    
    // - place the center ring precisely.
    CGFloat centerDiam = [self centerDiameterFromCurrentBounds];
    CGFloat width      = MAX((CGFloat) floor(centerDiam * [UIWaxRingViewV2 narrowRingPercentage]), 1.5f);
    if ((int) centerDiam != (int) lastCenterDiam) {
        lastCenterDiam              = width;
        vwCenter.layer.borderWidth  = width;
        vwCenter.layer.cornerRadius = centerDiam/2.0f;
    }
    vwCenter.bounds    = CGRectIntegral(CGRectMake(0.0f, 0.0f, centerDiam, centerDiam));
    vwCenter.center    = CGPointMake(szBounds.width/2.0f, szBounds.height/2.0f);
    
    // - now size the wax rings to the size of this view.
    wrvMid.frame       = self.bounds;
    wrvOuter.frame     = self.bounds;
    
    //  - now apply the transforms in those rings, but do so manually to control the shadow.
    [wrvMid setLocked:isLocked];
    [wrvOuter setLocked:isLocked];
}

/*
 *  Draw this wax for use in decoy generation.
 */
-(void) drawForDecoyRect:(CGRect) rc
{
    // - be damn sure the layout has occurred.
    [self setNeedsLayout];
    [self layoutIfNeeded];
    
    CGContextSaveGState(UIGraphicsGetCurrentContext());
    
    // - draw the inner ring first.
    [self drawInnerRingInRect:rc];
    
    // - now the other rings.
    [wrvMid drawForDecoyInRect:rc asValid:isValidLookingWax];
    [wrvOuter drawForDecoyInRect:rc asValid:isValidLookingWax];
    
    CGContextRestoreGState(UIGraphicsGetCurrentContext());

}

/*
 *  Draw a stylized seal in the given rectangle.
 *  - this is intentionally much less detailed than it normally is.
 */
+(void) drawStylizedVersionAsColor:(RSISecureSeal_Color_t) color inRect:(CGRect) rc
{
    ChatSealColorCombo *pscc = [ChatSeal sealColorsForColor:color];
    if (color == RSSC_INVALID) {
        // - the color for invalid seals isn't quite dark enough to show through
        //   the frosted pane.
        pscc.cMid = [UIColor darkGrayColor];
    }

    // - we're only using the foreground color here, assuming the seal is
    //   drawn in a pseudo-locked state.

    CGContextSaveGState(UIGraphicsGetCurrentContext());
    CGContextSetBlendMode(UIGraphicsGetCurrentContext(), kCGBlendModeNormal);

    // - we'll need the center one way or another.
    CGFloat diam     = [self centerDiameterFromRect:rc];
    CGPoint ptCenter = CGPointMake(CGRectGetMinX(rc) + (CGRectGetWidth(rc)/2.0f), CGRectGetMinY(rc) + (CGRectGetHeight(rc)/2.0f));
    CGRect  rcCenter = CGRectMake(ptCenter.x - (diam/2.0f), ptCenter.y - (diam/2.0f), diam, diam);

    // - draw the center if this is valid, which will be an alpha blended version.
    if (pscc.isValid) {
        UIColor *c = [pscc.cMid colorWithAlphaComponent:0.25f];
        [c setFill];
        CGContextFillEllipseInRect(UIGraphicsGetCurrentContext(), rcCenter);
    }

    // - draw the rings
    CGFloat lineWidth = (CGRectGetWidth(rc) - diam)/2.0f;
    CGFloat pad       = lineWidth/4.0f;
    lineWidth         = (lineWidth - pad)/2.0f;
    [pscc.cMid setStroke];
    CGFloat twoPi = (CGFloat) M_PI * 2.0f;

    CGContextSetLineWidth(UIGraphicsGetCurrentContext(), lineWidth);
    CGContextBeginPath(UIGraphicsGetCurrentContext());
    CGContextAddArc(UIGraphicsGetCurrentContext(), ptCenter.x, ptCenter.y, (diam/2.0f + lineWidth/2.0f), -twoPi*0.1f, -twoPi*0.14f, 0);
    CGContextStrokePath(UIGraphicsGetCurrentContext());

    CGContextBeginPath(UIGraphicsGetCurrentContext());
    CGContextAddArc(UIGraphicsGetCurrentContext(), ptCenter.x, ptCenter.y, (diam/2.0f + lineWidth + pad), (CGFloat) M_PI-twoPi*0.1f, (CGFloat) M_PI-twoPi*0.14f, 0);
    CGContextStrokePath(UIGraphicsGetCurrentContext());
    
    CGContextRestoreGState(UIGraphicsGetCurrentContext());
}

/*
 *  There is a change being made to the wax, so this is our chance to coordinate the bounds change 
 *  animation with the mask in the view.
 */
-(void) coordinateMaskSizingWithBoundsAnimation:(CAAnimation *) anim
{
    [wrvMid coordinateMaskSizingWithBoundsAnimation:anim];
    [wrvOuter coordinateMaskSizingWithBoundsAnimation:anim];
    
    // - we also have to create an animation for the corner radius
    if (vwCenter.layer.presentationLayer) {
        CABasicAnimation *animCorner = [ChatSeal duplicateAnimation:anim forNewKeyPath:@"cornerRadius"];
        animCorner.fromValue         = [NSNumber numberWithFloat:(float)((CALayer *)vwCenter.layer.presentationLayer).cornerRadius];
        animCorner.toValue           = [NSNumber numberWithFloat:(float) vwCenter.layer.cornerRadius];
        [vwCenter.layer addAnimation:animCorner forKey:@"cornerRadius"];
    }
}

@end

/**************************************
 UISealWaxViewV2 (internal)
 **************************************/
@implementation UISealWaxViewV2 (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    isValidLookingWax        = NO;
    isLocked                 = NO;
    
    // - probably a good idea to do this from the outside-in.
    wrvOuter                 = [[UIWaxRingViewV2 alloc] initAsOuterRing:YES];
    wrvOuter.zPosition       = UISWL_ZORDER_OUTER;
    [self addSubview:wrvOuter];
    
    wrvMid                   = [[UIWaxRingViewV2 alloc] initAsOuterRing:NO];
    wrvMid.zPosition         = UISWL_ZORDER_MID;
    [self addSubview:wrvMid];
    
    vwCenter                 = [[UIView alloc] init];
    vwCenter.backgroundColor = [UIColor clearColor];
    vwCenter.layer.zPosition = UISWL_ZORDER_INNER;
    [self addSubview:vwCenter];
    lastCenterDiam           = -1.0f;
    
    self.backgroundColor     = [UIColor clearColor];
}

/*
 *  Draw the inner ring.
 */
-(void) drawInnerRingInRect:(CGRect) rc
{
    CGFloat scale              = CGRectGetWidth(rc)/CGRectGetWidth(self.bounds);
    CGRect innerAdjusted       = vwCenter.bounds;
    innerAdjusted.size.width  *= scale;
    innerAdjusted.size.height *= scale;
    innerAdjusted              = CGRectIntegral(CGRectOffset(innerAdjusted,
                                                (CGRectGetWidth(rc) - innerAdjusted.size.width)/2.0f,
                                                (CGRectGetHeight(rc) - innerAdjusted.size.height)/2.0f));
    innerAdjusted              = CGRectOffset(innerAdjusted, rc.origin.x, rc.origin.y);

    if (vwCenter.layer.borderColor) {
        CGFloat borderWidth = vwCenter.layer.borderWidth;
        CGContextSaveGState(UIGraphicsGetCurrentContext());
        if (isValidLookingWax) {
            CGContextSetStrokeColorWithColor(UIGraphicsGetCurrentContext(),  vwCenter.layer.borderColor);
            CGContextSetLineWidth(UIGraphicsGetCurrentContext(), MAX(borderWidth/2.0f, 1.0f));
            CGFloat inset = 1.0f;
            CGContextStrokeEllipseInRect(UIGraphicsGetCurrentContext(), CGRectIntegral(CGRectInset(innerAdjusted, inset, inset)));
        }
        else {
            [[ChatSeal defaultInvalidSealColor] setStroke];
            CGContextSetLineWidth(UIGraphicsGetCurrentContext(), MAX(borderWidth/4.0f, 1.0f));
            CGFloat inset = MAX(borderWidth, 2.0f);
            CGContextStrokeEllipseInRect(UIGraphicsGetCurrentContext(), CGRectInset(innerAdjusted, inset, inset));
        }
        CGContextRestoreGState(UIGraphicsGetCurrentContext());
    }
}
@end