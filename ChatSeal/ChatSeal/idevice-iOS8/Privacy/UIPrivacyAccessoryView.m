//
//  UIPrivacyAccessoryView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 12/3/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIPrivacyAccessoryView.h"
#import "CHatSeal.h"

// - constants
static const CGFloat UIPA_STD_STROKE_WIDTH   = 1.5f;
static const CGSize  UIPA_STD_INDICATOR_SIZE = {8.0f, 13.0f};

// - forward declarations
@interface UIPrivacyDrawnIndicatorView : UIView
@end

/***********************
 UIPrivacyAccessoryView
 ***********************/
@implementation UIPrivacyAccessoryView
/*
 *  Object attributes.
 */
{
    UIPrivacyDrawnIndicatorView *pdi;
}

/*
 *  Initialize this view.
 */
-(id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.opaque          = NO;
        self.backgroundColor = [UIColor clearColor];
        pdi                  = [[UIPrivacyDrawnIndicatorView alloc] init];
        [pdi sizeToFit];
        [self addSubview:pdi];
        [self setDisplayAsOpen:NO withAnimation:NO];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [pdi release];
    pdi = nil;
    
    [super dealloc];
}

/*
 *  Return the size of this view.
 */
-(CGSize) sizeThatFits:(CGSize)size
{
    // - this is the size of the standard accessory display indicator.
    CGFloat bigSide = MAX(UIPA_STD_INDICATOR_SIZE.width, UIPA_STD_INDICATOR_SIZE.height);
    return CGSizeMake(bigSide, bigSide);
}

/*
 *  Perform layout.
 */
-(void) layoutSubviews
{
    pdi.center = CGPointMake((CGFloat) floor(CGRectGetWidth(self.bounds)/2.0), (CGFloat) floor(CGRectGetHeight(self.bounds)/2.0));
}

/*
 *  Change the orientation of the accessory to reflect open vs closed.
 */
-(void) setDisplayAsOpen:(BOOL) isOpen withAnimation:(BOOL) animated
{
    CGAffineTransform at;
    if (isOpen) {
        at = CGAffineTransformMakeRotation((CGFloat)(-M_PI_2));
    }
    else {
        at = CGAffineTransformMakeRotation((CGFloat)(M_PI_2));
    }
    
    // - apply the transform to highlight the state.
    if (animated) {
        [UIView animateKeyframesWithDuration:[ChatSeal standardItemFadeTime] delay:0.0f options:0 animations:^(void) {
            [UIView addKeyframeWithRelativeStartTime:0.0f relativeDuration:0.5f animations:^(void) {
                pdi.transform = CGAffineTransformIdentity;
            }];
            [UIView addKeyframeWithRelativeStartTime:0.5f relativeDuration:0.5f animations:^(void) {
                pdi.transform = at;
            }];
        }completion:nil];
    }
    else {
        pdi.transform = at;
    }
}

@end

/**********************************
 UIPrivacyDrawnIndicatorView
 **********************************/
@implementation UIPrivacyDrawnIndicatorView

/*
 *  Initialize this view.
 */
-(id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

/*
 *  Return the size of this view.
 */
-(CGSize) sizeThatFits:(CGSize)size
{
    // - this is the size of the standard accessory display indicator.
    return CGSizeMake(8.0f, 13.0f);
}

/*
 *  Draw this item.
 */
-(void) drawRect:(CGRect)rect
{
    CGContextSaveGState(UIGraphicsGetCurrentContext());
    
    [[UIColor clearColor] setFill];
    UIRectFill(self.bounds);
    
    // - stroke a simple partial triangle.
    [[UIColor colorWithWhite:0.77f alpha:1.0f] setStroke];
    CGContextSetLineWidth(UIGraphicsGetCurrentContext(), UIPA_STD_STROKE_WIDTH);
    CGContextSetLineCap(UIGraphicsGetCurrentContext(), kCGLineCapSquare);
    
    CGContextBeginPath(UIGraphicsGetCurrentContext());
    CGContextMoveToPoint(UIGraphicsGetCurrentContext(), UIPA_STD_STROKE_WIDTH, UIPA_STD_STROKE_WIDTH);
    CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), CGRectGetWidth(self.bounds) - UIPA_STD_STROKE_WIDTH, CGRectGetHeight(self.bounds)/2.0f);
    CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), UIPA_STD_STROKE_WIDTH, CGRectGetHeight(self.bounds) - UIPA_STD_STROKE_WIDTH);
    CGContextStrokePath(UIGraphicsGetCurrentContext());
    
    CGContextRestoreGState(UIGraphicsGetCurrentContext());
}
@end
