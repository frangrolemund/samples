//
//  UISealAboutCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/16/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIDynamicTypeCompliantEntity.h"
#import "UIGenericSizableTableViewCell.h"

@interface UISealAboutCell : UIGenericSizableTableViewCell
@property (nonatomic, retain) IBOutlet UILabel *lDescription;
@property (nonatomic, retain) IBOutlet UILabel *lValue;
@end
