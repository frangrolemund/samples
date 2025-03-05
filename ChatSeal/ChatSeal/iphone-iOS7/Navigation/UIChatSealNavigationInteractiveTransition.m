//
//  UIChatSeallNavigationInteractiveTransition.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/4/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UIChatSealNavigationInteractiveTransition.h"
#import "ChatSeal.h"

// - forward declarations
@interface UIChatSealNavigationInteractiveTransition (internal) <UIGestureRecognizerDelegate>
-(void) panOccurred;
@end

/*****************************************
 UIChatSealNavigationInteractiveTransition
 *****************************************/
@implementation UIChatSealNavigationInteractiveTransition
/*
 *  Object attributes.
 */
{
    UIViewController                 *parent;
    UIScreenEdgePanGestureRecognizer *grPanning;
    BOOL                             isInteractive;
    CGFloat                          curCompletion;
    BOOL                             allowToStart;
}

/*
 *  Initialize the object.
 */
-(id) initWithViewController:(UIViewController *) vc
{
    self = [super init];
    if (self) {
        allowToStart                     = YES;
        isInteractive                    = NO;
        curCompletion                    = 0.0f;
        parent                           = vc;           // only assign!
        grPanning                        = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(panOccurred)];
        grPanning.edges                  = UIRectEdgeLeft;
        [vc.view addGestureRecognizer:grPanning];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    parent = nil;
    
    [grPanning.view removeGestureRecognizer:grPanning];
    [grPanning release];
    grPanning = nil;
    
    [super dealloc];
}

/*
 *  Return the completion speed for the transition based on its current state.
 */
-(CGFloat) completionSpeed
{
    if ([ChatSeal isIOSVersionBEFORE8]) {
        // - a value of 1.0 will cause the animation to repeat itself after an
        //   interactive transition is cancelled, but this value appears to
        //   result in the behavior we're looking for.
        // - I have no clue what to think about this, except that it must be a
        //   bug in the percent-driven transition.
        return 0.99f;
    }
    else {
        return 1.0f;
    }
}

/*
 *  Return the gesture we're working with.
 */
-(UIGestureRecognizer *) gesture
{
    return [[grPanning retain] autorelease];
}

/*
 *  The view controller needs to enable/disable this behavior only after transitions are completed or
 *  there will be problems with the nav controller.  It cannot pop view controllers while a transition is pending.
 */
-(void) setAllowTransitionToStart:(BOOL) enabled
{
    allowToStart = enabled;
}
@end

/*****************************************************
 UIChatSealNavigationInteractiveTransition (internal)
 *****************************************************/
@implementation UIChatSealNavigationInteractiveTransition (internal)

/*
 *  This method is issued when the user swipes on the view.
 */
-(void) panOccurred
{
    curCompletion = [grPanning translationInView:parent.view].x / (parent.view.bounds.size.width * 1.0f);
    curCompletion = MIN(1.0f, MAX(0.0f, curCompletion));
    
    switch (grPanning.state) {
        case UIGestureRecognizerStatePossible:
            //  do nothing.
            break;
            
        case UIGestureRecognizerStateBegan:
            if (allowToStart) {
                [parent.navigationController popViewControllerAnimated:YES];
                curCompletion = 0.0f;
                isInteractive = YES;
            }
            break;
            
        case UIGestureRecognizerStateChanged:
            if (isInteractive) {
                [self updateInteractiveTransition:curCompletion];
            }
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateCancelled:
            if (isInteractive) {
                if (grPanning.state == UIGestureRecognizerStateCancelled || (1.0f - curCompletion) > 0.5f) {
                    [self cancelInteractiveTransition];
                }
                else {
                    [self finishInteractiveTransition];
                }
            }
            break;
    }
}
@end