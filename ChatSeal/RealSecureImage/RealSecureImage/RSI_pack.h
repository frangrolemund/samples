//
//  RSI_pack.h
//  RealSecureImage
//
//  Created by Francis Grolemund on 11/9/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RSI_scrambler.h"
#import "RSI_common.h"
#import "RSI_huffman.h"
#import "RSI_file.h"

@interface RSI_pack : NSObject

//  - JPEG packing operations.
+(NSUInteger) maxDataForJPEGImage:(UIImage *) img;
+(NSData *) packedJPEG:(UIImage *) img withQuality:(CGFloat) quality andData:(NSData *) data andError:(NSError **) err;
+(NSData *) scrambledJPEG:(UIImage *) img withQuality:(CGFloat) quality andKey:(RSI_scrambler *) key andError:(NSError **) err;
+(NSUInteger) bitsPerJPEGCoefficient;
+(NSUInteger) embeddedJPEGGroupSize;

//  - PNG packing operations
//  scrambling isn't supported because it won't be used due to excessive memory requirements.
+(NSUInteger) maxDataForPNGImage:(UIImage *) img;
+(NSUInteger) maxDataForPNGImageOfSize:(CGSize) szImage;
+(NSUInteger) bitsPerPNGPixel;
+(NSData *) packedPNG:(UIImage *) img andData:(NSData *) data andError:(NSError **) err;

@end
