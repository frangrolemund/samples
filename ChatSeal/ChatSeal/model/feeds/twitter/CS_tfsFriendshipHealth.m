//
//  CS_tfsFriendshipHealth.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/14/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tfsFriendshipHealth.h"

//  THREADING-NOTES:
//  - no locking is provided in this class.

// - constants
static NSString *CS_TFS_FH_HEALTH_ISSUES = @"hi";

/****************************
 CS_tfsFriendshipHealth
 ****************************/
@implementation CS_tfsFriendshipHealth
/*
 *  Object attributes.
 */
{
    NSMutableDictionary *mdHealthDeficiencies;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        mdHealthDeficiencies = [[NSMutableDictionary alloc] init];
    }
    return self;
}

-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        mdHealthDeficiencies = [[aDecoder decodeObjectForKey:CS_TFS_FH_HEALTH_ISSUES] retain];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [mdHealthDeficiencies release];
    mdHealthDeficiencies = nil;
    
    [super dealloc];
}

/*
 *  Save off this object.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:mdHealthDeficiencies forKey:CS_TFS_FH_HEALTH_ISSUES];
}

/*
 *  The purpose of this method is to recompute whether connection issues exist between a local user and a remote friend.
 *  - returns a value whether the health has been modified.
 */
-(BOOL) updateFriendshipFromUser:(CS_tfsUserData *) localUser toAccount:(NSNumber *) accountKey withState:(CS_tapi_friendship_state *) fs
{
    CS_tfsMessagingDeficiency *md    = [CS_tfsMessagingDeficiency deficiencyFromUser:localUser toUserWithState:fs];
    CS_tfsMessagingDeficiency *mdOld = [mdHealthDeficiencies objectForKey:accountKey];
    BOOL retChanged                  = NO;
    if ((md || mdOld) && ![md isEqualToDeficiency:mdOld]) {
        retChanged = YES;
    }
    
    if (md) {
        [mdHealthDeficiencies setObject:md forKey:accountKey];
    }
    else {
        if (mdOld) {
            [mdHealthDeficiencies removeObjectForKey:accountKey];
        }
    }
    return retChanged;
}

/*
 *  Iterate through our health states and discard any that match the provided list of friends.
 */
-(void) discardHealthRecordsForFriendsInArray:(NSArray *) arrFriends
{
    [mdHealthDeficiencies removeObjectsForKeys:arrFriends];
}

/*
 *  Discard a single friend's health state.
 */
-(void) discardHealthRecordForFriendWithKey:(NSNumber *) nKey
{
    [mdHealthDeficiencies removeObjectForKey:nKey];
}

/*
 *  Return the unique list of health issues managed by this object.
 */
-(NSDictionary *) friendshipHealthIssues
{
    return [NSDictionary dictionaryWithDictionary:mdHealthDeficiencies];
}

/*
 *  Return any deficiency records for the given account key.
 */
-(CS_tfsMessagingDeficiency *) deficiencyForFriendWithKey:(NSNumber *) nKey
{
    return [[[mdHealthDeficiencies objectForKey:nKey] retain] autorelease];
}

/*
 *  This method allows us to identify scenarios where my first query for
 *  a friend from this local user hasn't completed yet.  The first
 *  time we update our friendship for that key, the issue will either be updated
 *  or removed.
 */
-(void) addUnqueriedHealthIssueForAccounts:(NSArray *) arrFriends
{
    for (NSNumber *n in arrFriends) {
        if (![mdHealthDeficiencies objectForKey:n]) {
            [mdHealthDeficiencies setObject:[CS_tfsMessagingDeficiency deficiencyForUnqueriedFriend] forKey:n];
        }
    }
}

/*
 *  Discard all the health issues in this object and return the affected friends.
 */
-(NSArray *) discardAllHealthIssuesAndReturnFriends
{
    NSArray *arrKeys = [mdHealthDeficiencies allKeys];
    [mdHealthDeficiencies removeAllObjects];
    return arrKeys;
}
@end
