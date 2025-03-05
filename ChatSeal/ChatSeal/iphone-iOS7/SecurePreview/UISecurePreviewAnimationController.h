//
//  UISecurePreviewAnimationController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 11/21/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UIChatSealNavigationController.h"
#import "UIChatSealNavigationInteractiveTransition.h"

@interface UISecurePreviewAnimationController : NSObject<UIChatSealNavItemAnimatedTransitioning>
-(id) initWithInteractiveController:(UIChatSealNavigationInteractiveTransition *) ic;
@end
