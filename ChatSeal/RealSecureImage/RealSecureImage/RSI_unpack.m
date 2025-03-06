//
//  RSI_unpack.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 11/19/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import "RSI_error.h"
#import "RSI_unpack.h"
#import "RSI_common.h"
#import "RSI_pack.h"
#import "RSI_jpeg.h"
#import "RSI_png.h"

/**************************
 RSI_unpack
 **************************/
@implementation RSI_unpack

/*
 *  Analyze the image file and unpack its contents up to the maximum number of bytes (or zero for all bytes).
 */
+(NSData *) unpackData:(NSData *) imgFile withMaxLength:(NSUInteger) maxLen andError:(NSError **) err
{
    NSData *ret = nil;
    if ([JPEG_unpack isDataJPEG:imgFile]) {
        JPEG_unpack *jp = [[JPEG_unpack alloc] initWithData:imgFile andScrambler:nil andNewHiddenContent:nil andMaxLength:maxLen];
        ret = [jp unpackAndScramble:NO];
        [jp release];
        if (!ret) {
            [RSI_error fillError:err withCode:RSIErrorInvalidSecureImage];
        }
    }
    else {
        PNG_unpack *pp = [[PNG_unpack alloc] initWithData:imgFile andMaxLength:maxLen];
        ret = [pp unpackWithError:err];
        [pp release];
    }
    return ret;
}

/*
 *  Take a previously scrambled JPEG file and descramble it.
 */
+(RSI_securememory *) descrambledJPEG:(NSData *) jpegFile withKey:(RSI_scrambler *) key andError:(NSError **) err
{
    RSI_securememory *ret = nil;
    JPEG_unpack *jp = [[JPEG_unpack alloc] initWithData:jpegFile andScrambler:key andNewHiddenContent:nil andMaxLength:0];
    ret = [jp unpackAndScramble:NO];
    if (!ret) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSecureImage];
    }
    [jp release];
    return ret;
}

/*
 *  Analyze the JPEG and hash the unique elements of its image.
 */
+(RSI_securememory *) hashImageData:(NSData *) imgFile withError:(NSError **) err
{
    if ([JPEG_unpack isDataJPEG:imgFile]) {
        JPEG_unpack *jp = [[JPEG_unpack alloc] initWithData:imgFile andScrambler:nil andNewHiddenContent:nil andMaxLength:0];
        [jp captureImageHash];
    
        RSI_securememory *ret = nil;
        if ([jp unpackAndScramble:NO]) {
            ret = [jp hash];
        }
        [jp release];
    
        if (!ret) {
            [RSI_error fillError:err withCode:RSIErrorInvalidSecureImage];
        }
        
        return ret;
    }
    else {
        return [PNG_unpack hashImageData:imgFile withError:err];
    }
}

/*
 *  Replace the data that is in the image file with new content without changing its image hash.
 */
+(NSData *) repackData:(NSData *) imgFile withData:(NSData *) data andError:(NSError **) err
{
    NSData *ret = nil;
    if ([JPEG_unpack isDataJPEG:imgFile]) {
        JPEG_unpack *jp = [[JPEG_unpack alloc] initWithData:imgFile andScrambler:nil andNewHiddenContent:data andMaxLength:0];
        ret = [jp unpackAndScramble:NO];
        if (!ret) {
            [RSI_error fillError:err withCode:RSIErrorInvalidSecureImage];
        }
        [jp release];
    }
    else {
        ret = [PNG_unpack repackData:imgFile withData:data andError:err];
    }
    return ret;
}

/*
 *  This general-purpose routine will load a PNG from a supplied buffer of image data and then return it 
 *  in RGBA format.  If the imageSize is passed, it will be filled-in with the proper size of the image.
 */
+(NSData *) getPNGImageBufferFromFile:(NSData *) imgFile returningSize:(CGSize *) imageSize andError:(NSError **) err
{
    PNG_unpack *pp = [[PNG_unpack alloc] initWithData:imgFile andMaxLength:0];
    NSData *ret = [pp readImageWithError:err];
    if (ret && imageSize) {
        *imageSize = [pp imageSize];
    }
    [pp release];
    return ret;
}

/*
 *  Simple test to see if the image is a JPEG file.
 */
+(BOOL) isImageJPEG:(NSData *) d
{
    return [JPEG_unpack isDataJPEG:d];
}

/*
 *  This method is used to determine if the supplied data file
 *  has enough content to determine its type.
 */
+(BOOL) hasEnoughDataForImageTypeIdentification:(NSData *) d
{
    static NSUInteger minLen = 0;
    if (!minLen) {
        minLen = MAX([PNG_unpack minimumDataLengthForTypeIdentification], [JPEG_unpack minimumDataLengthForTypeIdentification]);
    }
    
    // - when the file is nil, we have to assume that we shouldn't continue looking at it.
    if (!d || d.length >= minLen) {
        return YES;
    }
    return NO;
}

/*
 *  Check the supplied data file is one of the variants that we support.
 */
+(BOOL) isSupportedPackedFile:(NSData *) d
{
    if (![RSI_unpack hasEnoughDataForImageTypeIdentification:d]) {
        return NO;
    }
    if ([PNG_unpack isDataPNG:d] || [JPEG_unpack isDataJPEG:d]) {
        return YES;
    }
    return NO;
}

/*
 *  Scramble an existing JPEG file.
 */
+(NSData *) scrambledJPEG:(NSData *) jpegFile andKey:(RSI_scrambler *) key andError:(NSError **) err
{
    NSData *ret = nil;
    JPEG_unpack *jp = [[JPEG_unpack alloc] initWithData:jpegFile andScrambler:key andNewHiddenContent:nil andMaxLength:0];
    ret = [jp unpackAndScramble:YES];
    if (!ret) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSecureImage];
    }
    [jp release];
    return ret;
}

@end
