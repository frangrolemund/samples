//
//  UISealSelectionViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/2/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealSelectionViewController.h"
#import "ChatSeal.h"
#import "UISealVaultCell.h"
#import "AlertManager.h"
#import "UINewSealViewController.h"
#import "ChatSealVaultPlaceholder.h"
#import "UISealVaultViewController.h"

// - constants
static const CGFloat UISSC_PH_HEADER_HEIGHT = 42.0f;
static const CGFloat UISSC_PH_HDR_VPAD      = 8.0f;


// - types
typedef enum {
    UISSV_SEC_NEW = 0,
    UISSV_SEC_CUR = 1
} uissv_sec_type_t;

// - forward declarations
@interface UISealSelectionViewController (internal) <UIDynamicTypeCompliantEntity>
-(void) setCompletionBlock:(sealSelectionCompleted) cb;
-(void) completeTheSelectionProcess;
-(void) setFatalErrorState:(BOOL) asFatal withText:(NSString *) text withAnimation:(BOOL) animated;
-(void) updateEditStateForView;
-(uissv_sec_type_t) realSectionForLogicalSection:(NSInteger) sec;
-(void) setActiveSeal:(NSString *) activeSeal;
-(void) loadIdentitiesOrDisplayErrorWithAnimation:(BOOL) animated;
-(void) notifyLowSpaceResolved;
-(void) setIsMessageSeal:(BOOL) ims;
-(void) setNavButtonToEditingInUse:(BOOL) inUse withAnimation:(BOOL) animated;
@end

// - table declarations
@interface UISealSelectionViewController (table) <UITableViewDataSource, UITableViewDelegate>
@end

// - overlay support
@interface UISealSelectionViewController (vaultOverlay) <UIVaultFailureOverlayViewDelegate>
+(NSArray *) convertIdentityArrayToPlaceholders:(NSArray *) arr;
+(void) drawPlaceholderCell:(UISealVaultCell *) cell withPlaceholder:(ChatSealVaultPlaceholder *) ph atPosition:(CGFloat) yPos;
@end

/******************************
 UISealSelectionViewController
 ******************************/
@implementation UISealSelectionViewController
/*
 *  Object attributes.
 */
{
    sealSelectionCompleted completionBlock;
    NSMutableArray         *maNewSeals;
    NSMutableArray         *maExistingSeals;
    BOOL                   inFatalError;
    NSString               *sCurActiveSeal;
    BOOL                   isMessageSeal;
}
@synthesize bbiUseThisSeal;
@synthesize tvSeals;
@synthesize bbiEdit;
@synthesize bbiNewSeal;
@synthesize vfoErrorDisplay;

/*
 *  Returns whether it makes sense to select seals.
 */
+(BOOL) selectionIsPossibleWithError:(NSError **) err
{
    if ([ChatSeal hasVault]) {
        NSArray *arr = [ChatSeal availableIdentitiesWithError:err];
        if (arr) {
            // - if any of the seals in the vault are owned, we can select from them.
            for (ChatSealIdentity *ident in arr) {
                if ([ident isOwned]) {
                    return YES;
                }
            }
        }
    }
    return NO;
}

/*
 *  Create and return a suitable view controller for active seal selection.
 */
+(UIViewController *) viewControllerWithSelectionCompletionBlock:(sealSelectionCompleted) completionBlock
{
    return [UISealSelectionViewController viewControllerForMessageSealSelection:YES withSelectionCompletionBlock:completionBlock];
}

/*
 *  Return a new seal selection screen, but select how it will be described at the top.
 *  - either for sealing a message or sharing with a friend.
 */
+(UIViewController *) viewControllerForMessageSealSelection:(BOOL) isForSealingMessages withSelectionCompletionBlock:(sealSelectionCompleted) completionBlock
{
    UINavigationController *nc = (UINavigationController *) [ChatSeal viewControllerForStoryboardId:@"UISealSelectionNavigationController"];
    if (nc) {
        UISealSelectionViewController *ssvc = (UISealSelectionViewController *) nc.topViewController;
        [ssvc setIsMessageSeal:isForSealingMessages];
        [ssvc setCompletionBlock:completionBlock];
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
        completionBlock = nil;
        inFatalError    = NO;
        isMessageSeal   = YES;
        maNewSeals      = [[NSMutableArray alloc] init];
        maExistingSeals = [[NSMutableArray alloc] init];
        [self setActiveSeal:[ChatSeal activeSeal]];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [bbiUseThisSeal release];
    bbiUseThisSeal = nil;

    tvSeals.delegate = nil;
    tvSeals.dataSource = nil;
    [tvSeals release];
    tvSeals = nil;
    
    [bbiEdit release];
    bbiEdit = nil;
    
    [bbiNewSeal release];
    bbiNewSeal = nil;
    
    [vfoErrorDisplay release];
    vfoErrorDisplay = nil;
    
    [maNewSeals release];
    maNewSeals = nil;
    
    [maExistingSeals release];
    maExistingSeals = nil;
    
    [self setActiveSeal:nil];
    [self setCompletionBlock:nil];
    [super dealloc];
}

/*
 *  Configure the object after loading.
 */
-(void) viewDidLoad
{
    [super viewDidLoad];
    
    // - wire up the table
    [UISealVaultCell registerCellForTable:tvSeals forCellReuseIdentifier:@"UISealVaultCell"];
    tvSeals.delegate   = self;
    tvSeals.dataSource = self;
    
    // - the failure overlay will require some placeholder support.
    vfoErrorDisplay.delegate = self;
    
    // - load up the available identities.
    [self loadIdentitiesOrDisplayErrorWithAnimation:NO];
    
    // - hide the toolbar initially so that the user's eye is drawn downward.
    [self.navigationController setToolbarHidden:YES];
    
    // - watch for low space resolutions
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyLowSpaceResolved) name:kChatSealNotifyLowStorageResolved object:nil];
}

/*
 *  The view is about to appear.
 */
-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (sCurActiveSeal) {
        for (NSUInteger i = 0; i < [maNewSeals count]; i++) {
            ChatSealIdentity *psi = [maNewSeals objectAtIndex:i];
            if ([sCurActiveSeal isEqualToString:psi.sealId]) {
                [tvSeals scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:(NSInteger) i inSection:UISSV_SEC_NEW] atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
                bbiUseThisSeal.enabled = YES;
                return;
            }
        }
        for (NSUInteger i = 0; i < [maExistingSeals count]; i++) {
            ChatSealIdentity *psi = [maExistingSeals objectAtIndex:i];
            if ([sCurActiveSeal isEqualToString:psi.sealId]) {
                [tvSeals scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:(NSInteger) i inSection:[maNewSeals count] ? 1 : 0] atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
                bbiUseThisSeal.enabled = YES;
                return;
            }
        }
        [self setActiveSeal:nil];
    }
}

/*
 *  The view has appeared.
 */
-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // - show the toolbar
    [self.navigationController setToolbarHidden:NO animated:YES];
}

/*
 *  Cancel seal selection.
 */
-(IBAction)doCancel:(id)sender
{
    // - nothing to do here, we aren't changing anything.
    [self completeTheSelectionProcess];
}

/*
 *  Add a new seal to the vault.
 */
-(IBAction)doAddNewSeal:(id)sender
{
    UIViewController *nsvc = [UINewSealViewController viewControllerWithCreationCompletionBlock:^(BOOL isCancelled, NSString *sealId) {
        [self dismissViewControllerAnimated:YES completion:^(void) {
            if (!isCancelled && sealId) {
                NSError *err = nil;
                [ChatSeal waitForAllVaultOperationsToComplete];
                ChatSealIdentity *ident = [ChatSeal identityForSeal:sealId withError:&err];
                if (ident) {
                    [maNewSeals insertObject:ident atIndex:0];
                    [CATransaction begin];
                    [CATransaction setCompletionBlock:^(void) {
                        [tvSeals selectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:UISSV_SEC_NEW] animated:YES scrollPosition:UITableViewScrollPositionMiddle];
                    }];
                    [tvSeals beginUpdates];
                    if ([maNewSeals count] == 1) {
                        [tvSeals insertSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
                    }
                    else {
                        
                        [tvSeals insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                    }
                    [tvSeals endUpdates];
                    [CATransaction commit];
                    [self setActiveSeal:ident.sealId];
                    [self updateEditStateForView];
                }
                else {
                    [self setFatalErrorState:YES withText:NSLocalizedString(@"A problem occurred while trying to retrieve your new seal from the Seal Vault.", nil) withAnimation:YES];
                }
            }
        }];
    } andAutomaticallyMakeActive:NO];
    [self presentViewController:nsvc animated:YES completion:nil];
}

/*
 *  Use the currently-selected seal.
 */
-(IBAction)doUseThisSeal:(id)sender
{
    NSError *err = nil;
    if ([ChatSeal setActiveSeal:sCurActiveSeal withError:&err]) {
        [self completeTheSelectionProcess];
    }
    else {
        NSLog(@"CS:  Failed to assign the active seal from seal selection.   %@", [err localizedDescription]);
        [AlertManager displayFatalAlertWithLowSpaceDetectionUsingTitle:NSLocalizedString(@"Seal Selection Interrupted", nil)
                                                               andText:NSLocalizedString(@"Your %@ was unable to assign a new active seal.", nil)];
    }
}

/*
 *  Toggle editing mode on the table.
 */
-(IBAction)doEdit:(id)sender
{
    [self setActiveSeal:nil];
    BOOL willBeEditing = !tvSeals.editing;
    [tvSeals setEditing:willBeEditing animated:YES];
    [self setNavButtonToEditingInUse:willBeEditing withAnimation:YES];
}

/*
 *  A rotation is about to occur.
 */
-(void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    // - when the vault failure is present, we want to
    //   force a recomputation of the content.
    if ([vfoErrorDisplay isFailureVisible]) {
        [self setFatalErrorState:YES withText:nil withAnimation:YES];
    }
}
@end

/******************************************
 UISealSelectionViewController (internal)
 ******************************************/
@implementation UISealSelectionViewController (internal)
/*
 *  Assign the completion block for the selection task.
 */
-(void) setCompletionBlock:(sealSelectionCompleted)cb
{
    if (completionBlock) {
        Block_release(completionBlock);
        completionBlock = nil;
    }
    
    if (cb) {
        completionBlock = Block_copy(cb);
    }
}

/*
 *  Notify the caller that selection is complete.   Since it is technially possible that 
 *  we could have entered this screen with a seal already selected, we're going to use the
 *  offical value as an indicator.
 */
-(void) completeTheSelectionProcess
{
    BOOL hasActive = NO;
    if ([ChatSeal activeSeal]) {
        hasActive = YES;
    }
    if (completionBlock) {
        completionBlock(hasActive);
    }
}

/*
 *  Display the fatal error text.
 */
-(void) setFatalErrorState:(BOOL) asFatal withText:(NSString *) text withAnimation:(BOOL) animated
{
    // - save the overall state and update the controls that manipulate content.
    inFatalError  = asFatal;
    [self updateEditStateForView];

    // - show/hide the failure display.
    if (asFatal) {
        [vfoErrorDisplay showFailureWithTitle:NSLocalizedString(@"Seals Locked", nil)
                                      andText:text
                                 andAnimation:animated];
    }
    else {
        [vfoErrorDisplay hideFailureWithAnimation:animated];
    }
}

/*
 *  Update the edit state for the view.
 */
-(void) updateEditStateForView
{
    BOOL inUse = tvSeals.editing && [maNewSeals count] > 0 && !inFatalError;
    [self setNavButtonToEditingInUse:inUse withAnimation:YES];
    if (tvSeals.editing && !inUse) {
        tvSeals.editing = NO;
    }
}

/*
 *  When a section value is provided, we need to figure out what
 *  the actual section should be based on the data because we don't 
 *  always show the 'new seals' section to avoid allocating a header region
 *  for it.
 */
-(uissv_sec_type_t) realSectionForLogicalSection:(NSInteger) sec
{
    if (sec == 0) {
        if ([maNewSeals count]) {
            return UISSV_SEC_NEW;
        }
        else {
            return UISSV_SEC_CUR;
        }
    }
    return (uissv_sec_type_t) sec;
}

/*
 *  Assign the active seal.
 */
-(void) setActiveSeal:(NSString *) activeSeal
{
    if (activeSeal != sCurActiveSeal) {
        [sCurActiveSeal release];
        sCurActiveSeal = [activeSeal retain];
    }
    bbiUseThisSeal.enabled = sCurActiveSeal ? YES : NO;
}

/*
 *  Load the current identities.
 */
-(void) loadIdentitiesOrDisplayErrorWithAnimation:(BOOL)animated
{
    NSError *err = nil;
    [maExistingSeals removeAllObjects];
    NSArray *arr = [ChatSeal availableIdentitiesWithError:&err];
    if (arr) {
        for (ChatSealIdentity *psi in arr) {
            if ([psi isOwned]) {
                [maExistingSeals addObject:psi];
            }
        }
        [ChatSealIdentity sortIdentityArrayForDisplay:maExistingSeals];
        [tvSeals reloadData];
        [self setFatalErrorState:NO withText:nil withAnimation:animated];
    }
    else {
        [self setFatalErrorState:YES withText:NSLocalizedString(@"Your Seal Vault cannot be unlocked due to an unexpected problem.", nil) withAnimation:animated];
    }
}

/*
 *  When low space is resolved, determine if we can access content again.
 */
-(void) notifyLowSpaceResolved;
{
    if (inFatalError) {
        [self loadIdentitiesOrDisplayErrorWithAnimation:YES];
    }
}

/*
 *  Change the behavior of this view to switch between message and sharing descriptions.
 */
-(void) setIsMessageSeal:(BOOL) ims
{
    isMessageSeal = ims;
    if (ims) {
        self.navigationItem.prompt = NSLocalizedString(@"Choose a Seal For Your Message", nil);
    }
    else {
        self.navigationItem.prompt = NSLocalizedString(@"Choose a Seal to Share", nil);
    }
}

/*
 *  Change the visual state of the screen to reflect whether editing is in effect for new seals.
 */
-(void) setNavButtonToEditingInUse:(BOOL) inUse withAnimation:(BOOL) animated
{
    BOOL allowEdit = YES;
    if (inFatalError || [maNewSeals count] == 0) {
        allowEdit = NO;
    }
    
    // - change the left item whenever we switch between editing and not editing.
    UIBarButtonItem *bbiLeft = nil;
    if (inUse && allowEdit) {
        bbiLeft = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(doEdit:)] autorelease];
    }
    else {
        bbiLeft = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(doEdit:)] autorelease];
    }

    [bbiLeft setEnabled:allowEdit];
    [self.navigationItem setLeftBarButtonItem:bbiLeft animated:animated];
    self.bbiEdit = bbiLeft;
    
    // - enable/disable the new seal button when editing is flipped.
    [bbiNewSeal setEnabled:!inUse && !inFatalError];
    
    // - do not show the toolbar when editing.
    [self.navigationController setToolbarHidden:inUse animated:animated];
}

/*
 *  A dynamic type update occurred.
 */
-(void) updateDynamicTypeNotificationReceived
{
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        [vfoErrorDisplay updateDynamicTypeNotificationReceived];
    }
}
@end

/**************************************
 UISealSelectionViewController (table)
 **************************************/
@implementation UISealSelectionViewController (table)
/*
 *  Return the number of sections in the view controller.
 */
-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    NSInteger numSections = 0;
    if ([maNewSeals count]) {
        numSections++;
    }
    if ([maExistingSeals count]) {
        numSections++;
    }
    return numSections;
}

/*
 *  Return the number of rows in each section.
 */
-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    uissv_sec_type_t realSec = [self realSectionForLogicalSection:section];
    if (realSec == UISSV_SEC_NEW) {
        return (NSInteger) [maNewSeals count];
    }
    else if (realSec == UISSV_SEC_CUR) {
        return (NSInteger) [maExistingSeals count];
    }
    return 0;
}

/*
 *  Section titles are only used when both sections have content.
 */
-(NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    uissv_sec_type_t realSec = [self realSectionForLogicalSection:section];
    if (realSec == UISSV_SEC_NEW) {
        if ([maNewSeals count]) {
            return NSLocalizedString(@"Just Created", nil);
        }
    }
    else if (realSec == UISSV_SEC_CUR) {
        if ([maExistingSeals count]) {
            return NSLocalizedString(@"Existing", nil);
        }
    }
    return nil;
}

/*
 *  Only permit editing for the new seals.
 */
-(BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self realSectionForLogicalSection:indexPath.section] == UISSV_SEC_NEW &&
        [maNewSeals count]) {
        return YES;
    }
    return NO;
}

/*
 *  Never permit row movemen
 */
-(BOOL) tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

/*
 *  Return the height of a single row.
 */
-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        return UITableViewAutomaticDimension;
    }
    else {
        static CGFloat stdRowHeight = -1.0f;
        if (stdRowHeight < 0.0f) {
            UISealVaultCell *svc = (UISealVaultCell *) [tvSeals dequeueReusableCellWithIdentifier:@"UISealVaultCell"];
            stdRowHeight         = CGRectGetHeight(svc.bounds);
        }
        return stdRowHeight;
    }
}

/*
 *  Return the cell for the given index path.
 */
-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    uissv_sec_type_t realSec = [self realSectionForLogicalSection:indexPath.section];
    ChatSealIdentity *psi = nil;
    if (realSec == UISSV_SEC_NEW) {
        if (indexPath.row < [maNewSeals count]) {
            psi = [maNewSeals objectAtIndex:(NSUInteger) indexPath.row];
        }
    }
    else if (realSec == UISSV_SEC_CUR) {
        if (indexPath.row < [maExistingSeals count]) {
            psi = [maExistingSeals objectAtIndex:(NSUInteger) indexPath.row];
        }
    }
    if (!psi) {
        return nil;
    }
    
    // - configure and return the cell.
    UISealVaultCell *svc = (UISealVaultCell *) [tvSeals dequeueReusableCellWithIdentifier:@"UISealVaultCell" forIndexPath:indexPath];
    [svc setActiveSealDisplayOnSelection:YES];
    if (sCurActiveSeal && [sCurActiveSeal isEqualToString:psi.sealId]) {
        [tvSeals selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
    }
    [svc configureCellWithIdentity:psi andShowDisclosureIndicator:NO];
    svc.selectionStyle = UITableViewCellSelectionStyleNone;
    return svc;
}

/*
 *  When we begin editing, make sure selection is disabled.
 */
-(void) tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSIndexPath *ip = [tvSeals indexPathForSelectedRow];
    if (ip) {
        [tvSeals deselectRowAtIndexPath:ip animated:YES];
    }
    [self setActiveSeal:nil];
}

/*
 *  Manage the deletion of seals we just created.
 */
-(void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    // - only permit deletion of the new cells.
    if (editingStyle != UITableViewCellEditingStyleDelete || [self realSectionForLogicalSection:indexPath.section] != UISSV_SEC_NEW ||
        indexPath.row >= [maNewSeals count]) {
        return;
    }
    
    // - deletion here is actually quite easy because these seals have never been used, so we don't need
    //   any confirmation before deleting them.  They are just an image with the keys and no dependencies.
    
    // ...first make sure the seal is destroyed in the vault.
    ChatSealIdentity *ident = [maNewSeals objectAtIndex:(NSUInteger) indexPath.row];
    NSString *sealId         = [ident sealId];
    NSError *err             = nil;
    if (![ChatSeal deleteSealForId:sealId withError:&err]) {
        NSLog(@"CS:  Failed to delete the seal %@.  %@", sealId, [err localizedDescription]);
        [AlertManager displayFatalAlertWithLowSpaceDetectionUsingTitle:NSLocalizedString(@"Seal Deletion Interrupted", nil)
                                                               andText:NSLocalizedString(@"Your %@ was unable to delete the seal.", nil)];
        return;
    }
    
    // ...now destroy it in the table.
    [maNewSeals removeObjectAtIndex:(NSUInteger) indexPath.row];
    [tvSeals beginUpdates];
    if ([maNewSeals count]) {
        [tvSeals deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    else {
        [tvSeals deleteSections:[NSIndexSet indexSetWithIndex:UISSV_SEC_NEW] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    [tvSeals endUpdates];
    
    // - make sure the edit availability is updated
    [self updateEditStateForView];
}

/*
 *  Prevent highlight changes when we're dragging or decelerating.
 */
-(BOOL) tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([tvSeals shouldPermitHighlight]) {
        [tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
        return YES;
    }
    return NO;
}

/*
 *  Selection has changed.
 */
-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    uissv_sec_type_t realSec = [self realSectionForLogicalSection:indexPath.section];
    if (realSec == UISSV_SEC_NEW) {
        if (indexPath.row < [maNewSeals count]) {
            ChatSealIdentity *psi = [maNewSeals objectAtIndex:(NSUInteger) indexPath.row];
            [self setActiveSeal:psi.sealId];
        }
    }
    else if (realSec == UISSV_SEC_CUR) {
        if (indexPath.row < [maExistingSeals count]) {
            ChatSealIdentity *psi = [maExistingSeals objectAtIndex:(NSUInteger) indexPath.row];
            [self setActiveSeal:psi.sealId];
        }
    }
}

@end

/********************************************
 UISealSelectionViewController (vaultOverlay)
 ********************************************/
@implementation UISealSelectionViewController (vaultOverlay)
/*
 * Attempt to convert the identities over to placeholders.
 */
+(NSArray *) convertIdentityArrayToPlaceholders:(NSArray *) arr
{
    NSMutableArray *maTmpSeals = [NSMutableArray array];
    for (ChatSealIdentity *psi in arr) {
        ChatSealVaultPlaceholder *ph = [ChatSealVaultPlaceholder placeholderForIdentity:psi];
        if (ph.sealColor != RSSC_INVALID) {
            [maTmpSeals addObject:ph];
        }
    }
    if ([maTmpSeals count]) {
        return maTmpSeals;
    }
    return nil;
}

/*
 *  Draw a placeholder.
 */
+(void) drawPlaceholderCell:(UISealVaultCell *) cell withPlaceholder:(ChatSealVaultPlaceholder *) ph atPosition:(CGFloat) yPos
{
    CGContextSaveGState(UIGraphicsGetCurrentContext());
    CGContextTranslateCTM(UIGraphicsGetCurrentContext(), 0.0f, yPos);
    [cell drawStylizedVersionWithPlaceholder:ph];
    CGContextRestoreGState(UIGraphicsGetCurrentContext());
}

/*
 *  Draw an overlay image for this view when a fatal vault error occurs.
 */
+(UIImage *) generateVaultFailurePlaceholderOfSize:(CGSize) szPlaceholder withInsets:(UIEdgeInsets) insets andContext:(NSObject *) ctx
{
    UISealSelectionViewController *ssvcContext = (UISealSelectionViewController *) ctx;
    
    // - first grab the last placeholder content
    NSArray *arrExisting   = [ChatSealVaultPlaceholder vaultSealPlaceholderData];
    NSArray *arrNewSeals   = nil;
    
    // - when there is context, we may use that instead, but since we don't really know whether
    //   it is viable under this failure, we're going to need to examine it.
    // - the backup scenario is to just use the placeholder database.
    if (ssvcContext && ([ssvcContext->maNewSeals count] || [ssvcContext->maExistingSeals count])) {
        if ([ssvcContext->maNewSeals count]) {
            NSArray *maTmpSeals = [UISealSelectionViewController convertIdentityArrayToPlaceholders:ssvcContext->maNewSeals];
            if (maTmpSeals) {
                arrNewSeals = maTmpSeals;
            }
        }

        if ([ssvcContext->maExistingSeals count]) {
            NSArray *maTmpSeals = [UISealSelectionViewController convertIdentityArrayToPlaceholders:ssvcContext->maExistingSeals];
            if (maTmpSeals) {
                arrExisting = maTmpSeals;
            }
        }
    }
    
    // - we can draw now.
    UIGraphicsBeginImageContextWithOptions(szPlaceholder, YES, 0.0f);
    
    // ...first the background
    [[UIVaultFailureOverlayView standardPlaceholderWhiteAlternative] setFill];
    UIRectFill(CGRectMake(0.0f, 0.0f, szPlaceholder.width, szPlaceholder.height));
    
    CGFloat curPos    = insets.top;
    
    // ...get a cell for painting.
    UISealVaultCell *svc = [[[UISealVaultCell alloc] init] autorelease];
    svc.frame            = CGRectMake(0.0f, 0.0f, szPlaceholder.width, [UISealVaultCell standardCellHeight]);
    NSUInteger curItem   = 0;
    
    // ...any new seals if we have them.
    if (ssvcContext && [arrNewSeals count]) {
        CGRect rcToFill = CGRectMake(0.0f, curPos, szPlaceholder.width, UISSC_PH_HDR_VPAD + UISSC_PH_HEADER_HEIGHT);
        [UIVaultFailureOverlayView drawStandardHeaderInRect:rcToFill assumingTextPct:0.15f];
        curPos          = CGRectGetMaxY(rcToFill);
        curItem         = 0;
        while (curItem < [arrNewSeals count] && curPos < szPlaceholder.height) {
            ChatSealVaultPlaceholder *ph = [arrNewSeals objectAtIndex:curItem];
            [UISealSelectionViewController drawPlaceholderCell:svc withPlaceholder:ph atPosition:curPos];
            curPos += [UISealVaultCell standardCellHeight];
            curItem++;
        }
    }
    
    // ...any existing seals.
    if ([arrExisting count] && curPos < szPlaceholder.height) {
        CGRect rcToFill   = CGRectMake(0.0f, curPos, szPlaceholder.width, UISSC_PH_HDR_VPAD + UISSC_PH_HEADER_HEIGHT);
        [UIVaultFailureOverlayView drawStandardHeaderInRect:rcToFill assumingTextPct:0.25f];
        curPos            = CGRectGetMaxY(rcToFill);
        curItem           = 0;
        while (curItem < [arrExisting count] && curPos < szPlaceholder.height) {
            ChatSealVaultPlaceholder *ph = [arrExisting objectAtIndex:curItem];
            [UISealSelectionViewController drawPlaceholderCell:svc withPlaceholder:ph atPosition:curPos];
            curPos += [UISealVaultCell standardCellHeight];
            curItem++;
        }
    }
    
    // ...and fill in the rest of the space with empty cells
    while (curPos < szPlaceholder.height) {
        [UISealSelectionViewController drawPlaceholderCell:svc withPlaceholder:nil atPosition:curPos];
        curPos += [UISealVaultCell standardCellHeight];
    }
    
    UIImage *ret = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return ret;
}

/*
 *  Return an overlay image for the failure overlay.
 */
-(UIImage *) placeholderImageForOverlay:(UIVaultFailureOverlayView *)overlay
{
    return [UISealSelectionViewController generateVaultFailurePlaceholderOfSize:[ChatSeal appWindowDimensions]
                                                                     withInsets:UIEdgeInsetsMake(CGRectGetMaxY(self.navigationController.navigationBar.frame), 0.0f, 0.0f, 0.0f)
                                                                     andContext:self];
}

@end