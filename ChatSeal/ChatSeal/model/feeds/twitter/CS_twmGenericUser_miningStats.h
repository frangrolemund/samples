//
//  CS_twmGenericUser_miningStats.h
//  ChatSeal
//
//  Created by Francis Grolemund on 8/8/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CS_twitterFeed;
@class CS_tapi_friendship_state;
@class CS_tapi_statuses_timeline_base;
@interface CS_twmGenericUser_miningStats : NSObject <NSCoding>
-(id) initWithScreenName:(NSString *) screenName;
-(id) initWithMiningStats:(CS_twmGenericUser_miningStats *) stats;
-(NSString *) screenName;
-(void) assignPostLoadScreenName:(NSString *) screenName;
-(NSUInteger) statPriority;
-(NSUInteger) statPopularity;
-(void) updateFriendshipState:(CS_tapi_friendship_state *) friendshipState;
-(BOOL) performMiningRequestsUsingFeed:(CS_twitterFeed *) feed;
-(BOOL) performOptionalMiningRequestsUsingFeed:(CS_twitterFeed *) feed;
-(BOOL) completeTimelineAPI:(CS_tapi_statuses_timeline_base *) api usingFeed:(CS_twitterFeed *) feed;
-(NSRecursiveLock *) statsLock;
-(void) populateAPIForMostRecentRequest:(CS_tapi_statuses_timeline_base *) api;
-(BOOL) populateAPIForPastGapsOrMostRecentRequest:(CS_tapi_statuses_timeline_base *) api;
-(BOOL) hasPriorGapsInHistory;
-(void) updateOnlyHistoryWithAPI:(CS_tapi_statuses_timeline_base *) api;
@end
