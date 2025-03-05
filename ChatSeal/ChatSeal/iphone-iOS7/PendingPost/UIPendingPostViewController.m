//
//  UIPendingPostViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIPendingPostViewController.h"
#import "ChatSeal.h"
#import "ChatSealFeedCollector.h"
#import "ChatSealPostedMessageProgress.h"
#import "UISealedMessageDisplayViewV2.h"
#import "UIPendingPostStatusTableViewCell.h"
#import "UIPendingPostDetailTableViewCell.h"
#import "UISealVaultCell.h"
#import "UISealDetailViewController.h"
#import "UISecurePreviewViewController.h"
#import "UIPendingPostDiscardTableViewCell.h"

// - constants
typedef enum {
    UIPPVC_SEC_STATUS,
    UIPPVC_SEC_SEAL,
    UIPPVC_SEC_DISCARD,
    
    UIPPFC_SEC_COUNT
} uippvc_section_t;

static const CGFloat UIPPVC_STD_DISPLAY_PAD = 15.0f;            // - extra padding for the bottom.

// - forward declarations
@interface UIPendingPostViewController (internal)
-(void) commonConfiguration;
-(void) setLastProgress:(ChatSealPostedMessageProgress *) prog;
-(ChatSealPostedMessageProgress *) lastProgress;
-(void) notifyPendingUpdate:(NSNotification *) notification;
-(void) removeDeletionButton;
@end

@interface UIPendingPostViewController (table) <UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate>
@end

@interface UIPendingPostViewController (messageDisplay) <UISealedMessageDisplayViewDataSourceV2>
@end

/******************************
 UIPendingPostViewController
 ******************************/
@implementation UIPendingPostViewController
/*
 *  Object attributes.
 */
{
    ChatSealFeed                  *activeFeed;
    NSMutableArray                *maItems;
    CGFloat                       displayHeight;
    NSString                      *author;
    NSDate                        *dtCreated;
    ChatSealIdentity              *identity;
    UISealedMessageDisplayViewV2  *messageDisplay;
    ChatSealPostedMessageProgress *lastProgress;
    BOOL                          hasAppeared;
    BOOL                          allowProgressUpdates;
}
@synthesize tvDetail;

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
    [tvDetail release];
    tvDetail = nil;
    
    [activeFeed release];
    activeFeed = nil;
    
    [maItems release];
    maItems = nil;
    
    [messageDisplay release];
    messageDisplay = nil;
    
    [lastProgress release];
    lastProgress = nil;
    
    [author release];
    author = nil;
    
    [dtCreated release];
    dtCreated = nil;
    
    [identity release];
    identity = nil;
    
    [super dealloc];
}

/*
 *  Configure the object.
 */
-(void) viewDidLoad
{
    [super viewDidLoad];
    
    // - set up the title.
    self.title = NSLocalizedString(@"My Post", nil);
    
    // - wait for updates.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyPendingUpdate:) name:kChatSealNotifyFeedPostProgress object:nil];
    
    // - and the table.
    [UISealVaultCell registerCellForTable:tvDetail forCellReuseIdentifier:@"UISealVaultCell"];
    tvDetail.dataSource = self;
    tvDetail.delegate   = self;
    
    // - and the message display, which we need to hold onto because it cannot
    //   be recreated over and over.  We'll use one instance and reparent
    //   it to different owning cells.
    messageDisplay                 = [[UISealedMessageDisplayViewV2 alloc] init];
    messageDisplay.backgroundColor = [UIColor clearColor];
    [messageDisplay setBounces:NO];
    messageDisplay.dataSource      = self;
    [messageDisplay setOwnerSealForStyling:identity.sealId];
    [messageDisplay setMaximumNumberOfItemsPerEntry:3];
}

/*
 *  The view has appeared.
 */
-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (hasAppeared && identity) {
        // - this is better than a simple reload because it precisely updates only what has changed.
        UISealVaultCell *svc = (UISealVaultCell *) [tvDetail cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:UIPPVC_SEC_SEAL]];
        [svc updateStatsWithIdentity:identity andAnimation:YES];
    }
    
    hasAppeared = YES;
}

/*
 *  This method will attempt to get the pending item ready for display.  If it cannot, it will return
 *  a failure code.
 */
-(BOOL) prepareForPendingDisplayOfProgress:(ChatSealPostedMessageProgress *) prog inFeed:(ChatSealFeed *) feed withError:(NSError **) err
{
    // - save off the feed for later.
    if (activeFeed != feed) {
        [activeFeed release];
        activeFeed = [feed retain];
    }
    
    // - first find the message.
    ChatSealMessage *csm = [ChatSeal messageForId:prog.messageId];
    if (!csm) {
        [CS_error fillError:err withCode:CSErrorStaleMessage];
        return NO;
    }
    
    // - now pull out the content we care about.
    BOOL ret = YES;
    if (![csm pinSecureContent:err]) {
        return NO;
    }
    
    identity          = [[csm identityWithError:err] retain];
    if (identity){
        ret = [csm performBlockUnderMessageLock:^BOOL(NSError **tmp) {
            ChatSealMessageEntry *cse = [csm entryForId:prog.entryId withError:err];
            if (!cse) {
                return NO;
            }
            
            NSUInteger numItems = cse.numItems;
            if (!numItems) {
                [CS_error fillError:err withCode:CSErrorStaleMessage];
                return NO;
            }
            
            [author release];
            author    = [[ChatSealMessage standardDisplayHeaderAuthorForMessage:csm andEntry:cse withActiveAuthorName:nil] retain];
            [dtCreated release];
            dtCreated = [[cse creationDate] retain];
            
            for (NSUInteger i = 0; i < numItems; i++) {
                id item = [cse itemAtIndex:i withError:err];
                if (!item) {
                    return NO;
                }
                [maItems addObject:item];
            }
            
            // - all ok.
            return YES;
        } withError:err];
    }
    else {
        ret = NO;
    }
    
    [csm unpinSecureContent];

    // - it is possible we'll have no progress if things went astray.
    self.lastProgress = ret ? prog : nil;
    
    // - compute the height of the row once and use it each time.
    displayHeight = [UISealedMessageDisplayViewV2 fullDisplayHeightForMessageEntryContent:maItems inCellWidth:[ChatSeal portraitWidth]];
    
    return ret;
}

/*
 *  This notification is fired whenever the size of dynamic type changes.
 */
-(void) updateDynamicTypeNotificationReceived
{
    if (self.lastProgress) {
        [messageDisplay updateDynamicTypeNotificationReceived];
        displayHeight = [UISealedMessageDisplayViewV2 fullDisplayHeightForMessageEntryContent:maItems inCellWidth:[ChatSeal portraitWidth]];
        
        // - with advanced self-sizing, the reload will be implicitly performed by the table.
        if (![ChatSeal isAdvancedSelfSizingInUse]) {
            [tvDetail reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:1 inSection:UIPPVC_SEC_STATUS]] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
}

@end

/***************************************
 UIPendingPostViewController (internal)
 ***************************************/
@implementation UIPendingPostViewController (internal)
/*
 *  Basic initialization.
 */
-(void) commonConfiguration
{
    activeFeed                = nil;
    maItems                   = [[NSMutableArray alloc] init];
    displayHeight             = 0.0f;
    author                    = nil;
    dtCreated                 = nil;
    identity                  = nil;
    messageDisplay            = nil;
    lastProgress              = nil;
    hasAppeared               = NO;
    allowProgressUpdates      = YES;
}

/*
 *  Assign the last progress.
 */
-(void) setLastProgress:(ChatSealPostedMessageProgress *) prog
{
    if (prog != lastProgress) {
        [lastProgress release];
        lastProgress = [prog retain];
    }
}

/*
 *  Return the last progress.
 */
-(ChatSealPostedMessageProgress *) lastProgress
{
    return [[lastProgress retain] autorelease];
}

/*
 *  A pending item's state was changed.
 */
-(void) notifyPendingUpdate:(NSNotification *) notification
{
    // - when we explicitly delete a post, we don't allow new pending
    //   updates because the cell needs to know the difference between a completed item and a deleted one.
    if (!allowProgressUpdates) {
        return;
    }
    
    ChatSealPostedMessageProgress *prog = [notification.userInfo objectForKey:kChatSealNotifyFeedPostProgressItemKey];
    if (prog) {
        if (!lastProgress || [lastProgress.safeEntryId isEqualToString:prog.safeEntryId]) {
            BOOL removeDelete = NO;
            if (!self.lastProgress.hasStarted) {
                removeDelete = YES;
            }
            self.lastProgress = prog;
            [tvDetail beginUpdates];
                if (removeDelete) {
                    [self removeDeletionButton];
                }
                [tvDetail reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:UIPPVC_SEC_STATUS]] withRowAnimation:UITableViewRowAnimationFade];
                     [tvDetail endUpdates];
            [tvDetail endUpdates];
        }
    }
}

/*
 *  The deletion button is available if the post hasn't started yet, but then gets removed when it begins.
 */
-(void) removeDeletionButton
{
    UIPendingPostDiscardTableViewCell *ppdtvc = (UIPendingPostDiscardTableViewCell *) [tvDetail cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:UIPPVC_SEC_DISCARD]];
    ppdtvc.lDiscard.textColor                 = [UIColor lightGrayColor];
    [tvDetail deleteSections:[NSIndexSet indexSetWithIndex:UIPPVC_SEC_DISCARD] withRowAnimation:UITableViewRowAnimationAutomatic];
}
@end

/***************************************
 UIPendingPostViewController (table)
 ***************************************/
@implementation UIPendingPostViewController (table)
/*
 *  Return the number of sections in this table.
 */
-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    if ([maItems count]) {
        if (!lastProgress.hasStarted) {
            return UIPPFC_SEC_COUNT;
        }
        else {
            return UIPPFC_SEC_COUNT - 1;
        }
    }
    else {
        // - if there are no items, we're not displaying anything else.
        return 1;
    }
}

/*
 *  Return a header for the given section.
 */
-(NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case UIPPVC_SEC_STATUS:
            // - the title is implied by the screen we're on.
            return nil;
            break;
            
        case UIPPVC_SEC_SEAL:
            return NSLocalizedString(@"Sealed With", nil);
            break;
            
        case UIPPVC_SEC_DISCARD:
            // - no need for a title here.
            return nil;
            break;
            
        default:
            return nil;
            break;
    }
}

/*
 *  Return the number of rows in this table by section.
 */
-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case UIPPVC_SEC_STATUS:
            if (self.lastProgress && allowProgressUpdates) {
                return 2;
            }
            else {
                // - when there is no progress, we need to just show the status.
                return 1;
            }
            break;
            
        case UIPPVC_SEC_SEAL:
            return 1;
            break;
        
        case UIPPVC_SEC_DISCARD:
            return 1;
            break;
            
        default:
            return 0;
            break;
    }
}

/*
 *  Return a cell from the table.
 */
-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == UIPPVC_SEC_STATUS) {
        if (indexPath.row == 0) {
            UIPendingPostStatusTableViewCell *pptvc = (UIPendingPostStatusTableViewCell *) [tvDetail dequeueReusableCellWithIdentifier:@"UIPendingPostStatusTableViewCell"];
            [pptvc refreshFromProgress:lastProgress];
            return pptvc;
        }
        else if (indexPath.row == 1) {
            UIPendingPostDetailTableViewCell *ppdvc = (UIPendingPostDetailTableViewCell *) [tvDetail dequeueReusableCellWithIdentifier:@"UIPendingPostDetailTableViewCell"];
            [ppdvc setDisplayView:messageDisplay withContentHeight:displayHeight + UIPPVC_STD_DISPLAY_PAD];
            return ppdvc;
        }
    }
    else if (indexPath.section == UIPPVC_SEC_SEAL) {
        if (indexPath.row == 0) {
            UISealVaultCell *svc = (UISealVaultCell *) [tvDetail dequeueReusableCellWithIdentifier:@"UISealVaultCell"];
            [svc configureCellWithIdentity:identity andShowDisclosureIndicator:identity.isOwned];
            return svc;
        }
    }
    else if (indexPath.section == UIPPVC_SEC_DISCARD) {
        if (indexPath.row == 0) {
            UIPendingPostDiscardTableViewCell *ppdtvc = (UIPendingPostDiscardTableViewCell *) [tvDetail dequeueReusableCellWithIdentifier:@"UIPendingPostDiscardTableViewCell"];
            return ppdtvc;
        }
    }
    return nil;
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
        if (indexPath.section == UIPPVC_SEC_STATUS) {
            if (indexPath.row == 1) {
                return displayHeight + UIPPVC_STD_DISPLAY_PAD;
            }
        }
        else if (indexPath.section == UIPPVC_SEC_SEAL) {
            UISealVaultCell *svc = [tvDetail dequeueReusableCellWithIdentifier:@"UISealVaultCell"];
            return CGRectGetHeight(svc.bounds);
        }
        return tvDetail.rowHeight;
    }
}

/*
 *  Allow/disallow highlighting of the cells.
 */
-(BOOL) tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == UIPPVC_SEC_STATUS) {
        return NO;
    }
    else if (indexPath.section == UIPPVC_SEC_SEAL) {
        if (![identity isOwned]) {
            return NO;
        }
    }
    
    if (![tvDetail shouldPermitHighlight]) {
        return NO;
    }
    
    return YES;
}

/*
 *  A row was selected.
 */
-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == UIPPVC_SEC_SEAL && [identity isOwned]) {
        UISealDetailViewController *sdvc = (UISealDetailViewController *) [ChatSeal viewControllerForStoryboardId:@"UISealDetailViewController"];
        [sdvc setIdentity:identity];
        [self.navigationController pushViewController:sdvc animated:YES];
    }
    else if (indexPath.section == UIPPVC_SEC_DISCARD && self.lastProgress && [maItems count]) {
        // - first turn off the feed's posting behavior immediately and get an update for the item
        //   in question to ensure it hasn't already started.
        [activeFeed setPendingPostProcessingEnabled:NO];
        ChatSealPostedMessageProgress *newProgress = [activeFeed updatedProgressForSafeEntryId:lastProgress.safeEntryId];
        if (!newProgress.hasStarted) {
            UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Do you want to delete this post before it is uploaded to your feed?", nil)
                                                            delegate:self
                                                   cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                              destructiveButtonTitle:NSLocalizedString(@"Delete Post", nil)
                                                   otherButtonTitles:nil];
            [as showInView:self.view];
            [as autorelease];
        }
        else {
            // - the item started while we were waiting so we cannot continue.
            [lastProgress release];
            lastProgress = [newProgress retain];
            
            [self removeDeletionButton];
            
            // - turn the post processing back-on now.
            [activeFeed setPendingPostProcessingEnabled:YES];
        }
    }
    [tvDetail deselectRowAtIndexPath:indexPath animated:YES];
}

/*
 *  The only time the action sheet is used is to delete a pending item.
 */
-(void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // - figure out if we need to delete or not.
    if (buttonIndex == 0) {
        [activeFeed deletePendingPostForSafeEntryId:lastProgress.safeEntryId];
        allowProgressUpdates = NO;
        self.lastProgress = nil;
        [maItems removeAllObjects];
        [tvDetail beginUpdates];
            [tvDetail deleteSections:[NSIndexSet indexSetWithIndex:UIPPVC_SEC_SEAL] withRowAnimation:UITableViewRowAnimationAutomatic];
            [tvDetail deleteSections:[NSIndexSet indexSetWithIndex:UIPPVC_SEC_DISCARD] withRowAnimation:UITableViewRowAnimationAutomatic];
            [tvDetail deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:1 inSection:UIPPVC_SEC_STATUS]] withRowAnimation:UITableViewRowAnimationAutomatic];
            [tvDetail reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:UIPPVC_SEC_STATUS]] withRowAnimation:UITableViewRowAnimationFade];
        [tvDetail endUpdates];
    }
    
    // - always re-enable the feed for posting.
    [activeFeed setPendingPostProcessingEnabled:YES];
}

@end

/*********************************************
 UIPendingPostViewController (messageDisplay)
 *********************************************/
@implementation UIPendingPostViewController (messageDisplay)
/*
 *  Return the number of entries that will be displayed.
 */
-(NSInteger) numberOfEntriesInDisplay:(UISealedMessageDisplayViewV2 *)messageDisplay
{
    return 1;
}

/*
 *  Return whether we authored this message.
 */
-(BOOL) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *)messageDisplay authorIsLocalForEntry:(NSInteger)entry
{
    return YES;
}

/*
 *  Return the number of items we intend to display.
 */
-(NSInteger) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *)messageDisplay numberOfItemsInEntry:(NSInteger)entry
{
    return (NSInteger) [maItems count];
}

/*
 *  Return the content for the given index.
 */
-(id) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *)messageDisplay contentForItemAtIndex:(NSIndexPath *)index
{
    if (index.item < [maItems count]) {
        return [maItems objectAtIndex:(NSUInteger) index.item];
    }
    return nil;
}

/*
 *  Return whether the item in question is an image.
 */
-(BOOL) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *)messageDisplay contentIsImageAtIndex:(NSIndexPath *)index
{
    if (index.item < [maItems count]) {
        return [[maItems objectAtIndex:(NSUInteger) index.item] isKindOfClass:[UIImage class]];
    }
    return NO;
}

/*
 *  Populate the header.
 */
-(void) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *)messageDisplay populateHeaderContent:(UISealedMessageDisplayHeaderDataV2 *)header forEntry:(NSInteger)entry
{
    // - now populate the header data.
    header.author       = author;
    header.creationDate = dtCreated;
    header.isRead       = YES;
    header.isOwner      = identity.isOwned;
}

/*
 *  Indicates that the item was tapped at the given index.
 *  - return YES if the item should proceed with a tapped animation.
 */
-(BOOL) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *)messageDisplay itemTappedAtIndex:(NSIndexPath *)index
{
    if (!self.lastProgress || !identity || index.item >= [maItems count]) {
        return NO;
    }

    id tapItem = [maItems objectAtIndex:(NSUInteger) index.item];
    if (![tapItem isKindOfClass:[UIImage class]]) {
        return NO;
    }
    
    UIImage *imgOrig   = (UIImage *) tapItem;
    CGFloat scale      = 1.0f;
    CGFloat phDim      = [ChatSealMessageEntry standardPlaceholderDimension];
    CGFloat maxDim     = MAX(imgOrig.size.width, imgOrig.size.height);
    if (maxDim > phDim) {
        scale = phDim/maxDim;
    }
    UIImage *imgSecure = [ChatSeal generateFrostedImageOfType:CS_FS_SECURE fromImage:imgOrig atScale:MIN(scale, 1.0f)];

    UISecurePreviewViewController *secP = (UISecurePreviewViewController *) [ChatSeal viewControllerForStoryboardId:@"UISecurePreviewViewController"];
    [secP setSecureImage:imgOrig withPlaceholder:imgSecure andOwningMessage:nil];
    [secP setInitialFadeEnabled:NO];
    [self.navigationController pushViewController:secP animated:YES];

    return YES;
}


@end