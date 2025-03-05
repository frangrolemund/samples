//
//  UISealAboutViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/16/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ChatSealIdentity;
@interface UISealAboutViewController : UITableViewController
-(void) setIdentity:(ChatSealIdentity *) psi;
@end
