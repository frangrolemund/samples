//
//  UIImageGeneration.h
//  ChatSeal
//
//  Created by Francis Grolemund on 6/1/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImageGeneration : NSObject
+(UIImage *) tabBarImageFromImage:(NSString *) imageNamed andTint:(UIColor *) c andIsSelected:(BOOL) isSelected;
+(UIImage *) imageFromView:(UIView *) view withScale:(CGFloat) scale;
+(UIColor *) adjustColor:(UIColor *) color byHuePct:(CGFloat) huePct andSatPct:(CGFloat) satPct andBrPct:(CGFloat) brPct andAlphaPct:(CGFloat) alphaPct;
+(UIImage *) image:(UIImage *) srcImage scaledTo:(CGFloat) scale asOpaque:(BOOL) isOpaque;
+(void) addRoundRect:(CGRect) rc toContext:(CGContextRef) ctx withCornerRadius:(CGFloat) radius;
+(UIColor *) disabledColorFromColor:(UIColor *) c;
+(UIColor *) highlightedColorFromColor:(UIColor *) c;
+(UIImage *) iconImageFromImage:(UIImage *) img inColor:(UIColor *) color withShadow:(UIColor *) shadowColor;
+(void) simpleRadialGradientImageOfHeight:(CGFloat) height withColor:(UIColor *) color andEndColor:(UIColor *) endColor withStartRadius:(CGFloat) startRadius
                             andEndRadius:(CGFloat) endRadius;
@end
