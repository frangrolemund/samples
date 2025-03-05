//
//  CS_twitterFeed_highPrio_friendRefresh.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/26/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeed_highPrio_friendRefresh.h"

//  THREADING-NOTES:
//  - there is no internal locking here because it is assumed that this is never modified outside the feed lock.

/****************************************
 CS_twitterFeed_highPrio_friendRefresh
 ****************************************/
@implementation CS_twitterFeed_highPrio_friendRefresh
/*
 *  Object attributes
 */
{
    NSString *sFriend;
    BOOL     isComplete;
}

/*
 *  Initialize the object
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
 *  Return a new task object.
 */
+(CS_twitterFeed_highPrio_friendRefresh *) taskForFriend:(NSString *) myFriend
{
    return [[[CS_twitterFeed_highPrio_friendRefresh alloc] initWithFriend:myFriend] autorelease];
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
    CS_tapi_friendships_show *fs = (CS_tapi_friendships_show *) [feed apiForName:@"CS_tapi_friendships_show" andReturnWasThrottled:nil withError:nil];
    if (!fs) {
        return NO;
    }
    
    [fs setSourceScreenName:feed.userId];
    [fs setTargetScreenName:sFriend];
    if (![feed addCollectorRequestWithAPI:fs andReturnWasThrottled:nil withError:nil]) {
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
    if ([task isKindOfClass:[CS_twitterFeed_highPrio_friendRefresh class]]) {
        CS_twitterFeed_highPrio_friendRefresh *taskOther = (CS_twitterFeed_highPrio_friendRefresh *) task;
        if (taskOther && [taskOther->sFriend isEqualToString:sFriend]) {
            return YES;
        }
    }
    return NO;
}
@end
