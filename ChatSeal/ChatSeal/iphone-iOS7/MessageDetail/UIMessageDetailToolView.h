//
//  UIMessageDetailToolView.h
//  ChatSeal
//
//  Created by Francis Grolemund on 9/23/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UISealedMessageEnvelopeViewV2.h"
#import "UIDynamicTypeCompliantEntity.h"

@class UIMessageDetailToolView;
@protocol UIMessageDetailToolViewDelegate <NSObject>
@optional
-(void) toolViewCameraPressed:(UIMessageDetailToolView *) toolView;
-(void) toolViewSealItPressed:(UIMessageDetailToolView *) toolView;
-(void) toolViewAddressPressed:(UIMessageDetailToolView *) toolView;
-(void) toolViewContentSizeChanged:(UIMessageDetailToolView *) toolView;
-(void) toolViewBecameFirstResponder:(UIMessageDetailToolView *) toolView;
@end

@interface UIMessageDetailToolView : UIView <UIDynamicTypeCompliantEntity>
+(NSTimeInterval) recommendedSizeAnimationDuration;
-(BOOL) isFirstResponder;
-(void) setHintText:(NSString *) hintText;
-(void) insertPhotoInMessage:(UIImage *) image;
-(NSArray *) currentMessageContents;
-(void) setMessageContents:(NSArray *) arrContents;
-(CGPoint) baseEnvelopeOffset;
-(UISealedMessageEnvelopeViewV2 *) envelopeForCurrentContentAndTargetHeight:(CGFloat) targetHeight;
-(void) setSealItButtonEnabled:(BOOL) isEnabled;
-(BOOL) hasContent;
-(void) setFrame:(CGRect)frame withImmediateLayout:(BOOL)immediateLayout;
-(void) setDisplayAddressEnabled:(BOOL) enabled;
-(BOOL) addressDisplayEnabled;
-(void) setAddressText:(NSString *) text withAnimation:(BOOL) animated;
-(CGFloat) reservedHeightForAddress;
-(void) prepareForRotation;
-(NSString *) textForActiveItem;
@property (nonatomic, assign) id<UIMessageDetailToolViewDelegate> delegate;
@end
