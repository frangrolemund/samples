//
//  UIMyFriendsInFeedTypeViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/15/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIMyFriendsInFeedTypeViewController.h"
#import "ChatSeal.h"
#import "ChatSealFeedCollector.h"
#import "UIMyFriendTableViewCell.h"
#import "UIFeedGenericHeaderFooter.h"
#import "AlertManager.h"
#import "UIFriendManagementViewController.h"
#import "UIFriendAdditionViewController.h"
#import "UIChatSealNavigationController.h"
#import "UIAdvancedSelfSizingTools.h"

// - constants
static const NSInteger UI_MYF_CONFIRM_DELETE = 0;
static const CGFloat   UI_MYF_HEADER_PAD     = 8.0f;

// - forward declarations
@interface UIMyFriendsInFeedTypeViewController (internal) <UIActionSheetDelegate>
-(void) commonConfiguration;
-(NSArray *) updatedFriends;
-(void) refreshFriendsListWithAnimation:(BOOL) animated;
-(void) notifyFriendsUpdated;
-(void) notifyFeedFriendUpdated:(NSNotification *) notification;
-(void) updatePreferredTextWidths;
-(void) doAddFriend;
-(void) reconfigureSelfSizingItemsAsInit:(BOOL) isInit;
@end

@interface UIMyFriendsInFeedTypeViewController (table) <UITableViewDataSource, UITableViewDelegate>
@end


/************************************
 UIMyFriendsInFeedTypeViewController
 ************************************/
@implementation UIMyFriendsInFeedTypeViewController
/*
 *  Object attributes.
 */
{
    BOOL               hasAppeared;
    BOOL               reloadFriendsOnAppearance;
    ChatSealFeedType   *feedType;
    NSArray            *arrMyFriends;
    ChatSealFeedFriend *toDelete;
    BOOL               isEditing;
    BOOL               requiresPendingEditRefresh;
    BOOL               wasAdding;
}
@synthesize tvFriends;
@synthesize vwNoFriends;
@synthesize lNoFriendsTitle;
@synthesize lNoFriendsDesc;

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
 *  Destroy the object.
 */
-(void) dealloc
{
    [feedType release];
    feedType = nil;
    
    [arrMyFriends release];
    arrMyFriends = nil;
    
    [tvFriends release];
    tvFriends = nil;
    
    [vwNoFriends release];
    vwNoFriends = nil;
    
    [toDelete release];
    toDelete = nil;
    
    [lNoFriendsTitle release];
    lNoFriendsTitle = nil;
    
    [lNoFriendsDesc release];
    lNoFriendsDesc = nil;
    
    [super dealloc];
}

/*
 *  Configure after loading.
 */
-(void) viewDidLoad
{
    [super viewDidLoad];
    
    // - move the no friends view to the front and hide it until
    //   it is needed.
    [self.view bringSubviewToFront:vwNoFriends];
    vwNoFriends.alpha = 0.0f;
    [self reconfigureSelfSizingItemsAsInit:YES];
    
    // - wire up the table.
    tvFriends.dataSource = self;
    tvFriends.delegate   = self;
    [self refreshFriendsListWithAnimation:NO];
    
    // - and the friend update notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyFriendsUpdated) name:kChatSealNotifyFriendshipsUpdated object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyFeedFriendUpdated:) name:kChatSealNotifyFeedFriendshipUpdated object:nil];
}

/*
 *  The view is about to appear
 */
-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // - reload the friends if necessary.
    if (reloadFriendsOnAppearance) {
        reloadFriendsOnAppearance = NO;
        if (!wasAdding) {
            [self refreshFriendsListWithAnimation:NO];
        }
    }
}

/*
 *  The view has just appeared.
 */
-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    hasAppeared = YES;
    
    // - if we were adding friends, make sure that the content is updated right away without waiting for the notification.
    if (wasAdding) {
        wasAdding = NO;
        [self refreshFriendsListWithAnimation:YES];
    }
}

/*
 *  Do some post-layout activities.
 */
-(void) viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self updatePreferredTextWidths];
}

/*
 *  Assign the type to use for displaying friend information.
 */
-(void) setFeedTypeToDisplay:(ChatSealFeedType *) ft
{
    if (feedType != ft) {
        [feedType release];
        feedType   = [ft retain];
        self.title = [ft friendsDisplayTitle];
        UIBarButtonItem *bbiAdd = nil;
        if ([ft canAddFriendsManually]) {
            bbiAdd = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(doAddFriend)] autorelease];
        }
        self.navigationItem.rightBarButtonItem = bbiAdd;
    }
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
    [self reconfigureSelfSizingItemsAsInit:NO];
}

@end

/***********************************************
 UIMyFriendsInFeedTypeViewController (internal)
 ***********************************************/
@implementation UIMyFriendsInFeedTypeViewController (internal)
/*
 *  Configure the object after creation.
 */
-(void) commonConfiguration
{
    hasAppeared                = NO;
    reloadFriendsOnAppearance  = NO;
    feedType                   = nil;
    arrMyFriends               = nil;
    toDelete                   = nil;
    isEditing                  = NO;
    requiresPendingEditRefresh = NO;
    wasAdding                  = NO;
}

/*
 *  Return a new array of friends to display.
 */
-(NSArray *) updatedFriends
{
    // - NOTE: you can manufacture friends lists here to test the refresh...
    return [feedType feedFriends];
}

/*
 *  Refresh my list of friends.
 */
-(void) refreshFriendsListWithAnimation:(BOOL) animated
{
    // - don't allow refreshes while we're in the middle of editing (choosing someone to ignore)
    //   because it will confuse the deletion process and the sort order changes a lot.
    if (isEditing) {
        requiresPendingEditRefresh = YES;
        return;
    }
    
    // - first figure out what has changed.
    NSMutableArray *maNewFriends = [NSMutableArray arrayWithArray:[self updatedFriends]];
    NSMutableArray *maUpdate   = nil;
    NSMutableArray *maDelete   = nil;
    NSMutableArray *maInsert   = nil;
    if (animated && [maNewFriends count]) {
        maUpdate = [NSMutableArray array];
        maDelete = [NSMutableArray array];
        maInsert = [NSMutableArray array];
        
        NSUInteger curIndex = 0;
        NSUInteger newIndex = 0;
        for (curIndex = 0; curIndex < [arrMyFriends count];) {
            // - grab a couple entries to compare
            ChatSealFeedFriend *csffCur = [arrMyFriends objectAtIndex:curIndex];
            ChatSealFeedFriend *csffNew = nil;
            if (newIndex < [maNewFriends count]) {
                csffNew = [maNewFriends objectAtIndex:newIndex];
            }
            
            // - is this an update?
            if (csffNew && [csffNew isEqual:csffCur]) {
                if (csffNew.friendVersion != csffCur.friendVersion) {
                    [maUpdate addObject:[NSIndexPath indexPathForRow:(NSInteger) curIndex inSection:0]];
                }
                curIndex++;
                newIndex++;
            }
            else {
                // - insertion or deletion?
                // ...if the old value doesn't exist in the new array, we need to delete
                NSUInteger pos = [maNewFriends indexOfObject:csffCur];
                if (pos == NSNotFound) {
                    [maDelete addObject:[NSIndexPath indexPathForRow:(NSInteger) curIndex inSection:0]];
                    curIndex++;
                }
                else {
                    // ...the old value exists, which means we need to insert new items until we get to
                    //    one that matches.
                    if (pos > newIndex) {
                        // - the position of the existing item is after where the new index is currently
                        //   located, so we know that we need to fill-in some new index items.
                        [maInsert addObject:[NSIndexPath indexPathForRow:(NSInteger) newIndex inSection:0]];
                        newIndex++;
                        
                    }
                    else {
                        // - the position of the existing item is before where the new index is currently located,
                        //   which means that we already inserted it in the new list, but must be deleted from the old.
                        [maDelete addObject:[NSIndexPath indexPathForRow:(NSInteger) curIndex inSection:0]];
                        curIndex++;
                    }
                    }
            }
        }
        
        // - any new items we didn't get a chance to add are at the end.
        for (;newIndex < [maNewFriends count]; newIndex++) {
            ChatSealFeedFriend *csffNew = [maNewFriends objectAtIndex:newIndex];
            NSUInteger pos              = [arrMyFriends indexOfObject:csffNew];
            if (pos == NSNotFound) {
                [maInsert addObject:[NSIndexPath indexPathForRow:(NSInteger) newIndex inSection:0]];
            }
        }
    }
    [arrMyFriends release];
    arrMyFriends = [maNewFriends retain];
    
    //  - now change it.
    if (animated) {
        // - show/hide the no friends display.
        BOOL showNoFriends = [arrMyFriends count] ? NO : YES;
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            vwNoFriends.alpha = showNoFriends ? 1.0f : 0.0f;
        }completion:^(BOOL finished) {
            if (showNoFriends) {
                [tvFriends reloadData];
            }
            tvFriends.userInteractionEnabled = !showNoFriends;
        }];
        
        // - reload the content.
        if (!showNoFriends) {
            // - now do the more interesting updates.
            [tvFriends beginUpdates];
            if ([maUpdate count]) {
                [tvFriends reloadRowsAtIndexPaths:maUpdate withRowAnimation:UITableViewRowAnimationFade];
            }
            if ([maDelete count]) {
                [tvFriends deleteRowsAtIndexPaths:maDelete withRowAnimation:UITableViewRowAnimationAutomatic];
            }
            if ([maInsert count]) {
                [tvFriends insertRowsAtIndexPaths:maInsert withRowAnimation:UITableViewRowAnimationAutomatic];
            }
            [tvFriends endUpdates];
        }
    }
    else {
        if ([arrMyFriends count]) {
            vwNoFriends.alpha = 0.0f;
            [tvFriends reloadData];
        }
        else {
            vwNoFriends.alpha = 1.0f;
        }
    }
    
    // - make sure this is always reset.
    requiresPendingEditRefresh = NO;
}

/*
 *  When friend updates occur, make sure the friends list is kept in synch.
 */
-(void) notifyFriendsUpdated
{
    if ([[ChatSeal applicationHub] isViewControllerTopOfTheHub:self]) {
        [self refreshFriendsListWithAnimation:YES];
    }
    else {
        reloadFriendsOnAppearance = YES;
    }
}

/*
 *  A single feed friend was updated.
 */
-(void) notifyFeedFriendUpdated:(NSNotification *) notification
{
    ChatSealFeed *csf = [notification.userInfo objectForKey:kChatSealNotifyFeedFriendshipFeedKey];
    if (csf && [csf.feedType isEqual:feedType]) {
        // - just update everything.
        [self notifyFriendsUpdated];
    }
}

/*
 *  This action sheet is only for deletion requests.
 */
-(void) actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    ChatSealFeedFriend *ffToDelete = [toDelete autorelease];
    toDelete                       = nil;
    if (buttonIndex == UI_MYF_CONFIRM_DELETE && ffToDelete) {
        // - now that they've confirmed they want to ignore/delete their friend, we need to discard everything
        //   we know about that person.
        NSUInteger pos = [arrMyFriends indexOfObject:ffToDelete];
        if (pos != NSNotFound) {
            if ([feedType ignoreFriendByAccountId:ffToDelete.userId]) {
                isEditing = NO;         //  turn this off because the end method won't happen.
                [self refreshFriendsListWithAnimation:YES];
                return;
            }
        }
        [AlertManager displayFatalAlertWithLowSpaceDetectionUsingTitle:NSLocalizedString(@"Unable to Ignore", nil)
                                                               andText:NSLocalizedString(@"ChatSeal was unable to ignore this friend because of an unexpected problem.", nil)];
    }
    else {
        [tvFriends setEditing:NO animated:YES];
    }
}

/*
 *  The caller will issue this from time to time to make sure the prefererd text widths are
 *  kept synchronized with their dimensions.
 */
-(void) updatePreferredTextWidths
{
    // - make sure that the auth-sub-views are updated.
    [[vwNoFriends viewWithTag:200] layoutIfNeeded];
    
    // - now make sure that the text items have accurate preferreed widths.
    int textItems[] = {201, 202};
    BOOL doLayout   = NO;
    for (int i = 0; i < sizeof(textItems)/sizeof(textItems[0]); i++) {
        NSObject *obj = [vwNoFriends viewWithTag:textItems[i]];
        if ([obj isKindOfClass:[UILabel class]]) {
            UILabel *l = (UILabel *) obj;
            CGFloat width = CGRectGetWidth(l.bounds);
            if ((int) width != (int) l.preferredMaxLayoutWidth) {
                doLayout                  = YES;
                l.preferredMaxLayoutWidth = width;
                [l setNeedsLayout];
            }
        }
    }
    
    // - make sure everything is laid out again with the new preferred widths.
    if (doLayout) {
        [vwNoFriends setNeedsLayout];
        [self.view layoutIfNeeded];
    }
}

/*
 *  The add button was pressed.
 */
-(void) doAddFriend
{
    UIFriendAdditionViewController *favc = [feedType friendAdditionViewController];
    if (favc) {
        favc.feedType                      = feedType;
        UIChatSealNavigationController *nc = [[[UIChatSealNavigationController alloc] initWithRootViewController:favc] autorelease];        
        [self presentViewController:nc animated:YES completion:nil];
        wasAdding                          = YES;           //  so we get a record if they added one.
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
    [UIAdvancedSelfSizingTools constrainAlertLabel:(UILabel *) self.lNoFriendsTitle asHeader:YES duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainAlertLabel:(UILabel *) self.lNoFriendsDesc asHeader:NO duringInitialization:isInit];
}

@end

/***********************************************
 UIMyFriendsInFeedTypeViewController (table)
 ***********************************************/
@implementation UIMyFriendsInFeedTypeViewController (table)
/*
 *  This is a simple table, we only show the list of friends, that's it.
 */
-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

/*
 *  Return the number of rows in the given section.
 */
-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger) [arrMyFriends count];
}

/*
 *  Return the cell for the given row.
 */
-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UIMyFriendTableViewCell *mftvc = (UIMyFriendTableViewCell *) [tableView dequeueReusableCellWithIdentifier:@"UIMyFriendTableViewCell"];
    if (indexPath.row < [arrMyFriends count]) {
        ChatSealFeedFriend *csff = [arrMyFriends objectAtIndex:(NSUInteger) indexPath.row];
        [mftvc configureWithFriend:csff andAnimation:NO];
    }
    return mftvc;
}

/*
 *  Return the text for the header.
 */
-(NSString *) genericHeaderText
{
    return NSLocalizedString(@"ChatSeal will help you maintain strong connections with your trusted friends.", nil);
}

/*
 *  Return the height for the header.
 */
-(CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return [UIFeedGenericHeaderFooter recommendedHeightForText:[self genericHeaderText] andScreenWidth:CGRectGetWidth(self.view.bounds)] + UI_MYF_HEADER_PAD;
}

/*
 *  Return a header for this table.
 */
-(UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    return [[[UIFeedGenericHeaderFooter alloc] initWithText:[self genericHeaderText] inColor:nil asHeader:YES] autorelease];
}

/*
 *  Allows us to choose if cell highlight is possible.
 */
-(BOOL) tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row < [arrMyFriends count]) {
        ChatSealFeedFriend *csff = [arrMyFriends objectAtIndex:(NSUInteger) indexPath.row];
        if (!csff.isDeleted && csff.isIdentified) {
            return YES;
        }
    }
    return NO;
}

/*
 *  Move into the detail screen for a particular friend.
 */
-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row < [arrMyFriends count]) {
        ChatSealFeedFriend *csff = [arrMyFriends objectAtIndex:(NSUInteger) indexPath.row];
        if (csff) {
            UIFriendManagementViewController *vcFriend = [feedType friendManagementViewController];
            if (vcFriend) {
                vcFriend.feedFriend = csff;
                [self.navigationController pushViewController:vcFriend animated:YES];
            }
        }
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

/*
 *  The user has swiped with the intention of deleting an item.
 */
-(void) tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    isEditing = YES;
}

/*
 *  The editing session has completed.
 */
-(void) tableView:(UITableView *)tableView didEndEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    isEditing = NO;
    
    // - if we needed to refresh while we were in the middle of editing, do so now that we're done with it.
    if (requiresPendingEditRefresh){
        [self refreshFriendsListWithAnimation:YES];
    }
}

/*
 *  Change the title for the deletion button.
 */
-(NSString *) tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NSLocalizedString(@"Ignore", nil);
}

/*
 *  Initiate a friend deletion request.
 */
-(void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle != UITableViewCellEditingStyleDelete) {
        return;
    }
    
    // - I'm saving off the object itself because the index can change very easily when a new friend list is retrieved.
    if (indexPath.row < [arrMyFriends count]) {
        [toDelete release];
        toDelete = [[arrMyFriends objectAtIndex:(NSUInteger) indexPath.row] retain];
        UIActionSheet *as = [[[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"You may have trouble chatting with this friend if you choose to ignore them.", nil)
                                                         delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                           destructiveButtonTitle:NSLocalizedString(@"Ignore Friend", nil)
                                                otherButtonTitles:nil] autorelease];
        [as showInView:self.view];
    }
}

@end
