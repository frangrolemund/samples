//
//  RSI_B1_vault_tests.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/31/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "RSI_B1_vault_tests.h"
#import "RealSecureImage.h"
#import "RSI_keyring.h"
#import "RSI_appkey.h"
#import "RSI_unpack.h"
#import "RSI_seal.h"
#import "RSI_error.h"
#import "RSI_secure_props.h"

static const NSUInteger RSI_B1_NUM_RAND     = 1024;
static NSString         *RSI_B1_KEY_RAND    = @"rand";
static NSString         *RSI_B1_KEY_TEXT    = @"text";
static NSString         *RSI_B1_TEXT_SAMPLE = @"The greatest happiness is to transform one's feelings into actions.";
static NSString         *RSI_B1_KEY_DATE    = @"date";
static NSString         *RSI_B1_KEY_IMG     = @"image";

@implementation RSI_B1_vault_tests

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
 *  Basic testing of vault support
 */
-(void) testUTVAULT_1_Basic
{
    NSString *basicPwd = @"foobar";
    NSString *changedPwd = @"hello";
    
    NSLog(@"UT-VAULT: - starting basic vault testing.");
    
    NSLog(@"UT-VAULT: - making sure that the vault is destroyed if it exists.");
    BOOL ret = [RealSecureImage destroyVaultWithError:&err];
    XCTAssertTrue(ret, @"Failed to destroy the vault.  %@", [err localizedDescription]);
    
    NSLog(@"UT-VAULT: - verifying the vault is indeed gone.");
    ret = [RealSecureImage hasVault];
    XCTAssertFalse(ret, @"The vault still exists and should not.");

    NSLog(@"UT-VAULT: - trying to open a non-existent vault.");
    ret = [RealSecureImage openVaultWithPassword:basicPwd andError:&err];
    XCTAssertFalse(ret, @"The vault was opened and should not have been.");
    
    NSLog(@"UT-VAULT: - initializing the vault.");
    ret = [RealSecureImage initializeVaultWithPassword:basicPwd andError:&err];
    XCTAssertTrue(ret, @"Failed to create a new vault.");
    
    NSLog(@"UT-VAULT: - verifying it is open.");
    ret = [RealSecureImage isVaultOpen];
    XCTAssertTrue(ret, @"The vault is not open and should be.");
    
    NSLog(@"UT-VAULT: - closing the vault.");
    [RealSecureImage closeVault];
    
    NSLog(@"UT-VAULT: - verifying it is closed.");
    ret = [RealSecureImage isVaultOpen];
    XCTAssertFalse(ret, @"The vault is not closed and should be.");
    
    NSLog(@"UT-VAULT: - checking that it exists.");
    ret = [RealSecureImage hasVault];
    XCTAssertTrue(ret, @"The vault doesn't exist and it should.");
    
    NSLog(@"UT-VAULT: - reopening the vault.");
    ret = [RealSecureImage openVaultWithPassword:basicPwd andError:&err];
    XCTAssertTrue(ret, @"Failed to reopen the vault.  %@", [err localizedDescription]);
    
    NSLog(@"UT-VAULT: - verifying that the vault is now open.");
    ret = [RealSecureImage isVaultOpen];
    XCTAssertTrue(ret, @"The vault wasn't open as expected."); 
    
    NSLog(@"UT-VAULT: - changing the vault password.");
    ret = [RealSecureImage changeVaultPassword:basicPwd toPassword:changedPwd andError:&err];
    XCTAssertTrue(ret, @"Failed to change the vault password.  %@", [err localizedDescription]);
    
    NSLog(@"UT-VAULT: - verifying that the vault is still open.");
    ret = [RealSecureImage isVaultOpen];
    XCTAssertTrue(ret, @"The vault wasn't open as expected.");
    
    NSLog(@"UT-VAULT: - closing the vault.");
    [RealSecureImage closeVault];
    
    NSLog(@"UT-VAULT: - verifying that the vault is now closed.");
    ret = [RealSecureImage isVaultOpen];
    XCTAssertFalse(ret, @"The vault wasn't closed as expcted.");
    
    NSLog(@"UT-VAULT: - verifying that the old password fails.");
    ret = [RealSecureImage openVaultWithPassword:basicPwd andError:&err];
    XCTAssertFalse(ret, @"The old password didn't fail as expected.");
    
    NSLog(@"UT-VAULT: - verifying that the new password succeeds.");
    ret = [RealSecureImage openVaultWithPassword:changedPwd andError:&err];
    XCTAssertTrue(ret, @"The new password didn't succeed as expected.");
    
    NSLog(@"UT-VAULT: - verifying that the vault is now open.");
    ret = [RealSecureImage isVaultOpen];
    XCTAssertTrue(ret, @"The vault wasn't open as expected.");
    
    static const NSUInteger RSI_B1_TO_ENCRYPT = 10;
    NSLog(@"UT-VAULT: - encrypting %u files in the vault.", RSI_B1_TO_ENCRYPT);
    NSMutableArray *maTestData = [NSMutableArray array];
    for (NSUInteger i = 0; i < RSI_B1_TO_ENCRYPT; i++) {
        @autoreleasepool {
            NSMutableData *dTest = [NSMutableData dataWithLength:2048];
            SecRandomCopyBytes(kSecRandomDefault, [dTest length], dTest.mutableBytes);
            [maTestData addObject:dTest];
            
            if (i > 0) {
                NSMutableData *dLast = [maTestData objectAtIndex:i-1];
                BOOL same = [dTest isEqualToData:dLast];
                XCTAssertFalse(same, @"The two test buffers are the same and they shouldn't be.");
            }
    
            NSString *sFile = [NSString stringWithFormat:@"rsi-b1-vault-%u.dat", i];
    
            NSLog(@"UT-VAULT: - generating %@", sFile);
            BOOL ret = [RealSecureImage writeVaultData:dTest toFile:sFile withError:&err];
            XCTAssertTrue(ret, @"Failed to write the vault data securely.  %@", [err localizedDescription]);
        }
    }

    NSLog(@"UT-VAULT: - verifying %u files in the vault are encrypted.", RSI_B1_TO_ENCRYPT);
    for (NSUInteger i = 0; i < RSI_B1_TO_ENCRYPT; i++) {
        @autoreleasepool {
            NSString *sFile = [NSString stringWithFormat:@"rsi-b1-vault-%u.dat", i];
            
            NSLog(@"UT-VAULT: - verifying %@", sFile);
            NSMutableData *mdOrig = [maTestData objectAtIndex:i];

            NSURL *uFile = [RealSecureImage absoluteURLForVaultFile:sFile withError:&err];
            XCTAssertNotNil(uFile, @"Failed to get a vault filename.");
            NSData *dEncrypted = [NSData dataWithContentsOfURL:uFile];
            XCTAssertNotNil(dEncrypted, @"Failed to load the encrypted file.");
            XCTAssertTrue([dEncrypted length] >= [mdOrig length], @"The encrypted file is not the right size.");
            BOOL ret = [mdOrig isEqualToData:[NSData dataWithBytesNoCopy:(void *) dEncrypted.bytes length:[mdOrig length] freeWhenDone:NO]];
            XCTAssertFalse(ret, @"The encrypted is somehow equal to the orignal.");
        }
    }

    NSLog(@"UT-VAULT: - decrypting %u files from the vault.", RSI_B1_TO_ENCRYPT);
    for (NSUInteger i = 0; i < RSI_B1_TO_ENCRYPT; i++) {
        @autoreleasepool {
            NSString *sFile = [NSString stringWithFormat:@"rsi-b1-vault-%u.dat", i];
            
            NSLog(@"UT-VAULT: - analyzing %@", sFile);
            RSISecureData *secD = nil;
            BOOL ret = [RealSecureImage readVaultFile:sFile intoData:&secD withError:&err];
            XCTAssertTrue(ret, @"Failed to read the vault URL.  %@", [err localizedDescription]);
            XCTAssertNotNil(secD, @"The returned file data was null.");
            
            NSMutableData *mdOrig = [maTestData objectAtIndex:i];
            ret = [mdOrig isEqualToData:[secD rawData]];
            XCTAssertTrue(ret, @"The decrypted content is not equal to the original content.");
        }
    }

    NSLog(@"UT-VAULT: - destroying the vault");
    ret = [RealSecureImage destroyVaultWithError:&err];
    XCTAssertTrue(ret, @"Failed to destroy the vault.  %@", [err localizedDescription]);
    
    NSLog(@"UT-VAULT: - verifying the vault is now gone");
    ret = [RealSecureImage hasVault];
    XCTAssertFalse(ret, @"The vault exists and should not.");
    
    NSLog(@"UT-VAULT: - all tests completed successfully.");
}

/*
 *  Generate an appropriate seal image.
 */
-(UIImage *) createSealImage
{
    CGSize szSeal = CGSizeMake(256.0f, 256.0f);
    UIGraphicsBeginImageContext(szSeal);
    
    CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), [[UIColor colorWithRed:(CGFloat)(rand() % 255)/255.0f green:(CGFloat)(rand() % 255)/255.0f blue:(CGFloat)(rand() % 255)/255.0f alpha:1.0f]CGColor]);
    CGContextFillRect(UIGraphicsGetCurrentContext(), CGRectMake(0.0f, 0.0f, szSeal.width, szSeal.height));
    
    CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), [[UIColor colorWithRed:(CGFloat)(rand() % 255)/255.0f green:(CGFloat)(rand() % 255)/255.0f blue:(CGFloat)(rand() % 255)/255.0f alpha:1.0f]CGColor]);
    CGContextFillEllipseInRect(UIGraphicsGetCurrentContext(), CGRectMake(szSeal.width/4.0f, szSeal.height/4.0f, szSeal.width/2.0f, szSeal.height/2.0f));
    
    UIImage *imgSeal = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    XCTAssertNotNil(imgSeal, @"Failed to create the seal image.");
    return imgSeal;
}

/*
 *  Compare the contents of the two seal id lists.
 */
-(void) compareSealLists:(NSArray *) arr1 andArray2:(NSArray *) arr2
{
    XCTAssertTrue([arr1 count] == [arr2 count], @"The count of seals is wrong.");
 
    for (NSUInteger i = 0; i < [arr1 count]; i++) {
        BOOL found = NO;
        NSString *origName = [arr1 objectAtIndex:i];
        for (NSUInteger j = 0; j < [arr2 count]; j++) {
            if ([origName isEqualToString:[arr2 objectAtIndex:j]]) {
                NSLog(@"UT-VAULT: - confirmed %@", origName);
                found = YES;
                break;
            }
        }
        XCTAssertTrue(found, @"Failed to find the seal %@", origName);
    }
}

/*
 *  Return the secure image hash for the seal.
 */
-(RSISecureData *) sealImageHash:(RSISecureSeal *) seal
{
    NSData *dSealImageNow = [seal originalSealImageWithError:&err];
    XCTAssertNotNil(dSealImageNow, @"Failed to retrieve the current seal image.");
    RSISecureData *sdHash = [RealSecureImage hashImageData:dSealImageNow withError:&err];
    XCTAssertNotNil(sdHash, @"Failed to hash the image data.");
    return sdHash;
}

/*
 *  Return the modification date of the seal file.
 */
-(NSDate *) sealModificationDate:(RSISecureSeal *) seal
{
    NSURL *u = [seal onDiskFile];
    XCTAssertNotNil(u, @"Failed to get the on-disk filename.");
    
    NSDictionary *dictFile = [[NSFileManager defaultManager] attributesOfItemAtPath:[u path] error:nil];
    XCTAssertNotNil(dictFile, @"Failed to get file attributes");
    
    NSDate *dt = (NSDate *) [dictFile objectForKey:NSFileModificationDate];
    XCTAssertNotNil(dt, @"Failed to retrieve the file modification date.");
    
    return dt;
}

/*
 *  Seal management testing.
 */
-(void) testUTVAULT_2_Seal
{
    NSString *basicPwd = @"sealmgmt";
    
    NSLog(@"UT-VAULT: - starting seal management testing.");
    
    NSLog(@"UT-VAULT: - building a new seal vault.");
    BOOL ret = [RealSecureImage initializeVaultWithPassword:basicPwd andError:&err];
    XCTAssertTrue(ret, @"Failed to create a new vault.");
    ret = [RealSecureImage hasVault];
    XCTAssertTrue(ret, @"The vault doesn't exist as expected.");

    NSLog(@"UT-VAULT: - creating the testing seals.");
    NSMutableArray *maSeals = [NSMutableArray array];
    NSMutableArray *maSafeIds = [NSMutableArray array];
    static const NSUInteger RSI_B1_NUM_SEALS = 10;
    for (NSUInteger i = 0; i < RSI_B1_NUM_SEALS; i++) {
        UIImage *img = [self createSealImage];
        
        NSString *sid = [RealSecureImage createSealWithImage:img andColor:RSSC_DEFAULT andError:&err];
        XCTAssertNotNil(sid, @"Failed to build the seal at index %u.  %@", i, [err localizedDescription]);
        
        RSISecureSeal *ss = [RealSecureImage sealForId:sid andError:&err];
        XCTAssertNotNil(ss, @"Failed to allocate the seal for id %@.  %@", sid, [err localizedDescription]);
        ret = [ss isOwned];
        XCTAssertTrue(ret, @"The seal is not owned and it should be.");
        
        UIImage *imgSafe = [ss safeSealImageWithError:&err];
        XCTAssertNotNil(imgSafe, @"Failed to generate a safe seal image.");
        
        NSString *sFile = [NSString stringWithFormat:@"safeimg-%u.jpg", i];
        NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
        u = [u URLByAppendingPathComponent:sFile];
        XCTAssertNotNil(u, @"Failed to generate the safe image name.");
        
        NSData *dSafe = UIImageJPEGRepresentation(imgSafe, 1.0f);
        XCTAssertNotNil(dSafe, @"The JPEG could not be generated.");
        ret = [dSafe writeToURL:u atomically:YES];
        XCTAssertTrue(ret, @"The safe image could not be written to disk.");
        
        NSLog(@"UT-VAULT: - created seal %@", sid);
        
        [maSeals addObject:sid];
        
        NSString *safeId = [ss safeSealIdWithError:&err];
        XCTAssertNotNil(safeId, @"Failed to generate a safe seal id.");
        XCTAssertFalse([sid isEqualToString:safeId], @"The safe id and the seal id are the same and shouldn't be.");
        for (int j = 0; j < [maSafeIds count]; j++) {
            NSString *oldSafeId = [maSafeIds objectAtIndex:j];
            XCTAssertFalse([oldSafeId isEqualToString:safeId], @"The new safe id is equal to a prior one.");
        }
        [maSafeIds addObject:safeId];
        NSLog(@"UT-VAULT:   (safe id is %@)", safeId);
    }
    
    NSLog(@"UT-VAULT: - forcing the creation of the external files sub-directory");
    NSData *d = [@"Hello World" dataUsingEncoding:NSASCIIStringEncoding];
    ret = [RealSecureImage writeVaultData:d toFile:@"forced-created" withError:&err];
    XCTAssertTrue(ret, @"Failed to write the file.");
    
    NSLog(@"UT-VAULT: - closing the vault");
    [RealSecureImage closeVault];
    
    NSLog(@"UT-VAULT: - verifying we can't get the seal list");
    NSArray *allSeals = [RealSecureImage availableSealsWithError:&err];
    XCTAssertNil(allSeals, @"The seals were retrieved but they should not have been.");
    
    NSLog(@"UT-VAULT: - verifying we can't get a safe seal list");
    NSDictionary *dSafeTmp = [RealSecureImage safeSealIndexWithError:&err];
    XCTAssertNil(dSafeTmp, @"The safe list was returned and shouldn't have been.");
    
    NSLog(@"UT-VAULT: - opening the vault and confirming the seal list");
    ret = [RealSecureImage openVaultWithPassword:basicPwd andError:&err];
    XCTAssertTrue(ret, @"Failed to open the vault.");
    
    NSLog(@"UT-VAULT: - verifying that the vault will return a lookup map of safe seals");
    NSDictionary *dSafeMap = [RealSecureImage safeSealIndexWithError:&err];
    XCTAssertNotNil(dSafeMap, @"Failed to retrieve a safe seal id map.  %@", [err localizedDescription]);
    XCTAssertTrue([dSafeMap count] == [maSeals count] && [dSafeMap count] == [maSafeIds count], @"Failed to get the expected number of safe ids in the map.");
    for (NSUInteger i = 0; i  < [maSafeIds count]; i++) {
        NSString *ssid = [maSafeIds objectAtIndex:i];
        NSString *sid  = [dSafeMap objectForKey:ssid];
        XCTAssertNotNil(sid, @"Failed to retrieve a sid from the safe map.");
        
        NSString *oldSid = [maSeals objectAtIndex:i];
        XCTAssertTrue([sid isEqualToString:oldSid], @"The sids do not match for index item %u", i);
    }
 
    allSeals = [RealSecureImage availableSealsWithError:&err];
    XCTAssertNotNil(allSeals, @"Failed to get a seal list.");
    
    [self compareSealLists:maSeals andArray2:allSeals];
    
    NSLog(@"UT-VAULT: - verifying reloaded seals produce the same safe ids.");
    for (int i = 0; i < RSI_B1_NUM_SEALS; i++) {
        NSString *sid = [allSeals objectAtIndex: i];
        RSISecureSeal *ssTmp = [RealSecureImage sealForId:sid andError:&err];
        XCTAssertNotNil(ssTmp, @"Failed to load the prior seal.");
        NSString *curSalted = [ssTmp safeSealIdWithError:&err];
        XCTAssertNotNil(curSalted, @"Failed to get the safe id.");
        
        NSString *oldSalted = [maSafeIds objectAtIndex:i];
        XCTAssertTrue([curSalted isEqualToString:oldSalted], @"The salted values are different and shouldn't be at index %d.", i);
        NSLog(@"UT-VAULT: - confirmed %@", sid);
    }
    
    NSLog(@"UT-VAULT: - closing the vault and deleting the keyring through external means");
    [RealSecureImage closeVault];
    ret = [RSI_keyring deleteAllKeyringsWithError:&err];
    XCTAssertTrue(ret, @"Failed to delete all the keyrings.  %@", [err localizedDescription]);
    
    NSLog(@"UT-VAULT: - verifying that the on-disk content can recreate the vault.");
    ret = [RealSecureImage openVaultWithPassword:basicPwd andError:&err];
    XCTAssertTrue(ret, @"The vault could not be reopened.  %@", [err localizedDescription]);
    
    NSArray *allSealsV2 = [RealSecureImage availableSealsWithError:&err];
    XCTAssertNotNil(allSealsV2, @"Failed to get a seal list.");
    [self compareSealLists:maSeals andArray2:allSealsV2];
    
    NSLog(@"UT-VAULT: - deleting seals from the vault individually.");
    for (NSUInteger i = 0; i < [allSealsV2 count]; i+=2) {
        NSString *sid = [allSealsV2 objectAtIndex:i];
        ret = [RealSecureImage deleteSealForId:sid andError:&err];
        XCTAssertTrue(ret, @"Failed to delete the seal at index %u.  %@", i, [err localizedDescription]);
    }
    
    NSLog(@"UT-VAULT: - verifying that half the seals are now gone.");
    for (NSUInteger i = 0; i < [allSealsV2 count]; i++) {
        if (i % 2 == 0) {
            ret = ![RealSecureImage sealExists:[allSealsV2 objectAtIndex:i] withError:&err];
        }
        else {
            ret = [RealSecureImage sealExists:[allSealsV2 objectAtIndex:i] withError:&err];
        }
        XCTAssertTrue(ret, @"Failed to verify the seal at index %u.  %@", i, [err localizedDescription]);
    }
    
    NSLog(@"UT-VAULT: - closing the vault and deleting the app key and keychain seals through external means");
    [RealSecureImage closeVault];
    ret = [RSI_appkey destroyKeychainContentsWithError:&err];
    XCTAssertTrue(ret, @"Failed to destroy the app key.");
    
    ret = [RSI_seal deleteAllSealsWithError:&err];
    XCTAssertTrue(ret, @"Failed to destroy the keychain seals.");
    
    NSLog(@"UT-VAULT: - verifying the app key is indeed gone.");
    ret = [RSI_appkey isInstalled];
    XCTAssertFalse(ret, @"The app key still exists and should not.");
    
    NSLog(@"UT-VAULT: - creating a new app key manually");
    RSI_appkey *ak = [[[RSI_appkey alloc] init] autorelease];
    ret = [ak authenticateWithPassword:basicPwd withError:&err];
    XCTAssertTrue(ret, @"Failed to create a new app key.");
    
    NSLog(@"UT-VAULT: - verifying the app key is now there.");
    ret = [RSI_appkey isInstalled];
    XCTAssertTrue(ret, @"The app key still exists and should not.");
    
    NSLog(@"UT-VAULT: - opening the vault to make sure that the old seals cannot be read.");
    ret = [RealSecureImage openVaultWithPassword:basicPwd andError:&err];
    XCTAssertTrue(ret, @"Failed to reopen the vault with the new app key.");
    
    NSLog(@"UT-VAULT: - verifying there are no old seals.");
    allSealsV2 = [RealSecureImage availableSealsWithError:&err];
    XCTAssertTrue([allSealsV2 count] == 0, @"There are still seals in the vault.");
    
    NSLog(@"UT-VAULT: - adding a single new seal.");    
    UIImage *img = [self createSealImage];
    
    NSString *sid = [RealSecureImage createSealWithImage:img andColor:RSSC_STD_BLUE andError:&err];
    XCTAssertNotNil(sid, @"Failed to build the seal.  %@", [err localizedDescription]);
    
    RSISecureSeal *ss = [RealSecureImage sealForId:sid andError:&err];
    XCTAssertNotNil(ss, @"Failed to allocate the seal for id %@.  %@", sid, [err localizedDescription]);    
    
    NSLog(@"UT-VAULT: - verifying there is now one seal in the vault.");
    allSealsV2 = [RealSecureImage availableSealsWithError:&err];
    XCTAssertTrue([allSealsV2 count] == 1, @"The expected number of seals didn't exist.");
    
    NSLog(@"UT-VAULT: - verifying the default color was set.");
    RSISecureSeal_Color_t color = [ss colorWithError:&err];
    XCTAssertTrue(color == RSSC_STD_BLUE, @"The color was not set correctly.  %@", err ? [err localizedDescription] : @"No error returned.");
    
    NSLog(@"UT-VAULT: - verifying that the on-disk content is modified during attribute changes.");
    RSISecureData *sdBaselineHash = [self sealImageHash:ss];
    NSDate        *dtBaseline = [self sealModificationDate:ss];
    
    ret = [ss isInvalidatedWithError:&err];
    XCTAssertFalse(ret, @"The seal is invalidated and should not have been.");
    XCTAssertNil(err, @"The error code was set and should not have been.");
    
    sleep(1);           //  ensure the modification date changes.

    NSLog(@"UT-VAULT: - changing the seal color and comparing its file information.");    
    ret = [ss setColor:RSSC_STD_ORANGE withError:&err];
    XCTAssertTrue(ret, @"Failed to change the seal color.");
    
    RSISecureData *sdAFterColorHash = [self sealImageHash:ss];
    NSDate        *dtAfterColor = [self sealModificationDate:ss];
    
    XCTAssertTrue([sdBaselineHash.rawData isEqualToData:sdAFterColorHash.rawData], @"The hashes are not equal as expected.");
    XCTAssertTrue([dtBaseline compare:dtAfterColor] == NSOrderedAscending, @"The modification dates are not ascending.");
    
    ret = [ss isInvalidatedWithError:&err];
    XCTAssertFalse(ret, @"The seal is invalidated and should not have been.");
    XCTAssertNil(err, @"The error code was set and should not have been.");    
    
    sleep(1);           //  ensure the modification date changes.
    
    NSLog(@"UT-VAULT: - changing the seal self-destruct timer and comparing its file information.");
    ret = [ss setSelfDestruct:15 withError:&err];
    XCTAssertTrue(ret, @"Failed to change the seal self destruct timer.");
    
    RSISecureData *sdAfterSelfDestruct = [self sealImageHash:ss];
    NSDate        *dtAfterSelfDestruct = [self sealModificationDate:ss];
    
    XCTAssertTrue([sdBaselineHash.rawData isEqualToData:sdAfterSelfDestruct.rawData], @"The hashes are not equal as expected.");
    XCTAssertTrue([dtAfterColor compare:dtAfterSelfDestruct] == NSOrderedAscending, @"The modification dates are not ascending.");
    
    ret = [ss isInvalidatedWithError:&err];
    XCTAssertFalse(ret, @"The seal is invalidated and should not have been.");
    XCTAssertNil(err, @"The error code was set and should not have been.");
        
    sleep(1);           //  ensure the modification date changes.
        
    NSLog(@"UT-VAULT: - invalidating the seal and comparing its file information.");
    ret = [ss invalidateUnconditionallyWithError:&err];
    XCTAssertTrue(ret, @"Failed to invalidate the seal");
    
    RSISecureData *sdAfterInvalidateHash = [self sealImageHash:ss];
    NSDate        *dtAfterInvalidate = [self sealModificationDate:ss];
    
    XCTAssertFalse([sdAFterColorHash.rawData isEqualToData:sdAfterInvalidateHash.rawData], @"The hashes are not different as expected.");
    XCTAssertTrue([dtAfterSelfDestruct compare:dtAfterInvalidate] == NSOrderedAscending, @"The modification dates are not ascending.");
    
    ret = [ss isInvalidatedWithError:&err];
    XCTAssertTrue(ret, @"The seal was not invalidated and should have been.");
    XCTAssertNil(err, @"The error code was set and should not have been.");
    
    NSLog(@"UT-VAULT: - invalidating the seal again to ensure it is a NOOP.");
    ret = [ss invalidateUnconditionallyWithError:&err];
    XCTAssertTrue(ret, @"Failed to invalidate the seal.");
    
    RSISecureData *sdAfterInvalidateHash2 = [self sealImageHash:ss];
    NSDate        *dtAfterInvalidate2 = [self sealModificationDate:ss];
    
    XCTAssertTrue([sdAfterInvalidateHash2.rawData isEqualToData:sdAfterInvalidateHash.rawData], @"The hashes are not the same as expected.");
    XCTAssertTrue([dtAfterInvalidate2 isEqualToDate:dtAfterInvalidate], @"The persistent file was changed and shouldn't have been.");
    NSLog(@"UT-VAULT: - all tests completed successfully.");
}

/*
 *  Verify that snapshot invalidation flags work through this codepath.
 */
-(void) testUTVAULT_3_SealSnapshot
{
    NSLog(@"UT-VAULT: - starting seal snapshot revocation testing.");
    
    NSString *pwd = @"~";
    NSLog(@"UT-VAULT: - building a new seal vault.");
    BOOL ret = [RealSecureImage initializeVaultWithPassword:pwd andError:&err];
    XCTAssertTrue(ret, @"Failed to create a new vault.");
    ret = [RealSecureImage hasVault];
    XCTAssertTrue(ret, @"The vault doesn't exist as expected.");
    
    NSLog(@"UT-VAULT: - adding a single new seal for snapshot checking.");
    UIImage *img = [self createSealImage];
    NSString *sid = [RealSecureImage createSealWithImage:img andColor:RSSC_STD_GREEN andError:&err];
    XCTAssertNotNil(sid, @"Failed to build the seal.  %@", [err localizedDescription]);
    RSISecureSeal *ss = [RealSecureImage sealForId:sid andError:&err];
    XCTAssertNotNil(ss, @"Failed to allocate the seal for id %@.  %@", sid, [err localizedDescription]);
    
    NSLog(@"UT-VAULT: - exporting the seal without the flag.");
    NSData *dWithoutSnap = [ss exportWithPassword:pwd andError:&err];
    XCTAssertNotNil(dWithoutSnap, @"Failed to export the seal without the flag.  %@", [err localizedDescription]);
    
    NSLog(@"UT-VAULT: - verifying snapshot flag is not set.");
    ret = [ss isInvalidateOnSnapshotEnabledWithError:&err];
    XCTAssertFalse(ret, @"The flag was set and shouldn't have been.");
    XCTAssertNil(err, @"The expecte error code was not returned.");
    
    NSLog(@"UT-VAULT: - adding the snapshot flag.");
    ret = [ss setInvalidateOnSnapshot:YES withError:&err];
    XCTAssertTrue(ret, @"Failed to set the invalidation behavior on the seal.");
    ret = [ss isInvalidateOnSnapshotEnabledWithError:&err];
    XCTAssertTrue(ret, @"The flag wasn't set and should have been.");
    NSData *dWithSnap = [ss exportWithPassword:@"~" andError:&err];
    XCTAssertNotNil(dWithSnap, @"Failed to export the seal with the flag.  %@", [err localizedDescription]);
    
    NSLog(@"UT-VAULT: - deleting the producer seal.");
    ret = [RealSecureImage deleteSealForId:sid andError:&err];
    XCTAssertTrue(ret, @"Failed to delete the seal.");
    
    NSLog(@"UT-VAULT: - importing the non-snapshot consumer seal.");
    ss = [RealSecureImage importSeal:dWithoutSnap usingPassword:pwd withError:&err];
    XCTAssertNotNil(ss, @"Failed to import the seal.  %@", [err localizedDescription]);
    ret = [ss isInvalidateOnSnapshotEnabledWithError:&err];
    XCTAssertFalse(ret, @"The flag was set and shouldn't have been.");
    NSLog(@"UT-VAULT: - trying to invalidate with snapshot, should fail.");
    ret = [ss invalidateForSnapshotWithError:&err];
    XCTAssertFalse(ret, @"The invalidation succeeded and should not have.");
    ret = [ss isInvalidatedWithError:&err];
    XCTAssertFalse(ret, @"The seal should not be invalidated.");
    
    //... we're not going to delete the consumer seal to ensure that I can
    //    update the seal reliably with a re-import instead of a delete first.
    
    NSLog(@"UT-VAULT: - importing the snapshot consumer seal.");
    ss = [RealSecureImage importSeal:dWithSnap usingPassword:pwd withError:&err];
    XCTAssertNotNil(ss, @"Failed to import the seal.  %@", [err localizedDescription]);
    ret = [ss isInvalidateOnSnapshotEnabledWithError:&err];
    XCTAssertTrue(ret, @"The flag wasn't set and should have been.");
    NSLog(@"UT-VAULT: - trying to invalidate with snapshot.");
    ret = [ss invalidateForSnapshotWithError:&err];
    XCTAssertTrue(ret, @"The invalidation failed.  %@", [err localizedDescription]);
    ret = [ss isInvalidatedWithError:&err];
    XCTAssertTrue(ret, @"The seal is not invalidated.  %@", [err localizedDescription]);
    
    NSLog(@"UT-VAULT: - all tests completed successfully.");
}

/*
 *  Return an image that can be used for packing secure content.
 */
-(UIImage *) imageForPacking
{
    CGSize sz = CGSizeMake(1024, 1024);
    UIGraphicsBeginImageContextWithOptions(sz, YES, 1.0f);
    [[UIColor blueColor] setFill];
    UIRectFill(CGRectMake(0.0f, 0.0f, sz.width, sz.height));
    UIImage *imgRet = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return imgRet;
}

/*
 *  Create and return a dictionary for packing testing.
 */
-(NSDictionary *) dictionaryForPackTesting
{
    NSMutableDictionary *mdRet = [NSMutableDictionary dictionary];
    NSMutableData *mdRandom    = [NSMutableData dataWithLength:RSI_B1_NUM_RAND];
    int ret = SecRandomCopyBytes(kSecRandomDefault, RSI_B1_NUM_RAND, (uint8_t *) mdRandom.mutableBytes);
    XCTAssertEqual(ret, 0, @"The random generation failed.");
    [mdRet setObject:mdRandom forKey:RSI_B1_KEY_RAND];
    [mdRet setObject:RSI_B1_TEXT_SAMPLE forKey:RSI_B1_KEY_TEXT];
    [mdRet setObject:[NSDate date] forKey:RSI_B1_KEY_DATE];
    [mdRet setObject:[self imageForPacking] forKey:RSI_B1_KEY_IMG];
    return mdRet;
}

/*
 *  Check that the two dictionaries have equal content or close enough.
 */
-(BOOL) isPackDictionary:(NSDictionary *) dictToCompare equalToOriginal:(NSDictionary *) dictOrig
{
    XCTAssertEqual(dictToCompare.count, dictOrig.count, @"The two dictionaries have different counts of items.");
    
    NSData *dRandComp = [dictToCompare objectForKey:RSI_B1_KEY_RAND];
    NSData *dRandOrig = [dictOrig objectForKey:RSI_B1_KEY_RAND];
    BOOL ret = [dRandComp isEqualToData:dRandOrig];
    XCTAssertTrue(ret, @"The two random buffers are not the same.");
    
    NSString *sample = [dictToCompare objectForKey:RSI_B1_KEY_TEXT];
    ret = [sample isEqualToString:RSI_B1_TEXT_SAMPLE];
    XCTAssertTrue(ret, @"The sample text is not identical.");
    
    NSDate *dateComp = [dictToCompare objectForKey:RSI_B1_KEY_DATE];
    NSDate *dateOrig = [dictOrig objectForKey:RSI_B1_KEY_DATE];
    ret = [dateComp isEqualToDate:dateOrig];
    XCTAssertTrue(ret, @"The dates are not equal.");
    
    UIImage *imgComp = [dictToCompare objectForKey:RSI_B1_KEY_IMG];
    UIImage *imgOrig = [dictOrig objectForKey:RSI_B1_KEY_IMG];
    
    XCTAssertNotNil(imgComp, @"There is no image in the comparison dictionary.");
    XCTAssertEqual((int) imgComp.size.width, (int) imgOrig.size.width, @"The image widths are not equal.");
    XCTAssertEqual((int) imgComp.size.height, (int) imgOrig.size.height, @"The image heights are not equal.");
    return YES;
}

/*
 *  Verify that seal-packed messages can be identified and decrypted accurately.
 */
-(void) testUTVAULT_4_SealPacking
{
    NSLog(@"UT-VAULT: - starting seal packing testing.");
    
    NSString *pwd = @"~";
    NSLog(@"UT-VAULT: - building a new seal vault.");
    BOOL ret = [RealSecureImage initializeVaultWithPassword:pwd andError:&err];
    XCTAssertTrue(ret, @"Failed to create a new vault.");
    ret = [RealSecureImage hasVault];
    XCTAssertTrue(ret, @"The vault doesn't exist as expected.");
    
    NSLog(@"UT-VAULT: - creating the testing seals.");
    NSMutableArray *maSeals = [NSMutableArray array];
    static const NSUInteger RSI_B1_NUM_SEALS = 10;
    for (NSUInteger i = 0; i < RSI_B1_NUM_SEALS; i++) {
        UIImage *img = [self createSealImage];
        
        NSString *sid = [RealSecureImage createSealWithImage:img andColor:RSSC_DEFAULT andError:&err];
        XCTAssertNotNil(sid, @"Failed to build the seal at index %u.  %@", i, [err localizedDescription]);
        
        NSLog(@"UT-VAULT: - created seal %@", sid);
        
        [maSeals addObject:sid];
    }
    
    NSLog(@"UT-VAULT: - packing the test content");
    NSMutableArray *maToTest = [NSMutableArray array];
    NSMutableArray *maPacked = [NSMutableArray array];
    NSMutableArray *maHashes = [NSMutableArray array];
    for (NSUInteger i = 0; i < RSI_B1_NUM_SEALS; i++) {
        NSDictionary    *dict = [self dictionaryForPackTesting];
        [maToTest addObject:dict];
        NSString        *sid  = [maSeals objectAtIndex:i];
        RSISecureSeal   *seal = [RealSecureImage sealForId:sid andError:&err];
        XCTAssertNotNil(seal, @"Failed to retrieve the new seal at index %u.  %@", i, [err localizedDescription]);
        
        NSData *dPacked = [seal packRoleBasedMessage:dict intoImage:[self imageForPacking] withError:&err];
        XCTAssertNotNil(dPacked, @"Failed to pack the message at index %u. %@", i, [err localizedDescription]);
        UIImage *img = [UIImage imageWithData:dPacked];
        XCTAssertNotNil(img, @"Unable to get an image from the packed file.");
        [maPacked addObject:dPacked];
        NSLog(@"UT-VAULT: - packed item %u", i + 1);
        
        NSString *hash = [RealSecureImage hashForPackedContent:dPacked withError:&err];
        XCTAssertNotNil(hash, @"Failed to hash the content at index %u.  %@", i, [err localizedDescription]);
        [maHashes addObject:hash];
    }
    
    NSLog(@"UT-VAULT: - verifying the seals can decrypt their own content.");
    for (NSUInteger i = 0; i < RSI_B1_NUM_SEALS; i++) {
        NSDictionary *dict  = [maToTest objectAtIndex:i];
        NSString     *sid   = [maSeals objectAtIndex:i];
        NSData       *dTest = [maPacked objectAtIndex:i];
        RSISecureSeal *seal = [RealSecureImage sealForId:sid andError:&err];
        XCTAssertNotNil(seal, @"Failed to retrieve the seal.");
        
        NSDictionary *dUnpacked = [seal unpackAndDecryptMessage:dTest withError:&err];
        XCTAssertNotNil(dUnpacked, @"Failed to unpack the message at index %u.  %@", i, [err localizedDescription]);
        
        BOOL ret = [self isPackDictionary:dUnpacked equalToOriginal:dict];
        XCTAssertTrue(ret, @"The unpacked dictionary is not equal to the original.");
        
        NSString *hash = [seal hashPackedMessage:dTest];
        NSString *sOrigHash = [maHashes objectAtIndex:i];
        XCTAssertTrue([hash isEqualToString:sOrigHash], @"The hashes are not equal.");
        
        NSLog(@"UT-VAULT: - data is valid at %u", i + 1);
    }
    
    NSLog(@"UT-VAULT: - verifying that the size unpack API works.");
    ret = [RealSecureImage hasEnoughDataForSealIdentification:nil];
    XCTAssertTrue(ret, @"The check failed to respond for a nil value.");
    NSMutableData *mdRand = [NSMutableData dataWithLength:256];
    SecRandomCopyBytes(kSecRandomDefault, mdRand.length, (uint8_t *) mdRand.mutableBytes);
    ret = [RealSecureImage hasEnoughDataForSealIdentification:mdRand];
    XCTAssertTrue(ret, @"The check failed to respond for invalid bytes.");
 
    NSLog(@"UT-VAULT: - performing limited data hash verification.");
    for (NSUInteger i = 0; i < RSI_B1_NUM_SEALS; i++) {
        NSString     *sid   = [maSeals objectAtIndex:i];
        NSData       *dTest = [maPacked objectAtIndex:i];
        NSUInteger   len    = MIN(1, dTest.length);
        BOOL oneFailed      = NO;
        BOOL onePassed      = NO;
        while (len < dTest.length-1) {
            @autoreleasepool {
                NSData *dLim  = [NSData dataWithBytes:dTest.bytes length:len];
                if ([RealSecureImage hasEnoughDataForSealIdentification:dLim]) {
                    RSISecureMessage *sm = [RealSecureImage identifyPackedContent:dLim withFullDecryption:NO andError:nil];
                    XCTAssertNil(sm.dMessage, @"The message is not nil.");
                    if (sm) {
                        XCTAssertTrue([sid isEqualToString:sm.sealId], @"The seal was not located.");
                        NSString *hashExpected = [maHashes objectAtIndex:i];
                        XCTAssertTrue([hashExpected isEqualToString:sm.hash], @"The two hashes do not match.");
                        onePassed = YES;
                        NSLog(@"UT-VAULT: - identified content with %u bytes out of %u for a savings of %4.2f%%.", (unsigned) len, (unsigned) dTest.length,
                              100.0f * ((float)(dTest.length - len)/(float) dTest.length));
                        break;
                    }
                }
                else {
                    oneFailed = YES;
                }
            }
            len = MIN(dTest.length, len+1);
        }
        
        XCTAssertTrue(onePassed, @"Failed to find a valid hash.");
        XCTAssertTrue(oneFailed, @"Failed to abort hashing without sufficient data.");
        NSLog(@"UT-VAULT: - hashing worked at index %u", i + 1);
    }
    
    NSLog(@"UT-VAULT: - performing full message verification.");
    for (NSUInteger i = 0; i < RSI_B1_NUM_SEALS; i++) {
        NSUInteger realIndex = (RSI_B1_NUM_SEALS - 1) - i;
        
        NSDictionary *dict  = [maToTest objectAtIndex:realIndex];
        NSString     *sid   = [maSeals objectAtIndex:realIndex];
        NSData       *dTest = [maPacked objectAtIndex:realIndex];
        NSString     *hash  = [maHashes objectAtIndex:realIndex];
    
        RSISecureMessage *sm = [RealSecureImage identifyPackedContent:dTest withFullDecryption:YES andError:&err];
        XCTAssertNotNil(sm, @"Failed to retrieve the packed content for index %u.  %@", realIndex, [err localizedDescription]);
        XCTAssertNotNil(sm.dMessage, @"Failed to get actual packed content for index %u.", realIndex);
        XCTAssertTrue([sid isEqualToString:sm.sealId], @"The seal id was not identified for index %u.", realIndex);
        XCTAssertTrue([hash isEqualToString:sm.hash], @"The hash was not correct for index %u", realIndex);
        
        BOOL ret = [self isPackDictionary:sm.dMessage equalToOriginal:dict];
        XCTAssertTrue(ret, @"The returned content for index %u is invalid.", realIndex);
        
        NSLog(@"UT-VAULT: - package identified at %u", realIndex + 1);
    }
    
    NSLog(@"UT-VAULT: - testing fast seal identification behavior with invalid PNG files");
    NSArray *bundles = [NSBundle allBundles];
    for (int i = 0; i < [bundles count]; i++) {
        NSBundle *bundle = [bundles objectAtIndex:i];
        
        NSArray *allPNGs = [bundle URLsForResourcesWithExtension:@".png" subdirectory:nil];
        if (!allPNGs || [allPNGs count] == 0) {
            continue;
        }
        
        for (int j = 0; j < [allPNGs count]; j++) {
            NSURL *u = [allPNGs objectAtIndex:j];
            NSString *sLast = [u lastPathComponent];
            NSRange r = [sLast rangeOfString:@"2c"];
            if (r.location != NSNotFound) {
                // - ignore the RGB-formatted files.
                continue;
            }
            
            @autoreleasepool {
                NSLog(@"UT-VAULT: - %@", [u path]);
                
                NSData *dFile = [NSData dataWithContentsOfURL:u];
                XCTAssertNotNil(dFile, @"Failed to load the file.");
                
                // - all of these files are invalid, which means they should allow identification with very little consideration.
                BOOL isOk = [RealSecureImage hasEnoughDataForSealIdentification:dFile];
                XCTAssertTrue(isOk, @"Failed to rule out the sample file at index %d.", j);
            }
        }
    }
    
    NSLog(@"UT-VAULT: - all tests completed successfully.");
}

/*
 *  Verify that the quick identification routine reacts predictably to known data sets.
 */
-(void) testUTVAULT_5_PackedImageIdentification
{
    NSLog(@"UT-VAULT: - starting packed image identification testing.");
    
    NSString *pwd = @"~";
    NSLog(@"UT-VAULT: - building a new seal vault.");
    BOOL ret = [RealSecureImage initializeVaultWithPassword:pwd andError:&err];
    XCTAssertTrue(ret, @"Failed to create a new vault.");
    ret = [RealSecureImage hasVault];
    XCTAssertTrue(ret, @"The vault doesn't exist as expected.");
    
    NSLog(@"UT-VAULT: - creating the testing seals.");
    NSMutableArray *maSeals = [NSMutableArray array];
    static const NSUInteger RSI_B1_NUM_SEALS = 10;
    for (NSUInteger i = 0; i < RSI_B1_NUM_SEALS; i++) {
        UIImage *img = [self createSealImage];
        
        NSString *sid = [RealSecureImage createSealWithImage:img andColor:RSSC_DEFAULT andError:&err];
        XCTAssertNotNil(sid, @"Failed to build the seal at index %u.  %@", i, [err localizedDescription]);
        
        NSLog(@"UT-VAULT: - created seal %@", sid);
        
        [maSeals addObject:sid];
    }
    
    NSLog(@"UT-VAULT: - packing the test content");
    NSMutableArray *maToTest = [NSMutableArray array];
    NSMutableArray *maPacked = [NSMutableArray array];
    NSMutableArray *maHashes = [NSMutableArray array];
    for (NSUInteger i = 0; i < RSI_B1_NUM_SEALS; i++) {
        NSDictionary    *dict = [self dictionaryForPackTesting];
        [maToTest addObject:dict];
        NSString        *sid  = [maSeals objectAtIndex:i];
        RSISecureSeal   *seal = [RealSecureImage sealForId:sid andError:&err];
        XCTAssertNotNil(seal, @"Failed to retrieve the new seal at index %u.  %@", i, [err localizedDescription]);
        
        NSData *dPacked = [seal packRoleBasedMessage:dict intoImage:[self imageForPacking] withError:&err];
        XCTAssertNotNil(dPacked, @"Failed to pack the message at index %u. %@", i, [err localizedDescription]);
        UIImage *img = [UIImage imageWithData:dPacked];
        XCTAssertNotNil(img, @"Unable to get an image from the packed file.");
        [maPacked addObject:dPacked];
        NSLog(@"UT-VAULT: - packed item %u", i + 1);
        
        NSString *hash = [RealSecureImage hashForPackedContent:dPacked withError:&err];
        XCTAssertNotNil(hash, @"Failed to hash the content at index %u.  %@", i, [err localizedDescription]);
        [maHashes addObject:hash];
    }
    
    NSLog(@"UT-VAULT: - verifying that known content will be eventually identified");
    for (NSUInteger i = 0; i < RSI_B1_NUM_SEALS; i++) {
        NSData *dPacked = (NSData *) [maPacked objectAtIndex:i];
        XCTAssert([dPacked length] >= [RSI_secure_props propertyHeaderLength], @"The packed data is too small.");
        
        BOOL wasIdentified = NO;
        @autoreleasepool {
            for (NSUInteger j = 1; j < [dPacked length]; j++) {
                NSData *dSubItem = [NSData dataWithBytes:dPacked.bytes length:j];
                RSISecureMessageIdentification *smi = [RealSecureImage quickPackedContentIdentification:dSubItem];
                XCTAssertFalse(smi.willNeverMatch, @"A known item will never match!");
                if (smi.message && smi.message.sealId) {
                    NSString *hash = (NSString *) [maHashes objectAtIndex:i];
                    XCTAssertTrue([hash isEqualToString:smi.message.hash], @"The hash was not computed correctly (%@ != %@).", smi.message.hash, hash);
                    wasIdentified = YES;
                    break;
                }
            }
        }
        XCTAssertTrue(wasIdentified, @"A known item was never identified.");
        NSLog(@"UT-VAULT: ...identified item %u as expected", i);
    }
    
    NSLog(@"UT-VAULT: - verifying that invalid content will never be identified.");
    NSArray *bundles = [NSBundle allBundles];
    for (int i = 0; i < [bundles count]; i++) {
        NSBundle *bundle = [bundles objectAtIndex:i];
        
        NSArray *allPNGs = [bundle URLsForResourcesWithExtension:@".png" subdirectory:nil];
        if (!allPNGs || [allPNGs count] == 0) {
            continue;
        }
        
        for (int j = 0; j < [allPNGs count]; j++) {
            NSURL *u = [allPNGs objectAtIndex:j];
            
            @autoreleasepool {
                NSData *dFile = [NSData dataWithContentsOfURL:u];
                XCTAssertNotNil(dFile, @"Failed to load the file.");
                
                for (NSUInteger k = 1; k < [dFile length]; k++) {
                    NSData *dSubItem = [NSData dataWithBytes:dFile.bytes length:k];
                    RSISecureMessageIdentification *smi = [RealSecureImage quickPackedContentIdentification:dSubItem];
                    XCTAssertTrue(smi.willNeverMatch || smi.message == nil, @"The invalid item was matched incorrectly.");
                }
                
                NSLog(@"UT-VAULT: ... correctly disregarded %@", [u path]);
            }
        }
    }
    
    NSLog(@"UT-VAULT: - verifying that when valid content finds no seal, it doesn't match.");
    for (NSUInteger i = 0; i < RSI_B1_NUM_SEALS; i++) {
        NSString *sid = [maSeals objectAtIndex:i];
        NSLog(@"UT-VAULT: - deleting the seal %@", sid);
        ret = [RealSecureImage deleteSealForId:sid andError:&err];
        XCTAssertTrue(ret, @"Failed to delete one of our seals.");
        
        NSData *dPacked = [maPacked objectAtIndex:i];
        RSISecureMessageIdentification *smi = [RealSecureImage quickPackedContentIdentification:dPacked];
        XCTAssertTrue(smi.willNeverMatch && smi.message && smi.message.sealId == nil, @"Failed to ignore the packed message.");
        NSLog(@"UT-VAULT: - the seal was not found as expected.");
    }
    
    NSLog(@"UT-VAULT: - all tests completed successfully.");
}

/*
 *  Just have one more test that can run so that all autorelease data is discarded.
 */
-(void) testUTVAULT_99_VaultCompletion
{
    NSLog(@"UT-VAULT: - VAULT TESTS COMPLETED SUCCESSFULLY.");
}

@end
