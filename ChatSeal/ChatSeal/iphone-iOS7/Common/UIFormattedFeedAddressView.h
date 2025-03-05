//
//  UIFormattedFeedAddressView.h
//  ChatSeal
//
//  Created by Francis Grolemund on 5/1/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIDynamicTypeCompliantEntity.h"

@interface UIFormattedFeedAddressView : UIView <UIDynamicTypeCompliantEntity>
-(void) setAddressFontHeight:(CGFloat) height;
-(void) setAddressText:(NSString *) address;
-(void) setTextColor:(UIColor *) c;
-(UIImageView *) logoImageView;
-(UILabel *) addressLabel;
-(CGSize) addressContentSize;
@end
