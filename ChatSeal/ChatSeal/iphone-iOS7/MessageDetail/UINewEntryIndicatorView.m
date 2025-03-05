//
//  UINewEntryIndicatorView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/5/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UINewEntryIndicatorView.h"
#import "ChatSeal.h"
#import "UIImageGeneration.h"

// - constants
static const CGFloat UINEI_STD_SIDE            = 40.0f;
static const CGFloat UINEI_STD_DIRECTION_PAD   = 10.0f;
static const NSUInteger UINEI_MAX_COUNT        = 99;             // to keep the display looking as good as possible.
static const CGFloat UINEI_STD_DIR_LINE        = 1.0f;
static const CGFloat UINEI_STD_OFFSET_PCT      = 1.0f/4.0f;
static const CGFloat UINEI_STD_BORDER_WIDTH    = 1.0f;

// - forward declarations
@interface UINewEntryIndicatorView (internal)
-(void) commonConfigurationWithOrientation:(BOOL) isUp;
-(void) displayTapped;
@end

@interface UINewEntryDisplayView : UIButton
-(void) setOrientationIsUp:(BOOL) isUp;
-(NSUInteger) newEntryCount;
-(void) setNewEntryCount:(NSUInteger) count;
@end

/*****************************
 UINewEntryIndicatorView
 *****************************/
@implementation UINewEntryIndicatorView
/*
 *  Object attributes.
 */
{
    UINewEntryDisplayView *nedDisplay;
    BOOL                  isBeingDisplayed;
}
@synthesize delegate;

/*
 *  Initialize the object.
 */
-(id) initWithOrientationAsUp:(BOOL) isUp
{
    CGSize szFrame = [self sizeThatFits:CGSizeZero];
    self           = [super initWithFrame:CGRectMake(0.0f, 0.0f, szFrame.width, szFrame.height)];
    if (self) {
        [self commonConfigurationWithOrientation:isUp];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    delegate = nil;
    [nedDisplay release];
    nedDisplay = nil;
    
    [super dealloc];
}

/*
 *  The new entry indicator is a constant dimension.
 */
-(CGSize) sizeThatFits:(CGSize)size
{
    return CGSizeMake(UINEI_STD_SIDE, UINEI_STD_SIDE + UINEI_STD_DIRECTION_PAD);
}

/*
 *  Assign a count to this object.
 */
-(void) setNewEntryCount:(NSUInteger) count withAnimation:(BOOL) animated
{
    // - we may want to animate this to make the transition nicer.
    if (animated && count != [nedDisplay newEntryCount] && isBeingDisplayed) {
        UIView *vwSnap                = [nedDisplay snapshotViewAfterScreenUpdates:YES];
        vwSnap.userInteractionEnabled = NO;
        nedDisplay.alpha = 0.0f;
        [self addSubview:vwSnap];
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            vwSnap.alpha = 0.0f;
            nedDisplay.alpha = 1.0f;
        }completion:^(BOOL finished) {
            [vwSnap removeFromSuperview];
        }];
    }
    
    // - update the display button
    [nedDisplay setNewEntryCount:count];
}

/*
 *  Show/hide the entry indicator.
 */
-(void) setIndicatorVisible:(BOOL) visible withAnimation:(BOOL) animated
{
    if (isBeingDisplayed == visible) {
        return;
    }
    
    CGFloat newVisibility = (visible ? 1.0f : 0.0f);
    if (animated) {
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            nedDisplay.alpha = newVisibility;
        }];
    }
    else {
        nedDisplay.alpha = newVisibility;
    }
    isBeingDisplayed            = visible;
    self.userInteractionEnabled = visible;
}
@end


/***********************************
 UINewEntryIndicatorView (internal)
 ***********************************/
@implementation UINewEntryIndicatorView (internal)
/*
 *  Configure the view.
 */
-(void) commonConfigurationWithOrientation:(BOOL)isUp
{
    // - if there is no indicator, the whole view should be hidden.
    delegate             = nil;
    self.backgroundColor = [UIColor clearColor];
    
    // - use a background display object so that we can optimize the animations
    //   to only change when they absolutely have to.
    nedDisplay                  = [[UINewEntryDisplayView alloc] initWithFrame:self.frame];
    nedDisplay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [nedDisplay addTarget:self action:@selector(displayTapped) forControlEvents:UIControlEventTouchUpInside];
    [nedDisplay setOrientationIsUp:isUp];
    [self addSubview:nedDisplay];
    nedDisplay.alpha            = 1.0f;
    isBeingDisplayed            = YES;
}

/*
 *  When the indicator is tapped, this method is issued.
 */
-(void) displayTapped
{
    if (delegate && [delegate respondsToSelector:@selector(newEntryIndicatorWasTapped:)]) {
        [delegate performSelector:@selector(newEntryIndicatorWasTapped:) withObject:self];
    }
}
@end

/****************************
 UINewEntryDisplayView
 ****************************/
@implementation UINewEntryDisplayView
/*
 *  Object attributes.
 */
{
    NSUInteger       curCount;
    BOOL             orientUp;
}

/*
 *  This is fired when the button is pressed.
 */
-(void) isPressed
{
    [self setNeedsDisplay];
}

/*
 *  Initialize the object.
 */
-(id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        curCount = 0;
        [self addTarget:self action:@selector(isPressed) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDownRepeat | UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [super dealloc];
}

/*
 *  Return the count to apply.
 */
-(NSUInteger) newEntryCount
{
    return curCount;
}

/*
 *  Assign a new count to this object.
 */
-(void) setNewEntryCount:(NSUInteger) count
{
    if (count != curCount) {
        curCount = count;
        [self setNeedsDisplay];
    }
}

/*
 *  Change the orientation of this object.
 */
-(void) setOrientationIsUp:(BOOL) isUp
{
    if (isUp != orientUp) {
        orientUp = isUp;
        [self setNeedsLayout];
        [self setNeedsDisplay];
    }
}

/*
 *  Draw the contents of this object.
 */
-(void) drawRect:(CGRect)rect
{
    CGRect rcBackground = CGRectMake(0.0f, 0.0f, UINEI_STD_SIDE, UINEI_STD_SIDE);
    if (orientUp) {
        rcBackground = CGRectOffset(rcBackground, 0.0f, UINEI_STD_DIRECTION_PAD);
    }
    
    UIColor *cTint = [ChatSeal defaultAppTintColor];
    
    CGContextSaveGState(UIGraphicsGetCurrentContext());
    
    // - we need to start with a background film to obscure, but suggest what is happening behind it.
    CGPoint ptCenter = CGPointMake(CGRectGetWidth(rcBackground)/2.0f, CGRectGetMinY(rcBackground) + CGRectGetHeight(rcBackground)/2.0f);
    CGContextSetAllowsAntialiasing(UIGraphicsGetCurrentContext(), YES);
    BOOL isPressed = (self.state == UIControlStateHighlighted ? YES : NO);
    UIColor *cFilm = [UIImageGeneration adjustColor:[ChatSeal defaultToolBackgroundColor] byHuePct:1.0f andSatPct:1.0f andBrPct:isPressed ? 1.2f : 1.0f andAlphaPct:0.95f];
    [cFilm setFill];
    CGContextBeginPath(UIGraphicsGetCurrentContext());
    CGContextAddArc(UIGraphicsGetCurrentContext(),
                    ptCenter.x,
                    ptCenter.y,
                    UINEI_STD_SIDE/2.0f, 0.0f, (CGFloat) (2.0 * M_PI), 1);
    CGContextFillPath(UIGraphicsGetCurrentContext());
    
    UIColor *cChrome = cTint;
    if (isPressed) {
        cChrome = [UIImageGeneration highlightedColorFromColor:cTint];
    }
    [cChrome setStroke];
    
    // - include the count
    NSString *sCount = nil;
    if (curCount > UINEI_MAX_COUNT) {
        sCount = @"++";
    }
    else {
        sCount = [NSString stringWithFormat:@"%u", (unsigned) curCount];
    }
    NSMutableDictionary *mdAttribs = [NSMutableDictionary dictionary];
    [mdAttribs setObject:[UIFont boldSystemFontOfSize:15.0f] forKey:NSFontAttributeName];
    [mdAttribs setObject:cChrome forKey:NSForegroundColorAttributeName];
    CGSize sz = [sCount sizeWithAttributes:mdAttribs];
    [sCount drawAtPoint:CGPointMake(ptCenter.x - (sz.width/2.0f), ptCenter.y - (sz.height/2.0f)) withAttributes:mdAttribs];
    
    // - and the direction lines.
    CGContextSetLineWidth(UIGraphicsGetCurrentContext(), UINEI_STD_DIR_LINE);
    CGContextSetLineCap(UIGraphicsGetCurrentContext(), kCGLineCapSquare);
    CGPoint theTip    = CGPointMake(ptCenter.x, orientUp ? UINEI_STD_DIR_LINE : CGRectGetHeight(self.bounds) - UINEI_STD_DIR_LINE);
    CGFloat offset    = CGRectGetWidth(self.bounds) * UINEI_STD_OFFSET_PCT;
    CGFloat startLine = orientUp ? UINEI_STD_DIRECTION_PAD - UINEI_STD_DIR_LINE : theTip.y - UINEI_STD_DIRECTION_PAD + UINEI_STD_DIR_LINE;
    CGContextBeginPath(UIGraphicsGetCurrentContext());
    CGContextMoveToPoint(UIGraphicsGetCurrentContext(), offset, startLine);
    CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), theTip.x, theTip.y);
    CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), CGRectGetWidth(self.bounds) - offset, startLine);
    CGContextStrokePath(UIGraphicsGetCurrentContext());
    
    // - and the simple border
    CGContextSetLineWidth(UIGraphicsGetCurrentContext(), 1.0f/[UIScreen mainScreen].scale);
    CGContextBeginPath(UIGraphicsGetCurrentContext());
    CGContextAddArc(UIGraphicsGetCurrentContext(), ptCenter.x, ptCenter.y, (UINEI_STD_SIDE/2.0f - (UINEI_STD_BORDER_WIDTH/2.0f)), 0.0f, (CGFloat) (2.0f * M_PI), 1);
    CGContextStrokePath(UIGraphicsGetCurrentContext());
    
    CGContextRestoreGState(UIGraphicsGetCurrentContext());
}

@end