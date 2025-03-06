//
//  RSI_symcrypt.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 12/5/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>
#import "RSI_symcrypt.h"
#import "RSI_error.h"
#import "RSI_common.h"

//  - static data
uint8_t blockInitVector[kCCBlockSizeAES128];      //  only used in the flawed ECB mode

//  - forward declarations
@interface RSI_symcrypt (internal)

-(id) initWithType:(NSUInteger) t andTag:(NSString *) tg andKey:(NSData *) k;
-(id) initWithType:(NSUInteger) t andTag:(NSString *) tg andSecureKey:(RSI_securememory *)k;
+(NSMutableDictionary *) dictionaryForLabel:(NSString *) label andType:(NSUInteger) kt andTag:(NSString *) tag andBeBrief:(BOOL) brief;
@end


/***************************
 RSI_symcrypt
 ***************************/
@implementation RSI_symcrypt

/*
 *  Initialize common attributes of this implementation
 */
+(void) initialize
{
    memset(blockInitVector, 0, sizeof(blockInitVector));
}

/*
 *  Return the size of the key used for symmetric encryption.
 */
+(NSUInteger) keySize
{
    // - while it appears 128-bit encryption is hard-ware accellerated, I'm
    //   inclined to use the highest possible encryption that is available to
    //   provide the most longevity to this solution.
    return kCCKeySizeAES256;
}

/*
 *  Create a new symmetric key in the keychain with the supplied attributes.
 */
+(RSI_symcrypt *) allocNewKeyForLabel:(NSString *) label andType:(NSUInteger) kt andTag:(NSString *) tag withError:(NSError **) err
{
    if (!tag || ![tag length]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return nil;
    }
    
    //  - now allocate a new key
    RSI_securememory *keyData = [RSI_securememory dataWithLength:[RSI_symcrypt keySize] * sizeof(uint8_t)];
    if (!keyData) {
        [RSI_error fillError:err withCode:RSIErrorOutOfMemory];
        return nil;
    }
    
    OSStatus status = SecRandomCopyBytes(kSecRandomDefault, [RSI_symcrypt keySize], (uint8_t *) keyData.mutableBytes);
    if (status != errSecSuccess) {
        [RSI_error fillError:err withCode:RSIErrorKeychainFailure andKeychainStatus:status];
        return nil;
    }
    
    if (![RSI_symcrypt importKeyWithLabel:label andType:kt andTag:tag andValue:keyData withError:err]) {
        return nil;
    }
    
    //  - and return the data for it.
    return [[RSI_symcrypt alloc] initWithType:kt andTag:tag andKey:keyData.rawData];
}

/*
 *  Import the given key 
 */
+(BOOL) importKeyWithLabel:(NSString *) label andType:(NSUInteger) kt andTag:(NSString *) tag andValue:(RSI_securememory *) keyData withError:(NSError **) err
{
    if (!label || !tag || !keyData || [keyData length] != [RSI_symcrypt keySize]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return NO;
    }
    
    NSMutableDictionary *mdKey = [RSI_symcrypt dictionaryForLabel:label andType:kt andTag:tag andBeBrief:NO];
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
 *  Rename the given key.
 */
+(BOOL) renameKeyForLabel:(NSString *) oldLabel andType:(NSUInteger) kt andTag:(NSString *) oldTag toNewLabel:(NSString *) newLabel andNewTag:(NSString *) newTag withError:(NSError **) err
{
    if (!oldLabel || !oldTag || !newLabel || !newTag) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return NO;
    }
    
    NSMutableDictionary *mdQuery = [RSI_symcrypt dictionaryForLabel:oldLabel andType:kt andTag:oldTag andBeBrief:YES];

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
 *  Find the application tags for all the keys that match the given type.
 */
+(NSArray *) findAllKeyTagsForType:(NSUInteger) kt withError:(NSError **) err
{
    NSMutableDictionary *mdQuery = [NSMutableDictionary dictionary];
    [mdQuery setObject:kSecClassKey forKey:kSecClass];
    [mdQuery setObject:kSecAttrKeyClassSymmetric forKey:kSecAttrKeyClass];
    [mdQuery setObject:[NSNumber numberWithUnsignedInteger:kt] forKey:kSecAttrKeyType];
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
 *  Find an existing symmetric key using the type and tag as search criteria.
 */
+(RSI_symcrypt *) allocExistingKeyForType:(NSUInteger) kt andTag:(NSString *) tag withError:(NSError **) err
{
    if (!tag || ![tag length]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return nil;
    }
    
    NSMutableDictionary *dQuery = [RSI_symcrypt dictionaryForLabel:nil andType:kt andTag:tag andBeBrief:YES];
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
    
    RSI_symcrypt *skRet = [[RSI_symcrypt alloc] initWithType:kt andTag:tag andKey:d];
    // - SecItemCopyMatching allocates a new item.
    if (d) {
        CFRelease((CFTypeRef *) d);
    }
    return skRet;
}

/*
 *  Allocate and return a transient key.
 */
+(RSI_symcrypt *) allocTransientWithKeyData:(RSI_securememory *) smKey andError:(NSError **) err
{
    if (!smKey || [smKey length] != [RSI_symcrypt keySize]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return nil;
    }
    
    return [[RSI_symcrypt alloc] initWithType:CSSM_ALGID_SYM_TRANSIENT andTag:@"transient" andSecureKey:smKey];
}

/*
 *  Allocate a transient key in the autorelease pool, which is not stored in the keychain.
 */
+(RSI_symcrypt *) transientWithKeyData:(RSI_securememory *) smKey andError:(NSError **) err
{
    return [[RSI_symcrypt allocTransientWithKeyData:smKey andError:err] autorelease];
}

/*
 *  Allocate a transient key using a password.
 */
+(RSI_symcrypt *) allocTransientWithPassword:(NSString *)pwd andError:(NSError **) err
{
    RSI_symcrypt *sk = nil;
    NSError *tmp = nil;
    @autoreleasepool {
        RSI_securememory *smPassword = [RSI_symcrypt symKeyFromPassword:pwd];
        if (smPassword) {
            sk = [RSI_symcrypt allocTransientWithKeyData:smPassword andError:&tmp];
        }
        else {
            [RSI_error fillError:&tmp withCode:RSIErrorCryptoFailure andFailureReason:@"Failed to generate a password hash."];
        }
        [tmp retain];
    }
    
    if (err) {
        *err = [tmp autorelease];
    }
    return sk;
}

/*
 *  Allocate a transient key.
 */
+(RSI_symcrypt *) transientKeyWithError:(NSError **) err
{
    RSI_securememory *secMem = [[RSI_securememory alloc] initWithLength:[RSI_symcrypt keySize]];
    RSI_symcrypt *skRet = nil;
    if (SecRandomCopyBytes(kSecRandomDefault, [RSI_symcrypt keySize], (unsigned char *) secMem.mutableBytes) == 0) {
        skRet = [RSI_symcrypt transientWithKeyData:secMem andError:err];
    }
    else {
        [RSI_error fillError:err withCode:RSIErrorCryptoFailure andFailureReason:@"Failed to get random memory."];
    }
    [secMem release];
    return skRet;
}

/*
 *  Find and delete a specific key in the chain.
 */
+(BOOL) deleteKeyWithType:(NSUInteger) kt andTag:(NSString *) tag withError:(NSError **) err
{
    NSMutableDictionary *mdQuery = [RSI_symcrypt dictionaryForLabel:nil andType:kt andTag:tag andBeBrief:YES];
    [mdQuery removeObjectForKey:kSecAttrKeySizeInBits];
    [mdQuery removeObjectForKey:kSecAttrEffectiveKeySize];
    
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
 *  Enumerate and delete all the keys of the given type.
 */
+(BOOL) deleteAllKeysWithType:(NSUInteger) kt withError:(NSError **) err
{
    NSArray *arr = [RSI_symcrypt findAllKeyTagsForType:kt withError:err];
    if (!arr) {
        return NO;
    }
    
    for (NSUInteger i = 0; i < [arr count]; i++) {
        if (![[arr objectAtIndex:i] isKindOfClass:[NSString class]]) {
            continue;
        }
        NSString *tag = [arr objectAtIndex:i];
        if (![RSI_symcrypt deleteKeyWithType:kt andTag:tag withError:err]) {
            return NO;
        }
    }
    return YES;
}

/*
 *  Do basic encryption with a symmetric key.
 */
+(BOOL) encrypt:(NSData *) clearBuf withKey:(RSI_securememory *) key intoBuffer:(NSMutableData *) encryptedBuffer withError:(NSError **) err
{
    if (!key || [key length] != [RSI_symcrypt keySize]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return NO;
    }
    
    if ([clearBuf length] == 0) {
        return NO;
    }
    
    //  Make the output buffer a multiple of the block size, but
    //  at least as big as the input plus one block as specified
    //  in the man page for CCCryptor
    NSUInteger len = [clearBuf length];
    len += ([RSI_symcrypt blockSize] << 1);
    len &= ~([RSI_symcrypt blockSize] - 1);
    
    [encryptedBuffer setLength:len];
    memset(encryptedBuffer.mutableBytes, 0, [encryptedBuffer length]);
    
    CCCryptorStatus ccStatus = 0;
    size_t lenMoved = 0;
    ccStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding, key.bytes, [key length], blockInitVector, clearBuf.bytes, [clearBuf length],
                       encryptedBuffer.mutableBytes, [encryptedBuffer length], &lenMoved);
    if (ccStatus != kCCSuccess) {
        [RSI_error fillError:err withCode:RSIErrorCryptoFailure andCryptoStatus:ccStatus];
        return NO;
    }
    
    if (lenMoved == 0) {
        [RSI_error fillError:err withCode:RSIErrorCryptoFailure andFailureReason:@"Failed to encrypt any data."];
        return NO;
    }
    
    [encryptedBuffer setLength:lenMoved];
    return YES;
}

/*
 *  Do basic decryption with a symmetric key.
 */
+(BOOL) decrypt:(NSData *) encryptedBuf withKey:(RSI_securememory *) key intoBuffer: (RSI_securememory *) clearBuffer withError:(NSError **) err
{
    if (!key || [key length] != [RSI_symcrypt keySize]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return NO;
    }
    
    [clearBuffer setLength:[encryptedBuf length]];
    
    CCCryptorStatus ccStatus = 0;
    size_t lenMoved = 0;
    ccStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding, key.bytes, [key length], blockInitVector, encryptedBuf.bytes, [encryptedBuf length],
                       clearBuffer.mutableBytes, [clearBuffer length], &lenMoved);
    if (ccStatus != kCCSuccess) {
        [RSI_error fillError:err withCode:RSIErrorCryptoFailure andCryptoStatus:ccStatus];
        return NO;
    }
    
    if (lenMoved == 0) {
        [RSI_error fillError:err withCode:RSIErrorCryptoFailure andFailureReason:@"Failed to decrypt any data."];
        return NO;
    }
    
    [clearBuffer setLength:lenMoved];
    return YES;
}

/*
 *  Hash the password and return it.
 */
+(RSI_securememory *) hashFromPassword:(NSString *) pwd
{
    if (!pwd || [pwd length] == 0) {
        return nil;
    }
    
    NSData *dPwd = [pwd dataUsingEncoding:NSUTF8StringEncoding];
    RSI_securememory *mdPwd = [RSI_securememory dataWithData:dPwd];
    
    //  - add salt to the password
    NSUInteger len = [mdPwd length];
    [mdPwd setLength:len + 4];
    ((unsigned char *) [mdPwd mutableBytes])[len]     = 'R';
    ((unsigned char *) [mdPwd mutableBytes])[len + 1] = 'P';
    ((unsigned char *) [mdPwd mutableBytes])[len + 2] = 'F';
    ((unsigned char *) [mdPwd mutableBytes])[len + 3] = 'G';
    
    // - HASHING-NOTE:
    //   - Passwords should always be as secure as possible.
    return [RSI_SHA_SECURE hashFromInput:mdPwd.rawData];
}

/*
 *  Produce a symmetric key generated from the supplied password.
 */
+(RSI_securememory *) symKeyFromHash:(RSI_securememory *) h
{
    // - HASHING-NOTE:
    //   - Passwords should always be as secure as possible.
    if (!h || [h length] != [RSI_SHA_SECURE SHA_LEN]) {
        return nil;
    }
    
    RSI_securememory *mdKey = [RSI_securememory dataWithLength:[RSI_symcrypt keySize]];
    
    //  - scramble the password a bit and make an encryption key out of it.
    NSUInteger vals[]   = {619, 631, 641, 643, 647, 653, 659, 661, 673, 677, 683, 691, 701, 709, 719, 727};
    NSUInteger numvals  = sizeof(vals)/sizeof(vals[0]);
    unsigned char *hash = (unsigned char *) [h bytes];
    for (NSUInteger i = 0; i < [mdKey length]; i++) {
        NSUInteger j = i % [h length];
        NSUInteger v = vals[i % numvals];
        ((unsigned char *) [mdKey mutableBytes])[i] = (unsigned char) ((hash[j] ^ v) & 0xFF);
    }
    return mdKey;
}

/*
 *  Produce a symmetric key from a password
 */
+(RSI_securememory *) symKeyFromPassword:(NSString *) pwd
{
    RSI_securememory *pHash = [RSI_symcrypt hashFromPassword:pwd];
    return [RSI_symcrypt symKeyFromHash:pHash];
}

/*
 *  Return the symmetric encryption block size.
 */
+(NSUInteger) blockSize
{
    return kCCBlockSizeAES128;
}

/*
 *  Encrypt a buffer of data.
 */
-(BOOL) encrypt:(NSData *) clearBuf intoBuffer:(NSMutableData *) encryptedBuffer withError:(NSError **) err
{
    return [RSI_symcrypt encrypt:clearBuf withKey:key intoBuffer:encryptedBuffer withError:err];
}

/*
 *  Decrypt a buffer of data.
 */
-(BOOL) decrypt:(NSData *) encryptedBuf intoBuffer: (RSI_securememory *) clearBuffer withError:(NSError **) err
{
    return [RSI_symcrypt decrypt:encryptedBuf withKey:key intoBuffer:clearBuffer withError:err];
}

/*
 *  Return the tag assigned to this key.
 */
-(NSString *) tag
{
    return [[tag retain] autorelease];
}

/*
 *  Return the data that comprises this key object.
 */
-(RSI_securememory *) key
{
    return [[key retain] autorelease];
}

/*
 *  Change the existing symmetric key with the given key data.
 */
-(BOOL) updateKeyWithData:(RSI_securememory *) newKeyData andError:(NSError **) err
{
    if (!newKeyData || [newKeyData length] != [RSI_symcrypt keySize] || type == CSSM_ALGID_SYM_TRANSIENT) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return NO;
    }
    
    //  - start by finding the existing key and its attributes
    NSMutableDictionary *mdQuery = [RSI_symcrypt dictionaryForLabel:nil andType:type andTag:tag andBeBrief:YES];
    [mdQuery setObject:kSecMatchLimitOne forKey:kSecMatchLimit];
    [mdQuery setObject:[NSNumber numberWithBool:YES] forKey:kSecReturnAttributes];
    
    //  - NOTE: the keychain locking is a little less obvious here and requires some care or the lock
    //          won't be released.  BE VERY CAREFUL ABOUT ADDING NEW CONDITIONS.
    NSDictionary *dictCurrent = nil;
    [RSI_common WRLOCK_KEYCHAIN];
    OSStatus status = SecItemCopyMatching((CFDictionaryRef) mdQuery, (CFTypeRef *) &dictCurrent);
    if (status != errSecSuccess) {
        [RSI_common UNLOCK_KEYCHAIN];
        [RSI_error fillError:err withCode:RSIErrorKeychainFailure andKeychainStatus:status];
        return NO;
    }

    //  - ensure the query class is completely up to date.
    mdQuery = [NSMutableDictionary dictionaryWithDictionary:dictCurrent];
    [mdQuery setObject:kSecClassKey forKey:kSecClass];
    [mdQuery setObject:kSecAttrKeyClassSymmetric forKey:kSecAttrKeyClass];
    
    // - SecItemCopyMatching allocates a new item.
    if (dictCurrent) {
        CFRelease((CFTypeRef *) dictCurrent);
    }

    //  - now update the entry with the new data
    NSMutableDictionary *mdToChange = [RSI_symcrypt dictionaryForLabel:nil andType:type andTag:tag andBeBrief:YES];
    [mdToChange removeObjectForKey:kSecClass];      //  - not used for updates
    [mdToChange setObject:newKeyData.rawData forKey:kSecValueData];
    status = SecItemUpdate((CFDictionaryRef) mdQuery, (CFDictionaryRef) mdToChange);
    [RSI_common UNLOCK_KEYCHAIN];
    if (status != errSecSuccess) {
        [RSI_error fillError:err withCode:RSIErrorKeychainFailure andKeychainStatus:status];
        return NO;
    }
    
    //  - save the updated data in this object
    [key release];
    key = [[RSI_securememory dataWithSecureData:newKeyData] retain];
    
    return YES;
}

@end


/***************************
 RSI_symcrypt (internal)
 ***************************/
@implementation RSI_symcrypt (internal)

/*
 *  Initialize the object.
 */
-(id) initWithType:(NSUInteger) t andTag:(NSString *) tg andKey:(NSData *) k
{
    return [self initWithType:t andTag:tg andSecureKey:[RSI_securememory dataWithData:k]];
}

/*
 *  Initialize the object.
 */
-(id) initWithType:(NSUInteger) t andTag:(NSString *) tg andSecureKey:(RSI_securememory *)k
{
    self = [super init];
    if (self) {
        type = t;
        tag  = [tg retain];
        key  = [k retain];
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
+(NSMutableDictionary *) dictionaryForLabel:(NSString *) label andType:(NSUInteger) kt andTag:(NSString *) tag andBeBrief:(BOOL) brief
{
    NSMutableDictionary *mdRet = [NSMutableDictionary dictionary];
    
    [mdRet setObject:kSecClassKey forKey:kSecClass];
    [mdRet setObject:kSecAttrKeyClassSymmetric forKey:kSecAttrKeyClass];
    if (label) {
        [mdRet setObject:label forKey:kSecAttrLabel];
    }
    [mdRet setObject:[NSNumber numberWithUnsignedInteger:kt] forKey:kSecAttrKeyType];
    if (tag) {
        NSData *dTag = [tag dataUsingEncoding:NSUTF8StringEncoding];
        [mdRet setObject:dTag forKey:kSecAttrApplicationTag];
    }

    [mdRet setObject:[NSNumber numberWithUnsignedInteger:([RSI_symcrypt keySize] << 3)] forKey:kSecAttrKeySizeInBits];
    [mdRet setObject:[NSNumber numberWithUnsignedInteger:([RSI_symcrypt keySize] << 3)] forKey:kSecAttrEffectiveKeySize];
    
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