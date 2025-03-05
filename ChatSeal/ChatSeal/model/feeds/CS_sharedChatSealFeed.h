//
//  CS_sharedChatSealFeed.h
//  ChatSeal
//
//  Created by Francis Grolemund on 5/27/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

// ...for connecting the feed to its type.
@protocol ChatSealFeedDelegate <NSObject>
-(ChatSealFeedType *) typeForFeed:(ChatSealFeed *) feed;
-(ChatSealFeedCollector *) collectorForFeed:(ChatSealFeed *) feed;
-(BOOL) canSaveFeed:(ChatSealFeed *) feed;
-(CS_netThrottledAPIFactory *) apiFactoryForFeed:(ChatSealFeed<ChatSealFeedImplementation> *) feed;
@end

// ...returning a packed message for further processing.
@interface CS_packedMessagePost : NSObject
-(id) initWithSafeEntry:(NSString *) e andSeal:(NSString *) sealId andIsOwner:(BOOL) isOwned;
@property (nonatomic, readonly) NSString *safeEntryId;
@property (nonatomic, readonly) NSString *sealId;
@property (nonatomic, readonly) BOOL     isSealOwner;
@property (nonatomic, retain) NSData     *packedMessage;
@end

@interface ChatSealFeedProgress (internal)
-(void) setOverallProgress:(double) val;
-(void) setScanProgress:(double) val;
-(void) setPostingProgress:(double) val;
-(BOOL) checkComplete:(double) val;
@end

@class CS_postedMessageState;
@class ChatSealMessage;
@interface ChatSealPostedMessageProgress (internal)
-(id) initWithState:(CS_postedMessageState *) state;
-(void) setMessageId:(NSString *)mid andEntryId:(NSString *) eid;
-(void) markAsFakeCompleted;
@end

// ...interact internally with the feed.
@interface ChatSealFeed (shared) <ChatSealFeedDelegate, ChatSealFeedImplementation>
-(id) initWithAccountDerivedId:(NSString *) sFeedId andDelegate:(id<ChatSealFeedDelegate>) d;
-(id) initWithAccountDerivedId:(NSString *) sFeedId andDelegate:(id<ChatSealFeedDelegate>) d andDictionary:(NSDictionary *) dict;
-(void) destroyFeedPersistentData;
-(NSURL *) feedDirectoryURL;
-(BOOL) saveConfigurationWithError:(NSError **) err;
-(void) saveDeferredUntilEndOfCycle;
-(BOOL) saveIfDeferredWorkIsPendingWithError:(NSError **) err;
-(NSDate *) lastRequestDateForCategory:(cs_cnt_throttle_category_t) category;
-(BOOL) setUserId:(NSString *) uid withError:(NSError **) err;
-(void) setDelegate:(id<ChatSealFeedDelegate>)delegate;
-(void) setPasswordExpired:(BOOL) isExpired;
-(NSArray *) pendingSafeEntriesToPost;
-(void) deleteStateForSafeEntries:(NSArray *) arrSafeEntries;
-(void) moveSafeEntriesToPostponed:(NSArray *) arrEntries;
-(void) movePostponedSafeEntriesToPending:(NSArray *) arrEntries;
-(BOOL) shouldPermitServiceWithExpiredPassword;
-(void) setPermitTemporaryAccessWithExpiredPassword;
-(void) setBackingIdentityIsAvailable:(BOOL) isAvailable;
-(BOOL) isBackingIdentityAvailable;
-(void) fireFriendshipUpdateNotification;

-(BOOL) hasCapacityForAPIByName:(NSString *) name withEvenDistribution:(BOOL)evenlyDistributed;
-(BOOL) hasCapacityForAPIByName:(NSString *) name withEvenDistribution:(BOOL) evenlyDistributed andAllowAnyCategory:(BOOL) allowAny;
-(CS_netFeedAPI *) apiForName:(NSString *) name andReturnWasThrottled:(BOOL *) wasThrottled withError:(NSError **) err;
-(CS_netFeedAPI *) evenlyDistributedApiForName:(NSString *) name andReturnWasThrottled:(BOOL *) wasThrottled withError:(NSError **) err;
-(CS_netFeedAPI *) apiForExistingRequest:(NSURLRequest *) req;
-(void) throttleAPIForOneCycle:(CS_netFeedAPI *) api;
-(void) reconfigureThrottleForAPIByName:(NSString *) name toLimit:(NSUInteger) limit andRemaining:(NSUInteger) numRemaining;
-(BOOL) addCollectorRequestWithAPI:(CS_netFeedAPI *) api andReturnWasThrottled:(BOOL *) wasThrottled withError:(NSError **) err;
-(CS_packedMessagePost *) generateNextPendingMessagePost;
-(void) movePendingSafeEntryToDelivering:(NSString *) safeEntryId;
-(void) moveDeliveringSafeEntry:(NSString *) safeEntryId toCompleted:(BOOL) isCompleted;
-(BOOL) isTrackingSafeEntry:(NSString *) safeEntryId;
-(NSUInteger) numberOfMessagesPosted;
-(void) updateSafeEntry:(NSString *) safeEntryId postProgressWithSent:(int64_t) numSent andTotalToSend:(int64_t) toSend;
-(void) incrementMessageCountReceived;
-(void) beginPendingDownloadForTag:(NSString *) tag;
-(void) updatePendingDownloadForTag:(NSString *) tag withProgressRecv:(int64_t) numRecv andTotalToRecv:(int64_t) toRecv;
-(void) completePendingDownloadForTag:(NSString *) tag;
-(void) requestHighPriorityAttention;
-(void) notifyMajorFeedUpdateHasOccurredAndShouldUpdateBadge:(BOOL) updateBadge;
-(ChatSealMessage *) importMessageIntoVault:(NSData *) dMessage andReturnOriginFeed:(ChatSealFeedLocation **) originFeed withError:(NSError **) err;
@end