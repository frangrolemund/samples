//
//  RSI_6_appkey_tests.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/2/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "RSI_6_appkey_tests.h"
#import "RSI_common.h"
#import "RSI_appkey.h"

static const char *RSI_6_TEST_DATA = "We live, in fact, in a world starved for solitude, silence, and private: and therefore starved for meditation and true friendship.";

@implementation RSI_6_appkey_tests
/*
 *  Generate and return a unique app key
 */
-(RSI_appkey *) uniqueAppKey
{
    BOOL ret = [RSI_appkey destroyKeychainContentsWithError:nil];
    XCTAssertTrue(ret, @"Failed to destroy the app key data.");
    
    return [[[RSI_appkey alloc] init] autorelease];    
}

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
 *  Verify that the app key is indeed stale across all its APIs.
 */
-(void) confirmStaleKey:(RSI_appkey *) appkey
{
    BOOL ret = [appkey destroyAllKeyDataWithError:&err];
    XCTAssertFalse(ret, @"Should have failed.");
    XCTAssertTrue(err.code == RSIErrorStaleVaultCreds, @"Failed to get the expected error code.");
    
    ret = [appkey authenticateWithPassword:@"foo" withError:&err];
    XCTAssertFalse(ret, @"Should have failed.");
    XCTAssertTrue(err.code == RSIErrorStaleVaultCreds, @"Failed to get the expected error code.");
    
    ret = [appkey changePasswordFrom:@"foo" toNewPassword:@"bar" withError:&err];
    XCTAssertFalse(ret, @"Should have failed.");
    XCTAssertTrue(err.code == RSIErrorStaleVaultCreds, @"Failed to get the expected error code.");
    
    ret = [appkey startKeyContextWithError:&err];
    XCTAssertFalse(ret, @"Should have failed.");
    XCTAssertTrue(err.code == RSIErrorStaleVaultCreds, @"Failed to get the expected error code.");
    
    ret = [appkey endKeyContextWithError:&err];
    XCTAssertFalse(ret, @"Should have failed.");
    XCTAssertTrue(err.code == RSIErrorStaleVaultCreds, @"Failed to get the expected error code.");
    
    ret = [appkey writeData:[NSData data] toURL:[NSURL URLWithString:@"/foo"] withError:&err];
    XCTAssertFalse(ret, @"Should have failed.");
    XCTAssertTrue(err.code == RSIErrorStaleVaultCreds, @"Failed to get the expected error code.");
    
    RSI_securememory *secMem = nil;
    ret = [appkey readURL:[NSURL URLWithString:@"/foo"] intoData:&secMem withError:&err];
    XCTAssertFalse(ret, @"Should have failed.");
    XCTAssertTrue(err.code == RSIErrorStaleVaultCreds, @"Failed to get the expected error code.");
    
    NSString *s = [appkey safeSaltedStringAsBase64:@"foobar" withError:&err];
    XCTAssertNil(s, @"Should have failed.");
    XCTAssertTrue(err.code == RSIErrorStaleVaultCreds, @"Failed to get the expected error code.");
}

/*
 *  Simple check that the app key is or is not in the keychain.
 */
-(void) verityAppKeyExistence:(BOOL) exists
{
    NSLog(@"UT-APPKEY: verifying the app key %s", exists ? "exists" : "does not exist");
    BOOL ret = [RSI_appkey isInstalled];
    XCTAssertTrue(exists == ret, @"Failed the verification test.");
}

/*
 *  Check that the salted text is still good after making app key modifications
 */
-(void) verifySaltIsFreshWithKey:(RSI_appkey *) ak andBaseline:(NSString *) baselineText andBaselineSalt:(NSString *) baselineSalt
{
    NSString *salted = [ak safeSaltedStringAsHex:baselineText withError:&err];
    XCTAssertNotNil(salted, @"Failed to get a salted string as expected.");
    XCTAssertTrue([salted isEqualToString:baselineSalt], @"The salted result has changed for some reason.");
}

/*
 *  Do simple confirmations with the app key to ensure that it behaves predictably.
 */
-(void) testUTSEAL_1_Basic
{
    static NSString *baselineText = @"The quick brown fox is here.";
    NSLog(@"UT-APPKEY: - starting basic app key testing.");
    
    NSLog(@"UT-APPKEY: - creating a new temporary app key.");
    RSI_appkey *appkey = [self uniqueAppKey];

    [self verityAppKeyExistence:NO];

    NSLog(@"UT-APPKEY: - initializing it");
    NSString *defPwd = @"foobar";
    NSString *changedPwd = @"HELLO";
    BOOL ret = [appkey authenticateWithPassword:defPwd withError:&err];
    XCTAssertTrue(ret, @"Failed to authenticate the app key.");
    NSString *saltedBaseline = [appkey safeSaltedStringAsHex:baselineText withError:&err];
    XCTAssertNotNil(saltedBaseline, @"Failed to salt the baseline text.  %@", [err localizedDescription]);
    [self verifySaltIsFreshWithKey:appkey andBaseline:baselineText andBaselineSalt:saltedBaseline];
    
    [self verityAppKeyExistence:YES];
    
    NSLog(@"UT-APPKEY: - invalidating the app key and verifying it is not usable");
    [appkey invalidateCredentials];
    [self confirmStaleKey:appkey];
    
    NSLog(@"UT-APPKEY: - recreating the key and re-authenticating with a bad password");
    appkey = [[[RSI_appkey alloc] init] autorelease];
    ret = [appkey authenticateWithPassword:@"badpwd" withError:&err];
    XCTAssertFalse(ret, @"Failed to detect the bad authentication.");
    
    NSLog(@"UT-APPKEY: - re-authenticating with the good password");
    ret = [appkey authenticateWithPassword:defPwd withError:&err];
    XCTAssertTrue(ret, @"Failed to authenticate with the app key.");
    [self verifySaltIsFreshWithKey:appkey andBaseline:baselineText andBaselineSalt:saltedBaseline];
    
    NSLog(@"UT-APPKEY: - changing the key password");
    ret = [appkey changePasswordFrom:defPwd toNewPassword:changedPwd withError:&err];
    XCTAssertTrue(ret, @"Failed to change the key password.");
    [self verifySaltIsFreshWithKey:appkey andBaseline:baselineText andBaselineSalt:saltedBaseline];
    
    NSLog(@"UT-APPKEY: - invalidating the app key and verifying it is not usable");
    [appkey invalidateCredentials];
    [self confirmStaleKey:appkey];

    NSLog(@"UT-APPKEY: - recreating the key and re-authenticating (with the old bad password)");
    appkey = [[[RSI_appkey alloc] init] autorelease];
    ret = [appkey authenticateWithPassword:defPwd withError:&err];
    XCTAssertFalse(ret, @"Failed to detect a bad password.");

    NSLog(@"UT-APPKEY: - re-authenticating (with the new password)");
    ret = [appkey authenticateWithPassword:changedPwd withError:&err];
    XCTAssertTrue(ret, @"Failed to re-authenticate.");
    [self verifySaltIsFreshWithKey:appkey andBaseline:baselineText andBaselineSalt:saltedBaseline];
    
    NSLog(@"UT-APPKEY: - writing encrypted data to disk.");
    NSData *tData = [NSData dataWithBytes:RSI_6_TEST_DATA length:strlen(RSI_6_TEST_DATA) + 1];
    NSURL *uTestFile = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    uTestFile = [uTestFile URLByAppendingPathComponent:@"appkey-encrypted.data"];
    ret = [appkey writeData:tData toURL:uTestFile withError:&err];
    XCTAssertTrue(ret, @"Failed to write the data to disk.");
    [self verifySaltIsFreshWithKey:appkey andBaseline:baselineText andBaselineSalt:saltedBaseline];
    
    NSLog(@"UT-APPKEY: - verifying the encrypted file is indeed different.");
    NSData *dEncrypted = [NSData dataWithContentsOfURL:uTestFile];
    XCTAssertNotNil(dEncrypted, @"The file could not be loaded manually.");
    XCTAssertTrue([dEncrypted length] >= [tData length], @"The encrypted file is too small.");
    int numSame = 0;
    for (NSUInteger i = 0; i < [tData length]; i++) {
        char orig = ((char *) [tData bytes])[i];
        char enc  = ((char *) [dEncrypted bytes])[i];
        if (orig == enc) {
            NSLog(@"UT-APPKEY: - notice: found equivalent characters at index %u", i);
            numSame++;
        }
    }
    if (numSame >= 5) {
        [RSI_common printBytes:tData withTitle:@"ORIGINAL STRING"];
        [RSI_common printBytes:dEncrypted withTitle:@"ENCRYPTED STRING"];
    }
    XCTAssertTrue(numSame < 5, @"There were too many similar characters in the two strings.");
    [self verifySaltIsFreshWithKey:appkey andBaseline:baselineText andBaselineSalt:saltedBaseline];
    
    NSLog(@"UT-APPKEY: - decrypting with a bad URL.");
    RSI_securememory *secMem = nil;
    ret = [appkey readURL:[NSURL URLWithString:@"/foobar"] intoData:&secMem withError:&err];
    XCTAssertFalse(ret, @"Failed to detect the bad URL.");
    
    NSLog(@"UT-APPKEY: - decrypting the file.");
    ret = [appkey readURL:uTestFile intoData:&secMem withError:&err];
    XCTAssertTrue(ret, @"Failed to decrypt the file.");
    [self verifySaltIsFreshWithKey:appkey andBaseline:baselineText andBaselineSalt:saltedBaseline];
    
    NSLog(@"UT-APPKEY: - verifying the file.");
    XCTAssertTrue([secMem length] >= [tData length], @"The decrypted file is too small.");
    int rc = memcmp(secMem.bytes, tData.bytes, [tData length]);
    XCTAssertTrue(rc == 0, @"The decrypted file is not the same as the original.");
    
    NSLog(@"UT-APPKEY: - invalidating the app key and verifying it is not usable");
    [appkey invalidateCredentials];
    [self confirmStaleKey:appkey];
    
    NSLog(@"UT-APPKEY: - deleting the app key password from outside to verify partial auth failure.");
    NSMutableDictionary *mdPwd = [NSMutableDictionary dictionary];
    [mdPwd setObject:kSecClassGenericPassword forKey:kSecClass];
    NSData *pTag = [@"app.pwd" dataUsingEncoding:NSUTF8StringEncoding];
    [mdPwd setObject:pTag forKey:kSecAttrGeneric];
    OSStatus status = 0;
    status = SecItemDelete((CFDictionaryRef) mdPwd);
    XCTAssertTrue(status == errSecSuccess, @"Failed to delete the application password.");

    NSLog(@"UT-APPKEY: - authenticating with only the encryption key remaining.");
    appkey = [[[RSI_appkey alloc] init] autorelease];
    ret = [appkey authenticateWithPassword:changedPwd withError:&err];
    XCTAssertFalse(ret, @"Authentication succeeded and shouldn't have.");
    XCTAssertTrue(err.code == RSIErrorPartialAppKey, @"Failed to get the partial app key error.");
 
    NSLog(@"UT-APPKEY: - all tests completed successfully.");
}

/*
 *  Verify that the app key encrypts correctly and is unique for each generation.
 */
-(void) testUTSEAL_2_Iteration
{
    const NSUInteger NUM_ITERATIONS = 100;
    static NSString *TEST_SALT = @"...chance favors only the prepared mind.";
    NSLog(@"UT-APPKEY: - checking for key and content differences over %u iterations", NUM_ITERATIONS);
    
    //  - for each iteration we'll save the generated app key file and the contents
    //    of the file we choose to encrypt.  The new data has to be different than
    //    every preceding version or there is potential issue with the encryption
    //    being used.  Obviously, this is only the most crude of encryption verifications
    //    but should detect glaring errors.
    NSMutableArray *maData = [NSMutableArray arrayWithCapacity:NUM_ITERATIONS];
    NSMutableArray *maSalted = [NSMutableArray arrayWithCapacity:NUM_ITERATIONS];
    NSData *tData = [NSData dataWithBytes:RSI_6_TEST_DATA length:strlen(RSI_6_TEST_DATA) + 1];
    NSURL *urlTmp = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    urlTmp = [urlTmp URLByAppendingPathComponent:@"iteration.tmp"];
    for (NSUInteger i = 0; i < NUM_ITERATIONS; i++) {
        RSI_appkey *appKey = [self uniqueAppKey];
        NSString *iterPwd = @"iteration";
        BOOL ret = [appKey authenticateWithPassword:iterPwd withError:&err];
        XCTAssertTrue(ret, @"Failed to authenticate.   %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
        
        ret = [appKey writeData:tData toURL:urlTmp withError:&err];
        XCTAssertTrue(ret, @"Failed to write the encrypted data.  %@  (%@)", [err localizedDescription], [err localizedFailureReason]);
        
        NSData *d2 = [NSData dataWithContentsOfURL:urlTmp];
        XCTAssertNotNil(d2, @"Failed to load the temp file.");
        
        NSString *salted = [appKey safeSaltedStringAsHex:TEST_SALT withError:&err];
        XCTAssertNotNil(salted, @"Failed to salt the key.  %@", [err localizedDescription]);

        XCTAssertTrue([d2 length] >= [tData length], @"ERROR: unexpected data loss in the output file.");

        ret = memcmp(d2.bytes, tData.bytes, [tData length]) ? NO : YES;
        XCTAssertFalse(ret, @"The output file was not encrypted as expected.");
        
        for (NSUInteger j = 0; j < [maData count]; j++) {
            NSData *dData = [maData objectAtIndex:j];
            ret = [d2 isEqualToData:dData];
            XCTAssertFalse(ret, @"The current enecrypted file is equivalent to the one at index %u.", j);
            
            NSString *oldSalted = [maSalted objectAtIndex:j];
            ret = [salted isEqualToString:oldSalted];
            XCTAssertFalse(ret, @"The current salted value is equivalent to the one at index %u.", j);
        }
        
        [maData addObject:d2];
        [maSalted addObject:salted];
        
        ret = [[NSFileManager defaultManager] removeItemAtURL:urlTmp error:&err];
        XCTAssertTrue(ret, @"Failed to remove the temporary file.");

        ret = [[NSFileManager defaultManager] fileExistsAtPath:[urlTmp path]];
        XCTAssertFalse(ret, @"The temporary file still exists.");
        
        RSI_appkey *akCopy = [[[RSI_appkey alloc] init] autorelease];
        XCTAssertNotNil(akCopy, @"Failed to copy the application key.");
        
        ret = [akCopy authenticateWithPassword:iterPwd withError:&err];
        XCTAssertTrue(ret, @"Failed to authenticate with the copied application key.");
        
        NSString *confirmSalted = [akCopy safeSaltedStringAsHex:TEST_SALT withError:&err];
        ret = [confirmSalted isEqualToString:salted];
        XCTAssertTrue(ret, @"Failed to retrieve the same salted value back.");
        
        //  - verify that credential invalidation works
        [appKey invalidateCredentials];
        
        RSI_securememory *secMem = nil;
        ret = [appKey readURL:urlTmp intoData:&secMem withError:&err];
        XCTAssertFalse(ret, @"Failed to verify credential invalidation.");
        XCTAssertTrue(err.code == RSIErrorStaleVaultCreds, @"Failed to verify credential invalidation.");

        ret = [akCopy destroyAllKeyDataWithError:&err];
        XCTAssertTrue(ret, @"Failed to delete the app key data.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    }
    
    NSLog(@"UT-APPKEY: - all app key iterations proved unique.");
}

@end
