//
//  UINewSealBackdropView.h
//  ChatSeal
//
//  Created by Francis Grolemund on 6/3/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UISealClippingContainer.h"

@class UINewSealBackdropView;
@protocol UINewSealBackdropViewDelegate <NSObject>
@optional
-(void) backdropViewCameraNotReady:(UINewSealBackdropView *) pv;
-(void) backdropViewCameraReady:(UINewSealBackdropView *) pv;
-(void) backdropView:(UINewSealBackdropView *) pv snappedPhoto:(UIImage *) img;
-(void) backdropView:(UINewSealBackdropView *) pv cameraFailedWithError:(NSError *) err;
@end

@interface UINewSealBackdropView : UISealClippingContainer
-(void) setSealImage:(UIImage *) image withAnimation:(BOOL) animated;
-(BOOL) hasSealImage;
-(UIImage *) generateMinimalSealImage;
-(BOOL) hasCameraSupport;
-(BOOL) canFlipCamera;
-(void) flipCamera;
-(void) snapPhoto;
-(void) switchToCamera;
-(void) switchToSealWithCompletion:(void(^)())completionBlock;
-(BOOL) isCameraActive;
-(BOOL) isCameraUsable;
-(BOOL) isFrontCameraActive;
-(void) viewDidAppear;
-(void) viewDidDisappear;
-(void) setDisplayRotation:(CGFloat) rotation withAnimation:(BOOL) animated;
-(void) prepareForBackground;
-(void) resumeForeground;

@property (nonatomic, assign) id<UINewSealBackdropViewDelegate> delegate;
@end
