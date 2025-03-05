//
//  UISealVaultViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 11/1/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UISealVaultViewController.h"
#import "ChatSeal.h"
#import "UISealVaultCell.h"
#import "UISealVaultScanCell.h"
#import "UISealVaultGiveCell.h"
#import "UINewSealViewController.h"
#import "AlertManager.h"
#import "ChatSealVaultPlaceholder.h"
#import "UISealDetailViewController.h"
#import "UISealExchangeController.h"
#import "UISealSelectionViewController.h"
#import "UISealShareViewController.h"
#import "UIDynamicTypeCompliantEntity.h"
#import "UISealVaultPrivacyCell.h"
#import "UIPrivacyViewController.h"

// - constants
static const CGFloat UISVC_PH_TOOL_TEXT_CX     = 110.0f;
static const NSInteger UISVC_PH_MIDDLE_SECTION = 1;

// - types
typedef enum {
    UISVC_SEC_TOOLS            = 0,
    UISVC_SEC_MINE             = 1,
    UISVC_SEC_THEIRS           = 2,
    
    UISVC_SEC_COUNT,
    UISVC_SEC_INVALID          = -1
} uisvc_sec_id_t;

typedef enum {
    UISVC_TOOL_PRIV = 0,
    UISVC_TOOL_SCAN = 1,
    UISVC_TOOL_GIVE = 2
} uisvc_tool_id_t;

// - forward declarations.
@interface UISealVaultViewController (internal) <UIDynamicTypeCompliantEntity>
-(void) updateSealDataWithAnimation:(BOOL) animated;
-(void) updateTableInsets;
-(void) notifyLowStorageResolved;
-(uisvc_sec_id_t) realSectionForLogicalSection:(NSInteger) sec;
@end

// - maintain my seals.
@interface UISealVaultViewController (mySeals)
-(void) doEditMySeals;
-(void) doAddNewSeal;
@end

// - all the data retrieval and display
@interface UISealVaultViewController (table) <UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate>
-(BOOL) hasOwnedSeals;
-(BOOL) hasOthersSeals;
-(BOOL) shouldConfirmSealDeletionIfNecessaryForIdentity:(ChatSealIdentity *) psi atIndexPath:(NSIndexPath *) ip fromMine:(BOOL) fromMine;
-(void) deleteSealAtIndex:(NSIndexPath *) indexPath fromMine:(BOOL) fromMine withSeal:(NSString *) sealId;
-(void) fadeOutCellAtIndexPath:(NSIndexPath *) ipToFade;
-(void) reconfigureToolsForNewSurroundingsWithAnimation:(BOOL) animated;
-(void) notifyBasestationUpdate;
-(void) notifySealInvalidation;
-(void) setNavButtonToEditingInUse:(BOOL) inUse withAnimation:(BOOL) animated;
@end

// - just a way to pass over some deletion argmuents to the delegate.
@interface UISealDeletionActionSheet : UIActionSheet
@property (nonatomic, retain) NSIndexPath *ipToDelete;
@property (nonatomic, assign) BOOL        fromMine;
@property (nonatomic, retain) NSString    *sealId;
@end

// - placeholder support
@interface UISealVaultViewController (vaultOverlay) <UIVaultFailureOverlayViewDelegate>
-(void) showSealVaultFailureWithAnimation:(BOOL) animated;
-(void) hideSealVaultFailureWithAnimation:(BOOL) animated;
@end

/*************************
 UISealVaultViewController
 *************************/
@implementation UISealVaultViewController
/*
 *  Object attributes
 */
{
    NSMutableArray *maMySeals;
    NSMutableArray *maOtherSeals;
    BOOL           hasActiveSeal;
    BOOL           hasAppeared;
    BOOL           hasExchangedASeal;
}
@synthesize tvSeals;
@synthesize vfoFailDisplay;

/*
 *  Return the text to display on the tab.
 */
+(NSString *) currentTextForTabBadgeThatIsActive:(BOOL) isActive
{
    // - this badge should only be used for exceptional scenarios like there is a seal-related problem that
    //   must be addressed or the person needs to make their first seal exchange.
    // - I don't want to use it for standard events like people nearby because it will make the
    //   important things related to seal management less important.
    BOOL showAlert = NO;
    
    // - the first test is whether we've transferred a seal to or from another device, in which
    //   case we want to guide the user over here.
    if (![ChatSeal hasTransferredASeal]) {
        showAlert = YES;
    }
    
    // - now look at each identity and see if there are exceptional conditions that must be
    //   overcome.
    if (!showAlert && [ChatSeal hasVault]) {
        NSError *err      = nil;
        NSArray *arrIdent = [ChatSeal availableIdentitiesWithError:&err];
        if (arrIdent) {
            for (ChatSealIdentity *ident in arrIdent) {
                // - these seals will be labeled as such and will prevent further
                //   messaging until they are resolved.
                if (![ident isOwned] && ([ident isExpired] || [ident isRevoked])) {
                    showAlert = YES;
                    break;
                }
                
                // - there is a problem with one of the seals that must be addressed.
                BOOL hasWarn = NO;
                if ([ident computedStatusTextAndDisplayAsWarning:&hasWarn] && hasWarn) {
                    showAlert = YES;
                    break;
                }
            }
        }
        else {
            NSLog(@"CS: Failed to retrieve the active identity list for badge computation.  %@", [err localizedDescription]);
        }
    }
    return (showAlert ? @"!" : nil);
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        hasActiveSeal     = NO;
        hasAppeared       = NO;
        maMySeals         = nil;
        maOtherSeals      = nil;
        hasExchangedASeal = NO;
    }
    return self;
}

/*
 *  Free the object
 */
-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    tvSeals.delegate   = nil;
    tvSeals.dataSource = nil;
    [tvSeals release];
    tvSeals = nil;
    
    [vfoFailDisplay release];
    vfoFailDisplay = nil;
    
    [maMySeals release];
    maMySeals = nil;
    
    [maOtherSeals release];
    maOtherSeals = nil;
    
    [super dealloc];
}

/*
 *  Configure the object.
 */
-(void) viewDidLoad
{
    [super viewDidLoad];
    
    // - wire up the navigation
    self.title                             = NSLocalizedString(@"Seal Vault", nil);
    [self setNavButtonToEditingInUse:NO withAnimation:NO];
    
    // - and the table for data access
    [UISealVaultCell registerCellForTable:tvSeals forCellReuseIdentifier:@"UISealVaultCell"];
    tvSeals.delegate   = self;
    tvSeals.dataSource = self;
    
    // - the overlay will receive placeholder content from us.
    // - NOTE: the rationale behind using this here is to offer one last way of identifying a really bad problem because
    //         it is technically possible for the vault to be open, but somehow the seals could not be retrieved.   While that
    //         scenario is improbable, it is one that I'd like to address if possible.
    vfoFailDisplay.delegate = self;
    
    // - wire up the notification to learn about storage corrections.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyLowStorageResolved) name:kChatSealNotifyLowStorageResolved object:nil];
    
    // ...and the base station updates too
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyBasestationUpdate) name:kChatSealNotifyNetworkChange object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyBasestationUpdate) name:kChatSealNotifyNearbyUserChange object:nil];
    
    // ...and watch for seal invalidations (probably expirations).
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifySealInvalidation) name:kChatSealNotifySealInvalidated object:nil];
}

/*
 *  Right before the view appears, make sure we have data for the table.
 */
-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // - initial data
    [self updateTableInsets];
    if (!hasAppeared) {
        [self updateSealDataWithAnimation:NO];
    }
}

/*
 *  Whether or not the view has appeared.
 */
-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // - after the first time, make sure the data is kept up to date.
    if (hasAppeared) {
        [self updateSealDataWithAnimation:YES];
    }
    hasAppeared = YES;
}

/*
 *  Rotation animation is about to occur so make sure the view is updated.
 */
-(void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self updateTableInsets];
    
    // - the overlay must be regenerated during rotations
    if ([vfoFailDisplay isFailureVisible]) {
        [self showSealVaultFailureWithAnimation:YES];
    }
}

/*
 *  Trigger the scan after a short delay.
 */
-(void) delayedShiftToScan
{
    [self tableView:tvSeals didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:UISVC_TOOL_SCAN inSection:UISVC_SEC_TOOLS]];
}

/*
 *  When the hub detects that a new application URL has been sent into this app, we'll
 *  take that opportunity to pop open the seal scanner if it makes sense.
 */
-(void) viewControllerShouldProcessApplicationURL:(NSURL *) url
{
    // - we aren't going to allow this if we're currently displaying a modal view.
    if (self.presentedViewController) {
        return;
    }
    
    // - now check for a navigation hierarchy that we can't overcome.
    NSUInteger numberOfControllers = [((UINavigationController *)self.navigationController).viewControllers count];
    if (numberOfControllers == 1) {
        [self performSelector:@selector(delayedShiftToScan) withObject:nil afterDelay:0.75f];
    }
    else if (numberOfControllers == 2) {
        UIViewController *vc = [((UINavigationController *) self.navigationController).viewControllers objectAtIndex:1];
        if ([vc isKindOfClass:[UISealShareViewController class]]) {
            [(UISealShareViewController *) vc doSwapModes];
        }
    }
}

/*
 *  The view has disappeared.
 */
-(void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [tvSeals parentViewControllerDidDisappear];
}
@end

/************************************
 UISealVaultViewController (internal)
 ************************************/
@implementation UISealVaultViewController (internal)
/*
 *  Return whether the active seal is available.
 */
-(BOOL) isActiveSealValidInList:(NSArray *) arrSeals
{
    NSString *activeSeal = [ChatSeal activeSeal];
    for (ChatSealIdentity *psi in arrSeals) {
        if (activeSeal && [activeSeal isEqualToString:psi.sealId]) {
            return YES;
        }
    }
    return NO;
}

/*
 *  Update the two arrays of seal data and possibly reload the table
 *  as a result of the change.
 */
-(void) updateSealDataWithAnimation:(BOOL) animated
{
    NSMutableArray *maUpdatedMySeals    = [NSMutableArray array];
    NSMutableArray *maUpdatedOtherSeals = [NSMutableArray array];
    
    // - first get the list of seals.
    NSError *err = nil;
    NSArray *arrIdentities = [ChatSeal availableIdentitiesWithError:&err];
    if (arrIdentities) {
        for (ChatSealIdentity *psi in arrIdentities) {
            if ([psi isOwned]) {
                [maUpdatedMySeals addObject:psi];
            }
            else {
                [maUpdatedOtherSeals addObject:psi];
            }
        }
        [self hideSealVaultFailureWithAnimation:animated];
    }
    else {
        NSLog(@"CS:  Failed to retrieve the active list of seals.  %@", [err localizedDescription]);
        maUpdatedMySeals    = nil;
        maUpdatedOtherSeals = nil;
        [self showSealVaultFailureWithAnimation:animated];
    }
    
    BOOL hasNewContent     = NO;
    BOOL updatedTools      = NO;
    BOOL updatedMyCells    = NO;
    BOOL updatedTheirCells = NO;
    
    // - do all this within a transaction.
    if (animated) {
        [tvSeals beginUpdates];
    }
    
    // - figure out if the tools section should be updated.
    BOOL newActiveState = [self isActiveSealValidInList:maUpdatedMySeals];
    if (newActiveState != hasActiveSeal ||
        hasExchangedASeal != [ChatSeal hasTransferredASeal] ||
        ([maMySeals count] != [maUpdatedMySeals count] && ([maMySeals count] == 0 || [maUpdatedMySeals count] == 0))) {
        hasNewContent = YES;
        if (animated) {
            [tvSeals reloadSections:[NSIndexSet indexSetWithIndex:UISVC_SEC_TOOLS] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        updatedTools = YES;
    }
    hasExchangedASeal = [ChatSeal hasTransferredASeal];
    
    BOOL hadMyCells    = ([maMySeals count] > 0) ? YES : NO;
    BOOL hadTheirCells = ([maOtherSeals count] > 0) ? YES : NO;
    
    // - we're going to look for and scroll to new items when we refresh so that people can see their content
    //   appear.
    NSInteger newItemSection = -1;
    NSInteger newItemRow     = -1;
    
    // - check if our seal list has changed.
    [ChatSealIdentity sortIdentityArrayForDisplay:maUpdatedMySeals];
    if (!maUpdatedMySeals || ![maUpdatedMySeals isEqualToArray:maMySeals]) {
        if ([maUpdatedMySeals count] != [maMySeals count] ||
            (!maUpdatedMySeals != !maMySeals)) {
            hasNewContent = YES;
            
            // - when we've added one, it always gets inserted at the top.
            if ([maUpdatedMySeals count] > [maMySeals count]) {
                newItemSection = UISVC_SEC_MINE;
                newItemRow     = 0;
            }
        }
        
        // - update the active array.
        [maMySeals release];
        maMySeals = [maUpdatedMySeals retain];
        updatedMyCells = YES;
    }
    
    // - save the new seal active state.
    hasActiveSeal = newActiveState;
    
    // - check if the others' seal list has changed.
    [ChatSealIdentity sortIdentityArrayForDisplay:maUpdatedOtherSeals];
    if (!maUpdatedOtherSeals || ![maUpdatedOtherSeals isEqualToArray:maOtherSeals]) {
        if ([maUpdatedOtherSeals count] != [maOtherSeals count] ||
            (!maUpdatedOtherSeals != !maOtherSeals)) {
            hasNewContent = YES;
            
            // - if we just acquired someone else's seal, we are going to scroll to it
            if (newItemSection == -1 && [maUpdatedOtherSeals count] > [maOtherSeals count]) {
                newItemSection = UISVC_SEC_THEIRS;
                newItemRow     = 0;
                for (NSUInteger i = 0; i < [maUpdatedOtherSeals count]; i++) {
                    ChatSealIdentity *oldOne = nil;
                    if (i < [maOtherSeals count]) {
                        oldOne = [maOtherSeals objectAtIndex:i];
                    }
                    ChatSealIdentity *newOne = [maUpdatedOtherSeals objectAtIndex:i];
                    if (!oldOne || ![newOne isEqual:oldOne] || i == ([maUpdatedOtherSeals count] - 1)) {
                        break;
                    }
                    newItemRow++;
                }
            }
        }
        
        // - update the active array.
        [maOtherSeals release];
        maOtherSeals = [maUpdatedOtherSeals retain];
        updatedTheirCells = YES;
    }
    
    // - we're only going to manage the section updates in one location to ensure
    //   it is done right.
    if (animated && (updatedMyCells || updatedTheirCells)) {
        // - I'm doing this in a very methodical way here intentionally.
        NSIndexSet *isMiddle = [NSIndexSet indexSetWithIndex:UISVC_PH_MIDDLE_SECTION];
        NSIndexSet *isLast   = [NSIndexSet indexSetWithIndex:UISVC_SEC_THEIRS];
        
        BOOL nowHasMyCells    = ([maMySeals count] > 0) ? YES : NO;
        BOOL nowHasTheirCells = ([maOtherSeals count] > 0) ? YES : NO;
        
        // - first do the reloads because they refer to the original rows.
        if (updatedMyCells && nowHasMyCells && hadMyCells) {
            [tvSeals reloadSections:isMiddle withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        
        if (updatedTheirCells && nowHasTheirCells && hadTheirCells) {
            if (hadMyCells) {
                [tvSeals reloadSections:isLast withRowAnimation:UITableViewRowAnimationAutomatic];
            }
            else {
                [tvSeals reloadSections:isMiddle withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }

        // - now the deletions, which are still referencing the original rows.
        if (hadTheirCells && !nowHasTheirCells) {
            if (hadMyCells) {
                [tvSeals deleteSections:isLast withRowAnimation:UITableViewRowAnimationAutomatic];
            }
            else {
                [tvSeals deleteSections:isMiddle withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }
        
        if (hadMyCells && !nowHasMyCells) {
            if (nowHasTheirCells || !hadTheirCells) {
                [tvSeals deleteSections:isMiddle withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }
        
        // - the insertions last.
        if (updatedMyCells && nowHasMyCells && !hadMyCells) {
            [tvSeals insertSections:isMiddle withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        
        if (updatedTheirCells && nowHasTheirCells && !hadTheirCells) {
            if (nowHasMyCells) {
                [tvSeals insertSections:isLast withRowAnimation:UITableViewRowAnimationAutomatic];
            }
            else {
                [tvSeals insertSections:isMiddle withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }
    }
    
    // - turn editing on/off based on whether there are any seals.
    if ([maMySeals count] || [maOtherSeals count]) {
        [self.navigationItem.leftBarButtonItem setEnabled:YES];
    }
    else {
        if (tvSeals.editing) {
            [tvSeals setEditing:NO animated:animated];
        }
        [self.navigationItem.leftBarButtonItem setEnabled:NO];
    }
    
    if (animated) {
        [tvSeals endUpdates];
    }
    
    // - when this isn't supposed to be animated, do an explicit reload
    if (hasNewContent && !animated) {
        [tvSeals reloadData];
    }
    else {
        // - now see if we need to do a more precise update of just what we can see.
        NSMutableArray *maReload = [NSMutableArray array];
        for (NSIndexPath *ipVisible in tvSeals.indexPathsForVisibleRows) {
            UISealVaultCell *svc   = (UISealVaultCell *) [tvSeals cellForRowAtIndexPath:ipVisible];
            if (!svc) {
                continue;
            }
            
            // - update my cells?
            if (!updatedMyCells && [self realSectionForLogicalSection:ipVisible.section] == UISVC_SEC_MINE) {
                if (ipVisible.row < [maMySeals count]) {
                    ChatSealIdentity *psi = [maMySeals objectAtIndex:(NSUInteger) ipVisible.row];
                    if ([ChatSeal isAdvancedSelfSizingInUse]) {
                        // - the height could change so we are going to do an explicit reload to force the height recalc, but
                        //   we don't want to reload needlessly.
                        if ([svc doesCellContentChangeWithIdentity:psi]) {
                            [maReload addObject:ipVisible];
                        }
                    }
                    else {
                        [svc updateStatsWithIdentity:psi andAnimation:YES];
                    }
                }
            }
            
            // - update their cells?
            if (!updatedTheirCells && [maOtherSeals count] && [self realSectionForLogicalSection:ipVisible.section] == UISVC_SEC_THEIRS) {
                if (ipVisible.row < [maOtherSeals count]) {
                    ChatSealIdentity *psi = [maOtherSeals objectAtIndex:(NSUInteger) ipVisible.row];
                    if ([ChatSeal isAdvancedSelfSizingInUse]) {
                        // - the height could change so we are going to do an explicit reload to force the height recalc, but
                        //   we don't want to reload needlessly.
                        if ([svc doesCellContentChangeWithIdentity:psi]) {
                            [maReload addObject:ipVisible];
                        }
                    }
                    else {
                        [svc updateStatsWithIdentity:psi andAnimation:YES];
                    }
                }
            }
        }
        
        // - when we need to do an explicit reload, do so now.
        if ([maReload count]) {
            [tvSeals reloadRowsAtIndexPaths:maReload withRowAnimation:animated ? UITableViewRowAnimationFade : UITableViewRowAnimationNone];
        }
        
        if (!updatedTools) {
            [self reconfigureToolsForNewSurroundingsWithAnimation:animated];
        }
    }
    
    // - scroll to the new item.
    if (hasAppeared && newItemSection != -1 && animated) {
        if (newItemSection == UISVC_SEC_THEIRS && ![maMySeals count]) {
            newItemSection = 1;
        }
        [tvSeals scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:newItemRow inSection:newItemSection] atScrollPosition:UITableViewScrollPositionNone animated:YES];
    }
}

/*
 *  The table insets are set up to correctly display the content, considering that there are top/bottom bars.
 */
-(void) updateTableInsets
{
    CGFloat topOffset    = CGRectGetMaxY(self.navigationController.navigationBar.frame);
    CGFloat botOffset    = [[ChatSeal applicationHub] tabBarHeight];
    tvSeals.contentInset = UIEdgeInsetsMake(topOffset, 0.0f, botOffset, 0.0f);
}

/*
 *  When a low-storage scenario is resolved, this method is called.
 */
-(void) notifyLowStorageResolved
{
    if ([vfoFailDisplay isFailureVisible]) {
        [self updateSealDataWithAnimation:YES];
    }
}

/*
 *  Convert from a section used by the table to one that allows us to identify what is being modifed
 *  since we may not have any seals ourselves, but want to show others' seals.
 */
-(uisvc_sec_id_t) realSectionForLogicalSection:(NSInteger) sec
{
    // - the tools are always visible and at position zero.
    if (sec == 0) {
        return UISVC_SEC_TOOLS;
    }
    
    // - the middle section is the hairy one based on whether
    //   I have any seals or not.
    if (sec == 1) {
        if ([maMySeals count]) {
            return UISVC_SEC_MINE;
        }
        else {
            return UISVC_SEC_THEIRS;
        }
    }
    
    // - the third section is always clear since we only
    //   have it when we personally own seals.
    if (sec == 2) {
        return UISVC_SEC_THEIRS;
    }
    
    // - this is a problem, so don't encourage ignorance.
    return UISVC_SEC_INVALID;
}

/*
 *  A dynamic type notification was received.
 */
-(void) updateDynamicTypeNotificationReceived
{
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        // - NOTE: the table will be automatically restyled.
        [vfoFailDisplay updateDynamicTypeNotificationReceived];
    }
}
@end

/************************************
 UISealVaultViewController (mySeals)
 ************************************/
@implementation UISealVaultViewController (mySeals)
/*
 *  Edit the active seal list.
 */
-(void) doEditMySeals
{
    BOOL willBeEditing = !tvSeals.editing;
    [tvSeals setEditing:willBeEditing animated:YES];
    [self setNavButtonToEditingInUse:willBeEditing withAnimation:YES];
}

/*
 *  Add a new seal to my list and make it active.
 */
-(void) doAddNewSeal
{
    // - create a new seal.
    UIViewController *vc = [UINewSealViewController viewControllerWithCreationCompletionBlock:^(BOOL isCancelled, NSString *sealId) {
        [self dismissViewControllerAnimated:YES completion:^(void) {
            if (!isCancelled && sealId) {
                [ChatSeal waitForAllVaultOperationsToComplete];
                [self updateSealDataWithAnimation:YES];
            }
        }];
    }];
    [self presentViewController:vc animated:YES completion:nil];
}
@end

/************************************
 UISealVaultViewController (table)
 ************************************/
@implementation UISealVaultViewController (table)
/*
 *  When owned seals exist in the vault, this returns YES.
 */
-(BOOL) hasOwnedSeals
{
    if ([maMySeals count]) {
        return YES;
    }
    return NO;
}

/*
 *  When the vault contains other peoples' seals, this returns YES.
 */
-(BOOL) hasOthersSeals
{
    if ([maOtherSeals count]) {
        return YES;
    }
    return NO;
}
/*
 *  Returns the number of sections we'll display in the table.
 */
-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    // - there are 3 possible sections:
    //   ...tools (probably untitled)
    //   ...my seals
    //   ...others' seals
    
    // - in order to ensure we can reset headers, which requires full section deletion, we're
    //   only going to return the precise number of sections that have content
    NSInteger ret = 1;
    if ([self hasOwnedSeals]) {
        ret++;
    }
    if ([self hasOthersSeals]) {
        ret++;
    }
    return ret;
}

/*
 *  Returns the number of rows in each section of the table view.
 */
-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    section = [self realSectionForLogicalSection:section];
    switch (section) {
        case UISVC_SEC_TOOLS:
            // - NOTE: we always show the privacy cell first.
            if ([self hasOwnedSeals]) {
                return 3;                       //  both scan and give.
            }
            else {
                return 2;                       //  only scan
            }
            break;
            
        case UISVC_SEC_MINE:
            return (NSInteger) [maMySeals count];
            break;
            
        case UISVC_SEC_THEIRS:
            return (NSInteger) [maOtherSeals count];
            break;
    }
    return 0;
}

/*
 *  Returns a cell at a given row in the table.
 */
-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *tvcRet = nil;
    if (indexPath.section == UISVC_SEC_TOOLS) {
        if (indexPath.row == UISVC_TOOL_PRIV) {
            tvcRet = [tableView dequeueReusableCellWithIdentifier:@"UISealVaultPrivacyCell"];
        }
        else if (indexPath.row == UISVC_TOOL_SCAN) {
            UISealVaultScanCell *svsc = [tableView dequeueReusableCellWithIdentifier:@"UISealVaultScanCell"];
            [svsc reconfigureCellForSharingAvailabilityWithAnimation:NO];
            tvcRet = svsc;
        }
        else if (indexPath.row == UISVC_TOOL_GIVE) {
            // - give my seal.
            UISealVaultGiveCell *svgc = [tableView dequeueReusableCellWithIdentifier:@"UISealVaultGiveCell"];
            [svgc reconfigureCellForSharingAvailabilityWithAnimation:NO];
            tvcRet = svgc;
        }
    }
    else {
        //  - the two latter sections are both for displaying seals.
        UISealVaultCell *svc = [tableView dequeueReusableCellWithIdentifier:@"UISealVaultCell" forIndexPath:indexPath];
        if ([self realSectionForLogicalSection:indexPath.section] == UISVC_SEC_MINE) {
            if (indexPath.row < [maMySeals count]) {
                ChatSealIdentity *psi = [maMySeals objectAtIndex:(NSUInteger) indexPath.row];
                [svc configureCellWithIdentity:psi andShowDisclosureIndicator:YES];
            }
        }
        else {
            if (indexPath.row < [maOtherSeals count]) {
                ChatSealIdentity *psi = [maOtherSeals objectAtIndex:(NSUInteger) indexPath.row];
                [svc configureCellWithIdentity:psi andShowDisclosureIndicator:NO];
            }
        }
        tvcRet = svc;
    }
    return tvcRet;
}

/*
 *  Returns the title for the given section.
 */
-(NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == UISVC_SEC_TOOLS) {
        return NSLocalizedString(@"Connect With Friends", nil);
    }
    else {
        if ([self realSectionForLogicalSection:section] == UISVC_SEC_MINE) {
            return NSLocalizedString(@"My Seals", nil);
        }
        else {
            return NSLocalizedString(@"Friends' Seals", nil);
        }
    }
}

/*
 *  Returns the editing capabilities for each row.
 */
-(BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger section = [self realSectionForLogicalSection:indexPath.section];
    if (section == UISVC_SEC_MINE || section == UISVC_SEC_THEIRS) {
        return YES;
    }
    return NO;
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
        static CGFloat privHeight = -1;
        static CGFloat scanHeight = -1;
        static CGFloat giveHeight = -1;
        static CGFloat stdHeight  = -1;
        
        NSInteger section = [self realSectionForLogicalSection:indexPath.section];
        switch (section) {
            case UISVC_SEC_TOOLS:
                if (indexPath.row == UISVC_TOOL_PRIV) {
                    if (privHeight < 0.0f) {
                        UISealVaultPrivacyCell *svpc = [tableView dequeueReusableCellWithIdentifier:@"UISealVaultPrivacyCell"];
                        privHeight                   = CGRectGetHeight(svpc.bounds);
                    }
                    return privHeight;
                }
                else if (indexPath.row == UISVC_TOOL_SCAN) {
                    if (scanHeight < 0.0f) {
                        UISealVaultScanCell *svsc = [tableView dequeueReusableCellWithIdentifier:@"UISealVaultScanCell"];
                        scanHeight                = CGRectGetHeight(svsc.bounds);
                    }
                    return scanHeight;
                }
                else if (indexPath.row == UISVC_TOOL_GIVE) {
                    if (giveHeight < 0.0f) {
                        UISealVaultGiveCell *svgc = [tableView dequeueReusableCellWithIdentifier:@"UISealVaultGiveCell"];
                        giveHeight                = CGRectGetHeight(svgc.bounds);
                    }
                    return giveHeight;
                }
                break;
                
            case UISVC_SEC_MINE:
            case UISVC_SEC_THEIRS:
                if (stdHeight < 0.0f) {
                    UISealVaultCell *svc = [tableView dequeueReusableCellWithIdentifier:@"UISealVaultCell"];
                    stdHeight            = CGRectGetHeight(svc.bounds);
                }
                return stdHeight;
                break;
        }
        return 0.0f;
    }
}

/*
 *  Figure out if the identity requires a confirmation before deleting it and display an action sheet if necessary.
 */
-(BOOL) shouldConfirmSealDeletionIfNecessaryForIdentity:(ChatSealIdentity *) psi atIndexPath:(NSIndexPath *) ip fromMine:(BOOL) fromMine
{
    NSString *asTitle         = nil;
    NSString *asDestroy       = nil;
    NSUInteger countActiveMsg = [ChatSealMessage countOfMessagesForSeal:psi.sealId];
    
    // - figure out if any of the conditions are such that it is a good idea to confirm first.
    if ([psi isOwned]) {
        // - when the seal has been given, it is important that we upgrade the warnings to better describe the implications
        //   of deleting my keys.
        if ([psi sealGivenCount]) {
            if ([psi sentCount]) {
                if ([psi sealGivenCount] == 1) {
                    asTitle = NSLocalizedString(@"You shared this seal with a friend.\nIf you delete it, you won't be able to fully control how they use the messages you sent to them.", nil);
                }
                else {
                    asTitle = NSLocalizedString(@"You shared this seal with your friends.\nIf you delete it, you won't be able to fully control how they use the messages you sent to them.", nil);
                }
            }
        }
        else {
            if (countActiveMsg) {
                asTitle = NSLocalizedString(@"If you delete your seal, you won't be able to read the messages you created with it. ", nil);
            }
        }
        asDestroy = NSLocalizedString(@"Delete My Seal", nil);
    }
    else {
        //  - when a seal is revoked/expired, no need to confirm because
        //    it really has no value at this point.
        if ([psi isRevoked] || [psi isExpired]) {
            return NO;
        }
        
        // - the seal is OK, so let's look closer.
        NSString *friendName = [psi ownerName];
        if (countActiveMsg) {
            if (friendName) {
                asTitle = NSLocalizedString(@"If you delete this seal, all of its messages will be locked until %@ shares it with you again.", nil);
                asTitle = [NSString stringWithFormat:asTitle, friendName];
            }
            else {
                asTitle = NSLocalizedString(@"If you delete this seal, all of its messages will be locked until your friend shares it with you again.", nil);
            }
        }
        else {
            if (friendName) {
                asTitle = NSLocalizedString(@"If you delete this seal, you won't be able to use it for personal communication with %@.", nil);
                asTitle = [NSString stringWithFormat:asTitle, friendName];
            }
            else {
                asTitle = NSLocalizedString(@"If you delete this seal, you won't be able to use it for personal communication with your friend.", nil);
            }
        }
        asDestroy = NSLocalizedString(@"Delete This Seal", nil);
    }
    
    // - only display the action sheet if there is confirmation text.
    if (asTitle && asDestroy) {
        // - deleting a seal always requires confirmation.
        UISealDeletionActionSheet *as = [[UISealDeletionActionSheet alloc] initWithTitle:asTitle
                                                                                delegate:self
                                                                       cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                                  destructiveButtonTitle:asDestroy
                                                                       otherButtonTitles:nil];
        as.ipToDelete = ip;
        as.fromMine   = fromMine;
        as.sealId     = psi.sealId;
        as.delegate   = self;
        [as showInView:self.view];
        [as release];
        return YES;
    }
    else {
        return NO;
    }
}

/*
 *  Complete the seal deletion process.
 */
-(void) deleteSealAtIndex:(NSIndexPath *) indexPath fromMine:(BOOL) fromMine withSeal:(NSString *) sealId
{
    if (!indexPath || !sealId) {
        return;
    }
    
    // - delete it permanently
    NSError *err           = nil;
    BOOL computeFullUpdate = NO;
    if ([ChatSeal deleteSealForId:sealId withError:&err]) {
        NSInteger numRemain = 0;
        
        // - remove the item from the internal arrays
        if (fromMine) {
            // - when this requires section modifications, we can't delete the
            //   item in the array here or it will confuse the update method.
            numRemain = (NSInteger) [maMySeals count] - 1;
            if (numRemain > 0) {
                [maMySeals removeObjectAtIndex:(NSUInteger) indexPath.row];
            }
            else {
                computeFullUpdate = YES;
            }
        }
        else {
            // - when this requires section modifications, we can't delete the
            //   item in the array here or it will confuse the update method.
            numRemain = (NSInteger) [maOtherSeals count] - 1;
            if (numRemain > 0) {
                [maOtherSeals removeObjectAtIndex:(NSUInteger) indexPath.row];
            }
            else {
                computeFullUpdate = YES;
            }
        }
        
        // - remove the cells from the table view
        if (numRemain == 0) {
            // - when we delete the final section, in order to get a clean animation, we're going to do a bit more.
            if (indexPath.section == UISVC_SEC_THEIRS || [maOtherSeals count] == 0) {
                [self fadeOutCellAtIndexPath:indexPath];
            }
        }
        else if (numRemain == 1) {
            // - the animation is less than ideal when we delete the next to the last one.
            if (indexPath.row == numRemain) {
                [self fadeOutCellAtIndexPath:indexPath];
            }
        }
        
        //  - in order to keep the section addition/deletion code in one place, we'll only do this
        //    with the heavier update method.
        if (computeFullUpdate) {
            [self updateSealDataWithAnimation:YES];
        }
        else {
            // - we're just deleting a single row, so it can be self-contained here.
            [tvSeals beginUpdates];
            [tvSeals deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
            [tvSeals endUpdates];
        }
    }
    else {
        // - present an appropriate error
        [AlertManager displayFatalAlertWithLowSpaceDetectionUsingTitle:NSLocalizedString(@"Seal Deletion Interrupted", nil)
                                                               andText:NSLocalizedString(@"Your %@ was unable to delete the seal.", nil)];
    }
}

/*
 *  Manage the deletions of seals.
 */
-(void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger section = [self realSectionForLogicalSection:indexPath.section];
    if (editingStyle != UITableViewCellEditingStyleDelete || !(section == UISVC_SEC_MINE || section == UISVC_SEC_THEIRS)) {
        return;
    }
    
    // - find the identity for the seal.
    ChatSealIdentity *psi     = nil;
    BOOL              fromMine = NO;
    if (section == UISVC_SEC_MINE) {
        fromMine = YES;
        if (indexPath.row < [maMySeals count]) {
            psi = [maMySeals objectAtIndex:(NSUInteger) indexPath.row];
        }
    }
    else {
        // - see if we have any active messages and adapt the warning.
        if (indexPath.row < [maOtherSeals count]) {
            psi = [maOtherSeals objectAtIndex:(NSUInteger) indexPath.row];
        }
    }
    
    // - nothing to do?
    if (!psi) {
        NSLog(@"CS:  Failed to retrieve an identity for the seal at index %ld:%ld.", (long) indexPath.section, (long) indexPath.row);
        return;
    }

    // - and see if confirmation is needed
    if (![self shouldConfirmSealDeletionIfNecessaryForIdentity:psi atIndexPath:indexPath fromMine:fromMine]) {
        [self deleteSealAtIndex:indexPath fromMine:fromMine withSeal:psi.sealId];
    }
}

/*
 *  Fade out the cell.
 */
-(void) fadeOutCellAtIndexPath:(NSIndexPath *) ipToFade
{
    UITableViewCell *tvc = [tvSeals cellForRowAtIndexPath:ipToFade];
    if (tvc) {
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            tvc.alpha = 0.0f;
        }];
    }
}

/*
 *  The action sheet was dismissed.
 */
-(void) actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if ([actionSheet isKindOfClass:[UISealDeletionActionSheet class]] && buttonIndex == 0) {
        // - delete the item.
        UISealDeletionActionSheet *sdas = (UISealDeletionActionSheet *) actionSheet;
        [self deleteSealAtIndex:sdas.ipToDelete fromMine:sdas.fromMine withSeal:sdas.sealId];
    }
}

/*
 *  Prevent row highlighting when it doesn't make sense.
 */
-(BOOL) tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([tvSeals shouldPermitHighlight]) {
        if (indexPath.section == UISVC_SEC_TOOLS) {
            if (indexPath.row == UISVC_TOOL_PRIV) {
                return YES;
            }
            else {
                // - if the accessory button is present, then we're going to use the accessory tap instead.
                UISealVaultToolCell *svtc = (UISealVaultToolCell *) [tableView cellForRowAtIndexPath:indexPath];
                if ([svtc isSharingPossible]) {
                    return YES;
                }
            }
        }
        else if ([self realSectionForLogicalSection:indexPath.section] == UISVC_SEC_MINE) {
            return YES;
        }
    }
    return NO;
}

/*
 *  A cell was selected and we should go to its detail screen.
 */
-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == UISVC_SEC_TOOLS) {
        if (indexPath.row == UISVC_TOOL_PRIV) {
            [UIPrivacyViewController displayPrivacyNoticeFromViewController:self asModal:NO];
        }
        else if (indexPath.row == UISVC_TOOL_SCAN) {
            UIViewController *vc = [UISealExchangeController sealAcceptViewControllerForIdentity:nil];
            [self.tvSeals prepareForNavigationPush];
            [self.navigationController pushViewController:vc animated:YES];
        }
        else if (indexPath.row == UISVC_TOOL_GIVE) {
            UISealVaultGiveCell *svgc = (UISealVaultGiveCell *) [tvSeals cellForRowAtIndexPath:indexPath];
            if (svgc) {
                if ([svgc isSharingPossible]) {
                    UIViewController *vc = [UISealExchangeController sealShareViewControllerForIdentity:nil];
                    [self.tvSeals prepareForNavigationPush];
                    [self.navigationController pushViewController:vc animated:YES];
                }
                else {
                    UIViewController *vc = [UISealSelectionViewController viewControllerForMessageSealSelection:NO withSelectionCompletionBlock:^(BOOL hasActiveCell) {
                        [self dismissViewControllerAnimated:YES completion:^(void) {
                            [self updateSealDataWithAnimation:YES];
                        }];
                    }];
                    [self presentViewController:vc animated:YES completion:nil];
                }
            }
        }
    }
    else if ([self realSectionForLogicalSection:indexPath.section] == UISVC_SEC_MINE) {
        if (indexPath.row < [maMySeals count]) {
            ChatSealIdentity *psi = [maMySeals objectAtIndex:(NSUInteger) indexPath.row];
            if (psi) {
                UISealDetailViewController *sdvc = (UISealDetailViewController *) [ChatSeal viewControllerForStoryboardId:@"UISealDetailViewController"];
                [sdvc setIdentity:psi];
                [self.tvSeals prepareForNavigationPush];
                [self.navigationController pushViewController:sdvc animated:YES];
            }
        }
    }
    [tvSeals deselectRowAtIndexPath:indexPath animated:YES];
}

/*
 *  Deal with the accessory tap.
 */
-(void) tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    // - treat it just like a selection.
    [self tableView:tableView didSelectRowAtIndexPath:indexPath];
}

/*
 *  When the tools cells are active, reconfigure them to reflect the current state of the local user community.
 */
-(void) reconfigureToolsForNewSurroundingsWithAnimation:(BOOL) animated
{
    NSMutableArray *maReload  = [NSMutableArray array];
    NSIndexPath *ipCheck      = [NSIndexPath indexPathForRow:UISVC_TOOL_SCAN inSection:UISVC_SEC_TOOLS];
    UISealVaultScanCell *svsc = (UISealVaultScanCell *) [tvSeals cellForRowAtIndexPath:ipCheck];
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        // - the height may have changed.
        if ([svsc hasDetailContentChanged]) {
            [maReload addObject:ipCheck];
        }
    }
    else {
        [svsc reconfigureCellForSharingAvailabilityWithAnimation:animated];
    }
    
    ipCheck                   = [NSIndexPath indexPathForRow:UISVC_TOOL_GIVE inSection:UISVC_SEC_TOOLS];
    UISealVaultGiveCell *svgc = (UISealVaultGiveCell *) [tvSeals cellForRowAtIndexPath:ipCheck];
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        // - the height may have changed.
        if ([svgc hasDetailContentChanged]) {
            [maReload addObject:ipCheck];
        }
    }
    else {
        [svgc reconfigureCellForSharingAvailabilityWithAnimation:animated];
    }
    
    // - if we have anything marked for reload, do that now.
    if ([maReload count]) {
        [tvSeals reloadRowsAtIndexPaths:maReload withRowAnimation:animated ? UITableViewRowAnimationFade : UITableViewRowAnimationNone];
    }
}

/*
 *  When one of the base station notifications come in to reflect current proximity information,
 *  update the tools.
 */
-(void) notifyBasestationUpdate
{
    [self reconfigureToolsForNewSurroundingsWithAnimation:YES];
}

/*
 *  When seals are invalidated, make sure these cells are up to date.
 */
-(void) notifySealInvalidation
{
    // - when this view is visible, update the cells right now.
    if (self.view.superview) {
        [self updateSealDataWithAnimation:YES];
    }
}

/*
 *  Change the left navbar button to edit/cancel based on whether editing is in effect.
 */
-(void) setNavButtonToEditingInUse:(BOOL) inUse withAnimation:(BOOL) animated
{
    UIBarButtonItem *bbi = nil;
    if (inUse) {
        bbi = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(doEditMySeals)];
    }
    else {
        bbi = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(doEditMySeals)];
    }
    
    // - because of the way the hub is constructed, the nav item isn't connected to the nav controller after first initialization, so
    //   we need to explicitly force the synchronization to occur.
    self.navigationItem.leftBarButtonItem = bbi;
    [bbi release];
    
    // - update the add button also so that we can disable it.
    bbi    = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(doAddNewSeal)];
    if (inUse) {
        bbi.enabled = NO;
    }
    self.navigationItem.rightBarButtonItem = bbi;
    [bbi release];
 
    
    [[ChatSeal applicationHub] syncNavigationItemFromTopViewController:self withAnimation:animated];
}

@end

/******************************
 UISealDeletionActionSheet
 ******************************/
@implementation UISealDeletionActionSheet
@synthesize ipToDelete;
@synthesize fromMine;
@synthesize sealId;
/*
 *  Free the object.
 */
-(void) dealloc
{
    [ipToDelete release];
    ipToDelete = nil;
    
    [sealId release];
    sealId = nil;
    [super dealloc];
}
@end

/*****************************************
 UISealVaultViewController (vaultOverlay)
 *****************************************/
@implementation UISealVaultViewController (vaultOverlay)

/*
 *  Display the seal vault failure overlay.
 */
-(void) showSealVaultFailureWithAnimation:(BOOL) animated
{
    [vfoFailDisplay showFailureWithTitle:NSLocalizedString(@"Seals Locked", nil) andText:NSLocalizedString(@"Your Seal Vault cannot be unlocked due to an unexpected problem.", nil) andAnimation:animated];
    self.navigationItem.leftBarButtonItem.enabled  = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
}

/*
 *  Hide the seal vault failure overlay.
 */
-(void) hideSealVaultFailureWithAnimation:(BOOL) animated
{
    [vfoFailDisplay hideFailureWithAnimation:animated];
    self.navigationItem.rightBarButtonItem.enabled = YES;
}

/*
 *  Generate the vault failure placeholder.
 */
+(UIImage *) generateVaultFailurePlaceholderOfSize:(CGSize) szPlaceholder withInsets:(UIEdgeInsets) insets andContext:(NSObject *) ctx
{
    // - first grab the last placeholder content and analyze it to get a feel for
    //   the makeup of this view.
    NSArray *arr   = [ChatSealVaultPlaceholder vaultSealPlaceholderData];
    BOOL hasMine   = NO;
    BOOL hasOthers = NO;
    for (ChatSealVaultPlaceholder *svp in arr) {
        if (svp.isMine) {
            hasMine = YES;
        }
        else {
            hasOthers = YES;
        }
    }

    // - we can draw now.
    UIGraphicsBeginImageContextWithOptions(szPlaceholder, YES, 0.0f);
    
    // ...first the background
    [[UIVaultFailureOverlayView standardPlaceholderWhiteAlternative] setFill];
    UIRectFill(CGRectMake(0.0f, 0.0f, szPlaceholder.width, szPlaceholder.height));
    
    // ...now we need to create the tools
    CGFloat curPos    = insets.top;
    CGRect rcToFill   = CGRectMake(0.0f, curPos, szPlaceholder.width, [UIVaultFailureOverlayView standardHeaderHeight]);
    [UIVaultFailureOverlayView drawStandardHeaderInRect:rcToFill assumingTextPct:0.5f];
    curPos            = CGRectGetMaxY(rcToFill);
    
    curPos            = [UIVaultFailureOverlayView drawStandardToolLineAtPos:curPos andWithWidth:szPlaceholder.width andShowText:YES ofWidth:UISVC_PH_TOOL_TEXT_CX];
    if (hasMine) {
        curPos        = [UIVaultFailureOverlayView drawStandardToolLineAtPos:curPos andWithWidth:szPlaceholder.width andShowText:YES ofWidth:UISVC_PH_TOOL_TEXT_CX];
    }
    
    // ... now the content, which will either be empty because there are no seals or
    //     will show the seal cells in their groups.
    if (hasMine || hasOthers) {
        rcToFill      = CGRectMake(0.0f, curPos, szPlaceholder.width, [UIVaultFailureOverlayView standardHeaderHeight]);
        [UIVaultFailureOverlayView drawStandardHeaderInRect:rcToFill assumingTextPct:0.25f];
        if (!hasMine) {
            hasOthers = NO;
        }
        curPos = CGRectGetMaxY(rcToFill);
        
        // - get a cell we can use for drawing.
        UISealVaultCell *svc = [[[UISealVaultCell alloc] init] autorelease];
        svc.frame            = CGRectMake(0.0f, 0.0f, szPlaceholder.width, [UISealVaultCell standardCellHeight]);
        NSUInteger curItem = 0;
        while (curPos < szPlaceholder.height) {
            ChatSealVaultPlaceholder *svp = nil;
            if (curItem < [arr count]) {
                svp = [arr objectAtIndex:curItem];
                curItem++;
            }
            
            // - add a second header if need-be.
            if (hasOthers && !svp.isMine) {
                rcToFill  = CGRectMake(0.0f, curPos, szPlaceholder.width, [UIVaultFailureOverlayView standardHeaderHeight]);
                [UIVaultFailureOverlayView drawStandardHeaderInRect:rcToFill assumingTextPct:0.35f];
                curPos    = CGRectGetMaxY(rcToFill);
                hasOthers = NO;
            }
            
            CGContextSaveGState(UIGraphicsGetCurrentContext());
            CGContextTranslateCTM(UIGraphicsGetCurrentContext(), 0.0f, curPos);
            [svc drawStylizedVersionWithPlaceholder:svp];
            CGContextRestoreGState(UIGraphicsGetCurrentContext());
            curPos +=  [UISealVaultCell standardCellHeight];
        }
    }
    else {
        // - with no seals, we need to make it look like a table where it creates separators for empty content
        while (curPos < szPlaceholder.height) {
            curPos = [UIVaultFailureOverlayView drawStandardToolLineAtPos:curPos andWithWidth:szPlaceholder.width andShowText:NO ofWidth:UISVC_PH_TOOL_TEXT_CX];
        }
    }
    
    UIImage *ret = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return ret;
}

/*
 *  Generate a placeholder for this view.
 */
-(UIImage *) placeholderImageForOverlay:(UIVaultFailureOverlayView *)overlay
{
    return [UISealVaultViewController generateVaultFailurePlaceholderOfSize:[ChatSeal appWindowDimensions]
                                                                 withInsets:UIEdgeInsetsMake(CGRectGetMaxY(self.navigationController.navigationBar.frame), 0.0f, 0.0f, 0.0f)
                                                                 andContext:self];
}

@end
