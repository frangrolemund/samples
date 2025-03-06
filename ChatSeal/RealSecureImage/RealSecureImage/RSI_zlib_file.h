//
//  RSI_zlib_file.h
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/11/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "RSI_file.h"
#include <zlib.h>

typedef enum
{
    RSI_CL_NONE = 0,
    RSI_CL_FAST = 1,
    RSI_CL_BEST = 9,
    RSI_CL_DEFAULT = -1
} RSI_compression_level_e;

typedef enum
{
    RSI_CS_DEFAULT  = 0,
    RSI_CS_FILTERED = 1,
    RSI_CS_HUFFMAN  = 2,
    RSI_CS_RLE      = 3,
    RSI_CS_FIXED    = 4

} RSI_compression_strategy_e;

#define RSI_ZLIB_BUFLEN 32768

@interface RSI_zlib_file : RSI_file
-(id) initForWriteWithLevel:(RSI_compression_level_e) l andWindowBits:(int) b andStategy:(RSI_compression_strategy_e) s withError:(NSError **) err;
-(id) initForReadWithData:(NSData *) dCompressed andError:(NSError **) err;

@end
