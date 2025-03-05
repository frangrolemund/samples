//
//  CS_twitterFeed_realtime.m
//  ChatSeal
//
//  Created by Francis Grolemund on 5/31/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeed_shared.h"

//  THREADING-NOTES:
//  - internal locking is provided.

// - constants
static NSString         *CS_TF_REALTIME_BACKOFF_KEY = @"realtimeBackOff";
static NSTimeInterval   CS_TF_BACKOFF_TIMEOUT       = (60 * 60 * 3);
static NSTimeInterval   CS_TF_ERROR_TIMEOUT         = 60;

/***************************
 CS_twitterFeed (realtime)
 ***************************/
@implementation CS_twitterFeed (realtime)
/*
 *  Perform realtime processing.
 */
-(BOOL) processFeedRequestsForRealtime
{
    //  !!REMEMBER!!
    //  - The only time to ever return NO from this method is when the request was throttled.
    @synchronized (self) {
        if (self.tapiRealtime || ![ChatSeal hasVault]){
            return YES;
        }
        
        // - if we got a 420, we need to respect it for a while
        NSDate *dtBackoffUntil = [self.mdConfiguration objectForKey:CS_TF_REALTIME_BACKOFF_KEY];
        if (dtBackoffUntil && [dtBackoffUntil compare:[NSDate date]] == NSOrderedDescending) {
            return YES;
        }
    }
    
    // - don't try to start a realtime request while in the background because we won't be around long enough for it to matter.
    if (![ChatSeal isApplicationForeground]) {
        return YES;
    }
    
    // - ok, let's begin.
    NSError *err         = nil;
    BOOL wasThrottled    = NO;
    CS_tapi_user *tuser = (CS_tapi_user *) [super apiForName:@"CS_tapi_user" andReturnWasThrottled:&wasThrottled withError:&err];
    if (!tuser) {
        if (!wasThrottled) {
            NSLog(@"CS: Failed to allocate a new realtime user Twitter stream.  %@", [err localizedDescription]);
        }
        return !wasThrottled;
    }
    
    tuser.delegate = self;
    if (![self addCollectorRequestWithAPI:tuser andReturnWasThrottled:&wasThrottled withError:&err]) {
        if (!wasThrottled) {
            NSLog(@"CS: Failed to schedule a new realtime user Twitter stream.  %@", [err localizedDescription]);
        }
        return !wasThrottled;
    }
    
    // - the realtime feed was created, so we can save it.
    @synchronized (self) {
        self.tapiRealtime = tuser;
    }
    return YES;
}

/*
 *  When a realtime request completes, this method is issued.
 */
-(void) completeFeedRequestForRealtime:(CS_twitterFeedAPI *)api
{
    // - this shouldn't happen, but I want to be sure.
    if (![api isKindOfClass:[CS_tapi_user class]]) {
        return;
    }
    
    // - this is an important item to watch because it indicates we need to avoid using the realtime feed for
    //   a bit.
    @synchronized (self) {
        // - when the API has failed, we want to back off for some amount of time, but that
        //   depends on the type of failure.
        if (![api isAPISuccessful] && [self isEnabled]) {
            NSTimeInterval ti = 0;
            if (api.HTTPStatusCode == CS_TWIT_TOO_MANY_LOGINS) {
                // - too many logins means we won't get access soon and we need to respect Twitter here.
                ti = CS_TF_BACKOFF_TIMEOUT;
            }
            else {
                // - a generic error should force a small delay.
                ti = CS_TF_ERROR_TIMEOUT;
            }
            [self.mdConfiguration setObject:[NSDate dateWithTimeIntervalSinceNow:ti] forKey:CS_TF_REALTIME_BACKOFF_KEY];
            [self saveConfigurationWithError:nil];
        }
        
        // - if we just disconnected our own realtime stream, we need to discard the one we have or we'll never be able to start a new one.
        if (api == self.tapiRealtime) {
            self.tapiRealtime.delegate = nil;
            self.tapiRealtime = nil;
            [[self activeMiningState] setRealtimeMiningIsOnline:NO];
        }
    }
}

/*
 *  The friends list is always sent when the stream is initially formed.
 */
-(void) twitterStreamAPI:(CS_tapi_user *)api didReceiveFriendsList:(NSArray *)arrFriends
{
    // - if our password was previously marked as expired, we just confirmed it is OK again.
    if (![self isPasswordValid]) {
        [self setPasswordExpired:NO];
    }
    
    // - update the friends count so that we can let them know about their feeds.
    [self setFriendsCount:(NSInteger) [arrFriends count]];
    
    // - the friends list is the first thing we retrieve from the realtime feed, so we'll use that
    //   as an indicator that we're successfully online.
    [[self activeMiningState] setRealtimeMiningIsOnline:YES];
}

/*
 *  This delegate notification is sent when a tweet is deleted on the streamed feed.
 */
-(void) twitterStreamAPI:(CS_tapi_user *)api didDetectDeletionOfTweet:(NSString *)tweetId
{
    // - when a tweet is deleted before we can download it, it doesn't make sense to
    //   even try to grab it.
    [self discardTweetForProcessing:tweetId];
}

/*
 *  This delegate notification is sent when a new image tweet is produced.
 */
-(void) twitterStreamAPI:(CS_tapi_user *) api didFindImageTweet:(NSString *) tweetId withURL:(NSURL *) url fromUser:(NSString *) userId
{
    // - save the tweet in the local tweet tracking database for the download category to deal with later.
    // - the user id (screen name) is always returned from these streaming queries, so we'll use it to rule out our own content because
    //   the realtime stream can race with another thread that is posting a message.  It is OK if our message comes through, we just need
    //   to be sure not to use it.
    [self saveTweetForProcessing:tweetId withPhoto:url fromUser:userId andFlagAsKnownUseful:NO];
}

/*
 *  This delegate notification is sent when we just followed someone new.
 */
-(void) twitterStreamAPI:(CS_tapi_user *)api didFollowUser:(NSString *)userId withFriendsCount:(NSNumber *)friendsCount
{
    [[self twitterType] setFeed:self withFollowing:YES forFriendName:userId];
    
    // - update the friends count if needed
    if (friendsCount) {
        [self setFriendsCount:[friendsCount integerValue] + 1];
    }
}

/*
 *  This delegate notification is sent when we just unfollowed someone.
 */
-(void) twitterStreamAPI:(CS_tapi_user *)api didUnfollowUser:(NSString *)userId withFriendsCount:(NSNumber *)friendsCount
{
    [[self twitterType] setFeed:self withFollowing:NO forFriendName:userId];

    // - update the friends count if needed
    if ([friendsCount integerValue]) {
        [self setFriendsCount:[friendsCount integerValue] - 1];
    }
}

/*
 *  This delegate notification is sent when we just blocked someone.
 */
-(void) twitterStreamAPI:(CS_tapi_user *)api didBlockUser:(NSString *)userId withFriendsCount:(NSNumber *)friendsCount
{
    [[self twitterType] setFeed:self asBlocking:YES forFriendName:userId];
}

/*
 *  This delegate notification is sent when we just unblocked someone.
 */
-(void) twitterStreamAPI:(CS_tapi_user *)api didUnblockUser:(NSString *)userId withFriendsCount:(NSNumber *)friendsCount
{
    [[self twitterType] setFeed:self asBlocking:NO forFriendName:userId];
}

@end
