//
//  UIPhotoCaptureView.h
//  ChatSeal
//
//  Created by Francis Grolemund on 4/11/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

//  - the view communicates with its owner over this protocol
@class UIPhotoCaptureView;
@protocol UIPhotoCaptureViewDelegate <NSObject>
@optional
-(void) photoViewCameraNotReady:(UIPhotoCaptureView *) pv;
-(void) photoViewCameraReady:(UIPhotoCaptureView *) pv;
-(void) photoView:(UIPhotoCaptureView *) pv snappedPhoto:(UIImage *) img;
-(void) photoView:(UIPhotoCaptureView *) pv failedWithError:(NSError *) err;
@end


//  - this view provides photo capture support.
@interface UIPhotoCaptureView : UIView
-(BOOL) isPhotoCaptureAvailable;
-(BOOL) isFrontCameraAvailable;
-(BOOL) isBackCameraAvailable;
-(BOOL) frontCameraIsPrimary;
-(BOOL) setPrimaryCamera:(BOOL) isFront;
-(void) setCaptureEnabled:(BOOL) enabled;
-(BOOL) isCaptureEnabled;
-(BOOL) snapPhoto;
-(UIImage *) imageForLastSample;
-(BOOL) isCameraUsable;

@property (nonatomic, assign) id<UIPhotoCaptureViewDelegate> delegate;
@end
