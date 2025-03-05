//
//  UIAlphaContext.h
//  ChatSeal
//
//  Created by Francis Grolemund on 6/19/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIAlphaContext : NSObject
+(UIAlphaContext *) contextWithSize:(CGSize) imageSize andScale:(CGFloat) imageScale;
+(UIAlphaContext *) contextWithSize:(CGSize) imageSize;
+(UIAlphaContext *) contextWithImage:(UIImage *) image;
+(UIImage *) maskForImage:(UIImage *) image;
-(id) initWithSize:(CGSize) imageSize andScale:(CGFloat) imageScale;
-(id) initWithMaskingImage:(UIImage *) image;
-(NSMutableData *) bitmap;
-(CGContextRef) context;
-(CGFloat) pxWidth;
-(CGFloat) pxHeight;
-(CGRect) pxBounds;
-(CGFloat) width;
-(CGFloat) height;
-(CGRect) bounds;
-(UIImage *) image;
-(UIImage *) imageAtOrientation:(UIImageOrientation) io;
-(UIImage *) imageMask;
@end
