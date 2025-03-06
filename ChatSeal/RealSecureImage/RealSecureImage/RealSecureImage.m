//
//  RealSecureImage.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 11/9/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import "RealSecureImage.h"
#import "RSI_pack.h"
#import "RSI_unpack.h"
#import "RSI_scrambler.h"
#import "RSI_common.h"
#import "RSI_securememory.h"
#import "RSI_vault.h"
#import "RSI_symcrypt.h"
#import "RSI_secure_props.h"
#import "RSI_seal.h"
#import "RSI_jpeg.h"

// - forward declarations
@interface RSISecureMessageIdentification (internal)
-(void) setMessage:(RSISecureMessage *) sm;
-(void) setMatchIsPossible:(BOOL) flag;
@end


/**************************
 RealSecureImage
 **************************/
@implementation RealSecureImage

/*
 *  Produce a JPEG file at the given compression ratio with the supplied data.
 */
+(NSData *) packedJPEG:(UIImage *) img withQuality:(CGFloat) quality andData:(NSData *) d andError:(NSError **) err
{
    return [RSI_pack packedJPEG:img withQuality:quality andData:d andError:err];
}

/*
 *  Retrieve the data enclosed in a given JPEG file.
 */
+(NSData *) unpackData:(NSData *) imgFile withMaxLength:(NSUInteger) maxLen andError:(NSError **) err
{
    return [RSI_unpack unpackData:imgFile withMaxLength:maxLen andError:err];
}

/*
 *  Compute the maximum amount of data that the given JPEG image can contain (in bytes).
 */
+(NSUInteger) maxDataForJPEGImage:(UIImage *) img
{
    return [RSI_pack maxDataForJPEGImage:img];
}

/*
 *  The maximum number of bits stored per coefficient in a JPEG file.
 */
+(NSUInteger) bitsPerJPEGCoefficient
{
    return [RSI_pack bitsPerJPEGCoefficient];
}

/*
 *  The number of coefficients per DU in a JPEG that can contain embedded data.
 */
+(NSUInteger) embeddedJPEGGroupSize
{
    return [RSI_pack embeddedJPEGGroupSize];
}

/*
 *  Allocate a transient scrambler key.
 */
+(RSI_scrambler *) allocTransientScramblerForData:(NSData *) d andError:(NSError **) err
{
    NSMutableData *mdKey = [NSMutableData dataWithData:d];
    [mdKey setLength:[RSI_scrambler keySize]];
    
    RSI_scrambler *scramKey = [RSI_scrambler allocTransientKeyWithData:mdKey andError:err];
    if (!scramKey) {
        return nil;
    }
    return scramKey;
}

/*
 *  Return a JPEG that has had its color scrambled by a given key.
 */
+(NSData *) scrambledJPEG:(UIImage *) img withQuality:(CGFloat) quality andKey:(NSData *) d andError:(NSError **) err
{
    RSI_scrambler *scramKey = [RealSecureImage allocTransientScramblerForData:d andError:err];
    if (!scramKey) {
        return nil;
    }
    
    NSData *ret = [RSI_pack scrambledJPEG:img withQuality:quality andKey:scramKey andError:err];
    [scramKey release];
    return ret;
}

/*
 *  Return a JPEG that has had its color scrambled by a given key, assuming that the source
 *  JPEG was previously encoded with this library.
 */
+(NSData *) scrambledJPEG:(NSData *) jpegFile andKey:(NSData *) d andError:(NSError **) err
{
    RSI_scrambler *scramKey = [RealSecureImage allocTransientScramblerForData:d andError:err];
    if (!scramKey) {
        return nil;
    }
    
    NSData *ret = [RSI_unpack scrambledJPEG:jpegFile andKey:scramKey andError:err];
    [scramKey release];
    return ret;
}

/*
 *  Return a descrambled version of a JPEG.
 */
+(RSISecureData *) descrambledJPEG:(NSData *) jpegFile andKey:(NSData *) d andError:(NSError **) err
{
    RSI_scrambler *scramKey = [RealSecureImage allocTransientScramblerForData:d andError:err];
    if (!scramKey) {
        return nil;
    }
    
    RSI_securememory *ret = [RSI_unpack descrambledJPEG:jpegFile withKey:scramKey andError:err];
    [scramKey release];
    return [ret convertToSecureData];
}

/*
 *  Hash the colors of an image.
 */
+(RSISecureData *) hashImageData:(NSData *) imgFile withError:(NSError **) err
{
    RSI_securememory *ret = [RSI_unpack hashImageData:imgFile withError:err];
    return [ret convertToSecureData];
}

/*
 *  Repack a JPEG file.
 */
+(NSData *) repackData:(NSData *) imgFile withData:(NSData *) data andError:(NSError **) err
{
    return [RSI_unpack repackData:imgFile withData:data andError:err];
}

/*
 *  This is a quick test to determine if the given data buffer is even large enough
 *  to identify its image file type.
 */
+(BOOL) hasEnoughDataForImageTypeIdentification:(NSData *) d
{
    return [RSI_unpack hasEnoughDataForImageTypeIdentification:d];
}

/*
 *  This is a quick test of a data buffer to determine if we can support it for unpacking.
 */
+(BOOL) isSupportedPackedFile:(NSData *) d
{
    return [RSI_unpack isSupportedPackedFile:d];
}

/*
 *  This value is chosen to compromise between size and quality, recognizing that
 *  as a steganographic solution, quality will more often suffer.
 */
+(CGFloat) defaultJPEGQualityForMessaging
{
    return [JPEG_pack defaultJPEGQualityForMessaging];
}

/*
 *  Return the most data that the given image can store.
 */
+(NSUInteger) maxDataForPNGImage:(UIImage *) img
{
    return [RSI_pack maxDataForPNGImage:img];
}

/*
 *  Return the most data that the given image can store.
 */
+(NSUInteger) maxDataForPNGImageOfSize:(CGSize) szImage
{
    return [RSI_pack maxDataForPNGImageOfSize:szImage];
}

/*
 *  Return the number of bits stored per PNG pixel.
 */
+(NSUInteger) bitsPerPNGPixel
{
    return [RSI_pack bitsPerPNGPixel];
}

/*
 *  Return a PNG image with the data packed into it
 */
+(NSData *) packedPNG:(UIImage *) img andData:(NSData *) data andError:(NSError **) err
{
    return [RSI_pack packedPNG:img andData:data andError:err];
}

/*
 *  Quick test to determine if the vault exists.
 */
+(BOOL) hasVault
{
    return [RSI_vault hasVault];
}

/*
 *  Determines if the current user is authenticated with the vault.
 */
+(BOOL) isVaultOpen
{
    return [RSI_vault isOpen];
}

/*
 *  Destroys the vault completely.
 */
+(BOOL) destroyVaultWithError:(NSError **)err
{
    return [RSI_vault destroyVaultWithError:err];
}

/*
 *  Create a new vault, destroying the previous one.
 */
+(BOOL) initializeVaultWithPassword:(NSString *) pwd andError:(NSError **) err
{
    return [RSI_vault initializeVaultWithPassword:pwd andError:err];
}

/*
 *  Authenciate with an existing vault.
 */
+(BOOL) openVaultWithPassword:(NSString *) pwd andError:(NSError **) err
{
    return [RSI_vault openVaultWithPassword:pwd andError:err];
}

/*
 *  Change the current vault's password.
 */
+(BOOL) changeVaultPassword:(NSString *)pwdFrom toPassword:(NSString *)pwdTo andError:(NSError **)err
{
    return [RSI_vault changeVaultPassword:pwdFrom toPassword:pwdTo andError:err];
}

/*
 *  Write a file to be secured by the vault.
 */
+(BOOL) writeVaultData:(NSData *) sourceData toFile:(NSString *) fName withError:(NSError **) err
{
    return [RSI_vault writeData:sourceData toFile:fName withError:err];
}

/*
 *  Write a file to be secured by the vault.
 */
+(BOOL) writeVaultData:(NSData *) sourceData toURL:(NSURL *) url withError:(NSError **) err
{
    return [RSI_vault writeData:sourceData toURL:url withError:err];
}

/*
 *  Read a secured file from the vault.
 */
+(BOOL) readVaultFile:(NSString *) fName intoData:(RSISecureData **) destData withError:(NSError **) err
{
    return [RSI_vault readFile:fName intoData:destData withError:err];
}

/*
 *  Read a secured file from the vault.
 */
+(BOOL) readVaultURL:(NSURL *) url intoData:(RSISecureData **) destData withError:(NSError **) err
{
    return [RSI_vault readURL:url intoData:destData withError:err];
}

/*
 *  Convert a releative name into an absolute URL.
 */
+(NSURL *) absoluteURLForVaultFile:(NSString *) fName withError:(NSError **) err
{
    return [RSI_vault absoluteURLForFile:fName withError:err];
}

/*
 *  Closes the vault if it is open, preventing further access until authentication occurs.
 */
+(void) closeVault
{
    [RSI_vault closeVault];
}

/*
 *  The highest cost of seal creation involves its public/private keypair.  This async method will
 *  request that be completed.
 */
+(void) prepareForSealGeneration
{
    [RSI_vault prepareForSealGeneration];
}

/*
 *  Get an enumeration of all the seals in the vault.
 */
+(NSArray *) availableSealsWithError:(NSError **) err
{
    return [RSI_vault availableSealsWithError:err];
}

/*
 *  Get the lookup table of all safe seal ids in the system.
 */
+(NSDictionary *) safeSealIndexWithError:(NSError **) err
{
    return [RSI_vault safeSealIndexWithError:err];
}

/*
 *  Return the length of a safe salted string value.
 *  - if not hex, then base-64.
 */
+(NSUInteger) lengthOfSafeSaltedStringAsHex:(BOOL) asHex
{
    return [RSI_vault lengthOfSafeSaltedStringAsHex:asHex];
}

/*
 *  Return an appropriate base-64 string from the given data.
 */
+(NSString *) filenameSafeBase64FromData:(NSData *) d
{
    if (!d.length) {
        return nil;
    }
    return [RSI_common base64FromData:d];
}

/*
 *  Convert a string into a network-friendly service name.
 *  - NOTE: this must be a valid length for Bonjour when completed.
 */
+(NSString *) secureServiceNameFromString:(NSString *) s
{
    if (!s) {
        return nil;
    }
    
    // - HASHING-NOTE:
    // - service names are only expected to be unique under normal circumstances and have
    //   a maximum length in Bonjour anyway.  We must stick with SHA-1 for this.
    RSI_SHA1 *sha1 = [[RSI_SHA1 alloc] init];
    const char *sid_salt = "pssidslt";
    [sha1 update:sid_salt withLength:strlen(sid_salt)];
    const char *ptrSid = [s UTF8String];
    [sha1 update:ptrSid withLength:strlen(ptrSid)];
    NSString *sRet = [sha1 stringHash];                 // - I want this to be a standard hex value so that the network system can find it to be predictable.
    [sha1 release];
    return sRet;
}

/*
 *  Return the length of the name when it is defined.
 */
+(NSUInteger) lengthOfSecureServiceName
{
    return [RSI_SHA1 SHA_LEN] * 2;
}

/*
 *  Creates a new seal in the vault.
 */
+(NSString *) createSealWithImage:(UIImage *) img andColor:(RSISecureSeal_Color_t) color andError:(NSError **) err
{
    return [RSI_vault createSealWithImage:img andColor:color andError:err];
}

/*
 *  Import someone else's seal into the vault.
 */
+(RSISecureSeal *) importSeal:(NSData *) sealData usingPassword:(NSString *) pwd withError:(NSError **) err
{
    return [RSI_vault importSeal:sealData usingPassword:pwd withError:err];
}

/*
 *  Retrieve an existing seal from the vault.
 */
+(RSISecureSeal *) sealForId:(NSString *) sealId andError:(NSError **) err
{
    return [RSI_vault sealForId:sealId andError:err];
}

/*
 *  Returns whether a given seal exists in the vault.
 */
+(BOOL) sealExists:(NSString *) sealId withError:(NSError **) err
{
    return [RSI_vault sealExists:sealId withError:err];
}

/*
 *  Deletes a seal from the system.
 */
+(BOOL) deleteSealForId:(NSString *) sealId andError:(NSError **) err
{
    return [RSI_vault deleteSeal:sealId withError:err];
}

/*
 *  Encrypt an array into a payload using the supplied password.
 */
+(NSData *) encryptArray:(NSArray *) arr forVersion:(uint16_t) v usingPassword:(NSString *) pwd withError:(NSError **) err
{
    if (!arr || !pwd) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return nil;
    }
    
    RSI_symcrypt *sk = [RSI_symcrypt allocTransientWithPassword:pwd andError:err];
    if (!sk) {
        return nil;
    }
    
    NSData *dRet = [RSI_secure_props encryptWithProperties:arr forType:RSI_SECPROP_APP andVersion:v usingKey:sk withError:err];
    [sk release];
    return dRet;
}

/*
 *  Decrypt a payload into an array using the supplied password.
 */
+(NSArray *) decryptIntoArray:(NSData *) dEncrypted forVersion:(uint16_t) v usingPassword:(NSString *) pwd withError:(NSError **) err
{
    if (!dEncrypted || !pwd) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return nil;
    }
    
    RSI_symcrypt *sk = [RSI_symcrypt allocTransientWithPassword:pwd andError:err];
    if (!sk) {
        return nil;
    }
    
    NSArray *arrRet = [RSI_secure_props decryptIntoProperties:dEncrypted forType:RSI_SECPROP_APP andVersion:v usingKey:sk withError:err];
    [sk release];
    return arrRet;
}

/*
 *  Return a string hash for the given data.
 */
+(NSString *) secureHashForData:(NSData *) data
{
    if (!data) {
        return @"";
    }
    
    // - HASHING-NOTE:
    //      - Use the best hash we have.
    RSI_SHA_SECURE *sha = [[RSI_SHA_SECURE alloc] init];
    [sha updateWithData:data];
    NSString *ret = [sha stringHash];
    [sha release];
    return ret;
}

/*
 *  Return a hash for the given data that is salted with the app key.
 */
+(NSString *) safeSaltedStringAsHex:(NSString *) source withError:(NSError **) err
{
    return [RSI_vault safeSaltedStringAsHex:source withError:err];
}

/*
 *  Return a hash for the given data that is salted with the app key.
 *  - NOTE: this is going to be much more costly than a simple HEX salted hash so use it 
 *          only when it isn't a target of constant recomputation.
 */
+(NSString *) safeSaltedStringAsBase64:(NSString *) source withError:(NSError **) err
{
    return [RSI_vault safeSaltedStringAsBase64:source withError:err];
}

/*
 *  This is a limited hash of the packed content's header, but if it is compared to
 *  content that was previously decrypted successfully, is guaranteed to be unique
 *  and a reliable way to identify partial matches for a packed stream.
 */
+(NSString *) hashForPackedContent:(NSData *) dPacked withError:(NSError **) err
{
    NSError *tmp       = nil;
    NSData *dEncrypted = [RealSecureImage unpackData:dPacked withMaxLength:[RSI_secure_props propertyHeaderLength] andError:&tmp];
    if (!dEncrypted || [dEncrypted length] < [RSI_secure_props propertyHeaderLength]) {
        [RSI_error fillError:err withCode:tmp ? tmp.code : RSIErrorInvalidSecureImage];
        return nil;
    }
    return [RSI_seal hashForEncryptedMessage:dEncrypted withError:err];
}

/*
 *  This method allows a caller to determine if the given packed data blob is suffiently large to support identification, which
 *  is useful during a download process and we have some of the data but not all of it yet.
 */
+(BOOL) hasEnoughDataForSealIdentification:(NSData *) dPacked
{
    @autoreleasepool {
        if (![RealSecureImage hasEnoughDataForImageTypeIdentification:dPacked]) {
            return NO;
        }
        
        // - when the file is just wrong, we can still assume it can support identification
        if (![RealSecureImage isSupportedPackedFile:dPacked]) {
            return YES;
        }
        
        NSError *tmp       = nil;
        NSData *dEncrypted = [RealSecureImage unpackData:dPacked withMaxLength:[RSI_secure_props propertyHeaderLength] andError:&tmp];
    
        // - the error code is very clear when the image will never suffice for this so we should assume it has everything we need to
        //   identify it.
        if (!dEncrypted && tmp.code == RSIErrorInvalidSecureImage) {
            return YES;
        }
        
        // - when there isn't enough data yet, we should keep trying.
        if (!dEncrypted || [dEncrypted length] < [RSI_secure_props propertyHeaderLength]) {
            // - there isn't yet enough encrypted data to decode the header
            return NO;
        }
        
        // - there is enough here, so proceed.
        return YES;
    }
}

/*
 *  This method combines the behavior of the hasEnoughDataForSealIdentification and the identifyPackedContent methods
 *  to figure out as quickly as possible what the status of the supplied buffer is.  The idea is to be able to 
 *  quickly check incoming images that are partially downloaded and figure out if it makes sense to continue retrieving them.
 */
+(RSISecureMessageIdentification *) quickPackedContentIdentification:(NSData *) dPacked
{
    RSISecureMessageIdentification *smiRet = [[[RSISecureMessageIdentification alloc] init] autorelease];
    @autoreleasepool {
        if (![RealSecureImage hasEnoughDataForImageTypeIdentification:dPacked]) {
            [smiRet setMatchIsPossible:YES];
            return smiRet;
        }
        
        // - when the file is just wrong, we can still assume it can support identification
        if (![RealSecureImage isSupportedPackedFile:dPacked]) {
            [smiRet setMatchIsPossible:NO];
            return smiRet;
        }
        
        NSError *tmp       = nil;
        NSData *dEncrypted = [RealSecureImage unpackData:dPacked withMaxLength:[RSI_secure_props propertyHeaderLength] andError:&tmp];
        
        // - an invalid image will never match, obviously.
        if (!dEncrypted && tmp.code == RSIErrorInvalidSecureImage) {
            [smiRet setMatchIsPossible:NO];
            return smiRet;
        }
        
        // - when there isn't enough data yet, we should keep trying.
        if (!dEncrypted || [dEncrypted length] < [RSI_secure_props propertyHeaderLength]) {
            // - there isn't yet enough encrypted data to decode the header
            [smiRet setMatchIsPossible:YES];
            return smiRet;
        }
        
        RSISecureMessage *sm = [RSI_seal identifyEncryptedMessage:dEncrypted withFullDecryption:NO andError:&tmp];
        if (sm) {
            [smiRet setMessage:sm];            
            if (sm.sealId) {
                [smiRet setMatchIsPossible:YES];
            }
            else {
                // - when the identification returns nothing, we have to assume the seal doesn't exist.
                [smiRet setMatchIsPossible:NO];
            }
        }
        else {
            // - when an unexpected error occurs, we must be optimistic.
            [smiRet setMatchIsPossible:YES];
        }
    }
    return smiRet;
}


/*
 *  The purpose of this method is to determine as quickly as possible whether the provided data file can be opened by
 *  the local vault-secured seals.   If so, it can optionally unpack the data.
 */
+(RSISecureMessage *) identifyPackedContent:(NSData *) dPacked withFullDecryption:(BOOL) fullDecryption andError:(NSError **) err
{
    //  NOTE:
    //  - We cannot make any assumptions as a rule about how the image files will store their content, which means that
    //    the file must be processed, at least partially, in order to determine its nature.   Even something as simple as a hash
    //    must either be applied to the entire packed file or to the data hidden in the file, but not to the basic structure of part
    //    of the PNG/JPEG file.    
    NSError *tmp       = nil;
    NSData *dEncrypted = [RealSecureImage unpackData:dPacked withMaxLength:fullDecryption ? 0 : [RSI_secure_props propertyHeaderLength] andError:&tmp];
    if (!dEncrypted || [dEncrypted length] < [RSI_secure_props propertyHeaderLength]) {
        [RSI_error fillError:err withCode:tmp ? tmp.code : RSIErrorInvalidSecureImage];
        return nil;
    }
    return [RSI_seal identifyEncryptedMessage:dEncrypted withFullDecryption:fullDecryption andError:err];
}

@end

/******************************
 RSISecureMessageIdentification
 ******************************/
@implementation RSISecureMessageIdentification
/*
 *  Object attributes.
 */
{
    RSISecureMessage *message;
    BOOL             willNeverMatch;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        message        = nil;
        willNeverMatch = YES;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [message release];
    message = nil;
    
    [super dealloc];
}

/*
 *  Return the message assigned to this object.
 */
-(RSISecureMessage *) message
{
    return [[message retain] autorelease];
}

/*
 *  Return the match state.
 */
-(BOOL) willNeverMatch
{
    return willNeverMatch;
}
@end

/******************************************
 RSISecureMessageIdentification (internal)
 ******************************************/
@implementation RSISecureMessageIdentification (internal)
/*
 *  Assign the message to this object.
 */
-(void) setMessage:(RSISecureMessage *) sm
{
    if (sm != message) {
        [message release];
        message = [sm retain];
    }
}

/*
 *  Assign the never match flag to this object.
 */
-(void) setMatchIsPossible:(BOOL) flag
{
    willNeverMatch = !flag;
}

@end
