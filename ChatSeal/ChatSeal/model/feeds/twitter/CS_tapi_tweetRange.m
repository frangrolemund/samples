//
//  CS_tapi_tweetRange.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/9/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tapi_tweetRange.h"

// - forward declarations
/**************************
 CS_tapi_tweetRange
 **************************/
@implementation CS_tapi_tweetRange
/*
 *  Object attributes.
 */
{
}
@synthesize minTweetId;
@synthesize maxTweetId;

/*
 *  Return an empty range object.
 */
+(CS_tapi_tweetRange *) emptyRange
{
    return [[[CS_tapi_tweetRange alloc] init] autorelease];
}

/*
 *  Return a filled-in range object.
 */
+(CS_tapi_tweetRange *) rangeForMin:(NSString *) minTweetId andMax:(NSString *) maxTweetId
{
    CS_tapi_tweetRange *tr = [[[CS_tapi_tweetRange alloc] init] autorelease];
    tr.minTweetId          = minTweetId;
    tr.maxTweetId          = maxTweetId;
    return tr;
}

/*
 *  Standardized comparison for these values.
 */
+(NSComparisonResult) rangeValueCompare:(NSString *) v1 withValue:(NSString *) v2
{
    if (v1 && v2) {
        return [v1 compare:v2 options:NSNumericSearch];
    }
    else if (!v1 && !v2) {
        return NSOrderedSame;
    }
    else if (!v1) {
        return NSOrderedAscending;
    }
    else {
        return NSOrderedDescending;
    }
}

/*
 *  Twitter timeline requests only accept a since_id greater than or equal to this value.
 */
+(NSString *) absoluteMinimum
{
    return @"1";
}

/*
 *  Convert the tweet id to a value.
 */
+(unsigned long long) tweetValueFromId:(NSString *) tweetId
{
    if (tweetId) {
        unsigned long long lValue = 0;
        NSScanner *scanner        = [NSScanner scannerWithString:tweetId];
        if ([scanner scanUnsignedLongLong:&lValue]) {
            return lValue;
        }
    }
    return ULLONG_MAX;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        minTweetId = nil;
        maxTweetId = nil;
    }
    return self;
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        minTweetId = [[aDecoder decodeObject] retain];
        maxTweetId = [[aDecoder decodeObject] retain];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [minTweetId release];
    minTweetId = nil;
    
    [maxTweetId release];
    maxTweetId = nil;
    
    [super dealloc];
}

/*
 *  Encode an object to an archive.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:minTweetId];
    [aCoder encodeObject:maxTweetId];
}

/*
 *  Return a description.
 */
-(NSString *) description
{
    return [NSString stringWithFormat:@"range:%@ --> %@", self.maxTweetId, self.minTweetId];
}

/*
 *  Determines if this range occurs after the other one, which is only
 *  when the maximum tweet is after the other maximum.
 */
-(BOOL) isAfter:(CS_tapi_tweetRange *) trOther
{
    if ([CS_tapi_tweetRange rangeValueCompare:self.maxTweetId withValue:trOther.maxTweetId] != NSOrderedAscending) {
        return YES;
    }
    return NO;
}

/*
 *  Determines if this range is intersected by the other one.
 */
-(BOOL) isIntersectedBy:(CS_tapi_tweetRange *) trOther
{
    if ([CS_tapi_tweetRange rangeValueCompare:self.minTweetId withValue:trOther.maxTweetId] != NSOrderedDescending &&
        [CS_tapi_tweetRange rangeValueCompare:self.maxTweetId withValue:trOther.maxTweetId] != NSOrderedAscending) {
        return YES;
    }
    return NO;
}

/*
 *  Determine if this range immediately precedes another one.
 */
-(BOOL) isAdjacentToAndPreceding:(CS_tapi_tweetRange *) trOther
{
    unsigned long long lMyMin    = [CS_tapi_tweetRange tweetValueFromId:self.minTweetId];
    unsigned long long lTheirMax = [CS_tapi_tweetRange tweetValueFromId:trOther.maxTweetId];
    if (lMyMin != ULLONG_MAX && lTheirMax != ULLONG_MAX && lMyMin == lTheirMax + 1) {
        return YES;
    }
    return NO;
}

/*
 *  Combine the contents of these two ranges and store the result in 
 *  this range.
 */
-(void) unionWith:(CS_tapi_tweetRange *) trOther
{
    if (!trOther) {
        return;
    }
    
    if ([CS_tapi_tweetRange rangeValueCompare:self.maxTweetId withValue:trOther.maxTweetId] == NSOrderedAscending) {
        self.maxTweetId = trOther.maxTweetId;
    }
    
    if ([CS_tapi_tweetRange rangeValueCompare:self.minTweetId withValue:trOther.minTweetId] == NSOrderedDescending) {
        self.minTweetId = trOther.minTweetId;
    }
}

/*
 *  Check for equality.
 */
-(BOOL) isEqualToRange:(CS_tapi_tweetRange *) trOther;
{
    if ([CS_tapi_tweetRange rangeValueCompare:self.minTweetId withValue:trOther.minTweetId] == NSOrderedSame &&
        [CS_tapi_tweetRange rangeValueCompare:self.maxTweetId withValue:trOther.maxTweetId] == NSOrderedSame) {
        return YES;
    }
    return NO;
}

@end
