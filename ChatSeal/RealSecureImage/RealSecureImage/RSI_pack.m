//
//  RSI_pack.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 11/9/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import "RSI_pack.h"
#import "RSI_error.h"
#import "RSI_common.h"
#import "RSI_jpeg.h"
#import "RSI_png.h"

//  - forward declarations
@interface RSI_pack (interal)
+(NSMutableData *) allocBitmapFromImage:(UIImage *) img forSize:(CGSize) szTarget withError:(NSError **) err;
+(NSData *) packedJPEG:(UIImage *) img withQuality:(CGFloat) quality andData:(NSData *) data andKey:(RSI_scrambler *) key andError:(NSError **) err;
@end

/**************************
 RSI_pack
 **************************/
@implementation RSI_pack

/*
 *  Apply steganography to the JPEG to embed data in the image.
 *  - this is intentionally static to more carefully manage the memory necessary to accomplish the embedding. 
 */
+(NSData *) packedJPEG:(UIImage *) img withQuality:(CGFloat) quality andData:(NSData *) data andError:(NSError **) err
{
    return [RSI_pack packedJPEG:img withQuality:quality andData:data andKey:nil andError:err];
}

/*
 *  Using the supplied key, scramble the colors in the provided image.
 *  - this is intentionally static to more carefully manage the memory necessary to accomplish the embedding.
 */
+(NSData *) scrambledJPEG:(UIImage *) img withQuality:(CGFloat) quality andKey:(RSI_scrambler *) key andError:(NSError **) err
{
    return [RSI_pack packedJPEG:img withQuality:quality andData:nil andKey:key andError:err];
}

/*
 *  Compute the maximum amount of data (in bytes) that can be stored in the given image.
 */
+(NSUInteger) maxDataForJPEGImage:(UIImage *) img
{
    CGSize sz = img.size;
    return [JPEG_pack maxDataForJPEGImageOfWidth:sz.width andHeight:sz.height];
}

/*
 *  The maximum number of bits stored per coefficient.
 */
+(NSUInteger) bitsPerJPEGCoefficient
{
    return [JPEG_pack bitsPerJPEGCoefficient];
}

/*
 *  The number of coefficients per DU that can contain embedded data.
 */
+(NSUInteger) embeddedJPEGGroupSize
{
    return [JPEG_pack embeddedJPEGGroupSize];
}

/*
 *  Return the maximum number of bytes that can be stored in the given file if packed as a PNG.
 */
+(NSUInteger) maxDataForPNGImage:(UIImage *) img
{
    if (!img) {
        return 0;
    }
    
    CGSize sz = img.size;
    return [PNG_pack maxDataForPNGImageOfWidth:sz.width andHeight:sz.height];
}

/*
 *  Return the maximum number of bytes that can be stored in a given file of size if packed as a PNG.
 */
+(NSUInteger) maxDataForPNGImageOfSize:(CGSize) szImage
{
    return [PNG_pack maxDataForPNGImageOfWidth:szImage.width andHeight:szImage.height];
}

/*
 *  Return the number of bits that each PNG pixel can store.
 */
+(NSUInteger) bitsPerPNGPixel
{
    return [PNG_pack bitsPerPNGPixel];
}

/*
 *  Apply steganography to the PNG to embed data in the image.
 *  - this is intentionally static to more carefully manage the memory necessary to accomplish the embedding.
 *  - to conserve memory, the resultant PNG will be sized down as much as possible before storing its data.
 */
+(NSData *) packedPNG:(UIImage *) img andData:(NSData *) data andError:(NSError **) err
{
    //  - first validate the input arguments.
    if (!img) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument andFailureReason:@"Missing an image handle."];
        return nil;
    }
    
    CGSize szImage = img.size;
    if (data && [RSI_pack maxDataForPNGImage:img] < [data length]) {
        [RSI_error fillError:err withCode:RSIErrorPackedDataOverflow andFailureReason:nil];
        return nil;
    }
    
    NSData *ret = nil;
    NSError *tmp = nil;
    
    @autoreleasepool {
        //  - create a bitmap array representing the source image.
        NSMutableData *imageBitmap = [RSI_pack allocBitmapFromImage:img forSize:szImage withError:err];
        if (!imageBitmap) {
            return nil;
        }
        
        //  - pack the image
        PNG_pack *pp = [[PNG_pack alloc] initWithBitmap:imageBitmap.mutableBytes andWidth:szImage.width andHeight:szImage.height andData:data];
        ret = [pp packedPNGandError:&tmp];
        [ret retain];
        [tmp retain];
        
        [pp release];
        [imageBitmap release];        
    }
    
    if (err) {
        *err = [tmp autorelease];
    }
    
    //  - and return it, if successful.
    return [ret autorelease];
}

@end

/**************************
 RSI_pack (internal)
 **************************/
@implementation RSI_pack (interal)

/*
 *  Convert the provided image into a bitmap array in RGBA format
 *  - NOTE: we don't use the alpha channel any longer, but since we read/convert
 *          the images as RGBA, I think it may make sense to have some implementation parity here.
 */
+(NSMutableData *) allocBitmapFromImage:(UIImage *) img forSize:(CGSize) szTarget withError:(NSError **) err
{
    size_t numBytesPerRow = szTarget.width * 4.0f;
    NSUInteger totalBytes = numBytesPerRow * szTarget.height;
    
    if (totalBytes == 0) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument andFailureReason:@"Empty images are not allowed."];
        return nil;
    }
    
    NSMutableData *mdBitmap = [[NSMutableData alloc] initWithLength:totalBytes];
    if (!mdBitmap) {
        [RSI_error fillError:err withCode:RSIErrorAborted andFailureReason:@"Failed to allocate a suitable bitmap image buffer for output."];
        return nil;
    }
    
    CGContextRef imgContext = NULL;
    CGColorSpaceRef csr = CGColorSpaceCreateDeviceRGB();
    imgContext = CGBitmapContextCreate(mdBitmap.mutableBytes, (size_t) szTarget.width, (size_t) szTarget.height, 8, numBytesPerRow, csr, (CGBitmapInfo) kCGImageAlphaPremultipliedLast);
    
    if (csr && imgContext) {
        CGContextTranslateCTM(imgContext, 0.0f, szTarget.height);
        CGContextScaleCTM(imgContext, 1.0f, -1.0f);
        
        UIGraphicsPushContext(imgContext);
        [img drawInRect:CGRectMake(0.0f, 0.0f, szTarget.width, szTarget.height)];
        UIGraphicsPopContext();
    }
    else {
        [RSI_error fillError:err withCode:RSIErrorAborted andFailureReason:@"A valid bitmap context could not be created."];
        [mdBitmap release];
        mdBitmap = nil;
    }
    
    if (imgContext) {
        CGContextRelease(imgContext);
    }

    if (csr) {
        CFRelease(csr);
    }

    return mdBitmap;
}

/*
 *  A common routine for packing JPEG images.
 */
+(NSData *) packedJPEG:(UIImage *) img withQuality:(CGFloat) quality andData:(NSData *) data andKey:(RSI_scrambler *) key andError:(NSError **) err
{
    //  - first validate the input arguments.
    if (!img) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument andFailureReason:@"Missing an image handle."];
        return nil;
    }
    
    CGSize szImage = img.size;
    if (data && [RSI_pack maxDataForJPEGImage:img] < [data length]) {
        [RSI_error fillError:err withCode:RSIErrorPackedDataOverflow andFailureReason:nil];
        return nil;
    }
    
    //  - create a bitmap array representing the source image.
    NSData *imageBitmap = [RSI_pack allocBitmapFromImage:img forSize:szImage withError:err];
    if (!imageBitmap) {
        return nil;
    }
    
    //  - pack the image
    const unsigned char *bitmap = imageBitmap.bytes;
    int q = (quality * 100);
    if (q > 100) {
        q = 100;
    }
    if (q < 5) {
        q = 5;
    }
    JPEG_pack *jp = [[JPEG_pack alloc] initWithBitmap:bitmap andWidth:szImage.width andHeight:szImage.height andQuality:q andData:data andKey:key];
    NSData *ret = [jp packedJPEGandError:err];
    
    [jp release];
    [imageBitmap release];
    
    //  - and return it, if successful.
    return ret;
}

@end


