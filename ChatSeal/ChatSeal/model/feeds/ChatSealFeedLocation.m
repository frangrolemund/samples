//
//  ChatSealFeedLocation.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/1/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "ChatSealFeedLocation.h"

//  THREADING-NOTES:
//  - no locking is provided.  This object is never modified after it is created.

// - constants
static NSString *CSFL_STD_ACCT_KEY = @"acct";
static NSString *CSFL_STD_TYPE_KEY = @"type";
static NSString *CSFL_STD_CTX_KEY  = @"ctx";

/****************************
 ChatSealFeedLocation
 ****************************/
@implementation ChatSealFeedLocation
/*
 *  Object attributes.
 */
{
}
@synthesize feedAccount;
@synthesize feedType;
@synthesize customContext;

/*
 *  Quick initialization of a feed location.
 */
+(ChatSealFeedLocation *) locationForType:(NSString *) feedType andAccount:(NSString *) feedAccount
{
    ChatSealFeedLocation *cfl = [[[ChatSealFeedLocation alloc] init] autorelease];
    cfl.feedType              = feedType;
    cfl.feedAccount           = feedAccount;
    return cfl;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        feedAccount   = nil;
        feedType      = nil;
        customContext = nil;
    }
    return self;
}

/*
 *  Initialize the object from an archive.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [self init];
    if (self) {
        feedType      = [[aDecoder decodeObjectForKey:CSFL_STD_TYPE_KEY] retain];
        feedAccount   = [[aDecoder decodeObjectForKey:CSFL_STD_ACCT_KEY] retain];
        customContext = [[aDecoder decodeObjectForKey:CSFL_STD_CTX_KEY] retain];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [feedAccount release];
    feedAccount = nil;
    
    [feedType release];
    feedType = nil;
    
    [customContext release];
    customContext = nil;
    
    [super dealloc];
}

/*
 *  Encode the object to an archive.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:feedType forKey:CSFL_STD_TYPE_KEY];
    [aCoder encodeObject:feedAccount forKey:CSFL_STD_ACCT_KEY];
    [aCoder encodeObject:customContext forKey:CSFL_STD_CTX_KEY];
}

/*
 *  Return a hash for this object.
 */
-(NSUInteger) hash
{
    return [[feedAccount stringByAppendingString:feedType] hash];
}

/*
 *  Check equality to another object.
 */
-(BOOL) isEqual:(id)object
{
    if (![object isKindOfClass:[ChatSealFeedLocation class]]) {
        return NO;
    }
    
    ChatSealFeedLocation *cflOther = (ChatSealFeedLocation *) object;
    return [self.feedType isEqualToString:cflOther.feedType] && [self.feedAccount isEqualToString:cflOther.feedAccount];
}

/*
 *  Return a decent description.
 */
-(NSString *) description
{
    return [NSString stringWithFormat:@"ChatSealFeedLocation: %@ (%@)%@", feedAccount, feedType, [self customContext] ? @" HAS CONTEXT" : @""];
}
@end
