//
//  RSI_symcrypt.h
//  RealSecureImage
//
//  Created by Francis Grolemund on 12/5/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSI_securememory.h"

//  - this class is used to manage all aspects of symmetric key encryption.
@interface RSI_symcrypt : NSObject
{
    NSUInteger       type;
    NSString         *tag;
    RSI_securememory *key;
}

+(NSUInteger) keySize;
+(RSI_symcrypt *) allocNewKeyForLabel:(NSString *) label andType:(NSUInteger) kt andTag:(NSString *) tag withError:(NSError **) err;
+(RSI_symcrypt *) allocExistingKeyForType:(NSUInteger) kt andTag:(NSString *) tag withError:(NSError **) err;
+(RSI_symcrypt *) allocTransientWithKeyData:(RSI_securememory *) smKey andError:(NSError **) err;
+(RSI_symcrypt *) allocTransientWithPassword:(NSString *) pwd andError:(NSError **) err;
+(RSI_symcrypt *) transientWithKeyData:(RSI_securememory *) smKey andError:(NSError **) err;
+(RSI_symcrypt *) transientKeyWithError:(NSError **) err;
+(NSArray *) findAllKeyTagsForType:(NSUInteger) kt withError:(NSError **) err;
+(BOOL) deleteKeyWithType:(NSUInteger) kt andTag:(NSString *) tag withError:(NSError **) err;
+(BOOL) deleteAllKeysWithType:(NSUInteger) kt withError:(NSError **) err;
+(BOOL) importKeyWithLabel:(NSString *) label andType:(NSUInteger) kt andTag:(NSString *) tag andValue:(RSI_securememory *) keyData withError:(NSError **) err;
+(BOOL) renameKeyForLabel:(NSString *) oldLabel andType:(NSUInteger) kt andTag:(NSString *) oldTag toNewLabel:(NSString *) newLabel andNewTag:(NSString *) newTag withError:(NSError **) err;
+(BOOL) encrypt:(NSData *) clearBuf withKey:(RSI_securememory *) key intoBuffer:(NSMutableData *) encryptedBuffer withError:(NSError **) err;
+(BOOL) decrypt:(NSData *) encryptedBuf withKey:(RSI_securememory *) key intoBuffer: (RSI_securememory *) clearBuffer withError:(NSError **) err;
+(RSI_securememory *) hashFromPassword:(NSString *) pwd;
+(RSI_securememory *) symKeyFromHash:(RSI_securememory *) h;
+(RSI_securememory *) symKeyFromPassword:(NSString *) pwd;
+(NSUInteger) blockSize;

-(BOOL) encrypt:(NSData *) clearBuf intoBuffer:(NSMutableData *) encryptedBuffer withError:(NSError **) err;
-(BOOL) decrypt:(NSData *) encryptedBuf intoBuffer: (RSI_securememory *) clearBuffer withError:(NSError **) err;
-(NSString *) tag;
-(RSI_securememory *) key;
-(BOOL) updateKeyWithData:(RSI_securememory *) newKeyData andError:(NSError **) err;

@end
