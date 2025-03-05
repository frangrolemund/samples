//
//  CS_twitterFeed_history_item.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/4/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeed_history_item.h"

//  THREADING-NOTES:
//  - there is no internal locking here.

// - forward declarations
@interface CS_twitterFeed_history_item (internal)
-(id) initWithTweet:(NSString *) tweetId andScreenName:(NSString *) screenName;
@end

/****************************
 CS_twitterFeed_history_item
 ****************************/
@implementation CS_twitterFeed_history_item
/*
 *  Object attributes
 */
{
    NSString *tweetId;
    NSString *screenName;
}

/*
 *  Instantiate a new history item.
 */
+(CS_twitterFeed_history_item *) itemForTweet:(NSString *) tweetId andScreenName:(NSString *) screenName
{
    return [[[CS_twitterFeed_history_item alloc] initWithTweet:tweetId andScreenName:screenName] autorelease];
}

/*
 *  Initialize from an archive.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [self init];
    if (self) {
        tweetId    = [[aDecoder decodeObject] retain];
        screenName = [[aDecoder decodeObject] retain];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [tweetId release];
    tweetId = nil;
    
    [screenName release];
    screenName = nil;
    
    [super dealloc];
}

/*
 *  Encode to an archive.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:tweetId];
    [aCoder encodeObject:screenName];
}

/*
 *  Return the tweet id for this history item.
 */
-(NSString *) tweetId
{
    return [[tweetId retain] autorelease];
}

/*
 *  Return the screen name for this hisory item.
 */
-(NSString *) screenName
{
    return [[screenName retain] autorelease];
}

/*
 *  Return a textual description of this object.
 */
-(NSString *) description
{
    return [NSString stringWithFormat:@"tweet %@ from @%@", tweetId, screenName];
}

/*
 *  Return the hash for this history item.
 */
-(NSUInteger) hash
{
    return [tweetId hash];
}

/*
 *  Test for equality.
 */
-(BOOL) isEqual:(id)object
{
    if ([object isKindOfClass:[CS_twitterFeed_history_item class]] &&
        [self.tweetId isEqualToString:[(CS_twitterFeed_history_item *) object tweetId]]) {
        return YES;
    }
    return NO;
}
@end

/***************************************
 CS_twitterFeed_history_item (internal)
 ***************************************/
@implementation CS_twitterFeed_history_item (internal)
/*
 *  Initialize the object.
 */
-(id) initWithTweet:(NSString *) tid andScreenName:(NSString *) sn
{
    self = [super init];
    if (self) {
        tweetId    = [tid retain];
        screenName = [sn retain];
    }
    return self;
}
@end