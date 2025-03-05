//
//  UIAlphaContext.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/19/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "UIAlphaContext.h"

/****************************
 UIAlphaContext
 ****************************/
@implementation UIAlphaContext
/*
 *  Object attributes.
 */
{
    CGFloat             scale;
    CGSize              size;
    NSMutableData       *mdBitmap;
    CGContextRef        context;
    UIImageOrientation  imageOrientation;
}

/*
 *  Initialize and return a new context.
 */
+(UIAlphaContext *) contextWithSize:(CGSize) imageSize andScale:(CGFloat) imageScale
{
    UIAlphaContext *ac = [[UIAlphaContext alloc] initWithSize:imageSize andScale:imageScale];
    return [ac autorelease];
}

/*
 *  Initialize and return a new context.
 */
+(UIAlphaContext *) contextWithSize:(CGSize) imageSize
{
    return [UIAlphaContext contextWithSize:imageSize andScale:[UIScreen mainScreen].scale];
}

/*
 *  Initialize using an image as a basis.
 */
+(UIAlphaContext *) contextWithImage:(UIImage *) image
{
    UIAlphaContext *ac = [[UIAlphaContext alloc] initWithMaskingImage:image];
    return [ac autorelease];
}

/*
 *  Generate an image mask and return it.
 */
+(UIImage *) maskForImage:(UIImage *) image
{
    UIImage *ret = nil;
    UIAlphaContext *ac = [[UIAlphaContext alloc] initWithMaskingImage:image];
    ret = [ac imageMask];
    [ac release];
    return ret;
}

/*
 *  Initialize the object.
 */
-(id) initWithSize:(CGSize) imageSize andScale:(CGFloat) imageScale
{
    self = [super init];
    if (self) {
        size             = imageSize;
        scale            = imageScale;
        imageOrientation = UIImageOrientationUp;
        
        int w = (int) (size.width * scale);
        int h = (int) (size.height * scale);
        
        //  - only the alpha is really relevant here.
        mdBitmap = [[NSMutableData alloc] initWithLength:(NSUInteger)(w*h)];
        context = CGBitmapContextCreate(mdBitmap.mutableBytes, (size_t) w, (size_t) h, 8, (size_t) w, NULL, (CGBitmapInfo) kCGImageAlphaOnly);
    }
    return self;
}

/*
 *  Initialize the object using the source as an image mask.
 */
-(id) initWithMaskingImage:(UIImage *) image
{
    self = [self initWithSize:image.size andScale:image.scale];
    if (self) {
        imageOrientation = image.imageOrientation;
        if (context) {
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, [self pxWidth], [self pxHeight]), [image CGImage]);
        }
    }
    return self;
}

/*
 * Free the object.
 */
-(void) dealloc
{
    if (context) {
        CGContextRelease(context);
        context = NULL;
    }
    
    [mdBitmap release];
    mdBitmap = nil;
    
    [super dealloc];
}

/*
 *  Return the enclosed bitmap.
 */
-(NSData *) bitmap
{
    return [[mdBitmap retain] autorelease];
}

/*
 *  Return the enclosed context.
 */
-(CGContextRef) context
{
    return context;
}

/*
 *  Return the width of the context in pixels.
 */
-(CGFloat) pxWidth
{
    return size.width * scale;
}

/*
 *  Return the height of the context in pixels.
 */
-(CGFloat) pxHeight
{
    return size.height * scale;
}

/*
 *  Return the pixel bounds of the context.
 */
-(CGRect) pxBounds
{
    return CGRectMake(0.0f, 0.0f, size.width * scale, size.height * scale);
}

/*
 *  Return the width of the context in points.
 */
-(CGFloat) width
{
    return size.width;
}

/*
 *  Return the height of the context in points.
 */
-(CGFloat) height
{
    return size.height;
}

/*
 *  Return the point bounds of the context.
 */
-(CGRect) bounds
{
    return CGRectMake(0.0f, 0.0f, size.width, size.height);
}

/*
 *  Return the generated image from the context.
 */
-(UIImage *) image
{
    return [self imageAtOrientation:imageOrientation];
}

/*
 *  Return the generated image from the context.
 */
-(UIImage *) imageAtOrientation:(UIImageOrientation) io
{
    UIImage *ret = nil;
    CGImageRef ir = CGBitmapContextCreateImage(context);
    ret = [UIImage imageWithCGImage:ir scale:scale orientation:io];
    CGImageRelease(ir);
    return ret;
}

/*
 *  Return a generated image mask.
 */
-(UIImage *) imageMask
{
    CGFloat pxWidth  = [self pxWidth];
    CGFloat pxHeight = [self pxHeight];
    
    UIImage *ret = nil;
    CGDataProviderRef alphaData = CGDataProviderCreateWithCFData((CFDataRef) mdBitmap);
    if (alphaData) {
        CGImageRef imageMask = CGImageMaskCreate((size_t) pxWidth, (size_t) pxHeight, 8, 8, (size_t) pxWidth, alphaData, NULL, NO);
        if (imageMask) {
            ret = [UIImage imageWithCGImage:imageMask scale:scale orientation:imageOrientation];
            CGImageRelease(imageMask);
        }
        CGDataProviderRelease(alphaData);
    }
    return ret;
}

@end
