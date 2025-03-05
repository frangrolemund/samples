//
//  UIFeedsOverviewViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/3/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIFeedsOverviewViewController.h"
#import "ChatSeal.h"
#import "ChatSealFeedCollector.h"
#import "UIFeedsOverviewTableViewCell.h"
#import "UIFeedDetailViewController.h"
#import "UIFeedsOverviewPlaceholder.h"
#import "UIFeedsOverviewSharingTableViewCell.h"
#import "UIFeedGenericHeaderFooter.h"
#import "UIMyFriendsInFeedTypeViewController.h"
#import "UIFeedsOverViewFriendsCell.h"
#import "UIAdvancedSelfSizingTools.h"

// - constants
static const CGFloat UIFOVC_STD_ROW_HEIGHT       = 44.0f;
static const CGFloat UIFOVC_STD_FEED_ROW_HEIGHT  = 82.0f;
static const CGFloat UIFOVC_PH_TOOL_TEXT_CX      = 200.0f;

typedef enum {
    UIFOV_SEC_SHARING = 0,
    UIFOV_SEC_FEEDS   = 1,
    
    
    UIFOV_SEC_COUNT
} uifov_section_t;

static const NSUInteger UIFOVC_WARN_MASK  = 0x01;
static const NSUInteger UIFOVC_SHARE_MASK = 0x02;

// - forward declarations
@interface UIFeedsOverviewViewController (internal) <UIVaultFailureOverlayViewDelegate>
+(BOOL) shouldDisplayFeedTabAlert:(BOOL *) wasCached;
-(void) commonConfiguration;
-(void) reconfigureAuthorizationDisplayWithAnimation:(BOOL) animated andUpdateBadges:(BOOL) updateBadges;
-(void) notifyAuthorizationChanged;
-(void) notifyFeedUpdate:(NSNotification *) notification;
-(void) setFatalErrorVisible:(BOOL) isVisible withAnimation:(BOOL) animated;
-(void) reloadSharingCellWithAnimation:(BOOL) animated;
-(NSUInteger) computeWarnShareMask;
-(NSIndexPath *) feedCompatibleIndexFromPath:(NSIndexPath *) ip;
-(BOOL) requiresFriendshipAdjustments;
-(void) notifyFriendshipsUpdated;
-(void) notifyFeedsUpdated;
@end

@interface UIFeedsOverviewViewController (table) <UITableViewDataSource, UITableViewDelegate>
-(void) refreshFeedsWithAnimation:(BOOL) animated;
-(void) updateTableInsets;
-(ChatSealFeed *) feedForIndexPath:(NSIndexPath *) indexPath;
@end

/*****************************
 UIFeedsOverviewViewController
 *****************************/
@implementation UIFeedsOverviewViewController
/*
 *  Object attributes.
 */
{
    BOOL                    reloadBeforeAppear;
    csft_friendship_state_t friendshipState;
    NSArray                 *arrAllFeeds;
    NSUInteger              warnShareMask;
}
@synthesize tvFeeds;
@synthesize vfoFailDisplay;
@synthesize avFeedAuth;

/*
 *  Determine the badge text.
 */
+(NSString *) currentTextForTabBadgeThatIsActive:(BOOL)isActive
{
    static NSString *UIFOV_ALERT = @"!";
    BOOL wasCached               = NO;
    NSString *ret                = nil;
    if ([UIFeedsOverviewViewController shouldDisplayFeedTabAlert:&wasCached]) {
        ret = UIFOV_ALERT;
    }
    
    // - when the value was changed, make sure we update the cached state for the next startup sequence.
    if (!wasCached) {
        [ChatSeal saveFeedCollectorAlertedState:ret ? YES : NO];
    }

    // - return the badge value.
    return ret;
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonConfiguration];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [tvFeeds release];
    tvFeeds = nil;
    
    [vfoFailDisplay release];
    vfoFailDisplay = nil;
    
    [avFeedAuth release];
    avFeedAuth = nil;
    
    [arrAllFeeds release];
    arrAllFeeds = nil;
    
    [super dealloc];
}

/*
 *  Configure the object.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // - wire up the table.
    tvFeeds.dataSource = self;
    tvFeeds.delegate   = self;
    
    // - assign a delegate to the failure display.
    // - NOTE: the rationale behind using this here is to offer one last way of identifying a really bad problem because
    //         it is technically possible for the vault to be open, but somehow the feeds could not be opened.   While that
    //         scenario is improbable, it is one that I'd like to address if possible.  This overlay will allow someone to
    //         know that while the system may know about the Twitter feeds, this app cannot recover any.
    vfoFailDisplay.delegate = self;    

    // - display the initial state.
    self.title = NSLocalizedString(@"Feeds", nil);
    [self reconfigureAuthorizationDisplayWithAnimation:NO andUpdateBadges:NO];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyAuthorizationChanged) name:kChatSealNotifyFeedTypesUpdated object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyFriendshipsUpdated) name:kChatSealNotifyFriendshipsUpdated object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyFeedsUpdated) name:kChatSealNotifyFeedTypesUpdated object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyFeedsUpdated) name:kChatSealNotifyFeedRefreshCompleted object:nil];
}

/*
 *  The view is about to appear.
 */
-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // - ensure the insets are accurate.
    [self updateTableInsets];
    
    // - if the feed table needs updated, we'll do it all at one time.
    if (reloadBeforeAppear || warnShareMask != [self computeWarnShareMask]) {
        [self refreshFeedsWithAnimation:NO];
    }
}

/*
 *  Layout has occurred.
 */
-(void) viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [avFeedAuth updatePreferredTextWidths];
}

/*
 *  The view is about to be rotated.
 */
-(void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self updateTableInsets];
    
    // - if the overlay is visible, we need to redisplay it to ensure it recomputes the placeholder
    if ([vfoFailDisplay isFailureVisible]) {
        [self setFatalErrorVisible:YES withAnimation:YES];
    }
}

/*
 *  The first time we need to use feeds, this method will initiate the first authorization.
 */
-(IBAction)doAuthorize:(id)sender
{
    [avFeedAuth disableAuthorizationButton];
    
    // - we need to use the direct access method in the collector because it will create the
    //   feed collection on the first use.
    [[ChatSeal applicationFeedCollector] openAndQuery:YES withCompletion:^(ChatSealFeedCollector *collector, BOOL success, NSError *err) {
        [self reconfigureAuthorizationDisplayWithAnimation:YES andUpdateBadges:YES];
    }];
}

/*
 *  The user can optionally authorize their feeds can be shared between themselves and their friends.
 */
-(IBAction)doAuthorizeSharing:(id)sender
{
    [ChatSeal displayFeedShareWarningIfNecessaryWithDescription:NO andCompletion:^(void) {
        [self reloadSharingCellWithAnimation:YES];
    }];
}

/*
 *  When the user changes the state of the sharing flag, we must update the relevant state in the 
 *  common location.
 */
-(IBAction)doChangeSharingState:(id)sender
{
    UISwitch *swSharing = (UISwitch *) sender;
    [ChatSeal setFeedsAreSharedWithSealsAsEnabled:swSharing.isOn];
    [self reloadSharingCellWithAnimation:YES];
}

/*
 *  A dynamic type notification was received.
 */
-(void) updateDynamicTypeNotificationReceived
{
    // - anything before version 8.0 didn't really apply dynamic type universally so I'm going
    //   to do the same.
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        return;
    }
    [avFeedAuth updateDynamicTypeNotificationReceived];
    [vfoFailDisplay updateDynamicTypeNotificationReceived];
}

/*
 *  The view has disappeared.
 */
-(void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self.tvFeeds parentViewControllerDidDisappear];
}

@end

/*****************************************
 UIFeedsOverviewViewController (internal)
 *****************************************/
@implementation UIFeedsOverviewViewController (internal)
/*
 *  Determine if the feed tab requires an alert to be displayed.
 */
+(BOOL) shouldDisplayFeedTabAlert:(BOOL *) wasCached
{
    *wasCached                   = NO;
    
    // - the simplest kind of checks.
    if (![[ChatSeal applicationFeedCollector] isConfigured] ||
        (([[ChatSeal applicationFeedCollector] isOpen] && [[ChatSeal applicationFeedCollector] hasBeenAuthQueried] && ![[ChatSeal applicationFeedCollector] isAuthorized]))) {
        return YES;
    }
    
    // - if we're configured and authorized, but not open, that is
    //   a reasonable scenario during startup and it shouldn't look like an error.
    if (![[ChatSeal applicationFeedCollector] isOpen]) {
        // - use the cached value so that we always start with a consistent experience from the last time.
        *wasCached = YES;
        return [ChatSeal lastFeedCollectorAlertedState] ? YES : NO;
    }
    
    // - if the friendship state on any of the types is broken, we need to know about it.
    NSArray *arrTypes = [[ChatSeal applicationFeedCollector] availableFeedTypes];
    for (ChatSealFeedType *ft in arrTypes) {
        if ([ft friendshipState] == CSFT_FS_BROKEN) {
            return YES;
        }
    }
    
    // - if there is no badge, see if any feeds are broken.
    NSArray *arrFeeds = [[ChatSeal applicationFeedCollector] availableFeedsAsSortedList];
    BOOL isBroken     = NO;
    BOOL hasEnabled   = NO;
    for (ChatSealFeed *feed in arrFeeds) {
        if ([feed isEnabled]) {
            hasEnabled = YES;
            if ([feed isInWarningState]) {
                isBroken = YES;
                break;
            }
        }
        else {
            if ([[feed currentPostingProgress] count]) {
                isBroken = YES;
                break;
            }
        }
    }
    
    // - when something is broken, we need to report it.
    if (isBroken || !hasEnabled) {
        return YES;
    }
    
    // - there is no problem.
    return NO;
}

/*
 *  Initial configuration of the object.
 */
-(void) commonConfiguration
{
    arrAllFeeds        = nil;
    reloadBeforeAppear = NO;
    friendshipState    = CSFT_FS_NONE;
    warnShareMask      = [self computeWarnShareMask];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyFeedUpdate:) name:kChatSealNotifyFeedUpdate object:nil];
}

/*
 *  Show/hide the authorization display as needed.
 */
-(void) reconfigureAuthorizationDisplayWithAnimation:(BOOL) animated andUpdateBadges:(BOOL) updateBadges
{
    // - override animation behavior if we're not even the active view.
    if (!self.view.superview) {
        animated = NO;
    }
    
    // - change the badge now because the interesting state has changed.
    if (updateBadges) {
        [[ChatSeal applicationHub] updateFeedAlertBadge];
    }
    
    // - figure out whether we should show the auth dialog or not.
    if ([[ChatSeal applicationFeedCollector] isConfigured]) {
        if ([[ChatSeal applicationFeedCollector] isOpen]) {
            if ([[ChatSeal applicationFeedCollector] isAuthorized]) {
                if ([[ChatSeal applicationFeedCollector] hasAnyFeeds]) {
                    [avFeedAuth setAuthorizationDisplayState:CS_FOAS_HIDDEN andAnimation:animated];
                }
                else {
                    [avFeedAuth setAuthorizationDisplayState:CS_FOAS_NOFEEDS andAnimation:animated];
                }
            }
            else {
                [avFeedAuth setAuthorizationDisplayState:CS_FOAS_NOAUTH andAnimation:animated];
            }
            
            // - always refresh the feeds.
            [self refreshFeedsWithAnimation:YES];
        }
        else {
            [ChatSeal openFeedsIfPossibleWithCompletion:^(BOOL success) {
                [self setFatalErrorVisible:!success withAnimation:animated];
                [[ChatSeal applicationHub] updateFeedAlertBadge];
            }];
        }
    }
    else {
        [avFeedAuth setAuthorizationDisplayState:CS_FOAS_REQUEST andAnimation:animated];
    }
}

/*
 *  Feed authorization has recently changed.
 */
-(void) notifyAuthorizationChanged
{
    [self reconfigureAuthorizationDisplayWithAnimation:YES andUpdateBadges:YES];
}

/*
 *  A change has occurred in a specific feed.
 */
-(void) notifyFeedUpdate:(NSNotification *) notification
{
    if ([[ChatSeal applicationHub] isViewControllerTopOfTheHub:self]) {
        ChatSealFeed *feed = [notification.userInfo objectForKey:kChatSealNotifyFeedUpdateFeedKey];
        if (feed) {
            NSUInteger pos = [arrAllFeeds indexOfObject:feed];
            if (pos != NSNotFound) {
                if (friendshipState != CSFT_FS_NONE) {
                    pos++;
                }
                UIFeedsOverviewTableViewCell *cell = (UIFeedsOverviewTableViewCell *) [tvFeeds cellForRowAtIndexPath:[NSIndexPath indexPathForRow:(NSInteger) pos inSection:UIFOV_SEC_FEEDS]];
                if (cell) {
                    // - these may happen a lot so don't animate if we're not using the tab.
                    [cell reconfigureCellWithFeed:feed withAnimation:YES];
                }
            }
        }
    }
    else {
        // - defer the updates because this view isn't visible and it really doesn't make sense to keep changing the
        //   cells.
        reloadBeforeAppear = YES;
    }
}

/*
 *  Turn the failure view on/off.
 */
-(void) setFatalErrorVisible:(BOOL) isVisible withAnimation:(BOOL) animated
{
    if (isVisible) {
        [vfoFailDisplay showFailureWithTitle:NSLocalizedString(@"Feeds Offline", nil)
                                     andText:NSLocalizedString(@"Your feeds cannot be accessed due to an unexpected problem.", nil)
                                andAnimation:animated];
    }
    else {
        [vfoFailDisplay hideFailureWithAnimation:animated];
    }
}

/*
 *  Generate the failure overlay placeholder for this view.
 */
+(UIImage *) generateVaultFailurePlaceholderOfSize:(CGSize)szPlaceholder withInsets:(UIEdgeInsets)insets andContext:(NSObject *)ctx
{
    if (szPlaceholder.width < 1.0f || szPlaceholder.height < 1.0f) {
        return nil;
    }
    
    // - load the placeholder data from disk.
    NSArray *aPH  = [UIFeedsOverviewPlaceholder feedPlaceholderData];
    
    // - grab a cell we can use for drawing the content.
    UIFeedsOverviewTableViewCell *foc = [[[UIFeedsOverviewTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil] autorelease];
    foc.frame                         = CGRectMake(0.0f, 0.0f, szPlaceholder.width, UIFOVC_STD_FEED_ROW_HEIGHT);
    
    // - draw the placeholder
    UIGraphicsBeginImageContextWithOptions(szPlaceholder, YES, 0.0f);
    
    // ...set the background color.
    [[UIVaultFailureOverlayView standardPlaceholderWhiteAlternative] setFill];
    UIRectFill(CGRectMake(0.0f, 0.0f, szPlaceholder.width, szPlaceholder.height));
    
    // - draw the sharing section
    CGFloat curPos    = insets.top;
    CGRect rcToFill   = CGRectMake(0.0f, curPos, szPlaceholder.width, [UIVaultFailureOverlayView standardHeaderHeight]);
    [UIVaultFailureOverlayView drawStandardHeaderInRect:rcToFill assumingTextPct:0.5f];
    curPos            = CGRectGetMaxY(rcToFill);
    curPos            = [UIVaultFailureOverlayView drawStandardToolLineAtPos:curPos andWithWidth:szPlaceholder.width andShowText:YES ofWidth:UIFOVC_PH_TOOL_TEXT_CX];
    
    // - draw the header for the twitter feeds.
    rcToFill = CGRectMake(0.0f, curPos, szPlaceholder.width, [UIVaultFailureOverlayView standardHeaderHeight]);
    [UIVaultFailureOverlayView drawStandardHeaderInRect:rcToFill assumingTextPct:0.5f];
    curPos           = CGRectGetMaxY(rcToFill);
    
    // ... iterate through the content, starting at the top inset and moving
    //   down to the bottom
    NSUInteger curCell = 0;
    while (curPos < szPlaceholder.height) {
        UIFeedsOverviewPlaceholder *foph = nil;
        if (curCell < [aPH count]) {
            foph = [aPH objectAtIndex:curCell];
        }
        
        CGContextSaveGState(UIGraphicsGetCurrentContext());
        CGContextTranslateCTM(UIGraphicsGetCurrentContext(), 0.0f, curPos);
        [foc drawStylizedVersionWithPlaceholder:foph];
        CGContextRestoreGState(UIGraphicsGetCurrentContext());
        
        curPos += UIFOVC_STD_FEED_ROW_HEIGHT;
        curCell++;
    }
    
    UIImage *ret = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return ret;
}

/*
 *  Generate the failure overlay placeholder for this view.
 */
-(UIImage *) placeholderImageForOverlay:(UIVaultFailureOverlayView *)overlay
{
    CGFloat top = MAX(CGRectGetMaxY(self.navigationController.navigationBar.frame), 40.0f);
    return [UIFeedsOverviewViewController generateVaultFailurePlaceholderOfSize:[ChatSeal appWindowDimensions]
                                                                     withInsets:UIEdgeInsetsMake(top, 0.0f, 0.0f, 0.0f)
                                                                     andContext:nil];
}

/*
 *  Reload the cell that shows the current sharing state.
 */
-(void) reloadSharingCellWithAnimation:(BOOL) animated
{
    [tvFeeds reloadSections:[NSIndexSet indexSetWithIndex:UIFOV_SEC_SHARING] withRowAnimation:animated ? UITableViewRowAnimationAutomatic : UITableViewRowAnimationNone];
}

/*
 *  Compute the mask used to indicate the current sharing state so we know if we should reload.
 */
-(NSUInteger) computeWarnShareMask
{
    NSUInteger ret = 0;
    if ([ChatSeal hasPresentedFeedShareWarning]) {
        ret |= UIFOVC_WARN_MASK;
    }
    if ([ChatSeal canShareFeedsDuringExchanges]) {
        ret |= UIFOVC_SHARE_MASK;
    }
    return ret;
}

/*
 *  Convert the given index into one that can address one of the feeds.
 */
-(NSIndexPath *) feedCompatibleIndexFromPath:(NSIndexPath *) ip
{
    if (ip.section == UIFOV_SEC_FEEDS && friendshipState != CSFT_FS_NONE) {
        if (ip.row == 0) {
            return nil;
        }
        else {
            return [NSIndexPath indexPathForRow:ip.row - 1 inSection:ip.section];
        }
    }
    return ip;
}

/*
 *  Returns whether the friendship cell should be displayed.
 */
-(BOOL) requiresFriendshipAdjustments
{
    return (friendshipState == CSFT_FS_NONE ? NO : YES);
}

/*
 *  When friendship information is changed, this notification is fired.
 */
-(void) notifyFriendshipsUpdated
{
    if ([[ChatSeal applicationHub] isViewControllerTopOfTheHub:self]) {
        ChatSealFeedType *ft              = [[ChatSeal applicationFeedCollector] typeForId:kChatSealFeedTypeTwitter];
        if (friendshipState != [ft friendshipState]) {
            [self refreshFeedsWithAnimation:YES];
        }
    }
    else {
        reloadBeforeAppear = YES;
    }
}

/*
 *  The feeds were updated.
 */
-(void) notifyFeedsUpdated
{
    // - generally we don't respond to feed update notifications, but in this case, we'll watch for overall
    //   online/offline behavior.
    if (vfoFailDisplay.isFailureVisible != ![[ChatSeal applicationFeedCollector] isOpen]) {
        if ([[ChatSeal applicationFeedCollector] isOpen]) {
            [self refreshFeedsWithAnimation:YES];
            [self setFatalErrorVisible:NO withAnimation:YES];
        }
        else {
            [self setFatalErrorVisible:YES withAnimation:YES];
        }
    }
}
@end

/*************************************
 UIFeedsOverviewViewController (table)
 *************************************/
@implementation UIFeedsOverviewViewController (table)
/*
 *  Refresh the active feed list.
 */
-(void) refreshFeedsWithAnimation:(BOOL) animated
{
    NSArray *arrNewFeeds              = [[ChatSeal applicationFeedCollector] availableFeedsAsSortedList];
    NSUInteger newWarnShare           = [self computeWarnShareMask];
    
    ChatSealFeedType *ft              = [[ChatSeal applicationFeedCollector] typeForId:kChatSealFeedTypeTwitter];
    csft_friendship_state_t lastState = friendshipState;
    friendshipState                   = (ft ? [ft friendshipState] : CSFT_FS_NONE);
    
    if ([arrNewFeeds isEqualToArray:arrAllFeeds] && warnShareMask == newWarnShare) {
        // - adjust the friendship state, if necessary.
        if (lastState != friendshipState) {
            UITableViewRowAnimation tvro = animated ? UITableViewRowAnimationAutomatic : UITableViewRowAnimationNone;
            NSIndexPath *ipFriendCell    = [NSIndexPath indexPathForRow:0 inSection:UIFOV_SEC_FEEDS];
            if (friendshipState == CSFT_FS_NONE) {
                [tvFeeds deleteRowsAtIndexPaths:[NSArray arrayWithObject:ipFriendCell] withRowAnimation:tvro];
            }
            else {
                if (lastState == CSFT_FS_NONE) {
                    [tvFeeds insertRowsAtIndexPaths:[NSArray arrayWithObject:ipFriendCell]  withRowAnimation:tvro];
                }
                else {
                    [tvFeeds reloadRowsAtIndexPaths:[NSArray arrayWithObject:ipFriendCell]  withRowAnimation:tvro];
                }
            }
        }
        
        // - the list of feeds is unchanged, but we need to make sure the visible cells are updated.
        BOOL visibleUpdates = NO;
        for (NSIndexPath *ip in tvFeeds.indexPathsForVisibleRows) {
            NSIndexPath *ipFeedCompat = [self feedCompatibleIndexFromPath:ip];
            if (ipFeedCompat && ipFeedCompat.section == UIFOV_SEC_FEEDS && ipFeedCompat.row < [arrAllFeeds count]) {
                ChatSealFeed *feed                = [arrAllFeeds objectAtIndex:(NSUInteger) ipFeedCompat.row];
                UIFeedsOverviewTableViewCell *tvc = (UIFeedsOverviewTableViewCell *) [tvFeeds cellForRowAtIndexPath:ip];
                
                // ...we need to do this in the context of a begin/end update sequence to force the height to be recomputed.
                if ([ChatSeal isAdvancedSelfSizingInUse] && !visibleUpdates) {
                    [tvFeeds beginUpdates];
                    visibleUpdates = YES;
                }
                [tvc reconfigureCellWithFeed:feed withAnimation:animated];
            }
        }
        if (visibleUpdates) {
            [tvFeeds endUpdates];
        }
    }
    else {
        // - new feeds need to be correctly displayed.
        warnShareMask = newWarnShare;
        
        // - use animation if requested.
        if (animated && [arrAllFeeds count]) {
            UIView *vwSnap = [tvFeeds.superview resizableSnapshotViewFromRect:tvFeeds.frame afterScreenUpdates:NO withCapInsets:UIEdgeInsetsZero];
            vwSnap.frame   = tvFeeds.frame;
            [tvFeeds.superview addSubview:vwSnap];
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                vwSnap.alpha = 0.0f;
            }completion:^(BOOL finished) {
                [vwSnap removeFromSuperview];
            }];
            
        }
        
        [arrAllFeeds release];
        arrAllFeeds = [arrNewFeeds retain];
        
        [tvFeeds reloadData];
        
        // - we're only going to update the on-disk placeholder data for major
        //   changes, not incremental things because feeds could change relatively often depending on what is happening.
        [UIFeedsOverviewPlaceholder saveFeedPlaceholderData];
    }
}

/*
 *  The table insets are set up to correctly display the content, considering that there are top/bottom bars.
 */
-(void) updateTableInsets
{
    CGFloat topOffset    = CGRectGetMaxY(self.navigationController.navigationBar.frame);
    CGFloat botOffset    = [[ChatSeal applicationHub] tabBarHeight];
    tvFeeds.contentInset = UIEdgeInsetsMake(topOffset, 0.0f, botOffset, 0.0f);
}

/*
 *  Return the number of sections.
 */
-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return UIFOV_SEC_COUNT;
}

/*
 *  Return a section header.
 */
-(NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case UIFOV_SEC_SHARING:
            return NSLocalizedString(@"Sharing", nil);
            break;
            
        case UIFOV_SEC_FEEDS:
            return NSLocalizedString(@"Twitter", nil);
            break;
            
        default:
            return nil;
            break;
    }
}

/*
 *  Return the appropriate heights for the rows in this table.
 */
-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // - when advanced sizing is available, we'll let it do the work for us.
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        return UITableViewAutomaticDimension;
    }
    else {
        switch (indexPath.section) {
            case UIFOV_SEC_SHARING:
                return UIFOVC_STD_ROW_HEIGHT;
                break;
                
            case UIFOV_SEC_FEEDS:
                indexPath = [self feedCompatibleIndexFromPath:indexPath];
                if (indexPath) {
                    return UIFOVC_STD_FEED_ROW_HEIGHT;
                }
                else {
                    return UIFOVC_STD_ROW_HEIGHT;
                }
                break;
                
            default:
                return 0;
                break;
        }
    }
}

/*
 *  Return the number of rows in the section.
 */
-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case UIFOV_SEC_SHARING:
            return 1;
            break;
            
        case UIFOV_SEC_FEEDS:
            if ([arrAllFeeds count]) {
                return (NSInteger) [arrAllFeeds count] + ([self requiresFriendshipAdjustments] ? 1 : 0);
            }
            else {
                return 0;
            }
            break;
            
        default:
            return 0;
            break;
    }
}

/*
 *  Return a cell for the given item.
 */
-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == UIFOV_SEC_SHARING) {
        UIFeedsOverviewSharingTableViewCell *ostc = (UIFeedsOverviewSharingTableViewCell *) [tvFeeds dequeueReusableCellWithIdentifier:@"UIFeedsOverviewSharingTableViewCell"];
        [ostc reconfigureSharingState];
        return ostc;
    }
    else if (indexPath.section == UIFOV_SEC_FEEDS) {
        indexPath = [self feedCompatibleIndexFromPath:indexPath];
        if (indexPath) {
            UIFeedsOverviewTableViewCell *tvc = (UIFeedsOverviewTableViewCell *) [tvFeeds dequeueReusableCellWithIdentifier:@"UIFeedsOverviewTableViewCell"];
            if (indexPath.row < [arrAllFeeds count]) {
                ChatSealFeed *csf = (ChatSealFeed *) [arrAllFeeds objectAtIndex:(NSUInteger) indexPath.row];
                [tvc reconfigureCellWithFeed:csf withAnimation:NO];
            }
            return tvc;
        }
        else {
            UIFeedsOverViewFriendsCell *fofc = (UIFeedsOverViewFriendsCell *) [tvFeeds dequeueReusableCellWithIdentifier:@"UIFeedsOverViewFriendsCell"];
            if (friendshipState == CSFT_FS_BROKEN) {
                fofc.lFriendsText.textColor = [ChatSeal defaultWarningColor];
                fofc.lFriendsText.text      = NSLocalizedString(@"Build Friendships", nil);
            }
            else {
                fofc.lFriendsText.textColor = [UIColor blackColor];
                fofc.lFriendsText.text      = NSLocalizedString(@"My Friends", nil);
            }
            return fofc;
        }
    }
    return nil;
}

/*
 *  Retrieve the feed for the given index path.
 */
-(ChatSealFeed *) feedForIndexPath:(NSIndexPath *) indexPath
{
    indexPath = [self feedCompatibleIndexFromPath:indexPath];
    if (indexPath.section == UIFOV_SEC_FEEDS && indexPath.row < [arrAllFeeds count]) {
        return (ChatSealFeed *) [arrAllFeeds objectAtIndex:(NSUInteger) indexPath.row];
    }
    return nil;
}

/*
 *  Determine if I should highlight a given row.
 */
-(BOOL) tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == UIFOV_SEC_FEEDS) {
        if ([self requiresFriendshipAdjustments] && indexPath.row == 0) {
            return YES;
        }
        else {
            ChatSealFeed *csf = [self feedForIndexPath:indexPath];
            if (csf && [csf isValid] && [tvFeeds shouldPermitHighlight]) {
                return YES;
            }
        }
    }
    return NO;
}

/*
 *  The row was selected, so we need to move into the detail screen.
 */
-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == UIFOV_SEC_FEEDS) {
        if ([self requiresFriendshipAdjustments] && indexPath.row == 0) {
            UIMyFriendsInFeedTypeViewController *mfftvc = (UIMyFriendsInFeedTypeViewController *) [ChatSeal viewControllerForStoryboardId:@"UIMyFriendsInFeedTypeViewController"];
            [mfftvc setFeedTypeToDisplay:[[ChatSeal applicationFeedCollector] typeForId:kChatSealFeedTypeTwitter]];
            [self.tvFeeds prepareForNavigationPush];
            [self.navigationController pushViewController:mfftvc animated:YES];
        }
        else {
            ChatSealFeed *csf = [self feedForIndexPath:indexPath];
            if (csf) {
                UIFeedDetailViewController *fdvc = (UIFeedDetailViewController *) [ChatSeal viewControllerForStoryboardId:@"UIFeedDetailViewController"];
                if (fdvc) {
                    [fdvc setActiveFeed:csf];
                    [self.tvFeeds prepareForNavigationPush];
                    [self.navigationController pushViewController:fdvc animated:YES];
                }
            }
        }
    }
    [tvFeeds deselectRowAtIndexPath:indexPath animated:YES];
}

/*
 *  Return an appropriate footer for the sharing section.
 */
-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    switch (section) {
        case UIFOV_SEC_SHARING:
            if ([ChatSeal canShareFeedsDuringExchanges]) {
                // - this is the desired state and doesn't require any notification.
                return nil;
            }
            else {
                UIFeedGenericHeaderFooter *genF = [[[UIFeedGenericHeaderFooter alloc] initWithText:[ChatSeal genericFeedSharingEncouragement] inColor:nil asHeader:NO] autorelease];
                return genF;
            }
            break;
            
        default:
            return nil;
            break;
    }
}

/*
 *  Return footer height for the different rows.
 */
-(CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    switch (section) {
        case UIFOV_SEC_SHARING:
            if ([ChatSeal canShareFeedsDuringExchanges]) {
                return 0.0f;
            }
            else {
                return [UIFeedGenericHeaderFooter recommendedHeightForText:[ChatSeal genericFeedSharingEncouragement] andScreenWidth:CGRectGetWidth(self.view.bounds)];
            }
            break;
            
        default:
            return 0.0f;
            break;
    }
}

@end
