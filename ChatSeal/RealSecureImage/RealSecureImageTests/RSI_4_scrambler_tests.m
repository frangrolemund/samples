//
//  RSI_4_scrambler_tests.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/1/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "RSI_4_scrambler_tests.h"
#import "RSI_common.h"
#import "RSI_scrambler.h"

static NSString *RSI_4_scrambler_TAG = @"scramtest";
static const char *RSI_4_scrambler_TEST_TEXT = "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";


@implementation RSI_4_scrambler_tests

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
 *  Test scrambling with a specific-sized buffer
 */
-(void) unitTestWithBufferSized:(NSUInteger) len andStatus:(BOOL) showStatus
{
    NSUInteger numBlocks = (len + ((1 << 8) - 1)) >> 8;
    if (showStatus) {
        NSLog(@"UT-SCRAMBLER: - scrambling a %u-block buffer (%u bytes).", numBlocks, len);
    }
    
    NSMutableData *mdData = [NSMutableData dataWithLength:len];
    for (NSUInteger i = 0; i < [mdData length]; i++) {
        ((unsigned char *) mdData.mutableBytes)[i] = (unsigned char) (rand() & 0xFF);
    }
    
    RSI_securememory *skey = [RSI_securememory dataWithLength:[RSI_scrambler keySize]];
    for (NSUInteger i = 0; i < [skey length]; i++) {
        ((unsigned char *) skey.mutableBytes)[i] = (unsigned char) (rand() & 0xFF);
    }
    
    NSMutableData *scrambled = [NSMutableData data];
    BOOL ret = [RSI_scrambler scramble:mdData withKey:skey intoBuffer:scrambled withError:&err];
    XCTAssertTrue(ret, @"Failed to scramble the data.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);

    ret = [scrambled isEqualToData:mdData];
    XCTAssertFalse(ret, @"The scrambled data was equal to the original (length of %u)!", mdData.length);
    
    if (showStatus) {
        NSLog(@"UT-SCRAMBLER: - descrambling the %u-block buffer (%u bytes).", numBlocks, len);
    }
    RSI_securememory *unscrambled = [RSI_securememory data];
    
    ret = [RSI_scrambler descramble:scrambled withKey:skey intoBuffer:unscrambled withError:&err];
    XCTAssertTrue(ret, @"Failed to unscramble the data.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);

    if (showStatus) {
        NSLog(@"UT-SCRAMBLER: - comparing the %u bytes of descrambled data to the original.", len);
    }
    ret = [unscrambled.rawData isEqualToData:mdData];
    XCTAssertTrue(ret, @"The data does not match!");
}

/*
 *  Verify that basic scrambling behavior is functional.
 */
-(void) testUTSCRAMBLER_1_Baseline
{
    NSLog(@"UT-SCRAMBLER: -  working with a scrambler key size of %u bytes.", [RSI_scrambler keySize]);
    time_t tSeed = time(NULL);
    NSLog(@"SCR-UT: - seeding the random number generator with %lu", tSeed);
    srand((unsigned int) tSeed);
    
    //  - baseline behavior to make sure that scrambling/descrambling works as
    //    intended
    [self unitTestWithBufferSized:10 andStatus:YES];
    [self unitTestWithBufferSized:255 andStatus:YES];
    [self unitTestWithBufferSized:256 andStatus:YES];
    [self unitTestWithBufferSized:257 andStatus:YES];
    [self unitTestWithBufferSized:511 andStatus:YES];
    [self unitTestWithBufferSized:512 andStatus:YES];
    [self unitTestWithBufferSized:513 andStatus:YES];
    [self unitTestWithBufferSized:4096 andStatus:YES];
    [self unitTestWithBufferSized:4200 andStatus:YES];
    [self unitTestWithBufferSized:8100 andStatus:YES];
    [self unitTestWithBufferSized:51000 andStatus:YES];
}

/*
 *  Confirm arguments are checked.
 */
-(void) testUTSCRAMBLER_2_CheckArgs
{
    NSMutableData *mdGood = [NSMutableData dataWithLength:1];
    NSMutableData *mdBad = [NSMutableData dataWithLength:0];
    RSI_securememory *smDescrambled = [RSI_securememory dataWithLength:0];
    RSI_securememory *smKey = [RSI_securememory dataWithLength:[RSI_scrambler keySize]];
    NSLog(@"UT-SCRAMBLER: -  verifing that arguments are checked for scrambling/descrambling");
    BOOL ret = [RSI_scrambler scramble:mdGood withKey:smKey intoBuffer:nil withError:&err] ||
               [RSI_scrambler scramble:mdBad withKey:smKey intoBuffer:mdGood withError:&err] ||
               [RSI_scrambler descramble:mdGood withKey:smKey intoBuffer:nil withError:&err] ||
               [RSI_scrambler descramble:mdBad withKey:smKey intoBuffer:smDescrambled withError:&err];
    
    XCTAssertFalse(ret, @"Arguments were not verified as expected.");
}

/*
 *  Delete all existing keys.
 */
-(void) testUTSCRAMBLER_3_DeleteAll
{
    NSLog(@"UT-SCRAMBLER: -  deleting all existing keys.");
    [RSI_scrambler deleteAllKeysWithError:nil];
    NSArray *arr = [RSI_scrambler findAllKeyTagsWithError:&err];
    XCTAssertTrue(!arr || [arr count] == 0, @"Found one or more keys after deletion.");
}

/*
 *  Create a new scrambler key.
 */
-(void) testUTSCRAMBLER_4_Create
{
    NSLog(@"UT-SCRAMBLER: - creating a scrambler key and importing it.");
    RSI_securememory *smKey = [RSI_securememory dataWithLength:[RSI_scrambler keySize]];
    for (int i = 0; i < [RSI_scrambler keySize]; i++) {
        ((unsigned char *) [smKey mutableBytes])[i] = (rand() & 0xFF);
    }
    
    BOOL ret = [RSI_scrambler importKeyWithLabel:@"testkey" andTag:RSI_4_scrambler_TAG andValue:smKey withError:&err];
    XCTAssertTrue(ret, @"Failed to import the key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-SCRAMBLER: - verifying that a duplicate import returns the appropriate error.");
    ret = [RSI_scrambler importKeyWithLabel:@"testkey" andTag:RSI_4_scrambler_TAG andValue:smKey withError:&err];
    XCTAssertFalse(ret, @"The duplicate import succeeded and should not have.");
    XCTAssertTrue(err.code == RSIErrorKeyExists, @"The return code was not correct.  %@", [err localizedDescription]);
    
    NSLog(@"UT-SCRAMBLER: - searching for the key we just imported.");
    RSI_scrambler *scram = nil;
    scram = [RSI_scrambler allocExistingKeyForTag:RSI_4_scrambler_TAG withError:&err];
    XCTAssertNotNil(scram, @"Failed to find the key we just created.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    [scram autorelease];
    
    NSLog(@"UT-SCRAMBLER: - comparing the key value to the original.");
    ret = [smKey.rawData isEqualToData:[scram key].rawData];
    XCTAssertTrue(ret, @"The keys are not equal.");
}

/*
 *  Scramble/descramble contents while importing/exporting
 */
-(void) testUTSCRAMBLER_5_ScrambleSequence
{
    NSData *tData = [NSData dataWithBytes:RSI_4_scrambler_TEST_TEXT length:strlen(RSI_4_scrambler_TEST_TEXT) + 1];
    
    NSLog(@"UT-SCRAMBLER: - scrambling the test text.");
    RSI_scrambler *scram = nil;
    scram = [RSI_scrambler allocExistingKeyForTag:RSI_4_scrambler_TAG withError:&err];
    XCTAssertNotNil(scram, @"Failed to find the key we just created.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    [scram autorelease];
   
    NSMutableData *mdScrambled = [NSMutableData data];
    BOOL ret = [scram scramble:tData intoBuffer:mdScrambled withError:&err];
    XCTAssertTrue(ret, @"Failed to scramble the text.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-SCRAMBLER: - verifying the scrambled data is different than the original");
    ret = [mdScrambled isEqualToData:tData];
    XCTAssertFalse(ret, @"The data was equal and should not have been.");
    
    [RSI_common printBytes:tData withTitle:@"DATA BEFORE SCRAMBLING"];
    [RSI_common printBytes:mdScrambled withTitle:@"DATA AFTER SCRAMBLING"];
    
    NSLog(@"UT-SCRAMBLER: -  adding a new key.");
    NSString *scrambleTagAlt = @"scramtestAlt";
    RSI_securememory *smKey = [RSI_securememory dataWithLength:[RSI_scrambler keySize]];
    for (int i = 0; i < [RSI_scrambler keySize]; i++) {
        ((unsigned char *) [smKey mutableBytes])[i] = (rand() & 0xFF);
    }
    
    ret = [RSI_scrambler importKeyWithLabel:@"testkey2" andTag:scrambleTagAlt andValue:smKey withError:&err];
    XCTAssertTrue(ret, @"Failed to import the key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
        
    NSLog(@"UT-SCRAMBLER: - searching for both keys we just imported.");
    scram = [RSI_scrambler allocExistingKeyForTag:scrambleTagAlt withError:&err];
    RSI_scrambler *scramSameOld = [RSI_scrambler allocExistingKeyForTag:RSI_4_scrambler_TAG withError:&err];
    XCTAssertTrue(scram && scramSameOld, @"Failed to find the keys.   %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    [scram autorelease];
    [scramSameOld autorelease];
    
    NSLog(@"UT-SCRAMBLER: -  verifying the tags.");
    ret = [scram.tag isEqualToString:scrambleTagAlt] && [scramSameOld.tag isEqualToString:RSI_4_scrambler_TAG];
    XCTAssertTrue(ret, @"The tags don't match.");
    
    NSLog(@"UT-SCRAMBLER: - descrambling with the second key.");
    RSI_securememory *smDescrambled = [RSI_securememory dataWithLength:0];
    ret = [scram descramble:mdScrambled intoBuffer:smDescrambled withError:&err];
    XCTAssertTrue(ret, @"Failed to descramble the data   %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-SCRAMBLER: - comparing the data to the original (should not match).");
    ret = [smDescrambled.rawData isEqualToData:tData];
    XCTAssertFalse(ret, @"The data matched and should not have.");
    
    NSLog(@"UT-SCRAMBLER: - descrambling with the first key.");
    ret = [scramSameOld descramble:mdScrambled intoBuffer:smDescrambled withError:&err];
    XCTAssertTrue(ret, @"Failed to descramble the data   %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-SCRAMBLER: -  comparing the data to the original (should match).");
    ret = [smDescrambled.rawData isEqualToData:tData];
    XCTAssertTrue(ret, @"The data did not match and should have.");
    
    NSLog(@"UT-SCRAMBLER: - descrambling with a modified scrambled buffer.");
    for (int i = 10; i < [mdScrambled length]; i += 75) {
        ((unsigned char *) mdScrambled.mutableBytes)[i] = 0xFD;
    }
    
    ret = [scramSameOld descramble:mdScrambled intoBuffer:smDescrambled withError:&err];
    XCTAssertTrue(ret, @"Failed to descramble the data   %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-SCRAMBLER: - comparing the data to the original (should not match).");
    ret = [smDescrambled.rawData isEqualToData:tData];
    XCTAssertFalse(ret, @"The data did not have matched and did.");
    
    NSLog(@"UT-SCRAMBLER: - deleting the first key.");
    ret = [RSI_scrambler deleteKeyWithTag:RSI_4_scrambler_TAG withError:&err];
    XCTAssertTrue(ret, @"Failed to delete the key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-SCRAMBLER: - verifing the key is gone.");
    scramSameOld = [RSI_scrambler allocExistingKeyForTag:RSI_4_scrambler_TAG withError:&err];
    XCTAssertNil(scramSameOld, @"The key was found and it should not have been.");
    
    NSLog(@"UT-SCRAMBLER: - searching for the second key.");
    NSArray *arr = [RSI_scrambler findAllKeyTagsWithError:&err];
    XCTAssertNotNil(arr, @"Failed to find the key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);

    ret = [arr count] == 1 && [scrambleTagAlt isEqualToString:[arr objectAtIndex:0]];
    XCTAssertTrue(ret, @"Failed to find exactly one tag equal to the one we expected.");
    
    NSLog(@"UT-SCRAMBLER: - deleting the final key.");
    ret = [RSI_scrambler deleteAllKeysWithError:&err];
    XCTAssertTrue(ret, @"Failed to delete the key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);

    NSLog(@"UT-SCRAMBLER: - verifying the final key is indeed gone.");
    arr = [RSI_scrambler findAllKeyTagsWithError:&err];
    XCTAssertTrue(!arr || [arr count] == 0, @"Found keys and should not have.");
}

/*
 *  Methodically test scrambling buffers of different sizes
 */
-(void) testUTSCRAMBLER_6_MethodicalScrambling
{
    NSLog(@"UT-SCRAMBLER: - testing scrambling for buffers from 1 - 1025 bytes");
    for (int i = 1; i < 1026; i++) {
        [self unitTestWithBufferSized:i andStatus:NO];
    }
}

/*
 *  Check that key renaming works.
 */
-(void) testUTSCRAMLER_7_DoRename
{
    NSLog(@"UT-SCRAMBLER: - verifying that key renaming works as ecpected.");
    static NSString *RSI_4_SCRAM_NAME1 = @"SCRAM_OLDNAME";
    static NSString *RSI_4_SCRAM_NAME2 = @"SCRAM_MODIFIED";
    
    NSLog(@"UT-SCRAMBLER: - creating the scrambler key.");
    RSI_securememory *smKey = [RSI_securememory dataWithLength:[RSI_scrambler keySize]];
    for (int i = 0; i < [RSI_scrambler keySize]; i++) {
        ((unsigned char *) [smKey mutableBytes])[i] = (rand() & 0xFF);
    }
    
    BOOL ret = [RSI_scrambler importKeyWithLabel:RSI_4_SCRAM_NAME1 andTag:RSI_4_SCRAM_NAME1 andValue:smKey withError:&err];
    XCTAssertTrue(ret, @"Failed to import the key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-SCRAMBLER: - searching for the key we just imported.");
    RSI_scrambler *scram = nil;
    scram = [RSI_scrambler allocExistingKeyForTag:RSI_4_SCRAM_NAME1 withError:&err];
    XCTAssertNotNil(scram, @"Failed to find the key we just created.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
        
    NSLog(@"UT-SCRAMBLER: - scrambling the input data.");
    NSMutableData *mdScrambled = [NSMutableData data];
    NSData *tData = [NSData dataWithBytes:RSI_4_scrambler_TEST_TEXT length:strlen(RSI_4_scrambler_TEST_TEXT) + 1];
    ret = [scram scramble:tData intoBuffer:mdScrambled withError:&err];
    XCTAssertTrue(ret, @"Failed to scramble the text.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-SCRAMBLER: - verifying the scrambled data is different than the original");
    ret = [mdScrambled isEqualToData:tData];
    XCTAssertFalse(ret, @"The data was equal and should not have been.");
        
    NSLog(@"UT-SCRAMBLER: - releasing the key and renaming it.");
    [scram release];
    scram = nil;
    ret = [RSI_scrambler renameKeyForLabel:RSI_4_SCRAM_NAME1 andTag:RSI_4_SCRAM_NAME1 toNewLabel:RSI_4_SCRAM_NAME2 andNewTag:RSI_4_SCRAM_NAME2 withError:&err];
    XCTAssertTrue(ret, @"Failed to rename the key.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-SCRAMBLER: - loading the key with the new name.");
    RSI_scrambler *scramRenamed = [RSI_scrambler allocExistingKeyForTag:RSI_4_SCRAM_NAME2 withError:&err];
    XCTAssertNotNil(scramRenamed, @"Failed to find the key we just created.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    [scramRenamed autorelease];
     
    NSLog(@"UT-SCRAMBLER: - descrambling the data.");
    RSI_securememory *dDecrypted = [RSI_securememory data];
    ret = [scramRenamed descramble:mdScrambled intoBuffer:dDecrypted withError:&err];
    XCTAssertTrue(ret, @"Failed to descramble the data.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-SCRAMBLER: - comparing the data to the original.");
    XCTAssertTrue(strcmp(RSI_4_scrambler_TEST_TEXT, dDecrypted.bytes) == 0, @"The output buffer didn't match the original.");
    
    NSLog(@"UT-SCRAMBLER: - key renaming has been verified.");
}

/*
 *  Check that key deletion of a bad id returns the correct error.
 */
-(void) testUTSCRAMLER_8_DoDeleteBadId
{
    NSLog(@"UT-SCRAMBLER: - verifying that key deletion of a bad id works as ecpected.");
    BOOL ret = [RSI_scrambler deleteKeyWithTag:@"badkeytag1234" withError:&err];
    XCTAssertFalse(ret, @"The request succeeded and shouldn't have.");
    XCTAssertTrue(err.code == RSIErrorKeyNotFound, @"The error code returned was invalid (%u).  %@", err.code, [err localizedDescription]);    
    NSLog(@"UT-SCRAMBLER: - key deletion returned the correct error code.");
}

@end
