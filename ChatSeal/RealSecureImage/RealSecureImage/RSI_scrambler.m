//
//  RSI_scrambler.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 12/11/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import "RSI_scrambler.h"
#import "RSI_common.h"
#import "RSI_error.h"

//  - forward declarations
@interface RSI_scrambler (internal)
-(id) initWithTag:(NSString *) t andKey:(NSData *) k;
+(NSMutableDictionary *) dictionaryForLabel:(NSString *) label andTag:(NSString *) tag andBeBrief:(BOOL) brief;
@end

/**********************
 RSI_scrambler
 **********************/
@implementation RSI_scrambler

/*
 *  Return the length of a scrambler key.
 */
+(NSUInteger) keySize
{
    return [RSI_SHA_SCRAMBLE SHA_LEN];
}

/*
 *  Allocate a key, but don't persist it in the keychain
 */
+(RSI_scrambler *) allocTransientKeyWithData:(NSData *) dKey andError:(NSError **) err
{
    if ([dKey length] != [RSI_scrambler keySize]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];        
        return nil;;
    }
    
    return [[RSI_scrambler alloc] initWithTag:@"transient" andKey:dKey];
}

/*
 *  Find a scrambler key in the keychain and load it.
 */
+(RSI_scrambler *) allocExistingKeyForTag:(NSString *) tag withError:(NSError **) err
{
    if (!tag || ![tag length]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return nil;
    }
    
    NSMutableDictionary *dQuery = [RSI_scrambler dictionaryForLabel:nil andTag:tag andBeBrief:YES];
    [dQuery setObject:kSecMatchLimitOne forKey:kSecMatchLimit];
    [dQuery setObject:[NSNumber numberWithBool:YES] forKey:kSecReturnData];
    
    NSData *d = nil;
    [RSI_common RDLOCK_KEYCHAIN];
    OSStatus status = SecItemCopyMatching((CFDictionaryRef) dQuery, (CFTypeRef *) &d);
    [RSI_common UNLOCK_KEYCHAIN];
    if (status != errSecSuccess) {
        if (status == errSecItemNotFound) {
            [RSI_error fillError:err withCode:RSIErrorKeyNotFound];
        }
        else {
            [RSI_error fillError:err withCode:RSIErrorKeychainFailure];
        }
        return nil;
    }
    
    RSI_scrambler *scramRet = [[RSI_scrambler alloc] initWithTag:tag andKey:d];
    
    // - SecItemCopyMatching allocates a new item.
    if (d) {
        CFRelease((CFTypeRef *) d);
    }
    return scramRet;
}

/*
 *  Find all the scrambler keys in the keychain.
 */
+(NSArray *) findAllKeyTagsWithError:(NSError **) err
{
    NSMutableDictionary *mdQuery = [NSMutableDictionary dictionary];
    [mdQuery setObject:kSecClassKey forKey:kSecClass];
    [mdQuery setObject:kSecAttrKeyClassSymmetric forKey:kSecAttrKeyClass];
    [mdQuery setObject:[NSNumber numberWithUnsignedInteger:CSSM_ALGID_SCRAMBLE] forKey:kSecAttrKeyType];
    [mdQuery setObject:kSecMatchLimitAll forKey:kSecMatchLimit];
    [mdQuery setObject:[NSNumber numberWithBool:YES] forKey:kSecReturnAttributes];
    
    NSArray *attribs = nil;
    [RSI_common RDLOCK_KEYCHAIN];
    OSStatus status = SecItemCopyMatching((CFDictionaryRef) mdQuery, (CFTypeRef *) &attribs);
    [RSI_common UNLOCK_KEYCHAIN];
    if (status == errSecItemNotFound) {
        return [NSArray array];
    }
    else if (status != errSecSuccess) {
        [RSI_error fillError:err withCode:RSIErrorKeychainFailure andKeychainStatus:status];
        return nil;
    }
    
    NSMutableArray *ret = [NSMutableArray array];
    for (NSUInteger i = 0; i < [attribs count]; i++) {
        if (![[attribs objectAtIndex:i] isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *dict = [attribs objectAtIndex:i];
        NSData *d = [dict objectForKey:kSecAttrApplicationTag];
        if (d) {
            NSString *sTag = [NSString stringWithUTF8String:(const char *) d.bytes];
            [ret addObject:sTag];
        }
    }
    
    // - SecItemCopyMatching allocates a new item.
    if (attribs) {
        CFRelease((CFTypeRef *) attribs);
    }
    return ret;
}

/*
 *  Delete a specific scrambler key from the keychain.
 */
+(BOOL) deleteKeyWithTag:(NSString *) tag withError:(NSError **) err
{
    NSMutableDictionary *mdQuery = [RSI_scrambler dictionaryForLabel:nil andTag:tag andBeBrief:YES];
    
    [RSI_common WRLOCK_KEYCHAIN];
    OSStatus status = SecItemDelete((CFDictionaryRef) mdQuery);
    [RSI_common UNLOCK_KEYCHAIN];
    if (status == errSecItemNotFound) {
        [RSI_error fillError:err withCode:RSIErrorKeyNotFound];
        return NO;
    }
    else if (status != errSecSuccess) {
        [RSI_error fillError:err withCode:RSIErrorKeychainFailure andKeychainStatus:status];
        return NO;
    }
    return YES;
}

/*
 *  Delete all the scrambler keys in the keychain.
 */
+(BOOL) deleteAllKeysWithError:(NSError **) err
{
    NSArray *arr = [RSI_scrambler findAllKeyTagsWithError:err];
    if (!arr) {
        return NO;
    }
    
    for (NSUInteger i = 0; i < [arr count]; i++) {
        if (![[arr objectAtIndex:i] isKindOfClass:[NSString class]]) {
            continue;
        }
        NSString *tag = [arr objectAtIndex:i];
        if (![RSI_scrambler deleteKeyWithTag:tag withError:err]) {
            return NO;
        }
    }
    return YES;
}

/*
 *  Import a specific scrambler key into the keychain.
 */
+(BOOL) importKeyWithLabel:(NSString *) label andTag:(NSString *) tag andValue:(RSI_securememory *) keyData withError:(NSError **) err
{
    if (!label || !tag || !keyData || [keyData length] != [RSI_scrambler keySize]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return NO;
    }
    
    NSMutableDictionary *mdKey = [RSI_scrambler dictionaryForLabel:label andTag:tag andBeBrief:NO];
    [mdKey setObject:[keyData rawData] forKey:kSecValueData];
    
    //  - add it to the keychain
    [RSI_common WRLOCK_KEYCHAIN];
    OSStatus status = SecItemAdd((CFDictionaryRef) mdKey, NULL);
    [RSI_common UNLOCK_KEYCHAIN];
    if (status == errSecDuplicateItem) {
        [RSI_error fillError:err withCode:RSIErrorKeyExists];
        return NO;
    }
    else if (status != errSecSuccess) {
        [RSI_error fillError:err withCode:RSIErrorKeychainFailure andKeychainStatus:status];
        return NO;
    }
    return YES;
}

/*
 *  Rename the provided scrambler key.
 */
+(BOOL) renameKeyForLabel:(NSString *) oldLabel andTag:(NSString *) oldTag toNewLabel:(NSString *) newLabel andNewTag:(NSString *) newTag withError:(NSError **) err;
{
    if (!oldLabel || !oldTag || !newLabel || !newTag) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return NO;
    }
    
    NSMutableDictionary *mdQuery = [RSI_scrambler dictionaryForLabel:oldLabel andTag:oldTag andBeBrief:YES];
    
    NSMutableDictionary *mdToModify = [NSMutableDictionary dictionary];
    [mdToModify setObject:newLabel forKey:kSecAttrLabel];
    NSData *dTag = [newTag dataUsingEncoding:NSUTF8StringEncoding];
    [mdToModify setObject:dTag forKey:kSecAttrApplicationTag];
    
    [RSI_common WRLOCK_KEYCHAIN];
    OSStatus status = SecItemUpdate((CFDictionaryRef) mdQuery, (CFDictionaryRef) mdToModify);
    [RSI_common UNLOCK_KEYCHAIN];
    if (status == errSecItemNotFound) {
        [RSI_error fillError:err withCode:RSIErrorKeyNotFound andKeychainStatus:status];
        return NO;
    }
    else if (status != errSecSuccess) {
        [RSI_error fillError:err withCode:RSIErrorKeychainFailure andKeychainStatus:status];
    }
    return YES;
}

/*
 *  Manage the scrambling/descrambling, which are mirror opposites of one another.
 *  METHOD:
 *    - the output buffer will be split into 256-byte blocks
 *    - data from the input stream will be interleaved into separate blocks
 *    - the sequence in which the blocks are used is completely random and determined by the key
 *    - within each block, the key data will be used to define the first index used, with each
 *      subsequent use incrementing it, wrapping around to the front.
 *    - if a block is consumed (the last one) then it is taken out of the marching list and the
 *      next one is used.  
 *    - every byte put into the output will be XORed with the key.
 *  Although this requires a lot of cache thrashing, it will spread the data throughout the file
 *  in a deterministic way defined by the key, making it relatively simple to reverse the process.  
 */
+(BOOL) scrambleOp:(const unsigned char *) srcData withKey:(RSI_securememory *) key intoBuffer:(unsigned char *) destData withLength:(NSUInteger) length andDirection:(BOOL) toScramble andError:(NSError **) err
{
    //  - the marching list is a list of integers defining the sequence of blocks
    NSUInteger numBlocks = ((length + ((1 << 8) - 1)) >> 8);
    if (!numBlocks) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return NO;
    }

    //  - the marching list is a random sequence of 256-byte indices that we'll use to define
    //    the stepping order in which data is output.
    NSUInteger *marchingList = [RSI_scrambler randomIndicesFrom:0 toEnd:numBlocks - 1 withShiftLeftBy:8 usingKey:key];
    
    //  - now for each byte in the source buffer, we need to find a location
    //    in the output buffer
    const unsigned char *keyData = (const unsigned char *) [key bytes];
    NSUInteger keyIndex          = 0;
    NSUInteger keyLen            = [key length];
    NSUInteger blockIndex        = 0;
    NSUInteger offset            = 0;
    NSUInteger lastBase          = (numBlocks - 1) << 8;
    NSUInteger lastLen           = length - lastBase;
    for (NSUInteger clearByte = 0; clearByte < length;) {
        //  - the base is the byte location of the block
        NSUInteger blockBase = marchingList[blockIndex];
        
        //  - the origin value is the distance from the base where
        //    the first byte is stored in the output buffer and is
        //    _always_ the same for each block
        NSUInteger origin = keyData[blockIndex % keyLen];
        
        //  - the index is built from the origin and the current
        //    offset
        NSUInteger scrambleByte = (origin + offset);
        BOOL skipBlock = NO;
        if (blockBase == lastBase) {
            scrambleByte = scrambleByte % lastLen;
            
            //  - when we're in the last block and we've advanced
            //    past the beginning again, we need to skip this block because
            //    it is full
            if (offset >= lastLen) {
                skipBlock = YES;
            }
        }
        else {
            scrambleByte = scrambleByte & 0xFF;
        }
        
        //  - advance to the next block and key
        blockIndex++;
        if (blockIndex >= numBlocks) {
            blockIndex = 0;
            offset++;
        }
        
        keyIndex++;
        if (keyIndex >= keyLen) {
            keyIndex = 0;
        }        
        
        //  - if we found a good index into the block, the data
        //    can be transferred, otherwise wait until the next iteration
        if (!skipBlock) {
            //  These descrambling operations use two XORs to minimize the effect that
            //  an XOR of zero will have on identifying the key
            //  - move the byte based on the polarity of this operation
            if (toScramble) {
                //  The destination is scrambled data
                destData[blockBase + scrambleByte] = srcData[clearByte] ^ keyData[keyIndex] ^ (scrambleByte & 0xFF);
            }
            else {
                //  The destination is descrambled data
                destData[clearByte] = srcData[blockBase + scrambleByte] ^ (scrambleByte & 0xFF) ^ keyData[keyIndex];
            }
            
            //  - advance to the next source byte
            clearByte++;
        }
    }
        
    return YES;
}

+(BOOL) scramble:(NSData *) clearBuf withKey:(RSI_securememory *) key intoBuffer:(NSMutableData *) scrambledBuffer withError:(NSError **) err
{
    if (!clearBuf || !scrambledBuffer || [clearBuf length] == 0) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return NO;
    }
    
    [scrambledBuffer setLength:[clearBuf length]];    
    if (![RSI_scrambler scrambleOp:clearBuf.bytes withKey:key intoBuffer:scrambledBuffer.mutableBytes withLength:[clearBuf length] andDirection:YES andError:err]) {
        [scrambledBuffer setLength:0];
        return NO;
    }
    
    return YES;
}

/*
 *  Convert an obfuscated buffer back into its original form.
 */
+(BOOL) descramble:(NSData *) scrambledBuffer withKey:(RSI_securememory *) key intoBuffer: (RSI_securememory *) clearBuffer withError:(NSError **) err
{
    if (!scrambledBuffer || !clearBuffer || [scrambledBuffer length] == 0) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return NO;
    }
    
    [clearBuffer setLength:[scrambledBuffer length]];    
    if (![RSI_scrambler scrambleOp:scrambledBuffer.bytes withKey:key intoBuffer:clearBuffer.mutableBytes withLength:[scrambledBuffer length] andDirection:NO andError:err]) {
        [clearBuffer setLength:0];
        return NO;
    }
    
    return YES;
}

/*
 *  Obfuscate the input buffer into the output buffer.
 */
-(BOOL) scramble:(NSData *) clearBuf intoBuffer:(NSMutableData *) scrambledBuffer withError:(NSError **) err
{
    return [RSI_scrambler scramble:clearBuf withKey:key intoBuffer:scrambledBuffer withError:err];
}

/*
 *  Convert an obfuscated buffer back into its original form.
 */
-(BOOL) descramble:(NSData *) scrambledBuffer intoBuffer: (RSI_securememory *) clearBuffer withError:(NSError **) err
{
    return [RSI_scrambler descramble:scrambledBuffer withKey:key intoBuffer:clearBuffer withError:err];
}

/*
 *  Return the current scrambler tag.
 */
-(NSString *) tag
{
    return [[tag retain] autorelease];
}

/*
 *  Return the scrambler key.
 */
-(RSI_securememory *) key
{
    return [[key retain] autorelease];
}

/*
 *  Generate a list of random indices using the scrambler key.
 */
+(NSUInteger *) randomIndicesFrom:(NSUInteger) start toEnd:(NSUInteger) end withShiftLeftBy:(NSUInteger) shiftAmt usingKey:(RSI_securememory *) key
{
    if (end < start) {
        return NULL;
    }
    
    NSMutableArray *maFullSet = [[NSMutableArray alloc] init];
    for (NSUInteger i = start; i < end+1; i++) {
        [maFullSet addObject:[NSNumber numberWithUnsignedInteger:i]];
    }
    
    NSUInteger numItems  = [maFullSet count];
    NSUInteger keyloc    = 0;
    NSUInteger keylen    = [key length];
    NSMutableData *mdRet = [NSMutableData dataWithLength:numItems * sizeof(NSUInteger)];
    NSUInteger *ret      = (NSUInteger *) mdRet.mutableBytes;
    for (int i = 0; i < numItems; i++) {
        NSUInteger randidx = ((unsigned char *) key.bytes)[(++keyloc)%keylen] % [maFullSet count];
        NSNumber *n        = [maFullSet objectAtIndex:randidx];
        ret[i]             = [n unsignedIntegerValue] << shiftAmt;
        [maFullSet removeObjectAtIndex:randidx];
    }
    [maFullSet release];
    
    return ret;
}

/*
 *  Generate a list of random indices using the scrambler key.
 */
-(NSUInteger *) randomIndicesFrom:(NSUInteger) start toEnd:(NSUInteger) end withShiftLeftBy:(NSUInteger) shiftAmt
{
    return [RSI_scrambler randomIndicesFrom:start toEnd:end withShiftLeftBy:shiftAmt usingKey:key];
}

@end


/************************
 RSI_scrambler (internal)
 ************************/
@implementation RSI_scrambler (internal)

/*
 *  Initialize the object.
 */
-(id) initWithTag:(NSString *) t andKey:(NSData *) k
{
    self = [super init];
    if (self) {
        tag = [[NSString alloc] initWithString:t];
        key = [[RSI_securememory alloc] initWithData:k];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [tag release];
    [key release];
    
    [super dealloc];
}

/*
 *  Create a standard dictionary for a symmetric key with the provided properties.
 */
+(NSMutableDictionary *) dictionaryForLabel:(NSString *) label andTag:(NSString *) tag andBeBrief:(BOOL) brief
{
    NSMutableDictionary *mdRet = [NSMutableDictionary dictionary];
    
    [mdRet setObject:kSecClassKey forKey:kSecClass];
    [mdRet setObject:kSecAttrKeyClassSymmetric forKey:kSecAttrKeyClass];            //  technically, this is a symmetric key, albeit a mathematically poor one
    if (label) {
        [mdRet setObject:label forKey:kSecAttrLabel];
    }
    [mdRet setObject:[NSNumber numberWithUnsignedInteger:CSSM_ALGID_SCRAMBLE] forKey:kSecAttrKeyType];
    if (tag) {
        NSData *dTag = [tag dataUsingEncoding:NSUTF8StringEncoding];
        [mdRet setObject:dTag forKey:kSecAttrApplicationTag];
    }
    
    [mdRet setObject:[NSNumber numberWithUnsignedInteger:([RSI_scrambler keySize] << 3)] forKey:kSecAttrKeySizeInBits];
    [mdRet setObject:[NSNumber numberWithUnsignedInteger:([RSI_scrambler keySize] << 3)] forKey:kSecAttrEffectiveKeySize];
    
    if (!brief) {
        [mdRet setObject:[NSNumber numberWithBool:YES] forKey:kSecAttrCanEncrypt];
        [mdRet setObject:[NSNumber numberWithBool:YES] forKey:kSecAttrCanDecrypt];
        [mdRet setObject:[NSNumber numberWithBool:NO] forKey:kSecAttrCanDerive];
        [mdRet setObject:[NSNumber numberWithBool:NO] forKey:kSecAttrCanSign];
        [mdRet setObject:[NSNumber numberWithBool:NO] forKey:kSecAttrCanVerify];
        [mdRet setObject:[NSNumber numberWithBool:NO] forKey:kSecAttrCanWrap];
        [mdRet setObject:[NSNumber numberWithBool:NO] forKey:kSecAttrCanUnwrap];
    }
    
    return mdRet;
}

@end