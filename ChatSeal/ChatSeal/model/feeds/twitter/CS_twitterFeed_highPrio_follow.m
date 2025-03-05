//
//  CS_twitterFeed_highPrio_follow.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeed_highPrio_follow.h"
#import "CS_tapi_friendship_state.h"

//  THREADING-NOTES:
//  - there is no internal locking here because it is assumed that this is never modified outside the feed lock.

// - constants
static NSString *CS_TFHPF_FRIEND_KEY = @"f";
static NSString *CS_TFHPF_COMP_KEY   = @"c";

/***********************************
 CS_twitterFeed_highPrio_follow
 ***********************************/
@implementation CS_twitterFeed_highPrio_follow
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
        sFriend     = [[aDecoder decodeObjectForKey:CS_TFHPF_FRIEND_KEY] retain];
        isComplete  = [aDecoder decodeBoolForKey:CS_TFHPF_COMP_KEY];
    }
    return self;
}

/*
 *  Encode to an archive.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:sFriend forKey:CS_TFHPF_FRIEND_KEY];
    [aCoder encodeBool:isComplete forKey:CS_TFHPF_COMP_KEY];
}

/*
 *  Return a new task object.
 */
+(CS_twitterFeed_highPrio_follow *) taskForFriend:(NSString *) myFriend
{
    return [[[CS_twitterFeed_highPrio_follow alloc] initWithFriend:myFriend] autorelease];
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
    CS_tapi_friendships_create *fc = (CS_tapi_friendships_create *) [feed apiForName:@"CS_tapi_friendships_create" andReturnWasThrottled:nil withError:nil];
    if (!fc) {
        return NO;
    }
    
    [fc setTargetScreenName:sFriend];
    if (![feed addCollectorRequestWithAPI:fc andReturnWasThrottled:nil withError:nil]) {
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
    if ([task isKindOfClass:[CS_twitterFeed_highPrio_follow class]]) {
        CS_twitterFeed_highPrio_follow *taskOther = (CS_twitterFeed_highPrio_follow *) task;
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
        if (state.isFollowing) {
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
    if (!screenName || ![screenName isEqualToString:sFriend] || state.isFollowing) {
        return NO;
    }

    // - we need to manufacture the right kind of new state based on the protection of the friend's data
    if (!state.isFollowing && ![state hasSentFollowRequest]) {
        // - because we can't know for certain whether an account is protected, we're going to assume it
        //   is and the state will be normalized when we make it up to the health object where the
        //   official protection state is stored.
        [state setHasSentFollowRequest:YES];
        return YES;
    }
    return NO;
}

@end
