//
//  UIGettingStartedViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 9/20/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIHubViewController.h"

@interface UIGettingStartedViewController : UIViewController <UIHubManagedViewController>
-(IBAction)doAcceptTheSeal:(id)sender;
@property (nonatomic, retain) IBOutlet UIButton *bAcceptSeal;
@end
