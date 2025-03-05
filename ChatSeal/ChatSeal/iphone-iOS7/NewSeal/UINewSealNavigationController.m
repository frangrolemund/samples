//
//  UINewSealNavigationController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/26/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UINewSealNavigationController.h"

/*******************************
 UINewSealNavigationController
 *******************************/
@implementation UINewSealNavigationController
/*
 *  The new seal window will only work in portrait mode with minor adjustments when rotating
 *  otherwise.
 */
-(NSUInteger) supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

@end
