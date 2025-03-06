//
//  RSI_jpeg.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/7/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "RSI_jpeg.h"

//  - used for resequencing the quantized coefficients.
//    (these represent the new locations of the coefficients
//     after zig-zagging.)
static const int std_zigzag[64] = {0,  1,  5,  6, 14, 15, 27, 28,
    2,  4,  7, 13, 16, 26, 29, 42,
    3,  8, 12, 17, 25, 30, 41, 43,
    9, 11, 18, 24, 31, 40, 44, 53,
    10, 19, 23, 32, 39, 45, 52, 54,
    20, 22, 33, 38, 46, 51, 55, 60,
    21, 34, 37, 47, 50, 56, 59, 61,
    35, 36, 48, 49, 57, 58, 62, 63};

//  These are taken directly from Annex K of ISO/IEC 10918-1: 1993(E)
static const quant_table_t std_lumin_quant = { 16,  11,  10,  16, 24,  40,  51,  61,
    12,  12,  14,  19, 26,  58,  60,  55,
    14,  13,  16,  24, 40,  57,  69,  56,
    14,  17,  22,  29, 51,  87,  80,  62,
    18,  22,  37,  56, 68,  109, 103, 77,
    24,  35,  55,  64, 81,  104, 113, 92,
    49,  64,  78,  87, 103, 121, 120, 101,
    72,  92,  95,  98, 112, 100, 103, 99};

static const quant_table_t std_chrom_quant = { 17,  18,  24,  47,  99,  99,  99,  99,
    18,  21,  26,  66,  99,  99,  99,  99,
    24,  26,  56,  99,  99,  99,  99,  99,
    47,  66,  99,  99,  99,  99,  99,  99,
    99,  99,  99,  99,  99,  99,  99,  99,
    99,  99,  99,  99,  99,  99,  99,  99,
    99,  99,  99,  99,  99,  99,  99,  99,
    99,  99,  99,  99,  99,  99,  99,  99};

static double sqrt2 = 0.0f;
static double rot3cos = 0.0f;
static double rot3sin = 0.0f;
static double rot1cos = 0.0f;
static double rot1sin = 0.0f;
static double sqrot6cos = 0.0f;
static double sqrot6sin = 0.0f;

#define CLAMP_TO(_val, _low, _hi)   \
if (_val < (_low)) {            \
_val = (_low);              \
} else if (_val > (_hi)) {      \
_val = (_hi);               \
}

/*
 *  DEBUG function to print the given matrix of data unit coefficients as integer values.
 */
void printMatrixInt(du_t DU, NSString *title)
{
    NSLog(@"%@", title);
    for (int row = 0; row < 8; row++) {
        NSString *rowString = @"";
        for (int col = 0; col < 8; col++) {
            int val = DU[(row << 3) + col];
            rowString = [rowString stringByAppendingFormat:@"%s%6d", col > 0 ? " " : "", val];
        }
        NSLog(@"%@", rowString);
    }
}

/**************************
 JPEG_pack
 **************************/
@implementation JPEG_pack

/*
 *  Perform common initialization for all uses.
 */
+(void) initialize
{    
    //  - precompute values we'll use for the FDCT
    sqrt2 = sqrt(2.0f);
    rot3cos = cos((3.0f * M_PI)/16.0f);
    rot3sin = sin((3.0f * M_PI)/16.0f);
    rot1cos = cos(M_PI/16.0f);
    rot1sin = sin(M_PI/16.0f);
    sqrot6cos = sqrt(2.0f) * cos((6.0f * M_PI)/16.0f);
    sqrot6sin = sqrt(2.0f) * sin((6.0f * M_PI)/16.0f);
}

/*
 *  Initialize the object.
 */
-(id) initWithBitmap:(const unsigned char *) bm andWidth:(int) w andHeight:(int) h andQuality:(int) q andData:(NSData *) d andKey:(RSI_scrambler *) key
{
    self = [super init];
    if (self) {
        bitmap = bm;
        width = w;
        height = h;
        quality = q;
        if (d) {
            data = [[RSI_file alloc] initForReadWithData:d];
        }
        
        //  - after some serious consideration, I've decided to keep the entire
        //    collection of DUs in RAM for two primary reasons:
        //    1.  to save on CPU processing because the image has to be scanned
        //    twice in order to compute a custom Huffman table.
        //    2.  to allow for much better scrambling when that is necessary, otherwise
        //    the data ends up being too close to its original location and shows ghosts
        //    of its former self.
        //  - my assumption is that we aren't going to support really large images and
        //    therefore can reasonably expect minimal resource requirements.
        [self allocDUCacheForWidth:w andHeight:h andZeroFill:YES];
        
        [self computeQuantTablesWithData:d];
        scrambledBitCount = 0;
        
        //  - if the standard tables from the spec are to be used
        //    uncomment these lines.
        //htDCLuma = [[RSI_huffman alloc] initWithType:HUFF_STD_DC_LUM];
        //htACLuma = [[RSI_huffman alloc] initWithType:HUFF_STD_AC_LUM];
        //htDCChroma = [[RSI_huffman alloc] initWithType:HUFF_STD_DC_CHR];
        //htACChroma = [[RSI_huffman alloc] initWithType:HUFF_STD_AC_CHR];
        
        //  ...otherwise create custom tables
        htDCLuma = [[RSI_huffman alloc] initWithType:HUFF_STD_NONE];
        htACLuma = [[RSI_huffman alloc] initWithType:HUFF_STD_NONE];
        htDCChroma = [[RSI_huffman alloc] initWithType:HUFF_STD_NONE];
        htACChroma = [[RSI_huffman alloc] initWithType:HUFF_STD_NONE];
        
        scramblerKey = [key retain];
        
        [self resetData];
    }
    return self;
}

/*
 *  Generate a quality-scaled quantization table.
 */
-(void) generateQuant:(quant_table_t) dest usingQuant:(const quant_table_t) src atQuality:(int) generateQuality
{
    CLAMP_TO(generateQuality, 1, 100);
    
    int scaling = (generateQuality < 50) ? (5000 / generateQuality) : (200 - (2 * generateQuality));
    
    //  - This is the standard Independent JPEG Group (IJG) algorithm for
    //    quantization scaling, which makes the images look just like 99% of the
    //    software-modified images on the Internet.
    for (int i = 0; i < 64; i++) {
        int val = src[i];
        int newval = ((scaling * val) + 50) / 100;
        CLAMP_TO(newval, 1, 255);
        dest[i] = newval;
    }
}

/*
 *  The quantization tables that are used for the final encoding aren't the same ones
 *  that were used to compress the source image.  Both types are computed specifically
 *  to minimize detection by external entities.
 */
-(void) computeQuantTablesWithData:(NSData *) d
{
    //  Generate the container quantization tables.
    [self generateQuant:container_lumin_quant usingQuant:std_lumin_quant atQuality:quality];
    [self generateQuant:container_chrom_quant usingQuant:std_chrom_quant atQuality:quality];
    
    //  - the fake values are generated per instance so that they can be slightly random to
    //    make these files harder to conclusively identify.
    //  - when the values are low in the embedding location, we can
    //    use larger quantization values and have the same general effect on the image
    int fakeq = 99;
    
    //  - randomization comes from the first 'width' bytes in the image
    //  - this CANNOT use any kind of random number generator or the
    //    results will be non-deterministic for seal images, which cannot
    //    ever be the case.
    int sum = 0;
    for (int i = 0; i < width; i++) {
        sum += bitmap[i];
    }
    
    int rFake = (sum & ((1 << 10) - 1));
    fakeq += (((100 - fakeq + 1) * rFake) >> 10);
    [self generateQuant:fake_lumin_quant usingQuant:std_lumin_quant atQuality:fakeq];
    [self generateQuant:fake_chrom_quant usingQuant:std_chrom_quant atQuality:fakeq];
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    bitmap = NULL;
    width = 0;
    height = 0;
    
    [data release];
    data = nil;
    
    [super dealloc];
}

/*
 *  If data exists, reset its pointers so that we can use it again.
 */
-(void) resetData
{
    if (data) {
        [data reset];
    }
}

/*
 *  Perform a forward discrete cosine transform on the provided data unit.
 *  - This is the baseline approach, which although slow, is correct.
 */
+(void) FDCTBaseline:(du_ref_t) DU withQuant:(quant_table_t) quantizer
{
    double dDU[64];
    
    for (int v = 0; v < 8; v++) {
        for (int u = 0; u < 8; u++) {
            
            dDU[(u << 3) + v] = 0.0f;
            
            for (int x = 0; x < 8; x++) {
                for (int y = 0; y < 8; y++) {
                    double val = DU[(x << 3) + y];
                    
                    double cosXU = cos((((2 * x) + 1) * u * M_PI) / 16.0f);
                    double cosYV = cos((((2 * y) + 1) * v * M_PI) / 16.0f);
                    
                    dDU[(u << 3) + v] += (val * cosXU * cosYV);
                }
            }
        }
    }
    
    for (int v = 0; v < 8; v++) {
        for (int u = 0; u < 8; u++) {
            if (u == 0) {
                dDU[(v << 3) + u] /= sqrt(2.0f);
            }
            
            if (v == 0) {
                dDU[(v << 3) + u] /= sqrt(2.0f);
            }
            
            dDU[(v << 3) + u] /= 4.0f;
        }
    }
    
    //  - apply quantization while it is still in floating point format to get the most
    //    bang for the buck.
    for (int n = 0; n < 64; n++) {
        DU[n] = round(dDU[n] / quantizer[n]);
    }
}

/*
 *  Perform a forward discrete cosine transform on the provided data unit.
 */
+(void) FDCTColumnsAndRows:(du_ref_t) DU withQuant:(quant_table_t) quantizer
{
    double dDU[64];
    double dDUTmp[64];
    
    //  - start with the rows
    for (int rv = 0; rv < 64; rv+=8) {
        
        //  - operate on each column, one at a time
        for (int u = 0, ru = 0; u < 8; u++, ru+=8) {
            
            dDUTmp[rv + u] = 0.0f;
            
            //  - now produce a 1D DCT with each column in the current row
            //    and store it in the current column's output
            for (int x = 0; x < 8; x++) {
                dDUTmp[rv + u] += (DU[rv + x] * cos((((2 * x) + 1) * u * M_PI) / 16.0f));
            }
        }
    }
    
    //  - now move to the columns
    for (int u = 0; u < 8; u++) {
        
        //  - operate on each row, one at a time.
        for (int rv = 0; rv < 64; rv+=8) {
            
            dDU[rv + u] = 0.0f;
            
            //  - now produce a 1D DCT with each row in the current column
            //    and store it in the current column's output.
            for (int y = 0, ry = 0; y < 8; y++, ry+=8) {
                dDU[rv + u] += (dDUTmp[ry + u] * cos((((2 * y) + 1) * (rv >> 3) * M_PI) / 16.0f));
            }
        }
    }
    
    //  Multiply the final results by the appropriate constant values.
    for (int v = 0; v < 8; v++) {
        for (int u = 0; u < 8; u++) {
            if (u == 0) {
                dDU[(v << 3) + u] = (dDU[(v << 3) + u] / sqrt(2.0f));
            }
            
            if (v == 0) {
                dDU[(v << 3) + u] = (dDU[(v << 3) + u] / sqrt(2.0f));
            }
            
            dDU[(v << 3) + u] /= 4.0f;
        }
    }
    
    //  - apply quantization while it is still in floating point format to get the most
    //    bang for the buck.
    for (int n = 0; n < 64; n++) {
        DU[n] = round(dDU[n] / quantizer[n]);
    }
}

/*
 *  Perform a forward discrete cosine transform on the provided data unit.
 */
+(void) FDCTPracticalFast:(du_ref_t) DU withQuant:(quant_table_t) quantizer
{
    //  This implements the 'Practical Fast 1-D DCT Algorithms with 11 Multiplications' by
    //  Loeffler, Ligtenberg and Moschytz.  1989 IEEE.
    //  The article 'Implementing Fast DCTs' from Doctor Dobb's Journal, 1999 was used
    //  as a reference.
    
    double dDU[64];
    
    //  - operate on the rows first
    for (int y = 0; y < 64; y+=8) {
        double c0, c1, c2, c3, c4, c5, c6, c7;
        double d0, d1, d2, d3, d4, d5, d6, d7;
        
        //  Pre-stage prep
        c0 = DU[y];
        c1 = DU[y + 1];
        c2 = DU[y + 2];
        c3 = DU[y + 3];
        c4 = DU[y + 4];
        c5 = DU[y + 5];
        c6 = DU[y + 6];
        c7 = DU[y + 7];
        
        //  Stage 1 - Fig 3 (DDJ)
        d0 = c0 + c7;
        d1 = c1 + c6;
        d2 = c2 + c5;
        d3 = c3 + c4;
        d4 = c3 - c4;
        d5 = c2 - c5;
        d6 = c1 - c6;
        d7 = c0 - c7;
        
        //  Stage 2
        c0 = d0 + d3;
        c1 = d1 + d2;
        c2 = d1 - d2;
        c3 = d0 - d3;
        
        double cmn = (d4 + d7) * rot3cos;
        c4 = cmn + (d7 * (rot3sin - rot3cos));
        c7 = cmn + (d4 * (-rot3sin - rot3cos));
        
        cmn = (d5 + d6) * rot1cos;
        c5 = cmn + (d6 * (rot1sin - rot1cos));
        c6 = cmn + (d5 * (-rot1sin - rot1cos));
        
        //  Stage 3
        d0 = c0 + c1;
        d1 = c0 - c1;
        
        cmn = (c2 + c3) * sqrot6cos;
        d2 = cmn + (c3 * (sqrot6sin - sqrot6cos));
        d3 = cmn + (c2 * (-sqrot6sin - sqrot6cos));
        
        d4 = c4 + c6;
        d5 = c7 - c5;
        d6 = c4 - c6;
        d7 = c5 + c7;
        
        //  Stage 4
        dDU[y]     = d0;
        dDU[y + 4] = d1;
        dDU[y + 2] = d2;
        dDU[y + 6] = d3;
        
        dDU[y + 7] = d7 - d4;
        dDU[y + 3] = d5 * sqrt2;
        dDU[y + 5] = d6 * sqrt2;
        dDU[y + 1] = d4 + d7;
    }
    
    // ...now the columns
    for (int x = 0; x < 8; x++) {
        double c0, c1, c2, c3, c4, c5, c6, c7;
        double d0, d1, d2, d3, d4, d5, d6, d7;
        
        //  Pre-stage prep
        c0 = dDU[x];
        c1 = dDU[x+8];
        c2 = dDU[x+16];
        c3 = dDU[x+24];
        c4 = dDU[x+32];
        c5 = dDU[x+40];
        c6 = dDU[x+48];
        c7 = dDU[x+56];
        
        //  Stage 1 - Fig 3 (DDJ)
        d0 = c0 + c7;
        d1 = c1 + c6;
        d2 = c2 + c5;
        d3 = c3 + c4;
        d4 = c3 - c4;
        d5 = c2 - c5;
        d6 = c1 - c6;
        d7 = c0 - c7;
        
        //  Stage 2
        c0 = d0 + d3;
        c1 = d1 + d2;
        c2 = d1 - d2;
        c3 = d0 - d3;
        
        double cmn = (d4 + d7) * rot3cos;
        c4 = cmn + (d7 * (rot3sin - rot3cos));
        c7 = cmn + (d4 * (-rot3sin - rot3cos));
        
        cmn = (d5 + d6) * rot1cos;
        c5 = cmn + (d6 * (rot1sin - rot1cos));
        c6 = cmn + (d5 * (-rot1sin - rot1cos));
        
        //  Stage 3
        d0 = c0 + c1;
        d1 = c0 - c1;
        
        cmn = (c2 + c3) * sqrot6cos;
        d2 = cmn + (c3 * (sqrot6sin - sqrot6cos));
        d3 = cmn + (c2 * (-sqrot6sin - sqrot6cos));
        
        d4 = c4 + c6;
        d5 = c7 - c5;
        d6 = c4 - c6;
        d7 = c5 + c7;
        
        //  Stage 4
        //  - note that the division by 8 is the required
        //    scaling factor after applying two 1D DCTs on the columns and rows.
        //  - move back into the source matrix and quantize now to avoid another
        //    pass through the array
        DU[x]      = round((d0 / 8.0f) / quantizer[x]);
        DU[x + 32] = round((d1 / 8.0f) / quantizer[x + 32]);
        DU[x + 16] = round((d2 / 8.0f) / quantizer[x + 16]);
        DU[x + 48] = round((d3 / 8.0f) / quantizer[x + 48]);
        
        DU[x + 56] = round(((d7 - d4) / 8.0f) / quantizer[x + 56]);
        DU[x + 24] = round(((d5 * sqrt2) / 8.0f) / quantizer[x + 24]);
        DU[x + 40] = round(((d6 * sqrt2) / 8.0f) / quantizer[x + 40]);
        DU[x + 8]  = round(((d4 + d7) / 8.0f) / quantizer[x + 8]);
    }
}

/*
 *  If data is provided, embed it into the image.
 *  - the fake tables have to be scaled to 8-bit resolution to accommodate storage into the output
 */
-(void) embedData:(du_ref_t) DU withRealQuant:(quant_table_t) realQuant andFakeQuant:(quant_table_t) fakeQuant
{
    //  This small function is the secret sauce.  The objective is to convert
    //  the quantized data unit into a high-quality quantized data unit, which
    //  leaves space in the high-frequency range for storing our data.
    
    //  - dequantize with the compressed values and re-quantize with the high-quality
    //    coefficients.  I'm calling the high quality coefficients 'fake' because
    //    they don't reflect how the image was quantized in the first place.
    for (int i = 0; i < 64; i++) {
        double val = DU[i] * realQuant[i];
        val /= fakeQuant[i];
        DU[i] = round(val);
    }
    
    //  - if there is data to embed, do that now
    if (data) {
        [self embedData:data intoDU:DU postZigzag:NO];
    }
}

#define APPLY_DIFF(_dc, _prevdc)   {img_sample_t tmp = (_dc); _dc -= (_prevdc); _prevdc = tmp;}

/*
 *  Every data unit is encoded in a zig-zag pattern.
 */
-(void) zigzagEncode:(du_ref_t) DU
{
    du_t tmp;
    
    for (int i = 0; i < 64; i++) {
        tmp[std_zigzag[i]] = DU[i];
    }
    
    for (int i = 0; i < 64; i++) {
        DU[i] = tmp[i];
    }
}

/*
 *  Perform encoding on the bitmap data:
 *  - color space conversion
 *  - level shift
 *  - FDCT
 *  - quantization
 *  - zig-zag
 */
-(BOOL) encodeScanUsingProcessor:(BOOL) freqProcessor intoOutput:(RSI_file *) fOutput withError:(NSError **) err
{
    du_ref_t duY;                               //  luma
    du_ref_t duCb;                              //  chroma-B
    du_ref_t duCr;                              //  chroma-R
    
    int oneRowOffset = (width << 2);            //  width * 4 color components
    
    [self resetData];
    prevYDC = 0;
    prevCbDC = 0;
    prevCrDC = 0;
    
    if (!freqProcessor && fOutput &&
        ![fOutput beginEntropyEncodedSegment]) {
        [RSI_error fillError:err withCode:RSIErrorImageOutputFailure andFailureReason:@"Failed to encode ECS."];
        return NO;
    }
    
    //  Encoding assumes four components (R, G, B, A), and we skip the alpha.
    //  - a data unit is an 8x8 matrix of coefficients.
    //  - if there is no output file, we'll compute the internal array of DUs, otherwise, we'll read from it
    du_ref_t DUbegin = (du_ref_t) [mdAllDUs mutableBytes];
    for (int y = 0; y < height; y += 8) {
        for (int x = 0; x < width; x+= 8) {
            if ((unsigned char *) DUbegin > ((unsigned char *)[mdAllDUs mutableBytes]) + [mdAllDUs length]) {
                [RSI_error fillError:err withCode:RSIErrorAborted andFailureReason:@"Invalid DU dereference!"];
                return NO;
            }
            duY = DUbegin;
            duCb = duY + 64;
            duCr = duCb + 64;
            
            
            //  Pass one involves computing the baseline DUs for the entire image.
            if (!fOutput) {
                int topLeftOffset = (y * oneRowOffset) + (x << 2);
                
                //  Now we have the top-left corner of one MCU, but it must be
                //  decomposed into the individual components before we
                //  can operate on it.
                int idx = 0;
                for (int yi = 0; yi < 8; yi++) {
                    for (int xi = 0; xi < 8; xi++, idx++) {
                        if ((x + xi) < width && (y + yi) < height) {
                            unsigned char red   = bitmap[topLeftOffset + (xi << 2)];
                            unsigned char green = bitmap[topLeftOffset + (xi << 2) + 1];
                            unsigned char blue  = bitmap[topLeftOffset + (xi << 2) + 2];
                            
                            duY[idx]  = (0.299 * red) + (0.587 * green) + (0.114 * blue);
                            duY[idx] -= 128;   //  level shift
                            duCb[idx] = (-0.1687 * red) - (0.3313 * green) + (0.5 * blue) + 128;
                            duCb[idx] -= 128;  //  level shift
                            duCr[idx] = (0.5 * red) - (0.4187 * green) - (0.0813 * blue) + 128;
                            duCr[idx] -= 128;  //  level shift
                            
                        }
                        else {
                            //  duplicate the valid pixels when beyond the edge
                            int oldVal = 0;
                            if ((x + xi) >= width) {
                                oldVal = (yi << 3) + xi - 1;
                            }
                            else if ((y + yi) > height) {
                                oldVal = ((yi - 1) << 3) + xi;
                            }
                            
                            duY[idx] = duY[oldVal];
                            duCb[idx] = duCb[oldVal];
                            duCr[idx] = duCr[oldVal];
                        }
                    }
                    
                    topLeftOffset += oneRowOffset;
                }
                
                //  The three data units are now created - apply a FDCT/quantization to them.
                [JPEG_pack FDCTPracticalFast:duY withQuant:container_lumin_quant];
                [JPEG_pack FDCTPracticalFast:duCb withQuant:container_chrom_quant];
                [JPEG_pack FDCTPracticalFast:duCr withQuant:container_chrom_quant];
                
                //  Convert the quantization to high-quality and embed the data
                [self embedData:duY withRealQuant:container_lumin_quant andFakeQuant:fake_lumin_quant];
                [self embedData:duCb withRealQuant:container_chrom_quant andFakeQuant:fake_chrom_quant];
                [self embedData:duCr withRealQuant:container_chrom_quant andFakeQuant:fake_chrom_quant];
                
                //  Convert the DC in each case to a differential
                APPLY_DIFF(duY[0], prevYDC);
                APPLY_DIFF(duCb[0], prevCbDC);
                APPLY_DIFF(duCr[0], prevCrDC);
                
                //  - if a scrambler key is defined, save off the original DCs in these DUs,
                //    which MUST occur AFTER the difference is applied to the data or
                //    the scrambled result will exceed the bounds of the coefficient and
                //    produce an invalid output file.
                if (scramblerKey) {
                    if (![self colorScrambleDCInDU:duY withError:err] ||
                        ![self colorScrambleDCInDU:duCb withError:err] ||
                        ![self colorScrambleDCInDU:duCr withError:err]) {
                        return NO;
                    }
                }
                
                //  Convert to the zig-zag encoding
                [self zigzagEncode:duY];
                [self zigzagEncode:duCb];
                [self zigzagEncode:duCr];
            }
            
            //  Send the data on to the next step
            //  - only if this is the final output or we're not scrambling
            if (fOutput || !scramblerKey) {
                if (![self processDU:duY forHuffmanDC:htDCLuma andHuffmanAC:htACLuma intoOutput:freqProcessor ? nil : fOutput withError:err]) {
                    return NO;
                }
                
                if (![self processDU:duCb forHuffmanDC:htDCChroma andHuffmanAC:htACChroma intoOutput:freqProcessor ? nil : fOutput withError:err]) {
                    return NO;
                }
                
                if (![self processDU:duCr forHuffmanDC:htDCChroma andHuffmanAC:htACChroma intoOutput:freqProcessor ? nil : fOutput withError:err]) {
                    return NO;
                }
            }
            
            //  Advance to the next triplet of DUs
            DUbegin = duCr + 64;
        }
    }
    
    //  - in the first phase, if scrambling is being performed we'll do all that and count frequencies
    //    at once to ensure that the Huffman tables reflect the scrambled output as opposed to the
    //    unscrambled content.
    if (!fOutput && scramblerKey) {
        if (![self scrambleCachedImageWithError:err]) {
            return NO;
        }
    }
    
    if (!freqProcessor && fOutput &&
        ![fOutput commitEntropyEncodedSegment]) {
        [RSI_error fillError:err withCode:RSIErrorImageOutputFailure andFailureReason:@"Failed to encode ECS."];
        return NO;
    }
    
    return YES;
}

/*
 *  Encode a single quantization table in zig-zag order into the output stream.
 */
-(BOOL) encodeOneQuantTable:(quant_table_t) qt intoOutput:(RSI_file *) fOutput
{
    quant_table_t qtZigZag;
    for (int i = 0; i < 64; i++) {
        qtZigZag[std_zigzag[i]] = qt[i];
    }
    
    if (![fOutput write:qtZigZag withLength:sizeof(quant_table_t)]) {
        return NO;
    }
    
    return YES;
}

/*
 *  Encode the high-quality (fake) quantization tables into the output.
 */
-(BOOL) encodeQuantTablesIntoOutput:(RSI_file *) fOutput withError:(NSError **) err
{
    if (![fOutput beginMarkerSegment:MARK_DQT] ||
        ![fOutput putc:JPEG_QUANT_LUMIN] ||                                     //  P | T:  (4 + 4)  quant element precision; quant table destination
        ![self encodeOneQuantTable:fake_lumin_quant intoOutput:fOutput] ||      //  Q:      (8 x 64) quantization table elements
        ![fOutput putc:JPEG_QUANT_CHROM] ||                                     //  P | T:  (4 + 4)  quant element precision; quant table destination
        ![self encodeOneQuantTable:fake_chrom_quant intoOutput:fOutput] ||      //  Q:      (8 x 64) quantization table elements
        ![fOutput commitMarkerSegment]) {
        [RSI_error fillError:err withCode:RSIErrorImageOutputFailure andFailureReason:@"Failed to encode DQT."];
        return NO;
    }
    
    return YES;
}

/*
 *  Encode the start of image (SOI) marker into the output.
 */
-(BOOL) encodeStartOfImageIntoOutput:(RSI_file *) fOutput withError:(NSError **) err
{
    //  - first the required SOI from the interchange format
    if (![fOutput writeMarker:MARK_SOI]) {
        [RSI_error fillError:err withCode:RSIErrorImageOutputFailure andFailureReason:@"Failed to encode SOI."];
        return NO;
    }
    
    //  - now the JFIF identification from ECMA/TR98
    NSData *dPrefix = [NSData dataWithBytes:JFIF_PFX length:JFIF_PFX_LEN];
    if (![fOutput beginMarkerSegment:MARK_APP0] ||
        ![fOutput write:dPrefix.bytes withLength:[dPrefix length]] ||
        ![fOutput putc:0x00] ||                                                 //  Units = 0: no units, X and Y density specify the pixel aspect ratio
        ![fOutput putw:0x01] ||                                                 //  Xdensity
        ![fOutput putw:0x01] ||                                                 //  Ydensity
        ![fOutput putc:0x00] ||                                                 //  Xthumbnail - no thumbnail
        ![fOutput putc:0x00] ||                                                 //  Ythumbnail - no thumbnail
        ![fOutput commitMarkerSegment]) {
        [RSI_error fillError:err withCode:RSIErrorImageOutputFailure andFailureReason:@"Failed to encode the JFIF APP0."];
        return NO;
    }
    
    return YES;
}

/*
 *  Encode the image into the output
 */
-(BOOL) encodeImageIntoOutput:(RSI_file *) fOutput withError:(NSError **) err
{
    //  - write all the header descriptive items.
    if (![self encodeStartOfImageIntoOutput:fOutput withError:err] ||
        ![self encodeQuantTablesIntoOutput:fOutput withError:err] ||
        ![self encodeHuffmanTablesIntoOutput:fOutput withError:err] ||
        ![self encodeFrameHeaderIntoOutput:fOutput withError:err] ||
        ![self encodeScanHeaderIntoOutput:fOutput withError:err]) {
        return NO;
    }
    
    //  - do the real deal encoding now that the Huffman tables are computed
    if (![self encodeScanUsingProcessor:NO intoOutput:fOutput withError:err]) {
        return NO;
    }
    
    //  - complete the image
    if (![self encodeEndOfImageIntoOutput:fOutput withError:err]) {
        return NO;
    }
    
    //  - if there is a scrambled remainder, encode that now
    return [self encodeScrambleSegmentIntoOutput:fOutput withError:err];
}

/*
 *  This method performs the actual packing of the data using
 *  baseline sequential DCT with 3 components.
 */
-(NSData *) packedJPEGandError:(NSError **) err
{
    //  - this is a two pass process.
    //  - during the first pass the DUs are formed and computed, but not output because
    //    the Huffman tables need to be generated with the frequencies
    //  - during the second pass the DUs that were generated during the first
    //    pass are reused and output
    [htDCLuma resetFrequencies];
    [htACLuma resetFrequencies];
    [htDCChroma resetFrequencies];
    [htACChroma resetFrequencies];
    if (![self encodeScanUsingProcessor:YES intoOutput:nil withError:err]) {
        return nil;
    }
    
    //  - now write the data to the target
    RSI_file *fOutput = [[RSI_file alloc] initForWrite];
    NSData *ret = nil;
    if ([self encodeImageIntoOutput:fOutput withError:err]) {
        ret = [fOutput fileData];
    }
    [fOutput release];
    
    //  - and return the target
    return ret;
}

/*
 *  Compute the maximum amount of data (in bytes) that can be stored in the given image.
 */
+(NSUInteger) maxDataForJPEGImageOfWidth:(NSUInteger) w andHeight:(NSUInteger) h
{
    NSUInteger duCX = ((w + 8) >> 3) - 1;
    NSUInteger duCY = ((h + 8) >> 3) - 1;
    
    NSUInteger totalDU = duCX * duCY * 3;
    
    //  - 9 bytes per DU can have data included and
    //    only 3 bits per byte
    return (totalDU * [JPEG_pack embeddedJPEGGroupSize] * [JPEG_pack bitsPerJPEGCoefficient]) >> 3;
}

/*
 *  The maximum number of bits stored per coefficient.
 */
+(NSUInteger) bitsPerJPEGCoefficient
{
    //  - if you change this, make sure you modify the embedData routine.
    return 2;
}

/*
 *  The number of coefficients per DU that can contain embedded data.
 */
+(NSUInteger) embeddedJPEGGroupSize
{
    //  - if you change this, make sure you modify the embedData routine.
    return 9;
}

/*
 *  The quality coefficient for JPEGs to compromise with size for our purposes.
 */
+(CGFloat) defaultJPEGQualityForMessaging
{
    return 0.35f;
}

@end


/**************************
 JPEG_unpack
 **************************/
@implementation JPEG_unpack
/*
 *  Object attributes.
 */
{
    RSI_file *input;
    RSI_file *output;
    RSI_file *hidden;
    
    NSUInteger maxUnpack;
    
    BOOL saveDUs;
    BOOL hasQuant;
    BOOL hasHuff;
    BOOL hasFrame;
    BOOL hasScan;
    BOOL hasEndOfImage;
    BOOL hasScramblerRemainder;
    
    RSI_SHA_SCRAMBLE *imageHash;
}

/*
 *  A simple check to see if the file should be JPEG.
 */
+(BOOL) isDataJPEG:(NSData *) d
{
    RSI_file *fInput = [[RSI_file alloc] initForReadWithData:d];
    BOOL ret = NO;
    
    uint16_t marker = 0;
    uint16_t num = 0;
    
    NSMutableData *md = [NSMutableData dataWithBytes:JFIF_PFX length:JFIF_PFX_LEN];
    if ([fInput getw:&marker] && marker == MARK_SOI &&
        [fInput getw:&marker] && marker == MARK_APP0 &&
        [fInput getw:&num] && (num == (JFIF_PFX_LEN + 9)) &&
        [fInput readBits:JFIF_PFX_LEN << 3 intoBuffer:md.mutableBytes ofLength:JFIF_PFX_LEN] &&
        [md isEqualToData:[NSData dataWithBytes:JFIF_PFX length:JFIF_PFX_LEN]]) {
        ret = YES;
    }
    [fInput release];
    return ret;
}

/*
 *  Returns how much data is required to identify the file as JPEG.
 */
+(NSUInteger) minimumDataLengthForTypeIdentification
{
    return 6 + JFIF_PFX_LEN;
}

/*
 *  Initialize the object.
 *  - depending on the arguments here, we'll do one of three types of operations
 *  - if a scrambler key is present, we'll descramble the image represented by the passed-in data.
 *  - if the hidden data is present, we'll repack the image with new data.
 *  - ...otherwise, we'll simply unpack the internal data.
 */
-(id) initWithData:(NSData *) d andScrambler:(RSI_scrambler *) key andNewHiddenContent:(NSData *) dHidden andMaxLength:(NSUInteger) len
{
    self = [super init];
    if (self) {
        input = [[RSI_file alloc] initForReadWithData:d];
        output = [[RSI_file alloc] initForWrite];
        
        if (dHidden) {
            hidden = [[RSI_file alloc] initForReadWithData:dHidden];
        }
        
        maxUnpack = len;
        
        saveDUs = NO;
        hasQuant = NO;
        hasHuff = NO;
        hasFrame = NO;
        hasScan = NO;
        hasEndOfImage = NO;
        hasScramblerRemainder = NO;
        
        scramblerKey = [key retain];
        
        // - descrambling and repacking require the entire list of DUs
        if (key || dHidden) {
            saveDUs = YES;
        }
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [input release];
    input = nil;
    
    [output release];
    output = nil;
    
    [hidden release];
    hidden = nil;
        
    [imageHash release];
    imageHash = nil;
    
    [super dealloc];
}

/*
 *  When descrambling an image, much of its content can be simply copied into the output stream
 *  because it is unchanged.
 */
-(BOOL) echoSegmentIntoOutput:(uint16_t) marker withContent:(BOOL) hasContent
{
    if (!saveDUs) {
        return YES;
    }
    
    if (hasContent) {
        if (![output beginMarkerSegment:marker]) {
            return NO;
        }
        
        uint16_t len = 0;
        if (![input peekw:&len]) {
            return  NO;
        }
        
        NSMutableData *d = [[NSMutableData alloc] initWithCapacity:0xFFFF];
        BOOL ret = [input peekBits:((NSUInteger) len) << 3 intoBuffer:d.mutableBytes ofLength:len];
        if (ret) {
            ret = [output write:((unsigned char *)d.bytes)+2 withLength:len-2];
        }
        [d release];
        if (!ret) {
            return NO;
        }
        
        return [output commitMarkerSegment];
    }
    else {
        return [output writeMarker:marker];
    }
}

/*
 *  Take one data unit and strip the embedded bits from it.
 *  - note that this DU has only just been entropy decoded and
 *    is still in zig-zag order.
 */
-(BOOL) decodeEmbeddedData:(du_t) DU
{
    //  - this is only used when unpacking
    //    (not descrambling or repacking)
    if (scramblerKey || hidden) {
        return YES;
    }
    
    //  Before zig-zag, the packed data was in indices
    //     63, 62, 55, 47, 54, 61, 53, 46, 45
    //  After zig-zag, those same values have been shifted into
    //     63, 62, 61, 60, 59, 58, 56, 55, 51
    
    //  All we need to do is read those values in sequence
    for (int i = 0; i < 9; i++) {
        img_sample_t sample = DU[revAfterZigzag[i]];
        DU[revAfterZigzag[i]] = 0;                 //  to allow hashing of just the relevant image data
        sample &= 0x03;
        
        if (![output writeBits:(uint32_t) sample ofLength:2]) {
            return NO;
        }
    }
    
    //  if the object is configured for image hashing, do that now.
    //  - we have to copy the data to ensure it is not architecture-dependent
    if (imageHash) {
        unsigned char hashBuf[DU_BYTELEN];
        for (int i = 0, j = 0; i < 64; i++, j+=2) {
            hashBuf[j] = (unsigned char)(((uint32_t)DU[i] >> 8) & 0xFF);
            hashBuf[j+1] = (unsigned char)((uint32_t)DU[i] & 0xFF);
        }
        [imageHash update:hashBuf withLength:DU_BYTELEN];
    }
    
    return YES;
}

/*
 *  Implment RECEIVE (fig F.17) and EXTEND (fig F.12)
 */
-(BOOL) receiveAndExtend:(unsigned char) value withResult:(img_sample_t *) result
{
    NSUInteger toSeek = 0;
    int curbit = 15;
    uint16_t peekval = 0;
    
    //  - first RECEIVE (fig F.17)
    if (![input peekUpTo16:&peekval]) {
        return NO;
    }
    
    *result = 0;
    for (int i = 0; i < value; i++) {
        *result = ((*result) << 1) | ((peekval >> curbit) & 0x1);
        curbit--;
        toSeek++;
    }
    
    //  - then EXTEND (fig F.12)
    if (value) {
        uint16_t Vt = (1 << (value - 1));
        if (*result < Vt) {
            Vt = (((uint16_t) -1) << value) + 1;
            *result += Vt;
        }
    }
    
    //  - this will indirectly verify that we never silently
    //    dropped off the end of the stream because of the uncertain peekUpTo16
    //    call.
    return [input seekBits:(NSInteger) toSeek];
}

/*
 *  Decode a single coefficient in the stream (fig. F.16)
 */
-(BOOL) decodeOneValue:(unsigned char *) value withHT:(RSI_huffman *) ht
{
    uint16_t peekval = 0;
    uint16_t code = 0;
    
    // - if the file is truncated, we will potentially get an
    //   invalid value back from this so it is important not to
    //   indirect off of it prematurely.
    if (![input peekUpTo16:&peekval]) {
        return NO;
    }
    
    int32_t *MINCODE = [ht MINCODE];
    int32_t *MAXCODE = [ht MAXCODE];
    uint16_t *VALPTR = [ht VALPTR];
    NSData *HUFFVAL = [ht HUFFVAL];
    
    *value = 0;
    
    int i;
    for (i = 0; i < 16; i++) {
        code = (code << 1) | ((peekval >> (15 - i)) & 0x01);
        
        if (code > MAXCODE[i]) {
            continue;
        }
        
        uint16_t j = VALPTR[i];
        j = j + code - MINCODE[i];
        if (j < [HUFFVAL length]) {
            *value = ((unsigned char *) HUFFVAL.bytes)[j];
        }
        break;
    }
    
    return [input seekBits:i+1];
}

/*
 *  Read a single data unit from the input stream.
 */
-(BOOL) decodeOneDU:(du_t) DU withDCHT:(RSI_huffman *) htDC andACHT:(RSI_huffman *) htAC andDescramble:(BOOL) descramble
{
    unsigned char value = 0;
    
    //  - start with an empty output array
    memset(DU, 0, sizeof(du_t));
    
    //  - decode the DC coefficient
    if (![self decodeOneValue:&value withHT:htDC] ||
        ![self receiveAndExtend:value withResult:&(DU[0])]) {
        return NO;
    }
    
    //  - now each AC (fig F.13)
    int k = 1;
    while (k < 64) {
        if (![self decodeOneValue:&value withHT:htAC]) {
            return NO;
        }
        
        unsigned char RRRR = (value >> 4);
        unsigned char SSSS = (value & 0xF);
        if (SSSS == 0) {
            if (RRRR == 15) {
                k+= 16;
            }
            else {
                break;
            }
        }
        else {
            k += RRRR;
            if (k > 63 || ![self receiveAndExtend:SSSS withResult:&(DU[k])]) {
                return NO;
            }
            k++;
        }
    }
    
    // - if there is a scrambler key, save the DC
    if (descramble) {
        //  - first the DC itself in scrambled form
        uint32_t val = (uint32_t) ((DU[0] + ((1 << 11) - 1)));          //  convert from two's compliment first to preserve the signed precision
        val &= 0x7FF;                                                   //  only 11 bits of precision in a scrambled DC
        if (![fScrambledDC writeBits:val ofLength:11]) {
            return NO;
        }
    }
    
    // - if this is a scenario where the entire DU is saved, do that now
    //   (either descrambling or repacking)
    if (saveDUs) {
        if (!width || !height) {
            return NO;
        }
        
        if (!mdAllDUs) {
            [self allocDUCacheForWidth:width andHeight:height andZeroFill:NO];
        }
        [mdAllDUs appendBytes:DU length:DU_BYTELEN];
    }
    
    return YES;
}

/*
 *  Decode the scan header.
 */
-(BOOL) decodeScanHeader
{
    uint16_t value = 0;
    unsigned char ucVal = 0;
    
    // - assume 3 components defined in the header
    if (![input getw:&value] || value != 12) {
        return NO;
    }
    
    // - number of image components
    if (![input readBits:8 intoBuffer:&ucVal ofLength:1] || ucVal != 3) {
        return NO;
    }
    
    // - the huffman table associations for each component
    for (int i = 0; i < 3; i++) {
        unsigned char comp[2];
        if (![input readBits:2 << 3 intoBuffer:comp ofLength:2]) {
            return NO;
        }
        
        switch (i)
        {
            case 0:
                if (comp[0] != JPEG_COMP_ID_Y ||
                    comp[1] != ((JPEG_HUFF_TABLE_ID_LUMIN << 4) | JPEG_HUFF_TABLE_ID_LUMIN)) {
                    return NO;
                }
                break;
                
            case 1:
                if (comp[0] != JPEG_COMP_ID_Cb ||
                    comp[1] != ((JPEG_HUFF_TABLE_ID_CHROM << 4) | JPEG_HUFF_TABLE_ID_CHROM)) {
                    return NO;
                }
                break;
                
            case 2:
                if (comp[0] != JPEG_COMP_ID_Cr ||
                    comp[1] != ((JPEG_HUFF_TABLE_ID_CHROM << 4) | JPEG_HUFF_TABLE_ID_CHROM)) {
                    return NO;
                }
                break;
                
            default:
                //  - should not happen
                return NO;
                break;
        }
    }
    
    // - spectral selection
    if (![input readBits:8 intoBuffer:&ucVal ofLength:1] || ucVal != 0 ||
        ![input readBits:8 intoBuffer:&ucVal ofLength:1] || ucVal != 63) {
        return NO;
    }
    
    // - approximation
    if (![input readBits:8 intoBuffer:&ucVal ofLength:1] || ucVal != 0) {
        return NO;
    }
    
    return YES;
}

/*
 *  Decode the full scan
 */
-(BOOL) decodeScanWithSoftAbort:(BOOL *) aborted andDescramble:(BOOL) descramble
{
    *aborted = NO;
    
    if (![self decodeScanHeader]) {
        return NO;
    }
    
    if (![input beginEntropyEncodedSegment]) {
        return NO;
    }
    
    if (descramble) {
        [fScrambledDC release];
        fScrambledDC = [[RSI_file alloc] initForWrite];
    }
    
    //  - we can expect at least (y >> 3) * (x >> 3) DU triplets in a valid file
    du_t DU;
    for (int y = 0; y < height; y += 8) {
        for (int x = 0; x < width; x+= 8) {
            //  - decode the Luma DU
            if (![self decodeOneDU:DU withDCHT:htDCLuma andACHT:htACLuma andDescramble:descramble] ||
                ![self decodeEmbeddedData:DU]) {
                return NO;
            }
            
            //  - decode Chroma blue DU
            if (![self decodeOneDU:DU withDCHT:htDCChroma andACHT:htACChroma andDescramble:descramble] ||
                ![self decodeEmbeddedData:DU]) {
                return NO;
            }
            
            //  - decode Chroma red DU
            if (![self decodeOneDU:DU withDCHT:htDCChroma andACHT:htACChroma andDescramble:descramble] ||
                ![self decodeEmbeddedData:DU]) {
                return NO;
            }
            
            //  - check if we should stop early, but we'll only check once per DU.
            if (maxUnpack && (!scramblerKey && !hidden) && [output numBytesWritten] > maxUnpack) {
                *aborted = YES;
                return YES;
            }
        }
    }
    
    return [input commitEntropyEncodedSegment];
}

/*
 *  Decode and verify the frame header.
 */
-(BOOL) decodeFrameHeader
{
    uint16_t value = 0;
    unsigned char ucVal = 0;
    
    //  - assume 3 components defined in the header
    if (![input getw:&value] || value != 17) {
        return NO;
    }
    
    // - precision
    if (![input readBits:8 intoBuffer:&ucVal ofLength:1] || ucVal != 8) {
        return NO;
    }
    
    // - number of lines
    if (![input getw:&value] || value == 0) {
        return NO;
    }
    height = value;
    
    //  - number of columns
    if (![input getw:&value] || value == 0) {
        return NO;
    }
    width = value;
    
    //  - number of components
    if (![input readBits:8 intoBuffer:&ucVal ofLength:1] || ucVal != 3) {
        return NO;
    }
    
    //  - each component
    for (int i = 0; i < 3; i++) {
        unsigned char comp[3];
        if (![input readBits:3 << 3 intoBuffer:comp ofLength:sizeof(comp)] ||
            comp[1] != JPEG_STD_SAMPLING_FACTOR) {
            return NO;
        }
        
        switch (i)
        {
            case 0:
                if (comp[0] != JPEG_COMP_ID_Y ||
                    comp[2] != JPEG_QUANT_LUMIN) {
                    return NO;
                }
                break;
                
            case 1:
                if (comp[0] != JPEG_COMP_ID_Cb ||
                    comp[2] != JPEG_QUANT_CHROM) {
                    return NO;
                }
                break;
                
            case 2:
                if (comp[0] != JPEG_COMP_ID_Cr ||
                    comp[2] != JPEG_QUANT_CHROM) {
                    return NO;
                }
                break;
                
            default:
                //  - should not occur
                return NO;
                break;
        }
    }
    
    return YES;
}

/*
 *  Decode and verify the structure of the Huffman tables.
 */
-(BOOL) decodeHuffmanTables
{
    uint16_t value = 0;
    unsigned char ucVal = 0;
    
    //  - the length of the Huffman table definitions
    if (![input getw:&value] || value < 2) {
        return NO;
    }
    
    value -= 2;
    int numTables = 0;
    unsigned char bits[16];
    RSI_huffman **ht = nil;
    NSMutableData *mdHV = [NSMutableData dataWithLength:[RSI_huffman MAX_SIZE_HUFFVALS]];
    while (value > 0) {
        numTables++;
        if (numTables > 4) {
            return NO;
        }
        
        if (![input readBits:8 intoBuffer:&ucVal ofLength:1]) {
            return NO;
        }
        
        //  - figure out which table will be populated.
        if (ucVal == ((JPEG_HUFF_TABLE_CLASS_DC << 4) | JPEG_HUFF_TABLE_ID_LUMIN)) {
            if (htDCLuma || htACLuma || htDCChroma || htACChroma) {
                return NO;
            }
            ht = &htDCLuma;
        }
        else if (ucVal == ((JPEG_HUFF_TABLE_CLASS_AC << 4) | JPEG_HUFF_TABLE_ID_LUMIN)) {
            if (!htDCLuma || htACLuma || htDCChroma || htACChroma) {
                return NO;
            }
            ht = &htACLuma;
        }
        else if (ucVal == ((JPEG_HUFF_TABLE_CLASS_DC << 4) | JPEG_HUFF_TABLE_ID_CHROM)) {
            if (!htDCLuma || !htACLuma || htDCChroma || htACChroma) {
                return NO;
            }
            ht = &htDCChroma;
        }
        else if (ucVal == ((JPEG_HUFF_TABLE_CLASS_AC << 4) | JPEG_HUFF_TABLE_ID_CHROM)) {
            if (!htDCLuma || !htACLuma || !htDCChroma || htACChroma) {
                return NO;
            }
            ht = &htACChroma;
        }
        else {
            //  invalid table identification
            return NO;
        }
        
        //  - already populated?
        if (*ht) {
            return NO;
        }
        
        //  - read the bit lengths
        if (![input readBits:(16 << 3) intoBuffer:bits ofLength:16]) {
            return NO;
        }
        
        //  - now the huffman table values.
        NSUInteger len = 0;
        for (int i = 0; i < 16; i++) {
            len += bits[i];
        }
        if (![input readBits:(len << 3) intoBuffer:mdHV.mutableBytes ofLength:len]) {
            return NO;
        }
        
        *ht = [[RSI_huffman alloc] initWithBits:bits andHuffValues:[NSData dataWithBytes:mdHV.mutableBytes length:len]];
        if (!*ht) {
            return NO;
        }
        
        value -= (17 + len);
    }
    
    //  -we exepect exactly four tables.
    if (numTables != 4) {
        return NO;
    }
    
    return YES;
    
}

/*
 *  Decode and verify the structure of the quantization tables.
 */
-(BOOL) decodeQuantTables
{
    uint16_t value = 0;
    unsigned char ucVal = 0;
    
    //  - the length of the quant table definitions
    if (![input getw:&value] || value < 2) {
        return NO;
    }
    
    //  - read tables until there is nothing left
    value -=2;
    int numTables = 0;
    while (value > 0) {
        numTables++;
        if (numTables > 2) {
            return NO;
        }
        
        //  - the precision/destination should be correct
        if (![input readBits:8 intoBuffer:&ucVal ofLength:1] ||
            ucVal & 0xF0) {
            return NO;
        }
        
        if ((numTables == 1 && ucVal != JPEG_QUANT_LUMIN) ||
            (numTables == 2 && ucVal != JPEG_QUANT_CHROM)) {
            return NO;
        }
        
        //  - move past the table data
        if (![input seekBits:8 * 64]) {
            return NO;
        }
        
        value -= 65;
    }
    
    //  - exactly two tables are expected
    if (numTables != 2) {
        return NO;
    }
    
    return YES;
}

/*
 *  Skip the next segment in the input file.
 */
-(BOOL) skipSegment
{
    uint16_t len = 0;
    if (![input getw:&len]) {
        return NO;
    }
    
    if (len < 2 || ![input seekBits:(len-2)<<3]) {
        return NO;
    }
    return YES;
}

/*
 *  Check if the expected JPEG header is present.
 */
-(BOOL) checkForHeader
{
    uint16_t marker = 0;
    
    //  - start of image (SOI)
    if (![input getw:&marker] || marker != MARK_SOI) {
        return NO;
    }
    
    if (![self echoSegmentIntoOutput:MARK_SOI withContent:NO]) {
        return  NO;
    }
    
    //  - JFIF APP0 marker
    if (![input getw:&marker] || marker != MARK_APP0) {
        return NO;
    }
    
    if (![self echoSegmentIntoOutput:MARK_APP0 withContent:YES]) {
        return  NO;
    }
    
    uint16_t num = 0;
    if (![input getw:&num] || (num != (JFIF_PFX_LEN + 9))) {
        return NO;
    }
    
    //  - JFIF predefined prefix data
    NSMutableData *md = [NSMutableData dataWithLength:JFIF_PFX_LEN];
    if (![input readBits:JFIF_PFX_LEN << 3 intoBuffer:md.mutableBytes ofLength:JFIF_PFX_LEN] ||
        ![md isEqualToData:[NSData dataWithBytes:JFIF_PFX length:JFIF_PFX_LEN]]) {
        return NO;
    }
    
    //  - units
    unsigned char ucNum = 0;
    if (![input readBits:8 intoBuffer:&ucNum ofLength:1] || ucNum != 0) {
        return NO;
    }
    
    //  - X/Y density
    if (![input getw:&num] || num != 1 ||
        ![input getw:&num] || num != 1) {
        return NO;
    }
    
    //  - thumbnail dimensions
    if (![input getw:&num] || num != 0) {
        return NO;
    }
    
    return YES;
}

/*
 *  Scrambled image files have some number of remainder bits at the end for the
 *  DCs in the image.
 */
-(BOOL) decodeDCRemainders
{
    uint16_t len = 0;
    if (![input getw:&len] || len < 3) {
        return NO;
    }
    
    len -=2;
    
    BOOL ret = YES;
    NSMutableData *dRem = [[NSMutableData alloc] initWithLength:len];
    if ([input readBits:(NSUInteger) len<<3 intoBuffer:dRem.mutableBytes ofLength:len]) {
        if ([fScrambledDC write:dRem.bytes withLength:len]) {
            //  Because of the way the internal files are handled, you can get
            //  double padding with the scrambled data.  The first time is when it
            //  was originally written in the packing code and then it can be padded
            //  again here the second time.  If there are any extra bytes in the buffer
            //  the descrambling process will fail, so it is important that we
            //  truncate to what it is expected to be.
            NSUInteger expectedLength = ((numDUs * 12) + 7) / 8;              //  assuming 12 source bits per DU
            ret = [fScrambledDC truncateTo:expectedLength];
        }
        else {
            ret = NO;
        }
    }
    else {
        ret = NO;
    }
    [dRem release];
    
    if (ret) {
        hasScramblerRemainder = YES;
    }
    
    return ret;
}

/*
 *  Descramble the AC coefficients in the image.
 */
-(BOOL) descrambleACCoefficients
{
    //  - We need a list of random indices into all the DUs of the image
    //    as well as into every coefficient in each DU.
    NSUInteger *DUIdx   = [scramblerKey randomIndicesFrom:0 toEnd:(NSUInteger) numDUs-1 withShiftLeftBy:6];
    NSUInteger *COEFIdx = [scramblerKey randomIndicesFrom:1 toEnd:63 withShiftLeftBy:0];
    
    if (!DUIdx || !COEFIdx) {
        return NO;
    }
    
    //  - operate on groups of 63 DUs at a time
    NSUInteger origDULen = (64 * sizeof(img_sample_t)) * 63;
    NSMutableData *mdSavedDU = [NSMutableData dataWithLength:origDULen];
    img_sample_t *savedDUs = (img_sample_t *) mdSavedDU.bytes;
    du_ref_t curDUs = (img_sample_t *) [mdAllDUs mutableBytes];
    
    int curDUPos[63];
    for (NSUInteger i = 0; i < numDUs; i+=63) {
        NSUInteger firstDU = i;
        NSUInteger scramCt = 63;
        if (firstDU + scramCt > numDUs) {
            scramCt = numDUs - firstDU;
        }
        
        // - first make a copy of all the scrambled DU data because
        //   it is going to be overwritten
        for (NSUInteger j = 0; j < scramCt; j++) {
            memcpy(&(savedDUs[j<<6]), &(curDUs[DUIdx[firstDU + j]]), DU_BYTELEN);
        }
        
        // - a current position is recorded inside each DU
        memset(curDUPos, 0, sizeof(curDUPos));
        
        // - take one DU from the list at a time and we'll recover its
        //   data from all the remaining DUs
        img_sample_t *sourceDU = savedDUs;
        for (NSUInteger j = 0; j < scramCt; j++) {
            
            //  - process each coefficient in that DU
            NSUInteger targetIdx = j;
            for (NSUInteger c = 1; c < 64; c++) {
                //  - find the scrambled location of the coefficient
                do {
                    targetIdx = (targetIdx + 1) % scramCt;
                } while (targetIdx == j || curDUPos[targetIdx] > 62);
                
                //  - and retrieve it from there
                int newPos = curDUPos[targetIdx];
                curDUPos[targetIdx]++;
                
                // - assert: make sure that our indices are in a valid range at all times
                NSAssert(COEFIdx[newPos] != 0, @"Invalid modification of the DC.");
                NSAssert((targetIdx << 6) + COEFIdx[newPos] < numDUs * 64, @"Array overrun in DU buffer.");
                
                curDUs[DUIdx[firstDU + j] + c] = sourceDU[(targetIdx << 6) + COEFIdx[newPos]];
            }
        }
    }
    
    return YES;
}

/*
 *  Descramble the DC coefficients in the image.
 */
-(BOOL) descrambleDCCoefficients
{
    BOOL ret = YES;
    RSI_securememory *smRealDCs = [[RSI_securememory alloc] init];
    RSI_file *dcFile = nil;
    
    if ([scramblerKey descramble:[fScrambledDC fileData] intoBuffer:smRealDCs withError:nil]) {
        dcFile = [[RSI_file alloc] initForReadWithData:smRealDCs.rawData];
        
        img_sample_t *DC = (img_sample_t *) [mdAllDUs mutableBytes];
        for (int i = 0; i < numDUs; i++) {
            unsigned char bytes[2];
            if (![dcFile readBits:12 intoBuffer:bytes ofLength:2]) {
                ret = NO;
                break;
            }
            
            uint32_t val = ((((uint32_t) bytes[0]) << 8) | ((uint32_t) bytes[1])) >> 4;     //  only 12 bits of precision
            *DC = (img_sample_t) val - ((1 << 11) - 1);                                     //  convert back to two's compliment
            
            DC += 64;
        }
    }
    else {
        ret = NO;
    }
    
    [dcFile release];
    [smRealDCs release];
    
    
    return ret;
}


/*
 *  With all the data read, now we need to descramble it.
 */
-(BOOL) descrambleImageData
{
    //  - we work backwards here in the order in which the file was originally
    //    scrambled in order to make debugging the process more natural.
    //  - the DC coefficients came last before entropy encoding
    if (![self descrambleDCCoefficients] ||
        ![self descrambleACCoefficients]) {
        return NO;
    }
    
    return YES;
}

/*
 *  Replace the hidden data in the image.
 */
-(BOOL) repackHiddenData
{
    du_ref_t curDUs = (img_sample_t *) [mdAllDUs mutableBytes];
    for (int i = 0; i < numDUs; i++) {
        [self embedData:hidden intoDU:curDUs postZigzag:YES];
        curDUs += 64;
    }
    
    //  - if any data remains, there is an error
    if ([hidden bitsRemaining] > 0) {
        return NO;
    }
    
    return YES;
}

/*
 *  Once all the data is descrambled, rewrite it to the output
 */
-(BOOL) rewriteFileDataWithScrambleSegment:(BOOL) hasScramble
{
    //  - these tables must be regenerated to support a new data set.
    [htDCLuma resetFrequencies];
    [htACLuma resetFrequencies];
    [htDCChroma resetFrequencies];
    [htACChroma resetFrequencies];
    
    //  Two passes:
    //  1.  Compute the Huffman tables
    //  2.  Output the content with the tables
    for (int i = 0; i < 2; i++) {
        img_sample_t *DU    = (img_sample_t *) [mdAllDUs mutableBytes];
        NSUInteger numBytes = [mdAllDUs length];
        if (numBytes % (DU_BYTELEN * 3) != 0) {             //  just a sanity check
            return NO;
        }
        while (numBytes > 0) {
            if (![self processDU:DU forHuffmanDC:htDCLuma andHuffmanAC:htACLuma intoOutput:(i == 0 ? nil : output) withError:nil]) {
                return NO;
            }
            DU += 64;
            
            if (![self processDU:DU forHuffmanDC:htDCChroma andHuffmanAC:htACChroma intoOutput:(i == 0 ? nil : output) withError:nil]) {
                return NO;
            }
            DU += 64;
            
            if (![self processDU:DU forHuffmanDC:htDCChroma andHuffmanAC:htACChroma intoOutput:(i == 0 ? nil : output) withError:nil]) {
                return NO;
            }
            DU += 64;
            
            numBytes -= (DU_BYTELEN * 3);
        }
        
        if (i == 0 &&(![self encodeHuffmanTablesIntoOutput:output withError:nil] ||
                      ![self encodeFrameHeaderIntoOutput:output withError:nil] ||
                      ![self encodeScanHeaderIntoOutput:output withError:nil] ||
                      ![output beginEntropyEncodedSegment])) {
            return NO;
        }
    }
    
    if (![output commitEntropyEncodedSegment] ||
        ![self encodeEndOfImageIntoOutput:output withError:nil]) {
        return NO;
    }
    
    if (hasScramble &&
        ![self encodeScrambleSegmentIntoOutput:output withError:nil]) {
        return NO;
    }
    
    return YES;
}

/*
 *  When scrambling the data buffer, we need to begin by saving off all the DCs.
 */
-(BOOL) saveOriginalDCs
{
    img_sample_t *DC = (img_sample_t *) [mdAllDUs mutableBytes];
    for (int i = 0; i < numDUs; i++) {
        if (![self colorScrambleDCInDU:DC withError:nil]) {
            return NO;
        }
        DC += 64;
    }
    return YES;
}

/*
 *  Unpack the data.
 *  - depending on whether a scrambler key is present, this will either just grab the
 *    hidden data or scramble/descramble the image and return the result.
 *  - when descrambling, this returns an object of type RSI_securememory and when simply
 *    unpacking, this returns an object of type NSData.
 */
-(id) unpackAndScramble:(BOOL) doScramble
{
    //  - bad argument!
    if (doScramble && !scramblerKey) {
        return nil;
    }
    
    //  The model for unpacking the file is to expect absolute precision with the necessary elements
    //  of the format.
    //  - any variation from the type of JPEG that the RSI_pack produces is automatically
    //    assumed to be invalid.
    //  - the exception are non-essential elements that do not impact the output.  I have a hunch
    //    that some services may use the comments in JPEGs as a way of doing custom accounting
    //    for their own purposes.  As long as the image data is unchanged, I can be fine with
    //    those additions.  Those additions potentially make these files harder to identify anyway.
    if (![self checkForHeader]) {
        return nil;
    }
    
    uint16_t marker = 0;
    while (![input isEOF]) {
        //  - get the next marker
        if (![input getw:&marker]) {
            return nil;
        }
        
        //  - parse the individual segments
        if (marker == MARK_SOF) {                                   //  Start of frame
            if (hasFrame || !hasQuant || !hasHuff || hasScan) {
                return nil;
            }
            
            if (![self decodeFrameHeader]) {
                return nil;
            }
            
            hasFrame = YES;
        }
        else if (marker == MARK_DQT) {                              //  Define quantization tables
            if (hasQuant || hasHuff || hasFrame) {                  
                return nil;
            }
            
            if (![self echoSegmentIntoOutput:MARK_DQT withContent:YES]) {
                return  nil;
            }
            
            if (![self decodeQuantTables]) {
                return nil;
            }
            
            hasQuant = YES;
        }
        else if (marker == MARK_DHT) {                              //  Define huffman tables
            if (hasHuff || !hasQuant || hasFrame) {
                return nil;
            }
            
            if (![self decodeHuffmanTables]) {
                return nil;
            }
            
            hasHuff = YES;
        }
        else if (marker == MARK_SOS) {                              //  Start of scan
            if (hasScan) {
                return nil;
            }
            
            //  - for the sake of efficiency, some times we want to only grab
            //    a small subset of the content of the image.  If that is enabled
            //    and we are good to this point, we aren't going to worry about the
            //    quality of the image afterwards.
            BOOL softAbort = NO;
            if (![self decodeScanWithSoftAbort:&softAbort andDescramble:scramblerKey != nil && !doScramble]) {
                return nil;
            }
            
            //  - if there is a maximum length of hidden data to pull from the
            //    image, ensure that is returned immediately without bothering with
            //    any more content.
            if (softAbort) {
                NSData *d = [output fileData];
                return [NSData dataWithBytes:d.bytes length:maxUnpack];
            }
            
            hasScan = YES;
        }
        else if (marker == MARK_EOI) {                              //  End of image
            hasEndOfImage = YES;
        }
        else if (marker == MARK_APP_SCRAMBLE) {                     //  Scrambler segment
            //  - if a scrambler segment is present, but we don't have a key
            //    then the caller didn't set this up correctly
            if (!hasQuant || !hasHuff || !hasFrame || !hasScan || !hasEndOfImage || !scramblerKey) {
                return nil;
            }
            
            if (![self decodeDCRemainders]) {
                return nil;
            }
        }
        else {
            //  Only markers that are benign for the image output
            //  may be included.  Unsupported image layout data is
            //  immediately flagged as unsupported.
            //  - the only benign components are comments and app extensions
            if (marker == MARK_COM ||
                (marker >= 0xFFE0 && marker <= 0xFFEF)) {
                if (![self skipSegment]) {
                    return nil;
                }
            }
            else {
                //  - unsupported marker.
                return nil;
            }
        }
    }


    //  - After reading the file, it may be necessary to do
    //    extra work before returning the result.  Possibilities are:
    //    1.  descramble it.
    //    2.  scramble it.
    //    3.  pack with data
    if (scramblerKey) {
        if (doScramble) {
            // - build the scrambler remainder and
            //   the scrambled output
            if ([self saveOriginalDCs] &&
                [self scrambleCachedImageWithError:nil]) {
                hasScramblerRemainder = YES;
            }
            else {
                return nil;
            }
        }
        else {
            if (![self descrambleImageData]) {
                return nil;
            }
        }
        
        //  - write out the file, however it looks now
        if (!hasScramblerRemainder ||
            ![self rewriteFileDataWithScrambleSegment:doScramble]) {
            return nil;
        }        
    }
    else if (hidden) {
        if (![self repackHiddenData] ||
            ![self rewriteFileDataWithScrambleSegment:NO]) {
            return nil;
        }
    }
    
    //  - Only if the file has everything we expect in it will we
    //    return data.  These are essential components that were
    //    created by RSI_pack.
    if (hasQuant && hasHuff && hasFrame && hasScan && hasEndOfImage) {
        //  - when descrambling, return a secure memory object.
        if (scramblerKey && !doScramble) {
            RSI_securememory *smRet = [RSI_securememory dataWithData:[output fileData]];
            [output zeroFileData];          //  and leave nothing behind in the insecure space
            return smRet;
        }
        else {
            //  - the plain old output is fine for unpacking, repacking and scrambling.
            return [output fileData];
        }
    }
    return nil;
}

/*
 *  Configure the object to compute a secure hash.
 */
-(void) captureImageHash
{
    if (!imageHash) {
        imageHash = [[RSI_SHA_SCRAMBLE alloc] init];
    }
}

/*
 *  Return the secure computed hash.
 */
-(RSI_securememory *) hash
{
    if (imageHash) {
        return [imageHash hash];
    }
    else {
        return nil;
    }
}

@end
