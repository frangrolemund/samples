//
//  UISealDetailViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/13/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ChatSealIdentity;
@interface UISealDetailViewController : UITableViewController  
-(void) setIdentity:(ChatSealIdentity *) psi;
@end
