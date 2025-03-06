//
//  RSI_png.h
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/8/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <zlib.h>
#import "RSI_png_scanline.h"
#import "RSI_file.h"
#import "RSI_zlib_file.h"
#import "RSI_securememory.h"

//  - an instance-based PNG packing object.
@interface PNG_pack : NSObject
-(id) initWithBitmap:(unsigned char *) bm andWidth:(NSUInteger) w andHeight:(NSUInteger) h andData:(NSData *) d;
-(NSData *) packedPNGandError:(NSError **) err;

+(NSUInteger) maxDataForPNGImageOfWidth:(NSUInteger) w andHeight:(NSUInteger) h;
+(NSUInteger) bitsPerPNGPixel;

@end

//  - this does the actual PNG unpacking
@interface PNG_unpack : NSObject
+(BOOL) isDataPNG:(NSData *) d;
+(NSUInteger) minimumDataLengthForTypeIdentification;
-(id) initWithData:(NSData *) dFile andMaxLength:(NSUInteger) len;
-(NSData *) unpackWithError:(NSError **) err;
-(NSData *) readImageWithError:(NSError **) err;
-(CGSize) imageSize;

+(NSData *) repackData:(NSData *) imgFile withData:(NSData *) data andError:(NSError **) err;
+(RSI_securememory *) hashImageData:(NSData *) jpegFile withError:(NSError **) err;

@end