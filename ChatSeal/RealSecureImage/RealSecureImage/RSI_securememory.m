//
//  RSI_securememory.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 12/7/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import "RSI_securememory.h"

static NSString *RSI_SECMEM_CODER_BUF = @"secmem";

/************************
 RSI_securememory
 ************************/
@implementation RSI_securememory

/*
 *  Create a new object in the autorelease pool.
 */
+(RSI_securememory *) data
{
    return [[[RSI_securememory alloc] init] autorelease];
}

/*
 *  Create a new object of the requested length (buffer is zeroed out) in the autorelease pool.
 */
+(RSI_securememory *) dataWithLength:(NSUInteger) len
{
    return [[[RSI_securememory alloc] initWithLength:len] autorelease];
}

/*
 *  Create a new object using the requested data in the autorelease pool.
 */
+(RSI_securememory *) dataWithData:(NSData *) d
{
    return [[[RSI_securememory alloc] initWithData:d] autorelease];
}

/*
 *  Create a new object using the requested bytes in the autorelease pool.
 */
+(RSI_securememory *) dataWithBytes:(const void *) bytes length:(NSUInteger) length
{
    return [[[RSI_securememory alloc] initWithBytes:bytes length:length] autorelease];
}

/*
 *  Create a new object using the requested data in the autorelease pool.
 */
+(RSI_securememory *) dataWithSecureData:(RSI_securememory *) secData
{
    return [[[RSI_securememory alloc] initWithSecureData:secData] autorelease];
}

/*
 *  Initialize the internal buffer using a data buffer.
 */
-(id) initWithData:(NSData *)data
{
    self = [super init];
    if (self) {
        securityEnabled = YES;
        buffer = [[NSMutableData alloc] initWithData:data];
    }
    return self;
}

/*
 *  Simple initializer
 */
-(id) init
{
    self = [super init];
    if (self) {
        securityEnabled = YES;
        buffer = [[NSMutableData alloc] init];
    }
    return self;
}

/*
 *  Initialize with length
 */
-(id) initWithLength:(NSUInteger) length
{
    self = [super init];
    if (self) {
        securityEnabled = YES;
        buffer = [[NSMutableData alloc] initWithLength:length];
    }
    return self;
}

/*
 *  Initialize the buffer with an existing buffer
 */
-(id) initWithBytes:(const void *) bytes length:(NSUInteger) length
{
    self = [super init];
    if (self) {
        securityEnabled = YES;
        buffer = [[NSMutableData alloc] initWithBytes:bytes length:length];
    }
    return self;
}

/*
 *  Initialize with another secure data object.
 */
-(id) initWithSecureData:(RSI_securememory *) secData
{
    self = [super init];
    if (self) {
        securityEnabled = secData->securityEnabled;
        buffer = [[NSMutableData alloc] initWithData:secData.rawData];
    }
    return self;
}

/*
 *  Initialize this object with a coder stream.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        securityEnabled = YES;
        buffer = [[aDecoder decodeObjectForKey:RSI_SECMEM_CODER_BUF] retain];
    }
    return self;
}

/*
 *  Free the object
 */
-(void) dealloc
{
    //  - make this memory secure by zeroing it out
    //    upon deletion
    if (buffer && securityEnabled) {
        memset([buffer mutableBytes], 0, [buffer length]);
    }
    [buffer release];
    buffer = nil;
    
    
    [super dealloc];
}

/*
 *  Serialize this object to a coder stream.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:buffer forKey:RSI_SECMEM_CODER_BUF];
}

/*
 *  Return a writable handle to the data
 */
-(void *) mutableBytes
{
    if (buffer) {
        return [buffer mutableBytes];
    }
    return NULL;
}

/*
 *  Return a read-only handle to the data
 */
-(const void *) bytes
{
    if (buffer) {
        return [buffer bytes];
    }
    return NULL;
}

/*
 *  Return the length of the data
 */
-(NSUInteger) length
{
    if (buffer) {
        return [buffer length];
    }
    return 0;
}

/*
 *  Set the length of the internal buffer
 */
-(void) setLength:(NSUInteger) length
{
    if (buffer) {
        [buffer setLength:length];
    }
}

/*
 *  Return the internal buffer pointer
 */
-(NSMutableData *) rawData
{
    return [[buffer retain] autorelease];
}

/*
 *  Compare this secure object to another data object.
 */
-(BOOL) isEqualToData:(NSData *) d
{
    return [buffer isEqualToData:d];
}

/*
 *  Compare this secure object to another.
 */
-(BOOL) isEqualToSecureData:(RSI_securememory *) sd
{
    return [buffer isEqualToData:sd->buffer];
}

/*
 *  Compare this object to another.
 */
-(BOOL) isEqual:(id)object
{
    if ([object isKindOfClass:[NSData class]]) {
        return [self isEqualToData:(NSData *) object];
    }
    else if ([object isKindOfClass:[RSI_securememory class]]) {
        return [self isEqualToSecureData:(RSI_securememory *) object];
    }
    return NO;
}

/*
 *  Append bytes onto the object.
 */
-(void) appendBytes:(const void *)bytes length:(NSUInteger)length
{
    [buffer appendBytes:bytes length:length];
}

/*
 *  Append data to the object.
 */
-(void) appendData:(NSData *)otherData
{
    [buffer appendData:otherData];
}

/*
 *  Append another secure memory object.
 */
-(void) appendSecureMemory:(RSI_securememory *) secData
{
    [buffer appendData:secData->buffer];
}

/*
 *  Don't clear this data when it is released.
 */
-(void) disableSecurity
{
    securityEnabled = NO;
}

/*
 *  Move from this internal secure memory object to 
 *  the exported constant secure data object.
 */
-(RSISecureData *) convertToSecureData
{
    RSISecureData *sdRet = nil;
    if (buffer) {
        sdRet = [[RSISecureData alloc] initWithData:buffer];
        [buffer release];
        buffer = nil;
        securityEnabled = NO;
    }
    return [sdRet autorelease];
}

@end

/************************
 RSISecureData
 ************************/
@implementation RSISecureData
/*
 *  Object attributes.
 */
{
    NSMutableData *buffer;
}

/*
 *  Initialize the object.
 */
-(id) initWithData:(NSMutableData *)md
{
    self = [super init];
    if (self) {
        buffer = [md retain];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    if (buffer) {
        memset([buffer mutableBytes], 0, [buffer length]);
    }
    [buffer release];
    buffer = nil;
    
    [super dealloc];
}

/*
 *  Return a read-only handle to the internal data
 */
-(NSData *) rawData
{
    return [[buffer retain] autorelease];
}

@end

