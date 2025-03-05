//
//  UITwitterFriendAdjustmentViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/24/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ChatSealFeedFriend;
@class CS_tfsFriendshipAdjustment;
@interface UITwitterFriendAdjustmentViewController : UITableViewController
-(void) setFriend:(ChatSealFeedFriend *) ff withAdjustment:(CS_tfsFriendshipAdjustment *) adj;
-(IBAction)doAction:(id)sender;
@end
