//
//  RSI_huffman.h
//  RealSecureImage
//
//  Created by Francis Grolemund on 11/14/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

//  - to support standar
typedef enum
{
    HUFF_STD_NONE = 0,
    HUFF_STD_DC_LUM = 1,
    HUFF_STD_AC_LUM = 2,
    HUFF_STD_DC_CHR = 3,
    HUFF_STD_AC_CHR = 4
} huffman_std_type_t;

typedef struct
{
    //  - Because the code is a bit stream that must be
    //    written as-is to the output, I don't want to messs
    //    with the possibility of two's-compliment conversion
    //    problems.  Therefore I made it 32-bit unsigned.
    //  - Likewise, negative sizes do not make any sense
    //    so I'm not going to even entertain them.
    uint32_t code;
    uint32_t size;
} huff_entry_t;


@interface RSI_huffman : NSObject
{
    BOOL                isTableBuilt;
    BOOL                hasInterchange;
    
    //  - interchange format
    huffman_std_type_t  style;
    unsigned char       bits[16];
    NSMutableData       *huffval;
    
    //  - encoding tables
    huff_entry_t HT[256];
    uint32_t FREQ[257];         // accommodate 0-255 plus the reserved code point
    
    //  - decoding tables
    int32_t mincode[16];
    int32_t maxcode[16];
    uint16_t valptr[16];
}

-(id) initWithType:(huffman_std_type_t) t;
-(id) initWithBits:(unsigned char [16]) b andHuffValues:(NSData *) values;

//  - for building a custom table
-(void) resetFrequencies;
-(void) countFrequency:(unsigned char) val;

//  - for encoding/decoding
-(const huff_entry_t *) table;

//  - for interacting with the interchange format
-(const unsigned char *) BITS;
-(NSData *) HUFFVAL;
-(int32_t *) MINCODE;
-(int32_t *) MAXCODE;
-(uint16_t *) VALPTR;

+(NSUInteger) MAX_SIZE_HUFFVALS;

@end
