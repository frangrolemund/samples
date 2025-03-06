//
//  RSI_common.h
//  RealSecureImage
//
//  Created by Francis Grolemund on 11/19/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import "RSI_securememory.h"
#import "RSI_error.h"

//  - symmetric algorithm types
enum {
	CSSM_ALGID_NONE =					0x00000000L,
	CSSM_ALGID_VENDOR_DEFINED =			CSSM_ALGID_NONE + 0x80000000L,
	CSSM_ALGID_AES,
    CSSM_ALGID_SYM_GLOBAL,                                                  //  the global symmetric key for on-disk encryption
    CSSM_ALGID_SYM_SEAL,                                                    //  seal symmetric keys
    CSSM_ALGID_SYM_RESP,                                                    //  per-response symmetric keys
    CSSM_ALGID_SCRAMBLE,                                                    //  scrambler keys
    CSSM_ALGID_SYM_TRANSIENT,                                               //  transient keys
    CSSM_ALGID_SYM_ATTRIBUTES,                                              //  seal attributes stored in key data
    CSSM_ALGID_SALT,                                                        //  application-global salt for unencrypted persistence
    CSSM_ALGID_VAULT_VERIFY,                                                //  verification key for vault behavior.
};

//  - the version for all secure properties
#define RSI_SECURE_VERSION 1

//  - type codes for each secure property file.
//  - INCREMENT THE VERSION if you add new type codes.
enum {
    RSI_SECPROP_NONE      = 0,
    RSI_SECPROP_SEAL      = 1,
    RSI_SECPROP_MSG_PROD  = 2,
    RSI_SECPROP_MSG_CONS  = 3,
    RSI_SECPROP_MSG_LOCAL = 4,
    RSI_SECPROP_APP       = 5,          //  - appliation-specific properties created by the owner of the library
};

//  - just some utilities
@interface RSI_common : NSObject
+(void) appendLong:(uint32_t) val toData:(NSMutableData *) md;
+(uint32_t) longFromPtr:(const unsigned char *) ptr;

+(void) printBytes:(NSData *) d withTitle:(NSString *) title;
+(void) printBytes:(NSData *) d withMaxLength:(NSUInteger) length andTitle:(NSString *) title;
+(BOOL) diffBytes:(NSData *) d1 withBytes:(NSData *) d2 andTitle:(NSString *) title;

+(void) RDLOCK_KEYCHAIN;
+(void) WRLOCK_KEYCHAIN;
+(void) UNLOCK_KEYCHAIN;

+(NSString *) hexFromData:(NSData *) d;
+(NSString *) base64FromData:(NSData *) d;
@end

// - all SHA types need to observe this protocol.
@protocol RSI_SHA <NSObject>
-(void) updateWithData:(NSData *) d;
-(void) update:(const void *) ptr withLength:(NSUInteger) length;
-(RSI_securememory *) hash;
-(NSString *) stringHash;
-(NSString *) base64StringHash;
-(void) reset;

+(RSI_securememory *) hashFromInput:(NSData *) input;
+(NSUInteger) SHA_LEN;
+(NSUInteger) SHA_B64_STRING_LEN;
+(SecPadding) SEC_PADDING;
@end

// - standard SHA-1
@interface RSI_SHA1 : NSObject <RSI_SHA>
@end

// - standard SHA-256
@interface RSI_SHA256 : NSObject <RSI_SHA>
@end

//  - whenever you want the best SHA variant offered, use this one.
@interface RSI_SHA_SECURE : RSI_SHA256
@end

//  - the scrambler key drives what is required from the image hash because the image provides the scrambler key.
@interface RSI_SHA_SCRAMBLE : RSI_SHA_SECURE
@end

//  - the seal hash for the id needs to remain constant
@interface RSI_SHA_SEAL : RSI_SHA256
@end
