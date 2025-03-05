//
//  UISealedMessageDeliveryAnimationController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 12/12/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UISealedMessageDeliveryAnimationController.h"
#import "UISealedMessageExportViewController.h"
#import "UIMessageDetailViewControllerV2.h"

//  - shared with the animation controller
@interface UISealedMessageExportViewController (shared)
-(void) animateDeliveryTransitionToDetail:(UIMessageDetailViewControllerV2 *) mdvc withDuration:(NSTimeInterval) duration andCompletion:(void(^)(void)) completionBlock;
-(void) navigationWasCompletedToViewController:(UIViewController *) vc;
@end

/*******************************************
 UISealedMessageDeliveryAnimationController
 *******************************************/
@implementation UISealedMessageDeliveryAnimationController
/*
 *  This isn't supported as an interactive transition.
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
    return 1.0f;
}

/*
 *  Animate the transition from the export view controller.
 */
-(void) animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    UIViewController *vcFrom = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *vcTo   = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    CGRect rcFinal           = [transitionContext finalFrameForViewController:vcTo];
    
    // - this can only work when we move backwards, so don't entertain any other options.
    UISealedMessageExportViewController *evc = nil;
    UIMessageDetailViewControllerV2 *mdv     = nil;
    if ([vcFrom isKindOfClass:[UISealedMessageExportViewController class]] &&
        [vcTo isKindOfClass:[UIMessageDetailViewControllerV2 class]]) {
        [[transitionContext containerView] insertSubview:vcTo.view belowSubview:vcFrom.view];
        evc = (UISealedMessageExportViewController *) vcFrom;
        mdv = (UIMessageDetailViewControllerV2 *) vcTo;
    }
    else {
        NSLog(@"CS:  Incorrect delivery animation controller usage.");
        [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
        return;
    }
    
    vcTo.view.frame = rcFinal;
    [evc animateDeliveryTransitionToDetail:mdv withDuration:[self transitionDuration:transitionContext] andCompletion:^(void) {
        [evc navigationWasCompletedToViewController:mdv];
        [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
    }];
}

@end
