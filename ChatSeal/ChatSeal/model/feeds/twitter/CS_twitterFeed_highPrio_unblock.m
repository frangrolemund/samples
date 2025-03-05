//
//  CS_twitterFeed_highPrio_unblock.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/29/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeed_highPrio_unblock.h"
#import "CS_tapi_friendship_state.h"

//  THREADING-NOTES:
//  - there is no internal locking here because it is assumed that this is never modified outside the feed lock.

// - constants
static NSString *CS_TFHPUB_FRIEND_KEY = @"f";
static NSString *CS_TFHPUB_COMP_KEY   = @"c";


/*******************************
 CS_twitterFeed_highPrio_unblock
 *******************************/
@implementation CS_twitterFeed_highPrio_unblock
/*
 *  Object attributes
 */
{
    NSString *sFriend;
    BOOL     isComplete;
}

/*
 *  Initialize the object.
 */
-(id) initWithFriend:(NSString *) myFriend
{
    self = [super init];
    if (self) {
        isComplete = NO;
        sFriend    = [myFriend retain];
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
        sFriend     = [[aDecoder decodeObjectForKey:CS_TFHPUB_FRIEND_KEY] retain];
        isComplete  = [aDecoder decodeBoolForKey:CS_TFHPUB_COMP_KEY];
    }
    return self;
}

/*
 *  Encode to an archive.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:sFriend forKey:CS_TFHPUB_FRIEND_KEY];
    [aCoder encodeBool:isComplete forKey:CS_TFHPUB_COMP_KEY];
}

/*
 *  Return a new task object.
 */
+(CS_twitterFeed_highPrio_unblock *) taskForFriend:(NSString *) myFriend
{
    return [[[CS_twitterFeed_highPrio_unblock alloc] initWithFriend:myFriend] autorelease];
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [sFriend release];
    sFriend = nil;
    
    [super dealloc];
}

/*
 *  Try to advance processing in this object.
 *  - return YES only if you were able to do something, even if it is minor.
 */
-(BOOL) tryToProcessTaskForFeed:(CS_twitterFeed *) feed
{
    CS_tapi_blocks_destroy *bd = (CS_tapi_blocks_destroy *) [feed apiForName:@"CS_tapi_blocks_destroy" andReturnWasThrottled:nil withError:nil];
    if (!bd) {
        return NO;
    }
    
    [bd setTargetScreenName:sFriend];
    if (![feed addCollectorRequestWithAPI:bd andReturnWasThrottled:nil withError:nil]) {
        return NO;
    }
    
    isComplete = YES;
    return YES;
}

/*
 *  Add-in the contents of the given task.
 */
-(void) mergeInWorkFromTask:(id<CS_twitterFeed_highPrio_task>) task
{
    // - nothing to merge.  If they are equal, then either can be used.
}

/*
 *  Is all the work completed?
 */
-(BOOL) hasCompletedTask
{
    return isComplete;
}

/*
 *  Is this task equal to another?
 */
-(BOOL) isEqualToTask:(id<CS_twitterFeed_highPrio_task>) task
{
    if ([task isKindOfClass:[CS_twitterFeed_highPrio_unblock class]]) {
        CS_twitterFeed_highPrio_unblock *taskOther = (CS_twitterFeed_highPrio_unblock *) task;
        if (taskOther && [taskOther->sFriend isEqualToString:sFriend]) {
            return YES;
        }
    }
    return NO;
}

/*
 *  Does this task still make sense with the given state?
 *  - this is intended to only be used with up-to-date state that was received from an online source.
 */
-(BOOL) isRedundantForState:(CS_tapi_friendship_state *) state forFriend:(NSString *) screenName
{
    if (screenName && [screenName isEqualToString:sFriend]) {
        if (!state.isBlocking) {
            return YES;
        }
    }
    return NO;
}

/*
 *  Adjust the state to reflect the fact that this task is going to be operating on it.
 *  - return YES if an adjustment was made.
 */
-(BOOL) reconcileTaskIntentInActualState:(CS_tapi_friendship_state *) state forFriend:(NSString *) screenName
{
    if (!screenName || ![screenName isEqualToString:sFriend] || !state.isBlocking) {
        return NO;
    }
    
    // - we need to manufacture the right kind of new state based on the protection of the friend's data
    if (state.isBlocking) {
        [state setIsBlocking:NO];
        return YES;
    }
    return NO;
}
@end
