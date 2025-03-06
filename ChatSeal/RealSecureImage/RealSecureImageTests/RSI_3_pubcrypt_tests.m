//
//  RSI_3_pubcrypt_tests.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/1/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "RSI_3_pubcrypt_tests.h"
#import "RSI_common.h"
#import "RSI_pubcrypt.h"

static const char *RSI_3_pubcrypt_LABEL = "PublicLabel";
static NSString   *RSI_3_pubcrypt_TAG   = @"simpleTag";
static const char *RSI_3_pubcrypt_TEST_TEXT = "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.";

@implementation RSI_3_pubcrypt_tests

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
 *  Delete all the keys
 */
-(void) testUTPUBCRYPT_1_DeleteAll
{
    NSLog(@"UT-PUBCRYPT: - deleting all existing keys.");
    BOOL ret1 = [RSI_pubcrypt deleteAllKeysAsPublic:YES withError:&err];
    BOOL ret2 = [RSI_pubcrypt deleteAllKeysAsPublic:NO withError:&err];

    XCTAssertTrue(ret1 && ret2, @"Failed to delete all keys.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSArray *arr = [RSI_pubcrypt findAllKeyTagsForPublic:YES withError:&err];
    XCTAssertTrue(!arr || ![arr count], @"Found keys after deletion!");
    
    arr = [RSI_pubcrypt findAllKeyTagsForPublic:NO withError:&err];
    XCTAssertTrue(!arr || ![arr count], @"Found keys after deletion!");    
}

/*
 *  Verify SHA behavior.
 */
-(void) testUTPUBCRYPT_1a_VerifySHA
{
    // - there wasn't a great place to ramrod this stuff, but I figured since the RSA work uses it initially, it might as well
    //   go here.
    NSLog(@"UT-PUBCRYPT: - verifying SHA definitions.");    
    XCTAssert([RSI_SHA_SECURE SHA_LEN] == [RSI_SHA256 SHA_LEN], @"The secure hash length is not using the best option.");
    XCTAssert([RSI_SHA_SCRAMBLE SHA_LEN] == [RSI_SHA_SECURE SHA_LEN], @"The scrambler hash length is not secure.");
    XCTAssert([RSI_SHA_SEAL SHA_LEN] == [RSI_SHA256 SHA_LEN], @"The seal hash length is not secure enough.");
    
    NSLog(@"UT-PUBCRYPT: - spot-checking SHA base-64 generation.");
    // - I just want to do a simple spot check of the base-64 generation because if for some reason I have a bug,
    //   that is a huge deal-breaker for me since so much of this implementation depends on the base-64.
    @autoreleasepool {
        NSMutableSet *msHashes = [NSMutableSet set];
     
        NSUInteger curVal = 0;
        NSUInteger count  = 0;
        for (int x = 0; x < 10; x++) {
            for (int y = 0; y < 1000; y++) {
                NSData *d = [NSData dataWithBytes:&curVal length:sizeof(curVal)];
                RSI_SHA_SECURE *ss = [[[RSI_SHA_SECURE alloc] init] autorelease];
                [ss updateWithData:d];
                NSString *hash = [ss base64StringHash];
                
                XCTAssert([hash length] == [RSI_SHA_SECURE SHA_B64_STRING_LEN], @"The hash length is not correct.");
                
                BOOL hasObj = [msHashes containsObject:hash];
                XCTAssertFalse(hasObj, @"The hash set has the base-64 value and should not.");
                
                [msHashes addObject:hash];
                count++;
                
                XCTAssert([msHashes count] == count, @"The number of hashes is wrong");
                
                curVal += 1;
            }
            curVal += 25000;
        }
    }
}

/*
 *  Create the primary keypair
 */
-(void) testUTPUBCRYPT_2_CreatePrimary
{
    NSLog(@"UT-PUBCRYPT: - creating the primary keypair.");
    RSI_pubcrypt *pubk = [RSI_pubcrypt allocNewKeyForPublicLabel:[NSString stringWithUTF8String:RSI_3_pubcrypt_LABEL] andPrivateLabel:[NSString stringWithUTF8String:RSI_3_pubcrypt_LABEL] andTag:RSI_3_pubcrypt_TAG withError:&err];
    XCTAssertNotNil(pubk, @"Failed to generate the public/private keypair.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    [pubk autorelease];
}

/*
 *  Attempt to create a duplicate keypair
 */
-(void) testUTPUBCRYPT_3_CreateDuplicate
{
    NSLog(@"UT-PUBCRYPT: - attempting to recreate the primary keypair, should fail.");
    RSI_pubcrypt *pubkDud = [RSI_pubcrypt allocNewKeyForPublicLabel:[NSString stringWithUTF8String:RSI_3_pubcrypt_LABEL] andPrivateLabel:[NSString stringWithUTF8String:RSI_3_pubcrypt_LABEL] andTag:RSI_3_pubcrypt_TAG withError:&err];
    XCTAssertNil(pubkDud, @"The key was created when it shouldn't have been.");

    XCTAssertEqual(err.code, RSIErrorKeyExists, @"Failed to receive a duplicate error from the key creation function.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
}

/*
 *  Test encryption after export/import.
 */
-(void) testUTPUBCRYPT_4_EncryptSequence
{
    NSLog(@"UT-PUBCRYPT: - searching for the primary keypair.");
    RSI_pubcrypt *pubk = [RSI_pubcrypt allocExistingKeyForTag:RSI_3_pubcrypt_TAG withError:&err];
    XCTAssertNotNil(pubk, @"Failed to find the existing data.  %@ (%@", [err localizedDescription], [err localizedFailureReason]);
    [pubk autorelease];
    
    NSLog(@"UT-PUBCRYPT: - verifying we have a full key.");
    XCTAssertTrue([pubk isFullKey], @"It didn't identify itself as a full key.");
    
    XCTAssertTrue([pubk blockLen] > 0, @"The block length is invalid.");
    
    NSLog(@"UT-PUBCRYPT: - exporting the public key.");
    NSData *dPublic = [pubk publicKey];
    XCTAssertNotNil(pubk, @"Failed to export the public key.");
    XCTAssertTrue([dPublic length] > 0, @"Failed to export the public key.");

    NSLog(@"UT-PUBCRYPT: - exporting the private key.");
    RSI_securememory *dPrivate = [pubk privateKey];
    XCTAssertNotNil(dPrivate, @"Failed to export the private key.");
    XCTAssertTrue([dPrivate length] > 0, @"Failed to export the private key.");

    NSLog(@"UT-PUBCRYPT: - deleting the public key.");
    BOOL ret = [RSI_pubcrypt deleteKeyAsPublic:YES andTag:RSI_3_pubcrypt_TAG withError:&err];
    XCTAssertTrue(ret, @"Failed to delete the public key.  %@ (%@", [err localizedDescription], [err localizedFailureReason]);
    
    pubk = nil;
    NSLog(@"UT-PUBCRYPT: - verifying the public key is indeed gone.");
    NSArray *arr = [RSI_pubcrypt findAllKeyTagsForPublic:YES withError:&err];
    XCTAssertTrue(!arr || [arr count] == 0, @"Expected to find no public keys but found one or more.");

    NSLog(@"UT-PUBCRYPT: - deleting the private key.");
    ret = [RSI_pubcrypt deleteKeyAsPublic:NO andTag:RSI_3_pubcrypt_TAG withError:&err];
    XCTAssertTrue(ret, @"Failed to delete the private key.  %@ (%@", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-PUBCRYPT: - verifying the private key is indeed gone.");
    arr = [RSI_pubcrypt findAllKeyTagsForPublic:NO withError:&err];
    XCTAssertTrue(!arr || [arr count] == 0, @"Expected to find no private keys but found one or more.");

    NSLog(@"UT-PUBCRYPT: - importing the public key.");
    ret = [RSI_pubcrypt importPublicKeyWithLabel:[NSString stringWithUTF8String:RSI_3_pubcrypt_LABEL] andTag:RSI_3_pubcrypt_TAG andValue:dPublic withError:&err];
    XCTAssertTrue(ret, @"Failed to import the public key.  %@ (%@", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-PUBCRYPT: - verifying that a duplicate import fails with the right error.");
    ret = [RSI_pubcrypt importPublicKeyWithLabel:[NSString stringWithUTF8String:RSI_3_pubcrypt_LABEL] andTag:RSI_3_pubcrypt_TAG andValue:dPublic withError:&err];
    XCTAssertFalse(ret, @"The re-import succeeded and should not have.");
    XCTAssertTrue(err.code == RSIErrorKeyExists, @"The error code was incorrect.  %@", [err localizedDescription]);
    
    NSLog(@"UT-PUBCRYPT: - verifying the public key is now there.");
    arr = [RSI_pubcrypt findAllKeyTagsForPublic:YES withError:&err];
    XCTAssertTrue(arr && [arr count] == 1, @"Expected to find one public key but did not.");
    
    NSLog(@"UT-PUBCRYPT: - loading the public key again.");    
    pubk = [RSI_pubcrypt allocExistingKeyForTag:RSI_3_pubcrypt_TAG withError:&err];
    XCTAssertNotNil(pubk, @"Failed to find the existing data.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    [pubk autorelease];
    
    NSLog(@"UT-PUBCRYPT: - encrypting the source text --> '%s'.", RSI_3_pubcrypt_TEST_TEXT);
    NSData *clearData = [NSData dataWithBytes:RSI_3_pubcrypt_TEST_TEXT length:strlen(RSI_3_pubcrypt_TEST_TEXT) + 1];
    NSMutableData *mdEncrypted = [NSMutableData data];
    
    ret = [pubk encrypt:clearData intoBuffer:mdEncrypted withError:&err];
    XCTAssertTrue(ret, @"Failed to encrypt the source data.");
    
    NSLog(@"UT-PUBCRYPT: - loading the partial key for decryption.");
    RSI_pubcrypt *pkD = [RSI_pubcrypt allocExistingKeyForTag:RSI_3_pubcrypt_TAG withError:&err];
    XCTAssertNotNil(pkD, @"Failed to find the existing data.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    [pkD autorelease];

    NSLog(@"UT-PUBCRYPT: - attempting to decrypt the data (should fail without a private key).");
    RSI_securememory *mdDecrypted = [RSI_securememory data];
    ret = [pkD decrypt:mdEncrypted intoBuffer:mdDecrypted withError:&err];
    XCTAssertFalse(ret, @"The data was decrypted when it should not have been.");

    NSLog(@"UT-PUBCRYPT: - importing the private key.");    
    ret = [RSI_pubcrypt importPrivateKeyWithLabel:[NSString stringWithUTF8String:RSI_3_pubcrypt_LABEL] andTag:RSI_3_pubcrypt_TAG andValue:dPrivate withError:&err];
    XCTAssertTrue(ret, @"Failed to import the public key.  %@ (%@", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-PUBCRYPT: - verifying that a duplicate import fails with the right error code.");
    ret = [RSI_pubcrypt importPrivateKeyWithLabel:[NSString stringWithUTF8String:RSI_3_pubcrypt_LABEL] andTag:RSI_3_pubcrypt_TAG andValue:dPrivate withError:&err];
    XCTAssertFalse(ret, @"The import succeeded and should not have.");
    XCTAssertTrue(err.code == RSIErrorKeyExists, @"The error code was incorrect.  %@", [err localizedDescription]);
    
    NSLog(@"UT-PUBCRYPT: - verifying the private key is now there.");
    arr = [RSI_pubcrypt findAllKeyTagsForPublic:NO withError:&err];
    XCTAssertTrue(arr && [arr count] == 1, @"Expected to find one private key but did not.");
    
    NSLog(@"UT-PUBCRYPT: - loading the full key for decryption.");
    pkD = [RSI_pubcrypt allocExistingKeyForTag:RSI_3_pubcrypt_TAG withError:&err];
    XCTAssertNotNil(pkD, @"Failed to find the existing data.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    [pkD autorelease];
    
    NSLog(@"UT-PUBCRYPT: - attempting to decrypt the data with the full key.");
    ret = [pkD decrypt:mdEncrypted intoBuffer:mdDecrypted withError:&err];
    XCTAssertTrue(ret, @"Failed to decrypt the data.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-PUBCRYPT: - verifying the data.");
    ret = [clearData isEqualToData:mdDecrypted.rawData];
    XCTAssertTrue(ret, @"The data buffers do not match.");
    
    NSLog(@"UT-PUBCRYPT: - decrypted the buffer into --> '%s'", (char *) [mdDecrypted bytes]);
}


/*
 *  Test signing
 */
-(void) testUTPUBCRYPT_5_SigningSequence
{
    NSLog(@"UT-PUBCRYPT: - loading the full encryption key again.");
    RSI_pubcrypt *pubk = [RSI_pubcrypt allocExistingKeyForTag:RSI_3_pubcrypt_TAG withError:&err];
    XCTAssertNotNil(pubk, @"Failed to load the key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    [pubk autorelease];

    NSData *clearData = [NSData dataWithBytes:RSI_3_pubcrypt_TEST_TEXT length:strlen(RSI_3_pubcrypt_TEST_TEXT) + 1];
    
    NSMutableData *mdSignature = [NSMutableData data];
    NSLog(@"UT-PUBCRYPT: - signing the test data.");
    BOOL ret = [pubk sign:clearData intoBuffer:mdSignature withError:&err];
    XCTAssertTrue(ret, @"Failed to sign the data.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-PUBCRYPT: - verifying the signature.");
    ret = [pubk verify:clearData withBuffer:mdSignature withError:&err];
    XCTAssertTrue(ret, @"Failed to verify the signature.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-PUBCRYPT: - verifying that a corrupted signature fails.");
    NSMutableData *mdBadSig = [NSMutableData dataWithData:mdSignature];
    for (int i = 0; i < [mdBadSig length]; i += 100) {
        ((unsigned char *) mdBadSig.mutableBytes)[i] = (unsigned char) ((rand() % 255) & 0xFF);
    }

    ret = [pubk verify:clearData withBuffer:mdBadSig withError:&err];
    XCTAssertFalse(ret, @"The corrupted signature passed when it shouldn't have.");
    
    NSLog(@"UT-PUBCRYPT: - verifying that a corrupted source data fails.");
    NSMutableData *mdBadSource = [NSMutableData dataWithData:clearData];
    for (int i = 0; i < [mdBadSource length]; i += 5) {
        ((unsigned char *) mdBadSource.mutableBytes)[i] = (unsigned char) ((rand() % 255) & 0xFF);
    }
    ret = [pubk verify:mdBadSource withBuffer:mdSignature withError:&err];
    XCTAssertFalse(ret, @"The corrupted data passed when it shouldn't have.");
}

/*
 *  Check that key renaming works.
 */
-(void) testUTPUBCRYPT_5_DoRename
{
    NSLog(@"UT-PUBCRYPT: - verifying that key renaming works as expected.");
    static NSString *RSI_5_PUB_NAME1 = @"PUBPRV_OLDNAME";
    static NSString *RSI_5_PUB_NAME2 = @"PUBPRV_MODIFIED";
    
    NSLog(@"UT-PUBCRYPT: - creating the keypair.");
    RSI_pubcrypt *pubk = [RSI_pubcrypt allocNewKeyForPublicLabel:RSI_5_PUB_NAME1 andPrivateLabel:RSI_5_PUB_NAME1 andTag:RSI_5_PUB_NAME1 withError:&err];
    XCTAssertNotNil(pubk, @"Failed to generate the public/private keypair.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
        
    char *TEST_STR = "This is some data that will be decrypted with the renamed key.";
    NSLog(@"UT-PUBCRYPT: - encrypting the input data --> '%s'.", TEST_STR);
    NSData *testData = [NSData dataWithBytes:TEST_STR length:strlen(TEST_STR)+1];
    NSMutableData *encrypted = [NSMutableData data];
    BOOL ret = [pubk encrypt:testData intoBuffer:encrypted withError:&err];
    XCTAssertTrue(ret, @"Failed to encrypt the data.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-PUBCRYPT: - verifying encrypted data is really different.");
    ret = [testData isEqualToData:encrypted];
    XCTAssertFalse(ret, @"The encrypted data is not different as was expected.");
    
    NSLog(@"UT-PUBCRYPT: - releasing the keys and renaming them.");
    [pubk release];
    pubk = nil;
    ret = [RSI_pubcrypt renamePublicKeyForLabel:RSI_5_PUB_NAME1 andTag:RSI_5_PUB_NAME1 toNewLabel:RSI_5_PUB_NAME2 andNewTag:RSI_5_PUB_NAME2 withError:&err];
    XCTAssertTrue(ret, @"Failed to rename the public key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    ret = [RSI_pubcrypt renamePrivateKeyWithLabel:RSI_5_PUB_NAME1 andTag:RSI_5_PUB_NAME1 toNewLabel:RSI_5_PUB_NAME2 andNewTag:RSI_5_PUB_NAME2 withError:&err];
    XCTAssertTrue(ret, @"Failed to rename the private key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-PUBCRYPT: - loading the key with the new name.");
    RSI_pubcrypt *pkRenamed = [RSI_pubcrypt allocExistingKeyForTag:RSI_5_PUB_NAME2 withError:&err];
    XCTAssertNotNil(pkRenamed, @"The keys were not found.  %@", [err localizedDescription]);
    [pkRenamed autorelease];
    
    NSLog(@"UT-PUBCRYPT: - verifying both keys are available.");
    ret = [pkRenamed isFullKey];
    XCTAssertTrue(ret, @"The key is not a full key!");
    
    NSLog(@"UT-PUBCRYPT: - decrypting the data.");
    RSI_securememory *dDecrypted = [RSI_securememory data];
    ret = [pkRenamed decrypt:encrypted intoBuffer:dDecrypted withError:&err];
    XCTAssertTrue(ret, @"Failed to decrypt the data.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-PUBCRYPT: - comparing the data to the original.");
    XCTAssertTrue(strcmp(TEST_STR, dDecrypted.bytes) == 0, @"The output buffer didn't match the original.");
    
    NSLog(@"UT-PUBCRYPT: - key renaming has been verified.");
}

/*
 *  Check that key deletion of a bad id returns the correct error.
 */
-(void) testUTPUBCRYPT_6_DoDeleteBadId
{
    NSLog(@"UT-PUBCRYPT: - verifying that key deletion of a bad id works as ecpected.");
    BOOL ret = [RSI_pubcrypt deleteKeyWithTag:@"badkey5678" withError:&err];
    XCTAssertFalse(ret, @"The request succeeded and shouldn't have.");
    XCTAssertTrue(err.code == RSIErrorKeyNotFound, @"The error code returned was invalid (%u).  %@", err.code, [err localizedDescription]);
    NSLog(@"UT-PUBCRYPT: - key deletion returned the correct error code.");
}

@end
