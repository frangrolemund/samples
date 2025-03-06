//
//  RSI_jpeg_base.h
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/21/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSI_file.h"
#import "RSI_common.h"
#import "RSI_huffman.h"
#import "RSI_scrambler.h"

//  - common types
typedef int16_t      img_sample_t;
typedef img_sample_t du_t[64];
typedef img_sample_t *du_ref_t;
#define DU_BYTELEN   (64 << 1)
typedef unsigned char quant_table_t[64];

//  - constants from Annex B - ISO/IEC 10918-1 : 1 1993(E)
extern const uint16_t MARK_SOI;
extern const uint16_t MARK_APP0;
extern const uint16_t MARK_DQT;
extern const uint16_t MARK_SOF;
extern const uint16_t MARK_DHT;
extern const uint16_t MARK_SOS;
extern const uint16_t MARK_EOI;
extern const uint16_t MARK_COM;
extern const uint16_t MARK_APPN;
extern const uint16_t MARK_APP_SCRAMBLE;

extern const unsigned char JPEG_HUFF_TABLE_CLASS_DC;
extern const unsigned char JPEG_HUFF_TABLE_CLASS_AC;
extern const unsigned char JPEG_HUFF_TABLE_ID_LUMIN;
extern const unsigned char JPEG_HUFF_TABLE_ID_CHROM;

extern const unsigned char JPEG_COMP_ID_Y;
extern const unsigned char JPEG_COMP_ID_Cb;
extern const unsigned char JPEG_COMP_ID_Cr;

extern const unsigned char JPEG_QUANT_LUMIN;
extern const unsigned char JPEG_QUANT_CHROM;
extern const unsigned char JPEG_STD_SAMPLING_FACTOR;

extern const unsigned char *JFIF_PFX;
extern const NSUInteger JFIF_PFX_LEN;

// - other constants
extern const int revAfterZigzag[9];

//  - this is the base class for all JPEG behavior common to packing and unpacking.
@interface JPEG_base : NSObject
{
    uint16_t            width;
    uint16_t            height;
    
    NSUInteger          numDUs;
    NSMutableData       *mdAllDUs;
    
    RSI_huffman         *htDCLuma;
    RSI_huffman         *htACLuma;
    RSI_huffman         *htDCChroma;
    RSI_huffman         *htACChroma;
    
    RSI_scrambler       *scramblerKey;
    int                 scrambledBitCount;
    RSI_file            *fOriginalDC;
    RSI_file            *fScrambledDC;
}

-(void) allocDUCacheForWidth:(uint16_t) w andHeight:(uint16_t) h andZeroFill:(BOOL) zeroFill;
-(BOOL) processDU:(du_ref_t) DU forHuffmanDC:(RSI_huffman *) htDC andHuffmanAC:(RSI_huffman *) htAC intoOutput:(RSI_file *) fOutput withError:(NSError **) err;
-(BOOL) colorScrambleDCInDU:(du_ref_t) DU withError:(NSError **) err;
-(void) embedData:(RSI_file *) data intoDU:(du_ref_t) DU postZigzag:(BOOL) afterZigzag;
-(BOOL) scrambleACCoefficientsWithError:(NSError **) err;
-(BOOL) scrambleCachedImageWithError:(NSError **) err;
-(BOOL) encodeOneHuffmanTable:(RSI_huffman *) HT asClass:(unsigned char) tclass intoOutput:(RSI_file *) fOutput withError:(NSError **) err;
-(BOOL) encodeHuffmanTablesIntoOutput:(RSI_file *) fOutput withError:(NSError **) err;
-(BOOL) encodeFrameHeaderIntoOutput:(RSI_file *) fOutput withError:(NSError **) err;
-(BOOL) encodeScanHeaderIntoOutput:(RSI_file *) fOutput withError:(NSError **) err;
-(BOOL) encodeEndOfImageIntoOutput:(RSI_file *) fOutput withError:(NSError **) err;
-(BOOL) encodeScrambleSegmentIntoOutput:(RSI_file *) fOutput withError:(NSError **) err;

@end
