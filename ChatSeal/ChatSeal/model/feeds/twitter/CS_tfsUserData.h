//
//  CS_tfsUserData.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/9/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CS_tfsFriendshipState_shared.h"

@class ChatSealIdentityFriend;
@class CS_tapi_friendship_state;
@class CS_tfsMessagingDeficiency;
@class CS_tapi_user_looked_up;
@class CS_tapi_users_show;
@interface CS_tfsUserData : NSObject <NSCoding>
+(CS_tfsUserData *) userDataForScreenName:(NSString *) screenName asAccount:(cs_tfs_account_id_t) acct andIsMe:(BOOL) isMe;
-(void) updateWithFriendInfo:(ChatSealIdentityFriend *) chatFriend;
-(NSNumber *) accountKey;
-(cs_tfs_account_id_t) accountId;
-(BOOL) addFriendshipState:(CS_tapi_friendship_state *) state forFriend:(CS_tfsUserData *) chatFriend;
-(BOOL) updateProtectionStateFromFriends:(NSArray *) arrFriends;
-(void) discardFriendshipStatesForAccountsNotInArray:(NSArray *) arrAccts;
-(void) discardFriendshipStateForKey:(NSNumber *) nKey;
-(void) addUnqueriedHealthIssuesForNewFriends:(NSArray *) arrAccts;
-(NSDictionary *) friendshipHealthIssues;
-(CS_tfsMessagingDeficiency *) deficiencyForFriendWithKey:(NSNumber *) nKey;
-(NSString *) generateProfileHash;
-(BOOL) setProfileImage:(NSString *) sImage;
-(NSString *) profileImage;
-(BOOL) hasRecentProfileImage;
-(NSArray *) discardAllHealthIssuesAndReturnFriends;
-(BOOL) setFriendByKey:(NSNumber *) nFriend asFollowing:(BOOL) isFollowing;
-(BOOL) setFriendByKey:(NSNumber *) nFriend asBlocking:(BOOL) isBlocking;
-(BOOL) markFriendByKeyAsBlockingMyFeed:(NSNumber *) nFriend;
-(BOOL) reconcileFriendByName:(NSString *) friendName andKey:(NSNumber *) nFriend withPendingTask:(id<CS_twitterFeed_highPrio_task>) task;
-(CS_tapi_friendship_state *) stateForFriendByKey:(NSNumber *) nFriend;
-(NSDictionary *) allReachableFriends;
-(BOOL) updateWithUserProfile:(CS_tapi_user_looked_up *) tul;
-(BOOL) isVerified;
-(void) flagAsProven;
@property (nonatomic, readonly) NSString *screenName;
@property (nonatomic, readonly) cs_tfs_account_id_t accountId;
@property (nonatomic, readonly) BOOL isMe;
@property (nonatomic, readonly) BOOL iAmSealOwnerInRelationship;
@property (nonatomic, readonly) BOOL userAccountIsProtected;
@property (nonatomic, readonly) NSString *fullName;
@property (nonatomic, readonly) NSString *location;
@property (nonatomic, readonly) BOOL isProven;
@property (nonatomic, assign)   uint16_t userVersion;
@property (nonatomic, retain)   NSString *cachedProfileHash;
@property (nonatomic, assign)   BOOL profileImageDownloadPending;
@property (nonatomic, assign)   BOOL isDeleted;
@end
