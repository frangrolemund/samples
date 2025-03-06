//
//  RSI_seal.h
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/28/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "RSI_keyring.h"
#import "RSI_securememory.h"

@class RSISecureMessage;
@interface RSI_seal : NSObject
+(void) prepareForSealGeneration;
+(void) stopAsyncCompute;
+(RSI_seal *) allocNewSealWithImage:(UIImage *) img andColorId:(int) color andError:(NSError **) err;
+(RSI_seal *) allocExistingSealWithId:(NSString *) sealId andError:(NSError **) err;
+(RSI_seal *) allocSealWithArchive:(NSData *) dArchive andError:(NSError **) err;
+(RSI_seal *) allocSealWithCurrentKeysAndArchive:(NSData *) dArchive andError:(NSError **) err;
+(RSI_seal *) importSeal:(NSData *) dExported withPassword:(NSString *) pwd andError:(NSError **) err;
+(BOOL) deleteSealForId:(NSString *) sealId andError:(NSError **) err;
+(BOOL) deleteAllSealsWithError:(NSError **) err;
+(NSArray *) availableSealsWithError:(NSError **) err;
+(BOOL) sealExists:(NSString *) sealId withError:(NSError **) err;
+(NSUInteger) maximumDaysBeforeSelfDestruct;
+(NSUInteger) defaultSelfDestructDays;

+(NSString *) hashForEncryptedMessage:(NSData *) dPacked withError:(NSError **) err;
+(RSISecureMessage *) identifyEncryptedMessage:(NSData *) dPacked withFullDecryption:(BOOL) fullDecryption andError:(NSError **) err;

-(NSString *) sealId;
-(BOOL) isProducerSeal;
-(NSData *) sealImage;
-(BOOL) invalidateSealImageWithError:(NSError **) err;
-(BOOL) isExpiredWithDayPadding:(BOOL) dayPad andError:(NSError **) err;
-(NSDate *) expirationDateWithDayPadding:(BOOL) dayPad andError:(NSError **) err;
-(uint16_t) selfDestructTimeoutWithError:(NSError **) err;
-(BOOL) setSelfDestruct:(uint16_t) selfDestruct withError:(NSError **) err;
-(int) colorIdWithError:(NSError **) err;
-(BOOL) setColorId:(int) color withError:(NSError **) err;
-(BOOL) invalidateExpiredSealWithError:(NSError **) err;
-(BOOL) invalidateSealUnconditionallyWithError:(NSError **) err;
-(BOOL) isInvalidatedWithError:(NSError **) err;
-(BOOL) setInvalidateOnSnapshot:(BOOL) enabled withError:(NSError **) err;
-(BOOL) isInvalidateOnSnapshotEnabledWithError:(NSError **) err;
-(BOOL) invalidateForSnapshotWithError:(NSError **) err;
-(BOOL) setExpirationDateUnconditionally:(NSDate *) dt withError:(NSError **) err;

-(RSI_securememory *) sealArchiveWithError:(NSError **) err;
-(NSData *) exportSealWithPassword:(NSString *) pwd andError:(NSError **) err;

-(NSData *) encryptProducerMessage:(NSDictionary *) msg withError:(NSError **) err;
-(NSData *) encryptConsumerMessage:(NSDictionary *) msg withError:(NSError **) err;
-(NSData *) encryptLocalOnlyMessage:(NSDictionary *) msg withError:(NSError **) err;
-(NSData *) encryptRoleBasedMessage:(NSDictionary *) msg withError:(NSError **)err;
-(NSDictionary *) decryptMessage:(NSData *) d withError:(NSError **) err;
-(void) discardTemporaryImage;

@end
