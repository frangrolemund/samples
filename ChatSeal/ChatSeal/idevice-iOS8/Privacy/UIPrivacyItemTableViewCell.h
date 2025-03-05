//
//  UIPrivacyItemTableViewCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 12/3/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIGenericSizableTableViewCell.h"

@interface UIPrivacyItemTableViewCell : UIGenericSizableTableViewCell
-(void) setTitle:(NSString *) title andDescription:(NSString *) description;
-(void) setDisplayDescription:(BOOL) visible;
-(CGFloat) recommendedHeightForRowOfWidth:(CGFloat) width;
-(CGFloat) descriptionHeight;
@property (nonatomic, retain) IBOutlet UILabel *lTitle;
@property (nonatomic, retain) IBOutlet UILabel *lDescription;
@property (nonatomic, retain) IBOutlet NSLayoutConstraint *lcDescriptionBottom;
@end
