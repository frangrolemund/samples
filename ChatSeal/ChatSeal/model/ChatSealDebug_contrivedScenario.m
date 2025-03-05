//
//  ChatSealDebug_contrivedScenario.m
//  ChatSeal
//
//  Created by Francis Grolemund on 11/18/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "ChatSealDebug_contrivedScenario.h"
#import "ChatSeal.h"
#import "ChatSealFeedCollector.h"
#import "CS_cacheMessage.h"

#if CHATSEAL_DEBUGGING_ROUTINES
#if CHATSEAL_RUNNING_CONTRIVED_SCENARIO
static NSString *CONTRIVED_SISTER_NAME           = @"AllieK";
static NSString *CONTRIVED_MY_NAME               = @"WinstonAteIt";
static NSString *CONTRIVED_FRIEND                = @"Mohit";

@interface ChatSealMessage (shared)
+(ChatSealMessage *) createMessageOfType:(ps_message_type_t) mtype usingSeal:(NSString *) sealId withDecoy:(UIImage *) decoy andData:(NSArray *) msgData
                          onCreationDate:(NSDate *) dtCreated andError:(NSError **) err;
@end

@interface CS_cacheMessage (shared)
-(void) setDateCreated:(NSDate *)dateCreated;
@end

#endif
#endif

/*******************************
 ChatSealDebug_contrivedScenario
 *******************************/
@implementation ChatSealDebug_contrivedScenario
#if CHATSEAL_DEBUGGING_ROUTINES
#if CHATSEAL_RUNNING_CONTRIVED_SCENARIO
/*
 *  Return the directory where contrived assets are stored.
 */
+(NSURL *) assetDir
{
    NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    u        = [u URLByAppendingPathComponent:@"contrived-assets"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:[u path]]) {
        NSLog(@"ERROR: the asset directory does not exist at %@", u);
        abort();
    }
    return u;
}

/*
 *  The basis for all the communications.
 */
+(NSTimeInterval) contrivedBasis
{
    return [[NSDate date] timeIntervalSince1970] - (60 * 60 * 24 * 1);
}

/*
 *  Convert an owned seal into an imported one.
 */
+(BOOL) exportAndReimportSeal:(NSString *) sealId
{
    [[ChatSeal vaultOperationQueue] waitUntilAllOperationsAreFinished];
    NSError *err = nil;
    RSISecureSeal *ss = [RealSecureImage sealForId:sealId andError:&err];
    if (!ss) {
        NSLog(@"ERROR: Failed to get the seal for export!, %@", [err localizedDescription]);
        return NO;
    }
    
    // - Because the connection is already encrypted, I'm not going to use a secondary password
    //   here.  I had considered not encrypting the payload at all, but I didn't really like the idea
    //   of sending over a packed JPEG on second thought since the JPEG itself would be in the clear, even if
    //   the seal data wasn't.
    NSData *dExported = [ss exportWithPassword:@"pwd" andError:&err];
    if (!dExported) {
        NSLog(@"ERROR: Failed to export the seal!  %@", [err localizedDescription]);
        return NO;
    }
    
    if (![ChatSeal deleteSealForId:sealId withError:&err]) {
        NSLog(@"ERROR: Failed to delete the seal!  %@", [err localizedDescription]);
        return NO;
    }
    
    if (![ChatSeal importSealFromData:dExported withPassword:@"pwd" andError:&err]) {
        NSLog(@"ERROR: Failed to reimport the seal! %@", [err localizedDescription]);
        return NO;
    }

    return YES;
}

/*
 *  Return a specific contrived image.
 */
+(UIImage *) contrivedImageWithName:(NSString *) name
{
    // - seal images must be 380x380.
    NSURL *u = [ChatSealDebug_contrivedScenario assetDir];
    u = [u URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.jpg", name]];
    return [UIImage imageWithContentsOfFile:[u path]];
    
}

/*
 *  Build the seal and messages for the sister.
 */
+(BOOL) buildSisterSealWithMessages
{
    UIImage *imgGirl = [ChatSealDebug_contrivedScenario  contrivedImageWithName:@"girl-sample"];
    NSError *err = nil;
    NSString *sealId = [ChatSeal createSealWithImage:imgGirl andColor:RSSC_STD_ORANGE andSetAsActive:NO withError:&err];
    if (!sealId) {
        NSLog(@"ERROR: Failed to create the seal!.  %@", [err localizedDescription]);
        return NO;
    }
    
    [[ChatSeal vaultOperationQueue] waitUntilAllOperationsAreFinished];
    
    // - now create my messages.
    NSMutableArray *maMsg = [NSMutableArray array];
    [maMsg addObject:imgGirl];
    NSDate *dt = [NSDate dateWithTimeIntervalSince1970:[ChatSealDebug_contrivedScenario contrivedBasis] - (60 * 60 * 24 * 6)];
    ChatSealMessage *msg = [ChatSealMessage createMessageOfType:PSMT_GENERIC usingSeal:sealId withDecoy:imgGirl andData:maMsg onCreationDate:dt andError:&err];
    if (!msg) {
        NSLog(@"ERROR: Failed to create a message.");
        return NO;
    }
    [msg setIsRead:YES withError:nil];
    
    if (![ChatSealDebug_contrivedScenario exportAndReimportSeal:sealId]) {
        return NO;
    }

    ChatSealIdentity *ident = [ChatSeal identityForSeal:sealId withError:&err];
    if (!ident) {
        NSLog(@"ERROR: Failed to get identity.  %@", [err localizedDescription]);
        return NO;
    }
    
    [ident setOwnerName:CONTRIVED_SISTER_NAME ifBeforeDate:nil];
    
    CS_cacheMessage *cached = [CS_cacheMessage messageForId:msg.messageId];
    [cached setDateCreated:dt];
    
    return YES;
}

/*
 *  Build the seal and messages for my content.
 */
+(BOOL) buildMySealWithMessages
{
    UIImage *imgMine = [ChatSealDebug_contrivedScenario contrivedImageWithName:@"dog-sample"];
    NSError *err = nil;
    NSString *sealId = [ChatSeal createSealWithImage:imgMine andColor:RSSC_STD_GREEN andSetAsActive:YES withError:&err];
    if (!sealId) {
        NSLog(@"ERROR: Failed to create the seal!.  %@", [err localizedDescription]);
        return NO;
    }
    
    [[ChatSeal vaultOperationQueue] waitUntilAllOperationsAreFinished];
    ChatSealIdentity *ident = [ChatSeal identityForSeal:sealId withError:&err];
    if (!ident) {
        NSLog(@"ERROR: Failed to get identity.  %@", [err localizedDescription]);
        return NO;
    }
    
    [ident setOwnerName:CONTRIVED_MY_NAME ifBeforeDate:nil];
    [ident incrementSealGivenCount];
    [ident incrementSealGivenCount];
    
    for (int i = 0; i < 15; i++) {
        [ident incrementSentCount];
    }
    
    for (int i = 0; i < 36; i++) {
        [ident incrementRecvCount];
    }
    
    // - now create my messages.
    NSMutableArray *maMsg = [NSMutableArray array];
    [maMsg addObject:@"Did you guys see anyone at the park yesterday?"];
    NSDate *dt = [NSDate dateWithTimeIntervalSince1970:[ChatSealDebug_contrivedScenario contrivedBasis]];
    ChatSealMessage *msg = [ChatSealMessage createMessageOfType:PSMT_GENERIC usingSeal:sealId withDecoy:imgMine andData:maMsg onCreationDate:dt andError:&err];
    if (!msg) {
        NSLog(@"ERROR: Failed to create my message.");
        return NO;
    }
    
    [maMsg removeAllObjects];
    [maMsg addObject:@"Yeah Zach showed."];
    ChatSealMessageEntry *me = [msg importRemoteEntryWithContents:maMsg asAuthor:CONTRIVED_SISTER_NAME onCreationDate:[NSDate dateWithTimeIntervalSince1970:[ChatSealDebug_contrivedScenario contrivedBasis] + 45] withError:&err];
    if (!me) {
        NSLog(@"ERROR: Failed to write a response.");
        return NO;
    }
    
    [maMsg removeAllObjects];
    [maMsg addObject:[ChatSealDebug_contrivedScenario contrivedImageWithName:@"group-sample"]];
    [maMsg addObject:@"Emily was there."];
    me = [msg importRemoteEntryWithContents:maMsg asAuthor:nil onCreationDate:[NSDate dateWithTimeIntervalSince1970:[ChatSealDebug_contrivedScenario contrivedBasis] + 120] withError:&err];
    if (!me) {
        NSLog(@"ERROR: Failed to write a response.");
        return NO;
    }
    
    [maMsg removeAllObjects];
    [maMsg addObject:@"Some of us are heading over to Chauncey's for wings later on.  Do any of you want to go?"];
    NSTimeInterval tiStart = [[NSDate date] timeIntervalSince1970] - 340;
    [msg addNewEntryOfType:PSMT_GENERIC withContents:maMsg onCreationDate:[NSDate dateWithTimeIntervalSince1970:tiStart] andError:nil];
    
    [maMsg removeAllObjects];
    [maMsg addObject:@"That sounds like fun, can you pick me up on the way?"];
    me = [msg importRemoteEntryWithContents:maMsg asAuthor:CONTRIVED_SISTER_NAME onCreationDate:[NSDate dateWithTimeIntervalSince1970:tiStart + 75] withError:&err];
    if (!me) {
        NSLog(@"ERROR: Failed to write a response.");
        return NO;
    }
    
    [maMsg removeAllObjects];
    [maMsg addObject:@"Sure thing."];
    [msg addNewEntryOfType:PSMT_GENERIC withContents:maMsg onCreationDate:[NSDate dateWithTimeIntervalSince1970:tiStart + 30] andError:nil];
    
    [maMsg removeAllObjects];
    [maMsg addObject:@"Let me know when you're leaving."];
    me = [msg importRemoteEntryWithContents:maMsg asAuthor:CONTRIVED_FRIEND onCreationDate:[NSDate dateWithTimeIntervalSince1970:tiStart + 140] withError:&err];
    if (!me) {
        NSLog(@"ERROR: Failed to write a response.");
        return NO;
    }
    
    [msg setIsRead:YES withError:nil];

    return YES;
}

/*
 *  Build a friend's seal.
 */
+(BOOL) buildFriendSealWithMessages
{
    UIImage *imgBoy = [ChatSealDebug_contrivedScenario  contrivedImageWithName:@"boy-sample"];
    NSError *err = nil;
    NSString *sealId = [ChatSeal createSealWithImage:imgBoy andColor:RSSC_STD_BLUE andSetAsActive:NO withError:&err];
    if (!sealId) {
        NSLog(@"ERROR: Failed to create the seal!.  %@", [err localizedDescription]);
        return NO;
    }
    
    [[ChatSeal vaultOperationQueue] waitUntilAllOperationsAreFinished];
    
    // - now create my messages.
    NSMutableArray *maMsg = [NSMutableArray array];
    [maMsg addObject:@"ROFL.  Send me a pic. 😜"];
    NSDate *dt = [NSDate dateWithTimeIntervalSince1970:[ChatSealDebug_contrivedScenario contrivedBasis] - (60 * 60 * 3)];
    ChatSealMessage *msg = [ChatSealMessage createMessageOfType:PSMT_GENERIC usingSeal:sealId withDecoy:imgBoy andData:maMsg onCreationDate:dt andError:&err];
    if (!msg) {
        NSLog(@"ERROR: Failed to create a message.");
        return NO;
    }
    [msg setIsRead:YES withError:nil];
    
    if (![ChatSealDebug_contrivedScenario exportAndReimportSeal:sealId]) {
        return NO;
    }
    
    ChatSealIdentity *ident = [ChatSeal identityForSeal:sealId withError:&err];
    if (!ident) {
        NSLog(@"ERROR: Failed to get identity.  %@", [err localizedDescription]);
        return NO;
    }
    
    [ident setOwnerName:CONTRIVED_FRIEND ifBeforeDate:nil];
    
    for (int i = 0; i < 7; i++) {
        [ident incrementSentCount];
    }
    
    CS_cacheMessage *cached = [CS_cacheMessage messageForId:msg.messageId];
    [cached setDateCreated:dt];
    
    return YES;
}

/*
 *  Construct an anonymous friend.
 */
+(BOOL) buildAnonFriendWithMessages
{
    UIImage *imgAlien = [ChatSealDebug_contrivedScenario  contrivedImageWithName:@"alien-sample"];
    NSError *err = nil;
    NSString *sealId = [ChatSeal createSealWithImage:imgAlien andColor:RSSC_STD_YELLOW andSetAsActive:NO withError:&err];
    if (!sealId) {
        NSLog(@"ERROR: Failed to create the seal!.  %@", [err localizedDescription]);
        return NO;
    }
    
    [[ChatSeal vaultOperationQueue] waitUntilAllOperationsAreFinished];
    
    // - now create my messages.
    NSMutableArray *maMsg = [NSMutableArray array];
    [maMsg addObject:@"I figured you'd say something like that."];
    NSDate *dt = [NSDate dateWithTimeIntervalSince1970:[ChatSealDebug_contrivedScenario contrivedBasis] - (60 * 60 * 2)];
    ChatSealMessage *msg = [ChatSealMessage createMessageOfType:PSMT_GENERIC usingSeal:sealId withDecoy:imgAlien andData:maMsg onCreationDate:dt andError:&err];
    if (!msg) {
        NSLog(@"ERROR: Failed to create a message.");
        return NO;
    }
    [msg setIsRead:YES withError:nil];
    
    if (![ChatSealDebug_contrivedScenario exportAndReimportSeal:sealId]) {
        return NO;
    }
    
    CS_cacheMessage *cached = [CS_cacheMessage messageForId:msg.messageId];
    [cached setDateCreated:dt];
    
    return YES;
}

/*
 *  Rebuild the entire vault and initialze its content.
 */
+(void) fullyRebuildVaultAndContent
{
    NSLog(@"CONTRIVED: Rebuilding your vault with placeholder content.");
    [ChatSealDebug_contrivedScenario assetDir];

    NSLog(@"CONTRIVED: Destroying all application data.");
    NSError *err = nil;
    if (![ChatSeal destroyAllApplicationDataWithError:&err]) {
        NSLog(@"ERROR: failed to detroy vault.  %@", [err localizedDescription]);
        return;
    }
    
    NSLog(@"CONTRIVED: Creating a new vault.");
    if (![ChatSeal initializeVaultWithError:&err]) {
        NSLog(@"ERROR: failed to initialize vault.,  %@", [err localizedDescription]);
        return;
    }
    
    NSLog(@"CONTRIVED: Setting flags.");
    [ChatSeal setMessageFirstExperienceIfNecessary];
    [ChatSeal checkForLocalNotificationPermissionsIfNecesssary];
    [ChatSeal setFeedsAreSharedWithSealsAsEnabled:YES];
    [ChatSeal setSealTransferCompleteIfNecessary];
    
    NSLog(@"CONTRIVED: Opening the collector.");
    [[ChatSeal applicationFeedCollector] openAndQuery:YES withCompletion:^(ChatSealFeedCollector *collector, BOOL success, NSError *tmp) {
        if (!success) {
            NSLog(@"ERROR: Failed to open the collector!  %@", [tmp localizedDescription]);
        }
    }];

    NSLog(@"CONTRIVED: Building seals with their messages.");
    if (![ChatSealDebug_contrivedScenario buildMySealWithMessages] ||
        ![ChatSealDebug_contrivedScenario buildSisterSealWithMessages] ||
        ![ChatSealDebug_contrivedScenario buildAnonFriendWithMessages] ||
        ![ChatSealDebug_contrivedScenario buildFriendSealWithMessages]) {
        return;
    }
    
    NSLog(@"CONTRIVED: The fake vault and content is fully configured."); 
}
#endif
#endif
/*
 *  The intent of this method is to reconfigure the simulator to look like what it needs to for
 *  taking App Store screen shots.
 */
+(void) buildScreenshotScenario
{
#if CHATSEAL_DEBUGGING_ROUTINES
#if CHATSEAL_RUNNING_CONTRIVED_SCENARIO
#if TARGET_IPHONE_SIMULATOR
    [ChatSealDebug_contrivedScenario fullyRebuildVaultAndContent];
#endif
#endif
#endif
}
@end