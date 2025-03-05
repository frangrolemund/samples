//
//  UISealedMessageExportAnimationController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 10/8/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIChatSealNavigationController.h"
#import "UIChatSealNavigationInteractiveTransition.h"

@interface UISealedMessageExportAnimationController : NSObject<UIChatSealNavItemAnimatedTransitioning>
-(id) initWithInteractiveController:(UIChatSealNavigationInteractiveTransition *) ic;
@end
