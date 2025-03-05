//
//  CS_postedMessage.m
//  ChatSeal
//
//  Created by Francis Grolemund on 5/12/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_postedMessage.h"
#import "ChatSeal.h"

//  THREADING-NOTES:
//  - this object requires no locking since it is readonly after creation.

// - constants
static NSString *CS_PM_KEY_SAFEENTRY = @"safeEntryId";
static NSString *CS_PM_KEY_ENTRY     = @"entryId";
static NSString *CS_PM_KEY_MESSAGE   = @"messageId";
static NSString *CS_PM_KEY_SEAL      = @"sealId";
static NSString *CS_PM_KEY_OWNED     = @"isOwned";

// - forward declarations
@interface CS_postedMessage (internal) <NSCoding>
-(void) releaseAllContent;
-(BOOL) fillUsingEntryData:(ChatSealMessageEntry *) entry withError:(NSError **) err;
@end

/*********************
 CS_postedMessage
 *********************/
@implementation CS_postedMessage
/*
 *  Object attributes.
 */
{
    NSString *safeEntryId;
    NSString *entryId;
    NSString *messageId;
    NSString *sealId;
    BOOL     isOwned;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        safeEntryId = nil;
        entryId     = nil;
        messageId   = nil;
        sealId      = nil;
        isOwned     = NO;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [self releaseAllContent];
    [super dealloc];
}

/*
 *  Return a new posted entry for the given entry.
 */
+(CS_postedMessage *) postedMessageForEntry:(ChatSealMessageEntry *) entry withError:(NSError **) err
{
    CS_postedMessage *pm = [[[CS_postedMessage alloc]init] autorelease];
    if ([pm fillUsingEntryData:entry withError:err]) {
        return pm;
    }
    return nil;
}

/*
 *  Return the safe entry id, which is a safe-salted version of the entry.
 */
-(NSString *) safeEntryId
{
    return [[safeEntryId retain] autorelease];
}

/*
 *  Return the entry id.
 */
-(NSString *) entryId
{
    return [[entryId retain] autorelease];
}

/*
 *  Return the message id.
 */
-(NSString *) messageId
{
    return [[messageId retain] autorelease];
}

/*
 *  Return the seal id.
 */
-(NSString *) sealId
{
    return [[sealId retain] autorelease];
}

/*
 *  Return whether the seal is owned.
 */
-(BOOL) isSealOwned
{
    return isOwned;
}

@end

/*****************************
 CS_postedMessage (internal)
 ****************************/
@implementation CS_postedMessage (internal)
/*
 *  Initialize the object from an archive.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        safeEntryId = [[aDecoder decodeObjectForKey:CS_PM_KEY_SAFEENTRY] retain];
        entryId     = [[aDecoder decodeObjectForKey:CS_PM_KEY_ENTRY] retain];
        messageId   = [[aDecoder decodeObjectForKey:CS_PM_KEY_MESSAGE] retain];
        sealId      = [[aDecoder decodeObjectForKey:CS_PM_KEY_SEAL] retain];
        isOwned     = [aDecoder decodeBoolForKey:CS_PM_KEY_OWNED];
    }
    return self;
}

/*
 *  Archive the object.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:safeEntryId forKey:CS_PM_KEY_SAFEENTRY];
    [aCoder encodeObject:entryId forKey:CS_PM_KEY_ENTRY];
    [aCoder encodeObject:messageId forKey:CS_PM_KEY_MESSAGE];
    [aCoder encodeObject:sealId forKey:CS_PM_KEY_SEAL];
    [aCoder encodeBool:isOwned forKey:CS_PM_KEY_OWNED];
}

/*
 *  Release the stored data.
 */
-(void) releaseAllContent
{
    [safeEntryId release];
    safeEntryId = nil;
    
    [entryId release];
    entryId = nil;
    
    [messageId release];
    messageId = nil;
    
    [sealId release];
    sealId = nil;
}

/*
 *  Populate the content of the posted entry
 */
-(BOOL) fillUsingEntryData:(ChatSealMessageEntry *) entry withError:(NSError **) err
{
    [self releaseAllContent];
    
    entryId      = [entry.entryId retain];
    NSError *tmp = nil;
    safeEntryId  = [[RealSecureImage safeSaltedStringAsBase64:entryId withError:&tmp] retain];          //  - use base-64 to minimize storage requirements.
    if (!safeEntryId) {
        NSLog(@"CS-ALERT: Unexpected safe entry id generation failure.  %@", [tmp localizedDescription]);
    }
    messageId    = [entry.messageId retain];
    sealId       = [entry.sealId retain];
    isOwned      = [entry isOwnerEntry];
    
    if (safeEntryId && entryId && messageId && sealId) {
        return YES;
    }
    else {
        [CS_error fillError:err withCode:CSErrorBadMessageStructure];
        return NO;
    }
}

@end