//
//  UINewSealCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 6/6/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UISealImageViewV2.h"
#import "ChatSeal.h"
#import "UIDynamicTypeCompliantEntity.h"

@interface UINewSealCell : UICollectionViewCell <UIDynamicTypeCompliantEntity>
-(void) setSealColor:(RSISecureSeal_Color_t) color;
-(RSISecureSeal_Color_t) sealColor;
-(void) configureSealImageFromView:(UISealImageViewV2 *) sealImageView;
-(void) setSealImage:(UIImage *) image;
-(void) setSealImageVisible:(BOOL) isVisible;
-(void) setLocked:(BOOL) isLocked;
-(void) setAllContentsVisible:(BOOL) isVisible withAnimation:(BOOL) animated;
-(void) setNoPhotoVisible:(BOOL) isVisible withAnimation:(BOOL)animated;
-(void) setCurrentRotation:(CGFloat) rotation;
-(void) setCenterRotation:(CGFloat) centerRotation;
-(void) setCurrentRotation:(CGFloat)rotation andCenterRotation:(CGFloat) centerRotation;
-(void) prepareForSmallDisplay;
-(void) triggerGlossEffect;
-(void) setCenterRingVisible:(BOOL) isVisible;
-(void) drawCellForDecoyInRect:(CGRect) rc;
-(void) flagAsSimpleImageDisplayOnly;
@end
