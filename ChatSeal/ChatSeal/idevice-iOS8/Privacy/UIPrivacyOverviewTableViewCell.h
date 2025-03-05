//
//  UIPrivacyOverviewTableViewCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 12/3/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIGenericSizableTableViewCell.h"

@interface UIPrivacyOverviewTableViewCell : UIGenericSizableTableViewCell
@property (nonatomic, retain) IBOutlet UIImageView *ivLogo;
@property (nonatomic, retain) IBOutlet UILabel *lTitle;
@property (nonatomic, retain) IBOutlet UILabel *lDesc;
@end
