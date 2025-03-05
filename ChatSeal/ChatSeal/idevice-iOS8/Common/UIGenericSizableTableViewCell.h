//
//  UIGenericSizableTableViewCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 9/30/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIDynamicTypeCompliantEntity.h"
#import "UIAdvancedSelfSizingTools.h"

@protocol UICustomSizableTableViewCell <NSObject>
@optional
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL) isInit;
-(BOOL) shouldCreateHeightConstraint;                                   //  manual layouts should generally return YES.
@end

@interface UIGenericSizableTableViewCell : UITableViewCell <UIDynamicTypeCompliantEntity, UICustomSizableTableViewCell>
@end
