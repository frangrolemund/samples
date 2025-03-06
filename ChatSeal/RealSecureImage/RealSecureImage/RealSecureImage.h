//
//  RealSecureImage.h
//  RealSecureImage
//
//  Created by Francis Grolemund on 11/9/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

/*****************************
 RealSecureImage
 *****************************/
@class RSISecureSeal;
@class RSISecureData;
@class RSISecureMessage;

typedef enum
{
    RSSC_STD_PURPLE       = 0,
    RSSC_STD_ORANGE       = 1,
    RSSC_STD_YELLOW       = 2,
    RSSC_STD_GREEN        = 3,
    RSSC_STD_BLUE         = 4,
    
    RSSC_NUM_SEAL_COLORS,
    RSSC_DEFAULT          = RSSC_STD_YELLOW,                // - I'm beginning with something positive and bright.
    RSSC_INVALID          = -1
} RSISecureSeal_Color_t;

@interface RSISecureMessageIdentification : NSObject
@property (nonatomic, readonly) BOOL willNeverMatch;
@property (nonatomic, readonly) RSISecureMessage *message;
@end

@interface RealSecureImage : NSObject

//  - high level interaction with the seal vault.
+(BOOL) hasVault;
+(BOOL) isVaultOpen;
+(BOOL) destroyVaultWithError:(NSError **) err;
+(BOOL) initializeVaultWithPassword:(NSString *) pwd andError:(NSError **) err;
+(BOOL) openVaultWithPassword:(NSString *) pwd andError:(NSError **) err;
+(BOOL) changeVaultPassword:(NSString *) pwdFrom toPassword:(NSString *) pwdTo andError:(NSError **) err;
+(BOOL) writeVaultData:(NSData *) sourceData toFile:(NSString *) fName withError:(NSError **) err;
+(BOOL) readVaultFile:(NSString *) fName intoData:(RSISecureData **) destData withError:(NSError **) err;
+(BOOL) writeVaultData:(NSData *) sourceData toURL:(NSURL *) url withError:(NSError **) err;
+(BOOL) readVaultURL:(NSURL *) url intoData:(RSISecureData **) destData withError:(NSError **) err;
+(NSURL *) absoluteURLForVaultFile:(NSString *) fName withError:(NSError **) err;
+(void) closeVault;
+(void) prepareForSealGeneration;

+(NSArray *) availableSealsWithError:(NSError **) err;
+(NSDictionary *) safeSealIndexWithError:(NSError **) err;
+(NSString *) secureServiceNameFromString:(NSString *) s;
+(NSUInteger) lengthOfSecureServiceName;
+(NSString *) createSealWithImage:(UIImage *) img andColor:(RSISecureSeal_Color_t) color andError:(NSError **) err;
+(RSISecureSeal *) sealForId:(NSString *) sealId andError:(NSError **) err;
+(BOOL) sealExists:(NSString *) sealId withError:(NSError **) err;
+(RSISecureSeal *) importSeal:(NSData *) sealData usingPassword:(NSString *) pwd withError:(NSError **) err;
+(BOOL) deleteSealForId:(NSString *) sealId andError:(NSError **) err;

//  - generic encryption APIs
+(NSData *) encryptArray:(NSArray *) arr forVersion:(uint16_t) v usingPassword:(NSString *) pwd withError:(NSError **) err;
+(NSArray *) decryptIntoArray:(NSData *) dEncrypted forVersion:(uint16_t) v usingPassword:(NSString *) pwd withError:(NSError **) err;
+(NSString *) secureHashForData:(NSData *) data;
+(NSString *) safeSaltedStringAsHex:(NSString *) source withError:(NSError **) err;
+(NSString *) safeSaltedStringAsBase64:(NSString *) source withError:(NSError **) err;
+(NSUInteger) lengthOfSafeSaltedStringAsHex:(BOOL) asHex;
+(NSString *) filenameSafeBase64FromData:(NSData *) d;

//  - low level APIs for direct manipulation of images
+(BOOL) hasEnoughDataForImageTypeIdentification:(NSData *) d;
+(BOOL) isSupportedPackedFile:(NSData *) d;
+(CGFloat) defaultJPEGQualityForMessaging;
+(NSUInteger) maxDataForJPEGImage:(UIImage *) img;
+(NSUInteger) bitsPerJPEGCoefficient;
+(NSUInteger) embeddedJPEGGroupSize;
+(NSData *) packedJPEG:(UIImage *) img withQuality:(CGFloat) quality andData:(NSData *) d andError:(NSError **) err;
+(NSData *) unpackData:(NSData *) imgFile withMaxLength:(NSUInteger) maxLen andError:(NSError **) err;
+(NSData *) scrambledJPEG:(UIImage *) img withQuality:(CGFloat) quality andKey:(NSData *) d andError:(NSError **) err;
+(NSData *) scrambledJPEG:(NSData *) jpegFile andKey:(NSData *) d andError:(NSError **) err;
+(RSISecureData *) descrambledJPEG:(NSData *) jpegFile andKey:(NSData *) d andError:(NSError **) err;
+(RSISecureData *) hashImageData:(NSData *) imgFile withError:(NSError **) err;
+(NSData *) repackData:(NSData *) imgFile withData:(NSData *) data andError:(NSError **) err;
+(NSUInteger) maxDataForPNGImage:(UIImage *) img;
+(NSUInteger) maxDataForPNGImageOfSize:(CGSize) szImage;
+(NSUInteger) bitsPerPNGPixel;
+(NSData *) packedPNG:(UIImage *) img andData:(NSData *) data andError:(NSError **) err;

// - aggregate APIs
+(NSString *) hashForPackedContent:(NSData *) dPacked withError:(NSError **) err;
+(BOOL) hasEnoughDataForSealIdentification:(NSData *) dPacked;
+(RSISecureMessageIdentification *) quickPackedContentIdentification:(NSData *) dPacked;
+(RSISecureMessage *) identifyPackedContent:(NSData *) dPacked withFullDecryption:(BOOL) fullDecryption andError:(NSError **) err;
@end

/*****************************
 RSISecureSeal
 *****************************/
//  NOTE:  There is intentionally no identifying information in this object because
//  it is not real (how do I really know they are who they say they are?) and it prevents
//  a misplaced seal from being easily used by its finder.
//  - Therefore, do not store any names or other data here.  Use the messages to
//    transmit that content out of band from the seal's data.
@interface RSISecureSeal : NSObject
+(NSUInteger) defaultSelfDestructDays;
-(NSString *) sealId;
-(NSString *) safeSealIdWithError:(NSError **) err;
-(BOOL) isOwned;
-(NSURL *) onDiskFile;
-(RSISecureSeal_Color_t) colorWithError:(NSError **) err;
-(BOOL) setColor:(RSISecureSeal_Color_t) color withError:(NSError **) err;
-(uint16_t) selfDestructTimeoutWithError:(NSError **) err;
-(BOOL) setSelfDestruct:(uint16_t) sdInDays withError:(NSError **) err;
-(BOOL) setInvalidateOnSnapshot:(BOOL) enabled withError:(NSError **) err;
-(BOOL) isInvalidateOnSnapshotEnabledWithError:(NSError **) err;
-(NSData *) originalSealImageWithError:(NSError **) err;
-(UIImage *) safeSealImageWithError:(NSError **) err;
-(NSData *) encryptLocalOnlyMessage:(NSDictionary *) msg withError:(NSError **) err;
-(NSData *) encryptRoleBasedMessage:(NSDictionary *) msg withError:(NSError **) err;
-(NSData *) packRoleBasedMessage:(NSDictionary *) msg intoImage:(UIImage *) img withError:(NSError **) err;
-(NSDictionary *) unpackAndDecryptMessage:(NSData *) msg withError:(NSError **) err;
-(NSString *) hashPackedMessage:(NSData *) msg;
-(NSDictionary *) decryptMessage:(NSData *) dEncrypted withError:(NSError **) err;
-(NSData *) exportWithPassword:(NSString *) pwd andError:(NSError **) err;
-(BOOL) invalidateExpiredWithError:(NSError **) err;
-(BOOL) invalidateForSnapshotWithError:(NSError **) err;
-(BOOL) invalidateUnconditionallyWithError:(NSError **) err;
-(BOOL) isInvalidatedWithError:(NSError **) err;
-(BOOL) setExpirationDate:(NSDate *) dt withError:(NSError **) err;
@end

/*****************************
 RSISecureData
 *****************************/
@interface RSISecureData : NSObject
-(id) initWithData:(NSMutableData *)md;
-(NSData *) rawData;
@end

/*****************************
 RSISecureMessage
 *****************************/
@interface RSISecureMessage : NSObject
@property (nonatomic, retain) NSString     *sealId;
@property (nonatomic, retain) NSDictionary *dMessage;
@property (nonatomic, retain) NSString     *hash;
@property (nonatomic, assign) BOOL         isProducerGenerated;
@end
