//
//  tdriverNavigationViewController.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 4/14/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import "tdriverNavigationViewController.h"

//  - we just need to allow all orientations to make sure
//    control sizing/orientation works correctly.
//  - the nav controller sets the pace for everything else.
@implementation tdriverNavigationViewController

-(NSUInteger) supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

/*
 *  Give a test window the opportunity to prevent rotation.
 */
-(BOOL) shouldAutorotate
{
    UIViewController *vc = self.topViewController;
    return [vc shouldAutorotate];
}

@end
