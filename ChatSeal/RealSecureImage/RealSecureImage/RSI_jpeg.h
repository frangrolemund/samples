//
//  RSI_jpeg.h
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/7/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSI_jpeg_base.h"

//  - an instance-based JPEG packing object.
@interface JPEG_pack : JPEG_base
{
    //  the data to operate upon
    int                  quality;
    const unsigned char *bitmap;
    
    RSI_file            *data;
    
    quant_table_t       container_lumin_quant;
    quant_table_t       container_chrom_quant;
    quant_table_t       fake_lumin_quant;
    quant_table_t       fake_chrom_quant;
    
    //  for encoding
    img_sample_t prevYDC;
    img_sample_t prevCbDC;
    img_sample_t prevCrDC;    
}

-(id) initWithBitmap:(const unsigned char *) bm andWidth:(int) w andHeight:(int) h andQuality:(int) q andData:(NSData *) d andKey:(RSI_scrambler *) key;
-(void) generateQuant:(quant_table_t) dest usingQuant:(const quant_table_t) src atQuality:(int) generateQuality;
-(void) computeQuantTablesWithData:(NSData *) d;
-(void) resetData;
-(void) embedData:(du_ref_t) DU withRealQuant:(quant_table_t) realQuant andFakeQuant:(quant_table_t) fakeQuant;
-(void) zigzagEncode:(du_ref_t) DU;
-(BOOL) encodeScanUsingProcessor:(BOOL) freqProcessor intoOutput:(RSI_file *) fOutput withError:(NSError **) err;
-(BOOL) encodeQuantTablesIntoOutput:(RSI_file *) fOutput withError:(NSError **) err;
-(BOOL) encodeStartOfImageIntoOutput:(RSI_file *) fOutput withError:(NSError **) err;
-(BOOL) encodeImageIntoOutput:(RSI_file *) fOutput withError:(NSError **) err;
-(NSData *) packedJPEGandError:(NSError **) err;
+(void) FDCTBaseline:(du_ref_t) DU withQuant:(quant_table_t) quantizer;
+(void) FDCTColumnsAndRows:(du_ref_t) DU withQuant:(quant_table_t) quantizer;
+(void) FDCTPracticalFast:(du_ref_t) DU withQuant:(quant_table_t) quantizer;
+(NSUInteger) maxDataForJPEGImageOfWidth:(NSUInteger) w andHeight:(NSUInteger) h;
+(NSUInteger) bitsPerJPEGCoefficient;
+(NSUInteger) embeddedJPEGGroupSize;
+(CGFloat) defaultJPEGQualityForMessaging;
@end

//  - this does the actual work of unpacking the object.
@interface JPEG_unpack : JPEG_base
+(BOOL) isDataJPEG:(NSData *) d;
+(NSUInteger) minimumDataLengthForTypeIdentification;
-(id) initWithData:(NSData *) d andScrambler:(RSI_scrambler *) key andNewHiddenContent:(NSData *) dHidden andMaxLength:(NSUInteger) len;
-(id) unpackAndScramble:(BOOL) doScramble;
-(BOOL) echoSegmentIntoOutput:(uint16_t) marker withContent:(BOOL) hasContent;
-(BOOL) checkForHeader;
-(BOOL) skipSegment;
-(BOOL) decodeQuantTables;
-(BOOL) decodeHuffmanTables;
-(BOOL) decodeFrameHeader;
-(BOOL) decodeScanWithSoftAbort:(BOOL *) aborted andDescramble:(BOOL) descramble;
-(BOOL) decodeScanHeader;
-(BOOL) decodeEmbeddedData:(du_t) DU;
-(BOOL) decodeOneDU:(du_t) DU withDCHT:(RSI_huffman *) htDC andACHT:(RSI_huffman *) htAC andDescramble:(BOOL) descramble;
-(BOOL) decodeOneValue:(unsigned char *) value withHT:(RSI_huffman *) ht;
-(BOOL) receiveAndExtend:(unsigned char) value withResult:(img_sample_t *) result;
-(void) captureImageHash;
-(BOOL) decodeDCRemainders;
-(RSI_securememory *) hash;
-(BOOL) rewriteFileDataWithScrambleSegment:(BOOL) hasScramble;
-(BOOL) descrambleImageData;
-(BOOL) descrambleDCCoefficients;
-(BOOL) descrambleACCoefficients;
-(BOOL) repackHiddenData;
@end

