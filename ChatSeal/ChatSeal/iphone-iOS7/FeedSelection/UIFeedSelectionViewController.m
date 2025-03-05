//
//  UIFeedSelectionViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 4/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIFeedSelectionViewController.h"
#import "ChatSeal.h"
#import "UIFeedAccessViewController.h"
#import "ChatSealFeedCollector.h"
#import "UIFeedSelectionTableViewCell.h"
#import "AlertManager.h"
#import "CS_twitterFeed.h"
#import "UIFeedsOverviewAuthView.h"

// - constants
static NSString *UIFSVC_STD_CELL = @"feedSelCell";

// - forward declarations
@interface UIFeedSelectionViewController (internal)
-(void) setCompletionBlock:(feedSelectionCompleted) cb;
-(void) completeTheSelectionProcessWithFeed:(ChatSealFeed *) feed;
-(void) refreshFeedsWithAnimation:(BOOL) animated;
-(void) setCurrentFeed:(ChatSealFeed *) feed;
-(void) notifyWillMoveToBackground;
-(void) setActiveAlert:(UIAlertView *) alertView;
-(void) notifyFeedTypesUpdated;
-(void) notifyFeedUpdated:(NSNotification *) notification;
-(void) updateOverlayWithAnimation:(BOOL) animated;
-(void) updateDescriptionLayoutWidth;
-(void) reconfigureSelfSizingItemsAsInit:(BOOL) isInit;
@end

@interface UIFeedSelectionViewController (table) <UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate>
@end

/********************************
 UIFeedSelectionViewController
 ********************************/
@implementation UIFeedSelectionViewController
/*
 *  Object attributes.
 */
{
    feedSelectionCompleted completionBlock;
    BOOL                   isCollectorConfigured;
    ChatSealFeed          *currentFeed;
    ChatSealFeed          *toEnableFeed;
    NSArray                *arrActiveFeeds;
    BOOL                   hasAppeared;
    UIAlertView            *avActive;
    BOOL                   completedLoadFeedOpen;
    BOOL                   showingOverlay;
}
@synthesize tvFeeds;
@synthesize bbiCancel;
@synthesize vwNoFeedsOverlay;
@synthesize lNoFeedsTitle;
@synthesize lNoFeedsDescription;

/*
 *  Return a new view controller that can be presented modally.
 */
+(UIViewController *) viewControllerWithActiveFeed:(ChatSealFeed *) activeFeed andSelectionCompletionBlock:(feedSelectionCompleted) completionBlock
{
    UINavigationController *nc = (UINavigationController *) [ChatSeal viewControllerForStoryboardId:@"UIFeedSelectionNavigationController"];
    if (nc) {
        UIFeedSelectionViewController *fsvc = (UIFeedSelectionViewController *) nc.topViewController;
        [fsvc setCurrentFeed:activeFeed];
        [fsvc setCompletionBlock:completionBlock];
    }
    return nc;
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        currentFeed           = nil;
        completionBlock       = nil;
        isCollectorConfigured = NO;
        arrActiveFeeds        = nil;
        hasAppeared           = NO;
        avActive              = nil;
        completedLoadFeedOpen = NO;
        toEnableFeed          = nil;
        showingOverlay        = NO;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self setCompletionBlock:nil];
    
    [tvFeeds release];
    tvFeeds = nil;
    
    [arrActiveFeeds release];
    arrActiveFeeds = nil;
    
    [currentFeed release];
    currentFeed = nil;
    
    [avActive release];
    avActive = nil;
    
    [toEnableFeed release];
    toEnableFeed = nil;
    
    [bbiCancel release];
    bbiCancel = nil;
    
    [vwNoFeedsOverlay release];
    vwNoFeedsOverlay = nil;
    
    [lNoFeedsTitle release];
    lNoFeedsTitle = nil;
    
    [lNoFeedsDescription release];
    lNoFeedsDescription = nil;
    
    [super dealloc];
}

/*
 *  Configure the object.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // - configure the controls
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        tvFeeds.rowHeight  = [UIFeedSelectionTableViewCell standardRowHeight];
    }
    tvFeeds.delegate       = self;
    tvFeeds.dataSource     = self;
    [tvFeeds registerClass:[UIFeedSelectionTableViewCell class] forCellReuseIdentifier:UIFSVC_STD_CELL];
    vwNoFeedsOverlay.alpha = 0.0f;
    [self reconfigureSelfSizingItemsAsInit:YES];
    
    // - ensure the feeds are available.
    BOOL wasOpen           = [[ChatSeal applicationFeedCollector] isOpen];
    if (wasOpen) {
        isCollectorConfigured = YES;
        completedLoadFeedOpen = YES;
        [self refreshFeedsWithAnimation:NO];
    }
    else {
        isCollectorConfigured = [ChatSeal openFeedsIfPossibleWithCompletion:^(BOOL success) {
            completedLoadFeedOpen = YES;
            if (success && !hasAppeared) {
                [self refreshFeedsWithAnimation:!wasOpen];
            }
        }];
        
        // - if we couldn't open the collector we may want to still avoid asking for permission.
        if (!isCollectorConfigured) {
            isCollectorConfigured = [[ChatSeal applicationFeedCollector] isConfigured];
            if (!isCollectorConfigured) {
                [tvFeeds showEmptyTableOverlayWithRowHeight:[UIFeedSelectionTableViewCell standardRowHeight] andAnimation:NO];
            }
        }
    }
    
    // - watch relevant notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyWillMoveToBackground) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyFeedTypesUpdated) name:kChatSealNotifyFeedTypesUpdated object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyFeedUpdated:) name:kChatSealNotifyFeedUpdate object:nil];
}

/*
 *  The view has appeared.
 */
-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    hasAppeared = YES;
    if (isCollectorConfigured) {
        if (completedLoadFeedOpen && !arrActiveFeeds) {
            [self refreshFeedsWithAnimation:YES];
        }
    }
    else {
        isCollectorConfigured               = YES;
        UIGenericAccessViewController *favc = [UIFeedAccessViewController instantateViewControllerWithCompletion:^(void) {
            [self refreshFeedsWithAnimation:YES];
            [self dismissViewControllerAnimated:YES completion:nil];
        }];
        [self presentViewController:favc animated:YES completion:nil];        
    }
}

/*
 *  In order to ensure the descriptive text is laid out correctly, we need to keep its preferred max layout width
 *  in synch with its dimensions.
 */
-(void) viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    [vwNoFeedsOverlay layoutIfNeeded];
    [self updateDescriptionLayoutWidth];
}

/*
 *  Cancel feed selection.
 */
-(IBAction)doCancel:(id)sender
{
    [self completeTheSelectionProcessWithFeed:nil];
}

/*
 *  A dynamic text update was issued.
 */
-(void) updateDynamicTypeNotificationReceived
{
    // - anything before version 8.0 didn't really apply dynamic type universally so I'm going
    //   to do the same.
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        return;
    }
    [self reconfigureSelfSizingItemsAsInit:NO];
}
@end

/*****************************************
 UIFeedSelectionViewController (internal)
 *****************************************/
@implementation UIFeedSelectionViewController (internal)
/*
 *  Assign the currently selected feed so that we can highlight it.
 */
-(void) setCurrentFeed:(ChatSealFeed *) feed
{
    if (feed != currentFeed) {
        [currentFeed release];
        currentFeed = [feed retain];
    }
}

/*
 *  Assign the completion block.
 */
-(void) setCompletionBlock:(feedSelectionCompleted) cb
{
    if (cb != completionBlock) {
        Block_release(completionBlock);
        completionBlock = nil;
        if (cb) {
            completionBlock = Block_copy(cb);
        }
    }
}

/*
 *  Complete feed selection.
 */
-(void) completeTheSelectionProcessWithFeed:(ChatSealFeed *) feed
{
    if (completionBlock) {
        completionBlock(feed);
        [self setCompletionBlock:nil];
    }
}

/*
 *  Refresh the list of feeds.
 */
-(void) refreshFeedsWithAnimation:(BOOL) animated
{
    NSArray *aNewActive = [[ChatSeal applicationFeedCollector] availableFeedsAsSortedList];

    // - I don't think that while this list is maintained outside the app that it makes sense to do
    //   an explicit table transaction to add/remove/update rows because the origin of these rows is
    //   disconnected from what is being maintained here.  It makes more sense to just fade-in the deltas, in my
    //   opinion.
    BOOL hadContent = [arrActiveFeeds count] ? YES : NO;
    [arrActiveFeeds release];
    arrActiveFeeds = [aNewActive retain];
    if (animated && hadContent) {
        [tvFeeds reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation: UITableViewRowAnimationAutomatic];
    }
    else {
        [UIView performWithoutAnimation:^(void) {
            [tvFeeds reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation: UITableViewRowAnimationNone];
        }];
    }
    
    // - make sure we show/hide the overlay under 8.0 because we're using self-sizing.
    if ([arrActiveFeeds count]) {
        [tvFeeds hideEmptyTableOverlayWithAnimation:animated];
    }
    else {
        [tvFeeds showEmptyTableOverlayWithRowHeight:[UIFeedSelectionTableViewCell standardRowHeight] andAnimation:animated];
    }
    
    // - configure the overlay last.
    [self updateOverlayWithAnimation:animated];
}

/*
 *  Assign a new active alert view.
 */
-(void) setActiveAlert:(UIAlertView *) alertView
{
    avActive.delegate = nil;
    [avActive dismissWithClickedButtonIndex:0 animated:YES];
    [avActive release];
    avActive = [alertView retain];
}

/*
 *  We're about to go to the background, so dismiss any active alert views.
 */
-(void) notifyWillMoveToBackground
{
    [self setActiveAlert:nil];
}

/*
 *  When the feeds are requeried as we become active again, make sure that the list is updated.
 */
-(void) notifyFeedTypesUpdated
{
    [self refreshFeedsWithAnimation:YES];
}

/*
 *  A single feed was updated.
 */
-(void) notifyFeedUpdated:(NSNotification *) notification
{
    ChatSealFeed *feed = [notification.userInfo objectForKey:kChatSealNotifyFeedUpdateFeedKey];
    NSUInteger pos     = [arrActiveFeeds indexOfObject:feed];
    if (pos != NSNotFound) {
        UIFeedSelectionTableViewCell *tvc = (UIFeedSelectionTableViewCell *) [tvFeeds cellForRowAtIndexPath:[NSIndexPath indexPathForRow:(NSInteger) pos inSection:0]];
        [tvFeeds beginUpdates];
        [tvc reconfigureCellWithFeed:feed withAnimation:YES];
        [tvFeeds endUpdates];
    }
}

/*
 *  The overlay may be the most important piece of this screen because it is my opportunity to pitch people
 *  on why they should sign up for Twitter and get them to do so.
 */
-(void) updateOverlayWithAnimation:(BOOL) animated
{
    // - otherwise, we need to show or change it.
    BOOL isAuthorized = YES;
    for (ChatSealFeedType *ft in [[ChatSeal applicationFeedCollector] availableFeedTypes]) {
        if (![ft isAuthorized]) {
            isAuthorized = NO;
            break;
        }
    }
    
    // - when there are feeds, we need to hide the overlay.
    if (isAuthorized && [arrActiveFeeds count]) {
        if (showingOverlay) {
            if (animated) {
                [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                    vwNoFeedsOverlay.alpha = 0.0f;
                }];
            }
            else {
                vwNoFeedsOverlay.alpha = 0.0f;
            }
            showingOverlay = NO;
        }
        return;
    }
    
    NSString *sNextTitle = nil;
    NSString *sNextDesc = nil;
    if (isAuthorized) {
        sNextTitle = [UIFeedsOverviewAuthView warningTextForNoFeedsInHeader:YES];
        sNextDesc  = [UIFeedsOverviewAuthView warningTextForNoFeedsInHeader:NO];
    }
    else {
        // - if we add more feed types later, this will change, but for the moment, I just want to be sure that they stay in synch
        //   because this error is probably the best way to describe the corrective action.
        sNextTitle = [UIFeedsOverviewAuthView warningTextForNoAuthInHeader:YES];
        sNextDesc  = [UIFeedsOverviewAuthView warningTextForNoAuthInHeader:NO];
    }
    
    // ...if it is visible, we need to fade into its next state.
    if (![sNextDesc isEqualToString:lNoFeedsDescription.text]) {
        if (showingOverlay) {
            UIView *vwSnap = [vwNoFeedsOverlay snapshotViewAfterScreenUpdates:YES];
            [vwNoFeedsOverlay addSubview:vwSnap];
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                vwSnap.alpha = 0.0f;
            } completion:^(BOOL finished) {
                [vwSnap removeFromSuperview];
            }];
        }
        
        // - update the text.
        lNoFeedsTitle.text       = sNextTitle;
        lNoFeedsDescription.text = sNextDesc;
        [self updateDescriptionLayoutWidth];
        [vwNoFeedsOverlay setNeedsUpdateConstraints];
        [vwNoFeedsOverlay updateConstraintsIfNeeded];
    }
    
    if (!showingOverlay) {
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            vwNoFeedsOverlay.alpha = 1.0f;
        }];
        showingOverlay = YES;
    }
}

/*
 *  Update the layout width on the description text.
 */
-(void) updateDescriptionLayoutWidth
{
    CGFloat width = CGRectGetWidth(lNoFeedsDescription.bounds);
    if ((int) width != (int) lNoFeedsDescription.preferredMaxLayoutWidth) {
        lNoFeedsDescription.preferredMaxLayoutWidth = width;
        [lNoFeedsDescription setNeedsLayout];
        [vwNoFeedsOverlay setNeedsUpdateConstraints];
    }
    
}

/*
 *  Reconfigure the dynamic type in the items in this view.
 */
-(void) reconfigureSelfSizingItemsAsInit:(BOOL) isInit
{
    // - not supported before v8.0
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        return;
    }
    [UIAdvancedSelfSizingTools constrainAlertLabel:(UILabel *) self.lNoFeedsTitle asHeader:YES duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainAlertLabel:(UILabel *) self.lNoFeedsDescription asHeader:NO duringInitialization:isInit];
}
@end

/***************************************
 UIFeedSelectionViewController (table)
 ***************************************/
@implementation UIFeedSelectionViewController (table)
/*
 *  Return the number of sections to display.
 */
-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    // - this is simple at the moment because we're only choosing feeds, never configuring them.
    return 1;
}

/*
 *  Return the number of rows in this view.
 */
-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger) [arrActiveFeeds count];
}

/*
 *  Return a specific cell for the table view.
 */
-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row < [arrActiveFeeds count]) {
        ChatSealFeed *feed                = [arrActiveFeeds objectAtIndex:(NSUInteger)indexPath.row];
        UIFeedSelectionTableViewCell *tvc = (UIFeedSelectionTableViewCell *) [tvFeeds dequeueReusableCellWithIdentifier:UIFSVC_STD_CELL forIndexPath:indexPath];
        [tvc reconfigureCellWithFeed:feed withAnimation:NO];
        [tvc setActiveFeedEnabled:([[feed feedId] isEqualToString:[currentFeed feedId]])];
        return tvc;
    }
    return nil;
}

/*
 *  When a row is highlighted, we need to determine if we should return it.
 */
-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row < [arrActiveFeeds count]) {
        ChatSealFeed *feed               = [arrActiveFeeds objectAtIndex:(NSUInteger)indexPath.row];
        UIFeedSelectionTableViewCell *fsc = (UIFeedSelectionTableViewCell *) [tableView cellForRowAtIndexPath:indexPath];
        if ([fsc isGoodForSelection]) {
            [self completeTheSelectionProcessWithFeed:feed];
            return;
        }
        
        // - when the feed is not good for selection, however, we'll need to present an alert describing the problem and solution because
        //   the exact cause may be outside of this app's control.
        if ([feed isEnabled] || [feed isDeleted]) {
            // - give some guidance about how to address the problem.
            NSString *sCorrective = [feed correctiveText];
            UIAlertView *av       = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Feed Offline", nil)
                                                               message:sCorrective delegate:nil
                                                     cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                     otherButtonTitles:nil];
            [self setActiveAlert:av];
            [av show];
            [av autorelease];
        }
        else {
            // - when the feed is disabled, we want to prompt the user if they want to enable it.
            NSString *sTitle   = NSLocalizedString(@"Turn On Feed \"%@\"?", nil);
            sTitle             = [NSString stringWithFormat:sTitle, [feed displayName]];
            NSString *sMessage = NSLocalizedString(@"This feed will be used to exchange personal messages.", nil);
            UIAlertView *av = [[UIAlertView alloc] initWithTitle:sTitle
                                                         message:sMessage
                                                        delegate:self
                                               cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                               otherButtonTitles:NSLocalizedString(@"Turn On", nil), nil];
            [self setActiveAlert:av];
            [av show];
            [av autorelease];
            [toEnableFeed release];
            toEnableFeed = [feed retain];
        }
    }
}

/*
 *  The only alert view we respond to is the one that re-enables feeds.  Handle that now.
 */
-(void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    // - the 'Enable' option is option 1
    if (buttonIndex == 1) {
        NSError *err = nil;
        if ([toEnableFeed setEnabled:YES withError:&err]) {
            if (![toEnableFeed isViableMessagingTarget]) {
                [self refreshFeedsWithAnimation:YES];
            }
            else {
                bbiCancel.enabled = NO;
                [self completeTheSelectionProcessWithFeed:toEnableFeed];
            }
        }
        else {
            NSLog(@"CS: Failed to renable the feed %@.  %@", [toEnableFeed displayName], [err localizedDescription]);
            [AlertManager displayErrorAlertWithTitle:NSLocalizedString(@"Feed Interrupted", nil) andText:NSLocalizedString(@"Your feed could not be enabled at this time.  Please consult the Feeds tab for more information.", nil)];
        }
    }
    [toEnableFeed release];
    toEnableFeed = nil;
}
@end
