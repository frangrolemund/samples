//
//  RSI_2_symcrypt_tests.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 12/31/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import "RSI_2_symcrypt_tests.h"
#import "RSI_common.h"
#import "RSI_symcrypt.h"

static NSString *RSI_2_symcrypt_GLOBALKEY    = @"GlobalKey";
static NSString *RSI_2_symcrypt_SECONDARYKEY = @"SecondaryKey";

@implementation RSI_2_symcrypt_tests

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
-(void) testUTSYMCRYPT_1_DeleteAll
{
    NSLog(@"UT-SYMCRYPT: - deleting all existing keys.");    
    BOOL ret = [RSI_symcrypt deleteAllKeysWithType:CSSM_ALGID_SYM_GLOBAL withError:&err];
    XCTAssertTrue(ret, @"Failed to delete all keys.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSArray *arr = [RSI_symcrypt findAllKeyTagsForType:CSSM_ALGID_SYM_GLOBAL withError:&err];
    XCTAssertTrue(arr, @"Failed to get a valid array.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    XCTAssertTrue([arr count] == 0, @"Found keys after deletion.");
}

/*
 *  Create a single global symmetric key.
 */
-(void) testUTSYMCRYPT_2_CreateGlobal
{
    NSLog(@"UT-SYMCRYPT: - creating the global key.");
    @autoreleasepool {
        RSI_symcrypt *sc = [RSI_symcrypt allocNewKeyForLabel:@"gkey" andType:CSSM_ALGID_SYM_GLOBAL andTag:RSI_2_symcrypt_GLOBALKEY withError:&err];
        XCTAssertNotNil(sc, @"Failed to create the global key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
        [sc release];
    }
    NSLog(@"UT-SYMCRYPT: - all secure memory should now be discarded.");    
}

/*
 *  Verify that the global key cannot be created twice.
 */
-(void) testUTSYMCRYPT_3_CreateDuplicate
{
    NSLog(@"UT-SYMCRYPT: - attempting to create the same key again, this should fail.");
    RSI_symcrypt *sc = [RSI_symcrypt allocNewKeyForLabel:@"gkey" andType:CSSM_ALGID_SYM_GLOBAL andTag:RSI_2_symcrypt_GLOBALKEY withError:&err];
    XCTAssertNil(sc, @"A new key was created when it shouldn't have been.");
    
    XCTAssertEqual(err.code, RSIErrorKeyExists, @"Failed when trying to duplicate the global key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);    
}

/*
 *  Create a second key
 */
-(void) testUTSYMCRYPT_4_CreateSecondary
{
    NSLog(@"UT-SYMCRYPT: - creating a secondary key.");
    RSI_symcrypt *sc = [[RSI_symcrypt allocNewKeyForLabel:@"gkey" andType:CSSM_ALGID_SYM_GLOBAL andTag:RSI_2_symcrypt_SECONDARYKEY withError:&err] autorelease];
    XCTAssertNotNil(sc, @"Failed to create the secondary key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-SYMCRYPT: - verifying that it can't be changed with a bad length key");
    RSI_securememory *secMem = [RSI_securememory dataWithLength:[RSI_symcrypt keySize]/2];
    BOOL ret = [sc updateKeyWithData:secMem andError:&err];
    XCTAssertFalse(ret, @"The update was allowed and shouldn't have been.");
    XCTAssertTrue(err.code == RSIErrorInvalidArgument, @"The failure was unexpected.");
    
    NSLog(@"UT-SYMCRYPT: - verifying that it can be changed with a good length key");
    secMem = [RSI_securememory dataWithLength:[RSI_symcrypt keySize]];
    int rc = SecRandomCopyBytes(kSecRandomDefault, [RSI_symcrypt keySize], [secMem mutableBytes]);
    XCTAssertTrue(rc == 0, @"Failed to generate random data for the key.");
    ret = [sc updateKeyWithData:secMem andError:&err];
    XCTAssertTrue(ret, @"Failed to update the key.");
    
    NSLog(@"UT-SYMCRYPT: - verifying that the key data was changed in the object");
    ret = [secMem isEqualToSecureData:[sc key]];
    XCTAssertTrue(ret, @"The two data buffers are not equal.");
        
    NSLog(@"UT-SYMCRYPT: - reloading the key to verify it was modified.");
    sc = nil;
    sc = [[RSI_symcrypt allocExistingKeyForType:CSSM_ALGID_SYM_GLOBAL andTag:RSI_2_symcrypt_SECONDARYKEY withError:&err] autorelease];
    XCTAssertNotNil(sc, @"Failed to find the existing key.");
    
    NSLog(@"UT-SYMCRYPT: - comparing the reloaded data to the content we used for modification");
    ret = [secMem isEqualToSecureData:[sc key]];
    XCTAssertTrue(ret, @"The two data buffers are not equal.");
}

/*
 *  Verify enumeration works
 */
-(void) testUTSYMCRYPT_5_DoEnumeration
{
    NSLog(@"UT-SYMCRYPT: - enumerating and verifying the two keys.");
    NSArray *arr = [RSI_symcrypt findAllKeyTagsForType:CSSM_ALGID_SYM_GLOBAL withError:&err];
    XCTAssertNotNil(arr, @"Failed to enumerate the two keys.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);

    XCTAssertEqual([arr count], (NSUInteger) 2, @"Found %u keys but expected 2.", [arr count]);
    
    for (int i = 0; i < [arr count]; i++) {
        NSString *tag = [arr objectAtIndex:i];
        
        BOOL oneEquals = [tag isEqualToString:RSI_2_symcrypt_GLOBALKEY] || [tag isEqualToString:RSI_2_symcrypt_SECONDARYKEY];
        XCTAssertTrue(oneEquals, @"The tag at index %u does not match.", i);
    }    
}

/*
 *  Do encrypt/decrypt with import/export.
 */
-(void) testUTSYMCRYPT_6_DoEncryptDecrypt
{
    NSLog(@"UT-SYMCRYPT: - verifying encryption works across keychains.");
    NSLog(@"UT-SYMCRYPT: - finding the first key explicitly.");
    RSI_symcrypt *sc = [RSI_symcrypt allocExistingKeyForType:CSSM_ALGID_SYM_GLOBAL andTag:RSI_2_symcrypt_GLOBALKEY withError:&err];
    XCTAssertNotNil(sc, @"Failed to find the global key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    [sc autorelease];
    
    char *TEST_STR = "The quick brown fox jumped over the lazy dog.";
    NSLog(@"UT-SYMCRYPT: - encrypting the input data --> '%s'.", TEST_STR);
    NSData *testData = [NSData dataWithBytes:TEST_STR length:strlen(TEST_STR)+1];
    NSMutableData *encrypted = [NSMutableData data];
    BOOL ret = [sc encrypt:testData intoBuffer:encrypted withError:&err];
    XCTAssertTrue(ret, @"Failed to encrypt the data.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-SYMCRYPT: - verifying encrypted data is really different.");
    ret = [testData isEqualToData:encrypted];
    XCTAssertFalse(ret, @"The encrypted data is not different as was expected.");
    
    NSLog(@"UT-SYMCRYPT: - exporting the key data and deleting the key.");
    NSString *t = [sc tag];
    RSI_securememory *k = [sc key];
    
    ret = [RSI_symcrypt deleteKeyWithType:CSSM_ALGID_SYM_GLOBAL andTag:t withError:&err];
    XCTAssertTrue(ret, @"Failed to delete the key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-SYMCRYPT: - searching for the key to make sure it is gone.");
    sc = [RSI_symcrypt allocExistingKeyForType:CSSM_ALGID_SYM_GLOBAL andTag:RSI_2_symcrypt_GLOBALKEY withError:&err];
    XCTAssertNil(sc, @"Found the key when we didn't expect to.");

    XCTAssertEqual(err.code, RSIErrorKeyNotFound, @"Failed to search for the key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-SYMCRYPT: - reimporting the key data.");
    ret = [RSI_symcrypt importKeyWithLabel:@"gkey" andType:CSSM_ALGID_SYM_GLOBAL andTag:t andValue:k withError:&err];
    XCTAssertTrue(ret, @"Failed to import the key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-SYMCRYPT: - verifying that a duplicate import produces the right error.");
    ret = [RSI_symcrypt importKeyWithLabel:@"gkey" andType:CSSM_ALGID_SYM_GLOBAL andTag:t andValue:k withError:&err];
    XCTAssertFalse(ret, @"The duplicate import succeeded and should not have.");
    XCTAssertTrue(err.code == RSIErrorKeyExists, @"The error code was not correct.  %@", [err localizedDescription]);
    
    NSLog(@"UT-SYMCRYPT: - finding the key again explicitly.");
    RSI_symcrypt *sc2 = [RSI_symcrypt allocExistingKeyForType:CSSM_ALGID_SYM_GLOBAL andTag:t withError:&err];
    XCTAssertNotNil(sc2, @"Failed to find the global key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    [sc2 autorelease];

    NSLog(@"UT-SYMCRYPT: - decrypting the data.");
    RSI_securememory *dDecrypted = [RSI_securememory data];
    ret = [sc2 decrypt:encrypted intoBuffer:dDecrypted withError:&err];
    XCTAssertTrue(ret, @"Failed to decrypt the data.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);

    NSLog(@"UT-SYMCRYPT: - comparing the data to the original.");
    XCTAssertEqual(strcmp(TEST_STR, dDecrypted.bytes), 0, @"The output buffer doesn't match the input.");

    NSLog(@"UT-SYMCRYPT: - decrypted --> '%s'", (char *) dDecrypted.bytes);
        
    NSLog(@"UT-SYMCRYPT: - modifying the last bit of the key to ensure that all are relevant.");
    unsigned char *bKey = (unsigned char *) k.mutableBytes;
    size_t len = k.length;
    bKey += (len - 1);
    unsigned char bBefore = *bKey;
    *bKey = (*bKey & 0xFE) | (!(*bKey & 0x01));
    unsigned char bAfter = *bKey;
    
    ret = [RSI_symcrypt deleteKeyWithType:CSSM_ALGID_SYM_GLOBAL andTag:t withError:&err];
    XCTAssertTrue(ret, @"Failed to delete the key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);

    sc = [RSI_symcrypt allocExistingKeyForType:CSSM_ALGID_SYM_GLOBAL andTag:RSI_2_symcrypt_GLOBALKEY withError:&err];
    XCTAssertNil(sc, @"Found the key when we didn't expect to.");
    
    XCTAssertEqual(err.code, RSIErrorKeyNotFound, @"Failed to search for the key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    ret = [RSI_symcrypt importKeyWithLabel:@"gkey" andType:CSSM_ALGID_SYM_GLOBAL andTag:t andValue:k withError:&err];
    XCTAssertTrue(ret, @"Failed to import the key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    RSI_symcrypt *sc3 = [RSI_symcrypt allocExistingKeyForType:CSSM_ALGID_SYM_GLOBAL andTag:t withError:&err];
    XCTAssertNotNil(sc3, @"Failed to find the global key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    [sc3 autorelease];
 
    NSLog(@"UT-SYMCRYPT: - decrypting the data with the modified key.");
    dDecrypted = [RSI_securememory data];
    ret = [sc3 decrypt:encrypted intoBuffer:dDecrypted withError:&err];
    XCTAssertTrue(ret, @"Failed to decrypt the data.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-SYMCRYPT: - comparing the data to the original.");
    XCTAssertTrue(strcmp(TEST_STR, dDecrypted.bytes) != 0, @"The output buffer matched the input buffer and should not have (%0x != %0x?).", bBefore, bAfter);
    
    NSLog(@"UT-SYMCRYPT: - encrypting with a random block of data.");
    RSI_securememory *mdRandom = [RSI_securememory dataWithLength:[RSI_symcrypt keySize]];
    for (int i = 0; i < [mdRandom length]; i++) {
        ((unsigned char *) [mdRandom mutableBytes])[i] = (unsigned char) (rand() & 0xFF);
    }
    
    const char *ALT_TEST = "Something wicked this way comes.";
    testData = [NSData dataWithBytes:ALT_TEST length:strlen(ALT_TEST)+1];
    ret = [RSI_symcrypt encrypt:testData withKey:mdRandom intoBuffer:encrypted withError:&err];
    XCTAssertTrue(ret, @"Failed to encrypt the data.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);

    NSLog(@"UT-SYMCRYPT: - decrypting with a random block of data.");
    ret = [RSI_symcrypt decrypt:encrypted withKey:mdRandom intoBuffer:dDecrypted withError:&err];
    XCTAssertTrue(ret, @"Failed to decrypt the data.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-SYMCRYPT: - comparing the data to the original.");
    XCTAssertEqual(strcmp(ALT_TEST, dDecrypted.bytes), 0, @"The output buffer doesn't match the input.");
    
    NSLog(@"UT-SYMCRYPT: - decrypted --> '%s'", (char *) dDecrypted.bytes);

    NSLog(@"UT-SYMCRYPT: - encryption behavior has been verified.");
}

/*
 *  Check that key renaming works.
 */
-(void) testUTSYMCRYPT_7_DoRename
{
    NSLog(@"UT-SYMCRYPT: - verifying that key renaming works as ecpected.");
    static NSString *RSI_2_SYMC_NAME1 = @"SYM_OLDNAME";
    static NSString *RSI_2_SYMC_NAME2 = @"SYM_MODIFIED";
    
    NSLog(@"UT-SYMCRYPT: - creating the key.");
    RSI_symcrypt *sc = [RSI_symcrypt allocNewKeyForLabel:RSI_2_SYMC_NAME1 andType:CSSM_ALGID_SYM_GLOBAL andTag:RSI_2_SYMC_NAME1 withError:&err];
    XCTAssertNotNil(sc, @"Failed to create the key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    char *TEST_STR = "This is some data that will be decrypted with the renamed key.";
    NSLog(@"UT-SYMCRYPT: - encrypting the input data --> '%s'.", TEST_STR);
    NSData *testData = [NSData dataWithBytes:TEST_STR length:strlen(TEST_STR)+1];
    NSMutableData *encrypted = [NSMutableData data];
    BOOL ret = [sc encrypt:testData intoBuffer:encrypted withError:&err];
    XCTAssertTrue(ret, @"Failed to encrypt the data.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-SYMCRYPT: - verifying encrypted data is really different.");
    ret = [testData isEqualToData:encrypted];
    XCTAssertFalse(ret, @"The encrypted data is not different as was expected.");

    NSLog(@"UT-SYMCRYPT: - releasing the key and renaming it.");    
    [sc release];
    sc = nil;
    ret = [RSI_symcrypt renameKeyForLabel:RSI_2_SYMC_NAME1 andType:CSSM_ALGID_SYM_GLOBAL andTag:RSI_2_SYMC_NAME1 toNewLabel:RSI_2_SYMC_NAME2 andNewTag:RSI_2_SYMC_NAME2 withError:&err];
    XCTAssertTrue(ret, @"Failed to rename the key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-SYMCRYPT: - loading the key with the new name.");
    RSI_symcrypt *scRenamed = [RSI_symcrypt allocExistingKeyForType:CSSM_ALGID_SYM_GLOBAL andTag:RSI_2_SYMC_NAME2 withError:&err];
    XCTAssertNotNil(scRenamed, @"The key was not found.  %@", [err localizedDescription]);
    [scRenamed autorelease];
    
    NSLog(@"UT-SYMCRYPT: - decrypting the data.");
    RSI_securememory *dDecrypted = [RSI_securememory data];
    ret = [scRenamed decrypt:encrypted intoBuffer:dDecrypted withError:&err];
    XCTAssertTrue(ret, @"Failed to decrypt the data.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-SYMCRYPT: - comparing the data to the original.");
    XCTAssertTrue(strcmp(TEST_STR, dDecrypted.bytes) == 0, @"The output buffer didn't match the original.");
    
    NSLog(@"UT-SYMCRYPT: - key renaming has been verified.");
}

/*
 *  Verify that deletion of an unknown key returns the right code.
 */
-(void) testUTSYMCRYPT_8_DoDeleteBadId
{
    NSLog(@"UT-SYMCRYPT: - verify that deletion of an unknown key returns a not found error.");
    BOOL ret = [RSI_symcrypt deleteKeyWithType:CSSM_ALGID_SYM_GLOBAL andTag:@"badkeyname1234" withError:&err];
    XCTAssertFalse(ret, @"The request succeeded and shouldn't have.");
    XCTAssertTrue(err.code == RSIErrorKeyNotFound, @"The error code returned was invalid (%u).  %@", err.code, [err localizedDescription]);
    NSLog(@"UT-SYMCRYPT: - the error was returned as expected.");    
}

@end
