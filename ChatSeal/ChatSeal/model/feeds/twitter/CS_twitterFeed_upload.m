//
//  CS_twitterFeed_upload.m
//  ChatSeal
//
//  Created by Francis Grolemund on 5/31/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeed_shared.h"
#import "CS_twitterFeed_history_item.h"
#import "CS_twitterFeed_tweetText.h"

//  THREADING-NOTES:
//  - internal locking is provided.

/****************************
 CS_twitterFeed (upload)
 ****************************/
@implementation CS_twitterFeed (upload)
/*
 *  Perform upload processing.
 */
-(BOOL) processFeedRequestsForUpload
{
    //  !!REMEMBER!!
    //  - The only time to ever return NO from this method is when the request was throttled.
    
    // - uploads will not occur during a background fetch because we have limited capacity.
    if (![ChatSeal isApplicationForeground]) {
        return YES;
    }
    
    // - the numeric id is critical for uploads because it will be used to hash the content in the
    //   header as an independently verifyable piece of information in the tweet that cannot
    //   be faked by a third-party.  Granted, this tweet text is just intended to rule out obvious
    //   non-matches, but it is important that someone can't use that fact to mess with me.
    NSString *id_str = [self numericTwitterId];
    if (!id_str) {
        return YES;
    }
    
    // - since preparation is very expensive, I'm not going to even bother if the throttles say we're out
    //   of capacity.
    if ([self isTwitterUploadThrottled] || ![self hasCapacityForAPIByName:@"CS_tapi_statuses_update_with_media" withEvenDistribution:NO]) {
        // - throttled
        return NO;
    }
    
    @synchronized (self) {
        // - only allow one preparation to occur at a time because until the item is scheduled,
        //   we don't want to be able to generate the same request twice, even if the throttle
        //   permits that.
        if(self.inPostPreparation) {
            return YES;
        }
        self.inPostPreparation = YES;
    }
    
    // - first see if there is any work we can do
    CS_packedMessagePost *pmp = [self generateNextPendingMessagePost];
    if (!pmp) {
        @synchronized (self) {
            self.inPostPreparation = NO;
        }
        return YES;
    }
    
    // - when we're not the seal owner and our friend does not know we exist,
    //   we should reply to ensure they will see the mention.
    NSString *friendName = nil;
    NSString *tweetId    = nil;
    if (!pmp.isSealOwner) {
        CS_twitterFeed_history_item *hi = [self priorTweetFromOwnerOfSeal:pmp.sealId];
        if (hi) {
            if ([[self twitterType] canUseTwitterReplyToFriend:hi.screenName fromMyFeed:self whenUsingSeal:pmp.sealId]) {
                tweetId    = hi.tweetId;
                friendName = hi.screenName;
            }
        }
    }
    
    // - the tweet text is an important element for this because it will help others know when they have a good
    //   chance of opening this message.
    NSString *tweetText = [CS_twitterFeed_tweetText tweetTextForSealId:pmp.sealId andNumericUserId:id_str];
    
    // - build the API, if possible.
    NSError *err      = nil;
    BOOL wasThrottled = NO;
    CS_tapi_statuses_update_with_media *postAPI = (CS_tapi_statuses_update_with_media *) [self apiForName:@"CS_tapi_statuses_update_with_media"
                                                                                      andReturnWasThrottled:&wasThrottled
                                                                                                  withError:&err];
    if (!postAPI ||
        ![postAPI setPostAsSafeEntry:pmp.safeEntryId withImagePNGData:pmp.packedMessage andTweetText:tweetText] ||
        ![postAPI markAsReplyToTweet:tweetId fromUser:friendName] ||
        ![self addCollectorRequestWithAPI:postAPI andReturnWasThrottled:&wasThrottled withError:&err]) {
        if (!wasThrottled) {
            NSLog(@"CS: Failed to prepare the upload request.  %@", [err localizedDescription]);
        }
        @synchronized (self) {
            self.inPostPreparation = NO;
        }
        return !wasThrottled;
    }
    
    // - when we use the reply feature, we're going to discard the consumer history after we reply once because
    //   replies are filtered by everyone except the one receiving them.  If we keep replying, we may never reach other
    //   feeds that are following.
    if (tweetId && friendName) {
        [self discardConsumerHistoryForSeal:pmp.sealId];
        [self saveDeferredUntilEndOfCycle];
    }
    
    // - we always update the last upload time when we successfully start a new one to add one extra layer of
    //   throttle in front of requests because if we hammer it too quickly after just posting, we'll get
    //   a media throttle response, which is something we don't want to mess with.
    [self updateLastUploadTime];
    
    // - NOTE: we must wait until the API is actually scheduled to move the state of the entry to
    //         deliverying to avoid leaking the message id until it is tracked by the background daemon.
    //         Look to the pipelineAPIWasScheduled for that logic.
    return YES;
}

/*
 *  Handle custom upload scheduling behavior.
 */
-(void) apiWasScheduledForUpload:(CS_netFeedAPI *)api
{
    //   - we need to be sure that it is fully tracked by the background daemon before we can assume it
    //   should be converted over to delivering or a crash while it is in preparation will leak the message
    //   and we'll never know that it isn't running.
    if ([api isKindOfClass:[CS_tapi_statuses_update_with_media class]]) {
        CS_tapi_statuses_update_with_media *upload = (CS_tapi_statuses_update_with_media *) api;
        [self movePendingSafeEntryToDelivering:upload.safeEntryId];
        
        // - when we are able to finally move the entry to delivering, we can assume we've fully prepared
        //   the post and can permit a second one if the throttle allows it.
        @synchronized (self) {
            self.inPostPreparation = NO;
        }
    }
}

/*
 *  When an upload request completes, this method is issued.
 */
-(void) completeFeedRequestForUpload:(CS_twitterFeedAPI *) api
{
    // - there is only one type of upload API.
    CS_tapi_statuses_update_with_media *uploadAPI = (CS_tapi_statuses_update_with_media *) api;
    BOOL uploadTimeoutChanged                     = NO;
    
    @synchronized (self) {
        // - when an API fails, we will never get the scheduled method call, so
        //   we need to be sure that post preparation ends here.
        self.inPostPreparation = NO;
        
        // - make sure we save off the daily limits for throttling.
        if ([uploadAPI isOverDailyUploadLimit]) {
            if ([self isPasswordValid]) {
                // - when we're over our daily limit, it is important to back off for a bit, although
                //   I don't think I'm necessarily going to wait a full 24 hours.
                [self setMediaUploadTimeout:time(NULL) + (6 * 60 * 60)];
                uploadTimeoutChanged = YES;
            }
        }
        else if ([uploadAPI mediaRateLimitRemaining] == 0 && [uploadAPI mediaRateLimitResetTime]) {
            [self setMediaUploadTimeout:[uploadAPI mediaRateLimitResetTime]];
            uploadTimeoutChanged = YES;
        }
        else if ([self isMediaUploadThrottled]) {
            [self setMediaUploadTimeout:0];
            uploadTimeoutChanged = YES;
        }
    }

    // - when the media upload timeout changes, the status will change so we need
    //   to let consumers know about it.
    if (uploadTimeoutChanged) {
        [self notifyMajorFeedUpdateHasOccurredAndShouldUpdateBadge:YES];
    }
    
    // - figure out if we were successful.
    NSString *tweetId = nil;
    if ([uploadAPI isAPISuccessful]) {
        tweetId = [uploadAPI postedTweetId];
        
        // - move the message to completed (which saves the feed database also).
        [self moveDeliveringSafeEntry:uploadAPI.safeEntryId asTweetId:tweetId toCompleted:YES];
    }
    else {
        // - move the message back to pending because it wasn't completed (which saves the feed database also).
        [self moveDeliveringSafeEntry:uploadAPI.safeEntryId toCompleted:NO];
    }
    
    // - the last thing to do is update the type if we were successful, but this must occur outside our lock.
    if (tweetId) {
        NSError *err             = nil;
        if (![[self twitterType] setTweetIdAsCompleted:tweetId withError:&err]) {
            NSLog(@"CS: Failed to update the posted tweet %@ as completed.  %@", tweetId, [err localizedDescription]);
        }
        
        // - if we'd previously flagged this tweet as something we should process (probably from the realtime feed),
        //   discard that now.
        [self discardTweetForProcessing:tweetId];
    }
    
    // - update the upload delay just to force this feed to back off a bit.
    [self updateLastUploadTime];
}
@end

