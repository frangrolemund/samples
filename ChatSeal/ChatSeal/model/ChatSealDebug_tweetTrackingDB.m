//
//  ChatSealDebug_tweetTrackingDB.m
//  ChatSeal
//
//  Created by Francis Grolemund on 5/27/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "ChatSealDebug_tweetTrackingDB.h"
#import "ChatSeal.h"
#import "CS_tweetTrackingDB.h"

/********************************
 ChatSealDebug_tweetTrackingDB
 ********************************/
@implementation ChatSealDebug_tweetTrackingDB
#ifdef CHATSEAL_DEBUGGING_ROUTINES

/*
 *  Exercise tweet tracking by adding a lot of content and then moving between sets and interspacing a lot of set deletions.
 */
+(BOOL) runTest_2ExtensiveTracking
{
    NSLog(@"TWEET-TRACK:  TEST-02:  Starting extensive tracking testing.");
    
    @autoreleasepool {
        CS_tweetTrackingDB *db           = [[[CS_tweetTrackingDB alloc] init] autorelease];
        NSMutableDictionary *mdPending   = [NSMutableDictionary dictionary];
        NSMutableSet        *setComplete = [NSMutableSet set];
        
        //  - the idea is that we're going to run a large number of iterations in order to be sure about this.
        srand(32);      // - reproducible
        static const NSUInteger PSDEBUG_TTDB_NUM_ITER = 5000;
        static const NSUInteger PSDEBUG_TTDB_PAD_COUNT = 17;
        NSLog(@"TWEET-TRACK:  TEST-02:  - beginning %lu iterations.", (unsigned long) PSDEBUG_TTDB_NUM_ITER);
        for (NSUInteger i = 0; i < PSDEBUG_TTDB_NUM_ITER; i++) {
            // - always add to the sets.
            int randId           = rand() + (int) PSDEBUG_TTDB_NUM_ITER;
            NSString *newTweetId = [NSString stringWithFormat:@"%llu", (unsigned long long) randId];
            if (i % 2 == 0) {
                [db setTweetAsCompleted:newTweetId];
                [setComplete addObject:newTweetId];
            }
            else {
                NSNumber *nCompareTo = [NSNumber numberWithInteger:randId / 7];
                [db setTweet:newTweetId asPendingWithContext:nCompareTo];
                [mdPending setObject:nCompareTo forKey:newTweetId];
            }
            
            // ...ensure we can find what we just added
            if ([db count] != [mdPending count] + [setComplete count]){
                NSLog(@"ERROR: The tracking database count does not equal the expected count (%lu != %lu).", (unsigned long) [db count],
                      (unsigned long) [mdPending count] + [setComplete count]);
                return NO;
            }
            
            if (![db isTweetTracked:newTweetId]) {
                NSLog(@"ERROR: The tweet we just added (%@) is not tracked.", newTweetId);
                return NO;
            }
            
            // - add an increasing tweet id to the candidate content.
            NSString *tid = [NSString stringWithFormat:@"%u", (unsigned) i];
            if (![db flagTweet:tid asCandidateFromFriend:@"Fran" withPhoto:nil andProvenUseful:(i % 2) == 0 ? YES : NO andForceIt:NO]) {
                NSLog(@"ERROR: Failed to flag a pending tweet.");
                return NO;
            }
            
            // - verify that everything we added, we can retrieve.
            for (NSString *sComplete in setComplete) {
                if (![db isTweetTracked:sComplete]) {
                    NSLog(@"ERROR: Failed to find the tracked tweet %@", sComplete);
                    return NO;
                }
            }
            
            for (NSString *sPending in mdPending.allKeys) {
                if (![db isTweetTracked:sPending]) {
                    NSLog(@"ERROR: Failed to find the tracked tweet %@", sPending);
                    return NO;
                }
                NSNumber *nContext = (NSNumber *) [db contextForPendingTweet:sPending];
                if (!nContext) {
                    NSLog(@"ERROR: Failed to find context for the pending tweet %@", sPending);
                    return NO;
                }
                NSNumber *nComp = [mdPending objectForKey:sPending];
                if (![nContext isEqualToNumber:nComp]) {
                    NSLog(@"ERROR: Failed to find good context for pending tweet %@", sPending);
                    return NO;
                }
            }
            
            if ((i+1)%1000 == 0) {
                NSLog(@"TWEET-TRACK:  TEST-02:  ...inserted %u items (%u pending, %u complete).", (unsigned)i, (unsigned) [mdPending count], (unsigned) [setComplete count]);
            }
            
            // - for the first half, don't do anything extra
            if (i < (PSDEBUG_TTDB_NUM_ITER >> 1)) {
                continue;
            }
            
            // - delete some items if we're on a boundary
            if (i % 100 == 0) {
                NSUInteger toDelete = 2;
                if ([db count] > PSDEBUG_TTDB_PAD_COUNT) {
                    toDelete = PSDEBUG_TTDB_PAD_COUNT;
                }
                for (NSUInteger j = 0; j < toDelete; j++) {
                    if (j % 2 == 0) {
                        if ([mdPending count]) {
                            NSUInteger item = ((NSUInteger) rand() % [mdPending count]);
                            NSString *sToDelete = [[mdPending allKeys] objectAtIndex:item];
                            [db untrackTweet:sToDelete];
                            [mdPending removeObjectForKey:sToDelete];
                        }
                    }
                    else {
                        if ([setComplete count]) {
                            NSArray *arrAllItems = [setComplete allObjects];
                            NSUInteger item = ((NSUInteger) rand() % [arrAllItems count]);
                            NSString *sToDelete = [arrAllItems objectAtIndex:item];
                            [db untrackTweet:sToDelete];
                            [setComplete removeObject:sToDelete];
                        }
                    }
                }
            }
            
            // - shift some if we're on a boundary
            if (i % 66 == 0) {
                if ([mdPending count] && [setComplete count]) {
                    NSUInteger item     = ((NSUInteger) rand()) % [mdPending count];
                    NSString *sPending  = [[[mdPending allKeys] objectAtIndex:item] retain];
                    [mdPending removeObjectForKey:sPending];
                    
                    item                = ((NSUInteger) rand()) % [setComplete count];
                    NSString *sComplete = [[[setComplete allObjects] objectAtIndex:item] retain];
                    NSScanner *scan = [NSScanner scannerWithString:sComplete];
                    [setComplete removeObject:sComplete];
                    unsigned long long ull = 0;
                    if (![scan scanUnsignedLongLong:&ull]) {
                        NSLog(@"ERROR: Failed to scan the tweet tweet %@", sComplete);
                        return NO;
                    }
                    
                    [db setTweetAsCompleted:sPending];
                    [setComplete addObject:sPending];
                    [sPending release];
                    
                    NSNumber *n = [NSNumber numberWithInteger:(int)ull/7];
                    [db setTweet:sComplete asPendingWithContext:n];
                    [mdPending setObject:n forKey:sComplete];
                    [sComplete release];
                }
            }
        }
    
        NSLog(@"TWEET-TRACK:  TEST-02:  - encoding/decoding the database.");
        NSData *dEncoded = [NSKeyedArchiver archivedDataWithRootObject:db];
        if (!dEncoded) {
            NSLog(@"ERROR: Failed to encode the database.");
            return NO;
        }
        
        CS_tweetTrackingDB *dbDecoded = [NSKeyedUnarchiver unarchiveObjectWithData:dEncoded];
        if (!dbDecoded) {
            NSLog(@"ERROR: Failed to unarchive the database.");
            return NO;
        }
        
        if ([dbDecoded count] != [db count]) {
            NSLog(@"ERROR: The decoded number of tweets is not the same.");
            return NO;
        }
        db = dbDecoded;
        dbDecoded = nil;
        
        NSLog(@"TWEET-TRACK:  TEST-02:  - verifying our candidate list.");
        NSArray *arrCand = [db allCandidates].allKeys;
        if ([arrCand count] == 0 || [arrCand count] > [CS_tweetTrackingDB maxCandidateTweets]) {
            NSLog(@"ERROR: The candidate list is maxed out and shouldn't be.");
            return NO;
        }
        
        // ...get the last N and sort them in descending order.
        arrCand = [arrCand sortedArrayUsingComparator:^NSComparisonResult(NSString *k1, NSString *k2) {
            return [k2 compare:k1 options:NSNumericSearch];
        }];
        
        // ...mark some as pending so they no longer appear.
        NSUInteger cur = PSDEBUG_TTDB_NUM_ITER - 1;
        for (NSUInteger i = 0; i < [arrCand count]; i++) {
            if (cur % 7 == 0) {
                NSString *tid = [arrCand objectAtIndex:i];
                [db setTweet:tid asPendingWithContext:@"foo"];
                [mdPending setObject:@"foo" forKey:tid];
            }
            cur--;
        }
        
        arrCand = [db allCandidates].allKeys;
        arrCand = [arrCand sortedArrayUsingComparator:^NSComparisonResult(NSString *k1, NSString *k2) {
            return [k2 compare:k1 options:NSNumericSearch];
        }];
        
        cur = PSDEBUG_TTDB_NUM_ITER - 1;
        for (NSUInteger i = 0; i < [arrCand count]; i++) {
            NSString *actual   = [arrCand objectAtIndex:i];
            NSString *expected = [NSString stringWithFormat:@"%u", (unsigned) cur];
            if (cur % 7 == 0) {
                if ([actual isEqualToString:expected]) {
                    NSLog(@"ERROR: the missing candidates exist!");
                    return NO;
                }
                cur--;
                expected = [NSString stringWithFormat:@"%u", (unsigned) cur];
            }
            if (![expected isEqualToString:actual]) {
                NSLog(@"ERROR: The value is wrong at index %u.", (unsigned) i);
                return NO;
            }
            cur--;
        }
        
        __block BOOL candFailed = NO;
        [[db allCandidates] enumerateKeysAndObjectsUsingBlock:^(NSString *tid, CS_candidateTweetContext *ctx, BOOL *stop) {
            unsigned long val = strtoul([tid UTF8String], NULL, 10);
            if (ctx.isProvenUseful != ((val % 2) == 0 ? YES : NO)) {
                NSLog(@"ERROR: The useful flag for %@ is wrong.", tid);
                *stop = YES;
                candFailed = YES;
            }
        }];
        
        if (candFailed) {
            return NO;
        }
        
        NSLog(@"TWEET-TRACK:  TEST-02:  - deleting all the tweets we tracked.");
        if (![db count]) {
            NSLog(@"ERROR: Did not find any remaining tweets!");
            return NO;
        }
        BOOL doPending = YES;
        NSUInteger numDeleted = 0;
        while ([mdPending count] || [setComplete count]) {
            // - delete an item.
            if (doPending) {
                if ([mdPending count]) {
                    NSArray *arrKeys = [mdPending allKeys];
                    NSUInteger idx   = ((NSUInteger) rand()) % [arrKeys count];
                    NSString *sId    = [arrKeys objectAtIndex:idx];
                    [db untrackTweet:sId];
                    [mdPending removeObjectForKey:sId];
                }
            }
            else {
                if ([setComplete count]) {
                    NSArray *arrKeys = [setComplete allObjects];
                    NSUInteger idx   = ((NSUInteger) rand()) % [arrKeys count];
                    NSString *sid    = [arrKeys objectAtIndex:idx];
                    [db untrackTweet:sid];
                    [setComplete removeObject:sid];
                }
            }
            numDeleted++;
            
            // - make sure the remaining items all line up.
            for (NSString *sPending in mdPending.allKeys) {
                if (![db isTweetTracked:sPending]) {
                    NSLog(@"ERROR: Failed to find a known pending tweet id %@ after %lu deletions occurred.", sPending, (unsigned long) numDeleted);
                    return NO;
                }
            }
            
            for (NSString *sCompleted in setComplete.allObjects) {
                if (![db isTweetTracked:sCompleted]) {
                    NSLog(@"ERROR: Failed to find a known completed tweet id %@ after %lu deletions occurred.", sCompleted, (unsigned long) numDeleted);
                    return NO;
                }
            }
            
            doPending = !doPending;
        }
        
        NSLog(@"TWEET-TRACK:  TEST-02:  - verifying we have no tweets remaining.");
        NSUInteger remain = [db count];
        if (remain != 0) {
            NSLog(@"ERROR: There are still %lu tweets in the database!", (unsigned long) remain);
            return NO;
        }
    }

    NSLog(@"TWEET-TRACK:  TEST-02:  All tests completed successfully.");
    return YES;
}

/*
 *  The most basic test of tweet tracking in the more complicated part of that object.
 */
+(BOOL) runTest_1SimpleCompletion
{
    NSLog(@"TWEET-TRACK:  TEST-01:  Beginning simple completion set testing.");
    
    @autoreleasepool {
        CS_tweetTrackingDB *db = [[[CS_tweetTrackingDB alloc] init] autorelease];

        // - add some tweets to consider
        NSLog(@"TWEET-TRACK:  TEST-01:  - adding sample tweets to consider");
        [db setTweetAsCompleted:@"1234"];
        [db setTweetAsCompleted:@"1230"];
        [db setTweetAsCompleted:@"2999"];
        
        [db setTweetAsCompleted:@"1230"];
        [db setTweetAsCompleted:@"2999"];
        [db setTweetAsCompleted:@"1234"];
        
        // - check that they all exist.
        NSLog(@"TWEET-TRACK:  TEST-01:  - checking that they now exist");
        if ([db count] != 3) {
            NSLog(@"ERROR: The number of tracked tweets is incorrect.");
            return NO;
        }
        
        if (![db isTweetTracked:@"1230"] ||
            ![db isTweetTracked:@"1234"] ||
            ![db isTweetTracked:@"2999"]) {
            NSLog(@"ERROR: Failed to find one of our tweets.");
            return NO;
        }

        NSLog(@"TWEET-TRACK:  TEST-01:  - deleting the tweets and re-adding some replacements");
        [db untrackTweet:@"1234"];
        if (![db isTweetTracked:@"1230"] ||
            ![db isTweetTracked:@"2999"]) {
            NSLog(@"ERROR: Failed to keep the tweet database consistent after deletion.");
            return NO;
        }
        [db setTweetAsCompleted:@"1300"];
        [db untrackTweet:@"1230"];
        [db setTweetAsCompleted:@"1111"];
        [db untrackTweet:@"2999"];
        [db setTweetAsCompleted:@"9999"];
        
        NSLog(@"TWEET-TRACK:  TEST-01:  - making sure our tweets still exist");
        if (![db isTweetTracked:@"1300"] ||
            ![db isTweetTracked:@"1111"] ||
            ![db isTweetTracked:@"9999"]) {
            NSLog(@"ERROR: one or more of the new tweets are not tracked.");
            return NO;
        }
        
        NSLog(@"TWEET-TRACK:  TEST-01:  - checking the final count");
        if ([db count] != 3) {
            NSLog(@"ERROR: the number of tracked tweets is incorrect.");
            return NO;
        }
    }
    
    NSLog(@"TWEET-TRACK:  TEST-01:  All tests completed successfully.");
    return YES;
}
#endif
/*
 *  Test the tweet tracking database to ensure it remains consistent through many updates.
 */
+(void) beginTweetTrackingTesting
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    if ([ChatSealDebug_tweetTrackingDB runTest_1SimpleCompletion] &&
        [ChatSealDebug_tweetTrackingDB runTest_2ExtensiveTracking]) {
        NSLog(@"TWEET-TRACK: All tracking tests completed successfully.");
    }
    else {
        NSLog(@"TWEET-TRACK: ERROR: Test failure.");
    }
#endif
}
@end
