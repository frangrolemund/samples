//
//  UIMessageOverviewViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 11/1/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UIMessageOverviewViewController.h"
#import "UIChatSealNavigationController.h"
#import "UIMessageDetailViewControllerV2.h"
#import "ChatSeal.h"
#import "UIMessageOverviewMessageCell.h"
#import "UIHubViewController.h"
#import "AlertManager.h"
#import "ChatSealWeakOperation.h"
#import "UISearchScroller.h"
#import "UIFakeKeyboardV2.h"
#import "UIDynamicTypeCompliantEntity.h"
#import "UIMessageOverviewPlaceholder.h"
#import "ChatSealFeedCollector.h"
#import "UITableViewWithSizeableCells.h"

// - constants
static NSString   *UIMO_STD_MSG_CELL    = @"UIMessageOverviewMessageCell";

// - forward declarations.
@interface UIMessageOverviewViewController (internal) <UIMessageDetailViewControllerV2Delegate, UIDynamicTypeCompliantEntity>
-(void) commonConfiguration;
-(void) doAddNewMessage;
-(void) completeNewMessageDisplayWithMessage:(ChatSealMessage *) psm;
-(void) prepareForExistingMessageDisplay:(ChatSealMessage *) psm withCompletion:(void(^)(BOOL prepared)) completionBlock;
-(void) completeExistingMessageDisplayWithRefresh:(BOOL) refreshRow andOptimizedReconfiguration:(BOOL) optReconfig;
-(UIMessageOverviewMessageCell *) activeMessageCell;
-(void) cancelDisplayPrep;
-(void) scheduleDisplayPrep:(NSBlockOperation *) bo;
-(void) updateEditAvailability;
-(void) updateRefreshStatsWithAnimation:(BOOL) animated;
-(void) applyCurrentSearchFilterWithAnimation:(BOOL) animated;
-(void) notifySealChanged;
-(void) displayDeletionFailureForMessage:(NSString *) mid andError:(NSError *) err;
-(void) destroyMessage:(ChatSealMessage *) psm atIndex:(NSIndexPath *) indexPath;
-(void) computeAndAssignRowHeight;
-(void) setVaultFailureStateEnabled:(BOOL) enabled withAnimation:(BOOL) animated;
-(void) notifyLowStorageResolved;
-(void) discardBarUnderlay;
-(void) notifyMessageImported:(NSNotification *) notification;
-(void) notifyCollectorUpdated;
-(void) setNavButtonToEditingInUse:(BOOL) inUse withAnimation:(BOOL) animated;
-(void) setIpCurrent:(NSIndexPath *) ip;
@end

// - transition APIs that are shared with the animation controller.
@interface UIMessageOverviewViewController (detailTransition)
-(void) setActiveMessageAnimationReady:(BOOL) isReadyForAnim;
-(void) setActiveMessagePresentationLocked:(BOOL) isLocked;
-(CGFloat) activeMessageSplitPosition;
-(CGFloat) searchBarSplitPosition;
-(void) closeSearch;
-(void) showSearchIfNotVisible;
-(void) completedReturnFromDetail;
@end

//  - keep the table routines in one place.
@interface UIMessageOverviewViewController (tableMgmt) <UITableViewDelegate, UITableViewDataSource, UIActionSheetDelegate>
-(BOOL) isGoodContentIndexForSelection:(NSIndexPath *) indexPath;
-(void) animateTapOnLockedMessageAtIndex:(NSIndexPath *) indexPath;
-(void) doToggleEditing;
-(void) refreshSealListAfterExistingSealChange;
@end

// - and the search routines also
@interface UIMessageOverviewViewController (search) <UISearchScrollerDelegate>
-(void) killFilterTimer;
-(void) deferredFilter;
@end

// - ensure the action sheet carries the deletion data over with it.
@interface UIMessageDeletionActionSheet : UIActionSheet
@property (nonatomic, retain) ChatSealMessage *psm;
@property (nonatomic, retain) NSIndexPath *indexPath;
@end

// - the vault overlay work is generally in one place.
@interface UIMessageOverviewViewController (vaultOverlay) <UIVaultFailureOverlayViewDelegate>
@end

/********************************
 UIMessageOverviewViewController
 ********************************/
@implementation UIMessageOverviewViewController
/*
 *  Object attributes
 */
{
    BOOL                            hasAppeared;
    BOOL                            sealsChanged;
    NSString                        *currentSearchCriteria;
    NSArray                         *aFilteredMessageList;
    ChatSealMessage                 *psmNew;
    ChatSealMessage                 *psmCurrent;
    NSIndexPath                     *ipCurrent;
    CGFloat                         currentScrollOffset;
    NSBlockOperation                *boMessageDisplayPrep;
    UITableViewWithSizeableCells    *tvTable;
    NSTimer                         *tmFilter;
    UIView                          *vwBarUnderlay;
    BOOL                            applyDeferredImportUpdate;
    BOOL                            isInDetail;
    BOOL                            hasAskedToNotify;
}
@synthesize ssSearchScroller;
@synthesize vfoFailOverlay;

/*
 *  Return the text for the badge on the tab.
 */
+(NSString *) currentTextForTabBadgeThatIsActive:(BOOL) isActive
{
    return nil;
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
    
    ssSearchScroller.delegate = nil;
    [ssSearchScroller release];
    ssSearchScroller = nil;
    
    [vfoFailOverlay release];
    vfoFailOverlay = nil;
    
    [tvTable release];
    tvTable = nil;
    
    [aFilteredMessageList release];
    aFilteredMessageList = nil;
    
    [currentSearchCriteria release];
    currentSearchCriteria = nil;
    
    [psmNew release];
    psmNew = nil;
    
    self.ipCurrent = nil;
    
    [self discardBarUnderlay];
    [self killFilterTimer];
    [self cancelDisplayPrep];
    [self completeExistingMessageDisplayWithRefresh:NO andOptimizedReconfiguration:NO];
    [super dealloc];
}

/*
 *  Configure the object.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // - load up the sub-views.
    // - build the subviews
    tvTable                     = [[UITableViewWithSizeableCells alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    [tvTable registerClass:[UIMessageOverviewMessageCell class] forCellReuseIdentifier:UIMO_STD_MSG_CELL];
    tvTable.separatorStyle      = UITableViewCellSeparatorStyleSingleLine;
    [self computeAndAssignRowHeight];
    tvTable.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    tvTable.delegate            = self;
    tvTable.dataSource          = self;
    
    ssSearchScroller.delegate = self;
    [ssSearchScroller setPrimaryContentView:tvTable];
    [ssSearchScroller setRefreshEnabled:YES];
    [self updateRefreshStatsWithAnimation:NO];
    
    // - wire up the vault overlay for error reporting
    // - NOTE: the rationale behind using this here is to offer one last way of identifying a really bad problem because
    //         it is technically possible for the vault to be open, but somehow the messages could not be opened.   While that
    //         scenario is improbable, it is one that I'd like to address if possible.
    vfoFailOverlay.delegate = self;
    
    // - retrieve the initial content
    [self applyCurrentSearchFilterWithAnimation:NO];
}

/*
 *  When the view is about to appear, clear current selection in the
 *  table.
 */
-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [ssSearchScroller setNavigationController:self.navigationController];       //  not populated until will appear because this is the first one.
    if (hasAppeared) {
        NSIndexPath *ip = [tvTable indexPathForSelectedRow];
        if (ip) {
            [tvTable deselectRowAtIndexPath:ip animated:NO];
        }
    }
    else {
        // - the first time this view is created, we're going to create a view that
        //   can offset the initial blending with the navigation bar, which causes a flicker with the
        //   search bar we have hidden underneath it.
        [self discardBarUnderlay];
        CGRect rc  = self.navigationController.navigationBar.frame;
        vwBarUnderlay                 = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, CGRectGetWidth(rc), CGRectGetMaxY(rc))];
        vwBarUnderlay.backgroundColor = [UIColor whiteColor];
        [self.view addSubview:vwBarUnderlay];
    }
    
    // - show the vault failure the first time.
    if (!hasAppeared && !aFilteredMessageList && ![vfoFailOverlay isFailureVisible]) {
        [self setVaultFailureStateEnabled:YES withAnimation:NO];
    }
}

/*
 *  Track first appearance so that we can auto-adjust the search field's location.
 */
-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [ssSearchScroller setDetectKeyboardResignation:YES];
    [self discardBarUnderlay];
    
    // - if a seal was modified while this view was hidden, check if any of the messages were
    //   affected.
    if (sealsChanged) {
        [self refreshSealListAfterExistingSealChange];
        sealsChanged = NO;
    }
    
    // - we cannot generate the placeholder when this view is first displayed because the
    //   window may not be active yet to get dimensions from.   If we've not yet reported
    //   a problem, do so now.
    if (!aFilteredMessageList) {
        if (![vfoFailOverlay isFailureVisible]) {
            [self setVaultFailureStateEnabled:YES withAnimation:YES];
        }
    }
    else {
        // - when we need to apply a deferred update, favor that, otherwise, insert a new message
        //   if one exists.
        if (applyDeferredImportUpdate) {
            applyDeferredImportUpdate = NO;
            [self applyCurrentSearchFilterWithAnimation:YES];
        }
        else {
            if (psmNew) {
                [self performSelector:@selector(completeNewMessageDisplayWithMessage:) withObject:psmNew afterDelay:0.75f];
                [psmNew release];
                psmNew = nil;
            }
        }
        
        // - when we haven't asked about notification preferences, do that now.  The first time the person sees this screen whether
        //   as a producer or consumer, we want to know what they need.
        if (!hasAskedToNotify) {
            hasAskedToNotify = YES;

            // - this takes care of 2 different scenarios, which I think should happen here because it implies the first experience
            //   is over and we should get their preferences right now.
            //   1.  I am a seal owner and just sent my first message.
            //   2.  I am a seal consumer and just received my first message.
            [ChatSeal checkForLocalNotificationPermissionsIfNecesssary];
        }
    }
    
    // - we're appeared.
    hasAppeared = YES;
}

/*
 *  This method is called before the rotation animation occurs.
 */
-(void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [ssSearchScroller willAnimateRotation];
    
    // - if the overlay is visible, we need to redisplay it to ensure it recomputes the placeholder
    if ([vfoFailOverlay isFailureVisible]) {
        [self setVaultFailureStateEnabled:YES withAnimation:YES];
    }
}

/*
 *  Assign the new message to this view.
 */
-(void) setNewMessage:(ChatSealMessage *) psm
{
    if (!psm) {
        return;
    }
    
    if (hasAppeared) {
        [self completeNewMessageDisplayWithMessage:psm];
    }
    else {
        // - if this view hasn't yet appeared, make sure the new message doesn't appear
        //   before we can animate it in.
        NSMutableArray *maFiltered = [NSMutableArray arrayWithArray:aFilteredMessageList];
        [maFiltered removeObject:psm];
        [aFilteredMessageList release];
        aFilteredMessageList = [maFiltered retain];
        [psmNew release];
        psmNew = [psm retain];
    }
}

/*
 *  Called before layout occurs.
 */
-(void) viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    // - the table needs to be inset on the bottom above the tabs.
    CGFloat tabHeight    = [[ChatSeal applicationHub] tabBarHeight];
    tvTable.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, tabHeight, 0.0f);
}

/*
 *  The search scroller manipulates the nav bar when it is responding to keyboard
 *  notifications, but that cannot happen when the view is hidden or we'll confuse
 *  later views.
 */
-(void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [ssSearchScroller setDetectKeyboardResignation:NO];
}

/*
 *  When this view controller is about to become active, make sure the 
 *  list of messages we can see are updated.
 */
-(void) viewControllerWillBecomeActiveTab
{
    NSArray *arrVisible = [tvTable indexPathsForVisibleRows];
    for (NSIndexPath *ip in arrVisible) {
        if (ip.row < [aFilteredMessageList count]) {
            ChatSealMessage *psm             = [aFilteredMessageList objectAtIndex:(NSUInteger) ip.row];
            UIMessageOverviewMessageCell *moc = (UIMessageOverviewMessageCell *) [tvTable cellForRowAtIndexPath:ip];
            if (!sealsChanged || [psm isLocked] == [moc isPermanentlyLocked]) {
                // - when seals change, we want the animation to be more obvious.
                [moc configureWithMessage:psm andAnimation:YES];
            }
        }
    }
}

@end

/******************************************
 UIMessageOverviewViewController (internal)
 ******************************************/
@implementation UIMessageOverviewViewController (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    // - track appearance so that we can
    //   correctly position the search field.
    hasAppeared               = NO;
    psmNew                    = nil;
    psmCurrent                = nil;
    ipCurrent                 = nil;
    currentScrollOffset       = -1.0f;
    tmFilter                  = nil;
    aFilteredMessageList      = nil;
    sealsChanged              = NO;
    applyDeferredImportUpdate = NO;
    isInDetail                = NO;
    hasAskedToNotify          = NO;
    
    // - set the title.
    self.title = @"ChatSeal";
    
    // - set up the nav buttons.
    [self setNavButtonToEditingInUse:NO withAnimation:NO];
    
    // - no filter by default
    currentSearchCriteria = nil;

    // - watch for interesting events.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifySealChanged) name:kChatSealNotifySealInvalidated object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifySealChanged) name:kChatSealNotifySealRenewed object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifySealChanged) name:kChatSealNotifySealImported object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyLowStorageResolved) name:kChatSealNotifyLowStorageResolved object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyMessageImported:) name:kChatSealNotifyMessageImported object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyCollectorUpdated) name:kChatSealNotifyFeedRefreshCompleted object:nil];
}

/*
 *  Add a new message.
 */
-(void) doAddNewMessage
{
    // - turn off editing if it is enabled
    if (tvTable.editing) {
        [tvTable setEditing:NO animated:YES];
    }
    
    // - if we can't open the existing message, then there is no reason to continue.
    ChatSealMessage *psm = [ChatSeal bestMessageForSeal:[ChatSeal activeSeal] andAuthor:[ChatSeal ownerForActiveSeal]];
    [self prepareForExistingMessageDisplay:psm withCompletion:^(BOOL prepared) {
        if (!prepared) {
            return;
        }
               
        // - show the detail screen.
        UIMessageDetailViewControllerV2 *mdvc = [[UIMessageDetailViewControllerV2 alloc] initWithExistingMessage:psm andForceAppend:YES];
        mdvc.delegate                         = self;
        UINavigationController *nc            = [UIChatSealNavigationController instantantiateNavigationControllerWithRoot:mdvc];
        [mdvc release];
        nc.modalTransitionStyle               = UIModalPresentationFullScreen;
        [self presentViewController:nc animated:YES completion:nil];
    }];
}


/*
 *  The message detail screen is cancelling.
 */
-(void) messageDetailShouldCancel:(UIMessageDetailViewControllerV2 *) md
{
    // - always refresh before we dismiss because it is possible that cancelling a pending message after we changed the font
    //   may have caused the content in this view to be changed.
    [self completeExistingMessageDisplayWithRefresh:NO andOptimizedReconfiguration:YES];
    [self dismissViewControllerAnimated:YES completion:nil];
}

/*
 *  The message detail screen created a new message.
 */
-(void) messageDetail:(UIMessageDetailViewControllerV2 *)md didCompleteWithMessage:(ChatSealMessage *)message
{
    [self dismissViewControllerAnimated:YES completion:^(void){
        [self setNewMessage:message];
        [self completeExistingMessageDisplayWithRefresh:YES andOptimizedReconfiguration:NO];
    }];
}

/*
 *  Present the new message in the table view.
 */
-(void) completeNewMessageDisplayWithMessage:(ChatSealMessage *) psm
{
    // - first figure out where the item should go in our list, which
    //   we'll put into the filtered list because independent of the search
    //   criteria, we want to ensure it is visible right now.
    NSUInteger idx = NSNotFound;
    BOOL       hasItem = NO;
    for (NSUInteger i = 0; i < [aFilteredMessageList count]; i++) {
        ChatSealMessage *psmTmp = [aFilteredMessageList objectAtIndex:i];
        if ([psm.messageId isEqualToString:psmTmp.messageId]) {
            hasItem = YES;
            break;
        }
        
        // - find a location where it can be sorted.
        if (!psm.creationDate || [psm.creationDate compare:psmTmp.creationDate] == NSOrderedAscending) {
            idx = i;
            break;
        }
    }
    
    // - if the array doesn't yet have it, we need to create a new one.
    if (!hasItem) {
        NSMutableArray *maNewList = [NSMutableArray arrayWithArray:aFilteredMessageList];
        if (idx == NSNotFound) {
            idx = [aFilteredMessageList count];
            [maNewList addObject:psm];
        }
        else {
            [maNewList insertObject:psm atIndex:idx];
        }
        [aFilteredMessageList release];
        aFilteredMessageList = [maNewList retain];
        
        // - if we just inserted our first message, hide the overlay.
        if ([aFilteredMessageList count] == 1) {
            [tvTable hideEmptyTableOverlayWithAnimation:YES];
        }
        
        // - scroll to the item right before it.
        [CATransaction begin];
        [CATransaction setCompletionBlock:^(void) {
            // ... and insert the new row.
            [CATransaction begin];
            [CATransaction setCompletionBlock:^(void) {
                // - and make sure it is visible.
                [tvTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:(NSInteger) idx inSection:0] atScrollPosition:UITableViewScrollPositionNone animated:YES];
            }];
            [tvTable insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForItem:(NSInteger) idx inSection:0]] withRowAnimation:UITableViewRowAnimationRight];
            [CATransaction commit];
        }];
        if (idx > 0) {
            [tvTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:(NSInteger) idx-1 inSection:0] atScrollPosition:UITableViewScrollPositionNone animated:YES];
        }
        [CATransaction commit];
        
        // - make sure the placeholders are saved
        [UIMessageOverviewPlaceholder saveVaultMessagePlaceholderData];
    }
}

/*
 *  When presenting an existing message, we must first pin its secure content to optimize the access path.
 *  - if this cannot occur here, then there is no reason to continue presentation.
 *  - we use a completion block here because preparation also scrolls to the message if it isn't already visible.
 */
-(void) prepareForExistingMessageDisplay:(ChatSealMessage *) psm withCompletion:(void(^)(BOOL prepared)) completionBlock
{
    // - nothing to do, just return.
    if (!psm) {
        if (completionBlock) {
            completionBlock(YES);
        }
        return;
    }
    
    if (psmCurrent) {
        NSLog(@"CS-ALERT:  Missing an explicit completion for the current message.");
        [self completeExistingMessageDisplayWithRefresh:YES andOptimizedReconfiguration:NO];
    }
    
    NSError *err = nil;
    if ([psm pinSecureContent:&err]) {
        // - once we're pinned, make sure the rest runs on the main thread.
        [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
            psmCurrent = [psm retain];
            
            // - make sure that the message knows it is is currently being displayed
            //   to prevent import conflicts.
            [psm setIsBeingDisplayed];
            
            // - once it is pinned, we need to scroll to it.
            NSUInteger pos = [aFilteredMessageList indexOfObject:psm];
            [CATransaction begin];
            [CATransaction setCompletionBlock:^(void){
                if (completionBlock) {
                    completionBlock(YES);
                }
            }];
            if (pos != NSNotFound) {
                self.ipCurrent      = [NSIndexPath indexPathForRow:(NSInteger) pos inSection:0];
                currentScrollOffset = tvTable.contentOffset.y;
                if (![tvTable cellForRowAtIndexPath:ipCurrent]) {
                    [tvTable scrollToRowAtIndexPath:ipCurrent atScrollPosition:UITableViewScrollPositionNone animated:YES];
                }
            }
            [CATransaction commit];
        }];
        return;
    }
    
    NSLog(@"CS: Failed to pin secure content.  %@  %@", [err localizedDescription], [err localizedFailureReason]);

    // - if the content could not be pinned, we need to show an alert for the user.
    [AlertManager displayFatalAlertWithLowSpaceDetectionUsingTitle:NSLocalizedString(@"Message Unlock Interrupted", nil)
                                                           andText:NSLocalizedString(@"Your %@ is unable to open this message.", nil)];
    if (completionBlock) {
        completionBlock(NO);
    }
}

/*
 *  After an existing message has been displayed, we need to unpin its contents.
 *  - the idea of using optimized reconfiguration is to minimize flicker when there isn't a high-degree of likelihood the
 *    row has changed.  Otherwise, we see that when we cancel message creation, for example.  Most of the time don't optimize it
 *    and let the code make the choice.
 */
-(void) completeExistingMessageDisplayWithRefresh:(BOOL) refreshRow andOptimizedReconfiguration:(BOOL)optReconfig
{
    BOOL showInvalidatedError = NO;
    NSString *invalTitle      = nil;
    NSString *invalError      = nil;
    if (psmCurrent) {
        ChatSealIdentity *ident = [psmCurrent identityWithError:nil];
        if (ident && ![ident isOwned] && [ident isInvalidated]) {
            showInvalidatedError = YES;
            if ([ident isRevoked]) {
                invalTitle = NSLocalizedString(@"Seal Revoked", nil);
                invalError = NSLocalizedString(@"Your friend has revoked their seal because you took a screenshot of a personal message they secured.", nil);
            }
            else {
                invalTitle = NSLocalizedString(@"Seal Expired", nil);
                invalError = NSLocalizedString(@"Your friend's seal has expired because you haven't received any new messages from them recently.", nil);
            }
        }
        
        // - only update the is-read indicator when we've fully completed the message display.
        [psmCurrent setIsRead:YES withError:nil];
        
        // - we don't always reload the content if nothing changed.
        if (refreshRow) {
            UIMessageOverviewMessageCell *moc = [self activeMessageCell];
            if ([ChatSeal isAdvancedSelfSizingInUse] && !optReconfig && ![moc canUpdatesToMesageBeOptimized:psmCurrent]) {
                // - in iOS8 and beyond the height may have been changed with the modifications.
                if (moc && ipCurrent) {
                    [tvTable reloadRowsAtIndexPaths:[NSArray arrayWithObject:ipCurrent] withRowAnimation:UITableViewRowAnimationFade];
                }
            }
            else {
                // - without advanced self-sizing, we can just assume that the height never changes.
                [moc configureWithMessage:psmCurrent andAnimation:YES];
            }
        }
        
        [psmCurrent unpinSecureContent];
        [psmCurrent release];
        psmCurrent = nil;
    }
    self.ipCurrent = nil;
    isInDetail = NO;
    
    // - when the seal is invalidated 
    if (showInvalidatedError) {
        [AlertManager displayErrorAlertWithTitle:invalTitle andText:invalError];
    }
}

/*
 *  Return the current active message cell.
 */
-(UIMessageOverviewMessageCell *) activeMessageCell
{
    UIMessageOverviewMessageCell *ret = nil;
    if (ipCurrent && psmCurrent) {
        ret = (UIMessageOverviewMessageCell *) [tvTable cellForRowAtIndexPath:ipCurrent];
        
        // - if we don't get a cell, that is very possibly due to the table modifying the content size
        //   when we're getting ready for a return transition.  To make sure we get as close to where we were, we're
        //   going to try to scroll back and see how that goes.
        if (!ret) {
            [tvTable scrollToRowAtIndexPath:ipCurrent atScrollPosition:UITableViewScrollPositionBottom animated:NO];
            ret                 = (UIMessageOverviewMessageCell *) [tvTable cellForRowAtIndexPath:ipCurrent];
        }
        
        // - the last thing is to try to return to the exact prior content offset, if possible.
        if (ret) {
            CGFloat diff        = currentScrollOffset - tvTable.contentOffset.y;
            CGFloat newPos      = CGRectGetMinY(ret.frame) + diff;
            if (newPos + CGRectGetHeight(ret.frame) > 0.0f && newPos < tvTable.contentSize.height) {
                [tvTable setContentOffset:CGPointMake(0.0f, currentScrollOffset) animated:NO];
            }
        }
    }
    return ret;
}

/*
 *  Cancel an active display preparation task.
 */
-(void) cancelDisplayPrep
{
    [boMessageDisplayPrep cancel];
    [boMessageDisplayPrep release];
    boMessageDisplayPrep = nil;
}

/*
 *  Add a new message display preparation task.
 */
-(void) scheduleDisplayPrep:(NSBlockOperation *) bo
{
    [self cancelDisplayPrep];
    boMessageDisplayPrep = [bo retain];
    [[ChatSeal uiPopulationQueue] addOperation:bo];
}

/*
 *  Toggle the edit features based on the current size of the filtered list.
 */
-(void) updateEditAvailability
{
    BOOL isEnabled                                = ([aFilteredMessageList count] ? YES : NO);
    if (!isEnabled) {
        [tvTable setEditing:NO animated:YES];
        [self setNavButtonToEditingInUse:NO withAnimation:YES];
    }
    self.navigationItem.leftBarButtonItem.enabled = isEnabled;
}

/*
 *  Update the statistics when the last update occurred.
 */
-(void) updateRefreshStatsWithAnimation:(BOOL) animated
{
    [ssSearchScroller setDescription:[[ChatSeal applicationFeedCollector] lastFeedRefreshResult] withAnimation:animated];
    [ssSearchScroller setRefreshCompletedWithAnimation:animated];
}

/*
 *  Apply the current search filter to the content in the view.
 */
-(void) applyCurrentSearchFilterWithAnimation:(BOOL) animated
{
    NSError *err          = nil;
    NSArray *arrNewList   = [ChatSeal messageListForSearchCriteria:currentSearchCriteria withItemIdentification:nil andError:&err];
    if (!arrNewList) {
        [aFilteredMessageList release];
        aFilteredMessageList = nil;
        [tvTable reloadData];
        NSLog(@"CS:  Failed to retrieve a message overview list.  %@", [err localizedDescription]);
        [self setVaultFailureStateEnabled:YES withAnimation:animated];
    }
    else if (![arrNewList isEqual:aFilteredMessageList]) {
        // - make sure the current index path is updated if it exists
        if (ipCurrent) {
            // - first downgrade the current cell if it is visible, because we would have 'unlocked'
            //   it.
            UIMessageOverviewMessageCell *moc = (UIMessageOverviewMessageCell *) [tvTable cellForRowAtIndexPath:ipCurrent];
            [moc configureAdvancedDisplayWithMessage:nil];
            
            // - now update the current item with the new array
            // - it is valid to accept an 'NSNotFound' here, which will simply
            //   be a flag to indicate the current item is not in the list of searched-for items.
            NSUInteger pos = [arrNewList indexOfObject:psmCurrent];
            self.ipCurrent = [NSIndexPath indexPathForRow:(NSInteger) pos inSection:0];
        }
        
        // - generate the custom paths for modifying the table.
        NSMutableArray *maToDelete = [NSMutableArray array];
        NSMutableArray *maToInsert = [NSMutableArray array];
        NSUInteger oldIdx = 0;
        NSUInteger newIdx = 0;
        for (;;) {
            // - figure out what is available.
            ChatSealMessage *psmOldFilter = nil;
            if (oldIdx < [aFilteredMessageList count]) {
                psmOldFilter = [aFilteredMessageList objectAtIndex:oldIdx];
            }
            ChatSealMessage *psmNewFilter = nil;
            if (newIdx < [arrNewList count]) {
                psmNewFilter = [arrNewList objectAtIndex:newIdx];
            }
            
            //  - we're out of content.
            if (!psmOldFilter && !psmNewFilter) {
                break;
            }
            
            //  - if the objects are identical, there is nothing to be done and
            //    the check is quick.
            if (psmOldFilter == psmNewFilter) {
                oldIdx++;
                newIdx++;
                continue;
            }
            
            // - if the new list doesn't contain the old item, this is a deletion.
            if (psmOldFilter && ![arrNewList containsObject:psmOldFilter]) {
                [maToDelete addObject:[NSIndexPath indexPathForRow:(NSInteger) oldIdx inSection:0]];
                oldIdx++;
                continue;
            }
            
            // - otherwise, we can assume this is an insertion.
            [maToInsert addObject:[NSIndexPath indexPathForRow:(NSInteger) newIdx inSection:0]];
            newIdx++;
        }

        [aFilteredMessageList release];
        aFilteredMessageList = [arrNewList retain];
        
        if ([aFilteredMessageList count] == 0) {
            [tvTable showEmptyTableOverlayWithRowHeight:70.0f andAnimation:animated];
        }
        else {
            [tvTable hideEmptyTableOverlayWithAnimation:animated];
        }

        // - to get a good snapshot without animation, even with the row animation flag of none, we need to wrap this in a transaction
        [CATransaction begin];
        [CATransaction setDisableActions:!animated];
            [tvTable beginUpdates];
            [tvTable deleteRowsAtIndexPaths:maToDelete withRowAnimation:animated ? UITableViewRowAnimationLeft : UITableViewRowAnimationNone];
            [tvTable insertRowsAtIndexPaths:maToInsert withRowAnimation:animated ? UITableViewRowAnimationRight : UITableViewRowAnimationNone];
            [tvTable endUpdates];
        [CATransaction commit];
        
        // - now hide the failure display if it is present.
        [self setVaultFailureStateEnabled:NO withAnimation:animated];
    }
}

/*
 *  This notification is sent whenever a seal is invalidated or renewed by a friend.  We're not going
 *  to track the exact seal that was involved because the check for cell validity needs to occur when the
 *  view reappears and it is probably better to do all of them at once anyway since multiple modifications could
 *  occur.
 */
-(void) notifySealChanged
{
    if (self.view.superview) {
        [self refreshSealListAfterExistingSealChange];
    }
    else {
        sealsChanged = YES;
    }
}

/*
 *  Display a standard alert when the message could not be deleted.
 */
-(void) displayDeletionFailureForMessage:(NSString *) mid andError:(NSError *) err
{
    NSLog(@"CS:  Failed to delete the message %@.  %@", mid, [err localizedDescription]);
    [AlertManager displayFatalAlertWithLowSpaceDetectionUsingTitle:NSLocalizedString(@"Message Not Deleted", nil)
                                                           andText:NSLocalizedString(@"Your %@ is unable to delete this personal message.", nil)];
}

/*
 *  Destroy a message permanently.
 */
-(void) destroyMessage:(ChatSealMessage *) psm atIndex:(NSIndexPath *) indexPath
{
    NSError *err  = nil;
    NSString *mid = [psm messageId];
    if (![psm destroyMessageWithError:&err]) {
        [self displayDeletionFailureForMessage:mid andError:err];
        return;
    }
    [[ChatSeal applicationFeedCollector] updateFeedsForDeletedMessage:mid];
    
    // - discard the content in the filtered array.
    NSMutableArray *maNewFiltered = [NSMutableArray arrayWithArray:aFilteredMessageList];
    [maNewFiltered removeObjectAtIndex:(NSUInteger) indexPath.row];
    [aFilteredMessageList release];
    aFilteredMessageList = [maNewFiltered retain];
    
    // - if we just deleted the last item and search is visible, clear it out because
    //   it no longer is relevant.
    if ([aFilteredMessageList count] == 0 && [ssSearchScroller isSearchForeground]) {
        [ssSearchScroller closeAllSearchBarsWithAnimation:YES];
    }
    
    // - when we're deleting the final row, we're going to do a little fade out because the default table animation in edit
    //   mode is a little crude
    if ([aFilteredMessageList count] == indexPath.row) {
        UITableViewCell *tvc = [tvTable cellForRowAtIndexPath:indexPath];
        if (tvc) {
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                tvc.alpha = 0.0f;
            }];
        }
    }
    
    if (![aFilteredMessageList count]) {
        [tvTable showEmptyTableOverlayWithRowHeight:70.0 andAnimation:YES];
    }
    
    // - and finally delete the object in the table.
    [tvTable beginUpdates];
    [tvTable deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    [tvTable endUpdates];
    [self updateEditAvailability];
    
    // - and save the placeholder content
    [UIMessageOverviewPlaceholder saveVaultMessagePlaceholderData];
}

/*
 *  Figure out how big a row should be in the table.
 */
-(void) computeAndAssignRowHeight
{
    // - only in prior versions do we compute the row height explicitly.
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        UIMessageOverviewMessageCell *moc = [tvTable dequeueReusableCellWithIdentifier:UIMO_STD_MSG_CELL];
        [moc configureWithMessage:nil andAnimation:NO];
        CGSize sz                         = [moc sizeThatFits:CGSizeMake(320.0f, 1.0f)];
        tvTable.rowHeight                 = sz.height;
    }
}

/*
 *  Dynamic type notification.
 */
-(void) updateDynamicTypeNotificationReceived
{
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        // - NOTE: the table will be automatically restyled.
        [vfoFailOverlay updateDynamicTypeNotificationReceived];
        [ssSearchScroller updateDynamicTypeNotificationReceived];
    }
    else {
        // - this screen supported a bare minimum of self-sizing prior to 8.0, but it was minimal as was the style
        //   in iOS at that time.
        [self computeAndAssignRowHeight];
        [tvTable reloadData];        
    }
}

/*
 *  Show/hide the vault failure display
 */
-(void) setVaultFailureStateEnabled:(BOOL) enabled withAnimation:(BOOL) animated
{
    tvTable.editing = NO;
    if (enabled) {
        [self killFilterTimer];
        self.navigationItem.leftBarButtonItem.enabled  = NO;
        self.navigationItem.rightBarButtonItem.enabled = NO;
        [vfoFailOverlay showFailureWithTitle:NSLocalizedString(@"Messages Locked", nil)
                                     andText:NSLocalizedString(@"Your personal messages cannot be unlocked due to an unexpected problem.", nil)
                                andAnimation:animated];
    }
    else {
        self.navigationItem.rightBarButtonItem.enabled = YES;
        [self updateEditAvailability];
        if ([vfoFailOverlay isFailureVisible]) {
            // - the only way the overlay will appear to match up is when the search bar is retracted.
            [ssSearchScroller closeAllSearchBarsWithAnimation:NO];
        }
        [vfoFailOverlay hideFailureWithAnimation:animated];
    }
}

/*
 *  When low storage has been resolved and we were in an error state, try repopulating the list.
 */
-(void) notifyLowStorageResolved
{
    if ([vfoFailOverlay isFailureVisible]) {
        [self applyCurrentSearchFilterWithAnimation:YES];
    }
}

/*
 *  I create a temporary masking view under the navigation bar when this view
 *  is first created because it will briefly blend the search bar and produce a flicker.
 *  - this seems a bit cleaner than messing with the color of the search scroller to achieve
 *    the same effect.
 */
-(void) discardBarUnderlay
{
    [vwBarUnderlay removeFromSuperview];
    [vwBarUnderlay release];
    vwBarUnderlay = nil;
}

/*
 *  A message was just imported, so we need to probably update the display.
 */
-(void) notifyMessageImported:(NSNotification *) notification
{
    if (self.view.superview) {
        // - first see if we just need to update a single item.
        NSString *msgId = [notification.userInfo objectForKey:kChatSealNotifyMessageImportedMessageKey];
        BOOL refreshed  = NO;
        if (msgId) {
            ChatSealMessage *psm = [ChatSeal messageForId:msgId];
            if (psm) {
                NSUInteger index = [aFilteredMessageList indexOfObject:psm];
                if (index != NSNotFound) {
                    [tvTable reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForItem:(NSInteger) index inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
                    refreshed = YES;
                }
            }
        }
        
        // - when we didn't update a single item, we should make sure that
        //   the full list is re-evaluated.
        if (!refreshed) {
            [self applyCurrentSearchFilterWithAnimation:YES];
        }
    }
    else {
        applyDeferredImportUpdate = YES;
    }
}

/*
 *  When feed refresh is performed, we'll get this notification.
 */
-(void) notifyCollectorUpdated
{
    // - provide a short delay so that the update reacts similarly to Mail.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self updateRefreshStatsWithAnimation:YES];
    });
}

/*
 *  Change the left navbar button to edit/cancel based on whether editing is in effect.
 */
-(void) setNavButtonToEditingInUse:(BOOL) inUse withAnimation:(BOOL) animated
{
    UIBarButtonItem *bbi = nil;
    if (inUse) {
        bbi = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(doToggleEditing)];
    }
    else {
        bbi = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(doToggleEditing)];
    }

    // - because of the way the hub is constructed, the nav item isn't connected to the nav controller after first initialization, so
    //   we need to explicitly force the synchronization to occur.
    self.navigationItem.leftBarButtonItem = bbi;
    [bbi release];
    
    // - compose is only available when we aren't editing.
    bbi = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:self action:@selector(doAddNewMessage)];
    if (inUse) {
        bbi.enabled = NO;
    }
    self.navigationItem.rightBarButtonItem = bbi;
    [bbi release];
    
    [[ChatSeal applicationHub] syncNavigationItemFromTopViewController:self withAnimation:animated];
}

/*
 *  Assign the current index that is being displayed.
 */
-(void) setIpCurrent:(NSIndexPath *) ip
{
    if (ip != ipCurrent) {
        [ipCurrent release];
        ipCurrent           = [ip retain];
        currentScrollOffset = -1.0f;
    }
}

@end

/**************************************************
 UIMessageOverviewViewController (detailTransition)
 **************************************************/
@implementation UIMessageOverviewViewController (detailTransition)
/*
 *  Upgrade/downgrade the active message cell so that it can be opened.
 */
-(void) setActiveMessageAnimationReady:(BOOL) isReadyForAnim
{
    
    UIMessageOverviewMessageCell *moc = [self activeMessageCell];
    if (moc) {
        [moc configureAdvancedDisplayWithMessage:isReadyForAnim ? psmCurrent : nil];
    }
    
    // - when the cell's animatable quality is disabled, take this opportunity
    //   to discard the tracked message.
    if (!isReadyForAnim) {
        [self completeExistingMessageDisplayWithRefresh:YES andOptimizedReconfiguration:NO];
    }
}
 
/*
 *  Animate the lock/unlock of the active message.
 */
-(void) setActiveMessagePresentationLocked:(BOOL) isLocked
{
    UIMessageOverviewMessageCell *moc = [self activeMessageCell];
    if (moc) {
        [moc setLocked:isLocked];
    }
}

/*
 *  When we're transitioning to the detail view, we're going to split the content in half and
 *  animate it opening to show the new view underneath.
 */
-(CGFloat) activeMessageSplitPosition
{
    UIMessageOverviewMessageCell *moc = [self activeMessageCell];
    if (moc) {
        CGRect rc = moc.frame;
        rc = [self.view convertRect:rc fromView:tvTable];
        return CGRectGetMaxY(rc);
    }
    
    // - when there is no item, we'll simply split in the center because
    //   that still gives the impression that things are closing.
    return CGRectGetHeight(self.view.bounds)/2.0f;
}

/*
 *  Return the low-end of the search bar if it is active or something less than zero
 *  if it isn't.
 */
-(CGFloat) searchBarSplitPosition
{
    return [ssSearchScroller foregroundSearchBarHeight];
}

/*
 *  Apply proxied search state from the another source.
 */
-(void) applyProxySearch:(NSString *) searchText
{
    if (searchText == currentSearchCriteria || [searchText isEqualToString:currentSearchCriteria]) {
        return;
    }
    
    [currentSearchCriteria release];
    currentSearchCriteria = [searchText retain];
    [self killFilterTimer];
    [self applyCurrentSearchFilterWithAnimation:NO];
}

/*
 *  Close the search bars.
 */
-(void) closeSearch
{
    if ([ssSearchScroller isSearchForeground]) {
        [self applyProxySearch:nil];
        [ssSearchScroller closeAllSearchBarsWithAnimation:NO];
    }
}

/*
 *  Set the search text explicitly, which is really used during the return navigation.
 */
-(void) showSearchIfNotVisible
{
    if (![ssSearchScroller isSearchForeground]) {
        [self applyProxySearch:@""];
        [ssSearchScroller setActiveSearchText:@"" withAnimation:NO andBecomeFirstResponder:NO];
    }
}

/*
 *  When returning make sure the navigation completes.
 */
-(void) completedReturnFromDetail
{
    if ([ssSearchScroller isSearchForeground]) {
        [ssSearchScroller completeNavigation];
    }
}
@end

/*********************************************
 UIMessageOverviewViewController (tableMgmt)
 *********************************************/
@implementation UIMessageOverviewViewController (tableMgmt)
/*
 *  Called when the scroll view scrolls.  This should be the table.
 */
-(void) scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView == tvTable) {
        CGFloat offset = scrollView.contentOffset.y + scrollView.contentInset.top;
        if ([ssSearchScroller applyProxiedScrollOffset:CGPointMake(0.0f, offset)]) {
            // - when the search scroller uses the offset for its own scrolling,
            //   it shouldn't be applied again here because the outer scroll view
            //   is already translating the table.
            tvTable.contentOffset = CGPointMake(0.0f, -scrollView.contentInset.top);
        }
        [ssSearchScroller setScrollEnabled:(fabs((float)offset) < 1.0f) ? YES : NO];        
    }
}

/*
 *  After we complete our dragging operation, make sure that the search scroller stays
 *  up to date.
 */
-(void) scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (scrollView == tvTable) {
        if (!decelerate) {
            [ssSearchScroller validateContentPositionAfterProxiedScrolling];
        }
    }
}

/*
 *  Make sure we validate also after deceleration.
 */
-(void) scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (scrollView == tvTable) {
        [ssSearchScroller validateContentPositionAfterProxiedScrolling];
    }
}

/*
 *  Return the number of sections to display
 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    //  There is intentionally only a single section because we need
    //  the separators to show up at the width of a single message line by default.
    return 1;
}

/*
 *  Return the number of rows in the given section.
 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    [self updateEditAvailability];
    return (NSInteger) [aFilteredMessageList count];
}

/*
 *  Return the cell for the given row.
 */
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tvTable dequeueReusableCellWithIdentifier:UIMO_STD_MSG_CELL forIndexPath:indexPath];
    
    // - on the iPhone6, the cell is being dequed in a smaller width, which causes layout problems when the cell
    //   is first used and shows up with the date being inset from the right side.
    if ((int) CGRectGetWidth(cell.bounds) < (int) CGRectGetWidth(tvTable.bounds)) {
        cell.bounds = CGRectMake(0.0f, 0.0f, CGRectGetWidth(tvTable.bounds), CGRectGetHeight(cell.bounds));
        [cell layoutIfNeeded];
    }
    
    if (indexPath.row < [aFilteredMessageList count]) {
        ChatSealMessage *psm = (ChatSealMessage *) [aFilteredMessageList objectAtIndex:(NSUInteger) indexPath.row];
        [(UIMessageOverviewMessageCell *) cell configureWithMessage:psm andAnimation:NO];
    }
    return cell;
}

/*
 *  This test confirms whether a content index is suitable for selection.
 *  - which includes whether it has a seal or not.
 */
-(BOOL) isGoodContentIndexForSelection:(NSIndexPath *) indexPath
{
    UIMessageOverviewMessageCell *moc = (UIMessageOverviewMessageCell *) [tvTable cellForRowAtIndexPath:indexPath];
    if (moc) {
        return YES;
    }
    return NO;
}

/*
 *  The only rows that can be highlighted are the content rows.
 */
-(BOOL) tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    // - don't permit a selection until we finish the detail-to-overview transition or it will
    //   lock hard.
    if (isInDetail || ![tvTable shouldPermitHighlight]) {
        return NO;
    }
    return [self isGoodContentIndexForSelection:indexPath];
}

/*
 *  Prevent selection in all but the content area.
 */
-(NSIndexPath *) tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self isGoodContentIndexForSelection:indexPath]) {
        return indexPath;
    }
    return nil;
}

/*
 *  Animate the cell in a way that indicates it can't be used.
 */
-(void) animateTapOnLockedMessageAtIndex:(NSIndexPath *) indexPath
{
    UITableViewCell *tvc = [tvTable cellForRowAtIndexPath:indexPath];
    if (!tvc) {
        return;
    }
    
    UIView *vwShadow         = [[[UIView alloc] initWithFrame:tvc.frame] autorelease];
    vwShadow.backgroundColor = [UIColor colorWithRed:0.7f green:0.7f blue:0.7f alpha:1.0f];
    CGFloat curZ             = tvc.layer.zPosition;
    
    [tvc.superview addSubview:vwShadow];
    vwShadow.layer.zPosition = -100.0f;
    tvc.layer.zPosition      = -50.0f;
    
    CGFloat slideDuration    = 0.15f;
    [UIView animateWithDuration:slideDuration delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
        tvc.transform = CGAffineTransformMakeTranslation(0.0f, -CGRectGetHeight(tvc.frame)*0.10f);
    }completion:^(BOOL finished) {
        [UIView animateWithDuration:slideDuration delay:0.0f usingSpringWithDamping:0.8f initialSpringVelocity:0.0f options:0 animations:^(void) {
            tvc.transform = CGAffineTransformIdentity;
        }completion:^(BOOL finished2) {
            [vwShadow removeFromSuperview];
            tvc.layer.zPosition = curZ;
        }];
    }];
}

/*
 *  A row was selected.
 */
-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row < [aFilteredMessageList count]) {
        UIMessageOverviewMessageCell *ms = (UIMessageOverviewMessageCell *) [tvTable cellForRowAtIndexPath:indexPath];
        if ([ms isPermanentlyLocked]) {
            [tvTable deselectRowAtIndexPath:indexPath animated:YES];
            [self animateTapOnLockedMessageAtIndex:indexPath];
            return;
        }
        
        // - if the search scroller is using the keyboard, hide that now because it won't make sense on the return trip.
        BOOL isFirst = [ssSearchScroller isFirstResponder];
        if (isFirst && [currentSearchCriteria length]) {
            [UIFakeKeyboardV2 setKeyboardMaskingEnabled:YES];
        }
        [ssSearchScroller resignFirstResponder];
      
        // - we're going to use the selection briefly to show that the item was tapped, but it isn't going
        //   to last because it will make the whole experience a little too gray. 
        [tvTable deselectRowAtIndexPath:indexPath animated:YES];
        
        // - now we need to prepare the message for display by pinning it, which will occur in the background and
        //   give the deselection a moment to complete.
        ChatSealWeakOperation *wo = [ChatSealWeakOperation weakOperationWrapper];
        ChatSealMessage *psm      = [aFilteredMessageList objectAtIndex:(NSUInteger) indexPath.row];
        NSBlockOperation *boTmp    = [NSBlockOperation blockOperationWithBlock:^(void) {
            [self prepareForExistingMessageDisplay:psm withCompletion:^(BOOL prepared) {
                if (prepared && ![wo isCancelled]) {
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
                        NSString *passSearch = nil;
                        if ([ssSearchScroller isSearchForeground]) {
                            [ssSearchScroller beginNavigation];
                            passSearch = currentSearchCriteria ? currentSearchCriteria : @"";
                        }
                        
                        // - apply the search filter
                        [psm applyFilter:passSearch];
                        
                        // - and open the detail
                        UIMessageDetailViewControllerV2 *mdvc = [[UIMessageDetailViewControllerV2 alloc] initWithExistingMessage:psm
                                                                                                                  andForceAppend:NO
                                                                                                                  withSearchText:passSearch
                                                                                                         andBecomeFirstResponder:isFirst];
                        [self.navigationController pushViewController:mdvc animated:YES];
                        [mdvc release];
                        
                        // - make sure that we prevent all other transitions until this one completes
                        isInDetail = YES;
                    }];
                }
                else {
                    // - make sure this always happens on the main thread.
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
                        [UIFakeKeyboardV2 setKeyboardMaskingEnabled:NO];
                    }];
                }
            }];
        }];
        [wo setOperation:boTmp];
        [self scheduleDisplayPrep:boTmp];
    }
}

/*
 *  This method checks if editing is supported for the given row.
 */
-(BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    UIMessageOverviewMessageCell *moc = (UIMessageOverviewMessageCell *) [tvTable cellForRowAtIndexPath:indexPath];
    if (moc) {
        return YES;
    }
    return NO;
}

/*
 *  Moving rows is never permitted.
 */
-(BOOL) tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

/*
 *  Process the action sheet tasks.
 */
-(void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ([actionSheet isKindOfClass:[UIMessageDeletionActionSheet class]]) {
        // - the deletion of a message thread.
        if (buttonIndex == 0) {
            UIMessageDeletionActionSheet *mdas = (UIMessageDeletionActionSheet *) actionSheet;
            [self destroyMessage:mdas.psm atIndex:mdas.indexPath];
        }
    }
}

/*
 *  Editing has occurred.
 */
-(void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle != UITableViewCellEditingStyleDelete) {
        return;
    }
    
    if (indexPath.row < [aFilteredMessageList count]) {
        ChatSealMessage *psm = [aFilteredMessageList objectAtIndex:(NSUInteger) indexPath.row];
        if (psm) {
            // - we may want to confirm this deletion, but that requires we look in the message first
            NSError *err         = nil;
            BOOL      isLocked   = [psm isLocked];
            
            // - when the message is not locked we should consistently require confirmation, regardless of
            //   the entry count.
            if (!isLocked) {
                // - we need an accurate count to confirm with.
                NSInteger numEntries = -1;
                if ([psm pinSecureContent:&err]) {
                    numEntries = [psm numEntriesWithError:&err];
                    [psm unpinSecureContent];
                }
                
                // - display the action sheet for confirmation.
                NSUInteger numPending = [[ChatSeal applicationFeedCollector] numberOfPendingPostsForMessage:psm.messageId];
                NSString *sTitle = nil;
                if (numEntries < 1) {
                    sTitle = NSLocalizedString(@"This message has personal content.", nil);
                }
                else if (numEntries == 1) {
                    if (numPending == 1) {
                        sTitle = NSLocalizedString(@"This message has one undelivered post.", nil);
                    }
                    else {
                        sTitle = NSLocalizedString(@"This message has one personal post.", nil);
                    }
                }
                else {
                    sTitle = NSLocalizedString(@"This message has %d personal posts.", nil);
                    sTitle = [NSString stringWithFormat:sTitle, numEntries];
                    
                    if (numPending) {
                        NSString *sAlt = nil;
                        if (numPending == numEntries) {
                            sTitle = NSLocalizedString(@"This message has %d undelivered posts.", nil);
                            sTitle = [NSString stringWithFormat:sTitle, numEntries];
                            sAlt   = @"";
                        }
                        else if (numPending == 1) {
                            sAlt = NSLocalizedString(@"\n(one of these is undelivered)", nil);
                        }
                        else {
                            sAlt = NSLocalizedString(@"\n(%u of these are undelivered)", nil);
                            sAlt = [NSString stringWithFormat:sAlt, numPending];
                        }
                        sTitle = [NSString stringWithFormat:@"%@%@", sTitle, sAlt];
                    }
                }

                UIMessageDeletionActionSheet *mdas = [[[UIMessageDeletionActionSheet alloc] initWithTitle:sTitle delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", nil) destructiveButtonTitle:NSLocalizedString(@"Delete This Message", nil) otherButtonTitles:nil] autorelease];
                mdas.psm       = psm;
                mdas.indexPath = indexPath;
                [mdas showInView:self.view];
            }
            else {
                [self destroyMessage:psm atIndex:indexPath];
            }
        }
    }
}

/*
 *  Turn editing on/off.
 */
-(void) doToggleEditing
{
    BOOL willBeInUse = !tvTable.editing;
    [tvTable setEditing:willBeInUse animated:YES];
    [self setNavButtonToEditingInUse:willBeInUse withAnimation:YES];
}

/*
 *  When seals are invalidated or renewed, we need to make sure the seal list is updated to reflect the modifications.
 */
-(void) refreshSealListAfterExistingSealChange
{
    BOOL hasConverts = NO;
    NSArray *arrIndx = [tvTable indexPathsForVisibleRows];
    for (NSIndexPath *ip in arrIndx) {
        if (ip.row < [aFilteredMessageList count]) {
            ChatSealMessage *psm             = [aFilteredMessageList objectAtIndex:(NSUInteger) ip.row];
            UIMessageOverviewMessageCell *moc = (UIMessageOverviewMessageCell *) [tvTable cellForRowAtIndexPath:ip];
            if (moc) {
                if ([psm isLocked] != [moc isPermanentlyLocked]) {
                    hasConverts = YES;
                    [moc configureWithMessage:psm andAnimation:YES];
                }
            }
        }
    }
    
    // - when any messages are now locked, make sure the placeholder content reflects that.
    if (hasConverts) {
        [UIMessageOverviewPlaceholder saveVaultMessagePlaceholderData];
    }
}

@end

/******************************************
 UIMessageOverviewViewController (search)
 ******************************************/
@implementation UIMessageOverviewViewController (search)
/*
 *  This method is called when the search scroller detects it should perform a refresh of content.
 */
-(void) searchScrollerRefreshTriggered:(UISearchScroller *) ss
{
    NSError *err = nil;
    if (![[ChatSeal applicationFeedCollector] refreshActiveFeedsAndAdvancePendingOperationsWithError:&err]) {
        NSLog(@"CS: Failed to explicitly refresh the active feeds.  %@", [err localizedDescription]);
        [ssSearchScroller setRefreshCompletedWithAnimation:YES];
    }
}

/*
 *  Destroy the filter timer.
 */
-(void) killFilterTimer
{
    [tmFilter invalidate];
    [tmFilter release];
    tmFilter = nil;
}

/*
 *  Apply a filter after some period of time.
 */
-(void) deferredFilter
{
    [self killFilterTimer];
    [self applyCurrentSearchFilterWithAnimation:YES];
}

/*
 *  When search text is modified, this method is called.
 */
-(void) searchScroller:(UISearchScroller *) ss textWasChanged:(NSString *) searchText
{
    if (searchText == currentSearchCriteria ||
        [searchText isEqualToString:currentSearchCriteria]) {
        return;
    }
    [currentSearchCriteria release];
    currentSearchCriteria = [searchText retain];
    if (tmFilter) {
        [tmFilter setFireDate:[NSDate dateWithTimeIntervalSinceNow:[ChatSeal standardSearchFilterDelay]]];
    }
    else {
        tmFilter = [[NSTimer scheduledTimerWithTimeInterval:[ChatSeal standardSearchFilterDelay] target:self selector:@selector(deferredFilter) userInfo:nil repeats:NO] retain];
    }
}

/*
 *  When the search bar is hidden, we need to ensure that the filter timer is also
 *  removed.
 */
-(void) searchScroller:(UISearchScroller *)ss didMoveToForegroundSearch:(BOOL)isForeground
{
    if (!isForeground) {
        // - this may be called indirectly when coming back from detail and
        //   we don't want a competing animation during the snapshot process.
        if (currentSearchCriteria) {
            [self killFilterTimer];
            [currentSearchCriteria release];
            currentSearchCriteria = nil;
            [self applyCurrentSearchFilterWithAnimation:YES];
        }
    }
}

/*
 *  When the search behavior is shifting its priority, this method determines if the bar should
 *  still be visible.  It should not if the table has been moved at all.
 */
-(BOOL) searchScroller:(UISearchScroller *) ss shouldCollapseAllAfterMoveToForeground:(BOOL) isForeground
{
    if (!isForeground && tvTable.contentOffset.y > 0.0f) {
        return YES;
    }
    return NO;
}

/*
 *  When cancellation is about to occur, coordinate the dismissal animations.
 */
-(void) searchScrollerWillCancel:(UISearchScroller *)ss
{
    // - equivalent to the background move that will occur in a moment.
    [self searchScroller:ss didMoveToForegroundSearch:NO];
}
@end

/**********************************
 UIMessageDeletionActionSheet
 **********************************/
@implementation UIMessageDeletionActionSheet
@synthesize psm;
@synthesize indexPath;

/*
 *  Free the object
 */
-(void) dealloc
{
    [psm release];
    psm = nil;
    
    [indexPath release];
    indexPath = nil;
    [super dealloc];
}

@end

/**********************************************
 UIMessageOverviewViewController (vaultOverlay)
 **********************************************/
@implementation UIMessageOverviewViewController (vaultOverlay)
/*
 *  Generate a vault overlay image to return to the overlay view.
 */
+(UIImage *) generateVaultFailurePlaceholderOfSize:(CGSize) szPlaceholder withInsets:(UIEdgeInsets) insets andContext:(NSObject *) ctx
{
    if (szPlaceholder.width < 1.0f || szPlaceholder.height < 1.0f) {
        return nil;
    }
    
    // - load the placeholder data from disk.
    NSArray *aPH  = [UIMessageOverviewPlaceholder vaultMessagePlaceholderData];
    
    // - grab a cell we can use for drawing the content.
    UIMessageOverviewMessageCell *momc = [[[UIMessageOverviewMessageCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil] autorelease];
    CGSize szCell                      = [momc sizeThatFits:CGSizeMake(szPlaceholder.width, 1.0f)];
    momc.frame                         = CGRectMake(0.0f, 0.0f, szCell.width, szCell.height);
    
    // - draw the placeholder
    UIGraphicsBeginImageContextWithOptions(szPlaceholder, YES, 0.0f);
    
    // ...set the background color.
    [[UIVaultFailureOverlayView standardPlaceholderWhiteAlternative] setFill];
    UIRectFill(CGRectMake(0.0f, 0.0f, szPlaceholder.width, szPlaceholder.height));
    
    // ... iterate through the content, starting at the top inset and moving
    //   down to the bottom
    CGFloat curPos     = insets.top;
    NSUInteger curCell = 0;
    while (curPos < szPlaceholder.height) {
        UIMessageOverviewPlaceholder *moph = nil;
        if (curCell < [aPH count]) {
            moph = [aPH objectAtIndex:curCell];
        }
        
        CGContextSaveGState(UIGraphicsGetCurrentContext());
        CGContextTranslateCTM(UIGraphicsGetCurrentContext(), 0.0f, curPos);
        [momc drawStylizedVersionWithPlaceholder:moph];
        CGContextRestoreGState(UIGraphicsGetCurrentContext());
        
        curPos += szCell.height;
        curCell++;
    }
    
    UIImage *ret = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return ret;
}

/*
 *  Return a placeholder through the delegate protocol.
 */
-(UIImage *) placeholderImageForOverlay:(UIVaultFailureOverlayView *)overlay
{
    // - I'm intentionally not using context for this because I want this to always work statically.
    return [UIMessageOverviewViewController generateVaultFailurePlaceholderOfSize:[ChatSeal appWindowDimensions]
                                                                       withInsets:UIEdgeInsetsMake(CGRectGetMaxY(self.navigationController.navigationBar.frame), 0.0f, 0.0f, 0.0f)
                                                                        andContext:nil];
}
@end
