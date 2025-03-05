//
//  CS_sha.m
//  ChatSeal
//
//  Created by Francis Grolemund on 9/11/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_sha.h"
#include <CommonCrypto/CommonDigest.h>

// - constants
const NSUInteger CS_SHA_HASH_LEN = CC_SHA1_DIGEST_LENGTH;

/**********************
 CS_sha
 **********************/
@implementation CS_sha
/*
 *  Object attributes.
 */
{
    // - this isn't intended to be cryptographically secure, just a nice way to hash for non-essential things.
    CC_SHA1_CTX ctx;
}

/*
 *  Return a new object.
 */
+(CS_sha *) shaHash
{
    return [[[CS_sha alloc] init] autorelease];
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        CC_SHA1_Init(&ctx);
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [super dealloc];
}

/*
 *  Update the hash.
 */
-(void) updateWithData:(NSData *) d
{
    return [self updateWithBuffer:d.bytes ofLength:d.length];
}

/*
 *  Update the hash.
 */
-(void) updateWithString:(NSString *) s
{
    [self updateWithBuffer:[s UTF8String] ofLength:[s length]];
}

/*
 *  Update the hash with new content.
 */
-(void) updateWithBuffer:(const void *) buf ofLength:(NSUInteger) len
{
    if (buf && len) {
        CC_SHA1_Update(&ctx, buf, (CC_LONG) len);
    }
    else {
        NSLog(@"CS-ALERT: Updating SHA hash with empty value.");
    }
}

/*
 *  Return the resulting hash value.
 */
-(NSData *) hashResult
{
    uint8_t buf[CC_SHA1_DIGEST_LENGTH];    
    [self saveResultIntoBuffer:buf ofLength:CC_SHA1_DIGEST_LENGTH];
    return [NSData dataWithBytes:buf length:CC_SHA1_DIGEST_LENGTH];
}

/*
 *  Finalize the hash and store it into the buffer, which is 
 */
-(void) saveResultIntoBuffer:(uint8_t *) buf ofLength:(NSUInteger) len
{
    if (len != CS_SHA_HASH_LEN) {
        return;
    }
    bzero(buf, len);
    CC_SHA1_Final(buf, &ctx);
}

/*
 *  Return the hash formatted as hex.
 */
-(NSString *) hashAsHex
{
    NSData *dResult = [self hashResult];
    NSString *sTmp = @"";
    for (int i = 0; i < [dResult length]; i++) {
        unsigned char b = ((unsigned char *) dResult.bytes)[i];
        sTmp = [sTmp stringByAppendingFormat:@"%02X", b];
    }
    return sTmp;
}

@end
