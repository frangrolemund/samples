//
//  CS_twitterFeed_pending.m
//  ChatSeal
//
//  Created by Francis Grolemund on 5/31/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeed_shared.h"
#import "CS_twitterFeed_pending_db.h"

/************************
 CS_twitterFeed (pending)
 ************************/
@implementation CS_twitterFeed (pending)
/*
 *  Return the URL for storing the pending database.
 */
-(NSURL *) pendingDBURL
{
    NSURL *u = [self feedDirectoryURL];
    return [u URLByAppendingPathComponent:@"pending"];
}

/*
 *  Return a pending database for storing tweets.
 *  - ASSUMES the lock is held.
 */
-(CS_twitterFeed_pending_db *) verifyOpenPendingDB
{
    CS_twitterFeed_pending_db *pdb = [self pendingDB];
    if (!pdb) {
        pdb = [[[CS_twitterFeed_pending_db alloc] init] autorelease];
        NSError *err = nil;
        if (![pdb openFromURL:[self pendingDBURL] withError:&err]) {
            NSLog(@"CS: Failed to open the pending tweet database.  %@", [err localizedDescription]);
            return nil;
        }
        self.pendingDB = pdb;
    }
    return pdb;
}

/*
 *  Determine if there is high priority download work to perform.
 */
-(BOOL) hasHighPriorityDownloads
{
    // - at the moment, any pending download is treated as high-priority just because
    //   we want to favor consumption as much as possible.
    @synchronized (self) {
        CS_twitterFeed_pending_db *pdb = [self verifyOpenPendingDB];
        return [pdb hasHighPriorityPendingNotProcessing];
    }
}

/*
 *  Do the initial configuration for pending tweets.
 */
-(void) configurePendingTweetProgress
{
    NSArray *arrAll = nil;
    @synchronized (self) {
        CS_twitterFeed_pending_db *pdb = [self verifyOpenPendingDB];
        arrAll = [pdb allPending];
    }
    
    for (NSString *tid in arrAll) {
        [self beginPendingDownloadForTag:tid];
    }
}

/*
 *  Save a tweet to be processed at some later date.
 *  - if the URL of the photo isn't provided, that is a signal that we must look it up before we can continue.
 */
-(void) saveTweetForProcessing:(NSString *) tweetId withPhoto:(NSURL *) uPhoto fromUser:(NSString *) userId andFlagAsKnownUseful:(BOOL) flagKnownUseful
{
    // - when I see my own tweets, I am always going to ignore them because it is possible to race between the
    //   data mining and posting activities.  If we end up sharing producer seals at some point the
    //   delay interval in the pending tweet below could be used, but I'm not going to handle that scenario
    //   now because it is wasted effort.
    // - NOTE: this userId is only passed from the realtime streams.
    if (userId && [[self twitterType] isUserIdMine:userId]) {
        return;
    }
    
    // - ignore tweets that already know about.
    if (![[self twitterType] doesCentralTweetTrackingPermitTweet:tweetId toBeProcessedByFeed:self]) {
        return;
    }
    
    // - save the tweet in the pending database for later processing.
    @synchronized (self) {
        CS_twitterFeed_pending_db *pdb = [self verifyOpenPendingDB];
        if ([pdb addPendingTweet:tweetId forScreenName:userId withEmbeddedPhoto:uPhoto andDelayUntil:nil]) {
            if (flagKnownUseful) {
                [pdb setTweetIsConfirmedUseful:tweetId];
            }
            [pdb save];
        }
    }
    
    // - when there is a photo, we can start processing the tweet right away.
    if (uPhoto) {
        [self beginPendingDownloadForTag:tweetId];
        [self requestHighPriorityAttention];
    }
}

/*
 *  Ignore a pending tweet because we found some evidence that it isn't required.
 */
-(void) discardTweetForProcessing:(NSString *) tweetId
{
    @synchronized (self) {
        CS_twitterFeed_pending_db *pdb = [self verifyOpenPendingDB];
        [pdb discardPendingTweet:tweetId];
        [pdb save];
    }
    [self completePendingDownloadForTag:tweetId];
}

/*
 *  When we have pending items that don't have a URL, we need to first look them up.
 *  - return NO if it could not be scheduled.
 */
-(BOOL) schedulePendingTweetLookupIfPossibleWithItems:(NSArray *) arrTweetIds
{
    CS_tapi_statuses_lookup *sl = (CS_tapi_statuses_lookup *) [self apiForName:@"CS_tapi_statuses_lookup" andReturnWasThrottled:nil withError:nil];
    if (!sl || ![sl setTweetIds:arrTweetIds] ||
        ![self addCollectorRequestWithAPI:sl andReturnWasThrottled:nil withError:nil]) {
        return NO;
    }
    return YES;
}

/*
 *  This method will attempt to start a new download request of a message candidate
 *  in the supplied category.
 *  - the transient category is used when we don't know if the message is useful.
 *  - the download category is used when we have confirmed a message, but it has
 *    failed to be downloaded as transient.
 *  - return NO if the request is throttled.
 */
-(BOOL) tryToProcessPendingInCategory:(cs_cnt_throttle_category_t) cat
{
    // - first find a pending item we can work on.
    CS_tweetPending *tpNext        = nil;
    BOOL           isConfirmed     = (cat == CS_CNT_THROTTLE_DOWNLOAD) ? YES : NO;
    NSArray         *arrNeedPhotos = nil;
    @synchronized (self) {
        CS_twitterFeed_pending_db *pdb = [self verifyOpenPendingDB];
        tpNext                         = [pdb nextPendingTweetWithPhotoAsConfirmed:isConfirmed];
        if (cat == CS_CNT_THROTTLE_TRANSIENT) {
            arrNeedPhotos = [pdb pendingTweetIdsWithoutPhotosAndMaxCount:[CS_tapi_statuses_lookup maxStatusesPerRequest]];
        }
    }
    
    // - if we find any that need photos for unknown tweets, begin that.
    if ([arrNeedPhotos count]) {
        if (![self schedulePendingTweetLookupIfPossibleWithItems:arrNeedPhotos]) {
            @synchronized (self) {
                [[self verifyOpenPendingDB] abortPendingTweetPhotoLookups:arrNeedPhotos];
            }
        }
    }

    // - no pending item, then we're done.
    if (!tpNext) {
        return YES;
    }
    
    // - now allocate the appropriate kind of API.
    CS_tapi_download_image *tdi         = nil;
    BOOL wasThrottled                    = NO;
    NSError *err                         = nil;
    if (isConfirmed) {
        tdi = (CS_tapi_download_image *) [self apiForName:@"CS_tapi_download_image" andReturnWasThrottled:&wasThrottled withError:&err];
    }
    else {
        tdi = (CS_tapi_download_image *) [self apiForName:@"CS_tapi_download_image_toverify" andReturnWasThrottled:&wasThrottled withError:&err];
    }
    
    if (!tdi) {
        if (!wasThrottled) {
            NSLog(@"CS: Failed to allocate a new pending message download.  %@", [err localizedDescription]);
        }
        return !wasThrottled;
    }
    
    [tdi setImageURL:tpNext.photoURL forTweetId:tpNext.tweetId];
    if (![self addCollectorRequestWithAPI:tdi andReturnWasThrottled:&wasThrottled withError:&err]) {
        if (!wasThrottled) {
            NSLog(@"CS: Failed to request a new pending message download.  %@", [err localizedDescription]);
        }
        return !wasThrottled;
    }
    
    // - now update the pending item.
    @synchronized (self) {
        // - don't save this processing state because a crash could make this inconsistent.
        tpNext.isBeingProcessed = YES;
    }
    
    return YES;
}

/*
 *  Determine if the given API is a downloaded tweet that is ready for completion.
 *  - returns YES if it matches.
 */
-(BOOL) tryToCompletePendingWithAPI:(CS_twitterFeedAPI *) api
{
    // - was this a lookup?
    if ([api isKindOfClass:[CS_tapi_statuses_lookup class]]) {
        [self completePendingTweetLookupsWithAPI:(CS_tapi_statuses_lookup *) api];
        return YES;
    }
    
    // - or an official download?
    if (![api isKindOfClass:[CS_tapi_download_image class]]) {
        return NO;
    }
    CS_tapi_download_image *tdi = (CS_tapi_download_image *) api;
    
    // - now import the content.
    NSData *dPhoto = nil;
    if ([tdi downloadResultURL]) {
        dPhoto = [NSData dataWithContentsOfURL:[tdi downloadResultURL]];
        if (!dPhoto) {
            NSLog(@"CS: Unexpected failure to open downloaded message item.");
            return YES;
        }
    }
    else {
        dPhoto = [tdi resultData];
    }
    
    // - the pending database needs to always be updated regardless
    //   of the outcome or whether we're actually able to
    BOOL isVaultOpen     = [ChatSeal isVaultOpen];
    BOOL updateCentral   = NO;
    BOOL notFoundError   = (tdi.HTTPStatusCode == CS_TWIT_NOT_FOUND) ? YES : NO;
    @synchronized (self) {
        CS_twitterFeed_pending_db *pdb = [self verifyOpenPendingDB];
        if (isVaultOpen && (api.isAPISuccessful || tdi.isCancelledForLackingSeal || notFoundError)) {
            [pdb discardPendingTweet:tdi.tweetId];
            updateCentral = YES;
        }
        else {
            // - when anything else happens, it must be treated as a failure becase it could be that
            //   there is something legitimate happening like the feed is now protected, although we'll sort
            //   of be hosed for a bit while that occurs.
            CS_tweetPending *tp  = [pdb pendingForTweet:tdi.tweetId];
            
            // - when the tweet already has a screen name, it is best to pass this along to the type as a candidate so
            //   that the connectivity can be tracked.
            if (tp.screenName && [[self twitterType] saveOrReplaceAsCandidateTweet:tp.tweetId fromFriend:tp.screenName withPhoto:tp.photoURL asProvenUseful:tp.isConfirmed]) {
                [pdb discardPendingTweet:tdi.tweetId];
            }
            else {
                // - no, then just mark it as failed and let it cycle.
                [pdb markPendingTweetFailedAndAllowProcessing:tdi.tweetId];
            }
            dPhoto = nil;
        }
        [pdb save];
    }
    
    // - import the item, but there's not much that can be done with the error
    //   since there are so many different ways this can fail.
    BOOL goodImport = NO;
    if (dPhoto) {
        ChatSealFeedLocation *csfl = nil;
        ChatSealMessage *csm       = [self importMessageIntoVault:dPhoto andReturnOriginFeed:&csfl withError:nil];
        if (csm) {
            // - when we pull-in a producer message as a consumer, we need to update the history with
            //   the information so that this consumer can reply to the producer when necessary.
            if (!csm.isAuthorMe && csfl.feedAccount) {
                // ...incrementing the message count in a moment will save
                [self addConsumerHistoryForSeal:csm.sealId withTweet:tdi.tweetId andOwnerScreenName:csfl.feedAccount];
            }
            [self incrementMessageCountReceived];
            goodImport = YES;
        }
    }
    
    // - when we're done make sure that we track what we've finished or allow this to be processed again later.
    if (updateCentral) {
        if (goodImport || notFoundError) {
            // - when the tweet has been imported or it doesn't exist any more, we can really just say it is done and never try again.
            [[self twitterType] setTweetIdAsCompleted:tdi.tweetId withError:nil];
        }
        else {
            // - if the tweet is discovered again through a different feed or channel like tweet history when we finally
            //   have a seal, we can give it another shot.
            [[self twitterType] untrackTweetId:tdi.tweetId withError:nil];
        }
    }
    
    return YES;
}

/*
 *  Update the API's progress in the pending database.
 */
-(void) updateProgressForPendingItemAPI:(CS_tapi_download_image *) api
{
    BOOL wantUpdate = NO;
    @synchronized (self) {
        CS_twitterFeed_pending_db *pdb = [self verifyOpenPendingDB];
        CS_tweetPending *tp            = [pdb pendingForTweet:api.tweetId];
        if (tp && api.totalBytesToRecv) {
            wantUpdate = YES;
        }
    }
    
    // - when updates occur, make sure that the rest of the app knows about it.
    if (wantUpdate) {
        [self updatePendingDownloadForTag:api.tweetId withProgressRecv:api.bytesRecv andTotalToRecv:api.totalBytesToRecv];
    }
}

/*
 *  When a verify API comes through, see if it is confirmed and update accordingly.
 */
-(void) updateMessageStateIfPossibleForVerifyAPI:(CS_tapi_download_image_toverify *) api
{
    if (![api isConfirmed]) {
        return;
    }
    
    // - once we know for sure that this is useful, it is important to update the pending database
    //   so that if the app crashes we can just schedule it as a background download.
    @synchronized (self) {
        CS_twitterFeed_pending_db *pdb = [self verifyOpenPendingDB];
        if (pdb) {
            [pdb setTweetIsConfirmedUseful:api.tweetId];
            [pdb save];
            [api markAsAnalyzed];
        }
    }
}

/*
 *  We just got a tweet lookup request back, process the results.
 */
-(void) completePendingTweetLookupsWithAPI:(CS_tapi_statuses_lookup *)api
{
    BOOL someIdentified = NO;
    NSArray *arrInvalid = nil;
    @synchronized (self) {
        someIdentified = [[self verifyOpenPendingDB] completePendingTweetPhotoLookupsWithAPI:api andReturnInvalid:&arrInvalid];
    }
    
    // - if any of the tweets we were verifying are now invalid, make sure the type forgets about them.
    if ([arrInvalid count]) {
        for (NSString *tid in arrInvalid) {
            [[self twitterType] setTweetIdAsCompleted:tid withError:nil];
        }
    }
    
    // - when tweets were identified, we're going to attempt a high-priority download.
    if (someIdentified) {
        [self requestHighPriorityAttention];
    }
}

/*
 *  Remove pending content from this feed to be transferred elsewhere.
 *  - this happens from time to time, usually when the feed is going to be offline or deleted.
 */
-(NSArray *) extractPendingItemsWithFullIdentification:(BOOL) fullyIdentified
{
    NSArray *arrPending = nil;
    @synchronized (self) {
        CS_twitterFeed_pending_db *pdb = [self verifyOpenPendingDB];
        arrPending = [pdb extractPendingItemsWithFullIdentification:fullyIdentified];
        if ([arrPending count]) {
            [pdb save];
        }
    }
    
    // - ensure we are no longer tracking these tweets with our feed.
    for (CS_tweetPending *tp in arrPending) {
        [[self twitterType] untrackTweetId:tp.tweetId withError:nil];
        [self completePendingDownloadForTag:tp.tweetId];
    }
    
    // - and return what we found.
    return arrPending;
}

/*
 *  Take the items provided and add them to our pending list.
 */
-(void) addPendingItemsToFeed:(NSArray *) arrPending
{
    if (![arrPending count]) {
        return;
    }
    
    @synchronized (self) {
        CS_twitterFeed_pending_db *pdb = [self verifyOpenPendingDB];
        [pdb addPendingItemsForProcessing:arrPending];
        [pdb save];
    }
    
    // - Any new content neeeds to be tracked for download if it is possible.
    BOOL shouldRequestHighPrio = NO;
    for (CS_tweetPending *tp in arrPending) {
        if (tp.photoURL) {
            [self beginPendingDownloadForTag:tp.tweetId];
            shouldRequestHighPrio = YES;
        }
    }
    
    // - if any were items that could be started, get the high-priority scheduler involved.
    if (shouldRequestHighPrio) {
        [self requestHighPriorityAttention];
    }
}
@end