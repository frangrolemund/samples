//
//  RSI_common.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 11/19/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import "RSI_common.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
#import <pthread.h>
#import "RSI_file.h"

// - locals
static pthread_rwlock_t keychainLock;

/***********************
 RSI_common
 ***********************/
@implementation RSI_common
/*
 *  Initialize this module.
 */
+(void) initialize
{
    // NOTE: I don't think it is responsible to assume that the SecItem APIs are thread safe because it isn't explicitly
    //       described as such in the documentation, so every call must be surrounded by the appropriate lock/unlock API
    //       calls to guarantee we never do anything squirley with the one location where we depend-on more than anything else.
    pthread_rwlock_init(&keychainLock, NULL);
}

/*
 *  Add a long value onto the provided data buffer.
 */
+(void) appendLong:(uint32_t) val toData:(NSMutableData *) md
{
    unsigned char buf[4];
    buf[0] = (val >> 24) & 0xFF;
    buf[1] = (val >> 16) & 0xFF;
    buf[2] = (val >> 8)  & 0xFF;
    buf[3] = (val & 0xFF);
    [md appendBytes:buf length:4];
}

/*
 *  Convert the next four bytes into a long value.
 */
+(uint32_t) longFromPtr:(const unsigned char *) ptr
{
    uint32_t ret = ((uint32_t) ptr[0] << 24) | ((uint32_t) ptr[1] << 16) | ((uint32_t) ptr[2] << 8) | (uint32_t) ptr[3];
    return ret;
}

/*
 *  Print bytes in a usable format for easy debugging.
 */
+(void) printBytes:(NSData *) d withTitle:(NSString *) title
{
    [RSI_common printBytes:d withMaxLength:0 andTitle:title];
}

/*
 *  Print bytes in a usable format for easy debugging.
 */
+(void) printBytes:(NSData *) d withMaxLength:(NSUInteger) length andTitle:(NSString *) title
{
    if (title) {
        NSLog(@"%@", title);
    }
    
    int sum = 0;
    NSUInteger toPrint = [d length];
    if (length && length < toPrint) {
        toPrint = length;
    }
    
    for (NSUInteger i = 0; i < toPrint; i+= 8) {
        NSString *line = @"";
        
        //  first generate the address of the line
        line = [line stringByAppendingFormat:@"%06X ", (unsigned int) i];
        
        //  now the hex values
        for (NSUInteger j = i; j < i + 8; j++) {
            if (j < toPrint) {
                unsigned char val = ((unsigned char *) [d bytes])[j];
                sum += val;
                line = [line stringByAppendingFormat:@"%02X ", (int) val];
            }
            else {
                line = [line stringByAppendingString:@"   "];
            }
        }
        
        line = [line stringByAppendingString:@" "];
        
        //  and the printable characters
        for (NSUInteger j = 0; j < 8 && (i + j) < toPrint; j++) {
            unsigned char val = ((unsigned char *) [d bytes])[i+j];
            if (val < 32 || val >= 127) {
                val = '.';
            }
            line = [line stringByAppendingFormat:@"%c", (char) val];
        }
        
        NSLog(@"%@", line);
    }
    
    NSLog(@"   - simple sum: %X", sum);
}

/*
 *  Compute a simple difference between the two buffers.
 */
+(BOOL) diffBytes:(NSData *) d1 withBytes:(NSData *) d2 andTitle:(NSString *) title
{
    BOOL isEqual = YES;

    const unsigned char *p1 = NULL, *p2 = NULL;
    NSUInteger len1 = 0, len2 = 0;
    
    if (d1) {
        p1 = [d1 bytes];
        len1 = [d1 length];
    }
    
    if (d2) {
        p2 = [d2 bytes];
        len2 = [d2 length];
    }

    NSUInteger i = 0;
    NSMutableArray *maDiff = [NSMutableArray array];
    while (i < len1 && i < len2) {
        NSString *line = @"";
        
        //  first generate the address of the line
        line = [line stringByAppendingFormat:@"%06X ", (unsigned int) i];
        
        //  now the hex values
        for (NSUInteger j = 0; j < 8; j++) {
            if (i >= len1 && i >= len2) {
                break;
            }
            
            if (i < len1 && i < len2 &&
                *p1 == *p2) {
                line = [line stringByAppendingString:@"   "];
            }
            else {
                line = [line stringByAppendingString:@"** "];
                isEqual = NO;
            }
            
            p1++;
            p2++;
            i++;
        }
        
        [maDiff addObject:line];
    }
    
    //  - only dump the map if they are different.
    if (!isEqual) {
        if (title) {
            NSLog(@"%@", title);
        }
        
        for (i = 0; i < [maDiff count]; i++) {
            NSString *s = [maDiff objectAtIndex:i];
            NSLog(@"%@", s);
        }
        
        [RSI_common printBytes:d1 withTitle:@"SOURCE of DIFF"];
        [RSI_common printBytes:d2 withTitle:@"DEST of DIFF"];
    }
    
    return isEqual;
}

/*
 *  Lock the keychain for reading.
 */
+(void) RDLOCK_KEYCHAIN
{
    pthread_rwlock_rdlock(&keychainLock);
}

/*
 *  Lock the keychain for read/write.
 */
+(void) WRLOCK_KEYCHAIN
{
    pthread_rwlock_wrlock(&keychainLock);
}

/*
 *  Unlock exclusive keychain access
 */
+(void) UNLOCK_KEYCHAIN
{
    pthread_rwlock_unlock(&keychainLock);
}

/*
 *  Convert a data buffer into a hex string.
 */
+(NSString *) hexFromData:(NSData *) d
{
    NSString *sTmp = @"";
    for (int i = 0; i < [d length]; i++) {
        unsigned char b = ((unsigned char *) d.bytes)[i];
        sTmp = [sTmp stringByAppendingFormat:@"%02X", b];
    }
    return sTmp;
}

/*
 *  Return a base-64 encoded item from the supplied data.
 */
+(NSString *) base64FromData:(NSData *) d
{
    // - This uses a URL and filename-safe alphabet as defined in RFC-4648 to ensure this
    //   can be used as a filename if need be.  I wasn't sure whether NSData's native support would
    //   always guarantee that.
    const char b64_index[64] = {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
                                'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
                                '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
                                '-', '_'};
    RSI_file *f            = [[RSI_file alloc] initForReadWithData:d];
    unsigned char idx      = 0;
    NSUInteger bitsToRead  = 6;
    NSMutableString *msRet = [NSMutableString string];
    for (;;) {
        idx = 0;
        if (![f readBits:bitsToRead intoBuffer:&idx ofLength:sizeof(idx)]) {
            bitsToRead = MIN([f bitsRemaining], 6);
            if (bitsToRead) {
                if (![f readBits:bitsToRead intoBuffer:&idx ofLength:sizeof(idx)]) {
                    break;
                }
            }
            else {
                // - end of the stream officially.
                break;
            }
        }
        
       idx = idx >> (8 - bitsToRead);         // - readBits always unpacks in bit order.
       [msRet appendFormat:@"%c", b64_index[MIN(idx, 63)]];
    }
    [f release];
    return msRet;
}

@end

/***********************
 RSI_SHA1
 ***********************/
@implementation RSI_SHA1
{
    CC_SHA1_CTX      ctx;
    RSI_securememory *hash;
}

/*
 *  Initialize the hashing object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        hash = nil;
        [self reset];
    }
    return self;
}

/*
 *  Finish the process
 */
-(void) buildHash
{
    if (!hash) {
        hash = [[RSI_securememory alloc] initWithLength:[RSI_SHA1 SHA_LEN]];
        CC_SHA1_Final((unsigned char *) hash.mutableBytes, &ctx);
    }
}

/*
 *  Free the hashing object
 */
-(void) dealloc
{
    [hash release];
    hash = nil;
    
    [super dealloc];
}

/*
 *  Build a SHA1 hash of the input data in one pass.
 */
+(RSI_securememory *) hashFromInput:(NSData *)input
{
    RSI_securememory *smHash = [RSI_securememory dataWithLength:[RSI_SHA1 SHA_LEN]];
    CC_SHA1(input.bytes, (CC_LONG) [input length], smHash.mutableBytes);
    return smHash;
}

/*
 *  Return the length of a SHA1 hash.
 */
+(NSUInteger) SHA_LEN
{
    return CC_SHA1_DIGEST_LENGTH;
}

/*
 *  Return the length of a base-64 version of the hash.
 */
+(NSUInteger) SHA_B64_STRING_LEN
{
    return (([RSI_SHA1 SHA_LEN] * 8) + 7) / 6;
}

/*
 *  The hash padding is important for RSA signing.
 */
+(SecPadding) SEC_PADDING
{
    return kSecPaddingPKCS1SHA1;
}

/*
 *  Reset the hash
 */
-(void) reset
{
    CC_SHA1_Init(&ctx);
    [hash release];
    hash = nil;
}

/*
 *  Update an incremental hash.
 */
-(void) updateWithData:(NSData *) d
{
    if (!hash) {
        [self update:d.bytes withLength:[d length]];
    }
}

/*
 *  Update an incremental hash
 */
-(void) update:(const void *) ptr withLength:(NSUInteger) length
{
    if (!hash) {
        CC_SHA1_Update(&ctx, ptr, (CC_LONG) length);
    }
}

/*
 *  Return the hash of the data.
 */
-(RSI_securememory *) hash
{
    if (!hash) {
        [self buildHash];
    }
    return [[hash retain] autorelease];
}

/*
 *  Return a string version of the hash in hex.
 */
-(NSString *) stringHash
{
    RSI_securememory *smHash = [self hash];
    if (!smHash) {
        return nil;
    }
    
    return [RSI_common hexFromData:smHash.rawData];
}

/*
 *  Return a base-64 string version of the hash.
 */
-(NSString *) base64StringHash
{
    RSI_securememory *smHash = [self hash];
    if (!smHash) {
        return nil;
    }
    
    return [RSI_common base64FromData:smHash.rawData];
}
@end

/***********************
 RSI_SHA256
 ***********************/
@implementation RSI_SHA256
{
    CC_SHA256_CTX    ctx;
    RSI_securememory *hash;
}

/*
 *  Initialize the hashing object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        hash = nil;
        [self reset];
    }
    return self;
}

/*
 *  Finish the process
 */
-(void) buildHash
{
    if (!hash) {
        hash = [[RSI_securememory alloc] initWithLength:[RSI_SHA256 SHA_LEN]];
        CC_SHA256_Final((unsigned char *) hash.mutableBytes, &ctx);
    }
}

/*
 *  Free the hashing object
 */
-(void) dealloc
{
    [hash release];
    hash = nil;
    
    [super dealloc];
}

/*
 *  Build a SHA1 hash of the input data in one pass.
 */
+(RSI_securememory *) hashFromInput:(NSData *)input
{
    RSI_securememory *smHash = [RSI_securememory dataWithLength:[RSI_SHA256 SHA_LEN]];
    CC_SHA256(input.bytes, (CC_LONG) [input length], smHash.mutableBytes);
    return smHash;
}

/*
 *  Return the length of a SHA256 hash.
 */
+(NSUInteger) SHA_LEN
{
    return CC_SHA256_DIGEST_LENGTH;
}

/*
 *  Return the length of a base-64 version of the hash.
 */
+(NSUInteger) SHA_B64_STRING_LEN
{
    return (([RSI_SHA256 SHA_LEN] * 8) + 7) / 6;
}

/*
 *  The hash padding is important for RSA signing.
 */
+(SecPadding) SEC_PADDING
{
    return kSecPaddingPKCS1SHA256;
}

/*
 *  Reset the hash
 */
-(void) reset
{
    CC_SHA256_Init(&ctx);
    [hash release];
    hash = nil;
}

/*
 *  Update an incremental hash.
 */
-(void) updateWithData:(NSData *) d
{
    if (!hash) {
        [self update:d.bytes withLength:[d length]];
    }
}

/*
 *  Update an incremental hash
 */
-(void) update:(const void *) ptr withLength:(NSUInteger) length
{
    if (!hash) {
        CC_SHA256_Update(&ctx, ptr, (CC_LONG) length);
    }
}

/*
 *  Return the hash of the data.
 */
-(RSI_securememory *) hash
{
    if (!hash) {
        [self buildHash];
    }
    return [[hash retain] autorelease];
}

/*
 *  Return a string version of the hash in hex.
 */
-(NSString *) stringHash
{
    RSI_securememory *smHash = [self hash];
    if (!smHash) {
        return nil;
    }
    
    return [RSI_common hexFromData:smHash.rawData];
}

/*
 *  Return a base-64 string version of the hash.
 */
-(NSString *) base64StringHash
{
    RSI_securememory *smHash = [self hash];
    if (!smHash) {
        return nil;
    }
    
    return [RSI_common base64FromData:smHash.rawData];
}
@end

/*************************
 RSI_SHA_SECURE
 *************************/
@implementation  RSI_SHA_SECURE
// - no impl, use the default behavior of whatever is defined in the base!
@end

/*************************
 RSI_SHA_SCRAMBLE
 *************************/
@implementation  RSI_SHA_SCRAMBLE
// - no impl, use the default behavior of whatever is defined in the base!
@end

/*************************
 RSI_SHA_SEAL
 *************************/
@implementation  RSI_SHA_SEAL
// - no impl, use the default behavior of whatever is defined in the base!
@end

