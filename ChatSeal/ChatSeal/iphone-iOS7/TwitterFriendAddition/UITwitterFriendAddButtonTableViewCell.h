//
//  UITwitterFriendAddButtonTableViewCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 8/30/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIGenericSizableTableViewCell.h"

@class UITwitterFriendAddButtonTableViewCell;
@protocol UITwitterFriendAddButtonTableViewCellDelegate <NSObject>
-(void) twitterFriendAddButtonPressed:(UITwitterFriendAddButtonTableViewCell *) cell;
@end

@interface UITwitterFriendAddButtonTableViewCell : UIGenericSizableTableViewCell
-(void) setEnabled:(BOOL) enabled;
@property (nonatomic, assign) id<UITwitterFriendAddButtonTableViewCellDelegate> delegate;
@end
