//
//  RSI_secure_props.h
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/15/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSI_symcrypt.h"

@interface RSI_secure_props : NSObject
{
    uint16_t propListType;
    uint16_t version;
    
    RSI_symcrypt *key;
}

+(BOOL) buildArchiveWithProperties:(NSObject *) props intoData:(RSI_securememory *) codedData asBinary:(BOOL) asBinary withCRCPRefix:(BOOL) hasPrefix andError:(NSError **) err;
+(BOOL) buildArchiveWithProperties:(NSObject *) props intoData:(RSI_securememory *) codedData withCRCPrefix:(BOOL) hasPrefix andError:(NSError **) err;
+(NSObject *) parseArchiveFromData:(NSData *) d withCRCPrefix:(BOOL) hasPrefix andError:(NSError **) err;

+(NSUInteger) propertyHeaderLength;
+(BOOL) isValidSecureProperties:(NSData *) d forVersion:(uint16_t) v usingKey:(RSI_symcrypt *) key andReturningType:(uint16_t *) propType withError:(NSError **) err;
+(NSArray *) decryptIntoProperties:(NSData *) d forType:(uint16_t) t andVersion:(uint16_t) v usingKey:(RSI_symcrypt *) key withError:(NSError **) err;
+(NSData *) encryptWithProperties:(NSArray *) props forType:(uint16_t) t andVersion:(uint16_t) v usingKey:(RSI_symcrypt *) key withError:(NSError **) err;
+(RSI_securememory *) decryptIntoData:(NSData *) d forType:(uint16_t) t andVersion:(uint16_t) v usingKey:(RSI_symcrypt *) key withError:(NSError **) err;
+(NSData *) encryptWithData:(NSData *) d forType:(uint16_t) t andVersion:(uint16_t) v usingKey:(RSI_symcrypt *) key withError:(NSError **) err;


-(id) initWithType:(uint16_t) t andVersion:(uint16_t) v andKey:(RSI_symcrypt *) k;

-(NSData *) encryptWithData:(NSData *) d withError:(NSError **) err;
-(NSData *) encryptWithProperties:(NSArray *) props withError:(NSError **) err;
-(RSI_securememory *) decryptIntoData:(NSData *) d andError:(NSError **) err;
-(RSI_securememory *) decryptIntoData:(NSData *) d withDeferredTypeChecking:(uint16_t *) propType andError:(NSError **) err;
-(NSArray *) decryptIntoProperties:(NSData *) d withError:(NSError **) err;
-(NSArray *) decryptIntoProperties:(NSData *) d withDeferredTypeChecking:(uint16_t *) propType andError:(NSError **) err;
-(BOOL) isSupportedProps:(NSData *) d andReturningType:(uint16_t *) propType withError:(NSError **) err;

@end
