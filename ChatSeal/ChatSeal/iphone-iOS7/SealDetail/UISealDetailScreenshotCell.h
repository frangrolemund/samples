//
//  UISealDetailScreenshotCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/16/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIGenericSizableTableViewCell.h"

@class ChatSealIdentity;
@interface UISealDetailScreenshotCell : UIGenericSizableTableViewCell
-(void) setIdentity:(ChatSealIdentity *) psi;
@property (nonatomic, retain) IBOutlet UILabel *lAfterScreenShot;
@property (nonatomic, retain) IBOutlet UILabel *lScreenShotEnabled;
@end
