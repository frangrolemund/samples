//
//  UISealExpirationViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/15/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ChatSealIdentity;
@interface UISealExpirationViewController : UITableViewController
-(void) setIdentity:(ChatSealIdentity *) psi;
@end
