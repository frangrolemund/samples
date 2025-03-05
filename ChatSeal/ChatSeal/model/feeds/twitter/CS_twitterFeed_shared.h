//
//  CS_twitterFeed_shared.h
//  ChatSeal
//
//  Created by Francis Grolemund on 5/31/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeed.h"
#import "ChatSealFeedCollector.h"
#import "CS_feedShared.h"
#import "CS_twitterFeedAPI.h"
#import "CS_sessionManager.h"
#import "UIFormattedTwitterFeedAddressView.h"
#import "ChatSeal.h"
#import "CS_tweetTrackingDB.h"
#import "CS_feedTypeTwitter.h"
#import "CS_tapi_shared.h"
#import "CS_twitterFeed_transient_mining.h"

// - forward declarations
@class CS_twitterFeed;
@class CS_tapi_friendship_state;
@protocol CS_twitterFeed_highPrio_task <NSObject>
-(BOOL) tryToProcessTaskForFeed:(CS_twitterFeed *) feed;                                                            // - this is where you try to process as much as possible.
-(void) mergeInWorkFromTask:(id<CS_twitterFeed_highPrio_task>) task;                                                // - for your own task type, you should try to pull the content out of the other.
-(BOOL) hasCompletedTask;                                                                                           // - is there anything remaining in this task?
-(BOOL) isEqualToTask:(id<CS_twitterFeed_highPrio_task>) task;                                                      // - do these two tasks refer to the exact same operation on the same entity?
@optional
-(BOOL) isRedundantForState:(CS_tapi_friendship_state *) state forFriend:(NSString *) screenName;                   // - should this task be removed because the state already reflects it is done?
-(BOOL) reconcileTaskIntentInActualState:(CS_tapi_friendship_state *) state forFriend:(NSString *) screenName;      // - adjust the state when this task is going to modify it.
@end

@protocol CS_twitterFeed_highPrioPersist_task <CS_twitterFeed_highPrio_task, NSCoding>
@end

@class CS_twitterFeed_pending_db;
@class CS_twitterFeed_history_item;
@interface CS_twitterFeed (internal)
+(NSString *) tokenForRequest:(NSURLRequest *) req;
-(void) setLastToken:(NSString *) token;
-(NSString *) lastToken;
-(time_t) mediaUploadTimeout;
-(void) setMediaUploadTimeout:(time_t) timeout;
-(CS_feedTypeTwitter *) twitterType;
-(BOOL) inPostPreparation;
-(void) setInPostPreparation:(BOOL) ipp;
-(CS_tapi_user *) tapiRealtime;
-(void) setTapiRealtime:(CS_tapi_user *) tu;
-(NSMutableDictionary *) mdConfiguration;
-(void) setPendingDB:(CS_twitterFeed_pending_db *) pdb;
-(CS_twitterFeed_pending_db *) pendingDB;
-(BOOL) isMediaUploadThrottled;
-(void) updateLastUploadTime;
-(BOOL) isTwitterUploadThrottled;
-(BOOL) hasRetrievedMyRateLimits;
-(void) setHasRetrievedMyRateLimits;
-(void) resetStaleFriendFlag;
-(NSMutableArray *) highPriorityTasksAsPersistent:(BOOL) persistent;
-(void) saveHighPriorityTask:(id<CS_twitterFeed_highPrio_task>) task andStartImmediately:(BOOL) startImmediately;
-(void) saveHighPriorityTask:(id<CS_twitterFeed_highPrio_task>) task thatActsUponFriend:(NSString *) screenName andStartImmediately:(BOOL) startImmediately;
-(void) cancelHighPriorityTask:(id<CS_twitterFeed_highPrio_task>) task;
-(void) addPostedTweetHistoryForSeal:(NSString *) sealId withTweet:(NSString *) tweetId andOwnerScreenName:(NSString *) screenName andAsSealOwner:(BOOL) isOwner;
-(void) addConsumerHistoryForSeal:(NSString *) sealId withTweet:(NSString *) tweetId andOwnerScreenName:(NSString *) screenName;
-(NSArray *) tweetHistoryForSeal:(NSString *) sealId andOwnerScreenName:(NSString *) screenName;
-(CS_twitterFeed_history_item *) priorTweetFromOwnerOfSeal:(NSString *) sealId;
-(void) discardConsumerHistoryForSeal:(NSString *) sealId;
-(void) moveDeliveringSafeEntry:(NSString *)safeEntryId asTweetId:(NSString *) tweetId toCompleted:(BOOL)isCompleted;
-(CS_twitterFeed_transient_mining *) activeMiningState;
-(NSDictionary *) statesForAllReachableFriends;
-(NSString *) numericTwitterId;
-(void) setNumericTwitterId:(NSString *) id_str;
-(BOOL) hasVerifiedMyTwitterId;
-(void) setHasVerifiedMyTwitterId;
-(BOOL) isUserTimelineRequestAllowed:(CS_tapi_statuses_user_timeline *) api;
-(void) completeUserTimelineRequest:(CS_tapi_statuses_user_timeline *) api;
-(void) setFriendsCount:(NSInteger) friendsCount;
-(BOOL) hasFriendsCount;
-(NSInteger) friendsCount;
@end

@interface CS_twitterFeed (pending)
-(BOOL) hasHighPriorityDownloads;
-(void) configurePendingTweetProgress;
-(void) saveTweetForProcessing:(NSString *) tweetId withPhoto:(NSURL *) uPhoto fromUser:(NSString *) userId andFlagAsKnownUseful:(BOOL) flagKnownUseful;
-(void) discardTweetForProcessing:(NSString *) tweetId;
-(BOOL) schedulePendingTweetLookupIfPossibleWithItems:(NSArray *) arrTweetIds;
-(BOOL) tryToProcessPendingInCategory:(cs_cnt_throttle_category_t) cat;
-(BOOL) tryToCompletePendingWithAPI:(CS_twitterFeedAPI *) api;
-(void) updateProgressForPendingItemAPI:(CS_tapi_download_image *) api;
-(void) updateMessageStateIfPossibleForVerifyAPI:(CS_tapi_download_image_toverify *) api;
-(void) completePendingTweetLookupsWithAPI:(CS_tapi_statuses_lookup *) api;
-(NSArray *) extractPendingItemsWithFullIdentification:(BOOL) fullyIdentified;
-(void) addPendingItemsToFeed:(NSArray *) arrPending;
@end

@interface CS_twitterFeed (upload)
-(BOOL) processFeedRequestsForUpload;
-(void) apiWasScheduledForUpload:(CS_netFeedAPI *)api;
-(void) completeFeedRequestForUpload:(CS_twitterFeedAPI *) api;
@end

@interface CS_twitterFeed (download)
-(BOOL) processFeedRequestsForDownload;
-(void) completeFeedRequestForDownload:(CS_twitterFeedAPI *) api;
@end

@interface CS_twitterFeed (transient)
-(BOOL) processFeedRequestsForTransientOnlyInHighPriority:(BOOL) onlyHighPrio;
-(void) requestCredsIfNecessary;
-(void) requestRateStatusIfNecessary;
-(void) tryToProcessHighPriorityWhenPersistent:(BOOL) doPersistent;
-(void) completeFeedRequestForTransient:(CS_twitterFeedAPI *) api;
-(void) markTimelineRangeAsProcessedFromAPI:(CS_tapi_statuses_timeline_base *) api;
@end

@interface CS_twitterFeed (realtime) <CS_tapi_userDelegate>
-(BOOL) processFeedRequestsForRealtime;
-(void) completeFeedRequestForRealtime:(CS_twitterFeedAPI *) api;
@end

