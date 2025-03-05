//
//  CS_twitterFriendshipState.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/7/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CS_tfsFriendshipState_shared.h"

@class CS_twitterFriendshipState;
@protocol CS_twitterFriendshipStateDelegate <NSObject>
-(void) initialFriendshipUpdateHasOccurredForState:(CS_twitterFriendshipState *) fs;
-(void) friendshipsUpdatedForState:(CS_twitterFriendshipState *) fs;
@end

@class CS_tapi_friendship_state;
@class CS_tfsFriendshipAdjustment;
@class CS_tapi_tweetRange;
@class CS_twitterFeed;
@class CS_tapi_users_show;
@interface CS_twitterFriendshipState : NSObject
-(void) setBaseTypeURL:(NSURL *) uBase;
-(BOOL) hasBaseURL;
-(csft_friendship_state_t) friendshipStateInType:(CS_feedTypeTwitter *) twitterFeedType;
-(NSArray *) feedFriendsInType:(CS_feedTypeTwitter *) twitterFeedType;
-(BOOL) hasHighPriorityWorkToPerformInType:(CS_feedTypeTwitter *) twitterFeedType;
-(BOOL) processFeedTypeRequestsUsingFeed:(ChatSealFeed *) feed inType:(CS_feedTypeTwitter *) twitterFeedType;
-(void) updateFriendshipsWithResultMasks:(NSDictionary *) dictMasks fromFeed:(ChatSealFeed *) feed inType:(CS_feedTypeTwitter *) twitterFeedType;
-(BOOL) ignoreFriendByAccountId:(NSString *) acctId;
-(void) restoreFriendsAccountIds:(NSArray *) arrFriends;
-(NSArray *) localFeedsConnectionStatusWithFriend:(ChatSealFeedFriend *) feedFriend inType:(CS_feedTypeTwitter *) twitterFeedType;
-(ChatSealFeedFriend *) refreshFriendFromFriend:(ChatSealFeedFriend *) feedFriend inType:(CS_feedTypeTwitter *) twitterFeedType;
-(void) incrementUserVersionForScreenName:(NSString *) screenName;
-(void) markFriendDeficienciesAsStaleForFeed:(CS_twitterFeed *) feed inType:(CS_feedTypeTwitter *) twitterFeedType;
-(void) updateTargetedFriendshipWithResults:(CS_tapi_friendships_show *) apiFriend fromFeed:(ChatSealFeed *) feed inType:(CS_feedTypeTwitter *) twitterFeedType;
-(CS_tfsFriendshipAdjustment *) recommendedAdjustmentForFeed:(ChatSealFeed *) feed withFriend:(ChatSealFeedFriend *) feedFriend;
-(void) setFeed:(CS_twitterFeed *) feed withFollowing:(BOOL) isFollowing forFriendName:(NSString *) friendName;
-(void) setFeed:(CS_twitterFeed *) feed asBlocking:(BOOL) isBlocking forFriendName:(NSString *) friendName;
-(void) markFeed:(CS_twitterFeed *) feed asBlockedByFriendWithName:(NSString *) friendName;
-(void) reconcileKnownFriendshipStateFromFeed:(CS_twitterFeed *) feed toFriend:(NSString *) friendName withPendingTask:(id<CS_twitterFeed_highPrio_task>) task;
-(CS_tapi_friendship_state *) stateForFriendByName:(NSString *) screenName inFeed:(CS_twitterFeed *) feed;
-(BOOL) isFriend:(NSString *) friendName followingMyFeed:(CS_twitterFeed *) feed;
-(BOOL) canMyFeed:(CS_twitterFeed *) feed readMyFriend:(NSString *) friendName;
-(NSDictionary *) statesForAllReachableFriendsInFeed:(CS_twitterFeed *) feed;
-(CS_twitterFeed *) bestLocalFeedForReadingFriend:(NSString *) friendName usingFeedList:(NSArray *) feedList;
-(BOOL) isTimelineRequestPermittedForFriend:(NSString *) friendName andRange:(CS_tapi_tweetRange *) range fromFeed:(CS_twitterFeed *) feed;
-(void) completeTimelineRequestForFriend:(NSString *) friendName andRange:(CS_tapi_tweetRange *) range;
-(void) discardAllTimelineRequestsFromFeed:(CS_twitterFeed *) feed;
-(BOOL) doesFriendshipDatabaseSupporFollowingWarning;
-(BOOL) canUseTwitterReplyToFriend:(NSString *) friendName fromMyFeed:(CS_twitterFeed *) feed whenUsingSeal:(NSString *) sealId;
-(BOOL) isTrackingFriendByName:(NSString *) friendName;
-(void) trackUnprovenFriendByName:(NSString *) friendName andInitializeWith:(CS_tapi_user_looked_up *) userInfo;
-(void) discardAllLocalUserStateForFeed:(ChatSealFeed *) feed;
@property (nonatomic, assign) id<CS_twitterFriendshipStateDelegate> delegate;
@end
