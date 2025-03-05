//
//  UIFeedSelectionTableViewCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 4/30/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIGenericSizableTableViewCell.h"

@class ChatSealFeed;
@interface UIFeedSelectionTableViewCell : UIGenericSizableTableViewCell
+(CGFloat) standardRowHeight;
-(BOOL) isGoodForSelection;
-(void) reconfigureCellWithFeed:(ChatSealFeed *) feed withAnimation:(BOOL) animated;
-(void) setActiveFeedEnabled:(BOOL) isEnabled;
@end
