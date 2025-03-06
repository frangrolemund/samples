//
//  RSI_seal.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/28/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "RSI_seal.h"
#import "RSI_error.h"
#import "RSI_common.h"
#import "RSI_pack.h"
#import "RSI_unpack.h"
#import "RSI_secure_props.h"
#import "RSI_symcrypt.h"

//  NOTE: seals are always generated with JPEG images because JPEGs are inherently
//        degradeable.  During some investigation into image formats on the web, I found
//        that nearly all web sites do post processing or modification on JPEGs that are uploaded.
//        While this makes using JPEG difficult for message passing, it actually makes it a lot
//        harder to pass someone's seal around, which is a good thing.  Therefore, I'm using JPEG
//        seals in an effort to better protect each person's privacy.
//  NOTE: every seal has attributes that have at most 16 bytes of data (cumulative).  They are
//        currently assigned like so:
//        byte  0:    color id
//        bytes 1-4:  expiration date (uint32_t) seconds from NSDate reference
//        byte  5:    bit flags
//        bytes 6-7:  self-destruct value
//        bytes 8-11: time value (uint32_t) seconds of last snapshot flag update

//  - some constants
//    - the minimum number of bytes that a seal image must be able to store as a JPEG.
//    - this was chosen to provide some growing room as necessary.
static const NSUInteger RSI_SEAL_MIN_DATA = 2975;                   //  - 168x168
//    - seal archive keys
static const NSString *RSI_SEAL_KEY_RING          = @"ring";
static const NSString *RSI_SEAL_KEY_IMG           = @"image";
static const NSString *RSI_SEAL_KEY_ADD_NOW       = @"add.now";
static const NSString *RSI_SEAL_KEY_ADD_SELFD     = @"add.selfd";
static const NSString *RSI_SEAL_KEY_ADD_SNAPINVAL = @"add.snapinval";
static const NSUInteger RSI_SEAL_COLOR_OFFSET     = 0;
static const NSUInteger RSI_SEAL_EXPDATE_OFFSET   = 1;
static const NSUInteger RSI_SEAL_FLAGS_OFFSET     = 5;
static const NSUInteger RSI_SEAL_SELFD_OFFSET     = 6;
static const NSUInteger RSI_SEAL_SNAP_DATE_OFFSET = 8;
static const NSUInteger RSI_SEAL_ATTRIB_LEN_REQD  = 12;
static const NSUInteger RSI_SEAL_DEFAULT_SELFD    = 90;             //  in days
static const NSUInteger RSI_SEAL_SEC_IN_DAY       = 60*60*24;
static const NSUInteger RSI_SEAL_MAX_SELFD        = 365;
static const unsigned char RSI_SEAL_FLAGS_INVALID = 0x01;           //  the seal is invalidate
static const unsigned char RSI_SEAL_FLAGS_SNAPVAL = 0x02;           //  invalidate the seal when a snapshot is taken
static const NSUInteger RSI_SEAL_STD_DATE_LEN     = sizeof(uint32_t);

// - forward declarations
@interface RSI_seal (internal)
-(id) initWithKeyring:(RSI_keyring *) keyRing andImageData:(NSData *) seal;
-(BOOL) ensureAttributesLoadedWithError:(NSError **) err;
-(uint16_t) selfDestructTimeoutUsingMemory:(RSI_securememory *) secMem;
-(void) setExpirationDate:(NSDate *) dt inAttributes:(RSI_securememory *) secMem;
-(NSDictionary *) addRevocationCriteriaIfProducerToMessage:(NSDictionary *) dictMessage withError:(NSError **) err;
-(NSDictionary *) updateRevocationCriteriaFromMessageData:(NSDictionary *) dMessage withError:(NSError **) err;
-(BOOL) sealFlags:(unsigned char *) flags withError:(NSError **) err;
-(BOOL) setSealFlags:(unsigned char) flags withError:(NSError **) err;
-(NSDate *) lastSnapshotUpdateWithError:(NSError **) err;
-(BOOL) setInvalidateOnSnapshotEnabled:(BOOL) isEnabled ifLastUpdateIsOlderThanDate:(NSDate *) dtUpdate withError:(NSError **) err;
+(void) assignSelfDestruct:(uint16_t) selfDestruct inAttributes:(NSMutableData *) attribs;
-(BOOL) setInvalidateOnSnapshotUnconditionally:(BOOL) enabled withUpdateDate:(NSDate *) dtUpdated withError:(NSError **) err;
-(BOOL) isSealValidForEncryptionWithError:(NSError **) err;
-(void) standardPackDate:(NSDate *) dt intoMemory:(NSMutableData *) mem atOffset:(NSUInteger) offset;
-(NSDate *) standardUnpackDateFromMemory:(NSData *) mem atOffset:(NSUInteger) offset;
-(void) discardCachedAttributes;
@end

/***********************
 RSI_seal
 ***********************/
@implementation RSI_seal
/*
 *  Object attributes.
 */
{
    RSI_keyring      *kr;
    RSI_securememory *attrib;
    NSData           *dSealImage;
}

/*
 *  Free a seal object.
 */
-(void) dealloc
{
    [kr release];
    kr = nil;
    
    [dSealImage release];
    dSealImage = nil;
    
    [self discardCachedAttributes];
    
    [super dealloc];
}

/*
 *  Create a new seal.
 */
+(RSI_seal *) allocNewSealWithImage:(UIImage *) img andColorId:(int) color andError:(NSError **) err
{
    if (color < 0 || color > 0xFF) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return nil;
    }    
    
    NSUInteger lenData = [RSI_pack maxDataForJPEGImage:img];
    if (lenData < RSI_SEAL_MIN_DATA) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSealImage andFailureReason:@"Image too small."];
        return nil;
    }
    
    //  - generate a clean image, which has all the storage locations in
    //    the seal zeroed out
    //  - this also ensures that the image is precisely oriented to this
    //    library's JPEG parser.
    NSError *tmp = nil;
    NSMutableData *mdEmpty = [NSMutableData dataWithLength:lenData];
    NSData *dSealImage = [RSI_pack packedJPEG:img withQuality:0.5f andData:mdEmpty andError:&tmp];
    if (!dSealImage) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSealImage andFailureReason:[tmp localizedDescription]];
        return nil;
    }
    
    //  - now create a secure hash of the image, which becomes the seal's scrambler key.
    RSI_securememory *imgHash = [RSI_unpack hashImageData:dSealImage withError:&tmp];
    if (!imgHash) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSealImage andFailureReason:[tmp localizedDescription]];
        return nil;
    }
    
    //  - setting the attributes can be costly after the fact, so we'll initialize them quickly here.
    NSMutableData *mdAttribs = [NSMutableData dataWithLength:RSI_SEAL_ATTRIB_LEN_REQD];
    ((unsigned char *) mdAttribs.mutableBytes)[RSI_SEAL_COLOR_OFFSET] = (unsigned char) color;
    [RSI_seal assignSelfDestruct:[RSI_seal defaultSelfDestructDays] inAttributes:mdAttribs];
    
    //  - the scrambler is necessary to generate a keyring for the seal. 
    RSI_keyring *kr = [RSI_keyring allocNewRingUsingScramblerData:imgHash andAttributes:mdAttribs withError:err];
    if (!kr) {
        return nil;
    }
    
    //  - now that we have a keyring, we can create the seal
    RSI_seal *ret = [[RSI_seal alloc] initWithKeyring:kr andImageData:dSealImage];
    [kr release];
    
    return ret;
}

/*
 *  Find an existing seal in the system and return it.
 */
+(RSI_seal *) allocExistingSealWithId:(NSString *) sealId andError:(NSError **) err
{
    //  - the keyring is the gate that we must pass
    RSI_keyring *kr = [[RSI_keyring allocExistingWithSealId:sealId] autorelease];
    if (![kr isValid]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSeal];
        return nil;
    }
    
    return [[RSI_seal alloc] initWithKeyring:kr andImageData:nil];
}

/*
 *  Instantiate a seal using an existing archive.  
 */
+(RSI_seal *) allocSealWithArchive:(NSData *) dArchive andError:(NSError **) err
{
    NSError *tmp = nil;
    NSObject *props = [RSI_secure_props parseArchiveFromData:dArchive withCRCPrefix:YES andError:&tmp];
    if (!props || ![props isKindOfClass:[NSDictionary class]]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSeal andFailureReason:[tmp localizedDescription]];
        return nil;
    }
    
    NSDictionary *dSeal = (NSDictionary *) props;
    
    //  - grab the seal attributes and validate them
    NSDictionary *dKeyring = [dSeal objectForKey:RSI_SEAL_KEY_RING];
    NSData       *dImage   = [dSeal objectForKey:RSI_SEAL_KEY_IMG];
    if (!dKeyring || !dImage) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSeal andFailureReason:@"Missing required attributes."];
        return nil;
    }
    
    NSData *dUnpacked = [RSI_unpack unpackData:dImage withMaxLength:0 andError:&tmp];
    if (!dUnpacked) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSeal andFailureReason:@"Invalid seal image."];
        return nil;
    }
    
    NSString *sid = [RSI_keyring sealForCollection:dKeyring];
    if (!sid) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSeal andFailureReason:@"Missing keyring identificatin."];
        return nil;
    }
    
    //   - if the keyring is already valid, then skip import
    RSI_keyring *kr = [RSI_keyring allocExistingWithSealId:sid];
    if (![kr isValid]) {
        [kr release];
        
        sid = [RSI_keyring importFromCollection:dKeyring andSeparateScramblerData:nil withError:&tmp];
        if (!sid) {
            [RSI_error fillError:err withCode:RSIErrorSealFailure andFailureReason:[tmp localizedDescription]];
            return nil;
        }
    
        kr = [RSI_keyring allocExistingWithSealId:sid];
    }
    
    if (!kr) {
        [RSI_error fillError:err withCode:RSIErrorAborted andFailureReason:@"Unexpected null keyring."];
        return nil;
    }
    
    return [[RSI_seal alloc] initWithKeyring:[kr autorelease] andImageData:dImage];
}

/*
 *  This method will open a seal archive, figure out its associated seal and pair the seal image
 *  with that data. 
 */
+(RSI_seal *) allocSealWithCurrentKeysAndArchive:(NSData *) dArchive andError:(NSError **) err
{
    NSError *tmp = nil;
    NSObject *props = [RSI_secure_props parseArchiveFromData:dArchive withCRCPrefix:YES andError:&tmp];
    if (!props || ![props isKindOfClass:[NSDictionary class]]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSeal andFailureReason:[tmp localizedDescription]];
        return nil;
    }
    
    NSDictionary *dSeal = (NSDictionary *) props;
    
    //  - grab the seal attributes and validate them
    NSString *sealId = [RSI_keyring sealForCollection:[dSeal objectForKey:RSI_SEAL_KEY_RING]];
    NSData   *dImage   = [dSeal objectForKey:RSI_SEAL_KEY_IMG];
    if (!sealId || !dImage) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSeal andFailureReason:@"Missing required attributes."];
        return nil;
    }
    
    // - build the keyring for the seal object.
    RSI_keyring *kr = [[RSI_keyring allocExistingWithSealId:sealId] autorelease];
    if (!kr || ![kr isValid]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSeal andFailureReason:@"Invalid keyring."];
        return nil;
    }
    
    return [[RSI_seal alloc] initWithKeyring:kr andImageData:dImage];
}

/*
 *  Every exported seal is encrypted with a password for security purposes.
 */
+(RSI_seal *) importSeal:(NSData *) dExported withPassword:(NSString *) pwd andError:(NSError **) err
{
    if (!pwd) {
        [RSI_error fillError:err withCode:RSIErrorBadPassword];
        return nil;
    }
    
    if (!dExported) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return nil;
    }
    
    RSI_error *tmp = nil;
    NSData *dEncryptedSealProps = [RSI_unpack unpackData:dExported withMaxLength:0 andError:&tmp];
    if (!dEncryptedSealProps) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSeal andFailureReason:[tmp localizedDescription]];
        return nil;
    }
    
    //  - generate a password for decrypting the payload
    RSI_symcrypt *symKey = [RSI_symcrypt allocTransientWithPassword:pwd andError:&tmp];
    if (!symKey) {
        [RSI_error fillError:err withCode:RSIErrorBadPassword andFailureReason:[tmp localizedDescription]];
        return nil;
    }
    
    NSArray *dDecryptPayload = [RSI_secure_props decryptIntoProperties:dEncryptedSealProps forType:RSI_SECPROP_SEAL andVersion:RSI_SECURE_VERSION usingKey:symKey withError:&tmp];
    [symKey release];           //  don't leave lying around for long
    if (!dDecryptPayload) {
        [RSI_error fillError:err withCode:RSIErrorBadPassword andFailureReason:[tmp localizedDescription]];
        return nil;
    }
    
    //  - now we have a payload, which should have the keys.
    if ([dDecryptPayload count] != 1 || ![[dDecryptPayload objectAtIndex:0] isKindOfClass:[NSDictionary class]]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSeal andFailureReason:@"Extraneous properties."];
        return nil;
    }
    
    NSDictionary *dictKeys = (NSDictionary *) [dDecryptPayload objectAtIndex:0];
    
    NSString *sid = [RSI_keyring sealForCollection:dictKeys];
    if (!sid) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSeal andFailureReason:@"Missing seal identification."];
        return nil;
    }
    
    //  - create a clean container image
    NSMutableData *mdEmpty = [NSMutableData dataWithLength:RSI_SEAL_MIN_DATA];
    dExported = [RSI_unpack repackData:dExported withData:mdEmpty andError:err];
    if (!dExported) {
        return nil;
    }
    
    //  - check to see if this seal exists and prevent a duplicate import if it is owned by us.
    NSString *sImported = nil;
    RSI_seal *seal = [[RSI_seal allocExistingSealWithId:sid andError:&tmp] autorelease];
    if (seal && [seal isProducerSeal]) {
        sImported = sid;
    }
    else {
        // - either the seal doesn't exist or it is a prior consumer seal, which we may want
        //   to overwrite.
        //  - just make sure that the seal doesn't already exist.
        [RSI_keyring deleteRingWithSealId:sid andError:nil];

        //  - generate a hash for the container
        RSI_securememory *smHash = [RSI_unpack hashImageData:dExported withError:&tmp];
        if (!smHash) {
            [RSI_error fillError:err withCode:RSIErrorInvalidSeal andFailureReason:[tmp localizedDescription]];
            return nil;
        }
        
        //  - now import it.
        sImported = [RSI_keyring importFromCollection:dictKeys andSeparateScramblerData:smHash withError:err];
        if (!sImported) {
            return nil;
        }
    }
    
    RSI_keyring *kr = [RSI_keyring allocExistingWithSealId:sImported];
    return [[[RSI_seal alloc] initWithKeyring:[kr autorelease] andImageData:dExported] autorelease];
}

/*
 *  Delete the seal with the given id.
 */
+(BOOL) deleteSealForId:(NSString *) sealId andError:(NSError **) err
{
    return [RSI_keyring deleteRingWithSealId:sealId andError:err];
}

/*
 *  Delete all seals.
 */
+(BOOL) deleteAllSealsWithError:(NSError **) err
{
    return [RSI_keyring deleteAllKeyringsWithError:err];
}

/*
 *  Return the maximum number of days before seal self-destruction occurs.
 */
+(NSUInteger) maximumDaysBeforeSelfDestruct
{
    //  - I'm doing this to protect people from accidentally causing a personal
    //    catastophe.  If they give a seal with a crazy expiration date and the person never
    //    reads another message, the expiration is never updated and the personal data stays
    //    viable forever.   This will ensure that after a reasonable amount of time, everything
    //    goes stale.  If you really don't want this outcome, stay in touch with the seal owner.
    return RSI_SEAL_MAX_SELFD;
}

/*
 *  Return the default number of days before a seal self-destructs.
 */
+(NSUInteger) defaultSelfDestructDays
{
    return RSI_SEAL_DEFAULT_SELFD;
}

/*
 *  Return the id of the seal
 */
-(NSString *) sealId
{
    if (kr) {
        return [kr sealId];
    }
    return nil;
}

/*
 *  Identify if the seal is owned by the user.
 */
-(BOOL) isProducerSeal
{
    if (kr) {
        return [kr isOwnersKeyring];
    }
    return NO;
}

/*
 *  Return the image for the seal.
 */
-(NSData *) sealImage
{
    return [[dSealImage retain] autorelease];
}

/*
 *  Modify the seal image to ensure that it can't be easily reused.
 */
-(BOOL) invalidateSealImageWithError:(NSError **) err
{
    if (!dSealImage) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSeal andFailureReason:@"Missing the seal image."];
        return NO;
    }

    // - JPEG's lossy quality is actually an asset here.
    UIImage *img = [UIImage imageWithData:dSealImage];
    NSMutableData *mdEmpty = [NSMutableData dataWithLength:1];
    NSData *dNewImage = [RSI_pack packedJPEG:img withQuality:0.75f andData:mdEmpty andError:err];
    if (!dNewImage) {
        return NO;
    }
    
    [dSealImage release];
    dSealImage = [dNewImage retain];
    
    return YES;
}

/*
 *  Generate an archive that can be used to recreate the seal later.
 */
-(RSI_securememory *) sealArchiveWithError:(NSError **) err
{
    if (!dSealImage) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSeal andFailureReason:@"Missing image."];
        return nil;
    }
    
    if (!kr) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSeal andFailureReason:@"Invalid keyring."];
        return nil;
    }

    //  - an archive is intended to be complete enough to recreate the seal.
    NSMutableDictionary *mdKeyRing = [kr exportForExternal:NO withAlternateAttributes:nil andError:err];
    if (!mdKeyRing) {
        return nil;
    }
    
    //  - the seal archive is just a standard keyed archive
    NSMutableDictionary *mdSeal = [NSMutableDictionary dictionary];
    [mdSeal setObject:mdKeyRing forKey:RSI_SEAL_KEY_RING];
    [mdSeal setObject:dSealImage forKey:RSI_SEAL_KEY_IMG];
    
    RSI_securememory *dArchive = [RSI_securememory data];
    if (![RSI_secure_props buildArchiveWithProperties:mdSeal intoData:dArchive withCRCPrefix:YES andError:err]) {
        return nil;
    }
    return dArchive;
}

/*
 *  Export a seal as a JPEG image for a remote consumer.
 */
-(NSData *) exportSealWithPassword:(NSString *) pwd andError:(NSError **) err
{
    if (!pwd) {
        [RSI_error fillError:err withCode:RSIErrorBadPassword];
        return nil;
    }
    
    if (!dSealImage || !kr) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSeal andFailureReason:@"Incomplete seal data."];
        return nil;
    }
    
    if (![self isProducerSeal]) {
        [RSI_error fillError:err withCode:RSIErrorUnsupportedConsumerAction];
        return nil;
    }
    
    //  - during export, the first expiration date is set automatically.
    if (![self ensureAttributesLoadedWithError:err]) {
        return nil;
    }
    uint16_t timeout = [self selfDestructTimeoutUsingMemory:attrib];
    NSDate *dtSelfDestruct = [NSDate dateWithTimeIntervalSinceNow:RSI_SEAL_SEC_IN_DAY*timeout];
    RSI_securememory *secMemConsumerAttrib = [RSI_securememory dataWithSecureData:attrib];
    [self setExpirationDate:dtSelfDestruct inAttributes:secMemConsumerAttrib];
    
    //  - export the keyring for the consumer seal.
    NSDictionary *dKeyRing = [kr exportForExternal:YES withAlternateAttributes:secMemConsumerAttrib andError:err];
    if (!dKeyRing) {
        return nil;
    }
    
    //  - use a container dictionary because we'll eventually
    //    add more content to this seal
    NSMutableArray *maExportedSeal = [NSMutableArray array];
    [maExportedSeal addObject:dKeyRing];
    
    //  - now generate a password for encrypting the payload
    RSI_symcrypt *symKey = [RSI_symcrypt allocTransientWithPassword:pwd andError:err];
    if (!symKey) {
        return nil;
    }
    
    //  - then create the secure property archive
    NSData *dSealProperties = [RSI_secure_props encryptWithProperties:maExportedSeal forType:RSI_SECPROP_SEAL andVersion:RSI_SECURE_VERSION usingKey:symKey withError:err];
    [symKey release];           //  don't leave the password in memory for long
    if (!dSealProperties) {
        return nil;
    }
    
    //  - finally, generate the packed seal image
    return [RSI_unpack repackData:dSealImage withData:dSealProperties andError:err];
}

/*
 *  Return a list of all the installed seals.
 */
+(NSArray *) availableSealsWithError:(NSError **) err
{
    return [RSI_keyring availableKeyringsWithError:err];
}

/*
 *  Encrypt a message as the seal owner.
 */
-(NSData *) encryptProducerMessage:(NSDictionary *) msg withError:(NSError **) err
{
    // - ensure that we can use this seal and it is not invalidated, because
    //   the dummy key is not something we want to ever use.
    if (![self isSealValidForEncryptionWithError:err]) {
        return nil;
    }
    
    msg = [self addRevocationCriteriaIfProducerToMessage:msg withError:err];
    if (!msg) {
        return nil;
    }
    return [kr encryptProducerMessage:msg withError:err];
}

/*
 *  Encrypt a message as a seal consumer.
 */
-(NSData *) encryptConsumerMessage:(NSDictionary *) msg withError:(NSError **) err
{
    // - ensure that we can use this seal and it is not invalidated, because
    //   the dummy key is not something we want to ever use.
    if (![self isSealValidForEncryptionWithError:err]) {
        return nil;
    }
    
    return [kr encryptConsumerMessage:msg withError:err];
}

/*
 *  Encrypt a local-only message (should not ever be sent over a network.)
 */
-(NSData *) encryptLocalOnlyMessage:(NSDictionary *) msg withError:(NSError **) err
{
    // - ensure that we can use this seal and it is not invalidated, because
    //   the dummy key is not something we want to ever use.
    if (![self isSealValidForEncryptionWithError:err]) {
        return nil;
    }
    
    return [kr encryptLocalOnlyMessage:msg withError:err];
}

/*
 *  Encrypt a message that is appropriate for the highest-qualifying role that the
 *  seal possessor can achive.
 */
-(NSData *) encryptRoleBasedMessage:(NSDictionary *) msg withError:(NSError **)err
{
    // - ensure that we can use this seal and it is not invalidated, because
    //   the dummy key is not something we want to ever use.
    if (![self isSealValidForEncryptionWithError:err]) {
        return nil;
    }
    
    msg = [self addRevocationCriteriaIfProducerToMessage:msg withError:err];
    if (!msg) {
        return nil;
    }
    return [kr encryptRoleBasedMessage:msg withError:err];
}

/*
 *  Attempt to decrypt a message with the seal.
 */
-(NSDictionary *) decryptMessage:(NSData *) d withError:(NSError **) err
{
    // - technically, just trying to decrypt with the keys is sufficient to test this, but my concern
    //   here is that the invalidation flag and not the encryption key was updated in the keychain because
    //   of a failure to access the keychain.  I'm going to use the flag first and then the key to
    //   offer two levels of verification in case only one was updated successfully during invalidation.
    if (![self isSealValidForEncryptionWithError:err]) {
        return nil;
    }
    
    BOOL isProducer = NO;
    NSDictionary *dMessage = [kr decryptMessage:d isProducerMessage:&isProducer withError:err];
    if (!dMessage) {
        return nil;
    }
    
    //  - when this message is from a producer update the expiration date of the seal.
    if (isProducer) {
        dMessage = [self updateRevocationCriteriaFromMessageData:dMessage withError:err];
        if (!dMessage) {
            return nil;
        }
    }
    return dMessage;
}
/*
 *  This is a limited hash of only the packed content's header, but if it is compared to
 *  content that was previously decrypted successfully, is guaranteed to be unique
 *  and a reliable way to identify partial matches for a packed stream.
 */
+(NSString *) hashForEncryptedMessage:(NSData *)dMsg withError:(NSError **)err
{
    return [RSI_keyring hashForEncryptedMessage:dMsg withError:err];
}

/*
 *  The purpose of this method is to determine as quickly as possible whether the provided data file can be opened by
 *  the local vault-secured seals.   If so, it can optionally unpack the data.
 *  - The assumption is that the packed content is an actual packed image with secure properties enclosed in it.
 */
+(RSISecureMessage *) identifyEncryptedMessage:(NSData *) dMsg withFullDecryption:(BOOL) fullDecryption andError:(NSError **) err
{
    RSISecureMessage *sm = [RSI_keyring identifyEncryptedMessage:dMsg withFullDecryption:fullDecryption andError:err];
    if (sm && fullDecryption && sm.sealId && sm.isProducerGenerated) {
        RSI_seal *newSeal = [RSI_seal allocExistingSealWithId:sm.sealId andError:err];
        sm.dMessage       = [newSeal updateRevocationCriteriaFromMessageData:sm.dMessage withError:err];
        [newSeal release];
        if (!sm.dMessage) {
            return nil;
        }
    }
    return sm;
}

/*
 *  Performs a superficial check to see if the seal exists in the keychain.
 */
+(BOOL) sealExists:(NSString *) sealId withError:(NSError **) err
{
    NSError *tmp = nil;
    if ([RSI_keyring ringForSeal:sealId existsWithError:&tmp]) {
        return YES;
    }
    
    if (err) {
        if (tmp.code != RSIErrorKeyNotFound) {
            *err = tmp;
        }
        else {
            *err = nil;
        }
    }
    return NO;
}

/*
 *  Discard the image cached inside the seal.
 */
-(void) discardTemporaryImage
{
    [dSealImage release];
    dSealImage = nil;
}

/*
 *  Prepare to generate a new seal.
 */
+(void) prepareForSealGeneration
{
    [RSI_keyring prepareForSealGeneration];
}

/*
 *  Stop async comput processing.
 */
+(void) stopAsyncCompute
{
    [RSI_keyring stopAsyncCompute];
}

/*
 *  Assign a new expiration date to the seal.
 *  NOTE:  This method is not intended for export because an explicit date is harder for
 *         people to manage and gets complicated across timezones and even customized 
 *         date/time settings for each device.   The self-destruct is the endorsed
 *         option.
 */
-(BOOL) setExpirationDate:(NSDate *) dt withError:(NSError **) err
{
    if (!dt) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return NO;
    }
    
    // - expiration date doesn't apply to producer seals
    if ([self isProducerSeal]) {
        [RSI_error fillError:err withCode:RSIErrorUnsupportedProducerAction];
        return NO;
    }
        
    // - never permit a date before right now.
    // - but this is a legitimate scenario because old messages would
    //   attempt this.
    NSDate *refDate = [NSDate date];
    if ([dt compare:refDate] != NSOrderedDescending) {
        return YES;
    }
    return [self setExpirationDateUnconditionally:dt withError:err];
}

/*
 *  Return the current expiration date for the seal.
 */
-(NSDate *) expirationDateWithDayPadding:(BOOL) dayPad andError:(NSError **) err
{
    if (![self ensureAttributesLoadedWithError:err]) {
        return nil;
    }
    
    NSDate *expDate = [self standardUnpackDateFromMemory:attrib.rawData atOffset:RSI_SEAL_EXPDATE_OFFSET];
    
    // - day padding will extend the expiration to the last moment of the day so that
    //   when the UI says the seal 'expires today', it really means any time today.
    // - I don't think it is productive to try to expire precisely 24 hours after the
    //   message is received because that could be at any time and people are going to
    //   only be in-tune with day-to-day timings and not an hour or minute of the day.
    if (dayPad) {
        NSCalendar       *cal   = [NSCalendar currentCalendar];
        NSDateComponents *comps = [cal components:NSMonthCalendarUnit | NSDayCalendarUnit | NSYearCalendarUnit fromDate:expDate];
        [comps setHour:23];
        [comps setMinute:59];
        expDate                 = [cal dateFromComponents:comps];
    }
    return expDate;
}

/*
 *  Perform a quick check to see if the seal is expired.
 *  - returns an error upon hard failure.
 */
-(BOOL) isExpiredWithDayPadding:(BOOL) dayPad andError:(NSError **) err
{
    //  - owned seals are never expired.
    if ([self isProducerSeal]) {
        return NO;
    }
    
    //  - now look at the date of expiration and
    //    see what it looks like.
    NSDate *expDate = [self expirationDateWithDayPadding:dayPad andError:err];
    if (!expDate) {
        return NO;
    }
    
    NSDate *dNow = [NSDate date];
    if ([dNow compare:expDate] == NSOrderedDescending) {
        return YES;
    }
    return NO;
}

/*
 *  Returns the self destruct timeout on the seal.
 */
-(uint16_t) selfDestructTimeoutWithError:(NSError **) err
{
    if (![self isProducerSeal]) {
        [RSI_error fillError:err withCode:RSIErrorUnsupportedConsumerAction];
        return 0;
    }
    
    if (![self ensureAttributesLoadedWithError:err]) {
        return 0;
    }
    
    return [self selfDestructTimeoutUsingMemory:attrib];
}

/*
 *  Sets the self destruct timeout (in days) in which the seal will
 *  be automatically invalidated if no message is received.
 */
-(BOOL) setSelfDestruct:(uint16_t) selfDestruct withError:(NSError **) err
{
    if (selfDestruct == 0) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return NO;
    }
    
    if (![self isProducerSeal]) {
        [RSI_error fillError:err withCode:RSIErrorUnsupportedConsumerAction];
        return NO;
    }
    
    if (![self ensureAttributesLoadedWithError:err]) {
        return NO;
    }
    
    //  - the self destruct timeout is a uint16_t value representing
    //    the number of days before the seal will self destruct for
    //    consumers.
    RSI_securememory *secMemChanged = [RSI_securememory dataWithSecureData:attrib];
    [RSI_seal assignSelfDestruct:selfDestruct inAttributes:secMemChanged.rawData];
    
    if (![kr setAttributesWithData:secMemChanged andError:err]) {
        return NO;
    }
    
    [self discardCachedAttributes];
    attrib = [secMemChanged retain];
    return YES;
}

/*
 *  Return the id for the color in the seal.
 *  - there are a limited number of colors to improve their design.
 */
-(int) colorIdWithError:(NSError **) err
{
    if (![self ensureAttributesLoadedWithError:err]) {
        return -1;
    }
    
    unsigned char *ptr = (unsigned char *) [attrib bytes];
    ptr = &(ptr[RSI_SEAL_COLOR_OFFSET]);
    return (int) *ptr;
}

/*
 *  Assign a new color id to the seal.
 */
-(BOOL) setColorId:(int) color withError:(NSError **) err
{
    //  - there is only one byte-worth of color storage.
    if (color < 0 || color > 0xFF) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return NO;
    }
    
    if (![self ensureAttributesLoadedWithError:err]) {
        return NO;
    }
    
    RSI_securememory *secMemChanged = [RSI_securememory dataWithSecureData:attrib];
    unsigned char *ptr = (unsigned char *) [secMemChanged mutableBytes];
    ptr = &(ptr[RSI_SEAL_COLOR_OFFSET]);

    *ptr = (unsigned char) color;
    
    if (![kr setAttributesWithData:secMemChanged andError:err]) {
        return NO;
    }
    [self discardCachedAttributes];
    attrib = [secMemChanged retain];
    return YES;    
}

/*
 *  When a seal is expired, the symmetric key is modified to ensure it can never again
 *  be used for decrypting content - at least until it is passed to the consumer again.
 */
-(BOOL) invalidateExpiredSealWithError:(NSError **) err
{
    NSError *tmp = nil;
    if (![self isExpiredWithDayPadding:YES andError:&tmp]) {
        [RSI_error fillError:err withCode:RSIErrorSealStillValid andFailureReason:tmp ? [tmp localizedDescription] : @"Seal is not expired."];
        return NO;
    }
    return [self invalidateSealUnconditionallyWithError:err];
}

/*
 *  Invalidate a seal, no matter what.
 */
-(BOOL) invalidateSealUnconditionallyWithError:(NSError **) err
{
    unsigned char flags = 0;
    if (![self sealFlags:&flags withError:err]) {
        return NO;
    }
    
    if (!(flags & RSI_SEAL_FLAGS_INVALID)) {
        // - I'm trying to be careful here to update as much as possible when
        //   seals are invalidated.
        // - The goal is to always get both of these two items updated, although
        //   the key itself is obviously a more important detail.
        NSError *tmp = nil;
        flags        |= RSI_SEAL_FLAGS_INVALID;
        BOOL ret     = [self setSealFlags:flags withError:&tmp];
        if ([kr invalidateSymmetricKeyWithError:err]) {
            if (!ret) {
                if (err) {
                    *err = tmp;
                    return NO;
                }
            }
        }
        else {
            return NO;
        }
    }
    return YES;
}

/*
 *  Returns whether the seal is invalid.
 */
-(BOOL) isInvalidatedWithError:(NSError **) err
{
    //  This is such an important test that we will always pull from the keychain to verify it because
    //  if we test for invalidation during an encryption task and we accidentally allow an invalid seal
    //  to be used, we'll end up with a serious problem because the mangled symmetric key will be used
    //  to encrypt the data and that key will never be tracked, consequently scrambling the file forever.
    [self discardCachedAttributes];
    
    unsigned char flags = 0;
    if (![self sealFlags:&flags withError:err]) {
        return NO;
    }
    return ((flags & RSI_SEAL_FLAGS_INVALID) ? YES : NO);
}

/*
 *  Change the flag on the seal to invalidate when a snapshot is taken.
 */
-(BOOL) setInvalidateOnSnapshot:(BOOL) enabled withError:(NSError **) err
{
    if (![self isProducerSeal]) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSeal];
        return NO;
    }
    
    // - I am intentionally saving what may be an invalid date (if this device's date is wrong) inside the
    //   seal for the last snapshot update date because I believe it to be important that the first message
    //   received does not reset it.
    // - The possible downside is if the device's date is in the future, then messages will not change it
    //   until that date passes, but I consider this an important part of letting the seal owner choose
    //   how this should proceed as opposed to letting the random retrieval of messages or the date/time on
    //   the consumer's device determine that.
    return [self setInvalidateOnSnapshotUnconditionally:enabled withUpdateDate:[NSDate date] withError:err];
}

/*
 *  Returns the current snapshot invalidation flag.
 */
-(BOOL) isInvalidateOnSnapshotEnabledWithError:(NSError **) err
{
    unsigned char flags = 0;
    if (![self sealFlags:&flags withError:err]) {
        return NO;
    }
    
    // - the flag is unset, but that isn't an error.
    if (!(flags & RSI_SEAL_FLAGS_SNAPVAL)) {
        if (err) {
            *err = nil;
        }
        return NO;
    }
    return YES;
}

/*
 *  If the invalidate-on-snapshot flag is set, invalidate this seal.
 */
-(BOOL) invalidateForSnapshotWithError:(NSError **) err
{
    //  - owned seals have no restrictions on snapshots.
    if ([self isProducerSeal]) {
        [RSI_error fillError:err withCode:RSIErrorSealStillValid];
        return NO;
    }
    
    // - if the flag is set then invalidate this seal.
    if ([self isInvalidateOnSnapshotEnabledWithError:err]) {
        return [self invalidateSealUnconditionallyWithError:err];
    }
    
    if (err && !*err) {
        [RSI_error fillError:err withCode:RSIErrorSealStillValid];
    }
    return NO;
}

/*
 *  Assign a new expiration date to the seal without confirming its viability.
 */
-(BOOL) setExpirationDateUnconditionally:(NSDate *) dt withError:(NSError **) err
{
    // - the expiration date is always relative to the reference date like other dates in this object.
    if (!dt || [dt compare:[NSDate dateWithTimeIntervalSinceReferenceDate:0]] == NSOrderedAscending) {
        dt = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
    }
    
    // - expiration date doesn't apply to producer seals
    if ([self isProducerSeal]) {
        [RSI_error fillError:err withCode:RSIErrorUnsupportedProducerAction];
        return NO;
    }
    
    NSDate *curExpiration = [self expirationDateWithDayPadding:NO andError:err];
    if (!curExpiration) {
        return NO;
    }
    
    //  - don't worry about changing the expiration date if it is the same.
    if ((int64_t)floor([dt timeIntervalSinceReferenceDate]) == (int64_t)floor([curExpiration timeIntervalSinceReferenceDate])) {
        return YES;
    }
    
    RSI_securememory *secMemChanged = [RSI_securememory dataWithSecureData:attrib];
    [self setExpirationDate:dt inAttributes:secMemChanged];
    if (![kr setAttributesWithData:secMemChanged andError:err]) {
        return NO;
    }
    [self discardCachedAttributes];
    attrib = [secMemChanged retain];
    return YES;
}
@end

/***********************
 RSI_seal (internal)
 ***********************/
@implementation RSI_seal (internal)

/*
 *  Initialize a new object.
 *  - a seal without image data cannot be exported.
 */
-(id) initWithKeyring:(RSI_keyring *) keyRing andImageData:(NSData *) seal
{
    self = [super init];
    if (self) {
        kr         = [keyRing retain];
        dSealImage = [seal retain];
        attrib     = nil;
    }
    return self;
}

/*
 *  The attributes are cached in this object to minimize the 
 *  hit to the keyring.
 */
-(BOOL) ensureAttributesLoadedWithError:(NSError **) err
{
    if (!attrib) {
        attrib = [[kr attributeDataWithError:err] retain];
        if (!attrib) {
            return NO;
        }
    }
    return YES;
}

/*
 *  Returns the self destruct timeout on the seal.
 */
-(uint16_t) selfDestructTimeoutUsingMemory:(RSI_securememory *) secMem
{
    if (!secMem || [secMem length] != [RSI_symcrypt keySize]) {
        return 0;
    }
    
    //  - the self destruct timeout is a uint16_t value representing
    //    the number of days before the seal will self destruct for
    //    consumers.
    unsigned char *ptr = (unsigned char *) [secMem bytes];
    ptr = &(ptr[RSI_SEAL_SELFD_OFFSET]);
    
    uint16_t selfDRet = 0;
    for (int i = 0; i < sizeof(selfDRet); i++) {
        selfDRet = selfDRet << 8;
        selfDRet |= *ptr;
        ptr++;
    }
    return selfDRet;
}

/*
 *  Set the expiration date field in a block of attribute memory.
 */
-(void) setExpirationDate:(NSDate *) dt inAttributes:(RSI_securememory *) secMem
{
    NSDate *maxDate = [NSDate dateWithTimeIntervalSinceNow:(RSI_SEAL_MAX_SELFD * RSI_SEAL_SEC_IN_DAY)];
    if (!dt || [dt compare:maxDate] == NSOrderedDescending) {
        dt = maxDate;
    }
    [self standardPackDate:dt intoMemory:secMem.rawData atOffset:RSI_SEAL_EXPDATE_OFFSET];
}

/*
 *  In producer-generated messages, include the revocation criteria to the message.
 */
-(NSDictionary *) addRevocationCriteriaIfProducerToMessage:(NSDictionary *) dictMessage withError:(NSError **) err
{
    if (![self isProducerSeal]) {
        return dictMessage;
    }

    // - first the self destruct timer value.
    uint16_t selfDTimeout = [self selfDestructTimeoutWithError:err];
    if (selfDTimeout == 0) {
        return nil;
    }

    NSMutableDictionary *dictModified = [NSMutableDictionary dictionaryWithDictionary:dictMessage];
    [dictModified setObject:[NSDate date] forKey:RSI_SEAL_KEY_ADD_NOW];
    [dictModified setObject:[NSNumber numberWithUnsignedShort:selfDTimeout] forKey:RSI_SEAL_KEY_ADD_SELFD];
    
    // - now the flag controlling snapshot invalidation.
    unsigned char flags = 0;
    if (![self sealFlags:&flags withError:err]) {
        return nil;
    }

    // - always add the snapshot flag so that we stay in synch with the client
    [dictModified setObject:[NSNumber numberWithBool:(flags & RSI_SEAL_FLAGS_SNAPVAL) ? YES : NO] forKey:RSI_SEAL_KEY_ADD_SNAPINVAL];

    return dictModified;
}

/*
 *  When a producer message comes-in, use it to update the revocation criteria on this seal.
 */
-(NSDictionary *) updateRevocationCriteriaFromMessageData:(NSDictionary *) dMessage withError:(NSError **) err
{
    NSDate *dtSent = [dMessage objectForKey:RSI_SEAL_KEY_ADD_NOW];
    NSNumber *nSelfD = [dMessage objectForKey:RSI_SEAL_KEY_ADD_SELFD];
    if (!dtSent || !nSelfD) {
        [RSI_error fillError:err withCode:RSIErrorInvalidSealedMessage andFailureReason:@"selfd(1)"];
        return nil;
    }
    
    NSMutableDictionary *mdAltMessage = [NSMutableDictionary dictionaryWithDictionary:dMessage];
    NSDate *dtNewExpire = [NSDate dateWithTimeInterval:[nSelfD unsignedShortValue]*RSI_SEAL_SEC_IN_DAY sinceDate:dtSent];
    BOOL invalOnSnap    = NO;
    NSObject *objSnap   = [mdAltMessage objectForKey:RSI_SEAL_KEY_ADD_SNAPINVAL];
    if (objSnap && [objSnap isKindOfClass:[NSNumber class]] && [(NSNumber *) objSnap boolValue]) {
        invalOnSnap = YES;
    }
    [mdAltMessage removeObjectForKey:RSI_SEAL_KEY_ADD_NOW];
    [mdAltMessage removeObjectForKey:RSI_SEAL_KEY_ADD_SELFD];
    [mdAltMessage removeObjectForKey:RSI_SEAL_KEY_ADD_SNAPINVAL];
    
    //  - if this isn't our seal, then update the revocation criteria on it from the message
    if (![self isProducerSeal]) {
        //  - never permit changing the expiration if the new expiration was before today
        //  - but this will allow a person to change their mind and set their self-destruct timer
        //    as an afterthought and have all their readers get updated.
        NSDate *dtNow = [NSDate date];
        if ([dtNow compare:dtNewExpire] == NSOrderedAscending) {
            // - one final check just to make sure that the expiration date always stays within our
            //   required bounds regardless of what the other party provided for a current date
            NSUInteger oNow  = [[NSCalendar currentCalendar] ordinalityOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitEra forDate:dtNow];
            NSUInteger oThen = [[NSCalendar currentCalendar] ordinalityOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitEra forDate:dtNewExpire];
            if (oNow < oThen) {
                // - when the range is blown, which could happen if the owner's clock is wrong on their device, always limit it to one year.
                if (oThen - oNow > RSI_SEAL_MAX_SELFD) {
                    dtNewExpire = [NSDate dateWithTimeInterval:RSI_SEAL_MAX_SELFD * RSI_SEAL_SEC_IN_DAY sinceDate:dtNow];
                }
            
                // - assign the new expiration date.
                if (![self setExpirationDate:dtNewExpire withError:nil]) {
                    [RSI_error fillError:err withCode:RSIErrorInvalidSealedMessage andFailureReason:@"selfd(2)"];
                    return nil;
                }
            }
        }
        
        // - add the snapshot invalidation flag, but only if this message is newer than when it was
        //   last updated.
        // - this ensures that the producer can continue to update their snapshot flag and the consumer can't play tricks and cause it to be
        //   turned off by reading a different, older message.
        if (objSnap && ![self setInvalidateOnSnapshotEnabled:invalOnSnap ifLastUpdateIsOlderThanDate:dtSent withError:err]) {
            return nil;
        }
    }

    //  - and return the message.
    return mdAltMessage;   
}

/*
 *  Return the seal flags.
 */
-(BOOL) sealFlags:(unsigned char *) flags withError:(NSError **) err
{
    if (![self ensureAttributesLoadedWithError:err]) {
        return NO;
    }
    
    unsigned char *ptr = (unsigned char *) [attrib bytes];
    ptr = &(ptr[RSI_SEAL_FLAGS_OFFSET]);

    if (flags) {
        *flags = *ptr;
    }
    return YES;
}

/*
 *  Change the seal flags.
 */
-(BOOL) setSealFlags:(unsigned char) flags withError:(NSError **) err
{
    if (![self ensureAttributesLoadedWithError:err]) {
        return NO;
    }
    
    RSI_securememory *secMemChanged = [RSI_securememory dataWithSecureData:attrib];
    unsigned char *ptr = (unsigned char *) [secMemChanged mutableBytes];
    ptr = &(ptr[RSI_SEAL_FLAGS_OFFSET]);
    
    *ptr = flags;
    
    if (![kr setAttributesWithData:secMemChanged andError:err]) {
        return NO;
    }
    [self discardCachedAttributes];
    attrib = [secMemChanged retain];
    return YES;
}

/*
 *  Return the last update date of the snapshot protection flag in the seal.
 */
-(NSDate *) lastSnapshotUpdateWithError:(NSError **) err
{
    if (![self ensureAttributesLoadedWithError:err]) {
        return nil;
    }
    return [self standardUnpackDateFromMemory:attrib.rawData atOffset:RSI_SEAL_SNAP_DATE_OFFSET];
}

/*
 *  The snapshot flag associated with this seal is updated by message only if its last update
 *  date is older than the one provided in the message.
 */
-(BOOL) setInvalidateOnSnapshotEnabled:(BOOL) isEnabled ifLastUpdateIsOlderThanDate:(NSDate *) dtUpdate withError:(NSError **) err
{
    NSDate *dtLast = [self lastSnapshotUpdateWithError:err];
    if (!dtLast || !dtUpdate) {
        return  NO;
    }
    
    // - don't report an error because the provided date is older and the new protection state is stale.
    if ([dtLast compare:dtUpdate] != NSOrderedAscending) {
        return YES;
    }
    
    return [self setInvalidateOnSnapshotUnconditionally:isEnabled withUpdateDate:dtUpdate withError:err];
}

/*
 *  Set the self-destruct value in the provided memory block.
 */
+(void) assignSelfDestruct:(uint16_t) selfDestruct inAttributes:(NSMutableData *) attribs
{
    unsigned char *ptr = (unsigned char *) [attribs mutableBytes];
    ptr = &(ptr[RSI_SEAL_SELFD_OFFSET]);
    
    for (int i = 0; i < sizeof(selfDestruct); i++) {
        *ptr = (unsigned char) (selfDestruct >> ((sizeof(selfDestruct)-1) << 3));
        selfDestruct = selfDestruct << 8;
        ptr++;
    }
}

/*
 *  Change the flag on the seal to invalidate when a snapshot is taken.
 */
-(BOOL) setInvalidateOnSnapshotUnconditionally:(BOOL) enabled withUpdateDate:(NSDate *) dtUpdated withError:(NSError **) err
{
    // - the update date is always relative to the reference date like other dates in this object.
    if (!dtUpdated || [dtUpdated compare:[NSDate dateWithTimeIntervalSinceReferenceDate:0]] == NSOrderedAscending) {
        dtUpdated = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
    }
    
    if (![self ensureAttributesLoadedWithError:err]) {
        return NO;
    }

    RSI_securememory *secMemChanged = [RSI_securememory dataWithSecureData:attrib];
    unsigned char *ptr              = (unsigned char *) [secMemChanged mutableBytes];
    unsigned char flags             = (ptr[RSI_SEAL_FLAGS_OFFSET] & ~RSI_SEAL_FLAGS_SNAPVAL);
    if (enabled) {
        flags |= RSI_SEAL_FLAGS_SNAPVAL;
    }
    ptr[RSI_SEAL_FLAGS_OFFSET]      = flags;
    [self standardPackDate:dtUpdated intoMemory:secMemChanged.rawData atOffset:RSI_SEAL_SNAP_DATE_OFFSET];
    if (![kr setAttributesWithData:secMemChanged andError:err]) {
        return NO;
    }
    [self discardCachedAttributes];
    attrib = [secMemChanged retain];
    return YES;
}

/*
 *  This check must occur before all forms of encryption because after a seal is invalidated, it should
 *  never again be used for encryption or it can risk applying the new key to the old data and still allowing
 *  access!
 */
-(BOOL) isSealValidForEncryptionWithError:(NSError **) err
{
    //  NOTE:  This test assumes that the 'isInvalidated' check below will pull directly
    //         from the keychain whenever it looks at flags to ensure we never use the
    //         mangled symmetric key to try to encrypt a file.
    
    // - just to be sure, we're always going to discard the current attributes, which
    //   I know is redundant with isInvalidated, but I got stung badly by this possibility.
    [self discardCachedAttributes];
    
    // - check invalidation state, which is the only real test.
    if (![self isInvalidatedWithError:nil]) {
        return YES;
    }
    [RSI_error fillError:err withCode:RSIErrorInvalidSeal];
    return NO;
}

/*
 *  Dates are always going to be stored as uint32_t relative to the reference date, so in order
 *  to ensure consistency, we'll pack them in one location.
 */
-(void) standardPackDate:(NSDate *) dt intoMemory:(NSMutableData *) mem atOffset:(NSUInteger) offset
{
    if (offset + RSI_SEAL_STD_DATE_LEN > mem.length) {
        return;
    }
    unsigned char *ptr = (unsigned char *) [mem mutableBytes];
    uint32_t tVal      = (uint32_t) [dt timeIntervalSinceReferenceDate];
    for (NSUInteger i = 0; i < RSI_SEAL_STD_DATE_LEN; i++) {
        ptr[offset + i] = (unsigned char) ((tVal >> 24) & 0xFF);
        tVal            = tVal << 8;
    }
}

/*
 *  Unpack a date from the attributes.
 */
-(NSDate *) standardUnpackDateFromMemory:(NSData *) mem atOffset:(NSUInteger) offset
{
    if (offset + RSI_SEAL_STD_DATE_LEN > mem.length) {
        return nil;
    }
    
    const unsigned char *ptr = (const unsigned char *) [mem bytes];
    
    uint32_t tVal = 0;
    for (NSUInteger i = 0; i < RSI_SEAL_STD_DATE_LEN; i++) {
        tVal =  tVal << 8;
        tVal |= ptr[offset + i];
    }
    return [NSDate dateWithTimeIntervalSinceReferenceDate:tVal];
}

/*
 *  Discard copies of attributes we have been using.
 */
-(void) discardCachedAttributes
{
    [attrib release];
    attrib = nil;
}
@end