//
//  RSI_jpeg_base.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/21/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "RSI_jpeg_base.h"

//  - constants used by this implementation.
static const uint16_t      EOB                      = 0;
static const uint16_t      Zx16                     = 0xF0;

//  - constants from Annex B - ISO/IEC 10918-1 : 1 1993(E)
const uint16_t MARK_SOI  = 0xFFD8;
const uint16_t MARK_APP0 = 0xFFE0;
const uint16_t MARK_DQT  = 0xFFDB;
const uint16_t MARK_SOF  = 0xFFC0;
const uint16_t MARK_DHT  = 0xFFC4;
const uint16_t MARK_SOS  = 0xFFDA;
const uint16_t MARK_EOI  = 0xFFD9;
const uint16_t MARK_COM  = 0xFFFE;
const uint16_t MARK_APPN = 0xFFEF;
const uint16_t MARK_APP_SCRAMBLE = MARK_APPN;

const unsigned char JPEG_HUFF_TABLE_CLASS_DC = 0x00;
const unsigned char JPEG_HUFF_TABLE_CLASS_AC = 0x01;
const unsigned char JPEG_HUFF_TABLE_ID_LUMIN = 0x00;
const unsigned char JPEG_HUFF_TABLE_ID_CHROM = 0x01;

const unsigned char JPEG_COMP_ID_Y           = 0x01;
const unsigned char JPEG_COMP_ID_Cb          = 0x02;
const unsigned char JPEG_COMP_ID_Cr          = 0x03;

const unsigned char JPEG_QUANT_LUMIN         = 0x00;
const unsigned char JPEG_QUANT_CHROM         = 0x01;
const unsigned char JPEG_STD_SAMPLING_FACTOR = 0x11;

static unsigned char jfif_pfx[] = {0x4A, 0x46, 0x49, 0x46, 0x00,             //  Identifier  "JFIF"
    0x01, 0x02};
const unsigned char *JFIF_PFX = jfif_pfx;
const NSUInteger JFIF_PFX_LEN = 7;


//  - static variables
//  In order to pack data, we use a very standard compression factor that
//  guarantees most of the high frequencies have been removed
static huff_entry_t xhuff_table[0xFFFF + 1];
static const int revzigzag[9] = {63, 62, 55, 47, 54, 61, 53, 46, 45};
const int revAfterZigzag[9]   = {63, 62, 61, 60, 59, 58, 56, 55, 51};

/************************
 JPEG_base
 ************************/
@implementation JPEG_base
/*
 *  Class-wide initialization
 */
+(void) initialize
{
    //  All entropy encoding converts individual samples to a combination of category and differential
    //  - the category encoding is defined in F.1.2.1.2
    //  The XHUF table is defined in F.1.2.1.3 and is constant for all operations.
    uint16_t curCat = 0;
    for (int i = 0; i < 32768; i++) {
        if (i != (((1 << curCat) - 1) & i)) {
            curCat++;
        }
        
        xhuff_table[i].size = curCat;
        xhuff_table[i].code = i & ((1 << curCat) - 1);
        if (i == 0) {
            continue;
        }
        
        //  - the negative numbers are in their usual place
        //    in twos-compliment notation with the high-order
        //    bit set.
        xhuff_table[(uint16_t) -i].size = curCat;
        xhuff_table[(uint16_t) -i].code = (-i - 1) & ((1 << curCat) - 1);
    }
}

/*
 *  Initialization
 */
-(id) init
{
    self = [super init];
    if (self) {
        width = height = 0;
        
        numDUs = 0;
        mdAllDUs = nil;
        
        htDCLuma = nil;
        htACLuma = nil;
        htDCChroma = nil;
        htACChroma = nil;
        
        scramblerKey = nil;
        scrambledBitCount = 0;
        fOriginalDC = nil;
        fScrambledDC = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [htDCLuma release];
    htDCLuma = nil;
    
    [htACLuma release];
    htACLuma = nil;
    
    [htDCChroma release];
    htDCChroma = nil;
    
    [htACChroma release];
    htACChroma = nil;    
    
    //  - erase all the DUs when they exist because
    //    they represent sensitive data
    if (mdAllDUs) {
        memset(mdAllDUs.mutableBytes, 0, [mdAllDUs length]);
    }
    [mdAllDUs release];
    mdAllDUs = nil;
    
    [scramblerKey release];
    scramblerKey = nil;
    
    [fOriginalDC release];
    fOriginalDC = nil;
    
    [fScrambledDC release];
    fScrambledDC = nil;
    
    [super dealloc];
}

/*
 *  The DU cache is an in-memory buffer used by both packing and unpacking.
 */
-(void) allocDUCacheForWidth:(uint16_t) w andHeight:(uint16_t) h andZeroFill:(BOOL) zeroFill
{
    numDUs              = ((w + 7) >> 3) * ((h + 7) >> 3) * 3;
    NSUInteger numBytes = numDUs * sizeof(img_sample_t) * 64;
    [mdAllDUs release];
    mdAllDUs = [[NSMutableData alloc] initWithCapacity:numBytes];
    if (zeroFill) {
        [mdAllDUs setLength:numBytes];
    }
}

/*
 *  Entropy-encode the fully completed and packed data
 *  - when no output file is passed, it is assumed that this routine should
 *    perform general-purpose frequency counting for Huffman table generation.
 */
-(BOOL) processDU:(du_ref_t) DU forHuffmanDC:(RSI_huffman *) htDC andHuffmanAC:(RSI_huffman *) htAC intoOutput:(RSI_file *) fOutput withError:(NSError **) err
{
    BOOL ret = YES;
    const huff_entry_t *HDC = NULL;
    const huff_entry_t *HAC = NULL;
    
    //  - use the appropriate tables for entropy encoding
    if (fOutput) {
        HDC = htDC.table;
        HAC = htAC.table;
        if (!HDC || !HAC) {
            return NO;
        }
    }
    
    //  - start by encoding the DC
    img_sample_t DIFF_DC = DU[0];
    
    //  - the DC is encoded mainly as a category found in the XHUFF table with additional
    //    differential bits when necessary
    huff_entry_t *CUR_XHUFF = &(xhuff_table[(uint16_t) DIFF_DC]);
    NSUInteger category = CUR_XHUFF->size;  //  see section F.1.2.1.2
    if (category > 11) {                    //  table F.1 defines only 2 categories
        [RSI_error fillError:err withCode:RSIErrorAborted andFailureReason:[NSString stringWithFormat:@"Invalid DC coefficient detected: %d", DIFF_DC]];
        return NO;
    }
    
    if (fOutput) {
        ret = [fOutput writeBits:HDC[category].code ofLength:HDC[category].size];
        if (ret && DIFF_DC != 0) {
            ret = [fOutput writeBits:CUR_XHUFF->code ofLength:CUR_XHUFF->size];
        }
    }
    else {
        [htDC countFrequency:category];
    }
    
    if (!ret) {
        [RSI_error fillError:err withCode:RSIErrorImageOutputFailure andFailureReason:@"Failed to encode DU-DC."];
        return NO;
    }
    
    //  - now each AC
    //  ...but first identify the last non-zero entry
    int lastNZ = -1;
    for (lastNZ = 63; lastNZ > 0; lastNZ--) {
        if (DU[lastNZ]) {
            break;
        }
    }
    
    //  ...the output process is slightly complicated by
    //     the fact that sequences of zeroes must be encoded
    //     in a special way.
    int zcount = 0;
    for (int i = 1;ret == YES && i < (lastNZ + 1); i++) {
        img_sample_t val = DU[i];
        if (val != 0) {
            CUR_XHUFF = &(xhuff_table[(uint16_t) val]);
            category = CUR_XHUFF->size;             //  see section F.1.2.1.2
            if (category > 10) {                    //  table F.2 defines only 10 categories
                NSLog(@"RSI: invalid AC coefficient detected: %d", val);
                return NO;
            }
            int RRRRSSSS = (category & 0x0F);
            RRRRSSSS |= (zcount << 4);
            zcount = 0;
            
            if (fOutput) {
                ret = [fOutput writeBits:HAC[RRRRSSSS].code ofLength:HAC[RRRRSSSS].size];
                if (ret) {
                    ret = [fOutput writeBits:CUR_XHUFF->code ofLength:CUR_XHUFF->size];
                }
            }
            else {
                [htAC countFrequency:RRRRSSSS];
            }
        }
        else {
            //  - sequence of 16 zeroes in a row has a custom code.
            zcount++;
            if (zcount == 16) {
                if (fOutput) {
                    ret = [fOutput writeBits:HAC[Zx16].code ofLength:HAC[Zx16].size];
                }
                else {
                    [htAC countFrequency:Zx16];
                }
                zcount = 0;
            }
        }
    }
    
    //  - encode an end of block when only zeroes remain.
    if (ret && lastNZ < 63) {
        if (fOutput) {
            ret = [fOutput writeBits:HAC[EOB].code ofLength:HAC[EOB].size];
        }
        else {
            [htAC countFrequency:EOB];
        }
    }
    
    if (!ret) {
        [RSI_error fillError:err withCode:RSIErrorImageOutputFailure andFailureReason:@"Failed to encode DU-AC."];
        return NO;
    }
    
    return YES;
}

/*
 *  Scramble the output colors in the image if requested.
 *  - the maximum bit width for DCs is defined in table F.1 of the
 *    spec, which is 11 bits of precision and one for sign or 12 bits.
 */
-(BOOL) colorScrambleDCInDU:(du_ref_t) DU withError:(NSError **) err
{
    //  This relies on the fact that the DC coefficients after the FDCT is applied
    //  represent the lowest frequency range of the color and contribute the most to the
    //  distribution in the DU.  By changing them we effectively change the color of
    //  the entire 8x8 block.  If the scrambler key is sufficiently random, the
    //  result to the entire image will be random as well.
    if (fOriginalDC && fScrambledDC) {
        // build a DC from the data.
        // - which we truncate to 11 bits instead of 12 to avoid ever producing the invalid
        //   value of +-2048 (which can happen because this is effectively randomized data).
        //   The remaining bits after all DUs are processed will be stored in a separate segment.
        // - see notes from Dec 15, 2012 for reference on the rationale
        // - but don't grab any padding at the end!
        unsigned char bytes[2] = {0, 0};
        if (scrambledBitCount > 0) {
            if (![fScrambledDC readBits:11 intoBuffer:bytes ofLength:2]) {
                [RSI_error fillError:err withCode:RSIErrorImageScramblingFailed andFailureReason:@"Failed to read the scrambled bits."];
                return NO;
            }
            
            uint32_t scrambledDC = (((uint32_t) bytes[0] << 8) | (uint32_t) bytes[1]) >> 5;  //  the value is unsigned when stored
            DU[0] = ((img_sample_t) scrambledDC) - ((1 << 11) - 1);                          //  convert back to its two's compliment form
            scrambledBitCount -= 11;
        }
    }
    else {
        //  - save off up 12 bits from the DC, which is the maximum
        //    that the spec permits for its precision, so that we
        //    can scramble all the DCs together.
        img_sample_t DC = DU[0];
        if (!fOriginalDC) {
            fOriginalDC = [[RSI_file alloc] initForWrite];
        }
        
        uint32_t val = (uint32_t)(DC + ((1 << 11) - 1));            //  convert from two's compliment first to preserve the signed precision
        val &= 0xFFF;                                               //  only 12 bits of precision
        if (![fOriginalDC writeBits:val ofLength:12]) {
            [RSI_error fillError:err withCode:RSIErrorImageScramblingFailed andFailureReason:@"Failed to write the scrambled bits."];
            return NO;
        }
        
        scrambledBitCount += 12;
    }
    
    return YES;
}

/*
 *  Pull data from the input stream and embed it into the standard coefficients.
 */
-(void) embedData:(RSI_file *) data intoDU:(du_ref_t) DU postZigzag:(BOOL) afterZigzag
{
    //  - we use 3 bits from the 9 bytes in the high-frequency corner (bottom right)
    //    to store the data in reverse zig-zag order to minimize the visual impact
    //    of adding new data.  The caller can choose to interleave its content
    //    on regular intervals to ensure that only the bottommost corner is used.
    for (int i = 0; i < 9; i++) {
        unsigned char val = 0;
        img_sample_t sample;
        
        //  - the coefficient will be in a different location depending on
        //    whether the zig-zag has been applied to the data.
        if (afterZigzag) {
            sample = DU[revAfterZigzag[i]];
        }
        else {
            sample = DU[revzigzag[i]];
        }
        
        sample &= (img_sample_t) 0xFFFC;                                        //  always zero-out the bits no matter what for consistency in all DUs
        if ([data readUpTo:2 bitsIntoBuffer:&val ofLength:1]) {
            val >>= 6;
            sample |= val;
        }
        
        if (afterZigzag) {
            DU[revAfterZigzag[i]] = sample;
        }
        else {
            DU[revzigzag[i]] = sample;
        }
    }
}

/*
 *  Scramble the image AC coefficients.
 *  - this algorithm is going to work in blocks of up to 63 DUs at a time
 *  - the value 63 represents the number of AC coefficients in each DU
 *  - in each block, any one DU will have its AC coefficients evenly spread across the
 *    remaining DUs using a canned set of indexes in each DU.
 */
-(BOOL) scrambleACCoefficientsWithError:(NSError **) err
{
    //  - We need a list of random indices into all the DUs of the image
    //    as well as into every coefficient in each DU.
    NSUInteger *DUIdx   = [scramblerKey randomIndicesFrom:0 toEnd:numDUs-1 withShiftLeftBy:6];
    NSUInteger *COEFIdx = [scramblerKey randomIndicesFrom:1 toEnd:63 withShiftLeftBy:0];
    
    if (!DUIdx || !COEFIdx) {
        [RSI_error fillError:err withCode:RSIErrorAborted andFailureReason:@"Failed to scramble image data(1)."];
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
        
        // - first make a copy of all the original DU data because
        //   it is going to be overwritten
        for (NSUInteger j = 0; j < scramCt; j++) {
            memcpy(&(savedDUs[j<<6]), &(curDUs[DUIdx[firstDU + j]]), DU_BYTELEN);
        }
        
        // - a current position is recorded inside each DU
        memset(curDUPos, 0, sizeof(curDUPos));
        
        // - take one DU from the list at a time and we'll spread its data
        //   throughout the remaining DUs
        img_sample_t *sourceDU = savedDUs;
        for (NSUInteger j = 0; j < scramCt; j++) {
            //  - process each coefficient in that DU
            NSUInteger targetIdx = j;
            for (int c = 1; c < 64; c++) {
                //  - grab the current coefficient
                img_sample_t ACcoef = sourceDU[c];
                
                //  - find a destination for it
                do {
                    targetIdx = (targetIdx + 1) % scramCt;
                } while (targetIdx == j || curDUPos[targetIdx] > 62);
                
                //  - and store the coefficient there
                int newPos = curDUPos[targetIdx];
                curDUPos[targetIdx]++;
                
                // - assert: make sure that our indices are in a valid range at all times
                NSAssert(COEFIdx[newPos] != 0, @"Invalid modification of the DC.");
                NSAssert(DUIdx[firstDU + targetIdx] + COEFIdx[newPos] < numDUs * 64, @"Array overrun in DU buffer.");
                
                curDUs[DUIdx[firstDU + targetIdx] + COEFIdx[newPos]] = ACcoef;
            }
            
            sourceDU += 64;
        }
    }
    
    return YES;
}

/*
 *  Scramble the contents of the cached image if necessary.
 */
-(BOOL) scrambleCachedImageWithError:(NSError **) err
{
    du_ref_t duY;                               //  luma
    du_ref_t duCb;                              //  chroma-B
    du_ref_t duCr;                              //  chroma-R
    
    if (!scramblerKey) {
        return YES;
    }
    
    if (fScrambledDC) {
        [RSI_error fillError:err withCode:RSIErrorAborted andFailureReason:@"Duplicate scrambling is not permitted."];
        return NO;
    }
    
    //  - start by scrambling the AC coefficients across the entire image.  This will
    //    distribute the low frequences, making coarse features unrecognizable in
    //    images of predominantly solid colors.
    if (![self scrambleACCoefficientsWithError:err]) {
        return NO;
    }
    
    //  - we're now going to replace the DC values we captured previously
    //    with scrambled versions of the same thing.
    NSData *dDUs = [fOriginalDC fileData];
    NSMutableData *mdDCs = [NSMutableData data];
    if (![scramblerKey scramble:dDUs intoBuffer:mdDCs withError:err]) {
        [fOriginalDC release];
        fOriginalDC = nil;
        [RSI_error fillError:err withCode:RSIErrorImageScramblingFailed andFailureReason:(err ? [*err localizedDescription] : nil)];
        return NO;
    }
    
    fScrambledDC = [[RSI_file alloc] initForReadWithData:mdDCs];
    [htDCLuma resetFrequencies];
    [htDCChroma resetFrequencies];
    
    //  - send it through the entropy encoding all at once
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
            
            //  - first scrample the DCs.
            if (scramblerKey) {
                if (![self colorScrambleDCInDU:duY withError:err] ||
                    ![self colorScrambleDCInDU:duCb withError:err] ||
                    ![self colorScrambleDCInDU:duCr withError:err]) {
                    return NO;
                }
            }
            
            //  - then count the frequencies
            if (![self processDU:duY forHuffmanDC:htDCLuma andHuffmanAC:htACLuma intoOutput:nil withError:err]) {
                return NO;
            }
            
            if (![self processDU:duCb forHuffmanDC:htDCChroma andHuffmanAC:htACChroma intoOutput:nil withError:err]) {
                return NO;
            }
            
            if (![self processDU:duCr forHuffmanDC:htDCChroma andHuffmanAC:htACChroma intoOutput:nil withError:err]) {
                return NO;
            }
            
            //  Advance to the next triplet of DUs
            DUbegin = duCr + 64;
        }
    }
    
    return YES;
}

/*
 *  Encode a single Huffman table in a pending DHT marker segment.
 */
-(BOOL) encodeOneHuffmanTable:(RSI_huffman *) HT asClass:(unsigned char) tclass intoOutput:(RSI_file *) fOutput withError:(NSError **) err
{
    NSData *HUFFVAL = [HT HUFFVAL];
    const unsigned char *BITS = [HT BITS];
    if (!HUFFVAL || !BITS ||
        ![fOutput putc:tclass] ||                                       //  Tc/Th:    (8)     table class/huffman desintation
        ![fOutput write:BITS withLength:16] ||                          //  L[i]      (8x16)  BITS
        ![fOutput write:HUFFVAL.bytes withLength:HUFFVAL.length]) {     //  V[i,j]    (8xixj) HUFFVAL
        [RSI_error fillError:err withCode:RSIErrorImageOutputFailure andFailureReason:@"Failed to encode DHT-1HT."];
        return NO;
    }
    return YES;
}

/*
 *  Encode the four Hufman tables into the output.
 */
-(BOOL) encodeHuffmanTablesIntoOutput:(RSI_file *) fOutput withError:(NSError **) err
{
    //  There are tables for each of DC/AC in luminance and chrominance data units.
    if (![fOutput beginMarkerSegment:MARK_DHT]) {
        [RSI_error fillError:err withCode:RSIErrorImageOutputFailure andFailureReason:@"Failed to encode DHT."];
        return NO;
    }
    
    if (![self encodeOneHuffmanTable:htDCLuma asClass:(JPEG_HUFF_TABLE_CLASS_DC << 4) | JPEG_HUFF_TABLE_ID_LUMIN intoOutput:fOutput withError:err] ||
        ![self encodeOneHuffmanTable:htACLuma asClass:(JPEG_HUFF_TABLE_CLASS_AC << 4) | JPEG_HUFF_TABLE_ID_LUMIN intoOutput:fOutput withError:err] ||
        ![self encodeOneHuffmanTable:htDCChroma asClass:(JPEG_HUFF_TABLE_CLASS_DC << 4) | JPEG_HUFF_TABLE_ID_CHROM intoOutput:fOutput withError:err] ||
        ![self encodeOneHuffmanTable:htACChroma asClass:(JPEG_HUFF_TABLE_CLASS_AC << 4) | JPEG_HUFF_TABLE_ID_CHROM intoOutput:fOutput withError:err]) {
        return NO;
    }
    
    if (![fOutput commitMarkerSegment]) {
        [RSI_error fillError:err withCode:RSIErrorImageOutputFailure andFailureReason:@"Failed to encode DHT."];
        return NO;
    }
    
    return YES;
}

/*
 *  Encode the frame header (SOF) marker segment into the output.
 */
-(BOOL) encodeFrameHeaderIntoOutput:(RSI_file *) fOutput withError:(NSError **) err
{
    if (![fOutput beginMarkerSegment:MARK_SOF] ||
        ![fOutput putc:0x08] ||                                 //  P:     (8)  sample precision
        ![fOutput putw:height] ||                               //  Y:     (16) number of lines
        ![fOutput putw:width] ||                                //  X:     (16) number of samples per line
        ![fOutput putc:0x03] ||                                 //  Nf:    (8)  number of image components in frame
        ![fOutput putc:JPEG_COMP_ID_Y] ||                       //  C1:    (8)  component id for first component type (Y)
        ![fOutput putc:JPEG_STD_SAMPLING_FACTOR] ||             //  H1/V1: (4+4) horiz/vert sampling factors for the component
        ![fOutput putc:JPEG_QUANT_LUMIN & 0x0F] ||              //  TQ1:   (8)  quantization table selector
        ![fOutput putc:JPEG_COMP_ID_Cb] ||                      //  C2:    (8)  component id for first component type (Cb)
        ![fOutput putc:JPEG_STD_SAMPLING_FACTOR] ||             //  H2/V2d: (4+4) horiz/vert sampling factors for the component
        ![fOutput putc:JPEG_QUANT_CHROM & 0x0F] ||              //  TQ2:   (8)  quantization table selector
        ![fOutput putc:JPEG_COMP_ID_Cr] ||                      //  C3:    (8)  component id for first component type (Cr)
        ![fOutput putc:JPEG_STD_SAMPLING_FACTOR] ||             //  H3/V3d: (4+4) horiz/vert sampling factors for the component
        ![fOutput putc:JPEG_QUANT_CHROM & 0x0F] ||              //  TQ3:   (8)  quantization table selector
        ![fOutput commitMarkerSegment]) {
        [RSI_error fillError:err withCode:RSIErrorImageOutputFailure andFailureReason:@"Failed to encode SOF."];
        return NO;
    }
    
    return YES;
}

/*
 *  Encode the scan header (SOS) marker segment into the output.
 */
-(BOOL) encodeScanHeaderIntoOutput:(RSI_file *) fOutput withError:(NSError **) err
{
    if (![fOutput beginMarkerSegment:MARK_SOS] ||
        ![fOutput putc:0x03] ||                                                                                 //  Ns:    (8)    number of components in scan
        ![fOutput putc:JPEG_COMP_ID_Y] ||                                                                       //  Cs1:   (8)    scan component selector
        ![fOutput putc:(JPEG_HUFF_TABLE_ID_LUMIN << 4) | JPEG_HUFF_TABLE_ID_LUMIN] ||                           //  Td/Ta1 (4+4) DC/AC entropy coding selector
        ![fOutput putc:JPEG_COMP_ID_Cb] ||                                                                      //  Cs2:   (8)    scan component selector
        ![fOutput putc:(JPEG_HUFF_TABLE_ID_CHROM << 4) | JPEG_HUFF_TABLE_ID_CHROM] ||                           //  Td/Ta2 (4+4) DC/AC entropy coding selector
        ![fOutput putc:JPEG_COMP_ID_Cr] ||                                                                      //  Cs3:   (8)    scan component selector
        ![fOutput putc:(JPEG_HUFF_TABLE_ID_CHROM << 4) | JPEG_HUFF_TABLE_ID_CHROM] ||                           //  Td/Ta3 (4+4) DC/AC entropy coding selector
        ![fOutput putc:0x00] ||                                                                                 //  Ss: start of spectral prediction
        ![fOutput putc:63] ||                                                                                   //  Se: end of spectral prediction
        ![fOutput putc:0x00] ||                                                                                 //  Ah/Al: Successive approximation bits
        ![fOutput commitMarkerSegment]) {
        [RSI_error fillError:err withCode:RSIErrorImageOutputFailure andFailureReason:@"Failed to encode SOS."];
        return NO;
    }
    return YES;
}

/*
 *  Encode the end of image (EOI) marker into the output.
 */
-(BOOL) encodeEndOfImageIntoOutput:(RSI_file *) fOutput withError:(NSError **) err
{
    if (![fOutput writeMarker:MARK_EOI]) {
        [RSI_error fillError:err withCode:RSIErrorImageOutputFailure andFailureReason:@"Failed to encode EOI."];
        return NO;
    }
    return YES;
}

/*
 *  When creating a scrambled image, we can only use 11 of 12 of the source DC bits from the
 *  scrambled stream because it is possible to produce invalid values with the full 12.  Since
 *  the exact bits are required, we truncate to 11 to avoid any complications.  The left over
 *  bits must be saved for decoding later, which we store in a special application segment at
 *  the end.
 */
-(BOOL) encodeScrambleSegmentIntoOutput:(RSI_file *) fOutput withError:(NSError **) err
{
    if (scrambledBitCount < 1 || !fScrambledDC) {
        return YES;
    }
    
    if (![fOutput beginMarkerSegment:MARK_APP_SCRAMBLE]) {
        [RSI_error fillError:err withCode:RSIErrorImageOutputFailure andFailureReason:@"Failed to encode scrambler segment(1)."];
        return NO;
    }
    
    //  - make sure that when you read from the scrambled array that we use the padded bit length of the
    //    content as opposed to what it was before it was scrambled or it is possible to
    //    accidentally truncate necessary data that will be important for accurate descrambling.
    NSUInteger numRemainingBits = [fScrambledDC bitsRemaining];
    NSMutableData *mdRemainder = [NSMutableData dataWithLength:(numRemainingBits + 7) >> 3];
    if (![fScrambledDC readBits:numRemainingBits intoBuffer:(unsigned char *) mdRemainder.mutableBytes ofLength:[mdRemainder length]]) {
        [RSI_error fillError:err withCode:RSIErrorImageOutputFailure andFailureReason:@"Failed to encode scrambler segment(2)."];
        return NO;
    }
    
    if (![fOutput write:(const unsigned char *) mdRemainder.bytes withLength:[mdRemainder length]]) {
        [RSI_error fillError:err withCode:RSIErrorImageOutputFailure andFailureReason:@"Failed to encode scrambler segment(3)."];
        return NO;
    }
    
    if (![fOutput commitMarkerSegment]) {
        [RSI_error fillError:err withCode:RSIErrorImageOutputFailure andFailureReason:@"Failed to encode scrambler segment(4)."];
        return NO;
    }
    
    return YES;
}

@end
