//
//  UISealDetailInactiveCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/15/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIGenericSizableTableViewCell.h"

@class ChatSealIdentity;
@interface UISealDetailInactiveCell : UIGenericSizableTableViewCell
-(void) setIdentity:(ChatSealIdentity *) psi;
@property (nonatomic, retain) IBOutlet UILabel *lInactiveText;
@end
