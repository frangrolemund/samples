//
//  CS_sha.h
//  ChatSeal
//
//  Created by Francis Grolemund on 9/11/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

extern const NSUInteger CS_SHA_HASH_LEN;

@interface CS_sha : NSObject
//  NOTE:  This is an insecure hash and is only for doing local computation!
+(CS_sha *) shaHash;

-(void) updateWithData:(NSData *) d;
-(void) updateWithString:(NSString *) s;
-(void) updateWithBuffer:(const void *) buf ofLength:(NSUInteger) len;

-(NSData *) hashResult;
-(void) saveResultIntoBuffer:(uint8_t *) buf ofLength:(NSUInteger) len;
-(NSString *) hashAsHex;
@end
