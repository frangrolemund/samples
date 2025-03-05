//
//  UIFeedDetailPendingPostTableViewCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 6/24/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIGenericSizableTableViewCell.h"

@class ChatSealPostedMessageProgress;
@interface UIFeedDetailPendingPostTableViewCell : UIGenericSizableTableViewCell
-(void) reconfigureWithProgress:(ChatSealPostedMessageProgress *) prog;
-(void) setCurrentProgress:(double) progress withAnimation:(BOOL) animated;
@property (nonatomic, retain) IBOutlet UIImageView        *ivSeal;
@property (nonatomic, retain) IBOutlet UILabel            *lDescription;
@property (nonatomic, retain) IBOutlet NSLayoutConstraint *lcImgHeight;
@end
