//
//  UITwitterFriendTableViewCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/21/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIFormattedTwitterFeedAddressView.h"
#import "UIGenericSizableTableViewCell.h"

@class ChatSealFeedFriend;
@interface UITwitterFriendTableViewCell : UIGenericSizableTableViewCell
-(void) reconfigureWithFriend:(ChatSealFeedFriend *) feedFriend andAnimation:(BOOL) animated;
@property (nonatomic, retain) IBOutlet UIImageView                       *ivProfile;
@property (nonatomic, retain) IBOutlet UILabel                           *lFullName;
@property (nonatomic, retain) IBOutlet UIFormattedTwitterFeedAddressView *favAddress;
@property (nonatomic, retain) IBOutlet UILabel                           *lLocation;
@end
