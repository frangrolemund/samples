//
//  CS_tapi_friendship_state.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tapi_friendship_state.h"

// - constants
static const uint16_t CS_TAPI_FS_MASK_FOLLOWING      = (1 << 0);
static const uint16_t CS_TAPI_FS_MASK_REQ_FOLLOW     = (1 << 1);
static const uint16_t CS_TAPI_FS_MASK_FOLLOWED_BY    = (1 << 2);
static const uint16_t CS_TAPI_FS_MASK_BLOCKING       = (1 << 3);
static const uint16_t CS_TAPI_FS_MASK_MUTING         = (1 << 4);
static const uint16_t CS_TAPI_FS_MASK_PROTECTED      = (1 << 5);
static const uint16_t CS_TAPI_FS_MASK_SEALOWNER      = (1 << 6);
static const uint16_t CS_TAPI_FS_MASK_FOLLOW_ME_REQ  = (1 << 7);
static const uint16_t CS_TAPI_FS_MASK_IS_BLOCKING_ME = (1 << 8);           //  this cannot be queried, only learned by following
static const uint16_t CS_TAPI_FS_MASK_IS_TRUSTED     = (1 << 9);           //  this cannot be queried, only learned through seal/message exchange.

/*******************************
 CS_tapi_friendship_state
 *******************************/
@implementation CS_tapi_friendship_state
/*
 *  Object attributes
 */
{
    uint16_t mask;
}

/*
 *  Initialize a new object.
 */
+(CS_tapi_friendship_state *) stateWithConnections:(NSArray *) arrConn
{
    CS_tapi_friendship_state *fs = [[[CS_tapi_friendship_state alloc] init] autorelease];
    uint16_t mask = 0;
    for (NSString *sConn in arrConn) {
        if ([sConn isEqualToString:@"following"]) {
            mask |= CS_TAPI_FS_MASK_FOLLOWING;
        }
        else if ([sConn isEqualToString:@"following_requested"]) {
            mask |= CS_TAPI_FS_MASK_REQ_FOLLOW;
            mask |= CS_TAPI_FS_MASK_PROTECTED;          // a foolow request always assumes the other guy is protected.
        }
        else if ([sConn isEqualToString:@"followed_by"]) {
            mask |= CS_TAPI_FS_MASK_FOLLOWED_BY;
        }
        else if ([sConn isEqualToString:@"blocking"]) {
            mask |= CS_TAPI_FS_MASK_BLOCKING;
        }
        else if ([sConn isEqualToString:@"muting"]) {
            mask |= CS_TAPI_FS_MASK_MUTING;
        }
        else if ([sConn isEqualToString:@"following_received"]) {
            mask |= CS_TAPI_FS_MASK_FOLLOW_ME_REQ;
        }
    }
    fs->mask = mask;
    return fs;
}

/*
 *  Initialize a new object.
 *  - parsed from the 'source' in https://dev.twitter.com/docs/api/1.1/get/friendships/show
 */
+(CS_tapi_friendship_state *) stateOfTargetFromSource:(NSDictionary *) dict
{
    CS_tapi_friendship_state *fs = [[[CS_tapi_friendship_state alloc] init] autorelease];
    uint16_t mask = 0;
    
    // - My intent is that the feed owner is always the source so that the result is for a given item.
    NSNumber *n = [dict objectForKey:@"followed_by"];
    if ([n boolValue]) {
        mask |= CS_TAPI_FS_MASK_FOLLOWED_BY;
    }
    
    n = [dict objectForKey:@"following"];
    if ([n boolValue]) {
        mask |= CS_TAPI_FS_MASK_FOLLOWING;
    }
    
    n = [dict objectForKey:@"following_received"];
    if ([n boolValue]) {
        mask |= CS_TAPI_FS_MASK_FOLLOW_ME_REQ;
    }
    
    n = [dict objectForKey:@"following_requested"];
    if ([n boolValue]) {
        mask |= CS_TAPI_FS_MASK_REQ_FOLLOW;
    }
    
    n = [dict objectForKey:@"blocking"];
    if ([n boolValue]) {
        mask |= CS_TAPI_FS_MASK_BLOCKING;
    }
    
    n = [dict objectForKey:@"muting"];
    if ([n boolValue]) {
        mask |= CS_TAPI_FS_MASK_MUTING;
    }
    
    fs->mask = mask;
    return fs;
}

/*
 *  Initialize a friendship state from another.
 */
+(CS_tapi_friendship_state *) stateWithState:(CS_tapi_friendship_state *) state
{
    if (state) {
        CS_tapi_friendship_state *ret = [[[CS_tapi_friendship_state alloc] init] autorelease];
        ret->mask                     = state->mask;
        return ret;
    }
    return  nil;
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        NSUInteger len = 0;
        void *bytes    = [aDecoder decodeBytesWithReturnedLength:&len];
        if (len == sizeof(mask)) {
            memcpy(&mask, bytes, sizeof(mask));
        }
        else {
            mask = 0;
        }
    }
    return self;
}

/*
 *  Encode to an archive.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeBytes:&mask length:sizeof(mask)];
}

/*
 *  Return whether this friend is one that we're following.
 */
-(BOOL) isFollowing
{
    return (mask & CS_TAPI_FS_MASK_FOLLOWING) ? YES : NO;
}

/*
 *  Change the following state on a friend manually.
 */
-(void) setIsFollowing:(BOOL)isFollowing
{
    // - we always reset the follow request because a major change to the
    //   follow state will clear that online.
    mask &= ~(CS_TAPI_FS_MASK_FOLLOWING | CS_TAPI_FS_MASK_REQ_FOLLOW);
    if (isFollowing) {
        // - when we are able to follow, that implies neither of us is blocking the other.
        mask &= ~(CS_TAPI_FS_MASK_IS_BLOCKING_ME | CS_TAPI_FS_MASK_BLOCKING);
        mask |= CS_TAPI_FS_MASK_FOLLOWING;
    }    
}

/*
 *  Returns whether we've requested to follow this friend.
 */
-(BOOL) hasSentFollowRequest
{
    return (mask & CS_TAPI_FS_MASK_REQ_FOLLOW) ? YES : NO;
}

/*
 *  Change the follow request flag.
 */
-(void) setHasSentFollowRequest:(BOOL) didRequest
{
    if (didRequest) {
        mask |= CS_TAPI_FS_MASK_REQ_FOLLOW;
    }
    else {
        mask = (mask & ~CS_TAPI_FS_MASK_REQ_FOLLOW);
    }
}

/*
 *  Whether this friend has requested to follow us.
 */
-(BOOL) friendWantsToFollowMe
{
    return (mask & CS_TAPI_FS_MASK_FOLLOW_ME_REQ) ? YES : NO;
}

/*
 *  Returns whether we're being followed by this friend.
 */
-(BOOL) isFollowedBy
{
    return (mask & CS_TAPI_FS_MASK_FOLLOWED_BY);
}

/*
 *  Returns whether we're blocking this friend.
 */
-(BOOL) isBlocking
{
    return (mask & CS_TAPI_FS_MASK_BLOCKING) ? YES : NO;
}

/*
 *  Change the blocking flag.
 */
-(void) setIsBlocking:(BOOL) isBlocking
{
    if (isBlocking) {
        mask |= CS_TAPI_FS_MASK_BLOCKING;
    }
    else {
        mask = (mask & ~CS_TAPI_FS_MASK_BLOCKING);
    }
}

/*
 *  Returns whether this friend is muted.
 */
-(BOOL) isMuting
{
    return (mask & CS_TAPI_FS_MASK_MUTING) ? YES : NO;
}

/*
 *  Turn muting on/off for this state.
 */
-(void) setIsMuting:(BOOL) isMuting
{
    if (isMuting) {
        mask |= CS_TAPI_FS_MASK_MUTING;
    }
    else {
        mask = (mask & ~CS_TAPI_FS_MASK_MUTING);
    }
}

/*
 *  Change the protected state.
 *  - this is provided because we use this object to store friendship information
 *    and that protection bit is useful for computing connectivity.
 */
-(void) setIsProtected:(BOOL) isProtected
{
    if (isProtected) {
        mask |= CS_TAPI_FS_MASK_PROTECTED;
    }
    else {
        mask = (mask & ~CS_TAPI_FS_MASK_PROTECTED);
    }
}

/*
 *  Return the protected bit.
 */
-(BOOL) isProtected
{
    return (mask & CS_TAPI_FS_MASK_PROTECTED) ? YES : NO;
}

/*
 *  Change the seal owner state.
 *  - this is provided to allow it to integrate better into the friendship state aggregation object.
 */
-(void) setIAmSealOwner:(BOOL)iAmSealOwner
{
    if (iAmSealOwner) {
        mask |= CS_TAPI_FS_MASK_SEALOWNER;
    }
    else {
        mask = (mask & ~CS_TAPI_FS_MASK_SEALOWNER);
    }
}

/*
 *  Return the seal owner bit.
 */
-(BOOL) iAmSealOwner
{
    return (mask & CS_TAPI_FS_MASK_SEALOWNER) ? YES : NO;
}

/*
 *  Does this state reflect that they are blocking me?
 */
-(BOOL) isBlockingMyAccount
{
    return (mask & CS_TAPI_FS_MASK_IS_BLOCKING_ME) ? YES : NO;
}

/*
 *  Flag this state as blocking my account.
 *  - since this is a rather severe state change, we can only go one way here and expect
 *    that a different state is used if it ever clears.
 */
-(void) setIsBlockingMyAccount
{
    // - when we flag our account as being blocked, any follow-related states are discarded because when one blocks all connections are lost.
    mask &= ~(CS_TAPI_FS_MASK_FOLLOW_ME_REQ | CS_TAPI_FS_MASK_FOLLOWED_BY | CS_TAPI_FS_MASK_FOLLOWING | CS_TAPI_FS_MASK_REQ_FOLLOW);
    mask |= CS_TAPI_FS_MASK_IS_BLOCKING_ME;
}

/*
 *  Return a debug description/
 */
-(NSString *) description
{
    NSMutableArray *maItems = [NSMutableArray array];
    if ([self isFollowing]) {
        [maItems addObject:@"following"];
    }
    
    if ([self hasSentFollowRequest]) {
        [maItems addObject:@"follow-req"];
    }
    
    if ([self friendWantsToFollowMe]) {
        [maItems addObject:@"req-follow-ME"];
    }
    
    if ([self isFollowedBy]) {
        [maItems addObject:@"is-following-me"];
    }
    
    if ([self isBlocking]) {
        [maItems addObject:@"blocking"];
    }
    
    if ([self isMuting]) {
        [maItems addObject:@"muting"];
    }
    
    if ([self isProtected]) {
        [maItems addObject:@"is-prot"];
    }
    
    if ([self iAmSealOwner]) {
        [maItems addObject:@"iam-seal-owner"];
    }
    
    if ([self isBlockingMyAccount]) {
        [maItems addObject:@"blocking-me"];
    }
    
    if ([self isTrusted]) {
        [maItems addObject:@"trusted"];
    }
    
    if (![maItems count]) {
        [maItems addObject:@"none"];
    }
    
    return [maItems componentsJoinedByString:@","];
}

/*
 *  Any attributes that were learned previously should be carried over to this
 *  object if possible.
 */
-(void) mergeWithLearnedFromState:(CS_tapi_friendship_state *) stateOther
{
    // - when we're being blocked, the main thing to check is that we haven't got any follow-related flags because
    //   those are mutually exclusive with a blocking state.
    if (stateOther && (stateOther->mask & CS_TAPI_FS_MASK_IS_BLOCKING_ME)) {
        if (![self isFollowing] && ![self isFollowedBy] && ![self hasSentFollowRequest] && ![self friendWantsToFollowMe]) {
            [self setIsBlockingMyAccount];
        }
    }
    
    // - also convey trust from one to the next.
    if (stateOther && [stateOther isTrusted]) {
        [self flagAsTrusted];
    }
}

/*
 *  Return whether the two states are equal.
 */
-(BOOL) isEqualToState:(CS_tapi_friendship_state *) stateOther
{
    if (!stateOther || mask != stateOther->mask) {
        return NO;
    }
    return YES;
}

/*
 *  Returns whether I can read this friend's content.
 */
-(BOOL) isReadable
{
    if (![self isProtected] || [self isFollowing]) {
        return YES;
    }
    return NO;
}

/*
 *  Mark this friend as trusted.
 */
-(void) flagAsTrusted
{
    mask |= CS_TAPI_FS_MASK_IS_TRUSTED;
}

/*
 *  Return this friend's trusted state.
 */
-(BOOL) isTrusted
{
    return (mask & CS_TAPI_FS_MASK_IS_TRUSTED) ? YES : NO;
}
@end
