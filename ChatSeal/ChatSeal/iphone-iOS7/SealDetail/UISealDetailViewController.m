//
//  UISealDetailViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/13/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealDetailViewController.h"
#import "ChatSeal.h"
#import "UISealDetailNameCell.h"
#import "UISealDetailActiveCell.h"
#import "UISealDetailInactiveCell.h"
#import "UISealExpirationViewController.h"
#import "UISealDetailScreenshotCell.h"
#import "UISealScreenshotViewController.h"
#import "UISealAboutViewController.h"
#import "UISealExchangeController.h"
#import "UIMessageDetailViewControllerV2.h"
#import "UIChatSealNavigationController.h"

// - types
typedef enum {
    UISVC_SEC_IDENTITY = 0,
    UISVC_SEC_REVOKE   = 1,
    UISVC_SEC_ABOUT    = 2,
    
    UISVC_SEC_COUNT
} uisdv_section_t;

typedef enum {
    UISVC_REV_SENDMSG = 0,
    UISVC_REV_EXPIRE  = 1,
    UISVC_REV_SCREEN  = 2,
} uisdv_revocation_t;

// - forward declarations
@interface UISealDetailViewController (internal) <UIMessageDetailViewControllerV2Delegate>
-(void) commonConfiguration;
-(void) doShareThisSeal;
-(NSIndexPath *) normalizedIndexPathFromIndexPath:(NSIndexPath *) ip;
-(BOOL) isActionableExpirationWarningVisible;
-(void) doSendADelayMessage;
-(void) resignNameFieldIfNecessary;
@end

// - table-related methods.
@interface UISealDetailViewController (table) <UISealDetailActiveCellDelegate>
@end

/***************************
 UISealDetailViewController
 ***************************/
@implementation UISealDetailViewController
/*
 *  Object attributes.
 */
{
    ChatSealIdentity *sealIdentity;
    BOOL              hasAppeared;
    BOOL              hasExpirationWarning;
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
    [sealIdentity release];
    sealIdentity = nil;
        
    [super dealloc];
}

/*
 *  Assign the identity to be managed.
 */
-(void) setIdentity:(ChatSealIdentity *) psi
{
    if (sealIdentity != psi) {
        [sealIdentity release];
        sealIdentity         = [psi retain];
        hasExpirationWarning = [self isActionableExpirationWarningVisible];
    }
}

/*
 *  When returning to this view from a detail sub-view, make sure
 *  that all the cells that could be modified are updated with current information.
 */
-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // - only do this when returning to this view.
    if (hasAppeared) {
        hasExpirationWarning = [self isActionableExpirationWarningVisible];
        [self.tableView reloadData];
    }
}

/*
 *  The view has appeared.
 */
-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    hasAppeared = YES;
}
@end

/*************************************
 UISealDetailViewController (internal)
 *************************************/
@implementation UISealDetailViewController (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    // - basic attributes.
    hasAppeared          = NO;
    hasExpirationWarning = NO;
    
    // - view configuration
    self.title                             = NSLocalizedString(@"My Seal", nil);
    UIBarButtonItem *bbiShare              = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Share", nil)
                                                                            style:UIBarButtonItemStylePlain target:self action:@selector(doShareThisSeal)];
    self.navigationItem.rightBarButtonItem = bbiShare;
    [bbiShare release];
    self.clearsSelectionOnViewWillAppear = YES;
}

/*
 *  Share this seal
 */
-(void) doShareThisSeal
{
    UIViewController *vc = [UISealExchangeController modalSealShareViewControllerForIdentity:sealIdentity withCompletion:^(BOOL hasExchangedASeal) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
    [self presentViewController:vc animated:YES completion:nil];
}

/*
 *  The original index paths in this object should be converted into normalized values
 *  to make it easier to deal with the changing revocation section.
 */
-(NSIndexPath *) normalizedIndexPathFromIndexPath:(NSIndexPath *) ip
{
    if (ip.section == UISVC_SEC_REVOKE) {
        if (hasExpirationWarning) {
            return ip;
        }
        else {
            if (ip.row == 0) {
                return [NSIndexPath indexPathForRow:UISVC_REV_EXPIRE inSection:UISVC_SEC_REVOKE];
            }
            else if (ip.row == 1) {
                return [NSIndexPath indexPathForRow:UISVC_REV_SCREEN inSection:UISVC_SEC_REVOKE];
            }
            else {
                return ip;
            }
        }
    }
    else {
        return ip;
    }
}

/*
 *  An actionable warning is one that we can actually deal with.  If the seal is already expired,
 *  there is nothing that can be done and it will need to be re-shared.
 */
-(BOOL) isActionableExpirationWarningVisible
{
    // - it isn't just the presence of the warning text, but the fact that
    //   the seal isn't already expired, which would be a problem.
    if ([sealIdentity isExpirationWarningVisible] &&
        [sealIdentity.nextExpirationDate compare:[NSDate date]] == NSOrderedDescending) {
        return YES;
    }
    return NO;
}

/*
 *  Write a message that will be used to delay the expiration of the active seal.
 */
-(void) doSendADelayMessage
{
    // - don't allow it to be pressed immediately upon return.
    if (!hasExpirationWarning) {
        return;
    }
    
    UIMessageDetailViewControllerV2 *mdvc = nil;
    ChatSealMessage *psm                 = [ChatSeal bestMessageForSeal:sealIdentity.sealId andAuthor:[ChatSeal ownerNameForSeal:sealIdentity.sealId]];
    if (psm) {
        mdvc = [[UIMessageDetailViewControllerV2 alloc] initWithExistingMessage:psm andForceAppend:YES];
    }
    else {
        mdvc = [[UIMessageDetailViewControllerV2 alloc] initWithSeal:sealIdentity.sealId];
    }
    mdvc.delegate = self;
    UINavigationController *nc            = [UIChatSealNavigationController instantantiateNavigationControllerWithRoot:mdvc];
    [mdvc release];
    nc.modalTransitionStyle               = UIModalPresentationFullScreen;
    [self presentViewController:nc animated:YES completion:nil];
}

/*
 *  We sent an expiration update so we should be able to remove that button.
 */
-(void) messageDetail:(UIMessageDetailViewControllerV2 *)md didCompleteWithMessage:(ChatSealMessage *)message
{
    [self dismissViewControllerAnimated:YES completion:nil];
    
    // - we're going to treat this as an imported message because it has the special distinction of
    //   being created outside the overview navigation path, which is generally the case with imports.
    [ChatSeal notifyMessageImportedWithId:message.messageId andEntry:nil];
}

/*
 *  Dismiss the new message screen, but do not remove the button because it was cancelled.
 */
-(void) messageDetailShouldCancel:(UIMessageDetailViewControllerV2 *)md
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

/*
 *  Resign the name field when things are changed/selected elsewhere.
 */
-(void) resignNameFieldIfNecessary
{
    UISealDetailNameCell *nc = (UISealDetailNameCell *) [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:UISVC_SEC_IDENTITY]];
    if (nc && nc.tfName.isFirstResponder) {
        [nc.tfName resignFirstResponder];
    }
}
@end

/***********************************
 UISealDetailViewController (table)
 ***********************************/
@implementation UISealDetailViewController (table)

/*
 *  Return the number of sections in this screen.
 */
-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return UISVC_SEC_COUNT;
}

/*
 *  Return the number of rows per section
 */
-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case UISVC_SEC_IDENTITY:
            return 2;
            break;
            
        case UISVC_SEC_REVOKE:
            if (hasExpirationWarning) {
                return 3;
            }
            else {
                return 2;
            }
            break;
            
        case UISVC_SEC_ABOUT:
            return 1;
            break;
            
        default:
            return 0;
            break;
    }
}

/*
 *  Return the cell at the given path.
 */
-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *tvcRet = nil;
    NSIndexPath     *ipNorm = nil;
    switch (indexPath.section) {
        case UISVC_SEC_IDENTITY:
            if (indexPath.row == 0) {
                tvcRet = [tableView dequeueReusableCellWithIdentifier:@"UISealDetailNameCell"];
                [(UISealDetailNameCell *) tvcRet setIdentity:sealIdentity];
            }
            else {
                tvcRet = [tableView dequeueReusableCellWithIdentifier:@"UISealDetailActiveCell"];
                ((UISealDetailActiveCell *) tvcRet).delegate = self;
                [(UISealDetailActiveCell *) tvcRet setIdentity:sealIdentity];
            }
            break;
            
        case UISVC_SEC_REVOKE:
            //  - NOTE:  I've thought that a reasonable additional option could be 'With a Surprise Message', essentially allowing
            //    a revocation message to be sent, but decided against it in the first release to allow me to refine the core set
            //    of features I decided to develop.
            ipNorm = [self normalizedIndexPathFromIndexPath:indexPath];
            switch (ipNorm.row) {
                case UISVC_REV_SENDMSG:
                    tvcRet = [tableView dequeueReusableCellWithIdentifier:@"UISealDetailStopExpireCell"];
                    break;
                    
                case UISVC_REV_EXPIRE:
                    tvcRet = [tableView dequeueReusableCellWithIdentifier:@"UISealDetailInactiveCell"];
                    [(UISealDetailInactiveCell *) tvcRet setIdentity:sealIdentity];
                    break;
                    
                case UISVC_REV_SCREEN:
                    tvcRet = [tableView dequeueReusableCellWithIdentifier:@"UISealDetailScreenshotCell"];
                    [(UISealDetailScreenshotCell *) tvcRet setIdentity:sealIdentity];
                    break;                    
            }
            break;
            
        case UISVC_SEC_ABOUT:
            tvcRet = [tableView dequeueReusableCellWithIdentifier:@"UISealDetailAboutCell"];
            break;
            
        default:
            tvcRet = nil;
            break;
    }
    
    // - return the configured cell.
    return tvcRet;
}

/*
 *  Return the appropriate header title.
 */
-(NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case UISVC_SEC_IDENTITY:
            return NSLocalizedString(@"Identity", nil);
            break;
            
        case UISVC_SEC_REVOKE:
            return NSLocalizedString(@"Self-Destruct", nil);
            break;
            
        case UISVC_SEC_ABOUT:
            return NSLocalizedString(@"Details", nil);
            break;
    }
    return nil;
}

/*
 *  Controls whether highlighting is possible at given cells.
 */
-(BOOL) tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == UISVC_SEC_IDENTITY) {
        return NO;
    }
    return YES;
}

/*
 *  When the active state changes on the seal, make sure the name is synchronized.
 */
-(void) activeCellModifiedActivity:(UISealDetailActiveCell *)cell
{
    UISealDetailNameCell *nc = (UISealDetailNameCell *) [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:UISVC_SEC_IDENTITY]];
    [nc updateNameForActivityState];
    [self resignNameFieldIfNecessary];
}

/*
 *   When a row is selected, we need to possibly go to a detail view for additional choices.
 */
-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSIndexPath *ipNorm = [self normalizedIndexPathFromIndexPath:indexPath];
    
    // - resign first responder if we changed cells
    if (ipNorm.section != UISVC_SEC_IDENTITY) {
        [self resignNameFieldIfNecessary];
    }
    
    // - send a message to prevent expiration
    if (ipNorm.section == UISVC_SEC_REVOKE && ipNorm.row == UISVC_REV_SENDMSG) {
        [self doSendADelayMessage];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    // - seal expiration by timeout
    if (ipNorm.section == UISVC_SEC_REVOKE && ipNorm.row == UISVC_REV_EXPIRE) {
        UISealExpirationViewController *sevc = (UISealExpirationViewController *) [ChatSeal viewControllerForStoryboardId:@"UISealExpirationViewController"];
        [sevc setIdentity:sealIdentity];
        [self.navigationController pushViewController:sevc animated:YES];
        return;
    }
    
    // - screenshot protection
    if (ipNorm.section == UISVC_SEC_REVOKE && ipNorm.row == UISVC_REV_SCREEN) {
        UISealScreenshotViewController *ssvc = (UISealScreenshotViewController *) [ChatSeal viewControllerForStoryboardId:@"UISealScreenshotViewController"];
        [ssvc setIdentity:sealIdentity];
        [self.navigationController pushViewController:ssvc animated:YES];
        return;
    }
    
    //  - about
    if (ipNorm.section == UISVC_SEC_ABOUT) {
        UISealAboutViewController *savc = (UISealAboutViewController *) [ChatSeal viewControllerForStoryboardId:@"UISealAboutViewController"];
        [savc setIdentity:sealIdentity];
        [self.navigationController pushViewController:savc animated:YES];
        return;
    }
}
@end