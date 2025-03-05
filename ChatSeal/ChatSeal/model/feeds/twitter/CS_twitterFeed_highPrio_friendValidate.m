//
//  CS_twitterFeed_highPrio_friendValidate.m
//  ChatSeal
//
//  Created by Francis Grolemund on 9/1/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeed_highPrio_friendValidate.h"

//  THREADING-NOTES:
//  - there is no internal locking here because it is assumed that this is never modified outside the feed lock.

/****************************************
 CS_twitterFeed_highPrio_friendValidate
 ****************************************/
@implementation CS_twitterFeed_highPrio_friendValidate
/*
 *  Object attributes
 */
{
    NSString                    *sFriend;
    BOOL                        isComplete;
    cs_tfhp_validateCompletion  valCompletion;
}

/*
 *  Initialize the object
 */
-(id) initWithFriend:(NSString *) myFriend withCompletion:(cs_tfhp_validateCompletion) completionBlock
{
    self = [super init];
    if (self) {
        isComplete    = NO;
        sFriend       = [myFriend retain];
        valCompletion = nil;
        if (completionBlock) {
            valCompletion = Block_copy(completionBlock);
        }
    }
    return self;
}

/*
 *  Return a new task object.
 */
+(CS_twitterFeed_highPrio_friendValidate *) taskForFriend:(NSString *) myFriend withCompletion:(cs_tfhp_validateCompletion) completionBlock
{
    return [[[CS_twitterFeed_highPrio_friendValidate alloc] initWithFriend:myFriend withCompletion:completionBlock] autorelease];
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [sFriend release];
    sFriend = nil;
    
    if (valCompletion) {
        Block_release(valCompletion);
        valCompletion = nil;
    }
    
    [super dealloc];
}

/*
 *  Try to advance processing in this object.
 *  - return YES only if you were able to do something, even if it is minor.
 */
-(BOOL) tryToProcessTaskForFeed:(CS_twitterFeed *) feed
{
    CS_tapi_users_show *uShow = (CS_tapi_users_show *) [feed apiForName:@"CS_tapi_users_show" andReturnWasThrottled:nil withError:nil];
    if (!uShow) {
        return NO;
    }
    
    [uShow setScreenName:sFriend];
    [uShow setCustomCompletionBlock:^(CS_netFeedAPI *api, ChatSealFeed *procFeed) {
        if (valCompletion) {
            CS_tapi_users_show *result = (CS_tapi_users_show *) api;
            [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
                valCompletion([result isAPISuccessful] ? [result resultDataAsUserInfo] : nil);
            }];
        }
    }];
    if (![feed addCollectorRequestWithAPI:uShow andReturnWasThrottled:nil withError:nil]) {
        return NO;
    }
    
    isComplete = YES;
    return YES;
}

/*
 *  Add-in the contents of the given task.
 */
-(void) mergeInWorkFromTask:(id<CS_twitterFeed_highPrio_task>) task
{
    // - nothing to merge.  If they are equal, then either can be used.
}

/*
 *  Is all the work completed?
 */
-(BOOL) hasCompletedTask
{
    return isComplete;
}

/*
 *  Is this task equal to another?
 */
-(BOOL) isEqualToTask:(id<CS_twitterFeed_highPrio_task>) task
{
    if ([task isKindOfClass:[CS_twitterFeed_highPrio_friendValidate class]]) {
        CS_twitterFeed_highPrio_friendValidate *taskOther = (CS_twitterFeed_highPrio_friendValidate *) task;
        if (taskOther && [taskOther->sFriend isEqualToString:sFriend]) {
            return YES;
        }
    }
    return NO;
}

@end
