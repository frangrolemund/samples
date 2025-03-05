//
//  UISealAcceptRadarView.h
//  ChatSeal
//
//  Created by Francis Grolemund on 2/14/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class UISealAcceptRadarView;
@protocol UISealAcceptRadarViewDelegate <NSObject>
@optional
-(void) radarTargetsWereUpdated:(UISealAcceptRadarView *) radarView;
@end

@interface UISealAcceptRadarView : UIView <UISealAcceptRadarViewDelegate>
+(NSTimeInterval) scanCycleDuration;
+(CGFloat) targetCornerRadiusPercentage;
-(void) setTopMarginHeight:(CGFloat) topMargin;
-(CGRect) activeSignalTargetRegion;
-(CGRect) scanningTargetRegion;
-(void) setTimedColorState:(UIColor *) c asPulsed:(BOOL) isPulsed;
-(void) setScannerOverlayText:(NSString *) text inColor:(UIColor *) c withAnimation:(BOOL) animated;
-(void) reconfigureDynamicTypeForInit:(BOOL) isInit;
-(void) prepareForRotation;
-(void) completeRotation;

@property (nonatomic, assign) id<UISealAcceptRadarViewDelegate> delegate;
@end
