//
//  UISealScreenshotViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/16/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ChatSealIdentity;
@interface UISealScreenshotViewController : UITableViewController
-(void) setIdentity:(ChatSealIdentity *) psi;
-(IBAction)doScreenshotChange;
@property (nonatomic, retain) IBOutlet UISwitch *swScreenshot;
@end
