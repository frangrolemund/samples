//
//  CS_sharedChatSealFeedCollector.h
//  ChatSeal
//
//  Created by Francis Grolemund on 5/27/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

@class ACAccountStore;
@class ChatSealMessageEntry;
@class PSCentralNetworkThrottle;

@interface ChatSealFeedCollector (shared)
+(void) issueUpdateNotificationForFeed:(ChatSealFeed *) feed;
-(CS_centralNetworkThrottle *) centralThrottle;
-(ACAccountStore *) accountStore;
-(BOOL) addRequestAPI:(CS_netFeedAPI *) api forFeed:(ChatSealFeed<ChatSealFeedImplementation> *) feed inCategory:(cs_cnt_throttle_category_t) category
andReturnWasThrottled:(BOOL *) wasThrottled withError:(NSError **) err;
-(NSString *) saveAndReturnPostedSafeEntry:(ChatSealMessageEntry *) entry withError:(NSError **) err;
-(CS_postedMessage *) postedMessageForSafeEntry:(NSString *) safeEntryId;
-(void) fillPostedMessageProgressItems:(NSArray *) arr;
-(void) fillPostedMessageProgressItem:(ChatSealPostedMessageProgress *) prog;
-(void) scheduleHighPriorityUpdateIfPossible;
-(void) cancelAllRequestsForFeed:(ChatSealFeed *) feed;
-(void) trackMessageImportEvent;
@end