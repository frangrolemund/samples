//
//  CS_twitterFeed_transient_mining.h
//  ChatSeal
//
//  Created by Francis Grolemund on 8/5/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CS_feedTypeTwitter;
@class CS_twitterFeed;
@class CS_tapi_statuses_timeline_base;
@interface CS_twitterFeed_transient_mining : NSObject
-(id) initWithFeedDirectory:(NSURL *) u;
-(void) markFriendshipsAreUpdated;
-(BOOL) hasHighPriorityWorkToPerformInFeed:(CS_twitterFeed *) feed;
-(BOOL) processFeedTypeRequestsUsingFeed:(CS_twitterFeed *) feed asOnlyHighPriority:(BOOL) onlyHighPrio;
-(void) completeTimelineProcesing:(CS_tapi_statuses_timeline_base *) api usingFeed:(CS_twitterFeed *) feed;
-(void) setRealtimeMiningIsOnline:(BOOL) isOnline;
-(void) setRealtimeContentEventsProcessed:(NSUInteger) numProcessed;
-(void) markTimelineRangeAsProcessedFromAPI:(CS_tapi_statuses_timeline_base *) api;
-(void) prefillSharedContentDuringCreationFromMining:(CS_twitterFeed_transient_mining *) miningOther;
@end
