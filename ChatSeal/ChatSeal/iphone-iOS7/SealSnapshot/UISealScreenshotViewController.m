//
//  UISealSnapshotViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/16/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealScreenshotViewController.h"
#import "ChatSeal.h"
#import "AlertManager.h"
#import "UIGenericSizableTableViewHeader.h"

// -  forward declarations
@interface UISealScreenshotViewController (internal)
-(void) commonConfiguration;
-(void) rebuildHeaderForCurrentWidth;
-(void) assignCurrentScreenshotFlagWithAnimation:(BOOL) animated;
@end

/****************************
 UISealScreenshotViewController
 ****************************/
@implementation UISealScreenshotViewController
/*
 *  Object attributes
 */
{
    ChatSealIdentity *sealIdentity;
}
@synthesize swScreenshot;

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
    
    [swScreenshot release];
    swScreenshot = nil;
    
    [super dealloc];
}

/*
 *  Configure the object.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    [self rebuildHeaderForCurrentWidth];
    [self assignCurrentScreenshotFlagWithAnimation:NO];
}

/*
 *  Assign the identity to this view.
 */
-(void) setIdentity:(ChatSealIdentity *) psi
{
    if (sealIdentity != psi) {
        [sealIdentity release];
        sealIdentity = [psi retain];
        [self assignCurrentScreenshotFlagWithAnimation:NO];
    }
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
 *  The screenshot switch was modified.
 */
-(IBAction)doScreenshotChange
{
    // - attempt to update the current value.
    NSError *err = nil;
    if (![sealIdentity setRevokeOnScreenshotEnabled:swScreenshot.on withError:&err]) {
        NSLog(@"CS:  Failed to update the expiration for seal %@.  %@", sealIdentity.safeSealId, [err localizedDescription]);
        [AlertManager displayFatalAlertWithLowSpaceDetectionUsingTitle:NSLocalizedString(@"Seal Update Interrupted", nil)
                                                               andText:NSLocalizedString(@"Your %@ was unable to change the screenshot detection on the seal because of an unexpected problem.", nil)];
        [self assignCurrentScreenshotFlagWithAnimation:YES];
        return;
    }
    
    // - add a note to the navigation bar to let them know how this will be propagated.
    [ChatSealMessage discardSealedMessageCache];
    self.navigationItem.prompt = NSLocalizedString(@"Your friends will be updated.", nil);
}

@end

/****************************************
 UISealScreenshotViewController (internal)
 ****************************************/
@implementation UISealScreenshotViewController (internal)
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
    UIView *vwHeader               = [[[UIGenericSizableTableViewHeader alloc] initWithText:NSLocalizedString(@"Anyone who takes a screenshot of your messages can be automatically locked out of all past and future exchanges.", nil)] autorelease];
    CGSize sz                      = [vwHeader sizeThatFits:CGSizeMake(CGRectGetWidth(self.view.bounds), 1.0f)];
    vwHeader.frame                 = CGRectMake(0.0f, 0.0f, sz.width, sz.height);
    self.tableView.tableHeaderView = vwHeader;
}

/*
 *  Assign the flag used for screenshot detection.
 */
-(void) assignCurrentScreenshotFlagWithAnimation:(BOOL) animated
{
    NSError *err = nil;
    BOOL isOn    = [sealIdentity isRevocationOnScreenshotEnabledWithError:&err];
    if (!isOn && err) {
        NSLog(@"CS:  Failed to query the screenshot flag for seal %@.  %@", [sealIdentity safeSealId], [err localizedDescription]);
    }
    [swScreenshot setOn:isOn animated:animated];
}

/*
 *  Don't allow highlighting of these rows.
 */
-(BOOL) tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}
@end
