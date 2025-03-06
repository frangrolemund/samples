//
//  RSI_vault.h
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/31/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RealSecureImage.h"

@interface RSI_vault : NSObject
+(NSString *) safeSaltedStringAsHex:(NSString *) source withError:(NSError **) err;
+(NSString *) safeSaltedStringAsBase64:(NSString *) source withError:(NSError **) err;
+(NSUInteger) lengthOfSafeSaltedStringAsHex:(BOOL) asHex;
+(BOOL) hasVault;
+(BOOL) isOpen;
+(BOOL) destroyVaultWithError:(NSError **) err;
+(BOOL) initializeVaultWithPassword:(NSString *) pwd andError:(NSError **) err;
+(BOOL) openVaultWithPassword:(NSString *) pwd andError:(NSError **) err;
+(BOOL) changeVaultPassword:(NSString *) pwdFrom toPassword:(NSString *) pwdTo andError:(NSError **) err;
+(BOOL) writeData:(NSData *) sourceData toURL:(NSURL *) url withError:(NSError **) err;
+(BOOL) writeData:(NSData *) sourceData toFile:(NSString *) fName withError:(NSError **) err;
+(BOOL) readURL:(NSURL *) url intoData:(RSISecureData **) destData withError:(NSError **) err;
+(BOOL) readFile:(NSString *) fName intoData:(RSISecureData **) destData withError:(NSError **) err;
+(NSURL *) absoluteURLForFile:(NSString *) fName withError:(NSError **) err;
+(void) closeVault;
+(void) prepareForSealGeneration;

+(NSString *) createSealWithImage:(UIImage *) img andColor:(RSISecureSeal_Color_t) color andError:(NSError **) err;
+(NSArray *) availableSealsWithError:(NSError **) err;
+(NSDictionary *) safeSealIndexWithError:(NSError **) err;
+(RSISecureSeal *) sealForId:(NSString *) sealId andError:(NSError **) err;
+(BOOL) sealExists:(NSString *) sealId withError:(NSError **) err;
+(RSISecureSeal *) importSeal:(NSData *) sealData usingPassword:(NSString *) pwd withError:(NSError **) err;
+(BOOL) deleteSeal:(NSString *) sealId withError:(NSError **) err;

@end
