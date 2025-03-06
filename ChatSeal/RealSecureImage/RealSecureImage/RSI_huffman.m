//
//  RSI_huffman.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 11/14/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import "RSI_huffman.h"

static const NSUInteger MAX_SIZE_HT = (255 * 16) + 1;      //  no overflow even with bad data
static const NSUInteger SIZE_FREQ_TABLE = 257;             //  0-255 plus a reserved code point

//  - forward declarations
@interface RSI_huffman (internal)
-(void) loadInterchangeWithStyle:(huffman_std_type_t) t;
-(BOOL) buildRuntimeTable;
-(BOOL) buildInterchangeFromStats;
@end

/**************************
 RSI_huffman
 **************************/
@implementation RSI_huffman

/*
 *  When in doubt, use a custom table
 */
-(id) init
{
    return [self initWithType:HUFF_STD_NONE];
}

/*
 *  The designated initializer
 */
-(id) initWithType:(huffman_std_type_t) t
{
    self = [super init];
    if (self) {
        isTableBuilt = NO;
        hasInterchange = NO;
        [self resetFrequencies];        
        style = t;
        huffval = [[NSMutableData alloc] init];
        [self loadInterchangeWithStyle:t];
    }
    return self;
}

/*
 *  Initialize the table with a sequence of bits and values.
 */
-(id) initWithBits:(unsigned char [16]) b andHuffValues:(NSData *) values
{
    self = [super init];
    if (self) {
        isTableBuilt = NO;
        hasInterchange = YES;
        style = HUFF_STD_NONE;
        memcpy(bits, b, sizeof(bits));
        huffval = [[NSMutableData alloc] initWithData:values];
    }
    return self;
}

/*
 *  Free the object
 */
-(void) dealloc
{
    [huffval release];
    huffval = nil;
    
    [super dealloc];
}

/*
 *  Returns a pointer to the table used for encoding/decoding.
 */
-(const huff_entry_t *) table
{
    if (!isTableBuilt) {
        if (![self buildRuntimeTable]) {
            return NULL;
        }
        isTableBuilt = YES;
    }
    
    return HT;
}

/*
 *  Returns the interchange list of code lengths.
 */
-(const unsigned char *) BITS
{
    if (!hasInterchange) {
        [self buildInterchangeFromStats];
    }
    
    return bits;
}

/*
 *  Returns the interchange list of values.
 */
-(NSData *) HUFFVAL
{
    if (!hasInterchange && ![self buildInterchangeFromStats]) {
        return nil;
    }
    
    return huffval;
}

/*
 *  Reset the saved frequencies array
 */
-(void) resetFrequencies
{
    memset(FREQ, 0, sizeof(FREQ));
    FREQ[SIZE_FREQ_TABLE - 1] = 1;
    isTableBuilt = NO;
    [self loadInterchangeWithStyle:style];
}

/*
 *  When building a custom Huffman table, this method will be used
 *  to count frequencies of values in a given stream of output.
 */
-(void) countFrequency:(unsigned char) val
{
    if (style != HUFF_STD_NONE) {
        return;
    }
    
    isTableBuilt = NO;
    FREQ[val]++;
}

/*
 *  Return the maximum size that a huffman value array can be.
 */
+(NSUInteger) MAX_SIZE_HUFFVALS
{
    return MAX_SIZE_HT;
}

/*
 *  For decoding, returns the MINCODE table defined in F.2.2.3
 */
-(int32_t *) MINCODE
{
    if (!isTableBuilt) {
        if (![self buildRuntimeTable]) {
            return NULL;
        }
        isTableBuilt = YES;
    }
    
    return mincode;
}

/*
 *  For decoding, returns the MAXCODE table defined in F.2.2.3
 */
-(int32_t *) MAXCODE
{
    if (!isTableBuilt) {
        if (![self buildRuntimeTable]) {
            return NULL;
        }
        isTableBuilt = YES;
    }
    
    return maxcode;
}

/*
 *  For decoding, returns the VALPTR table defined in F.2.2.3
 */
-(uint16_t *) VALPTR
{
    if (!isTableBuilt) {
        if (![self buildRuntimeTable]) {
            return NULL;
        }
        isTableBuilt = YES;
    }
    
    return valptr;
}

@end


/****************************
 RSI_huffman (internal)
 ****************************/
@implementation RSI_huffman (internal)
/*
 *  Configure the interchange tables with the codes appropriate for
 *  the given style.  
 */
-(void) loadInterchangeWithStyle:(huffman_std_type_t) t
{
    const unsigned char std_dc_lum_bits[] = {0x00, 0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
    const unsigned char std_dc_lum_vals[] = {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B};
    
    const unsigned char std_dc_chr_bits[] = {0x00, 0x03, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00};
    const unsigned char std_dc_chr_vals[] = {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B};
    
    const unsigned char std_ac_lum_bits[] = {0x00, 0x02, 0x01, 0x03, 0x03, 0x02, 0x04, 0x03, 0x05, 0x05, 0x04, 0x04, 0x00, 0x00, 0x01, 0x7D};
    const unsigned char std_ac_lum_vals[] = {0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06, 0x13, 0x51, 0x61, 0x07,
                                             0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xA1, 0x08, 0x23, 0x42, 0xB1, 0xC1, 0x15, 0x52, 0xD1, 0xF0,
                                             0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0A, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x25, 0x26, 0x27, 0x28,
                                             0x29, 0x2A, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49,
                                             0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69,
                                             0x6A, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
                                             0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7,
                                             0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5,
                                             0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xE1, 0xE2,
                                             0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8,
                                             0xF9, 0xFA};
    
    const unsigned char std_ac_chr_bits[] = {0x00, 0x02, 0x01, 0x02, 0x04, 0x04, 0x03, 0x04, 0x07, 0x05, 0x04, 0x04, 0x00, 0x01, 0x02, 0x77};
    const unsigned char std_ac_chr_vals[] = {0x00, 0x01, 0x02, 0x03, 0x11, 0x04, 0x05, 0x21, 0x31, 0x06, 0x12, 0x41, 0x51, 0x07, 0x61, 0x71,
                                             0x13, 0x22, 0x32, 0x81, 0x08, 0x14, 0x42, 0x91, 0xA1, 0xB1, 0xC1, 0x09, 0x23, 0x33, 0x52, 0xF0,
                                             0x15, 0x62, 0x72, 0xD1, 0x0A, 0x16, 0x24, 0x34, 0xE1, 0x25, 0xF1, 0x17, 0x18, 0x19, 0x1A, 0x26,
                                             0x27, 0x28, 0x29, 0x2A, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48,
                                             0x49, 0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68,
                                             0x69, 0x6A, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87,
                                             0x88, 0x89, 0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3, 0xA4, 0xA5,
                                             0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3,
                                             0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA,
                                             0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8,
                                             0xF9, 0xFA};
    
    switch (t)
    {
        //  - standard Luminance DC table from K.3.3.1
        case HUFF_STD_DC_LUM:
            memcpy(bits, std_dc_lum_bits, 16);
            [huffval setData:[NSData dataWithBytes:std_dc_lum_vals length:sizeof(std_dc_lum_vals)]];
            break;
            
        //  - standard Luminance AC table from K.3.3.2
        case HUFF_STD_AC_LUM:
            memcpy(bits, std_ac_lum_bits, 16);
            [huffval setData:[NSData dataWithBytes:std_ac_lum_vals length:sizeof(std_ac_lum_vals)]];
            break;
            
        //  - standard Chrominance DC table from K.3.3.1
        case HUFF_STD_DC_CHR:
            memcpy(bits, std_dc_chr_bits, 16);
            [huffval setData:[NSData dataWithBytes:std_dc_chr_vals length:sizeof(std_dc_chr_vals)]];
            break;
            
        //  - standard Chrominance AC table from K.3.3.2
        case HUFF_STD_AC_CHR:
            memcpy(bits, std_ac_chr_bits, 16);
            [huffval setData:[NSData dataWithBytes:std_ac_chr_vals length:sizeof(std_ac_chr_vals)]];
            break;
            
        //  - custom table to be defined.
        case HUFF_STD_NONE:
        default:
            memset(bits, 0, sizeof(bits));
            [huffval setLength:0];
            break;
    }
    
    if (t != HUFF_STD_NONE) {
        hasInterchange = YES;
    }
    else {
        hasInterchange = NO;
    }
}

/*
 *  Compute a Huffman table from the interchange format.
 */
-(BOOL) buildRuntimeTable
{
    //  With custom Huffman implementations, the interchange
    //  table has to be built first.
    if (!hasInterchange && ![self buildInterchangeFromStats]) {
        return NO;
    }
    
    //  Generate size table - fig C.1
    int lastk = -1;
    NSMutableData *mdSizes = [NSMutableData dataWithLength:(sizeof(uint32_t) * MAX_SIZE_HT)];
    uint32_t *huffsize = (uint32_t *) mdSizes.mutableBytes;
    int i, j, k;
    
    for (i = 1, j = 1, k = 0; i < 17;) {
        if (j > bits[i-1]) {
            i++;
            j = 1;
        }
        else {
            huffsize[k] = (uint32_t) i;
            k++;
            j++;
        }
    }

    huffsize[k] = 0;
    lastk = k;
    
    //  - the number of sizes must match the number of included codes
    if (lastk > [huffval length]) {
        return NO;
    }
    
    //  Generate code table - fig C.2
    NSMutableData *mdCodes = [NSMutableData dataWithLength:(sizeof(uint32_t) * MAX_SIZE_HT)];
    uint32_t *huffcode = (uint32_t *) mdCodes.mutableBytes;
    uint32_t code, sl;
    for (k = 0, code = 0, sl = huffsize[0];;) {
        huffcode[k] = code;
        code++;
        k++;
        
        if (huffsize[k] == sl) {
            continue;
        }
        
        if (huffsize[k] == 0) {
            break;
        }
        
        for (;;) {
            code = code << 1;
            sl = sl + 1;
            
            if (huffsize[k] == sl) {
                break;
            }
        }
    }
    
    //  Generate the huffman table - fig C.3
    memset(HT, 0, sizeof(HT));
    const unsigned char *values = (const unsigned char *) huffval.bytes;
    for (k = 0; k < lastk; k++) {
        if (huffsize[k] == 0) {
            continue;
        }
        
        int idx      = values[k];
        HT[idx].code = huffcode[k];
        HT[idx].size = huffsize[k];
    }
    
    //  Generate the decode tables - fig F.15
    memset(mincode, 0, sizeof(mincode));
    memset(maxcode, 0, sizeof(maxcode));
    memset(valptr, 0, sizeof(valptr));
    for (i = 0, j = 0; i < 16; i++) {
        if (bits[i] == 0) {
            maxcode[i] = -1;
        }
        else {
            valptr[i] = j;
            mincode[i] = (int32_t) huffcode[j];
            j = j + bits[i] - 1;
            maxcode[i] = (int32_t) huffcode[j];
            j++;
        }
        
    }
    
    return YES;
}

/*
 *  Build the interchange table from the collected statistics.
 *  - This implements the procedure defined in section K.2 of CCITT Rec. T.81 (1992 E).
 */
-(BOOL) buildInterchangeFromStats
{
    BOOL ret = YES;

    //  Prep work for the parallel tables
    int CODESIZE[SIZE_FREQ_TABLE];
    int OTHERS[SIZE_FREQ_TABLE];
    
    memset(CODESIZE, 0, sizeof(CODESIZE));
    for (int i = 0; i < SIZE_FREQ_TABLE; i++) {
        OTHERS[i] = -1;
    }
    
    //  Figure K.1 - Generate the code sizes
    //  - Note, this table is specified as being from 0-255 because
    //    all Huffman codes are eventually either a category (for DC) or
    //    a length plus a category (for AC), which in both cases are always
    //    0-255.   This part here is counting the frequencies of the categories
    //   encoded into the bit stream instead of the value of the DU elements.
    //  - The spec is predictably obscure about what constitutes a 'symbol' in K.2.
    int V1, V2;    
    for (;;) {
        //  - find V1 for least value of FREQ(V1) > 0
        //  - find V2 for next least value of FREQ(V2) > 0
        V1 = -1, V2 = -1;
        for (int i = 0; i < SIZE_FREQ_TABLE; i++) {
            if (FREQ[i] == 0) {
                continue;
            }
            
            if (V1 == -1 || FREQ[i] <= FREQ[V1]) {
                V2 = V1;
                V1 = i;
            }
            else if (V1 >= 0 && (V2 == -1 || FREQ[i] < FREQ[V2])) {
                V2 = i;
            }
        }
        
        //  - when we have no V2, that means we're out
        //    of entries.
        if (V2 == -1) {
            break;
        }
        
        FREQ[V1] = FREQ[V1] + FREQ[V2];
        FREQ[V2] = 0;

        for (;;) {
            CODESIZE[V1] = CODESIZE[V1] + 1;
            if (OTHERS[V1] == -1) {
                break;
            }
            V1 = OTHERS[V1];
        }
        
        OTHERS[V1] = V2;
        for (;;) {
            CODESIZE[V2] = CODESIZE[V2] + 1;
            if (OTHERS[V2] == -1) {
                break;
            }
            V2 = OTHERS[V2];
        }
    }
    
    //  Figure K.2 - Find the number of codes for each size.
    unsigned int pendingBITS[32 + 1];                                //  one extra to make it natural to count sizes
    memset(pendingBITS, 0, sizeof(pendingBITS));
    for (int i = 0; i < SIZE_FREQ_TABLE; i++) {
        if (CODESIZE[i] != 0) {
            if (CODESIZE[i] > 32) {
                NSLog(@"RSI: A codesize value exceeded the maximum: %d.", CODESIZE[i]);
                ret = NO;
                break;
            }
            pendingBITS[CODESIZE[i]] = pendingBITS[CODESIZE[i]] + 1;
        }
    }
    
    //  Figure K.3 - adjust bits to lengths no more than 16
    int i = 32;
    int j = 0;
    for (;ret == YES;) {
        if (pendingBITS[i] > 0) {
            j = i - 1;
            
            for (;;) {
                j--;
                if (j < 0) {
                    NSLog(@"RSI: Unexpected pending bit underflow.");
                    ret = NO;
                    break;
                }
                if (pendingBITS[j] > 0) {
                    pendingBITS[i] = pendingBITS[i] - 2;
                    pendingBITS[i - 1] = pendingBITS[i - 1] + 1;
                    pendingBITS[j + 1] = pendingBITS[j + 1] + 2;
                    pendingBITS[j] = pendingBITS[j] - 1;
                    break;
                }
            }
        }
        else {
            i--;
            if (i == 16) {
                for (;;) {
                    if (pendingBITS[i] != 0) {
                        break;
                    }
                    i--;
                    if (i < 0) {
                        NSLog(@"RSI: Unexpected pending bit underflow.");
                        ret = NO;
                        break;
                    }
                }
                
                pendingBITS[i] = pendingBITS[i] - 1;
                
                //  DONE.  We have 16 bits
                break;
            }
        }
    }
    
    //  - now just transfer them to the real array
    for (i = 0; ret == YES && i < 16; i++) {
        bits[i] = (unsigned char) (pendingBITS[i+1] & 0xFF);
    }
    
    //  Figure K.4 - Sort the table according to code size.
    for (i = 1; ret == YES && i < 33; i++) {
        for (j = 0; j < (SIZE_FREQ_TABLE - 1); j++) {
            if (CODESIZE[j] == i) {
                unsigned char hv = (unsigned char) (j & 0xFF);
                [huffval appendBytes:&hv length:1];
            }
        }
    }
        
    hasInterchange = ret;
    return ret;
}

@end