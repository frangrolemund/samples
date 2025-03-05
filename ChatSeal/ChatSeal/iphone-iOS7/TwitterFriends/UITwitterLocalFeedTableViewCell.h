//
//  UITwitterLocalFeedTableViewCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/23/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIFormattedTwitterFeedAddressView.h"
#import "UIGenericSizableTableViewCell.h"

@class UITwitterLocalFeedTableViewCell;
@protocol UITwitterLocalFeedTableViewCellDelegate <NSObject>
-(void) twitterLocalFeedCellActionWasPressed:(UITwitterLocalFeedTableViewCell *) tlc;
@end

@class CS_tfsFriendshipAdjustment;
@class ChatSealFeedFriend;
@interface UITwitterLocalFeedTableViewCell : UIGenericSizableTableViewCell
-(void) reconfigureWithFriendshipAdjustment:(CS_tfsFriendshipAdjustment *) adj forFriend:(ChatSealFeedFriend *) feedFriend andAnimation:(BOOL) animated;
-(IBAction)doFeedAction:(id)sender;
@property (nonatomic, retain) IBOutlet UIFormattedTwitterFeedAddressView  *favAddress;
@property (nonatomic, retain) IBOutlet UILabel                            *lStatus;
@property (nonatomic, retain) IBOutlet UIButton                           *bAction;
@property (nonatomic, assign) id<UITwitterLocalFeedTableViewCellDelegate> delegate;
@end
