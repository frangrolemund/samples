//
//  UIFeedDetailOverviewTableViewCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 6/20/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIGenericSizableTableViewCell.h"

@class ChatSealFeed;
@interface UIFeedDetailOverviewTableViewCell : UIGenericSizableTableViewCell
-(void) reconfigureCellWithFeed:(ChatSealFeed *) feed withAnimation:(BOOL) animated;
-(IBAction)doSwitchEnable:(id)sender;
@property (nonatomic, retain) IBOutlet UIView *vwFeedAddressContainer;
@property (nonatomic, retain) IBOutlet UISwitch *swEnable;
@end
