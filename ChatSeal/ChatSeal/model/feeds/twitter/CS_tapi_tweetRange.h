//
//  CS_tapi_tweetRange.h
//  ChatSeal
//
//  Created by Francis Grolemund on 8/9/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CS_tapi_tweetRange : NSObject <NSCoding>
+(CS_tapi_tweetRange *) emptyRange;
+(CS_tapi_tweetRange *) rangeForMin:(NSString *) minTweetId andMax:(NSString *) maxTweetId;
+(NSString *) absoluteMinimum;
+(NSComparisonResult) rangeValueCompare:(NSString *) v1 withValue:(NSString *) v2;
+(unsigned long long) tweetValueFromId:(NSString *) tweetId;
-(BOOL) isAfter:(CS_tapi_tweetRange *) trOther;
-(BOOL) isIntersectedBy:(CS_tapi_tweetRange *) trOther;
-(BOOL) isAdjacentToAndPreceding:(CS_tapi_tweetRange *) trOther;
-(void) unionWith:(CS_tapi_tweetRange *) trOther;
-(BOOL) isEqualToRange:(CS_tapi_tweetRange *) trOther;
@property (nonatomic, retain) NSString *minTweetId;
@property (nonatomic, retain) NSString *maxTweetId;
@end
