//
//  UIHubMessageDetailAnimationController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 12/4/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UIHubMessageDetailAnimationController.h"
#import "UIMessageDetailViewControllerV2.h"
#import "UIMessageOverviewViewController.h"
#import "ChatSeal.h"

// - constants
static const int     UIHMDA_STD_TAG_TOP     = 10001;
static const int     UIHMDA_STD_TAG_BOT     = 10002;
static const int     UIHMDA_STD_TAG_SHADOW  = 10003;
static const int     UIHMDA_STD_TAG_SEARCH  = 10004;
static const int     UIHMDA_STD_TAG_TABS    = 10005;
static const CGFloat UIHMDA_STD_SPRING_DAMP = 0.75f;
static const CGFloat UIHMDA_STD_SPRING_VEL  = 0.0f;
static const CGFloat UIHMDA_STD_TOP_OVERLAY = 50.0f;

// - shared with the hub.
@interface UIHubViewController (hubRelatedTransition)
-(void) prepareForTransition;
-(CGRect) tabsRectForOpening:(BOOL) isOpening;
-(void) setAllHubContentVisible:(BOOL) isVisible;
-(UIView *) containerView;
@end

// - transition APIs that are shared.
@interface UIMessageOverviewViewController (detailTransition)
-(void) setActiveMessageAnimationReady:(BOOL) isReadyForAnim;
-(void) setActiveMessagePresentationLocked:(BOOL) isLocked;
-(CGFloat) activeMessageSplitPosition;
-(CGFloat) searchBarSplitPosition;
-(void) completedReturnFromDetail;
@end

// - transition APIs that are shared.
@interface UIMessageDetailViewControllerV2 (overviewTransition)
-(void) completedOverviewReturnTransition;
@end

// - my own methods.
@interface UIHubMessageDetailAnimationController (internal)
-(void) animateTransitionOverDuration:(NSTimeInterval) duration asInteractive:(BOOL) isInteractive forMessageOverview:(UIMessageOverviewViewController *) mov
                     andMessageDetail:(UIMessageDetailViewControllerV2 *) mdv asPush:(BOOL) isPush withCompletion:(void(^)(void)) completionBlock;
-(void) hubTransitionWasCompletedToDetail:(BOOL) isToDetail withOverview:(UIMessageOverviewViewController *) mov andDetail:(UIMessageDetailViewControllerV2 *) mdv;
-(void) hubTransitionWasCancelledFromDetail:(UIMessageDetailViewControllerV2 *) mdv toOverview:(UIMessageOverviewViewController *) mov;
@end

/**************************************
 UIHubMessageDetailAnimationController
 **************************************/
@implementation UIHubMessageDetailAnimationController
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
    if ([transitionContext isInteractive]) {
        return 0.75f;
    }
    else {
        return 1.0f;
    }
}

/*
 *  Animate the transition to/from the photo access view controller.
 */
-(void) animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    UIViewController *vcFrom = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *vcTo   = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIViewController *vcHub  = [[ChatSeal applicationHub] currentViewController];
    CGRect rcFinal           = [transitionContext finalFrameForViewController:vcTo];
    
    // - confirm that the hub is involved here.
    if ((![vcFrom isKindOfClass:[UIHubViewController class]] && ![vcTo isKindOfClass:[UIHubViewController class]]) ||
         ![vcHub isKindOfClass:[UIMessageOverviewViewController class]]) {
        NSLog(@"CS:  Invalid hub transition.");
        [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
        return;
    }
    
    // - we're either move to or from the secure preview view controller.
    BOOL isTo = NO;
    UIMessageOverviewViewController *mov = (UIMessageOverviewViewController *) vcHub;
    UIMessageDetailViewControllerV2 *mdv = nil;
    if ([vcTo isKindOfClass:[UIMessageDetailViewControllerV2 class]]) {
        isTo = YES;
        mdv = (UIMessageDetailViewControllerV2 *) vcTo;
        [[transitionContext containerView] insertSubview:vcTo.view belowSubview:vcFrom.view];   //  add the detail below
    }
    else {
        mdv = (UIMessageDetailViewControllerV2 *) vcFrom;
        [[transitionContext containerView] addSubview:vcTo.view];                               //  add the hub above
    }
    
    vcTo.view.frame = rcFinal;
    [self animateTransitionOverDuration:[self transitionDuration:transitionContext] asInteractive:[transitionContext isInteractive]
                                             forMessageOverview:mov andMessageDetail:mdv asPush:isTo withCompletion:^(void) {
        [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
        if ([transitionContext transitionWasCancelled]) {
            if (!isTo) {
                [self hubTransitionWasCancelledFromDetail:mdv toOverview:mov];
            }
        }
        else {
            [self hubTransitionWasCompletedToDetail:isTo withOverview:mov andDetail:mdv];
        }
    }];
}
@end

/************************************************
 UIHubMessageDetailAnimationController (internal)
 ************************************************/
@implementation UIHubMessageDetailAnimationController (internal)
/*
 *  Prepare the hub's tabs for opening/closing the overview.
 */
-(void) prepareHubTabsForOpening:(BOOL) isOpening
{
    UIView *vwHub  = [[ChatSeal applicationHub] view];
    CGFloat height = CGRectGetHeight(vwHub.bounds);
    [UIView performWithoutAnimation:^(void) {
        // - prepare everything for the required transition.
        [[ChatSeal applicationHub] prepareForTransition];
        
        // - the tabs must be snapshot separately, but since they apply translucency, we need to snap them where they exist in the context of
        //   the superview hierarchy.
        // - but, we need to compute their offset based on their constraint-based location in the coordinate system.
        CGRect rcTabs          = [[ChatSeal applicationHub] tabsRectForOpening:isOpening];
        UIView *vwTabs         = [vwHub resizableSnapshotViewFromRect:CGRectInset(rcTabs, 0.0f, -1.0f) afterScreenUpdates:YES withCapInsets:UIEdgeInsetsZero];
        vwTabs.tag             = UIHMDA_STD_TAG_TABS;
        vwTabs.layer.zPosition = UIHMDA_STD_TOP_OVERLAY;
        vwTabs.frame           = CGRectOffset(vwTabs.frame, 0.0f, isOpening ? height - CGRectGetHeight(vwTabs.bounds) + 1.0f : height);
        vwTabs.alpha           = isOpening ? 0.0f : 1.0f;
        [vwHub addSubview:vwTabs];
    }];
}

/*
 *  Prepare to open/close the overview screen.
 */
-(void) prepareMessageOverview:(UIMessageOverviewViewController *) mov forOpening:(BOOL) isOpening
{
    [UIView performWithoutAnimation:^(void) {
        // - first get the vertical split points
        CGFloat vSplit = [mov activeMessageSplitPosition];
        CGFloat sSplit = [mov searchBarSplitPosition];
        
        UIView *vwHub       = [[ChatSeal applicationHub] view];
        UIView *vwContainer = [[ChatSeal applicationHub] containerView];
        
        // - and some details about the hub's view.
        CGFloat width  = CGRectGetWidth(vwHub.bounds);
        CGFloat height = CGRectGetHeight(vwHub.bounds);
        
        // - since the hub is sized to the same height as the content, we're going to assume the split
        //   is accurate in our coordinate space
        // - NOTE:  The snapshots must be taken after screen updates or rotations will not be procssed correctly.
        UIView *vwSrch = nil;
        if (sSplit > 0.0f) {
            vwSrch                 = [vwContainer resizableSnapshotViewFromRect:CGRectMake(0.0f, 0.0f, width, sSplit) afterScreenUpdates:YES withCapInsets:UIEdgeInsetsZero];
            vwSrch.tag             = UIHMDA_STD_TAG_SEARCH;
            vwSrch.layer.zPosition = UIHMDA_STD_TOP_OVERLAY;
            vwSrch.alpha           = isOpening ? 1.0f : 0.0f;
        }
        UIView *vwTop  = [vwContainer resizableSnapshotViewFromRect:CGRectMake(0.0f, 0.0f, width, vSplit) afterScreenUpdates:YES withCapInsets:UIEdgeInsetsZero];
        vwTop.tag      = UIHMDA_STD_TAG_TOP;
        UIView *vwBot  = [vwContainer resizableSnapshotViewFromRect:CGRectMake(0.0f, vSplit, width, height - vSplit) afterScreenUpdates:YES withCapInsets:UIEdgeInsetsZero];
        vwBot.tag      = UIHMDA_STD_TAG_BOT;
        
        // - now based on whether we're opening or closing, we'll offset the three snapshots' locations.
        vwTop.frame    = CGRectOffset(vwTop.frame, 0.0f, isOpening ? 0.0f : -vSplit);
        vwBot.frame    = CGRectOffset(vwBot.frame, 0.0f, isOpening ? vSplit : height);
        
        // - build a shadowy view that we can slowly hide.
        UIView *vwShadow         = [[[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, width, height)] autorelease];
        vwShadow.tag             = UIHMDA_STD_TAG_SHADOW;
        vwShadow.backgroundColor = [ChatSeal defaultLowChromeShadowColor];
        vwShadow.alpha           = isOpening ? 1.0f : 0.0f;
        
        // - add the views
        [vwHub addSubview:vwShadow];
        [vwHub addSubview:vwBot];
        [vwHub addSubview:vwTop];
        if (vwSrch) {
            [vwHub addSubview:vwSrch];
        }
        
        // - hide the background while we complete the animation.
        [[ChatSeal applicationHub] setAllHubContentVisible:NO];
    }];
}

/*
 *  Remove the views used for animation.
 */
-(void) removeTemporaryAnimatedViews
{
    UIView *vwHub = [[ChatSeal applicationHub] view];
    [[vwHub viewWithTag:UIHMDA_STD_TAG_TOP] removeFromSuperview];
    [[vwHub viewWithTag:UIHMDA_STD_TAG_BOT] removeFromSuperview];
    [[vwHub viewWithTag:UIHMDA_STD_TAG_SHADOW] removeFromSuperview];
    [[vwHub viewWithTag:UIHMDA_STD_TAG_SEARCH] removeFromSuperview];
}

/*
 *  The tabs must be removed last because they are animated with the lock action.
 */
-(void) removeTemporaryTabView
{
    UIView *vwHub = [[ChatSeal applicationHub] view];
    [[vwHub viewWithTag:UIHMDA_STD_TAG_TABS] removeFromSuperview];
}

/*
 *  The process of opening/closing the message view requires we grab good screen shots before doing so and then
 *  cause them to split apart or come together.
 */
-(void) displayMessageOverview:(UIMessageOverviewViewController *) mov asOpening:(BOOL) isOpening andInteractive:(BOOL) isInteractive
{
    // - we can't prepare the display elements during an interactive transition because it occurs
    //   within the keyframe and causes some problems.
    if (!isInteractive) {
        [self prepareMessageOverview:mov forOpening:isOpening];
    }
    
    // - first get the vertical split point
    CGFloat vSplit = [mov activeMessageSplitPosition];
    
    // - and some details about this view.
    UIView *vwHub = [[ChatSeal applicationHub] view];
    CGFloat height = CGRectGetHeight(vwHub.bounds);
    
    UIView *vwTop    = [vwHub viewWithTag:UIHMDA_STD_TAG_TOP];
    UIView *vwBot    = [vwHub viewWithTag:UIHMDA_STD_TAG_BOT];
    UIView *vwShadow = [vwHub viewWithTag:UIHMDA_STD_TAG_SHADOW];
    UIView *vwTabs   = [vwHub viewWithTag:UIHMDA_STD_TAG_TABS];
    
    // - now move the content.
    vwShadow.alpha = isOpening ? 0.0f : 1.0f;
    vwTop.frame    = CGRectOffset(vwTop.frame, 0.0f, isOpening ? -vSplit : vSplit);
    vwBot.frame    = CGRectOffset(vwBot.frame, 0.0f, isOpening ? height : -CGRectGetHeight(vwBot.frame));
    vwTabs.frame   = CGRectOffset(vwTabs.frame, 0.0f, isOpening ? height : -CGRectGetHeight(vwTabs.frame) + 1.0f);
}

/*
 *  When we're returning to the overview from the detail screen, we should
 *  fade the change back to the original value of the search.
 */
-(void) fadeSearchForReturn;
{
    UIView *vwHub  = [[ChatSeal applicationHub] view];
    UIView *vwSrch = [vwHub viewWithTag:UIHMDA_STD_TAG_SEARCH];
    vwSrch.alpha   = 1.0f;
}

/*
 *  Manage the animation between the message overview window and the detail.
 */
-(void) animateTransitionOverDuration:(NSTimeInterval) duration asInteractive:(BOOL) isInteractive forMessageOverview:(UIMessageOverviewViewController *) mov
                     andMessageDetail:(UIMessageDetailViewControllerV2 *) mdv asPush:(BOOL) isPush withCompletion:(void(^)(void)) completionBlock
{
    // - the first step is to upgrade the current cell so that it can do animation.
    [mov setActiveMessageAnimationReady:YES];
    
    // - and move it to locked/unlocked based on which direction we're headed
    [mov setActiveMessagePresentationLocked:isPush];
    
    // - the tabs' visibility is animated with the lock and therefore must be set up.
    [self prepareHubTabsForOpening:isPush];
    
    // - animate the message opening or closing with the lock turning and it splitting apart.
    UIView *vwTmpTabs            = [[ChatSeal applicationHub].view viewWithTag:UIHMDA_STD_TAG_TABS];
    if (isPush) {
        NSTimeInterval splitDuration = duration - [ChatSeal standardLockDuration];
        [UIView animateWithDuration:[ChatSeal standardLockDuration] animations:^(void) {
            [mov setActiveMessagePresentationLocked:NO];
            vwTmpTabs.alpha = 1.0f;
        }completion:^(BOOL finished) {
            [UIView animateWithDuration:splitDuration delay:0.0f usingSpringWithDamping:UIHMDA_STD_SPRING_DAMP initialSpringVelocity:UIHMDA_STD_SPRING_VEL options:0 animations:^(void) {
                [self displayMessageOverview:mov asOpening:YES andInteractive:isInteractive];
            } completion:^(BOOL finished2) {
                if (completionBlock) {
                    completionBlock();
                }
            }];
        }];
    }
    else {
        // - on the return trip, if we're not interactive, apply the standard spring animation, otherwise, we need
        //   to use keyframes to get the right kind of reopen effect when the transition is cancelled.
        if (isInteractive) {
            [self prepareMessageOverview:mov forOpening:NO];
            [UIView animateKeyframesWithDuration:duration delay:0.0f options:0 animations:^(void) {
                [UIView addKeyframeWithRelativeStartTime:0.0f relativeDuration:1.0f animations:^(void) {
                    [self displayMessageOverview:mov asOpening:NO andInteractive:YES];
                }];
                [UIView addKeyframeWithRelativeStartTime:0.0f relativeDuration:0.25f animations:^(void) {
                    [self fadeSearchForReturn];
                }];
            }completion:^(BOOL finished) {
                if (completionBlock) {
                    completionBlock();
                }
            }];
        }
        else {
            [UIView animateWithDuration:duration delay:0.0f usingSpringWithDamping:UIHMDA_STD_SPRING_DAMP initialSpringVelocity:UIHMDA_STD_SPRING_VEL options:0 animations:^(void) {
                [self displayMessageOverview:mov asOpening:NO andInteractive:NO];
            } completion:^(BOOL finished2) {
                if (completionBlock) {
                    completionBlock();
                }
            }];
        }
    }
}

/*
 *  When the hub transition completes successfully, this method is issued.
 */
-(void) hubTransitionWasCompletedToDetail:(BOOL) isToDetail withOverview:(UIMessageOverviewViewController *) mov andDetail:(UIMessageDetailViewControllerV2 *) mdv
{
    [[ChatSeal applicationHub] setAllHubContentVisible:YES];
    [self removeTemporaryAnimatedViews];
    
    // - if we just returned frokm the detail screen, do the locking last
    if (isToDetail) {
        [self removeTemporaryTabView];
    }
    else {
        [mdv completedOverviewReturnTransition];
        [mov completedReturnFromDetail];        
        [UIView animateWithDuration:[ChatSeal standardLockDuration] animations:^(void) {
            [mov setActiveMessagePresentationLocked:YES];
            [[ChatSeal applicationHub].view viewWithTag:UIHMDA_STD_TAG_TABS].alpha = 0.0f;
        } completion:^(BOOL finished) {
            [mov setActiveMessageAnimationReady:NO];
            [self removeTemporaryTabView];
        }];
    }
}

/*
 *  The transition back to the hub was cancelled.
 */
-(void) hubTransitionWasCancelledFromDetail:(UIMessageDetailViewControllerV2 *) mdv toOverview:(UIMessageOverviewViewController *) mov
{
    [self removeTemporaryAnimatedViews];
    [self removeTemporaryTabView];
}
@end

