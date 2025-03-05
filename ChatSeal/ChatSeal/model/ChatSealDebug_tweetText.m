//
//  ChatSealDebug_tweetText.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/31/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "ChatSealDebug_tweetText.h"
#include "ChatSeal.h"
#include "CS_twitterFeed_tweetText.h"

/*************************
 ChatSealDebug_tweetText
 *************************/
@implementation ChatSealDebug_tweetText
#ifdef CHATSEAL_DEBUGGING_ROUTINES

/*
 *  Verify that the routines work correctly when presented with invalid text.
 */
+(BOOL) runTest_3BadTextValidation
{
    NSLog(@"TWEET-TEXT:  TEST-03:  Starting bad text validation.");

    NSLog(@"TWEET-TEXT:  TEST-03:  - verifying that nils and empty strings are not accepted for text gen.");
    if ([CS_twitterFeed_tweetText tweetTextForSealId:@"hQnnHHJ0UvHU3kHPJ_5u4pLqFHvQHSDgcS81VzRxB3A" andNumericUserId:nil]) {
        NSLog(@"ERROR: generated text with bad content.");
        return NO;
    }

    if ([CS_twitterFeed_tweetText tweetTextForSealId:@"hQnnHHJ0UvHU3kHPJ_5u4pLqFHvQHSDgcS81VzRxB3A" andNumericUserId:@""]) {
        NSLog(@"ERROR: generated text with bad content.");
        return NO;
    }
    
    if ([CS_twitterFeed_tweetText tweetTextForSealId:@"" andNumericUserId:@"2397823004"]) {
        NSLog(@"ERROR: generated text with bad content.");
        return NO;
    }

    if ([CS_twitterFeed_tweetText tweetTextForSealId:nil andNumericUserId:@"2397823004"]) {
        NSLog(@"ERROR: generated text with bad content.");
        return NO;
    }

    if ([CS_twitterFeed_tweetText tweetTextForSealId:nil andNumericUserId:nil]) {
        NSLog(@"ERROR: generated text with bad content.");
        return NO;
    }

    if ([CS_twitterFeed_tweetText tweetTextForSealId:@"" andNumericUserId:@""]) {
        NSLog(@"ERROR: generated text with bad content.");
        return NO;
    }
    
    NSLog(@"TWEET-TEXT:  TEST-03:  - verifying that nils and empty strings are not accepted for text verification.");
    NSString *sampleText = @"#BePersonal @lPUl:";
    NSString *sampleId   = @"2397823004";
    if ([CS_twitterFeed_tweetText isTweetWithText:sampleText possibilyUsefulFromNumericUserId:nil]) {
        NSLog(@"ERROR: false positive identification.");
        return NO;
    }

    if ([CS_twitterFeed_tweetText isTweetWithText:sampleText possibilyUsefulFromNumericUserId:@""]) {
        NSLog(@"ERROR: false positive identification.");
        return NO;
    }
    
    if ([CS_twitterFeed_tweetText isTweetWithText:nil possibilyUsefulFromNumericUserId:sampleId]) {
        NSLog(@"ERROR: false positive identification.");
        return NO;
    }

    if ([CS_twitterFeed_tweetText isTweetWithText:@"" possibilyUsefulFromNumericUserId:sampleId]) {
        NSLog(@"ERROR: false positive identification.");
        return NO;
    }
    
    NSLog(@"TWEET-TEXT:  TEST-03:  - verifying the bogus strings are caught.");
    if ([CS_twitterFeed_tweetText isTweetWithText:@"#ABCDEFGHIJ @lPUl:"possibilyUsefulFromNumericUserId:sampleId]) {
        NSLog(@"ERROR: false positive identification.");
        return NO;
    }
    
    if ([CS_twitterFeed_tweetText isTweetWithText:@"#BEPersonal @lPUl:"possibilyUsefulFromNumericUserId:sampleId]) {
        NSLog(@"ERROR: false positive identification.");
        return NO;
    }

    if ([CS_twitterFeed_tweetText isTweetWithText:@"BePersonal @lPUl:"possibilyUsefulFromNumericUserId:sampleId]) {
        NSLog(@"ERROR: false positive identification.");
        return NO;
    }

    if ([CS_twitterFeed_tweetText isTweetWithText:@"@lPUl:"possibilyUsefulFromNumericUserId:sampleId]) {
        NSLog(@"ERROR: false positive identification.");
        return NO;
    }

    if ([CS_twitterFeed_tweetText isTweetWithText:@"#BePersonal @:"possibilyUsefulFromNumericUserId:sampleId]) {
        NSLog(@"ERROR: false positive identification.");
        return NO;
    }

    if ([CS_twitterFeed_tweetText isTweetWithText:@"#BePersonal #lPUl:" possibilyUsefulFromNumericUserId:sampleId]) {
        NSLog(@"ERROR: false positive identification.");
        return NO;
    }
    
    NSLog(@"TWEET-TEXT:  TEST-03:  Bad text validation completed.");
    return YES;
}

/*
 *  Perform mass validation with many different ids and the same seals.
 */
+(BOOL) runTest_2DifferentIdsWithSeals:(NSArray *) arrSeals
{
    NSLog(@"TWEET-TEXT:  TEST-02:  Starting multi-id validation.");
    static const NSUInteger NUM_ITER = 10000;
    NSLog(@"TWEET-TEXT:  TEST-02:  - checking seals each with %u different id_strs.", (unsigned) NUM_ITER);
    for (NSString *sid in arrSeals) {
        for (NSUInteger i = 0; i < NUM_ITER; i++) {
            if (i > 0 && (i + 1) % 1000 == 0) {
                NSLog(@"TWEET-TEXT:  TEST-02:  - completed %u iterations.", (unsigned) i+1);
            }
            unsigned val = (unsigned) rand();
            NSString *id_str = [NSString stringWithFormat:@"%u", val];
            NSString *goodText = [CS_twitterFeed_tweetText tweetTextForSealId:sid andNumericUserId:id_str];
            if (!goodText) {
                NSLog(@"ERROR: failed to generate tweet text.");
                return NO;
            }
            
            if (![CS_twitterFeed_tweetText isTweetWithText:goodText possibilyUsefulFromNumericUserId:id_str]) {
                NSLog(@"ERROR: failed to confirm the text was good.");
                return NO;
            }
            
            // ...Twitter has started adding the image URL to the end of the tweet automatically.
            NSString *augmentedText = [NSString stringWithFormat:@"%@ http://t.co/m26vJVPUyp", goodText];
            if (![CS_twitterFeed_tweetText isTweetWithText:augmentedText possibilyUsefulFromNumericUserId:id_str]) {
                NSLog(@"ERROR: failed to confirm the augmented text.");
                return NO;
            }
            
            // ...I'm going to assume that content being inserted before is also possible at some point.
            NSString *prefixedText = [NSString stringWithFormat:@"asdfasdfasdfsdf%@", goodText];
            if (![CS_twitterFeed_tweetText isTweetWithText:prefixedText possibilyUsefulFromNumericUserId:id_str]) {
                NSLog(@"ERROR: failed to confirm the prefixed text.");
                return NO;
            }
                        
            NSString *clippedText = [goodText substringToIndex:[goodText length] - 2];
            if ([CS_twitterFeed_tweetText isTweetWithText:clippedText possibilyUsefulFromNumericUserId:id_str]) {
                NSLog(@"ERROR: failed to detect clipped text.");
                return NO;
            }
            
            //  ********
            //  NOTE: these next two tests could theoretically pass if we found one of the very unlikely collisions and
            //        that would be fine for the most part because collisions, while rare, are expected.  Just verify that
            //        they really are valid collisions.  The seal id in those cases would be important.
            //  ********
            id_str = [NSString stringWithFormat:@"%u", val+1];
            if ([CS_twitterFeed_tweetText isTweetWithText:goodText possibilyUsefulFromNumericUserId:id_str]) {
                NSLog(@"ERROR: failed to detect that a modified id was a problem.");
                return NO;
            }
                        
            if ([id_str length] > 1) {
                id_str = [id_str substringToIndex:[id_str length]-2];
            }
            if ([CS_twitterFeed_tweetText isTweetWithText:goodText possibilyUsefulFromNumericUserId:id_str]) {
                NSLog(@"ERROR: failed to detect that a modified id was a problem.");
                return NO;
            }
        }
    }
    
    NSLog(@"TWEET-TEXT:  TEST-02:  Multi-id validation completed.");
    return YES;
}

/*
 *  Ensure we can generate and decode tweets.
 */
+(BOOL) runTest_1SimpleTextBehaviorWithSeals:(NSArray *) arrSeals
{
    NSLog(@"TWEET-TEXT:  TEST-01:  Starting simple tweet text verification.");
    
    NSString *sample_id = @"2397823004";
    NSString *bad_id    = @"5397823004";
    for (NSString *sid in arrSeals) {
        NSLog(@"TWEET-TEXT:  TEST-01:  - verifying with seal %@", sid);
        NSString *goodText = [CS_twitterFeed_tweetText tweetTextForSealId:sid andNumericUserId:sample_id];
        if (!goodText) {
            NSLog(@"ERROR: failed to generate tweet text.");
            return NO;
        }
        NSLog(@"TWEET-TEXT:  TEST-01:  - generated tweet text as '%@'", goodText);
        if (![CS_twitterFeed_tweetText isTweetWithText:goodText possibilyUsefulFromNumericUserId:sample_id]) {
            NSLog(@"ERROR: failed to confirm the text was good.");
            return NO;
        }

        if ([CS_twitterFeed_tweetText isTweetWithText:goodText possibilyUsefulFromNumericUserId:bad_id]) {
            NSLog(@"ERROR: an invalid id gave a false positive.");
            return NO;
        }
        NSLog(@"TWEET-TEXT:  TEST-01:  - tweet text has been confirmed.");
    }
    NSLog(@"TWEET-TEXT:  TEST-01:  Simple tweet text verification completed.");
    return YES;
}

#endif

/*
 *  Verify that the tweet text processing work is correct.
 */
+(void) beginTweetTextTesting
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    // - predictability
    srand(32);
    
    // - these seals must exist because the validation checks the vault for confirmation.
    NSArray *arrSeals = [RealSecureImage availableSealsWithError:nil];
    if (!arrSeals.count) {
        NSLog(@"TWEET-TEXT: ERROR: There are no seals available for processing.");
        return;
    }
    
    if ([ChatSealDebug_tweetText runTest_1SimpleTextBehaviorWithSeals:arrSeals] &&
        [ChatSealDebug_tweetText runTest_2DifferentIdsWithSeals:arrSeals] &&
        [ChatSealDebug_tweetText runTest_3BadTextValidation]) {
        NSLog(@"MINING-HIST:  All tracking tests completed successfully.");
    }
    else {
        NSLog(@"TWEET-TEXT: ERROR: Test failure.");
    }
#endif
}
@end
