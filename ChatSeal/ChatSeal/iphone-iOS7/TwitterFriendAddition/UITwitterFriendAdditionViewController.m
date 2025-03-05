//
//  UITwitterFriendAdditionViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/29/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UITwitterFriendAdditionViewController.h"
#import "UIFeedGenericHeaderFooter.h"
#import "UITwitterFriendAddTableViewCell.h"
#import "UITwitterFriendAddButtonTableViewCell.h"
#import "ChatSealFeedCollector.h"
#import "CS_feedTypeTwitter.h"
#import "CS_twitterFeed.h"
#import "UITwitterFriendStatusHeaderView.h"
#import "ChatSeal.h"
#import "AlertManager.h"
#import "UITableViewWithSizeableCells.h"

//  - forward declarations.
@interface UITwitterFriendAdditionViewController (internal) <UITwitterFriendAddTableViewCellDelegate, UITwitterFriendAddButtonTableViewCellDelegate, UIActionSheetDelegate>
-(NSString *) footerHint;
-(void) commonConfiguration;
-(void) doCancel;
-(void) manageEnablementOfButton:(UITwitterFriendAddButtonTableViewCell *) cell;
-(UITwitterFriendAddButtonTableViewCell *) addButtonCell;
-(UITwitterFriendAddTableViewCell *) nameCell;
-(BOOL) isCurrentFriendAllowedAndSetStatus:(BOOL) setStatus;
-(void) beginFriendProcessing;
-(CS_twitterFeed *) bestFeedForValidation;
-(void) completeFriendAdditionWithUserInfo:(CS_tapi_user_looked_up *) userInfo;
@end

@interface UITwitterFriendAdditionViewController (table) <UITableViewDataSource, UITableViewDelegate>
@end

/**************************************
 UITwitterFriendAdditionViewController
 **************************************/
@implementation UITwitterFriendAdditionViewController
/*
 *  Object attributes.
 */
{
    UITableViewWithSizeableCells    *tvFriend;
    NSString                        *screenName;
    UITwitterFriendStatusHeaderView *shStatus;
    BOOL                            isBeingValidated;
    BOOL                            hasStartedEntering;
    BOOL                            updatedNameCell;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        [self commonConfiguration];
    }
    return self;
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
    [tvFriend release];
    tvFriend = nil;
    
    [screenName release];
    screenName = nil;
    
    [shStatus release];
    shStatus = nil;
    
    [super dealloc];
}

/*
 *  The view has been loaded.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // - configure the content in this view.
    self.view.backgroundColor = [UIColor whiteColor];
    
    tvFriend                     = [[UITableViewWithSizeableCells alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    tvFriend.autoresizingMask    = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    tvFriend.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    tvFriend.dataSource          = self;
    tvFriend.delegate            = self;
    [self.view addSubview:tvFriend];
}
@end

/************************************************
 UITwitterFriendAdditionViewController (internal)
 ************************************************/
@implementation UITwitterFriendAdditionViewController (internal)
/*
 *  Configure during initialization.
 */
-(void) commonConfiguration
{
    tvFriend                               = nil;
    screenName                             = nil;
    shStatus                               = nil;
    isBeingValidated                       = NO;
    hasStartedEntering                     = NO;
    updatedNameCell                        = NO;
    
    self.title                             = NSLocalizedString(@"Twitter Friend", nil);
    UIBarButtonItem *bbiCancel             = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(doCancel)] autorelease];
    self.navigationItem.rightBarButtonItem = bbiCancel;
}

/*
 *  Return the text for the footer of the friend cell.
 */
-(NSString *) footerHint
{
    return NSLocalizedString(@"ChatSeal can watch your friend's Twitter feed for personal messages and ensure their content remains accessible to you.", nil);
}

/*
 *  Cancel this addition.
 */
-(void) doCancel
{
    // - cancel any high priority tasks we started.
    for (CS_twitterFeed *tf in [self.feedType feeds]) {
        [tf cancelHighPriorityValidationForFriend:screenName];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

/*
 *  The text in the add table cell has been modified.
 */
-(void) twitterFriendAddTextChanged:(UITwitterFriendAddTableViewCell *)tvc toValue:(NSString *)text
{
    [screenName release];
    screenName = [text retain];
    
    // - we're not going to show the button until they start typing text.
    BOOL shouldLoadButton = NO;
    if (!hasStartedEntering) {
        shouldLoadButton   = YES;
        hasStartedEntering = YES;
    }
    
    // - with the very first character, we'll include the button from now on, but presumably the person
    //   now understands what the intent is here without being distracted.
    if (shouldLoadButton) {
        [tvFriend beginUpdates];
        [tvFriend insertSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
        [tvFriend endUpdates];
    }
    else {
        [self manageEnablementOfButton:[self addButtonCell]];
    }
}

/*
 *  Allows us to either allow or deny returning.
 */
-(BOOL) twitterFriendAddReturnRequested:(UITwitterFriendAddTableViewCell *)tvc
{
    if (![self isCurrentFriendAllowedAndSetStatus:NO]) {
        return NO;
    }
    
    // - assume we're going to try to use this guy.
    [self beginFriendProcessing];
    
    return YES;
}

/*
 *  Button was pressed.
 */
-(void) twitterFriendAddButtonPressed:(UITwitterFriendAddButtonTableViewCell *)cell
{
    [[self nameCell] resignFirstResponder];
    [self beginFriendProcessing];
}

/*
 *  Enable/disable the button based on the content.
 */
-(void) manageEnablementOfButton:(UITwitterFriendAddButtonTableViewCell *) cell
{
    [cell setEnabled:[self isCurrentFriendAllowedAndSetStatus:YES]];
}

/*
 *  Return the view for the add button.
 */
-(UITwitterFriendAddButtonTableViewCell *) addButtonCell
{
    UITableViewCell *tvc = [tvFriend cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1]];
    if (tvc && [tvc isKindOfClass:[UITwitterFriendAddButtonTableViewCell class]]) {
        return (UITwitterFriendAddButtonTableViewCell *) tvc;
    }
    return nil;
}

/*
 *  Return the cell with the friend's name.
 */
-(UITwitterFriendAddTableViewCell *) nameCell
{
    UITableViewCell *tvc = [tvFriend cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    if (tvc && [tvc isKindOfClass:[UITwitterFriendAddTableViewCell class]]) {
        return (UITwitterFriendAddTableViewCell *) tvc;
    }
    return nil;
}

/*
 *  Check if the friend we've defined is allowed for processing.
 */
-(BOOL) isCurrentFriendAllowedAndSetStatus:(BOOL)setStatus
{
    BOOL isAllowed      = NO;
    BOOL statusAssigned = NO;
    if ([screenName length]) {
        NSArray *arrFeeds = [self.feedType feeds];
        isAllowed = YES;
        
        NSString *lcScreenName = [screenName lowercaseString];
        
        // - check for local feeds.
        for (CS_twitterFeed *feed in arrFeeds) {
            if ([[feed.userId lowercaseString] isEqualToString:lcScreenName]) {
                isAllowed = NO;
                if (setStatus) {
                    [shStatus setStatusText:NSLocalizedString(@"My feed name.", nil) inColor:[ChatSeal defaultWarningColor]];
                    statusAssigned = YES;
                }
                break;
            }
        }
        
        // - or existing friends?
        if (isAllowed) {
            isAllowed = ![(CS_feedTypeTwitter *) self.feedType isTrackingFriendByName:lcScreenName];
            if (!isAllowed) {
                if (setStatus) {
                    [shStatus setStatusText:NSLocalizedString(@"Friend already exists.", nil) inColor:[ChatSeal defaultWarningColor]];
                    statusAssigned = YES;
                }
            }
        }
    }
    
    // - if we didn't set status here, then fade out.
    if (!statusAssigned && setStatus) {
        [shStatus setStatusText:nil inColor:nil];
    }
    
    return isAllowed;
}

/*
 *  We've passed the first stage of validation, now either add it or validate a bit more.
 */
-(void) beginFriendProcessing
{
    if (!screenName) {
        return;
    }
    
    // - prevent any further attempts while we're doing our work.
    [[self nameCell] setEnabled:NO];
    [[self addButtonCell] setEnabled:NO];
    
    // - now check for a way that we can validate this friend.  If none exists, we'll just allow the friend to be added because the
    //   friend list is only used .
    CS_twitterFeed *tfValidate = [self bestFeedForValidation];
    if (!tfValidate) {
        [self completeFriendAdditionWithUserInfo:nil];
        return;
    }
    
    // - if we have a feed, we'll try to validate the friend just to prevent cruft from building up if they make a typo, for instance.
    [shStatus setStatusText:NSLocalizedString(@"Validating your friend.", nil) inColor:[UIColor darkGrayColor]];
    [shStatus startAnimating];
    
    // - now schedule a check.
    [tfValidate requestHighPriorityValidationForFriend:screenName withCompletion:^(CS_tapi_user_looked_up *result) {
        // - once this completes, we don't want to do anything if it was cancelled.
        if (self.parentViewController) {
            if (result) {
                [self completeFriendAdditionWithUserInfo:result];
            }
            else {
                [shStatus setStatusText:NSLocalizedString(@"Twitter user does not exist.", nil) inColor:[ChatSeal defaultWarningColor]];
                [shStatus stopAnimating];
                [[self nameCell] setEnabled:YES];
                [[self nameCell] becomeFirstResponder];
            }
        }
    }];
}

/*
 *  Return a feed we can use to validate a friend.
 */
-(CS_twitterFeed *) bestFeedForValidation
{
    for (CS_twitterFeed *tf in [self.feedType feeds]) {
        // - we're going to use the lookup API here so just check for it.
        if ([tf isLikelyToScheduleAPIByName:@"CS_tapi_users_lookup" withEventDistribution:NO]) {
            return tf;
        }
    }
    return nil;
}

/*
 *  Dismiss this view and add the new friend.
 */
-(void) completeFriendAdditionWithUserInfo:(CS_tapi_user_looked_up *) userInfo
{
    // - track the friend before we dismiss so the presenting view controller can start preparing to show it.
    [(CS_feedTypeTwitter *) self.feedType trackUnprovenFriendByName:screenName andInitializeWith:userInfo];
    
    // - dismiss the view controller.
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end

/**********************************************
 UITwitterFriendAdditionViewController (table)
 **********************************************/
@implementation UITwitterFriendAdditionViewController (table)
/*
 *  Return the number of sections in the table view.
 */
-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    // - we're not going to show the second row in the table until
    //   they begin typing so that the intent of this screen is clear.  The
    //   button row tends to distract you from what you need to do.
    if (hasStartedEntering) {
        return 2;
    }
    else {
        return 1;
    }
}

/*
 *  Return the number of rows in each section.
 */
-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

/*
 *  Return a cell for the given  row.
 */
-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        UITwitterFriendAddTableViewCell *tfac = [[[UITwitterFriendAddTableViewCell alloc] init] autorelease];
        if (screenName.length) {
            [tfac setScreenName:screenName];
            updatedNameCell                   = YES;
        }
        tfac.delegate                         = self;
        return tfac;
    }
    else if (indexPath.section == 1) {
        UITwitterFriendAddButtonTableViewCell *tbac = [[[UITwitterFriendAddButtonTableViewCell alloc] init] autorelease];
        tbac.delegate                               = self;
        [self manageEnablementOfButton:tbac];
        return tbac;
    }
    return nil;
}

/*
 *  Return the height of the given header.
 */
-(CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == 0) {
        return [UITwitterFriendStatusHeaderView headerHeight];
    }
    return 0.0f;
}

/*
 *  Return the header for the given section.
 */
-(UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == 0) {
        [shStatus release];
        shStatus = [[UITwitterFriendStatusHeaderView alloc] init];
        if (updatedNameCell) {
            updatedNameCell = NO;
            [self isCurrentFriendAllowedAndSetStatus:YES];
        }
        return shStatus;
    }
    return nil;
}

/*
 *  The given header is about to be discarded.
 */
-(void) tableView:(UITableView *)tableView didEndDisplayingHeaderView:(UIView *)view forSection:(NSInteger)section
{
    if (view == shStatus) {
        [shStatus release];
        shStatus = nil;
    }
}

/*
 *  Return the height of the footer in the given section.
 */
-(CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (section == 0) {
        return [UIFeedGenericHeaderFooter recommendedHeightForText:[self footerHint] andScreenWidth:CGRectGetWidth(self.view.frame)];
    }
    return 0.0f;
}

/*
 *  Return the custom view for the footer.
 */
-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    if (section == 0) {
        return [[[UIFeedGenericHeaderFooter alloc] initWithText:[self footerHint] inColor:nil asHeader:NO] autorelease];
    }
    return nil;
}
@end
