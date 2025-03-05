//
//  UIMyFriendTableViewCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/15/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIGenericSizableTableViewCell.h"

@class ChatSealFeedFriend;
@interface UIMyFriendTableViewCell : UIGenericSizableTableViewCell
+(void) setBorderOnProfile:(UIImageView *) ivProfile;
-(void) configureWithFriend:(ChatSealFeedFriend *) feedFriend andAnimation:(BOOL) animated;
@property (nonatomic, retain) IBOutlet UIImageView *ivFriendProfile;
@property (nonatomic, retain) IBOutlet UILabel     *lFriendName;
@property (nonatomic, retain) IBOutlet UILabel     *lConnectionStatus;
@property (nonatomic, retain) IBOutlet UILabel     *lTrusted;
@end
