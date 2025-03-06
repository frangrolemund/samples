//
//  RSI_seal_ring.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/18/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RSI_keyring.h"
#import "RSI_scrambler.h"
#import "RSI_symcrypt.h"
#import "RSI_pubcrypt.h"
#import "RSI_common.h"
#import "RSI_pack.h"
#import "RSI_unpack.h"
#import "RSI_secure_props.h"

//  - local data
static NSString *RSI_SR_TMP_KEY            = @"tmpkey";
static NSString *RSI_SR_CACHED_KEY         = @"cachedKey";
static NSString *RSI_SR_PROP_ID            = @"id";
static NSString *RSI_SR_PROP_SYMKEY        = @"symk";
static NSString *RSI_SR_PROP_PUBKEY        = @"pubk";
static NSString *RSI_SR_PROP_PRVKEY        = @"prvk";
static NSString *RSI_SR_PROP_ATTRIB        = @"attrib";
static NSString *RSI_SR_PROP_SCRAMKEY      = @"scramk";

static NSString *RSI_SCRAMI_CODER_BUF      = @"image";
static NSString *RSI_SCRAMI_CODER_FLAG     = @"isuiimage";

static NSObject       *synchKeyring        = nil;
static NSMutableArray *maKeyringCache      = nil;

static NSMutableArray   *sparePubKeys      = nil;
static dispatch_queue_t asyncGenQueue      = NULL;
static NSObject         *genLock           = nil;
static BOOL             isAsyncGenerating  = NO;

//  - a simple container for caching keyring attributes
@interface RSI_cached_keyring : NSObject
{
    NSString *sealId;
    BOOL     isProducer;
}

+(RSI_cached_keyring *) cachedKeyringForId:(NSString *) sealId andIsProducer:(BOOL) isProd;

@property (nonatomic, retain) NSString *sealId;
@property (nonatomic, assign) BOOL isProducer;
@end

//  - a simple container for serializing a scrambled image
@interface RSI_scrambled_image : NSObject <NSCoding>
{
    NSData *dImage;
    BOOL   isUIImage;
}

-(id) initWithData:(NSData *) dimg andUIFlag:(BOOL) uiimg;
-(id) objectForDataUsingScrambler:(RSI_scrambler *) scram withError:(NSError **) err;
@end

//  - the secure property archive types created by this file
typedef enum
{
    KM_PRODUCER = RSI_SECPROP_MSG_PROD,
    KM_CONSUMER = RSI_SECPROP_MSG_CONS,
    KM_LOCAL    = RSI_SECPROP_MSG_LOCAL,
    KM_ROLE_HIGHEST                         //  adapts to either producer or consumer, whichever the higher can be achived.
} rsi_keyring_msg_t;

//  - forward declarations
@interface RSI_keyring (internal)
+(NSString *) insecureHeaderStringHashForData:(NSData *) d;
+(BOOL) verifyKeyringCacheWithError:(NSError **) err;
+(void) freshenKeyringInCache:(NSUInteger) index;
+(void) freeKeyringCache;
-(id) initWithSealId:(NSString *) sid andCreationExport:(NSMutableDictionary *) mdExport;
+(NSString *) generateSealIdFromScrambler:(RSI_securememory *) scramData andRSAKey:(RSI_pubcrypt *) rsa andSymmtricKey:(RSI_symcrypt *) sym;
+(BOOL) importKeysWithId:(NSString *) newSid andPublicData:(NSData *) pubk andPrivateData:(RSI_securememory *) prvk andSymData:(RSI_securememory *) symk
            andScramData:(RSI_securememory *) scramk andAttributes:(RSI_securememory *) attrib withError:(NSError **) err;
-(NSData *) encryptMessage:(NSDictionary *) msg asType:(rsi_keyring_msg_t) msgType withError:(NSError **) err;
-(NSData *) encryptMessageInPool:(NSDictionary *) msg asType:(rsi_keyring_msg_t) msgType withError:(NSError **) err;
-(NSObject *) modifyCollection:(NSObject *) obj withScrambler:(RSI_scrambler *) scram andDoScramble:(BOOL) doScramble andError:(NSError **) err;
-(RSI_scrambled_image *) scrambleImage:(UIImage *) img withScrambler:(RSI_scrambler *) scram andError:(NSError **) err;
-(RSI_scrambled_image *) scrambleJPEG:(NSData *) jpeg withScrambler:(RSI_scrambler *) scram andError:(NSError **) err;
-(NSDictionary *) decryptMessageProperties:(NSArray *) props forType:(rsi_keyring_msg_t) msgType withError:(NSError **) err;
+(void) generateSparePublicKey;
+(NSMutableDictionary *) buildExportForExternal:(BOOL) forExternal andSeal:(NSString *) sealId andSymKey:(RSI_symcrypt *) symk andPubKey:(RSI_pubcrypt *) pubk
                                  andAttributes:(RSI_securememory *) attribs andScramblerData:(RSI_securememory *) scramData withError:(NSError **) err;
+(BOOL) isSealInCache:(NSString *) sealId;
@end

/**************************
 RSI_keyring
 **************************/
@implementation RSI_keyring
{
    //  - be very cautious about storing anything in this object because
    //    some types of keys are not referenced indirectly through the keychain
    //    and will store sensitive key data in memory while they are allocated.
    NSString *sealId;
    
    
    //  - because the export process is very expensive, during creation, we will store the export temporarily
    //    and only for a single access.  This is to accommodate the fact that we have the keys during creation and could
    //    easily save them instead of doing a subsequent search.
    //  - if this attribute doesn't exist, we will go through the more elaborate processing.
    NSMutableDictionary *mdCreationExportForLocal;
}

/*
 *  Initialize the keyring module.
 */
+(void) initialize
{
    // - the pub keys array will be used for synchronization also.
    sparePubKeys = [[NSMutableArray alloc] init];
    genLock      = [[NSObject alloc] init];
    
    // - accesses to the common keyring cache use this object.
    synchKeyring = [[NSObject alloc] init];
}

/*
 *  Free the object
 */
-(void) dealloc
{
    [sealId release];
    sealId = nil;
    
    [mdCreationExportForLocal release];
    mdCreationExportForLocal = nil;
    
    [super dealloc];
}

/*
 *  Get the id of the seal.
 */
-(NSString *) sealId
{
    return [[sealId retain] autorelease];
}

/*
 *  Allocate a new collection of seal keys.
 */
+(RSI_keyring *) allocNewRingUsingScramblerData:(RSI_securememory *) scrData andAttributes:(NSData *) attribs withError:(NSError **) err
{
    if (!scrData) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument andFailureReason:@"Missing scrambler data."];
        return nil;
    }
    
    if (attribs && [attribs length] > [RSI_keyring attributeDataLength]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument andFailureReason:@"Attributes exceed capacity."];
        return nil;
    }
    
    //  - the seal has four types of keys associated with it:
    //    1.  symmetric key
    //    2.  public key
    //    3.  private key
    //    4.  scrambler key.
    //  - when allocating, all four must be created or the object is not valid.
    //  - since all are connected with the seal id, they must be temporarily created, exported, and then reimported with the
    //    correct key.
    
    NSError *tmp                         = nil;
    RSI_keyring *keys                    = nil;
    NSMutableDictionary *mdInitialExport = nil;
    
    //  - don't leave these objects laying around because they are sensitive
    @autoreleasepool {
        RSI_pubcrypt *pubPrv = nil;
        RSI_symcrypt *sym = nil;
        NSString     *newSid = nil;
        
        //  - create temporary versions that we can export.        
        @synchronized (sparePubKeys) {
            //  - first attempt to pull a cached key
            NSString *pubKeyLabel = nil;
            if ([sparePubKeys count]) {
               pubKeyLabel = [sparePubKeys objectAtIndex:0];
                NSRange r = [pubKeyLabel rangeOfString:RSI_SR_CACHED_KEY];
                if (r.location == 0) {
                    [[pubKeyLabel retain] autorelease];
                    [sparePubKeys removeObjectAtIndex:0];
                    pubPrv = [RSI_pubcrypt allocExistingKeyForTag:pubKeyLabel withError:&tmp];
                    if (!pubPrv) {
                        //  - delete it in case it was some sort of corruption that caused the failure.                        
                        NSLog(@"RSI: Failed to allocate the existing cached key.  %@", [tmp localizedDescription]);
                        [RSI_pubcrypt deleteKeyWithTag:pubKeyLabel withError:nil];
                        pubKeyLabel = nil;
                    }
                }
                else {
                    // - this shouldn't happen but could mean a serious issue is wrong with the caching and
                    //   we would never want to accidentally delete it.
                    NSLog(@"RSI: Invalid cached seal identified --> %@", pubKeyLabel);
                    pubKeyLabel = nil;
                }
            }
            
            //  - if there was nothing cached, then 
            if (!pubPrv) {
                pubKeyLabel = RSI_SR_TMP_KEY;
                [RSI_pubcrypt deleteKeyWithTag:RSI_SR_TMP_KEY withError:nil];                
                pubPrv = [RSI_pubcrypt allocNewKeyForPublicLabel:pubKeyLabel andPrivateLabel:pubKeyLabel andTag:pubKeyLabel withError:&tmp];
            }
            
            if (pubPrv) {
                [RSI_symcrypt deleteKeyWithType:CSSM_ALGID_SYM_SEAL andTag:RSI_SR_TMP_KEY withError:nil];
                sym = [RSI_symcrypt allocNewKeyForLabel:RSI_SR_TMP_KEY andType:CSSM_ALGID_SYM_SEAL andTag:RSI_SR_TMP_KEY withError:&tmp];
                if (sym) {
                    newSid = [RSI_keyring generateSealIdFromScrambler:scrData andRSAKey:pubPrv andSymmtricKey:sym];
                }
            }
            
            //  - rename/import them in the keychain to create the ones we need.
            //  - renaming is used instead of importing to optimize the process during seal creation.
            RSI_securememory *initialAttributes = [RSI_securememory dataWithLength:[RSI_keyring attributeDataLength]];
            if (attribs && [attribs length]) {
                memcpy(initialAttributes.mutableBytes, attribs.bytes, [attribs length]);
            }
            if (pubPrv && sym && newSid) {
                // - produce an export while we still have the keys in order
                //   to optimize seal creation.
                NSMutableDictionary *mdExported = [RSI_keyring buildExportForExternal:NO
                                                                              andSeal:newSid
                                                                            andSymKey:sym
                                                                            andPubKey:pubPrv
                                                                        andAttributes:initialAttributes
                                                                     andScramblerData:scrData
                                                                            withError:nil];
                
                if ([RSI_keyring deleteRingWithSealId:newSid andError:err] &&
                    [RSI_pubcrypt renamePublicKeyForLabel:pubKeyLabel andTag:pubKeyLabel toNewLabel:newSid andNewTag:newSid withError:err] &&
                    [RSI_pubcrypt renamePrivateKeyWithLabel:pubKeyLabel andTag:pubKeyLabel toNewLabel:newSid andNewTag:newSid withError:err] &&
                    [RSI_symcrypt renameKeyForLabel:RSI_SR_TMP_KEY andType:CSSM_ALGID_SYM_SEAL andTag:RSI_SR_TMP_KEY toNewLabel:newSid andNewTag:newSid withError:err] &&
                    [RSI_scrambler importKeyWithLabel:newSid andTag:newSid andValue:scrData withError:err] &&
                    [RSI_symcrypt importKeyWithLabel:newSid andType:CSSM_ALGID_SYM_ATTRIBUTES andTag:newSid andValue:initialAttributes withError:err]) {
                    
                    // - success, so save the exported content.
                    mdInitialExport = mdExported;
                }
                else {
                    // - try do delete what we can.
                    [RSI_pubcrypt deleteKeyWithTag:pubKeyLabel withError:nil];
                    [RSI_symcrypt deleteKeyWithType:CSSM_ALGID_SYM_SEAL andTag:RSI_SR_TMP_KEY withError:nil];
                    [RSI_pubcrypt deleteKeyWithTag:newSid withError:nil];
                    [RSI_symcrypt deleteKeyWithType:CSSM_ALGID_SYM_SEAL andTag:newSid withError:nil];
                    [RSI_scrambler deleteKeyWithTag:newSid withError:nil];
                    newSid = nil;
                }
            }
            
            [pubPrv release];
            pubPrv = nil;
            
            [sym release];
            sym = nil;
        }
        
        if (newSid) {
            keys = [[RSI_keyring alloc] initWithSealId:newSid andCreationExport:mdInitialExport];
            [RSI_keyring freeKeyringCache];
        }
        [tmp retain];
    }
    
    [tmp autorelease];
    if (err) {
        *err = tmp;
    }
    
    return keys;
}

/*
 *  Delete the key ring for the given seal id.
 */
+(BOOL) deleteRingWithSealId:(NSString *) sealId andError:(NSError **) err
{
    @synchronized (synchKeyring) {
        [RSI_keyring freeKeyringCache];
        
        NSError *tmp = nil;
        BOOL ret     = YES;
        if (![RSI_symcrypt deleteKeyWithType:CSSM_ALGID_SYM_SEAL andTag:sealId withError:&tmp] &&
            tmp.code != RSIErrorKeyNotFound) {
            if (err) {
                *err = tmp;
            }
            ret = NO;
        }
        
        if (![RSI_scrambler deleteKeyWithTag:sealId withError:&tmp] &&
            tmp.code != RSIErrorKeyNotFound) {
            if (err) {
                *err = tmp;
            }
            ret = NO;
        }
        
        if (![RSI_pubcrypt deleteKeyWithTag:sealId withError:&tmp] &&
            tmp.code != RSIErrorKeyNotFound) {
            if (err) {
                *err = tmp;
            }
            ret = NO;
        }
        if (![RSI_symcrypt deleteKeyWithType:CSSM_ALGID_SYM_ATTRIBUTES andTag:sealId withError:&tmp] &&
            tmp.code != RSIErrorKeyNotFound) {
            if (err) {
                *err = tmp;            
            }
            ret = NO;
        }
        
        return ret;
    }
}

/*
 *  Delete all the keyrings in the system.
 */
+(BOOL) deleteAllKeyringsWithError:(NSError **) err
{
    [RSI_keyring freeKeyringCache];
    
    NSArray *arr = [RSI_keyring availableKeyringsWithError:err];
    if (!arr) {
        return NO;
    }
    
    for (NSUInteger i = 0; i < [arr count]; i++) {
        NSString *s = [arr objectAtIndex:i];
        if (![RSI_keyring deleteRingWithSealId:s andError:err]) {
            return NO;
        }
    }
    
    return YES;
}

/*
 *  Return a list of all keyrings in the system.
 */
+(NSArray *) availableKeyringsWithError:(NSError **) err
{
    return [RSI_symcrypt findAllKeyTagsForType:CSSM_ALGID_SYM_SEAL withError:err];
}

/*
 *  Allocate an existing ring that is supposed to be saved on the keychain.
 *  - we intentionally don't validate the id at this point because that will hammer the
 *    keychain if many are processsed sequentially.
 */
+(RSI_keyring *) allocExistingWithSealId:(NSString *) sid
{
    RSI_keyring *kr = [[RSI_keyring alloc] initWithSealId:sid andCreationExport:nil];
    return kr;
}

/*
 *  Verifies that the necessary components exist for the seal.
 */
-(BOOL) isValid
{
    RSI_symcrypt *sk = [RSI_symcrypt allocExistingKeyForType:CSSM_ALGID_SYM_SEAL andTag:sealId withError:nil];
    if (!sk) {
        return NO;
    }
    
    RSI_pubcrypt *pk = [RSI_pubcrypt allocExistingKeyForTag:sealId withError:nil];
    RSI_scrambler *scram = [RSI_scrambler allocExistingKeyForTag:sealId withError:nil];

    BOOL ret = YES;
    if (!pk || !sk || !scram) {
        ret = NO;
    }
    [pk release];
    [sk release];
    [scram release];

    return ret;
}

/*
 *  Determines if this keyring is owned by the holder.
 */
-(BOOL) isOwnersKeyring
{
    RSI_pubcrypt *pk = [[RSI_pubcrypt allocExistingKeyForTag:sealId withError:nil] autorelease];
    if (pk && [pk isFullKey]) {
        return YES;
    }
    return NO;
}

/*
 *  Export the componenents of this ring to a collection.
 */
-(NSMutableDictionary *) exportForExternal:(BOOL) forExternal withAlternateAttributes:(RSI_securememory *) altAttrib andError:(NSError **) err
{
    // - during ring creation we will store the full export briefly to optimize seal creation, but
    //   it is only good for a single request.
    if (!forExternal && mdCreationExportForLocal) {
        NSMutableDictionary *mdRet = mdCreationExportForLocal;
        mdCreationExportForLocal   = nil;
        return [mdRet autorelease];
    }
    
    // - otherwise, do this the hard way by consulting the keychain.
    RSI_pubcrypt *pubk = [RSI_pubcrypt allocExistingKeyForTag:sealId withError:err];
    if (!pubk) {
        return nil;
    }
    
    if (altAttrib && [altAttrib length] != [RSI_symcrypt keySize]) {
        [pubk release];
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return nil;
    }
    
    //  - we never allow someone else's keys to be exported externally.
    if (forExternal && ![pubk isFullKey]) {
        [pubk release];
        [RSI_error fillError:err withCode:RSIErrorUnsupportedConsumerAction];
        return nil;
    }
    
    RSI_scrambler *scram = nil;
    RSI_symcrypt *symk = [RSI_symcrypt allocExistingKeyForType:CSSM_ALGID_SYM_SEAL andTag:sealId withError:err];
    if (symk) {
        scram = [RSI_scrambler allocExistingKeyForTag:sealId withError:err];
    }
    RSI_symcrypt *attrib = [RSI_symcrypt allocExistingKeyForType:CSSM_ALGID_SYM_ATTRIBUTES andTag:sealId withError:err];
    
    NSMutableDictionary *mdExported = nil;
    if (pubk && scram && symk && attrib) {
        mdExported = [RSI_keyring buildExportForExternal:forExternal
                                                 andSeal:sealId
                                               andSymKey:symk
                                               andPubKey:pubk
                                           andAttributes:altAttrib ? altAttrib : attrib.key
                                        andScramblerData:scram.key
                                               withError:err];
    }
    [pubk release];
    [symk release];
    [scram release];
    [attrib release];
    
    return mdExported;
}

/*
 *  Given an export dictionary, return the id of the seal inside.
 */
+(NSString *) sealForCollection:(NSDictionary *) srExportedData
{
    NSString *ret = nil;
    if (srExportedData &&
        [[srExportedData objectForKey:RSI_SR_PROP_ID] isKindOfClass:[NSString class]]) {
        ret = [srExportedData objectForKey:RSI_SR_PROP_ID];
    }
    return ret;
}

/*
 *  Import an exported ring.
 */
+(NSString *) importFromCollection:(NSDictionary *) srExportedData andSeparateScramblerData:(RSI_securememory *) scrData withError:(NSError **) err
{
    NSError *tmp = nil;
    NSString *importedId = nil;
    
    if (!srExportedData ||
        ![[srExportedData objectForKey:RSI_SR_PROP_ID] isKindOfClass:[NSString class]] ||
        ![[srExportedData objectForKey:RSI_SR_PROP_SYMKEY] isKindOfClass:[RSI_securememory class]] ||
        ![[srExportedData objectForKey:RSI_SR_PROP_PUBKEY] isKindOfClass:[NSData class]] ||
        ([srExportedData objectForKey:RSI_SR_PROP_SCRAMKEY] != nil && ![[srExportedData objectForKey:RSI_SR_PROP_SCRAMKEY] isKindOfClass:[RSI_securememory class]]) ||
        (![srExportedData objectForKey:RSI_SR_PROP_SCRAMKEY] && !scrData) ||
        ([srExportedData objectForKey:RSI_SR_PROP_PRVKEY] != nil && ![[srExportedData objectForKey:RSI_SR_PROP_PRVKEY] isKindOfClass:[RSI_securememory class]]) ||
        ![[srExportedData objectForKey:RSI_SR_PROP_ATTRIB] isKindOfClass:[RSI_securememory class]]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return nil;
    }
    
    @autoreleasepool {
        NSString *sealId = [srExportedData objectForKey:RSI_SR_PROP_ID];
        RSI_securememory *symKeyData = [srExportedData objectForKey:RSI_SR_PROP_SYMKEY];
        NSData *pubKeyData = [srExportedData objectForKey:RSI_SR_PROP_PUBKEY];
        RSI_securememory *scramKey = [srExportedData objectForKey:RSI_SR_PROP_SCRAMKEY];
        if (scrData) {
            scramKey = scrData;
        }
        RSI_securememory *prvKey = [srExportedData objectForKey:RSI_SR_PROP_PRVKEY];
        RSI_securememory *attrib = [srExportedData objectForKey:RSI_SR_PROP_ATTRIB];
        
        //  - now pull them all into the keychain.
        if ([RSI_keyring importKeysWithId:sealId andPublicData:pubKeyData andPrivateData:prvKey andSymData:symKeyData andScramData:scramKey andAttributes:attrib withError:&tmp]) {
            importedId = sealId;
            [RSI_keyring freeKeyringCache];
        }
        
        [tmp retain];
    }

    [tmp autorelease];
    if (err) {
        *err = tmp;
    }
    
    return importedId;
}

/*
 *  Encrypt a producer message with the seal, implying that all that have the seal can
 *  read it.
 */
-(NSData *) encryptProducerMessage:(NSDictionary *) msg withError:(NSError **) err
{
    return [self encryptMessageInPool:msg asType:KM_PRODUCER withError:err];
}

/*
 *  Encrypt a consumer message, implying that only a producer can read it.
 */
-(NSData *) encryptConsumerMessage:(NSDictionary *) msg withError:(NSError **) err
{
    return [self encryptMessageInPool:msg asType:KM_CONSUMER withError:err];
}

/*
 *  Encrypt a local message, which doesn't sign or secondarily encrypt the message.
 */
-(NSData *) encryptLocalOnlyMessage:(NSDictionary *) msg withError:(NSError **) err
{
    return [self encryptMessageInPool:msg asType:KM_LOCAL withError:err];
}

/*
 *  Encrypt a message with the highest-qualifying role that for the 
 *  possessor of the keyring.
 */
-(NSData *) encryptRoleBasedMessage:(NSDictionary *) msg withError:(NSError **)err
{
    return [self encryptMessageInPool:msg asType:KM_ROLE_HIGHEST withError:err];
}

/*
 *  Attempt to decrypt a message using the seal.
 */
-(NSDictionary *) decryptMessage:(NSData *) d isProducerMessage:(BOOL *) isProducerGenerated withError:(NSError **) err
{
    NSError *tmp = nil;
    NSDictionary *ret = nil;
    
    if (isProducerGenerated) {
        *isProducerGenerated = NO;
    }
    
    //  - do everything in an an autorelease pool to ensure that
    //    symmetric keys are deleted immediately after use.
    @autoreleasepool {
        RSI_symcrypt *symk = [RSI_symcrypt allocExistingKeyForType:CSSM_ALGID_SYM_SEAL andTag:sealId withError:&tmp];
        RSI_secure_props *secProps = [[RSI_secure_props alloc] initWithType:RSI_SECPROP_NONE andVersion:RSI_SECURE_VERSION andKey:symk];
        uint16_t propType = 0;
        if (symk) {
            RSI_securememory *secMem = [secProps decryptIntoData:d withDeferredTypeChecking:&propType andError:&tmp];
            if (secMem && (propType == RSI_SECPROP_MSG_PROD || propType == RSI_SECPROP_MSG_CONS || propType == RSI_SECPROP_MSG_LOCAL)) {
                
                //  - there are two high-level elements in every message and in the interest of
                //    efficiency, they are explicitly packed here instead of using
                //    a keyed archive.
                const unsigned char *ptr = (const unsigned char *) secMem.bytes;
                NSData *d1 = nil;
                NSData *d2 = nil;
                NSUInteger len = [secMem length];
                
                //  - the first is the message itself, possibly encrypted.
                if (len > 4) {
                    uint32_t lenData = [RSI_common longFromPtr:ptr];
                    ptr += 4;
                    len -= 4;
                    
                    if (lenData <= len) {
                        d1 = [NSData dataWithBytesNoCopy:(void *) ptr length:lenData freeWhenDone:NO];
                        len -= lenData;
                        ptr += lenData;
                    }
                }
                
                //  - the second is a signature or an encrypted symmetric key, depending on the message
                if (len >= 4) {
                    uint32_t lenData = [RSI_common longFromPtr:ptr];
                    ptr += 4;
                    len -= 4;
                    
                    if (lenData == len) {
                        d2 = [NSData dataWithBytesNoCopy:(void *) ptr length:lenData freeWhenDone:NO];
                    }
                }
                
                //  - if you don't have both, then there is nothing that can be done.
                if (d1 && d2) {
                    ret = [self decryptMessageProperties:[NSArray arrayWithObjects:d1, d2, nil] forType:propType withError:&tmp];
                    if (ret && isProducerGenerated) {
                        *isProducerGenerated = (propType == RSI_SECPROP_MSG_PROD);
                    }
                }
                else {
                    [RSI_error fillError:&tmp withCode:RSIErrorInvalidSealedMessage andFailureReason:@"Inconsistent data format."];
                }
            }
            else {
                [RSI_error fillError:&tmp withCode:RSIErrorSecurePropsVersionMismatch andFailureReason:@"Unsupported secure message type."];
            }
        }
        [secProps release];
        [symk release];

        [ret retain];
        [tmp retain];
    }
    
    [tmp autorelease];
    if (err) {
        *err = tmp;
    }
    
    return [ret autorelease];
}

/*
 *  This is a limited hash of only the data header, but if it is compared to
 *  content that was previously decrypted successfully, is guaranteed to be unique
 *  and a reliable way to identify partial matches for a packed stream.
 */
+(NSString *) hashForEncryptedMessage:(NSData *) dMsg withError:(NSError **) err
{
    // - HASHING-NOTE:
    //      - I gave some thought to whether I wanted to use a secure hash or not for this data and
    //        even though it is conceivable that a manufactured collision could cause us to try to
    //        process a bogus message before the official one arrives, the only time we actually save
    //        a message hash is when a message is processed successfully, which means it depends on the
    //        symmetric and RSA encryption keys.   Therefore, in that case, a manufactured collision would
    //        be no different than any bogus content that may arrive that we must rule out.   Insecure
    //        hashing is sufficient for this purpose.
    
    // - the guarantee comes from the fact that the header can only be decrypted by the keyring and it
    //   contains CRCs for itself and for the data that follows.  There is no other sequence of bytes
    //   that could be equally self-consistent and unlocked by the encryption key.
    // - my purpose in using this kind of approach is to minimize on network reads whenever possible since
    //   they are costly on a phone and consume valuable time that could be spent downloading other content.
    NSString *sRet = [RSI_keyring insecureHeaderStringHashForData:dMsg];
    if (!sRet) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSealedMessage];
        return nil;
    }
    return sRet;
}

/*
 *  The purpose of this method is to determine as quickly as possible whether the provided message blob an be opened by
 *  the local key rings.   If so, it can optionally unpack the data.
 *  - when we simply cannot find a matching seal, we will return a secure message object with no items filled-in, but if
 *    there are likely keychain problems, we will return a nil.
 */
+(RSISecureMessage *) identifyEncryptedMessage:(NSData *) dMsg withFullDecryption:(BOOL) fullDecryption andError:(NSError **) err
{
    if (!dMsg || [dMsg length] < [RSI_secure_props propertyHeaderLength]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSealedMessage];
        return nil;
    }
    
    // - I'm using a rather big lock here for identification of encrypted messages because I'm not sure I want to have
    //   a lot of parallel identification happening because it is so CPU-intensive.  Not only will it make the phone hot after
    //   a while but it could slow things down everywhere and that seems counter-productive.  We'll do one of these at a time.
    @synchronized (synchKeyring) {
        // - the seal cache is important for minimizing the hit when identifying producer keyring-created messages.
        if (![RSI_keyring verifyKeyringCacheWithError:err]) {
            return nil;
        }
        
        // - look through each seal one at a time to figure out if it can process the message.
        RSISecureMessage *smRet = [[[RSISecureMessage alloc] init] autorelease];
        NSError *tmp            = nil;
        for (NSUInteger krIndex = 0; krIndex < [maKeyringCache count]; krIndex++) {
            RSI_cached_keyring *ck = [maKeyringCache objectAtIndex:krIndex];
            
            //  - operate in an autorelease pool to ensure that the symmetric keys are
            //    destroyed as soon as they are done being used.
            @autoreleasepool {
                RSI_symcrypt *symk = [[RSI_symcrypt allocExistingKeyForType:CSSM_ALGID_SYM_SEAL andTag:ck.sealId withError:&tmp] autorelease];
                if (symk) {
                    uint16_t propType = 0;
                    if ([RSI_secure_props isValidSecureProperties:dMsg forVersion:RSI_SECURE_VERSION usingKey:symk andReturningType:&propType withError:nil]) {
                        // - if these checks don't pass, we're likely trying to identify a locally-encrypted message, which we never
                        //   want to be able to do so minimize their use externally.
                        if (propType == RSI_SECPROP_MSG_PROD || (propType == RSI_SECPROP_MSG_CONS && ck.isProducer)) {
                            smRet.sealId              = ck.sealId;
                            smRet.hash                = [RSI_keyring insecureHeaderStringHashForData:dMsg];
                            if (fullDecryption) {
                                RSI_keyring *kr           = [RSI_keyring allocExistingWithSealId:ck.sealId];
                                BOOL isProducer           = NO;
                                smRet.dMessage            = [kr decryptMessage:dMsg isProducerMessage:&isProducer withError:&tmp];
                                smRet.isProducerGenerated = isProducer;
                                [kr release];
                                if (!smRet.dMessage) {
                                    // - if the mesage cannot be decrypted but we had good secure properties, this is corrupted and
                                    //   must be considered a serious failure.
                                    smRet = nil;
                                    [tmp retain];
                                }
                            }
                        }
                        
                        // - make sure the keyring is used first next time.
                        [self freshenKeyringInCache:krIndex];
                        
                        //  - don't bother looking any more, we found a key for this data.
                        break;
                    }
                }
                else {
                    // - any keychain error must be reported
                    smRet = nil;
                    [tmp retain];
                    break;
                }
            }
        }
        
        // - it is important that if we didn't find a seal, but there was nothing that smelled of a keychain error (due to low storage, possibly), that
        //   we return something.  A failure to find a seal returns a good object, but no seal id.  A failure to use the keychain is more serious and will return
        //   a hard failure.
        if (!smRet || !smRet.sealId) {
            if (err) {
                if (tmp) {
                    *err = [tmp autorelease];
                }
                else {
                    [RSI_error fillError:err withCode:RSIErrorInvalidSealedMessage];
                }
            }
        }
        return smRet;
    }
}

/*
 *  Perform a superficial check to see if the seal exists in the keychain.
 */
+(BOOL) ringForSeal:(NSString *) sealId existsWithError:(NSError **) err
{
    RSI_symcrypt *sk = [RSI_symcrypt allocExistingKeyForType:CSSM_ALGID_SYM_SEAL andTag:sealId withError:err];
    BOOL ret = YES;
    if (!sk) {
        ret = NO;
    }
    [sk release];
    return ret;
}

/*
 *  Nearly all the cost associated with seal creation is tied up in the public key generation.  Keep a
 *  spare lying around at all times in order to guarantee that seals can be created quickly.
 *  - I initially did this automatically after keyring construction but found that the needs of the app
 *    required more precise control over when this was performed.
 */
+(void) prepareForSealGeneration
{
    @synchronized (genLock)
    {
        if (!asyncGenQueue) {
            asyncGenQueue = dispatch_queue_create("kr_async_gen", NULL);
        }
        if (isAsyncGenerating) {
            return;
        }
    }
    [RSI_keyring generateSparePublicKey];
}

/*
 *  Stop async computation.
 */
+(void) stopAsyncCompute
{
    @synchronized (genLock) {
        if (asyncGenQueue) {
            dispatch_release(asyncGenQueue);
            asyncGenQueue = NULL;
        }
    }
}

/*
 *  The keyring can have associated attributes, but they are of limited length.
 */
+(NSUInteger) attributeDataLength
{
    return [RSI_symcrypt keySize];
}

/*
 *  Return the attributes stored with this keyring.
 */
-(RSI_securememory *) attributeDataWithError:(NSError **) err
{
    RSI_symcrypt *sk = [[RSI_symcrypt allocExistingKeyForType:CSSM_ALGID_SYM_ATTRIBUTES andTag:sealId withError:err] autorelease];
    if (!sk) {
        return nil;
    }
    return [RSI_securememory dataWithSecureData:sk.key];
}

/*
 *  Update the attributes for this keyring.
 */
-(BOOL) setAttributesWithData:(RSI_securememory *) newAttributes andError:(NSError **) err
{
    @synchronized (synchKeyring) {
        // - first make sure that the keyring wasn't deleted by some other thread with a different object instance.
        if (![RSI_keyring isSealInCache:sealId]) {
            [RSI_error fillError:err withCode:RSIErrorInvalidSeal];
            return NO;
        }
        
        // - now assign the attributes because this keyring still exists.
        RSI_symcrypt *sk = [[RSI_symcrypt allocExistingKeyForType:CSSM_ALGID_SYM_ATTRIBUTES andTag:sealId withError:err] autorelease];
        if (!sk || ![sk updateKeyWithData:newAttributes andError:err]) {
            return NO;
        }
        
        // - if we'd previously cached the export, update it with the new attributes
        if (mdCreationExportForLocal) {
            [mdCreationExportForLocal setObject:sk.key forKey:RSI_SR_PROP_ATTRIB];
        }
        
        return YES;
    }
}

/*
 *  The key ring can be updated so that its symmetric key exists, but is different
 *  so that the entity exists in an invalid, but accounted-for state.
 */
-(BOOL) invalidateSymmetricKeyWithError:(NSError **) err
{
    RSI_symcrypt *symk = [[RSI_symcrypt allocExistingKeyForType:CSSM_ALGID_SYM_SEAL andTag:sealId withError:err] autorelease];
    if (!symk) {
        return NO;
    }
    
    //  - this is as simple as just changing the key so that it can't be used for decryption.
    RSI_securememory *secMem = [RSI_securememory dataWithLength:[RSI_symcrypt keySize]];
    if (SecRandomCopyBytes(kSecRandomDefault, [RSI_symcrypt keySize], (uint8_t *) secMem.mutableBytes) != 0) {
        [RSI_error fillError:err withCode:RSIErrorCryptoFailure andFailureReason:@"Failed to generate the symmetric key replacement."];
        return NO;
    }
    
    if (![symk updateKeyWithData:secMem andError:err]) {
        return NO;
    }

    return YES;
}

@end

/**************************
  RSI_keyring (internal)
  **************************/
@implementation RSI_keyring (internal)
/*
 *  Return a quick string hash of the header region of the supplied buffer.
 *  - NOTE: this is not intended to be network-secure.
 */
+(NSString *) insecureHeaderStringHashForData:(NSData *) d
{
    if (!d || [d length] < [RSI_secure_props propertyHeaderLength]) {
        return nil;
    }
    
    // - HASHING-NOTE:
    //      - this hash may be SHA-1 because it is only used locally.
    RSI_SHA1 *hash = [[[RSI_SHA1 alloc] init] autorelease];
    [hash updateWithData:[NSData dataWithBytes:d.bytes length:[RSI_secure_props propertyHeaderLength]]];
    
    // - use base-64 to keep this as short as possible.
    return [hash base64StringHash];
}

/*
 *  In order to optimize searches for keyrings during data identification, the ids
 *  of every keyring are kept in a list ordered by popularity.  To force the list to
 *  be recreated, simply call this routine.
 *  - ASSUMES the lock is held.
 */
+(BOOL) verifyKeyringCacheWithError:(NSError **) err
{
    if (maKeyringCache) {
        return YES;
    }
    
    //  - the seal cache contains a list of all the seal ids and a flag indicating whether
    //    they support producer operations.
    //  - this is necessary because the added search of the keychain for public/private keypairs
    //    is an expensive one and not necessarily something we need to do every time we want to
    //    identify new messages.
    NSArray *symKeyArr = [RSI_symcrypt findAllKeyTagsForType:CSSM_ALGID_SYM_SEAL withError:err];
    if (!symKeyArr) {
        return NO;
    }
    maKeyringCache = [[NSMutableArray alloc] initWithCapacity:[symKeyArr count]];
    for (NSUInteger i = 0; i < [symKeyArr count]; i++) {
        NSString *sid    = [symKeyArr objectAtIndex:i];
        NSError *tmp     = nil;
        RSI_pubcrypt *pk = [RSI_pubcrypt allocExistingKeyForTag:sid withError:&tmp];
        if (!pk) {
            if (tmp.code == RSIErrorKeyNotFound) {
                //  - this is technically something odd because of the mismatch, but
                //    I'm going to allow it until it becomes an issue.
                NSLog(@"RSI: Incomplete seal %@ identified.", sid);
                continue;
            }
            else {
                if (err) {
                    *err = tmp;
                }
                [RSI_keyring freeKeyringCache];
                return NO;
            }
        }
        [maKeyringCache addObject:[RSI_cached_keyring cachedKeyringForId:sid andIsProducer:[pk isFullKey]]];
        [pk release];
    }
    return YES;
}

/*
 *  The keyrings used most often are put at the top to optimize searches for them.
 *  - ASSUMES the lock is held.
 */
+(void) freshenKeyringInCache:(NSUInteger) index
{
    if (index > 0 && index < [maKeyringCache count]) {
        RSI_cached_keyring *cachedKeyring = [[maKeyringCache objectAtIndex:index] retain];
        if (cachedKeyring) {
            [maKeyringCache removeObjectAtIndex:index];
            [maKeyringCache insertObject:cachedKeyring atIndex:0];
            [cachedKeyring release];
        }
    }
}

/*
 *  Free the list of cached keyrings.
 */
+(void) freeKeyringCache
{
    // - An explicit lock is necessary because this is called from a lot of codepaths that are outside the identification one.
    @synchronized (synchKeyring) {
        [maKeyringCache release];
        maKeyringCache = nil;
    }
}


/*
 *  Initialize the object.
 */
-(id) initWithSealId:(NSString *) sid andCreationExport:(NSMutableDictionary *) mdExport
{
    self = [super init];
    if (self) {
        sealId                   = [sid retain];
        mdCreationExportForLocal = [mdExport retain];
    }
    return self;
}

/*
 *  Use the three types of keys to generate a seal identifier.
 */
+(NSString *) generateSealIdFromScrambler:(RSI_securememory *) scramData andRSAKey:(RSI_pubcrypt *) rsa andSymmtricKey:(RSI_symcrypt *) sym
{
    // - HASHING-NOTE:
    //      - the cornerstone of this infrastructure is the seal-id.  It is expected to be reliably unique at all times.  Therefore, we
    //        must try to use the best hash available.  But, this will be valid between releases, and maybe upgrades to the secure SHA
    //        algorithm, which means that we need to decide now and keep it there pretty much forever.
    RSI_SHA_SEAL *sha = [[[RSI_SHA_SEAL alloc] init] autorelease];
    
    //  - both producers and consumers must be able to generate a seal
    //    id from the keys, which means that the private key cannot be
    //    used.
    [sha update:@"RPRSI" withLength:5];            // salt, just in case
    [sha updateWithData:scramData.rawData];
    [sha updateWithData:rsa.publicKey];
    [sha updateWithData:sym.key.rawData];
    
    // - since this is a very long value, we're going to use base-64 to encode it to save on some storage.
    return [sha base64StringHash];
}

/*
 *  Import the keys into the local keychain.
 */
+(BOOL) importKeysWithId:(NSString *) newSid andPublicData:(NSData *) pubk andPrivateData:(RSI_securememory *) prvk andSymData:(RSI_securememory *) symk
            andScramData:(RSI_securememory *) scramk andAttributes:(RSI_securememory *) attrib withError:(NSError **) err;

{
    if (![RSI_keyring deleteRingWithSealId:newSid andError:err]) {
        return NO;
    }
    
    if (![RSI_pubcrypt importPublicKeyWithLabel:newSid andTag:newSid andValue:pubk withError:err] ||
        (prvk && ![RSI_pubcrypt importPrivateKeyWithLabel:newSid andTag:newSid andValue:prvk withError:err]) ||
        ![RSI_symcrypt importKeyWithLabel:newSid andType:CSSM_ALGID_SYM_SEAL andTag:newSid andValue:symk withError:err] ||
        ![RSI_scrambler importKeyWithLabel:newSid andTag:newSid andValue:scramk withError:err] ||
        ![RSI_symcrypt importKeyWithLabel:newSid andType:CSSM_ALGID_SYM_ATTRIBUTES andTag:newSid andValue:attrib withError:err]) {
        
        [RSI_pubcrypt deleteKeyWithTag:newSid withError:nil];
        [RSI_symcrypt deleteKeyWithType:CSSM_ALGID_SYM_SEAL andTag:newSid withError:nil];
        [RSI_scrambler deleteKeyWithTag:newSid withError:nil];
        newSid = nil;
        return NO;
    }

    return YES;
}

/*
 *  The core encryption routine.  This will encrypt the two styles of message: producer and consumer.  
 */
-(NSData *) encryptMessage:(NSDictionary *) msg asType:(rsi_keyring_msg_t) msgType withError:(NSError **) err
{
    if (!msg) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return nil;
    }
    
    //  - pull the keys first
    NSError *tmp = nil;
    RSI_scrambler *scram = [[RSI_scrambler allocExistingKeyForTag:sealId withError:&tmp] autorelease];
    if (!scram) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSeal andFailureReason:[tmp localizedDescription]];
        return nil;
    }
    
    //  - both ends of the communication use the symmetric and public keys
    RSI_symcrypt *symk = [[RSI_symcrypt allocExistingKeyForType:CSSM_ALGID_SYM_SEAL andTag:sealId withError:&tmp] autorelease];
    if (!symk) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSeal andFailureReason:[tmp localizedDescription]];
        return nil;
    }
    
    RSI_pubcrypt *pubk = [[RSI_pubcrypt allocExistingKeyForTag:sealId withError:&tmp] autorelease];
    if (!pubk) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSeal andFailureReason:[tmp localizedDescription]];
        return nil;
    }
    
    //  - send a message type based on the highest possible role for the
    //    user.
    if (msgType == KM_ROLE_HIGHEST) {
        if ([pubk isFullKey]) {
            msgType = KM_PRODUCER;
        }
        else {
            msgType = KM_CONSUMER;
        }
    }
    
    //  - ensure that everything that can be scrambled is
    msg = (NSDictionary *) [self modifyCollection:msg withScrambler:scram andDoScramble:YES andError:err];
    if (!msg) {
        return nil;
    }
    
    //  - the choice of XML or binary comes from the desire to make all external content relatively standard
    //    and open in format at least.   My concern is that if this gets popular, a divergence in versions could
    //    make it very messy to parse old messages.
    BOOL isBinary = NO;
    if (msgType == KM_LOCAL) {
        isBinary = YES;
    }

    //  - both message types will have a single blob for their payload.
    RSI_securememory *smPayload = [RSI_securememory data];
    if (![RSI_secure_props buildArchiveWithProperties:msg intoData:smPayload asBinary:isBinary withCRCPRefix:YES andError:nil]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSecureProps andFailureReason:@"Failed to generate the formatted keyring payload."];
        return nil;
    }
    
    RSI_securememory *smMessage = [RSI_securememory data];
    
    //  - now things start to diverge.
    //  - producers sign the blob and store it as-is with the signed key
    //  - consumers encrypt the blob with a custom symmetric key
    if (msgType == KM_PRODUCER) {
        //  - ensure that the right ones are generating content
        if (![pubk isFullKey]) {
            [RSI_error fillError:err withCode:RSIErrorUnsupportedConsumerAction];
            return nil;
        }
        
        //  - a producer message has two elements.
        //  1.  the data blob (unencrypted)
        //  2,  the producer signature of the data blob
        NSMutableData *signature = [NSMutableData data];
        if (![pubk sign:smPayload.rawData intoBuffer:signature withError:err]) {
            return nil;
        }
        
        //  - pack the two types of elements into a common data buffer
        [RSI_common appendLong:(uint32_t) [smPayload length] toData:smMessage.rawData];
        [smMessage appendSecureMemory:smPayload];
        
        [RSI_common appendLong:(uint32_t) [signature length] toData:smMessage.rawData];
        [smMessage appendData:signature];
    }
    else if (msgType == KM_CONSUMER) {
        //  - a consumer message has two elements.
        //  1.  the data blob (encrypted)
        //  2.  a symmetric key encrypted with the public key of the producer.
        RSI_symcrypt *skConsumer = [RSI_symcrypt transientKeyWithError:err];
        
        NSMutableData *encryptedPayload = [NSMutableData data];
        if (![skConsumer encrypt:smPayload.rawData intoBuffer:encryptedPayload withError:err]) {
            return nil;
        }
        
        NSMutableData *encryptedKey = [NSMutableData data];
        if (![pubk encrypt:skConsumer.key.rawData intoBuffer:encryptedKey withError:err]) {
            return nil;
        }
        
        //  - pack the two types of elements into a common data buffer
        [RSI_common appendLong:(uint32_t) [encryptedPayload length] toData:smMessage.rawData];
        [smMessage appendData:encryptedPayload];
        
        [RSI_common appendLong:(uint32_t) [encryptedKey length] toData:smMessage.rawData];
        [smMessage appendData:encryptedKey];        
    }
    else if (msgType == KM_LOCAL) {
        //  - a local message only has the payload blob, which makes it look a lot like
        //    a producer message without the identity confirmation.
        [RSI_common appendLong:(uint32_t) [smPayload length] toData:smMessage.rawData];
        [smMessage appendSecureMemory:smPayload];
        
        //  - we need to put a zero length on the second data blob so that it is created during
        //    decryption, but not used.
        [RSI_common appendLong:0 toData:smMessage.rawData];
    }
    else {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return nil;
    }
    
    //  - if we made it this far, we have what we need to build the final result
    return [RSI_secure_props encryptWithData:smMessage.rawData forType:msgType andVersion:RSI_SECURE_VERSION usingKey:symk withError:err];
}

/*
 *  Encrypt the message in an auto-release pool to ensure that any temporary objects are completely destroyed.
 */
-(NSData *) encryptMessageInPool:(NSDictionary *) msg asType:(rsi_keyring_msg_t) msgType withError:(NSError **) err
{
    NSError *tmp = nil;
    NSData *ret = nil;
    
    //  - do everything in an autorelease pool to ensure that
    //    symmetric keys are deleted immediately after use.
    @autoreleasepool {
        ret = [self encryptMessage:msg asType:msgType withError:&tmp];
        [ret retain];
        [tmp retain];
    }
    
    [tmp autorelease];
    if (err) {
        *err = tmp;
    }
    return [ret autorelease];
}

/*
 *  Produce a scrambled version of the provided collection object.
 */
-(NSObject *) modifyCollection:(NSObject *) obj withScrambler:(RSI_scrambler *) scram andDoScramble:(BOOL) doScramble andError:(NSError **) err
{
    NSArray *arr = nil;
    NSMutableDictionary *mdRet = nil;
    NSMutableArray *maRet = nil;
    NSObject *item = nil;
    
    //  - identify the type of object
    BOOL isDict = NO;
    if ([obj isKindOfClass:[NSDictionary class]]) {
        isDict = YES;
        arr = [(NSDictionary *) obj allKeys];
        mdRet = [NSMutableDictionary dictionaryWithCapacity:[arr count]];
    }
    else if ([obj isKindOfClass:[NSArray class]]) {
        arr = (NSArray *) obj;
        maRet = [NSMutableArray arrayWithCapacity:[arr count]];
    }
    else {
        //  - unsupported colllection.
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return nil;
    }
    
    //  - loop through all the instances
    for (NSUInteger i = 0; i < [arr count]; i++) {
        NSString *k = nil;
        if (isDict) {
            k = [arr objectAtIndex:i];
            item = [(NSDictionary *) obj objectForKey:k];
            if (!item) {
                continue;
            }
        }
        else {
            item = [arr objectAtIndex:i];
        }
        
        //  - convert images to scrambled versions
        //  - we don't scramble text, however, because it is regular enough that it could allow for easier
        //    inference of the scrambler key.
        if (doScramble && [item isKindOfClass:[UIImage class]]) {
            item = [self scrambleImage:(UIImage *) item withScrambler:scram andError:err];
        }
        else if (doScramble && [item isKindOfClass:[NSData class]] && [RSI_unpack isImageJPEG:(NSData *) item]) {
            item = [self scrambleJPEG:(NSData *) item withScrambler:scram andError:err];
        }
        else if (!doScramble && [item isKindOfClass:[RSI_scrambled_image class]]) {
            item = [(RSI_scrambled_image *) item objectForDataUsingScrambler:scram withError:err];
        }
        else if ([item isKindOfClass:[NSDictionary class]] || [item isKindOfClass:[NSArray class]]) {
            item = [self modifyCollection:item withScrambler:scram andDoScramble:doScramble andError:err];
        }
        
        if (!item) {
            return nil;
        }
        
        //  - save the converted item
        if (isDict) {
            [mdRet setObject:item forKey:k];
        }
        else {
            [maRet addObject:item];
        }
    }
    
    if (isDict) {
        return mdRet;
    }
    else {
        return maRet;
    }
}

/*
 *  Produce a scrambled JPEG from the given image.
 */
-(RSI_scrambled_image *) scrambleImage:(UIImage *) img withScrambler:(RSI_scrambler *) scram andError:(NSError **) err
{
    //  - if the caller didn't bother to pack the image, we'll choose a sufficiently reasonable quality to
    //    compromise between size and quality.
    NSData *dScrambled = [RSI_pack scrambledJPEG:img withQuality:[RealSecureImage defaultJPEGQualityForMessaging] andKey:scram andError:err];
    if (!dScrambled) {
        return nil;
    }
    return [[[RSI_scrambled_image alloc] initWithData:dScrambled andUIFlag:YES] autorelease];
}

/*
 *  Produce a scrambled JPEG from the given unscrambled JPEG.
 */
-(RSI_scrambled_image *) scrambleJPEG:(NSData *) jpeg withScrambler:(RSI_scrambler *) scram andError:(NSError **) err
{
    NSData *dScrambled = [RSI_unpack scrambledJPEG:jpeg andKey:scram andError:err];
    if (!dScrambled) {
        return nil;
    }
    return [[[RSI_scrambled_image alloc] initWithData:dScrambled andUIFlag:NO] autorelease];
}

/*
 *  Given a set of properties, interpret them based on the type.
 */
-(NSDictionary *) decryptMessageProperties:(NSArray *) props forType:(rsi_keyring_msg_t) msgType withError:(NSError **) err
{
    NSError *tmp = nil;
    
    //  - the public key is used for producer/consumer communication
    RSI_pubcrypt *pubk = nil;
    if (msgType != RSI_SECPROP_MSG_LOCAL) {
        pubk = [[RSI_pubcrypt allocExistingKeyForTag:sealId withError:&tmp] autorelease];
        if (!pubk) {
            [RSI_error fillError:err withCode:RSIErrorInvalidSeal andFailureReason:[tmp localizedDescription]];
            return nil;
        }
    }
    
    //  - the scrambler, sometimes
    RSI_scrambler *scram = [[RSI_scrambler allocExistingKeyForTag:sealId withError:&tmp] autorelease];
    if (!scram) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSeal andFailureReason:[tmp localizedDescription]];
        return nil;
    }
    
    //  - verify that the format is valid.
    if ([props count] != 2 ||
        ![[props objectAtIndex:0] isKindOfClass:[NSData class]] ||
        ![[props objectAtIndex:1] isKindOfClass:[NSData class]]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSealedMessage andFailureReason:@"Invalid(1)."];
        return nil;
    }
    
    RSI_securememory *secMemTmp = nil;
    NSData *dBlob   = [props objectAtIndex:0];
    NSData *dKeySig = [props objectAtIndex:1];
    
    //  - is the message from a producer or a consumer?
    if (msgType == KM_PRODUCER) {
        //  producer messages are signed by the producer's private key, so the first thing is to
        //  verify that signature.
        if (![pubk verify:dBlob withBuffer:dKeySig withError:nil]) {
            [RSI_error fillError:err withCode:RSIErrorInvalidSealedMessage andFailureReason:@"Invalid(2)."];
            return nil;
        }
    
        // - allow the blob to fall through into the decoding stage.
    }
    else if (msgType == KM_CONSUMER) {
        //  - a consumer message may only be opened by a producer seal
        if (![pubk isFullKey]) {
            [RSI_error fillError:err withCode:RSIErrorUnsupportedConsumerAction];
            return nil;
        }
        
        //  - the second value is a symmetric key encrypted with the producer's public key.
        RSI_securememory *secKey = [RSI_securememory data];
        if (![pubk decrypt:dKeySig intoBuffer:secKey withError:nil]) {
            [RSI_error fillError:err withCode:RSIErrorInvalidSealedMessage andFailureReason:@"Invalid(3)."];
            return nil;
        }
        
        RSI_symcrypt *symConsumer = [RSI_symcrypt transientWithKeyData:secKey andError:nil];
        secMemTmp = [RSI_securememory data];
        if (!symConsumer || ![symConsumer decrypt:dBlob intoBuffer:secMemTmp withError:nil]) {
            [RSI_error fillError:err withCode:RSIErrorInvalidSealedMessage andFailureReason:@"Invalid(4)."];
            return nil;
        }
        
        //  - the blob has been decrypted, so use that one
        dBlob = secMemTmp.rawData;
    }
    else if (msgType == KM_LOCAL) {
        if ([dKeySig length] != 0) {
            [RSI_error fillError:err withCode:RSIErrorInvalidSealedMessage andFailureReason:@"Invalid(5)."];
            return nil;
        }
    }
    else {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return nil;
    }
    
    //  - now decode the message into a target dictionary
    NSObject *ret = [RSI_secure_props parseArchiveFromData:dBlob withCRCPrefix:YES andError:nil];
    if (!ret || ![ret isKindOfClass:[NSDictionary class]]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSealedMessage andFailureReason:@"Invalid(6)."];
        return nil;
    }
    
    //  - and finally, descramble it 
    return (NSDictionary *) [self modifyCollection:ret withScrambler:scram andDoScramble:NO andError:err];
}

/*
 *  During seal creation, the generation of the public/private keypair takes the longest amount of time
 *  so we're going to create them asynchronously in order to ensure they are available quickly
 *  when they are needed.
 */
+(void) generateSparePublicKey
{
    @synchronized (genLock) {
        if (!asyncGenQueue || isAsyncGenerating) {
            return;
        }
        
        // - don't bother with the async call if we already have spare keys.
        @synchronized (sparePubKeys) {
            if ([sparePubKeys count]) {
                return;
            }
        }
        
        isAsyncGenerating = YES;
        dispatch_async(asyncGenQueue, ^(void) {
            //  - hold onto the container so that the thread creating seals is synchronized.
            //  - btw, we do need a container instead of just a string because the object address must
            //    remain constant between seal creations/destructions
            @synchronized (sparePubKeys) {
                NSError *tmp = nil;
                NSArray *arrAllKeys = [RSI_pubcrypt findAllKeyTagsForPublic:NO withError:&tmp];
                if (arrAllKeys) {
                    //  - figure out if any of these keys are spares.
                    for (NSUInteger i = 0; i < [arrAllKeys count]; i++) {
                        NSString *keyTag = [arrAllKeys objectAtIndex:i];
                        NSRange r = [keyTag rangeOfString:RSI_SR_CACHED_KEY];
                        if (r.location == 0) {
                            if ([sparePubKeys indexOfObject:keyTag] == NSNotFound) {
                                [sparePubKeys addObject:keyTag];
                            }
                        }
                    }
                    
                    // - if there are no spares in the array, we'll need to create one, otherwise, just use what is there.
                    if ([sparePubKeys count] == 0) {
                        //  - no keys in the array, so let's generate one.
                        NSString *keyTag = [NSString stringWithFormat:@"%@.%ld", RSI_SR_CACHED_KEY, time(NULL)];
                        RSI_pubcrypt *pk = [RSI_pubcrypt allocNewKeyForPublicLabel:keyTag andPrivateLabel:keyTag andTag:keyTag withError:&tmp];
                        if (pk) {
                            [sparePubKeys addObject:keyTag];
                            [pk release];
                        }
                        else {
                            NSLog(@"RSI: Async key generation failed.  %@", [tmp localizedDescription]);
                        }
                    }
                }
                else {
                    NSLog(@"RSI: Async key generation failed to find all private keys.  %@", [tmp localizedDescription]);

                }
                
                // - make sure the async generation flag is reset!
                @synchronized (genLock) {
                    isAsyncGenerating = NO;
                }
            }
        });
    }
}

/*
 *  Create a dictionary that can be used for exporting the keyring contents.
 */
+(NSMutableDictionary *) buildExportForExternal:(BOOL) forExternal andSeal:(NSString *) sealId andSymKey:(RSI_symcrypt *) symk andPubKey:(RSI_pubcrypt *) pubk
                                  andAttributes:(RSI_securememory *) attribs andScramblerData:(RSI_securememory *) scramData withError:(NSError **) err
{
    RSI_securememory *symmetricKey = [symk key];
    NSData           *publicKey    = [pubk publicKey];
    if (!symmetricKey || !publicKey) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return nil;
    }
    
    NSMutableDictionary *mdExported = [NSMutableDictionary dictionary];
    [mdExported setObject:sealId forKey:RSI_SR_PROP_ID];
    [mdExported setObject:symmetricKey forKey:RSI_SR_PROP_SYMKEY];
    [mdExported setObject:publicKey forKey:RSI_SR_PROP_PUBKEY];
    [mdExported setObject:attribs forKey:RSI_SR_PROP_ATTRIB];
    if (!forExternal) {
        [mdExported setObject:scramData forKey:RSI_SR_PROP_SCRAMKEY];
        if ([pubk isFullKey]) {
            RSI_securememory *privateKey = pubk.privateKey;
            if (!privateKey) {
                [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
                return nil;
            }
            [mdExported setObject:privateKey forKey:RSI_SR_PROP_PRVKEY];
        }
    }
    return mdExported;
}

/*
 *  Determines if the seal is in the keyring cache.
 *  - ASSUMES the lock is held.
 */
+(BOOL) isSealInCache:(NSString *) sealId
{
    // - verify that someone else didn't already delete this keyring on a different thread, with
    //   a different object instance.
    if (![RSI_keyring verifyKeyringCacheWithError:nil]) {
        return NO;
    }
    
    BOOL hasIt = NO;
    for (RSI_cached_keyring *ckr in maKeyringCache) {
        if ([ckr.sealId isEqualToString:sealId]) {
            hasIt = YES;
        }
    }
    return hasIt;
}

@end

/**************************
 RSI_cached_keyring
 **************************/
@implementation RSI_cached_keyring
@synthesize sealId;
@synthesize isProducer;

/*
 *  Return a built cached keyring object.
 */
+(RSI_cached_keyring *) cachedKeyringForId:(NSString *) sealId andIsProducer:(BOOL) isProd
{
    RSI_cached_keyring *ck = [[RSI_cached_keyring alloc] init];
    ck.sealId              = sealId;
    ck.isProducer          = isProd;
    return [ck autorelease];
}

/*
 *  Free a cached keyring object.
 */
-(void) dealloc
{
    [sealId release];
    sealId = nil;
    
    [super dealloc];
}
@end

/**************************
 RSI_scrambled_image
 **************************/
@implementation RSI_scrambled_image
/*
 *  Initialize the object
 */
-(id) initWithData:(NSData *)dimg andUIFlag:(BOOL)uiimg
{
    self = [super init];
    if (self) {
        dImage = [dimg retain];
        isUIImage = uiimg;
    }
    return self;
}

/*
 *  Initialize this object with a coder stream.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        dImage = [[aDecoder decodeObjectForKey:RSI_SCRAMI_CODER_BUF] retain];
        isUIImage = [[aDecoder decodeObjectForKey:RSI_SCRAMI_CODER_FLAG] boolValue];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [dImage release];
    dImage = nil;
    
    [super dealloc];
}

/*
 *  Returns the appropriate object given the enclosed data.
 */
-(id) objectForDataUsingScrambler:(RSI_scrambler *) scram withError:(NSError **) err
{
    //  - first attempt to descramble
    RSI_securememory *secMem = nil;
    secMem = [RSI_unpack descrambledJPEG:dImage withKey:scram andError:err];
    if (!secMem) {
        return nil;
    }
    
    //  - now disable security on the memory so that it isn't cleared while
    //    in use by the caller.
    [secMem disableSecurity];

    // - prepare the return object based on the type of scrambled image.
    NSObject *ret = nil;
    if (isUIImage) {
        ret = [UIImage imageWithData:secMem.rawData];
    }
    else {
        ret = [[secMem.rawData retain] autorelease];
    }
    return  ret;
}

/*
 *  Serialize this object to a coder stream.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:dImage forKey:RSI_SCRAMI_CODER_BUF];
    [aCoder encodeObject:[NSNumber numberWithBool:isUIImage] forKey:RSI_SCRAMI_CODER_FLAG];
}

@end

/*********************
 RSISecureMessage
 *********************/
@implementation RSISecureMessage
@synthesize sealId;
@synthesize dMessage;
@synthesize hash;
@synthesize isProducerGenerated;

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        sealId              = nil;
        dMessage            = nil;
        hash                = nil;
        isProducerGenerated = NO;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [sealId release];
    sealId = nil;
    
    [dMessage release];
    dMessage = nil;
    
    [hash release];
    hash = nil;
    
    [super dealloc];
}

@end