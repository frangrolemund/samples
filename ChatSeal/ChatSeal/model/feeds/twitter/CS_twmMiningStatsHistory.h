//
//  CS_twmMiningStatsHistory.h
//  ChatSeal
//
//  Created by Francis Grolemund on 8/9/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CS_tapi_statuses_timeline_base;
@class CS_tapi_tweetRange;
@interface CS_twmMiningStatsHistory : NSObject <NSCoding, NSCopying>
+(NSUInteger) maximumHistory;
-(NSArray *) processedHistory;
-(void) updateHistoryWithRange:(CS_tapi_tweetRange *) range fromAPI:(CS_tapi_statuses_timeline_base *) api;
-(void) populateAPIForMostRecentRequest:(CS_tapi_statuses_timeline_base *) api;
-(BOOL) populateAPIForPastGapsOrMostRecentRequest:(CS_tapi_statuses_timeline_base *) api;
-(BOOL) hasPriorGapsInHistory;
-(NSTimeInterval) timeIntervalSinceLastUpdate;
@end
