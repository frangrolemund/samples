//
//  UITwitterFriendAdjustmentViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/24/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UITwitterFriendAdjustmentViewController.h"
#import "ChatSealFeedFriend.h"
#import "CS_tfsFriendshipAdjustment.h"
#import "UITwitterFriendFeedTableViewCell.h"
#import "UITwitterFriendCorrectiveActionTableViewCell.h"
#import "UIFeedGenericHeaderFooter.h"
#import "ChatSeal.h"
#import "AlertManager.h"

// - types
typedef enum {
    UIFAV_SEC_FEED_NAME = 0,
    UIFAV_SEC_ACTION    = 1
    
} uifav_section_t;

// - constants
static const CGFloat UITFAV_STD_FOOTER_PAD = 8.0f;

// - forward declarations
@interface UITwitterFriendAdjustmentViewController (internal)
-(void) doCancelClose;
-(void) notifyDidEnterBackground;
-(NSString *) correctiveText;
-(void) setRightBarButtonItemWithAnimation:(BOOL) animated;
-(void) notifyFriendUpdated;
@end

/****************************************
 UITwitterFriendAdjustmentViewController
 ****************************************/
@implementation UITwitterFriendAdjustmentViewController
/*
 *  Object attributes
 */
{
    ChatSealFeedFriend          *feedFriend;
    CS_tfsFriendshipAdjustment  *feedAdjustment;
    NSString                    *sCorrectiveText;
    BOOL                        isActionStale;
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        feedFriend       = nil;
        feedAdjustment   = nil;
        sCorrectiveText  = nil;
        isActionStale    = NO;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [feedFriend release];
    feedFriend = nil;
    
    [feedAdjustment release];
    feedAdjustment = nil;
    
    [sCorrectiveText release];
    sCorrectiveText = nil;
    
    [super dealloc];
}

/*
 *  Assign the friend and adjustment parameters for this view.
 */
-(void) setFriend:(ChatSealFeedFriend *) ff withAdjustment:(CS_tfsFriendshipAdjustment *) adj
{
    if (ff != feedFriend) {
        [feedFriend release];
        feedFriend = [ff retain];
    }
    
    if (adj != feedAdjustment) {
        [feedAdjustment release];
        feedAdjustment = [adj retain];
    }
    
    [sCorrectiveText release];
    sCorrectiveText = nil;
}

/*
 *  Handle post-load configuration.
 */
-(void) viewDidLoad
{
    [super viewDidLoad];
    
    // - set a title
    self.title = NSLocalizedString(@"Adjust My Feed", nil);
    
    // - add the cancel/close
    [self setRightBarButtonItemWithAnimation:NO];
    
    // - set up the notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyFriendUpdated) name:kChatSealNotifyFriendshipsUpdated object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyFriendUpdated) name:kChatSealNotifyFeedFriendshipUpdated object:nil];
}

/*
 *  The user has requested that we perform the adjustment.
 */
-(IBAction)doAction:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:^(void) {
        NSError *err = nil;
        if (![feedAdjustment applyAdjustmentForFriend:feedFriend.userId withError:&err]) {
            // - record the error at least and let them know that something happened.
            // - DO NOT record friend information here for security purposes.
            NSLog(@"CS: Failed to apply friend adjustment.  %@", [err localizedDescription]);
            [AlertManager displayFatalAlertWithLowSpaceDetectionUsingTitle:NSLocalizedString(@"Adjustment Interrupted", nil) andText:NSLocalizedString(@"ChatSeal encountered an unexpected problem while attempting to improve connections with your friend.", nil)];
        }
    }];
}

/*
 *  Return the number of sections in the table.
 */
-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    if (!isActionStale && feedAdjustment.hasCorrectiveAction) {
        return 2;
    }
    else {
        return 1;
    }
}

/*
 *  Return the header/footer height.
 */
-(CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (section == UIFAV_SEC_FEED_NAME) {
        return [UIFeedGenericHeaderFooter recommendedHeightForText:self.correctiveText andScreenWidth:CGRectGetWidth(self.view.bounds)] + UITFAV_STD_FOOTER_PAD;
    }
    return 0.0f;
}

/*
 *  Return a custom footer for the descriptive text.
 */
-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    if (section == UIFAV_SEC_FEED_NAME) {
        return [[[UIFeedGenericHeaderFooter alloc] initWithText:self.correctiveText
                                                        inColor:(feedAdjustment.isWarning && !isActionStale) ? [ChatSeal defaultWarningColor] : nil
                                                       asHeader:NO] autorelease];
    }
    return nil;
}

/*
 *  Return the number of rows in the table.
 */
-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // - always 1 in each.
    return 1;
}

/*
 *  Return the cell for the given item.
 */
-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == UIFAV_SEC_FEED_NAME) {
        // - the feed address.
        UITwitterFriendFeedTableViewCell *ftvc = (UITwitterFriendFeedTableViewCell *) [tableView dequeueReusableCellWithIdentifier:@"UITwitterFriendFeedTableViewCell"];
        [ftvc.favAddress setAddressText:feedAdjustment.screenName];
        [ftvc.favAddress setTextColor:[UIColor blackColor]];
        return ftvc;
    }
    else if (indexPath.section == UIFAV_SEC_ACTION) {
        // - the corrective action.
        UITwitterFriendCorrectiveActionTableViewCell *catvc = (UITwitterFriendCorrectiveActionTableViewCell *) [tableView dequeueReusableCellWithIdentifier:@"UITwitterFriendCorrectiveActionTableViewCell"];
        [catvc.bCorrectiveAction setTitle:[feedAdjustment correctiveButtonTextForFriend:feedFriend] forState:UIControlStateNormal];
        return catvc;
    }
    
    return nil;
}

/*
 *  No highlighting allowed.
 */
-(BOOL) tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

@end

/***************************************************
 UITwitterFriendAdjustmentViewController (internal)
 ***************************************************/
@implementation UITwitterFriendAdjustmentViewController (internal)
/*
 *  The button on the navigation bar was tapped.
 */
-(void) doCancelClose
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

/*
 *  The app was just backgrounded.
 */
-(void) notifyDidEnterBackground
{
    // - when we enter the background, we have to assume that when the app is restored,
    //   that the work this was expected to perform may have changed.  The best bet is to
    //   force them to go through the friend detail again instead of trying to adapt to what
    //   may be a completely different scenario.  We don't present enough context in this
    //   screen to allow them to make an informed decision if the parameters change.
    [self dismissViewControllerAnimated:YES completion:nil];
}

/*
 *  Return the corrective text that we should display
 */
-(NSString *) correctiveText
{
    // - only compute this once since we use it a lot for footer sizing.
    if (!sCorrectiveText && feedFriend && feedAdjustment && feedFriend.friendNameOrDescription) {
        sCorrectiveText = [[feedAdjustment correctiveTextForFriend:feedFriend] retain];
    }
    return [[sCorrectiveText retain] autorelease];
}


/*
 *  Assign the right bar button item as necessary.
 */
-(void) setRightBarButtonItemWithAnimation:(BOOL) animated
{
    UIBarButtonItem *bbiCancel = nil;
    if (!isActionStale && feedAdjustment.hasCorrectiveAction) {
        bbiCancel = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(doCancelClose)] autorelease];
    }
    else {
        bbiCancel = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doCancelClose)] autorelease];
    }
    [self.navigationItem setRightBarButtonItem:bbiCancel animated:animated];
}

/*
 *  Any updates of my friend information should force us to rethink what we're doing here.
 *  - this will detect both the routine update and the realtime update of a single item.
 */
-(void) notifyFriendUpdated
{
    // - don't worry about these if we've already disabled the screen.
    if (isActionStale) {
        return;
    }
    
    CS_tfsFriendshipAdjustment *newAdj = [feedAdjustment highestPriorityAdjustmentForFriend:feedFriend];
    if (newAdj && ![feedAdjustment recommendsTheSameAdjustmentAs:newAdj]) {
        [feedAdjustment release];
        feedAdjustment = [newAdj retain];
        
        // - animate the transition so that we can just do a simple table reload.
        UIView *vwSnap = [self.tableView snapshotViewAfterScreenUpdates:YES];
        vwSnap.frame   = self.tableView.frame;
        [self.tableView.superview addSubview:vwSnap];
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            vwSnap.alpha = 0.0f;
        }completion:^(BOOL finished) {
            [vwSnap removeFromSuperview];
        }];
        
        // - give the person something to indicate that we know that an update has occurred.
        // - I gave some long thought to this and decided that it is not appropriate to change the
        //   type of action screen this represents from here because all context is lost for the user.
        //   When this happens, we must mark the screen as stale and force them back to the former one.
        [sCorrectiveText release];
        NSString *sFmt       = NSLocalizedString(@"Your friendship with %@ has been updated.", nil);
        sCorrectiveText      = [[NSString stringWithFormat:sFmt, [newAdj descriptiveNameForFeedFriend:feedFriend]] retain];
        isActionStale        = YES;
        
        [self setRightBarButtonItemWithAnimation:YES];
        [self.tableView reloadData];
    }
}
@end

