//
//  CS_feedTypeTwitter.h
//  ChatSeal
//
//  Created by Francis Grolemund on 3/24/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ChatSealFeedType.h"
#import "CS_sharedChatSealFeedTypeImplementation.h"

@class CS_twitterFeed;
@class ACAccount;
@class CS_tapi_application_rate_limit_status;
@class CS_tapi_friendship_state;
@class CS_tapi_friendships_lookup;
@class CS_tapi_friendships_show;
@class CS_tfsFriendshipAdjustment;
@class CS_tapi_statuses_user_timeline;
@class CS_tapi_user_looked_up;
@protocol CS_twitterFeed_highPrio_task;
@interface CS_feedTypeTwitter : ChatSealFeedType <CS_sharedChatSealFeedTypeImplementation>
-(ACAccount *) accountForFeed:(CS_twitterFeed *) feed;
+(BOOL) isValidTwitterHost:(NSString *) sHost;
-(BOOL) setTweetIdAsCompleted:(NSString *) tweetId withError:(NSError **) err;
-(BOOL) untrackTweetId:(NSString *) tweetId withError:(NSError **) err;
-(BOOL) isUserIdMine:(NSString *) userId;
-(BOOL) isTweetTrackedInAnyFeed:(NSString *) tweetId;
-(BOOL) doesCentralTweetTrackingPermitTweet:(NSString *) tweetId toBeProcessedByFeed:(ChatSealFeed *) feed;
-(void) updateFactoryLimitsWithStatus:(CS_tapi_application_rate_limit_status *) apiStatus inFeed:(ChatSealFeed *) feed;
-(NSArray *) requiredTwitterAPIResources;
-(void) updateFriendshipsWithResultMasks:(NSDictionary *) dictMasks fromFeed:(ChatSealFeed *) feed;
-(NSArray *) localFeedsConnectionStatusWithFriend:(ChatSealFeedFriend *) feedFriend;
-(ChatSealFeedFriend *) refreshFriendFromFriend:(ChatSealFeedFriend *) feedFriend;
-(void) incrementFriendVersionForScreenName:(NSString *) myFriend;
-(void) markFriendDeficienciesAsStaleForFeed:(CS_twitterFeed *) feed;
-(void) updateTargetedFriendshipWithResults:(CS_tapi_friendships_show *) apiShow fromFeed:(ChatSealFeed *) feed;
-(CS_tfsFriendshipAdjustment *) recommendedAdjustmentForFeed:(ChatSealFeed *) feed withFriend:(ChatSealFeedFriend *) feedFriend;
-(void) setFeed:(CS_twitterFeed *) feed withFollowing:(BOOL) isFollowing forFriendName:(NSString *) friendName;
-(void) setFeed:(CS_twitterFeed *) feed asBlocking:(BOOL) isBlocking forFriendName:(NSString *) friendName;
-(void) markFeed:(CS_twitterFeed *) feed asBlockedByFriendWithName:(NSString *) friendName;
-(void) reconcileKnownFriendshipStateFromFeed:(CS_twitterFeed *) feed toFriend:(NSString *) friendName withPendingTask:(id<CS_twitterFeed_highPrio_task>) task;
-(CS_tapi_friendship_state *) stateForFriendByName:(NSString *) screenName inFeed:(CS_twitterFeed *) feed;
-(BOOL) isFriend:(NSString *) friendName followingMyFeed:(CS_twitterFeed *) feed;
-(BOOL) canMyFeed:(CS_twitterFeed *) feed readMyFriend:(NSString *) friendName;
-(NSDictionary *) statesForAllReachableFriendsInFeed:(CS_twitterFeed *) feed;
-(void) processPostedMessageHistory:(NSArray *) arrHist fromSourceFeed:(CS_twitterFeed *) sourceFeed;
-(BOOL) saveOrReplaceAsCandidateTweet:(NSString *) tweetId fromFriend:(NSString *) friendName withPhoto:(NSURL *) uPhoto asProvenUseful:(BOOL) isUseful;
-(BOOL) isUserTimelineRequest:(CS_tapi_statuses_user_timeline *) api allowedForFeed:(CS_twitterFeed *) feed;
-(void) completeUserTimelineRequest:(CS_tapi_statuses_user_timeline *) api fromFeed:(CS_twitterFeed *) feed;
-(void) discardAllTimelineRequestsFromFeed:(CS_twitterFeed *) feed;
-(void) reassignPendingItemsFromFeed:(CS_twitterFeed *) feed priorToDeletion:(BOOL) willDelete;
-(void) checkForCandidateAssignments;
-(void) checkIfOtherPendingCanBeTransferredToFeed:(CS_twitterFeed *) feed;
-(BOOL) doesFriendshipDatabaseSupportFollowingWarning;
-(BOOL) canUseTwitterReplyToFriend:(NSString *) friendName fromMyFeed:(CS_twitterFeed *) feed whenUsingSeal:(NSString *) sealId;
-(BOOL) isTrackingFriendByName:(NSString *) friendName;
-(void) trackUnprovenFriendByName:(NSString *) friendName andInitializeWith:(CS_tapi_user_looked_up *) userInfo;
@end
