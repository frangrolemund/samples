//
//  UIFeedsOverviewTableViewCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 6/3/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIGenericSizableTableViewCell.h"

@class ChatSealFeed;
@class UIFeedsOverviewPlaceholder;
@interface UIFeedsOverviewTableViewCell : UIGenericSizableTableViewCell
-(void) reconfigureCellWithFeed:(ChatSealFeed *) feed withAnimation:(BOOL) animated;
-(void) drawStylizedVersionWithPlaceholder:(UIFeedsOverviewPlaceholder *) foph;
@property (nonatomic, retain) IBOutlet UIView *vwFeedAddressContainer;
@property (nonatomic, retain) IBOutlet UILabel *lExchangeCount;
@property (nonatomic, retain) IBOutlet UILabel *lStatus;
@property (nonatomic, retain) IBOutlet UIProgressView *pvProgress;
@end
