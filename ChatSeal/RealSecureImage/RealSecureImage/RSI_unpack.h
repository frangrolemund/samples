//
//  RSI_unpack.h
//  RealSecureImage
//
//  Created by Francis Grolemund on 11/19/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import "RSI_scrambler.h"
#import "RSI_securememory.h"

@interface RSI_unpack : NSObject

+(NSData *) unpackData:(NSData *) imgFile withMaxLength:(NSUInteger) maxLen andError:(NSError **) err;
+(RSI_securememory *) descrambledJPEG:(NSData *) jpegFile withKey:(RSI_scrambler *) key andError:(NSError **) err;
+(RSI_securememory *) hashImageData:(NSData *) imgFile withError:(NSError **) err;
+(NSData *) repackData:(NSData *) imgFile withData:(NSData *) data andError:(NSError **) err;
+(NSData *) getPNGImageBufferFromFile:(NSData *) imgFile returningSize:(CGSize *) imageSize andError:(NSError **) err;
+(BOOL) isImageJPEG:(NSData *) d;
+(BOOL) hasEnoughDataForImageTypeIdentification:(NSData *) d;
+(BOOL) isSupportedPackedFile:(NSData *) d;
+(NSData *) scrambledJPEG:(NSData *) jpegFile andKey:(RSI_scrambler *) key andError:(NSError **) err;

@end
