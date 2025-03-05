//
//  UITwitterFriendAddTableViewCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 8/29/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIGenericSizableTableViewCell.h"

@class UITwitterFriendAddTableViewCell;
@protocol UITwitterFriendAddTableViewCellDelegate <NSObject>
@optional
-(BOOL) twitterFriendAddReturnRequested:(UITwitterFriendAddTableViewCell *) tvc;
-(void) twitterFriendAddTextChanged:(UITwitterFriendAddTableViewCell *) tvc toValue:(NSString *) text;
@end

@interface UITwitterFriendAddTableViewCell : UIGenericSizableTableViewCell
-(NSString *) twitterScreenName;
-(void) setScreenName:(NSString *) screenName;
-(void) setEnabled:(BOOL) isEnabled;
@property (nonatomic, assign) id<UITwitterFriendAddTableViewCellDelegate> delegate;
@end
