//
//  UISealClippingContainer.h
//  ChatSeal
//
//  Created by Francis Grolemund on 6/12/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UISealImageViewV2.h"
#import "UIDynamicTypeCompliantEntity.h"

@interface UISealClippingContainer : UIView <UIDynamicTypeCompliantEntity>
-(UISealImageViewV2 *) sealImageView;
-(UIView *) addPhotoView;
-(UIView *) contentView;
-(void) hitClipToInsideWax;
-(void) setExtendedView:(BOOL) isExtended withAnimation:(BOOL) isAnimated andCompletion:(void(^)(void))completionBlock;
-(BOOL) isExtended;
-(void) copyAllAttributesFromSealView:(UISealImageViewV2 *) sealView;
-(void) setSealImage:(UIImage *) image;
-(void) setNoPhotoVisible:(BOOL) isVisible withAnimation:(BOOL) animated;
-(void) triggerGlossEffect;
-(UIImage *) sealImage;
-(void) coordinateSizingWithBoundsAnimation:(CAAnimation *) anim;
-(void) convertToSimpleDisplay;
@end
