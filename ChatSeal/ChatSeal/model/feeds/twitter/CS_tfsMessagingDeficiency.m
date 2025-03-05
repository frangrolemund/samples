//
//  CS_tfsMessagingDeficiency.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/16/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tfsMessagingDeficiency.h"
#import "CS_tfsFriendshipState_shared.h"

// - constants
typedef uint32_t cs_tfs_mh_mask_t;
static const cs_tfs_mh_mask_t CS_TFS_MASK_NO_FOLLOW             = (1 << 0);
static const cs_tfs_mh_mask_t CS_TFS_MASK_THEY_NOT_FOLLOWING    = (1 << 1);
static const cs_tfs_mh_mask_t CS_TFS_MASK_SEAL_OWNER_PROT       = (1 << 2);
static const cs_tfs_mh_mask_t CS_TFS_MASK_PROT_WANT_FOLLOW      = (1 << 3);
static const cs_tfs_mh_mask_t CS_TFS_MASK_BLOCKED               = (1 << 4);
static const cs_tfs_mh_mask_t CS_TFS_MASK_MUTING                = (1 << 5);
static const cs_tfs_mh_mask_t CS_TFS_MASK_ALL_FEEDS_DISABLED    = (1 << 6);
static const cs_tfs_mh_mask_t CS_TFS_MASK_UNQUERIED             = (1 << 7);
static const cs_tfs_mh_mask_t CS_TFS_MASK_WAIT_ACCEPT_FOLLOW    = (1 << 8);
static const cs_tfs_mh_mask_t CS_TFS_MASK_FRIEND_PROT           = (1 << 9);
static const cs_tfs_mh_mask_t CS_TFS_MASK_THEY_BLOCK_ME         = (1 << 10);
static const cs_tfs_mh_mask_t CS_TFS_MASK_IAM_SEAL_OWNER_NOFOL  = (1 << 11);

// - forward declarations
@interface CS_tfsMessagingDeficiency (internal)
-(id) initWithHealthProblems:(cs_tfs_mh_mask_t) health;
-(cs_tfs_mh_mask_t) healthProblems;
@end

/************************
 CS_tfsMessagingDeficiency
 ************************/
@implementation CS_tfsMessagingDeficiency
/*
 *  Object attributes
 */
{
    // - this is named intentionally because the absence of a mask should mean no problems!
    cs_tfs_mh_mask_t healthProblems;
}

+(CS_tfsMessagingDeficiency *) deficiencyFromUser:(CS_tfsUserData *) localUser toUserWithState:(CS_tapi_friendship_state *) fs
{
    cs_tfs_mh_mask_t mask = 0;
    
    if (![fs isFollowing]) {
        mask |= CS_TFS_MASK_NO_FOLLOW;
    }
    
    if ([fs hasSentFollowRequest]) {
        mask |= CS_TFS_MASK_WAIT_ACCEPT_FOLLOW;
    }
    
    if ([fs isMuting]) {
        mask |= CS_TFS_MASK_MUTING;
    }
    
    // - Problem-1: If we've explicitly blocked this person, that will severely diminish our ability
    //              to communicate.
    if ([fs isBlocking]) {
        mask |= CS_TFS_MASK_BLOCKED;
    }
    
    // - Problem-2: I am a consumer and have not followed the account of a protected seal owner.
    if (![fs iAmSealOwner] && ![fs isFollowing] && [fs isProtected] && [fs isTrusted]) {
        mask |= CS_TFS_MASK_SEAL_OWNER_PROT;
    }
    
    // - Problem-3: A seal owner that is protected has friendship requests outstanding from a friend.
    if (![fs isFollowedBy] && [fs friendWantsToFollowMe]) {
        // - the main flag is that they want to follow us and we need to make sure that gets reported.
        mask |= CS_TFS_MASK_PROT_WANT_FOLLOW;
    }
    
    // - Problem-4: They are blocking my account.  This can only be learned by an error response, not by query.
    if ([fs isBlockingMyAccount]) {
        mask |= CS_TFS_MASK_THEY_BLOCK_ME;
    }
    
    // - this is provided only when there are other problems to report because it is not a problem as such, but
    //   is useful for understanding the extent of the deficiency when it exists.
    if (mask && [fs isProtected]){
        mask |= CS_TFS_MASK_FRIEND_PROT;
    }
    
    // - Problem-5: They are not following me.
    if (![fs isFollowedBy]) {
        mask |= CS_TFS_MASK_THEY_NOT_FOLLOWING;
        
        // - Problem-5a: I am a protected seal owner so they really won't see me.
        if ([localUser userAccountIsProtected] && [fs iAmSealOwner]) {
            mask |= CS_TFS_MASK_IAM_SEAL_OWNER_NOFOL;
        }
    }
    
    // - only return an object when we set something in the mask.
    return (mask ? [[[CS_tfsMessagingDeficiency alloc] initWithHealthProblems:mask] autorelease] : nil);
}

/*
 *  Return the combination of the health of the two input items.
 */
+(CS_tfsMessagingDeficiency *) unionOfDeficiency:(CS_tfsMessagingDeficiency *) d1 withDeficiency:(CS_tfsMessagingDeficiency *) d2
{
    if (d1 && d2) {
        // - I gave some thought to this and I really do want an official union of states because if even
        //   one of these exist, that means there is an opportunity for improvement in the collection that
        //   contributed the individual health states.
        cs_tfs_mh_mask_t mask = d1.healthProblems;
        mask                 |= d2.healthProblems;
        if (mask & CS_TFS_MASK_ALL_FEEDS_DISABLED) {
            if (!([d1 allFeedsAreDisabled] && [d2 allFeedsAreDisabled])) {
                // - the only way we propagate a feeds disabled mask is when
                //   both have it originally.
                mask &= ~CS_TFS_MASK_ALL_FEEDS_DISABLED;
            }
        }
        else if (mask & CS_TFS_MASK_UNQUERIED) {
            if (!([d1 isUnqueried] && [d2 isUnqueried])) {
                // - the only way to propagate an unqueried mask is when both
                //   are unqueried.
                mask &= ~CS_TFS_MASK_UNQUERIED;
            }
        }
        return [[[CS_tfsMessagingDeficiency alloc] initWithHealthProblems:mask] autorelease];
    }
    else if (d1) {
        return d1;
    }
    else {
        return d2;
    }
}

/*
 *  This is a special state that is flagged when all feeds are disabled and I can't reach my friend at all.
 */
+(CS_tfsMessagingDeficiency *) deficiencyForAllFeedsDisabled
{
    return [[[CS_tfsMessagingDeficiency alloc] initWithHealthProblems:CS_TFS_MASK_ALL_FEEDS_DISABLED] autorelease];
}

/*
 *  When a friend relationship has never been verified, we need to flag them as unqueried.
 */
+(CS_tfsMessagingDeficiency *) deficiencyForUnqueriedFriend
{
    return [[[CS_tfsMessagingDeficiency alloc] initWithHealthProblems:CS_TFS_MASK_UNQUERIED] autorelease];
}

/*
 *  Initialize from an archive.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        NSUInteger numBytes = 0;
        void *ptr = [aDecoder decodeBytesWithReturnedLength:&numBytes];
        if (numBytes == sizeof(healthProblems)) {
            memcpy(&healthProblems, ptr, numBytes);
        }
        else {
            healthProblems = 0;
        }
    }
    return self;
}

/*
 *  Encode this object to an archive.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeBytes:&healthProblems length:sizeof(healthProblems)];
}

/*
 *  Return a hash for this problem.
 */
-(NSUInteger) hash
{
    return (NSUInteger) healthProblems;
}

/*
 *  Generic equivalence test.
 */
-(BOOL) isEqual:(id)object
{
    if (![object isKindOfClass:[CS_tfsMessagingDeficiency class]]) {
        return NO;
    }
    return [self isEqualToDeficiency:(CS_tfsMessagingDeficiency *) object];
}

/*
 *  Check if this object is equal to another.
 */
-(BOOL) isEqualToDeficiency:(CS_tfsMessagingDeficiency *) other
{
    if (healthProblems == other.healthProblems) {
        return YES;
    }
    return NO;
}

/*
 *  The existence of this object implies at least a sub-optimal health picture if nothing else.
 */
-(BOOL) isSubOptimal
{
    return YES;
}

/*
 *  There are specific states that really must be addressed.
 */
-(BOOL) isBroken
{
    // - NOTE: the unqueried state is not included as 'broken' because we just haven't had a chance
    //         to discover it yet.
    return (healthProblems & (CS_TFS_MASK_SEAL_OWNER_PROT |
                              CS_TFS_MASK_PROT_WANT_FOLLOW |
                              CS_TFS_MASK_BLOCKED |
                              CS_TFS_MASK_ALL_FEEDS_DISABLED |
                              CS_TFS_MASK_THEY_BLOCK_ME |
                              CS_TFS_MASK_IAM_SEAL_OWNER_NOFOL)) ? YES : NO;
}

/*
 *  Is our ability to send messages sub-optimal to this target friend?
 */
-(BOOL) isSendRestricted
{
    return (healthProblems & CS_TFS_MASK_THEY_NOT_FOLLOWING) ? YES : NO;
}

/*
 *  Is our ability to receive messages sub-optimal from this target friend?
 */
-(BOOL) isRecvRestricted
{
    return (healthProblems & (CS_TFS_MASK_NO_FOLLOW | CS_TFS_MASK_BLOCKED | CS_TFS_MASK_MUTING)) ? YES : NO;
}

/*
 *  Are we waiting for this friend to accept our follow request?
 */
-(BOOL) isWaitingForFollowAccept
{
    return (healthProblems & CS_TFS_MASK_WAIT_ACCEPT_FOLLOW) ? YES : NO;
}

/*
 *  If the friend is a protected seal owner, we must follow them in order to
 *  be able to get messages.  This is important to resolve.
 */
-(BOOL) isNotFollowingProtectedSealOwner
{
    return (healthProblems & CS_TFS_MASK_SEAL_OWNER_PROT) ? YES : NO;
}

/*
 *  If my account is protected and my friend has requested to follow us, we need
 *  to resolve this.
 */
-(BOOL) isProtectedWithFriendRequest
{
    return (healthProblems & CS_TFS_MASK_PROT_WANT_FOLLOW) ? YES : NO;
}

/*
 *  If I've blocked their account, this is important to resolve.
 */
-(BOOL) isBlocked
{
    return (healthProblems & CS_TFS_MASK_BLOCKED) ? YES : NO;
}

/*
 *  Does the friend this represents have a protected account?
 */
-(BOOL) isFriendProtected
{
    return (healthProblems & CS_TFS_MASK_FRIEND_PROT) ? YES : NO;
}

/*
 *  Is this friend blocking me from following?
 */
-(BOOL) isBlockingMyAccount
{
    return (healthProblems & CS_TFS_MASK_THEY_BLOCK_ME) ? YES : NO;
}

/*
 *  Whether I've muted my friend's account.
 */
-(BOOL) isMuting
{
    return (healthProblems & CS_TFS_MASK_MUTING) ? YES : NO;
}

/*
 *  Clear any deficiencies in this object.
 */
-(void) reset
{
    healthProblems = 0;
}

/*
 *  Return a brief bit of text to describe this deficiency.
 */
-(NSString *) shortDescription
{
    if ([self isBroken]) {
        if ([self allFeedsAreDisabled]) {
            return NSLocalizedString(@"My feeds are turned off.", nil);
        }
        else if ([self isBlocked]) {
            return NSLocalizedString(@"This friend is blocked.", nil);
        }
        else if ([self isNotFollowingProtectedSealOwner]) {
            return NSLocalizedString(@"You must follow this friend.", nil);
        }
        else if ([self isProtectedWithFriendRequest]) {
            return NSLocalizedString(@"This friend needs to follow you.", nil);
        }
        else if ([self isBlockingMyAccount]) {
            return NSLocalizedString(@"This friend is blocking you.", nil);
        }
    }
    else if ([self isUnqueried]) {
        return NSLocalizedString(@"Waiting for connectivity.", nil);
    }

    // - this is the default, but shouldn't be the only text.
    return NSLocalizedString(@"Connections can be improved.", nil);
}

/*
 *  There is no path possible to this friend because all my feeds are disabled.  This
 *  is a very special state, but reflects a broken relationship.
 */
-(BOOL) allFeedsAreDisabled
{
    return (healthProblems & CS_TFS_MASK_ALL_FEEDS_DISABLED) ? YES : NO;
}

/*
 *  Indicates whether this friend is unqueried.
 */
-(BOOL) isUnqueried
{
    return (healthProblems & CS_TFS_MASK_UNQUERIED) ? YES : NO;
}

/*
 *  Is my account protected and I have a seal that I've shared.
 */
-(BOOL) iAmProtectedSealOwnerAndTheyNoFollow
{
    return (healthProblems & CS_TFS_MASK_IAM_SEAL_OWNER_NOFOL) ? YES : NO;
}

@end

/**********************************
 CS_tfsMessagingDeficiency (internal)
 **********************************/
@implementation CS_tfsMessagingDeficiency (internal)
/*
 *  Initialize an object.
 */
-(id) initWithHealthProblems:(cs_tfs_mh_mask_t) hp
{
    self = [super init];
    if (self) {
        healthProblems = hp;
    }
    return self;
}

/*
 *  Return the health mask.
 */
-(cs_tfs_mh_mask_t) healthProblems
{
    return healthProblems;
}
@end