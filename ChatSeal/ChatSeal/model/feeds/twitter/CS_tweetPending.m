//
//  CS_tweetPending.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/2/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeed_pending_db.h"

//  THREADING-NOTES:
//  - this object uses internal locking because it could be modified outside
//    its database's critical section.

// - constants
static NSString         *CS_TFPDB_ENCODE_TWEET_KEY = @"tid";
static NSString         *CS_TFPDB_ENCODE_IMAGE_KEY = @"img";
static NSString         *CS_TFPDB_ENCODE_CONF_KEY  = @"conf";
static NSString         *CS_TFPDB_ENCODE_DELAY_KEY = @"delay";
static NSString         *CS_TFPDB_ENCODE_NAME_KEY  = @"name";
static NSTimeInterval   CS_TFPDB_FAIL_DELAY        = (60 * 10);
static NSTimeInterval   CS_TFPDB_FAIL_DELAY_LONG   = (60 * 60 * 6);

// - forward declarations
@interface CS_tweetPending (internal)
-(void) setDelayDate:(NSDate *) dt;
-(BOOL) shouldDelayProcessingNL;
@end

/**********************
 CS_tweetPending
 **********************/
@implementation CS_tweetPending
/*
 *  Object attributes.
 */
{
    NSString *tweetId;
    NSURL    *photoURL;
    BOOL     isConfirmed;
    BOOL     isBeingProcessed;
    NSDate   *delayDate;
    NSString *screenName;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        tweetId          = nil;
        photoURL         = nil;
        isConfirmed      = NO;
        isBeingProcessed = NO;
        delayDate        = nil;
        screenName       = nil;
    }
    return self;
}

/*
 *  Initialize from an archive.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [self init];
    if (self) {
        tweetId          = [[aDecoder decodeObjectForKey:CS_TFPDB_ENCODE_TWEET_KEY] retain];
        photoURL         = [[aDecoder decodeObjectForKey:CS_TFPDB_ENCODE_IMAGE_KEY] retain];
        isConfirmed      = [aDecoder decodeBoolForKey:CS_TFPDB_ENCODE_CONF_KEY];
        delayDate        = [[aDecoder decodeObjectForKey:CS_TFPDB_ENCODE_DELAY_KEY] retain];
        screenName       = [[aDecoder decodeObjectForKey:CS_TFPDB_ENCODE_NAME_KEY] retain];
    }
    return self;
}

/*
 *  Save to an archive.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    @synchronized (self) {
        [aCoder encodeObject:tweetId forKey:CS_TFPDB_ENCODE_TWEET_KEY];
        [aCoder encodeObject:photoURL forKey:CS_TFPDB_ENCODE_IMAGE_KEY];
        [aCoder encodeBool:isConfirmed forKey:CS_TFPDB_ENCODE_CONF_KEY];
        [aCoder encodeObject:delayDate forKey:CS_TFPDB_ENCODE_DELAY_KEY];
        [aCoder encodeObject:screenName forKey:CS_TFPDB_ENCODE_NAME_KEY];
        
        // NOTE: we do not save the 'is-being-processed' state because it is possible
        //       that a crash will make it inconsistent and we'll never end up processing it.
        // NOTE: we do not save the 'progress' value because it won't be useful after a transient API
        //       is restarted and cannot be acquired for a background download.
    }
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [tweetId release];
    tweetId = nil;
    
    [photoURL release];
    photoURL = nil;
    
    [delayDate release];
    delayDate = nil;
    
    [screenName release];
    screenName = nil;
    
    [super dealloc];
}

/*
 *  Return the id of the given tweet.
 */
-(NSString *) tweetId
{
    @synchronized (self) {
        return [[tweetId retain] autorelease];
    }
}

/*
 *  Return the photo embedded in the given tweet.
 */
-(NSURL *) photoURL
{
    @synchronized (self) {
        return [[photoURL retain] autorelease];
    }
}

/*
 *  Returns whether the given tweet is confirmed useful.
 */
-(BOOL) isConfirmed
{
    @synchronized (self) {
        return isConfirmed;
    }
}

/*
 *  Returns whether the given tweet is being actively processed.
 */
-(BOOL) isBeingProcessed
{
    @synchronized (self) {
        return isBeingProcessed;
    }
}

/*
 *  Mark whether this tweet is being processed.
 */
-(void) setIsBeingProcessed:(BOOL) val
{
    @synchronized (self) {
        isBeingProcessed = val;
    }
}

/*
 *  Compute whether it is a good idea to delay processing.
 */
-(BOOL) shouldDelayProcessing
{
    @synchronized (self) {
        return [self shouldDelayProcessingNL];
    }
}

/*
 *  Return the screen name, if it exists.
 */
-(NSString *) screenName
{
    @synchronized (self) {
        return [[screenName retain] autorelease];
    }
}

/*
 *  If a delay date exists, that is a clear indication that it was previous operation failed.
 */
-(BOOL) hasPreviouslyFailedProcessing
{
    @synchronized (self) {
         return (delayDate ? YES : NO);
    }
}
@end

/****************************
 CS_tweetPending (internal)
 ****************************/
@implementation CS_tweetPending (internal)
/*
 *  Initialize the object.
 */
-(id) initWithTweet:(NSString *) tid
{
    self = [self init];
    if (self) {
        tweetId = [tid retain];
    }
    return self;
}

/*
 *  Assign the photo to this pending item.
 */
-(void) setPhotoURL:(NSURL *) uPhoto
{
    @synchronized (self) {
        if (uPhoto != photoURL) {
            [photoURL release];
            photoURL = [uPhoto retain];
        }
    }
}

/*
 *  Assign the confirmed state to this tweet.
 */
-(void) setIsConfirmed:(BOOL) val
{
    @synchronized (self) {
        isConfirmed = val;
    }
}

/*
 *  Assign a screen name to this pending item.
 */
-(void) setScreenName:(NSString *) sn
{
    if (sn != screenName) {
        [screenName release];
        screenName = [sn retain];
    }
}

/*
 *  Check if we should attempt to process this pending item based on 
 *  the status and the confirmation state.
 *  - confirmation state doesn't always matter, like if we're just checking if anything exists.
 */
-(BOOL) shouldProcessPendingIfWantConfirmed:(BOOL) wantConf andMatchingFlag:(BOOL) isConf
{
    @synchronized (self) {
        // - in-process tweets aren't adjusted.
        if (isBeingProcessed) {
            return NO;
        }
        
        // - we expect to find a photo with this API.
        if (!photoURL) {
            return NO;
        }
        
        // - don't process tweets that need some time.
        if ([self shouldDelayProcessingNL]) {
            return NO;
        }
        
        // - match up the confirmation, if needed
        if (wantConf && isConf != isConfirmed) {
            return NO;
        }
    }
    return YES;
}

/*
 *  Assign the date we want to delay this item until.
 */
-(void) setDelayDate:(NSDate *) dt
{
    @synchronized (self) {
        if (delayDate != dt) {
            [delayDate release];
            delayDate = [dt retain];
        }
    }
}

/*
 *  Check if we should delay processing.
 *  - ASSUMES the lock is held.
 */
-(BOOL) shouldDelayProcessingNL
{
    if (delayDate) {
        if ([delayDate compare:[NSDate date]] == NSOrderedDescending) {
            return YES;
        }
        // - don't delete the delay date because it serves as an indicator
        //   of whether this failed before.
    }
    return NO;
}

/*
 *  When failures occur we want to handle them appropriately.
 */
-(void) markFailedAndAllowProcessing
{
    @synchronized (self) {
        isBeingProcessed         = NO;
        BOOL forceIdentification = (delayDate && photoURL && !screenName);
        NSDate *dtNewDelay       = nil;
        
        // - when we fail a couple times with an item, we're going to force identification
        //   because we may need to start using the friendship database to determine when we can
        //   access it.
        if (forceIdentification) {
            [photoURL release];
            photoURL = nil;
            // ...no delay date assigned so this is processed quickly.
        }
        else {
            dtNewDelay = [NSDate dateWithTimeIntervalSinceNow:(delayDate && screenName) ? CS_TFPDB_FAIL_DELAY_LONG : CS_TFPDB_FAIL_DELAY];
        }
        
        // - save the new delay date.
        [delayDate release];
        delayDate = [dtNewDelay retain];
    }
}

/*
 *  Prepare this pending item to be moved somewhere else.
 */
-(void) prepareForExtraction
{
    isBeingProcessed = NO;
    [delayDate release];
    delayDate = nil;
}
@end
