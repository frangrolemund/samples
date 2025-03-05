//
//  UISealedMessageExportAnimationController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/8/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UISealedMessageExportAnimationController.h"
#import "UISealedMessageExportViewController.h"

//  - shared with the animation controller
@interface UISealedMessageExportViewController (shared)
-(void) animateNavigationTransitionToThisView:(BOOL) toThisView withDuration:(NSTimeInterval) duration andCompletion:(void(^)(void)) completionBlock;
-(void) navigationTransitionWasCancelled;
-(void) navigationWasCompletedToViewController:(UIViewController *) vc;
@end

/*********************************************
 UISealedMessageExportAnimationController
 *********************************************/
@implementation UISealedMessageExportAnimationController
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
    return 2.0f;
}

/*
 *  Animate the transition to/from the export view controller.
 */
-(void) animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    UIViewController *vcFrom = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *vcTo   = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    CGRect rcFinal           = [transitionContext finalFrameForViewController:vcTo];
    
    // - we're either moving to or from the message export view controller
    BOOL isTo = NO;
    UISealedMessageExportViewController *evc = nil;
    if ([vcTo isKindOfClass:[UISealedMessageExportViewController class]]) {
        isTo = YES;
        [[transitionContext containerView] addSubview:vcTo.view];
        evc = (UISealedMessageExportViewController *) vcTo;
    }
    else {
        [[transitionContext containerView] insertSubview:vcTo.view belowSubview:vcFrom.view];
        evc = (UISealedMessageExportViewController *) vcFrom;
    }
    
    vcTo.view.frame = rcFinal;
    if (evc) {
        [(UISealedMessageExportViewController *) evc animateNavigationTransitionToThisView:isTo withDuration:[self transitionDuration:transitionContext] andCompletion:^(void){
            if (!isTo) {
                if ([transitionContext transitionWasCancelled]) {
                    [evc navigationTransitionWasCancelled];
                }
                else {
                    [evc navigationWasCompletedToViewController:vcTo];
                }
            }
            [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
        }];
    }
    else {
        NSLog(@"CS: Did not find an export view controller.");
        [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
    }
}

@end
