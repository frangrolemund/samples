//
//  UITwitterFriendViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/17/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UITwitterFriendViewController.h"
#import "UITwitterFriendTableViewCell.h"
#import "CS_feedTypeTwitter.h"
#import "ChatSeal.h"
#import "UITwitterLocalFeedTableViewCell.h"
#import "CS_tfsFriendshipAdjustment.h"
#import "UIFeedGenericHeaderFooter.h"
#import "AlertManager.h"
#import "UITwitterFriendAdjustmentNavigationController.h"
#import "UIAdvancedSelfSizingTools.h"

// - constants
typedef enum {
    UI_TFV_SEC_FRIEND = 0,
    UI_TFV_SEC_FEEDS  = 1,
    
} ui_tfv_section_t;

static const NSTimeInterval UITFVC_REFRESH_INTERVAL = 15;               //  these feed refreshes should occur infrequently at best.

// - forward declarations
@interface UITwitterFriendViewController (internal)
-(CS_feedTypeTwitter *) twitterType;
-(void) refreshFriendDataWithAnimation:(BOOL) animated andForceVisibleUpdates:(BOOL) forceUpdates;
-(void) notifyFriendsUpdated;
-(void) saveNewFeedAdjustments:(NSArray *) arrAdj;
-(void) animateIncrementalRefreshWithNewFeedArray:(NSArray *) arrFeeds andForceVisibleUpdates:(BOOL) forceUpdates;
-(BOOL) hasAnyAdjustmentsThatCouldBeRefreshed;
-(void) startRefreshTimerIfNotRunning;
-(void) cancelRefreshTimer;
-(void) timerFired;
-(void) notifyDidEnterForeground;
-(void) notifyDidUpdateFeeds;
@end

@interface UITwitterFriendViewController (table) <UITableViewDelegate, UITableViewDataSource, UITwitterLocalFeedTableViewCellDelegate>
@end

/*********************************
 UITwitterFriendViewController
 *********************************/
@implementation UITwitterFriendViewController
/*
 *  Object attributes.
 */
{
    NSMutableArray *maLocalFeedAdjustments;
    NSTimer        *tmRefresh;
}
@synthesize tvFriendDetail;

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        maLocalFeedAdjustments = nil;
        tmRefresh              = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [tvFriendDetail release];
    tvFriendDetail = nil;
    
    [maLocalFeedAdjustments release];
    maLocalFeedAdjustments = nil;
    
    [super dealloc];
}

/*
 *  The view has been loaded.
 */
-(void) viewDidLoad
{
    [super viewDidLoad];
    
    // - configure the basic controls.
    self.title = NSLocalizedString(@"Twitter Friend", nil);
    
    // - and the notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyFriendsUpdated) name:kChatSealNotifyFriendshipsUpdated object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyFriendsUpdated) name:kChatSealNotifyFeedFriendshipUpdated object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyDidEnterForeground) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyDidUpdateFeeds) name:kChatSealNotifyFeedTypesUpdated object:nil];
    
    // - wire up the table.
    tvFriendDetail.delegate   = self;
    tvFriendDetail.dataSource = self;
    [self refreshFriendDataWithAnimation:NO andForceVisibleUpdates:NO];
}

/*
 *  The view controller is about to be discarded.
 */
-(void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // - when the view controller is going to be discarded, do some final cleanup.
    if (!self.parentViewController) {
        [self cancelRefreshTimer];
        
        // - if there are any pending adjustments, stop them now.
        for (CS_tfsFriendshipAdjustment *fa in maLocalFeedAdjustments) {
            [fa cancelConnectionUpdateForFriend:self.feedFriend];
        }
    }
}

/*
 *  The view has just appeared.
 */
-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // - some things, like waiting for a friend to accept my request are
    //   not passed back through the user's realtime feed so we need to more actively
    //   query for them.
    if ([self hasAnyAdjustmentsThatCouldBeRefreshed]) {
        [self startRefreshTimerIfNotRunning];
    }
}

@end

/*****************************************
 UITwitterFriendViewController (internal)
 *****************************************/
@implementation UITwitterFriendViewController (internal)
/*
 *  Return the type for the Twitter feeds.
 */
-(CS_feedTypeTwitter *) twitterType
{
    return (CS_feedTypeTwitter *) self.feedFriend.feedType;
}

/*
 *  Refresh the content in this view.
 */
-(void) refreshFriendDataWithAnimation:(BOOL) animated andForceVisibleUpdates:(BOOL) forceUpdates
{
    // - first determine if we have to update the friend object.
    ChatSealFeedFriend *ffRefreshed = [[self twitterType] refreshFriendFromFriend:self.feedFriend];
    BOOL friendChanged              = NO;
    if (ffRefreshed != self.feedFriend &&
        ffRefreshed.friendVersion != self.feedFriend.friendVersion) {
        friendChanged   = YES;
        self.feedFriend = ffRefreshed;
    }
    
    // - now check the local feeds to see if anything changed (but only if they haven't deleted their account.)
    NSArray *arrFeeds = self.feedFriend.isDeleted ? nil : [[self twitterType] localFeedsConnectionStatusWithFriend:self.feedFriend];
    
    // - be a little bit more surgical with animated changes.
    if (animated) {
        // - when the friend's basic information changed, then we need to referesh the overview cell.
        if (friendChanged) {
            NSIndexPath *ipFriend = [NSIndexPath indexPathForRow:0 inSection:UI_TFV_SEC_FRIEND];
            if ([ChatSeal isAdvancedSelfSizingInUse]) {
                [tvFriendDetail reloadRowsAtIndexPaths:[NSArray arrayWithObject:ipFriend] withRowAnimation:UITableViewRowAnimationFade];
            }
            else {
                UITwitterFriendTableViewCell *tftvc = (UITwitterFriendTableViewCell *) [tvFriendDetail cellForRowAtIndexPath:ipFriend];
                [tftvc reconfigureWithFriend:self.feedFriend andAnimation:YES];
            }
        }
        
        // - figure out what has to change.
        if ([arrFeeds count] && ![maLocalFeedAdjustments count]) {
            [self saveNewFeedAdjustments:nil];
            [tvFriendDetail insertSections:[NSIndexSet indexSetWithIndex:UI_TFV_SEC_FEEDS] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        else if (![arrFeeds count] && [maLocalFeedAdjustments count]) {
            [self saveNewFeedAdjustments:arrFeeds];
            [tvFriendDetail deleteSections:[NSIndexSet indexSetWithIndex:UI_TFV_SEC_FEEDS] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        else if ([maLocalFeedAdjustments count]){
            [self animateIncrementalRefreshWithNewFeedArray:arrFeeds andForceVisibleUpdates:forceUpdates];
        }
        
    }
    else {
        // - no animation, just a quick reload.
        [self saveNewFeedAdjustments:arrFeeds];
        [tvFriendDetail reloadData];
    }
    
    // - the adjustment timer needs to be running when it is required.
    if ([self hasAnyAdjustmentsThatCouldBeRefreshed]) {
        [self startRefreshTimerIfNotRunning];
    }
    else {
        if (tmRefresh) {
            [self cancelRefreshTimer];
        }
    }
}

/*
 *  Swap-out the adjustments we have.
 */
-(void) saveNewFeedAdjustments:(NSArray *) arrAdj
{
    [maLocalFeedAdjustments release];
    maLocalFeedAdjustments = (NSMutableArray *) [arrAdj mutableCopy];
}

/*
 *  This method will figure out what has to change in the table when the refresh is non-trivial.
 */
-(void) animateIncrementalRefreshWithNewFeedArray:(NSArray *) arrFeeds andForceVisibleUpdates:(BOOL) forceUpdates
{
    NSMutableArray *maNewFeeds = [NSMutableArray array];
    NSMutableArray *maToUpdate = nil;
    NSMutableArray *maToDelete = nil;
    NSMutableArray *maToInsert = nil;
    
    // - this is more challenging because we need to establish where things have changed.
    NSUInteger curOldIdx = 0;
    NSUInteger curNewIdx = 0;
    for (;;) {
        CS_tfsFriendshipAdjustment *faOld = nil;
        CS_tfsFriendshipAdjustment *faNew = nil;
        
        if (curOldIdx < [maLocalFeedAdjustments count]) {
            faOld = [maLocalFeedAdjustments objectAtIndex:curOldIdx];
        }
        
        if (curNewIdx < [arrFeeds count]) {
            faNew = [arrFeeds objectAtIndex:curNewIdx];
        }
        
        // - when both arrays are exhausted, we're done.
        if (!faOld && !faNew) {
            break;
        }
        
        // - determine the order of the two items.
        NSComparisonResult compared;
        if (!faOld) {
            compared = NSOrderedDescending;
        }
        else if (!faNew) {
            compared = NSOrderedAscending;
        }
        else {
            compared = [faOld.screenName compare:faNew.screenName];
        }
        
        // - now act on that order
        if (compared == NSOrderedAscending) {
            // - if the old is before the new one, then we must have deleted it.
            if (!maToDelete) {
                maToDelete = [NSMutableArray array];
            }
            [maToDelete addObject:[NSIndexPath indexPathForRow:(NSInteger) curOldIdx inSection:UI_TFV_SEC_FEEDS]];
            curOldIdx++;
        }
        else if (compared == NSOrderedDescending) {
            // - if the old is after the new, we must be inserting.
            if (!maToInsert) {
                maToInsert = [NSMutableArray array];
            }
            [maToInsert addObject:[NSIndexPath indexPathForRow:(NSInteger) [maNewFeeds count] inSection:UI_TFV_SEC_FEEDS]];
            curNewIdx++;
            [maNewFeeds addObject:faNew];
        }
        else {
            // - these are equal, so the question is whether we need to update the item?
            if (!maToUpdate) {
                maToUpdate = [NSMutableArray array];
            }
            if (forceUpdates || ![faNew recommendsTheSameAdjustmentAs:faOld]) {
                [maLocalFeedAdjustments replaceObjectAtIndex:curOldIdx withObject:faNew];
                [maToUpdate addObject:[NSIndexPath indexPathForRow:(NSInteger) curOldIdx inSection:UI_TFV_SEC_FEEDS]];
            }
            curOldIdx++;
            curNewIdx++;
            [maNewFeeds addObject:faNew];
        }
    }

    // - and change it.
    [tvFriendDetail beginUpdates];
    
    // ...update with the current indices
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        // - reloads are necessary to ensure the row height is recomputed.
        if ([maToUpdate count]) {
            [tvFriendDetail reloadRowsAtIndexPaths:maToUpdate withRowAnimation:UITableViewRowAnimationFade];
        }
    }
    else {
        for (NSIndexPath *ip in maToUpdate) {
            UITwitterLocalFeedTableViewCell *tvc = (UITwitterLocalFeedTableViewCell *) [tvFriendDetail cellForRowAtIndexPath:ip];
            if (ip.row < [maLocalFeedAdjustments count]) {
                CS_tfsFriendshipAdjustment *fa = [maLocalFeedAdjustments objectAtIndex:(NSUInteger) ip.row];
                if (fa) {
                    [tvc reconfigureWithFriendshipAdjustment:fa forFriend:self.feedFriend andAnimation:YES];
                }
            }
        }
    }
    
    // - save the updated adjustments
    [self saveNewFeedAdjustments:maNewFeeds];
    
    // ...delete
    if (maToDelete) {
        [tvFriendDetail deleteRowsAtIndexPaths:maToDelete withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    
    // ...insert
    if (maToInsert) {
        [tvFriendDetail insertRowsAtIndexPaths:maToInsert withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    
    [tvFriendDetail endUpdates];
    
}

/*
 *  This notification is sent whenever the friend content is updated.
 */
-(void) notifyFriendsUpdated
{
    [self refreshFriendDataWithAnimation:YES andForceVisibleUpdates:NO];
}

/*
 *  Determine if any adjustments are such that we're waiting on a friend's response and
 *  a well-timed update could help.
 */
-(BOOL) hasAnyAdjustmentsThatCouldBeRefreshed
{
    for (CS_tfsFriendshipAdjustment *fa in maLocalFeedAdjustments) {
        if ([fa canBenefitFromRegularUpdates]) {
            return YES;
        }
    }
    return NO;
}

/*
 *  Create a refresh timer.
 */
-(void) startRefreshTimerIfNotRunning
{
    // - once we start the timer because of an important detail, then it is to our advantage to
    //   just let it run and perform the updates if possible.
    if (!tmRefresh) {
        tmRefresh = [[NSTimer timerWithTimeInterval:UITFVC_REFRESH_INTERVAL target:self selector:@selector(timerFired) userInfo:nil repeats:NO] retain];
        [[NSRunLoop mainRunLoop] addTimer:tmRefresh forMode:NSRunLoopCommonModes];
    }
}

/*
 *  Cancel the pending refresh timer.
 */
-(void) cancelRefreshTimer
{
    [tmRefresh invalidate];
    [tmRefresh release];
    tmRefresh = nil;
}

/*
 *  When the refresh timer is fired, it calls this method.
 */
-(void) timerFired
{
    [self cancelRefreshTimer];
    
    // - now refresh any items that show a possibly pending state.
    for (CS_tfsFriendshipAdjustment *fa in maLocalFeedAdjustments) {
        if ([fa canBenefitFromRegularUpdates]) {
            [fa requestConnectionUpdateForFriend:self.feedFriend];
        }
    }
    
    // - states in this particular screen are very important and can look really out of date when
    //   we don't have a realtime stream.   In order to give the person the best possible chance of seeing when things
    //   change, we're going to keep refreshing them as long as this screen is visible.   Some things that tend to be important
    //   are when a friend accepts my follow request or when an unblock state changes, for example.
    if ([self hasAnyAdjustmentsThatCouldBeRefreshed]) {
        [self startRefreshTimerIfNotRunning];
    }
}

/*
 *  The app just entered the foreground.
 */
-(void) notifyDidEnterForeground
{
    // - and see if wee should fire an overall update.
    if ([self hasAnyAdjustmentsThatCouldBeRefreshed]) {
        [self startRefreshTimerIfNotRunning];
    }
}

/*
 *  The feeds were refreshed.
 */
-(void) notifyDidUpdateFeeds
{
    // - we need to do this for the sake of detecting Twitter app installs, but we need
    //   to wait until the foreground feed refresh completes or we'll get incomplete data.
    [self refreshFriendDataWithAnimation:YES andForceVisibleUpdates:NO];
}
@end

/*****************************************
 UITwitterFriendViewController (table)
 *****************************************/
@implementation UITwitterFriendViewController (table)
/*
 *  Return the number of sections in this table.
 */
-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    if ([maLocalFeedAdjustments count]) {
        return 2;
    }
    else {
        return 1;
    }
}

/*
 *  Return the text for the feed header.
 */
-(NSString *) feedHeaderText
{
    return NSLocalizedString(@"Keep your feeds well-connected so that you and your friend will always find each other's personal messages.", nil);
}

/*
 *  Return a header height.
 */
-(CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == UI_TFV_SEC_FEEDS) {
        CGFloat ret = [UIFeedGenericHeaderFooter recommendedHeightForText:[self feedHeaderText] andScreenWidth:CGRectGetWidth(self.view.bounds)];
        if (![ChatSeal isAdvancedSelfSizingInUse]) {
            ret *= 1.25f;
        }
        return ret;
    }
    return 0.0f;
}

/*
 *  Return a custom view to display the feeds header.
 */
-(UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == UI_TFV_SEC_FEEDS) {
        return [[[UIFeedGenericHeaderFooter alloc] initWithText:[self feedHeaderText] inColor:nil asHeader:YES] autorelease];
    }
    return nil;
}

/*
 *  Return the number of rows in each section in this view.
 */
-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case UI_TFV_SEC_FRIEND:
            return 1;
            break;
            
        case UI_TFV_SEC_FEEDS:
            return (NSInteger) [maLocalFeedAdjustments count];
            break;
    }
    return 1;
}

/*
 *  Return the height for the given row.
 */
-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        return UITableViewAutomaticDimension;
    }
    else {
        UITableViewCell *tvcTmp = nil;
        switch (indexPath.section) {
            case UI_TFV_SEC_FRIEND:
                tvcTmp = [tvFriendDetail dequeueReusableCellWithIdentifier:@"UITwitterFriendTableViewCell"];
                break;
                
            case UI_TFV_SEC_FEEDS:
                tvcTmp = [tvFriendDetail dequeueReusableCellWithIdentifier:@"UITwitterLocalFeedTableViewCell"];
                break;
                
            default:
                tvcTmp = nil;       //  nothing to do.
                break;
        }
        
        return CGRectGetHeight(tvcTmp.bounds);
    }
}

/*
 *  Return a cell for a given section/row.
 */
-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *tvcRet         = nil;
    CS_tfsFriendshipAdjustment *adj = nil;
    switch (indexPath.section) {
        case UI_TFV_SEC_FRIEND:
            tvcRet = [tvFriendDetail dequeueReusableCellWithIdentifier:@"UITwitterFriendTableViewCell"];
            [(UITwitterFriendTableViewCell *) tvcRet reconfigureWithFriend:self.feedFriend andAnimation:NO];
            break;
            
        case UI_TFV_SEC_FEEDS:
            tvcRet = [tvFriendDetail dequeueReusableCellWithIdentifier:@"UITwitterLocalFeedTableViewCell"];
            if (indexPath.row < [maLocalFeedAdjustments count]) {
                adj = [maLocalFeedAdjustments objectAtIndex:(NSUInteger) indexPath.row];
                [(UITwitterLocalFeedTableViewCell *) tvcRet reconfigureWithFriendshipAdjustment:adj forFriend:self.feedFriend andAnimation:NO];
                [(UITwitterLocalFeedTableViewCell *) tvcRet setDelegate:self];
            }
            break;
            
        default:
            tvcRet = nil;
            break;
    }
    return tvcRet;
}

/*
 *  Controls the highlighting of rows.
 */
-(BOOL) tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    // - these rows aren't ever highlighted.
    return NO;
}

/*
 *  When the action button is pressed on a cell, respond to it.
 */
-(void) twitterLocalFeedCellActionWasPressed:(UITwitterLocalFeedTableViewCell *) tlc
{
    NSIndexPath *ipItem = [tvFriendDetail indexPathForCell:tlc];
    if (!ipItem || ipItem.section != UI_TFV_SEC_FEEDS || ipItem.row >= [maLocalFeedAdjustments count]) {
        return;
    }

    // NOTE: for the moment, the only thing we really should be doing inline is to turn on a feed because
    //       everything else warrants a more detailed explanation.
    CS_tfsFriendshipAdjustment *adj = [maLocalFeedAdjustments objectAtIndex:(NSUInteger) ipItem.row];
    NSError *err                    = nil;
    if (![adj applyAdjustmentForFriend:self.feedFriend.userId withError:&err]) {            // - if this works, we should get a feed update notification
        [AlertManager displayFatalAlertWithLowSpaceDetectionUsingTitle:NSLocalizedString(@"Feed Not Adjusted", nil)
                                                               andText:NSLocalizedString(@"Your feed adjustment encountered an unexpected problem.", nil)];
        // - don't write out the feed name because we don't want to divulge it.
        NSLog(@"CS: Failed to adjust local feed.  %@", [err localizedDescription]);
    }
}

/*
 *  Pop open the adjustment detail for a given local feed.
 */
-(void) tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section != UI_TFV_SEC_FEEDS || indexPath.row >= [maLocalFeedAdjustments count]) {
        return;
    }
    
    CS_tfsFriendshipAdjustment *adj = [maLocalFeedAdjustments objectAtIndex:(NSUInteger) indexPath.row];
    if (adj) {
        UITwitterFriendAdjustmentNavigationController *tanc = [UITwitterFriendAdjustmentNavigationController modalControllerForFriend:self.feedFriend forAdjustment:adj];
        [self presentViewController:tanc animated:YES completion:nil];
    }
}
@end