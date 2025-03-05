//
//  UISealWaxViewV2.h
//  ChatSeal
//
//  Created by Francis Grolemund on 9/3/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <RealSecureImage/RealSecureImage.h>

@interface UISealWaxViewV2 : UIView
+(void) verifyResources;
+(CGFloat) centerDiameterFromRect:(CGRect) rc;
+(void) drawStylizedVersionAsColor:(RSISecureSeal_Color_t) color inRect:(CGRect) rc;
-(CGFloat) centerDiameterFromCurrentBounds;
-(void) prepareForSmallDisplay;
-(void) setOuterColor:(UIColor *) cOuter andMidColor:(UIColor *) cMid andInnerColor:(UIColor *) cInner;
-(void) setCenterVisible:(BOOL) isVisible;
-(void) setSealWaxValid:(BOOL) isValidWax;
-(void) drawForDecoyRect:(CGRect) rc;
-(void) coordinateMaskSizingWithBoundsAnimation:(CAAnimation *) anim;

@property (nonatomic, assign) BOOL locked;
@end
