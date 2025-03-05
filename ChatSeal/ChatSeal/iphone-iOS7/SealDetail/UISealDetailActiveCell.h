//
//  UISealDetailActiveCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/15/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIGenericSizableTableViewCell.h"

@class UISealDetailActiveCell;
@protocol  UISealDetailActiveCellDelegate <NSObject>
@optional
-(void) activeCellModifiedActivity:(UISealDetailActiveCell *) cell;
@end

@class ChatSealIdentity;
@interface UISealDetailActiveCell : UIGenericSizableTableViewCell
-(void) setIdentity:(ChatSealIdentity *) psi;
@property (nonatomic, retain) IBOutlet UILabel *lActiveText;
@property (nonatomic, retain) IBOutlet UISwitch *swActive;
@property (nonatomic, assign) id<UISealDetailActiveCellDelegate> delegate;
@end
