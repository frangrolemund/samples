//
//  CS_postedMessageState.m
//  ChatSeal
//
//  Created by Francis Grolemund on 5/13/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_postedMessageState.h"

// - constants
static NSString *CS_PMS_SAFE_ENTRY_KEY = @"seid";
static NSString *CS_PMS_STATE_KEY      = @"state";
static NSString *CS_PMS_DESC_KEY       = @"desc";
static NSString *CS_PMS_DATE_KEY       = @"date";

// - forward declarations
@interface CS_postedMessageState (internal) <NSCoding>
-(id) initWithSafeEntry:(NSString *) seid;
@end

/**************************
 CS_postedMessageState
 **************************/
@implementation CS_postedMessageState
/*
 *  Object attributes.
 */
{
    NSString *safeEntryId;
    NSDate   *dtCreated;
}
@synthesize state;
@synthesize totalToSend;
@synthesize numSent;
@synthesize msgDescription;

/*
 *  Return a new instance of this object.
 */
+(CS_postedMessageState *) stateForSafeEntry:(NSString *) safeEntryId
{
    return [[[CS_postedMessageState alloc] initWithSafeEntry:safeEntryId] autorelease];
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [safeEntryId release];
    safeEntryId = nil;
    
    [msgDescription release];
    msgDescription = nil;
    
    [dtCreated release];
    dtCreated = nil;
    
    [super dealloc];
}

/*
 *  Return the entry id for this state.
 */
-(NSString *) safeEntryId
{
    return [[safeEntryId retain] autorelease];
}

/*
 *  Return the date this item was created.
 */
-(NSDate *) dateCreated
{
    return [[dtCreated retain] autorelease];
}

/*
 *  Compare two state items.
 */
-(NSComparisonResult) compare:(CS_postedMessageState *) otherState
{
    NSComparisonResult result = [dtCreated compare:otherState->dtCreated];
    if (result == NSOrderedSame) {
        result = [self.msgDescription compare:otherState.msgDescription];
    }
    return result;
}
@end


/*******************************
 CS_postedMessageState (internal)
 *******************************/
@implementation CS_postedMessageState (internal)

/*
 *  Initialize the object.
 */
-(id) initWithSafeEntry:(NSString *) seid
{
    self = [super init];
    if (self) {
        safeEntryId    = [seid retain];
        state          = CS_PMS_PENDING;
        totalToSend    = -1;
        numSent        = -1;
        msgDescription = nil;
        dtCreated      = [[NSDate date] retain];
    }
    return self;
}

/*
 *  Initialize from an archive.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        safeEntryId    = [[aDecoder decodeObjectForKey:CS_PMS_SAFE_ENTRY_KEY] retain];
        state          = (cs_postedmessage_state_t) [aDecoder decodeIntegerForKey:CS_PMS_STATE_KEY];
        msgDescription = [[aDecoder decodeObjectForKey:CS_PMS_DESC_KEY] retain];
        dtCreated      = [[aDecoder decodeObjectForKey:CS_PMS_DATE_KEY] retain];
    }
    return self;
}

/*
 *  Encode to an archive.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:safeEntryId forKey:CS_PMS_SAFE_ENTRY_KEY];
    [aCoder encodeInteger:state forKey:CS_PMS_STATE_KEY];
    [aCoder encodeObject:msgDescription forKey:CS_PMS_DESC_KEY];
    [aCoder encodeObject:dtCreated forKey:CS_PMS_DATE_KEY];
    
    // NOTE: we don't encode the sent totals because persisting them will only thrash
    //       the disk and often won't matter anyway since once the item is done, it won't be used.
}

@end