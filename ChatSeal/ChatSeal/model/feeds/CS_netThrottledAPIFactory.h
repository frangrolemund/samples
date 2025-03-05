//
//  CS_netThrottledAPIFactory.h
//  ChatSeal
//
//  Created by Francis Grolemund on 3/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CS_centralNetworkThrottle.h"

// NOTE:  The intent is that custom types generate one of these on request, but the feeds
//        never have to explicitly manage them.  The base class for the feed will take
//        care of the lifetime of this factory.
@class CS_netFeedAPI;
@interface CS_netThrottledAPIFactory : NSObject
-(id) initWithNetworkThrottle:(CS_centralNetworkThrottle *) throttle;
-(BOOL) hasStatsFileDefined;
-(BOOL) isOpen;
-(BOOL) setThrottleStatsFile:(NSURL *) statsFile withError:(NSError **) err;
-(CS_netFeedAPI *) apiForName:(NSString *) name andRequestEvenDistribution:(BOOL) evenlyDistributed andReturnWasThrottled:(BOOL *) wasThrottled withError:(NSError **) err;
-(CS_netFeedAPI *) apiForName:(NSString *) name andReturnWasThrottled:(BOOL *) wasThrottled withError:(NSError **) err;
-(CS_netFeedAPI *) apiForExistingRequest:(NSURLRequest *) req;
-(NSDate *) lastRequestDateForCategory:(cs_cnt_throttle_category_t) category;
-(BOOL) hasCapacityForAPIByName:(NSString *) name withEvenDistribution:(BOOL) evenlyDistributed andAllowAnyCategory:(BOOL) allowAny;
-(void) throttleAPIForOneCycle:(CS_netFeedAPI *) api;
-(void) reconfigureThrottleForAPIByName:(NSString *) name toLimit:(NSUInteger) limit andRemaining:(NSUInteger) numRemaining;

// - feed types will use this API to define all their throttle limits.
-(void) setThrottleLimitAdjustmentPercentage:(float) pct;
-(void) addAPIThrottleDefinitionForClass:(Class) c inCategory:(cs_cnt_throttle_category_t) category withLimit:(NSUInteger) limit perInterval:(NSTimeInterval) interval;
-(void) addAPIThrottleDefinitionForClass:(Class) c inCategory:(cs_cnt_throttle_category_t) category withConcurrentLimit:(NSUInteger) limit;
@end
