//
//  UIMessageDetailFeedAddressView.h
//  ChatSeal
//
//  Created by Francis Grolemund on 4/21/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIDynamicTypeCompliantEntity.h"

@class UIMessageDetailFeedAddressView;
@protocol UIMessageDetailFeedAddressViewDelegate <NSObject>
@optional
-(void) feedAddressViewDidPressButton:(UIMessageDetailFeedAddressView *) addressView;
@end

@interface UIMessageDetailFeedAddressView : UIView <UIDynamicTypeCompliantEntity>
+(UIButton *) standardUploadButton;
+(CGFloat) standardSidePad;
+(CGAffineTransform) shearTransformForLabel:(UILabel *) l;
-(void) setFeedAddressText:(NSString *) text withAnimation:(BOOL) animated;
@property (nonatomic, assign) id<UIMessageDetailFeedAddressViewDelegate> delegate;
@end
