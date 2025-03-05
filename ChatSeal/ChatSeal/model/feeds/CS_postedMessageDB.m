//
//  CS_postedMessageDB.m
//  ChatSeal
//
//  Created by Francis Grolemund on 5/12/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_postedMessageDB.h"
#import "CS_feedCollectorUtil.h"
#import "ChatSeal.h"
#import "CS_feedShared.h"
#import "ChatSealPostedMessageProgress.h"

//  THREADING-NOTES:
//  - no locking is provided because it is expected that the owner of this object instance will lock around it.

// - forward declarations
@interface CS_postedMessageDB (internal)
-(id) initWithURL:(NSURL *) u;
-(BOOL) loadFromDiskWithError:(NSError **) err;
-(BOOL) saveToDiskWithError:(NSError **) err;
@end

/***********************
 CS_postedMessageDB
 ***********************/
@implementation CS_postedMessageDB
/*
 *  Object attributes.
 */
{
    NSURL               *uDatabaseFile;
    NSMutableDictionary *mdEntryDatabase;
}

/*
 *  Return a new instance of this object using the given URL as a source if it exists.
 */
+(CS_postedMessageDB *) databaseFromURL:(NSURL *) u withError:(NSError **) err
{
    CS_postedMessageDB *dbRet = [[[CS_postedMessageDB alloc] initWithURL:u] autorelease];
    if ([dbRet loadFromDiskWithError:err]) {
        return dbRet;
    }
    return nil;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [uDatabaseFile release];
    uDatabaseFile = nil;
    
    [mdEntryDatabase release];
    mdEntryDatabase = nil;
    
    [super dealloc];
}

/*
 *  Save a new entry to the database.
 */
-(CS_postedMessage *) addPostedMessageForEntry:(ChatSealMessageEntry *) entry withError:(NSError **) err
{
    // - make sure this database has been loaded at least once.
    if (!mdEntryDatabase) {
        [CS_error fillError:err withCode:CSErrorFeedCollectionNotOpen];
        return nil;
    }
    
    // - add a new entry.
    CS_postedMessage *pm = [CS_postedMessage postedMessageForEntry:entry withError:err];
    if (!pm) {
        return nil;
    }
    
    [mdEntryDatabase setObject:pm forKey:pm.safeEntryId];
    
    // - and persist it to disk.
    if (![self saveToDiskWithError:err]) {
        return nil;
    }
    return pm;
}

/*
 *  Find a specific posted message inside this object database.
 */
-(CS_postedMessage *) postedMessageForSafeEntryId:(NSString *) safeEntryId
{
    return (CS_postedMessage *) [[[mdEntryDatabase objectForKey:safeEntryId] retain] autorelease];
}

/*
 *  The given message is being deleted, so we need to remove all the entries
 *  in our database that match it.
 */
-(NSArray *) prepareSafeEntriesForMessageDeletion:(NSString *) messageId;
{
    NSMutableArray *maRet = [NSMutableArray array];
    if (!mdEntryDatabase) {
        return maRet;
    }
    
    NSArray *arrVals = [mdEntryDatabase allValues];
    for (CS_postedMessage *pm in arrVals) {
        if (![messageId isEqualToString:pm.messageId]) {
            continue;
        }
        [maRet addObject:pm.safeEntryId];
        [mdEntryDatabase removeObjectForKey:pm.safeEntryId];
    }
    
    if ([maRet count]) {
        [self saveToDiskWithError:nil];
    }
    return maRet;
}

/*
 *  The given seal is being invalidated so we need to either remove the entries or
 *  possibly mark them as postponed.
 */
-(NSArray *) prepareSafeEntriesForSealInvalidation:(NSString *) sealId andReturningPostponed:(BOOL *) isPostponed
{
    NSMutableArray *maRet = [NSMutableArray array];
    if (!mdEntryDatabase) {
        return maRet;
    }
    
    BOOL shouldSave  = NO;
    NSArray *arrVals = [mdEntryDatabase allValues];
    for (CS_postedMessage *pm in arrVals) {
        if (![sealId isEqualToString:pm.sealId]) {
            continue;
        }
        
        // - when we don't own the seal, we'll allow the entries to be postponed
        //   instead because the person may get the seal again later.
        if (!pm.isSealOwned) {
            if (isPostponed) {
                *isPostponed = YES;
            }
        }
        else {
            [mdEntryDatabase removeObjectForKey:pm.safeEntryId];
            shouldSave = YES;            
        }
        [maRet addObject:pm.safeEntryId];
    }
    
    // - if we're postponing entries, then don't worry about updating the database.
    if (shouldSave) {
        [self saveToDiskWithError:nil];
    }
    return maRet;
}

/*
 *  Return the list of entries for the given seal id.
 */
-(NSArray *) safeEntriesForSealId:(NSString *) sealId
{
    NSMutableArray *maRet = [NSMutableArray array];
    if (!mdEntryDatabase) {
        return maRet;
    }

    NSArray *arrVals = [mdEntryDatabase allValues];
    for (CS_postedMessage *pm in arrVals) {
        if ([sealId isEqualToString:pm.sealId]) {
            [maRet addObject:pm.safeEntryId];
        }
    }
    return maRet;
}

/*
 *  Populate the provided progress items from the database.
 */
-(void) fillPostedMessageProgressItems:(NSArray *) arr
{
    if (!mdEntryDatabase) {
        return;
    }
    for (ChatSealPostedMessageProgress *prog in arr) {
        CS_postedMessage *pm = [mdEntryDatabase objectForKey:prog.safeEntryId];
        if (pm) {
            [prog setMessageId:pm.messageId andEntryId:pm.entryId];
        }
    }
}

@end

/*******************************
 CS_postedMessageDB (internal)
 *******************************/
@implementation CS_postedMessageDB (internal)
/*
 *  Initialize the object.
 */
-(id) initWithURL:(NSURL *) u
{
    self = [super init];
    if (self) {
        uDatabaseFile = [u retain];
    }
    return self;
}

/*
 *  Load the internal database using the persistent URL.
 */
-(BOOL) loadFromDiskWithError:(NSError **) err
{
    [mdEntryDatabase release];
    mdEntryDatabase = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:[uDatabaseFile path]]) {
        NSDictionary *dict = [CS_feedCollectorUtil secureLoadConfigurationFromFile:uDatabaseFile withError:err];
        if (!dict) {
            return NO;
        }
        mdEntryDatabase = [[NSMutableDictionary alloc] initWithDictionary:dict];
    }
    else {
        mdEntryDatabase = [[NSMutableDictionary alloc] init];
    }
    return YES;
}

/*
 *  Save the entry database to disk.
 */
-(BOOL) saveToDiskWithError:(NSError **) err
{
    if (!mdEntryDatabase || !uDatabaseFile) {
        [CS_error fillError:err withCode:CSErrorFeedCollectionNotOpen];
        return NO;
    }
    return [CS_feedCollectorUtil secureSaveConfiguration:mdEntryDatabase asFile:uDatabaseFile withError:err];
}
@end
