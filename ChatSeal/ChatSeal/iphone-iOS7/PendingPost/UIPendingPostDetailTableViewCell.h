//
//  UIPendingPostDetailTableViewCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 6/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIGenericSizableTableViewCell.h"

@interface UIPendingPostDetailTableViewCell : UIGenericSizableTableViewCell
-(void) setDisplayView:(UIView *) dv withContentHeight:(CGFloat) contentHeight;
@end
