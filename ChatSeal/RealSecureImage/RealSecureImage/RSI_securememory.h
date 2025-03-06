//
//  RSI_securememory.h
//  RealSecureImage
//
//  Created by Francis Grolemund on 12/7/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RealSecureImage.h"

@interface RSI_securememory : NSObject <NSCoding>
{
    NSMutableData *buffer;
    BOOL           securityEnabled;
}

+(RSI_securememory *) data;
+(RSI_securememory *) dataWithLength:(NSUInteger) len;
+(RSI_securememory *) dataWithData:(NSData *) d;
+(RSI_securememory *) dataWithSecureData:(RSI_securememory *) secData;
+(RSI_securememory *) dataWithBytes:(const void *) bytes length:(NSUInteger) length;

-(id) init;
-(id) initWithData:(NSData *)data;
-(id) initWithSecureData:(RSI_securememory *) secData;
-(id) initWithLength:(NSUInteger) length;
-(id) initWithBytes:(const void *) bytes length:(NSUInteger) length;

-(void *) mutableBytes;
-(const void *) bytes;
-(NSUInteger) length;
-(void) setLength:(NSUInteger) length;
-(NSMutableData *) rawData;
-(BOOL) isEqualToData:(NSData *) d;
-(BOOL) isEqualToSecureData:(RSI_securememory *) sd;
-(void) appendBytes:(const void *)bytes length:(NSUInteger)length;
-(void) appendData:(NSData *)otherData;
-(void) appendSecureMemory:(RSI_securememory *) secData;
-(void) disableSecurity;
-(RSISecureData *) convertToSecureData;

@end
