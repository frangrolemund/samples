//
//  UIFeedsOverviewSharingTableViewCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/2/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIGenericSizableTableViewCell.h"

@interface UIFeedsOverviewSharingTableViewCell : UIGenericSizableTableViewCell
-(void) reconfigureSharingState;
@property (nonatomic, retain) IBOutlet UILabel *lShareText;
@property (nonatomic, retain) IBOutlet UISwitch *swSharing;
@property (nonatomic, retain) IBOutlet UIButton *bAuthorize;
@end
