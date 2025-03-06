//
//  RSI_secureseal.h
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/31/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RealSecureImage.h"
#import "RSI_appkey.h"

@interface RSISecureSeal (internal)

+(NSString *) createSealInVault:(NSURL *) url withAppKey:(RSI_appkey *) appkey andImage:(UIImage *) img andColor:(RSISecureSeal_Color_t) color andError:(NSError **) err;
+(RSISecureSeal *) sealInVault:(NSURL *) url forId:(NSString *) sealId withAppKey:(RSI_appkey *) appkey andError:(NSError **) err;
+(RSISecureSeal *) importSealIntoVault:(NSURL *) url withAppKey:(RSI_appkey *) appkey andSealData:(NSData *) sealData usingPassword:(NSString *) pwd withError:(NSError **) err;
-(BOOL) synchronizeArchiveAndModifySealImage:(BOOL) modifyImage withError:(NSError **) err;
+(BOOL) deleteSealInVault:(NSURL *) url forId:(NSString *) sealId withAppKey:(RSI_appkey *) appkey andError:(NSError **) err;
-(BOOL) isDeleted;
@end
