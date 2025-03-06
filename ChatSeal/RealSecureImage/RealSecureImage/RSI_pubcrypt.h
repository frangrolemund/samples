//
//  RSI_pubcrypt.h
//  RealSecureImage
//
//  Created by Francis Grolemund on 12/5/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import "RSI_securememory.h"

//  - this class is used to manage all aspects of public key encryption.
@interface RSI_pubcrypt : NSObject
+(NSUInteger) keySize;

+(RSI_pubcrypt *) allocNewKeyForPublicLabel:(NSString *) publ andPrivateLabel:(NSString *) prvl andTag:(NSString *) tag withError:(NSError **) err;
+(RSI_pubcrypt *) allocExistingKeyForTag:(NSString *) tag withError:(NSError **) err;
+(NSArray *) findAllKeyTagsForPublic:(BOOL) pubKeys withError:(NSError **) err;
+(BOOL) deleteKeyAsPublic:(BOOL) pubKey andTag:(NSString *) tag withError:(NSError **) err;
+(BOOL) deleteKeyWithTag:(NSString *) tag withError:(NSError **) err;
+(BOOL) deleteAllKeysAsPublic:(BOOL) pubKey withError:(NSError **) err;
+(BOOL) importPublicKeyWithLabel:(NSString *) label andTag:(NSString *) tag andValue:(NSData *) keyData withError:(NSError **) err;
+(BOOL) renamePublicKeyForLabel:(NSString *) oldLabel andTag:(NSString *) oldTag toNewLabel:(NSString *) newLabel andNewTag:(NSString *) newTag withError:(NSError **) err;
+(BOOL) importPrivateKeyWithLabel:(NSString *) label andTag:(NSString *) tag andValue:(RSI_securememory *) keyData withError:(NSError **) err;
+(BOOL) renamePrivateKeyWithLabel:(NSString *) oldLabel andTag:(NSString *) oldTag toNewLabel:(NSString *) newLabel andNewTag:(NSString *) newTag withError:(NSError **) err;
-(BOOL) isFullKey;
-(NSUInteger) blockLen;
-(NSUInteger) padLen;
-(BOOL) encrypt:(NSData *) clearBuf intoBuffer:(NSMutableData *) encryptedBuffer withError:(NSError **) err;
-(BOOL) decrypt:(NSData *) encryptedBuf intoBuffer: (RSI_securememory *) clearBuffer withError:(NSError **) err;
-(NSData *) publicKey;
-(RSI_securememory *) privateKey;
-(BOOL) sign:(NSData *) dataBuffer intoBuffer:(NSMutableData *) signature withError:(NSError **) err;
-(BOOL) verify:(NSData *) dataBuffer withBuffer:(NSData *) signature withError:(NSError **) err;

@end
