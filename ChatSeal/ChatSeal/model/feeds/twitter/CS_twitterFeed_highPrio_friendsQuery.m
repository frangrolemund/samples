//
//  CS_twitterFeed_highPrio_friendsQuery.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/26/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeed_highPrio_friendsQuery.h"

//  THREADING-NOTES:
//  - there is no internal locking here because it is assumed that this is never modified outside the feed lock.

// - constants
static const NSUInteger CS_TF_MAX_FRIENDS_QUERY = 5000;

/*************************************
 CS_twitterFeed_highPrio_friendsQuery
 *************************************/
@implementation CS_twitterFeed_highPrio_friendsQuery
/*
 *  Object attributes
 */
{
    NSMutableArray *maFriendsToQuery;
}

/*
 *  Make sure that we don't query too many.
 */
-(void) limitFriendCount
{
    if ([maFriendsToQuery count] > CS_TF_MAX_FRIENDS_QUERY) {
        [maFriendsToQuery removeObjectsInRange:NSMakeRange(CS_TF_MAX_FRIENDS_QUERY, [maFriendsToQuery count] - CS_TF_MAX_FRIENDS_QUERY)];
    }
}

/*
 *  Initialize the object
 */
-(id) initWithFriends:(NSArray *) arrFriends
{
    self = [super init];
    if (self) {
        maFriendsToQuery = [[NSMutableArray alloc] initWithArray:arrFriends];
        [self limitFriendCount];
    }
    return self;
}

/*
 *  Return a new task object.
 */
+(CS_twitterFeed_highPrio_friendsQuery *) taskForFriends:(NSArray *) arrFriends
{
    return [[[CS_twitterFeed_highPrio_friendsQuery alloc] initWithFriends:arrFriends] autorelease];
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [maFriendsToQuery release];
    maFriendsToQuery = nil;
    
    [super dealloc];
}

/*
 *  Try to advance processing in this object.
 *  - return YES only if you were able to do something, even if it is minor.
 */
-(BOOL) tryToProcessTaskForFeed:(CS_twitterFeed *) feed
{
    BOOL didProcess = NO;
    
    // - we're going to request these until we finish or are throttled.
    for (;;) {
        if (![maFriendsToQuery count]) {
            return didProcess;
        }
        
        NSArray *arrScreenNames = [maFriendsToQuery subarrayWithRange:NSMakeRange(0, MIN(maFriendsToQuery.count, [CS_tapi_friendships_lookup maxUsersPerRequest]))];
        
        // - we have some names, try to allocate the API.
        CS_tapi_friendships_lookup *frl = (CS_tapi_friendships_lookup *) [feed apiForName:@"CS_tapi_friendships_lookup" andReturnWasThrottled:nil withError:nil];
        if (!frl) {
            return didProcess;
        }
        
        // - and schedule it.
        [frl setScreenNames:arrScreenNames];
        if (![feed addCollectorRequestWithAPI:frl andReturnWasThrottled:nil withError:nil]) {
            return didProcess;
        }
        
        didProcess = YES;
        [maFriendsToQuery removeObjectsInArray:arrScreenNames];
    }
    
    return didProcess;
}

/*
 *  Add-in the contents of the given task.
 */
-(void) mergeInWorkFromTask:(id<CS_twitterFeed_highPrio_task>) task
{
    if ([task isKindOfClass:[CS_twitterFeed_highPrio_friendsQuery class]]) {
        CS_twitterFeed_highPrio_friendsQuery *otherTask = (CS_twitterFeed_highPrio_friendsQuery *) task;
        if ([maFriendsToQuery count]) {
            NSMutableSet *msItems = [NSMutableSet setWithArray:maFriendsToQuery];
            [msItems addObjectsFromArray:otherTask->maFriendsToQuery];
            [maFriendsToQuery removeAllObjects];
            [maFriendsToQuery addObjectsFromArray:msItems.allObjects];
        }
        else {
            [maFriendsToQuery addObjectsFromArray:otherTask->maFriendsToQuery];
        }
        [self limitFriendCount];
    }
}

/*
 *  Is all the work completed?
 */
-(BOOL) hasCompletedTask
{
    if ([maFriendsToQuery count] == 0) {
        return YES;
    }
    return NO;
}

/*
 *  Is this task equal to another?
 */
-(BOOL) isEqualToTask:(id<CS_twitterFeed_highPrio_task>) task
{
    // - the friends we're querying aren't important, we only ever want one of these
    //   to ever be used at a time because they may be issued multiple times.
    if ([task isKindOfClass:[CS_twitterFeed_highPrio_friendsQuery class]]) {
        return YES;
    }
    return NO;
}
@end
