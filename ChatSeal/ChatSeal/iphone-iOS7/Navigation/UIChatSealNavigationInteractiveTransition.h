//
//  UIChatSealNavigationInteractiveTransition.h
//  ChatSeal
//
//  Created by Francis Grolemund on 10/4/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIChatSealNavigationInteractiveTransition : UIPercentDrivenInteractiveTransition
-(id) initWithViewController:(UIViewController *) vc;
-(void) setAllowTransitionToStart:(BOOL) enabled;
-(UIGestureRecognizer *) gesture;
@end
