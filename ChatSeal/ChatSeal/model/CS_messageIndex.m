//
//  CS_messageIndex.m
//  ChatSeal
//
//  Created by Francis Grolemund on 11/5/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#include <CommonCrypto/CommonDigest.h>
#import "CS_messageIndex.h"
#import "ChatSealMessage.h"
#import "CS_sha.h"

// - constants
static const NSUInteger CS_MI_HASH_LEN = CC_SHA1_DIGEST_LENGTH;         // - we need to keep this because it is a compile-time constant.
static const NSUInteger CS_MI_MAX_PAD  = 32;
static const NSUInteger CS_MI_MIN_PAD  = 8;
static const NSUInteger CS_MAX_STRING  = (256 * 1024);

// - types
typedef unsigned char hash_val_t[CS_MI_HASH_LEN];

// - locals
static NSString *CS_MI_TODAY = nil;

// - forward declarations
@interface CS_messageIndex (internal)
-(void) hashString:(NSString *) sToHash withSalt:(NSString *) salt intoHash:(hash_val_t) hv;
-(BOOL) hasHashInIndex:(hash_val_t) hash;
-(void) addRandomPadHashesToArray:(NSMutableArray *) maHashes withSalt:(NSString *) saltValue;
@end

/******************
 CS_messageIndex
 ******************/
@implementation CS_messageIndex
/*
 *  Object attributes
 */
{
    NSMutableSet *wordSet;
    NSData       *indexData;
    BOOL         stringMatchIncludesToday;
}

/*
 *  Split a string into words.
 */
+(NSArray *) standardStringSplitWithWhitespace:(NSString *) content andAlphaNumOnly:(BOOL) alphaOnly
{
    // - make sure that we don't overflow by processing huge things.
    if ([content length] > CS_MAX_STRING) {
        content = [content substringToIndex:CS_MAX_STRING];
    }
    
    // - convert to lowercase
    content = [content lowercaseString];
    
    // - trim the ends
    content = [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    NSCharacterSet *cs = nil;
    if (alphaOnly) {
        // - we're going to split this into words along whitespace boundaries
        //   and ignore all non alpha-numeric items except for an apostrophe since
        //   it is used to combine two words
        NSMutableCharacterSet *csTmp = [NSMutableCharacterSet alphanumericCharacterSet];
        [csTmp addCharactersInString:@"'"];
        [csTmp invert];
        cs = csTmp;
    }
    else {
        cs = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    }
    return [content componentsSeparatedByCharactersInSet:cs];
}

/*
 *  Initialize the object.
 */
-(id) initWithIndexData:(NSData *) data
{
    self = [super init];
    if (self) {
        stringMatchIncludesToday = NO;
        wordSet                  = [[NSMutableSet alloc] init];
        indexData                = [data retain];
    }
    return self;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    return [self initWithIndexData:nil];
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [wordSet release];
    wordSet = nil;
    
    [indexData release];
    indexData = nil;
    
    [super dealloc];
}

/*
 *  Add content to the index
 */
-(void) appendContentToIndex:(NSString *) content
{
    NSArray *arr = [CS_messageIndex standardStringSplitWithWhitespace:content andAlphaNumOnly:YES];
    if (!arr || [arr count] < 1) {
        return;
    }
    
    // - save every word to generate a unique list for hashing.
    for (NSString *s in arr) {
        // - string splitting behavior in NSString will generate empty strings in the result, which
        //   consume hash processing for no benefit.
        if ([s length]) {
            [wordSet addObject:s];
        }
    }
    
    // - remove the existing index because it is now stale.
    [indexData release];
    indexData = nil;
}

/*
 *  Generate a new index with the given salt value.
 */
-(BOOL) generateIndexWithSalt:(NSString *) saltValue
{
    if (!saltValue) {
        return NO;
    }

    // - hash each one of the words in the set using the salt.
    // - in order to get the best search efficiency, the index
    //   will be sorted, so we need to first capture all the
    //   hashes before we can store them.
    NSMutableArray *maHashes = [NSMutableArray array];
    for (NSString *sWord in wordSet) {
        NSMutableData *d = [NSMutableData dataWithLength:CS_MI_HASH_LEN];
        [self hashString:sWord withSalt:saltValue intoHash:d.mutableBytes];
        [maHashes addObject:d];
    }
    [self addRandomPadHashesToArray:maHashes withSalt:saltValue];
    
    //  - sort the array
    NSArray *arrSortedHashes = [maHashes sortedArrayUsingComparator:^NSComparisonResult(NSData *d1, NSData *d2){
        int diff = memcmp(d1.bytes, d2.bytes, CS_MI_HASH_LEN);
        if (diff < 0) {
            return NSOrderedAscending;
        }
        else if (diff > 0) {
            return NSOrderedDescending;
        }
        else {
            return NSOrderedSame;
        }
    }];
    
    // - generate a new index
    [indexData release];
    NSMutableData *mdIndex = [NSMutableData dataWithLength:[arrSortedHashes count] * CS_MI_HASH_LEN];
    void *pIndex           = mdIndex.mutableBytes;
    for (NSUInteger i = 0; i < [arrSortedHashes count]; i++) {
        NSData *d = [arrSortedHashes objectAtIndex:i];
        memcpy(pIndex, d.bytes, CS_MI_HASH_LEN);
        pIndex += CS_MI_HASH_LEN;
    }
    indexData = [mdIndex retain];
    return YES;
}

/*
 *  Determine if the given search terms match the generated index
 */
-(BOOL) matchesString:(NSString *) searchTerm usingSalt:(NSString *) saltValue
{
    if (!searchTerm || !saltValue || !indexData) {
        return NO;
    }
    
    NSArray *arr = [CS_messageIndex standardStringSplitWithWhitespace:searchTerm andAlphaNumOnly:YES];
    hash_val_t wordHash;
    
    // - check each word in the source list, which will be used like an AND
    //   operation.
    for (NSString *findWord in arr) {
        [self hashString:findWord withSalt:saltValue intoHash:wordHash];
        
        // - every word must show up to satisfy the logic operation.
        if (![self hasHashInIndex:wordHash]) {
            // ...handle a very special case where we're looking for the abbreviated 'Today' string.
            if (!CS_MI_TODAY) {
                CS_MI_TODAY = [[ChatSealMessage formattedMessageEntryDate:[NSDate date] andAbbreviateThisWeek:YES andExcludeRedundantYear:YES] retain];
            }
            
            if (!stringMatchIncludesToday || !CS_MI_TODAY || [CS_MI_TODAY caseInsensitiveCompare:findWord] != NSOrderedSame) {
                return NO;
            }
        }
    }
    return YES;
}

/*
 *  Return the current generated index.
 */
-(NSData *) indexData
{
    return [[indexData retain] autorelease];
}

/*
 *  The string matching is generally very precise, but since the overview includes an abbreviated 'Today' string
 *  we're going to also support that for matching when it applies.   Obviously it doesn't make sense to hard code
 *  'Today' into the official index.
 */
-(void) setStringMatchIncludesAbbreviatedToday:(BOOL) includesToday
{
    stringMatchIncludesToday = includesToday;
}

@end

/***************************
 CS_messageIndex (internal)
 ***************************/
@implementation CS_messageIndex (internal)
/*
 *  Hash a string and return the result
 */
-(void) hashString:(NSString *) sToHash withSalt:(NSString *) salt intoHash:(hash_val_t) hv
{
    CS_sha *sha = [CS_sha shaHash];
    [sha updateWithString:salt];
    [sha updateWithString:sToHash];
    [sha saveResultIntoBuffer:hv ofLength:CS_MI_HASH_LEN];
}

/*
 *  Returns whether the index contains the given hash.
 */
-(BOOL) hasHashInIndex:(hash_val_t) hash
{
    const unsigned char *pIndex = (const unsigned char *) [indexData bytes];
    NSInteger numItems          = (NSInteger) ([indexData length] / CS_MI_HASH_LEN);
    
    // - ensure we never walk memory when there is nothing there.
    if (numItems == 0) {
        return NO;
    }
    
    NSInteger lowVal  = 0;
    NSInteger highVal = numItems-1;
    for (;;) {
        NSInteger curItem         = lowVal + ((highVal - lowVal)/2);
        const unsigned char *pCur = pIndex + (curItem * (NSInteger) CS_MI_HASH_LEN);
        int diff = memcmp(hash, pCur, CS_MI_HASH_LEN);
        if (!diff) {
            return YES;
        }
        
        // - split the working set
        if (diff < 0) {
            highVal = curItem - 1;
        }
        else {
            lowVal  = curItem + 1;
        }
        
        // - but don't go on forever.
        if (lowVal < 0 || highVal >= numItems || highVal < lowVal) {
            break;
        }
    }
    return NO;
}

/*
 *  In order to make the index less deterministic (1:1) for each word, we're going
 *  to pad it with some extra content.   The point is to avoid a scenario where a person could
 *  infer whether words already exist in a message by adding content and checking the index.
 */
-(void) addRandomPadHashesToArray:(NSMutableArray *) maHashes withSalt:(NSString *) saltValue
{
    static NSString *samples[5] = {@";",
                                   @"&",
                                   @"`",
                                   @"~",
                                   @"*"};
    
    // - I thought about this and I'm OK with using rand() instead of the secure randomization because
    //   this data isn't actually used for anything except indirection.
    NSUInteger toPad    = ((NSUInteger) rand() % (CS_MI_MAX_PAD - CS_MI_MIN_PAD)) + CS_MI_MIN_PAD;
    for (NSUInteger i = 0; i < toPad; i++) {
        // - we're going to use combinations of characters that won't likely ever
        //   show up in a search because special ones are removed.
        NSString *sVal = @"";
        for (int j = 0; j < 10; j++) {
            sVal = [sVal stringByAppendingString:samples[rand()%5]];
        }
        NSMutableData *hash = [NSMutableData dataWithLength:CS_MI_HASH_LEN];
        [self hashString:sVal withSalt:saltValue intoHash:hash.mutableBytes];
        [maHashes addObject:hash];
    }
}
@end
