//
//  CS_twitterFeed_tweetText.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/7/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeed_tweetText.h"
#import "ChatSeal.h"
#import "CS_sha.h"

//  NOTE: with this particular algorithm, I tried to pick a bit length that was unlikely to produce erroneous
//        collisions without going nuts and overloading my Tweet text.  The idea is to minimize the cases where
//        we try downloading something unnecessarily because of an unlucky combination in one of our friends' feeds.
//        - in this case there are going to be four base-64 characters taken from the hash.

// - constants
static NSString             *CS_TWF_TT_STD_PREFIX   = @"#BePersonal @";
static NSUInteger           CS_TWF_TT_FILTER_CHARS  = 4;
static NSUInteger           CS_TWF_TT_MIN_TWEET_LEN = 0;

// - forward declarations
@interface CS_twitterFeed_tweetText (internal)
+(NSString *) hintFilterForSealId:(NSString *) sid andUserId:(NSString *) id_str;
@end

/*******************************
 CS_twitterFeed_tweetText
 *******************************/
@implementation CS_twitterFeed_tweetText
/*
 *  Initialize this module.
 */
+(void) initialize
{
    CS_TWF_TT_MIN_TWEET_LEN = [CS_TWF_TT_STD_PREFIX length] + CS_TWF_TT_FILTER_CHARS + 1;           //  one extra for the colon.
}

/*
 *  Generate the standard tweet text for the given seal id and screen name.
 */
+(NSString *) tweetTextForSealId:(NSString *) sid andNumericUserId:(NSString *) id_str
{
    // NOTE:  The tweet text is actually a crucial part of this implementation because it allows
    //        us to identify tweets that we have a high-probability of decoding.  The idea is to
    //        allow the device to spend most of its time in the timelines and only download when
    //        there is a really good chance of opening a message.  Even then we have quick-out logic
    //        that prevents too much bandwidth to be expended.  The last thing we want is to have
    //        a popular product that gets worse with popularity.
    //        - there is very little data shared here, but since the seal-id is a secret that all of the
    //          trusted parties have, it is a great indicator for whether we can open this.
    //        - the seal id _must_ be hashed with something that cannot be spoofed by a third party for this filter to
    //          be useful.  The id_str that represents a Twitter user is perfect for this purpose because it is always returned
    //          from every request type.
    // FORMAT: '#BePersonal @xxxx:'
    // - the 'xxxx' are four characters from the hash (in base-64) of the seal id and the id_str
    // - the goal here is to make this as reasonable as possible, especially through the Twitter app, which has
    //   limited space for presenting a new Tweet.  Too much random-looking gook is going to be unpleasing, but we need
    //   just enough to help narrow the search.  The combination of that hashtag, which I think is pretty decent, and a short
    //   four-character hash should be enough.
    
    NSString *hintFilter = [self hintFilterForSealId:sid andUserId:id_str];
    if (!hintFilter) {
        return nil;
    }
    return [NSString stringWithFormat:@"%@%@:", CS_TWF_TT_STD_PREFIX, hintFilter];
}

/*
 *  Determine if the provided text may imply a useful entity we can decode.
 */
+(BOOL) isTweetWithText:(NSString *) tweetText possibilyUsefulFromNumericUserId:(NSString *) id_str
{
    // - assume a minimum of one character for the filter and one for the colon.
    NSUInteger lenText = [tweetText length];
    if (lenText < CS_TWF_TT_MIN_TWEET_LEN || ![id_str length]) {
        return NO;
    }
    
    // - the first test is simple.  We expect to see the basic body in here.
    NSRange r = [tweetText rangeOfString:CS_TWF_TT_STD_PREFIX];
    if (!tweetText || r.location == NSNotFound) {
        return NO;
    }
    
    // - now check for the filter characters.
    NSUInteger lenPrefix = r.location + r.length;
    NSRange rEnd = [tweetText rangeOfString:@":" options:0 range:NSMakeRange(lenPrefix, lenText - lenPrefix)];
    if (rEnd.location == NSNotFound) {
        return NO;
    }
 
    // - pull out the filter.
    NSString *sFilter = nil;
    @try {
        sFilter = [tweetText substringWithRange:NSMakeRange(r.location + r.length, CS_TWF_TT_FILTER_CHARS)];
    }
    @catch (NSException *exception) {
        // - ignore.
    }
    if ([sFilter length] != CS_TWF_TT_FILTER_CHARS) {
        return NO;
    }
    
    // - the idea here is to look through all the seals we know about in the vault and see if any match what we're
    //   looking for.
    NSArray *arrSeals = [RealSecureImage availableSealsWithError:nil];
    for (NSString *sid in arrSeals) {
        NSString *sCmpFilter = [self hintFilterForSealId:sid andUserId:id_str];
        if ([sCmpFilter isEqualToString:sFilter]) {
            return YES;
        }
    }
    return NO;
}
@end


/************************************
 CS_twitterFeed_tweetText (internal)
 ************************************/
@implementation CS_twitterFeed_tweetText (internal)
/*
 *  Hash the two values and return an appropriate hint filter.
 */
+(NSString *) hintFilterForSealId:(NSString *) sid andUserId:(NSString *) id_str
{
    if (!sid.length || !id_str.length) {
        return nil;
    }
    
    // - just to ensure we're in synch.
    if (CS_TWF_TT_FILTER_CHARS != 4) {
        NSLog(@"CS-ALERT: Tweet text code mismatch.");
        return nil;
    }
    
    // - I'm using the raw routines here to do the hashing because I don't want this to take any longer than it needs to.
    uint8_t buf[CS_SHA_HASH_LEN];
    
    CS_sha *sha = [CS_sha shaHash];
    [sha updateWithString:id_str];
    [sha updateWithString:sid];
    [sha saveResultIntoBuffer:buf ofLength:CS_SHA_HASH_LEN];
    NSData *dBuf      = [NSData dataWithBytes:buf length:CS_SHA_HASH_LEN];
    NSString *sBase64 = [RealSecureImage filenameSafeBase64FromData:dBuf];
    NSUInteger len    = sBase64.length;
    if (len < 10) {
        NSLog(@"CS-ALERT: Unexpected preparation result during Tweet text generation.");
        return nil;
    }

    // - grab four characters from throughout the base-64 hash that can be used as a filter.
    NSString *ret  = [sBase64 substringWithRange:NSMakeRange(0, 1)];
    ret            = [ret stringByAppendingString:[sBase64 substringWithRange:NSMakeRange(len - 1, 1)]];
    ret            = [ret stringByAppendingString:[sBase64 substringWithRange:NSMakeRange(len/4, 1)]];
    ret            = [ret stringByAppendingString:[sBase64 substringWithRange:NSMakeRange((len/4) * 3, 1)]];
    return ret;
}
@end
