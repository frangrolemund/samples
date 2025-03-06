//
//  RSI_9_seal_tests.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/28/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "RSI_9_seal_tests.h"
#import "RSI_seal.h"
#import "RSI_error.h"

@interface RSI_seal (shared)
-(BOOL) setExpirationDate:(NSDate *) dt withError:(NSError **) err;
-(BOOL) setInvalidateOnSnapshotUnconditionally:(BOOL) enabled withError:(NSError **) err;
@end

@implementation RSI_9_seal_tests

/*
 *  Simple prep between tests.
 */
-(void) setUp
{
    [super setUp];    
    err = nil;
    
    time_t tNow = time(NULL);
    NSLog(@"UT-SEAL: - the random seed is %ld", tNow);
    srand((unsigned int) tNow);
    
    self.continueAfterFailure = NO;    
}

/*
 *  General purpose routine for creating seal images.
 */
-(UIImage *) createSealImageOfSize:(CGSize) szImg
{
    UIGraphicsBeginImageContext(szImg);
    
    UIColor *cSeal = [UIColor colorWithRed:((CGFloat) (rand() % 255))/255.0f green:((CGFloat) (rand() % 255))/255.0f  blue:((CGFloat) (rand() % 255))/255.0f  alpha:1.0f];
    UIColor *cBorder = [UIColor colorWithRed:((CGFloat) (rand() % 255))/255.0f green:((CGFloat) (rand() % 255))/255.0f  blue:((CGFloat) (rand() % 255))/255.0f  alpha:1.0f];
    CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), [cSeal CGColor]);
    CGContextSetStrokeColorWithColor(UIGraphicsGetCurrentContext(), [cBorder CGColor]);
    
    CGRect rcFull = CGRectMake(0.0f, 0.0f, szImg.width, szImg.height);
    CGContextFillRect(UIGraphicsGetCurrentContext(), rcFull);
    
    CGContextSetLineWidth(UIGraphicsGetCurrentContext(), 10.0f);
    CGContextStrokeRect(UIGraphicsGetCurrentContext(), rcFull);
    
    UIImage *ret = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    XCTAssertNotNil(ret, @"An image was not created.");
    return ret;
}

/*
 *  Save the data as a file.
 */
-(void) saveData:(NSData *) dFile asName:(NSString *) sFile
{
    NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    u = [u URLByAppendingPathComponent:sFile];
    BOOL ret = [dFile writeToURL:u atomically:YES];
    
    XCTAssertTrue(ret, @"Failed to save the file data.");
}

/*
 *  Basic testing of seal support
 */
-(void) testUTSEAL_1_Basic
{
    NSLog(@"UT-SEAL: - starting basic seal testing.");
    
    NSLog(@"UT-SEAL: - deleting all old seals.");
    BOOL ret = [RSI_seal deleteAllSealsWithError:&err];
    XCTAssertTrue(ret, @"Failed to delete all existing seals.  %@", [err localizedDescription]);
    
    NSLog(@"UT-SEAL: - verifying that a NULL image fails.");
    RSI_seal *seal = [RSI_seal allocNewSealWithImage:nil andColorId:0 andError:&err];
    XCTAssertNil(seal, @"A seal was generated and should not have been.");
    XCTAssertTrue(err.code == RSIErrorInvalidSealImage, @"Failed to return the expected error.");
    
    NSLog(@"UT-SEAL: - verifying that a small image fails.");
    UIImage *imgSeal = [self createSealImageOfSize:CGSizeMake(60.0f, 60.0f)];
    seal = [RSI_seal allocNewSealWithImage:imgSeal andColorId:0 andError:&err];
    XCTAssertNil(seal, @"A seal was generated and should not have been.");
    XCTAssertTrue(err.code == RSIErrorInvalidSealImage, @"Failed to return the expected error.");

    imgSeal = [self createSealImageOfSize:CGSizeMake(256.0f, 256.0f)];
    
    NSLog(@"UT-SEAL: - verifying that bad colors fail.");
    seal = [RSI_seal allocNewSealWithImage:imgSeal andColorId:-1 andError:&err];
    XCTAssertNil(seal, @"A seal was generated and should not have been.");
    XCTAssertTrue(err.code == RSIErrorInvalidArgument, @"Failed to return the expected error.");

    seal = [RSI_seal allocNewSealWithImage:imgSeal andColorId:256 andError:&err];
    XCTAssertNil(seal, @"A seal was generated and should not have been.");
    XCTAssertTrue(err.code == RSIErrorInvalidArgument, @"Failed to return the expected error.");
    
    NSLog(@"UT-SEAL: - verifying that a seal can be created with a properly-sized image.");
    seal = [RSI_seal allocNewSealWithImage:imgSeal andColorId:0 andError:&err];
    XCTAssertNotNil(seal, @"The seal was not created as expected.  %@", [err localizedDescription]);
    XCTAssertNotNil([seal sealImage], @"The seal doesn't have an image as expected.");
    
    [self saveData:[seal sealImage] asName:@"seal-image-basic.jpg"];
    
    NSLog(@"UT-SEAL: - verifying the seal is a producer seal.");
    ret = [seal isProducerSeal];
    XCTAssertTrue(ret, @"The seal was not a producer seal and should have been.");
    
    NSLog(@"UT-SEAL: - archiving the seal.");
    RSI_securememory *smSealArchive = [seal sealArchiveWithError:&err];
    XCTAssertNotNil(smSealArchive, @"Failed to archive the existing seal.  %@", [err localizedDescription]);
    
    NSString *sid = [seal sealId];
    XCTAssertNotNil(sid, @"Failed to retrieve a valid id for the seal.");
    NSLog(@"UT-SEAL: - generated a seal with id of %@", sid);
    
    NSLog(@"UT-SEAL: - releasing and re-retrieving the seal.");
    [seal release];
    
    RSI_seal *sealCmp = [[RSI_seal allocExistingSealWithId:sid andError:&err] autorelease];
    XCTAssertNotNil(sealCmp, @"Failed to allocate the existing seal.");
    XCTAssertTrue([sid isEqualToString:[sealCmp sealId]], @"The retrieved seal is unequal to the original");
    XCTAssertNil([sealCmp sealImage], @"The seal has an image, but it shouldn't have.");
    
    NSLog(@"UT-SEAL: - deleting the new seal.");
    ret = [RSI_seal deleteSealForId:sid andError:&err];
    XCTAssertTrue(ret, @"Failed to delete the seal.  %@", [err localizedDescription]);
    
    NSLog(@"UT-SEAL: - verifying the seal is now gone.");
    seal = [RSI_seal allocExistingSealWithId:sid andError:&err];
    XCTAssertNil(seal, @"Allocated the seal when it should have been gone.");
    
    NSLog(@"UT-SEAL: - reimporting the seal from the archive.");
    RSI_seal *sealImported = [[RSI_seal allocSealWithArchive:smSealArchive.rawData andError:&err] autorelease];
    XCTAssertNotNil(sealImported, @"Failed to re-import the seal from the archive.");
    XCTAssertTrue([sid isEqualToString:[sealImported sealId]], @"The retrieved seal is unequal to the original");
    XCTAssertNotNil([sealImported sealImage], @"The imported seal doesn't have an image.");
    
    UIImage *imgSealImported = [UIImage imageWithData:[sealImported sealImage]];
    XCTAssertNotNil(imgSealImported, @"The imported image is not a valid image format.");
    CGSize szImported = imgSealImported.size;
    XCTAssertTrue((int) szImported.width == 256 && (int) szImported.height == 256, @"The returned image is the wrong size.");
    
    NSLog(@"UT-SEAL: - checking that the seal is now there.");
    sealCmp = [[RSI_seal allocExistingSealWithId:sid andError:&err] autorelease];
    XCTAssertNotNil(sealCmp, @"Failed to allocate the existing seal.");
    XCTAssertTrue([sid isEqualToString:[sealCmp sealId]], @"The retrieved seal is unequal to the original");
    
    NSLog(@"UT-SEAL: - verifying the seal is still a producer after reimporting it.");
    ret = [sealCmp isProducerSeal];
    XCTAssertTrue(ret, @"The seal was not identified correctly as a producer.");
    
    NSLog(@"UT-SEAL: - reimporting the seal from the archive (should exist).");
    RSI_seal *sealImported2 = [[RSI_seal allocSealWithArchive:smSealArchive.rawData andError:&err] autorelease];
    XCTAssertNotNil(sealImported2, @"Failed to re-import the seal from the archive.");
    XCTAssertTrue([sid isEqualToString:[sealImported2 sealId]], @"The imported seal is unequal to the original");
    XCTAssertNotNil([sealImported2 sealImage], @"The imported seal doesn't have an image.");
    
    NSLog(@"UT-SEAL: - checking that the seal is still there.");
    sealCmp = [[RSI_seal allocExistingSealWithId:sid andError:&err] autorelease];
    XCTAssertNotNil(sealCmp, @"Failed to allocate the existing seal.");
    XCTAssertTrue([sid isEqualToString:[sealCmp sealId]], @"The retrieved seal is unequal to the original");
    
    NSLog(@"UT-SEAL: - exporting the seal with a nil password (should fail).");
    NSData *dExportedSeal = [sealImported exportSealWithPassword:nil andError:&err];
    XCTAssertNil(dExportedSeal, @"The seal was exported and should not have been.");
    XCTAssertTrue(err.code == RSIErrorBadPassword, @"The expected error was not returned.");
    
    NSLog(@"UT-SEAL: - exporting the seal.");
    dExportedSeal = [sealImported exportSealWithPassword:@"foobar" andError:&err];
    XCTAssertNotNil(dExportedSeal, @"Failed to export the seal.  %@", [err localizedDescription]);
    
    UIImage *imgSealExported = [UIImage imageWithData:dExportedSeal];
    XCTAssertNotNil(imgSealExported, @"Failed to verify the exported seal image.");
    
    [self saveData:dExportedSeal asName:@"seal-image-basic-exported.jpg"];
    
    NSLog(@"UT-SEAL: - deleting the seal again.");
    ret = [RSI_seal deleteSealForId:sid andError:&err];
    XCTAssertTrue(ret, @"Failed to delete the seal.  %@", [err localizedDescription]);
    
    NSLog(@"UT-SEAL: - verifying the seal is now gone.");
    seal = [RSI_seal allocExistingSealWithId:sid andError:&err];
    XCTAssertNil(seal, @"Allocated the seal when it should have been gone.");
    
    NSLog(@"UT-SEAL: - trying to import the seal with a nil password (should fail).");
    sealImported = [RSI_seal importSeal:dExportedSeal withPassword:nil andError:&err];
    XCTAssertNil(sealImported, @"The seal was imported but should have failed.");
    XCTAssertTrue(err.code == RSIErrorBadPassword, @"Did not receive the expected failure code.");

    NSLog(@"UT-SEAL: - trying to import the seal with a bad password (should fail).");
    sealImported = [RSI_seal importSeal:dExportedSeal withPassword:@"abc" andError:&err];
    XCTAssertNil(sealImported, @"The seal was imported but should have failed.");
    XCTAssertTrue(err.code == RSIErrorBadPassword, @"Did not receive the expected failure code.");
    
    NSLog(@"UT-SEAL: - trying to import the seal with a good password.");
    sealImported = [RSI_seal importSeal:dExportedSeal withPassword:@"foobar" andError:&err];
    XCTAssertNotNil(sealImported, @"Failed to import the seal.  %@", [err localizedDescription]);
    XCTAssertTrue([sid isEqualToString:[sealImported2 sealId]], @"The imported seal is unequal to the original");
    XCTAssertNotNil([sealImported2 sealImage], @"The imported seal doesn't have an image.");
    
    NSLog(@"UT-SEAL: - verifying the imported seal is not a producer.");
    ret = [sealImported isProducerSeal];
    XCTAssertFalse(ret, @"The seal was not correctly identified as a consumer.");
    
    NSLog(@"UT-SEAL: - all tests completed successfully.");
}

/*
 *  Creates a test payload
 */
-(NSDictionary *) testPayload
{
    NSMutableDictionary *mdRet = [NSMutableDictionary dictionary];
    [mdRet setObject:[NSNumber numberWithInt:41412412] forKey:@"number"];
    [mdRet setObject:[NSDate date] forKey:@"date"];

    RSI_securememory *sm = [RSI_securememory dataWithLength:257];
    XCTAssertNotNil(sm, @"Failed to allocate the secure test data.");
    SecRandomCopyBytes(kSecRandomDefault, [sm length], sm.mutableBytes);
    [mdRet setObject:sm forKey:@"secmem"];
    
    NSMutableData *md = [NSMutableData dataWithLength:351];
    XCTAssertNotNil(md, @"Failed to allocate the test data.");
    SecRandomCopyBytes(kSecRandomDefault, [md length], md.mutableBytes);
    [mdRet setObject:md forKey:@"mem"];
    
    UIImage *img = [self createSealImageOfSize:CGSizeMake(128, 128)];
    XCTAssertNotNil(img, @"Failed to allocate the test image.");
    [mdRet setObject:img forKey:@"img"];
    
    XCTAssertNotNil(mdRet, @"Failed to allocate the test dictionary.");
    
    return mdRet;
}

/*
 *  Verify that two payloads are identical.
 */
-(void) verifyPayload:(NSDictionary *) decrypted withOriginal:(NSDictionary *) orig
{
    XCTAssertTrue(decrypted && [decrypted count] == 5, @"Failed to get the number of expected elements.");

    XCTAssertTrue([(NSObject *) [decrypted objectForKey:@"number"] isKindOfClass:[NSNumber class]], @"The number object is invalid.");
    XCTAssertTrue([(NSNumber *) [decrypted objectForKey:@"number"] isEqualToNumber:[orig objectForKey:@"number"]], @"The number is invalid.");

    XCTAssertTrue([(NSObject *) [decrypted objectForKey:@"date"] isKindOfClass:[NSDate class]], @"The date object is invalid.");
    XCTAssertTrue([(NSDate *) [decrypted objectForKey:@"date"] isEqualToDate:[orig objectForKey:@"date"]], @"The date is invalid.");
    
    XCTAssertTrue([(NSObject *) [decrypted objectForKey:@"secmem"] isKindOfClass:[RSI_securememory class]], @"The secure memory object is invalid.");
    XCTAssertTrue([(RSI_securememory *) [decrypted objectForKey:@"secmem"] isEqualToSecureData:[orig objectForKey:@"secmem"]], @"The secure memory is invalid.");

    XCTAssertTrue([(NSObject *) [decrypted objectForKey:@"mem"] isKindOfClass:[NSData class]], @"The memory object is invalid.");
    XCTAssertTrue([(NSData *) [decrypted objectForKey:@"mem"] isEqualToData:[orig objectForKey:@"mem"]], @"The memory is invalid.");
                  
    XCTAssertTrue([(NSObject *) [decrypted objectForKey:@"img"] isKindOfClass:[UIImage class]], @"The image object is invalid.");
    CGSize szDecrypt = ((UIImage *) [decrypted objectForKey:@"img"]).size;
    CGSize szOrig    = ((UIImage *) [orig objectForKey:@"img"]).size;
                  
    XCTAssertTrue((int) szDecrypt.width == (int) szOrig.width && (int) szDecrypt.height == (int) szOrig.height, @"The image dimensions are different.");    
}

/*
 *  Verify that the day-padded expiration is still in the same day as the current expiration, but at the end.
 */
-(void) verifyDayPaddedExpirationWithSeal:(RSI_seal *) seal andPreciseExpiration:(NSDate *) dtExpires
{
    NSCalendar *cal  = [NSCalendar currentCalendar];
    NSDate *dtPadded = [seal expirationDateWithDayPadding:YES andError:&err];
    XCTAssertNotNil(dtPadded, @"The padded date could not be constructed.  %@", [err localizedDescription]);
    
    NSUInteger unitFlags       = NSMonthCalendarUnit | NSDayCalendarUnit | NSYearCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit;
    NSDateComponents *dcExact  = [cal components:unitFlags fromDate:dtExpires];
    NSDateComponents *dcPadded = [cal components:unitFlags fromDate:dtPadded];
    
    XCTAssertEqual(dcExact.month, dcPadded.month, @"The months are not equal.");
    XCTAssertEqual(dcExact.day, dcPadded.day, @"The days are not equal.");
    XCTAssertEqual(dcExact.year, dcPadded.year, @"The years are not equal.");
    XCTAssertEqual(dcPadded.hour, 23, @"The padded hour is not at the end of day.");
    XCTAssertEqual(dcPadded.minute, 59, @"The padded minute is not at the end of day.");
}

/*
 *  Role-based encryption/decryption verification.
 */
-(void) testUTSEAL_2_Roles
{
    NSLog(@"UT-SEAL: - starting role-based seal testing.");
    
    NSLog(@"UT-SEAL: - preparing for seal creation.");
    [RSI_seal prepareForSealGeneration];
        
    NSLog(@"UT-SEAL: - deleting all old seals.");
    BOOL ret = [RSI_seal deleteAllSealsWithError:&err];
    XCTAssertTrue(ret, @"Failed to delete all existing seals.  %@", [err localizedDescription]);
    
    NSLog(@"UT-SEAL: - verifying all the seals are indeed gone.");
    NSArray *arrSealsRem = [RSI_seal availableSealsWithError:&err];
    XCTAssertTrue(!arrSealsRem || [arrSealsRem count] == 0, @"There are still seals remaining.  Count = %u", [arrSealsRem count]);
    
    const NSUInteger RSI_9_NUM_ROLES = 10;
    NSLog(@"UT-SEAL: - creating %u seals for testing", RSI_9_NUM_ROLES);
    
    NSMutableArray *maSealArray = [NSMutableArray array];
    NSMutableArray *maSealImages = [NSMutableArray array];
    for (NSUInteger i = 0; i < RSI_9_NUM_ROLES; i++) {
        UIImage *img = [self createSealImageOfSize:CGSizeMake(256 + (rand() % 20), 256 + (rand() % 20))];
        RSI_seal *seal = [RSI_seal allocNewSealWithImage:img andColorId:0 andError:&err];
        XCTAssertNotNil(seal, @"Failed to create the seal at index %u.  %@", i, [err localizedDescription]);
        [seal autorelease];
        NSLog(@"UT-SEAL: - created %@", [seal sealId]);
        [RSI_seal prepareForSealGeneration];
        [maSealArray addObject:seal];
        [maSealImages addObject:img];
        
        NSDate *dtExpire = [seal expirationDateWithDayPadding:NO andError:&err];
        XCTAssertNotNil(dtExpire, @"Failed to receive an expiration date at index %u", i);
        [self verifyDayPaddedExpirationWithSeal:seal andPreciseExpiration:dtExpire];
        NSDate *dtNow = [NSDate date];
        ret = ([dtExpire compare:dtNow] == NSOrderedAscending);
        XCTAssertTrue(ret, @"The expiration date of the owned seal is not valid for index %u.", i);
        
        ret = [seal isExpiredWithDayPadding:NO andError:&err];
        XCTAssertFalse(ret, @"The seal was expired at index %u.", i);
        XCTAssertNil(err, @"An error was returned and it shouldn't have been.");
        
        uint16_t targetSelfDestruct = (i*13)+1;
        ret = [seal setSelfDestruct:targetSelfDestruct withError:&err];
        XCTAssertTrue(ret, @"Failed to set the self destruction value for seal %u.", i);
        
        uint16_t actualSelfDestruct = [seal selfDestructTimeoutWithError:&err];
        XCTAssertTrue(targetSelfDestruct == actualSelfDestruct, @"Failed to get the correct self destruct value for index %u.", i);
    }
    
    NSLog(@"UT-SEAL: - enumerating all the seals.");
    NSArray *arrSeals = [RSI_seal availableSealsWithError:&err];
    XCTAssertNotNil(arrSeals, @"Failed to get a list of available seals.");
    XCTAssertTrue([arrSeals count] == RSI_9_NUM_ROLES, @"The count of seals doesn't match what was expected.");
    
    NSLog(@"UT-SEAL: - verifying the enumerated seals.");
    for (NSUInteger i = 0; i < [arrSeals count]; i++) {
        NSString *s = [arrSeals objectAtIndex:i];

        BOOL found = NO;
        for (NSUInteger j = 0; !found && j < [maSealArray count]; j++) {
            RSI_seal *seal = [maSealArray objectAtIndex:j];
            if ([s isEqualToString:[seal sealId]]) {
                found = YES;
            }
            
            ret = [seal isProducerSeal];
            XCTAssertTrue(ret, @"The seal at index %u was not a producer seal and should have been.", i);
        }
        
        NSLog(@"UT-SEAL: - checking %@.", s);
        XCTAssertTrue(found, @"The value was not found in the created list.");
    }
    
    NSLog(@"UT-SEAL: - creating the test datasets.");
    NSMutableArray *maTestData = [NSMutableArray array];
    for (NSUInteger i= 0; i < RSI_9_NUM_ROLES; i++) {
        [maTestData addObject:[self testPayload]];
    }
    
    NSLog(@"UT-SEAL: - encrypting the datasets as both producer, consumer, local and role.");
    NSMutableArray *maEncProd = [NSMutableArray array];
    NSMutableArray *maEncCons = [NSMutableArray array];
    NSMutableArray *maEncLocal = [NSMutableArray array];
    NSMutableArray *maEncRole = [NSMutableArray array];
    for (NSUInteger i = 0; i < RSI_9_NUM_ROLES; i++) {
        RSI_seal *s = [maSealArray objectAtIndex:i];
        
        NSData *dP = [s encryptProducerMessage:[maTestData objectAtIndex:i] withError:&err];
        XCTAssertNotNil(dP, @"Failed to encrypt the producer message at index %u.  %@", i, [err localizedDescription]);
        
        NSData *dC = [s encryptConsumerMessage:[maTestData objectAtIndex:i] withError:&err];
        XCTAssertNotNil(dC, @"Failed to encrypt the consumer message at index %u.  %@", i, [err localizedDescription]);
        
        NSData *dL = [s encryptLocalOnlyMessage:[maTestData objectAtIndex:i] withError:&err];
        XCTAssertNotNil(dC, @"Failed to encrypt the local message at index %u.  %@", i, [err localizedDescription]);
        
        NSData *dR = [s encryptRoleBasedMessage:[maTestData objectAtIndex:i] withError:&err];
        XCTAssertNotNil(dR, @"Failed to encrypt the role-based message at index %u.  %@", i, [err localizedDescription]);
        
        [maEncProd addObject:dP];
        [maEncCons addObject:dC];
        [maEncLocal addObject:dL];
        [maEncRole addObject:dR];
        
        //  - verify that the role-based message can be decrypted by the producer.
        RSISecureMessage *smDecrypt = [RSI_seal identifyEncryptedMessage:dR withFullDecryption:YES andError:&err];
        XCTAssertNotNil(smDecrypt.dMessage, @"Failed to decrypt the role-based item we just created for index %u.  %@", i, [err localizedDescription]);
        XCTAssertTrue([[s sealId] isEqualToString:[smDecrypt sealId]], @"The identified seal for the role-based method was incorrect.");
        [self verifyPayload:smDecrypt.dMessage withOriginal:[maTestData objectAtIndex:i]];
    }
    
    NSLog(@"UT-SEAL: - exporting the seals.");
    NSMutableArray *maExportFull = [NSMutableArray array];
    NSMutableArray *maExport = [NSMutableArray array];
    for (NSUInteger i = 0; i < RSI_9_NUM_ROLES; i++) {
        RSI_seal *s = [maSealArray objectAtIndex:i];
        
        RSI_securememory *smExFull = [s sealArchiveWithError:&err];
        XCTAssertNotNil(smExFull, @"Failed to export the full seal at index %u.  %@", i, [err localizedDescription]);
        
        NSData *dEx = [s exportSealWithPassword:@"hello" andError:&err];
        XCTAssertNotNil(dEx, @"Failed to export the seal at index %u.  %@", i, [err localizedDescription]);
        
        [maExportFull addObject:smExFull];
        [maExport addObject:dEx];
    }
    
    NSLog(@"UT-SEAL: - deleting all the seals.");
    [maSealArray removeAllObjects];
    for (NSUInteger i = 0; i < [arrSeals count]; i++) {
        BOOL ret = [RSI_seal deleteSealForId:[arrSeals objectAtIndex:i] andError:&err];
        XCTAssertTrue(ret, @"Failed to delete the seal %@.", [arrSeals objectAtIndex:i]);
    }
    
    NSLog(@"UT-SEAL: - importing the consumer seals.");
    for (NSUInteger i = 0; i < [maExport count]; i++) {
        NSData *dEx = [maExport objectAtIndex:i];
        RSI_seal *seal = [RSI_seal importSeal:dEx withPassword:@"hello" andError:&err];
        XCTAssertNotNil(seal, @"Failed to import the seal at index %u.  %@", i, [err localizedDescription]);
        [maSealArray addObject:seal];
        
        ret = [seal setSelfDestruct:i+1 withError:&err];
        XCTAssertFalse(ret, @"The self destruct timeout was set on the consumer seal at index %u and shouldn't have been.", i);
        
        uint16_t targetSelfDestruct = (i*13)+1;
        uint16_t selfDestructValue = [seal selfDestructTimeoutWithError:&err];
        XCTAssertTrue(selfDestructValue == 0, @"Retrieved a self destruct value in a consumer seal and shouldn't have.");
        XCTAssertTrue(err.code == RSIErrorUnsupportedConsumerAction, @"The returned error code was invalid.");
        
        NSDate *dtLow = [NSDate dateWithTimeIntervalSinceNow:60*60*24*(targetSelfDestruct-1)];
        NSDate *dtHigh = [NSDate dateWithTimeIntervalSinceNow:(60*60*24*targetSelfDestruct)+300];           //  add a bit of extra time to exceed the high end
        
        NSDate *expires = [seal expirationDateWithDayPadding:NO andError:&err];
        XCTAssertNotNil(expires, @"Failed to retrieve an expiration date for the seal at index %u.", i);
        [self verifyDayPaddedExpirationWithSeal:seal andPreciseExpiration:expires];
        
        ret = ([dtLow compare:expires] == NSOrderedAscending);
        XCTAssertTrue(ret, @"The expiration date is too low at index %u.", i);
        
        ret = ([dtHigh compare:expires] == NSOrderedDescending);
        XCTAssertTrue(ret, @"The expiration date is too high at index %u.", i);
        
        //  - assign an expiration date by the back door so that we can test that it is updated when messages are identified.
        NSDate *dtNowPlusALittle = [NSDate dateWithTimeIntervalSinceNow:60*60];
        ret = [seal setExpirationDate:dtNowPlusALittle withError:&err];
        XCTAssertTrue(ret, @"Failed to set the expiration date at6 index %u.", i);
        
        expires = [seal expirationDateWithDayPadding:NO andError:&err];
        [self verifyDayPaddedExpirationWithSeal:seal andPreciseExpiration:expires];
        NSTimeInterval tiSet = [dtNowPlusALittle timeIntervalSinceReferenceDate];
        NSTimeInterval tiRet = [expires timeIntervalSinceReferenceDate];
        XCTAssertTrue((uint64_t) tiSet == (uint64_t) tiRet, @"The expired date was not set correctly.");
        
        err = nil;
        ret = [seal isInvalidatedWithError:&err];
        XCTAssertFalse(ret, @"The seal at index %u was invalidated and shouldn't have been.", i);
        XCTAssertNil(err, @"The error code was set and shouldn't have been.");
    }
    
    NSLog(@"UT-SEAL: - checking that bulk identification works for producer messages.");
    NSMutableArray *maTmp = [NSMutableArray arrayWithArray:maEncProd];
    for (NSUInteger i = 0; i < RSI_9_NUM_ROLES; i+=2) {
        NSMutableData *mdBadMsg = [NSMutableData dataWithLength:1024];
        SecRandomCopyBytes(kSecRandomDefault, [mdBadMsg length], mdBadMsg.mutableBytes);
        [maTmp replaceObjectAtIndex:i withObject:mdBadMsg];
    }
    
    for (NSUInteger i = 0; i < RSI_9_NUM_ROLES; i++) {
        NSObject *obj = [maTmp objectAtIndex:i];
        RSISecureMessage *sm = [RSI_seal identifyEncryptedMessage:(NSData *) obj withFullDecryption:NO andError:&err];
        if (i%2 == 0) {
            XCTAssertNil(sm.sealId,  @"Failed to get the expected no-identify result at index %u.", i);
        }
        else if  (i%2 == 1 && sm && sm.sealId) {
            NSString *toCompare = [[maSealArray objectAtIndex:i] sealId];
            XCTAssertTrue([toCompare isEqualToString:sm.sealId], @"The seal id at index %u doesn't match.", i);
        }
        else {
            XCTAssertTrue(NO, @"Failed to get the expected identification at index %u.",  i);
        }
    }
    
    NSLog(@"UT-SEAL: - checking that producer messages can be accurately decrypted.");
    for (NSUInteger i = 0; i < RSI_9_NUM_ROLES; i++) {
        NSDictionary *dict = nil;
        NSDictionary *dictRoleBased = nil;
        RSI_seal *seal = nil;
        RSI_seal *consumSeal = [maSealArray objectAtIndex:i];
        
        ret = [consumSeal isProducerSeal];
        XCTAssertFalse(ret, @"The consumer seal at index %u was incorrectly identified as a producer.", i);
        
        NSLog(@"UT-SEAL: - decrypting data for %@.", [consumSeal sealId]);
        RSISecureMessage *sm = nil;
        if (i%2 == 0) {
            sm   = [RSI_seal identifyEncryptedMessage:[maEncProd objectAtIndex:i] withFullDecryption:YES andError:&err];
            dict = sm.dMessage;
            XCTAssertNotNil(dict, @"Failed to auto-decrypt the data at index %u.", i);
            XCTAssertTrue([[sm sealId] isEqualToString:[consumSeal sealId]], @"The returned seal does not match as expected.");
            
            sm            = [RSI_seal identifyEncryptedMessage:[maEncRole objectAtIndex:i] withFullDecryption:YES andError:&err];
            dictRoleBased = sm.dMessage;
            seal          = [[RSI_seal allocExistingSealWithId:sm.sealId andError:&err] autorelease];
            XCTAssertNotNil(seal, @"Failed to allocate an existing seal for the id %@.", sm.sealId);
        }
        else {
            dict = [consumSeal decryptMessage:[maEncProd objectAtIndex:i] withError:&err];
            XCTAssertNotNil(dict, @"Failed to auto-decrypt the data at index %u.", i);
            
            dictRoleBased = [consumSeal decryptMessage:[maEncRole objectAtIndex:i] withError:&err];
        }
        XCTAssertNotNil(dictRoleBased, @"Failed to auto-decrypt the role-based data at index %u.", i);
        
        [self verifyPayload:dict withOriginal:[maTestData objectAtIndex:i]];
        [self verifyPayload:dictRoleBased withOriginal:[maTestData objectAtIndex:i]];
        
        //  - the expiration date on the seal should have been updated
        if (!seal) {
            seal = consumSeal;
        }
        
        uint16_t targetSelfDestruct = (i*13)+1;
        NSDate *dtLow = [NSDate dateWithTimeIntervalSinceNow:60*60*24*(targetSelfDestruct-1)];
        NSDate *dtHigh = [NSDate dateWithTimeIntervalSinceNow:(60*60*24*targetSelfDestruct)+300];           //  add a bit of extra time to exceed the high end
        
        NSDate *expires = [seal expirationDateWithDayPadding:NO andError:&err];
        XCTAssertNotNil(expires, @"Failed to retrieve an expiration date for the seal at index %u.", i);
        [self verifyDayPaddedExpirationWithSeal:seal andPreciseExpiration:expires];
        
        ret = ([dtLow compare:expires] == NSOrderedAscending);
        XCTAssertTrue(ret, @"The expiration date is too low at index %u.", i);
        
        ret = ([dtHigh compare:expires] == NSOrderedDescending);
        XCTAssertTrue(ret, @"The expiration date is too high at index %u.", i);
        
        //  - decrypt the data a second time to ensure the expiration is unchanged
        //    and cannot be incremented over and over.
        NSDictionary *dictSecond = [seal decryptMessage:[maEncProd objectAtIndex:i] withError:&err];
        XCTAssertNotNil(dictSecond, @"Failed to decrypt the message a second time.");
        
        [self verifyPayload:dictSecond withOriginal:[maTestData objectAtIndex:i]];
        
        NSDate *expiresTwo = [seal expirationDateWithDayPadding:NO andError:&err];
        XCTAssertNotNil(expiresTwo, @"The expiration could not be retrieved the second time.");
        [self verifyDayPaddedExpirationWithSeal:seal andPreciseExpiration:expiresTwo];
        
        uint64_t tiOrig = floor([expires timeIntervalSinceReferenceDate]);
        uint64_t tiSec  = floor([expiresTwo timeIntervalSinceReferenceDate]);
        
        // - floats are imprecise, so accept anything within a second.
        XCTAssertTrue((tiOrig == tiSec) || (tiOrig == (tiSec-1)) || (tiSec == (tiOrig - 1)), @"The second expires date (%llu) was not equal to the first (%llu) in index %u.", tiSec, tiOrig, i);
    }
    [maEncProd removeAllObjects];
    
    NSLog(@"UT-SEAL: - checking that consumer messages cannot be decrypted with the installed consumer seals.");
    for (NSUInteger i = 0; i < RSI_9_NUM_ROLES; i++) {
        RSISecureMessage *sm = [RSI_seal identifyEncryptedMessage:[maEncCons objectAtIndex:i] withFullDecryption:YES andError:nil];
        XCTAssertNil(sm.dMessage, @"The content was decrypted and should not have been at index %u.", i);
    }
    [maEncCons removeAllObjects];
    
    NSLog(@"UT-SEAL: - checking that consumer seals can decrypt the local messages created by a producer.");
    for (NSUInteger i = 0; i < RSI_9_NUM_ROLES; i++) {
        RSI_seal *consumSeal = [maSealArray objectAtIndex:i];
        NSDictionary *dict = [consumSeal decryptMessage:[maEncLocal objectAtIndex:i] withError:&err];
        XCTAssertNotNil(dict, @"Failed to decrypt the local message at index %u", i);
        
        [self verifyPayload:dict withOriginal:[maTestData objectAtIndex:i]];
    }
    
    NSLog(@"UT-SEAL: - encrypting some consumer responses.");
    [maEncRole removeAllObjects];
    NSMutableArray *maConsResponses = [NSMutableArray array];
    for (NSUInteger i = 0; i < RSI_9_NUM_ROLES; i++) {
        RSI_seal *seal = [maSealArray objectAtIndex:i];
        
        NSData *dResp = [seal encryptConsumerMessage:[maTestData objectAtIndex:i] withError:&err];
        XCTAssertNotNil(dResp, @"Failed to encrypt the consumer response.");
        
        NSDictionary *dictDecrypt = [seal decryptMessage:dResp withError:nil];
        XCTAssertNil(dictDecrypt, @"The consumer decrypted its own response.");
        
        [maConsResponses addObject:dResp];
        
        dResp = [seal encryptRoleBasedMessage:[maTestData objectAtIndex:i] withError:&err];
        XCTAssertNotNil(dResp, @"Failed to encrypt the consumer role-based response.");
        
        dictDecrypt = [seal decryptMessage:dResp withError:nil];
        XCTAssertNil(dictDecrypt, @"The consumer decrypted its own role-based response.");
        [maEncRole addObject:dResp];
        
        //  - verify expiration while we're at it.
        NSDate *dtNow = [NSDate dateWithTimeIntervalSinceNow:1.0];
        ret = [seal setExpirationDate:dtNow withError:&err];
        XCTAssertTrue(ret, @"Failed to set the expiration date");
        
        sleep(3);
        ret = [seal isExpiredWithDayPadding:NO andError:&err];
        XCTAssertTrue(ret, @"Failed to detect expiration at index %u", i);
        
        // - now check that day padding doesn't allow it to be expired.
        ret = [seal isExpiredWithDayPadding:YES andError:&err];
        XCTAssertFalse(ret, @"Day padding didn't protect the seal against expiration.");
    }
    
    NSLog(@"UT-SEAL: - deleting all the seals.");
    [maSealArray removeAllObjects];
    ret = [RSI_seal deleteAllSealsWithError:&err];
    XCTAssertTrue(ret, @"Failed to delete all the seals.");
    
    NSLog(@"UT-SEAL: - importing the producer seals.");
    for (NSUInteger i = 0; i < [maExportFull count]; i++) {
        RSI_securememory *smExFull = [maExportFull objectAtIndex:i];
        RSI_seal *seal = [[RSI_seal allocSealWithArchive:smExFull.rawData andError:&err] autorelease];
        XCTAssertNotNil(seal, @"Failed to allocate the seal as expected.");
        [maSealArray addObject:seal];
        
        uint16_t targetSelfDestruct = (i*13)+1;
        uint16_t actualSelfDestruct = [seal selfDestructTimeoutWithError:&err];
        XCTAssertTrue(targetSelfDestruct == actualSelfDestruct, @"Failed to get the correct self destruct value for index %u.", i);        
    }
    
    NSLog(@"UT-SEAL: - checking that consumer messages can be accurately decrypted.");
    for (NSUInteger i = 0; i < RSI_9_NUM_ROLES; i++) {
        NSDictionary *dict = nil;
        NSDictionary *dictRoleBased = nil;
        RSI_seal *seal = nil;
        RSI_seal *prodSeal = [maSealArray objectAtIndex:i];
        RSISecureMessage *sm = nil;
        NSLog(@"UT-SEAL: - decrypting data for %@.", [prodSeal sealId]);
        if (i%2 == 0) {
            sm   = [RSI_seal identifyEncryptedMessage:[maConsResponses objectAtIndex:i] withFullDecryption:YES andError:&err];
            dict = sm.dMessage;
            XCTAssertNotNil(dict, @"Failed to auto-decrypt the data at index %u.", i);
            seal = [[RSI_seal allocExistingSealWithId:sm.sealId andError:&err] autorelease];
            XCTAssertNotNil(seal, @"Failed to retrieve a seal at index %u.", i);
            XCTAssertTrue([[seal sealId] isEqualToString:[prodSeal sealId]], @"The returned seal does not match as expected.");
            
            sm            = [RSI_seal identifyEncryptedMessage:[maEncRole objectAtIndex:i] withFullDecryption:YES andError:&err];
            dictRoleBased = sm.dMessage;
        }
        else {
            dict = [prodSeal decryptMessage:[maConsResponses objectAtIndex:i] withError:&err];
            XCTAssertNotNil(dict, @"Failed to auto-decrypt the data at index %u.", i);
            
            dictRoleBased = [prodSeal decryptMessage:[maEncRole objectAtIndex:i] withError:&err];
        }
        XCTAssertNotNil(dictRoleBased, @"Failed to auto-decrypt the role-based data at index %u.", i);
        
        [self verifyPayload:dict withOriginal:[maTestData objectAtIndex:i]];
        [self verifyPayload:dictRoleBased withOriginal:[maTestData objectAtIndex:i]];
    }
    
    NSLog(@"UT-SEAL: - checking that the producer seals can decrypt the local messages it created.");
    for (NSUInteger i = 0; i < RSI_9_NUM_ROLES; i++) {
        RSI_seal *prodSeal = [maSealArray objectAtIndex:i];
        NSDictionary *dict = [prodSeal decryptMessage:[maEncLocal objectAtIndex:i] withError:&err];
        XCTAssertNotNil(dict, @"Failed to decrypt the local message at index %u", i);
        
        [self verifyPayload:dict withOriginal:[maTestData objectAtIndex:i]];
    }
    
    NSLog(@"UT-SEAL: - invalidating all the seals and verifying that the messages can't be decrypted.");
    for (NSUInteger i = 0; i < RSI_9_NUM_ROLES; i++) {
        RSI_seal *prodSeal = [maSealArray objectAtIndex:i];
        NSLog(@"UT-SEAL: - invalidating seal for %@.", [prodSeal sealId]);
        ret = [prodSeal invalidateSealUnconditionallyWithError:&err];
        XCTAssertTrue(ret, @"Failed to invalidate the seal at index %u.", i);
        
        err = nil;
        ret = [prodSeal isInvalidatedWithError:&err];
        XCTAssertTrue(ret, @"The seal's invalidation could not be identified at index %u.", i);
        XCTAssertNil(err, @"The return code was set and shouldn't have been.");
        
        NSLog(@"UT-SEAL: - verifying seal %@ is unusable.", [prodSeal sealId]);
        if (i%2 == 0) {
            RSISecureMessage *sm = [RSI_seal identifyEncryptedMessage:[maConsResponses objectAtIndex:i] withFullDecryption:YES andError:&err];
            XCTAssertNil(sm.sealId, @"The seal data was identified and should not have been at index %u.", i);
        }
        else {
            NSDictionary * dict = [prodSeal decryptMessage:[maConsResponses objectAtIndex:i] withError:&err];
            XCTAssertNil(dict, @"Decryption occurred and shouldn't have at index %u.", i);
        }
    }
    
    NSLog(@"UT-SEAL: - stopping the async seal creation.");
    [RSI_seal stopAsyncCompute];
 
    NSLog(@"UT-SEAL: - all tests completed successfully.");    
}

/*
 *  Verify seal attributes do the right thing.
 */
-(void) testUTSEAL_3_Attributes
{
    NSLog(@"UT-SEAL: - starting seal attribute testing.");

    NSLog(@"UT-SEAL: - creating a working seal.");
    UIImage *img = [self createSealImageOfSize:CGSizeMake(256 + (rand() % 20), 256 + (rand() % 20))];
    RSI_seal *seal = [RSI_seal allocNewSealWithImage:img andColorId:32 andError:&err];
    XCTAssertNotNil(seal, @"Failed to create the seal.  %@", [err localizedDescription]);
    [seal autorelease];
    
    NSLog(@"UT-SEAL: - verifying that the seal's initialization color was set.");
    int color = [seal colorIdWithError:&err];
    XCTAssertTrue(color == 32, @"The color id was not assigned correctly.  %@", err ? [err localizedDescription] : @"No error returned.");
    
    NSLog(@"UT-SEAL: - verifying that the seal cannot accept an invalid color.");
    BOOL ret = [seal setColorId:-1 withError:&err];
    XCTAssertFalse(ret, @"The invalid color id was accepted.");
    XCTAssertTrue(err.code == RSIErrorInvalidArgument, @"The expected error code was not returned.");
    
    ret = [seal setColorId:256 withError:&err];
    XCTAssertFalse(ret, @"The invalid color id was accepted.");
    XCTAssertTrue(err.code == RSIErrorInvalidArgument, @"The expected error code was not returned.");
    
    NSLog(@"UT-SEAL: - verifying that the seal cannot accept an invalid self destruct value.");
    ret = [seal setSelfDestruct:0 withError:&err];
    XCTAssertFalse(ret, @"The invalid self destruct value was accepted.");
    XCTAssertTrue(err.code == RSIErrorInvalidArgument, @"The expected error code was not returned.");
    
    NSLog(@"UT-SEAL: - checking that the two attributes can be set and retrieved.");
    for (int i = 1; i < 0xFFFF+1; i+=253) {
        ret = [seal setColorId:(i%0xFF) withError:&err];
        XCTAssertTrue(ret, @"The color could not be set.");
        
        ret = [seal setSelfDestruct:i withError:&err];
        XCTAssertTrue(ret, @"The self destruct timeout could not be set.");
        
        int curColor = [seal colorIdWithError:&err];
        XCTAssertTrue(curColor == (i%0xFF), @"The color id was not retrieved successfully for index %d.  (retrieved = %d)", i, curColor);
        
        uint16_t selfDestruct = [seal selfDestructTimeoutWithError:&err];
        XCTAssertTrue(selfDestruct > 0, @"The self destruct value could not be set.");
        
        ret = [seal isExpiredWithDayPadding:NO andError:&err];
        XCTAssertFalse(ret, @"The seal was expired and should not have been.");
        
        ret = [seal invalidateExpiredSealWithError:&err];
        XCTAssertFalse(ret, @"The seal was invalidated and should not have been.");
        
        ret = [seal isInvalidatedWithError:&err];
        XCTAssertFalse(ret, @"The seal was invalidated and should not have been.");
    }
       
    NSString *sTest = @"Hello World";
    NSDictionary *dToEncrypt = [NSDictionary dictionaryWithObject:sTest forKey:@"test"];
    NSData *dEncrypted = [seal encryptRoleBasedMessage:dToEncrypt withError:&err];
    XCTAssertNotNil(dEncrypted, @"Failed to encrypt the test message.");
    
    NSDictionary *dDecrypted = [seal decryptMessage:dEncrypted withError:&err];
    XCTAssertNotNil(dDecrypted, @"Failed to decrypt the message before invalidation.");
    ret = [dToEncrypt isEqualToDictionary:dDecrypted];
    XCTAssertTrue(ret, @"The decryption failed.");
    
    NSLog(@"UT-SEAL: - checking seal invalidation works.");        
    ret = [seal invalidateSealUnconditionallyWithError:&err];
    XCTAssertTrue(ret, @"The expired seal could not be invalidated.");
    
    ret = [seal isInvalidatedWithError:&err];
    XCTAssertTrue(ret, @"The invalidated seal could not be identified.");
    
    NSDictionary *dInvalidDecrypted = [seal decryptMessage:dEncrypted withError:&err];
    XCTAssertNil(dInvalidDecrypted, @"The seal decrypted the test and shouldn't have.");
    
    NSLog(@"UT-SEAL: - all tests completed successfully.");    
}

/*
 *  A common password for import/export.
 */
-(NSString *) sealPassword
{
    return @"~";
}

/*
 *  A test message to verify correctness.
 */
-(NSString *) revocationTestMessage
{
    return @"This message should confirm revocation worked correctly.";
}

/*
 *  The dictionary key for the test message.
 */
-(NSString *) revocationTestKey
{
    return @"TESTKEY";
}

/*
 *  Switch the seal over to its producer form.
 */
-(RSI_seal *) switchSeal:(NSString *) sealId toProducerSeal:(RSI_securememory *) smProducer
{
    BOOL ret = [RSI_seal deleteSealForId:sealId andError:&err];
    XCTAssertTrue(ret, @"Failed to delete the seal for the producer switch.  %@", [err localizedDescription]);
    
    ret = [RSI_seal sealExists:sealId withError:nil];
    XCTAssertFalse(ret, @"The seal still exists after deletion.");
    
    RSI_seal *pSeal = [RSI_seal allocSealWithArchive:smProducer.rawData andError:&err];
    XCTAssertNotNil(pSeal, @"The producer seal could not be reimported.  %@", [err localizedDescription]);
    [pSeal autorelease];
    
    ret = [pSeal isProducerSeal];
    XCTAssertTrue(ret, @"The imported seal is not a producer seal as expected.");
    
    ret = [pSeal.sealId isEqualToString:sealId];
    XCTAssertTrue(ret, @"The seal id before and after do not match.");
    
    NSLog(@"UT-SEAL: - switched over to producer seal.");
    return pSeal;
}

/*
 *  Switch the seal over to its consumer form.
 */
-(RSI_seal *) switchSeal:(NSString *) sealId toConsumerSeal:(NSData *) dConsumer
{
    BOOL ret = [RSI_seal deleteSealForId:sealId andError:&err];
    XCTAssertTrue(ret, @"Failed to delete the seal for the consumer switch.  %@", [err localizedDescription]);
    
    ret = [RSI_seal sealExists:sealId withError:nil];
    XCTAssertFalse(ret, @"The seal still exists after deletion.");
    
    RSI_seal *pSeal = [RSI_seal importSeal:dConsumer withPassword:[self sealPassword] andError:&err];
    XCTAssertNotNil(pSeal, @"The consumer seal could not be imported.  %@", [err localizedDescription]);
    
    ret = [pSeal isProducerSeal];
    XCTAssertFalse(ret, @"The imported seal is not a consumer seal as expected.");
    
    ret = [pSeal.sealId isEqualToString:sealId];
    XCTAssertTrue(ret, @"The seal id before and after do not match.");
    
    NSLog(@"UT-SEAL: - switched over to consumer seal.");
    return pSeal;
}

/*
 *  Verify that the consumer seal can decrypt the message.
 */
-(BOOL) verifyTestMesage:(NSData *) testMessage withSeal:(RSI_seal *) seal
{
    NSDictionary *dDecrypted = [seal decryptMessage:testMessage withError:&err];
    if (!dDecrypted) {
        NSLog(@"UT-SEAL:  !!!There is no decrypted data.  %@", [err localizedDescription]);
        return NO;
    }
    
    NSObject *obj = [dDecrypted objectForKey:[self revocationTestKey]];
    if (!obj || ![obj isKindOfClass:[NSString class]]) {
        NSLog(@"UT-SEAL:  !!!Data is incorrect.");
        return NO;
    }
    
    BOOL ret = [(NSString *) obj isEqualToString:[self revocationTestMessage]];
    if (!ret) {
        NSLog(@"UT-SEAL:  !!!Strings not equal.");
    }
    return ret;
}

/*
 *  Verify that the consumer seal can decrypt the message.
 */
-(BOOL) verifyTestMesage:(NSData *) testMessage withSealId:(NSString *) sealId
{
    RSI_seal *seal = [RSI_seal allocExistingSealWithId:sealId andError:&err];
    XCTAssertNotNil(seal, @"Failed to allocate the existing seal.  %@", [err localizedDescription]);
    return [self verifyTestMesage:testMessage withSeal:[seal autorelease]];
}

/*
 *  Verify that the seal can't be invalidated by snapshot.
 */
-(void) verifySnapshotInvalidationFailsForSeal:(RSI_seal *) seal
{
    BOOL ret = [seal invalidateForSnapshotWithError:&err];
    XCTAssertFalse(ret, @"The snapshot invalidation succeeded and shouldn't have.");
    XCTAssertEqual(err.code, RSIErrorSealStillValid, @"The error code is not what we expected.");
}

/*
 *  Expiration testing.
 *  - this is intended to be a much more exhaustive set of expiration tests that
 *    ensure that the relevant data is passed to consumers and their access can
 *    be revoked reliably when important criteria are met.
 */
-(void) testUTSEAL_4_Expiration
{
    NSLog(@"UT-SEAL: - starting expiration testing.");
   
    NSLog(@"UT-SEAL: - deleting all seals.");
    BOOL ret = [RSI_seal deleteAllSealsWithError:nil];
    XCTAssertTrue(ret, @"Failed to delete all the existing seals.  %@", [err localizedDescription]);
    
    NSLog(@"UT-SEAL: - creating a working seal.");
    UIImage *img = [self createSealImageOfSize:CGSizeMake(256 + (rand() % 20), 256 + (rand() % 20))];
    RSI_seal *seal = [RSI_seal allocNewSealWithImage:img andColorId:0 andError:&err];
    XCTAssertNotNil(seal, @"Failed to create the seal.  %@", [err localizedDescription]);
    NSString *sealId = [seal sealId];
    [seal autorelease];
    
    NSLog(@"UT-SEAL: - exporting as a producer seal.");
    RSI_securememory *smProducerSeal = [seal sealArchiveWithError:&err];
    XCTAssertNotNil(smProducerSeal, @"Failed to export the producer seal.  %@", [err localizedDescription]);
    
    NSLog(@"UT-SEAL: - exporting as a consumer seal.");
    NSData *dConsumerSeal = [seal exportSealWithPassword:[self sealPassword] andError:&err];
    XCTAssertNotNil(dConsumerSeal, @"Failed to export the consumer seal.  %@", [err localizedDescription]);

    NSLog(@"UT-SEAL: - encrypting a test message with the seal.");
    NSData *dEncryptedVerify = [seal encryptProducerMessage:[NSDictionary dictionaryWithObject:[self revocationTestMessage] forKey:[self revocationTestKey]] withError:&err];
    XCTAssertNotNil(dEncryptedVerify, @"Failed to encrypt the test message.");
    
    NSLog(@"UT-SEAL: - verify we can switch to consumer.");
    [self switchSeal:sealId toConsumerSeal:dConsumerSeal];
    
    NSLog(@"UT-SEAL: - verify that consumer can decrypt.");
    ret = [self verifyTestMesage:dEncryptedVerify withSealId:sealId];
    XCTAssertTrue(ret, @"Failed to verify the decrypted message.");
    
    NSLog(@"UT-SEAL: - testing producer cannot be expired.");
    seal = [self switchSeal:sealId toProducerSeal:smProducerSeal];
    ret = [seal setExpirationDate:[NSDate dateWithTimeIntervalSinceReferenceDate:0] withError:&err];
    XCTAssertFalse(ret, @"The producer seal allowed an expiration to be set and shouldn't have.");
    ret = [seal invalidateExpiredSealWithError:&err];
    XCTAssertFalse(ret, @"The producer seal was expired and should not have been.");
    
    NSLog(@"UT-SEAL: - checking that consumer will expire with the same config.");
    seal = [self switchSeal:sealId toConsumerSeal:dConsumerSeal];
    ret = [seal setExpirationDateUnconditionally:[NSDate dateWithTimeIntervalSinceReferenceDate:0] withError:&err];         //  expiration is relative to reference date!
    XCTAssertTrue(ret, @"The consumer seal didn't allow an expiration value to be assigned.  %@", [err localizedDescription]);
    ret = [seal invalidateExpiredSealWithError:&err];
    XCTAssertTrue(ret, @"The consumer seal could not be expired by date.  %@", [err localizedDescription]);
    ret = [seal isInvalidatedWithError:&err];
    XCTAssertTrue(ret, @"The consumer seal wasn't invalidated when we checked.  %@", [err localizedDescription]);
    NSLog(@"UT-SEAL: - the consumer seal was invalidated by a simple date expiration.");

    NSLog(@"UT-SEAL: - verifying that a re-import will fix the seal.");
    seal = [self switchSeal:sealId toConsumerSeal:dConsumerSeal];
    ret = [seal isInvalidatedWithError:&err];
    XCTAssertFalse(ret, @"The seal was invalid and shouldn't have been.");
    ret = [seal setExpirationDateUnconditionally:[NSDate dateWithTimeIntervalSinceReferenceDate:0] withError:&err];
    XCTAssertTrue(ret, @"The consumer seal didn't allow an expiration value to be assigned.  %@", [err localizedDescription]);
    
    NSLog(@"UT-SEAL: - decrypting, which should address the expiration date.");
    [self verifyTestMesage:dEncryptedVerify withSeal:seal];
    ret = [seal invalidateExpiredSealWithError:&err];
    XCTAssertFalse(ret, @"The consumer seal was expired and shouldn't have been.");
    ret = [seal isInvalidatedWithError:&err];
    XCTAssertFalse(ret, @"The consumer seal was invalid and shouldn't have been.");
    NSLog(@"UT-SEAL: - the consumer seal's lifespan was increased by message reading.");
    
    NSLog(@"UT-SEAL: - all tests completed successfully.");
}


/*
 *  Revocation testing.
 *  - this is intended to be a much more exhaustive set of revocation tests.
 */
-(void) testUTSEAL_5_Revocation
{
    NSLog(@"UT-SEAL: - starting revocation testing.");
    
    NSLog(@"UT-SEAL: - deleting all seals.");
    BOOL ret = [RSI_seal deleteAllSealsWithError:nil];
    XCTAssertTrue(ret, @"Failed to delete all the existing seals.  %@", [err localizedDescription]);
    
    NSLog(@"UT-SEAL: - creating a working seal.");
    [RSI_seal prepareForSealGeneration];    
    UIImage *img = [self createSealImageOfSize:CGSizeMake(256 + (rand() % 20), 256 + (rand() % 20))];
    RSI_seal *seal = [RSI_seal allocNewSealWithImage:img andColorId:0 andError:&err];
    XCTAssertNotNil(seal, @"Failed to create the seal.  %@", [err localizedDescription]);
    NSString *sealId = [seal sealId];
    [seal autorelease];
    
    NSLog(@"UT-SEAL: - exporting as a producer seal.");
    RSI_securememory *smProducerSeal = [seal sealArchiveWithError:&err];
    XCTAssertNotNil(smProducerSeal, @"Failed to export the producer seal.  %@", [err localizedDescription]);
    
    NSLog(@"UT-SEAL: - exporting as a consumer seal.");
    sleep(1);       // - to ensure the snapshot date is precise
    ret = [seal setInvalidateOnSnapshot:NO withError:&err];
    XCTAssertTrue(ret, @"Failed to set the snapshot invalidation flag.  %@", [err localizedDescription]);
    NSData *dConsumerSeal = [seal exportSealWithPassword:[self sealPassword] andError:&err];
    XCTAssertNotNil(dConsumerSeal, @"Failed to export the consumer seal.  %@", [err localizedDescription]);
    NSData *dEncryptedVerify = [seal encryptProducerMessage:[NSDictionary dictionaryWithObject:[self revocationTestMessage] forKey:[self revocationTestKey]] withError:&err];
    XCTAssertNotNil(dEncryptedVerify, @"Failed to encrypt the test message.");
    sleep(1);       // - to ensure the snapshot date is precise
    ret = [seal setInvalidateOnSnapshot:YES withError:&err];
    XCTAssertTrue(ret, @"Failed to set the snapshot invalidation flag.  %@", [err localizedDescription]);
    NSData *dConsumerSealSnap = [seal exportSealWithPassword:[self sealPassword] andError:&err];
    XCTAssertNotNil(dConsumerSealSnap, @"Failed to export the consumer seal with snapshot protection.  %@", [err localizedDescription]);
    
    NSLog(@"UT-SEAL: - encrypting a test message with the seal (with snapshot mode update).");
    NSData *dEncryptedVerifySnap = [seal encryptProducerMessage:[NSDictionary dictionaryWithObject:[self revocationTestMessage] forKey:[self revocationTestKey]] withError:&err];
    XCTAssertNotNil(dEncryptedVerifySnap, @"Failed to encrypt the test message.");
    
    NSLog(@"UT-SEAL: - verify that the producer seal cannot be invalidated.");
    ret = [seal isInvalidateOnSnapshotEnabledWithError:&err];
    XCTAssertTrue(ret, @"The producer isn't set with snapshot invalidation as expected.");
    ret = [seal invalidateForSnapshotWithError:&err];
    XCTAssertFalse(ret, @"The producer seal shouldn't have been invalidated.");
    
    NSLog(@"UT-SEAL: - verify we can switch to consumer (with no snap-protect).");
    seal = [self switchSeal:sealId toConsumerSeal:dConsumerSeal];
    
    NSLog(@"UT-SEAL: - verify that consumer will not be invalidated.");
    ret = [seal isInvalidateOnSnapshotEnabledWithError:&err];
    XCTAssertFalse(ret, @"The consumer has snapshot invalidation assigned and should not.");
    ret = [seal invalidateForSnapshotWithError:&err];
    XCTAssertFalse(ret, @"The consumer seal shouldn't have been invalidated.");
    
    NSLog(@"UT-SEAL: - verify that consumer can decrypt.");
    ret = [self verifyTestMesage:dEncryptedVerifySnap withSealId:sealId];
    XCTAssertTrue(ret, @"Failed to verify the decrypted message.");
    
    NSLog(@"UT-SEAL: - verify that an old message will not disable snapshot protection mode.");
    seal = [self switchSeal:sealId toConsumerSeal:dConsumerSealSnap];
    [self verifyTestMesage:dEncryptedVerify withSeal:seal];
    ret = [seal invalidateForSnapshotWithError:&err];
    XCTAssertTrue(ret, @"The consumer seal should have been invalidated by snapshot. %@", [err localizedDescription]);
    
    NSLog(@"UT-SEAL: - verify that a new message will enable snapshot protection mode.");
    seal = [self switchSeal:sealId toConsumerSeal:dConsumerSeal];
    [self verifyTestMesage:dEncryptedVerify withSeal:seal];
    ret = [seal invalidateForSnapshotWithError:&err];
    XCTAssertFalse(ret, @"The consumer seal shouldn't have been invalidated yet.");
    ret = [seal isInvalidatedWithError:&err];
    XCTAssertFalse(ret, @"The consumer seal is invalid and shouldn't be.");
    [self verifyTestMesage:dEncryptedVerifySnap withSeal:seal];
    ret = [seal invalidateForSnapshotWithError:&err];
    XCTAssertTrue(ret, @"The consumer seal wasn't invalidated as expected.  %@", [err localizedDescription]);
    ret = [seal isInvalidatedWithError:&err];
    XCTAssertTrue(ret, @"The consumer seal is still valid.");
    
    NSLog(@"UT-SEAL: - all tests completed successfully.");
}

/*
 *  Hybrid testing with invalidation attributes..
 *  - the point of this test to ensure that modifying one attribute doesn't corrupt the other and vice-versa because
 *    they are all stored in the same attributes buffer.
 */
-(void) testUTSEAL_6_InvalidationHybrid
{
    NSLog(@"UT-SEAL: - starting hybrid invalidation testing.");
    
    NSLog(@"UT-SEAL: - deleting all seals.");
    BOOL ret = [RSI_seal deleteAllSealsWithError:nil];
    XCTAssertTrue(ret, @"Failed to delete all the existing seals.  %@", [err localizedDescription]);
    
    NSLog(@"UT-SEAL: - creating a working seal.");
    UIImage *img = [self createSealImageOfSize:CGSizeMake(256 + (rand() % 20), 256 + (rand() % 20))];
    RSI_seal *seal = [RSI_seal allocNewSealWithImage:img andColorId:0 andError:&err];
    XCTAssertNotNil(seal, @"Failed to create the seal.  %@", [err localizedDescription]);
    NSString *sealId = [seal sealId];
    [seal autorelease];
    
    NSLog(@"UT-SEAL: - assigning a self-destruct value.");
    uint16_t selfD = 55;
    ret = [seal setSelfDestruct:selfD withError:&err];
    XCTAssertTrue(ret, @"Failed to assign the self destruct value.  %@", [err localizedDescription]);
    NSLog(@"UT-SEAL: - verifying that repeated snapshot flag modifications will not change it.");
    for (NSUInteger i = 0; i < 100; i++) {
        ret = [seal setInvalidateOnSnapshot:(i % 2) == 0 ? YES : NO withError:&err];
        XCTAssertTrue(ret, @"The seal invalidation assignment could not be made.  %@", [err localizedDescription]);
        RSI_seal *sCur = [RSI_seal allocExistingSealWithId:sealId andError:&err];
        XCTAssertNotNil(sCur, @"Failed to load the current seal.  %@", [err localizedDescription]);
        uint16_t curVal = [sCur selfDestructTimeoutWithError:&err];
        [sCur release];
        XCTAssertTrue(curVal == selfD, @"The self-destruct value wasn't what we expected.");
    }
    
    NSLog(@"UT-SEAL: - exporting the seal without snapshot detection.");
    ret = [seal setInvalidateOnSnapshot:NO withError:&err];
    XCTAssertTrue(ret, @"Failed to set the invalidation flag.  %@", [err localizedDescription]);
    NSData *dConsumerSeal = [seal exportSealWithPassword:[self sealPassword] andError:&err];
    XCTAssertNotNil(dConsumerSeal, @"Failed to export the consumer seal.  %@", [err localizedDescription]);
    seal = [self switchSeal:sealId toConsumerSeal:dConsumerSeal];
    ret = [seal invalidateForSnapshotWithError:&err];
    XCTAssertFalse(ret, @"The consumer seal was invalidated and should not have been.");
    ret = [seal isInvalidatedWithError:&err];
    XCTAssertFalse(ret, @"The consumer seal is not valid.");
    NSLog(@"UT-SEAL: - verifying that repeated expiration date modifications will not change it.");
    for (NSUInteger i = 0; i < 100; i++) {
        ret = [seal setExpirationDateUnconditionally:[NSDate dateWithTimeIntervalSinceNow:rand() % 10000] withError:&err];
        XCTAssertTrue(ret, @"Failed to set the expiration date.  %@", [err localizedDescription]);
        RSI_seal *sCur = [RSI_seal allocExistingSealWithId:sealId andError:&err];
        ret = [sCur isInvalidateOnSnapshotEnabledWithError:&err];
        XCTAssertFalse(ret, @"The snapshot flag is set and should not be.");
        ret = [sCur invalidateForSnapshotWithError:&err];
        XCTAssertFalse(ret, @"The consumer seal was invalidated and should not have been.");
        ret = [sCur isInvalidatedWithError:&err];
        XCTAssertFalse(ret, @"The consumer seal is not valid.");
        [sCur release];
    }
    
    NSLog(@"UT-SEAL: - all tests completed successfully.");
}

/*
 *  These tests verify that invalidated seals are no longer usable for encryption or decryption.
 *  - It is very important to confirm this because the seal remains usable in some sense, but that
 *    isn't the kind of use we want to take advantage of.  Invalidating the keys is done to ensure that
 *    none of the original data exists, even in the keychain.   Invalidation is a bit of a hairy scenario 
 *    because it is technically possible for the flags to be updated, but the key was not.
 */
-(void) testUTSEAL_7_InvalidationCrypto
{
    NSLog(@"UT-SEAL: - starting invalidation crypto testing.");
    
    NSLog(@"UT-SEAL: - creating a working seal.");
    UIImage *img = [self createSealImageOfSize:CGSizeMake(256 + (rand() % 20), 256 + (rand() % 20))];
    RSI_seal *seal = [RSI_seal allocNewSealWithImage:img andColorId:0 andError:&err];
    XCTAssertNotNil(seal, @"Failed to create the seal.  %@", [err localizedDescription]);
    NSString *sealId = [seal sealId];
    [seal autorelease];
    
    NSLog(@"UT-SEAL: - exporting as a consumer seal.");
    NSData *dConsumerSeal = [seal exportSealWithPassword:[self sealPassword] andError:&err];
    XCTAssertNotNil(dConsumerSeal, @"Failed to export the consumer seal.  %@", [err localizedDescription]);
    
    NSLog(@"UT-SEAL: - encrypting a test message with the seal.");
    NSDictionary *dictToTest = [NSDictionary dictionaryWithObject:[self revocationTestMessage] forKey:[self revocationTestKey]];
    NSData *dEncryptedVerify = [seal encryptProducerMessage:dictToTest withError:&err];
    XCTAssertNotNil(dEncryptedVerify, @"Failed to encrypt the test message.");
    
    NSLog(@"UT-SEAL: - verify we can switch the seal over to consumer and decrypt.");
    seal = [self switchSeal:sealId toConsumerSeal:dConsumerSeal];
    [self verifyTestMesage:dEncryptedVerify withSeal:seal];
    
    NSLog(@"UT-SEAL: - invalidating the seal.");
    BOOL ret = [seal invalidateSealUnconditionallyWithError:&err];
    XCTAssertTrue(ret, @"Failed to invalidate the seal.");
    
    NSLog(@"UT-SEAL: - attempting to encrypt using the four approaches (should fail).");
    NSData *dTmp = [seal encryptProducerMessage:dictToTest withError:&err];
    XCTAssertNil(dTmp, @"The encryption occurred and shouldn't have.");
    XCTAssertTrue(err.code == RSIErrorInvalidSeal, @"The returned error wasn't what we expected.");
    NSLog(@"UT-SEAL: - failed to encrypt as producer as expected.");

    dTmp = [seal encryptRoleBasedMessage:dictToTest withError:&err];
    XCTAssertNil(dTmp, @"The encryption occurred and shouldn't have.");
    XCTAssertTrue(err.code == RSIErrorInvalidSeal, @"The returned error wasn't what we expected.");
    NSLog(@"UT-SEAL: - failed to encrypt role-based as expected.");

    dTmp = [seal encryptConsumerMessage:dictToTest withError:&err];
    XCTAssertNil(dTmp, @"The encryption occurred and shouldn't have.");
    XCTAssertTrue(err.code == RSIErrorInvalidSeal, @"The returned error wasn't what we expected.");
    NSLog(@"UT-SEAL: - failed to encrypt as consumer as expected.");
    
    dTmp = [seal encryptLocalOnlyMessage:dictToTest withError:&err];
    XCTAssertNil(dTmp, @"The encryption occurred and shouldn't have.");
    XCTAssertTrue(err.code == RSIErrorInvalidSeal, @"The returned error wasn't what we expected.");
    NSLog(@"UT-SEAL: - failed to encrypt local-only as expected.");
    
    NSLog(@"UT-SEAL: - attempting to decrypt (should fail).");
    NSDictionary *dToVerify = [seal decryptMessage:dEncryptedVerify withError:&err];
    XCTAssertNil(dToVerify, @"The decryption occurred and shouldn't have.");
    XCTAssertTrue(err.code == RSIErrorInvalidSeal, @"The returned error wasn't what we expected.");
    NSLog(@"UT-SEAL: - failed to decrypt as expected.");
    
    NSLog(@"UT-SEAL: - all tests completed successfully.");
}
@end
