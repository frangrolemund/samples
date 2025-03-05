//
//  CS_image.m
//  ChatSeal
//
//  Created by Francis Grolemund on 4/28/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "CS_image.h"
#import "CS_error.h"

//  - constants
static const char *PHSIMG_RAW_ID               = "RPrawimg";              //  must be a multiple of uint16_t
static const int PHSIMG_LEN_RAW_ID             = 8;
static NSUInteger PHSC_MAX_TABLE_IMAGE_SIDE    = 64;        //  in points
static NSUInteger PHSC_MAX_COLL_IMAGE_SIDE     = 64;        //  in points

// - forward declarations.
@interface CS_image (internal)
+(UIImage *) forceLoadImage:(CGImageRef) image withError:(NSError **) err;
+(UIImage *) loadJPGImmediatelyWithProvider:(CGDataProviderRef) provider andError:(NSError **) err;
+(UIImage *) imageScaledToMaximumPoints:(CGFloat) maxDimension forSource:(UIImage *) img andAlwaysRedraw:(BOOL) alwaysRedraw;
@end

/***********************
 CS_image
 ***********************/
@implementation CS_image
/*
 *  There are times where files must be completely pulled into memory to
 *  produce a fluid UI.  This method will accomplish that.
 */
+(UIImage *) loadPNGImmediatelyAtPath:(NSString *) path withError:(NSError **) err
{
    //  - load the file first.
    CGDataProviderRef dpFile = CGDataProviderCreateWithFilename([path UTF8String]);
    if (!dpFile) {
        [CS_error fillError:err withCode:CSErrorFilesystemAccessError andFailureReason:@"Failed to load the requested image path."];
        return nil;
    }
    
    CGImageRef imgInFile = CGImageCreateWithPNGDataProvider(dpFile, NULL, NO, kCGRenderingIntentDefault);
    CGDataProviderRelease(dpFile);
    if (!imgInFile) {
        [CS_error fillError:err withCode:CSErrorFilesystemAccessError andFailureReason:@"The image is not a valid PNG."];
        return nil;
    }
    
    UIImage *ret = [CS_image forceLoadImage:imgInFile withError:err];
    CGImageRelease(imgInFile);
    return ret;
}

/*
 *  There are times where files must be completely pulled into memory to
 *  produce a fluid UI.  This method will accomplish that.
 */
+(UIImage *) loadJPGImmediatelyAtPath:(NSString *) path withError:(NSError **) err
{
    //  - load the file first.
    CGDataProviderRef dpFile = CGDataProviderCreateWithFilename([path UTF8String]);
    if (!dpFile) {
        [CS_error fillError:err withCode:CSErrorFilesystemAccessError andFailureReason:@"Failed to load the requested image path."];
        return nil;
    }
    UIImage *ret = [CS_image loadJPGImmediatelyWithProvider:dpFile andError:err];
    CGDataProviderRelease(dpFile);
    return ret;
}

/*
 *  There are times where files must be completely pulled into memory to
 *  produce a fluid UI.  This method will accomplish that.
 */
+(UIImage *) loadJPGImmediatelyWithData:(NSData *) data withError:(NSError **) err
{
    //  - load the file first.
    CGDataProviderRef dpFile = CGDataProviderCreateWithCFData((CFDataRef) data);
    if (!dpFile) {
        [CS_error fillError:err withCode:CSErrorFilesystemAccessError andFailureReason:@"Failed to load the requested image data."];
        return nil;
    }
    UIImage *ret = [CS_image loadJPGImmediatelyWithProvider:dpFile andError:err];
    CGDataProviderRelease(dpFile);
    return ret;
}

/*
 *  Convert the supplied image to a raw RGB data format that is quicker to load.
 */
+(NSData *) imageToRawFormat:(UIImage *) img withError:(NSError **) err
{
    if (!img) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        return nil;
    }
    
    CGSize szImage = img.size;
    if (szImage.width < 1.0f || szImage.height < 1.0f) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        return nil;
    }
    
    uint16_t width = (uint16_t) szImage.width;
    uint16_t height = (uint16_t) szImage.height;
    uint8_t  scale = (uint8_t) img.scale;
    uint8_t  orient = (uint8_t) img.imageOrientation;

    // - the buffer is very simple with an id, the width/height, scale, orientation and the RGBA image data.
    NSUInteger offsetToImage = PHSIMG_LEN_RAW_ID + sizeof(width) + sizeof(height) + sizeof(scale) + sizeof(orient);
    NSUInteger bytesPerRow = width * 4;
    NSUInteger buflen = offsetToImage + (bytesPerRow * height);
    NSMutableData *mdRet = [NSMutableData dataWithLength:buflen];

    //  - save the header.
    strncpy(mdRet.mutableBytes, PHSIMG_RAW_ID, PHSIMG_LEN_RAW_ID);
    uint16_t *pDim = (uint16_t *) &(((unsigned char *) mdRet.mutableBytes)[PHSIMG_LEN_RAW_ID]);
    *pDim = htons(width);
    pDim++;
    *pDim = htons(height);
    pDim++;
    uint8_t *attrib = (uint8_t *) pDim;
    attrib[0] = scale;
    attrib[1] = orient;

    //  - now create an output buffer
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef targetContext = CGBitmapContextCreate(((unsigned char *) mdRet.mutableBytes) + offsetToImage, width, height, 8, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(colorSpace);
    if (!targetContext) {
        [CS_error fillError:err withCode:CSErrorAborted andFailureReason:@"Unexpected Quartz failure to create a new bitmap context."];
        return nil;
    }

    // - draw the image into the output buffer and we're done.
    CGContextDrawImage(targetContext, CGRectMake(0.0f, 0.0f, width, height), [img CGImage]);
    CGContextRelease(targetContext);
    return mdRet;
}

/*
 *  Convert a quickload raw image format to an image handle.
 */
+(UIImage *) rawFormatToImage:(NSData *) dImage withError:(NSError **) err
{
    // - first validate the buffer.
    uint16_t width = 0;
    uint16_t height = 0;
    uint8_t  scale = 1;
    uint8_t  orient = 0;
    NSUInteger offsetToImage = PHSIMG_LEN_RAW_ID + sizeof(width) + sizeof(height) + sizeof(scale) + sizeof(orient);
    if (!dImage || [dImage length] < offsetToImage) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        return nil;
    }
    
    const unsigned char *ptr = [dImage bytes];
    if (strncmp(PHSIMG_RAW_ID, (const char *) ptr, PHSIMG_LEN_RAW_ID)) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        return nil;
    }
    ptr += PHSIMG_LEN_RAW_ID;

    width = ntohs(*((uint16_t *) ptr));
    ptr += sizeof(uint16_t);
    height = ntohs(*((uint16_t *) ptr));
    ptr += sizeof(uint16_t);
    scale = *ptr;
    ptr++;
    orient = *ptr;
    ptr++;

    NSUInteger bytesPerRow = width * 4;
    if ([dImage length] - offsetToImage < (bytesPerRow * height)) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        return nil;
    }

    // - now create a context that will be suitable for the buffer
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef targetContext = CGBitmapContextCreate((void *) ptr, width, height, 8, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(colorSpace);
    if (!targetContext) {
        [CS_error fillError:err withCode:CSErrorAborted andFailureReason:@"Unexpected Quartz failure to create a new bitmap context."];
        return nil;
    }
    
    //  - and generate an image from it.
    UIImage *retImg = nil;
    CGImageRef outputImage = CGBitmapContextCreateImage(targetContext);
    if (outputImage) {
        retImg = [UIImage imageWithCGImage:outputImage scale:scale orientation:orient];
        CGImageRelease(outputImage);
    }
    else {
        [CS_error fillError:err withCode:CSErrorAborted andFailureReason:@"Unexpected Quartz failure to create an image from a bitmap context."];
    }
    CGContextRelease(targetContext);
    return retImg;
}

/*
 *  This routine will scale a larger image down for uniform display in
 *  a table view.
 */
+(UIImage *) tableReadyUIScaledImage:(UIImage *) img
{
    return [CS_image imageScaledToMaximumPoints:PHSC_MAX_TABLE_IMAGE_SIDE forSource:img];
}

/*
 *  This routine will scale a larger image down for uniform display in
 *  a collection view.
 */
+(UIImage *) collectionReadyUIScaledImage:(UIImage *) img
{
    return [CS_image imageScaledToMaximumPoints:PHSC_MAX_COLL_IMAGE_SIDE forSource:img];
}

/*
 *  Return a scaled image.
 */
+(UIImage *) imageScaledToMaximumPoints:(CGFloat) maxDimension forSource:(UIImage *) img
{
    return [CS_image imageScaledToMaximumPoints:maxDimension forSource:img andAlwaysRedraw:NO];
}

/*
 *  Return an image, but be sure that it can be used from other threads.
 */
+(UIImage *) threadSafeImageScaledToMaximumPoints:(CGFloat) maxDimension forSource:(UIImage *) img
{
    return [CS_image imageScaledToMaximumPoints:maxDimension forSource:img andAlwaysRedraw:YES];
}

/*
 *  Load an image from disk in a thread-safe way and scale it.
 *  - this method was created to begin to diagnose an error that appears periodically when running
 *    the app.  The error in the console reads something like:
 *    '<Error>: ImageIO: CGImageReadSessionGetCachedImageBlockData *** CGImageReadSessionGetCachedImageBlockData: bad readSession [0xbc1a380]'
 *  - I wanted to have a place where I could experiment with different approaches.  Although at one
 *    point I converted entirely over to Quartz APIs for image loading, the same error appeared.  I read in some circles
 *    that loading images on a background thread with UIKit was unsupported, but that seems to conflict with the documentation after iOS4.0.
 *  - My investigation identified that the error is emitted when CGContextDrawImage is called. This is likely the point where the data provider pulls
 *    the data.  I saw this with and without ImageIO integration.  The only advantage to ImageIO is to automate the identification of the data.
 *  - At the moment, this simply redraws the image to ensure that it is fully loaded, but I don't yet have a good idea about 
 *    what to do next.  As far as I can tell, I've tried every possible solution down to the low-level Quartz APIs.
 *  - This error has the suggestion of a race condition since it occurs unpredictably when doing background thread image conversions, but I haven't
 *    yet figured out the elements involved specifically.
 */
+(UIImage *) threadSafeImageScaledToMaximumPoints:(CGFloat) maxDimension forSourcePath:(NSString *) imgPath
{
    UIImage *img = [UIImage imageWithContentsOfFile:imgPath];
    return [CS_image threadSafeImageScaledToMaximumPoints:maxDimension forSource:img];
}

@end

/***********************
 CS_image (internal)
 ***********************/
@implementation CS_image (internal)
/*
 *  Return a scaled image.
 */
+(UIImage *) imageScaledToMaximumPoints:(CGFloat) maxDimension forSource:(UIImage *) img andAlwaysRedraw:(BOOL) alwaysRedraw
{
    maxDimension = maxDimension * [UIScreen mainScreen].scale;
    CGSize szImage = img.size;
    CGFloat arImg = szImage.width / szImage.height;
    BOOL rescale = alwaysRedraw;
    if (szImage.width > szImage.height) {
        if (szImage.width > maxDimension) {
            rescale = YES;
            szImage = CGSizeMake(maxDimension, maxDimension/arImg);
        }
    }
    else {
        if (szImage.height > maxDimension) {
            rescale = YES;
            szImage = CGSizeMake(arImg*maxDimension, maxDimension);
        }
    }
    
    if (rescale) {
        UIGraphicsBeginImageContextWithOptions(szImage, YES, img.scale);
        CGContextSetAllowsAntialiasing(UIGraphicsGetCurrentContext(), NO);
        [[UIColor whiteColor] set];
        UIRectFill(CGRectMake(0, 0, szImage.width + 1, szImage.height + 1));
        [img drawInRect:CGRectMake(0.0f, 0.0f, szImage.width, szImage.height)];
        img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return img;
}

/*
 *  Ensure that an image is fully loaded into RAM by explicitly painting
 *  it to a new image context.
 */
+(UIImage *) forceLoadImage:(CGImageRef) image withError:(NSError **) err
{
    UIImage *ret = nil;
    
    //  - now create a target context to store it
    size_t w = (size_t) CGImageGetWidth(image);
    size_t h = (size_t) CGImageGetHeight(image);
    
    unsigned char *imgBuffer = (unsigned char *) malloc(w*h*4);
    if (imgBuffer) {
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef targetContext = CGBitmapContextCreate(imgBuffer, w, h, 8, w*4, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
        CGColorSpaceRelease(colorSpace);
        if (targetContext) {
            CGContextDrawImage(targetContext, CGRectMake(0.0f, 0.0f, w, h), image);
            CGImageRef outputImage = CGBitmapContextCreateImage(targetContext);
            if (outputImage) {
                ret = [UIImage imageWithCGImage:outputImage];
                CGImageRelease(outputImage);
            }
            CGContextRelease(targetContext);
        }
        free(imgBuffer);
    }
    
    if (!ret) {
        [CS_error fillError:err withCode:CSErrorAborted andFailureReason:@"Failed to perform image conversion."];
    }
    
    return ret;
}

/*
 *  Load a JPG file using a given data provider.
 */
+(UIImage *) loadJPGImmediatelyWithProvider:(CGDataProviderRef) provider andError:(NSError **) err
{
    CGImageRef imgInFile = CGImageCreateWithJPEGDataProvider(provider, NULL, NO, kCGRenderingIntentDefault);
    if (!imgInFile) {
        [CS_error fillError:err withCode:CSErrorFilesystemAccessError andFailureReason:@"The image is not a valid JPG."];
        return nil;
    }
    
    UIImage *ret = [CS_image forceLoadImage:imgInFile withError:err];
    CGImageRelease(imgInFile);
    return ret;
}
@end

