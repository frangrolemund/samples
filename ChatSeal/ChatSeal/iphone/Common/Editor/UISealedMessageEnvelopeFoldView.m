//
//  UISealedMessageEnvelopeFoldView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/13/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "UISealedMessageEnvelopeFoldView.h"
#import "ChatSeal.h"

// - constants
static const int     UISMEF_BACK_SHADOW_VW = 100;
static const CGFloat UISMEF_BACKDROP_PAD   = 10.0f;

// - forward declarations
@interface UISealedMessageEnvelopeFoldView (internal)
-(void) commonConfiguration;
@end

//  - this class is used to present a slight shadow over
//    the content when we fold the envelope
@interface UIFoldingShadow : UIView
@end

/********************************
 UISealedMessageEnvelopeFoldView
 ********************************/
@implementation UISealedMessageEnvelopeFoldView
/*
 *  Object attributes
 */
{
    UIView             *vwBackdrop;
    UIView             *vwPaper;
    UIView             *vwContent;
    UIFoldingShadow    *vwShadow;
    UIView             *vwTopEdge;
    BOOL               hasTopShadow;
    BOOL               hasBotShadow;
    UIView             *vwFarBack;
}

/*
 *  Initialize the object.
 */
-(id) initWithContentView:(UIView *) cv withTopShadow:(BOOL) hasTop andBottomShadow:(BOOL) hasBot
{
    self = [super initWithFrame:cv.frame];
    if (self) {
        vwContent       = [cv retain];
        hasTopShadow    = hasTop;
        hasBotShadow    = hasBot;
        vwFarBack       = nil;
        [self commonConfiguration];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [vwContent release];
    vwContent = nil;
    
    [vwPaper release];
    vwPaper = nil;

    [vwShadow release];
    vwShadow = nil;
    
    [vwTopEdge release];
    vwTopEdge = nil;
    
    [vwBackdrop release];
    vwBackdrop = nil;
    
    [vwFarBack release];
    vwFarBack = nil;
    
    [super dealloc];
}

/*
 *  Enable/disable the folding shadow, which provides a nice gradient that simulates
 *  the paper being obscured.
 */
-(void) setFoldingShadowVisible:(BOOL) isVisible withTopEdgeShadow:(BOOL) hasTopEdge
{
    //  - the primary shadow is what gives the illusion of the folded sections.
    vwShadow.alpha = (isVisible ? 1.0f : 0.0f);
    
    // - in the case of the top flap, we want an extra shadow that can be used to differentate it from the bottom flap.
    if (hasTopEdge) {
        if (!vwTopEdge) {
            vwTopEdge                     = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 2.0f, CGRectGetWidth(self.bounds), 1.0f)];
            vwTopEdge.autoresizingMask    = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
            vwTopEdge.backgroundColor     = [ChatSeal defaultPaperColor];
            vwTopEdge.autoresizingMask    = UIViewAutoresizingFlexibleWidth;
            vwTopEdge.layer.shadowRadius  = 2.0f;
            vwTopEdge.layer.shadowOffset  = CGSizeMake(0.0f, -1.0f);
            vwTopEdge.layer.shadowOpacity = 1.0f;
            vwTopEdge.layer.shadowColor   = [[UIColor colorWithWhite:0.0f alpha:0.7f] CGColor];
            [self insertSubview:vwTopEdge belowSubview:vwPaper];
        }
        vwTopEdge.alpha            = 1.0f;
    }
    else {
        vwTopEdge.alpha = 0.0f;
    }
}

/*
 *  This can be used for debugging purposes since a transform view cannot have color.
 */
-(void) setBackgroundColor:(UIColor *)backgroundColor
{
    vwPaper.backgroundColor = backgroundColor;
}

/*
 *  Return the view used to present a backdrop shadow, which allows the caller
 *  the opportunity to configure it.
 */
-(UIView *) backdropShadowView
{
    UIView *vw = [vwBackdrop viewWithTag:UISMEF_BACK_SHADOW_VW];
    return [[vw retain] autorelease];
}

/*
 *  Show/hide the backdrop shadow.
 */
-(void) setBackdropShadowVisible:(BOOL) isVisible
{
    [self backdropShadowView].alpha = (isVisible ? 1.0f : 0.0f);
}

/*
 *  The far back view is under everything and is used for addressing the envelope.
 */
-(void) setFarbackView:(UIView *) vw inRect:(CGRect) rc
{
    if (vw != [vwFarBack.subviews lastObject]) {
        // - remove the previous view.
        [vwFarBack removeFromSuperview];
        [vwFarBack release];
        
        // - and create a new one that we can carefully control.
        vwFarBack                   = [[UIView alloc] initWithFrame:vw.frame];
        vwFarBack.layer.transform   = CATransform3DMakeRotation((CGFloat) M_PI, 1.0f, 0.0f, 0.0f);              //  only visible after rotation, like the paper
        vwFarBack.layer.doubleSided = NO;
        vwFarBack.layer.zPosition   = -1.0f;                                                                    //  to overlay the paper in the end.
        vw.autoresizingMask         = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [vwFarBack addSubview:vw];
        
        [self addSubview:vwFarBack];
    }
    
    // - no matter what, the frame is always set.
    rc              = CGRectIntegral(rc);
    vwFarBack.frame = rc;
}

@end

/******************************************
 UISealedMessageEnvelopeFoldView (internal)
 ******************************************/
@implementation UISealedMessageEnvelopeFoldView (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    // - in order to get really precise replacement shadows for the envelope's unfolded paper I'm
    //   using a shadow view inside a clipping container that will have its sides adjusted based
    //   on what we wish to show since it is tough to obscure only one side of a view's shadows and
    //   still get a compatible offset/opacity to what the parent is using.
    CGRect rcItem                = CGRectMake(0.0f, 0.0f, CGRectGetWidth(vwContent.frame), CGRectGetHeight(vwContent.frame));
    CGRect rcBackdrop            = CGRectOffset(CGRectInset(rcItem, -UISMEF_BACKDROP_PAD, 0.0f), 0.0f, 1.0f);
    CGFloat shadVPad             = 0.0f;
    if (hasTopShadow) {
        rcBackdrop               = CGRectOffset(rcBackdrop, 0.0f, -UISMEF_BACKDROP_PAD);
        rcBackdrop.size.height  += UISMEF_BACKDROP_PAD;
        shadVPad                 = UISMEF_BACKDROP_PAD;
    }
    if (hasBotShadow) {
        rcBackdrop.size.height  += UISMEF_BACKDROP_PAD;
    }
    vwBackdrop                   = [[UIView alloc] initWithFrame:rcBackdrop];
    vwBackdrop.autoresizingMask  = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    vwBackdrop.clipsToBounds     = YES;
    vwBackdrop.layer.doubleSided = NO;
    vwBackdrop.layer.zPosition   = -0.02f;
    [self addSubview:vwBackdrop];
    
    UIView *vwBDShadow           = [[UIView alloc] initWithFrame:CGRectOffset(rcItem, UISMEF_BACKDROP_PAD, shadVPad)];
    vwBDShadow.autoresizingMask  = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    vwBDShadow.backgroundColor   = [ChatSeal defaultPaperColor];
    vwBDShadow.tag               = UISMEF_BACK_SHADOW_VW;
    [vwBackdrop addSubview:vwBDShadow];
    [vwBDShadow release];
    [self setBackdropShadowVisible:NO];
    
    // - ...and the back paper, which will be visible when the shadow disappers.
    vwPaper = [[UIView alloc] initWithFrame:rcItem];
    vwPaper.autoresizingMask    = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    vwPaper.backgroundColor     = [ChatSeal defaultPaperColor];
    [self addSubview:vwPaper];
    vwPaper.layer.transform     = CATransform3DMakeRotation((CGFloat) M_PI, 1.0f, 0.0f, 0.0f);  //  only visible after rotation
    vwPaper.layer.zPosition     = 0.0f;                                                         //  too big of a value and we'll get a disproportionate rotation.
    vwPaper.layer.doubleSided   = YES;

    // - add the content in the middle
    vwContent.frame             = rcItem;
    vwContent.autoresizingMask  = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    vwContent.layer.zPosition   = 0.5f;
    vwContent.layer.doubleSided = NO;
    [self addSubview:vwContent];
    
    // - create the shadow view that will overlay the content.
    vwShadow = [[UIFoldingShadow alloc] initWithFrame:rcItem];
    vwShadow.autoresizingMask  = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    vwShadow.alpha = 0.0f;
    vwShadow.layer.zPosition   = 0.7f;
    vwShadow.layer.doubleSided = NO;
    [self addSubview:vwShadow];
}
@end

/*****************************
 UIFoldingShadow
 *****************************/
@implementation UIFoldingShadow
/*
 *  This shadow is presented with a gradient.
 */
+(Class) layerClass
{
    return [CAGradientLayer class];
}

/*
 *  Initialize the object.
 */
-(id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        CAGradientLayer *gl = (CAGradientLayer *) self.layer;
        gl.locations        = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0.0f], [NSNumber numberWithFloat:0.5f], [NSNumber numberWithFloat:1.0f], nil];
        gl.colors           = [NSArray arrayWithObjects:(id) [[UIColor colorWithWhite:0.0f alpha:0.25f] CGColor],
                                                        (id) [[UIColor colorWithWhite:0.0f alpha:0.05f] CGColor],
                                                        (id)[[UIColor colorWithWhite:0.0f alpha:0.0f] CGColor], nil];
    }
    return self;
}

@end
