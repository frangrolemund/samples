//
//  CS_twitterFeed.h
//  ChatSeal
//
//  Created by Francis Grolemund on 3/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "ChatSealFeed.h"

@class ACAccount;
@protocol ChatSealFeedDelegate;
@class CS_tapi_user_looked_up;
@interface CS_twitterFeed : ChatSealFeed
+(NSString *) feedIdForAccount:(ACAccount *) account;
+(CS_twitterFeed *) feedForAccountId:(NSString *) sFeedId andDelegate:(id<ChatSealFeedDelegate>) delegate andDictionary:(NSDictionary *) dict;
+(CS_twitterFeed *) feedForAccount:(ACAccount *) account andDelegate:(id<ChatSealFeedDelegate>) delegate andDictionary:(NSDictionary *) dict;
+(NSString *) genericNoAuthError;
-(void) setACAccountIdentifier:(NSString *) identifier;
-(NSString *) acAccountIdentifier;
-(void) requestHighPriorityLookupForFriends:(NSArray *) friendsList;
-(void) requestHighPriorityRefreshForFriend:(NSString *) screenName;
-(void) cancelHighPriorityRefreshForFriend:(NSString *) screenName;
-(void) requestHighPriorityFollowForFriend:(NSString *) screenName;
-(void) requestHighPriorityUnblockForFriend:(NSString *) screenName;
-(void) requestHighPriorityUnmuteForFriend:(NSString *) screenName;
-(BOOL) hasRealtimeSupport;
-(void) notifyFriendshipsHaveBeenUpdated;
-(void) prefillSharedContentDuringCreationFromFeed:(CS_twitterFeed *) feedOther;
-(BOOL) isLikelyToScheduleAPIByName:(NSString *) name withEventDistribution:(BOOL) evenlyDistributed;
-(void) requestHighPriorityValidationForFriend:(NSString *) screenName withCompletion:(void(^)(CS_tapi_user_looked_up *result)) completion;
-(void) cancelHighPriorityValidationForFriend:(NSString *) screenName;
@end
