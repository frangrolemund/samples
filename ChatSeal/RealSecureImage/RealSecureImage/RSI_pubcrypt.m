//
//  RSI_pubcrypt.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 12/5/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import "RSI_pubcrypt.h"
#import "RSI_common.h"
#import "RSI_error.h"
#import <CommonCrypto/CommonDigest.h>

#define PUB_PRV_BITSIZE 2048

//  - forward declarations
@interface RSI_pubcrypt (internal)
+(NSMutableDictionary *) dictionaryForPublic:(BOOL) pubKey andLabel:(NSString *) label andTag:(NSString *) tag andBeBrief:(BOOL) brief;
-(id) initWithTag:(NSString *) t andPublic:(SecKeyRef) pubK andPrivate:(SecKeyRef) prvK;
+(BOOL) importKeyWithLabel:(NSString *) label andTag:(NSString *) tag andValue:(NSData *) keyData asPublic:(BOOL) ispub withError:(NSError **) err;
+(BOOL) renameKeyWithLabel:(NSString *) oldLabel andTag:(NSString *) oldTag asPublic:(BOOL) ispub toNewLabel:(NSString *) newLabel andNewTag:(NSString *) newTag withError:(NSError **) err;
@end

/***************************
 RSI_pubcrypt
 ***************************/
@implementation RSI_pubcrypt
/*
 *  Object attributes.
 */
{
    NSString  *tag;
    SecKeyRef publicKey;
    SecKeyRef privateKey;
}

/*
 *  Return the size (in bytes) of the key
 */
+(NSUInteger) keySize
{
    return (PUB_PRV_BITSIZE >> 3);
}

/*
 *  Create a mew public/private keypair.
 */
+(RSI_pubcrypt *) allocNewKeyForPublicLabel:(NSString *) publ andPrivateLabel:(NSString *) prvl andTag:(NSString *) tag withError:(NSError **) err;
{
    if (!tag || ![tag length]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return nil;
    }
    
    NSArray *arr = nil;
    NSMutableDictionary *publicAttr = [RSI_pubcrypt dictionaryForPublic:YES andLabel:publ andTag:tag andBeBrief:NO];
    NSMutableDictionary *privAttr = [RSI_pubcrypt dictionaryForPublic:NO andLabel:publ andTag:tag andBeBrief:NO];
    
    [publicAttr setObject:kSecMatchLimitAll forKey:kSecMatchLimit];
    [privAttr setObject:kSecMatchLimitAll forKey:kSecMatchLimit];
    
    //  - first determine if either the public or private keys already exist
    [RSI_common RDLOCK_KEYCHAIN];
    OSStatus status = SecItemCopyMatching((CFDictionaryRef) publicAttr, (CFTypeRef *) &arr);
    [RSI_common UNLOCK_KEYCHAIN];
    if (arr) {
        CFRelease((CFTypeRef *) arr);
    }
    if (status != errSecItemNotFound) {
        [RSI_error fillError:err withCode:RSIErrorKeyExists];
        return nil;
    }
    [RSI_common RDLOCK_KEYCHAIN];
    status = SecItemCopyMatching((CFDictionaryRef) privAttr, (CFTypeRef *) &arr);
    [RSI_common UNLOCK_KEYCHAIN];
    if (arr) {
        CFRelease((CFTypeRef *) arr);
    }
    if (status != errSecItemNotFound) {
        [RSI_error fillError:err withCode:RSIErrorKeyExists];
        return nil;
    }
    
    //  - now start the process of constructing the key definition
    NSMutableDictionary *keyAttr = [NSMutableDictionary dictionary];
    [keyAttr setObject:kSecAttrKeyTypeRSA forKey:kSecAttrKeyType];
    [keyAttr setObject:[NSNumber numberWithUnsignedInteger:PUB_PRV_BITSIZE] forKey:kSecAttrKeySizeInBits];
    
    [publicAttr removeObjectForKey:kSecMatchLimit];
    [keyAttr setObject:publicAttr forKey:kSecPublicKeyAttrs];
    
    [privAttr removeObjectForKey:kSecMatchLimit];
    [keyAttr setObject:privAttr forKey:kSecPrivateKeyAttrs];
    
    SecKeyRef pubK = 0;
    SecKeyRef prvK = 0;
    
    [RSI_common WRLOCK_KEYCHAIN];
    status = SecKeyGeneratePair((CFDictionaryRef) keyAttr, &pubK, &prvK);
    [RSI_common UNLOCK_KEYCHAIN];
    if (status != errSecSuccess) {
        [RSI_error fillError:err withCode:RSIErrorKeychainFailure andKeychainStatus:status];
        return nil;
    }
    
    RSI_pubcrypt *pk = [[RSI_pubcrypt alloc] initWithTag:tag andPublic:pubK andPrivate:prvK];
    CFRelease(pubK);
    CFRelease(prvK);
    
    return pk;
}

/*
 *  Find an existing public (and optional private) keypair.
 */
+(RSI_pubcrypt *) allocExistingKeyForTag:(NSString *) tag withError:(NSError **) err
{
    SecKeyRef pubK = 0;
    SecKeyRef prvK = 0;
    
    if (!tag || ![tag length]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return nil;
    }
    
    NSMutableDictionary *pubQuery = [RSI_pubcrypt dictionaryForPublic:YES andLabel:nil andTag:tag andBeBrief:YES];
    [pubQuery setObject:kSecMatchLimitOne forKey:kSecMatchLimit];
    [pubQuery setObject:[NSNumber numberWithBool:YES] forKey:kSecReturnRef];
    
    [RSI_common RDLOCK_KEYCHAIN];
    OSStatus status = SecItemCopyMatching((CFDictionaryRef) pubQuery, (CFTypeRef *) &pubK);
    [RSI_common UNLOCK_KEYCHAIN];
    if (status != errSecSuccess) {
        if (status == errSecItemNotFound) {
            [RSI_error fillError:err withCode:RSIErrorKeyNotFound];
        }
        else {
            [RSI_error fillError:err withCode:RSIErrorKeychainFailure andKeychainStatus:status];
        }
        return nil;
    }
    
    NSMutableDictionary *prvQuery = [RSI_pubcrypt dictionaryForPublic:NO andLabel:nil andTag:tag andBeBrief:YES];
    [prvQuery setObject:kSecMatchLimitOne forKey:kSecMatchLimit];
    [prvQuery setObject:[NSNumber numberWithBool:YES] forKey:kSecReturnRef];
    
    [RSI_common RDLOCK_KEYCHAIN];
    status = SecItemCopyMatching((CFDictionaryRef) prvQuery, (CFTypeRef *) &prvK);
    [RSI_common UNLOCK_KEYCHAIN];
    if (status != errSecSuccess &&
        status != errSecItemNotFound) {
        CFRelease(pubK);
        [RSI_error fillError:err withCode:RSIErrorKeychainFailure andKeychainStatus:status];
        return nil;
    }
    
    RSI_pubcrypt *pk = [[RSI_pubcrypt alloc] initWithTag:tag andPublic:pubK andPrivate:prvK];
    CFRelease(pubK);
    if (prvK) {
        CFRelease(prvK);
    }
    
    return pk;
}

/*
 *  A full key has both a public and private keypair.
 */
-(BOOL) isFullKey
{
    if (publicKey && privateKey) {
        return YES;
    }
    return NO;
}

/*
 *  The block length indicates the size of the encryption block.
 */
-(NSUInteger) blockLen
{
    if (publicKey) {
        return SecKeyGetBlockSize(publicKey);
    }
    return 0;
}

/*
 *  The padding length is used to figure out how much of the block length is
 *  consumed independently of the actual data to encrypt.
 */
-(NSUInteger) padLen
{
    //  Assume we are always using PKCS1 padding.
    return 11;
}

/*
 *  Encrypt a data buffer.
 */
-(BOOL) encrypt:(NSData *) clearBuf intoBuffer:(NSMutableData *) encryptedBuffer withError:(NSError **) err
{
    //  - Only a public key can encrypt
    if (!publicKey) {
        [RSI_error fillError:err withCode:RSIErrorInsufficientKey andFailureReason:@"A suitable public key does not exist."];
        return NO;
    }
    
    //  - I'm not going to assume we're using more than a block's length here because
    //    this is not very efficient.
    NSUInteger len = [self blockLen];
    if ([clearBuf length] < 1 || len == 0 || [clearBuf length] > (len - [self padLen])) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return NO;
    }
    
    [encryptedBuffer setLength:len];
    memset(encryptedBuffer.mutableBytes, 0, [encryptedBuffer length]);
    OSStatus status = 0;
    size_t lenWritten = [encryptedBuffer length];
    status = SecKeyEncrypt(publicKey, kSecPaddingPKCS1, clearBuf.bytes, [clearBuf length], encryptedBuffer.mutableBytes, &lenWritten);
    if (status != errSecSuccess) {
        [RSI_error fillError:err withCode:RSIErrorCryptoFailure andKeychainStatus:status];
        return NO;
    }

    [encryptedBuffer setLength:lenWritten];
    return YES;
}

/*
 *  Decrypt a data buffer.
 */
-(BOOL) decrypt:(NSData *) encryptedBuf intoBuffer: (RSI_securememory *) clearBuffer withError:(NSError **) err
{
    //  - Only a private key can decrypt
    if (!privateKey) {
        [RSI_error fillError:err withCode:RSIErrorInsufficientKey andFailureReason:@"A suitable private key does not exist."];
        return NO;
    }
    
    //  - I'm not going to assume we're using more than a block's length here because
    //    this is not very efficient.
    NSUInteger len = [self blockLen];
    if ([encryptedBuf length] < 1 || len == 0 || [encryptedBuf length] > len) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return NO;
    }
    
    [clearBuffer setLength:len];
    memset(clearBuffer.mutableBytes, 0, [clearBuffer length]);
    OSStatus status = 0;
    size_t lenWritten = [clearBuffer length];
    
    status = SecKeyDecrypt(privateKey, kSecPaddingPKCS1, encryptedBuf.bytes, [encryptedBuf length], clearBuffer.mutableBytes, &lenWritten);
    if (status != errSecSuccess) {
        [RSI_error fillError:err withCode:RSIErrorCryptoFailure andKeychainStatus:status];
        return NO;
    }
    
    [clearBuffer setLength:lenWritten];
    return YES;
}

/*
 *  Return the data for the public key in the keypair.
 */
-(NSData *) publicKey
{
    NSMutableDictionary *mdQuery = [RSI_pubcrypt dictionaryForPublic:YES andLabel:nil andTag:tag andBeBrief:YES];
    [mdQuery setObject:kSecMatchLimitOne forKey:kSecMatchLimit];
    [mdQuery setObject:[NSNumber numberWithBool:YES] forKey:kSecReturnData];
    
    NSData *pData = nil;
    [RSI_common RDLOCK_KEYCHAIN];
    OSStatus status = SecItemCopyMatching((CFDictionaryRef) mdQuery, (CFTypeRef *) &pData);
    [RSI_common UNLOCK_KEYCHAIN];
    if (status == errSecSuccess) {
        NSData *dRet = [NSData dataWithData:pData];
        //  SecItemCopyMatching allocates a new item
        CFRelease((CFTypeRef *) pData);
        return dRet;
    }
    return nil;
}

/*
 *  Return the data for the private key in the keypair.
 */
-(RSI_securememory *) privateKey
{
    NSMutableDictionary *mdQuery = [RSI_pubcrypt dictionaryForPublic:NO andLabel:nil andTag:tag andBeBrief:YES];
    [mdQuery setObject:kSecMatchLimitOne forKey:kSecMatchLimit];
    [mdQuery setObject:[NSNumber numberWithBool:YES] forKey:kSecReturnData];
    
    NSData *pData   = nil;
    [RSI_common RDLOCK_KEYCHAIN];
    OSStatus status = SecItemCopyMatching((CFDictionaryRef) mdQuery, (CFTypeRef *) &pData);
    [RSI_common UNLOCK_KEYCHAIN];
    if (status == errSecSuccess) {
        RSI_securememory *smRet = [RSI_securememory dataWithData:pData];
        //  SecItemCopyMatching allocates a new item
        CFRelease((CFTypeRef *) pData);
        return smRet;
    }
    return nil;
}

/*
 *  Find a list of all the tags that are of a specific polarity.
 */
+(NSArray *) findAllKeyTagsForPublic:(BOOL) pubKeys withError:(NSError **) err
{
    NSMutableDictionary *mdQuery = [NSMutableDictionary dictionary];
    [mdQuery setObject:kSecClassKey forKey:kSecClass];
    [mdQuery setObject:(pubKeys ? kSecAttrKeyClassPublic : kSecAttrKeyClassPrivate)  forKey:kSecAttrKeyClass];
    [mdQuery setObject:kSecAttrKeyTypeRSA forKey:kSecAttrKeyType];
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
    
    // - SecItemCopyMatching allocates a new value.
    if (attribs) {
        CFRelease((CFTypeRef *) attribs);
    }
    return ret;
}

/*
 *  Delete a specific key from the chain.
 */
+(BOOL) deleteKeyAsPublic:(BOOL) pubKey andTag:(NSString *) tag withError:(NSError **) err
{
    NSMutableDictionary *mdQuery = [RSI_pubcrypt dictionaryForPublic:pubKey andLabel:nil andTag:tag andBeBrief:YES];
    
    [RSI_common WRLOCK_KEYCHAIN];
    OSStatus status = SecItemDelete((CFDictionaryRef) mdQuery);
    [RSI_common UNLOCK_KEYCHAIN];
    if (status != errSecSuccess) {
        if (status == errSecItemNotFound) {
            [RSI_error fillError:err withCode:RSIErrorKeyNotFound];
        }
        else {
            [RSI_error fillError:err withCode:RSIErrorKeychainFailure andKeychainStatus:status];
        }
        return NO;
    }
    return YES;
}

/*
 *  Delete a specific keypair from the chain.
 */
+(BOOL) deleteKeyWithTag:(NSString *) tag withError:(NSError **) err
{
    if (![RSI_pubcrypt deleteKeyAsPublic:YES andTag:tag withError:err]) {
        return NO;
    }
    
    NSError *tmpErr = nil;
    if (![RSI_pubcrypt deleteKeyAsPublic:NO andTag:tag withError:&tmpErr] &&
        tmpErr && tmpErr.code != RSIErrorKeyNotFound) {
        if (err) {
            *err = tmpErr;
        }
        return NO;
    }
    return YES;
}

/*
 *  Delete all the keys of specific parity.
 */
+(BOOL) deleteAllKeysAsPublic:(BOOL) pubKey withError:(NSError **) err
{
    NSArray *arr = nil;
    arr = [RSI_pubcrypt findAllKeyTagsForPublic:pubKey withError:err];
    if (!arr) {
        return NO;
    }
    
    for (NSUInteger i = 0; i < [arr count]; i++) {
        if (![[arr objectAtIndex:i] isKindOfClass:[NSString class]]) {
            continue;
        }
        NSString *sTag = [arr objectAtIndex:i];
        if (![RSI_pubcrypt deleteKeyAsPublic:pubKey andTag:sTag withError:err]) {
            return NO;
        }
    }
    return YES;
}

/*
 *  Import a public key into the system.
 */
+(BOOL) importPublicKeyWithLabel:(NSString *) label andTag:(NSString *) tag andValue:(NSData *) keyData withError:(NSError **) err
{
    return [RSI_pubcrypt importKeyWithLabel:label andTag:tag andValue:keyData asPublic:YES withError:err];
}

/*
 *  Rename a public key in the system.
 */
+(BOOL) renamePublicKeyForLabel:(NSString *) oldLabel andTag:(NSString *) oldTag toNewLabel:(NSString *) newLabel andNewTag:(NSString *) newTag withError:(NSError **) err
{
    return [RSI_pubcrypt renameKeyWithLabel:oldLabel andTag:oldTag asPublic:YES toNewLabel:newLabel andNewTag:newTag withError:err];
}

/*
 *  Import a private key into the system.
 */
+(BOOL) importPrivateKeyWithLabel:(NSString *) label andTag:(NSString *) tag andValue:(RSI_securememory *) keyData withError:(NSError **) err
{
    return [RSI_pubcrypt importKeyWithLabel:label andTag:tag andValue:keyData.rawData asPublic:NO withError:err];
}

/*
 *  Rename a private key in the system.
 */
+(BOOL) renamePrivateKeyWithLabel:(NSString *) oldLabel andTag:(NSString *) oldTag toNewLabel:(NSString *) newLabel andNewTag:(NSString *) newTag withError:(NSError **) err
{
    return [RSI_pubcrypt renameKeyWithLabel:oldLabel andTag:oldTag asPublic:NO toNewLabel:newLabel andNewTag:newTag withError:err];
}

/*
 *  Use the private key to sign a buffer.
 */
-(BOOL) sign:(NSData *) dataBuffer intoBuffer:(NSMutableData *) signature withError:(NSError **) err
{
    if (!dataBuffer || ![dataBuffer length] || !signature) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return NO;
    }
    
    if (!privateKey) {
        [RSI_error fillError:err withCode:RSIErrorInsufficientKey andFailureReason:@"A suitable private key does not exist."];
        return NO;
    }
    
    // - HASHING-NOTE:
    //   - because the signing is an essential part of this model, we must always use the best possible hash algorithm.
    NSUInteger lenBlock = SecKeyGetBlockSize(privateKey);
    if ([RSI_SHA_SECURE SHA_LEN] > (lenBlock - 11)) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return NO;
    }
    
    //  - first create the hash used for the signature
    RSI_securememory *mdHash = [RSI_SHA_SECURE hashFromInput:dataBuffer];
    
    //  - now sign it.
    [signature setLength:lenBlock];
    memset(signature.mutableBytes, 0, lenBlock);
    
    OSStatus status = 0;
    size_t lenSigned = lenBlock;
    status = SecKeyRawSign(privateKey, [RSI_SHA_SECURE SEC_PADDING], mdHash.bytes, [mdHash length], signature.mutableBytes, &lenSigned);
    if (status != 0) {
        [RSI_error fillError:err withCode:RSIErrorCryptoFailure andKeychainStatus:status];
        return NO;
    }
    
    return YES;
}

/*
 *  Use the public key to verify a buffer.
 */
-(BOOL) verify:(NSData *) dataBuffer withBuffer:(NSData *) signature withError:(NSError **) err
{
    if (!dataBuffer || ![dataBuffer length] || !signature || ![signature length]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return NO;
    }
    
    if (!publicKey) {
        [RSI_error fillError:err withCode:RSIErrorInsufficientKey andFailureReason:@"A suitable public key does not exist."];
        return NO;
    }
    // - HASHING-NOTE:
    //   - because the signing is an essential part of this model, we must always use the best possible hash algorithm.
    // - first create the hash used for the signature
    RSI_securememory *mdHash = [RSI_SHA_SECURE hashFromInput:dataBuffer];
    
    //  - now verify it.
    OSStatus status = 0;
    status = SecKeyRawVerify(publicKey, [RSI_SHA_SECURE SEC_PADDING], mdHash.bytes, [mdHash length], signature.bytes, [signature length]);
    if (status != 0) {
        [RSI_error fillError:err withCode:RSIErrorCryptoFailure andKeychainStatus:status];
        return NO;
    }
    
    return YES;
}

@end

/***************************
 RSI_pubcrypt (internal)
 ***************************/
@implementation RSI_pubcrypt (internal)

/*
 *  Return a standard dictionary for the given key type.
 */
+(NSMutableDictionary *) dictionaryForPublic:(BOOL) pubKey andLabel:(NSString *) label andTag:(NSString *) tag andBeBrief:(BOOL) brief
{
    NSMutableDictionary *mdRet = [NSMutableDictionary dictionary];
    [mdRet setObject:kSecClassKey forKey:kSecClass];
    [mdRet setObject:kSecAttrKeyTypeRSA forKey:kSecAttrKeyType];
    [mdRet setObject:(pubKey ? kSecAttrKeyClassPublic : kSecAttrKeyClassPrivate) forKey:kSecAttrKeyClass];
    if (label) {
        [mdRet setObject:label forKey:kSecAttrLabel];
    }
    if (tag) {
        NSData *dTag = [tag dataUsingEncoding:NSUTF8StringEncoding];
        [mdRet setObject:dTag forKey:kSecAttrApplicationTag];
    }
    
    if (!brief) {
        [mdRet setObject:[NSNumber numberWithBool:YES] forKey:kSecAttrIsPermanent];
        [mdRet setObject:[NSNumber numberWithBool:!pubKey] forKey:kSecAttrCanDecrypt];
        [mdRet setObject:[NSNumber numberWithBool:pubKey] forKey:kSecAttrCanEncrypt];
        [mdRet setObject:[NSNumber numberWithBool:NO] forKey:kSecAttrCanDerive];
        [mdRet setObject:[NSNumber numberWithBool:!pubKey] forKey:kSecAttrCanSign];
        [mdRet setObject:[NSNumber numberWithBool:pubKey] forKey:kSecAttrCanVerify];
        [mdRet setObject:[NSNumber numberWithBool:NO] forKey:kSecAttrCanUnwrap];
    }

    return mdRet;
}

/*
 *  Initialize the object with a public and (an optional) private key
 */
-(id) initWithTag:(NSString *) t andPublic:(SecKeyRef) pubK andPrivate:(SecKeyRef) prvK
{
    self = [super init];
    if (self) {
        publicKey = 0;
        privateKey = 0;
        
        tag = [[NSString alloc] initWithString:t];
        
        if (pubK) {
            publicKey = (SecKeyRef) CFRetain(pubK);
        }
        
        if (prvK) {
            privateKey = (SecKeyRef) CFRetain(prvK);
        }
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [tag release];
    tag = nil;
    
    if (publicKey) {
        CFRelease(publicKey);
        publicKey = 0;
    }
    
    if (privateKey) {
        CFRelease(privateKey);
        privateKey = 0;
    }
    [super dealloc];
}

/*
 *  Import a key into the library.
 */
+(BOOL) importKeyWithLabel:(NSString *) label andTag:(NSString *) tag andValue:(NSData *) keyData asPublic:(BOOL) ispub withError:(NSError **) err
{
    if (!tag || ![tag length] || !keyData || ![keyData length]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return NO;
    }
    
    NSMutableDictionary *dKeyDef = [RSI_pubcrypt dictionaryForPublic:ispub andLabel:label andTag:tag andBeBrief:NO];
    [dKeyDef setObject:[NSNumber numberWithUnsignedInteger:PUB_PRV_BITSIZE] forKey:kSecAttrKeySizeInBits];
    [dKeyDef setObject:keyData forKey:kSecValueData];
    
    [RSI_common WRLOCK_KEYCHAIN];
    OSStatus status = SecItemAdd((CFDictionaryRef) dKeyDef, NULL);
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
 *  Rename a key in the library.
 */
+(BOOL) renameKeyWithLabel:(NSString *) oldLabel andTag:(NSString *) oldTag asPublic:(BOOL) ispub toNewLabel:(NSString *) newLabel andNewTag:(NSString *) newTag withError:(NSError **) err
{
    if (!oldLabel || !oldTag || !newLabel || !newTag) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return NO;
    }
    
    NSMutableDictionary *mdQuery = [RSI_pubcrypt dictionaryForPublic:ispub andLabel:oldLabel andTag:oldTag andBeBrief:YES];
    
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

@end


