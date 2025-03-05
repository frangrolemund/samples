//
//  UIFeedsOverviewPlaceholder.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/27/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIFeedsOverviewPlaceholder.h"
#import "ChatSeal.h"
#import "ChatSealFeedCollector.h"

// - constants
static const int UIFOP_MAX_PLACEHOLDERS = 10;           // only enough for a screenful of data.
static NSString *UIFOP_PH_NAME_KEY      = @"nm";
static NSString *UIFOP_PH_EXCH_KEY      = @"ex";

// - forward declarations
@interface UIFeedsOverviewPlaceholder (internal)
+(NSURL *) placeholderDirectory;
-(void) setLenName:(NSUInteger) len;
-(void) setLenExchanged:(NSUInteger) len;
@end

/***********************************
 UIFeedsOverviewPlaceholder
 ***********************************/
@implementation UIFeedsOverviewPlaceholder
/*
 *  Object attributes.
 */
{
    // - this is all I feel comfortable storing because even a color of a feed type
    //   could maybe provide information about the user.
    NSUInteger lenName;
    NSUInteger lenExchanged;
}

/*
 *  Save the active list of feeds as placeholders.
 */
+(void) saveFeedPlaceholderData
{
    // - retrieve the list of active feeds, assuming we're showing all of them.
    NSError *err = nil;
    NSArray *arr = [[ChatSeal applicationFeedCollector] availableFeedsAsSortedList];
    if (!arr) {
        NSLog(@"CS:  Failed to retrieve a list of feeds for saving placeholder data.  %@", [err localizedDescription]);
        arr = [NSArray array];
    }
    
    // - now convert the first N feeds into placeholders, which are just items that can be used to recreate
    //   a stylized impression of the content, but no real data appears.
    NSMutableArray *maPlaceholders = [NSMutableArray array];
    for (NSUInteger i = 0; i < [arr count] && i < UIFOP_MAX_PLACEHOLDERS; i++) {
        ChatSealFeed    *feed            = [arr objectAtIndex:i];
        UIFeedsOverviewPlaceholder *foph = [[[UIFeedsOverviewPlaceholder alloc] init] autorelease];
        foph.lenName      = feed.displayName.length;
        NSString *sTmp    = [NSString stringWithFormat:@"%u", (unsigned) [feed numberOfMessagesProcessed]];
        foph.lenExchanged = [sTmp length];
        [maPlaceholders addObject:foph];
    }
    
    //  - now save this array to disk, and it can be unencrypted because there is nothing significant in these
    //    items.
    NSURL *uPH = [UIFeedsOverviewPlaceholder placeholderDirectory];
    NSData *d  = [NSKeyedArchiver archivedDataWithRootObject:maPlaceholders];
    if (d) {
        if (![d writeToURL:uPH atomically:YES]) {
            NSLog(@"CS:  Failed to save message overview placeholder content.");
        }
    }
}

/*
 *  Return all the feed placeholders we know about.
 */
+(NSArray *) feedPlaceholderData
{
    // - load the placeholder data from disk.
    NSURL *u      = [UIFeedsOverviewPlaceholder placeholderDirectory];
    NSObject *obj = [NSKeyedUnarchiver unarchiveObjectWithFile:[u path]];
    NSArray  *aPH = nil;
    if (obj && [obj isKindOfClass:[NSArray class]]) {
        aPH = (NSArray *) obj;
    }
    else {
        aPH = [NSArray array];
    }
    return aPH;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        lenName      = 0;
        lenExchanged = 0;
    }
    return self;
}

/*
 *  Decode the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [self init];
    if (self) {
        lenName      = (NSUInteger) [aDecoder decodeIntegerForKey:UIFOP_PH_NAME_KEY];
        lenExchanged = (NSUInteger) [aDecoder decodeIntegerForKey:UIFOP_PH_EXCH_KEY];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [super dealloc];
}

/*
 *  Encode the object.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInteger:(NSInteger) lenName forKey:UIFOP_PH_NAME_KEY];
    [aCoder encodeInteger:(NSInteger) lenExchanged forKey:UIFOP_PH_EXCH_KEY];
}

/*
 *  Return the length of the name for the feed.
 */
-(NSUInteger) lenName
{
    return lenName;
}

/*
 *  Return the length (in digits) of the exchange count.
 */
-(NSUInteger) lenExchanged
{
    return lenExchanged;
}

@end

/*************************************
 UIFeedsOverviewPlaceholder (internal)
 *************************************/
@implementation UIFeedsOverviewPlaceholder (internal)
/*
 *  Return the URL for storing placeholders.
 */
+(NSURL *) placeholderDirectory
{
    NSURL *u = [ChatSeal standardPlaceholderDirectory];
    return [u URLByAppendingPathComponent:@"f_ph"];
}

/*
 *  Set the length of the feed name.
 */
-(void) setLenName:(NSUInteger) len
{
    lenName = len;
}

/*
 *  Set the length of the exchange count.
 */
-(void) setLenExchanged:(NSUInteger) len
{
    lenExchanged = len;
}
@end