//
//  UISealExpirationViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/15/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealExpirationViewController.h"
#import "ChatSeal.h"
#import "AlertManager.h"
#import "UISealExpirationCell.h"
#import "UITableViewWithSizeableCells.h"
#import "UIGenericSizableTableViewCell.h"
#import "UIGenericSizableTableViewHeader.h"

// - constants
struct expire_def {
    int         days;
    NSString    *desc;
};
static const struct expire_def expiration_options[] = {{1,   @"1 day"},
                                                       {3,   @"3 days"},
                                                       {7,   @"One week"},
                                                       {30,  @"One month"},
                                                       {90,  @"Three months"},
                                                       {180, @"Six months"},
                                                       {365, @"One year"}};
static const NSUInteger NUM_EXPIRE_OPTS = sizeof(expiration_options)/sizeof(expiration_options[0]);

// - forward declarations
@interface UISealExpirationViewController (internal)
-(void) commonConfiguration;
-(void) rebuildHeaderForCurrentWidth;
@end

/*******************************
 UISealExpirationViewController
 *******************************/
@implementation UISealExpirationViewController
/*
 *  Object attributes.
 */
{
    ChatSealIdentity *sealIdentity;
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
 *  Configure the view.
 */
-(void) viewDidLoad
{
    [super viewDidLoad];
    [self rebuildHeaderForCurrentWidth];
}

/*
 *  When rotating, we want the header to match the new dimensions.
 */
-(void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self rebuildHeaderForCurrentWidth];
}

/*
 *  Assign the identity to this view.
 */
-(void) setIdentity:(ChatSealIdentity *) psi
{
    if (sealIdentity != psi) {
        [sealIdentity release];
        sealIdentity = [psi retain];
    }
}

@end

/*****************************************
 UISealExpirationViewController (internal)
 *****************************************/
@implementation UISealExpirationViewController (internal)
/*
 *  Initial configuration.
 */
-(void) commonConfiguration
{
    self.title = NSLocalizedString(@"Self-Destruct", nil);
}

/*
 *  Rebuild the header because the table needs to readjust based on rotation.
 */
-(void) rebuildHeaderForCurrentWidth
{
    UIView *vwHeader               = [[[UIGenericSizableTableViewHeader alloc] initWithText:NSLocalizedString(@"Your friends must receive new messages at least this often in order to avoid being locked out of all past and future exchanges.", nil)] autorelease];
    CGSize sz                      = [vwHeader sizeThatFits:CGSizeMake(CGRectGetWidth(self.view.bounds), 1.0f)];
    vwHeader.frame                 = CGRectMake(0.0f, 0.0f, sz.width, sz.height);
    self.tableView.tableHeaderView = vwHeader;
}

/*
 *  The number of sections in the view.
 */
-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

/*
 *  The number of rows in the view.
 */
-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return NUM_EXPIRE_OPTS;
    }
    return 0;
}

/*
 *  We need to hook the retrieval of the static fields in order to check them as they appear.
 */
-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        // - these cells must be dynamically generated so that we can better control how dynamic (different use of dynamic)
        //   text sizing works.
        UISealExpirationCell *sec = (UISealExpirationCell *) [tableView dequeueReusableCellWithIdentifier:@"UISealExpirationCell" forIndexPath:indexPath];
        if (indexPath.row < NUM_EXPIRE_OPTS) {
            sec.lExpirationText.text = NSLocalizedString(expiration_options[indexPath.row].desc, nil);
            sec.tag                  = expiration_options[indexPath.row].days;
        }
        sec.selectionStyle   = UITableViewCellSelectionStyleNone;
        NSUInteger expires = [sealIdentity sealExpirationTimoutInDaysWithError:nil];
        if (sec.tag == expires) {
            sec.accessoryType = UITableViewCellAccessoryCheckmark;
        }
        else {
            sec.accessoryType = UITableViewCellAccessoryNone;
        }
        return sec;
    }
    return nil;
}

/*
 *  Handle selection of the rows.
 */
-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *tvc = [tableView cellForRowAtIndexPath:indexPath];
    if (tvc.accessoryType == UITableViewCellAccessoryCheckmark) {
        return;
    }
    
    // - attempt to update the current value.
    NSError *err = nil;
    if (![sealIdentity setExpirationTimeoutInDays:(NSUInteger) tvc.tag withError:&err]) {
        NSLog(@"CS:  Failed to update the expiration for seal %@.  %@", sealIdentity.safeSealId, [err localizedDescription]);
        [AlertManager displayFatalAlertWithLowSpaceDetectionUsingTitle:NSLocalizedString(@"Seal Update Interrupted", nil)
                                                               andText:NSLocalizedString(@"Your %@ was unable to change the expiration time on the seal because of an unexpected problem.", nil)];
        return;
    }
    
    // - update all the visible cells with the new checkmark.
    for (UITableViewCell *tvcCur in tableView.visibleCells) {
        if (tvcCur.tag == tvc.tag) {
            tvcCur.accessoryType = UITableViewCellAccessoryCheckmark;
        }
        else {
            tvcCur.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    
    // - add a note to the navigation bar to let them know how this will be propagated.
    [ChatSealMessage discardSealedMessageCache];
    self.navigationItem.prompt = NSLocalizedString(@"Your friends will be updated.", nil);
}
@end