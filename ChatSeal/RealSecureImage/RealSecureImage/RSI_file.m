//
//  RSI_file.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 11/15/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import "RSI_file.h"
#import "RSI_common.h"

static const NSUInteger MAX_SEGMENT_DATA_LEN = 0xFFFF - 2;
static const NSUInteger MAX_INPUT_FILE_LEN   = (5 * 1024 * 1024);     //  To ensure that really large files can't be used to break this.

//  - forward declarations
@interface RSI_file (internal)
-(BOOL) writeWordToOutput:(uint16_t) w;
@end


/************************
 RSI_file
 ************************/
@implementation RSI_file
/*
 *  Object attributes.
 */
{
    BOOL          isWrite;
    NSMutableData *mdFile;
    NSData        *mdInput;
    
    BOOL          inMarker;
    NSMutableData *mdSegment;
    
    BOOL          inECS;
    unsigned char curBitStreamByte;
    
    NSInteger     curBit;
    
    NSInteger     numInputBits;
}

/*
 *  Initialize the file object for output.
 */
-(id) initForWrite
{
    self = [super init];
    if (self) {
        isWrite = YES;
        mdFile = [[NSMutableData alloc] init];
        inMarker = NO;
        mdSegment = [[NSMutableData alloc] init];
        inECS = NO;
        curBit = 7;
    }
    return self;
}

/*
 *  Initialize the file object for input.
 */
-(id) initForReadWithData:(NSData *) d
{
    self = [super init];
    if (self) {
        isWrite = NO;
        mdInput = nil;
        if (d && [d length] < MAX_INPUT_FILE_LEN) {
            mdInput = [d retain];                       //  no need for mutable data, so don't recopy it.
            numInputBits = (NSInteger) ([d length] << 3);
        }
        [self reset];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [mdFile release];
    mdFile = nil;
    
    [mdSegment release];
    mdSegment = nil;
    
    [mdInput release];
    mdInput = nil;
    
    [super dealloc];
}

/*
 *  Return a copy of the data.
 */
-(NSData *) fileData
{
    if (![self flush]) {
        return nil;
    }
    return [[mdFile retain] autorelease];
}

/*
 *  Return a copy of the data that has been implicitly flushed.  
 *  - any pending bits that don't yet produce a byte won't be included.
 */
-(NSData *) flushedFileData
{
    if (!isWrite) {
        return nil;
    }
    return [[mdFile retain] autorelease];
}

/*
 *  Return a count of the number of bytes written to this output stream.
 */
-(NSUInteger) numBytesWritten
{
    if (!isWrite) {
        return 0;
    }
    return [mdFile length];
}

/*
 *  Trucate the file data if possible
 */
-(BOOL) truncateTo:(NSUInteger) length
{
    if ([self flush]) {
        [mdFile setLength:length];
        return YES;
    }
    else {
        return NO;
    }
}

/*
 *  To ensure that in secure situations the file data is gone
 *  this method will zero it.
 */
-(void) zeroFileData
{
    if (mdFile) {
        memset(mdFile.mutableBytes, 0, [mdFile length]);
    }
}

/*
 *  Write a marker that stands alone in the output.
 */
-(BOOL) writeMarker:(uint16_t) marker
{
    if (inMarker) {
        return NO;
    }
    
    return [self writeWordToOutput:marker];
}

/*
 *  Start a new marker segment, implying more will come.
 */
-(BOOL) beginMarkerSegment:(uint16_t) marker
{
    if (inMarker) {
        return NO;
    }
    
    //  - this segment identifier should be written immediately.
    if ([self writeMarker:marker]) {
        inMarker = YES;
        return YES;
    }
    return NO;
}

/*
 *  Write a single byte to the current marker segment
 */
-(BOOL) putc:(unsigned char) c
{
    //  - write to the segment buffer only
    return [self write:&c withLength:1];
}

/*
 *  Write an unsigned 16-bit integer to the current marker segment
 */
-(BOOL) putw:(uint16_t) w
{
    unsigned char buf[2];
    buf[0] = (unsigned char) ((w >> 8) & 0xFF);
    buf[1] = (unsigned char) (w & 0xFF);
    
    //  - write to the segment buffer only    
    return [self write:buf withLength:2];
}

/*
 *  Write a sequence of bytes to the current file
 */
-(BOOL) write:(const unsigned char *) bytes withLength:(NSUInteger) len
{
    if (!isWrite) {
        return NO;
    }
    
    if (inMarker) {
        //  - write to the segment buffer only
        if (curBit != 7) {
            return NO;
        }
        
        if ([mdSegment length] + len  > MAX_SEGMENT_DATA_LEN) {
            return NO;
        }
        
        [mdSegment appendBytes:bytes length:len];
    }
    else {
        //  - if the current bit is the high one, then we
        //    can assume that a straight append is acceptable.
        if (curBit == 7) {
            return [self writeToOutput:bytes withLength:len];
        }
        else {
            //  - there are some stray bits, so we have to do this the hard way.
            [self writeBitsFromBuffer:bytes withNumBits:len << 3];
        }
    }
    return YES;
}

/*
 *  Commit a pending marker segment to the output.
 */
-(BOOL) commitMarkerSegment
{
    if (!inMarker) {
        return NO;
    }
    
    if ([mdSegment length] == 0) {
        return NO;
    }
    
    //  - the length includes itself, and then write the data for the segment.
    if ([self writeWordToOutput:[mdSegment length] + 2] &&
        [self writeToOutput:mdSegment.bytes withLength:[mdSegment length]]) {
        [mdSegment setLength:0];
        inMarker = NO;
        return YES;
    }
    
    return NO;
}

/*
 *  Begin writing an entropy-encoded segment, which encodes bits at a time.
 */
-(BOOL) beginEntropyEncodedSegment
{
    if (inMarker || inECS) {
        return NO;
    }

    inECS = YES;
    
    if (isWrite) {
        curBitStreamByte = 0;
        curBit = 7;
    }
    
    return YES;
}

/*
 *  Write the specified number of least-significant bits from the supplied
 *  value to the output stream.
 */
-(BOOL) writeBits:(uint32_t) value ofLength:(NSUInteger) numBits
{
    unsigned char bytes[4];
    if (numBits > 32) {
        return NO;
    }
    
    NSUInteger remain = numBits;
    int pos = 0;
    while (remain > 0) {
        if (remain > 8) {
            bytes[pos] = (unsigned char) ((value >> (remain - 8)) & 0xFF);
            remain -= 8;
        }
        else {
            bytes[pos] = (unsigned char) ((value << (8 - remain)) & (0xFF & ~((1 << (8-remain))-1)));
            remain = 0;
        }
        pos++;
    }
    
    return [self writeBitsFromBuffer:bytes withNumBits:numBits];
}

/*
 *  Using a buffer of bytes, write from most-to-least significant bits to the output file.
 */
-(BOOL) writeBitsFromBuffer:(const unsigned char *) buffer withNumBits:(NSUInteger) numBits
{
    if (inMarker || !isWrite || !numBits || !buffer) {
        return NO;
    }
    
    //  - while there are more bits to write
    while (numBits) {
        unsigned char curByte = *buffer;
        for (int i = 0; i < 8 && numBits; i++) {
            curBitStreamByte |= (((curByte & (1 << (7-i))) >> (7-i)) << curBit);
            curBit--;

            //  - is the current byte filled?
            if (curBit < 0) {
                //  - yes, write it to the output stream.
                if (![self writeToOutput:&curBitStreamByte withLength:1]) {
                    return NO;
                }
                
                //  - stuff an extra byte when we just encoded an '0xFF'
                if (inECS && curBitStreamByte == 0xFF) {
                    curBitStreamByte = 0x00;
                    if (![self writeToOutput:&curBitStreamByte withLength:1]) {
                        return NO;
                    }
                }
                
                curBit = 7;
                curBitStreamByte = 0;
            }
            numBits--;
        }
        buffer++;
    }
    return YES;
}

/*
 *  Commit an entropy encoded segment.
 */
-(BOOL) commitEntropyEncodedSegment
{
    if (inMarker || !inECS) {
        return NO;
    }
    
    if (isWrite) {
        //  - check if padding is necessary
        if (curBit < 7 && ![self writeBits:0xFFFF ofLength:(NSUInteger) curBit + 1]) {
            return NO;
        }
    }
    else {
        //  - if we're on a non-byte boundary, we must discard the
        //    padding that would have come at the end.
        if ((curBit & 0x7) && ![self seekBits:(8 - (curBit & 0x7))]) {
            return NO;
        }
    }
    
    inECS = NO;
    return YES;
}

/*
 *  Retrieve the specified number of bits into the data buffer, but do
 *  not advance the internal pointer.
 */
-(BOOL) peekBits:(NSUInteger) numBits intoBuffer:(unsigned char *) buf ofLength:(NSUInteger) len
{
    NSUInteger neededLen = (numBits >> 3);
    if (numBits & 0x7) {
        neededLen++;
    }
    
    if (isWrite ||
        ((NSUInteger) curBit + numBits) > numInputBits ||
        neededLen > len) {
        return NO;
    }
    
    //  The interchange format is reasonably easy to seek through because most blocks of data
    //  are byte aligned.  Only the entropy-encoded data is freeform, but
    //  it still pads its final byte.
    
    NSInteger tmpOffset = curBit;         //  so the real value doesn't change during a peek operation
    int outIndex = 0;
    const unsigned char *bstream = ((const unsigned char *) mdInput.bytes);    
    
    //  - are we starting on a byte boundary requesting
    //    at least 8 bits?  If so, then pull bytes as fast as possible
    //  - this can only occur when we're not entropy decoding because when that is happening
    //    there are special markers to be on the lookout for.
    if (!inECS && (tmpOffset & 0x7) == 0 && numBits >= 8) {
        NSUInteger numBytes = numBits >> 3;
        memcpy(buf, &(bstream[tmpOffset >> 3]), numBytes);
        tmpOffset += (numBytes << 3);
        outIndex += numBytes;
        numBits &= 0x7;
    }
    
    //  - otherwise, grab the bits one at a time the hard way.
    unsigned char curByte = 0;
    unsigned char outByte = 0;
    int outBit = 7;
    BOOL first = YES;
    while (numBits) {
        if (((tmpOffset & 0x7) == 0) || first) {
            NSInteger idx = (tmpOffset >> 3);
            curByte       = bstream[idx];
            
            //  - check for byte stuffing and adjust accordingly
            if (inECS && curByte == 0x00 && idx > 0 && bstream[idx - 1] == 0xFF) {
                idx++;
                if (idx < [mdInput length]) {
                    curByte = bstream[idx];
                    tmpOffset += 8;
                }
                else {
                    //  - the end of the stream because we've exhausted the last
                    //    byte
                    return NO;
                }
            }
            first = NO;
        }
        
        int bitNum = 7 - (tmpOffset & 0x7);
        unsigned char setBit = (curByte & (1 << bitNum)) >> bitNum;
        outByte |= (setBit << outBit);
        
        outBit--;
        numBits--;
        tmpOffset++;
        
        if (!numBits || outBit < 0) {
            buf[outIndex] = outByte;
            outIndex++;
            outByte = 0;
            outBit = 7;
        }
    }
    
    return YES;
}

/*
 *  Retrieve the specified number of bits into the data buffer, _AND_
 *  advance the internal pointer.
 */
-(BOOL) readBits:(NSUInteger) numBits intoBuffer:(unsigned char *) buf ofLength:(NSUInteger) len
{
    if ([self peekBits:numBits intoBuffer:buf ofLength:len]) {
        return [self seekBits:(NSInteger) numBits];
    }
    return NO;
}

/*
 *  Read some number of bytes into the data buffer, _AND_ advance
 *  the internal pointer.
 */
-(BOOL) readBytes:(NSUInteger) numBytes intoBuffer:(unsigned char *) buf ofLength:(NSUInteger) len
{
    return [self readBits:numBytes << 3 intoBuffer:buf ofLength:len];
}

/*
 *  Read one word value.
 */
-(BOOL) getw:(uint16_t *) w
{
    if ([self peekw:w]) {
        return [self seekBits:sizeof(uint16_t) * 8];
    }
    return NO;
}

/*
 *  Peek at one word value.
 */
-(BOOL) peekw:(uint16_t *) w
{
    unsigned char buf[2];
    if ([self peekBits:16 intoBuffer:buf ofLength:2]) {
        *w = (buf[0] << 8) | buf[1];
        return YES;
    }
    return NO;
}

/*
 *  Seek in the in the input stream by the specified number of bits.
 *  - I left the signed value in this routine in case I decided to ever
 *    support a backwards seek.
 */
-(BOOL) seekBits:(NSInteger) numBits
{
    if (isWrite || numBits < 0) {
        return NO;
    }
    
    NSInteger newBit = curBit;
    if (inECS) {
        //  - while in ECS mode, we need to correctly seek past
        //    byte-stuffed values, which means that a 0x00 following
        //    a 0xFF is not counted with the seeking.
        const unsigned char *bstream = ((const unsigned char *) mdInput.bytes);
        while (numBits > 0) {
            BOOL hasMark = (bstream[newBit >> 3] == 0xFF) ? YES : NO;
            newBit += ((numBits > 8) ? 8 : numBits);
            
            if (hasMark && newBit <= numInputBits && bstream[newBit >> 3] == 0x00) {
                newBit += 8;        //  skip a stuffed byte when it is found;
            }
            
            numBits -= 8;
        }
    }
    else {
        newBit += numBits;
    }
    
    if (newBit < 0 || newBit > numInputBits) {
        return NO;
    }
    
    curBit = newBit;
    return YES;
}

/*
 *  Check for end of file.
 */
-(BOOL) isEOF
{
    if (!isWrite && (curBit < numInputBits)) {
        return NO;
    }
    return YES;
}

/*
 *  Peek into the stream and pull at least one bit and no more than 16.
 */
-(BOOL) peekUpTo16:(uint16_t *) w
{
    if (curBit >= numInputBits) {
        return NO;
    }
    
    NSUInteger toGrab = 16;
    if (toGrab > (numInputBits - curBit)) {
        toGrab = (NSUInteger) (numInputBits - curBit);
    }

    unsigned char buf[2] = {0, 0};
    if ([self peekBits:toGrab intoBuffer:buf ofLength:2]) {
        *w = (buf[0] << 8) | buf[1];
        return YES;
    }
    return NO;
}

/*
 *  Reset the internal pointer to the data.
 */
-(BOOL) reset
{
    if (isWrite) {
        return NO;
    }
    inMarker = NO;
    inECS = NO;
    
    //  - in read-only mode, we count from first to last instead of
    //    in bit order.
    curBit = 0;
    return YES;
}

/*
 *  Read from the stream, up to the specified number of bits.
 */
-(BOOL) readUpTo:(NSUInteger) count bitsIntoBuffer:(unsigned char *) buf ofLength:(NSUInteger) len
{
    if (curBit >= numInputBits) {
        return NO;
    }
    NSUInteger toGrab = count;
    if (toGrab > (numInputBits - curBit)) {
        toGrab = (NSUInteger) (numInputBits - curBit);
    }
    return [self readBits:toGrab intoBuffer:buf ofLength:len];
}

/*
 *  Return the number of bits remaining in the file to be read
 */
-(NSUInteger) bitsRemaining
{
    if (isWrite || curBit > numInputBits) {
        return 0;
    }
    return (NSUInteger) (numInputBits - curBit);
}

@end


/******************************
 RSI_file (internal)
 ******************************/
@implementation RSI_file (internal)

/*
 *  Write a word to the output stream.
 */
-(BOOL) writeWordToOutput:(uint16_t) w
{
    unsigned char buf[2];
    buf[0] = (unsigned char) ((w >> 8) & 0xFF);
    buf[1] = (unsigned char) (w & 0xFF);
    return [self writeToOutput:buf withLength:2];
}

@end


/******************************
 RSI_file (internal_shared)
 ******************************/
@implementation RSI_file (internal_shared)

/*
 *  Flush partially-written to the output file.
 */
-(BOOL) flush
{
    if (!isWrite) {
        return YES;
    }
    
    if (inMarker) {
        if (![self commitMarkerSegment]) {
            return NO;
        }
    }
    else if (inECS) {
        if (![self commitEntropyEncodedSegment]) {
            return NO;
        }
    }
    else if (curBit != 7) {
        return [self writeBits:0 ofLength:(NSUInteger) curBit+1];
    }
    
    return YES;
}

/*
 *  Write bytes to the output stream in sequence.
 */
-(BOOL) writeToOutput:(const unsigned char *) bytes withLength:(NSUInteger) len
{
    if (!isWrite || len == 0) {
        return NO;
    }
    
    [mdFile appendBytes:bytes length:len];
    return YES;
}

@end
