//
//  RSI_scrambler.h
//  RealSecureImage
//
//  Created by Francis Grolemund on 12/11/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSI_securememory.h"

//  - this class is used for data scrambling based on a given key, but
//    should not be confused with real mathematic encryption.  This
//    is more of an obfuscation technique.
@interface RSI_scrambler : NSObject
{
    NSString         *tag;
    RSI_securememory *key;
}

+(NSUInteger) keySize;
+(RSI_scrambler *) allocTransientKeyWithData:(NSData *) dKey andError:(NSError **) err;
+(RSI_scrambler *) allocExistingKeyForTag:(NSString *) tag withError:(NSError **) err;
+(NSArray *) findAllKeyTagsWithError:(NSError **) err;
+(BOOL) deleteKeyWithTag:(NSString *) tag withError:(NSError **) err;
+(BOOL) deleteAllKeysWithError:(NSError **) err;
+(BOOL) importKeyWithLabel:(NSString *) label andTag:(NSString *) tag andValue:(RSI_securememory *) keyData withError:(NSError **) err;
+(BOOL) renameKeyForLabel:(NSString *) oldLabel andTag:(NSString *) oldTag toNewLabel:(NSString *) newLabel andNewTag:(NSString *) newTag withError:(NSError **) err;
+(BOOL) scramble:(NSData *) clearBuf withKey:(RSI_securememory *) key intoBuffer:(NSMutableData *) scrambledBuffer withError:(NSError **) err;
+(BOOL) descramble:(NSData *) scrambledBuffer withKey:(RSI_securememory *) key intoBuffer: (RSI_securememory *) clearBuffer withError:(NSError **) err;
+(NSUInteger *) randomIndicesFrom:(NSUInteger) start toEnd:(NSUInteger) end withShiftLeftBy:(NSUInteger) shiftAmt usingKey:(RSI_securememory *) key;

-(BOOL) scramble:(NSData *) clearBuf intoBuffer:(NSMutableData *) scrambledBuffer withError:(NSError **) err;
-(BOOL) descramble:(NSData *) scrambledBuffer intoBuffer: (RSI_securememory *) clearBuffer withError:(NSError **) err;
-(NSString *) tag;
-(RSI_securememory *) key;
-(NSUInteger *) randomIndicesFrom:(NSUInteger) start toEnd:(NSUInteger) end withShiftLeftBy:(NSUInteger) shiftAmt;

@end
