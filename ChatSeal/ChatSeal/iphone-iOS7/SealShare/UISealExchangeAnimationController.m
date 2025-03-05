//
//  UISealExchangeAnimationController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/17/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealExchangeAnimationController.h"
#import "UISealShareViewController.h"
#import "UISealAcceptViewController.h"
#import "ChatSeal.h"

// - constants
static const CGFloat UISEA_STD_EYEPOS          = 1000.0f;

// - a background for this transition.
@interface UISealExchangeAnimationBackdropView : UIView
@end

/***********************************
 UISealExchangeAnimationController
 ***********************************/
@implementation UISealExchangeAnimationController
/*
 *  We aren't going to support interactive transitions between exchange views because
 *  the animations simply won't make sense.
 */
-(UIChatSealNavigationInteractiveTransition *) interactiveController
{
    return nil;
}

/*
 *  Return the duration of the transition.
 */
-(NSTimeInterval) transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext
{
    return 0.5f;
}

/*
 *  Animate the transition to/from the export view controller.
 */
-(void) animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    UIViewController *vcFrom = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *vcTo   = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    CGRect rcFinal           = [transitionContext finalFrameForViewController:vcTo];
    
    // - the animation is really quite portable since it doesn't rely on any custom content in either view
    //   for it to work.
    
    
    // - create a temporary backdrop.
    UIView *vwContainer = [transitionContext containerView];
    UISealExchangeAnimationBackdropView *sbv = [[[UISealExchangeAnimationBackdropView alloc] initWithFrame:rcFinal] autorelease];
    [vwContainer addSubview:sbv];
    
    // - ...and add perspective and push the to-view to the back to give it the appearance of rotating into place.
    CATransform3D perspective           = CATransform3DIdentity;
    perspective.m34                     = -1.0f/UISEA_STD_EYEPOS;
    sbv.layer.sublayerTransform         = perspective;
    CGFloat backZPos                    = -UISEA_STD_EYEPOS/2.0f;
    vcTo.view.layer.zPosition           = backZPos;
    
    // - we're going to work in the perspective-adjusted background.
    [sbv addSubview:vcTo.view];
    [sbv addSubview:vcFrom.view];
    
    // - do the animation, but we're just going to use simple layer animations so that we get the right curves.
    NSTimeInterval tiDuration = [self transitionDuration:transitionContext];
    [UIView animateKeyframesWithDuration:tiDuration delay:0.0f options:0.0f animations:^(void) {
        [CATransaction begin];
        
        // - fade out the foreground item initially.
        [UIView addKeyframeWithRelativeStartTime:0.0f relativeDuration:0.75f animations:^(void) {
            vcFrom.view.alpha = 0.0f;
        }];
        
        // - move the foreground to the back
        CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"zPosition"];
        anim.fromValue         = [NSNumber numberWithFloat:0.0f];
        anim.toValue           = [NSNumber numberWithFloat:(float) backZPos];
        anim.duration          = tiDuration;
        [vcFrom.view.layer addAnimation:anim forKey:@"zPosition"];
        
        anim                = [CABasicAnimation animationWithKeyPath:@"transform"];
        anim.fromValue      = [NSValue valueWithCATransform3D:CATransform3DIdentity];
        anim.toValue        = [NSValue valueWithCATransform3D:CATransform3DMakeTranslation(-CGRectGetWidth(rcFinal)/5.0f, 0.0f, 0.0f)];
        anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        anim.autoreverses   = YES;
        anim.duration       = tiDuration/2.0f;
        [vcFrom.view.layer addAnimation:anim forKey:@"transform"];
        
        // - move the background to the front.
        anim = [CABasicAnimation animationWithKeyPath:@"zPosition"];
        anim.fromValue            = [NSNumber numberWithFloat:(float) backZPos];
        anim.toValue              = [NSNumber numberWithFloat:0.0f];
        anim.duration             = tiDuration;
        [vcTo.view.layer addAnimation:anim forKey:@"zPosition"];
        vcTo.view.layer.zPosition = 0.0f;
        
        anim                = [CABasicAnimation animationWithKeyPath:@"transform"];
        anim.fromValue      = [NSValue valueWithCATransform3D:CATransform3DIdentity];
        anim.toValue        = [NSValue valueWithCATransform3D:CATransform3DMakeTranslation(CGRectGetWidth(rcFinal)/5.0f, 0.0f, 0.0f)];
        anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        anim.autoreverses   = YES;
        anim.duration       = tiDuration/2.0f;
        [vcTo.view.layer addAnimation:anim forKey:@"transform"];
        
        [CATransaction commit];
        
    } completion:^(BOOL finished) {
        // - make sure the to-view is in the container now
        [vwContainer addSubview:vcTo.view];
        
        // - remove the temporary backdrop
        [sbv removeFromSuperview];
        
        // - and reset the transforms
        vcTo.view.layer.transform   = CATransform3DIdentity;
        vcFrom.view.layer.transform = CATransform3DIdentity;
        
        // - and complete the transition.
        [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
    }];
}

@end

/*************************************
 UISealExchangeAnimationBackdropView
 *************************************/
@implementation UISealExchangeAnimationBackdropView
/*
 *  Initialize the view.
 */
-(id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [ChatSeal defaultIconColor];
    }
    return self;
}

/*
 *  Draw this item.
 */
-(void) drawRect:(CGRect)rect
{
    [self.backgroundColor setFill];
    UIRectFill(self.bounds);
    
    CGSize szBounds        = self.bounds.size;
    CGGradientRef gradient = CGGradientCreateWithColors(NULL, (CFArrayRef) [NSArray arrayWithObjects:(id) [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.0f].CGColor,
                                                                                                     (id) [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:1.0f].CGColor, nil],
                                                        NULL);
    CGPoint ptCenter  = CGPointMake(szBounds.width/2.0f, szBounds.height/2.0f);
    CGFloat longSide  = MAX(szBounds.width, szBounds.height);
    CGContextDrawRadialGradient(UIGraphicsGetCurrentContext(), gradient, ptCenter, 0.0f, ptCenter, longSide*0.75f, kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(gradient);
}
@end