//
//  UIPSRefreshView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 12/8/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UIPSRefreshView.h"

// - constants
static const CGFloat UICS_RV_ONE_SIDE = 19.0f;
static const int     UICS_RV_TICKS    = 12;
static const CGFloat UICS_RV_TICK_W   = 2.0f;
static const CGFloat UICS_RV_TICK_H   = 5.0f;

// - forward declarations
@interface UIPSRefreshView (internal)
-(void) commonConfiguration;
-(void) displayLinkTriggered;
@end

/**********************
 UIPSRefreshView
 **********************/
@implementation UIPSRefreshView
/*
 *  Object attributes.
 */
{
    CGFloat       pctComplete;
    int           animOffset;
    CADisplayLink *dlRedraw;
    BOOL          isPaused;
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
    [dlRedraw release];
    dlRedraw = nil;
    
    [super dealloc];
}

/*
 *  Size this object.
 */
-(CGSize) sizeThatFits:(CGSize)size
{
    return CGSizeMake(UICS_RV_ONE_SIDE, UICS_RV_ONE_SIDE);
}

/*
 *  The refresh control draws only its completion percentage 
 *  for each frame.
 */
-(void) setRefreshCompletionPercentage:(CGFloat) pct
{
    pctComplete = MIN(pct, 1.0f);
    [self setNeedsDisplay];
    if (pctComplete == 1.0f) {
        // - reset the offset each time we get unpaused
        //   to maintain a consistent startup experience.
        if (isPaused) {
            animOffset = 0;
        }
        isPaused = NO;
    }
    else {
        isPaused = YES;
    }
    [dlRedraw setPaused:isPaused];
}

/*
 *  Redraw the refresh view.
 */
-(void) drawRect:(CGRect)rect
{
    [super drawRect:rect];
    
    // - offset from the center
    CGSize szBounds    = self.bounds.size;
    CGFloat halfHeight = szBounds.height/2.0f;
    CGContextTranslateCTM(UIGraphicsGetCurrentContext(), szBounds.width/2.0f, halfHeight);
    
    // - create all the visible ticks.
    CGFloat oneTickPct = 1.0f / (CGFloat) UICS_RV_TICKS;
    UIColor *cBaseline = [UIColor colorWithWhite:157.0f/255.0f alpha:1.0f];
    CGFloat curAlpha   = isPaused ? 1.0f : ((CGFloat) animOffset) * oneTickPct;
    for (CGFloat pos = 0.0f; pos < pctComplete; pos += oneTickPct) {
        // - prepare the region
        CGContextSaveGState(UIGraphicsGetCurrentContext());
        CGContextRotateCTM(UIGraphicsGetCurrentContext(), (((CGFloat) M_PI * 2.0f) * pos));
        CGContextTranslateCTM(UIGraphicsGetCurrentContext(), 0.0f, -halfHeight);
        
        // - the color depends on whether we're animating.
        [[cBaseline colorWithAlphaComponent:(1.0f - ((0.8f * curAlpha) + 0.2f))] setFill];
        curAlpha = curAlpha - oneTickPct;
        if (curAlpha < 0.0f) {
            curAlpha += 1.0f;
        }
        
        // - draw the tick
        CGFloat halfTickWidth = UICS_RV_TICK_W/2.0f;
        CGFloat tickSide      = UICS_RV_TICK_H - UICS_RV_TICK_W;
        
        CGContextBeginPath(UIGraphicsGetCurrentContext());
        CGContextMoveToPoint(UIGraphicsGetCurrentContext(), -halfTickWidth, halfTickWidth);
        CGContextAddArc(UIGraphicsGetCurrentContext(), 0, halfTickWidth, halfTickWidth, (CGFloat) M_PI, (CGFloat) M_PI * 2.0f, 0);
        CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), halfTickWidth, halfTickWidth + tickSide);
        CGContextAddArc(UIGraphicsGetCurrentContext(), 0, halfTickWidth + tickSide, halfTickWidth, 0, (CGFloat) M_PI, 0);
        CGContextClosePath(UIGraphicsGetCurrentContext());
        CGContextFillPath(UIGraphicsGetCurrentContext());
        CGContextRestoreGState(UIGraphicsGetCurrentContext());
    }
}

/*
 *  When this view is no longer being used, make sure its display link is invalidated
 *  so this can be destroyed.
 */
-(void) removeFromSuperview
{
    [dlRedraw invalidate];    
    [super removeFromSuperview];
}

@end


/***************************
 UIPSRefreshView (internal)
 ***************************/
@implementation UIPSRefreshView (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    pctComplete                     = 0.0f;
    animOffset                      = 0;
    dlRedraw                        = [[CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkTriggered)] retain];
    dlRedraw.frameInterval          = 5;
    isPaused                        = YES;
    dlRedraw.paused                 = isPaused;
    [dlRedraw addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    
    self.backgroundColor            = [UIColor clearColor];
    self.opaque                     = NO;
    self.clearsContextBeforeDrawing = YES;
}

/*
 *  This method is called whenever the display link fires.
 */
-(void) displayLinkTriggered
{
    animOffset = (animOffset + 1) % UICS_RV_TICKS;
    [self setNeedsDisplay];
}
@end