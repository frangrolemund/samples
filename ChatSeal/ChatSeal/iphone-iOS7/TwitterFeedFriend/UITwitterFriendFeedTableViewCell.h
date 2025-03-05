//
//  UITwitterFriendFeedTableViewCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIFormattedTwitterFeedAddressView.h"
#import "UIGenericSizableTableViewCell.h"

@interface UITwitterFriendFeedTableViewCell : UIGenericSizableTableViewCell
@property (nonatomic, retain) IBOutlet UIFormattedTwitterFeedAddressView *favAddress;
@end
