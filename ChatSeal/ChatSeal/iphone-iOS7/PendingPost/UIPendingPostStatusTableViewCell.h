//
//  UIPendingPostStatusTableViewCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 6/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIGenericSizableTableViewCell.h"

@class ChatSealPostedMessageProgress;
@interface UIPendingPostStatusTableViewCell : UIGenericSizableTableViewCell
-(void) refreshFromProgress:(ChatSealPostedMessageProgress *) prog;
@property (nonatomic, retain) IBOutlet UILabel *lDesc;
@property (nonatomic, retain) IBOutlet UILabel *lStatus;
@end
