//
//  ChatSealDebug_message.m
//  ChatSeal
//
//  Created by Francis Grolemund on 11/15/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "ChatSealDebug_message.h"
#import "ChatSeal.h"
#import "UIImageGeneration.h"

#ifdef CHATSEAL_DEBUGGING_ROUTINES
#import <AssetsLibrary/AssetsLibrary.h>

// - constants
static const NSUInteger CS_DEBUG_TARGET_EMBEDDED_IMAGE_LENGTH = (128 * 1024);
static const CGFloat    CS_DEBUG_MINUMUM_EMBEDDED_SCALE       = 0.15f;
static const NSString   *CS_DEFAULT_JAPANESE                  = @"漢字仮名交じり文";

// - forward declarations
@interface ChatSealDebug_message (capacity)
+(void) testCapacityWithMessage:(ChatSealMessage *) psm withNumberOfItems:(NSUInteger) numItems;
@end

@interface ChatSealDebug_message (correctness)
+(void) testCorrectnessWithCurrentVault;
@end

#endif

/************************
 ChatSealDebug_message
 ************************/
@implementation ChatSealDebug_message
/*
 *  Append a large number of items to a single message to test performance.
 */
+(void) appendRandomContentToMessage:(ChatSealMessage *) psm withNumberOfItems:(NSUInteger) numItems
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    [ChatSealDebug_message testCapacityWithMessage:psm withNumberOfItems:numItems];
#endif
}

/*
 *  Verify that the messaging infrastructure works correctly.
 */
+(void) destructivelyVerifyMessagingInfrastructure
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    [ChatSealDebug_message testCorrectnessWithCurrentVault];
#endif
}
@end


/*********************************
 ChatSealDebug_message (capacity)
 *********************************/
@implementation ChatSealDebug_message (capacity)

// - I just want to be doubly sure that these aren't visible.
#ifdef CHATSEAL_DEBUGGING_ROUTINES

/*
 *  Using the provided sample images, append fake content to the message.
 */
+(void) appendRandomContentToMessage:(ChatSealMessage *)psm withNumberOfItems:(NSUInteger)numItems andSampleImages:(NSArray *) arrSamples
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    if ([arrSamples count] < 1) {
        NSLog(@"ERROR: Sample images not provided.");
        return;
    }
    
    NSError *err = nil;
    if (![psm pinSecureContent:&err]) {
        NSLog(@"ERROR: Failed to pin secure content.  %@", [err localizedDescription]);
        return;
    }
    
    NSString *LOREM_IPSUM = @"Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";
    NSUInteger len = [LOREM_IPSUM length];
    @autoreleasepool {
        for (NSUInteger i = 0; i < numItems; i++) {
            NSUInteger toIndex = 10 + ((NSUInteger) rand() % (len - 11));
            NSString *text = [LOREM_IPSUM substringToIndex:toIndex];
            NSMutableArray *maToAdd = [NSMutableArray array];
            switch (rand() % 4) {
                case 0:
                    [maToAdd addObject:text];
                    break;
                    
                case 1:
                    [maToAdd addObject:[arrSamples objectAtIndex:(NSUInteger) rand() % [arrSamples count]]];
                    break;
                    
                case 2:
                    [maToAdd addObject:text];
                    [maToAdd addObject:[arrSamples objectAtIndex:(NSUInteger) rand() % [arrSamples count]]];
                    break;
                    
                case 3:
                    [maToAdd addObject:[arrSamples objectAtIndex:(NSUInteger) rand() % [arrSamples count]]];
                    [maToAdd addObject:text];
                    break;
            }
            
            if (![psm addNewEntryOfType:PSMT_GENERIC withContents:maToAdd onCreationDate:nil andError:&err]) {
                NSLog(@"ERROR: Failed to add the new message entry at index %lu.  %@", (unsigned long) i, [err localizedDescription]);
                break;
            }
            NSLog(@"DEBUG: Added new entry %lu.", (unsigned long)(i + 1));
        }
    }
    [psm unpinSecureContent];
#endif
}

/*
 *  Append a bunch of random content to test performance and capacity constraints.
 */
+(void) testCapacityWithMessage:(ChatSealMessage *) psm withNumberOfItems:(NSUInteger) numItems
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    static NSMutableArray *maSampleImages = nil;
    static const NSUInteger NUM_SAMPLES   = 10;
    if (maSampleImages) {
        [ChatSealDebug_message appendRandomContentToMessage:psm withNumberOfItems:numItems andSampleImages:maSampleImages];
        return;
    }
    
    // - no samples yet exist, so build them
    NSLog(@"DEBUG: Building the sample image list.");
    maSampleImages = [[NSMutableArray alloc] init];
    ALAssetsLibrary *alib = [[[ALAssetsLibrary alloc] init] autorelease];
    [alib enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        if (!group) {
            [ChatSealDebug_message appendRandomContentToMessage:psm withNumberOfItems:numItems andSampleImages:maSampleImages];
            return;
        }
        
        if ([maSampleImages count] >= NUM_SAMPLES) {
            *stop = YES;
            return;
        }
        
        if ([group numberOfAssets] == 0) {
            return;
        }
        
        [group enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop2) {
            if (!result) {
                return;
            }
            
            if ([maSampleImages count] >= NUM_SAMPLES) {
                *stop2 = YES;
                return;
            }
            
            UIImageOrientation io = UIImageOrientationUp;
            switch (result.defaultRepresentation.orientation) {
                case ALAssetOrientationUp:
                    io = UIImageOrientationUp;
                    break;
                    
                case ALAssetOrientationDown:
                    io = UIImageOrientationDown;
                    break;
                    
                case ALAssetOrientationLeft:
                    io = UIImageOrientationLeft;
                    break;
                    
                case ALAssetOrientationRight:
                    io = UIImageOrientationRight;
                    break;
                    
                case ALAssetOrientationUpMirrored:
                    io = UIImageOrientationUpMirrored;
                    break;
                    
                case ALAssetOrientationDownMirrored:
                    io = UIImageOrientationDownMirrored;
                    break;
                    
                case ALAssetOrientationLeftMirrored:
                    io = UIImageOrientationLeftMirrored;
                    break;
                    
                case ALAssetOrientationRightMirrored:
                    io = UIImageOrientationRightMirrored;
                    break;
            }
            
            UIImage *image = [UIImage imageWithCGImage:result.defaultRepresentation.fullResolutionImage scale:result.defaultRepresentation.scale orientation:io];
            
            // - scaling is going to be performed based on how much we can reasonably send in the
            //   message while trying to maintain a decent quality.
            // - we can use the Apple JPEG conversion API to compute the scaling factor since it will be optimized
            NSData *d                = UIImageJPEGRepresentation(image, [RealSecureImage defaultJPEGQualityForMessaging]);
            NSUInteger currentLength = [d length];
            if (currentLength > CS_DEBUG_TARGET_EMBEDDED_IMAGE_LENGTH) {
                CGFloat scale = (CGFloat) CS_DEBUG_TARGET_EMBEDDED_IMAGE_LENGTH/(CGFloat) currentLength;
                if (scale < CS_DEBUG_MINUMUM_EMBEDDED_SCALE) {
                    scale = CS_DEBUG_MINUMUM_EMBEDDED_SCALE;
                }
                image = [UIImageGeneration image:image scaledTo:scale asOpaque:YES];
            }
            
            if (image) {
                [maSampleImages addObject:image];
                NSLog(@"DEBUG: Added a new sample to the list.");
            }
            else {
                NSLog(@"ERROR: Image should never be NULL.");
            }
        }];
        
    } failureBlock:^(NSError *err) {
        NSLog(@"ERROR: enumeration of the asset library failed.  %@", [err localizedDescription]);
    }];
    
#endif    
}
@end


/************************************
  ChatSealDebug_message (correctness)
 ************************************/
@implementation ChatSealDebug_message (correctness)

/*
 *  Clear out all existing messages.
 */
+(BOOL) test_1_clearMessages
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"MSG-DEBUG:  Test-1:  Clearing all existing messages.");
    NSError *err = nil;
    if (![ChatSealMessage destroyAllMessagesWithError:&err]) {
        NSLog(@"ERROR:  Failed to destroy all messages.  %@", [err localizedDescription]);
        return NO;
    }
    NSLog(@"MSG-DEBUG:  Test-1:  All messages have been cleared successfully.");
#endif
    return YES;
}

/*
 *  Generate a decoy image.
 */
+(UIImage *) fakeDecoy
{
    UIImage *ret = nil;
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    CGSize sz = CGSizeMake(800, 600);
    UIGraphicsBeginImageContextWithOptions(sz, YES, 1.0f);
    [[UIColor redColor] setFill];
    UIRectFill(CGRectMake(0.0f, 0.0f, sz.width, sz.height));
    [[UIColor blueColor] setStroke];
    CGContextSetLineWidth(UIGraphicsGetCurrentContext(), 4.0f);
    CGContextBeginPath(UIGraphicsGetCurrentContext());
    CGContextMoveToPoint(UIGraphicsGetCurrentContext(), 0.0f, 0.0f);
    CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), sz.width, sz.height);
    CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), sz.width, 0.0f);
    CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), 0.0f, sz.height);
    CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), 0.0f, 0.0f);
    CGContextStrokePath(UIGraphicsGetCurrentContext());
    ret = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
#endif
    return ret;
}

/*
 *  Generate a fake image that can be used as a photo in the message.
 */
+(UIImage *) fakePhoto
{
    UIImage *ret = nil;
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    CGSize sz = CGSizeMake(200 + (rand() % 200), 200 + (rand() % 200));
    UIGraphicsBeginImageContextWithOptions(sz, YES, 1.0f);
    [[UIColor colorWithRed:(CGFloat) (rand() % 100)/100.0f green:(CGFloat) (rand() % 100)/100.0f blue:(CGFloat) (rand() % 100)/100.0f alpha:1.0f] setFill];
    UIRectFill(CGRectMake(0.0f, 0.0f, sz.width, sz.height));
    [[UIColor blackColor] setStroke];
    CGContextSetLineWidth(UIGraphicsGetCurrentContext(), 2.0f);
    UIRectFrame(CGRectMake(0.0f, 0.0f, sz.width, sz.height));
    ret = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
#endif
    return ret;
    
}

/*
 *  Add a new message
 */
+(BOOL) test_2_addMessage
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"MSG-DEBUG:  Test-2:  Adding a single message.");
    NSError *err = nil;
    NSArray *arrSample = [NSArray arrayWithObjects:@"The quick brown fox jumped over the lazy dog.",
                                                   [ChatSealDebug_message fakePhoto],
                                                    CS_DEFAULT_JAPANESE,
                                                    nil];
    ChatSealMessage *psm = [ChatSeal createMessageOfType:PSMT_GENERIC withDecoy:[ChatSealDebug_message fakeDecoy] andData:arrSample andError:&err];
    if (!psm) {
        NSLog(@"ERROR:  Failed to create the new message.  %@", [err localizedDescription]);
        return NO;
    }
    NSInteger numEntries = [psm numEntriesWithError:&err];
    if (numEntries != 1) {
        NSLog(@"ERROR:  The number of entries is incorrect.");
        return NO;
    }
    
    if (![psm pinSecureContent:&err]) {
        NSLog(@"ERROR:  Failed to pin the message.  %@", [err localizedDescription]);
        return NO;
    }

    BOOL ret = YES;
    ChatSealMessageEntry *me = [psm entryForIndex:0 withError:&err];
    if (me) {
        NSData *dPacked = [me sealedMessageWithError:&err];
        if (dPacked && [dPacked length]) {
            UIImage *converted = [UIImage imageWithData:dPacked];
            if (converted) {
                NSLog(@"MSG-DEBUG:  the packed data is %lu bytes", (unsigned long) [dPacked length]);
            }
            else {
                NSLog(@"ERROR:  The returned packed image is not valid.");
                ret = NO;
            }
        }
        else {
            NSLog(@"ERROR:  Failed to get a packed image for the new message.  %@", [err localizedDescription]);
            ret = NO;
        }

        // - verify that we can find the entry by id.
        if (ret) {
            NSString *entryId = [me entryId];
            if (entryId) {
                ChatSealMessageEntry *meById = [psm entryForId:entryId withError:&err];
                if (!meById) {
                    NSLog(@"ERROR: Failed to get an entry using its id of %@.  %@", entryId, [err localizedDescription]);
                    ret = NO;
                }
            }
            else {
                NSLog(@"ERROR: Failed to get a string entry id.");
                ret = NO;
            }
        }
    }
    else {
        NSLog(@"ERROR:  Failed to get an entry.  %@", [err localizedDescription]);
        ret = NO;
    }
    [psm unpinSecureContent];
    if (!ret) {
        return NO;
    }
    NSLog(@"MSG-DEBUG:  Test-2:  The message was added successfully.");    
#endif
    return YES;
}

/*
 *  Create a new message and append 3 items to it for a total of four entries.
 */
+(BOOL) test_3_addEntries
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"MSG-DEBUG:  Test-3:  Appending simple entries.");
    NSError *err = nil;
    NSArray *arrEntries = [NSArray arrayWithObjects:@"The first entry.", @"Something in second", @"Random third: asdas23r", @"Fourth coming up last.", nil];
    
    // - start by creating a new message
    NSLog(@"MSG-DEBUG:  ...adding a new message.");
    ChatSealMessage *psm = [ChatSeal createMessageOfType:PSMT_GENERIC withDecoy:[ChatSealDebug_message fakeDecoy] andData:[NSArray arrayWithObject:[arrEntries objectAtIndex:0]] andError:&err];
    if (!psm) {
        NSLog(@"ERROR: Failed to create a new message.  %@", [err localizedDescription]);
        return NO;
    }
    
    // - now add 3 entries
    for (NSUInteger i = 1; i < [arrEntries count]; i++) {
        NSString *sEntry = [arrEntries objectAtIndex:i];
        NSLog(@"MSG-DEBUG:  ...appending entry %lu.", (unsigned long) i);
        if (![psm addNewEntryOfType:PSMT_GENERIC withContents:[NSArray arrayWithObject:sEntry] onCreationDate:nil andError:&err]) {
            NSLog(@"ERROR:  Failed to add the new entry.");
            return NO;
        }
    }
    
    // - now verify the 4 entries.
    NSLog(@"MSG-DEBUG:  ...verifying the entries");
    NSInteger numEntries = [psm numEntriesWithError:&err];
    if (numEntries < 0) {
        NSLog(@"ERROR:  Failed to retrieve an entry count.  %@", [err localizedDescription]);
        return NO;
    }
    
    if (numEntries != [arrEntries count]) {
        NSLog(@"ERROR:  The message doesn't have the required number of entries.  %ld != %lu", (long) numEntries, (unsigned long) [arrEntries count]);
        return NO;
    }

    BOOL ret = YES;
    if (![psm pinSecureContent:&err]) {
        NSLog(@"ERROR:  Failed to pin the secure content.  %@", [err localizedDescription]);
        return NO;
    }
    
    for (NSInteger i = 0; i < numEntries; i++) {
        ChatSealMessageEntry *me = [psm entryForIndex:(NSUInteger) i withError:&err];
        if (!me) {
            NSLog(@"ERROR:  Failed to retrieve the entry at index %lu.  %@", (unsigned long) i, [err localizedDescription]);
            ret = NO;
            break;
        }
        
        if ([me numItems] != 1) {
            NSLog(@"ERROR:  The entry at index %lu has the wrong number of items.", (unsigned long) i);
            ret = NO;
            break;
        }
        
        if ([me isItemAnImageAtIndex:0]) {
            NSLog(@"ERROR:  The item at index %lu should be a string.", (unsigned long) i);
            ret = NO;
            break;
        }
        
        NSString *sStored = [me itemAsStringAtIndex:0];
        NSString *sEntry = [arrEntries objectAtIndex:(NSUInteger) i];
        
        if (![sEntry isEqualToString:sStored]) {
            NSLog(@"ERROR:  The item at index %lu is not equal to what it should be.  %@ != %@", (unsigned long) i, sStored, sEntry);
            ret = NO;
            break;
        }
        
        NSData *dPacked = [me sealedMessageWithError:&err];
        if (!dPacked || [dPacked length] == 0) {
            NSLog(@"ERROR:  Failed to pack the entry.  %@", [err localizedDescription]);
            ret = NO;
            break;
        }
        
        NSLog(@"MSG-DEBUG:  ...the packed image is %lu bytes long.", (unsigned long) [dPacked length]);
    }
    [psm unpinSecureContent];
    if (!ret) {
        return NO;
    }

    NSLog(@"MSG-DEBUG:  Test-3:  Basic appending works.");
#endif
    return YES;
}

/*
 *  Very predictable and reproducible sorting testing.
 */
+(BOOL) test_4_simpleInsertions
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"MSG-DEBUG:  Test-4:  Verifying simple sorted insertions.");
    NSError *err = nil;
    NSArray *arrEntries = [NSArray arrayWithObjects:@"ONE", @"TWO", @"THREE", @"FOUR", nil];
    // - start by creating a new message
    NSLog(@"MSG-DEBUG:  ...adding a new message.");
    ChatSealMessage *psm = [ChatSeal createMessageOfType:PSMT_GENERIC withDecoy:[ChatSealDebug_message fakeDecoy] andData:[NSArray arrayWithObject:[arrEntries objectAtIndex:0]] andError:&err];
    if (!psm) {
        NSLog(@"ERROR: Failed to create a new message.  %@", [err localizedDescription]);
        return NO;
    }
    
    // - now add 3 entries, but in out of sequece dates to force insertions.
    for (NSUInteger i = 1; i < [arrEntries count]; i++) {
        NSString *sEntry = [arrEntries objectAtIndex:i];
        NSLog(@"MSG-DEBUG:  ...appending entry %lu.", (unsigned long) i);
        NSDate *dtCreate = nil;
        switch (i) {
            case 1:
                dtCreate = [NSDate dateWithTimeIntervalSince1970:0];
                break;
                
            case 2:
                dtCreate = [NSDate dateWithTimeIntervalSince1970:1000];
                break;
                
            case 3:
                dtCreate = [NSDate dateWithTimeIntervalSinceNow:1000];
                break;
        }
        if (![psm addNewEntryOfType:PSMT_GENERIC withContents:[NSArray arrayWithObject:sEntry] onCreationDate:dtCreate andError:&err]) {
            NSLog(@"ERROR:  Failed to add the new entry.");
            return NO;
        }
    }
    
    // - now verify the 4 entries.
    NSLog(@"MSG-DEBUG:  ...verifying the entries");
    NSInteger numEntries = [psm numEntriesWithError:&err];
    if (numEntries < 0) {
        NSLog(@"ERROR:  Failed to retrieve an entry count.  %@", [err localizedDescription]);
        return NO;
    }
    
    if (numEntries != [arrEntries count]) {
        NSLog(@"ERROR:  The message doesn't have the required number of entries.  %ld != %lu", (long) numEntries, (unsigned long) [arrEntries count]);
        return NO;
    }
    
    if (![psm pinSecureContent:&err]) {
        NSLog(@"ERROR:  Failed to pin the message.  %@", [err localizedDescription]);
        return NO;
    }
    
    BOOL ret = YES;
    for (NSInteger i = 0; i < numEntries; i++) {
        ChatSealMessageEntry *me = [psm entryForIndex:(NSUInteger) i withError:&err];
        if (!me) {
            NSLog(@"ERROR:  Failed to retrieve the entry at index %lu.  %@", (unsigned long) i, [err localizedDescription]);
            ret = NO;
            break;
        }
        
        if ([me numItems] != 1) {
            NSLog(@"ERROR:  The entry at index %lu has the wrong number of items.", (unsigned long) i);
            ret = NO;
            break;
        }
        
        if ([me isItemAnImageAtIndex:0]) {
            NSLog(@"ERROR:  The item at index %lu should be a string.", (unsigned long) i);
            ret = NO;
            break;
        }
        
        NSString *sStored = [me itemAsStringAtIndex:0];
        NSUInteger compareTo = 0;
        switch (i) {
            case 0:
                compareTo = 1;
                break;
                
            case 1:
                compareTo = 2;
                break;
                
            case 2:
                compareTo = 0;
                break;
                
            case 3:
                compareTo = 3;
                break;
        }
        NSString *sEntry = [arrEntries objectAtIndex:compareTo];
        
        if (![sEntry isEqualToString:sStored]) {
            NSLog(@"ERROR:  The item at index %lu is not equal to what it should be.  %@ != %@", (unsigned long) i, sStored, sEntry);
            ret = NO;
            break;
        }
    }
    
    [psm unpinSecureContent];
    if (!ret) {
        return NO;
    }
    
    NSLog(@"MSG-DEBUG:  Test-4:  Simple insertions verified successfully..");
#endif
    return YES;
}

/*
 *  Verify more complex sorted insertion of new entries by date works correctly.
 */
+(BOOL) test_5_sortedInsertions
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSString *qbf                = @"The quick brown fox jumped over the lazy dog.";
    NSMutableArray *maTestEntries = [NSMutableArray array];
    NSMutableArray *maTestDates  = [NSMutableArray array];
    
    NSLog(@"MSG-DEBUG:  Test-5:  Verifying sorted insertions.");
    NSError *err = nil;
    NSLog(@"MSG-DEBUG:  ...adding a new message.");
    ChatSealMessage *psm = [ChatSeal createMessageOfType:PSMT_GENERIC withDecoy:[ChatSealDebug_message fakeDecoy] andData:[NSArray arrayWithObject:@"First"] andError:&err];
    if (!psm) {
        NSLog(@"ERROR:  Failed to create the new message.  %@", [err localizedDescription]);
        return NO;
    }
    
    NSLog(@"MSG-DEBUG:  ...appending a bunch of new entities.");
    static const NSUInteger TARGET_ENTRY_COUNT = 100;
    for (NSUInteger iter = 0; iter < TARGET_ENTRY_COUNT; iter++) {
        NSUInteger insertionPoint = 0;
        if ([maTestDates count]) {
            insertionPoint = (NSUInteger) rand() % [maTestDates count];
        }
        NSTimeInterval tBefore = [[NSDate date] timeIntervalSince1970] + 100;
        NSTimeInterval tAfter  = tBefore + (60 * 60 * 24 * 365 * 10);
        
        if (insertionPoint < [maTestDates count]) {
            NSDate *dt = [maTestDates objectAtIndex:insertionPoint];
            tAfter     = [dt timeIntervalSince1970];
        }
        
        if (insertionPoint > 0) {
            NSDate *dt = [maTestDates objectAtIndex:insertionPoint-1];
            tBefore    = [dt timeIntervalSince1970];
        }
        
        NSDate *dtToCreate = [NSDate dateWithTimeIntervalSince1970:tBefore + ((tAfter - tBefore)/2)];
        NSString *sToAdd   = [qbf substringToIndex:(iter % [qbf length]) + 1];
        [maTestDates insertObject:dtToCreate atIndex:insertionPoint];
        [maTestEntries insertObject:sToAdd atIndex:insertionPoint];
        
        NSLog(@"MSG-DEBUG:  ...appending entry %lu.", (unsigned long) iter + 1);
        ChatSealMessageEntry *meNew = [psm addNewEntryOfType:PSMT_GENERIC withContents:[NSArray arrayWithObject:sToAdd] onCreationDate:dtToCreate andError:&err];
        if (!meNew) {
            NSLog(@"ERROR:  Failed to append the entry at index %lu.  %@", (unsigned long) iter, [err localizedDescription]);
            return NO;
        }
    }
    
    NSLog(@"MSG-DEBUG:  ...verifying the sorted order of the test data.");
    NSDate *dtOld = [NSDate dateWithTimeIntervalSince1970:0];
    for (NSUInteger i = 0; i < [maTestDates count]; i++) {
        NSDate *dtCur = [maTestDates objectAtIndex:i];
        if ([dtCur compare:dtOld] != NSOrderedDescending) {
            NSLog(@"ERROR:  The test data is out of order!");
            return NO;
        }
    }
    
    NSLog(@"MSG-DEBUG:  ...verifying the sorted order of the entries.");
    NSInteger numEntries = [psm numEntriesWithError:&err];
    if (numEntries < 0) {
        NSLog(@"ERROR:  The number of entries are invalid.  %@", [err localizedDescription]);
        return NO;
    }
    
    if (numEntries != (TARGET_ENTRY_COUNT + 1)) {
        NSLog(@"ERROR:  There are the wrong number of entries --> %ld.", (long) numEntries);
        return NO;
    }
    
    if (![psm pinSecureContent:&err]) {
        NSLog(@"ERROR:  Failed to pin the message.  %@", [err localizedDescription]);
        return NO;
    }
    
    BOOL ret = YES;
    for (NSInteger i = 1; i < numEntries; i++) {
        ChatSealMessageEntry *me = [psm entryForIndex:(NSUInteger) i withError:&err];
        if (!me) {
            NSLog(@"ERROR:  Failed to retrieve the entry at index %ld.  %@", (long) i, [err localizedDescription]);
            ret = NO;
            break;
        }
        
        if ([me numItems] != 1) {
            NSLog(@"ERROR:  The number of items in entry %ld are invalid.", (long) i);
            ret = NO;
            break;
        }
    }
    [psm unpinSecureContent];
    if (!ret) {
        return ret;
    }
    
    NSLog(@"MSG-DEBUG:  Test-5:  Sorted insertions have been verified successfully.");
#endif
    return YES;
}

/*
 *  Delete entries in the message.
 */
+(BOOL) test_6_simpleEntryDeletions
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"MSG-DEBUG:  Test-6:  Verifying simple entry deletions.");
    
    NSError *err = nil;
    NSLog(@"MSG-DEBUG:  ...adding a new message.");
    ChatSealMessage *psm = [ChatSeal createMessageOfType:PSMT_GENERIC withDecoy:[ChatSealDebug_message fakeDecoy] andData:[NSArray arrayWithObject:@"First"] andError:&err];
    if (!psm) {
        NSLog(@"ERROR:  Failed to create the new message.  %@", [err localizedDescription]);
        return NO;
    }
    
    NSLog(@"MSG-DEBUG:  ...appending a bunch of new entities.");
    static const NSUInteger TARGET_ENTRY_COUNT = 20;
    NSMutableArray *maEntries = [NSMutableArray array];
    for (NSUInteger i = 0; i < TARGET_ENTRY_COUNT; i++) {
        // - build a sample entry
        NSString *s = @"";
        for (NSUInteger j = 0; j < 10; j++) {
            s = [s stringByAppendingFormat:@"%c", (rand() % 26) + 'a'];
        }
        
        [maEntries addObject:s];
        
        if (i % 2 == 0) {
            NSLog(@"MSG-DEBUG:  ...appending entry %lu as '%@'.", (unsigned long) i + 1, s);
            if (![psm addNewEntryOfType:PSMT_GENERIC withContents:[NSArray arrayWithObject:s] onCreationDate:nil andError:&err]) {
                NSLog(@"ERROR:  Failed to add the new entry at index %lu.  %@", (unsigned long) i, [err localizedDescription]);
                return NO;
            }
        }
        else {
            NSLog(@"MSG-DEBUG:  ...appending entry %lu as '%@'. (with alternate decoy)", (unsigned long) (i + 1), s);
            if (![psm addNewEntryOfType:PSMT_GENERIC withContents:[NSArray arrayWithObject:s] andDecoy:[self fakeDecoy] onCreationDate:nil andError:&err]) {
                NSLog(@"ERROR: Failed to add the new entry (with decoy) at index %lu.  %@", (unsigned long) i, [err localizedDescription]);
                return NO;
            }
        }
    }
    
    NSLog(@"MSG-DEBUG:  ...deleting half of the entries.");
    for (NSUInteger i = 0; i < TARGET_ENTRY_COUNT/2; i++) {
        NSUInteger index = ((NSUInteger) rand() % [maEntries count]) + 1;
        
        NSLog(@"MSG-DEBUG:  ...deleting entry at %lu.", (unsigned long) index);
        [maEntries removeObjectAtIndex:index-1];
        
        if (![psm destroyEntryAtIndex:index withError:&err]) {
            NSLog(@"ERROR:  Failed to destroy the entry at index %lu.  %@", (unsigned long) index, [err localizedDescription]);
            return NO;
        }
    }
    
    NSLog(@"MSG-DEBUG:  ...verifying the remaining entries.");
    NSInteger numEntries = [psm numEntriesWithError:&err];
    if (numEntries != (TARGET_ENTRY_COUNT/2) + 1) {
        NSLog(@"ERROR:  The remaining entry count is invalid.");
        return NO;
    }
    
    if (![psm pinSecureContent:&err]) {
        NSLog(@"ERROR:  Failed to pin the secure content.  %@", [err localizedDescription]);
        return NO;
    }
    
    BOOL ret = YES;
    for (NSUInteger i = 1; i < numEntries; i++) {
        ChatSealMessageEntry *me = [psm entryForIndex:i withError:&err];
        if (!me) {
            NSLog(@"ERROR:  Failed to retrieve the entry at index %lu.  %@", (unsigned long) i, [err localizedDescription]);
            ret = NO;
            break;
        }
        
        if ([me numItems] != 1) {
            NSLog(@"ERROR:  The entry at index %lu has an invalid number of items.", (unsigned long) i);
            ret = NO;
            break;
        }
        
        if ([me isItemAnImageAtIndex:0]) {
            NSLog(@"ERROR:  The entry is invalid at index %lu", (unsigned long) i);
            ret = NO;
            break;
        }
        
        NSString *sToCompare = [maEntries objectAtIndex:i-1];
        NSString *s = [me itemAsStringAtIndex:0];
        if (!s || ![s isEqualToString:sToCompare]) {
            NSLog(@"ERROR:  The entry at index %lu is not what we expected.  %@ != %@", (unsigned long) i, s, sToCompare);
            ret = NO;
            break;
        }
        
        NSLog(@"MSG-DEBUG:  ...item with value %@ %s", s, [me hasAlternateDecoy] ? "HAS an alternate decoy" : "uses the shared decoy");
    }
    
    [psm unpinSecureContent];
    if (!ret) {
        return NO;
    }
    
    NSLog(@"MSG-DEBUG:  Test-6:  Simple entry deletions have been verified.");
#endif
    return YES;
}

/*
 *  The purpose of this test is to try to break the index with constant thrashing of the
 *  entry list with sorting and deletions.
 */
+(BOOL) test_8_entryStress
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"MSG-DEBUG:  Test-8:  Stress testing.");
    
    NSError *err = nil;
    NSLog(@"MSG-DEBUG:  ...adding a new message.");
    ChatSealMessage *psm = [ChatSeal createMessageOfType:PSMT_GENERIC withDecoy:[ChatSealDebug_message fakeDecoy] andData:[NSArray arrayWithObject:@"Stress"] andError:&err];
    if (!psm) {
        NSLog(@"ERROR:  Failed to create the new message.  %@", [err localizedDescription]);
        return NO;
    }
    
    // - this array is used for verifying all the entry ids as we move along.
    NSMutableArray *maEntryIds = [NSMutableArray array];

    NSLog(@"MSG-DEBUG:  ...pinning the message for efficiency.");
    if (![psm pinSecureContent:&err]) {
        NSLog(@"ERROR:  Failed to pin the mesage.  %@", [err localizedDescription]);
        return NO;
    }
    
    static const NSUInteger TARGET_STRESS_COUNT = 1000 + 1;
    BOOL ret = YES;
    
    ChatSealMessageEntry *meLast = nil;
    for (NSUInteger i = 0; ret && i < TARGET_STRESS_COUNT; i++) {
        @autoreleasepool {
            NSInteger numEntries = [psm numEntriesWithError:&err];
            if (numEntries < 0) {
                NSLog(@"ERROR:  The number of entries is incorrect after iteration %lu.  %@", (unsigned long) i, [err localizedDescription]);
                ret = NO;
                break;
            }
            
            // - random deletion part of the time.
            if (numEntries > 100) {
                if (rand() % 3 == 1) {
                    NSUInteger toDestroy = (NSUInteger) (rand() % numEntries);
                    ChatSealMessageEntry *meToDestroy = [psm entryForIndex:toDestroy withError:&err];
                    if (!meToDestroy) {
                        NSLog(@"ERROR: Failed to find the existing entry to destroy at index %lu.  %@", (unsigned long) toDestroy, [err localizedDescription]);
                        ret = NO;
                        break;
                    }
                    [maEntryIds removeObject:meToDestroy.entryId];
                    
                    if (![psm destroyEntryAtIndex:toDestroy withError:&err]) {
                        NSLog(@"ERROR:  Failed to destroy the entry at index %lu with %lu entries.  %@", (unsigned long) toDestroy, (unsigned long) numEntries,
                              [err localizedDescription]);
                        ret = NO;
                        break;
                    }
                    NSLog(@"MSG-DEBUG:  ...deleted item at %lu.", (unsigned long) toDestroy);
                    
                    if (meLast) {
                        if (![meLast isStale]) {
                            NSLog(@"ERROR:  The last entry is not stale as expected.");
                            ret = NO;
                            break;
                        }
                    }
                    
                    if (![psm verifyMessageStructureWithError:&err]) {
                        NSLog(@"ERROR:  Failed to verify after deletion.  %@", [err localizedDescription]);
                        ret = NO;
                        break;
                    }
                }
            }
            
            // - add a new item.
            NSString *s = @"";
            int len = (rand() % 20) + 10;
            for (int j = 0; j < len; j++) {
                s = [s stringByAppendingFormat:@"%c", (rand() % 26) + 'A'];
            }
            
            NSDate *dToCreate = [NSDate dateWithTimeIntervalSince1970:rand()];
            ChatSealMessageEntry *me = [psm addNewEntryOfType:PSMT_GENERIC withContents:[NSArray arrayWithObject:s] onCreationDate:dToCreate andError:&err];
            if (!me) {
                NSLog(@"ERROR:  Failed to add a new entry for date %@ of value '%@'", dToCreate, s);
                ret = NO;
                break;
            }
            
            if (meLast) {
                if (![meLast isStale]) {
                    NSLog(@"ERROR:  The last entry is not stale as expected.");
                    ret = NO;
                    break;
                }
            }
            
            // - save the entry id
            [maEntryIds addObject:[me entryId]];
            
            // - periodically try to grab a sealed message from entries as they are created.
            if (i % 4 == 0) {
                NSData *dSealed = [me sealedMessageWithError:&err];
                if (!dSealed || [dSealed length] == 0) {
                    NSLog(@"ERROR:  Failed to acquire a sealed entry from the message at index %lu.  %@", (unsigned long) i, [err localizedDescription]);
                    ret = NO;
                    break;
                }
                NSLog(@"MSG-DEBUG:  ...grabbed a sealed message of length %lu for index %lu.", (unsigned long) [dSealed length], (unsigned long) i);
            }
            
            if (![psm verifyMessageStructureWithError:&err]) {
                NSLog(@"ERROR:  Failed to verify after insertion.  %@", [err localizedDescription]);
                ret = NO;
                break;
            }
            
            // - we need to re-retrieve the last item because a new item can never be stale since it isn't tied to the buffer.
            [meLast release];
            meLast = nil;
            NSInteger num = [psm numEntriesWithError:nil];
            if (num > 0) {
                meLast = [[psm entryForIndex:(NSUInteger) num-1 withError:nil] retain];
            }
            
            // - verify that all the entries can still be retireved by id.
            for (NSString *entryId in maEntryIds) {
                ChatSealMessageEntry *meTmp = [psm entryForId:entryId withError:&err];
                if (!meTmp) {
                    NSLog(@"ERROR: Failed to retrieve an existing entry %@ by id.  %@", entryId, [err localizedDescription]);
                    ret = NO;
                    break;
                }
                
                if (![entryId isEqualToString:[meTmp entryId]]) {
                    NSLog(@"ERROR: Returned the wrong entry for id %@", entryId);
                    ret = NO;
                    break;
                }
            }
            
            NSLog(@"MSG-DEBUG:  ...completed %lu iteration(s) for date %@", (unsigned long) (i+1), dToCreate);
        }
    }
    [meLast release];
    meLast = nil;
    
    [psm unpinSecureContent];
    if (ret) {
        NSLog(@"MSG-DEBUG:  Test-8:  Stress testing was completed successfully.");
    }
    else {
        return NO;
    }
#endif
    return YES;
}

/*
 *  Verify that importing sorts the items correctly.
 */
+(BOOL) test_8a_entryImport
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"MSG-DEBUG:  Test-8a:  Entry import testing.");
    
    // - predictability
    srand(32);
    
    NSError *err = nil;
    NSLog(@"MSG-DEBUG: ...adding a new message.");
    ChatSealMessage *psm = [ChatSeal createMessageOfType:PSMT_GENERIC withDecoy:[ChatSealDebug_message fakeDecoy] andData:[NSArray arrayWithObject:@"entryImport"] andError:&err];
    if (!psm) {
        NSLog(@"ERROR:  Failed to create the new message.  %@", [err localizedDescription]);
        return NO;
    }
    
    if (![psm pinSecureContent:&err]) {
        NSLog(@"ERROR: Failed to pin the message.  %@", [err localizedDescription]);
        return NO;
    }
    
    BOOL ret            = YES;
    NSUInteger numToAdd = 10;
    NSLog(@"MSG-DEBUG: ...(adding items)");
    NSMutableArray *maAddedEntries = [NSMutableArray array];
    for (NSUInteger i = 0; i < numToAdd; i++) {
        NSString *sItem = [NSString stringWithFormat:@"item %u - %d", (unsigned) i, rand()];
        ChatSealMessageEntry *meAdded = [psm addNewEntryOfType:PSMT_GENERIC withContents:[NSArray arrayWithObject:sItem] onCreationDate:nil andError:&err];
        if (!meAdded) {
            NSLog(@"ERROR: Failed to add a new entry.  %@", [err localizedDescription]);
            ret = NO;
            break;
        }
        [maAddedEntries addObject:[meAdded entryId]];
        NSLog(@"MSG-DEBUG: ...new %u as %@ for %@",(unsigned) i, [meAdded entryId], [meAdded creationDate]);
        sleep(1);
    }
    
    NSMutableArray *maExtracted = [NSMutableArray array];
    if (ret) {
        NSLog(@"MSG-DEBUG: ...(extracting and deleting items)");
        for (NSUInteger i = 0; i < numToAdd; i+=2) {
            NSString *eid = [maAddedEntries objectAtIndex:i];
            ChatSealMessageEntry *me = [psm entryForId:eid withError:&err];
            if (!me) {
                NSLog(@"ERROR: failed to find an entry at index %u.  %@", (unsigned) i, [err localizedDescription]);
                ret = NO;
                break;
            }
            
            NSData *dExtracted = [me sealedMessageWithError:&err];
            if (!dExtracted) {
                NSLog(@"ERROR: failed to extract the entry.  %@", [err localizedDescription]);
                ret = NO;
                break;
            }
            
            [maExtracted addObject:dExtracted];
            
            if (![psm destroyEntry:me withError:&err]) {
                NSLog(@"ERROR: failed to delete the entry.  %@", [err localizedDescription]);
                ret = NO;
                break;
            }
        }
    }
    
    // - verify we have less now
    if (ret) {
        NSLog(@"MSG-DEBUG: ...verifying that we have less entries now.");
        NSInteger numToCheck = [psm numEntriesWithError:&err];
        if (numToCheck == (numToAdd/2) + 1) {
            for (NSUInteger i = 1; i < numToCheck; i++) {
                ChatSealMessageEntry *meItem = [psm entryForIndex:i withError:&err];
                if (!meItem) {
                    NSLog(@"ERROR: failed to pull the entry %u.  %@", (unsigned) i, [err localizedDescription]);
                    ret = NO;
                    break;
                }
                NSLog(@"MSG-DEBUG: ...item %u as %@ on %@", (unsigned) i - 1, [meItem entryId], [meItem creationDate]);
            }
        }
        else {
            NSLog(@"ERROR: we have too many entries = %u.", (unsigned) numToCheck);
            ret = NO;
        }
    }
    
    // - now start importing to test sorting
    if (ret) {
        NSLog(@"MSG-DEBUG: ...reimporting all the extracted data.");
        for (NSData *dExt in maExtracted) {
            if (![ChatSeal importMessageIntoVault:dExt andSetDefaultFeed:nil withError:&err]) {
                NSLog(@"ERROR: Failed to import one of the extracted items.  %@", [err localizedDescription]);
                ret = NO;
                break;
            }
        }
    }
    
    // - now enumerate all the entries and check the sorting.
    if (ret) {
        NSLog(@"MSG-DEBUG: ...checking on the sorted list.");
        NSInteger numToCheck = [psm numEntriesWithError:&err];
        NSMutableArray *maCheckIds = [NSMutableArray array];
        if (numToCheck == numToAdd + 1) {
            for (NSUInteger i = 1; i < numToAdd + 1; i++) {
                ChatSealMessageEntry *meItem = [psm entryForIndex:i withError:&err];
                if (!meItem) {
                    NSLog(@"ERROR: failed to pull the entry %u.  %@", (unsigned) i, [err localizedDescription]);
                    ret = NO;
                    break;
                }
                [maCheckIds addObject:[meItem entryId]];
                NSLog(@"MSG-DEBUG: ...item %u as %@ on %@", (unsigned) i - 1, [meItem entryId], [meItem creationDate]);
            }
            
            if (![maCheckIds isEqualToArray:maAddedEntries]) {
                NSLog(@"ERROR: the two entry arrays are not equal.");
                ret = NO;
            }
        }
        else {
            NSLog(@"ERROR: the returned count was bad = %d", (int) numToCheck);
            ret = NO;
        }
    }
    
    [psm unpinSecureContent];
    if (!ret) {
        return NO;
    }
    
    NSLog(@"MSG-DEBUG:  Test-8a:  Entry import testing completed successfully.");
  #endif
    return YES;
}


/*
 *  Return the list of items in the message.
 */
+(NSMutableArray *) allFirstItemsForAllEntriesInMessage:(ChatSealMessage *) psm
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSError *err                       = nil;
    NSMutableArray *maAllCurrentEntries = [NSMutableArray array];
    NSInteger count = [psm numEntriesWithError:&err];
    if (count != -1) {
        for (NSInteger i = 0; i < count; i++) {
            ChatSealMessageEntry *me = [psm entryForIndex:(NSUInteger) i withError:&err];
            if (!me) {
                NSLog(@"ERROR: Failed to get an entry.  %@", [err localizedDescription]);
                return nil;
            }
            NSObject *obj = [me itemAtIndex:0 withError:nil];
            if (obj) {
                [maAllCurrentEntries addObject:obj];
            }
        }
        
    }
    else {
        return nil;
    }
    return maAllCurrentEntries;
#endif
    return nil;
}

/*
 *  The purpose of this test is to try to see if the import filter does what
 *  we expect it to do in concernt with a deletion.
 */
+(BOOL) test_9_simpleImportFilter
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"MSG-DEBUG:  Test-9:  Simple import filter.");

    
    NSError *err = nil;
    NSLog(@"MSG-DEBUG: ...adding a new message.");
    ChatSealMessage *psm = [ChatSeal createMessageOfType:PSMT_GENERIC withDecoy:[ChatSealDebug_message fakeDecoy] andData:[NSArray arrayWithObject:@"SimpleImportFilter"] andError:&err];
    if (!psm) {
        NSLog(@"ERROR:  Failed to create the new message.  %@", [err localizedDescription]);
        return NO;
    }
    
    if (![psm pinSecureContent:&err]) {
        NSLog(@"ERROR: Failed to pin the message.  %@", [err localizedDescription]);
        return NO;
    }
    
    // ... set as displayed so that the import filter comes into play.
    [psm setIsBeingDisplayed];
    
    BOOL ret = YES;
    
    NSLog(@"MSG-DEBUG: ...creating some entries and grabbing one in the middle.");
    NSData *dExported = nil;
    NSString *meid    = nil;
    for (NSUInteger i = 0; i < 10; i++) {
        NSString *sItem = [NSString stringWithFormat:@"entry %u", (unsigned) i];
        sleep(1);
        ChatSealMessageEntry *meNew = [psm addNewEntryOfType:PSMT_GENERIC withContents:[NSArray arrayWithObject:sItem] onCreationDate:nil andError:&err];
        if (!meNew) {
            ret = NO;
            NSLog(@"ERROR: Failed to build a new entry!  %@", [err localizedDescription]);
            break;
        }
        NSLog(@"MSG-DEBUG: ...entry %u created", (unsigned) i);
        
        if (i == 5) {
            NSLog(@"MSG-DEBUG: ...and deleting the middle entry.");
            meid      = [meNew entryId];
            dExported = [meNew sealedMessageWithError:&err];
            if (!dExported) {
                NSLog(@"ERROR: Failed to export a sealed message.  %@", [err localizedDescription]);
                ret = NO;
                break;
            }
            
            if (![psm destroyEntry:meNew withError:&err]) {
                NSLog(@"ERROR: Failed to destroy the new entry.  %@", [err localizedDescription]);
                ret = NO;
                break;
            }
        }
    }
    
    // - save off the list of entries as they exist in the message.
    NSMutableArray *maAllCurrentEntries = nil;
    if (ret) {
        NSLog(@"MSG-DEBUG: ...creating some entries and grabbing one in the middle.");
        maAllCurrentEntries = [ChatSealDebug_message allFirstItemsForAllEntriesInMessage:psm];
        if (!maAllCurrentEntries) {
            ret = NO;
        }
    }
    
    // - add one more.
    ChatSealMessageEntry *meLast = nil;
    if (ret) {
        meLast = [psm addNewEntryOfType:PSMT_GENERIC withContents:[NSArray arrayWithObject:@"last"] onCreationDate:nil andError:&err];
        if (!meLast) {
            NSLog(@"ERROR: Failed to add the last item.  %@", [err localizedDescription]);
            ret = NO;
        }
    }
    
    // - import an old entry, which should build a filter.
    if (ret) {
        NSLog(@"MSG-DEBUG: ...reimporting the entry we deleted before.");
        if (![ChatSeal importMessageIntoVault:dExported andSetDefaultFeed:nil withError:&err]) {
            NSLog(@"ERROR: Failed to reimport the message.  %@", [err localizedDescription]);
            ret = NO;
        }
    }
    
    // - verify the filter is accurate.
    if (ret) {
        NSLog(@"MSG-DEBUG: ...verifying that import builds a filter");
        NSMutableArray *maEntries = [ChatSealDebug_message allFirstItemsForAllEntriesInMessage:psm];
        if (maEntries) {
            [maEntries removeLastObject];
            if (![maEntries isEqualToArray:maAllCurrentEntries]) {
                NSLog(@"ERROR: the two arrays are not equal.");
                ret = NO;
            }
        }
        else {
            ret = NO;
        }
    }
    
    // - delete the one we just created (which should unset the filter.)
    if (ret) {
        NSLog(@"MSG-DEBUG: ...deleting the last entry now");
        if (![psm destroyEntry:meLast withError:&err]) {
            NSLog(@"ERROR: failed to destroy the last entry.  %@", [err localizedDescription]);
            ret = NO;
        }
    }
    
    // - verify the filter is unset.
    if (ret) {
        NSLog(@"MSG-DEBUG: ...verifying the filter is now unset");
        NSMutableArray *maEntries = [self allFirstItemsForAllEntriesInMessage:psm];
        NSMutableArray *maTmp = [NSMutableArray arrayWithArray:maEntries];
        [maTmp removeObjectsInArray:maAllCurrentEntries];
        if ([maEntries count] - 1 != [maAllCurrentEntries count] ||
            [maTmp count] != 1) {
            NSLog(@"ERROR: the filter was not unset");
            ret = NO;
        }
    }
    
    // - now delete the item and re-import to apply a new import filer.
    if (ret) {
        NSLog(@"MSG-DEBUG: ...re-applying the import filter");
        ChatSealMessageEntry *meTmp = [psm entryForId:meid withError:&err];
        NSString *sItem = [meTmp itemAsStringAtIndex:0];
        NSLog(@"MSG-DEBUG: ...found the entry with item '%@", sItem);
        if ([psm destroyEntry:meTmp withError:&err]) {
            if (![ChatSeal importMessageIntoVault:dExported andSetDefaultFeed:nil withError:&err]) {
                NSLog(@"ERROR: failed to reimport the message into the vault.  %@", [err localizedDescription]);
                ret = NO;
            }
        }
        else {
            NSLog(@"ERROR: failed to destroy the entry again.  %@", [err localizedDescription]);
            ret = NO;
        }
    }
    
    // - verify the filter is accurate.
    if (ret) {
        NSLog(@"MSG-DEBUG: ...verifying that import builds a filter");
        NSMutableArray *maEntries = [ChatSealDebug_message allFirstItemsForAllEntriesInMessage:psm];
        if (maEntries) {
            if (![maEntries isEqualToArray:maAllCurrentEntries]) {
                NSLog(@"ERROR: the two arrays are not equal.");
                ret = NO;
            }
        }
        else {
            ret = NO;
        }
    }
    
    // - and create one more
    if (ret) {
        NSLog(@"MSG-DEBUG: ...adding one extra.");
        ChatSealMessageEntry *meNew = [psm addNewEntryOfType:PSMT_GENERIC withContents:[NSArray arrayWithObject:@"lastV2"] onCreationDate:nil andError:&err];
        if (!meNew) {
            NSLog(@"ERROR: Failed to add the last item.  %@", [err localizedDescription]);
            ret = NO;
        }
    }
    
    // - verify the filter is unset.
    if (ret) {
        NSLog(@"MSG-DEBUG: ...verifying the filter is now unset");
        NSMutableArray *maEntries = [self allFirstItemsForAllEntriesInMessage:psm];
        NSMutableArray *maTmp = [NSMutableArray arrayWithArray:maEntries];
        [maTmp removeObjectsInArray:maAllCurrentEntries];
        if ([maEntries count] - 2 != [maAllCurrentEntries count] ||
            [maTmp count] != 2) {
            NSLog(@"ERROR: the filter was not unset");
            ret = NO;
        }
    }
    
    [psm unpinSecureContent];
    if (!ret) {
        return NO;
    }
    
    NSLog(@"MSG-DEBUG:  Test-9:  Simple import filter testing completed successfully.");

#endif
    return YES;
}


/*
 *  Verify that more complex filtering scenarios after importing still produce valid data.
 *  - this is meant to more accurately simulate the behavior of reading a message while items are coming in.
 */
+(BOOL) test_10_complexImportFilter
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"MSG-DEBUG:  Test-10:  Complex import filter.");

    // - predictability
    srand(32);
    
    NSError *err = nil;
    NSLog(@"MSG-DEBUG: ...adding a new message.");
    ChatSealMessage *psm = [ChatSeal createMessageOfType:PSMT_GENERIC withDecoy:[ChatSealDebug_message fakeDecoy] andData:[NSArray arrayWithObject:@"SimpleImportFilter"] andError:&err];
    if (!psm) {
        NSLog(@"ERROR:  Failed to create the new message.  %@", [err localizedDescription]);
        return NO;
    }
    sleep(1);
    
    if (![psm pinSecureContent:&err]) {
        NSLog(@"ERROR: Failed to pin the message.  %@", [err localizedDescription]);
        return NO;
    }
    
    // ... set as displayed so that the import filter comes into play.
    [psm setIsBeingDisplayed];
    
    BOOL ret     = YES;
    
    NSString *pfx[3] = {@"abc", @"def", @"ghi"};
    
    // ... we're going to run through multiple iterations of a lot of additions, filters
    //     and deletions to test all the differerent variations.
    NSUInteger numTotal = 1;
    for (NSUInteger times = 0; ret && times < 4; times++) {
        NSLog(@"MSG-DEBUG: ...beginning big iteration %u.", (unsigned) times);

        @autoreleasepool {
            NSLog(@"MSG-DEBUG: ...(adding items)");
            NSUInteger numToAdd = 10;
            
            NSMutableArray *maNewItems = [NSMutableArray array];
            for (NSUInteger i = 0; i < numToAdd; i++) {
                NSString *curPfx = pfx[i % 3];
                
                NSString *sItem = [NSString stringWithFormat:@"%@ item %u - %d", curPfx, (unsigned) i, rand()];
                ChatSealMessageEntry *meAdded = [psm addNewEntryOfType:PSMT_GENERIC withContents:[NSArray arrayWithObject:sItem] onCreationDate:nil andError:&err];
                if (!meAdded) {
                    NSLog(@"ERROR: Failed to add a new entry.  %@", [err localizedDescription]);
                    ret = NO;
                    break;
                }
                NSLog(@"MSG-DEBUG: ...new at %@ on %@", [meAdded entryId], [meAdded creationDate]);
                NSLog(@"MSG-DEBUG: ...-->'%@'", sItem);
                [maNewItems addObject:meAdded.entryId];
                sleep(1);
            }

            // - extract some random items.
            NSMutableArray *maExtracted = [NSMutableArray array];
            NSUInteger numRemain        = numToAdd;
            NSLog(@"MSG-DEBUG: ...(extracting and deleting items)");
            if (ret) {
                NSUInteger numToDelete = numToAdd / 2;
                for (NSUInteger i = 0; i < numToDelete; i++) {
                    NSUInteger randIdx = numTotal + ((NSUInteger) rand() % numRemain);
                    ChatSealMessageEntry *me = [psm entryForIndex:randIdx withError:&err];
                    if (!me) {
                        NSLog(@"ERROR: failed to find an entry at index %u.  %@", (unsigned) randIdx, [err localizedDescription]);
                        ret = NO;
                        break;
                    }
                    
                    NSData *dExtracted = [me sealedMessageWithError:&err];
                    if (!dExtracted) {
                        NSLog(@"ERROR: failed to extract the entry.  %@", [err localizedDescription]);
                        ret = NO;
                        break;
                    }
                    
                    [maExtracted addObject:dExtracted];
                    
                    if (![psm destroyEntry:me withError:&err]) {
                        NSLog(@"ERROR: failed to delete the entry.  %@", [err localizedDescription]);
                        ret = NO;
                        break;
                    }
                    
                    numRemain--;
                }
            }
            
            // - apply a random filter based on the iteration
            NSMutableArray *maItemsWithCurFilter = nil;
            if (ret) {
                NSUInteger filter = times % 4;
                NSString *sFilter = nil;
                if (filter < 3) {
                    sFilter = pfx[filter];
                }
                
                NSArray *arrItems = [self allFirstItemsForAllEntriesInMessage:psm];
                NSUInteger idx = 0;
                for (NSString *sItem in arrItems) {
                    NSLog(@"MSG-DEBUG: ...before filter %02u --> '%@'", (unsigned) idx, sItem);
                    idx++;
                }
                
                NSLog(@"MSG-DEBUG: ...(applying filter = '%@')", sFilter);
                [psm applyFilter:sFilter];
                
                // - save off the content before the imports
                maItemsWithCurFilter = [self allFirstItemsForAllEntriesInMessage:psm];
                if (!maItemsWithCurFilter) {
                    NSLog(@"ERROR: failed to get items.");
                    ret = NO;
                }
                idx = 0;
                for (NSString *sItem in maItemsWithCurFilter) {
                    NSLog(@"MSG-DEBUG: ...after filter %02u --> '%@'", (unsigned) idx, sItem);
                    idx++;
                }
            }
            
            // - now start importing and ensure that the filter remains.
            if (ret) {
                NSLog(@"MSG-DEBUG: ...(reimporting all the extracted data)");
                for (NSData *dExt in maExtracted) {
                    ChatSealMessage *psmImported = nil;
                    if (!(psmImported = [ChatSeal importMessageIntoVault:dExt andSetDefaultFeed:nil withError:&err])) {
                        NSLog(@"ERROR: Failed to import one of the extracted items.  %@", [err localizedDescription]);
                        ret = NO;
                        break;
                    }
                    
                    NSLog(@"MSG-DEBUG: ...imported entry into message %@", [psmImported messageId]);
                    
                    NSMutableArray *maCurItems = [self allFirstItemsForAllEntriesInMessage:psm];
                    if (!maCurItems || ![maCurItems isEqual:maItemsWithCurFilter]) {
                        NSLog(@"ERROR: failed to confirm the filter is still valid.");
                        ret = NO;
                        break;
                    }
                    NSLog(@"MSG-DEBUG: ...filter is still valid");
                }
            }
            
            // - unfilter the content and make sure that our items are still in the same locations as when we
            //   started.
            if (ret) {
                NSLog(@"MSG-DEBUG: ...(verifying that unfiltered content is correct)");
                [psm applyFilter:nil];
                NSMutableArray *maVerify = [NSMutableArray array];
                for (NSUInteger i = numTotal; i < (numTotal + numToAdd); i++) {
                    ChatSealMessageEntry *pme = [psm entryForIndex:i withError:&err];
                    if (!pme) {
                        NSLog(@"ERROR: failed to get message entry %u for verification.  %@", (unsigned) i, [err localizedDescription]);
                        ret = NO;
                        break;
                    }
                    [maVerify addObject:pme.entryId];
                }
                
                if (![maVerify isEqualToArray:maNewItems]) {
                    NSLog(@"ERROR: the two arrays are not equal.");
                    ret = NO;
                }
            }
            
            numTotal += numToAdd;
        }
        
        if (!ret) {
            break;
        }
    }
    
    [psm unpinSecureContent];
    if (!ret) {
        return NO;
    }
    
    NSLog(@"MSG-DEBUG:  Test-10:  All complex import filter tests passed successfully..");
#endif
    return YES;
}

/*
 *  The purpose of this test is to present a rather large collection of images to test that
 *  the pre-computed UI image heights work correctly in all scenarios during scrolling.
 */
+(BOOL) test_11_largeImageCollection
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"MSG-DEBUG:  Test-11:  Large image collection testing.");
    
    
    NSError *err = nil;
    NSLog(@"MSG-DEBUG: ...adding a new message.");
    ChatSealMessage *psm = [ChatSeal createMessageOfType:PSMT_GENERIC withDecoy:[ChatSealDebug_message fakeDecoy] andData:[NSArray arrayWithObject:@"LargeImageCollection"] andError:&err];
    if (!psm) {
        NSLog(@"ERROR:  Failed to create the new message.  %@", [err localizedDescription]);
        return NO;
    }
    
    if (![psm pinSecureContent:&err]) {
        NSLog(@"ERROR: Failed to pin the message.  %@", [err localizedDescription]);
        return NO;
    }
    
    BOOL ret = YES;
    NSLog(@"MSG-DEBUG: ...(adding items)");
    NSMutableArray *arrSizes = [NSMutableArray array];
    for (NSUInteger i = 0; i < 256; i++) {
        @autoreleasepool {
            CGSize szImage = CGSizeZero;
            szImage.width  = 32 + (rand() % 256);
            szImage.height = 32 + (rand() % 256);
            UIGraphicsBeginImageContextWithOptions(szImage, YES, i % 2 == 0 ? 1.0f : 2.0f);
            [[UIColor colorWithRed:((float)(rand()%255))/255.0f green:((float)(rand()%255))/255.0f blue:((float)(rand()%255))/255.0f alpha:1.0f] setFill];
            UIRectFill(CGRectMake(0.0f, 0.0f, szImage.width, szImage.height));
            UIImage *imgNew = UIGraphicsGetImageFromCurrentImageContext();
            [arrSizes addObject:[NSValue valueWithCGSize:imgNew.size]];
            UIGraphicsEndImageContext();
            
            ChatSealMessageEntry *meAdded = [psm addNewEntryOfType:PSMT_GENERIC withContents:[NSArray arrayWithObject:imgNew] onCreationDate:nil andError:&err];
            if (!meAdded) {
                NSLog(@"ERROR: Failed to add a new entry.  %@", [err localizedDescription]);
                ret = NO;
                break;
            }
            NSLog(@"MSG-DEBUG: ...new at %@ on %@ (image is %4.2f x %4.2f at position %u)", [meAdded entryId], [meAdded creationDate], imgNew.size.width, imgNew.size.height, (unsigned) i + 1);
        }
    }
    
    NSLog(@"MSG-DEBUG: ...(confirming sizes)");
    for (NSUInteger i = 0; ret && i < 256; i++) {
        // - skip the original entry by adding one.
        ChatSealMessageEntry *me = [psm entryForIndex:i+1 withError:nil];
        if (!me) {
            NSLog(@"ERROR: Failed to retrieve an entry.");
            ret = NO;
            break;
        }
        
        CGSize szCached = [me imageSizeForItemAtIndex:0];
        NSValue *v = [arrSizes objectAtIndex:i];
        CGSize sz  = v.CGSizeValue;
        if ((int) szCached.width != (int) sz.width ||
            (int) szCached.height != (int) sz.height) {
            NSLog(@"ERROR: the cached dimensions do not match the original ones!");
            ret = NO;
            break;
        }
    }
    
    [psm unpinSecureContent];
    if (!ret) {
        return NO;
    }
    
    NSLog(@"MSG-DEBUG:  Test-11:  All testing with a large image collection completed successfully.");
    
#endif
    return YES;
}

#endif

/*
 *  Test the correctness of the messaging infrastructure using the active seal.
 */
+(void) testCorrectnessWithCurrentVault
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    srand(32);
    if (![ChatSealDebug_message test_1_clearMessages] ||
        ![ChatSealDebug_message test_2_addMessage] ||
        ![ChatSealDebug_message test_3_addEntries] ||
        ![ChatSealDebug_message test_4_simpleInsertions] ||
        ![ChatSealDebug_message test_5_sortedInsertions] ||
        ![ChatSealDebug_message test_6_simpleEntryDeletions] ||
        ![ChatSealDebug_message test_8_entryStress] ||
        ![ChatSealDebug_message test_8a_entryImport] ||
        ![ChatSealDebug_message test_9_simpleImportFilter] ||
        ![ChatSealDebug_message test_10_complexImportFilter] ||
        ![ChatSealDebug_message test_11_largeImageCollection]
        ) {
        NSLog(@"ERROR: Failed to verify message infrastructure.");
    }
#endif
}
@end