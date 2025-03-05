//
//  UIChatSealNavigationBar.h
//  ChatSeal
//
//  Created by Francis Grolemund on 9/10/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIChatSealNavigationBar : UINavigationBar
-(void) setLayoutRebuildEnabled:(BOOL) isEnabled;
-(void) assignStandardNavStyleInsideNavigationController:(UINavigationController *) nc;
-(void) assignLaunchCompatibleNavStyle;
@end
