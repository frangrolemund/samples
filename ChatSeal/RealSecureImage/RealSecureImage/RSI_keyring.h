//
//  RSI_seal_ring.h
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/18/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSI_securememory.h"

//  - This object represents the key ring for a seal, which
//    includes its three necessary keys.  I'm using the term
//    'ring', not to be confused with 'chain' as a keychain subset
//    for one particular secure interaction.
@class RSISecureMessage;
@interface RSI_keyring : NSObject

+(void) prepareForSealGeneration;
+(void) stopAsyncCompute;
+(RSI_keyring *) allocNewRingUsingScramblerData:(RSI_securememory *) scrData andAttributes:(NSData *) attribs withError:(NSError **) err;
+(BOOL) deleteRingWithSealId:(NSString *) sealId andError:(NSError **) err;
+(BOOL) deleteAllKeyringsWithError:(NSError **) err;
+(NSArray *) availableKeyringsWithError:(NSError **) err;
+(RSI_keyring *) allocExistingWithSealId:(NSString *) sid;
+(NSString *) importFromCollection:(NSDictionary *) srExportedData andSeparateScramblerData:(RSI_securememory *) scrData withError:(NSError **) err;
+(NSString *) sealForCollection:(NSDictionary *) srExportedData;
+(BOOL) ringForSeal:(NSString *) sealId existsWithError:(NSError **) err;

+(NSString *) hashForEncryptedMessage:(NSData *) dMsg withError:(NSError **) err;
+(RSISecureMessage *) identifyEncryptedMessage:(NSData *) dMsg withFullDecryption:(BOOL) fullDecryption andError:(NSError **) err;

-(NSString *) sealId;
-(BOOL) isValid;
-(BOOL) isOwnersKeyring;
-(NSMutableDictionary *) exportForExternal:(BOOL) forExternal withAlternateAttributes:(RSI_securememory *) altAttrib andError:(NSError **) err;
+(NSUInteger) attributeDataLength;
-(RSI_securememory *) attributeDataWithError:(NSError **) err;
-(BOOL) setAttributesWithData:(RSI_securememory *) newAttributes andError:(NSError **) err;
-(BOOL) invalidateSymmetricKeyWithError:(NSError **) err;

-(NSData *) encryptProducerMessage:(NSDictionary *) msg withError:(NSError **) err;
-(NSData *) encryptConsumerMessage:(NSDictionary *) msg withError:(NSError **) err;
-(NSData *) encryptLocalOnlyMessage:(NSDictionary *) msg withError:(NSError **) err;
-(NSData *) encryptRoleBasedMessage:(NSDictionary *) msg withError:(NSError **)err;
-(NSDictionary *) decryptMessage:(NSData *) d isProducerMessage:(BOOL *) isProducerGenerated withError:(NSError **) err;

@end
