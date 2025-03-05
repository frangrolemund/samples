//
//  CS_twitterFeed_transient.m
//  ChatSeal
//
//  Created by Francis Grolemund on 5/31/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeed_shared.h"

//  THREADING-NOTES:
//  - internal locking is provided.

// - forward declarations
@interface CS_twitterFeed (transient_internal)
-(void) completeFriendLookups:(CS_tapi_friendships_lookup *) api;
-(void) completeFriendFollow:(CS_tapi_friendships_create *) api;
-(void) completeVerifyCredentials:(CS_tapi_account_verify_credentials *) api;
@end

/****************************
 CS_twitterFeed (transient)
 ****************************/
@implementation CS_twitterFeed (transient)
/*
 *  Perform transient processing.
 */
-(BOOL) processFeedRequestsForTransientOnlyInHighPriority:(BOOL) onlyHighPrio
{
    //  NOTE: I'm not going to use the throttling return code here for anything because generally speaking
    //        one API could be throttled while another may not.  The fact they are throttled should not
    //        impact one another.  The goal is to push as much work through as possible.
    
    //  - the absolute first thing for any new feed is to get its credentials verified because that id
    //    will be essential to sending messages
    //  - but it isn't necessary if we're in the background because we don't upload then
    if ([ChatSeal isApplicationForeground]) {
        [self requestCredsIfNecessary];
    }
    
    //  - the next thing is to always make sure my rate limits are retrieved so that we can update
    //    our throttle to be consistent.
    [self requestRateStatusIfNecessary];
    
    //  - don't do high-priority transient tasks when in the background because they just consume
    //    precious cycles that we don't have.
    if ([ChatSeal isApplicationForeground]) {
        //  - try to process the persistent tasks because they are the most important
        //    high priority things.
        [self tryToProcessHighPriorityWhenPersistent:YES];
        
        //  - now the non-persistent items, which are still important, but less so.
        [self tryToProcessHighPriorityWhenPersistent:NO];
    }
    
    //  - attempt to advance any downloads, which we do in a transient
    //    way initially because that will be the only chance we have to verify them without
    //    expending bandwidth.
    [self tryToProcessPendingInCategory:CS_CNT_THROTTLE_TRANSIENT];
    
    // - attempt to advance the mining.
    if (self.tapiRealtime) {
        // - we can use the existence of a realtime stream to influence how the mining occurs here.
        [[self activeMiningState] setRealtimeContentEventsProcessed:[self.tapiRealtime numberOfContentChangeEvents]];
    }
    [[self activeMiningState] processFeedTypeRequestsUsingFeed:self asOnlyHighPriority:onlyHighPrio];
        
    return YES;
}

/*
 *  This is usually only issued once per feed for its lifetime.  It retrieves the Twitter numberic id for the account.
 */
-(void) requestCredsIfNecessary
{
    // - this id should never change, but I'm going to verify it here during every startup to be absolutely sure.  If it did change
    //   everything would be hosed completely with the uploading since it requires the data to be accurate.
    if ([self hasVerifiedMyTwitterId]) {
        return;
    }
    
    // - we're going to use even distribution here so that we don't overload the API, which is pretty limited in capacity.
    BOOL wasThrottled = NO;
    NSError *err      = nil;
    CS_tapi_account_verify_credentials *vc = (CS_tapi_account_verify_credentials *) [self evenlyDistributedApiForName:@"CS_tapi_account_verify_credentials" andReturnWasThrottled:&wasThrottled withError:&err];;
    if (vc) {
        if ([self addCollectorRequestWithAPI:vc andReturnWasThrottled:&wasThrottled withError:&err]) {
            return;
        }
    }

    // - something went wrong.
    if (!wasThrottled) {
        NSLog(@"CS: Failed to issue the credential verification.  %@", [err localizedDescription]);
    }
}

/*
 *  Usually just once per app execution, the feed will synchronize itself with its online rate status values.
 */
-(void) requestRateStatusIfNecessary
{
    NSError *err = nil;
    if (![self hasRetrievedMyRateLimits]) {
        BOOL wasThrottled = NO;
        CS_tapi_application_rate_limit_status *arls = (CS_tapi_application_rate_limit_status *) [self apiForName:@"CS_tapi_application_rate_limit_status"
                                                                                           andReturnWasThrottled:&wasThrottled
                                                                                                       withError:&err];
        // - I'm not going to abort when this doesn't work because this status request is really just a convenience to keep our APIs synched up.
        if (arls) {
            [arls setResources:[[self twitterType] requiredTwitterAPIResources]];
            if ([self addCollectorRequestWithAPI:arls andReturnWasThrottled:&wasThrottled withError:&err]) {
                // - if it could be scheduled, don't worry about this any more.
                [self setHasRetrievedMyRateLimits];
            }
            else {
                if (!wasThrottled) {
                    NSLog(@"CS: Failed to schedule a rate limit status request.  %@", [err localizedDescription]);
                }
            }
        }
        else {
            if (!wasThrottled) {
                NSLog(@"CS: Failed to generate a rate limit status request.  %@", [err localizedDescription]);
            }
        }
    }
}

/*
 *  Advance the high priority processing.
 */
-(void) tryToProcessHighPriorityWhenPersistent:(BOOL) doPersistent
{
    // - the first thing is to grab the relevant array and pull all the items so that while
    //   the lock is released, nobody is messing around with the content.
    NSMutableArray *maToProcess = nil;
    @synchronized (self) {
        NSMutableArray *maTmp = [self highPriorityTasksAsPersistent:doPersistent];
        if ([maTmp count]) {
            maToProcess = [NSMutableArray arrayWithArray:maTmp];
            [maTmp removeAllObjects];
        }
    }
    
    if (![maToProcess count]) {
        return;
    }
    
    // - now we need to iterate over the array and try to process everything in it.
    NSMutableIndexSet *mis = nil;
    BOOL hasDoneSomeWork   = NO;
    for (NSUInteger i = 0; i < [maToProcess count]; i++) {
        id<CS_twitterFeed_highPrio_task> task = [maToProcess objectAtIndex:i];
        if ([task tryToProcessTaskForFeed:self]) {
            hasDoneSomeWork = YES;
            if ([task hasCompletedTask]) {
                if (!mis) {
                    mis = [NSMutableIndexSet indexSet];
                }
                [mis addIndex:i];
            }
        }
    }
    
    // - remove everything we processed.
    if ([mis count]) {
        [maToProcess removeObjectsAtIndexes:mis];
    }
    
    @synchronized (self) {
        // - now we need to update the original array if there is still pending content.
        if ([maToProcess count]) {
            NSMutableArray *maTmp = [self highPriorityTasksAsPersistent:doPersistent];
            if ([maTmp count]) {
                // - new items were added while we were processing
                for (NSUInteger i = 0; i < [maTmp count]; i++) {
                    id<CS_twitterFeed_highPrio_task> newTask = [maTmp objectAtIndex:i];
                    
                    // - see if any in our process array matches and if so, merge their tasks together.
                    for (NSUInteger j = 0; j < [maToProcess count]; j++) {
                        id<CS_twitterFeed_highPrio_task> procTask = [maToProcess objectAtIndex:j];
                        if (![newTask isEqualToTask:procTask]) {
                            continue;
                        }
                        
                        [newTask mergeInWorkFromTask:procTask];
                        [maToProcess removeObjectAtIndex:j];
                        break;
                    }
                }
                
                // - anything remaining in the to process array needs to be restored, but at the front because
                //   they were technically there first.
                [maToProcess addObjectsFromArray:maTmp];
                [maTmp removeAllObjects];
                [maTmp addObjectsFromArray:maToProcess];
                hasDoneSomeWork = YES;
            }
            else {
                [maTmp addObjectsFromArray:maToProcess];
            }
        }
        
        // - if this is persistent and we accomplished a bit of what we intended,
        //   then save off the changes.
        if (doPersistent && hasDoneSomeWork) {
            [self saveConfigurationWithError:nil];
        }
    }
}

/*
 *  When a transient request completes, this method is issued.
 */
-(void) completeFeedRequestForTransient:(CS_twitterFeedAPI *)api
{
    // - if the password was previously marked invalid, we just re-confirmed it.
    if ([api isAPISuccessful] && ![self isPasswordValid]) {
        [self setPasswordExpired:NO];
    }
    
    // - figure out what to do with the results
    if ([api isKindOfClass:[CS_tapi_statuses_timeline_base class]]) {
        [[self activeMiningState] completeTimelineProcesing:(CS_tapi_statuses_timeline_base *) api usingFeed:self];
    }
    else if ([api isKindOfClass:[CS_tapi_application_rate_limit_status class]]) {
        [[self twitterType] updateFactoryLimitsWithStatus:(CS_tapi_application_rate_limit_status *) api inFeed:self];
    }
    else if ([api isKindOfClass:[CS_tapi_friendships_lookup class]]) {
        [self completeFriendLookups:(CS_tapi_friendships_lookup *) api];
    }
    else if ([api isKindOfClass:[CS_tapi_friendships_show class]]) {
        [[self twitterType] updateTargetedFriendshipWithResults:(CS_tapi_friendships_show *) api fromFeed:self];
    }
    else if ([api isKindOfClass:[CS_tapi_friendships_create class]]) {
        [self completeFriendFollow:(CS_tapi_friendships_create *) api];
    }
    else if ([api isKindOfClass:[CS_tapi_blocks_destroy class]]) {
        // - verify current state when we fail
        if (![api isAPISuccessful]) {
            [self requestHighPriorityRefreshForFriend:[(CS_tapi_blocks_destroy *) api targetScreenName]];
        }
    }
    else if ([api isKindOfClass:[CS_tapi_mutes_users_destroy class]]) {
        // - verify current state when we fail.
        if (![api isAPISuccessful]) {
            [self requestHighPriorityRefreshForFriend:[(CS_tapi_mutes_users_destroy *) api targetScreenName]];
        }
    }
    else if ([api isKindOfClass:[CS_tapi_account_verify_credentials class]]) {
        [self completeVerifyCredentials:(CS_tapi_account_verify_credentials *) api];
    }
    else if ([self tryToCompletePendingWithAPI:api]) {
        return;
    }
}

/*
 *  Pass the provided API onto the mining stats to update the associated ranges and prevent 
 *  any lookups by this feed because it was completed elsewhere.
 */
-(void) markTimelineRangeAsProcessedFromAPI:(CS_tapi_statuses_timeline_base *) api
{
    [[self activeMiningState] markTimelineRangeAsProcessedFromAPI:api];
}

@end

/************************************
 CS_twitterFeed (transient_internal)
 ************************************/
@implementation CS_twitterFeed (transient_internal)
/*
 *  When we get friend lookups, we're going to do a bit more to ensure that
 *  the lookups don't collide with in-progress high-priority tasks that
 *  will update them.
 */
-(void) completeFriendLookups:(CS_tapi_friendships_lookup *) api
{
    if (![api isAPISuccessful]) {
        return;
    }
    
    // - friendships are no longer stale.
    [self resetStaleFriendFlag];
    
    // - update the masks for our current set of outstanding tasks.
    NSDictionary *dictMasks = [api friendResultMasks];
    @synchronized (self) {
        // - we're only going to go through persistent tasks because they are the only ones that really
        //   matter for friendship updates.
        // - generally-speaking, this is a rare scenario because these tasks should often be completed immediately.
        NSMutableArray *maTasks = [self highPriorityTasksAsPersistent:YES];
        if ([maTasks count]) {
            __block NSMutableIndexSet *msToDelete = nil;
            for (NSUInteger i = 0; i < [maTasks count]; i++) {
                id <CS_twitterFeed_highPrio_task> task = [maTasks objectAtIndex:i];
                if (![task respondsToSelector:@selector(isRedundantForState:forFriend:)] ||
                    ![task respondsToSelector:@selector(reconcileTaskIntentInActualState:forFriend:)]) {
                    continue;
                }
                
                // - go through all the masks and see if the tasks conflict with them.
                [dictMasks enumerateKeysAndObjectsUsingBlock:^(NSString *friendName, CS_tapi_friendship_state *state, BOOL *stop) {
                    // - is this task no longer useful?
                    if ([task isRedundantForState:state forFriend:friendName]) {
                        if (!msToDelete) {
                            msToDelete = [[NSMutableIndexSet indexSet] retain];
                        }
                        [msToDelete addIndex:i];
                        *stop = YES;
                        return;
                    }
                    
                    // - should the state be changed to reflect the intent of the task?
                    if ([task reconcileTaskIntentInActualState:state forFriend:friendName]) {
                        *stop = YES;
                        return;
                    }
                }];
            }
            
            // - if we should delete any tasks, do so now.
            [msToDelete autorelease];
            if ([msToDelete count]) {
                [maTasks removeObjectsAtIndexes:msToDelete];
                [self saveConfigurationWithError:nil];
            }
        }
    }
    
    // - send the masks (possibly modified) up to the type for friendship processing.
    [[self twitterType] updateFriendshipsWithResultMasks:dictMasks fromFeed:self];
}

/*
 *  We just issued a follow request, now we need to determine how to complete its processing.
 */
-(void) completeFriendFollow:(CS_tapi_friendships_create *) api
{
    // - we need to be careful here because if this succeeds, it could be just a confirmation that we'll need to wait
    //   for my friend to officially accept the follow request.  We don't want to reset that flag prematurely.
    if ([api isAPISuccessful]) {
        CS_tapi_friendship_state *state = [[self twitterType] stateForFriendByName:[api targetScreenName] inFeed:self];
        if (![state isProtected]) {
            // - we need to convert over to a full-follow only if the friend wasn't previously protected.
            [[self twitterType] setFeed:self withFollowing:YES forFriendName:[api targetScreenName]];
        }
    }
    else {
        if ([api didFollowFailBecauseTheyBlockedMe]) {
            [[self twitterType] markFeed:self asBlockedByFriendWithName:[api targetScreenName]];
        }
        else {
            // - when the request fails for any other reason, we're going to force a requery to make sure we have recent data
            [self requestHighPriorityRefreshForFriend:[api targetScreenName]];
        }
    }
}

/*
 *  Complete credential verification.
 */
-(void) completeVerifyCredentials:(CS_tapi_account_verify_credentials *) api
{
    if ([api isAPISuccessful]) {
        NSString *id_str = nil;
        NSNumber *nFriends = nil;
        [(CS_tapi_account_verify_credentials *) api parseNumericIdStr:&id_str andFriendsCount:&nFriends];
        if (id_str) {
            if ([id_str isEqualToString:[self numericTwitterId]]) {
                [self setHasVerifiedMyTwitterId];
            }
            else {
                [self setNumericTwitterId:id_str];
            }
        }
        
        if (nFriends) {
            [self setFriendsCount:[nFriends integerValue]];
        }
    }
}

@end
