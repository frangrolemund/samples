//
//  UIVaultFailureOverlayView.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/7/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIDynamicTypeCompliantEntity.h"

@class UIVaultFailureOverlayView;
@protocol UIVaultFailureOverlayViewDelegate <NSObject>
+(UIImage *) generateVaultFailurePlaceholderOfSize:(CGSize) szPlaceholder withInsets:(UIEdgeInsets) insets andContext:(NSObject *) ctx;
@optional
-(UIImage *) placeholderImageForOverlay:(UIVaultFailureOverlayView *) overlay;
@end

@interface UIVaultFailureOverlayView : UIView <UIDynamicTypeCompliantEntity>
+(UIColor *) standardPlaceholderWhiteAlternative;
+(CGFloat) standardHeaderHeight;
+(void) drawStandardHeaderInRect:(CGRect) rc assumingTextPct:(CGFloat) textPct;
+(CGFloat) drawStandardToolLineAtPos:(CGFloat) yPos andWithWidth:(CGFloat) width andShowText:(BOOL) showText ofWidth:(CGFloat) textWidth;
-(void) showFailureWithTitle:(NSString *) title andText:(NSString *) text andAnimation:(BOOL) animated;
-(void) hideFailureWithAnimation:(BOOL) animated;
-(BOOL) isFailureVisible;
-(void) setUseFrostedEffect:(BOOL) useFrosted;
-(void) setScalePlaceholderForEfficiency:(BOOL) enabled;
+(UIColor *) complimentaryBackgroundColor;

@property (nonatomic, assign) id<UIVaultFailureOverlayViewDelegate> delegate;
@end
