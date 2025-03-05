//
//  CS_twmMiningStatsHistory.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/9/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twmMiningStatsHistory.h"
#import "CS_tapi_statuses_timeline_base.h"

//  THREADING-NOTES:
//  - no locking is provided.

// - constants
static const NSUInteger CS_TWM_MH_MAX_HISTORY = 5;
static NSString        *CS_TWM_MH_KEY_HIST    = @"h";

/*******************************
 CS_twmMiningStatsHistory
 *******************************/
@implementation CS_twmMiningStatsHistory
/*
 *  Object attributes.
 */
{
    NSMutableArray *maHistory;
    NSTimeInterval tLastUpdate;         //  persistence is probably unnecessary for now.
}

/*
 *  Return the maximum number of items this history object will save.
 */
+(NSUInteger) maximumHistory
{
    return CS_TWM_MH_MAX_HISTORY;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        maHistory   = nil;
        tLastUpdate = 0;
    }
    return self;
}

/*
 *  Initialize from an archive.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        maHistory   = [[aDecoder decodeObjectForKey:CS_TWM_MH_KEY_HIST] retain];
        tLastUpdate = 0;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [maHistory release];
    maHistory = nil;
    [super dealloc];
}

/*
 *  Encode to an archive.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:maHistory forKey:CS_TWM_MH_KEY_HIST];
}

/*
 *  Create a copy.
 */
-(id) copyWithZone:(NSZone *)zone
{
    CS_twmMiningStatsHistory *msCopy = [[CS_twmMiningStatsHistory allocWithZone:zone] init];
    if (maHistory && msCopy) {
        msCopy->maHistory = [[NSMutableArray alloc] init];
        for (CS_tapi_tweetRange *tr in maHistory) {
            [msCopy->maHistory addObject:[CS_tapi_tweetRange rangeForMin:tr.minTweetId andMax:tr.maxTweetId]];
        }
    }
    return msCopy;
}

/*
 *  Return an array of all the processed items.
 */
-(NSArray *) processedHistory
{
    return [NSArray arrayWithArray:maHistory];
}

/*
 *  Update the history based on the content we found.
 */
-(void) updateHistoryWithRange:(CS_tapi_tweetRange *) range fromAPI:(CS_tapi_statuses_timeline_base *) api
{
    if (!range) {
        return;
    }
    
    if (!maHistory) {
        maHistory = [[NSMutableArray alloc] init];
    }
    
    // - by tracking the last update, we can use it to determine mining priority.  This does not
    //   need to be persisted!
    tLastUpdate = [[NSDate date] timeIntervalSinceReferenceDate];
    
    // - when the API is provided and successful, we can derive some information from how it was requested to expand our range
    //   based on what was returned.
    // - REMEMBER: an empty range is valid and indicates nothing exists there.
    if ([api isAPISuccessful]) {
        // - if the API specified a max_id, in timelines that means return all tweets up to and including this maximum id.  If it wasn't
        //   part of the range, then it doesn't exist and we can still assume it has been processed.
        if (api.maxTweetId) {
            if (!range.maxTweetId || [CS_tapi_tweetRange rangeValueCompare:api.maxTweetId withValue:range.maxTweetId] == NSOrderedDescending) {
                range.maxTweetId = api.maxTweetId;
            }
        }
        
        // - when there is no minimum range, we can assume the range was empty, in which case we should try to determine
        //   if the API offers any clues because we may have asked for something and nothing existed.
        if (!range.minTweetId || (api.sinceTweetId && [CS_tapi_tweetRange rangeValueCompare:api.sinceTweetId withValue:range.minTweetId] == NSOrderedAscending)) {
            if (api.sinceTweetId) {
                // - the since-id is exclusive, so we can only assume the one _after_ this one is the first one ruled-out.
                unsigned long long lValue = [CS_tapi_tweetRange tweetValueFromId:api.sinceTweetId];
                if (lValue != ULLONG_MAX) {
                    lValue++;
                    range.minTweetId = [NSString stringWithFormat:@"%llu", lValue];
                }
            }
            else {
                // - with no since_id, we can assume that there is nothing before our low range because nothing was returned.
                range.minTweetId = [CS_tapi_tweetRange absoluteMinimum];
            }
        }
    }
    
    // - no range, then don't record anything.
    if (!range.minTweetId || !range.maxTweetId) {
        return;
    }
    
    // - we can look at these arguments and learn a lot about the activity of the timeline because we know what we asked for and
    //   how much was returned.  That information will allow us to merge content accordingly.
    // - the goal is to keep a complete range of history that describes what has been retrieved so that if we have an opportunity
    //   to look at prior stuff, we can do so at some point.
    NSUInteger insertIndex     = 0;
    CS_tapi_tweetRange *trLast = nil;
    for (insertIndex = 0; insertIndex < [maHistory count]; insertIndex++) {
        CS_tapi_tweetRange *trCur = [maHistory objectAtIndex:insertIndex];
        if ([range isAfter:trCur]) {
            break;
        }
        trLast = trCur;
    }
    
    // - when the new item is not first, ensure it shouldn't be merged with
    //   the one that comes before it.
    if (trLast && ([trLast isIntersectedBy:range] || [trLast isAdjacentToAndPreceding:range])) {
        insertIndex--;
        [trLast unionWith:range];
        range = trLast;
    }
    else {
        [maHistory insertObject:range atIndex:insertIndex];
    }
    
    // - now merge the item with the rest.
    NSMutableIndexSet *mis = nil;
    for (NSUInteger i = insertIndex + 1; i < [maHistory count]; i++) {
        CS_tapi_tweetRange *trCur = [maHistory objectAtIndex:i];
        if (![range isIntersectedBy:trCur] && ![range isAdjacentToAndPreceding:trCur]) {
            break;
        }
        
        if (!mis) {
            mis = [NSMutableIndexSet indexSet];
        }
        
        [range unionWith:trCur];
        [mis addIndex:i];
    }
    
    // - delete anything we don't need any longer.
    if (mis) {
        [maHistory removeObjectsAtIndexes:mis];
    }
    
    // - now make sure that we don't track anything beyond the maximum.   The notion here is that the maximum history
    //   accounts for content we may have seen many minutes ago and is probably not available on Twitter any more anyway since
    //   we can only go back so far.  
    NSUInteger count = [maHistory count];
    if (count > CS_TWM_MH_MAX_HISTORY) {
        [maHistory removeObjectsInRange:NSMakeRange(CS_TWM_MH_MAX_HISTORY, count - CS_TWM_MH_MAX_HISTORY)];
    }
}

/*
 *  Given the API, populate a request that will get the most recent content not seen on the timeline.
 */
-(void) populateAPIForMostRecentRequest:(CS_tapi_statuses_timeline_base *) api
{
    if ([maHistory count]) {
        CS_tapi_tweetRange *tr = [maHistory firstObject];
        api.sinceTweetId       = tr.maxTweetId;
    }
}

/*
 *  Given the API, populate a requst that will fill-in gaps in our understanding for past data primarily, but
 *  fall-back to forward requests when we know everything.
 *  - return NO whenever we fallback to the forward request.
 */
-(BOOL) populateAPIForPastGapsOrMostRecentRequest:(CS_tapi_statuses_timeline_base *) api
{
    // - if there is no history, then just do a standard forward request.
    NSUInteger count = [maHistory count];
    if (count) {
        CS_tapi_tweetRange *trFirst = [maHistory firstObject];
        unsigned long long lMinFirst = [CS_tapi_tweetRange tweetValueFromId:trFirst.minTweetId];
        if (count == 1) {
            // - when there is only one, we may default to moving forward or grabbing
            //   everything up to the minimum we previously retrieved.
            if ([trFirst.minTweetId isEqualToString:[CS_tapi_tweetRange absoluteMinimum]]) {
                api.sinceTweetId = trFirst.maxTweetId;
            }
            else {
                // - return less than the full range because the query is inclusive of the last item and that
                //   will give us a false positive about the range's quality when we go to merge into history.
                api.maxTweetId = [NSString stringWithFormat:@"%llu", lMinFirst ? lMinFirst - 1 : 0];
                return YES;
            }
        }
        else {
            // - when there are two, we're shooting to fill the gap between the two items.
            CS_tapi_tweetRange *trSecond = [maHistory objectAtIndex:1];
            api.maxTweetId               = [NSString stringWithFormat:@"%llu", lMinFirst ? lMinFirst - 1 : 0];
            api.sinceTweetId             = trSecond.maxTweetId;
            return YES;
        }
    }
    return NO;
}

/*
 *  Determine if there are gaps in our understanding.
 */
-(BOOL) hasPriorGapsInHistory
{
    if ([maHistory count]) {
        CS_tapi_tweetRange *tr = [maHistory firstObject];
        if (![tr.minTweetId isEqualToString:[CS_tapi_tweetRange absoluteMinimum]]) {
            return YES;
        }
    }
    return NO;
}

/*
 *  Return the time that has elapsed since we updated.
 */
-(NSTimeInterval) timeIntervalSinceLastUpdate
{
    return [[NSDate date] timeIntervalSinceReferenceDate] - tLastUpdate;
}
@end
