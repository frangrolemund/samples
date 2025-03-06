//
//  RSI_png.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/8/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "RSI_png.h" 
#import "RSI_file.h"
#import "RSI_common.h"
#import "RSI_error.h"

//  DESIGN NOTES:
//  - The steganography in this implentation uses anywhere from 7-9 bits per pixel depending on the input data density.  The idea is
//    to have a dense enough packing that we don't have to read a ton of the file to partially identify it, but permit a gradual
//    ramp up in the packing so that there isn't visible banding in the output image.
//  - The first pixel is reserved for identifying the density.
//  - Subsequent pixels each have the content packed according to the density.
//  - I've noticed that when Twitter shows a preview of an image, it has no background, so transparency-based packing is obvious.  I'm really
//    avoiding transparency until a last resort to give this the best chance at looking great on Twitter.
//  - The high bit in the 4-bit density identification in the first pixel is always set in this first release.
//  - The best packing efficiency always comes from packing as much as possible into the front of the image, rather than spreading it throughout, which
//    is why I started with a density of 7 bits.  This is an attempt to find a compromise between image quality and size.   In that case, which satisfies
//    pretty much everything for V1 of ChatSeal, the alpha isn't so high as to make it obvious and we still have some room to grow if need-be.

//  - common symbols
static const uint32_t MAX_IMAGE_SIDE                 = 1024;
static const int SIG_LEN                             = 8;
static const unsigned char PNG_SIG[8]                = {0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a};
static const uint32_t IHDR                           = 0x49484452;
static const uint32_t IDAT                           = 0x49444154;
static const uint32_t IEND                           = 0x49454E44;
static const uint32_t IPLT                           = 0x504C5445;
static const int STREAM_OUT_LEN                      = (128 * 1024);
static const unsigned char FILTER_NONE               = 0;
static const unsigned char FILTER_SUB                = 1;
static const unsigned char FILTER_UP                 = 2;
static const unsigned char FILTER_AVE                = 3;
static const unsigned char FILTER_PAETH              = 4;
static const unsigned char MASK_ALLBUT_4             = 0xF0;
static const unsigned char MASK_ALLBUT_2             = 0xFC;
static const int           ALPHA_COMP                = 3;
static const unsigned char COLOR_TYPE_RGBA           = 6;
static const unsigned char COLOR_TYPE_RGB            = 2;
static const NSUInteger    PNG_PACK_BIT_DENSITY      = 6;

//  MAJOR-DESIGN-NOTE:
//  - I learned the _hard way_ that sites will do all kinds of photo manipulation after you upload.  First was learning that nearly all JPEGs are
//    re-saved when they are used on the web.  Second was when Twitter stripped the alpha from my images.   Because of that, I'm going to use
//    only straight RGB output, although I'll read RGBA input if it is provided.
static const int           PNG_BYTES_PER_PIXEL       = 3;

// - these errors are intended to be a very limited and verifyable subset from the
//   larger list to make it more efficient to identify unsupported or invalid images as soon
//   as possible during the download process.  Only with very clear error codes can we hope
//   to coordinate well with this particular module.
static const RSIErrorCode  RSI_PNG_ERR_FATAL_INVALID = RSIErrorInvalidSecureImage;              // - if we can definiteively say we did not create this image, it is invalid.
static const RSIErrorCode  RSI_PNG_ERR_READ_FAIL     = RSIErrorFileReadFailed;                  // - any unknown failure to process input is a read failure.
static const RSIErrorCode  RSI_PNG_ERR_WRITE_FAIL    = RSIErrorImageOutputFailure;              // - all output errors are write failures.
static const RSIErrorCode  RSI_PNG_ERR_INVAL_ARG     = RSIErrorInvalidArgument;

//  - pass indices
static const int Adam7[8][8] = {{1,6,4,6,2,6,4,6},
                                {7,7,7,7,7,7,7,7},
                                {5,6,5,6,5,6,5,6},
                                {7,7,7,7,7,7,7,7},
                                {3,6,4,6,3,6,4,6},
                                {7,7,7,7,7,7,7,7},
                                {5,6,5,6,5,6,5,6},
                                {7,7,7,7,7,7,7,7}};

static const int AdamPassFirstRow[8] = {0, 0, 4, 0, 2, 0, 1, 255};                  //  the first row to use for processing in a given pass (one extra value at the end to simplify the loop)
static const int AdamPassNextRow[7][8] = {{ 0, -1, -1, -1, -1, -1, -1, -1},         //  each index reflects the next minor row in the Adam7 array
                                          { 0, -1, -1, -1, -1, -1, -1, -1},
                                          {-1, -1, -1, -1,  4, -1, -1, -1},
                                          { 4, -1, -1, -1,  0, -1, -1, -1},
                                          {-1, -1,  6, -1, -1, -1,  2, -1},
                                          { 2, -1,  4, -1,  6, -1,  0, -1},
                                          {-1,  3, -1,  5, -1,  7, -1,  1}};

//  - Utility functions
static voidpf PNG_zalloc(voidpf opaque, uInt items, uInt size)
{
    return calloc(items, size);
}

static void PNG_zfree(voidpf opaque, voidpf address) {
    return free(address);
}

static inline unsigned char PNG_average(unsigned char left, unsigned char above)
{
    int tmp = (int) left + (int) above;
    return (unsigned char) (tmp >> 1);
}

static inline int PNG_paethpredictor(unsigned char left, unsigned char above, unsigned char uleft)
{
    int p = (int) left + (int) above - (int) uleft;
    int pa = abs(p - (int) left);
    int pb = abs(p - (int) above);
    int pc = abs(p - (int) uleft);
    
    if (pa <= pb && pa <= pc) {
        return left;
    }
    else if (pb <= pc) {
        return above;
    }
    else {
        return uleft;
    }
}

//  - forward declarations
@interface PNG_unpack (internal)
-(BOOL) readHeaderWithError:(NSError **) err;
-(BOOL) prepForChunkOfLength:(uint32_t *) clen andType:(uint32_t *) ctype andCRCBegin:(const unsigned char **) crcBegin withError:(NSError **) err;
-(BOOL) processChunkCRCFromBegin:(const unsigned char *) crcBegin withLength:(uint32_t) clen andError:(NSError **) err;
-(BOOL) peekQuad:(uint32_t *) val atLocation:(const unsigned char *) ptr;
-(BOOL) readQuad:(uint32_t *) val;
-(BOOL) processIDATOfLength:(uint32_t) clen withError:(NSError **) err;
-(BOOL) skipChunkOfLength:(uint32_t) clen withError:(NSError **) err;
-(BOOL) consumeScanlinesWithError:(NSError **) err;
-(BOOL) tryToReadImageWithError:(NSError **) err;
@end


/*************************
 PNG_unpack
 *************************/
@implementation PNG_unpack
/*
 *  Object attributes.
 */
{
    NSData *dImage;
    const unsigned char *curByte;
    const unsigned char *lastByte;
    
    NSUInteger maxUnpack;
    
    BOOL isInterlaced;
    uint32_t width;
    uint32_t height;
    
    BOOL streamInit;
    z_stream inStream;
    NSMutableData *mdDecompressBuffer;
    unsigned char *nextDecomp;
    unsigned char *lastDecomp;
    
    RSI_png_scanline *scanline;
    
    NSMutableData *mdImageBuffer;
    unsigned char *imgBuffer;
    RSI_file      *unpackedData;
    BOOL          readReserved;
    BOOL          hasAlpha;
    
    int pass;
    int rowMajor;                   //  multiples of 8 (must be signed to match up with the Adam passes)
    int rowMinor;                   //  from 0 - 7     (must be signed to match up with the Adam passes)
}

/*
 *  Returns how much data is required to identify the file as PNG.
 */
+(NSUInteger) minimumDataLengthForTypeIdentification
{
    return SIG_LEN;
}

/*
 *  A simple check to see if the file should be PNG file.
 */
+(BOOL) isDataPNG:(NSData *) d
{
    if (!d || d.length < SIG_LEN) {
        return NO;
    }
    if (memcmp(d.bytes, PNG_SIG, SIG_LEN)) {
        return NO;
    }
    return YES;
}

/*
 *  Initialize the object with a potential PNG file.
 */
-(id) initWithData:(NSData *) dFile andMaxLength:(NSUInteger) len
{
    self = [super init];
    if (self) {
        dImage       = [dFile retain];
        streamInit   = NO;
        maxUnpack    = len;
        readReserved = NO;
        hasAlpha     = NO;
    }
    return self;
}

/*
 *  Free the object
 */
-(void) dealloc
{
    [dImage release];
    dImage = nil;

    curByte = NULL;
    lastByte = NULL;
    
    [scanline release];
    scanline = nil;
    
    [mdImageBuffer release];
    mdImageBuffer = nil;
    imgBuffer = NULL;
    
    [mdDecompressBuffer release];
    mdDecompressBuffer = nil;
    
    [unpackedData release];
    unpackedData = nil;
    
    if (streamInit) {
        inflateEnd(&inStream);
        streamInit = NO;
    }
    
    [super dealloc];
}


/*
 *  Decode the data in the image.
 */
-(NSData *) unpackWithError:(NSError **) err
{
    NSData *ret = nil;
    NSError *tmp = nil;
    @autoreleasepool {
        //  - when unpacking we need to allocate a file to receive
        //    the content.
        [unpackedData release];
        unpackedData = [[RSI_file alloc ] initForWrite];
        
        //  - since we set up the unpacked data buffer, it will attempt to
        //    read into that as opposed to a full image buffer
        if ([self tryToReadImageWithError:&tmp]) {
            //  - prepare to return the buffer.
            ret = [[unpackedData fileData] retain];
            if (maxUnpack && [ret length] > maxUnpack) {
                [ret autorelease];
                ret = [[NSData dataWithBytes:ret.bytes length:maxUnpack] retain];
            }
        }
        [tmp retain];
    }
    
    [tmp autorelease];
    if (err) {
        *err = tmp;
    }
    
    return [ret autorelease];
}

/*
 *  Read the image buffer data (RGBA color components)
 */
-(NSData *) readImageWithError:(NSError **) err
{
    NSData *ret = nil;
    NSError *tmp = nil;
    @autoreleasepool {
        //  - since we didn't set up a output data buffer, the assumption
        //    is that the reading method will allocate a bitmap 
        //    before returning.
        if ([self tryToReadImageWithError:&tmp]) {
            ret = [mdImageBuffer retain];
        }
        [tmp retain];
    }
    
    [tmp autorelease];
    if (err) {
        *err = tmp;
    }

    return [ret autorelease];
}

/*
 *  After a successful read of the image, this returns its size.
 */
-(CGSize) imageSize
{
    return CGSizeMake(width, height);
}

/*
 *  Repack the contents of the image file with alternate data.
 */
+(NSData *) repackData:(NSData *) imgFile withData:(NSData *) data andError:(NSError **) err
{
    NSData *ret = nil;
    
    //  - pull the image buffer
    PNG_unpack *pu = [[PNG_unpack alloc] initWithData:imgFile andMaxLength:0];
    CGSize szImg = CGSizeZero;
    NSData *dImg = [pu readImageWithError:err];
    szImg = [pu imageSize];
    [pu release];
    if (!dImg) {
        return nil;
    }

    //  - make a copy so that we can repack it.
    NSMutableData *mdImage = [NSMutableData dataWithData:dImg];
    
    //  - and pack
    PNG_pack *pp = [[PNG_pack alloc] initWithBitmap:mdImage.mutableBytes andWidth:szImg.width andHeight:szImg.height andData:data];
    ret = [pp packedPNGandError:err];
    [pp release];
   
    return ret;
}

/*
 *  Hash the colors of the image.
 */
+(RSI_securememory *) hashImageData:(NSData *) imgFile withError:(NSError **) err
{    
    //  - pull the image buffer
    PNG_unpack *pu = [[[PNG_unpack alloc] initWithData:imgFile andMaxLength:0] autorelease];
    CGSize szImg = CGSizeZero;
    NSData *dImg = [pu readImageWithError:err];
    if (!dImg) {
        return nil;
    }
    szImg = [pu imageSize];
    
    //  - make a copy so that we can clear out the data bits.
    NSMutableData *mdImage = [NSMutableData dataWithData:dImg];
    int width = szImg.width;
    int height = szImg.height;
    if ([mdImage length] != width * height * 4) {
        [RSI_error fillError:err withCode:RSI_PNG_ERR_FATAL_INVALID];
        return nil;
    }
    
    //  - clear all the data bits to ensure consistency
    unsigned char *bitmap = [mdImage mutableBytes];
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            //  zero out the data fields in the colors
            for (int c = 0; c < 3; c++) {
                *bitmap &= MASK_ALLBUT_2;
                bitmap++;
            }
            
            //  and the alpha
            *bitmap &= MASK_ALLBUT_4;
            bitmap++;
        }
    }
    
    //  - now just create a SHA1 hash of the data
    return [RSI_SHA_SCRAMBLE hashFromInput:mdImage];
}

@end


/*************************
 PNG_unpack (internal)
 *************************/
@implementation PNG_unpack (internal)

/*
 *  The first content in a PNG file is signature and IHDR.
 */
-(BOOL) readHeaderWithError:(NSError **) err
{
    //  - the signature is easy.
    if ((lastByte - curByte) < SIG_LEN) {
        [RSI_error fillError:err withCode:RSI_PNG_ERR_READ_FAIL andFailureReason:@"Missing or invalid signature."];
        return NO;
    }

    if (memcmp(curByte, PNG_SIG, SIG_LEN)) {
        [RSI_error fillError:err withCode:RSI_PNG_ERR_FATAL_INVALID andFailureReason:@"Missing or invalid signature."];
        return NO;
    }
    
    curByte+=8;
    
    //  - the IHDR isn't too bad either.
    uint32_t clen = 0;
    uint32_t chunk = 0;
    const unsigned char *crcBegin = NULL;
    if (![self prepForChunkOfLength:&clen andType:&chunk andCRCBegin:&crcBegin withError:err]) {
        return NO;
    }
    
    if (chunk != IHDR) {
        [RSI_error fillError:err withCode:RSI_PNG_ERR_FATAL_INVALID andFailureReason:@"Missing IHDR chunk."];
        return NO;
    }
    
    if (clen != 13) {
        [RSI_error fillError:err withCode:RSI_PNG_ERR_READ_FAIL andFailureReason:@"Missing IHDR chunk."];
        return NO;
    }
    
    if (![self readQuad:&width] || ![self readQuad:&height] ||
        width == 0 || height == 0) {
        [RSI_error fillError:err withCode:RSI_PNG_ERR_READ_FAIL andFailureReason:@"IHDR format error."];
        return NO;
    }
    
    if (width > MAX_IMAGE_SIDE || height > MAX_IMAGE_SIDE) {
        [RSI_error fillError:err withCode:RSI_PNG_ERR_FATAL_INVALID andFailureReason:@"Image is too large."];
        return NO;
    }
    
    if (curByte + 5 >= lastByte) {
        [RSI_error fillError:err withCode:RSI_PNG_ERR_READ_FAIL andFailureReason:@"Incomplete header."];
        return NO;
    }

    //  - these values must be very specific or the embedded data cannot exist
    if (curByte[0] != 8) {
        [RSI_error fillError:err withCode:RSI_PNG_ERR_FATAL_INVALID andFailureReason:@"Invalid bit depth."];
        return NO;
    }
    
    if (curByte[1] != COLOR_TYPE_RGBA && curByte[1] != COLOR_TYPE_RGB) {
        [RSI_error fillError:err withCode:RSI_PNG_ERR_FATAL_INVALID andFailureReason:@"Invalid color type."];
        return NO;
    }

    // - NOTE: after some thought I decided that I'm going to accept an image that has been 'up converted' to include
    //         an alpha channel just because the reverse happened to me with Twitter and I don't want to be blindsided again.  Plus
    //         it is just easier to assume the extra and ignore it than to customize around a 3-byte pixel format.
    hasAlpha = (curByte[1] == COLOR_TYPE_RGBA) ? YES : NO;
    
    if (curByte[2] != 0) {
        [RSI_error fillError:err withCode:RSI_PNG_ERR_FATAL_INVALID andFailureReason:@"Invalid compression method."];
        return NO;
    }
    
    if (curByte[3] != 0) {
        [RSI_error fillError:err withCode:RSI_PNG_ERR_FATAL_INVALID andFailureReason:@"Invalid filter method."];
        return NO;
    }
    
    if (curByte[4] != 0 && curByte[4] != 1) {
        [RSI_error fillError:err withCode:RSI_PNG_ERR_FATAL_INVALID andFailureReason:@"Invalid interlacing method."];
        return NO;
    }
    
    isInterlaced = (curByte[4] ? YES : NO);
    curByte += 5;
    
    if (![self processChunkCRCFromBegin:crcBegin withLength:clen andError:err]) {
        return NO;
    }
    
    return YES;
}

/*
 *  Since we process the CRC at the end (to facillitate partial chunking), this method gets some relevant data for the chunk
 *  and tracks the location from where the CRC should be performed.
 */
-(BOOL) prepForChunkOfLength:(uint32_t *) clen andType:(uint32_t *) ctype andCRCBegin:(const unsigned char **) crcBegin withError:(NSError **) err;
{
    //  - pull the length of the chunk
    if (![self readQuad:clen]) {
        [RSI_error fillError:err withCode:RSI_PNG_ERR_READ_FAIL andFailureReason:@"Missing chunk layout data."];
        return NO;
    }
    
    //  - then save the location where the CRC should start
    *crcBegin = curByte;
    
    //  - now read the type
    if (![self readQuad:ctype]) {
        [RSI_error fillError:err withCode:RSI_PNG_ERR_READ_FAIL andFailureReason:@"Missing chunk layout data."];
        return NO;
    }
    
    return YES;
}

/*
 *  Verify the CRC from the beginning to the current location, which is expected to be right where
 *  the CRC starts in the byte sequence.
 */
-(BOOL) processChunkCRCFromBegin:(const unsigned char *) crcBegin withLength:(uint32_t) clen andError:(NSError **) err
{
    //  - verify the CRC last because when doing partial packed data reads, it is possible that
    //    the file will be truncated before the CRC
    uint32_t crc = (uint32_t) crc32(0, crcBegin, clen + 4);
    uint32_t crcCompare = 0;
    if (![self readQuad:&crcCompare]) {
        [RSI_error fillError:err withCode:RSI_PNG_ERR_READ_FAIL andFailureReason:@"Chunk CRC read failure."];
        return NO;
    }
    
    if (crc != crcCompare) {
        [RSI_error fillError:err withCode:RSI_PNG_ERR_FATAL_INVALID andFailureReason:@"Chunk CRC failure."];
        return NO;
    }
    
    return YES;
}

/*
 *  Take a peek at the quad value
 */
-(BOOL) peekQuad:(uint32_t *) val atLocation:(const unsigned char *) ptr
{
    if (ptr + 4 <= lastByte) {
        *val = ((uint32_t) ptr[0] << 24) | ((uint32_t) ptr[1] << 16) | ((uint32_t) ptr[2] << 8) | (uint32_t) ptr[3];
        return YES;
    }
    else {
        return NO;
    }
}

/*
 *  Read a four-byte value from the stream
 */
-(BOOL) readQuad:(uint32_t *) val
{
    if ([self peekQuad:val atLocation:curByte]) {
        curByte +=4;
        return YES;
    }
    return NO;
}

/*
 *  Skip a chunk in the input stream.
 */
-(BOOL) skipChunkOfLength:(uint32_t) clen withError:(NSError **) err
{
    curByte += clen;
    return YES;
}

/*
 *  The IDAT contains the actual image data.
 */
-(BOOL) processIDATOfLength:(uint32_t) clen withError:(NSError **) err
{
    //  - with a zero-length IDAT, just make sure the CRC is skipped, but
    //    return
    if (clen == 0) {
        return YES;
    }
    
    //  - configure the input stream 
    if (!streamInit) {
        inStream.zalloc = PNG_zalloc;
        inStream.zfree  = PNG_zfree;
        inStream.opaque = 0;
        
        inStream.next_in = (Bytef *) curByte;

        //  - the length will be larger when the file is truncated, which
        //    is uncommon, but this is something we need to consider.
        if (clen > (lastByte - curByte)) {
            inStream.avail_in = (uInt) (lastByte - curByte);
        }
        else {
            inStream.avail_in = clen;
        }
        
        int zret = inflateInit2(&inStream, 15);
        if (zret != Z_OK) {
            [RSI_error fillError:err withCode:RSI_PNG_ERR_READ_FAIL andZlibError:zret];
            return NO;
        }
        streamInit = YES;
    }
    else {
        inStream.next_in = (Bytef *) curByte;
        inStream.avail_in = clen;
    }
    
    //  - repeatedly read from the input stream until this IDAT is consumed
    for (;;) {
        //  - find a location in the output buffer to store the data
        //    and set up the stream
        int numRemain = (int) (lastDecomp - nextDecomp);
        if (numRemain) {
            memmove(mdDecompressBuffer.mutableBytes, nextDecomp, numRemain);
        }
        nextDecomp = mdDecompressBuffer.mutableBytes;
        
        inStream.next_out = &(nextDecomp[numRemain]);
        int toGrab = STREAM_OUT_LEN - numRemain;
        inStream.avail_out = (uInt) toGrab;                        //  this works because we have a limit on the width of the image and one scanline can never exceed the buffer
        
        int zret = inflate(&inStream, Z_NO_FLUSH);
        if (zret != Z_OK && zret != Z_STREAM_END) {
            [RSI_error fillError:err withCode:RSI_PNG_ERR_READ_FAIL andZlibError:zret];
            return NO;
        }

        lastDecomp = &(nextDecomp[(NSUInteger) (numRemain + toGrab) - inStream.avail_out]);
        
        //  - process as many scanlines as possible from the buffer
        if (![self consumeScanlinesWithError:err]) {
            return NO;
        }
        
        //  - exit early if there is a maximum amount of data to unpack.
        if (maxUnpack && unpackedData && [unpackedData numBytesWritten] >= maxUnpack) {
            return YES;
        }
        
        if (zret == Z_STREAM_END && (inStream.avail_in > 0 || nextDecomp != lastDecomp)) {
            [RSI_error fillError:err withCode:RSI_PNG_ERR_FATAL_INVALID andFailureReason:@"Extraneous IDAT content error."];
            return NO;
        }

        //  - when there is no more input, finish up with this chunk
        if (inStream.avail_in == 0) {
            break;
        }
    }

    //  - jump over the IDAT chunk
    return [self skipChunkOfLength:clen withError:err];
}

/*
 *  When scanlines have been read, then process them one at a time.
 */
-(BOOL) consumeScanlinesWithError:(NSError **) err
{
    //  - the goal will be to read as much of the buffer as possible
    while (nextDecomp < lastDecomp) {
        //  - if we've advanced through all the passes, but more data remains, that
        //    indicates an error in the way we're reading it or it was packed.
        if (pass > 6 || rowMajor >= height) {
            [RSI_error fillError:err withCode:RSI_PNG_ERR_FATAL_INVALID andFailureReason:@"Interlacing sequence error."];
            return NO;
        }
        
        //  - determine what kind of filter we're working with
        unsigned char filter = *nextDecomp;
        if (filter > FILTER_PAETH) {
            [RSI_error fillError:err withCode:RSI_PNG_ERR_FATAL_INVALID andFailureReason:@"Unknown filter type encountered."];
            return NO;
        }
        
        unsigned char *curScanLine = [scanline current];
        unsigned char *prevScanLine = [scanline previous];

        //  - attempt to fill the current buffer with the filtered data
        int pixelWidth = hasAlpha ? 4 : 3;
        int scanLen    = 4;                                                        //  always start at the second pixel to support averaging with prior pixels
        int rowIndex   = (rowMajor + rowMinor) * (int) width * 4;
        unsigned char *tmpNext = nextDecomp;
        for (uint32_t i = 0, colIndex = 0; i < width; i++, colIndex += 4) {
            //  - not enough space with this buffer
            if (lastDecomp - tmpNext < pixelWidth) {
                //  - if interlaced and there is no more to expect in this row, then
                //    update the next pointer
                if (isInterlaced) {
                    uint32_t curAdamCol = i & 0x07;
                    for (uint32_t j = curAdamCol; j < 8; j++) {
                        if (Adam7[rowMinor][j] == pass + 1) {
                            //  - the next pixel is outside the bounds of our bitmap
                            if (i + j >= width) {
                                nextDecomp = tmpNext;
                            }
                            break;
                        }
                    }
                }
                
                return YES;
            }
            
            //  - if interlacing:
            //      ...and there is nothing in this column, then continue,
            //      ...or  there is nothing in this row, then break
            //      ...otherwise, store the data in the output.
            if (isInterlaced) {
                if (Adam7[rowMinor][i & 0x07] != pass + 1) {
                    continue;
                }
                else if (rowMajor + rowMinor >= height) {
                    break;
                }
            }
            
            //  - before processing the first pixel, advance the pointer.
            //  - this is necessary because not every pass in a small image
            //    will necessarily use the next scanline.
            if (tmpNext == nextDecomp) {
                tmpNext++;
            }

            //  - defilter the data
            unsigned char r, g, b, a;
            r = tmpNext[0];
            g = tmpNext[1];
            b = tmpNext[2];
            if (hasAlpha) {
                a = tmpNext[3];
            }
            else {
                a = 0xFF;            // - assume that no alpha means 100% opacity.
            }
            tmpNext += hasAlpha ? 4 : 3;
            
            switch (filter)
            {
                case FILTER_NONE:
                default:
                    //  nothing to do
                    break;
                    
                case FILTER_SUB:
                    r += curScanLine[scanLen - 4];
                    g += curScanLine[scanLen - 3];
                    b += curScanLine[scanLen - 2];
                    if (hasAlpha) {
                        a += curScanLine[scanLen - 1];
                    }
                    break;
                    
                case FILTER_UP:
                    r += prevScanLine[scanLen];
                    g += prevScanLine[scanLen+1];
                    b += prevScanLine[scanLen+2];
                    if (hasAlpha) {
                        a += prevScanLine[scanLen+3];
                    }
                    break;
                    
                case FILTER_AVE:
                    r += PNG_average(curScanLine[scanLen - 4], prevScanLine[scanLen]);
                    g += PNG_average(curScanLine[scanLen - 3], prevScanLine[scanLen+1]);
                    b += PNG_average(curScanLine[scanLen - 2], prevScanLine[scanLen+2]);
                    if (hasAlpha) {
                        a += PNG_average(curScanLine[scanLen - 1], prevScanLine[scanLen+3]);
                    }
                    break;
                    
                case FILTER_PAETH:
                    r = (unsigned char) (((int) r + PNG_paethpredictor(curScanLine[scanLen - 4], prevScanLine[scanLen],   prevScanLine[scanLen - 4])) % 256);
                    g = (unsigned char) (((int) g + PNG_paethpredictor(curScanLine[scanLen - 3], prevScanLine[scanLen+1], prevScanLine[scanLen - 3])) % 256);
                    b = (unsigned char) (((int) b + PNG_paethpredictor(curScanLine[scanLen - 2], prevScanLine[scanLen+2], prevScanLine[scanLen - 2])) % 256);
                    if (hasAlpha) {
                        a = (unsigned char) (((int) a + PNG_paethpredictor(curScanLine[scanLen - 1], prevScanLine[scanLen+3], prevScanLine[scanLen - 1])) % 256);
                    }
                    break;
            }
            
            //  - store one pixel in the current scanline buffer
            curScanLine[scanLen]   = r;
            curScanLine[scanLen+1] = g;
            curScanLine[scanLen+2] = b;
            curScanLine[scanLen+3] = a;
            
            //  - and in either the output buffer or the unpacked data buffer
            if (imgBuffer) {
                imgBuffer[(uint32_t) rowIndex + colIndex]     = r;
                imgBuffer[(uint32_t) rowIndex + colIndex + 1] = g;
                imgBuffer[(uint32_t) rowIndex + colIndex + 2] = b;
                imgBuffer[(uint32_t) rowIndex + colIndex + 3] = a;
            }
            
            scanLen += 4;
        }
        
        //  - when unpacking, it is critical to do this outside the scanline loop because
        //    an insufficient scanline buffer will force that loop to be executed multiple times for the same
        //    y offset.
        if (unpackedData) {
            curScanLine = [scanline current] + 4;
            for (int i = 0; i < width; i++) {
                if (readReserved) {
                    //  NOTE: the steganography is made up of 6 low-order bits.
                    if (![unpackedData writeBits:curScanLine[0] ofLength:2] ||
                        ![unpackedData writeBits:curScanLine[1] ofLength:2] ||
                        ![unpackedData writeBits:curScanLine[2] ofLength:2] ||
                        (hasAlpha && ![unpackedData writeBits:curScanLine[3] ofLength:1])) {
                        [RSI_error fillError:err withCode:RSI_PNG_ERR_READ_FAIL andFailureReason:@"Unpack failure."];
                        return NO;
                    }
                }
                else {
                    // - I'm reserving the contents of the first pixel for future expansion.
                    readReserved = YES;
                }
                
                curScanLine += 4;
            }
        }
                
        //  - exit early if unpacking with a maximum length of data.
        if (maxUnpack && unpackedData && [unpackedData numBytesWritten] >= maxUnpack) {
            return YES;
        }
        
        //  - save off the location of the next scanline
        nextDecomp = tmpNext;
        
        //  - and the contents of the scanline we just processed.
        [scanline advance];
        
        //  - and identify the next row.
        if (isInterlaced) {
            int nextRow = AdamPassNextRow[pass][rowMinor];
            if (nextRow == -1) {
                [RSI_error fillError:err withCode:RSI_PNG_ERR_READ_FAIL andFailureReason:@"Invalid interlacing row sequence."];
                return NO;
            }
            
            if (nextRow <= rowMinor) {
                rowMajor += 8;
                if (rowMajor >= height) {
                    pass++;
                    [scanline resetHistory];                //  interlaced images always reset the history between passes
                    rowMajor = 0;
                }
                rowMinor = AdamPassFirstRow[pass];
            }
            else {
                rowMinor = nextRow;
            }
        }
        else {
            rowMinor++;
            if (rowMinor > 7) {
                rowMajor += 8;
                rowMinor = 0;
            }
        }        
    }

    return YES;
}

/*
 *  Read the image buffer data (RGBA color components)
 */
-(BOOL) tryToReadImageWithError:(NSError **) err
{
    //  - check arguments and prepare for the read process
    if (!dImage || [dImage length] < 1) {
        [RSI_error fillError:err withCode:RSI_PNG_ERR_INVAL_ARG];
        return NO;
    }
    
    curByte = (const unsigned char *) [dImage bytes];
    lastByte = curByte + [dImage length];
    width = height = 0;
    isInterlaced = NO;
    pass = rowMajor = rowMinor = 0;
    
    //  - determine what kind of image this is and if
    //    we support it.
    if (![self readHeaderWithError:err]) {
        return NO;
    }
    
    //  - build the buffers we'll use for decoding (but only if we want to retain the color data)
    //  - a scan line is never larger than the next multiple of 8 for the width
    //  - add one to the scan line buffer to simplify filtering/averaging
    //  - NOTE: we're assuming we'll store RGBA even if the source image was only RGB.
    [mdImageBuffer release];
    if (unpackedData) {
        mdImageBuffer = nil;
        imgBuffer = NULL;
    }
    else {
        mdImageBuffer = [[NSMutableData alloc] initWithLength:(width <<  2) * height];
        imgBuffer = (unsigned char *) [mdImageBuffer mutableBytes];
    }
    
    if (streamInit) {
        deflateEnd(&inStream);
    }
    streamInit = NO;
    mdDecompressBuffer = [[NSMutableData alloc] initWithLength:STREAM_OUT_LEN];
    nextDecomp = (unsigned char *) mdDecompressBuffer.mutableBytes;
    lastDecomp = nextDecomp;
    
    [scanline release];
    scanline = [[RSI_png_scanline alloc] initWithWidth:width];
    
    //  - now process each of the chunks one at a time, skipping
    //    non-critical ones and flagging unsupported critical
    //    ones.
    uint32_t clen = 0;
    uint32_t chunk = 0;
    const unsigned char *crcFrom = NULL;
    for (;;) {
        //  - in order to support partial unpacking with truncated files, the CRC isn't validated
        //    until after the content is processed, which allows an early exit before the
        //    end of the chunk
        if (![self prepForChunkOfLength:&clen andType:&chunk andCRCBegin:&crcFrom withError:err]) {
            return NO;
        }
        
        //  - if we found the end of the stream, just move past its length
        if (chunk == IEND) {
            curByte += clen;
        }
        //  - if we found an IDAT, this needs to be processed.
        else if (chunk == IDAT) {
            if (![self processIDATOfLength:clen withError:err]) {
                return NO;
            }
            
            //  - exit early if there is a maximum on the amount of data to unpack.
            if (maxUnpack && unpackedData && [unpackedData numBytesWritten] >= maxUnpack) {
                return YES;
            }
        }
        //  - if this is an ancillary chunk, skip it.
        //  - the fifth bit of the high byte is the one of interest.
        else if ((chunk >> 29) & 0x01) {
            if (![self skipChunkOfLength:clen withError:err]) {
                return NO;
            }
        }
        //  - a PLTE critical chunk is actually optional in truecolor
        //    images and can be safely ignored
        else if (chunk == IPLT) {
            if (![self skipChunkOfLength:clen withError:err]) {
                return NO;
            }
        }
        else {
            //  - anything remaining is a critical chunk that we do not support
            [RSI_error fillError:err withCode:RSI_PNG_ERR_FATAL_INVALID andFailureReason:@"Found unsupported critical chunk."];
            return NO;
        }
        
        //  - finish off by verifying the CRC.
        if (crcFrom + clen <= lastByte) {
            if (![self processChunkCRCFromBegin:crcFrom withLength:clen andError:err]) {
                return NO;
            }
        }
        else {
            [RSI_error fillError:err withCode:RSI_PNG_ERR_READ_FAIL andFailureReason:@"Truncated file."];
            return NO;
        }
        
        //  - the final CRC is verified, so exit the loop
        if (chunk == IEND) {
            break;
        }
    }
    
    //  - we should be at the end of the file
    if (curByte != lastByte) {
        [RSI_error fillError:err withCode:RSI_PNG_ERR_FATAL_INVALID andFailureReason:@"Trailing data found in file."];
        return NO;
    }
    
    return YES;
}

@end


/****************************
 PNG_pack
 ****************************/
@implementation PNG_pack
/*
 *  Object attributs.
 */
{
    unsigned char   *bitmap;
    NSUInteger      width;
    NSUInteger      height;
    
    BOOL            savedReserved;
    NSUInteger      lenData;
    RSI_file        *data;
    
    NSMutableData   *filteredLines[5];                 //  none, sub, up, ave, paeth
    
    RSI_zlib_file   *outputFile;
    
    NSData          *dIDAT;
}

/*
 *  Initialize the object.
 *  - a non-const bitmap is passed because it must be modified in place to include the embedded data
 *    because the filtering depends on the prior lines reflecting the expected color composition of
 *    the actual image.
 */
-(id) initWithBitmap:(unsigned char *) bm andWidth:(NSUInteger) w andHeight:(NSUInteger) h andData:(NSData *) d
{
    self = [super init];
    if (self) {
        bitmap        = bm;
        width         = w;
        height        = h;
        lenData       = [d length];
        savedReserved = NO;
        
        if (d) {
            data = [[RSI_file alloc] initForReadWithData:d];
        }
        
        for (int i = 0; i < 5; i++) {
            filteredLines[i] = [[NSMutableData alloc] initWithLength:width * PNG_BYTES_PER_PIXEL];
        }
    }
    return self;
}

/*
 *  Free the object
 */
-(void) dealloc
{
    for (int i = 0; i < 5; i++) {
        [filteredLines[i] release];
        filteredLines[i] = nil;
    }
    
    [outputFile release];
    outputFile = nil;
    
    [dIDAT release];
    dIDAT = nil;
    
    [data release];
    data = nil;
    
    width = height = 0;
    
    bitmap = NULL;
    
    [super dealloc];
}

/*
 *  Return the maximum number of bytes that can be stored in the given file if packed as a PNG.
 */
+(NSUInteger) maxDataForPNGImageOfWidth:(NSUInteger) w andHeight:(NSUInteger) h;
{
    NSUInteger numBits = w * h * [PNG_pack bitsPerPNGPixel];
    NSUInteger retVal = (numBits >> 3);
    if (retVal > 2) {
        return retVal - 1;          //  we reserve the first pixel of data or 6 bits (rounded to 8) for density identification.
    }
    return 0;
}

/*
 *  Return the number of bits that each PNG pixel can store.
 */
+(NSUInteger) bitsPerPNGPixel
{
    return PNG_PACK_BIT_DENSITY;
}

/*
 *  Process one scanline from the source image.
 *  - the scanline is modified in-place because unless the previous lines include the embedded
 *    data, these routines 
 */
-(BOOL) processScanLine:(unsigned char *) scanline atIndex:(int) y withError:(NSError **) err
{
    //  - save off the filtered scanline
    unsigned char *pNO_FILTER    = [filteredLines[FILTER_NONE] mutableBytes];
    unsigned char *pSUB_FILTER   = [filteredLines[FILTER_SUB] mutableBytes];
    unsigned char *pUP_FILTER    = [filteredLines[FILTER_UP] mutableBytes];
    unsigned char *pAVE_FILTER   = [filteredLines[FILTER_AVE] mutableBytes];
    unsigned char *pPAETH_FILTER = [filteredLines[FILTER_PAETH] mutableBytes];
    
    //  - process each color component one at a time.    
    unsigned int absvals[5] = {0, 0, 0, 0, 0};
    int comp = 0;
    NSUInteger numComps = (width << 2);
    for (NSUInteger x = 0; x < numComps; x++) {
        unsigned char c = *scanline;
        
        //  - store the data in the component
        if (data && ![data isEOF]) {
            if (savedReserved) {
                unsigned char val = 0;

                // - we don't store any data in the alpha component because the PNG
                //   will be saved without it to make it more portable.
                if (comp == ALPHA_COMP) {
                    // - assume the alpha is fully opaque.
                    c = 0xFF;
                }
                else {
                    if ([data readUpTo:2 bitsIntoBuffer:&val ofLength:1]) {
                        c &= MASK_ALLBUT_2;
                        val = val >> 6;
                        c |= val;
                    }
                }
             }
            else {
                // - the first pixel is reserved for future expansion at the moment.
                if (comp == ALPHA_COMP) {
                    savedReserved = YES;
                }
                c &= MASK_ALLBUT_2;
            }
        }
        
        //  - save the embedded data into the bitmap so that subsquent
        //    multi-pixel filters (sub, paeth, etc.) use the complete
        //    color data and not just the original
        *scanline = c;
        
        //  - now filter this item into each temporary scanline buffer
        //  - but only with RGB colors because otherwise, we don't use the data.
        if (comp != ALPHA_COMP) {
            unsigned char left   = 0;
            unsigned char up     = 0;
            unsigned char upleft = 0;
            if (x > 3) {
                left = *(scanline - 4);
            }
            if (y > 0) {
                up = *(scanline - (width << 2));
                if (x > 3) {
                    upleft = *(scanline - (width << 2) - 4);
                }
            }
            
            for (int i = 0; i < 5; i++) {
                unsigned char fc = 0;
                switch (i) {
                    case FILTER_NONE:
                    default:
                        fc = *pNO_FILTER = c;
                        pNO_FILTER++;
                        break;
                        
                    case FILTER_SUB:
                        fc = *pSUB_FILTER = c - left;
                        pSUB_FILTER++;
                        break;
                        
                    case FILTER_UP:
                        fc = *pUP_FILTER = c - up;
                        pUP_FILTER++;
                        break;
                        
                    case FILTER_AVE:
                        fc = *pAVE_FILTER = c - PNG_average(left, up);
                        pAVE_FILTER++;
                        break;
                        
                    case FILTER_PAETH:
                        fc = *pPAETH_FILTER = c - PNG_paethpredictor(left, up, upleft);
                        pPAETH_FILTER++;
                        break;
                }
                
                //  - save statistics on the item to help decide which is best for the output.
                absvals[i] += fc;
            }
        }
        
        //  - next component
        scanline++;
        comp = (comp + 1) % 0x04;
    }
        
    //  - send each scanline to the correct output after
    //    we determine which one is likely to have the best compression characteristics
    NSUInteger lowest = 0;
    for (NSUInteger i = 1;i < 5; i++) {
        if (absvals[i] < absvals[lowest]) {
            lowest = i;
        }
    }
    
    //  write the filter code
    [outputFile writeBits:(uint32_t) lowest ofLength:8];
    
    // - convert the buffer into RGB and write the color data.
    const unsigned char *filtered_scanline = [filteredLines[lowest] bytes];
    [outputFile writeToOutput:filtered_scanline withLength:width * PNG_BYTES_PER_PIXEL];
    
    return YES;
}

/*
 *  Compute the optimal IDAT composition.
 */
-(BOOL) generateIDATWIthError:(NSError **) err
{
    //  - allocate an output file to use for compressing the stream.
    outputFile = [[RSI_zlib_file alloc] initForWriteWithLevel:RSI_CL_BEST andWindowBits:15 andStategy:RSI_CS_DEFAULT withError:err];
    if (!outputFile) {
        return NO;
    }
    
    //  - iterate over each scanline and
    //    sending content to the four styles of output file.
    unsigned char *scanline = bitmap;
    for (int y = 0; y < height; y++) {
        if (![self processScanLine:scanline atIndex:y withError:err]) {
            return NO;
        }
        
        scanline += (width << 2);
    }
    
    //  - one at a time, evaluate each output file and choose the smallest
    dIDAT = [[outputFile fileData] retain];
    [outputFile release];
    outputFile = nil;
    
    //  - if none of them made the grade, then abort
    if (!dIDAT || ![dIDAT length]) {
        [RSI_error fillError:err withCode:RSI_PNG_ERR_WRITE_FAIL andFailureReason:@"Failed to generate a suitable IDAT file."];
        return NO;
    }

    return YES;
}

/*
 *  Produce the packed PNG file.
 */
-(NSData *) packedPNGandError:(NSError **) err
{
    if (!bitmap || width < 1 || height < 1 || width > MAX_IMAGE_SIDE || height > MAX_IMAGE_SIDE) {
        [RSI_error fillError:err withCode:RSI_PNG_ERR_INVAL_ARG];
        return nil;
    }
    
    //  - the hard part is generating the IDAT so we'll do that first
    if (![self generateIDATWIthError:err]) {
        return nil;
    }
    
    //  - now with compressed IDAT data, all that remains is to just
    //    output it with a bare minimum composition of header and footer.
    RSI_file *fOutput = [[[RSI_file alloc] initForWrite] autorelease];
    
    //  - write the file prefix
    if (![fOutput writeToOutput:PNG_SIG withLength:8]) {
        [RSI_error fillError:err withCode:RSI_PNG_ERR_WRITE_FAIL andFailureReason:@"Failed to write the file signature."];
        return nil;
    }
    
    //  - write the IHDR
    NSData *dChunk = nil;
    RSI_file *fChunk = [[[RSI_file alloc] initForWrite] autorelease];
    if (![fChunk writeBits:IHDR ofLength:32] ||
        ![fChunk writeBits:(uint32_t) width ofLength:32] || //  width
        ![fChunk writeBits:(uint32_t) height ofLength:32] ||//  height
        ![fChunk writeBits:8 ofLength:8] ||                 //  bit depth
        ![fChunk writeBits:COLOR_TYPE_RGB ofLength:8] ||    //  color type
        ![fChunk writeBits:0 ofLength:8] ||                 //  compression method
        ![fChunk writeBits:0 ofLength:8] ||                 //  filter method
        ![fChunk writeBits:0 ofLength:8] ||                 //  interlace method (no interlacing)
        !(dChunk = [fChunk fileData])) {
        [RSI_error fillError:err withCode:RSI_PNG_ERR_WRITE_FAIL andFailureReason:@"Failed to build the IHDR structure."];
        return nil;
    }
    
    uLong crc = crc32(0, dChunk.bytes, (uInt) [dChunk length]);
    if (![fOutput writeBits:(uint32_t) [dChunk length] - 4 ofLength:32] ||       //  length of data
        ![fOutput writeToOutput:dChunk.bytes withLength:[dChunk length]] ||      //  the type and data
        ![fOutput writeBits:(uint32_t) crc ofLength:32]) {                       //  the CRC
        [RSI_error fillError:err withCode:RSI_PNG_ERR_WRITE_FAIL andFailureReason:@"Failed to output the IHDR chunk."];
        return nil;
    }
    
    //  - write the IDAT
    unsigned char buf[4];
    buf[0] = (unsigned char) (IDAT >> 24) & 0xFF;
    buf[1] = (unsigned char) (IDAT >> 16) & 0xFF;
    buf[2] = (unsigned char) (IDAT >> 8) & 0xFF;
    buf[3] = (unsigned char) IDAT & 0xFF;
    crc = crc32(0, buf, 4);
    crc = crc32(crc, dIDAT.bytes, (uInt) dIDAT.length);
    
    if (![fOutput writeBits:(uint32_t) [dIDAT length] ofLength:32] ||           //  length of data
        ![fOutput writeBits:IDAT ofLength:32] ||                                //  chunk type
        ![fOutput writeToOutput:dIDAT.bytes withLength:[dIDAT length]] ||       //  image data
        ![fOutput writeBits:(uint32_t) crc ofLength:32]) {                      //  the CRC
        [RSI_error fillError:err withCode:RSI_PNG_ERR_WRITE_FAIL andFailureReason:@"Failed to write the IDAT chunk."];
        return nil;
    }
    
    //  - write the IEND
    buf[0] = (unsigned char) (IEND >> 24) & 0xFF;
    buf[1] = (unsigned char) (IEND >> 16) & 0xFF;
    buf[2] = (unsigned char) (IEND >> 8) & 0xFF;
    buf[3] = (unsigned char) IEND & 0xFF;
    crc = crc32(0, buf, 4);
    
    if (![fOutput writeBits:0 ofLength:32] ||                                   //  length of data (0)
        ![fOutput writeBits:IEND ofLength:32] ||                                //  chunk type
        ![fOutput writeBits:(uint32_t) crc ofLength:32]) {                      //  the CRC
        [RSI_error fillError:err withCode:RSI_PNG_ERR_WRITE_FAIL andFailureReason:@"Failed to write the IEND chunk."];
        return nil;        
    }

    return [fOutput fileData];
}

@end