//
//  ChatSealFeedType.m
//  ChatSeal
//
//  Created by Francis Grolemund on 3/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//
#import "ChatSealFeedType.h"
#import "CS_feedShared.h"
#import "CS_sessionManager.h"
#import "ChatSealFeedCollector.h"
#import "ChatSeal.h"
#import <SystemConfiguration/SCNetworkReachability.h>

//  THREADING-NOTES:
//  - internal locking is provided only for delegate-related tasks.
//  - subclasses must handle their own locking and assume any method in the base can be called
//    from any thread at any time.

// - forward declarations
@interface ChatSealFeedType (internal)
-(id<ChatSealFeedTypeDelegate>) delegate;
-(void) reachabilityFlagUpdate:(SCNetworkReachabilityFlags) newFlags;
-(void) discardLastRefresh;
@end

/*
 *  Retain one of our reachability items.
 */
const void *networkReachabilityRetain(const void *info)
{
    ChatSealFeedType *csft = (ChatSealFeedType *) info;
    [csft retain];
    return info;
}

/*
 *  Release one of our reachability items.
 */
void networkReachabilityRelease(const void *info)
{
    ChatSealFeedType *csft = (ChatSealFeedType *) info;
    [csft release];
}

/*
 *  Process a reachability event change.
 */
void networkReachabilityCallback(SCNetworkReachabilityRef target,
                                 SCNetworkReachabilityFlags flags,
                                 void *info)
{
    ChatSealFeedType *csft = (ChatSealFeedType *) info;
    [csft reachabilityFlagUpdate:flags];
}

/**********************
 ChatSealFeedType
 **********************/
@implementation ChatSealFeedType
/*
 *  Object attributes.
 */
{
    id<ChatSealFeedTypeDelegate> delegate;
    SCNetworkReachabilityRef     netReach;
    SCNetworkReachabilityFlags   flags;
    BOOL                         gotFlags;
    NSDate                       *lastRefresh;
}

/*
 *  Return the directory where type-specific databases are stored.
 */
+(NSURL *) feedTypeURL
{
    NSURL *uBase = [ChatSealFeedCollector feedCollectionURL];
    uBase        = [uBase URLByAppendingPathComponent:@"types"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:[uBase path]]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:[uBase path] withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return uBase;
}

/*
 *  Return the cache category for storing profile images for friends.
 */
+(NSString *) friendProfilesCacheCategory
{
    return @"friends";
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    if (delegate) {
        // - the delegate relationships are very important and if one of the
        //   other objects wants to use this on a thread other than where it is being
        //   released, we can race for its life.  Make sure you close before releasing
        //   and the right relationships will be maintained.
        NSLog(@"CS-ALERT: Feed types must be closed before deallocation.");
    }
    
    [self close];
    
    // - make sure that the network reachability item is fully discarded when we deallocate.
    if (netReach) {
        SCNetworkReachabilityUnscheduleFromRunLoop(netReach, CFRunLoopGetMain(), kCFRunLoopCommonModes);
        SCNetworkReachabilitySetCallback(netReach, NULL, NULL);
        CFRelease(netReach);
        netReach = NULL;
    }
    
    [super dealloc];
}

/*
 *  Determine if two types are equal.
 */
-(BOOL) isEqual:(id)object
{
    if ([object isKindOfClass:[ChatSealFeedType class]] &&
         [[(ChatSealFeedType *) object typeId] isEqualToString:self.typeId]) {
        return YES;
    }
    return NO;
}

/*
 *  This is a sanity test to ensure that we aren't using feed types that are partially implemented.
 */
-(BOOL) hasMinimumImplementation
{
    NSString *desc   = [self description];
    NSString *typeId = [self typeId];
    if (desc && [desc length] && typeId && [typeId length]) {
        return YES;
    }
    return NO;
}

/*
 *  Return a descripton for the feed type, which is usually just the online service name.
 */
-(NSString *) description
{
    return nil;
}

/*
 *  Return a unique string identifier for the type.
 */
-(NSString *) typeId
{
    return nil;
}

/*
 *  You can override this with a specific host that will be reguarly checked for network access.
 */
-(NSString *) typeHostName
{
    return nil;
}

/*
 *  Returns whether the feed is managed by the settings app.
 */
-(BOOL) isManagedBySettings
{
    return NO;
}

/*
 *  Returns whether the user is authorized to use the feed, which is most often important for ones managed by Settings.
 */
-(BOOL) isAuthorized
{
    return NO;
}

/*
 *  Refresh the authorization state for this feed type.
 */
-(void) refreshAuthorizationWithCompletion:(void (^)(void)) completionBlock
{
}

/*
 *  Return a list of the feeds managed by this type.
 */
-(NSArray *) feeds
{
    return nil;
}

/*
 *  The friendship state is used to determine whether we need to present additional 
 *  configuration to help the user stay connected to their friends.  This is a single flag
 *  that allows us to ask the type to compute whether there is a good shot at receiving personal
 *  messages.  While the UI that this flag suggests isn't 100% necessary if people keep their feeds connected, it
 *  is provided as a tool for auto-configuring peoples' feeds to interact.
 */
-(csft_friendship_state_t) friendshipState
{
    //  CSFT_FS_NONE    means there are no friends for this type
    //  CSFT_FS_BROKEN  means there is at least one thing that is preventing communication and must be dealt with now.
    //  CSFT_FS_REFINE  means there are friends that could be viewed
    return CSFT_FS_NONE;
}

/*
 *  Return the list of all friends for this type of feed.  Each should be an instance of type ChatSealFeedFriend 
 *  that can be displayed as necessary.
 */
-(NSArray *) feedFriends
{
    return nil;
}

/*
 *  Override this to get a custom title.
 */
-(NSString *) friendsDisplayTitle
{
    return NSLocalizedString(@"My Friends", nil);
}

/*
 *  Return a default image to use for friends' profiles.
 */
-(UIImage *) friendDefaultProfileImage
{
    return nil;
}

/*
 *  Return the date when this feed was last refreshed.
 */
-(NSDate *) lastRefresh
{
    @synchronized (self) {
        if (lastRefresh) {
            return [[lastRefresh retain] autorelease];
        }
        return [NSDate dateWithTimeIntervalSince1970:0];
    }
}

/*
 *  When we identify another feed as a friend of this type, we
 *  can choose to ignore them, in which case we won't try to cultivate
 *  a relationship with them.
 *  - return a success/failure for the operation.
 */
-(BOOL) ignoreFriendByAccountId:(NSString *) acctId
{
    return NO;
}

/*
 *  Reverse the effects of prvious friend ignore requests.
 */
-(void) restoreFriendsAccountIds:(NSArray *)arrFriends
{
}

/*
 *  Return a view controller that is capable of managing my friends.
 */
-(UIFriendManagementViewController *) friendManagementViewController
{
    return nil;
}

/*
 *  Return whether friendships can be added manually.
 */
-(BOOL) canAddFriendsManually
{
    return NO;
}

/*
 *  When types allow friends to be added manually, return a custom view controller for that purpose.
 */
-(UIFriendAdditionViewController *) friendAdditionViewController
{
    return nil;
}
@end

/*****************************
 ChatSealFeedType (internal)
 *****************************/
@implementation ChatSealFeedType (internal)
/*
 *  Return the current delegate
 */
-(id<ChatSealFeedTypeDelegate>) delegate
{
    @synchronized (self) {
        // - we don't want the delegate to disappear before we can use
        //   it, so even though we don't retain it during storage, it must
        //   be retained in the autorelease pool before it is returned.
        return [[delegate retain] autorelease];
    }
}

/*
 *  Flags were received that change the state of reachability.
 */
-(void) reachabilityFlagUpdate:(SCNetworkReachabilityFlags) newFlags
{
    BOOL wasReachable = [self areFeedsNetworkReachable];
    @synchronized (self) {
        gotFlags = YES;
        flags    = newFlags;
    }
    
    // - if the flags changed something, we need to issue a full update for all feeds.
    if (wasReachable != [self areFeedsNetworkReachable]) {
        // - when we were previously offline, we want a full refresh as soon as possible.
        if ([self areFeedsNetworkReachable]) {
            [self discardLastRefresh];
        }
        
        // - update everyone that cares about this type's network state.
        for (ChatSealFeed *feed in self.feeds) {
            [ChatSealFeedCollector issueUpdateNotificationForFeed:feed];
        }
        [[ChatSeal applicationHub] updateFeedAlertBadge];
        NSLog(@"CS: The %@ network is now %s.", [self description], [self areFeedsNetworkReachable] ? "reachable" : "unreachable");
    }
}

/*
 *  Discard the last refresh date.
 */
-(void) discardLastRefresh
{
    @synchronized (self) {
        [lastRefresh release];
        lastRefresh = nil;
    }
}
@end

/*****************************
 ChatSealFeedType (shared)
 *****************************/
@implementation ChatSealFeedType (shared)
/*
 *  Types can also support some amount of processing, but only in specific categories because they are intended to manage data relationships
 *  that encompass all the feeds, not do the main feed workloads.
 */
+(BOOL) isThrottleCategorySupportedForProcessing:(cs_cnt_throttle_category_t) cat
{
    if (cat == CS_CNT_THROTTLE_TRANSIENT) {
        return YES;
    }
    return NO;
}

/*
 *  Initialize the object.
 */
-(id) initWithDelegate:(id<ChatSealFeedTypeDelegate>) d
{
    self = [super init];
    if (self) {
        delegate    = d;  // - assign, not retain!
        flags       = 0;
        gotFlags    = NO;
        lastRefresh = nil;
        
        netReach = NULL;
        NSString *sTypeHost = [self typeHostName];
        if (sTypeHost) {
            netReach = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, [sTypeHost UTF8String]);
            if (netReach) {
                SCNetworkReachabilityContext ctx;
                ctx.version         = 0;
                ctx.info            = self;
                ctx.retain          = networkReachabilityRetain;
                ctx.release         = networkReachabilityRelease;
                ctx.copyDescription = NULL;
                SCNetworkReachabilitySetCallback(netReach, networkReachabilityCallback, &ctx);
                SCNetworkReachabilityScheduleWithRunLoop(netReach, CFRunLoopGetMain(), kCFRunLoopCommonModes);
            }
        }
    }
    return self;
}

/*
 *  Assign the delegate of this type, which is most often the collector itself.
 */
-(void) setDelegate:(id<ChatSealFeedTypeDelegate>)d
{
    @synchronized (self) {
        // - assign, not retain!
        delegate = d;
    }
}

/*
 *  Return the collector that owns this object.
 */
-(ChatSealFeedCollector *) collectorForFeedType:(ChatSealFeedType *) ft
{
    return [self.delegate performSelector:@selector(collectorForFeedType:) withObject:ft];
}

/*
 *  Return the type for a given feed.
 */
-(ChatSealFeedType *) typeForFeed:(ChatSealFeed *) feed
{
    // - once we return our own reference, we don't want to disappear.
    return [[self retain] autorelease];
}

/*
 *  Return the collector for a given feed.
 */
-(ChatSealFeedCollector *) collectorForFeed:(ChatSealFeed *) feed
{
    return [self collectorForFeedType:self];
}

/*
 *  Allow or deny saving the feed.
 */
-(BOOL) canSaveFeed:(ChatSealFeed *)feed
{
    return YES;
}

/*
 *  The factory is used to manage throttled API requests.
 */
-(CS_netThrottledAPIFactory *) apiFactoryForFeed:(ChatSealFeed *)feed
{
    return nil;
}

/*
 *  The sub-types should implement this particular method in order to allow
 *  restarting background tasks after shutdown.
 */
-(CS_netFeedAPIRequest *) canGenerateAPIRequestFromRequest:(NSURLRequest *) req
{
    return nil;
}

/*
 *  Every feed type is explicitly closed before it is discarded in order to ensure
 *  it has an opportunity to safely clear its delegate relationships with child objects.
 */
-(void) close
{
    [self discardLastRefresh];
    [self setDelegate:nil];
}

/*
 *  Quick check to see if we can see the network.
 */
-(BOOL) areFeedsNetworkReachable
{
    @synchronized (self) {
        if (gotFlags) {
            if ((flags  & kSCNetworkReachabilityFlagsReachable) &&
                !(flags & kSCNetworkReachabilityFlagsInterventionRequired) &&
                !((flags & (kSCNetworkFlagsConnectionRequired | kSCNetworkFlagsConnectionAutomatic)) == kSCNetworkFlagsConnectionRequired)) {
                return YES;
            }
            else {
                return NO;
            }
        }
        
        // - assume it is until we get an update.
        return YES;
    }
}

/*
 *  When the feeds can't be reached, determine why.
 */
-(NSString *) networkReachabilityError
{
    if ([self areFeedsNetworkReachable]) {
        return nil;
    }
    @synchronized (self) {
        if (flags & kSCNetworkReachabilityFlagsInterventionRequired) {
            return NSLocalizedString(@"Confirm network settings.", nil);
        }
        else {
            return NSLocalizedString(@"Network unavailable.", nil);
        }
    }
}

/*
 *  The types store refresh dates so that we can respond quickly to changes in networking.
 */
-(void) updateLastRefresh
{
    @synchronized (self) {
        [lastRefresh release];
        lastRefresh = [[NSDate date] retain];
    }
}

@end