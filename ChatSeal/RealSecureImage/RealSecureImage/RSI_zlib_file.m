//
//  RSI_zlib_file.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/11/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "RSI_zlib_file.h"
#import "RSI_error.h"

//  - constants
static const NSUInteger RSI_ZF_CACHESIZE = (1024 * 64);

static voidpf ZLIB_zalloc(voidpf opaque, uInt items, uInt size)
{
    return calloc(items, size);
}

static void ZLIB_zfree(voidpf opaque, voidpf address) {
    return free(address);
}

/******************************
 RSI_zlib_file
 ******************************/
@implementation RSI_zlib_file
/*
 *  Object attributes
 */
{
    //  - these attributes are only used for
    //    writing.
    BOOL                       isInit;
    z_stream                   zOutStream;
    NSMutableData              *outBuffer;
    RSI_compression_level_e    level;
    int                        windowBits;
    RSI_compression_strategy_e strategy;
    NSMutableData              *outCache;
    unsigned char              *cacheBegin;
    unsigned char              *cacheCur;
    unsigned char              *cacheEnd;
}

/*
 *  Initialze the object.
 *  - returns nil and autoreleases the object if an error occurs.
 */
-(id) initForWriteWithLevel:(RSI_compression_level_e) l andWindowBits:(int) b andStategy:(RSI_compression_strategy_e) s withError:(NSError **) err
{
    self = [super initForWrite];
    if (self) {
        isInit = NO;
        
        memset(&zOutStream, 0, sizeof(z_stream));
        outBuffer  = [[NSMutableData alloc] initWithLength:RSI_ZLIB_BUFLEN];
        level      = l;
        windowBits = b;
        strategy   = s;
        outCache   = [[NSMutableData alloc] initWithLength:RSI_ZF_CACHESIZE];
        cacheBegin = cacheCur = (unsigned char *) outCache.mutableBytes;
        cacheEnd   = cacheCur + RSI_ZF_CACHESIZE;
        
        zOutStream.zalloc = ZLIB_zalloc;
        zOutStream.zfree  = ZLIB_zfree;
        zOutStream.opaque = 0;
        
        zOutStream.next_out =  outBuffer.mutableBytes;
        zOutStream.avail_out = RSI_ZLIB_BUFLEN;
        
        int ret = deflateInit2(&zOutStream, level, Z_DEFLATED, windowBits, 9, strategy);
        if (ret == Z_OK) {
            isInit = YES;
        }
        else {
            [RSI_error fillError:err withCode:RSIErrorInvalidArgument andZlibError:ret];
            isInit = NO;
            
            [self autorelease];
            return nil;
        }
    }
    return self;
}

/*
 *  Read from a compressed stream.
 *  - returns nil and autoreleases the object if an error occurs
 */
-(id) initForReadWithData:(NSData *) dCompressed andError:(NSError **) err
{
    z_stream zread;

    //  - In order for reading to work at the moment, we need to pull all the compressed data
    //    at once and store that.  This is less than ideal, but reading is only currently used
    //    in the tests to verify writing (which itself is used).
    //  - the output data MUST be a stack variable because the super object hasn't been
    //    initialized yet.
    NSMutableData *dFile = nil;
    if (dCompressed && [dCompressed length] > 0) {
        memset(&zread, 0, sizeof(z_stream));
        
        dFile = [[NSMutableData alloc] init];
    
        zread.zalloc = ZLIB_zalloc;
        zread.zfree  = ZLIB_zfree;
        zread.opaque = 0;
    
        zread.next_in  = (Bytef *) dCompressed.bytes;
        zread.avail_in = (uInt) [dCompressed length];
        
        int ret = inflateInit2(&zread, 15);
        if (ret == Z_OK) {
            do {
                [dFile setLength:[dFile length] + RSI_ZLIB_BUFLEN];
                zread.avail_out = RSI_ZLIB_BUFLEN;
                zread.next_out = ((unsigned char *) [dFile mutableBytes]) + [dFile length] - RSI_ZLIB_BUFLEN;
                ret = inflate(&zread, Z_NO_FLUSH);
            } while (ret == Z_OK);
            
            if (ret == Z_STREAM_END) {
                [dFile setLength:zread.total_out];
            }
            
            inflateEnd(&zread);
        }
        
        if (ret != Z_OK && ret != Z_STREAM_END) {
            [dFile release];
            dFile = nil;
            [RSI_error fillError:err withCode:RSIErrorFileReadFailed andZlibError:ret];
        }
    }
    else {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
    }
    
    //  - initialize the super object with all the data.
    self = [super initForReadWithData:dFile];
    [dFile release];
    
    if (self) {
        isInit = NO;
        if (!dFile) {
            return nil;
        }
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [outBuffer release];
    outBuffer = nil;
    
    [outCache release];
    outCache = nil;
    
    if (isInit) {
        deflateEnd(&zOutStream);
    }
    
    [super dealloc];
}

/*
 *  Handle deflation, which includes appending 
 *  data to the output file.
 *  - assumes next_in and avail_in are set appropriately
 */
-(int) deflateInputWithFlush:(int) flush
{
    if (!isInit || zOutStream.avail_out != RSI_ZLIB_BUFLEN) {
        return Z_ERRNO;
    }
    
    int ret = Z_OK;
    while (ret == Z_OK && (zOutStream.avail_in > 0 || flush == Z_FINISH)) {
        ret = deflate(&zOutStream, flush);
        if (ret == Z_OK || ret == Z_STREAM_END) {
            NSUInteger num_bytes = (NSUInteger) (zOutStream.next_out - (Bytef *) outBuffer.mutableBytes);
            if (num_bytes) {
                if (![super writeToOutput:outBuffer.bytes withLength:num_bytes]) {
                    return Z_ERRNO;
                }
            }
            
            zOutStream.next_out = (Bytef *) outBuffer.mutableBytes;
            zOutStream.avail_out = RSI_ZLIB_BUFLEN;
        }
    }
    return ret;
}

/*
 *  Deflate whatever is in the cache.
 */
-(BOOL) sendPendingCacheToOutput
{
    uint32_t toWrite = (uint32_t) (cacheCur - cacheBegin);
    if (toWrite) {
        zOutStream.next_in  = cacheBegin;
        zOutStream.avail_in = toWrite;
        int rc = [self deflateInputWithFlush:Z_NO_FLUSH];
        if (rc != Z_OK) {
            return NO;
        }
        cacheCur = cacheBegin;
    }
    return YES;
}

/*
 *  Flush partially-written to the output file.
 */
-(BOOL) flush
{
    //  - first make sure that all relevant data is
    //    sent to the compressor
    BOOL ret = [super flush];
    if (ret) {
        //  - make sure the cache is empty
        if (![self sendPendingCacheToOutput]) {
            return NO;
        }
        
        //  - then instruct it to finalize the stream.
        int zrc = [self deflateInputWithFlush:Z_FINISH];
        if (zrc != Z_STREAM_END) {
            return NO;
        }
    }
    return ret;
}

/*
 *  Write bytes to the output stream in sequence.
 */
-(BOOL) writeToOutput:(const unsigned char *) bytes withLength:(NSUInteger) len
{
    if (!isInit) {
        return NO;
    }
    
    while (len > 0) {
        NSUInteger toWrite = len;
        if (toWrite > (cacheEnd - cacheCur)) {
            toWrite = (uint32_t) (cacheEnd - cacheCur);
        }
        
        memcpy(cacheCur, bytes, toWrite);
        cacheCur += toWrite;
        if (cacheCur >= cacheEnd) {
            if (![self sendPendingCacheToOutput]) {
                return NO;
            }
        }
        
        bytes += toWrite;
        len -= toWrite;
    }

    return YES;
}

@end
