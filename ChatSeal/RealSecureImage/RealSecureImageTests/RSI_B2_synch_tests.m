//
//  RSI_B2_synch_tests.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 5/8/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "RealSecureImage.h"

// - constants
static time_t   RSI_B2_TEST_TIME      = 300;
static NSString *RSI_B2_STD_VAULT_PWD = @"foo";

// - declarations.
@interface RSI_B2_synch_tests : XCTestCase
@end

@interface RB2_Synch_Shutdown_Trigger : NSObject
@property (atomic, assign) BOOL shutdown;
@property (atomic, assign) BOOL abort;
-(NSMutableArray *) activeSeals;
-(void) addNewSeal:(NSString *) seal;
-(void) setDeletedSeal:(NSString *) seal;
-(BOOL) isSealDeleted:(NSString *) seal;
-(NSMutableArray *) remainingSeals;
-(void) addPackedDataToIdentify:(NSData *) d fromSeal:(NSString *) sid;
-(NSData *) popNextPackedData;
-(NSUInteger) numSealsCreated;
@end

@interface RB2_Generic_Thread : NSThread
-(id) initWithTrigger:(RB2_Synch_Shutdown_Trigger *) t;
-(BOOL) isShutdown;
-(void) haltTesting;
-(void) abortTesting;
-(RB2_Synch_Shutdown_Trigger *) trigger;
@end

@interface RB2_ReadWrite_Thread : RB2_Generic_Thread
@end

@interface RB2_IsValid_Thread : RB2_Generic_Thread
@end

@interface RB2_SealCreate_Thread : RB2_Generic_Thread
@end

@interface RB2_SealTweak_Thread : RB2_Generic_Thread
@end

@interface RB2_PackedData_Thread : RB2_Generic_Thread
@end

@interface RB2_IdentifyAndDelete_Thread : RB2_Generic_Thread
@end

/****************************
 RSI_B2_synch_tests
 ****************************/
@implementation RSI_B2_synch_tests
/*
 *  Object attributes
 */
{
    NSError *err;
    RB2_Synch_Shutdown_Trigger *trigger;
    NSMutableArray             *maThreads;
}

/*
 *  General purpose routine for creating seal images.
 */
+(UIImage *) createSealImageOfSize:(CGSize) szImg
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
    return ret;
}

/*
 *  Return a dictionary we can try packing with.
 */
+(NSDictionary *) testDictionary
{
    NSMutableDictionary *mdRet = [NSMutableDictionary dictionary];
    [mdRet setObject:[NSNumber numberWithInt:41412412] forKey:@"number"];
    [mdRet setObject:[NSDate date] forKey:@"date"];
    
    NSMutableData *md = [NSMutableData dataWithLength:351];
    SecRandomCopyBytes(kSecRandomDefault, [md length], md.mutableBytes);
    [mdRet setObject:md forKey:@"mem"];
    
    UIImage *img = [RSI_B2_synch_tests createSealImageOfSize:CGSizeMake(128, 128)];
    [mdRet setObject:img forKey:@"img"];
    
    return mdRet;
}


/*
 *  Verify that the given dictionary is what we packed.
 */
+(BOOL) verifyTestDictionary:(NSDictionary *) dict withOriginal:(NSDictionary *) orig
{
    if (!dict || [dict count] != 5) {
        NSLog(@"ERROR-VALIDATE: Failed to get the number of expected elements.");
        return NO;
    }

    if (![(NSObject *) [dict objectForKey:@"number"] isKindOfClass:[NSNumber class]] ||
        ![(NSNumber *) [dict objectForKey:@"number"] isEqualToNumber:[orig objectForKey:@"number"]]) {
        NSLog(@"ERROR-VALIDATE: The number is invalid.");
        return NO;
    }
    
    if (![(NSObject *) [dict objectForKey:@"date"] isKindOfClass:[NSDate class]] ||
        ![(NSDate *) [dict objectForKey:@"date"] isEqualToDate:[orig objectForKey:@"date"]]) {
        NSLog(@"ERROR-VALIDATE: The date is invalid.");
        return NO;
    }

    if (![(NSObject *) [dict objectForKey:@"mem"] isKindOfClass:[NSData class]] ||
        ![(NSData *) [dict objectForKey:@"mem"] isEqualToData:[orig objectForKey:@"mem"]]) {
        NSLog(@"ERROR-VALIDATE: The memory is invalid.");
        return NO;
    }

    if (![(NSObject *) [dict objectForKey:@"img"] isKindOfClass:[UIImage class]]) {
        NSLog(@"ERROR-VALIDATE: The image is invalid.");
        return NO;
    }
    
    CGSize szDecrypt = ((UIImage *) [dict objectForKey:@"img"]).size;
    CGSize szOrig    = ((UIImage *) [orig objectForKey:@"img"]).size;
    
    if ((int) szDecrypt.width != (int) szOrig.width || (int) szDecrypt.height != (int) szOrig.height) {
        NSLog(@"ERROR-VALIDATE: The image is the wrong size.");
        return NO;
    }
    return YES;
}

/*
 *  Simple prep between tests.
 */
-(void) setUp
{
    [super setUp];
    srand(32);              // predictable randomization
    err = nil;
    self.continueAfterFailure = NO;
    trigger = [[RB2_Synch_Shutdown_Trigger alloc] init];
    trigger.shutdown = NO;
    trigger.abort    = NO;
    maThreads = [[NSMutableArray alloc] init];
}

/*
 *  Finish up between tests.
 */
-(void) tearDown
{
    [trigger release];
    trigger = nil;
    
    [maThreads release];
    maThreads = nil;
}

/*
 *  Get the vault up and running.
 */
-(BOOL) testVaultCreation
{
    NSLog(@"UT-SYNCH: - creating a new vault.");
    BOOL ret = [RealSecureImage initializeVaultWithPassword:RSI_B2_STD_VAULT_PWD andError:&err];
    XCTAssertTrue(ret, @"Failed to initialize the vault.  %@", [err localizedDescription]);
    
    [RealSecureImage prepareForSealGeneration];
    
    return YES;
}

/*
 *  Start up the test threads.
 */
-(BOOL) testStartThreads
{
    NSLog(@"UT-SYNCH: - starting all the threads.");
    // - validity threads
    RB2_IsValid_Thread *iv = [[[RB2_IsValid_Thread alloc] initWithTrigger:trigger] autorelease];
    [maThreads addObject:iv];
    
    // - read/write threads
    for (int i = 0; i < 3; i++) {
        RB2_ReadWrite_Thread *rw = [[[RB2_ReadWrite_Thread alloc] initWithTrigger:trigger] autorelease];
        [maThreads addObject:rw];
    }
    
    // - a thread to create seals
    RB2_SealCreate_Thread *sc = [[[RB2_SealCreate_Thread alloc] initWithTrigger:trigger] autorelease];
    [maThreads addObject:sc];
    
    // - tweaking threads
    for (int i = 0; i < 3; i++) {
        RB2_SealTweak_Thread *stt = [[[RB2_SealTweak_Thread alloc] initWithTrigger:trigger] autorelease];
        [maThreads addObject:stt];
    }
    
    // - packing
    RB2_PackedData_Thread *pdt = [[[RB2_PackedData_Thread alloc] initWithTrigger:trigger] autorelease];
    [maThreads addObject:pdt];
    
    // - identification and deletion
    RB2_IdentifyAndDelete_Thread *idt = [[[RB2_IdentifyAndDelete_Thread alloc] initWithTrigger:trigger] autorelease];
    [maThreads addObject:idt];
    
    // - start them all
    for (NSThread *t in maThreads) {
        NSLog(@"UT-SYNCH: - ...%@", [[t class] description]);
        [t start];
    }
    
    return YES;
}

/*
 *  Verify the threads are all operating correctly and haven't started shutting down yet.
 */
-(BOOL) testWatchThreads
{
    time_t tBegin = time(NULL);
    time_t tEnd   = tBegin + RSI_B2_TEST_TIME;
    
    struct tm *tmEnd = localtime(&tEnd);
    NSLog(@"UT-SYNCH: - thread shutdown is expected after %02d:%02d.%02d", tmEnd->tm_hour, tmEnd->tm_min, tmEnd->tm_sec);
    for (;;) {
        // - check for abnormal scenarios.
        XCTAssertFalse(trigger.abort, @"ERROR: Tests were aborted!");
        if (trigger.abort) {
            return NO;
        }
        
        // - check for proper completion.
        if (trigger.shutdown) {
            BOOL threadsRemain = NO;
            for (NSThread *t in maThreads) {
                if (![t isFinished]) {
                    threadsRemain = YES;
                    break;
                }
            }
            
            // - all the threads are done so we can exit.
            if (!threadsRemain) {
                NSLog(@"UT-SYNCH: - all threads have exited successfully.");
                NSLog(@"UT-SYNCH: - there were %u seals created.", (unsigned) trigger.numSealsCreated);
                break;
            }
        }
        sleep(1);
        
        // - see if it is time to quit testing
        if (!trigger.shutdown && time(NULL) > tEnd) {
            NSLog(@"UT-SYNCH: - initiating gradual shutdown of multi-threaded testing.");
            trigger.shutdown = YES;
        }
    }
    return !trigger.abort;
}

/*
 *  Do final vault verification before shutting down.
 */
-(BOOL) testVaultHealthBeforeCompletion
{
    NSLog(@"UT-SYNCH: - verifying the vault.");
    [RealSecureImage closeVault];
    
    BOOL ret = [RealSecureImage openVaultWithPassword:RSI_B2_STD_VAULT_PWD andError:&err];
    XCTAssertTrue(ret, @"Failed to reopen the vault.  %@", [err localizedDescription]);
    
    NSArray *arr = [RealSecureImage availableSealsWithError:&err];
    XCTAssertNotNil(arr, @"No seal data was returned.  %@", [err localizedDescription]);
    
    XCTAssertEqual([arr count], 0, @"There should be no seals remaining.");
    
    return YES;
}

/*
 *  There is just one big test for this since a lot of things have to play here.
 */
-(void) testUTSYNC_1_Full
{
    NSLog(@"UT-SYNCH: - starting thread synchronization testing.");
    if (![self testVaultCreation] ||
        ![self testStartThreads] ||
        ![self testWatchThreads] ||
        ![self testVaultHealthBeforeCompletion]) {
        return;
    }
    NSLog(@"UT-SYNCH: - all tests completed successfully.");
}

@end

/************************************
 RB2_Synch_Shutdown_Trigger
 ************************************/
@implementation RB2_Synch_Shutdown_Trigger
/*
 *  Object attributes.
 */
{
    NSMutableArray *maSeals;
    NSUInteger numCreated;
    NSMutableArray *maDeleted;
    NSMutableDictionary *mdToIdentify;
}
@synthesize shutdown;
/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        maSeals      = [[NSMutableArray alloc] init];
        numCreated   = 0;
        maDeleted    = [[NSMutableArray alloc] init];
        mdToIdentify = [[NSMutableDictionary alloc] init];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [maSeals release];
    maSeals = nil;
    
    [maDeleted release];
    maDeleted = nil;
    
    [mdToIdentify release];
    mdToIdentify = nil;
    
    [super dealloc];
}

/*
 *  Return a list of active seals.
 */
-(NSMutableArray *) activeSeals
{
    @synchronized (self) {
        return [NSMutableArray arrayWithArray:maSeals];
    }
}

/*
 *  Add a new tracked seal.
 */
-(void) addNewSeal:(NSString *) seal
{
    if (!seal) {
        return;
    }
    
    @synchronized (self) {
        numCreated++;
        [maSeals addObject:seal];
    }
}

/*
 *  Mark a seal as deleted.
 */
-(void) setDeletedSeal:(NSString *) seal
{
    @synchronized (self) {
        [maDeleted addObject:seal];
    }
}

/*
 *  Checks if a seal was deleted.
 */
-(BOOL) isSealDeleted:(NSString *) seal
{
    @synchronized (self) {
        return [maDeleted containsObject:seal];
    }
}

/*
 *  Returns the list of seals that haven't been deleted yet.
 */
-(NSMutableArray *) remainingSeals
{
    @synchronized (self) {
        NSMutableArray *maRet = [NSMutableArray arrayWithArray:maSeals];
        [maRet removeObjectsInArray:maDeleted];
        return maRet;
    }
}

/*
 *  Add new packed data to the list.
 */
-(void) addPackedDataToIdentify:(NSData *) d fromSeal:(NSString *) sid
{
    @synchronized (self) {
        [mdToIdentify setObject:d forKey:sid];
    }
}

/*
 *  Pop new packed data to process.
 */
-(NSData *) popNextPackedData
{
    @synchronized (self) {
        NSArray *arrToId = mdToIdentify.allKeys;
        NSString *last   = [arrToId lastObject];
        if (last) {
            NSData *d = [[[mdToIdentify objectForKey:last] retain] autorelease];
            [mdToIdentify removeObjectForKey:last];
            NSLog(@"UT-SYNCH: popping data for seal %@", last);
            return d;
        }
        return nil;
    }
}

/*
 *  Return the total number of seals eventually created.
 */
-(NSUInteger) numSealsCreated
{
    return  numCreated;
}
@end

/************************************
 RB2_Generic_Thread
 ************************************/
@implementation RB2_Generic_Thread
/*
 *  Object attributes
 */
{
    RB2_Synch_Shutdown_Trigger *trigger;
}

/*
 *  Initialize the object.
 */
-(id) initWithTrigger:(RB2_Synch_Shutdown_Trigger *)t
{
    self = [super init];
    if (self) {
        trigger = [t retain];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [trigger release];
    trigger = nil;
    
    [super dealloc];
}

/*
 *  Determines if the trigger indicates shutdown is necessary.
 */
-(BOOL) isShutdown
{
    return trigger.shutdown;
}

/*
 *  Allow a thread to stop testing.
 */
-(void) haltTesting
{
    trigger.shutdown = YES;
}

/*
 *  Abort further testing.
 */
-(void) abortTesting
{
    trigger.abort = YES;
}

/*
 *  Return a handle to the active trigger.
 */
-(RB2_Synch_Shutdown_Trigger *) trigger
{
    return [[trigger retain] autorelease];
}
@end

/*****************************
 RB2_ReadWrite_Thread
 *****************************/
@implementation RB2_ReadWrite_Thread
/*
 *  The purpose of this thread is to keep reading/writing secure files for its lifetime.
 */
-(void) main
{
    NSLog(@"UT-SYNCH (read/write): starting thread.");
    while (![self isShutdown]) {
        NSUUID *uuid = [NSUUID UUID];
        NSString *fname = [uuid UUIDString];
        
        NSMutableData *mdSample = [NSMutableData dataWithLength:256];
        if (SecRandomCopyBytes(kSecRandomDefault, [mdSample length], (uint8_t *) [mdSample mutableBytes]) != 0) {
            NSLog(@"ERROR: Failed to copy random bytes!");
            [self abortTesting];
            return;
        }

        NSError *tmp = nil;
        BOOL ret = [RealSecureImage writeVaultData:mdSample toFile:fname withError:&tmp];
        if (!ret) {
            NSLog(@"ERROR: Failed to write secure vault data.  %@", [tmp localizedDescription]);
            [self abortTesting];
            return;
        }
        
        RSISecureData *sd = nil;
        ret = [RealSecureImage readVaultFile:fname intoData:&sd withError:&tmp];
        if (!ret) {
            NSLog(@"ERROR: Failed to re-read the encrypted file.  %@", [tmp localizedDescription]);
            [self abortTesting];
            return;
        }
        
        if (![sd.rawData isEqualToData:mdSample]) {
            NSLog(@"ERROR: The re-read data is not equal to the original.");
            [self abortTesting];
            return;
        }
        
        NSURL *u = [RealSecureImage absoluteURLForVaultFile:fname withError:&tmp];
        if (!u) {
            NSLog(@"ERROR: Failed to get the absolute URL for a source file.");
            [self abortTesting];
            return;
        }
        
        if (![[NSFileManager defaultManager] removeItemAtURL:u error:nil]) {
            NSLog(@"ERROR: Failed to remove the temporary encrypted file %@.", [u path]);
            [self abortTesting];
            return;
        }
    }
    NSLog(@"UT-SYNCH (read/write): exiting thread.");
}

@end

/*****************************
 RB2_IsValid_Thread
 *****************************/
@implementation RB2_IsValid_Thread

/*
 *  Just repeatedly check that things are good.
 */
-(void) main
{
    NSLog(@"UT-SYNCH (is-valid): starting thread.");
    while (![self isShutdown]) {
        BOOL ret = [RealSecureImage hasVault];
        if (!ret) {
            NSLog(@"ERROR: The vault doesn't exist as it is expected to.");
            [self abortTesting];
            return;
        }
        
        ret = [RealSecureImage isVaultOpen];
        if (!ret) {
            NSLog(@"ERROR: The vault is not open as it is expected to be.");
            [self abortTesting];
            return;
        }
    }
    NSLog(@"UT-SYNCH (is-valid): exiting thread.");
}

@end

/***************************
 RB2_SealCreate_Thread
 ***************************/
@implementation RB2_SealCreate_Thread
/*
 *  Create seals until we are told to stop.
 */
-(void) main
{
    NSLog(@"UT-SYNCH (create): starting thread.");
    RSISecureSeal_Color_t cur = 0;
    while (![self isShutdown]) {
        @autoreleasepool {
            UIImage *img = [RSI_B2_synch_tests createSealImageOfSize:CGSizeMake(256, 256)];
            if (!img) {
                NSLog(@"ERROR: Failed to create a seal image.");
                [self abortTesting];
                return;
            }
            
            NSError *tmp = nil;
            NSString *sid = [RealSecureImage createSealWithImage:img andColor:cur andError:&tmp];
            if (!sid) {
                NSLog(@"ERROR: Failed to create a new seal.  %@", [tmp localizedDescription]);
                [self abortTesting];
                return;
            }
            cur = (cur + 1) % RSSC_NUM_SEAL_COLORS;
            [[self trigger] addNewSeal:sid];
            NSLog(@"UT-SYNCH (create): The new seal %@ was created.", sid);
            [RealSecureImage prepareForSealGeneration];
        }
        
        // - give the other threads time to play
        sleep(1);
    }
    NSLog(@"UT-SYNCH (create): exiting thread.");
}
@end

/***************************
 RB2_SealTweak_Thread
 ***************************/
@implementation RB2_SealTweak_Thread
/*
 *  Tweak the seals by playing with their external APIs.
 */
-(void) main
{
    NSLog(@"UT-SYNCH (tweak): starting thread.");
    NSMutableArray *maProcessed = [NSMutableArray array];
    for (;;) {
        NSMutableArray *arrSeals = [NSMutableArray arrayWithArray:[[self trigger] activeSeals]];
        if ([self isShutdown]) {
            // - when we've processed all the seals for the last time, we can exit.
            if ([maProcessed count] == [arrSeals count]) {
                break;
            }
        }
        
        // - reset if we're still waiting.
        if ([arrSeals count] == [maProcessed count]) {
            [maProcessed removeAllObjects];
        }
        
        // - identify a seal to mess with.
        NSString *sid = nil;
        for (;;) {
            if ([arrSeals count] == 0) {
                break;
            }
            
            sid = (NSString *) [arrSeals objectAtIndex:rand() % [arrSeals count]];
            if (![maProcessed containsObject:sid]) {
                break;
            }
            [arrSeals removeObject:sid];
        }
        
        if (!sid) {
            continue;
        }
        
        NSError *tmp = nil;
        @autoreleasepool {
            RSISecureSeal *sseal = [RealSecureImage sealForId:sid andError:&tmp];
            if (!sseal) {
                if (![[self trigger] isSealDeleted:sid]) {
                    NSLog(@"ERROR: Failed to retrieve a known seal %@. %@", sid, [tmp localizedDescription]);
                    [self abortTesting];
                    return;
                }
            }
            
            NSString *tmpSid = [sseal sealId];
            NSString *tmpSSid = [sseal safeSealIdWithError:nil];
            BOOL     isOwned  = [sseal isOwned];
            NSURL    *uOnDisk = [sseal onDiskFile];
            UIImage *img      = [sseal safeSealImageWithError:nil];
            NSData  *dOrig    = [sseal originalSealImageWithError:nil];
            if (!tmpSid || !tmpSSid || !isOwned || !uOnDisk || !img || !dOrig) {
                if (![[self trigger] isSealDeleted:sid]) {
                    NSLog(@"ERROR: Failed to get basic info from a known seal %@", sid);
                    [self abortTesting];
                    return;
                }
            }
            
            BOOL ret = [sseal setInvalidateOnSnapshot:(rand() % 2 == 0) ? YES : NO withError:&tmp];
            if (!ret) {
                if (![[self trigger] isSealDeleted:sid]) {
                    NSLog(@"ERROR: Failed to set the invalidate on snapshot flag on seal %@.  %@", tmpSid, [tmp localizedDescription]);
                    [self abortTesting];
                    return;
                }
            }
            
            ret = [sseal setSelfDestruct:(rand() % 363) + 1 withError:&tmp];
            if (!ret) {
                if (![[self trigger] isSealDeleted:sid]) {
                    NSLog(@"ERROR: Failed to set the self destruct on seal %@.  %@", tmpSid, [tmp localizedDescription]);
                    [self abortTesting];
                    return;
                }
            }
        }
        [maProcessed addObject:sid];
    }
    
    NSLog(@"UT-SYNCH (tweak): exiting thread.");
}
@end

/************************************
 RB2_PackedData_Thread
 ************************************/
@implementation RB2_PackedData_Thread
/*
 *  Every time new seals pop up, pack some data and store it for a different thread to identify.
 */
-(void) main
{
    NSLog(@"UT-SYNCH (packed-data): starting thread.");
    BOOL hasStarted = NO;
    
    NSMutableArray *maProcessed = [NSMutableArray array];
    for (;;) {
        NSMutableArray *arrRem = [[self trigger] remainingSeals];
        if ([self isShutdown]) {
            if ([arrRem count] == 0) {
                break;
            }
            sleep(1);
            NSLog(@"UT-SYNCH (packed-data): waiting for remaining to be zero.");
        }
        
        if (!hasStarted && [arrRem count] < 10) {
            continue;
        }
        hasStarted = YES;
        
        [arrRem removeObjectsInArray:maProcessed];
        if (![arrRem count]) {
            continue;
        }
        
        @autoreleasepool {
            NSString *sid = [arrRem objectAtIndex:rand() % [arrRem count]];
            
            NSError *tmp = nil;
            RSISecureSeal *ss = [RealSecureImage sealForId:sid andError:&tmp];
            if (!ss) {
                NSLog(@"ERROR: Failed to retrieve a known seal %@.  %@", sid, [tmp localizedDescription]);
                [self abortTesting];
                return;
            }
            
            NSDictionary *dToPack = [RSI_B2_synch_tests testDictionary];
            UIImage *img          = [RSI_B2_synch_tests createSealImageOfSize:CGSizeMake(1024, 1024)];
            NSData *dPacked       = [ss packRoleBasedMessage:dToPack intoImage:img withError:&tmp];
            if (!dPacked) {
                NSLog(@"ERROR: Failed to pack the content using seal %@.  %@", sid, [tmp localizedDescription]);
                [self abortTesting];
                return;
            }
            
            NSLog(@"UT-SYNCH (packed-data): added packed data to identify for seal %@", sid);
            [maProcessed addObject:sid];
            [[self trigger] addPackedDataToIdentify:dPacked fromSeal:sid];
        }
    }
    
    NSLog(@"UT-SYNCH (packed-data): exiting thread.");
}

@end

/********************************
 RB2_IdentifyAndDelete_Thread
 ********************************/
@implementation RB2_IdentifyAndDelete_Thread
/*
 *  When data is packed, this thread will use it to find seals to delete.
 */
-(void) main
{
    NSLog(@"UT-SYNCH (identify-delete): starting thread.");
    for (;;) {
        if ([self isShutdown]) {
            if ([[[self trigger] remainingSeals] count] == 0) {
                break;
            }
        }
        
        @autoreleasepool {
            NSData *dToId = [[self trigger] popNextPackedData];
            if (!dToId) {
                sleep(1);
                continue;
            }
            
            NSError *tmp = nil;
            RSISecureMessage *sm = [RealSecureImage identifyPackedContent:dToId withFullDecryption:YES andError:&tmp];
            if (!sm) {
                NSLog(@"ERROR: Failed to identify a known packed data file.  %@", [tmp localizedDescription]);
                [self abortTesting];
                return;
            }
            
            NSLog(@"UT-SYNCH (identify-delete): identified data for seal %@", sm.sealId);
            
            if (![[[self trigger] remainingSeals] containsObject:sm.sealId]) {
                NSLog(@"ERROR: The identified seal %@ doesn't exist as remaining!", sm.sealId);
                [self abortTesting];
                return;
            }
            
            [[self trigger] setDeletedSeal:sm.sealId];
            BOOL ret = [RealSecureImage deleteSealForId:sm.sealId andError:&tmp];
            if (!ret) {
                NSLog(@"ERROR: Failed to delete the seal %@.  %@", sm.sealId, [tmp localizedDescription]);
                [self abortTesting];
                return;
            }
            
            RSISecureSeal *ss = [RealSecureImage sealForId:sm.sealId andError:nil];
            if (ss) {
                NSLog(@"ERROR: Found a seal we thought we deleted.");
                [self abortTesting];
                return;
            }
            
            NSLog(@"UT-SYNCH (identify-delete): deleted seal %@", sm.sealId);            
        }
    }

    NSLog(@"UT-SYNCH (identify-delete): exiting thread.");
}

@end
