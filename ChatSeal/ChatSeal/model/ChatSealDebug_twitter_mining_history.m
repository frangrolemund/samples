//
//  ChatSealDebug_twitter_mining_history.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/11/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "ChatSealDebug_twitter_mining_history.h"
#import "ChatSeal.h"
#import "CS_twmMiningStatsHistory.h"
#import "CS_tapi_tweetRange.h"
#import "CS_tapi_statuses_timeline_base.h"

#ifdef CHATSEAL_DEBUGGING_ROUTINES
@interface CS_tapi_auto_good_timeline_call : CS_tapi_statuses_timeline_base
@end
#endif

/************************************
 ChatSealDebug_twitter_mining_history
 ************************************/
@implementation ChatSealDebug_twitter_mining_history
#ifdef CHATSEAL_DEBUGGING_ROUTINES

/*
 *  Verify the range-expansion behavior when passing an API that has content.
 */
+(BOOL) runTest_2RangeExpansion
{
    NSLog(@"MINING-HIST:  TEST-02:  Starting range expansion testing.");
    
    // - make an API we can use for passing state through.
    CS_tapi_statuses_timeline_base *api     = [[[CS_tapi_statuses_timeline_base alloc] initWithCreatorHandle:nil inCategory:CS_CNT_THROTTLE_TRANSIENT] autorelease];
    
    // - for each of these, we're going to verify that ranges are expanded predictably based on the content in the API.
    @autoreleasepool {
        CS_twmMiningStatsHistory *hist = [[[CS_twmMiningStatsHistory alloc] init] autorelease];
        
        NSLog(@"MINING-HIST:  TEST-02:  - checking the max id is expanded with an empty range.");
        CS_tapi_tweetRange *tr = [CS_tapi_tweetRange rangeForMin:@"1234" andMax:@"2345"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        
        CS_tapi_statuses_timeline_base *apiGood = [[[CS_tapi_auto_good_timeline_call alloc] initWithCreatorHandle:nil inCategory:CS_CNT_THROTTLE_TRANSIENT] autorelease];
        apiGood.maxTweetId                      = @"9951";
        tr = [CS_tapi_tweetRange emptyRange];
        [hist updateHistoryWithRange:tr fromAPI:apiGood];
        
        NSArray *a = [hist processedHistory];
        if ([a count] != 1) {
            NSLog(@"ERROR: the processed history is the wrong length.");
            return NO;
        }
        
        tr = [a firstObject];
        if (![tr.minTweetId isEqualToString:[CS_tapi_tweetRange absoluteMinimum]] ||
            ![tr.maxTweetId isEqualToString:@"9951"]) {
            NSLog(@"ERROR: the returned aggregate item is wrong.");
            return NO;
        }
    }
    
    @autoreleasepool {
        CS_twmMiningStatsHistory *hist = [[[CS_twmMiningStatsHistory alloc] init] autorelease];
        
        NSLog(@"MINING-HIST:  TEST-02:  - checking no change is made when there is no max tweet and an empty range.");
        CS_tapi_tweetRange *tr = [CS_tapi_tweetRange rangeForMin:@"1234" andMax:@"2345"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        
        CS_tapi_statuses_timeline_base *apiGood = [[[CS_tapi_auto_good_timeline_call alloc] initWithCreatorHandle:nil inCategory:CS_CNT_THROTTLE_TRANSIENT] autorelease];
        tr = [CS_tapi_tweetRange emptyRange];
        [hist updateHistoryWithRange:tr fromAPI:apiGood];
        
        NSArray *a = [hist processedHistory];
        if ([a count] != 1) {
            NSLog(@"ERROR: the processed history is the wrong length.");
            return NO;
        }
        
        tr = [a firstObject];
        if (![tr.minTweetId isEqualToString:@"1234"] ||
            ![tr.maxTweetId isEqualToString:@"2345"]) {
            NSLog(@"ERROR: the returned aggregate item is wrong.");
            return NO;
        }
    }
    
    @autoreleasepool {
        CS_twmMiningStatsHistory *hist = [[[CS_twmMiningStatsHistory alloc] init] autorelease];
        
        NSLog(@"MINING-HIST:  TEST-02:  - checking the max id is expanded but a since_id that less than actual is not");
        CS_tapi_tweetRange *tr = [CS_tapi_tweetRange rangeForMin:@"1234" andMax:@"2345"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        
        CS_tapi_statuses_timeline_base *apiGood = [[[CS_tapi_auto_good_timeline_call alloc] initWithCreatorHandle:nil inCategory:CS_CNT_THROTTLE_TRANSIENT] autorelease];
        apiGood.maxTweetId                      = @"4567";
        apiGood.sinceTweetId                    = @"4000";
        tr = [CS_tapi_tweetRange rangeForMin:@"3456" andMax:@"4200"];
        [hist updateHistoryWithRange:tr fromAPI:apiGood];
        
        NSArray *a = [hist processedHistory];
        if ([a count] != 2) {
            NSLog(@"ERROR: the processed history is the wrong length.");
            return NO;
        }
        
        tr = [a objectAtIndex:0];
        if (![tr.minTweetId isEqualToString:@"3456"] ||
            ![tr.maxTweetId isEqualToString:@"4567"]) {
            NSLog(@"ERROR: the returned first item is wrong.");
            return NO;
        }
        
        tr = [a objectAtIndex:1];
        if (![tr.minTweetId isEqualToString:@"1234"] ||
            ![tr.maxTweetId isEqualToString:@"2345"]) {
            NSLog(@"ERROR: the returned last item is wrong.");
            return NO;
        }
    }
    
    @autoreleasepool {
        CS_twmMiningStatsHistory *hist = [[[CS_twmMiningStatsHistory alloc] init] autorelease];
        
        NSLog(@"MINING-HIST:  TEST-02:  - checking that a since_id expands the low-end");
        CS_tapi_tweetRange *tr = [CS_tapi_tweetRange rangeForMin:@"1234" andMax:@"2345"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        
        CS_tapi_statuses_timeline_base *apiGood = [[[CS_tapi_auto_good_timeline_call alloc] initWithCreatorHandle:nil inCategory:CS_CNT_THROTTLE_TRANSIENT] autorelease];
        apiGood.sinceTweetId                    = @"250";
        tr = [CS_tapi_tweetRange rangeForMin:@"750" andMax:@"1234"];
        [hist updateHistoryWithRange:tr fromAPI:apiGood];
        
        NSArray *a = [hist processedHistory];
        if ([a count] != 1) {
            NSLog(@"ERROR: the processed history is the wrong length.");
            return NO;
        }
        
        tr = [a firstObject];
        if (![tr.minTweetId isEqualToString:@"251"] ||
            ![tr.maxTweetId isEqualToString:@"2345"]) {
            NSLog(@"ERROR: the returned aggregate item is wrong.");
            return NO;
        }
    }
    
    
    NSLog(@"MINING-HIST:  TEST-02:  Range expansion testing completed.");
    return YES;
}

/*
 *  Ensure that we can track tweet histories accurately.
 */
+(BOOL) runTest_1SimpleTracking
{
    NSLog(@"MINING-HIST:  TEST-01:  Starting simple history tracking.");
    
    // - make an API we can use for passing state through.
    CS_tapi_statuses_timeline_base *api = [[[CS_tapi_statuses_timeline_base alloc] initWithCreatorHandle:nil inCategory:CS_CNT_THROTTLE_TRANSIENT] autorelease];
    
    // - for each of these, we're going to build an object and then add content and see how it gets merged.
    @autoreleasepool {
        CS_twmMiningStatsHistory *hist = [[[CS_twmMiningStatsHistory alloc] init] autorelease];
        
        NSLog(@"MINING-HIST:  TEST-01:  - checking for the most basic aggregation.");
        CS_tapi_tweetRange *tr = [CS_tapi_tweetRange rangeForMin:@"1234" andMax:@"2345"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"2345" andMax:@"3456"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"3456" andMax:@"4567"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        
        NSArray *a = [hist processedHistory];
        if ([a count] != 1) {
            NSLog(@"ERROR: the processed history is the wrong length.");
            return NO;
        }
        
        tr = [a firstObject];
        if (![tr.minTweetId isEqualToString:@"1234"] ||
            ![tr.maxTweetId isEqualToString:@"4567"]) {
            NSLog(@"ERROR: the returned aggregate item is wrong.");
            return NO;
        }
    }
    
    @autoreleasepool {
        CS_twmMiningStatsHistory *hist = [[[CS_twmMiningStatsHistory alloc] init] autorelease];
        
        NSLog(@"MINING-HIST:  TEST-01:  - checking for non-intersecting ranges.");
        CS_tapi_tweetRange *tr = [CS_tapi_tweetRange rangeForMin:@"1234" andMax:@"2344"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"2346" andMax:@"3455"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"3457" andMax:@"4567"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        
        NSArray *a = [hist processedHistory];
        if ([a count] != 3) {
            NSLog(@"ERROR: the processed history is the wrong length.");
            return NO;
        }        
    }
    
    @autoreleasepool {
        CS_twmMiningStatsHistory *hist = [[[CS_twmMiningStatsHistory alloc] init] autorelease];
        
        NSLog(@"MINING-HIST:  TEST-01:  - checking for out of sequence intersecting ranges.");
        CS_tapi_tweetRange *tr = [CS_tapi_tweetRange rangeForMin:@"3455" andMax:@"4567"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"2345" andMax:@"3455"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"1234" andMax:@"2345"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        
        NSArray *a = [hist processedHistory];
        if ([a count] != 1) {
            NSLog(@"ERROR: the processed history is the wrong length.");
            return NO;
        }
        
        tr = [a firstObject];
        if (![tr.minTweetId isEqualToString:@"1234"] ||
            ![tr.maxTweetId isEqualToString:@"4567"]) {
            NSLog(@"ERROR: the returned aggregate item is wrong.");
            return NO;
        }
    }
    
    @autoreleasepool {
        CS_twmMiningStatsHistory *hist = [[[CS_twmMiningStatsHistory alloc] init] autorelease];
        
        NSLog(@"MINING-HIST:  TEST-01:  - checking for out of sequence complex intersecting ranges.");
        CS_tapi_tweetRange *tr = [CS_tapi_tweetRange rangeForMin:@"1234" andMax:@"2000"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"2345" andMax:@"3000"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"3456" andMax:@"5678"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"1450" andMax:@"2500"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"2590" andMax:@"4000"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        
        NSArray *a = [hist processedHistory];
        if ([a count] != 1) {
            NSLog(@"ERROR: the processed history is the wrong length.");
            return NO;
        }
        
        tr = [a firstObject];
        if (![tr.minTweetId isEqualToString:@"1234"] ||
            ![tr.maxTweetId isEqualToString:@"5678"]) {
            NSLog(@"ERROR: the returned aggregate item is wrong.");
            return NO;
        }
    }
    
    @autoreleasepool {
        CS_twmMiningStatsHistory *hist = [[[CS_twmMiningStatsHistory alloc] init] autorelease];
        
        NSLog(@"MINING-HIST:  TEST-01:  - checking for history limit.");
        CS_tapi_tweetRange *tr = [CS_tapi_tweetRange rangeForMin:@"1234" andMax:@"2344"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"2345" andMax:@"3455"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"3457" andMax:@"4566"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"4568" andMax:@"5677"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"5679" andMax:@"6788"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"6790" andMax:@"7890"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        
        NSArray *a = [hist processedHistory];
        if ([a count] != [CS_twmMiningStatsHistory maximumHistory]) {
            NSLog(@"ERROR: the processed history is the wrong length.");
            return NO;
        }
    }
    
    @autoreleasepool {
        CS_twmMiningStatsHistory *hist = [[[CS_twmMiningStatsHistory alloc] init] autorelease];
        
        NSLog(@"MINING-HIST:  TEST-01:  - varying width numeric values.");
        CS_tapi_tweetRange *tr = [CS_tapi_tweetRange rangeForMin:@"99012" andMax:@"100055"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"1" andMax:@"10"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"9701" andMax:@"9801"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"212" andMax:@"404"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"25" andMax:@"69"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"501" andMax:@"609"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        
        NSArray *a = [hist processedHistory];
        if ([a count] != [CS_twmMiningStatsHistory maximumHistory]) {
            NSLog(@"ERROR: the processed history is the wrong length.");
            return NO;
        }
        
        tr = [a objectAtIndex:4];
        if (![tr.minTweetId isEqualToString:@"25"] || ![tr.maxTweetId isEqualToString:@"69"]) {
            NSLog(@"ERROR: the fifth item is bad.");
            return NO;
        }
        
        tr = [a objectAtIndex:3];
        if (![tr.minTweetId isEqualToString:@"212"] || ![tr.maxTweetId isEqualToString:@"404"]) {
            NSLog(@"ERROR: the fourth item is bad.");
            return NO;
        }
        
        tr = [a objectAtIndex:2];
        if (![tr.minTweetId isEqualToString:@"501"] || ![tr.maxTweetId isEqualToString:@"609"]) {
            NSLog(@"ERROR: the third item is bad.");
            return NO;
        }
        
        tr = [a objectAtIndex:1];
        if (![tr.minTweetId isEqualToString:@"9701"] || ![tr.maxTweetId isEqualToString:@"9801"]) {
            NSLog(@"ERROR: the second item is bad.");
            return NO;
        }

        tr = [a objectAtIndex:0];
        if (![tr.minTweetId isEqualToString:@"99012"] || ![tr.maxTweetId isEqualToString:@"100055"]) {
            NSLog(@"ERROR: the first item is bad.");
            return NO;
        }
    }
    
    @autoreleasepool {
        CS_twmMiningStatsHistory *hist = [[[CS_twmMiningStatsHistory alloc] init] autorelease];
        
        NSLog(@"MINING-HIST:  TEST-01:  - complex range intersections.");
        CS_tapi_tweetRange *tr = [CS_tapi_tweetRange rangeForMin:@"9999" andMax:@"10000"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"1" andMax:@"2"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"7" andMax:@"8"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"9200" andMax:@"9998"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"33" andMax:@"44"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"20" andMax:@"23"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"9997" andMax:@"9999"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        tr = [CS_tapi_tweetRange rangeForMin:@"8" andMax:@"60"];
        [hist updateHistoryWithRange:tr fromAPI:api];
        
        NSArray *a = [hist processedHistory];
        if ([a count] != 3) {
            NSLog(@"ERROR: the processed history is the wrong length.");
            return NO;
        }
        
        tr = [a objectAtIndex:2];
        if (![tr.minTweetId isEqualToString:@"1"] || ![tr.maxTweetId isEqualToString:@"2"]) {
            NSLog(@"ERROR: the third item is bad.");
            return NO;
        }
        
        tr = [a objectAtIndex:1];
        if (![tr.minTweetId isEqualToString:@"7"] || ![tr.maxTweetId isEqualToString:@"60"]) {
            NSLog(@"ERROR: the second item is bad.");
            return NO;
        }
        
        tr = [a objectAtIndex:0];
        if (![tr.minTweetId isEqualToString:@"9200"] || ![tr.maxTweetId isEqualToString:@"10000"]) {
            NSLog(@"ERROR: the first item is bad.");
            return NO;
        }
    }
    
    NSLog(@"MINING-HIST:  TEST-01:  Simple history tracking completed.");
    return YES;
}

#endif

/*
 *  Test that the mining history does the right thing.
 */
+(void) beginTwitterMiningHistoryTesting
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    if ([ChatSealDebug_twitter_mining_history runTest_1SimpleTracking] &&
        [ChatSealDebug_twitter_mining_history runTest_2RangeExpansion]) {
        NSLog(@"MINING-HIST:  All tracking tests completed successfully.");
    }
    else {
        NSLog(@"MINING-HIST: ERROR: Test failure.");
    }
#endif
}
@end


#ifdef CHATSEAL_DEBUGGING_ROUTINES
/*********************************
 CS_tapi_auto_good_timeline_call
 *********************************/
@implementation CS_tapi_auto_good_timeline_call
/*
 *  Initialize the object.
 */
-(id) initWithCreatorHandle:(CS_netFeedCreatorDelegateHandle *)cdh inCategory:(cs_cnt_throttle_category_t)category
{
    self = [super initWithCreatorHandle:cdh inCategory:category];
    if (self) {
        [super markStatusAsGood];
    }
    return self;
}
@end
#endif

