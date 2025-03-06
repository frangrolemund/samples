//
//  RSI_8_keyring_tests.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/18/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "RSI_8_keyring_tests.h"
#import "RSI_keyring.h"
#import "RSI_common.h"
#import "RSI_pack.h"
#import "RSI_unpack.h"
#import "bigtime.h"
#import "RSI_secure_props.h"

static const char *RSI_8_SAMPLE_TEXT = "Is it so bad, then, to be misunderstood? Pythagoras was misunderstood, and Socrates, ...and Copernicus, and Galileo, and Newton, and every pure and wise spirit that ever took flesh. To be great is to be misunderstood.";

@implementation RSI_8_keyring_tests

/*
 *  Simple prep between tests.
 */
-(void) setUp
{
    [super setUp];    
    err = nil;
    self.continueAfterFailure = NO;    
}

/*
 *  Create a keyring with a specified bit of scrambler data.
 */
-(RSI_keyring *) keyringWithScramble:(RSI_securememory *) scramTmp andAttributes:(NSData *) attribs
{
    NSLog(@"UT-KEYRING: - creating a new key ring.");
    RSI_keyring *kr = [RSI_keyring allocNewRingUsingScramblerData:scramTmp andAttributes:attribs withError:&err];
    XCTAssertNotNil(kr, @"Failed to create a new keyring.  %@", [err localizedDescription]);
    
    NSLog(@"UT-KEYRING: - the key ring id is %@", [kr sealId]);
    return [kr autorelease];
}

/*
 *  Allocate a purely random keyring.
 */
-(RSI_keyring *) randomKeyRing
{
    time_t tNow = time(NULL);
    int val = (int) tNow + rand();
    
    NSLog(@"UT-KEYRING: - creating the random keyring data.");
    RSI_securememory *scramTmp = [RSI_SHA_SCRAMBLE hashFromInput:[NSData dataWithBytes:&val length:sizeof(val)]];
    XCTAssertNotNil(scramTmp, @"Failed to allocate a secure memory hash.");
    
    return [self keyringWithScramble:scramTmp andAttributes:nil];
}

/*
 *  Basic testing of key ring support
 */
-(void) testUTKEYRING_1_Basic
{
    NSLog(@"UT-KEYRING: - starting basic key ring testing.");
    
    NSLog(@"UT-KEYRING: - deleting all existing keyrings.");
    BOOL ret = [RSI_keyring deleteAllKeyringsWithError:&err];
    XCTAssertTrue(ret, @"Failed to delete all existing keyrings.  %@", [err localizedDescription]);
    
    NSLog(@"UT-KEYRING: - verifying that invalid arguments are detected.");
    RSI_keyring *kr = [RSI_keyring allocNewRingUsingScramblerData:nil andAttributes:nil withError:&err];
    XCTAssertNil(kr, @"Allocated seal keys with bad argument.");
    
    const char *hashSrc = "RoleScramble";
    RSI_securememory *scramTmp = [RSI_SHA_SCRAMBLE hashFromInput:[NSData dataWithBytes:hashSrc length:strlen(hashSrc)]];
    NSMutableData *md = [NSMutableData dataWithLength:1024];
    kr = [RSI_keyring allocNewRingUsingScramblerData:scramTmp andAttributes:md withError:&err];
    XCTAssertNil(kr, @"Allocated seal keys with bad argument.");
    
    kr = [self randomKeyRing];
    NSString *sealId = [kr sealId];
    
    ret = [kr isValid];
    XCTAssertTrue(ret, @"The ring is not valid and it should be.");
    NSLog(@"UT-KEYRING: - the ring is valid");
    
    NSLog(@"UT-KEYRING: - verifying this is an owner's keyring");
    ret = [kr isOwnersKeyring];
    XCTAssertTrue(ret, @"The keyring is not identified as an owner's keyring and it should be.");
    
    NSLog(@"UT-KEYRING: - checking the attributes are zero to start");
    RSI_securememory *secAttributes = [kr attributeDataWithError:&err];
    XCTAssertNotNil(secAttributes, @"The attributes could not be retrieved.");
    
    NSMutableData *mdZero = [NSMutableData dataWithLength:[RSI_keyring attributeDataLength]];
    ret = [mdZero isEqualToData:secAttributes.rawData];
    XCTAssertTrue(ret, @"The attributes did not start with a value of zero.");
    
    NSLog(@"UT-KEYRING: - setting the attributes to something specific");
    RSI_securememory *secMemSpecific = [RSI_securememory dataWithLength:[RSI_keyring attributeDataLength]];
    for (NSUInteger i = 0; i < [RSI_keyring attributeDataLength]; i++) {
        ((unsigned char *) [secMemSpecific mutableBytes])[i] = 100-i;
    }
    ret = [kr setAttributesWithData:secMemSpecific andError:&err];
    XCTAssertTrue(ret, @"Failed to assign the attributes.");
    
    NSLog(@"UT-KEYRING: - exporting the ring");
    NSDictionary *dExported = [kr exportForExternal:NO withAlternateAttributes:nil andError:&err];
    XCTAssertNotNil(dExported, @"Failed to export the ring.  %@", [err localizedDescription]);
    
    NSLog(@"UT-KEYRING: - exporting the ring with alternate attributes");
    RSI_securememory *secMemAlternate = [RSI_securememory dataWithLength:[RSI_keyring attributeDataLength]];
    for (NSUInteger i = 0; i < [RSI_keyring attributeDataLength]; i++) {
        ((unsigned char *) [secMemAlternate mutableBytes])[i] = 100-i;
    }
    NSDictionary *dExportedAlternate = [kr exportForExternal:NO withAlternateAttributes:secMemAlternate andError:&err];
    XCTAssertNotNil(dExportedAlternate, @"Failed to export the ring.  %@", [err localizedDescription]);

    NSLog(@"UT-KEYRING: - deleting the ring.");
    ret = [RSI_keyring deleteRingWithSealId:sealId andError:&err];
    XCTAssertTrue(ret, @"Failed to delete the key ring.  %@", [err localizedDescription]);
    
    NSLog(@"UT-KEYRING: - verifying the ring is gone.");
    kr = [[RSI_keyring allocExistingWithSealId:sealId] autorelease];
    ret = [kr isValid];
    XCTAssertFalse(ret, @"The ring was reported as valid when it is gone.");
    
    NSLog(@"UT-KEYRING: - reimporting the ring");
    NSString *simportedId = [RSI_keyring importFromCollection:dExported andSeparateScramblerData:nil withError:&err];
    XCTAssertNotNil(simportedId, @"Failed to import the exported key into the global keychain.");
    XCTAssertTrue([sealId isEqualToString:simportedId], @"The imported key does not equal the original");
    
    NSLog(@"UT-KEYRING: - the imported key id is %@", simportedId);
    
    NSLog(@"UT-KEYRING: - verifying the ring is now there.");
    kr = [[RSI_keyring allocExistingWithSealId:simportedId] autorelease];
    ret = [kr isValid];
    XCTAssertTrue(ret, @"The keyring was not found when it was expected to be.");
    
    NSLog(@"UT-KEYRING: - verifying this is an owner's keyring");
    ret = [kr isOwnersKeyring];
    XCTAssertTrue(ret, @"The keyring is not identified as an owner's keyring and it should be.");
    
    NSLog(@"UT-KEYRING: - retrieving the attributes and verifying they are the modified value.");
    secAttributes = [kr attributeDataWithError:&err];
    XCTAssertNotNil(secAttributes, @"Failed to retrieve the attributes.");
    
    ret = [secAttributes isEqualToSecureData:secMemSpecific];
    XCTAssertTrue(ret, @"The attributes are different than expected.");
        
    NSLog(@"UT-KEYRING: - deleting the ring.");
    ret = [RSI_keyring deleteRingWithSealId:sealId andError:&err];
    XCTAssertTrue(ret, @"Failed to delete the key ring.  %@", [err localizedDescription]);

    NSLog(@"UT-KEYRING: - verifying the ring is gone.");
    kr = [[RSI_keyring allocExistingWithSealId:sealId] autorelease];
    ret = [kr isValid];
    XCTAssertFalse(ret, @"The ring was reported as valid when it is gone.");
    
    NSLog(@"UT-KEYRING: - reimporting the ring with alternate attributes");
    simportedId = [RSI_keyring importFromCollection:dExportedAlternate andSeparateScramblerData:nil withError:&err];
    XCTAssertNotNil(simportedId, @"Failed to import the exported key into the global keychain.");
    XCTAssertTrue([sealId isEqualToString:simportedId], @"The imported key does not equal the original");
    
    NSLog(@"UT-KEYRING: - the imported key id is %@", simportedId);
    
    NSLog(@"UT-KEYRING: - retrieving the attributes and verifying they are the modified value.");
    secAttributes = [kr attributeDataWithError:&err];
    XCTAssertNotNil(secAttributes, @"Failed to retrieve the attributes.");
    
    ret = [secAttributes isEqualToSecureData:secMemAlternate];
    XCTAssertTrue(ret, @"The attributes are different than expected.");

    NSLog(@"UT-KEYRING: - all tests completed successfully.");
}

/*
 *  Creates a test image of the given size.
 */
-(UIImage *) imageOfSize:(CGSize) sz andBackground:(UIColor *) bgColor andLineColor:(UIColor *) lColor
{
    UIGraphicsBeginImageContext(sz);
    CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), [bgColor CGColor]);
    CGContextFillRect(UIGraphicsGetCurrentContext(), CGRectMake(0.0f, 0.0f, sz.width, sz.height));
    CGContextSetStrokeColorWithColor(UIGraphicsGetCurrentContext(), [lColor CGColor]);
    CGContextStrokeRect(UIGraphicsGetCurrentContext(), CGRectMake(0.0f, 0.0f, sz.width, sz.height));
    UIImage *ret = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return ret;
}

/*
 *  Generate an array with test data for encryption/decryption.
 */
-(NSMutableDictionary *) buildTestDictionary
{
    NSMutableDictionary *mdProps = [NSMutableDictionary dictionary];
    [mdProps setObject:@"The quick brown fox jumped." forKey:@"fox"];
    [mdProps setObject:[NSNumber numberWithInt:45] forKey:@"number"];
    [mdProps setObject:[NSDate date] forKey:@"date"];
    
    RSI_securememory *secmem = [RSI_securememory dataWithLength:25];
    for (int i = 0; i < [secmem length]; i++) {
        ((unsigned char *) secmem.mutableBytes)[i] = (rand() % 0xFF);
    }
    [mdProps setObject:secmem forKey:@"smemory"];
    
    NSMutableArray *maSub1 = [NSMutableArray array];
    [maSub1 addObject:@"Something new"];
    
    NSMutableDictionary *mdSub2 = [NSMutableDictionary dictionary];
    [mdSub2 setObject:[NSNumber numberWithFloat:0.295f] forKey:@"float"];
    [mdSub2 setObject:[self imageOfSize:CGSizeMake(100, 100) andBackground:[UIColor blueColor] andLineColor:[UIColor redColor]] forKey:@"uiimage"];
    
    [maSub1 addObject:mdSub2];
    
    [mdProps setObject:maSub1 forKey:@"sub-arr"];
    
    NSMutableDictionary *mdSubDir = [NSMutableDictionary dictionary];
    UIImage *img = [self imageOfSize:CGSizeMake(201, 205) andBackground:[UIColor yellowColor] andLineColor:[UIColor orangeColor]];
    NSData *d = [RSI_pack packedJPEG:img withQuality:0.50f andData:[NSData dataWithBytes:RSI_8_SAMPLE_TEXT length:strlen(RSI_8_SAMPLE_TEXT)+1] andError:&err];
    XCTAssertNotNil(d, @"Failed to pack the sample JPEG.  %@", [err localizedDescription]);
    [mdSubDir setObject:d forKey:@"packedimg"];
    
    [mdProps setObject:mdSubDir forKey:@"sub-dir"];
    
    XCTAssertNotNil(mdProps, @"Failed to create the test dictionary.");
    return mdProps;
}

/*
 *  Validate the contents of a known test dictionary.
 */
-(void) validateTestDictionary:(NSDictionary *) props withOriginal:(NSDictionary *) orig
{
    XCTAssertNotNil(props, @"Failed to decrypt the test dictionary.");
    
    XCTAssertEqual([props count], (NSUInteger) 6, @"The decrypted dictionary doesn't have the expected number of elements.");

    XCTAssertTrue([[props objectForKey:@"fox"] isKindOfClass:[NSString class]], @"Missing 'fox' value.");
    XCTAssertTrue([(NSString *) [props objectForKey:@"fox"] isEqualToString:[orig objectForKey:@"fox"]], @"Invalid 'fox' value.");

    XCTAssertTrue([[props objectForKey:@"number"] isKindOfClass:[NSNumber class]], @"Missing 'number' value.");
    XCTAssertTrue([(NSNumber *) [props objectForKey:@"number"] isEqualToNumber:[orig objectForKey:@"number"]], @"Invalid 'number' value.");
    
    XCTAssertTrue([[props objectForKey:@"date"] isKindOfClass:[NSDate class]], @"Missing 'date' value.");
    XCTAssertTrue([(NSDate *) [props objectForKey:@"date"] isEqualToDate:[orig objectForKey:@"date"]], @"Invalid 'date' value.");
    
    XCTAssertTrue([[props objectForKey:@"smemory"] isKindOfClass:[RSI_securememory class]], @"Missing 'smemory' value.");
    XCTAssertTrue([(RSI_securememory *) [props objectForKey:@"smemory"] isEqualToSecureData:[orig objectForKey:@"smemory"]], @"Invalid 'smemory' value.");
    
    XCTAssertTrue([[props objectForKey:@"sub-arr"] isKindOfClass:[NSArray class]], @"Missing 'sub-arr' value.");
    NSArray *saP = (NSArray *) [props objectForKey:@"sub-arr"];
    NSArray *saO = (NSArray *) [orig objectForKey:@"sub-arr"];
    
    XCTAssertTrue([saP count] == 2, @"Unexpected sub-array contents.");
    XCTAssertTrue([[saP objectAtIndex:0] isKindOfClass:[NSString class]], @"Missing sub-array string.");
    XCTAssertTrue([(NSString *) [saP objectAtIndex:0] isEqualToString:[saO objectAtIndex:0]], @"Invalid sub-array string.");
    
    XCTAssertTrue([[saP objectAtIndex:1] isKindOfClass:[NSDictionary class]], @"Missing sub-array dictionary.");
    
    NSDictionary *sdP = (NSDictionary *) [saP objectAtIndex:1];
    NSDictionary *sdO = (NSDictionary *) [saO objectAtIndex:1];
    
    XCTAssertTrue([(NSNumber *) [sdP objectForKey:@"float"] floatValue] - [(NSNumber *) [sdO objectForKey:@"float"] floatValue] < 0.0001, @"Invalid 'float' value.");
    
    XCTAssertTrue([[sdP objectForKey:@"uiimage"] isKindOfClass:[UIImage class]], @"Missing 'uiimage' value.");
    UIImage *img1 = (UIImage *) [sdP objectForKey:@"uiimage"];
    CGSize sz = img1.size;
    XCTAssertTrue((int) sz.width == 100 && (int) sz.height == 100, @"The 'uiimage' is an invalid size.");
    
    XCTAssertTrue([[props objectForKey:@"sub-dir"] isKindOfClass:[NSDictionary class]], @"Missing 'sub-dir' value.");
    sdP = (NSDictionary *) [props objectForKey:@"sub-dir"];
    
    XCTAssertTrue([[sdP objectForKey:@"packedimg"] isKindOfClass:[NSData class]], @"Missing 'packedimg' value.");
    NSData *dPacked = (NSData *) [sdP objectForKey:@"packedimg"];
    
    NSData *dUnpacked = [RSI_unpack unpackData:dPacked withMaxLength:0 andError:&err];
    XCTAssertNotNil(dUnpacked, @"Failed to unpack the packed image.");
    
    XCTAssertTrue([dUnpacked length] >= strlen(RSI_8_SAMPLE_TEXT), @"The returned packed text is invalid.");
    
    int rc = strncmp((const char *) dUnpacked.bytes, RSI_8_SAMPLE_TEXT, strlen(RSI_8_SAMPLE_TEXT));
    XCTAssertTrue(rc == 0, @"The unpacked data is not valid.");
}

/*
 *  Verify that the encryption/decryption works.
 */
-(void) verifyEncryptDecryptWithRing:(RSI_keyring *) kr forType:(int) encType
{
    NSLog(@"UT-KEYRING: - building the test properties.");
    NSMutableDictionary *mdProps = [self buildTestDictionary];
    
    NSLog(@"UT-KEYRING: - encrypting the properties as %s.", encType == 0 ? "producer" : (encType == 1 ? "consumer" : "local"));
    NSData *encrypted = nil;
    XCTAssertTrue(encType < 3, @"The encryption type is bad.");
    if (encType == 0) {
        encrypted = [kr encryptProducerMessage:mdProps withError:&err];
    }
    else if (encType == 1) {
        encrypted = [kr encryptConsumerMessage:mdProps withError:&err];
    }
    else if (encType == 2) {
        encrypted = [kr encryptLocalOnlyMessage:mdProps withError:&err];
    }
    XCTAssertNotNil(encrypted, @"Failed to encrypt the %s message.  %@", encType == 0 ? "producer" : (encType == 1 ? "consumer" : "local"), [err localizedDescription]);
    
    NSLog(@"UT-KEYRING: - decrypting the properties.");
    BOOL isProducer = NO;
    NSDictionary *dictDecoded = [kr decryptMessage:encrypted isProducerMessage:&isProducer withError:&err];
    XCTAssertNotNil(dictDecoded, @"Failed to decrypt the %s message.  %@", encType == 0 ? "producer" : (encType == 1 ? "consumer" : "local"), [err localizedDescription]);
    BOOL ret = (isProducer == (encType == 0));
    XCTAssertTrue(ret, @"Failed to identify the message type.");
    
    NSLog(@"UT-KEYRING: - validating the returned data.");
    [self validateTestDictionary:dictDecoded withOriginal:mdProps];
}

/*
 *  Encryption/decryption testing
 */
-(void) testUTKEYRING_2_EncryptDecrypt
{
    NSLog(@"UT-KEYRING: - starting encryption testing.");
    
    time_t t_now = time(NULL);
    srand((unsigned int) t_now);
    NSLog(@"UT-KEYRING: - the seed is %ld", t_now);
    
    RSI_keyring *kr = [self randomKeyRing];
    
    [self verifyEncryptDecryptWithRing:kr forType:0];
    [self verifyEncryptDecryptWithRing:kr forType:1];
    [self verifyEncryptDecryptWithRing:kr forType:2];
    
    NSLog(@"UT-KEYRING: - verifying that invalidated key rings cannot be used");
    NSMutableDictionary *mdProps = [self buildTestDictionary];
    NSData *dEncrypted = [kr encryptProducerMessage:mdProps withError:&err];
    XCTAssertNotNil(dEncrypted, @"Failed to encrypt the test properties.");
    
    BOOL isProducer = NO;
    NSDictionary *dDecrypted = [kr decryptMessage:dEncrypted isProducerMessage:&isProducer withError:&err];
    XCTAssertNotNil(dDecrypted, @"Failed to decrypt the message before invalidation.");
    XCTAssertTrue(isProducer, @"The message was not correctly identified as a producer message.");
    
    BOOL ret = [kr invalidateSymmetricKeyWithError:&err];
    XCTAssertTrue(ret, @"Failed to invalidate the key ring.");
    
    dDecrypted = [kr decryptMessage:dEncrypted isProducerMessage:nil withError:&err];
    XCTAssertNil(dDecrypted, @"The message was decrypted with the invalidated key ring.");
    
    NSLog(@"UT-KEYRING: - all tests completed successfully.");
}

/*
 *  Check that the keyring's attributes match the predictable pattern provided during
 *  initialization.
 */
-(void) verifyPredictableAttributesInRing:(RSI_keyring *) kr
{
    NSLog(@"UT-KEYRING: - verifying the initialization attributes are in place.");
    RSI_securememory *secMem = [kr attributeDataWithError:&err];
    XCTAssertNotNil(secMem, @"Failed to retrieve attributes.  %@", [err localizedDescription]);
    
    XCTAssertTrue([secMem length] > 10, @"The attributes are not long enough.");
    
    for (int i = 0; i < 10; i++) {
        char b = ((char *) secMem.mutableBytes)[i];
        XCTAssertTrue(b == i, @"The attribute at byte %d is wrong.  (was %d)", i, b);
    }
}

/*
 *  Role testing
 *  - validates that producer and consumer messages can only be read by 
 *    the intended parties.
 */
-(void) testUTKEYRING_3_Roles
{
    NSLog(@"UT-KEYRING: - starting role testing.");
    
    time_t t_now = time(NULL);
    srand((unsigned int) t_now);
    NSLog(@"UT-KEYRING: - the seed is %ld", t_now);
    
    //  - we must generate the scrambler data here so that reimport can occur later
    //    on the consumer side.
    const char *hashSrc = "RoleScramble";
    RSI_securememory *scramTmp = [RSI_SHA_SCRAMBLE hashFromInput:[NSData dataWithBytes:hashSrc length:strlen(hashSrc)]];
    XCTAssertNotNil(scramTmp, @"Failed to allocate a secure memory hash.");    
    
    // - save some predictable attribute data to verify that works.
    NSMutableData *mdAttribs = [NSMutableData dataWithLength:10];
    for (int i = 0; i < 10; i++) {
        ((char *) mdAttribs.mutableBytes)[i] = i;
    }
    RSI_keyring *kr = [self keyringWithScramble:scramTmp andAttributes:mdAttribs];
    
    NSLog(@"UT-KEYRING: - verifying this is an owner's keyring");
    BOOL ret = [kr isOwnersKeyring];
    XCTAssertTrue(ret, @"The keyring is not identified as an owner's keyring and it should be.");
    
    NSLog(@"UT-KEYRING: - building the test data.");
    NSMutableDictionary *mdProps = [self buildTestDictionary];
    
    NSLog(@"UT-KEYRING: - encrypting a producer message with the full seal.");
    NSData *encryptedProducer = [kr encryptProducerMessage:mdProps withError:&err];
    XCTAssertNotNil(encryptedProducer, @"Failed to encrypt the producer message.");

    NSLog(@"UT-KEYRING: - encrypting a consumer message with the full seal.");
    NSData *encryptedProdConsum = [kr encryptConsumerMessage:mdProps withError:&err];
    XCTAssertNotNil(encryptedProducer, @"Failed to encrypt the consumer message.");
 
    NSLog(@"UT-KEYRING: - exporting the key ring for each role and deleting it.");
    
    NSMutableDictionary *mdProdKeyRing = [kr exportForExternal:NO withAlternateAttributes:nil andError:&err];
    XCTAssertNotNil(mdProdKeyRing, @"Failed to export the producer keyring.");
    
    NSMutableDictionary *mdConsKeyRing = [kr exportForExternal:YES withAlternateAttributes:nil andError:&err];
    XCTAssertNotNil(mdConsKeyRing, @"Failed to export the consumer keyring.");
    
    NSString *sealId = [kr sealId];
    ret = [RSI_keyring deleteRingWithSealId:sealId andError:&err];
    XCTAssertTrue(ret, @"Failed to delete the keyring.  %@", [err localizedDescription]);
    
    kr = [RSI_keyring allocExistingWithSealId:sealId];
    XCTAssertFalse([kr isValid], @"Found the deleted keyring.");
    [kr release];
    
    NSLog(@"UT-KEYRING: - reimporting the keyring as a consumer key.");
    NSString *importedSeal = [RSI_keyring importFromCollection:mdConsKeyRing andSeparateScramblerData:scramTmp withError:&err];
    XCTAssertTrue([importedSeal isEqualToString:sealId], @"Failed to import the consumer keyring.");
    
    kr = [RSI_keyring allocExistingWithSealId:sealId];
    XCTAssertTrue([kr isValid], @"Failed to find the keyring again.");
    [kr autorelease];
    
    [self verifyPredictableAttributesInRing:kr];
    
    NSLog(@"UT-KEYRING: - verifying this is no longer an owner's keyring");
    ret = [kr isOwnersKeyring];
    XCTAssertFalse(ret, @"The keyring was identified as an owner's keyring and it should not have been.");    
    
    NSLog(@"UT-KEYRING: - verifying that the consumer keyring cannot be exported externally.");
    NSMutableDictionary *mdExport2 = [kr exportForExternal:YES withAlternateAttributes:nil andError:&err];
    XCTAssertNil(mdExport2, @"The consumer keyring was able to be exported for external distribution.");
    
    NSLog(@"UT-KEYRING: - verifying that the consumer keyring can be exported locally.");
    mdExport2 = [kr exportForExternal:NO withAlternateAttributes:nil andError:&err];
    XCTAssertNotNil(mdExport2, @"The consumer keyring was not exported as expected.");
    
    NSLog(@"UT-KEYRING: - checking that the keyring can decrypt a producer message.");
    NSDictionary *dDecrypted = [kr decryptMessage:encryptedProducer isProducerMessage:nil withError:&err];
    XCTAssertNotNil(dDecrypted, @"Failed to decrypt the message.  %@", [err localizedDescription]);
    
    [self validateTestDictionary:dDecrypted withOriginal:mdProps];
    dDecrypted = nil;
    
    NSLog(@"UT-KEYRING: - checking that the keyring will not decrypt a producer-generated consumer message.");
    dDecrypted = [kr decryptMessage:encryptedProdConsum isProducerMessage:nil withError:&err];
    XCTAssertNil(dDecrypted, @"Decrypted the producer-generated consumer message and should not have.");
    XCTAssertTrue(err.code == RSIErrorUnsupportedConsumerAction, @"Failed to receive the expected error code.");
    
    NSLog(@"UT-KEYRING: - attempting to encrypt as producer with a half-seal (should fail).");
    NSData *dEncryptedConsumer = [kr encryptProducerMessage:mdProps withError:&err];
    XCTAssertNil(dEncryptedConsumer, @"Encrypted as producer and shouldn't have.");
    XCTAssertTrue(err.code == RSIErrorUnsupportedConsumerAction, @"Failed to receive the expected error code.");    
    
    NSLog(@"UT-KEYRING: - attempting to encrypt as consumer with a half-seal.");
    dEncryptedConsumer = [kr encryptConsumerMessage:mdProps withError:&err];
    XCTAssertNotNil(dEncryptedConsumer, @"Failed to encrypt the consumer message.  %@", [err localizedDescription]);
    
    NSLog(@"UT-KEYRING: - attempting to decrypt the consumer message (should fail).");
    dDecrypted = [kr decryptMessage:dEncryptedConsumer isProducerMessage:nil withError:&err];
    XCTAssertNil(dDecrypted, @"Decrypted the consumer message and should not have.");
    XCTAssertTrue(err.code == RSIErrorUnsupportedConsumerAction, @"Failed to receive the expected error code."); 

    NSLog(@"UT-KEYRING: - deleting the consumer keyring.");
    ret = [RSI_keyring deleteRingWithSealId:sealId andError:&err];
    XCTAssertTrue(ret, @"Failed to delete the keyring.  %@", [err localizedDescription]);
    
    kr = [RSI_keyring allocExistingWithSealId:sealId];
    XCTAssertFalse([kr isValid], @"Found the deleted keyring.");
    [kr release];
    
    NSLog(@"UT-KEYRING: - reimporting the producer keyring.");
    importedSeal = [RSI_keyring importFromCollection:mdProdKeyRing andSeparateScramblerData:nil withError:&err];
    XCTAssertTrue([importedSeal isEqualToString:sealId], @"Failed to import the consumer keyring.");
    
    kr = [RSI_keyring allocExistingWithSealId:sealId];
    XCTAssertTrue([kr isValid], @"Failed to find the keyring again.");
    [kr autorelease];
    
    [self verifyPredictableAttributesInRing:kr]; 
    
    NSLog(@"UT-KEYRING: - verifying this is an owner's keyring");
    ret = [kr isOwnersKeyring];
    XCTAssertTrue(ret, @"The keyring is not identified as an owner's keyring and it should be.");
    
    NSLog(@"UT-KEYRING: - attempting to decrypt the consumer message");
    NSDictionary *dDecryptedConsumer = [kr decryptMessage:dEncryptedConsumer isProducerMessage:nil withError:&err];
    XCTAssertNotNil(dDecryptedConsumer, @"Failed to decrypt the consumer message.  %@", [err localizedDescription]);
    
    [self validateTestDictionary:dDecryptedConsumer withOriginal:mdProps];
        
    NSLog(@"UT-KEYRING: - all tests completed successfully.");     
}

/*
 *  Payload identification testing.
 */
-(void) testUTKEYRING_4_Identification
{
    NSLog(@"UT-KEYRING: - starting identification testing.");
    
    NSLog(@"UT-KEYRING: - deleting all existing keyrings.");
    BOOL ret = [RSI_keyring deleteAllKeyringsWithError:&err];
    XCTAssertTrue(ret, @"Failed to delete all existing keyrings.  %@", [err localizedDescription]);
    
    NSLog(@"UT-KEYRING: - building all the test dictionaries.");
    NSMutableArray *maTestDict = [NSMutableArray array];
    const NSUInteger NUM_TEST_KEYS = 10;
    
    for (NSUInteger i = 0; i < NUM_TEST_KEYS; i++) {
        NSDictionary *dict = [self buildTestDictionary];
        XCTAssertNotNil(dict, @"Failed to build the test dictionary at index %u.", i);
        
        [maTestDict addObject:dict];
    }
    
    NSLog(@"UT-KEYRING: - building all the keys.");
    NSMutableArray *maTestKeys = [NSMutableArray array];
    for (NSUInteger i = 0; i < NUM_TEST_KEYS; i++) {
        RSI_keyring *kr = [self randomKeyRing];
        XCTAssertNotNil(kr, @"Failed to build the keyring at index %u.", i);
        
        [maTestKeys addObject:kr];
    }
    
    NSLog(@"UT-KEYRING: - encrypting all the test data.");
    NSMutableArray *maEncrypted = [NSMutableArray array];
    NSMutableArray *maHashes    = [NSMutableArray array];
    for (NSUInteger i = 0; i < NUM_TEST_KEYS; i++) {
        RSI_keyring *kr = [maTestKeys objectAtIndex:i];
        
        NSData *d = [kr encryptProducerMessage:[maTestDict objectAtIndex:i] withError:&err];
        XCTAssertNotNil(d, @"Failed to encrypt the message at index %u.", i);
        NSString *sHash = nil;
        sHash = [RSI_keyring hashForEncryptedMessage:[NSData dataWithBytes:d.bytes length:[RSI_secure_props propertyHeaderLength]-1] withError:&err];
        XCTAssertNil(sHash, @"Failed to get an invalid hash at index %u.", i);
        XCTAssertTrue(err.code == RSIErrorInvalidSealedMessage , @"Failed to get the expected error code.");
        sHash = [RSI_keyring hashForEncryptedMessage:d withError:&err];
        XCTAssertNotNil(sHash, @"Failed to hash the message at index %u.", i);
        [maHashes addObject:sHash];
        [maEncrypted addObject:d];
    }
    
    bigtime_t btStart = btclock();
    NSLog(@"UT-KEYRING: - verifying all the test data can be generally decrypted.");
    for (NSUInteger i = 0; i < NUM_TEST_KEYS; i++) {
        NSData *d = [maEncrypted objectAtIndex:i];
        
        RSISecureMessage *smDecrypted = [RSI_keyring identifyEncryptedMessage:d withFullDecryption:YES andError:&err];
        XCTAssertNotNil(smDecrypted.dMessage, @"Failed to identify the encrypted data at index %u.", i);
        XCTAssertNotNil(smDecrypted.sealId, @"Failed to return a valid seal id.");
        XCTAssertTrue(smDecrypted.isProducerGenerated, @"Failed to identify the producer message.");
        
        [self validateTestDictionary:smDecrypted.dMessage withOriginal:[maTestDict objectAtIndex:i]];
        
        NSString *sHash = [maHashes objectAtIndex:i];
        XCTAssertTrue([sHash isEqualToString:smDecrypted.hash], @"The hash was not equal at index %u.", i);
        
        NSLog(@"UT-KEYRING: - identified seal %@.", smDecrypted.sealId);
    }
    
    bigtime_t btDiff = btclock() - btStart;
    
    NSLog(@"UT-KEYRING: - average identification time was %f seconds.", btinsec(btDiff/NUM_TEST_KEYS));
    
    NSLog(@"UT-KEYRING: - verifying that the seal cache is in use.");
    NSData *d = [maEncrypted objectAtIndex:NUM_TEST_KEYS-1];
    btStart = btclock();
    RSISecureMessage *smRepeat = [RSI_keyring identifyEncryptedMessage:d withFullDecryption:YES andError:&err];
    bigtime_t btDiffRepeat = btclock() - btStart;
    XCTAssertNotNil(smRepeat.dMessage, @"Failed to peform repeat decryption.");
    
    [self validateTestDictionary:smRepeat.dMessage withOriginal:[maTestDict objectAtIndex:NUM_TEST_KEYS-1]];
    XCTAssertTrue(btDiffRepeat < (btDiff/NUM_TEST_KEYS), @"The repeat execution was not faster as expected.");
        
    NSLog(@"UT-KEYRING: - popular search time was %f seconds.", btinsec(btDiffRepeat));
    
    NSLog(@"UT-KEYRING: - verifying bulk identification behavior.");
    NSMutableArray *maToIdentify = [NSMutableArray array];
    for (NSUInteger i = 0; i < NUM_TEST_KEYS; i++) {
        [maToIdentify addObject:[maEncrypted objectAtIndex:NUM_TEST_KEYS-1-i]];
        
        NSMutableData *mdTestData = [NSMutableData dataWithLength:1024];
        SecRandomCopyBytes(kSecRandomDefault, [mdTestData length], mdTestData.mutableBytes);
        [maToIdentify addObject:mdTestData];
    }
    
    for (NSUInteger i = 0; i < [maToIdentify count]; i++) {
        NSData *dObj  = (NSData *) [maToIdentify objectAtIndex:i];
        XCTAssertTrue(dObj && [dObj length] >= [RSI_secure_props propertyHeaderLength], @"The object is invalid at index %u.", i);
        NSData *dLimited = [NSData dataWithBytes:dObj.bytes length:[RSI_secure_props propertyHeaderLength]];
        RSISecureMessage *smIdentified = [RSI_keyring identifyEncryptedMessage:dLimited withFullDecryption:NO andError:&err];
        if (i % 2 == 0) {
            NSString *sHash = [maHashes objectAtIndex:NUM_TEST_KEYS-1-(i/2)];
            NSString *sLimHash  = [RSI_keyring hashForEncryptedMessage:dLimited withError:nil];
            XCTAssertTrue([sHash isEqualToString:sLimHash], @"The hash is not equal to the limited hash.");
            XCTAssertNil(smIdentified.dMessage, @"The message was not empty as expected at index %u.", i);
            XCTAssertNotNil(smIdentified, @"The identification failed for index %u.", i);
            XCTAssertNotNil(smIdentified.sealId, @"Failed to return a valid seal for index %u.", i);
            
            RSI_keyring *kr = [maTestKeys objectAtIndex:NUM_TEST_KEYS-1-(i/2)];
            XCTAssertTrue([smIdentified.sealId isEqualToString:kr.sealId], @"The seal id doesn't match its expected value at index %u.", i);
            
            XCTAssertTrue([sHash isEqualToString:smIdentified.hash], @"The hashes are not equal at index %u.", i);
                          
            NSLog(@"UT-KEYRING: - identified seal %@.", smIdentified.sealId);
        }
        else {
            XCTAssertNil(smIdentified.sealId, @"Failed to flag a bad data buffer for index %u.", i);
            XCTAssertEqual(err.code, RSIErrorInvalidSealedMessage, @"The expected return code was not provided.");
        }
    }
    
    //  - this is necessary to ensure that local messages are never passed externally
    //  (if they cannot ever be identified, then they are of no use to an external entity)
    NSLog(@"UT-KEYRING: - verifying bulk identification doesn't flag local messages.");
    NSMutableArray *maToIdentifyWithLocal = [NSMutableArray array];
    for (NSUInteger i = 0; i < NUM_TEST_KEYS; i++) {
        RSI_keyring *kr = [maTestKeys objectAtIndex:i];
    
        NSData *dLocal = [kr encryptLocalOnlyMessage:[maTestDict objectAtIndex:i] withError:&err];
        XCTAssertNotNil(dLocal, @"Failed to encrypt a local-only message.");
        [maToIdentifyWithLocal addObject:dLocal];
    }
    
    for (NSUInteger i = 0; i < NUM_TEST_KEYS; i++) {
        NSObject *obj = [maToIdentifyWithLocal objectAtIndex:i];
        RSISecureMessage *sm = [RSI_keyring identifyEncryptedMessage:(NSData *) obj withFullDecryption:YES andError:&err];
        XCTAssertNil(sm.sealId, @"Failed to flag a bad data buffer for index %u.", i/2);
        XCTAssertEqual(err.code, RSIErrorInvalidSealedMessage, @"The expected return code was not provided.");
    }
        
    NSLog(@"UT-KEYRING: - all tests completed successfully.");
}


@end
