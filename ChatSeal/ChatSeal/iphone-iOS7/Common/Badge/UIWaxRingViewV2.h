//
//  UIWaxRingViewV2.h
//  ChatSeal
//
//  Created by Francis Grolemund on 9/3/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIWaxRingViewV2 : UIView
+(void) verifyResources;
+(CGFloat) centerPercentage;
+(CGFloat) narrowRingPercentage;
-(id) initAsOuterRing:(BOOL) isOuter;
-(void) setZPosition:(CGFloat) zPosition;
-(void) setRingColor:(UIColor *)color;
-(void) prepareForSmallDisplay;
-(void) setLocked:(BOOL) newIsLocked;
-(void) drawForDecoyInRect:(CGRect) rc asValid:(BOOL) isValid;
-(void) coordinateMaskSizingWithBoundsAnimation:(CAAnimation *) anim;
@end
