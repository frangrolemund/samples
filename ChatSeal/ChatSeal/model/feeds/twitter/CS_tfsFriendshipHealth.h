//
//  CS_tfsFriendshipHealth.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/14/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CS_tfsFriendshipState_shared.h"

@interface CS_tfsFriendshipHealth : NSObject <NSCoding>
-(BOOL) updateFriendshipFromUser:(CS_tfsUserData *) localUser toAccount:(NSNumber *) accountKey withState:(CS_tapi_friendship_state *) fs;
-(void) discardHealthRecordsForFriendsInArray:(NSArray *) arrFriends;
-(void) discardHealthRecordForFriendWithKey:(NSNumber *) nKey;
-(NSDictionary *) friendshipHealthIssues;
-(CS_tfsMessagingDeficiency *) deficiencyForFriendWithKey:(NSNumber *) nKey;
-(void) addUnqueriedHealthIssueForAccounts:(NSArray *) arrFriends;
-(NSArray *) discardAllHealthIssuesAndReturnFriends;
@end
