//
//  UIChatSealNavigationController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 10/4/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIChatSealNavigationInteractiveTransition.h"
#import "UIDynamicTypeCompliantEntity.h"

// - all view controllers that want to participate in nav-item transitioning should adopt this
//   protocol.
@protocol UIChatSealNavItemAnimatedTransitioning <UIViewControllerAnimatedTransitioning>
-(UIChatSealNavigationInteractiveTransition *) interactiveController;
@end

//  - the nav controller will look for items along the way that can return custom animations
@protocol UIChatSealCustomNavTransitionDelegate <NSObject>
-(id<UIChatSealNavItemAnimatedTransitioning>) navItemInController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC;
@optional
-(void) navigationWillPushThisViewController;
-(void) navigationWillPopThisViewController;
@end

//  - the standard navigation controller for the app.
@interface UIChatSealNavigationController : UINavigationController <UIDynamicTypeCompliantEntity>
+(UINavigationController *) instantantiateNavigationControllerWithRoot:(UIViewController *) vc;
-(void) setIsApplicationPrimary;
@end
