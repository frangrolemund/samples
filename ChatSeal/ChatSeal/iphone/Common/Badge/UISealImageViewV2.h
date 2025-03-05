//
//  UISealImageViewV2.h
//  ChatSeal
//
//  Created by Francis Grolemund on 3/21/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class UISealImageViewV2;
@protocol UISealImageViewV2Delegate <NSObject>
@optional
-(void) sealImageWasModified:(UISealImageViewV2 *) siv;
@end

@interface UISealImageViewV2 : UIView

+(CGSize) sealImageSizeInPixels;

-(void) setSealImage:(UIImage *) img;
-(void) setEditingEnabled:(BOOL) enabled;
-(UIImage *) standardizedSealImage;
-(BOOL) hasSealImage;
-(void) setHitClippingRadiusPct:(CGFloat) pct;
-(CGFloat) hitClippingRadiusPct;
-(NSUInteger) editVersion;
-(void) copyAllAttributesFromSealView:(UISealImageViewV2 *) sealView;

@property (nonatomic, assign) id<UISealImageViewV2Delegate> delegate;
@end
