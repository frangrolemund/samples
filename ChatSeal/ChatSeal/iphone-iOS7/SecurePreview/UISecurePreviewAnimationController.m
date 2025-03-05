//
//  UISecurePreviewAnimationController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 11/21/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UISecurePreviewAnimationController.h"
#import "UIMessageDetailViewControllerV2.h"
#import "UISecurePreviewViewController.h"

//  - shared with the animation controller
@interface UISecurePreviewViewController (shared)
-(void) prepareForNavigationTransition;
-(void) addKeyframesForTransitionToThisView:(BOOL) toThisView;
-(void) navigationTransitionWasCancelled;
-(void) navigationWasCompletedToViewController:(UIViewController *) vc;
@end

@interface UIMessageDetailViewControllerV2 (shared)
-(void) prepareForSecurePreviewTransitionToThisView:(BOOL) toThisView;
-(void) addKeyframesForSecurePreviewTransitionToThisView:(BOOL) toThisView;
@end

/************************************
 UISecurePreviewAnimationController
 ************************************/
@implementation UISecurePreviewAnimationController
/*
 *  Object attributes
 */
{
    UIChatSealNavigationInteractiveTransition *interactiveController;
}

/*
 *  Initialize the object.
 */
-(id) initWithInteractiveController:(UIChatSealNavigationInteractiveTransition *) ic
{
    self = [super init];
    if (self) {
        interactiveController = [ic retain];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [interactiveController release];
    interactiveController = nil;
    
    [super dealloc];
}

/*
 *  Returns an interactive controller for this animation controller.
 */
-(UIChatSealNavigationInteractiveTransition *) interactiveController
{
    // - this is to rule out the interactivePopGestureRecognizer in the UINavigationController    
    if (interactiveController.gesture.numberOfTouches > 0) {
        return [[interactiveController retain] autorelease];
    }
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
 *  Animate the transition to/from the photo access view controller.
 */
-(void) animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    UIViewController *vcFrom = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *vcTo   = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    CGRect rcFinal           = [transitionContext finalFrameForViewController:vcTo];
    
    // - we're either move to or from the secure preview view controller.
    BOOL isTo = NO;
    UISecurePreviewViewController *spv   = nil;
    UIMessageDetailViewControllerV2 *mdv = nil;
    if ([vcTo isKindOfClass:[UISecurePreviewViewController class]]) {
        isTo = YES;
        [[transitionContext containerView] addSubview:vcTo.view];
        spv = (UISecurePreviewViewController *) vcTo;
        
        if ([vcFrom isKindOfClass:[UIMessageDetailViewControllerV2 class]]) {
            mdv = (UIMessageDetailViewControllerV2 *) vcFrom;
        }
    }
    else {
        [[transitionContext containerView] insertSubview:vcTo.view belowSubview:vcFrom.view];
        spv = (UISecurePreviewViewController *) vcFrom;
        
        if ([vcTo isKindOfClass:[UIMessageDetailViewControllerV2 class]]) {
            mdv = (UIMessageDetailViewControllerV2 *) vcTo;
        }
    }
    
    vcTo.view.frame = rcFinal;
    if (spv) {
        //  - we're going to perform the keyframe control here because both of the views need to participate.
        [spv prepareForNavigationTransition];
        [mdv prepareForSecurePreviewTransitionToThisView:!isTo];
        [UIView animateKeyframesWithDuration:[self transitionDuration:transitionContext] delay:0.0f options:0 animations:^(void) {
            [spv addKeyframesForTransitionToThisView:isTo];
            [mdv addKeyframesForSecurePreviewTransitionToThisView:!isTo];
        }completion:^(BOOL finished) {
            if ([transitionContext transitionWasCancelled]) {
                if (!isTo) {
                    [spv navigationTransitionWasCancelled];
                }
            }
            else {
                [spv navigationWasCompletedToViewController:vcTo];
            }
            
            [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
        }];
    }
    else {
        NSLog(@"CS: Did not find a secure preview view controller.");
        [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
    }
}
@end
