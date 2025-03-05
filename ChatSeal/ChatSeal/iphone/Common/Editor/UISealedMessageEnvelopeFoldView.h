//
//  UISealedMessageEnvelopeFoldView.h
//  ChatSeal
//
//  Created by Francis Grolemund on 10/13/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UITransformView.h"

@interface UISealedMessageEnvelopeFoldView : UITransformView
-(id) initWithContentView:(UIView *) cv withTopShadow:(BOOL) hasTop andBottomShadow:(BOOL) hasBot;
-(void) setFoldingShadowVisible:(BOOL) isVisible withTopEdgeShadow:(BOOL) hasTopEdge;
-(UIView *) backdropShadowView;
-(void) setBackdropShadowVisible:(BOOL) isVisible;
-(void) setFarbackView:(UIView *) vw inRect:(CGRect) rc;
@end
