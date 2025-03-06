//
//  RSI_2a_secure_prop_tests.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/15/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "RSI_2a_secure_prop_tests.h"
#import "RSI_secure_props.h"
#import "RSI_common.h"

static NSString *RSI_2a_LOREM = @"Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";
static const uint16_t RSI_2a_TYPE = 95;
static const uint16_t RSI_2a_VER  = 3;
static const char *known_buffer = "RealProven";

static const NSUInteger CSSM_RSI_2a = CSSM_ALGID_VENDOR_DEFINED + 125;

@implementation RSI_2a_secure_prop_tests

/*
 *  Simple cleanup between tests.
 */
-(void) setUp
{
    [super setUp];    
    err = nil;
    self.continueAfterFailure = NO; 
}

/*
 *  Create a key for testing.
 */
-(RSI_securememory *) buildSecureKey
{
    RSI_securememory *smKey = [RSI_securememory dataWithLength:[RSI_symcrypt keySize]];
    int ret = SecRandomCopyBytes(kSecRandomDefault, [RSI_symcrypt keySize], smKey.mutableBytes);
    XCTAssertEqual(ret, 0, @"Failed to initialize the sample key.");
    return smKey;
}

/*
 *  Verify that header processing is functional.
 */
-(void) testUTSECPROCS_1_Header
{
    NSLog(@"UT-SECPROPS: - verifying behavior of %u byte secure property headers.", [RSI_secure_props propertyHeaderLength]);
    
    RSI_securememory *smKey = [self buildSecureKey];
    
    RSI_secure_props *sp = [[[RSI_secure_props alloc] initWithType:88 andVersion:25 andKey:nil] autorelease];
    
    NSLog(@"UT-SECPROPS: - checking that an empty buffer can be validated.");
    RSI_symcrypt *key = [RSI_symcrypt transientWithKeyData:smKey andError:&err];
    sp = [[[RSI_secure_props alloc] initWithType:88 andVersion:25 andKey:key] autorelease];
    NSData *dEmptyProps = [sp encryptWithProperties:[NSArray array] withError:&err];
    XCTAssertNotNil(dEmptyProps, @"Failed to build a secure properties buffer.  %@", [err localizedDescription]);
    
    uint16_t propType = 0;
    BOOL valid = [RSI_secure_props isValidSecureProperties:dEmptyProps forVersion:25 usingKey:key andReturningType:&propType withError:nil];
    XCTAssertTrue(valid, @"Failed to validate the empty buffer's header with a known good key.");
    XCTAssertEqual(propType, (uint16_t) 88, @"The returned property type is invalid.");
    
    NSLog(@"UT-SECPROPS: - checking that the wrong key will not validate the buffer.");
    RSI_securememory *smKeyBad = [self buildSecureKey];
    RSI_symcrypt *keyBad = [RSI_symcrypt transientWithKeyData:smKeyBad andError:&err];
    valid = [RSI_secure_props isValidSecureProperties:dEmptyProps forVersion:25 usingKey:keyBad andReturningType:nil withError:nil];
    XCTAssertFalse(valid, @"Validated a buffer incorrectly with a bad key.");
    
    NSLog(@"UT-SECPROPS: - trying the right key again.");
    valid = [RSI_secure_props isValidSecureProperties:dEmptyProps forVersion:25 usingKey:key andReturningType:nil withError:nil];
    XCTAssertTrue(valid, @"Failed to validate the empty buffer's header with a known good key.");

    NSLog(@"UT-SECPROPS: - checking that a copied header succeeds.");
    NSMutableData *mdEmptyCopy = [NSMutableData dataWithData:dEmptyProps];
    valid = [RSI_secure_props isValidSecureProperties:mdEmptyCopy forVersion:25 usingKey:key andReturningType:&propType withError:nil];
    XCTAssertTrue(valid, @"Failed to validate the copied buffer's header with a known good key.");
    XCTAssertEqual(propType, (uint16_t) 88, @"The returned property type is invalid.");
    
    NSLog(@"UT-SECPROPS: - checking that a corrupted header fails.");
    ((unsigned char *) [mdEmptyCopy mutableBytes])[3] ^= 0xCE;
    valid = [RSI_secure_props isValidSecureProperties:mdEmptyCopy forVersion:25 usingKey:key andReturningType:nil withError:nil];
    XCTAssertFalse(valid, @"Failed to detect the corrupted header.");
    
    NSLog(@"UT-SECPROPS: - all header tests passed successfully.");
}

/*
 *  Build an array that can be used for secure property list verification.
 */
-(NSArray *) buildPayload
{
    NSMutableArray *maRet = [NSMutableArray array];
    
    @autoreleasepool {
        // - test the simple types
        [maRet addObject:[NSNumber numberWithInt:25]];
        [maRet addObject:[NSNumber numberWithFloat:M_PI]];
        [maRet addObject:[NSNumber numberWithUnsignedLongLong:0xFFEEFFAA0011]];
        [maRet addObject:RSI_2a_LOREM];
        [maRet addObject:[NSDate date]];

        //  - test the container types
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setObject:[NSNumber numberWithShort:1] forKey:@"kshort"];
        [dict setObject:[NSNumber numberWithChar:'a'] forKey:@"kchar"];
        [dict setObject:@"Foobar" forKey:@"kstring"];
        
        NSMutableArray *maSub = [NSMutableArray array];
        [maSub addObject:RSI_2a_LOREM];
        [maSub addObject:[NSDate date]];
        [maSub addObject:[NSData dataWithBytes:known_buffer length:strlen(known_buffer) + 1]];
        [dict setObject:maSub forKey:@"karr"];
        
        [maRet addObject:dict];
    
        //  - test the custom types
        RSI_securememory *sm = [RSI_securememory dataWithLength:256*1024];
        int ret = SecRandomCopyBytes(kSecRandomDefault, [sm length], sm.mutableBytes);
        XCTAssertEqual(ret, 0, @"Failed to generate random data for the secure memory type.");
        [maRet addObject:sm];
    }
    return maRet;
}

/*
 *  Verify that a secure property payload can be stored and recovered.  
 */
-(void) testUTSECPROCS_2_Payload
{
    NSLog(@"UT-SECPROPS: - verifying that a secure payload can be saved/restored.");
    
    NSLog(@"UT-SECPROPS: - building a test payload.");
    NSArray *arrPayload = [self buildPayload];
    XCTAssertNotNil(arrPayload, @"Failed to build a payload for testing archival.");

    NSLog(@"UT-SECPROPS: - generating an encryption key");
    [RSI_symcrypt deleteAllKeysWithType:CSSM_RSI_2a withError:nil];
    RSI_symcrypt *key = [RSI_symcrypt allocNewKeyForLabel:@"test" andType:CSSM_RSI_2a andTag:@"test" withError:&err];
    [key autorelease];
    XCTAssertNotNil(key, @"Failed to build a secure encryption key.");
    
    NSLog(@"UT-SECPROPS: - archiving the data");
    RSI_secure_props *sp = [[[RSI_secure_props alloc] initWithType:RSI_2a_TYPE andVersion:RSI_2a_VER andKey:key] autorelease];
    
    NSData *dEncrypted = [sp encryptWithProperties:arrPayload withError:&err];
    XCTAssertNotNil(dEncrypted, @"Failed to archive the property list.  %@", [err localizedDescription]);
    
    NSLog(@"UT-SECPROPS: - verifying that a known string isn't found with a simple search");
    NSRange r = [dEncrypted rangeOfData:[NSData dataWithBytes:known_buffer length:strlen(known_buffer) + 1] options:0 range:NSMakeRange(0, [dEncrypted length])];
    XCTAssertTrue(r.location == NSNotFound, @"Found the known buffer and should not have.");
    
    NSLog(@"UT-SECPROPS: - verifying that the payload is supported with the given key");
    BOOL isSupported = [sp isSupportedProps:dEncrypted andReturningType:nil withError:nil];
    XCTAssertTrue(isSupported, @"The payload is invalid.");
    
    NSLog(@"UT-SECPROPS: - generating an alternate key for comparison.");
    RSI_symcrypt *keyBad = [RSI_symcrypt allocNewKeyForLabel:@"testbad" andType:CSSM_RSI_2a andTag:@"testbad" withError:&err];
    [keyBad autorelease];
    XCTAssertNotNil(key, @"Failed to build a secure encryption key.");
    
    NSLog(@"UT-SECPROPS: - verifying that the payload is not supported with the bad key");
    isSupported = [RSI_secure_props isValidSecureProperties:dEncrypted forVersion:RSI_2a_VER usingKey:keyBad andReturningType:nil withError:nil];
    XCTAssertFalse(isSupported, @"The payload was supported but should not have been.");
    
    NSLog(@"UT-SECPROPS: - testing the other supported interface with the good key");
    uint16_t propType = 0;
    isSupported = [RSI_secure_props isValidSecureProperties:dEncrypted forVersion:RSI_2a_VER usingKey:key andReturningType:&propType withError:nil];
    XCTAssertTrue(isSupported, @"The payload was not supported and should have been.");
    XCTAssertEqual(propType, RSI_2a_TYPE, @"The property type validation failed.");
    
    NSLog(@"UT-SECPROPS: - loading the properties from the encrypted file");
    NSArray *propsLoaded = [sp decryptIntoProperties:dEncrypted withError:&err];
    XCTAssertNotNil(propsLoaded, @"Failed to decode the properties.  %@", [err localizedDescription]);
    
    NSLog(@"UT-SECPROPS: - comparing the reloaded contents to the original");
    BOOL ret = [propsLoaded isEqualToArray:arrPayload];
    XCTAssertTrue(ret, @"The reloaded array is different.");
    
    NSLog(@"UT-SECPROPS: - verifying the bad key won't work for loading the properties");
    propsLoaded = [RSI_secure_props decryptIntoProperties:dEncrypted forType:RSI_2a_TYPE andVersion:RSI_2a_VER usingKey:keyBad withError:&err];
    XCTAssertNil(propsLoaded, @"The bad key loaded the properties and should not have.");
    XCTAssertEqual(err.code, RSIErrorInvalidSecureProps, @"Failed to receive the expected error code.");
    
    NSLog(@"UT-SECPROPS: - verify that bad type and version for a given list are identified");
    propsLoaded = [RSI_secure_props decryptIntoProperties:dEncrypted forType:RSI_2a_TYPE + 5 andVersion:RSI_2a_VER usingKey:key withError:&err];
    XCTAssertNil(propsLoaded, @"The bad type loaded the properties and should not have.");
    XCTAssertEqual(err.code, RSIErrorSecurePropsVersionMismatch, @"Failed to get the version mismatch error.");

    propsLoaded = [RSI_secure_props decryptIntoProperties:dEncrypted forType:RSI_2a_TYPE andVersion:0 usingKey:key withError:&err];
    XCTAssertNil(propsLoaded, @"The bad type loaded the properties and should not have.");
    XCTAssertEqual(err.code, RSIErrorSecurePropsVersionMismatch, @"Failed to get the version mismatch error.");
    
    NSLog(@"UT-SECPROPS: - verifying the quick pass approach works");
    propsLoaded = [RSI_secure_props decryptIntoProperties:dEncrypted forType:RSI_2a_TYPE andVersion:RSI_2a_VER usingKey:key withError:&err];
    XCTAssertNotNil(propsLoaded, @"Failed to load the properties as expected.");
    ret = [propsLoaded isEqualToArray:arrPayload];
    XCTAssertTrue(ret, @"The reloaded array is different.");
    
    NSLog(@"UT-SECPROPS: - verifying that payload additions are ignored");
    NSMutableData *mdAddedPayload = [NSMutableData dataWithLength:[dEncrypted length] + 191];
    SecRandomCopyBytes(kSecRandomDefault, [mdAddedPayload length], mdAddedPayload.mutableBytes);
    memcpy((unsigned char *) mdAddedPayload.mutableBytes, (unsigned char *) dEncrypted.bytes, [dEncrypted length]);
    propsLoaded = [RSI_secure_props decryptIntoProperties:mdAddedPayload forType:RSI_2a_TYPE andVersion:RSI_2a_VER usingKey:key withError:&err];
    XCTAssertNotNil(propsLoaded, @"Failed to load the properties as expected.");
    ret = [propsLoaded isEqualToArray:arrPayload];
    XCTAssertTrue(ret, @"The reloaded array is different.");
    
    NSLog(@"UT-SECPROPS: - verifying that payload truncation is detected right after header.");
    NSData *dTrunc = [NSData dataWithBytesNoCopy:(void *) dEncrypted.bytes length:[RSI_secure_props propertyHeaderLength] freeWhenDone:NO];
    propsLoaded = [sp decryptIntoProperties:dTrunc withError:&err];
    XCTAssertNil(propsLoaded, @"The truncated properties were loaded, but should not have been.");
    XCTAssertEqual(err.code, RSIErrorInvalidSecureProps, @"Failed to receive the expected error code.");

    NSLog(@"UT-SECPROPS: - verifying that payload truncation is detected in an odd place");
    dTrunc = [NSData dataWithBytesNoCopy:(void *) dEncrypted.bytes length:[RSI_secure_props propertyHeaderLength] + 122 freeWhenDone:NO];
    propsLoaded = [sp decryptIntoProperties:dTrunc withError:&err];
    XCTAssertNil(propsLoaded, @"The truncated properties were loaded, but should not have been.");
    XCTAssertEqual(err.code, RSIErrorInvalidSecureProps, @"Failed to receive the expected error code.");
    
    NSLog(@"UT-SECPROPS: - testing quick property decryption");
    NSArray *arrQuick = [NSArray arrayWithObjects:[NSNumber numberWithBool:NO], [NSDate date], @"Quickly.", nil];
    dEncrypted = [RSI_secure_props encryptWithProperties:arrQuick forType:1 andVersion:1 usingKey:keyBad withError:&err];
    XCTAssertNotNil(dEncrypted, @"Failed to encrypt the quick properties.");
    
    propsLoaded = [RSI_secure_props decryptIntoProperties:dEncrypted forType:2 andVersion:1 usingKey:keyBad withError:&err];
    XCTAssertNil(propsLoaded, @"Failed to detect type change while decrypting data.");
    
    isSupported = [RSI_secure_props isValidSecureProperties:dEncrypted forVersion:1 usingKey:keyBad andReturningType:nil withError:&err];
    XCTAssertTrue(isSupported, @"The is valid check failed.");

    propsLoaded = [RSI_secure_props decryptIntoProperties:dEncrypted forType:1 andVersion:0 usingKey:keyBad withError:&err];
    XCTAssertNil(propsLoaded, @"Failed to detect invalid version while decrypting data.");

    propsLoaded = [RSI_secure_props decryptIntoProperties:dEncrypted forType:1 andVersion:2 usingKey:keyBad withError:&err];
    XCTAssertNotNil(propsLoaded, @"Failed to reload the quick array.");
    
    ret = [propsLoaded isEqualToArray:arrQuick];
    XCTAssertTrue(ret, @"The reloaded array was different than the original.");
    
    NSLog(@"UT-SECPROPS: - testing deferred type checking"); 
    RSI_secure_props *spDefer = [[[RSI_secure_props alloc] initWithType:19 andVersion:1 andKey:keyBad] autorelease];
    uint16_t deferredType = 0;
    propsLoaded = [spDefer decryptIntoProperties:dEncrypted withDeferredTypeChecking:nil andError:&err];
    XCTAssertNil(propsLoaded, @"The type wasn't checked on the object and it should have been.");
    
    propsLoaded = [spDefer decryptIntoProperties:dEncrypted withDeferredTypeChecking:&deferredType andError:&err];
    XCTAssertNotNil(propsLoaded, @"Failed to load the properties with deferred type checking.");
    XCTAssertEqual(deferredType, (uint16_t) 1, @"The type doens't match the original");
    
    ret = [propsLoaded isEqualToArray:arrQuick];
    XCTAssertTrue(ret, @"The reloaded array was different than the original.");
    
    NSLog(@"UT-SECPROPS: - verifying no encryption works as expected");
    NSData *dNotEncrypted = [RSI_secure_props encryptWithProperties:arrPayload forType:RSI_2a_TYPE andVersion:RSI_2a_VER usingKey:nil withError:&err];
    XCTAssertNotNil(dNotEncrypted, @"Failed to encode the array with no encryption.");
    
    NSLog(@"UT-SECPROPS: - verifying we can recover the array from an unencrypted buffer");
    propsLoaded = [RSI_secure_props decryptIntoProperties:dNotEncrypted forType:RSI_2a_TYPE andVersion:RSI_2a_VER usingKey:nil withError:&err];
    XCTAssertNotNil(propsLoaded, @"Failed to decode the unencrypted properties.");
    
    NSLog(@"UT-SECPROPS: - comparing the buffers");
    ret = [propsLoaded isEqualToArray:arrPayload];
    XCTAssertTrue(ret, @"The unencrypted, decoded buffer is not the same as the original.");
    
    NSLog(@"UT-SECPROPS: - all payload tests passed successfully.");
}

/*
 *  Verify that secure properties that are manually created work with the CRC prefix.
 */
-(void) testUTSECPROCS_3_Prefixed
{
    NSLog(@"UT-SECPROPS: - verifying that a payload can incorporate a simple CRC prefix.");
    
    NSLog(@"UT-SECPROPS: - building a test payload.");
    NSArray *arrPayload = [self buildPayload];
    XCTAssertNotNil(arrPayload, @"Failed to build a payload for testing archival.");
    
    NSLog(@"UT-SECPROPS: - creating the data without a CRC prefix.");
    RSI_securememory *secMem = [RSI_securememory data];
    BOOL ret = [RSI_secure_props buildArchiveWithProperties:arrPayload intoData:secMem withCRCPrefix:NO andError:&err];
    XCTAssertTrue(ret, @"Failed to build the archive.");
    
    NSLog(@"UT-SECPROPS: - verifying the CRC check works.");
    NSObject *obj = [RSI_secure_props parseArchiveFromData:secMem.rawData withCRCPrefix:YES andError:&err];
    XCTAssertNil(obj, @"Failed to detect the CRC error.");
    
    NSLog(@"UT-SECPROPS: - creating the data with a CRC prefix.");
    ret = [RSI_secure_props buildArchiveWithProperties:arrPayload intoData:secMem withCRCPrefix:YES andError:&err];
    XCTAssertTrue(ret, @"Failed to build the archive.");
    
    NSLog(@"UT-SECPROPS: - verifying the object can be read");
    obj = [RSI_secure_props parseArchiveFromData:secMem.rawData withCRCPrefix:YES andError:&err];
    XCTAssertNotNil(obj, @"Failed to decode the object.  %@", [err localizedDescription]);
    
    NSLog(@"UT-SECPROPS: - compraring the decoded payload to the orignal.");
    ret = [obj isKindOfClass:[NSArray class]] && [(NSArray *) obj isEqualToArray:arrPayload];
    XCTAssertTrue(ret, @"The decoded content is not equal.");
    
    static const NSUInteger UTSECPROCS_ITER = 1000;
    NSLog(@"UT-SECPROPS: - testing %u iterations of invalid content to ensure that it is detected.", UTSECPROCS_ITER);
    NSMutableData *mdLast = nil;
    for (NSUInteger i = 0; i < UTSECPROCS_ITER; i++) {
        NSMutableData *mdTest = [NSMutableData dataWithLength:4096];
        SecRandomCopyBytes(kSecRandomDefault, [mdTest length], mdTest.mutableBytes);
        if (mdLast) {
            ret = [mdTest isEqualToData:mdLast];
            XCTAssertFalse(ret, @"The test data is the same as the last iteration.");
        }
        
        obj = [RSI_secure_props parseArchiveFromData:mdTest withCRCPrefix:YES andError:&err];
        XCTAssertNil(obj, @"Failed to detect the bad data.");
        XCTAssertTrue(err.code == RSIErrorInvalidSecureProps, @"Failed to get the expected secure property failure code.");
        
        mdLast = mdTest;
    }

    NSLog(@"UT-SECPROPS: - all prefix tests passed successfully.");
}

/*
 *  Evaluate the performance of the secure properties.
 */
-(void) testUTSECPROCS_4_Perform
{
    NSLog(@"UT-SECPROPS: - beginning performance testing.");

    static const NSUInteger NUM_PERF_ITEMS = 1000000;
    NSLog(@"UT-SECPROPS: - building the two payloads.");
    NSMutableArray *maPerfArray  = [NSMutableArray array];
    NSMutableData  *mdPerfBuffer = [NSMutableData dataWithLength:NUM_PERF_ITEMS * sizeof(int)];
    int *pBuf                    = (int *) mdPerfBuffer.mutableBytes;
    for (NSUInteger i = 0; i < NUM_PERF_ITEMS; i++) {
        [maPerfArray addObject:[NSNumber numberWithInt:rand()]];
        *pBuf = rand();
        pBuf++;
    }
    
    //  - first test the array
    RSI_securememory *secMem = [RSI_securememory data];
    NSLog(@"UT-SECPROPS: - archiving/unarchiving the array.");
    BOOL ret = [RSI_secure_props buildArchiveWithProperties:maPerfArray intoData:secMem withCRCPrefix:YES andError:&err];
    XCTAssertTrue(ret, @"Failed to build the archive.");
    NSObject *obj = [RSI_secure_props parseArchiveFromData:secMem.rawData withCRCPrefix:YES andError:&err];
    XCTAssertNotNil(obj, @"Failed to decode the object.  %@", [err localizedDescription]);
    NSLog(@"UT-SECPROPS: - the array I/O is done.");
    XCTAssertTrue([obj isKindOfClass:[NSArray class]], @"The returned object is not an array.");
    XCTAssertTrue([(NSArray *) obj isEqualToArray:maPerfArray], @"The returned array is not equal.");
    NSLog(@"UT-SECPROPS: - the array test is complete.");

    // - now the buffer
    RSI_securememory *secMem2 = [RSI_securememory data];
    NSLog(@"UT-SECPROPS: - archiving/unarchiving the buffer.");
    ret = [RSI_secure_props buildArchiveWithProperties:mdPerfBuffer intoData:secMem2 withCRCPrefix:YES andError:&err];
    XCTAssertTrue(ret, @"Failed to build the archive.");
    obj = [RSI_secure_props parseArchiveFromData:secMem2.rawData withCRCPrefix:YES andError:&err];
    XCTAssertNotNil(obj, @"Failed to decode the object.  %@", [err localizedDescription]);
    NSLog(@"UT-SECPROPS: - the buffer I/O is done.");
    XCTAssertTrue([obj isKindOfClass:[NSData class]], @"The returned object is not a buffer.");
    XCTAssertTrue([(NSData *) obj isEqualToData:mdPerfBuffer], @"The returned buffer is not equal.");
    NSLog(@"UT-SECPROPS: - the buffer test is complete.");

    NSLog(@"UT-SECPROPS: - all performance tests passed successfully.");
}
@end
