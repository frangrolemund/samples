//
//  RSI_file.h
//  RealSecureImage
//
//  Created by Francis Grolemund on 11/15/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RSI_file : NSObject
-(id) initForWrite;
-(NSUInteger) numBytesWritten;
-(id) initForReadWithData:(NSData *) d;
-(NSData *) fileData;
-(NSData *) flushedFileData; 
-(void) zeroFileData;

//  - write functions
-(BOOL) writeMarker:(uint16_t) marker;

-(BOOL) beginMarkerSegment:(uint16_t) marker;
-(BOOL) putc:(unsigned char) c;
-(BOOL) putw:(uint16_t) w;
-(BOOL) write:(const unsigned char *) bytes withLength:(NSUInteger) len;
-(BOOL) commitMarkerSegment;

-(BOOL) beginEntropyEncodedSegment;
-(BOOL) writeBits:(uint32_t) value ofLength:(NSUInteger) numBits;
-(BOOL) writeBitsFromBuffer:(const unsigned char *) buffer withNumBits:(NSUInteger) numBits;
-(BOOL) commitEntropyEncodedSegment;

-(BOOL) truncateTo:(NSUInteger) length;


//  - read functions
-(BOOL) peekBits:(NSUInteger) numBits intoBuffer:(unsigned char *) buf ofLength:(NSUInteger) len;
-(BOOL) readBits:(NSUInteger) numBits intoBuffer:(unsigned char *) buf ofLength:(NSUInteger) len;
-(BOOL) getw:(uint16_t *) w;
-(BOOL) peekw:(uint16_t *) w;
-(BOOL) seekBits:(NSInteger) numBits;
-(BOOL) isEOF;
-(BOOL) peekUpTo16:(uint16_t *) w;
-(BOOL) reset;
-(BOOL) readUpTo:(NSUInteger) count bitsIntoBuffer:(unsigned char *) buf ofLength:(NSUInteger) len;
-(NSUInteger) bitsRemaining;
-(BOOL) readBytes:(NSUInteger) numBytes intoBuffer:(unsigned char *) buf ofLength:(NSUInteger) len;

@end

@interface RSI_file (internal_shared)
-(BOOL) flush;
-(BOOL) writeToOutput:(const unsigned char *) bytes withLength:(NSUInteger) len;
@end

