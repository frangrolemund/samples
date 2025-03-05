//
//  ChatSealMessage.m
//  ChatSeal
//
//  Created by Francis Grolemund on 2/15/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "ChatSealMessage.h"
#import "ChatSeal.h"
#import "RealSecureImage/RealSecureImage.h"
#import "CS_error.h"
#import "CS_cacheSeal.h"
#import "CS_cacheMessage.h"
#import "CS_messageIndex.h"
#import "UIImageGeneration.h"
#import "CS_messageIndex.h"
#import "CS_messageShared.h"
#import <libkern/OSAtomic.h>

//  - constants
NSString *PSM_GENERIC_KEY                     = @"generic";
NSString *PSM_MSGID_KEY                       = @"msgid";       // to make it possible for consumers to know where this message belongs.
NSString *PSM_MSGITEMS_KEY                    = @"msgItems";    // the actual entry data (NString, UIImage)
NSString *PSM_OWNER_KEY                       = @"owner";       // author of the entry
NSString *PSM_CRDATE_KEY                      = @"dateCreated"; // when the entry was created
NSString *PSM_ENTRYID_KEY                     = @"entryId";     // unique id for the entry.
NSString *PSM_PARENT_KEY                      = @"parentId";    // if the message is a response to an existing one, this allows it to be inserted in the right location in the list
NSString *PSM_REVOKE_KEY                      = @"revoke";
NSString *PSM_ISREAD_KEY                      = @"isread";      // label the entry as is-read or not
NSString *PSM_IMGMETRICS_KEY                  = @"imgmetrix";   // temporary storage for the heights of the image items in the UI.
NSString *PSM_USERDATA_KEY                    = @"userData";    // additional capacity in a packed message for caller-created content.
static const uint32_t PSM_SIG_HDR             = 0x50536D73;     // PSms
static const uint32_t PSM_SIG_IDX             = 0x6D696478;     // midx
const uint32_t PSM_SIG_ENTRY                  = 0x6D656E74;     // ment
static const uint32_t PSM_MSG_VER             = 1;
const uint32_t PSM_FLAG_ISREAD                = 0x01;           // these flags are used by both the message and the entries, but not always in all cases.  One set is more convenient.
const uint32_t PSM_FLAG_REVOKE                = 0x02;
const uint32_t PSM_FLAG_SEALOWNER             = 0x04;
static const int PSMT_IMPORT_FLAG             = 0x8000;

//  - types
typedef struct _psm_msg_hdr {
    uint32_t sig;                                       //  PSM_SIG_HDR
    uint32_t version;                                   //  PSM_MSG_VER
    uint32_t flags;
    int32_t linkIndex;                                  //  The next index value to use when saving image links.
} _psm_msg_hdr_t;

typedef struct _psm_msg_idx {
    uint32_t sig;                                       //  PSM_SIG_IDX
    uint32_t numEntries;
} _psm_msg_idx_t;

typedef uint32_t _psm_msg_idx_item_t;

//  - locals
static NSMutableArray *maFullMessageList = nil;
static BOOL           cacheStartup       = YES;

//  - forward declarations
@interface ChatSealMessage (internal)
-(void) setMessageContentsLength:(NSUInteger) newLength;
-(void) discardMessageContents;
-(_psm_msg_hdr_t *) header;
-(_psm_msg_idx_t *) index;
-(void) setIsReadWithoutSave:(BOOL) isRead;
+(NSURL *) messageRootWithError:(NSError **) err;
-(id) initWithNewMessageUsingSeal:(NSString *) sealId;
-(id) initFirstImportOfMessageId:(NSString *) messageId andSealId:(NSString *) sealId;
-(id) initWithCacheItem:(CS_cacheMessage *) cacheItem;
-(id) initWithMessageId:(NSString *) messageId andSealId:(NSString *) sealId;
-(BOOL) saveDecoy:(UIImage *) decoy andError:(NSError **) err;
-(BOOL) loadSealWithError:(NSError **) err;
-(BOOL) appendEntryToArchive:(ChatSealMessageEntry *) mdEntry withError:(NSError **) err;
-(NSURL *) archiveFile;
+(NSURL *) sealIdFileForMessage:(NSURL *) msgDir;
-(BOOL) loadMessageStateWithError:(NSError **) err;
+(NSDictionary *) validatedOnDiskMessageListWithError:(NSError **) err;
+(BOOL) _buildMessageListWithError:(NSError **) err;
+(BOOL) buildMessageListIfNotValid:(NSError **) err;
-(void) fillCachedMessageItemIfPossible:(CS_cacheMessage *) cm andForceUpdates:(BOOL) forceUpdates;
-(void) releaseAllData;
-(BOOL) replaceOnDiskArchiveWithError:(NSError **) err;
-(NSArray *) indexReadyEntries;
+(void) insertMessageIntoGlobalList:(ChatSealMessage *) psm;
-(void) assignCacheItem:(CS_cacheMessage *) ci;
-(BOOL) loadCacheIfNecessary;
+(NSUInteger) offsetToEntryBlockForNumberOfEntries:(NSUInteger) numEntries;
+(NSUInteger) lengthOfMessageBufferWithNumberOfEntries:(NSUInteger) numEntries andEntryBlockLength:(NSUInteger) entryBlockLen;
-(int32_t) nextLinkIndex;
-(BOOL) convertToEntryLinks:(ChatSealMessageEntry *) meEntry andSaveInArray:(NSMutableArray *) maConverted withError:(NSError **) err;
-(BOOL) insertEntry:(ChatSealMessageEntry *) meEntry atIndex:(NSUInteger) idx andReturnReallocation:(BOOL *) reallocated withError:(NSError **) err;
-(BOOL) findAndDeleteEntry:(ChatSealMessageEntry *) meEntry withError:(NSError **) err;
-(ChatSealMessageEntry *) addEntryOfType:(ps_message_type_t) msgType withId:(NSUUID *) entryId andContents:(NSArray *) msgData onCreationDate:(NSDate *) dtCreated
                               withAuthor:(NSString *) author andParentId:(NSUUID *) uuidParent andError:(NSError **) err;
-(ChatSealMessageEntry *) addEntryOfType:(ps_message_type_t) msgType withId:(NSUUID *) entryId andContents:(NSArray *) msgData andDecoy:(UIImage *) decoy
                         andDecoyIsCommon:(BOOL) commonDecoy onCreationDate:(NSDate *) dtCreated withAuthor:(NSString *) author andParentId:(NSUUID *) uuidParent
                                 andError:(NSError **) err;
-(void) discardActiveFilter;
-(void) createActiveFilter;
-(void) recreateActiveFilter;
-(BOOL) recacheMessageForSeal:(RSISecureSeal *) ss;
-(BOOL) isSealValidForMessage:(RSISecureSeal *) ss andRebuildIndex:(BOOL) rebuildIdx;
-(void) setAuthor:(NSString *) author;
-(BOOL) importEntryIntoMessage:(NSDictionary *) dEntry asType:(ps_message_type_t) mtype withError:(NSError **) err;
-(void) buildPostImportFilterUsingEntry:(ChatSealMessageEntry *) me;
-(ChatSealMessageEntry *) entryForIndex:(NSUInteger) idx andAllowFilter:(BOOL) allowFilter withError:(NSError **) err;
+(void) updateApplicationUnreadCount;
@end

// - shared with the cache infrastructure to keep its external interface clear
@interface CS_cacheMessage (shared)
+(BOOL) isValidated;
+(void) saveCache;
+(void) cacheItem:(CS_cacheMessage *) newItem;
+(void) discardCachedMessage:(NSString *) mid;
+(void) permanentlyLockAllMessagesForSeal:(NSString *) sealId;
-(id) initWithMessage:(NSString *) messageId andSeal:(CS_cacheSeal *) seal;
-(void) setSeal:(CS_cacheSeal *) seal;
-(void) setDateCreated:(NSDate *)dateCreated;
-(void) setAuthor:(NSString *)author;
-(void) setSynopsis:(NSString *)synopsis;
-(CS_messageIndex *) regenerateIndexWithStringArray:(NSArray *) entries;
-(CS_messageIndex *) existingIndexIfAvailable;
-(void) setIsRead:(BOOL) readValue;
-(void) setDefaultFeed:(NSString *) feedId;

@end

// - shared with the identity infrastructure.
@interface ChatSealIdentity (shared)
+(id) identityForSealId:(NSString *) sid withError:(NSError **) err;
@end

/*************************
 ChatSealMessage (shared)
 *************************/
@implementation ChatSealMessage (shared)
/*
 *  Return the name for the decoy file.
 */
+(NSURL *) decoyFileForMessageDirectory:(NSURL *) msgDir
{
    if (!msgDir) {
        return nil;
    }
    return [msgDir URLByAppendingPathComponent:@"decoy"];
}

/*
 *  Generate a filename relative to the messgae root for a secure image.
 */
+(NSURL *) fileForSecureImageIndex:(int32_t) idx inDirectory:(NSURL *) uDir
{
    NSString *sFile = [NSString stringWithFormat:@"dat-%d", idx];
    NSURL *uFile = [uDir URLByAppendingPathComponent:sFile];
    return uFile;
}

/*
 *  Create a new message 
 */
+(ChatSealMessage *) createMessageOfType:(ps_message_type_t) mtype usingSeal:(NSString *) sealId withDecoy:(UIImage *) decoy andData:(NSArray *) msgData
                                  onCreationDate:(NSDate *) dtCreated andError:(NSError **) err
{
    NSURL *uRoot = [ChatSealMessage messageRootWithError:err];
    if (!uRoot) {
        return nil;
    }
    
    // - ensure that the current message list is loaded before starting.
    if (![ChatSealMessage buildMessageListIfNotValid:err]) {
        return nil;
    }
    
    //  - get a handle to the given seal.
    RSISecureSeal *seal = [RealSecureImage sealForId:sealId andError:err];
    if (!seal) {
        return nil;
    }
    
    @synchronized (maFullMessageList) {
        //  - generate the basic message object.
        ChatSealMessage *psm = [[[ChatSealMessage alloc] initWithNewMessageUsingSeal:sealId] autorelease];
        
        //  - the idea here is to save the largest possible decoy so that
        //    subsequent messages can take advantage of it.
        //  - use the seal to create a payload
        //  - store the payload in the decoy
        //  - save the results to the archive.
        if ([psm saveDecoy:decoy andError:err] &&
            [psm addEntryOfType:mtype withId:nil andContents:msgData andDecoy:decoy andDecoyIsCommon:YES onCreationDate:dtCreated withAuthor:nil andParentId:nil andError:err]) {
            [ChatSealMessage insertMessageIntoGlobalList:psm];
        }
        else {
            // - don't leave a partially-initialized directory laying around.
            NSError *tmp = nil;
            if (![psm destroyMessageWithError:&tmp]) {
                NSLog(@"CS:  Failed to discard partial new message.  %@", [tmp localizedDescription]);
                NSURL *u = [psm messageDirectory];
                [[NSFileManager defaultManager] removeItemAtURL:u error:nil];
            }
            psm = nil;
        }
        return psm;
    }
}

/*
 *  Return the complete list of messages that match the given search criteria.
 *  - the item identification callback is expected to return YES to continue or NO to abort and return only the items collected to date.
 */
+(NSArray *) messageListForSearchCriteria:(NSString *) searchString withItemIdentification:(BOOL(^)(ChatSealMessage *)) itemIdentified andError:(NSError **) err
{
    // - ensure that the current message list is loaded first
    if (![ChatSealMessage buildMessageListIfNotValid:err]) {
        return nil;
    }
    
    NSArray *arr = [RealSecureImage availableSealsWithError:err];
    if (!arr) {
        return nil;
    }
    
    @synchronized (maFullMessageList) {
        NSMutableArray *maRet = [NSMutableArray array];
        for (ChatSealMessage *psm in maFullMessageList) {
            if (searchString && [searchString length]) {
                // - when filtering, we won't allow invalid seals to return results.
                if (![arr containsObject:psm.sealId]) {
                    continue;
                }
                
                if (![psm messageMatchesSearchCriteria:searchString]) {
                    continue;
                }
            }
            
            [maRet addObject:psm];
            
            // - when a message is identified, pass it along to the caller.
            if (itemIdentified) {
                if (!itemIdentified(psm)) {
                    break;
                }
            }
        }
        
        // - return the adjusted list.
        return maRet;
    }
}

/*
 *  Import a sealed message into the local vault.
 *  - NOTE: since this routine can return errors for legitimate reasons like there is no key for this
 *          message, we have to be a little careful to avoid using the error code for much other
 *          than debugging.
 *  - NOTE: the processed cache is _only_ updated when we successfully import a message because it 
 *          is possible that we'll get the key for the message at some later date and we don't
 *          want to risk a scenario where a message is falsely tagged when we never actually opened it.
 *  - NOTE: importing a message will implicitly build a custom filter for the current message state if
 *          the message is currently being viewed.   This is to guard against scenarios where an active
 *          message is being scrolled as an import occurs.  Without the filter, the indices would change
 *          in the duration of a single scroll event and completely mess up the visible state.
 */
+(ChatSealMessage *) importMessageIntoVault:(NSData *) dMessage andSetDefaultFeed:(NSString *) feedId andReturnUserData:(NSObject **) userData withError:(NSError **) err
{
    // - this method will always take a more exhaustive approach to ensuring a message
    //   doesn't already exist because it has to work independently of the processed cache, which
    //   could be unreliable, if it gets corrupted.
    // - if you want to minimize the work being done here, first check with the isMessageCurrentlyKnown method.
    NSURL *uRoot = [ChatSealMessage messageRootWithError:err];
    if (!uRoot) {
        return nil;
    }
    
    // - try to decrypt
    RSISecureMessage *sm = [RealSecureImage identifyPackedContent:dMessage withFullDecryption:YES andError:err];
    if (!sm || !sm.sealId || !sm.dMessage || !sm.hash) {
        return nil;
    }
    
    // - ensure that the current message list is loaded before continuing.
    if (![ChatSealMessage buildMessageListIfNotValid:err]) {
        return nil;
    }
    
    // - I don't expect the processed cache to report false-positives, so we can use it for
    //   basic verification we shouldn't re-import the message.
    if ([CS_cacheMessage processedMessageEntryForHash:sm.hash]) {
        [CS_error fillError:err withCode:CSErrorMessageExists];
        return nil;
    }
    
    NSDictionary *dictMsg = sm.dMessage;
    NSString *mid         = [dictMsg objectForKey:PSM_MSGID_KEY];
    NSUUID *entryId       = [dictMsg objectForKey:PSM_ENTRYID_KEY];
    NSUUID *parentId      = [dictMsg objectForKey:PSM_PARENT_KEY];
    NSString *author      = [dictMsg objectForKey:PSM_OWNER_KEY];
    NSDate *dtCreated     = [dictMsg objectForKey:PSM_CRDATE_KEY];
    NSArray *arrItems     = [dictMsg objectForKey:PSM_MSGITEMS_KEY];
    NSNumber *nRevoke     = [dictMsg objectForKey:PSM_REVOKE_KEY];
     
    ps_message_type_t mtype = PSMT_GENERIC;
    if (nRevoke && [nRevoke boolValue]) {
        mtype = PSMT_REVOKE;
    }
    
    ChatSealMessage *psm = nil;
    BOOL ret              = YES;
    
    // - Now, when the message is not in the processed cache, it is possible that processed cache is somehow
    //   messed up and we really need to scan the existing message to be 100% sure.
    @synchronized (maFullMessageList) {
        ChatSealMessage *psmSameSeal   = nil;
        ChatSealMessage *psmSameAuthor = nil;
        for (ChatSealMessage *psmCur in maFullMessageList) {
            if ([mid isEqualToString:[psmCur messageId]]) {
                psm = psmCur;
                break;
            }
            
            // - this is a fallback.  if we end up not finding the precise message, we'll use
            //   the closest one we can find.
            if ([psmCur.sealId isEqualToString:sm.sealId]) {
                psmSameSeal = psmCur;
                if ((!psmCur.author && !author) ||
                    ([psmCur.author isEqualToString:author])) {
                    psmSameAuthor = psmCur;
                }
            }
        }
        
        // ...when we couldn't find the exact message (because the owner deleted the original), we're
        //    going to try to find another in our list that has the same author.
        // NOTE: given the next check, I'm not exactly sure this is ever really useful, but I'm going to
        //       keep it for now to guard against a scenario I may not have considered because I'm assuming
        //       there was a reason for the author check at one point.
        if (!psm && psmSameAuthor) {
            psm = psmSameAuthor;
        }
        
        // - the last fallback is the last one that has the same seal.
        if (!psm && psmSameSeal) {
            psm = psmSameSeal;
        }
        
        // ...when the message already exists, we want to verify that the item isn't already there before appending to it.
        if (psm) {
            // - if any failures occurred, return immediately.
            if (![psm importEntryIntoMessage:dictMsg asType:mtype withError:err]) {
                return nil;
            }
            
            // - set the default feed for the message, if provided.
            if (feedId && ![psm isAuthorMe]) {
                [psm setDefaultFeedForMessage:feedId];
            }
         }
    }

    // - don't synchronize this until is is necessary because repacking is somewhat costly.
    if (!psm) {
        // - at one point, I was zeroing out the data in the decoy, but I realized that this was causing
        //   an overall dimming of the image.  Instead, we're going to just create
        //   a fresh decoy for the new message.
        UIImage *imgDecoy = [ChatSeal standardDecoyForSeal:sm.sealId];
        if (!imgDecoy) {
            [CS_error fillError:err withCode:CSErrorInvalidDecoyImage andFailureReason:@"Failed to generate a new message decoy."];
            return nil;
        }
        
        @synchronized (maFullMessageList) {
            // - now create the message in the vault.
            psm = [[[ChatSealMessage alloc] initFirstImportOfMessageId:mid andSealId:sm.sealId] autorelease];
            if (![psm pinSecureContent:err] ||
                ![psm saveDecoy:imgDecoy andError:err] ||
                ![psm addEntryOfType:mtype | PSMT_IMPORT_FLAG withId:entryId andContents:arrItems andDecoy:imgDecoy andDecoyIsCommon:YES onCreationDate:dtCreated
                          withAuthor:author andParentId:parentId andError:err]) {
                    NSError *tmp = nil;
                    if (![psm destroyMessageWithError:&tmp]) {
                        NSLog(@"CS:  Failed to discard partial new message.  %@", [tmp localizedDescription]);
                        NSURL *u = [psm messageDirectory];
                        [[NSFileManager defaultManager] removeItemAtURL:u error:nil];
                    }
                    ret = NO;
            }
            
            // - assign the default feed for the message if it wsa provided.
            if (feedId && ![psm isAuthorMe]) {
                [psm setDefaultFeedForMessage:feedId];
            }
            
            // - unpin in one location only to ensure it happens.
            [psm unpinSecureContent];
            
            // - if any failures occurred, return
            if (!ret) {
                return nil;
            }
             
            [ChatSealMessage insertMessageIntoGlobalList:psm];
        }
        [ChatSeal setMessageFirstExperienceIfNecessary];
    }
    
    // - update the processed cache.
    [CS_cacheMessage markMessageEntryAsProcessed:[entryId UUIDString] withHash:sm.hash];
    
    // - update the author's name and receipt count
    ChatSealIdentity *ident = [ChatSeal identityForSeal:sm.sealId withError:nil];
    if (ident && ![ident isOwned]) {
        [ident setOwnerName:author ifBeforeDate:dtCreated];
    }
    [ident incrementRecvCount];    
    
    // - notify any interested parties.
    if (psm && entryId) {
        // - use the message id of the actual message object and not the one in the data passed-in because
        //   we may need to change that message id before we import it.
        [ChatSeal notifyMessageImportedWithId:psm.messageId andEntry:entryId];
        [ChatSealMessage updateApplicationUnreadCount];
        
        // - return the user data with this message, if it exists.
        if (userData) {
            *userData = [dictMsg objectForKey:PSM_USERDATA_KEY];
        }
    }
    return psm;
}

/*
 *  Determines if the given message currently exists in the vault.
 */
+(BOOL) isPackedMessageCurrentlyKnown:(NSData *) dMessage
{
    // - this method is intentionally going to limit the check to only the message header to make it as efficient
    //   as possible.
    RSISecureMessage *sm = [RealSecureImage identifyPackedContent:dMessage withFullDecryption:NO andError:nil];
    if (!sm) {
        return NO;
    }
    return ([CS_cacheMessage processedMessageEntryForHash:sm.hash] ? YES : NO);
}

/*
 *  Determine if the given message identified by hash exists in the vault.
 */
+(BOOL) isPackedMessageHashCurrentlyKnown:(NSString *) sHash
{
    return ([CS_cacheMessage processedMessageEntryForHash:sHash] ? YES : NO);
}

/*
 *  Find a message in the system that matches the given seal/author combination when creating a new
 *  message.  This allows us to continue in the identity that we started with.
 */
+(ChatSealMessage *) bestMessageForSeal:(NSString *) sid andAuthor:(NSString *) author
{
    // - don't bother without a seal.
    if (!sid) {
        return nil;
    }
    
    //  - scan the entire list of active messages.
    @synchronized (maFullMessageList) {
        ChatSealMessage *psmMostRecent = nil;
        for (ChatSealMessage *psm in maFullMessageList) {
            NSString *sidCur = [psm sealId];
            if (!sidCur || ![sidCur isEqualToString:sid]) {
                continue;
            }
            
            // - an exact author match is ideal.
            if ((!psm.author && !author) || [psm.author isEqualToString:author]) {
                return [[psm retain] autorelease];
            }
            
            // - otherwise, we'll go for the most recent one with any author name.
            if (!psmMostRecent || [psmMostRecent.creationDate compare:[psm creationDate]] == NSOrderedAscending) {
                psmMostRecent = psm;
            }
        }
        
        // - return the most recent one we could find if all else fails.
        return [[psmMostRecent retain] autorelease];
    }
}

/*
 *  Locate the message with the matching id.
 */
+(ChatSealMessage *) messageForId:(NSString *) mid
{
    if (!mid) {
        return nil;
    }
    
    //  - scan the entire list of active messages for the one with the same id.
    @synchronized (maFullMessageList) {
        for (ChatSealMessage *psm in maFullMessageList) {
            if ([[psm messageId] isEqualToString:mid]) {
                return [[psm retain] autorelease];
            }
        }
    }
    return nil;
}

@end

/*************************
 ChatSealMessage
 *************************/
@implementation ChatSealMessage
{
    // - all minimally-viable messages must
    //   have these items.
    CS_messageEdition *editionLock;
    NSUInteger         pinCount;
    BOOL               isBeingDisplayed;
    BOOL               isNew;
    NSString           *mid;
    NSString           *sid;
    NSURL              *messageDirectory;
    
    // - the associated cache item, which may not
    //   be loaded.
    CS_cacheMessage  *cachedMessage;
    
    // - the seal used to secure the message, which may
    //   not be loaded.
    RSISecureSeal     *seal;
    
    // - current state of the message, which may not
    //   be loaded.
    NSMutableData     *mdMessageContents;
    NSIndexSet        *isNewItemSet;
    
    // - filtering attributes
    NSString          *currentFilterCriteria;
    NSUInteger        numFilteredEntries;
    NSMutableData     *mdFilteredIndices;
    BOOL              isImportFiltered;
}

/*
 *  Initialize this subsystem.
 */
+(void) initialize
{
    maFullMessageList = [[NSMutableArray alloc] init];    
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [self releaseAllData];
    [editionLock release];
    editionLock = nil;
    [super dealloc];
}

/*
 *  Destroy the message directory.
 */
+(BOOL) destroyAllMessagesWithError:(NSError **) err
{
    NSURL *url = [ChatSealMessage messageRootWithError:err];
    if (!url) {
        return NO;
    }
 
    @synchronized (maFullMessageList) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:[url path]]) {
            NSError *tmp = nil;
            if (![[NSFileManager defaultManager] removeItemAtURL:url error:&tmp]) {
                [CS_error fillError:err withCode:CSErrorFilesystemAccessError andFailureReason:[tmp localizedDescription]];
                return NO;
            }
        }
        [CS_cacheMessage releaseAllCachedContent];
        return YES;
    }
}

/*
 *  This general-purpose routine formats the date for a message entry.
 */
+(NSString *) formattedMessageEntryDate:(NSDate *) dt andAbbreviateThisWeek:(BOOL) abbreviateThisWeek andExcludeRedundantYear:(BOOL) excludeYear
{
    //  - the first thing is to format the date and time separately so we can
    //    accurately count characters.
    NSString *sDateName     = nil;
    
    NSDate           *dNow  = [NSDate date];
    NSUInteger       units  = NSYearCalendarUnit | NSDayCalendarUnit | NSWeekOfYearCalendarUnit;
    NSDateComponents *dcNow = [[NSCalendar currentCalendar] components:units fromDate:dNow];
    NSDateComponents *dc    = [[NSCalendar currentCalendar] components:units fromDate:dt];
    
    //  - we'll treat the current week a little differently
    if (abbreviateThisWeek && dc.year == dcNow.year && dc.weekOfYear == dcNow.weekOfYear) {
        if (dc.day == dcNow.day) {
            sDateName = NSLocalizedString(@"Today", nil);
        }
        else {
            NSDateFormatter *df = [[NSDateFormatter alloc] init];
            [df setDateFormat:@"EEEE"];
            sDateName = [df stringFromDate:dt];
            [df release];
        }
    }
    else {
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        if (excludeYear && dc.year == dcNow.year) {
            [df setDateFormat:@"MMM dd"];
        }
        else {
            [df setDateFormat:@"MMM dd, yyyy"];
        }
        sDateName = [df stringFromDate:dt];
        [df release];
    }
    return sDateName;
}

/*
 *  When seals are discarded or revoked, we must ensure that the cache can never be used again to infer their messages' content.
 */
+(void) permanentlyLockAllMessagesForSeal:(NSString *) sealId
{
    @synchronized (maFullMessageList) {
        [CS_cacheMessage permanentlyLockAllMessagesForSeal:sealId];
        [ChatSealMessage updateApplicationUnreadCount];
    }
}

/*
 *  Return the number of messages in the system that match the given id.
 */
+(NSUInteger) countOfMessagesForSeal:(NSString *) sealId
{
    NSUInteger ret = 0;
    NSArray *arr = [CS_cacheMessage messageItemList];
    for (CS_cacheMessage *cm in arr) {
        if (cm.seal) {
            if ([sealId isEqualToString:cm.seal.sealId]) {
                ret++;
            }
        }
    }
    return ret;
}

/*
 *  The sealed message cache saves on repeated packing of messages, but when we modify seals it must
 *  be discarded so that seal attributes are updated for the next round of packing.
 */
+(void) discardSealedMessageCache
{
    @synchronized (maFullMessageList) {
        NSURL *url = [ChatSealMessageEntry sealedMessageCacheWithCreationIfNotExist:NO];
        if ([[NSFileManager defaultManager] fileExistsAtPath:[url path]] && ![[NSFileManager defaultManager] removeItemAtURL:url error:nil]) {
            NSArray *arr = [ChatSeal sortedDirectoryListForURL:url withError:nil];
            if (arr) {
                BOOL hasFailed = NO;
                for (NSURL *u in arr) {
                    if (![[NSFileManager defaultManager] removeItemAtURL:u error:nil]) {
                        hasFailed = YES;
                    }
                }
                if (hasFailed) {
                    NSLog(@"CS: The sealed message cache could not be completely discarded.");
                }
            }
        }        
    }
}

/*
 *  Recache the relevant information for the messages identified by the given seal.
 */
+(void) recacheMessagesForSeal:(RSISecureSeal *) ss
{
    @synchronized (maFullMessageList) {
        // - scan the active list for candidates and update their cached information as needed.
        BOOL resave = NO;
        for (ChatSealMessage *psm in maFullMessageList) {
            if ([psm recacheMessageForSeal:ss]) {
                resave = YES;
            }
        }
        
        // - if any of the cached items was updated, save the cache to disk.
        if (resave) {
            [CS_cacheMessage saveCache];
            [ChatSealMessage updateApplicationUnreadCount];
        }
    }
}

/*
 * Recache messages for the given seal id.
 */
+(void) recacheMessagesForSealId:(NSString *) sid
{
    RSISecureSeal *ss = [RealSecureImage sealForId:sid andError:nil];
    if (ss) {
        [ChatSealMessage recacheMessagesForSeal:ss];
    }
}

/*
 *  This common routine will format a good author string for a given entry that can be displayed in its header.
 */
+(NSString *) standardDisplayHeaderAuthorForMessage:(ChatSealMessage *) csm andEntry:(ChatSealMessageEntry *) me withActiveAuthorName:(NSString *) activeAuthor
{
    NSString *author = nil;
    if (csm && me) {
        author = [me author];
        if ([csm isAuthorMe] && [me isOwnerEntry]) {
            // - I'm not going to display the author name if it is the same as what I'm using right now, because
            //   that feels a bit redundant.
            if ([author isEqualToString:activeAuthor]) {
                author = nil;
            }
            else if (author) {
                // - I'm also not going to show a generic anoymous author name when I own the seal
                //   because I think it is sort of a bit much when you see a lot of one liner messages
                //   in the display.
                author = [NSString stringWithFormat:@"%@ (%@)", [ChatSeal ownerForAnonymousSealForMe:YES withLongForm:NO], author];
            }
        }
        else if (![csm isAuthorMe]) {
            // - I'm not the seal owner, but I have to display the content.
            if ([me isOwnerEntry]) {
                NSString *ownerName = [ChatSeal ownerNameForSeal:csm.sealId];
                author              = ownerName ? ownerName : (author ? author : [ChatSeal ownerForAnonymousSealForMe:NO withLongForm:NO]);
            }
            else {
                // - the consumers don't see anyone except themselves and the seal owner, so it is
                //   proper to only display them as 'Me'.
                if (author) {
                    author = [NSString stringWithFormat:@"%@ (%@)", [ChatSeal ownerForAnonymousSealForMe:YES withLongForm:NO], author];
                }
                else {
                    author = [ChatSeal ownerForAnonymousSealForMe:YES withLongForm:YES];
                }
            }
        }
    }
    return author;
}

/*
 *  The id of the message is assigned when it is first created and is retained throughout its lifetime to allow for quick categorization.
 */
-(NSString *) messageId
{
    [editionLock lock];
    NSString *ret = [[mid retain] autorelease];
    [editionLock unlock];
    return ret;
}

/*
 *  Returns the location of the on-disk archive.
 */
-(NSURL *) messageDirectory
{
    NSURL *ret = nil;
    [editionLock lock];
    
    if (mid) {
        if (!messageDirectory) {
            NSURL *uRoot = [ChatSealMessage messageRootWithError:nil];
            messageDirectory = [[uRoot URLByAppendingPathComponent:mid] retain];
        }
        ret = [[messageDirectory retain] autorelease];
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Add a new entry to the message, encoded as a producer/consumer depending on the seal ownership.
 *  - the purpose of supplying a creation date here is to facillitate testing, but in general it should be nil.
 */
-(ChatSealMessageEntry *) addNewEntryOfType:(ps_message_type_t) msgType withContents:(NSArray *) msgData onCreationDate:(NSDate *) dtCreated andError:(NSError **) err
{
    ChatSealMessageEntry *entry = nil;
    [editionLock lock];
    
    entry = [self addEntryOfType:msgType withId:nil andContents:msgData onCreationDate:dtCreated withAuthor:nil andParentId:nil andError:err];
    
    [editionLock unlock];
    return entry;
}

/*
 *  Append a new message of the given type with the requested decoy.
 *  - the purpose of supplying a creation date here is to facillitate testing, but in general it should be nil.
 */
-(ChatSealMessageEntry *) addNewEntryOfType:(ps_message_type_t) msgType withContents:(NSArray *) msgData andDecoy:(UIImage *) decoy onCreationDate:(NSDate *) dtCreated
                                    andError:(NSError **) err
{
    ChatSealMessageEntry *entry = nil;
    [editionLock lock];
    
    entry = [self addEntryOfType:msgType withId:nil andContents:msgData andDecoy:decoy andDecoyIsCommon:NO onCreationDate:dtCreated withAuthor:nil andParentId:nil andError:err];
    
    [editionLock unlock];
    return entry;
}

/*
 *  Append a FAKE remote entry onto this message.
 *  - This is INTENDED ONLY as a debugging tool.
 */
-(ChatSealMessageEntry *) importRemoteEntryWithContents:(NSArray *) msgData asAuthor:(NSString *) author onCreationDate:(NSDate *) dtCreated withError:(NSError **) err
{
    NSMutableDictionary *mdImport = [NSMutableDictionary dictionary];
    NSUUID *entryId               = [NSUUID UUID];
    [mdImport setObject:entryId forKey:PSM_ENTRYID_KEY];
    [mdImport setObject:[NSUUID UUID] forKey:PSM_PARENT_KEY];
    if (author) {
        [mdImport setObject:author forKey:PSM_OWNER_KEY];
    }
    [mdImport setObject:dtCreated ? dtCreated : [NSDate date] forKey:PSM_CRDATE_KEY];
    [mdImport setObject:msgData forKey:PSM_MSGITEMS_KEY];
    
    if ([self importEntryIntoMessage:mdImport asType:PSMT_GENERIC withError:err]) {
        ChatSealMessageEntry *meRet = [[[ChatSealMessageEntry alloc] initWithMessage:mid inDirectory:[self messageDirectory] andSeal:seal andData:NULL usingLock:editionLock] autorelease];
        [meRet setMessageId:mid];
        [meRet setItems:msgData];
        [meRet setEntryId:entryId];
        [meRet setCreationDate:[mdImport objectForKey:PSM_CRDATE_KEY]];
        return meRet;
    }
    return nil;
}

/*
 *  Return the number of entries currently configured in the message.
 */
-(NSInteger) numEntriesWithError:(NSError **) err
{
    NSInteger ret = -1;
    [editionLock lock];
    if ([self pinSecureContent:err]) {
        if (mdFilteredIndices) {
            ret = (NSInteger) numFilteredEntries;
        }
        else {
            _psm_msg_idx_t *idx = [self index];
            if (idx) {
                ret = (NSInteger) idx->numEntries;
            }
        }
        [self unpinSecureContent];
    }
    [editionLock unlock];
    return ret;
}

/*
 *  Returns whether a seal exists on-device for this message.
 */
-(BOOL) hasSealWithError:(NSError **) err
{
    BOOL ret = YES;
    [editionLock lock];
    
    if ([self loadCacheIfNecessary]) {
        if (!cachedMessage.seal || cachedMessage.seal.isKnown) {
            ret = NO;
        }
    }
    else {
        ret = NO;
    }

    [editionLock unlock];
    return  ret;
}

/*
 *  Retrieve the date the message was created.
 */
-(NSDate *) creationDate
{
    NSDate *dtRet = nil;
    [editionLock lock];
    
    if ([self loadCacheIfNecessary]) {
        dtRet = [cachedMessage dateCreated];
    }
    
    [editionLock unlock];
    return dtRet;
}

/*
 *  Return the shape of the seal.
 */
-(RSISecureSeal_Color_t) sealColor
{
    RSISecureSeal_Color_t ret = RSSC_INVALID;
    [editionLock lock];
    
    if ([self loadCacheIfNecessary] && cachedMessage.seal) {
        ret = [cachedMessage.seal color];
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Return the initial author of the message.
 */
-(NSString *) author
{
    NSString *ret = nil;
    
    [editionLock lock];
    
    //  - don't return an author name if this message is locked because
    //    the seal is no longer useful.
    if (![self isLocked]) {
        // - we're always going to start with the owner name and only fall back to content
        //   in the message itself when that fails.
        ret = [ChatSealIdentity ownerNameForSeal:[self sealId]];
        if (!ret) {
            if ([self isAuthorMe]) {
                ret = [ChatSeal ownerForAnonymousSealForMe:YES withLongForm:YES];
            }
            else {
                if ([self loadCacheIfNecessary] && cachedMessage.author) {
                    ret = cachedMessage.author;
                }
                else {
                    ret = [ChatSeal ownerForAnonymousSealForMe:NO withLongForm:YES];
                }
            }
        }
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Identifies conclusively if I authored this message.
 */
-(BOOL) isAuthorMe
{
    BOOL ret = YES;
    [editionLock lock];
    
    if ([self loadCacheIfNecessary]) {
        ret = (cachedMessage.seal.isKnown && cachedMessage.seal.isOwned);
    }
    else {
        ret = NO;
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Returns the message synopsis.
 */
-(NSString *) synopsis
{
    NSString *ret = nil;
    [editionLock lock];
    
    if ([self loadCacheIfNecessary]) {
        ret = [cachedMessage synopsis];
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Retrieve a specific entry from the message.
 */
-(ChatSealMessageEntry *) entryForIndex:(NSUInteger) idx withError:(NSError **) err
{
    return [self entryForIndex:idx andAllowFilter:YES withError:err];
}

/*
 *  Locate an entry using its unique id.
 *  - this is somewhat expensive, but should really only be used when posting messages
 *    and one at a time anyway because of network throttling.
 */
-(ChatSealMessageEntry *) entryForId:(NSString *) entryId withError:(NSError **) err
{
    ChatSealMessageEntry *meRet = nil;
    if (!entryId) {
        [CS_error fillError:err withCode:CSErrorNotFound];
        return nil;
    }
    
    // - convert the entry into raw bytes because the entry can most quickly check that
    //   kind of organization.
    NSUUID *entryAsUUID = [[NSUUID alloc] initWithUUIDString:entryId];
    uuid_t rawUUID;
    [entryAsUUID getUUIDBytes:rawUUID];
    [entryAsUUID release];
    
    [editionLock lock];

    // - NOTE: keep in mind that this message object may be used by the user at the same
    //   time if they're looking at it.  That could include filtering, which means that
    //   all the external APIs that include the search filter cannot be used.  We need
    //   to look throughout, independent of the filter state.
    
    _psm_msg_idx_t *idx      = [self index];
    NSUInteger offset        = sizeof(_psm_msg_hdr_t) + sizeof(_psm_msg_idx_t);
    NSUInteger lenBuffer     = [mdMessageContents length];
    unsigned char *endBuffer = ((unsigned char *) [mdMessageContents mutableBytes]) + lenBuffer;
    if (idx) {
        for (uint32_t entryItem = 0; entryItem < idx->numEntries; entryItem++) {
            if (offset + (sizeof(_psm_msg_idx_item_t) * (entryItem + 1)) <= lenBuffer) {
                _psm_msg_idx_item_t *entryIndex = (_psm_msg_idx_item_t *) (((unsigned char *) [mdMessageContents mutableBytes]) + offset);
                unsigned char *pElement         = ((unsigned char *) [mdMessageContents mutableBytes]) + entryIndex[entryItem];
                if (pElement < endBuffer) {
                    // - the goal here is to avoid creating anything until we're sure this entry matches in order to
                    //   minimize the search time here as much as possible, even though this is an O(n) kind of search.
                    if ([ChatSealMessageEntry entryAtLocation:pElement isEqualToUUID:&rawUUID]) {
                        meRet = [[[ChatSealMessageEntry alloc] initWithMessage:mid inDirectory:[self messageDirectory] andSeal:seal andData:pElement usingLock:editionLock] autorelease];
                        [meRet assignCreationEditionFromLock];
                        break;
                    }
                }
                else {
                    NSLog(@"CS-ALERT:  Bad element index pointer in entryForId.");
                    break;
                }
            }
        }
    }
    
    [editionLock unlock];
    
    // - if we didn't find it and there was no error to this point, create a generic one.
    if (!meRet && err && !err) {
        [CS_error fillError:err withCode:CSErrorNotFound];
    }
    return meRet;
}

/*
 *  This API is useful because it more carefully controls the locking for entry export.
 *  - the user data argument allows the caller to include arbitrary extra content with the message
 *    as it is packed.
 */
-(NSData *) sealedMessageForEntryId:(NSString *) entryId includingUserData:(NSObject *) objUser withError:(NSError **) err
{
    NSData *dRet                = nil;
    NSError *tmp                = nil;
    CS_messageEntryExport *mee = nil;
    
    // - use this pool to limit the lifespan of these personal items.
    @autoreleasepool {
        // - first find and then export the entry while under the edition lock to prevent
        //   any changes to the message.
        [editionLock lock];
        ChatSealMessageEntry *pme = [self entryForId:entryId withError:err];
        if (pme) {
            mee = [pme exportEntryWithError:err];
        }
        [editionLock unlock];
        
        // - now outside the lock we can try to build the sealed message, which may take a little time, but
        //   shouldn't be obvious.
        if (mee) {
            // - if they passed-in some additional data to include in message payload, add that now before we seal it.
            if (objUser) {
                [mee.exportedContent setObject:objUser forKey:PSM_USERDATA_KEY];
            }
            dRet = [[ChatSealMessageEntry buildSealedMessageFromExportedEntry:mee withError:&tmp] retain];       // escape the pool
            [tmp retain];                                                                                        // escape the pool
        }
    }
    
    [tmp autorelease];
    if (err) {
        *err = tmp;
    }
    return [dRet autorelease];
}

/*
 *  Return whether this message was just created.
 */
-(BOOL) isNew
{
    BOOL ret = NO;
    [editionLock lock];
    ret = isNew;
    [editionLock unlock];
    return ret;
}

/*
 *  Destroy the provided entry from the message contents both in-memory and on-disk.
 */
-(BOOL) destroyEntry:(ChatSealMessageEntry *) entry withError:(NSError **) err
{
    BOOL ret = YES;
    
    [editionLock lock];
    
    // - make sure that we have a complete object.
    if ([self pinSecureContent:err]) {
        //  - remove the entry links
        NSUInteger numItems = [entry numItems];
        NSURL *msgDir       = [self messageDirectory];
        for (NSUInteger i = 0; i < numItems; i++) {
            NSObject *obj = [entry linkedItemAtIndex:i withError:nil];
            if (obj && [obj isKindOfClass:[NSNumber class]]) {
                NSURL *uFile = [ChatSealMessage fileForSecureImageIndex:[(NSNumber *) obj intValue] inDirectory:msgDir];
                if (uFile) {
                    [[NSFileManager defaultManager] removeItemAtURL:uFile error:nil];
                }
            }
        }
        
        //  - and the placeholder images.
        [entry discardEntryPlaceholders];
        
        //  - and the alternate decoy, if present
        [entry destroyAlternateDecoyFileIfPresent];
        
        NSUUID *entryUUID = [entry entryUUID];
        
        // - now locate the entry we're going to delete and remove it from the in-memory contents.
        if ([self findAndDeleteEntry:entry withError: err]) {
            //  - update the archive.
            if (![self replaceOnDiskArchiveWithError:err]) {
                // - a failure here leaves the object inconsistent, so
                //   we don't want to use it any longer.
                [CS_cacheMessage discardCachedMessage:mid];
                [self releaseAllData];
                ret = NO;
            }
            
            // - and the processed message cache so that it can be re-downloaded later.
            [CS_cacheMessage discardProcessedMessageEntry:[entryUUID UUIDString]];
            
            // - if this was the last entry, then destroy the message.
            if (ret) {
                if ([self numEntriesWithError:nil] == 0) {
                    ret = [self destroyMessageWithError:err];
                }
                else {
                    // - the cache needs to be updated for a deleted item because the synopsis should
                    //   be reverted.
                    CS_cacheMessage *cm = [CS_cacheMessage messageForId:mid];
                    [self fillCachedMessageItemIfPossible:cm andForceUpdates:YES];
                    [CS_cacheMessage saveCache];
                }
            }
        }
        else {
            ret = NO;
        }
        [self unpinSecureContent];
    }
    else {
        ret = NO;
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Destroy an entry at a given index.
 */
-(BOOL) destroyEntryAtIndex:(NSUInteger) idx withError:(NSError **) err
{
    BOOL ret = YES;
    [editionLock lock];
    
    // - make sure the object is complete
    if ([self pinSecureContent:err]) {
        ChatSealMessageEntry *me = [self entryForIndex:idx withError:err];
        if (me) {
            ret = [self destroyEntry:me withError:err];
        }
        else {
            ret = NO;
        }
        [self unpinSecureContent];
    }
    else {
        ret = NO;
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Destroy the complete message with all its on-disk contents.
 */
-(BOOL) destroyMessageWithError:(NSError **) err
{
    BOOL ret = YES;
    [editionLock lock];
    
    if (mid) {
        NSURL *u     = [self messageDirectory];
        NSError *tmp = nil;
        if ([[NSFileManager defaultManager] removeItemAtURL:u error:&tmp]) {
            [CS_cacheMessage discardCachedMessage:mid];
            [CS_cacheMessage saveCache];
            [self releaseAllData];
            @synchronized (maFullMessageList) {
                [maFullMessageList removeObject:self];
            }
        }
        else {
            [CS_error fillError:err withCode:CSErrorFilesystemAccessError andFailureReason:[tmp localizedDescription]];
            ret = NO;
        }
    }
    else {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        ret = NO;
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Destroy the complete new message with all on-disk contents.
 */
-(BOOL) destroyNewMessageWithError:(NSError **) err
{
    // - this used to do a bit more, but I like the idea of making
    //   new message destruction named something else.
    return [self destroyMessageWithError:err];
}

/*
 *  This API is used to ensure that individual messages can be checked for whether they match the search string.
 */
-(BOOL) messageMatchesSearchCriteria:(NSString *) searchCriteria
{
    BOOL ret = YES;
    [editionLock lock];
    
    if (searchCriteria && [searchCriteria length]) {
        if ([self loadCacheIfNecessary]) {
            // - get/create an index.
            CS_messageIndex *mi = [cachedMessage existingIndexIfAvailable];
            if (!mi) {
                if ([self pinSecureContent:nil]) {
                    mi = [cachedMessage regenerateIndexWithStringArray:[self indexReadyEntries]];
                    [self unpinSecureContent];
                }
                else {
                    ret = NO;
                }
            }
            
            // - only continue if the index is solid.
            if (ret) {
                // - the date created should always exist and if it does and is today, we'll include search support for that string
                //   to not create odd behavior that you can't search for something that is clearly visible.
                if (cachedMessage.dateCreated) {
                    NSUInteger startDay = [[NSCalendar currentCalendar] ordinalityOfUnit:NSDayCalendarUnit inUnit:NSEraCalendarUnit forDate:[NSDate date]];
                    NSUInteger endDay   = [[NSCalendar currentCalendar] ordinalityOfUnit:NSDayCalendarUnit inUnit:NSEraCalendarUnit forDate:cachedMessage.dateCreated];
                    if (startDay == endDay) {
                        [mi setStringMatchIncludesAbbreviatedToday:YES];
                    }
                }
                
                // - see if we have a match.
                ret = [mi matchesString:searchCriteria usingSalt:[cachedMessage indexSalt]];
            }
        }
        else {
            ret = NO;
        }
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Load up the secure content for this message.
 */
-(BOOL) pinSecureContent:(NSError **) err
{
    @synchronized (maFullMessageList) {
        BOOL ret = YES;
        [editionLock lock];
        
        // - the first time we pin, we're going to decrypt the message.
        if (pinCount == 0) {
            if ([self loadSealWithError:err]) {
                if ([self loadMessageStateWithError:err]) {
                    // - apply the filter if text is set.
                    [self createActiveFilter];
                    
                    // verify its contents since this is the first pinning
                    pinCount = 1;
                    if (![self verifyMessageStructureWithError:err]) {
                        [self unpinSecureContent];
                        ret = NO;
                    }
                }
                else {
                    ret = NO;
                }
            }
            else {
                ret = NO;
            }
        }
        else {
            pinCount++;
        }
        
        [editionLock unlock];
        return ret;
    }
}

/*
 *  Release all the secure content in this message.
 */
-(void) unpinSecureContent
{
    @synchronized (maFullMessageList) {
        [editionLock lock];
        if (pinCount) {
            pinCount--;
            if (pinCount == 0) {
                // - free the actual message data
                [self discardMessageContents];
                
                [seal release];
                seal = nil;
                
                // - I'm clearing out the active search criteria also because it
                //   imposes a lot of extra processing during pinning.  The expectation
                //   is that you pin for the first time and then set the criteria.
                [currentFilterCriteria release];
                currentFilterCriteria = nil;
                [self discardActiveFilter];
                
                // - make sure we don't assume this is being used any longer if we unloaded it completely.
                isBeingDisplayed = NO;
            }
        }
        [editionLock unlock];        
    }
}

/*
 *  Verify that the message's internal structure is valid.
 */
-(BOOL) verifyMessageStructureWithError:(NSError **) err
{
    BOOL ret = YES;
    [editionLock lock];
    
    if ([self pinSecureContent:err]) {
        if (!mdMessageContents) {
            [CS_error fillError:err withCode:CSErrorBadMessageStructure andFailureReason:@"No contents."];
            ret = NO;
        }
    }
    else {
        ret = NO;
    }
    
    //  - verify that the message header looks good.
    if (ret) {
        _psm_msg_hdr_t *hdr = [self header];
        if (!hdr || hdr->sig != PSM_SIG_HDR) {
            [CS_error fillError:err withCode:CSErrorBadMessageStructure andFailureReason:@"Bad header."];
            ret = NO;
        }
        else if (hdr->version > PSM_MSG_VER) {
            [CS_error fillError:err withCode:CSErrorBadMessageStructure andFailureReason:@"Bad version."];
            ret = NO;
        }
    }
    
    // - verify that the index header is good
    _psm_msg_idx_t *index = NULL;
    if (ret) {
        index = [self index];
        if (!index || index->sig != PSM_SIG_IDX) {
            [CS_error fillError:err withCode:CSErrorBadMessageStructure andFailureReason:@"Bad index header."];
            ret = NO;
        }
    }
    
    //  - verify the basic structure of the entries.
    if (ret) {
        NSUInteger numEntries       = index->numEntries;
        NSUInteger lenBuffer        = [mdMessageContents length];
        const unsigned char *pBegin = (const unsigned char *) [mdMessageContents bytes];
        const unsigned char *pEnd   = pBegin + lenBuffer;
        _psm_msg_idx_item_t *indexEntries = (_psm_msg_idx_item_t *) (((unsigned char *) index) + sizeof(_psm_msg_idx_t));
        NSInteger lastOffset = -1;
        for (NSUInteger i = 0; i < numEntries; i++) {
            NSInteger offset = (NSInteger) indexEntries[i];
            if (offset <= lastOffset) {
                [CS_error fillError:err withCode:CSErrorBadMessageStructure andFailureReason:@"Overlapping index offset."];
                ret = NO;
                break;
            }
            
            if (offset > lenBuffer) {
                [CS_error fillError:err withCode:CSErrorBadMessageStructure andFailureReason:@"Overflow index offset."];
                ret = NO;
                break;
            }
            
            const unsigned char *pEntry = pBegin + offset;
            if (pEnd - pEntry < sizeof(PSM_SIG_ENTRY) ||
                memcmp(pEntry, &PSM_SIG_ENTRY, sizeof(PSM_SIG_ENTRY))) {
                [CS_error fillError:err withCode:CSErrorBadMessageStructure andFailureReason:@"Entry signature failure."];
                ret = NO;
                break;
            }
            lastOffset = offset;
        }
    }
    
    // - verify the last entry carefully since it bumps up against the back of the buffer.
    if (ret && index->numEntries > 0) {
        ChatSealMessageEntry *me = [self entryForIndex:index->numEntries-1 withError:nil];
        if (!me) {
            [CS_error fillError:err withCode:CSErrorBadMessageStructure andFailureReason:@"Failed to retrieve the last entry."];
            ret = NO;
        }
        
        if (ret) {
            NSUInteger numItems = [me numItems];
            for (NSUInteger j = 0; j < numItems; j++) {
                if ([me isItemAnImageAtIndex:j]) {
                    NSObject *obj = [me linkedItemAtIndex:j withError:nil];
                    if (!obj || !([obj isKindOfClass:[NSNumber class]] || [obj isKindOfClass:[UIImage class]])) {
                        [CS_error fillError:err withCode:CSErrorBadMessageStructure andFailureReason:@"The last entry has a bad image handle."];
                        ret = NO;
                        break;
                    }
                }
                else {
                    NSObject *obj = [me itemAsStringAtIndex:j];
                    if (!obj || ![obj isKindOfClass:[NSString class]]) {
                        [CS_error fillError:err withCode:CSErrorBadMessageStructure andFailureReason:@"The last entry has a bad string."];
                        ret = NO;
                        break;
                    }
                }
            }
        }
    }
    [self unpinSecureContent];
    
    [editionLock unlock];
    return ret;
}

/*
 *  Returns whether the message has been read or not.
 */
-(BOOL) isRead
{
    BOOL ret = NO;
    [editionLock lock];
    
    if ([self loadCacheIfNecessary]) {
        ret = [cachedMessage isRead];
    }
    else {
        if ([self pinSecureContent:nil]) {
            
            _psm_msg_hdr_t *hdr = [self header];
            if (hdr) {
                ret = (hdr->flags & PSM_FLAG_ISREAD) ? YES : NO;
            }
            [self unpinSecureContent];
        }
        else {
            ret = NO;
        }
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Assign the is-read value in the header.
 */
-(void) setHeader:(_psm_msg_hdr_t *) hdr toIsRead:(BOOL) isRead
{
    [editionLock lock];
    if (hdr) {
        hdr->flags &= ~PSM_FLAG_ISREAD;
        if (isRead) {
            hdr->flags |= PSM_FLAG_ISREAD;
        }
    }
    [editionLock unlock];
}

/*
 *  Update the message with a new is-read state.
 */
-(BOOL) setIsRead:(BOOL) newIsRead withError:(NSError **) err
{
    BOOL ret = YES;
    [editionLock lock];
    
    if (newIsRead != [self isRead]) {
        if ([self pinSecureContent:err]) {
            _psm_msg_hdr_t *hdr = [self header];
            if (hdr) {
                BOOL oldRead = (hdr->flags & PSM_FLAG_ISREAD) ? YES : NO;
                [self setHeader:hdr toIsRead:newIsRead];
                
                // ...if we're moving to is-read, make sure all entries
                //   share that distinction.
                if (newIsRead) {
                    NSInteger numItems = [self numEntriesWithError:nil];
                    for (NSUInteger i = 0; i < numItems; i++) {
                        ChatSealMessageEntry *pme = [self entryForIndex:i withError:nil];
                        if (pme) {
                            [pme setIsRead:YES];
                        }
                    }
                }
                
                // ...update teh cache and the message archive.
                [self loadCacheIfNecessary];
                [cachedMessage setIsRead:newIsRead];
                if (![self replaceOnDiskArchiveWithError:err]) {
                    [self setHeader:hdr toIsRead:oldRead];
                    [cachedMessage setIsRead: oldRead];
                    ret = NO;
                }
            }
            else {
                ret = NO;
            }
            
            [self unpinSecureContent];
        }
        else {
            ret = NO;
        }
    }
    
    [editionLock unlock];
    [ChatSealMessage updateApplicationUnreadCount];
    return ret;
}

/*
 *  Return the table image for the seal.
 */
-(UIImage *) sealTableImage
{
    UIImage *ret = nil;
    [editionLock lock];
    
    if ([self loadCacheIfNecessary]) {
        // - return an appropriate image for the table.
        if ([self isLocked]) {
            ret = [CS_cacheSeal sealMissingTableImage];
        }
        else {
            ret = [cachedMessage.seal tableImage];
        }
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Returns whether the item is locked.
 */
-(BOOL) isLocked
{
    BOOL ret = YES;
    [editionLock lock];
    
    if ([self loadCacheIfNecessary]) {
        ret = (cachedMessage.seal && [cachedMessage.seal isKnown] && [cachedMessage.seal isValid] ? NO : YES);
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Returns the seal id for this message.
 */
-(NSString *) sealId
{
    NSString *ret = nil;
    [editionLock lock];
    
    if ([self loadCacheIfNecessary]) {
        ret = [[cachedMessage.seal.sealId retain] autorelease];
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Every entry in the message has an id that can be used to identify 
 *  it regardless of whether the message is filtered or not.  This
 *  method takes the filtered index and returns the id.
 */
-(psm_entry_id_t) filterAwareEntryIdForIndex:(NSUInteger) idx
{
    psm_entry_id_t ret = (psm_entry_id_t) -1;
    
    [editionLock lock];
    
    if (mdFilteredIndices) {
        if (idx < numFilteredEntries) {
            _psm_msg_idx_item_t *filteredEntries = (_psm_msg_idx_item_t *) [mdFilteredIndices mutableBytes];
            ret = (psm_entry_id_t) filteredEntries[idx];
        }
    }
    else {
        ret = (psm_entry_id_t) idx;
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Return the real index for the given entry id.
 */
-(NSInteger) indexForFilterAwareEntryId:(psm_entry_id_t) entryId
{
    NSInteger ret = -1;
    [editionLock lock];
    
    // - only when the entry is valid will we search for it.
    if (entryId >= 0) {
        if (mdFilteredIndices) {
            _psm_msg_idx_item_t *filteredEntries = (_psm_msg_idx_item_t *) [mdFilteredIndices mutableBytes];
            for (NSUInteger i = 0; i < numFilteredEntries; i++) {
                if (filteredEntries[i] == entryId) {
                    ret = (NSInteger) i;
                    break;
                }
            }
        }
        else {
            ret = entryId;
        }
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Apply a filter to the message.   A value of nil or an empty string will 
 *  unfilter the entire message.
 */
-(void) applyFilter:(NSString *) searchFilter
{
    [editionLock lock];
    
    // - minimize search filter application processing when someone just adds some spaces.
    searchFilter = [searchFilter stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (isImportFiltered ||
        (searchFilter != currentFilterCriteria && ![searchFilter isEqualToString:currentFilterCriteria])) {
        [currentFilterCriteria release];
        currentFilterCriteria = [searchFilter retain];
        [self recreateActiveFilter];
    }
    
    [editionLock unlock];
}

/*
 *  Return the message identity.
 */
-(ChatSealIdentity *) identityWithError:(NSError **) err
{
    ChatSealIdentity *ret = nil;
    [editionLock lock];
    
    ret = [ChatSealIdentity identityForSealId:[self sealId] withError:err];
    
    [editionLock unlock];
    return ret;
}

/*
 *  When we're using a message currently, this flag will help us decide how best
 *  to handle imports.
 */
-(void) setIsBeingDisplayed
{
    [editionLock lock];
    if (pinCount) {
        isBeingDisplayed = YES;
    }
    [editionLock unlock];
}

/*
 *  Return the list of unread items in the message or nil if there are no (unread) items.
 */
-(NSIndexSet *) unreadItems
{
    NSIndexSet *ret = nil;
    [editionLock lock];
    if ([self pinSecureContent:nil]) {
        if (isNewItemSet) {
            ret = [[isNewItemSet retain] autorelease];
        }
        else {
            // - no sense in building one if we've already read this.
            if (![self isRead]) {
                NSInteger count           = [self numEntriesWithError:nil];
                NSMutableIndexSet *misTmp = nil;
                for (NSInteger i = 0; i < count; i++) {
                    ChatSealMessageEntry *me = [self entryForIndex:(NSUInteger) i withError:nil];
                    if (![me isRead]) {
                        if (!misTmp) {
                            misTmp = [NSMutableIndexSet indexSet];
                        }
                        [misTmp addIndex:(NSUInteger) i];
                    }
                }
                isNewItemSet = [misTmp retain];
                ret          = misTmp;
            }
        }
        [self unpinSecureContent];
    }
    [editionLock unlock];
    return ret;
}

/*
 *  The fact that modifications to a message could make entries stale requires that some
 *  operations which must occur reliably (like message posting or packing) need
 *  to occur under a full edition lock.
 */
-(BOOL) performBlockUnderMessageLock:(BOOL (^)(NSError **err)) messageProtectedBlock withError:(NSError **) err
{
    BOOL ret = NO;
    [editionLock lock];
    if (messageProtectedBlock) {
        ret = messageProtectedBlock(err);
    }
    else {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
    }
    [editionLock unlock];
    return ret;
}

/*
 *  The default feed allows us to pre-populate it when entering the message at a later time.
 */
-(void) setDefaultFeedForMessage:(NSString *) feedId
{
    [editionLock lock];
    
    // - the message first
    if ([self loadCacheIfNecessary]) {
        if (![cachedMessage.defaultFeed isEqualToString:feedId]) {
            [cachedMessage setDefaultFeed:feedId];
            [CS_cacheMessage saveCache];
        }
    }
    
    // - and the seal second as a backup in case the message is deleted.
    ChatSealIdentity *ident = [ChatSealIdentity identityForSealId:sid withError:nil];
    [ident setDefaultFeed:feedId];
    
    [editionLock unlock];
}

/*
 *  Figure out if we can identify a default feed for the message, which may not
 *  be possible if it was never set or became invalid at some point.
 */
-(NSString *) defaultFeedForMessage
{
    NSString *ret = nil;
    [editionLock lock];
    
    if ([self loadCacheIfNecessary]) {
        ret = [cachedMessage defaultFeed];
        if (!ret) {
            // - fall back to the seal when there is no default on the message explicitly.
            ChatSealIdentity *ident = [ChatSealIdentity identityForSealId:sid withError:nil];
            ret = [ident defaultFeed];
        }
    }
    
    [editionLock unlock];
    return ret;
}

@end

/*************************
 ChatSealMessage (internal)
 *************************/
@implementation ChatSealMessage (internal)

/*
 *  The message root is where all the messages are stored in the local filesystem.
 */
+(NSURL *) messageRootWithError:(NSError **) err
{
    static NSURL *mRoot = nil;
    if (!mRoot) {
        mRoot = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
        mRoot = [mRoot URLByAppendingPathComponent:@"messages"];
        [mRoot retain];
    }
    
    if (mRoot) {
        if (![[NSFileManager defaultManager] fileExistsAtPath:[mRoot path]]) {
            NSError *tmp = nil;
            if (![[NSFileManager defaultManager] createDirectoryAtURL:mRoot withIntermediateDirectories:YES attributes:nil error:&tmp]) {
                [mRoot release];
                mRoot = nil;
                NSLog(@"CS: Failed to create the message root directory.  %@", [tmp localizedDescription]);
            }
        }
    }
    else {
        [CS_error fillError:err withCode:CSErrorFilesystemAccessError andFailureReason:@"Failed to retrieve a message root directory."];
    }
    return mRoot;
}

/*
 *  Change the size of the message, but do so here so that we can
 *  carefully manage the edition also.
 */
-(void) setMessageContentsLength:(NSUInteger) newLength
{
    [editionLock incrementEdition];
    [mdMessageContents setLength:newLength];
}

/*
 *  Discard the message contents so that they are no longer used.
 */
-(void) discardMessageContents
{
    [editionLock incrementEdition];
    if (mdMessageContents) {
        memset(mdMessageContents.mutableBytes, 0x01, mdMessageContents.length);             //  for debugging so we don't use it after it is freed.
    }
    [mdMessageContents release];
    mdMessageContents = nil;
    
    [isNewItemSet release];
    isNewItemSet = nil;
}

/*
 *  Return a pointer to the header.
 */
-(_psm_msg_hdr_t *) header
{
    _psm_msg_hdr_t *hdr = (_psm_msg_hdr_t *) [mdMessageContents mutableBytes];
    if ([mdMessageContents length] < sizeof(_psm_msg_hdr_t) ||
        (hdr && hdr->sig != PSM_SIG_HDR) ||
        (hdr && hdr->version != PSM_MSG_VER)) {
        hdr = NULL;
    }
    return hdr;
}

/*
 *  Return a pointer to the index.
 */
-(_psm_msg_idx_t *) index
{
    _psm_msg_idx_t *idx = (_psm_msg_idx_t *) (((unsigned char *) [mdMessageContents mutableBytes]) + sizeof(_psm_msg_hdr_t));
    if ([mdMessageContents length] < [ChatSealMessage lengthOfMessageBufferWithNumberOfEntries:0 andEntryBlockLength:0] ||
        (idx && idx->sig != PSM_SIG_IDX)) {
        idx = NULL;
    }
    return idx;
}

/*
 *  Assign the is-read value on the message without saving it.
 */
-(void) setIsReadWithoutSave:(BOOL) isRead
{
    _psm_msg_hdr_t *hdr = [self header];
    if (hdr) {
        hdr->flags = hdr->flags & (~PSM_FLAG_ISREAD);
        if (isRead) {
            hdr->flags |= PSM_FLAG_ISREAD;
        }
    }
}

/*
 *  Create a new message
 */
-(id) initWithNewMessageUsingSeal:(NSString *) sealId
{
    NSString *msgId = [[NSUUID UUID] UUIDString];
    self = [self initWithMessageId:msgId andSealId:sealId];
    if (self) {
        isNew  = YES;
    }
    return self;
}

/*
 *  Import a new message
 */
-(id) initFirstImportOfMessageId:(NSString *) messageId andSealId:(NSString *) sealId
{
    self = [self initWithMessageId:messageId andSealId:sealId];
    if (self) {
        isNew  = YES;
    }
    return self;
}


/*
 *  Initialize the object with the given item from the cache.
 */
-(id) initWithCacheItem:(CS_cacheMessage *) cacheItem
{
    self = [self initWithMessageId:cacheItem.messageId andSealId:cacheItem.seal.sealId];
    if (self) {
        cachedMessage = [cacheItem retain];
    }
    return self;
}

/*
 *  Initialize the object.
 */
-(id) initWithMessageId:(NSString *) messageId andSealId:(NSString *) sealId
{
    self = [super init];
    if (self) {
        editionLock           = [[CS_messageEdition alloc] init];
        pinCount              = 0;
        isBeingDisplayed      = NO;
        isNew                 = NO;
        mid                   = nil;
        sid                   = nil;
        seal                  = nil;
        cachedMessage         = nil;
        mdMessageContents     = nil;
        isNewItemSet          = nil;
        messageDirectory      = nil;
        currentFilterCriteria = nil;
        mdFilteredIndices     = nil;
        numFilteredEntries    = 0;
        isImportFiltered      = NO;
        
        //  - create the message root directory if it doesn't already exist.
        NSURL *uRoot = [ChatSealMessage messageRootWithError:nil];
        if (uRoot) {
            uRoot = [uRoot URLByAppendingPathComponent:messageId];
            if (uRoot &&
                ([[NSFileManager defaultManager] fileExistsAtPath:[uRoot path]] ||
                 [[NSFileManager defaultManager] createDirectoryAtPath:[uRoot path] withIntermediateDirectories:YES attributes:nil error:nil])) {
                    mid = [messageId retain];
                }
        }
        
        sid = [sealId retain];
    }
    return self;
}

/*
 *  Save the decoy to the message root.
 */
-(BOOL) saveDecoy:(UIImage *) decoy andError:(NSError **) err
{
    //  - load up the seal if it isn't yet.
    if (![self loadSealWithError:err]) {
        return NO;
    }
    
    //  - now convert to a JPEG (for optimial size), encrypt it and save to disk
    //  - the seal is used so that message recipients don't own the proof of which decoy is used
    //    if their seal copy is revoked later.
    NSURL *uFile = [ChatSealMessage decoyFileForMessageDirectory:[self messageDirectory]];
    return [ChatSealMessageEntry saveSecureImage:decoy toURL:uFile withSeal:seal andError:err];
}

/*
 *  Ensure the seal is loaded.
 */
-(BOOL) loadSealWithError:(NSError **) err
{
    //  - just some basic validation the object doesn't hurt.
    if (!mid) {
        [CS_error fillError:err withCode:CSErrorFilesystemAccessError andFailureReason:@"Unable to access the message root directory."];
        return NO;
    }
    
    //  - if the seal hasn't been loaded, do so now.
    if (!seal) {
        seal = [[RealSecureImage sealForId:sid andError:err] retain];
        if (!seal) {
            return NO;
        }
    }
    return YES;
}

/*
 *  Save the new entry to the running archive.  
 */
-(BOOL) appendEntryToArchive:(ChatSealMessageEntry *) meEntry withError:(NSError **) err
{
    //  - just in case to ensure we never overwrite an existing
    //    message.
    if (!mdMessageContents) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        return NO;
    }
    
    //  - first figure out where this item is going to be placed.
    NSDate *dtOfNewItem    = [meEntry creationDate];
    NSUUID *idOfParent     = [meEntry parentId];
    BOOL   newIsMine       = [meEntry isOwnerEntry];
    NSInteger numEntries   = [self numEntriesWithError:err];
    if (numEntries < 0) {
        return NO;
    }
    NSUInteger insertIndex   = 0;
    BOOL       inOwnerStream = NO;
    for (NSUInteger i = 0; i < numEntries; i++) {
        ChatSealMessageEntry *meOld = [self entryForIndex:i withError:err];
        if (!meOld) {
            return NO;
        }
        
        // - the sorting is a bit different based on whether this is a producer
        //   message because the goal is to always put responses from consumers
        //   inline with the producer's entry, but otherwise to just ensure
        //   that the stream of thought for the producer stays chronologically
        //   accurate.
        if (newIsMine) {
            // - when the next entry is mine and it occurs after this one chronologically, we
            //   need to insert right before it.
            if ([meOld isOwnerEntry] && [[meOld creationDate] compare:dtOfNewItem] == NSOrderedDescending) {
                break;
            }
        }
        else {
            NSUUID *oldEntryUUID = [meOld entryUUID];
            if ([meOld isOwnerEntry] && [oldEntryUUID isEqual:idOfParent]) {
                inOwnerStream = YES;
            }
            else if (inOwnerStream && [meOld isOwnerEntry]) {
                // - if we just happened upon the end of the producer stream, the
                //   entry goes at the end.
                break;
            }
            else if (inOwnerStream && [[meOld creationDate] compare:dtOfNewItem] == NSOrderedDescending) {
                // - if the next item is another consumer message, but occurs chronologically after this
                //   we're done.
                break;
            }
        }
        
        // - update the insertion index because we still need to advance
        insertIndex = i+1;
    }
    
    //  - from this point on, we'll have to support rolling back if an error occurs.
    BOOL ret                    = YES;
    BOOL reallocatedBuffer      = NO;
    NSMutableArray *maConverted = [NSMutableArray array];
    ret = [self convertToEntryLinks:meEntry andSaveInArray:maConverted withError:err];
    if (ret) {
        [self insertEntry:meEntry atIndex:insertIndex andReturnReallocation:&reallocatedBuffer withError:err];
    }
    
    //  - and update the seal id file for this message
    //  - this allows the message to be quickly decrypted without scanning
    //    for its associated seal.
    NSURL *sealIdFile = nil;
    if (ret) {
        // - if it doesn't exist, create it.
        sealIdFile = [ChatSealMessage sealIdFileForMessage:[self messageDirectory]];
        if (![[NSFileManager defaultManager] fileExistsAtPath:[sealIdFile path]]) {
            NSString *sidText = [(RSISecureSeal *) seal safeSealIdWithError:err];
            if (!sidText || ![sidText writeToURL:sealIdFile atomically:YES encoding:NSASCIIStringEncoding error:err]) {
                ret = NO;
            }
        }
    }
    
    //  - and replace the on-disk version
    if (ret) {
        ret = [self replaceOnDiskArchiveWithError:err];
    }
    
    // - always update its date to the current date/time so that we track when new content is added.
    if (ret) {
        if ([[NSFileManager defaultManager] setAttributes:[NSDictionary dictionaryWithObject:[NSDate date] forKey:NSFileCreationDate] ofItemAtPath:[sealIdFile path] error:err]) {
            CS_cacheMessage *cm = [CS_cacheMessage messageForId:mid];
            [self fillCachedMessageItemIfPossible:cm andForceUpdates:YES];
            [cm setDateCreated:[NSDate date]];
            [CS_cacheMessage saveCache];
        }
        else {
            ret = NO;
        }
    }
    
    // - if there are image placeholders to be created, do so now.
    if (ret && [maConverted count]) {
        NSUInteger numItems = [meEntry numItems];
        for (NSUInteger i = 0; i < numItems; i++) {
            if (![meEntry isItemAnImageAtIndex:i]) {
                continue;
            }
            // - just execute this to force its creation.
            [meEntry imagePlaceholderAtIndex:i];
        }
    }
    
    //  - if any errors occurred, we need to roll back all the changes that were just made.
    if (!ret) {
        // - when the buffer has been reallocated, we need to remove the space for the new content.
        if (reallocatedBuffer) {
            [self destroyEntry:meEntry withError:nil];
        }
        else {
            // - manual removal of all the extra links
            [meEntry destroyAlternateDecoyFileIfPresent];
            
            for (NSUInteger i = 0; i < [maConverted count]; i++) {
                NSObject *obj = [maConverted objectAtIndex:i];
                if (![obj isKindOfClass:[NSNumber class]]) {
                    continue;
                }
                
                NSURL *uFile = [ChatSealMessage fileForSecureImageIndex:[(NSNumber *) obj intValue] inDirectory:[self messageDirectory]];
                [[NSFileManager defaultManager] removeItemAtURL:uFile error:nil];
            }
            
        }
    }
    return ret;
}

/*
 *  Return the name of the message archive file.
 */
-(NSURL *) archiveFile
{
    return [[self messageDirectory] URLByAppendingPathComponent:@"archive"];
}

/*
 *  Return the name of the encrypted file that stores the
 *  seal id for this message thread.
 */
+(NSURL *) sealIdFileForMessage:(NSURL *) msgDir
{
    return [msgDir URLByAppendingPathComponent:@"ssid"];
}

/*
 *  Reload the contents of the message from the current directory.
 */
-(BOOL) loadMessageStateWithError:(NSError **) err
{
    if (mdMessageContents) {
        return YES;
    }
    
    mdMessageContents = [[NSMutableData alloc] init];

    //  - find the archive file.
    BOOL ret = YES;
    NSError *tmp = nil;
    @autoreleasepool {
        NSURL *uArchive = [self archiveFile];
        NSData *dArchive = [NSData dataWithContentsOfURL:uArchive];
        if (dArchive) {
            NSDictionary *dict = [(RSISecureSeal *) seal decryptMessage:dArchive withError:&tmp];
            NSObject *obj      = [dict objectForKey:PSM_GENERIC_KEY];
            if (dict && [obj isKindOfClass:[NSData class]]) {
                NSData *fData = (NSData *) obj;
                [self setMessageContentsLength:[fData length]];
                memcpy(mdMessageContents.mutableBytes, fData.bytes, [fData length]);
            }
            else {
                [CS_error fillError:&tmp withCode:CSErrorInvalidSeal andFailureReason:[tmp localizedDescription]];
                ret = NO;
            }
        }
        else {
            // - until the message is saved, there will be no entries, but the basic storage will exist.
            if (isNew) {
                [self setMessageContentsLength:[ChatSealMessage lengthOfMessageBufferWithNumberOfEntries:0 andEntryBlockLength:0]];
                
                // - when assigning the signatures, we won't use the common
                //   routines because they check the signatures.
                _psm_msg_hdr_t *hdr = (_psm_msg_hdr_t *) [mdMessageContents mutableBytes];
                if (hdr) {
                    hdr->sig     = PSM_SIG_HDR;
                    hdr->version = PSM_MSG_VER;
                }
                _psm_msg_idx_t *idx = (_psm_msg_idx_t *) ((unsigned char *) [mdMessageContents mutableBytes] + sizeof(_psm_msg_hdr_t));
                if (idx) {
                    idx->sig     = PSM_SIG_IDX;
                }
            }
            else {
                [CS_error fillError:err withCode:CSErrorFilesystemAccessError];
                ret = NO;
            }
        }
        
        [tmp retain];
    }
    
    [tmp autorelease];
    if (err) {
        *err = tmp;
    }

    // - if any error occurs, assume no state.
    if (!ret) {
        [self discardMessageContents];
    }
    return ret;
}

/*
 *  Return a list of all the messages in the vault, validated to be proper message entries.
 */
+(NSDictionary *) validatedOnDiskMessageListWithError:(NSError **) err
{
    NSMutableDictionary *mdRet = [NSMutableDictionary dictionary];
    NSURL *uRoot = [ChatSealMessage messageRootWithError:err];
    if (!uRoot) {
        return nil;
    }
    
    NSArray *arrMessages = [ChatSeal sortedDirectoryListForURL:uRoot withError:err];
    if (!arrMessages) {
        return nil;
    }
 
    //  - now for each one, ensure it is a directory and has the required content
    //  - if so, then add it to the running cache.
    NSDictionary *mdSafeIdMap = nil;
    for (NSUInteger i = 0; i < [arrMessages count]; i++) {
        NSURL *uItem = [arrMessages objectAtIndex:i];
        NSNumber *nIsDir = nil;
        if (![uItem getResourceValue:&nIsDir forKey:NSURLIsDirectoryKey error:nil] ||
            ![nIsDir boolValue]) {
            continue;
        }
        
        NSString *msgId = [uItem lastPathComponent];
        
        //  - should be a message.
        uItem = [ChatSealMessage sealIdFileForMessage:uItem];
        if (!uItem) {
            continue;
        }
        
        // - convert out the seal id file content
        NSString *ssid = [NSString stringWithContentsOfURL:uItem encoding:NSASCIIStringEncoding error:nil];
        if (!ssid) {
            continue;
        }
        
        CS_cacheSeal *sTmp = [CS_cacheSeal sealForSafeId:ssid];
        NSString *sealId  = [sTmp sealId];
        if (!msgId) {
            continue;
        }
        
        //  NOTE: an empty seal id is actually allowed if this message cannot be decrypted, but we'll
        //  always make sure.
        if (!sealId) {
            if (!mdSafeIdMap) {
                mdSafeIdMap  = [ChatSeal safeSealIndexWithError:nil];
            }
            
            // - check the map to see if it really exists and the cache is somehow not up to date
            if ([mdSafeIdMap objectForKey:ssid]) {
                NSLog(@"CS: Seal cache consistency failure.  Forcing recreation.");
                [CS_cacheSeal forceCacheRecreation];
            }
        }
        
        // - save the validated item into the dictionary
        if (sealId) {
            [mdRet setObject:sealId forKey:msgId];
        }
        else {
            [mdRet setObject:[NSNumber numberWithBool:NO] forKey:msgId];
        }
    }
    return mdRet;
}

/*
 *  Rebuild the list of cached messages using the on-disk contents.
 *  - the underline prefix is an attempt to avoid fat-fingering this
 *    version when I really want to standardize on the IfNotValid variant.
 */
+(BOOL) _buildMessageListWithError:(NSError **) err
{
    if (![ChatSeal isVaultOpen]) {
        [CS_error fillError:err withCode:CSErrorVaultNotInitialized];
        return NO;
    }
    
    //  - ensure that we have a fresh list to work with.
    [maFullMessageList removeAllObjects];
    [CS_cacheMessage releaseAllCachedContent];
    
    //  - get a list of all the messages in that are in the vault.
    NSDictionary *dMessages = [ChatSealMessage validatedOnDiskMessageListWithError:err];
    if (!dMessages) {
        return NO;
    }
    
    // - load each message one by one and cache its relevant content.
    for (NSString *msgId in dMessages.allKeys) {
        NSObject *obj    = [dMessages objectForKey:msgId];
        NSString *sealId = nil;
        if (obj && [obj isKindOfClass:[NSString class]]) {
            sealId = (NSString *) obj;
        }
        
        //  - create a message handle so that we can cache its content
        ChatSealMessage *psm = [[ChatSealMessage alloc] initWithMessageId:msgId andSealId:sealId];
    
        //  - the message must be pinned in order to get the index-ready entries.
        NSError          *tmp = nil;
        if (sealId && ![psm pinSecureContent:&tmp]) {
            [psm release];
            // - check the seal real quick.  If it is invalid, don't worry about printing an error message
            ChatSealIdentity *ident = [ChatSeal identityForSeal:sealId withError:nil];
            if (ident && !ident.isInvalidated) {
                NSLog(@"CS: Failed to pin the message with id %@ for cache recreation.   %@", msgId, [tmp localizedDescription]);
            }
            continue;
        }
        
        //  - cache the message for later.
        CS_cacheSeal *csTmp  = [CS_cacheSeal sealForId:sealId];
        CS_cacheMessage *msg = [[[CS_cacheMessage alloc] initWithMessage:msgId andSeal:csTmp] autorelease];
        [psm fillCachedMessageItemIfPossible:msg andForceUpdates:NO];
        if (sealId) {
            [msg regenerateIndexWithStringArray:[psm indexReadyEntries]];
        }
        [CS_cacheMessage cacheItem:msg];
        [psm assignCacheItem:msg];              //  save the cache item to avoid a lookup later.
        [maFullMessageList addObject:psm];
        if (sealId) {
            [psm unpinSecureContent];
        }
        [psm release];
    }
    
    // - sort the list of messages
    [maFullMessageList sortUsingComparator:^NSComparisonResult(ChatSealMessage *psm1, ChatSealMessage *psm2){
        return [psm1.creationDate compare:psm2.creationDate];
    }];
    
    // - and save the cache.
    [CS_cacheMessage saveCache];
    return YES;
}

/*
 *  Build a new message list if the current one is not valid.
 */
+(BOOL) buildMessageListIfNotValid:(NSError **) err
{
    @synchronized (maFullMessageList) {
        static BOOL shouldUpdateUnreadCount = YES;
        BOOL agreeWithCache = NO;
        if ([CS_cacheMessage isValidated]) {
            agreeWithCache = YES;
            if (cacheStartup) {
                // - during startup, validate the cache against what is in the message
                //   directory because if they get out of synch because of a crash or something,
                //   we'll have inconsistencies.
                NSDictionary *dMsg = [self validatedOnDiskMessageListWithError:err];
                if (!dMsg || [dMsg count] != [CS_cacheMessage messageCount]) {
                    agreeWithCache = NO;
                }
                cacheStartup = NO;
            }
            
            // - when the cache is valid, make sure that this subsystem matches
            //   its content.
            if (agreeWithCache) {
                if ([maFullMessageList count] != [CS_cacheMessage messageCount]) {
                    [maFullMessageList removeAllObjects];
                    NSArray *arr = [CS_cacheMessage messageItemList];
                    for (CS_cacheMessage *cm in arr) {
                        ChatSealMessage *psm = [[ChatSealMessage alloc] initWithCacheItem:cm];
                        [maFullMessageList addObject:psm];
                        [psm release];
                    }
                }
            }
        }
        
        // - generate the list from scratch because the cache is out of date or non-existent.
        if (!agreeWithCache) {
            if (![ChatSealMessage _buildMessageListWithError:err]) {
                return NO;
            }
            shouldUpdateUnreadCount = YES;
        }
        
        // - when the app first starts or when there is a major change, we'll update the icon badge.
        if (shouldUpdateUnreadCount) {
            shouldUpdateUnreadCount = NO;
            [ChatSealMessage updateApplicationUnreadCount];
        }
    }
    return YES;
}

/*
 *  Fill the message tag with data for caching.
 */
-(void) fillCachedMessageItemIfPossible:(CS_cacheMessage *) cm andForceUpdates:(BOOL) forceUpdates
{
    if (!forceUpdates && cm.dateCreated && cm.synopsis && cm.author) {
        return;
    }
    
    //  - the date created is going to be tracked with the
    //    sid file because after a message's seal is lost
    //    we still want to show the creation date, even without
    //    decryption.  This is the only piece of data that
    //    won't be encrypted because it will help someone
    //    identify the lost message later.  I don't like the idea
    //    of having absolutely no identifying information.
    if (!cm.dateCreated) {
        NSURL *sealIdFile = [ChatSealMessage sealIdFileForMessage:[self messageDirectory]];
        NSDictionary *dict = [[NSFileManager defaultManager] attributesOfItemAtPath:[sealIdFile path] error:nil];
        NSDate *crDate = [dict objectForKey:NSFileCreationDate];
        if (crDate) {
            cm.dateCreated = crDate;
        }
        else {
            cm.dateCreated = [NSDate date];
        }
    }
    
    //  - everything else from this point on requires secure access.
    if (![self pinSecureContent:nil]) {
        return;
    }
    
    //  - the author and synopsis are derived from the content.
    NSInteger numEntries = [self numEntriesWithError:nil];
    if (numEntries > 0) {
        // - author is from the first entry, which is always the seal owner.
        ChatSealMessageEntry *entry = [self entryForIndex:0 withError:nil];
        if (entry) {
            // - the author, but only if I didn't author this message because
            //   otherwise, my seal will show my true identity.
            if (![self isAuthorMe]) {
                // - try to get an author - remember this must be work for recaching after
                //   revocation and for that first experience.  We'll start with the seal.
                NSString *sTmp = nil;
                ChatSealIdentity *ident = [self identityWithError:nil];
                if (ident) {
                    sTmp = [ident ownerName];
                }

                // - this may work out to be nil in the end, but we want to give it the best
                //   chance at succeeding.
                cm.author = sTmp ? sTmp : entry.author;
            }
        }
        
        // - the synopsis from the last one in the sequence.
        entry = [self entryForIndex:(NSUInteger) (numEntries - 1) withError:nil];
        if (entry) {
            if ([entry isItemAnImageAtIndex:0]) {
                cm.synopsis = NSLocalizedString(@"A personal photo.", nil);
            }
            else {
                NSString *sItem = [entry itemAsStringAtIndex:0];
                cm.synopsis     = sItem;
            }
        }
    }

    // - the is-read flag
    _psm_msg_hdr_t *hdr = [self header];
    if (hdr) {
        [cm setIsRead:hdr->flags & PSM_FLAG_ISREAD ? YES : NO];
    }
    
    // - unpin the secure data if we loaded it briefly.
    [self unpinSecureContent];
}

/*
 *  Release all the data in the object.
 */
-(void) releaseAllData
{
    [mid release];
    mid = nil;
    
    [messageDirectory release];
    messageDirectory = nil;
    
    [sid release];
    sid = nil;
    
    [seal release];
    seal = nil;
    
    [cachedMessage release];
    cachedMessage = nil;
    
    [self discardMessageContents];
    
    [currentFilterCriteria release];
    currentFilterCriteria = nil;
    [self discardActiveFilter];
}

/*
 *  Re-save the on-disk archive.
 */
-(BOOL) replaceOnDiskArchiveWithError:(NSError **) err
{
    // - this is a line of defense to ensure that we never update the on-disk content
    //   with an invalid seal since doing so will use the new dummy key and that is particularly
    //   problematic because the open archive might actually be re-saved in a way that we can see it.
    if (!seal || [seal isInvalidatedWithError:nil]) {
        [CS_error fillError:err withCode:CSErrorInvalidSeal];
        return NO;
    }
    
    // - the seal should be OK, let's get started.
    NSDictionary *dictArchive = [NSDictionary dictionaryWithObject:mdMessageContents forKey:PSM_GENERIC_KEY];
    NSData *dArchive          = [seal encryptLocalOnlyMessage:dictArchive withError:err];
    if (dArchive) {
        NSURL *uArchive = [self archiveFile];
        if ([dArchive writeToURL:uArchive atomically:YES]) {
            // - ensure the cache is up to date.
            if (![CS_cacheMessage isValidated]) {
                if (![ChatSealMessage buildMessageListIfNotValid:err]) {
                    return NO;
                }
            }
            
            // - now see if we need to create an entry
            CS_cacheMessage *cm = [CS_cacheMessage messageForId:mid];
            CS_cacheSeal *cs    = [CS_cacheSeal sealForId:seal.sealId];
            if (cs) {
                if (cm) {
                    // - update the is-read indicator since that can change.
                    _psm_msg_hdr_t *hdr = [self header];
                    [cm setIsRead:hdr && (hdr->flags & PSM_FLAG_ISREAD) ? YES : NO];
                }
                else {
                    cm = [[[CS_cacheMessage alloc] initWithMessage:mid andSeal:cs] autorelease];
                    [self fillCachedMessageItemIfPossible:cm andForceUpdates:NO];
                    [CS_cacheMessage cacheItem:cm];
                }
            }
            [cm regenerateIndexWithStringArray:[self indexReadyEntries]];
            [CS_cacheMessage saveCache];
            
            // - saving this item always recreates the filter because that is generally what we want to
            //   do.  The only time this recreation is overridden is when we have a message import scenario.
            [self recreateActiveFilter];
            return YES;
        }
        else {
            [CS_error fillError:err withCode:CSErrorFilesystemAccessError andFailureReason:@"Failed to write message archive."];
        }
    }
    return NO;
}

/*
 *  Append a UTF8 string onto a provided memory buffer.
 */
-(void) appendUTF8String:(const char *) s ontoMemoryBuffer:(NSMutableData *) mdBuffer startingAtPosition:(NSUInteger *) pos
{
    if (!s) {
        return;
    }
    size_t len = strlen(s);
    if (!len) {
        return;
    }
    if (*pos + len + 1 >= [mdBuffer length]) {
        NSLog(@"CS-ALERT: Buffer overflow abort.");
        return;
    }
    
    unsigned char *pBuffer = (unsigned char *) [mdBuffer mutableBytes];
    strncpy((char *) &(pBuffer[*pos]), s, len);
    pBuffer[*pos + len] = ' ';         //  add a trailing space so that the splits work for indexing.
    *pos    += (len + 1);
}

/*
 *  Create an array that represents all the textual entries in this message for generating
 *  an index.
 *  - ASSUMES the cache is pinned.
 */
-(NSArray *) indexReadyEntries
{
    NSMutableSet *sAuthors   = [NSMutableSet set];
    NSMutableSet *sDates     = [NSMutableSet set];
    NSMutableArray *maRet    = [NSMutableArray array];
    NSMutableData *mdContent = [NSMutableData dataWithLength:[mdMessageContents length]];                       // this will never exceed the current length.
    NSUInteger curPos        = 0;
    NSString *sAnonOwner     = [ChatSeal ownerForAnonymousSealForMe:[seal isOwned] withLongForm:YES];
    
    // - ASSUMES the cache is pinned!
    if (!pinCount) {
        return nil;
    }
    
    // - my intent here is to pack the content as tightly as possible
    //   because this routine is called every time a message is updated.
    NSInteger numEntries = [self numEntriesWithError:nil];
    for (NSUInteger i = 0; i < numEntries; i++) {
        ChatSealMessageEntry *me = [self entryForIndex:i withError:nil];
        if (me) {
            // - authors will show up frequently so don't record duplicates
            NSString *author = [me author];
            if (!author) {
                author = sAnonOwner;
            }
            if (author && ![sAuthors containsObject:author]) {
                [sAuthors addObject:author];
                [self appendUTF8String:[author UTF8String] ontoMemoryBuffer:mdContent startingAtPosition:&curPos];
            }
            
            // - the dates should probably be searchable, but we shouldn't abbreviate this week
            //   because that changes constantly and indices are not updated if they aren't modified.
            NSDate *dtCreated = [me creationDate];
            if (dtCreated) {
                NSDateComponents *dc = [[NSCalendar currentCalendar] components:NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit fromDate:dtCreated];
                if (dc) {
                    if (![sDates containsObject:dc]) {
                        [sDates addObject:dc];
                        NSString *sFormatted = [ChatSealMessage formattedMessageEntryDate:dtCreated andAbbreviateThisWeek:NO andExcludeRedundantYear:NO];
                        [maRet addObject:sFormatted];
                    }
                }
            }
            
            uint16_t numItems = (uint16_t) [me numItems];
            for (NSUInteger item = 0; item < numItems; item++) {
                if ([me isItemAnImageAtIndex:item]) {
                    continue;
                }
                
                const char *utf8 = [me UTF8StringItemAtIndex:item];
                if (utf8) {
                    [self appendUTF8String:utf8 ontoMemoryBuffer:mdContent startingAtPosition:&curPos];
                }
            }
        }
    }
    
    // - append the UTF8 memory buffer to the return array
    if (curPos) {
        @try {
            NSString *sString = [NSString stringWithUTF8String:[mdContent bytes]];
            if (sString) {
                [maRet addObject:sString];
            }
            else {
                NSLog(@"CS:  Index entries are NULL in message %@.", mid);
            }
        }
        @catch (NSException *exception) {
            NSLog(@"CS:  Index conversion failure.  %@", [exception description]);
        }
    }
    
    // - and return the collection.
    return maRet;
}

/*
 *  When a new message is created or imported, make sure the 
 *  global list remains sorted.
 *  - assumes the lock is held!
 */
+(void) insertMessageIntoGlobalList:(ChatSealMessage *) psm
{
    // - manually insert the message to avoid a post-insert sort.
    if (psm) {
        BOOL found = NO;
        for (NSUInteger i = 0; i < [maFullMessageList count]; i++) {
            ChatSealMessage *psmCur = [maFullMessageList objectAtIndex:i];
            if ([psmCur.creationDate compare:psm.creationDate] == NSOrderedDescending) {
                [maFullMessageList insertObject:psm atIndex:i];
                found = YES;
                break;
            }
        }
        
        // - it wasn't inserted, so it should go at the end
        if (!found) {
            [maFullMessageList addObject:psm];
        }
    }
    
}

/*
 *  Assign the cache item to the message.
 */
-(void) assignCacheItem:(CS_cacheMessage *) ci
{
    if (cachedMessage != ci) {
        [cachedMessage release];
        cachedMessage = [ci retain];
    }
}

/*
 *  Ensure the cache is inserted into this message.
 */
-(BOOL) loadCacheIfNecessary
{
    if (!cachedMessage) {
        cachedMessage = [[CS_cacheMessage messageForId:mid] retain];
    }
    return (cachedMessage ? YES : NO);
}

/*
 *  Return the offset into the entry buffer.
 */
+(NSUInteger) offsetToEntryBlockForNumberOfEntries:(NSUInteger) numEntries
{
    return sizeof(_psm_msg_hdr_t) + sizeof(_psm_msg_idx_t) + (sizeof(_psm_msg_idx_item_t) * numEntries);
}

/*
 *  Compute the length of the message buffer given the given message entry requirements.
 */
+(NSUInteger) lengthOfMessageBufferWithNumberOfEntries:(NSUInteger) numEntries andEntryBlockLength:(NSUInteger) entryBlockLen
{
    // - the message buffer is organized as:
    //      HEADER      (fixed size/length)
    //      INDEX       (fixed sizes of random length)
    //      ENTRIES     (random sizes and random length)
    return [ChatSealMessage offsetToEntryBlockForNumberOfEntries:numEntries] + entryBlockLen;
}

/*
 *  Return the index of the next link value when assigning
 *  images to a message.
 *  - we'll never roll this particular value back when aborting a message
 *    because it only exists for uniqueness of the link images and can 
 *    have values discarded since we won't likely consume the full allotment.
 */
-(int32_t) nextLinkIndex
{
    _psm_msg_hdr_t *hdr = [self header];
    int32_t ret = -1;
    if (hdr) {
        ret = hdr->linkIndex;
        hdr->linkIndex++;
    }
    return ret;
}

/*
 *  For a given message, convert all its images to secure links and store thier values in the provided array.
 */
-(BOOL) convertToEntryLinks:(ChatSealMessageEntry *) meEntry andSaveInArray:(NSMutableArray *) maConverted withError:(NSError **) err
{
    // - get all the images from the content.
    for (NSUInteger i = 0; i < [meEntry numItems]; i++) {
        if (![meEntry isItemAnImageAtIndex:i]) {
            continue;
        }
        
        // - measure this item for later insertion
        [meEntry measureImageForUIMetricsAtIndex:i];
        
        int32_t nextIndex = [self nextLinkIndex];
        if (nextIndex < 0) {
            [CS_error fillError:err withCode:CSErrorInvalidArgument andFailureReason:@"Failed to generate a good link index."];
            return NO;
        }
        
        if (![meEntry convertToSecureImageAtIndex:i toLink:nextIndex withError:err]) {
            return NO;
        }
        
        [maConverted addObject:[NSNumber numberWithInt:nextIndex]];
    }
    
    // - when an alternate decoy is specified, we need to save it also.
    if (![meEntry saveAlternateDecoyIfPresentWithError:err]) {
        return NO;
    }
    
    return YES;
}

/*
 *  Insert the provided entry at the given index.
 */
-(BOOL) insertEntry:(ChatSealMessageEntry *) meEntry atIndex:(NSUInteger) idx andReturnReallocation:(BOOL *) reallocated withError:(NSError **) err
{
    _psm_msg_idx_t *pIndex = [self index];
    if (!pIndex) {
        [CS_error fillError:err withCode:CSErrorAborted andFailureReason:@"Failed to get index pointer."];
        return NO;
    }
    NSUInteger numEntries   = pIndex->numEntries;
    
    //  - dump the new item as a packed buffer of data, which will be much faster to
    //    archive/unarchive.
    NSData *d = [meEntry convertNewEntryToBuffer];
    if (!d || [d length] == 0) {
        [CS_error fillError:err withCode:CSErrorAborted andFailureReason:@"Failed to convert new entry to buffer."];
        return NO;
    }
    
    // - now resize the backing buffer so that there is enough room for a new index item
    //   and the data we just retrieved.
    *reallocated     = YES;
    NSUInteger lenNewItem  = [d length];
    NSUInteger toAdd       = sizeof(_psm_msg_idx_item_t) + lenNewItem;
    [self setMessageContentsLength:[mdMessageContents length] + toAdd];
    
    //  ... grab reference pointers after resizing because the buffer may have been shifted in memory.
    pIndex                 = [self index];
    unsigned char *pNewEnd = ((unsigned char *) [mdMessageContents mutableBytes] + [mdMessageContents length]);
    unsigned char *pCurEnd = pNewEnd - toAdd;
    
    // - in order to move all the content in this object around, we need to be very careful and will do it
    //   in five separate phases.   Each one is dedicated to one segment of the buffer.
    _psm_msg_idx_item_t *pIndexItems = (_psm_msg_idx_item_t *) (((unsigned char *) pIndex) + sizeof(_psm_msg_idx_t));
    if (!pIndexItems) {
        [CS_error fillError:err withCode:CSErrorAborted andFailureReason:@"Unexpected invalid index pointer."];
        return NO;
    }
    
    // -- PHASE 1:  move the entries after the insertion point.
    NSUInteger offset              = 0;
    unsigned char *pFirst          = NULL;
    unsigned char *pLast           = NULL;
    unsigned char *pNewEntryTarget = NULL;
    NSUInteger toMove     = 0;
    if (idx < numEntries) {
        offset          = pIndexItems[idx];
        pFirst          = (((unsigned char *) [mdMessageContents mutableBytes]) + offset);
        pNewEntryTarget = pFirst + sizeof(_psm_msg_idx_item_t);
        toMove          = (NSUInteger) (pCurEnd - pFirst);
        if (pNewEntryTarget + lenNewItem + toMove != pNewEnd) {         // the old item(s) must be moved up against the end or there is a problem.
            NSLog(@"CS-ALERT:  Phase 1 message capacity failure.");
        }
        memcpy(pNewEntryTarget + lenNewItem, pFirst, toMove);           // move the distance of the new item plus the index entry it will occupy.
    }
    
    // -- PHASE 2:  move the entries before the insertion point.
    if (idx > 0) {
        offset = pIndexItems[0];
        pFirst = (((unsigned char *) [mdMessageContents mutableBytes]) + offset);
        if (idx < numEntries) {
            offset = pIndexItems[idx];
            pLast  = (((unsigned char *) [mdMessageContents mutableBytes]) + offset);
        }
        else {
            pLast = pCurEnd;
        }
        toMove = (NSUInteger) (pLast - pFirst);
        memcpy(pFirst + sizeof(_psm_msg_idx_item_t), pFirst, toMove);                       // move by the distance of the index entry the new item occupies
    }
    
    // -- PHASE 3:  move/adjust the index entries after the insertion point
    if (idx < numEntries) {
        pFirst = (((unsigned char *) pIndexItems) + (sizeof(_psm_msg_idx_item_t) * idx));
        pLast  = (((unsigned char *) pIndexItems) + (sizeof(_psm_msg_idx_item_t) * numEntries));
        toMove = (NSUInteger) (pLast - pFirst);
        memcpy(pFirst + sizeof(_psm_msg_idx_item_t), pFirst, toMove);
    }
    for (NSUInteger i = idx + 1; i < numEntries + 1; i++) {
        pIndexItems[i] += toAdd;
    }
    
    // -- PHASE 4:  adjust the index entries before the insertion point.
    for (NSUInteger i = 0; i < idx; i++) {
        pIndexItems[i] += sizeof(_psm_msg_idx_item_t);
    }
    
    // -- PHASE 5:  store the new item and increment the total message count.
    if (!pNewEntryTarget) {
        pNewEntryTarget = pCurEnd + sizeof(_psm_msg_idx_item_t);
    }
    memcpy(pNewEntryTarget, [d bytes], lenNewItem);
    pIndexItems[idx] = (_psm_msg_idx_item_t) (pNewEntryTarget - (unsigned char *) [mdMessageContents bytes]);
    pIndex->numEntries++;

    return YES;
}

/*
 *  Locate the given entry and delete it.
 */
-(BOOL) findAndDeleteEntry:(ChatSealMessageEntry *) meEntry withError:(NSError **)err
{
    //  - this routine is very rarely used in the real app and only in the case of a serious
    //    error, so a more brute-force approach for finding the entry is allowed here.
    NSUUID *eid = [meEntry entryUUID];
    if (!eid) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        return NO;
    }
    
    _psm_msg_idx_t *index = [self index];
    if (!index) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        return NO;
    }
    
    // - first figure out if the entry exists.
    NSUInteger numEntries           = index->numEntries;
    NSInteger  entryFound           = -1;
    _psm_msg_idx_item_t *indexItems = (_psm_msg_idx_item_t *) (((unsigned char *) index) + sizeof(_psm_msg_idx_t));
    for (NSInteger i = 0; i < numEntries; i++) {
        unsigned char *ptr = ((unsigned char *) [mdMessageContents mutableBytes]) + indexItems[i];
        NSUUID *tmpUUID = [ChatSealMessageEntry entryIdForData:ptr];
        if (!tmpUUID) {
            [CS_error fillError:err withCode:CSErrorInvalidArgument];
            return NO;
        }
        if ([eid isEqual:tmpUUID]) {
            entryFound = i;
            break;
        }
    }
    
    // - the entry doesn't exist.
    if (entryFound == -1) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        return NO;
    }
    
    // - the entry exists, so start by figuring out precisely where it is.
    unsigned char *pEndOfBuffer  = ((unsigned char *) [mdMessageContents mutableBytes]) + [mdMessageContents length];
    unsigned char *pBeginOfEntry = ((unsigned char *) [mdMessageContents mutableBytes]) + indexItems[entryFound];
    unsigned char *pEndOfEntry   = pEndOfBuffer;
    if (entryFound + 1 < numEntries) {
        pEndOfEntry = ((unsigned char *) [mdMessageContents mutableBytes]) + indexItems[entryFound + 1];
    }
    NSUInteger lenEntry = (NSUInteger) (pEndOfEntry - pBeginOfEntry);
    
    // - now we're going to do this in phases to be sure it is correct.
    // -- PHASE 1: Compress the entry list.
    NSUInteger toMove = 0;
    if (pEndOfEntry < pEndOfBuffer) {
        toMove = (NSUInteger) (pEndOfBuffer - pEndOfEntry);
        if (pBeginOfEntry + toMove > pEndOfBuffer) {
            NSLog(@"CS-ALERT:  Message buffer overflow.");
        }
        memmove(pBeginOfEntry, pEndOfEntry, pEndOfBuffer - pEndOfEntry);
        pEndOfBuffer -= lenEntry;
    }
    
    // -- PHASE 2: Compress the index and adjust the number of entries.
    unsigned char *pIdxBefore = (unsigned char *) &(indexItems[entryFound]);
    unsigned char *pIdxAfter  = (unsigned char *) &(indexItems[entryFound+1]);
    toMove = (NSUInteger) (pEndOfBuffer - pIdxAfter);
    if (pIdxBefore + toMove > pEndOfBuffer) {
        NSLog(@"CS-ALERT:  Message buffer overflow.");
    }
    memmove(pIdxBefore, pIdxAfter, pEndOfBuffer - pIdxAfter);
    index->numEntries--;
    numEntries--;
    
    // -- PHASE 3: Adjust all the index entries.
    for (NSUInteger i = 0; i < numEntries; i++) {
        if (i < entryFound) {
            // - items before only need to be adjusted by the size of an index entry.
            indexItems[i] -= sizeof(_psm_msg_idx_item_t);
        }
        else {
            // - items after need to be adjusted by the size of an index entry and the
            //   content we deleted.
            indexItems[i] -= (sizeof(_psm_msg_idx_item_t) + lenEntry);
        }
    }
    
    // -- PHASE 4: Compress the entire buffer and discard the entry accounting.
    NSUInteger newLen = (NSUInteger) (pEndOfBuffer - (unsigned char *) [mdMessageContents mutableBytes]);
    if (newLen > [mdMessageContents length]) {
        NSLog(@"CS-ALERT:  Message buffer overflow.");
    }
    [self setMessageContentsLength:newLen];
    [meEntry clearEntry];
        
    return YES;
}

/*
 *  This is the general-purpose add entry routine.
 *  - the decoy will be associated with the on-disk version.
 */
-(ChatSealMessageEntry *) addEntryOfType:(ps_message_type_t) msgType withId:(NSUUID *) entryId andContents:(NSArray *) msgData onCreationDate:(NSDate *) dtCreated
                               withAuthor:(NSString *) author andParentId:(NSUUID *) uuidParent andError:(NSError **) err
{
    NSError *tmp               = nil;
    ChatSealMessageEntry *ret = nil;
    
    // - ensure that the secure state is in order
    if (![self pinSecureContent:err]) {
        return nil;
    }
    
    // - don't keep secure content laying around long.
    @autoreleasepool {
        NSURL *decoyFile  = [ChatSealMessage decoyFileForMessageDirectory:[self messageDirectory]];
        UIImage *imgDecoy = [ChatSealMessageEntry loadSecureImage:decoyFile withSeal:seal andError:err];
        if (imgDecoy) {
            ret = [[self addEntryOfType:msgType withId:entryId andContents:msgData andDecoy:imgDecoy andDecoyIsCommon:YES onCreationDate:dtCreated withAuthor:author
                            andParentId:uuidParent andError:&tmp] retain];
        }
        [tmp retain];
    }
    
    [tmp autorelease];
    if (err) {
        *err = tmp;
    }
    
    [self unpinSecureContent];
    return [ret autorelease];
}

/*
 *  This is the general-purpose add entry routine.   
 *  - if the decoy is not common, a copy will be made of it, so be conscious of that fact.
 */
-(ChatSealMessageEntry *) addEntryOfType:(ps_message_type_t) msgType withId:(NSUUID *) entryId andContents:(NSArray *) msgData andDecoy:(UIImage *) decoy
                         andDecoyIsCommon:(BOOL) commonDecoy onCreationDate:(NSDate *) dtCreated withAuthor:(NSString *) author andParentId:(NSUUID *) uuidParent
                                 andError:(NSError **) err;
{
    if (!msgData) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        return nil;
    }
    
    if (![self pinSecureContent:err]) {
        return nil;
    }
    
    BOOL isImport = NO;
    if (msgType & PSMT_IMPORT_FLAG) {
        isImport = YES;
        msgType = (ps_message_type_t)((NSUInteger) msgType & ~(NSUInteger)PSMT_IMPORT_FLAG);
    }
    
    // - prevent revocation by consumers in all cases, which should never happen
    //   but I need to ensure that an honest UI bug never creates a disaster.
    if (msgType == PSMT_REVOKE) {
        if (![seal isOwned]) {
            [CS_error fillError:err withCode:CSErrorInvalidSeal];
            [self unpinSecureContent];
            return nil;
        }
    }
    
    // - first build a writeable message entry structure.
    ChatSealMessageEntry *meRet = [[[ChatSealMessageEntry alloc] initWithMessage:mid inDirectory:[self messageDirectory] andSeal:seal andData:NULL usingLock:editionLock] autorelease];
    [meRet setMessageId:mid];
    [meRet setItems:msgData];
    if (!author) {
        if ([seal isOwned]) {
            if (isImport) {
                // - a consumer response should generate an anonymous author when it is not provided.
                author = [ChatSeal ownerForAnonymousSealForMe:NO withLongForm:NO];
            }
            else {
                author = [ChatSeal ownerNameForSeal:seal.sealId];
            }
        }
        else {
            if (isImport) {
                author = [ChatSeal ownerForAnonymousSealForMe:NO withLongForm:YES];
            }
            else {
                author = [ChatSeal ownerForActiveSeal];
            }
        }
    }
    [meRet setAuthor:author];
    [meRet setCreationDate:dtCreated ? dtCreated : [NSDate date]];
    [meRet setEntryId:entryId ? entryId : [NSUUID UUID]];
    if (msgType == PSMT_REVOKE) {
        [meRet markForSealRevocation];
    }
    //  ...assign the is-read markers as appropriate.
    _psm_msg_idx_t *idx = [self index];
    if (idx && idx->numEntries == 0 && [seal isOwned]) {
        // - this is the first entry, which means we can mark it as read.
        [self setIsReadWithoutSave:YES];
    }
    else if (isImport) {
        // - all imports reset the is-read indicator.
        [self setIsReadWithoutSave:NO];
    }
    if (!isImport) {
        [meRet setIsRead:YES];
    }
    
    if (![(RSISecureSeal *) seal isOwned] && !uuidParent && !isImport) {
        //  - search for the last message that had no parent, which would
        //    have been created by the owner and use that as a response
        //    parent
        //  - this is so a response can be inserted after the owner's
        //    message entry.
        NSInteger numEntries = (NSInteger) idx->numEntries;
        for (NSInteger i = numEntries - 1; i >= 0; i--) {
            ChatSealMessageEntry *me = [self entryForIndex:(NSUInteger) i andAllowFilter:NO withError:nil];
            if ([me isOwnerEntry]) {
                if ((uuidParent = [me entryUUID]) != nil) {
                    break;
                }
            }
        }
        
        //  - all responses from seal consumers must have a parent
        //    UUID.
        if (!uuidParent) {
            [CS_error fillError:err withCode:CSErrorArchivalError andFailureReason:@"Consumer response is missing a producer message."];
            [self unpinSecureContent];
            return nil;
        }
    }
    [meRet setParentId:uuidParent];
    
    // - when the decoy is non-common, that is, not the one specified by the seal owner initially, we'll need
    //   to retain a copy of the new one in order to be sure to get it for later packing.
    if (!commonDecoy) {
        [meRet setAlternateDecoy:decoy];
    }
    
    // - finally, store it in the archive
    if (![self appendEntryToArchive:meRet withError:err]) {
        meRet = nil;
    }
    
    // - the final step is to ensure the newly created entry's edition matches the one
    //   in the message right now.
    [meRet assignCreationEditionFromLock];
    
    [self unpinSecureContent];
    return meRet;
}

/*
 *  Discard the current message filter.
 */
-(void) discardActiveFilter
{
    [mdFilteredIndices release];
    mdFilteredIndices  = nil;
    numFilteredEntries = 0;
    isImportFiltered   = NO;
    
    // - the new item set is based on the active filter and
    //   it doesn't make sense to retain it when the filter is discarded.
    [isNewItemSet release];
    isNewItemSet = nil;
}

/*
 *  Determine if *any* of the given items in the search array matches the text.
 *  - NOTE: we must effectively do an OR operation here in order to support a transition
 *          from the index-based search to a full text search.  The index search operates
 *          like an AND, where it filters out any messages that do not match precisely, but
 *          those matches occur over all the entries.  In here, we're looking at one entry at
 *          a time, which means that an entry may only have part of the search criteria.   We do
 *          not want a scenario where a search string is applied in the overview with 3 words, they match
 *          and the message detail shows no results because two words are in one entry and 1 word is in another.
 */
-(BOOL) searchArray:(NSArray *) arrToMatch matchesText:(NSString *) text
{
    if (!text) {
        return NO;
    }
    
    // - by doing the string check in this way, I am intentionally allowing a more
    //   granular search (that-is, substring matching) in the message detail screen
    //   that is not possible with the secure index.   The value of granular search is too great to dumb this down
    //   just for the sake of consistency.   Generally speaking, I don't expect it to be
    //   an issue (the inconsistency) as a rule.   When you're looking at detail, you are going
    //   to want to weed things out more interactively, which this will support.
    for (NSString *s in arrToMatch) {
        @try {
            NSRange r = [text rangeOfString:s options:NSCaseInsensitiveSearch];
            if (r.location != NSNotFound) {
                return YES;
            }
        }
        @catch (NSException *exception) {
            //  do nothing, just catch it.
        }
    }
    return NO;
}

/*
 *  Create a message filter index, which is a simple list of all the entries
 *  that match the current criteria.
 */
-(void) createActiveFilter
{
    if (mdFilteredIndices) {
        [self discardActiveFilter];
    }
    
    // - the active only makes sense for a pinned message, but even then
    //   it requires some text or we assume the entire message is matched.
    if (!pinCount || !currentFilterCriteria || [currentFilterCriteria length] == 0) {
        return;
    }
    
    // ... create the search array from the criteria using the same type of string
    //     splitting we used to index in the first place.
    // ... use the less precise splitting approach here so that special characters are retained and we just split on whitespace
    //     boundaries.
    NSArray *arrToMatch = [CS_messageIndex standardStringSplitWithWhitespace:currentFilterCriteria andAlphaNumOnly:NO];
    if (!arrToMatch || [arrToMatch count] == 0) {
        return;
    }
    
    // - the filter is a buffer of _psm_msg_idx_item_t values that act as
    //   indirection into the official list.
    if (![self pinSecureContent:nil]) {
        return;
    }

    // - NOTE:  we can safely access the external APIs as long as the filter
    //          buffer remains discarded, otherwise it will return intermediate state
    NSInteger numEntries = [self numEntriesWithError:nil];
    if (numEntries < 1) {
        [self unpinSecureContent];
        return;
    }
    
    // - save off a dictionary of computed dates to minimize the cost.
    NSMutableDictionary *mdComputedDates = [NSMutableDictionary dictionary];
    NSUInteger curNewFilterItem          = 0;
    NSUInteger lenNewFilterBuffer        = 0;
    _psm_msg_idx_item_t  *filterItems    = NULL;
    NSMutableData        *mdNewFilterBuf = [NSMutableData data];
    NSString *sAnon                      = nil;
    NSString *sAnonOwner                 = nil;
    NSMutableIndexSet *misTmpNewItems    = nil;
    
    // - this process is straightforward.  we must move through each entry and
    //   identify whether it matches the given search criteria.
    for (NSUInteger entry = 0; entry < numEntries; entry++) {
        ChatSealMessageEntry *me = [self entryForIndex:entry withError:nil];
        if (!me) {
            [self unpinSecureContent];
            return;
        }
        
        //  - we need to test whether the different elements here
        //    match.  If any do, then this is a suitable filter candidate.
        //  - try to do this efficiently!
        BOOL matched     = NO;
        NSString *author = [me author];
        if (!author) {
            // - for each of these scenarios, we're only going to check them once since the
            //   anonymous text doesn't change.
            if ([me isOwnerEntry]) {
                if (!sAnonOwner) {
                    sAnonOwner = [ChatSeal ownerForAnonymousSealForMe:YES withLongForm:NO];
                }
                author = sAnonOwner;
            }
            else {
                if (!sAnon) {
                    sAnon  = [ChatSeal ownerForAnonymousSealForMe:NO withLongForm:NO];
                }
                author = sAnon;
            }
        }
        if (author && [self searchArray:arrToMatch matchesText:author]) {
            matched = YES;
        }
        else {
            for (NSUInteger item = 0; item < [me numItems]; item++) {
                NSString *text = [me itemAsStringAtIndex:item];
                if (!text) {
                    continue;
                }
                if ([self searchArray:arrToMatch matchesText:text]) {
                    matched = YES;
                    break;
                }
            }
        }
        
        // ...search the date/time last and only when absolutely necessary because it is most expensive to do so.
        if (!matched) {
            NSDate *date    = [me creationDate];
            NSString *sTime = [ChatSealMessageEntry standardDisplayFormattedTimeForDate:date];
            if ([self searchArray:arrToMatch matchesText:sTime]) {
                matched = YES;
            }
            
            // - the date string requires a lot of computation to create.
            if (!matched) {
                NSDateComponents *dc         = [[NSCalendar currentCalendar] components:NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit fromDate:date];
                NSString         *dateString = [mdComputedDates objectForKey:dc];
                if (!dateString) {
                    NSAttributedString *as = [ChatSealMessageEntry standardDisplayDetailsForAuthorSuffix:@"" withAuthorColor:[UIColor blackColor] andBoldFont:nil onDate:date withTimeString:@"" andTimeFont:nil];
                    dateString = [as string];
                    [mdComputedDates setObject:dateString ? dateString : @"" forKey:dc];
                }
                if ([self searchArray:arrToMatch matchesText:dateString]) {
                    matched = YES;
                }
            }
        }
        
        // - if this entry matched, add it to the filter.
        if (matched) {
            //  ... reallocate the buffer if necessary.
            if (curNewFilterItem >= lenNewFilterBuffer) {
                lenNewFilterBuffer   += 32;     //  space for N elements
                NSUInteger newByteLen = lenNewFilterBuffer * sizeof(_psm_msg_idx_item_t);
                [mdNewFilterBuf setLength:newByteLen];
                filterItems           = (_psm_msg_idx_item_t *) [mdNewFilterBuf mutableBytes];
            }
            
            // - now set the index.
            filterItems[curNewFilterItem] = (_psm_msg_idx_item_t) entry;
            
            // - and see if it is new
            if (![me isRead]) {
                if (!misTmpNewItems) {
                    misTmpNewItems = [NSMutableIndexSet indexSet];
                }
                [misTmpNewItems addIndex:curNewFilterItem];
            }
            
            curNewFilterItem++;
        }
    }
    
    // - save off the new filter buffer.
    isNewItemSet       = [misTmpNewItems retain];
    mdFilteredIndices  = [mdNewFilterBuf retain];
    numFilteredEntries = curNewFilterItem;
    
    [self unpinSecureContent];
}

/*
 *  Regenerate the filter based on the current message contents.
 */
-(void) recreateActiveFilter
{
    [self discardActiveFilter];
    [self createActiveFilter];
}

/*
 *  Recache a single message and return whether we need to resave.
 *  - Although this is INTERNAL, we must include locking because this is
 *    called from one of our static methods.
 */
-(BOOL) recacheMessageForSeal:(RSISecureSeal *) ss
{
    BOOL ret = NO;
    [editionLock lock];
    
    if ([self isSealValidForMessage:ss andRebuildIndex:YES]) {
        CS_cacheMessage *cm = [CS_cacheMessage messageForId:mid];
        [self fillCachedMessageItemIfPossible:cm andForceUpdates:YES];
        ret = YES;
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Check if the provided seal is sufficient to decode this message.
 *  - when a message can be opened with a given seal, we may also want to optionally
 *    rebuild its index as well.
 */
-(BOOL) isSealValidForMessage:(RSISecureSeal *) ss andRebuildIndex:(BOOL) rebuildIdx
{
    if (![self loadCacheIfNecessary]) {
        return NO;
    }
    
    // - when there is a seal already associated with the message, we're fine, otherwise
    //   we need to check.
    if (cachedMessage.seal && sid) {
        if ([cachedMessage.seal.sealId isEqualToString:ss.sealId]) {
            if (rebuildIdx) {
                if ([self pinSecureContent:nil]) {
                    [self replaceOnDiskArchiveWithError:nil];
                    [self unpinSecureContent];
                }
            }
            return YES;
        }
        else {
            return NO;
        }
    }
    else {
        // - no seal, so we're going to determine if the provided seal can open it.
        // - this only happens if the identity was destroyed that was associated with the
        //   message, which means we know the identity has no record of the message's contents.
        @synchronized (maFullMessageList) {
            BOOL isValid      = NO;
            sid               = [ss.sealId retain];          //  to try it on for size
            CS_cacheSeal *cs = [CS_cacheSeal sealForId:ss.sealId];
            if (cs && [self pinSecureContent:nil]) {
                // - the ability to pin the message is proof it is ok.
                isValid            = YES;
                cachedMessage.seal = cs;
                [CS_cacheMessage saveCache];
                
                //  - now we're going to count the items in the message to update our identity.
                BOOL isOwned           = [ss isOwned];
                NSInteger numItems     = [self numEntriesWithError:nil];
                NSUInteger numSent     = 0;
                NSUInteger numRecv     = 0;
                for (NSInteger i = 0; isValid && i < numItems; i++) {
                    ChatSealMessageEntry *me = [self entryForIndex:(NSUInteger) i withError:nil];
                    if (me) {
                        if ([me isOwnerEntry] == isOwned) {
                            numSent++;
                        }
                        else {
                            numRecv++;
                        }
                    }
                }
                
                // - ensure the index is rebuilt.
                [self replaceOnDiskArchiveWithError:nil];
                
                // - and release the pin.
                [self unpinSecureContent];
                
                // - add onto the existing identity to track the items associated with this seal.
                if (numSent || numRecv) {
                    ChatSealIdentity *psi = [ChatSealIdentity identityForSealId:ss.sealId withError:nil];
                    if (numSent) {
                        [psi addToSentCount:numSent];
                    }
                    if (numRecv) {
                        [psi addToRecvCount:numRecv];
                    }
                }
            }
            else {
                // - if we couldn't pin the message, this seal id isn't valid for this message.
                [sid release];
                sid = nil;
            }
            return isValid;
        }
    }
    return NO;
}

/*
 *  Assign the author to the message.
 */
-(void) setAuthor:(NSString *) author
{
    if (![self loadCacheIfNecessary]) {
        return;
    }
    cachedMessage.author = author;
    [CS_cacheMessage saveCache];
}

/*
 *  Import the data in the entry dictionary into the message, which assumes that the validation
 *  has already occurred.
 *  - Although this is INTERNAL, we must supply locking because it is called from a static method.
 */
-(BOOL) importEntryIntoMessage:(NSDictionary *) dEntry asType:(ps_message_type_t) mtype withError:(NSError **) err
{
    BOOL ret = YES;
    [editionLock lock];
    
    NSUUID *entryId       = [dEntry objectForKey:PSM_ENTRYID_KEY];
    NSUUID *parentId      = [dEntry objectForKey:PSM_PARENT_KEY];
    NSString *author      = [dEntry objectForKey:PSM_OWNER_KEY];
    NSDate *dtCreated     = [dEntry objectForKey:PSM_CRDATE_KEY];
    NSArray *arrItems     = [dEntry objectForKey:PSM_MSGITEMS_KEY];
    
    
    if ([self pinSecureContent:err]) {
        NSInteger numEntries = [self numEntriesWithError:err];
        if (numEntries == -1) {
            ret = NO;
        }
        
        // ...check if the entry exists.
        if (ret) {
            for (NSUInteger i = 0; i < numEntries; i++) {
                ChatSealMessageEntry *pme = [self entryForIndex:i withError:err];
                if (!pme) {
                    // - this should not happen, but if it did we should not continue down this path.
                    NSLog(@"CS: The message %@ has an invalid entry that is preventing further additions.", mid);
                    ret = NO;
                    break;
                }
                if ([pme.entryUUID isEqual:entryId]) {
                    // - it is already here, so don't re-insert it.
                    [CS_error fillError:err withCode:CSErrorMessageExists];
                    ret = NO;
                    break;
                }
            }
        }
        
        // ...it looks like the message is new so we can append it (make sure we mark it as not read).
        if (ret) {
            ChatSealMessageEntry *meRet = nil;
            
            // - temporarily save off the filter so that it isn't recreated by the addEntry method below, which is useful
            //   any time except when we're importing.
            // - importing needs to keep the result set unmodified from the UI perspective
            NSString *sTmpFilterCriteria     = currentFilterCriteria;
            currentFilterCriteria            = nil;
            NSUInteger tmpNumFilteredEntries = numFilteredEntries;
            numFilteredEntries               = 0;
            NSMutableData *mdTmpFiltered     = mdFilteredIndices;
            mdFilteredIndices                = nil;
            BOOL tmpIsImportFiltered         = isImportFiltered;
            isImportFiltered                 = NO;
            
            // - try to add the entry.
            if ((meRet =[self addEntryOfType:mtype | PSMT_IMPORT_FLAG withId:entryId andContents:arrItems onCreationDate:dtCreated withAuthor:author
                                 andParentId:parentId andError:err])) {
                // - if this is a new last entry and it is from the seal owner, we want to update the author on the cached message.
                if (![self isAuthorMe]) {
                    ChatSealMessageEntry *me = [self entryForIndex:(NSUInteger) numEntries withError:nil];
                    if (me && [[me entryUUID] isEqual:entryId] && [me isOwnerEntry]) {
                        [self setAuthor:me.author];
                    }
                }
            }
            else {
                ret = NO;
            }
            
            // - replace the filter to what it was.
            [self discardActiveFilter];                 //  this should never really be necessary, but added for completeness.
            currentFilterCriteria = sTmpFilterCriteria;
            numFilteredEntries    = tmpNumFilteredEntries;
            mdFilteredIndices     = mdTmpFiltered;
            isImportFiltered      = tmpIsImportFiltered;
            
            // - also, make sure that the filter is updated
            if (isBeingDisplayed) {
                [self buildPostImportFilterUsingEntry:meRet];
            }
        }
        
        // ...unpin in one location only to ensure it happens.
        [self unpinSecureContent];
    }
    else {
        ret = NO;
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  When we import messages, it is possible that someone is actively looking at the message when that happens and any 
 *  scrolling could get severely screwed up if the message just instantly changed with new indices.   It gets even
 *  more crazy when we're indirecting off of filtered indices.   The way we avoid problems is to use that filtered 
 *  index array as a buffer during that import.  When an import occurs, we need to reapply the filter externally in order to see
 *  new content.
 *  - ASSUMES the lock is held.
 */
-(void) buildPostImportFilterUsingEntry:(ChatSealMessageEntry *) me
{
    // - the goal, whether there is an active filter or not, is to keep the returned content exactly the same
    //   after this method returns.  It is not to include a possible new filtered item in an active filter because
    //   that generates the same kind of inconsistencies as showing a new item with no filter.
    NSUInteger curFilterCount  = numFilteredEntries;
    NSMutableData *mdTmpFilter = nil;
    if (mdFilteredIndices) {
        mdTmpFilter = [NSMutableData dataWithData:mdFilteredIndices];
    }
    
    NSMutableData *mdNewFilter   = nil;
    NSUInteger    newFilterCount = 0;
    
    // - discard the active filter so all our entry analysis APIs work on the
    //   direct buffer.
    [self discardActiveFilter];
    
    NSError *tmp         = nil;
    NSInteger numEntries = [self numEntriesWithError:&tmp];
    if (numEntries == -1) {
        NSLog(@"CS-ALERT: Unexpected failure to get message stats during post import refilter.  %@", [tmp localizedDescription]);
        return;
    }
    
    // - figure out if we're adjusting an old filter or creating a new one.
    _psm_msg_idx_item_t *pFilterItem = NULL;
    if (mdTmpFilter) {
        // - adjusting the old filter means that we need to just renumber indices.
        // ...first find where it ended up.
        for (NSUInteger i = 0; i < numEntries; i++) {
            ChatSealMessageEntry *meToFilter = [self entryForIndex:i withError:&tmp];
            if (!meToFilter) {
                NSLog(@"CS-ALERT: Unexpected failure to get an item during post import refilter.  %@", [tmp localizedDescription]);
                return;
            }
            
            // - find the index of the new item because everything after it
            //   need to be updated.
            if (![meToFilter.entryUUID isEqual:me.entryUUID]) {
                continue;
            }
            
            // - increment every item that comes after the one we just inserted
            pFilterItem = (_psm_msg_idx_item_t *) [mdTmpFilter mutableBytes];
            for (NSUInteger j = 0; j < curFilterCount; j++) {
                if (pFilterItem[j] >= (_psm_msg_idx_item_t) i) {
                    pFilterItem[j]++;
                }
            }
            
            // - that was all we needed.
            break;
        }
        
        // - use the same buffer we just copied
        mdNewFilter    = mdTmpFilter;
        newFilterCount = curFilterCount;
    }
    else {
        // - creating a new one that has everything except the item.
        newFilterCount = (NSUInteger) numEntries - 1;
        mdNewFilter    = [NSMutableData dataWithLength:(newFilterCount * sizeof(_psm_msg_idx_item_t))];
        pFilterItem    = (_psm_msg_idx_item_t *) [mdNewFilter mutableBytes];
        for (NSUInteger i = 0; i < numEntries; i++) {
            ChatSealMessageEntry *meToFilter = [self entryForIndex:i withError:&tmp];
            if (!meToFilter) {
                NSLog(@"CS-ALERT: Unexpected failure to get an item during post import refilter.  %@", [tmp localizedDescription]);
                return;
            }
            
            // - if this isn't the item, it can go into our new index.
            if (![me.entryUUID isEqual:meToFilter.entryUUID]) {
                *pFilterItem = (_psm_msg_idx_item_t) i;
                pFilterItem++;
            }
        }
    }
    
    // - last thing is to update the active filter so that all consumers get that information.
    mdFilteredIndices  = [mdNewFilter retain];
    numFilteredEntries = newFilterCount;
    isImportFiltered   = YES;
}

/*
 *  Retrieve a specific entry from the message.
 *  - but, this allows us to control whether the filter is applied because it could hose up calculations elsewhere.
 */
-(ChatSealMessageEntry *) entryForIndex:(NSUInteger) idx andAllowFilter:(BOOL) allowFilter withError:(NSError **) err
{
    ChatSealMessageEntry *meRet = nil;
    BOOL ret                     = YES;
    
    [editionLock lock];
    
    // - because the entry is indirected off of the secure content, we need
    //   to make sure the message is pinned in order to have access to its content, because
    //   otherwise, the buffer may disappear before the content is accessed.
    if (!pinCount) {
        [CS_error fillError:err withCode:CSErrorInvalidSecureRequest andFailureReason:@"The message is not pinned."];
        ret = NO;
    }
    
    // - when there is a filter, we're going to need to indirect off of its contents.
    if (allowFilter && ret && mdFilteredIndices) {
        if (idx < numFilteredEntries) {
            _psm_msg_idx_item_t *filterEntries = (_psm_msg_idx_item_t *) [mdFilteredIndices mutableBytes];
            idx = filterEntries[idx];
        }
        else {
            [CS_error fillError:err withCode:CSErrorInvalidArgument];
            ret = NO;
        }
    }
    
    // - retrieve the entry.
    _psm_msg_idx_t *pIndex = [self index];
    if (ret && idx < pIndex->numEntries) {
        NSUInteger offset = sizeof(_psm_msg_hdr_t) + sizeof(_psm_msg_idx_t);
        if (offset + (sizeof(_psm_msg_idx_item_t) * (idx + 1)) <= [mdMessageContents length]) {
            _psm_msg_idx_item_t *entryIndex = (_psm_msg_idx_item_t *) (((unsigned char *) [mdMessageContents mutableBytes]) + offset);
            unsigned char *pElement = ((unsigned char *) [mdMessageContents mutableBytes]) + entryIndex[idx];
            if (pElement < ((unsigned char *) [mdMessageContents mutableBytes]) + [mdMessageContents length]) {
                meRet = [[[ChatSealMessageEntry alloc] initWithMessage:mid inDirectory:[self messageDirectory] andSeal:seal andData:pElement usingLock:editionLock] autorelease];
                [meRet assignCreationEditionFromLock];
            }
            else {
                NSLog(@"CS-ALERT:  Bad element index pointer.");
            }
        }
        
        // - when we couldn't find anything just forget about it.
        if (!meRet) {
            [CS_error fillError:err withCode:CSErrorInvalidArgument];
        }
    }
    
    [editionLock unlock];
    return meRet;
}

/*
 *  Using the full message list, determine the count of items that are unread and
 *  apply them to the application badge.
 *  - I'm intentionally only showing the number of _messages_ with unread items as
 *    opposed to all the items because I don't want to overburden the person.  A high
 *    count may end up feeling like work as opposed to just knowing that there is something
 *    new.
 */
+(void) updateApplicationUnreadCount
{
    NSInteger count = 0;
    @synchronized (maFullMessageList) {
        for (ChatSealMessage *psm in maFullMessageList) {
            if (![psm isRead]) {
                count++;
            }
        }
    }
    
    // - update this on the main thread just to be sure.
    [ChatSeal setApplicationBadgeToValue:count];
}

@end

/*****************************
 CS_messageEdition
 NOTE: - this is provided to deal with the very
         important detail of message consistency with
         entry objects that might exist outside the bounds
         of the owning message.
 *****************************/
@implementation CS_messageEdition
/*
 *  Object attributes.
 */
{
    NSRecursiveLock *rLock;
    int32_t         edition;
    int32_t         numLocks;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        // - the entry is often going to use this in a message codepath,
        //   so we need a recursive lock here.
        rLock    = [[NSRecursiveLock alloc] init];
        edition  = 0;
        
        // - I'm counting these informally so that I can do spot checks after the unit test to
        //   ensure that no locks are outstanding.
        numLocks = 0;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [rLock release];
    rLock = nil;
    
    [super dealloc];
}

/*
 *  Lock the object.
 */
-(void) lock
{
    OSAtomicIncrement32(&numLocks);
    [rLock lock];
}

/*
 *  Unlock the object.
 */
-(void) unlock
{
    OSAtomicDecrement32(&numLocks);
    [rLock unlock];
}

/*
 *  Atomically increment the edition.
 */
-(void) incrementEdition
{
    OSAtomicIncrement32(&edition);
}

/*
 *  Return the value of the current edition.
 */
-(NSInteger) currentEdition
{
    return (NSInteger) OSAtomicAdd32(0, &edition);
}

/*
 *  Does a quick check to compare the provided edition to this object's edition.
 */
-(BOOL) isEqualToEdition:(NSInteger) cmpEdition
{
    if (cmpEdition == [self currentEdition]) {
        return YES;
    }
    return NO;
}
@end
