//
//  ChatSealPostedMessageProgress.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/24/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "ChatSealPostedMessageProgress.h"
#import "CS_feedShared.h"
#import "CS_postedMessageState.h"

//  THREADING-NOTES:
//  - no locking is provided.  This object is never modified after it is created.

/*********************************
 ChatSealPostedMessageProgress
 *********************************/
@implementation ChatSealPostedMessageProgress
/*
 *  Object attributes
 */
{
    int64_t     totalToSend;
    int64_t     numSent;
    NSString    *msgId;
    NSString    *entryId;
    NSString    *safeEntryId;
    NSString    *desc;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [msgId release];
    msgId = nil;
    
    [entryId release];
    entryId = nil;
    
    [safeEntryId release];
    safeEntryId = nil;
    
    [desc release];
    desc = nil;
    
    [super dealloc];
}

/*
 *  Return whether this progress item indicates the message is fully posted.
 */
-(BOOL) isCompleted
{
    if (totalToSend > 0 && numSent == totalToSend) {
        return YES;
    }
    return NO;
}

/*
 *  Indicate whether we have started the post yet.
 */
-(BOOL) hasStarted
{
    if (numSent > 0) {
        return YES;
    }
    return NO;
}

/*
 *  Return the active progress.
 */
-(double) progress
{
    if (totalToSend > 0) {
        return (double) numSent / (double) totalToSend;;
    }
    else {
        return 0.0;
    }
}

/*
 *  Return the message's id.
 */
-(NSString *) messageId
{
    return [[msgId retain] autorelease];
}

/*
 *  Return the message entry id for this post.
 */
-(NSString *) entryId
{
    return [[entryId retain] autorelease];
}

/*
 *  Return the safe entry id.
 */
-(NSString *) safeEntryId
{
    return [[safeEntryId retain] autorelease];
}

/*
 *  Return the message description.
 */
-(NSString *) msgDescription
{
    return [[desc retain] autorelease];
}

/*
 *  Determine if these two objects refer to the same item.
 */
-(BOOL) isEqual:(id)object
{
    if (![object isKindOfClass:[ChatSealPostedMessageProgress class]]) {
        return NO;
    }
    
    ChatSealPostedMessageProgress *cspmp = (ChatSealPostedMessageProgress *) object;
    return [self.safeEntryId isEqualToString:cspmp.safeEntryId];
}

@end

/***************************************
 ChatSealPostedMessageProgress (internal)
 ***************************************/
@implementation ChatSealPostedMessageProgress (internal)
/*
 *  Initialize the object.
 */
-(id) initWithState:(CS_postedMessageState *) state
{
    self = [super init];
    if (self) {
        numSent     = state.numSent;
        totalToSend = state.totalToSend;
        safeEntryId = [[state safeEntryId] retain];
        desc        = [[state msgDescription] retain];
    }
    return self;
}

/*
 *  Assign the message id and entry id to this object.
 */
-(void) setMessageId:(NSString *)mid andEntryId:(NSString *) eid
{
    if (mid != msgId) {
        [msgId release];
        msgId = [mid retain];
    }
    
    if (eid != entryId) {
        [entryId release];
        entryId = [eid retain];
    }
}

/*
 *  When we delete these items, we're going to temporarily mark them as completed so that
 *  progress checks do the right thing and remove them from consideration.
 */
-(void) markAsFakeCompleted
{
    numSent = totalToSend = 1;
}

@end
