//
//  UISealDetailNameCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/15/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIGenericSizableTableViewCell.h"

@class ChatSealIdentity;
@interface UISealDetailNameCell : UIGenericSizableTableViewCell
-(void) setIdentity:(ChatSealIdentity *) psi;
-(void) updateNameForActivityState;
@property (nonatomic, retain) IBOutlet UITextField *tfName;
@end
