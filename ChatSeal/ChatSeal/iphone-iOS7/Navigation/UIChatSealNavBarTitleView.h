//
//  UIChatSealNavBarTitleView.h
//  ChatSeal
//
//  Created by Francis Grolemund on 9/9/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIChatSealNavBarTitleView : UIView
+(UIFont *) standardTitleFont;
-(void) applyScramblingMask;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, assign) CGFloat maxTextWidth;
@property (nonatomic, retain) UIColor *monochromeColor;
@end
