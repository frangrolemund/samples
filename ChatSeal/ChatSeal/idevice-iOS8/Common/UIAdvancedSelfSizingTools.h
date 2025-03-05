//
//  UIAdvancedSelfSizingTools.h
//  ChatSeal
//
//  Created by Francis Grolemund on 10/2/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UIAdvancedSelfSizingTools : NSObject
+(void) constrainTextLabel:(UILabel *) l withPreferredSettingsAndTextStyle:(NSString *) textStyle duringInitialization:(BOOL) isInit;
+(void) constrainTextField:(UITextField *) tf withPreferredSettingsAndTextStyle:(NSString *) textStyle duringInitialization:(BOOL) isInit;
+(void) constrainTextButton:(UIButton *) tb withPreferredSettingsAndTextStyle:(NSString *) textStyle duringInitialization:(BOOL) isInit;
+(void) constrainAlertLabel:(UILabel *) l asHeader:(BOOL) isHeader duringInitialization:(BOOL) isInit;
+(void) constrainAlertButton:(UIButton *) b duringInitialization:(BOOL) isInit;
+(void) constrainTextLabel:(UILabel *) l withPreferredSettingsAndTextStyle:(NSString *) textStyle andSizeScale:(CGFloat) sizeScale andMinimumSize:(CGFloat) minPointSize
      duringInitialization:(BOOL) isInit;
+(void) constrainTextLabel:(UILabel *) l withPreferredSettingsAndTextStyle:(NSString *) textStyle andMinimumSize:(CGFloat) minPointSize duringInitialization:(BOOL) isInit;
+(void) constrainTextButton:(UIButton *) tb withPreferredSettingsAndTextStyle:(NSString *) textStyle andMinimumSize:(CGFloat) minPointSize duringInitialization:(BOOL) isInit;
+(UIFont *) constrainedFontForPreferredSettingsAndTextStyle:(NSString *) textStyle;
+(UIFont *) constrainedFontForPreferredSettingsAndTextStyle:(NSString *) textStyle andSizeScale:(CGFloat) sizeScale andMinHeight:(CGFloat) minHeight;
+(BOOL) isInSizeChangeNotification;
+(void) startSizeChangeSequence;
+(void) completeSizeChangeSequence;
@end
