


//
//  RSI_secure_props.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/15/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "RSI_secure_props.h"
#import "RSI_error.h"
#import "RSI_common.h"
#import "RSI_zlib_file.h"
#import <zlib.h>

//  - shared symbols
static NSString *RSI_SECURE_ROOT   = @"sroot";
static const BOOL RSI_SP_BIN_PROPS = YES;

//  - forward declarations
@interface RSI_secure_props (internal)
-(BOOL) buildSecureHeader:(RSI_securememory *) sm andPayloadLength:(NSUInteger) lenPayload andPayloadCRC:(uLong) crcPayload withError:(NSError **) err;
-(BOOL) appendRandomPad:(RSI_securememory *) sm withError:(NSError **) err;
-(BOOL) buildPropertyBlob:(RSI_securememory *)smBlob fromData:(NSData *)d withCRC:(uLong *)crc andError:(NSError **)err;
+(BOOL) validateSecureHeader:(NSData *) smHeader forVersion:(uint16_t) ver returningLength:(uint32_t *) len andReturningCRC:(uint32_t *) crc andReturningType:(uint16_t *) propType
                   withError:(NSError **) err;
-(BOOL) isSupportedProps:(NSData *) d withPayloadLength:(uint32_t *) len andPayloadCRC:(uint32_t *) crc andPayloadType:(uint16_t *) propType withError:(NSError **) err;
-(NSData *) findPropertyBlob:(NSData *) smBlob withCRC:(uint32_t) crc andError:(NSError **) err;
@end

/******************************
 RSI_secure_props
 - the point of this class is to provide simple encryption and obfuscation to property list management.  As I
   investigated encrypting property lists before, I was concerned that their repeatable headers (even in binary)
   could be used to infer the encryption keys.  To address that problem, I'm including random padding before and
   after the actual payload.  
 - additionally, I wanted a quick way to identify valid secure archives without needing to decrypt the whole thing.  
   To that end, I created a fairly small and simple header that can fit in a single PNG scanline that is decrypted first.  If
   its CRC of a series of random bytes matches, then we can assume the key works.  This should allow reasonably efficient tests
   of images, even streamed from the internet, without needing to pull the entire thing down and open it completely only to find
   that the image is not recognized.  
 ******************************/
@implementation RSI_secure_props

/*
 *  Build an archived data stream.
 *  - when this method is used by external entities, the CRC prefix must be used or a decryption failure
 *    will likely result in a major problem while parsing the data because the data could be garbage and
 *    indirect off into the ether.
 */
+(BOOL) buildArchiveWithProperties:(NSObject *) props intoData:(RSI_securememory *) codedData asBinary:(BOOL) asBinary withCRCPRefix:(BOOL) hasPrefix andError:(NSError **) err
{
    BOOL ret = YES;
    RSI_securememory *secMemTmp = [[RSI_securememory alloc] init];

    //  - build a sequence of characters
    NSKeyedArchiver *archiver = nil;
    @try {
        archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:secMemTmp.rawData];
        [archiver setOutputFormat:asBinary ? NSPropertyListBinaryFormat_v1_0 : NSPropertyListXMLFormat_v1_0];
        [archiver encodeObject:props forKey:RSI_SECURE_ROOT];
        [archiver finishEncoding];
    }
    @catch (NSException *e) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSecureProps andFailureReason:@"Failed to create the secure property list."];
        ret = NO;
    }
    [archiver release];
    
    //  - if the data was archived successfully, then identify it as compressed or uncompressed.
    NSUInteger lenProperties = [secMemTmp.rawData length];
    if (ret) {
        [codedData setLength:0];
        
        RSI_zlib_file *zfile = nil;
        NSData *dFile        = secMemTmp.rawData;
        BOOL hasCompression  = NO;
        if (!asBinary) {
            hasCompression = YES;
            zfile = [[RSI_zlib_file alloc] initForWriteWithLevel:RSI_CL_BEST andWindowBits:15 andStategy:RSI_CS_FIXED withError:err];
            if (zfile) {
                if ([zfile writeToOutput:(unsigned char *) [secMemTmp bytes] withLength:[secMemTmp length]]) {
                    dFile = [zfile fileData];
                }
                else {
                    ret = NO;
                }
            }
            else {
                ret = NO;
            }
        }

        if (ret && dFile) {
            if (hasPrefix) {
                uLong crc = crc32(0, dFile.bytes, (uInt) [dFile length]);
                [RSI_common appendLong:(uint32_t) crc toData:codedData.rawData];
            }
            
            [RSI_common appendLong:hasCompression ? 1 : 0 toData:codedData.rawData];
            [RSI_common appendLong:(uint32_t) lenProperties toData:codedData.rawData];             // the length must be the length before compression.
            [codedData appendBytes:dFile.bytes length:[dFile length]];
        }
        else {
            [RSI_error fillError:err withCode:RSIErrorFileWriteFailed];
        }
        
        [zfile release];
    
    }
    
    [secMemTmp release];
    
    return ret;
}

/*
 *  Where possible, use this variant, but there are a couple cases where the binary flavor must be explicitly chosen.
 */
+(BOOL) buildArchiveWithProperties:(NSObject *) props intoData:(RSI_securememory *) codedData withCRCPrefix:(BOOL) hasPrefix andError:(NSError **) err
{
    // - the XML format is really expensive to parse on a real device, so I'm reverting to all
    //   binary since openness isn't an issue at the moment.
    return [RSI_secure_props buildArchiveWithProperties:props intoData:codedData asBinary:RSI_SP_BIN_PROPS withCRCPRefix:hasPrefix andError:err];
}

/*
 *  Parse an archive created with buildArchiveWithProperties.
 */
+(NSObject *) parseArchiveFromData:(NSData *) d withCRCPrefix:(BOOL) hasPrefix andError:(NSError **) err
{
    NSObject *ret = nil;
    if (!d || [d length] < 4) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSecureProps andFailureReason:@"Truncated properties."];
        return nil;
    }
    
    //  - figure out if this is a compressed archive or not
    const unsigned char *ptr = (const unsigned char *) d.bytes;
    
    //  - if this archive begins with a CRC, compute that now
    if (hasPrefix) {
        if ([d length] < 8) {
            [RSI_error fillError:err withCode:RSIErrorInvalidSecureProps andFailureReason:@"Truncated properties."];
            return nil;            
        }
        
        uint32_t expectedCRC = [RSI_common longFromPtr:ptr];
        uLong crc = crc32(0, ptr+12, (uInt) [d length]-12);
        if ((uint32_t) crc != expectedCRC) {
            [RSI_error fillError:err withCode:RSIErrorInvalidSecureProps andFailureReason:@"CRC failure in prefix."];
            return nil;
        }
        ptr+=4;
    }
    
    BOOL hasCompression = [RSI_common longFromPtr:ptr];
    ptr                 += 4;
    uint32_t len        = [RSI_common longFromPtr:ptr];
    
    RSI_securememory *secMem = nil;
    NSData *dArchive = [NSData dataWithBytesNoCopy:(void *) ptr+4 length:[d length] - 4 freeWhenDone:NO];
    if (hasCompression) {
        //  - a length signals that the data is compressed
        RSI_zlib_file *zfile = [[RSI_zlib_file alloc] initForReadWithData:dArchive andError:nil];
        secMem = [[RSI_securememory alloc] initWithLength:len];
        
        if (zfile && [zfile readBytes:len intoBuffer:secMem.mutableBytes ofLength:len]) {
            dArchive = secMem.rawData;
        }
        else {
            dArchive = nil;
        }
        [zfile release];
    }
    else {
        if ([dArchive length] > len) {
            dArchive = [NSData dataWithBytes:dArchive.bytes length:len];
        }
    }
    
    //  - parse the content of the archive
    if (dArchive) {
        NSKeyedUnarchiver *unarchiver = nil;
        @try {
            unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:dArchive];
            NSObject *root = [unarchiver decodeObjectForKey:RSI_SECURE_ROOT];
            if (root) {
                ret = root;
            }
            [unarchiver finishDecoding];
        }
        @catch (NSException *exception) {
            //  - don't let any exceptions bubble up any farther.
        }
        [unarchiver release];
    }
    
    [secMem release];
    
    if (!ret) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSecureProps andFailureReason:@"Format error."];
    }
    return ret;
}

/*
 *  The property header is used only for identification and
 *  does not include any property data.  Its purpose is to make
 *  it very fast to determine if a given key can decrypt the
 *  payload.  The header is a multiple of the AES block size
 *  and contains random quantitative envidence.
 */
+(NSUInteger) propertyHeaderLength
{
    //  - The AES block size is 16 bytes, which means that
    //    this header is 64.  We use a multiple of the block
    //    size because we use PKCS7 padding if it isn't.  
    return [RSI_symcrypt blockSize] << 2;
}

/*
 *  Check if the data buffer is expected to be secure.
 */
+(BOOL) isValidSecureProperties:(NSData *) d forVersion:(uint16_t) v usingKey:(RSI_symcrypt *) key andReturningType:(uint16_t *) propType withError:(NSError **) err
{
    RSI_secure_props *sp = [[RSI_secure_props alloc] initWithType:0 andVersion:v andKey:key];
    BOOL ret = [sp isSupportedProps:d andReturningType:propType withError:err];
    [sp release];
    return ret;
}

/*
 *  A quick pass of secure property decryption.
 */
+(NSArray *) decryptIntoProperties:(NSData *) d forType:(uint16_t) t andVersion:(uint16_t) v usingKey:(RSI_symcrypt *) key withError:(NSError **) err
{
    NSArray *ret = nil;

    RSI_secure_props *sp = [[RSI_secure_props alloc] initWithType:t andVersion:v andKey:key];
    ret = [sp decryptIntoProperties:d withError:err];
    [sp release];
    return ret;
}

/*
 *  A quick pass of secure property encryption.
 */
+(NSData *) encryptWithProperties:(NSArray *) props forType:(uint16_t) t andVersion:(uint16_t) v usingKey:(RSI_symcrypt *) key withError:(NSError **) err
{
    NSData *ret = nil;
    
    RSI_secure_props *sp = [[RSI_secure_props alloc] initWithType:t andVersion:v andKey:key];
    ret = [sp encryptWithProperties:props withError:err];
    [sp release];
    return ret;
}

/*
 *  A quick pass of secure data decryption.
 */
+(RSI_securememory *) decryptIntoData:(NSData *) d forType:(uint16_t) t andVersion:(uint16_t) v usingKey:(RSI_symcrypt *) key withError:(NSError **) err
{
    RSI_securememory *ret = nil;
    
    RSI_secure_props *sp = [[RSI_secure_props alloc] initWithType:t andVersion:v andKey:key];
    ret = [sp decryptIntoData:d andError:err];
    [sp release];
    return ret;
}

/*
 *  A quick pass of secure data encryption.
 */
+(NSData *) encryptWithData:(NSData *) d forType:(uint16_t) t andVersion:(uint16_t) v usingKey:(RSI_symcrypt *) key withError:(NSError **) err
{
    NSData *ret = nil;
    
    RSI_secure_props *sp = [[RSI_secure_props alloc] initWithType:t andVersion:v andKey:key];
    ret = [sp encryptWithData:d withError:err];
    [sp release];
    return ret;
}


/*
 *  Initialize the object. 
 */
-(id) initWithType:(uint16_t) t andVersion:(uint16_t) v andKey:(RSI_symcrypt *) k
{
    self = [super init];
    if (self) {
        propListType = t;
        version      = v;
        key          = [k retain];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [key release];
    key = nil;
    
    [super dealloc];
}

/*
 *  Encrypts a secure property list and returns the resultant data.
 */
-(NSData *) encryptWithProperties:(NSArray *) props withError:(NSError **) err
{    
    NSData *dRet = nil;
    RSI_securememory *codedData = [[RSI_securememory alloc] init];
    
    if ([RSI_secure_props buildArchiveWithProperties:props intoData:codedData withCRCPrefix:NO andError:err]) {
        dRet = [self encryptWithData:codedData.rawData withError:err];
    }
    [codedData release];

    return dRet;
}

/*
 *  Encrypts a data block and returns the result.
 */
-(NSData *) encryptWithData:(NSData *) d withError:(NSError **) err
{
    NSMutableData *dRet = nil;
    RSI_securememory *smHdr = [[RSI_securememory alloc] init];
    RSI_securememory *smProps = [[RSI_securememory alloc] init];
    NSMutableData *encryptedHdr = [[NSMutableData alloc] init];
    NSMutableData *encryptedPayload = [[NSMutableData alloc] init];
    
    // - the final result has two pieces, a header and a payload
    // - the payload's encrypted length is stored in the header along with
    //   its CRC, which does double duty of tying the two blobs together, but
    //   also ensures that during decryption, any extaneous data can be ignored.
    // - packed images will almost always provide extra data for decryption.
    uLong crc             = 0;
    NSUInteger payloadLen = 0;
    if ([self buildPropertyBlob:smProps fromData:d withCRC:&crc andError:err]) {
        //  - encrypt the property blob
        if (key) {
            if ([key encrypt:[smProps rawData] intoBuffer:encryptedPayload withError:err]) {
                payloadLen = [encryptedPayload length];
            }
        }
        else {
            payloadLen = [smProps length];
        }
        
        //  - now build the secure header
        if (payloadLen && [self buildSecureHeader:smHdr andPayloadLength:payloadLen andPayloadCRC:crc withError:err]) {
            //  - and encrypt/pack everything
            if (key) {
                if ([key encrypt:[smHdr rawData] intoBuffer:encryptedHdr withError:err]) {
                    dRet = [NSMutableData data];
                    [dRet appendData:encryptedHdr];
                    [dRet appendData:encryptedPayload];
                }
            }
            else {
                dRet = [NSMutableData data];
                [smHdr setLength:[RSI_secure_props propertyHeaderLength]];      //  unencrypted headers must be explicitly padded
                [dRet appendData:[smHdr rawData]];
                [dRet appendData:[smProps rawData]];
            }
        }
    }
    
    [encryptedPayload release];
    [encryptedHdr release];
    [smProps release];
    [smHdr release];
    
    return dRet;
}

/*
 *  Decrypts a buffer into a secure property list.
 */
-(NSArray *) decryptIntoProperties:(NSData *) d withError:(NSError **) err
{
    return [self decryptIntoProperties:d withDeferredTypeChecking:nil andError:err];
}

/*
 *  Decrypts a buffer into a secure property list and optionally allows the caller to validate
 *  the type instead of doing it in place here.
 */
-(NSArray *) decryptIntoProperties:(NSData *) d withDeferredTypeChecking:(uint16_t *) propType andError:(NSError **) err;
{
    NSArray *ret = nil;
    RSI_securememory *sm = [self decryptIntoData:d withDeferredTypeChecking:propType andError:err];
    if (sm) {
        NSObject *obj = [RSI_secure_props parseArchiveFromData:sm.rawData withCRCPrefix:NO andError:nil];
        if ([obj isKindOfClass:[NSArray class]]) {
            ret = (NSArray *) obj;
        }
        else {
            [RSI_error fillError:err withCode:RSIErrorInvalidSecureProps andFailureReason:@"Format error."];
        }
    }
    return ret;
}

/*
 *  Decrypts a buffer into a data object.
 */
-(RSI_securememory *) decryptIntoData:(NSData *) d andError:(NSError **) err
{
    return [self decryptIntoData:d withDeferredTypeChecking:nil andError:err];
}

/*
 *  Decrypts a buffer into a data buffer and optionally allows the caller to validate
 *  the type instead of doing it in place here.
 */
-(RSI_securememory *) decryptIntoData:(NSData *) d withDeferredTypeChecking:(uint16_t *) propType andError:(NSError **) err
{
    uint16_t embeddedType = 0;
    uint32_t embeddedLen = 0;
    uint32_t embeddedCRC = 0;
    if (![self isSupportedProps:d withPayloadLength:&embeddedLen andPayloadCRC:&embeddedCRC andPayloadType:&embeddedType withError:err]) {
        return nil;
    }
    
    //  - when a return pointer for the property type exists, that means the caller
    //    is going to validate, otherwise we need to do it now.
    if (propType) {
        *propType = embeddedType;
    }
    else {
        if (embeddedType != propListType) {
            [RSI_error fillError:err withCode:RSIErrorSecurePropsVersionMismatch];
            return nil;
        }
    }
    
    NSUInteger hdrLen = [RSI_secure_props propertyHeaderLength];
    if (hdrLen + embeddedLen > [d length]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSecureProps andFailureReason:@"Truncated payload."];
        return nil;
    }
    
    RSI_securememory *ret = nil;
    NSData *dPropBlob = nil;
    NSData *dPayloadBefore = [NSData dataWithBytesNoCopy:(unsigned char *) d.bytes + hdrLen length:embeddedLen freeWhenDone:NO];
    if (key) {
        RSI_securememory *smPayload = [[RSI_securememory alloc] init];
        if ([key decrypt:dPayloadBefore intoBuffer:smPayload withError:err] &&
            (dPropBlob = [self findPropertyBlob:smPayload.rawData withCRC:embeddedCRC andError:err])) {
            ret = [RSI_securememory dataWithData:dPropBlob];
        }
        else {
            [RSI_error fillError:err withCode:RSIErrorInvalidSecureProps andFailureReason:err ? [*err localizedDescription] : @"Decryption failed."];
        }
        [smPayload release];        
    }
    else {
        if ((dPropBlob = [self findPropertyBlob:dPayloadBefore withCRC:embeddedCRC andError:err])) {
            ret = [RSI_securememory dataWithData:dPropBlob];
        }
    }
    
    return ret;    
}

/*
 *  Verifies that the given buffer begins with a secure property header of the right
 *  format.
 *  - this doesn't verify the type so that this method can be used in a general purpose identification
 *    loop for many different secure property types at the same version.
 */
-(BOOL) isSupportedProps:(NSData *) d andReturningType:(uint16_t *) propType withError:(NSError **) err
{
    return [self isSupportedProps:d withPayloadLength:nil andPayloadCRC:nil andPayloadType:propType withError:err];
}

@end

/******************************
 RSI_secure_props (internal)
 ******************************/
@implementation RSI_secure_props (internal)

/*
 *  A secure header is a simple, but important construct.  It will consist of a series of random 
 *  bytes with the embedded property list type/version and a CRC at the end.  When reading it, if the
 *  expected version and type don't match or the CRC doesn't match the bytes, then
 *  we don't have the data we need.  I'm going to assume that the chances of collisions
 *  are very small since the buffer is sufficiently large.
 *  - in order to minimize the chance of a predictable layout aiding in reverse engineering 
 *    the symmetric key, I'm going to checksum only 24 bytes of the full sequence and that
 *    series of bytes is randomly determined as well as the location of the CRC.
 */
-(BOOL) buildSecureHeader:(RSI_securememory *) sm andPayloadLength:(NSUInteger) lenPayload andPayloadCRC:(uLong) crcPayload withError:(NSError **) err
{
    //  - get the random sequence of bytes first.
    NSUInteger plen = [RSI_secure_props propertyHeaderLength] - 1;   //  subtract one to ensure PKCS7 padding doesn't extend past the header len
    [sm setLength:plen];
    int ret = SecRandomCopyBytes(kSecRandomDefault, plen, sm.mutableBytes);
    if (ret != 0) {
        [RSI_error fillError:err withCode:RSIErrorCryptoFailure andFailureReason:@"Failed to generate a secure byte sequence."];
        return NO;
    }
    
    //  - determine where to start checksumming
    //    byte-0 is a skip count from 1-16
    unsigned char *ptr = [sm mutableBytes];
    ptr += ((*ptr & 0x0F) + 1);
    
    //  - in order to be very sure this is unique, I'm using an interleaved UUID in the following
    //    payload data.   The pointer is at the beginning of the payload right now, but will shortly
    //    have data bytes stored in the even locations.  The odd ones will be used to store the
    //    UUID so that this header is absolutely unique in all scenarios, which will be important
    //    when it is hashed later.
    unsigned char *pUUIDtgt = ptr + 1;
    NSUUID  *uuid           = [NSUUID UUID];
    uuid_t  uuidBytes;
    unsigned char *pBytes   = (unsigned char *) &uuidBytes;
    [uuid getUUIDBytes:pBytes];
    for (NSUInteger i = 0; i < sizeof(uuid_t); i++) {
        *pUUIDtgt = *pBytes;
        pBytes++;
        pUUIDtgt += 2;
    }

    //  - distribute the type, version, payload length and payload crc (12 bytes)
    //    throughout the next block of 24 random bytes.
    //  - the length is necessary so that when decrypting blobs longer than
    //    what we produced, we can very easily know how much to pull.
    //  - keep the version and length in the middle - the least predictable location
    ptr[0]  = (lenPayload >> 24) & 0xFF;
    ptr[2]  = (lenPayload >> 8) & 0xFF;
    ptr[4]  = (crcPayload >> 24) & 0xFF;
    ptr[6]  = (propListType >> 8) & 0xFF;
    ptr[8]  = (version & 0xFF);
    ptr[10] = (propListType & 0xFF);
    ptr[12] = (version >> 8) & 0xFF;
    ptr[14] = (crcPayload >> 8) & 0xFF;
    ptr[16] = (crcPayload & 0xFF);
    ptr[18] = (crcPayload >> 16) & 0xFF;
    ptr[20] = (lenPayload & 0xFF);
    ptr[22] = (lenPayload >> 16) & 0xFF;

    //  - now checksum the next 24 bytes
    uLong crc = crc32(0, ptr, 24);
    ptr += 24;
    
    uint32_t val = (uint32_t) crc;             //  force 32-bits regardless of what a long is
    
    //  - now skip from 1-8 bytes
    ptr += ((*ptr & 0x07) + 1);
    
    //  - and store the CRC
    *ptr = (val >> 24) & 0xFF;
    ptr++;
    *ptr = (val >> 16) & 0xFF;
    ptr++;
    *ptr = (val >> 8) & 0xFF;
    ptr++;
    *ptr = (val & 0xFF);
    
    return YES;
}

/*
 *  Append a random padding sequence to the memory buffer.
 */
-(BOOL) appendRandomPad:(RSI_securememory *) sm withError:(NSError **) err
{
    //  the random pad is anywhere from 8 - 32 bytes of data with a preceding byte count
    unsigned char buf[33];
    int ret = SecRandomCopyBytes(kSecRandomDefault, sizeof(buf), buf);
    if (ret != 0) {
        [RSI_error fillError:err withCode:RSIErrorCryptoFailure andFailureReason:@"Failed to generate a secure byte sequence."];
        return NO;
    }
    buf[0] = (buf[0] % 25) + 8;
    [sm appendBytes:buf length:buf[0] + 1];
    return YES;
}

/*
 *  Build the serialized list of properties for output.
 */
-(BOOL) buildPropertyBlob:(RSI_securememory *)smBlob fromData:(NSData *)d withCRC:(uLong *)crc andError:(NSError **)err
{
    if (!d) {
        d = [NSData data];
    }
    
    // - always pad before the properties themselves to randomize their
    //   location because they have a constant header that could be used to
    //   infer the encryption key.
    if (![self appendRandomPad:smBlob withError:err]) {
        return NO;
    }
    
    //  - in order to ensure the structure is easily traversed, put a length
    //    in before the coded data.
    [RSI_common appendLong:(uint32_t) [d length] toData:smBlob.rawData];
    [smBlob appendData:d];
    
    //  - now add the CRC after
    *crc = crc32(0, d.bytes, (uInt) [d length]);
    [RSI_common appendLong:(uint32_t) *crc toData:smBlob.rawData];
    
    //  - and one more random blob just to obscure things a little bit more
    return [self appendRandomPad:smBlob withError:err];
}

/*
 *  Verify that the provided header 
 */
+(BOOL) validateSecureHeader:(NSData *) smHeader forVersion:(uint16_t) ver returningLength:(uint32_t *) len andReturningCRC:(uint32_t *) crc andReturningType:(uint16_t *) propType
                   withError:(NSError **) err
{
    if ([smHeader length] < ([RSI_secure_props propertyHeaderLength] - 1)) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSecureProps andFailureReason:@"Invalid header length."];
        return NO;
    }
    
    //  - determine where to start checksumming
    //    byte-0 is a skip count from 1-16
    const unsigned char *ptr = [smHeader bytes];
    ptr += ((*ptr & 0x0F) + 1);
    
    //  - grab the last four bytes to later match type/version
    uint16_t embedType = (ptr[6] << 8) | ptr[10];
    uint16_t embedVer  = (ptr[12] << 8) | ptr[8];
    uint32_t embedLen  = ((uint32_t) ptr[0] << 24) | ((uint32_t) ptr[22] << 16) | ((uint32_t) ptr[2] << 8) | (uint32_t) ptr[20];
    uint32_t embedCRC  = ((uint32_t) ptr[4] << 24) | ((uint32_t) ptr[18] << 16) | ((uint32_t) ptr[14] << 8) | (uint32_t) ptr[16];
    
    //  - now checksum the next 24 bytes
    uLong crcHdr = crc32(0, ptr, 24);
    ptr += 24;
    
    //  - now skip from 1-8 bytes
    ptr += ((*ptr & 0x07) + 1);
    
    uint32_t val = 0;
    val = ((uint32_t) ptr[0] << 24) | ((uint32_t) ptr[1] << 16) | ((uint32_t) ptr[2] << 8) | (uint32_t) ptr[3];
    
    if ((uint32_t) crcHdr != val) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSecureProps andFailureReason:@"CRC failure."];
        return NO;
    }

    //  - verify the version last because by this point
    //    we know that the header was built by us.
    if (embedVer > ver) {
        [RSI_error fillError:err withCode:RSIErrorSecurePropsVersionMismatch];
        return NO;
    }
    
    //  - this code shouldn't validate the type because the same key can be used
    //    with and should be able to identify valid headers for multiple types.
    if (propType) {
        *propType = embedType;
    }
    
    //  - the length is used to determine the quantity of data to decrypt from the payload
    if (len) {
        *len = embedLen;
    }
    
    //  - the payload CRC is used to ensure that the header and payload were created together.
    if (crc) {
        *crc = embedCRC;
    }
    
    return YES;
}

/*
 *  Verifies that the given buffer begins with a secure property header of the right
 *  format.
 */
-(BOOL) isSupportedProps:(NSData *) d withPayloadLength:(uint32_t *) len andPayloadCRC:(uint32_t *) crc andPayloadType:(uint16_t *) propType withError:(NSError **) err
{
    RSI_securememory *smDecrypted = [RSI_securememory data];
    if (!d || [d length] < [RSI_secure_props propertyHeaderLength]) {
        return NO;
    }

    if (key) {
        if (![key decrypt:[NSData dataWithBytes:d.bytes length:[RSI_secure_props propertyHeaderLength]] intoBuffer:smDecrypted withError:nil] ||
            ![RSI_secure_props validateSecureHeader:smDecrypted.rawData forVersion:version returningLength:len andReturningCRC:crc andReturningType:propType withError:err]) {
            return NO;
        }
    }
    else {
        if (![RSI_secure_props validateSecureHeader:d forVersion:version returningLength:len andReturningCRC:crc andReturningType:propType withError:err]) {
            return NO;
        }
    }
        
    return YES;
}

/*
 *  Identify the blob of property data within the payload.
 */
-(NSData *) findPropertyBlob:(NSData *) smBlob withCRC:(uint32_t) crc andError:(NSError **) err
{
    NSUInteger numBytes = [smBlob length];
    if (!smBlob || numBytes < 1) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSecureProps andFailureReason:@"Short property blob."];
        return nil;
    }
    
    const unsigned char *ptr = smBlob.bytes;
    
    //  - hop over the random padding
    numBytes -= 1;
    if (numBytes < (*ptr + 4)) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSecureProps andFailureReason:@"Padding error."];
        return nil;
    }
    numBytes -= *ptr;
    ptr += (ptr[0] + 1);
    
    //  - grab the length
    uint32_t len = [RSI_common longFromPtr:ptr];
    if (!len || numBytes < (len + 8)) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSecureProps andFailureReason:@"Bad property length"];
        return nil;
    }
    ptr += 4;
    
    //  - validate the archive and then decode it.
    uLong crcComputed = crc32(0, ptr, len);
    const unsigned char *archiveStart = ptr;
    ptr += len;
    uint32_t val = [RSI_common longFromPtr:ptr];
    if ((uint32_t) crc == val &&
        crcComputed == crc) {
        return [NSData dataWithBytesNoCopy:(void *) archiveStart length:len freeWhenDone:NO];
    }
    
    [RSI_error fillError:err withCode:RSIErrorInvalidSecureProps andFailureReason:@"Format error."];
    return nil;
}

@end
