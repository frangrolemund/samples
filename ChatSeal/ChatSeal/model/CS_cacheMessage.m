//
//  CS_cacheMessage.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/23/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "CS_cacheMessage.h"
#import "CS_diskCache.h"
#import "CS_messageIndex.h"
#import "CS_error.h"

// - constants
static NSString *CS_MSGCACHE_CATEGORY = @"messages";
static NSString *CS_MSGLIST_BASE      = @"msg-list";
static NSString *CS_MID_KEY           = @"mid";
static NSString *CS_SEAL_KEY          = @"sealId";
static NSString *CS_DATE_KEY          = @"dateCreated";
static NSString *CS_SYNOPIS_KEY       = @"synopsis";
static NSString *CS_SALT_KEY          = @"salt";
static NSString *CS_IDXCACHE_CATEGORY = @"indices";
static NSString *CS_ISREAD_KEY        = @"isread";
static NSString *CS_PROC_IDS          = @"mproc";
static NSString *CS_PLACEHOLDER_KEY   = @"phold";
static NSString *CS_AUTHOR_KEY        = @"author";
static NSString *CS_FEED_KEY          = @"feed";

// - local data
static NSMutableArray       *maMessageIds              = nil;
static NSMutableDictionary  *mdMessages                = nil;
static BOOL                 isValidated                = NO;
static BOOL                 processedLoaded            = NO;
static NSMutableDictionary  *mdProcessedMessageEntries = nil;

// - forward declarations
@interface CS_cacheMessage (internal) <NSCoding>
-(void) regenerateSalt;
-(BOOL) hasGoodSalt;
+(NSString *) categoryForMessageItem:(NSString *) mid;
+(void) loadProcessedMessageEntryCache;
+(void) saveProcessedMessageEntryCache;
@end

// - shared with the general-purpose message infrastructure to
//   keep the external interface clear
@interface CS_cacheMessage (shared)
+(BOOL) isValidated;
+(void) cacheItem:(CS_cacheMessage *) newItem;
+(void) discardCachedMessage:(NSString *) mid;
+(void) saveCache;
-(id) initWithMessage:(NSString *) messageId andSeal:(CS_cacheSeal *) seal;
-(void) setSeal:(CS_cacheSeal *) seal;
-(void) setDateCreated:(NSDate *)dateCreated;
-(void) setSynopsis:(NSString *)synopsis;
-(CS_messageIndex *) regenerateIndexWithStringArray:(NSArray *) entries;
-(CS_messageIndex *) existingIndexIfAvailable;
-(void) setIsRead:(BOOL) readValue;
+(void) permanentlyLockAllMessagesForSeal:(NSString *) sealId;
-(void) setAuthor:(NSString *) author;
-(void) setDefaultFeed:(NSString *) feedId;
@end

/******************
 CS_cacheMessage
 ******************/
@implementation CS_cacheMessage
/*
 *  Object attributes.
 */
{
    NSString      *mid;
    CS_cacheSeal *seal;
    NSDate        *dateCreated;
    NSString      *synopsis;
    NSString      *indexSalt;
    BOOL          isRead;
    NSString      *author;
    NSString      *defaultFeed;
}

/*
 *  Initialize the library.
 */
+(void) initialize
{
    maMessageIds              = [[NSMutableArray alloc] init];
    mdMessages                = [[NSMutableDictionary alloc] init];
    mdProcessedMessageEntries = [[NSMutableDictionary alloc] init];
}

/*
 *  Release all the cached message content.
 */
+(void) releaseAllCachedContent
{
    @synchronized (maMessageIds) {
        [maMessageIds removeAllObjects];
        [mdMessages removeAllObjects];
    }
}

/*
 *  Return a reference to the cached list of messages.
 */
+(NSArray *) messageList
{
    @synchronized (maMessageIds) {
        return [NSArray arrayWithArray:maMessageIds];
    }
}

/*
 *  Return the number of messages.
 */
+(NSUInteger) messageCount
{
    @synchronized (maMessageIds) {
        return [maMessageIds count];
    }
}

/*
 *  Return the complete list of messages in order.
 */
+(NSArray *) messageItemList
{
    @synchronized (maMessageIds) {
        NSMutableArray *maRet = [NSMutableArray array];
        for (NSString *mid in maMessageIds) {
            CS_cacheMessage *cm = [mdMessages objectForKey:mid];
            if (cm) {
                [maRet addObject:cm];
            }
        }
        return maRet;
    }
}

/*
 *  Return the message for the provided id.
 */
+(CS_cacheMessage *) messageForId:(NSString *) mid
{
    @synchronized (maMessageIds) {
        return [[[mdMessages objectForKey:mid] retain] autorelease];
    }
}

/*
 *  Messages that we've processed before must be tracked to make the import
 *  process more efficient later.  The idea will be to quickly short-circuit as 
 *  much of import as possible.
 */
+(void) markMessageEntryAsProcessed:(NSString *) entryId withHash:(NSString *) msgHash
{
    if (!entryId || !msgHash) {
        return;
    }
    
    @synchronized (mdProcessedMessageEntries) {
        [CS_cacheMessage loadProcessedMessageEntryCache];
        [mdProcessedMessageEntries setObject:entryId forKey:msgHash];
        [CS_cacheMessage saveProcessedMessageEntryCache];
    }
}

/*
 *  Determine if the provided message has been processed previously.
 */
+(NSString *) processedMessageEntryForHash:(NSString *) msgHash
{
    if (!msgHash) {
        return nil;
    }
    
    @synchronized (mdProcessedMessageEntries) {
        [CS_cacheMessage loadProcessedMessageEntryCache];
        return [mdProcessedMessageEntries objectForKey:msgHash];
    }
}

/*
 *  Determine if the message entry is in the processed cache, but since this
 *  is a fairly costly search, it should be done infrequently.
 *  - I'm including this so that when I re-send messages, I don't try to mark them
 *    as processed needlessly.
 */
+(BOOL) hasProcessedMessageEntry:(NSString *) entryId
{
    if (!entryId) {
        return NO;
    }
    
    @synchronized (mdProcessedMessageEntries) {
        [CS_cacheMessage loadProcessedMessageEntryCache];
        NSArray *arr = [mdProcessedMessageEntries allKeysForObject:entryId];
        return (arr && [arr count] ? YES : NO);
    }
}

/*
 *  Find an entry in the procssed cache and discard it so that we can pull it in again.
 */
+(void) discardProcessedMessageEntry:(NSString *) entryId
{
    if (!entryId) {
        return;
    }
    
    @synchronized (mdProcessedMessageEntries) {
        [CS_cacheMessage loadProcessedMessageEntryCache];
        NSArray *arr = [mdProcessedMessageEntries allKeysForObject:entryId];
        if (arr && [arr count]) {
            [mdProcessedMessageEntries removeObjectsForKeys:arr];
            [CS_cacheMessage saveProcessedMessageEntryCache];
        }
    }
}

/*
 *  Try to locate an image placeholder, which is the blurred version of a message item image.
 */
+(UIImage *) imagePlaceholderForBase:(NSString *) baseName andMessage:(NSString *) mid usingSeal:(RSISecureSeal *) seal
{
    if (!seal) {
        return nil;
    }
    
    UIImage *img = nil;
    @autoreleasepool {
        NSObject *obj = [CS_diskCache cachedDataWithBaseName:baseName andCategory:[CS_cacheMessage categoryForMessageItem:mid]];
        if (!obj || ![obj isKindOfClass:[NSData class]]) {
            return nil;
        }
        NSError *err = nil;
        NSDictionary *dict = [seal decryptMessage:(NSData *) obj withError:&err];
        if (!dict) {
            NSLog(@"CS:  Failed to decrypt placeholder content.");
            return  nil;
        }
        
        obj = [dict objectForKey:CS_PLACEHOLDER_KEY];
        if (obj && [obj isKindOfClass:[NSData class]]) {
            img = [[UIImage imageWithData:(NSData *) obj] retain];
        }
    }
    return [img autorelease];
}

/*
 *  Save an image placeholder to the cache.
 *  - because the placeholder is an extension of the message content, we must use the seal
 *    for encryption instead of just the app key because when the seal is gone, the placeholders
 *    must be unavailable. 
 */
+(void) saveImage:(UIImage *) img asPlaceholderForBase:(NSString *) baseName andMessage:(NSString *) mid usingSeal:(RSISecureSeal *) seal
{
    if (!img || !seal) {
        return;
    }
    
    NSData *dImg       = UIImageJPEGRepresentation(img, 0.5f);                                        //  quality isn't really an issue because the image is blurred anyway.
    NSDictionary *dict = [NSDictionary dictionaryWithObject:dImg forKey:CS_PLACEHOLDER_KEY];
    NSError *err       = nil;
    NSData *dEncrypted = [seal encryptLocalOnlyMessage:dict withError:&err];
    if (!dEncrypted) {
        NSLog(@"CS:  Failed to encrypt placeholder content.  %@", [err localizedDescription]);
    }
    [CS_diskCache saveCachedData:dEncrypted withBaseName:baseName andCategory:[CS_cacheMessage categoryForMessageItem:mid]];
}

/*
 *  Discard an existing placeholder.
 */
+(void) discardPlaceholderForBase:(NSString *) baseName andMessage:(NSString *) mid
{
    [CS_diskCache invalidateCacheItemWithBaseName:baseName andCategory:[CS_cacheMessage categoryForMessageItem:mid]];
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [self setSeal:nil];
    
    [mid release];
    mid = nil;
    
    [dateCreated release];
    dateCreated = nil;
    
    [synopsis release];
    synopsis = nil;
    
    [indexSalt release];
    indexSalt = nil;
    
    [author release];
    author = nil;
    
    [defaultFeed release];
    defaultFeed = nil;
    
    [super dealloc];
}

/*
 *  Return the unique id of the message.
 */
-(NSString *) messageId
{
    @synchronized (self) {
        return [[mid retain] autorelease];
    }
}

/*
 *  Return the seal used to secure the message.
 */
-(CS_cacheSeal *) seal
{
    @synchronized (self) {
        return [[seal retain] autorelease];
    }
}

/*
 *  Return the date created
 */
-(NSDate *) dateCreated
{
    @synchronized (self) {
        return [[dateCreated retain] autorelease];
    }
}

/*
 *  Return the synopsis
 */
-(NSString *) synopsis
{
    @synchronized (self) {
        return [[synopsis retain] autorelease];
    }
}

/*
 *  Return the current salt value for indexing.
 */
-(NSString *) indexSalt
{
    @synchronized (self) {
        return [[indexSalt retain] autorelease];
    }
}

/*
 *  Determine if the message has been read by the local user.
 */
-(BOOL) isRead
{
    @synchronized (self) {
        return isRead;
    }
}

/*
 *  Return the author of the message, which is the person with the owning seal.
 */
-(NSString *) author
{
    @synchronized (self) {
        return [[author retain] autorelease];        
    }
}

/*
 *  Return the default feed when appending to the message.
 */
-(NSString *) defaultFeed
{
    @synchronized (self) {
        return [[defaultFeed retain] autorelease];
    }
}

@end

/****************************
 CS_cacheMessage (internal)
 ****************************/
@implementation CS_cacheMessage (internal)
/*
 *  Initialize the object
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        mid = [[aDecoder decodeObjectForKey:CS_MID_KEY] retain];
        NSString *sealId = [aDecoder decodeObjectForKey:CS_SEAL_KEY];
        if (sealId) {
            seal = [[CS_cacheSeal sealForId:sealId] retain];
        }
        dateCreated = [[aDecoder decodeObjectForKey:CS_DATE_KEY] retain];
        synopsis    = [[aDecoder decodeObjectForKey:CS_SYNOPIS_KEY] retain];
        indexSalt   = [[aDecoder decodeObjectForKey:CS_SALT_KEY] retain];
        isRead      = [aDecoder decodeBoolForKey:CS_ISREAD_KEY];
        author      = [[aDecoder decodeObjectForKey:CS_AUTHOR_KEY] retain];
        defaultFeed = [[aDecoder decodeObjectForKey:CS_FEED_KEY] retain];
    }
    return self;
}

/*
 *  Encode this object for coding.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    @synchronized (self) {
        [aCoder encodeObject:mid forKey:CS_MID_KEY];
        [aCoder encodeObject:[seal sealId] forKey:CS_SEAL_KEY];
        [aCoder encodeObject:dateCreated forKey:CS_DATE_KEY];
        [aCoder encodeObject:synopsis forKey:CS_SYNOPIS_KEY];
        [aCoder encodeObject:indexSalt forKey:CS_SALT_KEY];
        [aCoder encodeBool:isRead forKey:CS_ISREAD_KEY];
        [aCoder encodeObject:author forKey:CS_AUTHOR_KEY];
        [aCoder encodeObject:defaultFeed forKey:CS_FEED_KEY];
    }
}

/*
 *  We need to be absolutely sure about the quality of the salt in the index
 *  or the index will be invalid.
 */
-(BOOL) hasGoodSalt
{
    if (indexSalt && [indexSalt length] > 0) {
        return YES;
    }
    return NO;
}

/*
 *  Regenerate the salt value used to build a message-specific index.
 */
-(void) regenerateSalt
{
    [indexSalt release];
    indexSalt = [[[NSUUID UUID] UUIDString] retain];
}

/*
 *  Generate a category for storing a single item from a message.
 */
+(NSString *) categoryForMessageItem:(NSString *) mid
{
    return [NSString stringWithFormat:@"%@/%@", CS_MSGCACHE_CATEGORY, mid];
}

/*
 *  Attempt to load all the processed message entries from disk if they haven't been loaded yet.
 *  - even though this is a cache, it is one that we don't want to be deleted to recover space, so
 *    it will be in the normal vault.
 */
+(void) loadProcessedMessageEntryCache
{
    if (processedLoaded) {
        return;
    }
    
    //  - don't release the old content because a crypto error could cause the on-disk file from
    //    being loaded and we'll attempt to not overwrite is needlessly.
    NSError *err = nil;
    NSURL *u = [RealSecureImage absoluteURLForVaultFile:CS_PROC_IDS withError:&err];
    if (!u) {
        NSLog(@"CS:  Failed to generate a vault name for processed ids.  %@", [err localizedDescription]);
        return;
    }
    
    // - if the file exists, attempt to load it into the dictionary.
    if ([[NSFileManager defaultManager] fileExistsAtPath:[u path]]) {
        RSISecureData *secD = nil;
        if ([RealSecureImage readVaultURL:u intoData:&secD withError:&err]) {
            NSObject *obj = nil;
            @try {
                obj = [NSKeyedUnarchiver unarchiveObjectWithData:secD.rawData];
            }
            @catch (NSException *exception) {
                NSLog(@"CS:  The message cache archive caused an exception.  %@", [exception description]);
            }
            if (obj) {
                if ([obj isKindOfClass:[NSDictionary class]]) {
                    [mdProcessedMessageEntries addEntriesFromDictionary:(NSDictionary *) obj];
                }
            }
        }
        else {
            NSLog(@"CS:  Failed to read the processed ids file.  %@", [err localizedDescription]);
            return;         //  we don't assume it is loaded here because it could have been a crypto error due to out of space.
        }
    }
    processedLoaded = YES;
}

/*
 *  Attempt to save all the procssed message entries in memory to disk.
 */
+(void) saveProcessedMessageEntryCache
{
    NSError *err = nil;
    NSURL *u = [RealSecureImage absoluteURLForVaultFile:CS_PROC_IDS withError:&err];
    if (!u) {
        NSLog(@"CS:  Failed to generate a vault name for processed ids.  %@", [err localizedDescription]);
        return;
    }
    
    // - create an archive to save.
    NSData *d = nil;
    @try {
        d = [NSKeyedArchiver archivedDataWithRootObject:mdProcessedMessageEntries];
    }
    @catch (NSException *exception) {
        NSLog(@"CS:  The message cache archive generated an exception.  %@", [exception description]);
    }
    if (!d) {
        return;
    }
    
    // - this happens atomically, so a failure to write is actually OK because the prior content will
    //   remain.
    // - cache consistency here isn't a priority because it will just require extra work next time to rule out
    //   the message.
    if (![RealSecureImage writeVaultData:d toURL:u withError:&err]) {
        NSLog(@"CS:  Failed to save the processed ids cache.  %@", [err localizedDescription]);
    }
}

@end

/****************************
 CS_cacheMessage (shared)
 ****************************/
@implementation CS_cacheMessage (shared)

/*
 *  Return whether the cache has been validated.
 */
+(BOOL) isValidated
{
    @synchronized (maMessageIds) {
        if (isValidated) {
            return YES;
        }
        
        // - determine if there is on-disk content that we can use.
        [maMessageIds removeAllObjects];
        [mdMessages removeAllObjects];
        NSObject *obj = [CS_diskCache secureCachedDataWithBaseName:CS_MSGLIST_BASE andCategory:CS_MSGCACHE_CATEGORY];
        if (obj && [obj isKindOfClass:[NSArray class]] && [(NSArray *) obj count] == 3) {
            NSArray *arr = (NSArray *) obj;
            if ([[arr objectAtIndex:0] isKindOfClass:[NSNumber class]] &&
                [[arr objectAtIndex:1] isKindOfClass:[NSArray class]] &&
                [[arr objectAtIndex:2] isKindOfClass:[NSDictionary class]]) {
                // - it is important to tie the epoch to the cache to prevent people from playing games by
                //   copying data around.
                NSNumber *nEpoch = [arr objectAtIndex:0];
                if (nEpoch.integerValue == [ChatSeal cacheEpoch]) {
                    NSArray      *arrIds = [arr objectAtIndex:1];
                    [maMessageIds addObjectsFromArray:arrIds];
                    NSDictionary *mdMsgs = [arr objectAtIndex:2];
                    [mdMessages addEntriesFromDictionary:mdMsgs];
                    isValidated = YES;
                    return YES;
                }
            }
        }
        
        // - when the message cache is not returned successfully, we need to completely invalidate it and its indices so
        //   that it will be recreated using the current state.
        [CS_diskCache invalidateCacheCategory:CS_MSGCACHE_CATEGORY];
        [CS_diskCache invalidateCacheCategory:CS_IDXCACHE_CATEGORY];
    }
    return NO;
}

/*
 *  Save the message cache to disk if possible and at least mark it
 *  validated.
 */
+(void) saveCache
{
    @synchronized (maMessageIds) {
        // - save both items because the array has the messages in sorted order.
        NSArray *arr = [NSArray arrayWithObjects:[NSNumber numberWithInteger:[ChatSeal cacheEpoch]], maMessageIds, mdMessages, nil];
        if (![CS_diskCache saveSecureCachedData:arr withBaseName:CS_MSGLIST_BASE andCategory:CS_MSGCACHE_CATEGORY]) {
            // - when the message cache cannot be saved, then it is deleted on disk and the associated indices
            //   are also invalid because their salt values will be out of date the next time the app starts up.
            //   This is unfortunately the side-effect of the approach we use here to optimize cache accesses.
            [CS_diskCache invalidateCacheCategory:CS_IDXCACHE_CATEGORY];
        }
        isValidated = YES;
    }
}

/*
 *  Cache the new message item.
 */
+(void) cacheItem:(CS_cacheMessage *) newItem
{
    @synchronized (maMessageIds) {
        NSString *mid = [newItem messageId];
        if (!newItem || !mid) {
            return;
        }
        
        // - create the arrays if they don't exist.
        if (!maMessageIds) {
            maMessageIds = [[NSMutableArray alloc] init];
        }
        
        if (!mdMessages) {
            mdMessages = [[NSMutableDictionary alloc] init];
        }
        
        // - add/overwrite the content as necessary.
        if ([maMessageIds indexOfObject:mid] == NSNotFound) {
            [maMessageIds addObject:mid];
        }
        [mdMessages setObject:newItem forKey:mid];
    }
}

/*
 *  Remove all traces of the provided message item.
 */
+(void) discardCachedMessage:(NSString *) mid
{
    @synchronized (maMessageIds) {
        [maMessageIds removeObject:mid];
        [mdMessages removeObjectForKey:mid];        
    }
    [CS_diskCache invalidateCacheItemWithBaseName:mid andCategory:CS_IDXCACHE_CATEGORY];
    [CS_diskCache invalidateCacheCategory:[CS_cacheMessage categoryForMessageItem:mid]];
}

/*
 *  Initialize the object.
 */
-(id) initWithMessage:(NSString *) messageId andSeal:(CS_cacheSeal *) messageSeal
{
    self = [super init];
    if (self) {
        mid         = [messageId retain];
        seal        = nil;
        [self setSeal:messageSeal];
        dateCreated = nil;
        synopsis    = nil;
        indexSalt   = nil;
        isRead      = NO;
        author      = nil;
        defaultFeed = nil;
    }
    return self;
}

/*
 *  Assign a new cached seal to the message.
 */
-(void) setSeal:(CS_cacheSeal *) altSeal
{
    @synchronized (self) {
        if (seal != altSeal) {
            [seal release];
            seal = [altSeal retain];
        }
    }
}

/*
 *  Assign the date the message was created.
 */
-(void) setDateCreated:(NSDate *)newDC
{
    @synchronized (self) {
        if (dateCreated != newDC) {
            [dateCreated release];
            dateCreated = [newDC retain];
        }
    }
}

/*
 *  Assign a message synopsis.
 */
-(void) setSynopsis:(NSString *)newSynopsis
{
    @synchronized (self) {
        if (synopsis != newSynopsis) {
            [synopsis release];
            synopsis = [newSynopsis retain];
        }
    }
}

/*
 *  Force a recreation of the current message index using the given
 *  messag entry list.
 */
-(CS_messageIndex *) regenerateIndexWithStringArray:(NSArray *) entries
{
    @synchronized (self) {
        if (entries) {
            [self regenerateSalt];
            CS_messageIndex *mi = [[[CS_messageIndex alloc] init] autorelease];
            for (NSString *entry in entries) {
                [mi appendContentToIndex:entry];
            }
            if ([mi generateIndexWithSalt:indexSalt]) {
                NSData *d = [mi indexData];
                if (d) {
                    [CS_diskCache saveCachedData:d withBaseName:mid andCategory:CS_IDXCACHE_CATEGORY];
                }
                return mi;
            }
        }
        
        // - make sure that the salt is discarded so that we never get out of synch.
        [indexSalt release];
        indexSalt = nil;
        
        return nil;
    }
}

/*
 *  Return the existing message index.
 */
-(CS_messageIndex *) existingIndexIfAvailable
{
    @synchronized (self) {
        // - never return an index if we don't have salt for it because the index
        //   will be unusable.
        if ([self hasGoodSalt]) {
            NSData *d = [CS_diskCache cachedDataWithBaseName:mid andCategory:CS_IDXCACHE_CATEGORY];
            if (d) {
                return [[[CS_messageIndex alloc] initWithIndexData:d] autorelease];
            }
        }
        return nil;
    }
}

/*
 *  Set the value of the is-read flag on the message.
 */
-(void) setIsRead:(BOOL) readValue
{
    @synchronized (self) {
        isRead = readValue;
    }
}

/*
 *  When seals are discarded, we need to ensure that the cached contents for the message are updated so prevent
 *  further access.
 */
+(void) permanentlyLockAllMessagesForSeal:(NSString *) sealId
{
    if (!sealId) {
        return;
    }
    
    @synchronized (maMessageIds) {
        BOOL shouldSave = NO;
        
        // - for every message that matches the seal, we are going to discard all of the cultivated information to
        //   completely wipe it.
        for (CS_cacheMessage *cm in mdMessages.allValues) {
            if ([sealId isEqualToString:cm.seal.sealId]) {
                // -  if the seal is no longer in the seal cache, we need to break
                //    that connection because the seal cache never references a seal
                //    not in the vault.
                if (![CS_cacheSeal sealForId:sealId]) {
                    [cm setSeal:nil];
                }
                
                // - clear the author, synopsis and index.
                [cm setAuthor:nil];
                [cm setSynopsis:nil];
                [cm setDefaultFeed:nil];
                [cm setIsRead:YES];
                [cm regenerateIndexWithStringArray:[NSArray array]];
                shouldSave = YES;
            }
        }
        
        // - update the cache.
        if (shouldSave) {
            [CS_cacheMessage saveCache];
        }
    }
}

/*
 *  Assign the author to this message.
 */
-(void) setAuthor:(NSString *) newAuthor
{
    @synchronized (self) {
        if (newAuthor != author) {
            [author release];
            author = [newAuthor retain];
        }
    }
}

/*
 *  Assign the default feed when appending to the message.
 */
-(void) setDefaultFeed:(NSString *) newFeed
{
    @synchronized (self) {
        if (newFeed != defaultFeed) {
            [defaultFeed release];
            defaultFeed = [newFeed retain];
        }
    }
}
@end
