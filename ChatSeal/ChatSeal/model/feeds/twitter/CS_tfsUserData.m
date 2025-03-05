//
//  CS_tfsUserData.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/9/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tfsUserData.h"
#import "ChatSealIdentity.h"
#import "ChatSealFeedLocation.h"
#import "CS_tapi_friendships_lookup.h"
#import "CS_tfsFriendshipHealth.h"
#import "ChatSeal.h"
#import "CS_twitterFeed_shared.h"
#import "CS_tapi_users_lookup.h"

//  THREADING-NOTES:
//  - no locking is provided in this class.

// - constants
static const uint16_t CS_TFS_MASK_ME                = (1 << 0);
static const uint16_t CS_TFS_MASK_ACCT_PROTECTED    = (1 << 1);
static const uint16_t CS_TFS_MASK_SEAL_OWNER        = (1 << 2);
static const uint16_t CS_TFS_MASK_VERIFIED          = (1 << 3);
static const uint16_t CS_TFS_MASK_PROVEN            = (1 << 4);
static NSString       *CS_TFS_KEY_MASK              = @"m";
static NSString       *CS_TFS_KEY_SCREEN_NAME       = @"sn";
static NSString       *CS_TFS_KEY_LOCAL_ACCT        = @"la";
static NSString       *CS_TFS_KEY_FRIENDS           = @"f";
static NSString       *CS_TFS_KEY_FRIEND_HEALTH     = @"fh";
static NSString       *CS_TFS_KEY_FULL_NAME         = @"fn";
static NSString       *CS_TFS_KEY_LOCATION          = @"l";
static NSString       *CS_TFS_KEY_PROFILE           = @"p";
static NSString       *CS_TFS_KEY_SALT              = @"s";
static NSString       *CS_TFS_KEY_CACHED_HASH       = @"cph";
static NSString       *CS_TFS_KEY_ACCT_DELETED      = @"del";

// - forward declarations
@interface CS_tfsUserData (internal)
-(id) initWithScreenName:(NSString *) screenName asAccount:(cs_tfs_account_id_t) acct andIsMe:(BOOL) isMe;
-(CS_tfsFriendshipHealth *) friendshipHealth;
-(void) recomputeFullHealthForMyFriends;
-(NSMutableDictionary *) myFriendships;
-(void) setUserAccountIsProtected:(BOOL)userAccountIsProtected;
@end

/********************
 CS_tfsUserData
 ********************/
@implementation CS_tfsUserData
/*
 *  Object attributes.
 */
{
    uint16_t               mask;
    NSString               *twitterScreenName;
    cs_tfs_account_id_t    localAccountId;                 // not the twitter-assigned numeric id!
    NSMutableDictionary    *mdFriendships;
    CS_tfsFriendshipHealth *fhFriendshipHealth;
    int32_t                randomSalt;
    NSString               *sProfileImage;
    BOOL                   isDeleted;
}
@synthesize fullName;
@synthesize location;
@synthesize userVersion;
@synthesize cachedProfileHash;
@synthesize profileImageDownloadPending;

/*
 *  Return a user data object for one of my local feeds.
 */
+(CS_tfsUserData *) userDataForScreenName:(NSString *) screenName asAccount:(cs_tfs_account_id_t) acct andIsMe:(BOOL) isMe
{
    // - assume this is for me until we set the friend data.
    return [[[CS_tfsUserData alloc] initWithScreenName:screenName asAccount:acct andIsMe:isMe] autorelease];
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        mask                        = 0;
        twitterScreenName           = nil;
        localAccountId              = 0;
        mdFriendships               = nil;
        fhFriendshipHealth          = nil;
        fullName                    = nil;
        location                    = nil;
        sProfileImage               = nil;
        userVersion                 = 0;
        randomSalt                  = 0;
        cachedProfileHash           = nil;
        profileImageDownloadPending = NO;
        isDeleted                   = NO;
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
        NSInteger tmp           = [aDecoder decodeIntegerForKey:CS_TFS_KEY_MASK];
        mask                    = (uint16_t) tmp;
        twitterScreenName       = [[aDecoder decodeObjectForKey:CS_TFS_KEY_SCREEN_NAME] retain];
        NSNumber *n             = [aDecoder decodeObjectForKey:CS_TFS_KEY_LOCAL_ACCT];
        localAccountId          = n.unsignedIntegerValue;
        mdFriendships           = [[aDecoder decodeObjectForKey:CS_TFS_KEY_FRIENDS] retain];
        fhFriendshipHealth      = [[aDecoder decodeObjectForKey:CS_TFS_KEY_FRIEND_HEALTH] retain];
        fullName                = [[aDecoder decodeObjectForKey:CS_TFS_KEY_FULL_NAME] retain];
        location                = [[aDecoder decodeObjectForKey:CS_TFS_KEY_LOCATION] retain];
        sProfileImage           = [[aDecoder decodeObjectForKey:CS_TFS_KEY_PROFILE] retain];
        randomSalt              = [aDecoder decodeInt32ForKey:CS_TFS_KEY_SALT];
        cachedProfileHash       = [[aDecoder decodeObjectForKey:CS_TFS_KEY_CACHED_HASH] retain];
        isDeleted               = [aDecoder decodeBoolForKey:CS_TFS_KEY_ACCT_DELETED];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [twitterScreenName release];
    twitterScreenName = nil;
    
    [mdFriendships release];
    mdFriendships = nil;
    
    [fhFriendshipHealth release];
    fhFriendshipHealth = nil;
    
    [fullName release];
    fullName = nil;
    
    [location release];
    location = nil;
    
    [sProfileImage release];
    sProfileImage = nil;
    
    [cachedProfileHash release];
    cachedProfileHash = nil;
    
    [super dealloc];
}

/*
 *  Save the object to an archive.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInteger:(NSInteger) mask forKey:CS_TFS_KEY_MASK];
    [aCoder encodeObject:twitterScreenName forKey:CS_TFS_KEY_SCREEN_NAME];
    [aCoder encodeObject:[NSNumber numberWithUnsignedInteger:localAccountId] forKey:CS_TFS_KEY_LOCAL_ACCT];
    [aCoder encodeObject:mdFriendships forKey:CS_TFS_KEY_FRIENDS];
    [aCoder encodeObject:fhFriendshipHealth forKey:CS_TFS_KEY_FRIEND_HEALTH];
    [aCoder encodeObject:fullName forKey:CS_TFS_KEY_FULL_NAME];
    [aCoder encodeObject:location forKey:CS_TFS_KEY_LOCATION];
    [aCoder encodeObject:sProfileImage forKey:CS_TFS_KEY_PROFILE];
    [aCoder encodeInt32:randomSalt forKey:CS_TFS_KEY_SALT];
    [aCoder encodeObject:cachedProfileHash forKey:CS_TFS_KEY_CACHED_HASH];
    if (self.isDeleted) {
        [aCoder encodeBool:YES forKey:CS_TFS_KEY_ACCT_DELETED];
    }
}

/*
 *  Return a debug description.
 */
-(NSString *) description
{
    if (mask == 0) {
        return @"(no attributes)";
    }
    else {
        NSMutableArray *maContent = [NSMutableArray array];
        if ([self isMe]) {
            [maContent addObject:@"is-me"];
        }
        if ([self userAccountIsProtected]) {
            [maContent addObject:@"prot"];
        }
        if ([self iAmSealOwnerInRelationship]) {
            [maContent addObject:@"iam-seal-owner"];
        }
        if (self.isDeleted) {
            [maContent addObject:@"is-DELETED"];
        }
        return [NSString stringWithFormat:@"%@ as %u (%@)", twitterScreenName, (unsigned) localAccountId, [maContent componentsJoinedByString:@","]];
    }
}

/*
 *  Return the screen name for the user.
 */
-(NSString *) screenName
{
    return [[twitterScreenName retain] autorelease];
}

/*
 *  Return whether this user is me.
 */
-(BOOL) isMe
{
    return (mask & CS_TFS_MASK_ME);
}

/*
 *  Retrieve the protection state.
 */
-(BOOL) userAccountIsProtected
{
    return (mask & CS_TFS_MASK_ACCT_PROTECTED);
}

/*
 *  Returns whether this user is the seal owner in our relationship.
 */
-(BOOL) iAmSealOwnerInRelationship
{
    return (mask & CS_TFS_MASK_SEAL_OWNER);
}

/*
 *  Update the object with the given friend information if we have it.
 */
-(void) updateWithFriendInfo:(ChatSealIdentityFriend *) chatFriend
{
    if (chatFriend) {
        // - if this is for a friend, it obviously isn't me any longer.
        mask = (mask & ~(CS_TFS_MASK_SEAL_OWNER | CS_TFS_MASK_ME));
        if (chatFriend.isSealOwnerInRelationship) {
            mask |= CS_TFS_MASK_SEAL_OWNER;
        }
    }
}

/*
 *  Return the account id.
 */
-(cs_tfs_account_id_t) accountId
{
    return localAccountId;
}

/*
 *  Return a key value for a dictionary.
 */
-(NSNumber *) accountKey
{
    return [NSNumber numberWithUnsignedInteger:localAccountId];
}

/*
 *  Connect a friend to us.
 *  - returns whether the health has been modified as a result of this change.
 */
-(BOOL) addFriendshipState:(CS_tapi_friendship_state *) state forFriend:(CS_tfsUserData *) chatFriend
{
    if (!(mask & CS_TFS_MASK_ME)) {
        return NO;
    }
    
    // - we're going to propagate the protection state over to our friendship object, which
    //   we know is alway soff by default.
    if (chatFriend.userAccountIsProtected) {
        [state setIsProtected:YES];
    }
    else {
        // - a follow request is not possible with an unprotected account, so if
        //   that exists, we've manufactured the state elsewhere and we should assume
        //   we're following.
        // - unless of course they're blocking me, in which case, this is sort of a soft request to follow.
        if (state.hasSentFollowRequest && !state.isBlockingMyAccount) {
            [state setIsFollowing:YES];
        }
    }
    
    // - and the seal owner state too.
    if (chatFriend.iAmSealOwnerInRelationship) {
        [state setIAmSealOwner:YES];
    }
    
    // - and then save off the new data after we merge it with what we learned about this friend.
    NSNumber *nKey                     = [chatFriend accountKey];
    CS_tapi_friendship_state *oldState = [[self myFriendships] objectForKey:nKey];
    BOOL shouldSave                    = ![state isEqualToState:oldState];              //  if we updated the state, we minimally need to save.
    [state mergeWithLearnedFromState:oldState];
    if (chatFriend.isProven && ![state isTrusted]) {
        [state flagAsTrusted];
        shouldSave = YES;
    }
    [[self myFriendships] setObject:state forKey:[chatFriend accountKey]];
    if ([[self friendshipHealth] updateFriendshipFromUser:self toAccount:[chatFriend accountKey] withState:state]) {
        // - also if your discrepancies have been modified, we should save.
        shouldSave = YES;
    }
    
    // - when something changed, we need to update the friend data and save.
    if (shouldSave) {
        // - make sure that a change to the health updates the version for this user so we see deltas in the UI.
        chatFriend.userVersion++;
    }
    return shouldSave;
}

/*
 *  Make sure that if we've tracked the connectivity for a list of
 *  our friends.
 *  - this only makes sense if this is a local user that is tracking friend connectivity.
 *  - returns whether the overall health has been modified as a result of this change.
 */
-(BOOL) updateProtectionStateFromFriends:(NSArray *) arrFriends
{
    BOOL ret = NO;
    for (CS_tfsUserData *myFriend in arrFriends) {
        NSNumber *acctKey            = [myFriend accountKey];
        CS_tapi_friendship_state *fs = [[self myFriendships] objectForKey:acctKey];
        if (fs) {
            [fs setIsProtected:myFriend.userAccountIsProtected];
            if ([[self friendshipHealth] updateFriendshipFromUser:self toAccount:[myFriend accountKey] withState:fs]) {
                ret = YES;
            }
        }
    }
    return ret;
}

/*
 *  Dicard the given friendship states.
 */
-(void) discardFriendshipStatesForAccountsNotInArray:(NSArray *) arrAccts
{
    if (mdFriendships) {
        NSMutableArray *maMineExtra = [NSMutableArray arrayWithArray:[self myFriendships].allKeys];
        [maMineExtra removeObjectsInArray:arrAccts];
        if ([maMineExtra count]) {
            [[self myFriendships] removeObjectsForKeys:maMineExtra];
            [[self friendshipHealth] discardHealthRecordsForFriendsInArray:maMineExtra];
        }
    }
}

/*
 *  Discard a single friend's state.
 */
-(void) discardFriendshipStateForKey:(NSNumber *) nKey
{
    [[self myFriendships] removeObjectForKey:nKey];
    [[self friendshipHealth] discardHealthRecordForFriendWithKey:nKey];    
}

/*
 *  When we first add friends, we want to know that they are unqueried if that is indeed true.
 */
-(void) addUnqueriedHealthIssuesForNewFriends:(NSArray *) arrAccts
{
    [[self friendshipHealth] addUnqueriedHealthIssueForAccounts:arrAccts];
}

/*
 *  Return the list of health issues impacting this user's connection with their friends.
 */
-(NSDictionary *) friendshipHealthIssues
{
    if (!self.isDeleted && fhFriendshipHealth) {
        return [fhFriendshipHealth friendshipHealthIssues];
    }
    return nil;
}

/*
 *  Return any deficiency records for the given account key.
 */
-(CS_tfsMessagingDeficiency *) deficiencyForFriendWithKey:(NSNumber *) nKey
{
    if (!self.isDeleted && fhFriendshipHealth) {
        return [fhFriendshipHealth deficiencyForFriendWithKey:nKey];
    }
    return nil;
}

/*
 *  Return a hash of the profile image URL with the salt.
 */
-(NSString *) generateProfileHash
{
    NSMutableData *mdHash = [NSMutableData data];
    if (sProfileImage) {
        [mdHash appendData:[sProfileImage dataUsingEncoding:NSASCIIStringEncoding]];
    }
    [mdHash appendBytes:&randomSalt length:sizeof(randomSalt)];
    return [ChatSeal insecureHashForData:mdHash];
}

/*
 *  Assign a new profile image to this user and make sure that we update everything.
 *  - returns YES if the image is different than the last one.
 */
-(BOOL) setProfileImage:(NSString *) spi
{
    if (![spi isEqualToString:sProfileImage]) {
        [sProfileImage release];
        sProfileImage = [spi retain];
        SecRandomCopyBytes(kSecRandomDefault, sizeof(randomSalt), (uint8_t *) &randomSalt);
        return YES;
    }
    return NO;
}

/*
 *  Return the current profile image.
 */
-(NSString *) profileImage
{
    return [[sProfileImage retain] autorelease];
}

/*
 *  Return whether the profile image is up to date.
 */
-(BOOL) hasRecentProfileImage
{
    if ([self.cachedProfileHash isEqualToString:[self generateProfileHash]]) {
        return YES;
    }
    return NO;
}

/*
 *  Discard all the tracked health issues for this object.
 */
-(NSArray *) discardAllHealthIssuesAndReturnFriends
{
    return [fhFriendshipHealth discardAllHealthIssuesAndReturnFriends];
}

/*
 *  Change the following state for a friend.
 *  - return YES if a change was made.
 */
-(BOOL) setFriendByKey:(NSNumber *) nFriend asFollowing:(BOOL) isFollowing
{
    CS_tapi_friendship_state *fs = [[self myFriendships] objectForKey:nFriend];
    if (fs && (fs.isFollowing != isFollowing)) {
        [fs setIsFollowing:isFollowing];
        [[self friendshipHealth] updateFriendshipFromUser:self toAccount:nFriend withState:fs];
        return YES;
    }
    return NO;
}

/*
 *  Change the blocking state for a friend.
 *  - return YES if a change was made.
 */
-(BOOL) setFriendByKey:(NSNumber *) nFriend asBlocking:(BOOL) isBlocking
{
    CS_tapi_friendship_state *fs = [[self myFriendships] objectForKey:nFriend];
    if (fs && (fs.isBlocking != isBlocking)) {
        [fs setIsBlocking:isBlocking];
        [[self friendshipHealth] updateFriendshipFromUser:self toAccount:nFriend withState:fs];
        return YES;
    }
    return NO;
}

/*
 *  Change whether my friend is blocking us.
 */
-(BOOL) markFriendByKeyAsBlockingMyFeed:(NSNumber *) nFriend
{
    CS_tapi_friendship_state *fs = [[self myFriendships] objectForKey:nFriend];
    if (fs && (!fs.isBlockingMyAccount || fs.hasSentFollowRequest)) {
        [fs setIsBlockingMyAccount];
        [[self friendshipHealth] updateFriendshipFromUser:self toAccount:nFriend withState:fs];
        return YES;
    }
    return NO;    
}

/*
 *  Using the pending task, reconcile it with the existing data in my friend.
 *  - return YES if a change was made.
 */
-(BOOL) reconcileFriendByName:(NSString *) friendName andKey:(NSNumber *) nFriend withPendingTask:(id<CS_twitterFeed_highPrio_task>) task
{
    CS_tapi_friendship_state *fs = [[self myFriendships] objectForKey:nFriend];
    if (fs && [task reconcileTaskIntentInActualState:fs forFriend:friendName]) {
        [[self friendshipHealth] updateFriendshipFromUser:self toAccount:nFriend withState:fs];
        return YES;
    }
    return NO;
}

/*
 *  Return the friendship state object for the given friend.
 */
-(CS_tapi_friendship_state *) stateForFriendByKey:(NSNumber *) nFriend
{
    if (mdFriendships && nFriend) {
        return [CS_tapi_friendship_state stateWithState:[mdFriendships objectForKey:nFriend]];
    }
    return nil;
}

/*
 *  Return the friendship states for all the friends that can be reached.
 */
-(NSDictionary *) allReachableFriends
{
    NSMutableDictionary *mdRet = [NSMutableDictionary dictionary];
    [mdFriendships enumerateKeysAndObjectsUsingBlock:^(NSNumber *nKey, CS_tapi_friendship_state *state, BOOL *stop) {
        if (state.isFollowing || !state.isProtected) {
            [mdRet setObject:[CS_tapi_friendship_state stateWithState:state] forKey:nKey];
        }
    }];
    return mdRet;
}

/*
 *  Update the user information with the retrieved content.
 *  - returns YES if the profile changed this data.
 */
-(BOOL) updateWithUserProfile:(CS_tapi_user_looked_up *) tulu
{
    BOOL wasChanged = NO;
    
    // - if we change nothing else, these two are important to recognize.
    if ([self userAccountIsProtected] != tulu.isProtected || self.isDeleted || !self.isVerified) {
        wasChanged = YES;
    }
    
    // - attributes that are relevant to all users.
    [self setUserAccountIsProtected:tulu.isProtected];
    self.isDeleted = NO;
    mask |= CS_TFS_MASK_VERIFIED;
    
    // - don't save anything for local users because it isn't displayed.
    if (![self isMe]) {
        // - update the name, location, profile image location
        if (tulu.fullName && ![tulu.fullName isEqualToString:fullName]) {
            [fullName release];
            fullName = [tulu.fullName retain];
            wasChanged     = YES;
        }
        
        if (![tulu.location isEqualToString:self.location]) {
            [location release];
            location = [tulu.location length] ? [tulu.location retain] : nil;
            wasChanged     = YES;
        }
        
        if ([self setProfileImage:tulu.sProfileImage]) {
            wasChanged                  = YES;
        }
    }
    
    // - the user version will help the UI know when the friend is different somehow.
    if (wasChanged) {
        userVersion++;
    }
    
    return wasChanged;
}

/*
 *  Mark a user as deleted.
 */
-(void) setIsDeleted:(BOOL)newIsDel
{
    if (newIsDel != isDeleted) {
        isDeleted = newIsDel;
        userVersion++;
    }
}

/*
 *  Return whether a user is deleted.
 */
-(BOOL) isDeleted
{
    return isDeleted;
}

/*
 *  Return whether this account is confirmed with at least one user update.
 */
-(BOOL) isVerified
{
    return (mask & CS_TFS_MASK_VERIFIED) ? YES : NO;
}

/*
 *  A proven user is someone who we've identified through seal activity (exchange or message passing).
 *  - once a user is proven, he can never be unproven and this indicates a high degree of trust.
 */
-(BOOL) isProven
{
    return (mask & CS_TFS_MASK_PROVEN) ? YES : NO;
}

/*
 *  Promote a user to proven.
 */
-(void) flagAsProven
{
    mask |= CS_TFS_MASK_PROVEN;
    userVersion++;
}
@end

/*****************************
 CS_tfsUserData (internal)
 *****************************/
@implementation CS_tfsUserData (internal)
/*
 *  Initialize this object.
 */
-(id) initWithScreenName:(NSString *) screenName asAccount:(cs_tfs_account_id_t) acct andIsMe:(BOOL) isMe
{
    self = [self init];
    if (self) {
        twitterScreenName = [screenName retain];
        localAccountId    = acct;
        if (isMe) {
            mask |= CS_TFS_MASK_ME;
        }
    }
    return self;
}

/*
 *  Returmn the friendship health object for a local user.
 */
-(CS_tfsFriendshipHealth *) friendshipHealth
{
    if (!fhFriendshipHealth) {
        fhFriendshipHealth = [[CS_tfsFriendshipHealth alloc] init];
    }
    return [[fhFriendshipHealth retain] autorelease];
}

/*
 *  Perform a complete recomputation of our health based on new data.
 */
-(void) recomputeFullHealthForMyFriends
{
    CS_tfsFriendshipHealth *health = [self friendshipHealth];
    NSMutableDictionary *tmpFriends = [self myFriendships];
    for (NSNumber *nKey in tmpFriends) {
        CS_tapi_friendship_state *fs = [tmpFriends objectForKey:nKey];
        if (fs) {
            [health updateFriendshipFromUser:self toAccount:nKey withState:fs];
        }
    }
}

/*
 *  Return a dictionary of my friendship states.
 */
-(NSMutableDictionary *) myFriendships
{
    if (!mdFriendships) {
        mdFriendships = [[NSMutableDictionary alloc] init];
    }
    return [[mdFriendships retain] autorelease];
}

/*
 *  Assign the protection state.
 */
-(void) setUserAccountIsProtected:(BOOL)userAccountIsProtected
{
    uint16_t oldMask = mask;
    if (userAccountIsProtected) {
        mask |= CS_TFS_MASK_ACCT_PROTECTED;
    }
    else {
        mask &= ~CS_TFS_MASK_ACCT_PROTECTED;
    }
    
    // - when we change one of our own protection states, we'll have to recompute the entire
    //   connectivity set.
    if ((oldMask & CS_TFS_MASK_ME) && (mask & CS_TFS_MASK_ACCT_PROTECTED) != userAccountIsProtected) {
        [self recomputeFullHealthForMyFriends];
    }
}

@end

