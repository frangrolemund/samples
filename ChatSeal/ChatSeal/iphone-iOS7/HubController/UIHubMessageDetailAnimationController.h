//
//  UIHubMessageDetailAnimationController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 12/4/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UIChatSealNavigationController.h"
#import "UIChatSealNavigationInteractiveTransition.h"

@interface UIHubMessageDetailAnimationController : NSObject<UIChatSealNavItemAnimatedTransitioning>
-(id) initWithInteractiveController:(UIChatSealNavigationInteractiveTransition *) ic;
@end
