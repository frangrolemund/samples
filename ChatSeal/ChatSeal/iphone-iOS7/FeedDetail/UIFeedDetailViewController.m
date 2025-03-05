//
//  UIFeedDetailViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/20/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIFeedDetailViewController.h"
#import "ChatSealFeedCollector.h"
#import "UIFeedDetailOverviewTableViewCell.h"
#import "ChatSeal.h"
#import "UIFeedGenericHeaderFooter.h"
#import "UIFeedDetailPendingPostTableViewCell.h"
#import "UIPendingPostViewController.h"
#import "AlertManager.h"

typedef enum {
    CS_FDC_OVERVIEW = 0,
    CS_FDC_PENDING  = 1,
    
    CS_FDC_SEC_COUNT
} cs_uifdvc_section_t;

// - forward declarations
@interface UIFeedDetailViewController (internal)
-(void) commonConfiguration;
-(void) refreshData;
-(void) notifyFeedUpdated:(NSNotification *) notification;
-(void) notifyFeedTypesUpdated;
-(void) notifyPostProgress:(NSNotification *) notification;
+(NSString *) correctiveTextForFeed:(ChatSealFeed *) feed;
-(NSString *) lastCorrectiveText;
-(void) setLastCorrectiveText:(NSString *) text;
@end

@interface UIFeedDetailViewController (table) <UITableViewDataSource, UITableViewDelegate>
@end

/*******************************
 UIFeedDetailViewController
 *******************************/
@implementation UIFeedDetailViewController
/*
 *  Object attributes
 */
{
    ChatSealFeed   *activeFeed;
    BOOL           feedWasEnabled;
    NSString       *sLastCorrective;
    NSMutableArray *maPostingProgress;
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
    
    [activeFeed release];
    activeFeed = nil;
    
    [sLastCorrective release];
    sLastCorrective = nil;
    
    [tvDetail release];
    tvDetail = nil;
    
    [maPostingProgress release];
    maPostingProgress = nil;
    
    [super dealloc];
}

/*
 *  Configure the object.
 */
-(void) viewDidLoad
{
    [super viewDidLoad];
    
    // - set the back bar item.
    // - assign a title.
    self.title = NSLocalizedString(@"My Feed", nil);
    
    // - grab the current progress.
    NSArray *arrProg = [activeFeed currentPostingProgress];
    if (arrProg) {
        maPostingProgress = [[NSMutableArray arrayWithArray:arrProg] retain];
        NSMutableIndexSet *mis = [NSMutableIndexSet indexSet];
        for (NSUInteger i = 0; i < [maPostingProgress count]; i++) {
            ChatSealPostedMessageProgress *prog = [maPostingProgress objectAtIndex:i];
            if (prog.isCompleted) {
                [mis addIndex:i];
            }
        }
        if (mis.count) {
            [maPostingProgress removeObjectsAtIndexes:mis];
        }
    }
    
    // - wire up the table.
    tvDetail.dataSource = self;
    tvDetail.delegate   = self;
    
    // - and the notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyFeedTypesUpdated) name:kChatSealNotifyFeedTypesUpdated object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyFeedUpdated:) name:kChatSealNotifyFeedUpdate object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyPostProgress:) name:kChatSealNotifyFeedPostProgress object:nil];
}

/*
 *  Set the feed that will be displayed in this detail screen.
 */
-(void) setActiveFeed:(ChatSealFeed *) feed
{
    if (feed != activeFeed) {
        [activeFeed release];
        activeFeed = [feed retain];
    }
}

@end

/*************************************
 UIFeedDetailViewController (internal)
 *************************************/
@implementation UIFeedDetailViewController (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    activeFeed        = nil;
    feedWasEnabled    = YES;
    sLastCorrective   = nil;
    maPostingProgress = nil;
}

/*
 *  Refresh the content in this view.
 */
-(void) refreshData
{
    BOOL useAnim = YES;
    if (self.navigationController.topViewController != self) {
        useAnim = NO;
    }
    
    // - do a couple quick checks to see if the feed actually changed in a way that might make sense for us to refresh because if it hasn't, it
    //   will just flicker the screen and that is not useful.
    if (activeFeed.isEnabled == feedWasEnabled && [self.lastCorrectiveText isEqualToString:[UIFeedDetailViewController correctiveTextForFeed:activeFeed]]) {
        //  - nothing has changed, so there is no need to refresh.
        return;
    }
    
    [tvDetail reloadSections:[NSIndexSet indexSetWithIndex:CS_FDC_OVERVIEW] withRowAnimation:useAnim ? UITableViewRowAnimationFade : UITableViewRowAnimationNone];
}

/*
 *  An update notification is received, which may require that we change the display.
 */
-(void) notifyFeedUpdated:(NSNotification *) notification
{
    ChatSealFeed *feed = [notification.userInfo objectForKey:kChatSealNotifyFeedUpdateFeedKey];
    if (feed == activeFeed) {
        [self refreshData];
    }
}

/*
 *  When the feed types are updated, figure out if I should change anything here.
 */
-(void) notifyFeedTypesUpdated
{
    NSArray *arrFeeds = [[ChatSeal applicationFeedCollector] availableFeedsAsSortedList];
    for (ChatSealFeed *csf in arrFeeds) {
        if ([csf.feedId isEqualToString:activeFeed.feedId]) {
            if (csf != activeFeed) {
                [activeFeed release];
                activeFeed = [csf retain];
                break;
            }
        }
    }
    
    // - make sure the data in the view is updated whether or not the feed is recreated.
    [self refreshData];
}

/*
 *  There may have been an update to one of the items we need to post.
 */
-(void) notifyPostProgress:(NSNotification *)notification
{
    ChatSealPostedMessageProgress *prog = [notification.userInfo objectForKey:kChatSealNotifyFeedPostProgressItemKey];
    
    // - it is possible this isn't one of ours, so we need to determine if we even care.
    for (NSUInteger i = 0; i < [maPostingProgress count]; i++) {
        ChatSealPostedMessageProgress *pCur = [maPostingProgress objectAtIndex:i];
        if ([prog isEqual:pCur]) {
            if (prog.isCompleted) {
                if ([maPostingProgress count] == 1) {
                    [maPostingProgress removeAllObjects];
                    [tvDetail deleteSections:[NSIndexSet indexSetWithIndex:CS_FDC_PENDING] withRowAnimation:UITableViewRowAnimationAutomatic];
                }
                else {
                    [maPostingProgress removeObjectAtIndex:i];
                    [tvDetail deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:(NSInteger) i inSection:CS_FDC_PENDING]]
                                    withRowAnimation:UITableViewRowAnimationAutomatic];
                }
            }
            else {
                [maPostingProgress replaceObjectAtIndex:i withObject:prog];
                UIFeedDetailPendingPostTableViewCell *pc = (UIFeedDetailPendingPostTableViewCell *) [tvDetail cellForRowAtIndexPath:[NSIndexPath indexPathForRow:(NSInteger) i
                                                                                                                                                       inSection:CS_FDC_PENDING]];
                // - may not be visible, in which case, don't worry about it.
                [pc setCurrentProgress:prog.progress withAnimation:YES];
            }
            break;
        }
    }
}

/*
 *  Compute the right kind of corrective text for the given feed.
 */
+(NSString *) correctiveTextForFeed:(ChatSealFeed *) feed
{
    NSString *sRet = [feed correctiveText];
    if (!sRet) {
        sRet = NSLocalizedString(@"This feed is working properly.", nil);
    }
    return sRet;
}

/*
 *  Return the last assigned corrective text.
 */
-(NSString *) lastCorrectiveText
{
    return [[sLastCorrective retain] autorelease];
}

/*
 *  Assign the last corrective text.
 */
-(void) setLastCorrectiveText:(NSString *) text
{
    if (text != sLastCorrective) {
        [sLastCorrective release];
        sLastCorrective = [text retain];
    }
}
@end

/************************************
 UIFeedDetailViewController (table)
 ************************************/
@implementation UIFeedDetailViewController (table)
/*
 *  Return the number of sections in the table view.
 */
-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    if ([maPostingProgress count]) {
        return 2;
    }
    else {
        return 1;
    }
}

/*
 *  Return the number of rows in the given section.
 */
-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case CS_FDC_OVERVIEW:
            return 1;
            break;
            
        case CS_FDC_PENDING:
            return (NSInteger) [maPostingProgress count];
            break;
            
        default:
            return 0;
            break;
    }
}

/*
 *  Return the header text.
 */
-(NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case CS_FDC_OVERVIEW:
            // - the first item requires no header, it is implied by this sub-screen.
            return nil;
            break;
            
        case CS_FDC_PENDING:
            return NSLocalizedString(@"Posts In Progress", nil);
            break;
            
        default:
            return nil;
            break;
    }
}

/*
 *  Return the cell for the given section/row.
 */
-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == CS_FDC_OVERVIEW) {
        UIFeedDetailOverviewTableViewCell *fdotc = (UIFeedDetailOverviewTableViewCell *) [tvDetail dequeueReusableCellWithIdentifier:@"UIFeedDetailOverviewTableViewCell"];
        [fdotc reconfigureCellWithFeed:activeFeed withAnimation:NO];
        if (![activeFeed isValid]) {
            fdotc.userInteractionEnabled = NO;
        }
        feedWasEnabled = [activeFeed isEnabled];
        return fdotc;
    }
    else if (indexPath.section == CS_FDC_PENDING) {
        if (indexPath.row < [maPostingProgress count]) {
            ChatSealPostedMessageProgress *cspmp         = [maPostingProgress objectAtIndex:(NSUInteger) indexPath.row];
            UIFeedDetailPendingPostTableViewCell *fdpotc = (UIFeedDetailPendingPostTableViewCell *) [tvDetail dequeueReusableCellWithIdentifier:@"UIFeedDetailPendingPostTableViewCell"];
            [fdpotc reconfigureWithProgress:cspmp];
            return fdpotc;
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
        if (indexPath.section == CS_FDC_OVERVIEW) {
            UITableViewCell *tvc = [tvDetail dequeueReusableCellWithIdentifier:@"UIFeedDetailOverviewTableViewCell"];
            return CGRectGetHeight(tvc.bounds);
        }
        else if (indexPath.section == CS_FDC_PENDING) {
            UITableViewCell *tvc = [tvDetail dequeueReusableCellWithIdentifier:@"UIFeedDetailPendingPostTableViewCell"];
            return CGRectGetHeight(tvc.bounds);
        }
        return 0.0f;
    }
}

/*
 *  Return an appropriate footer for the overview that includes the status.
 */
-(CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (section == CS_FDC_OVERVIEW) {
        CGFloat ret = [UIFeedGenericHeaderFooter recommendedHeightForText:[UIFeedDetailViewController correctiveTextForFeed:activeFeed] andScreenWidth:CGRectGetWidth(self.view.bounds)];
        if (![ChatSeal isAdvancedSelfSizingInUse] && [maPostingProgress count]) {
            ret *= 1.25f;
        }
        return ret;
    }
    return 0;
}

/*
 *  Return the footer for the overview that shows the corrective text.
 */
-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    if (section != CS_FDC_OVERVIEW) {
        return nil;
    }
    
    // - figure out what will be displayed and return an appropriate cell.
    self.lastCorrectiveText = [UIFeedDetailViewController correctiveTextForFeed:activeFeed];
    UIColor *cTextColor      = nil;
    if (![activeFeed isInWarningState]) {                      //  feed is OK.
        cTextColor     = nil;                                  //  use the default.
    }
    else {
        if ([activeFeed isEnabled]) {
            cTextColor = [ChatSeal defaultWarningColor];
        }
        else {
            cTextColor = [UIColor lightGrayColor];
        }
    }
    
    return [[[UIFeedGenericHeaderFooter alloc] initWithText:self.lastCorrectiveText inColor:cTextColor asHeader:NO] autorelease];
}

/*
 * Should a row be highlighted?
 */
-(BOOL) tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == CS_FDC_OVERVIEW) {
        return NO;
    }
    
    if (![tvDetail shouldPermitHighlight]) {
        return NO;
    }
    
    return YES;
}

/*
 *  Selection of items in the table.
 */
-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == CS_FDC_PENDING && indexPath.row < [maPostingProgress count]) {
        ChatSealPostedMessageProgress *cspmp = (ChatSealPostedMessageProgress *) [maPostingProgress objectAtIndex:(NSUInteger) indexPath.row];
        UIPendingPostViewController *ppvc    = (UIPendingPostViewController *) [ChatSeal viewControllerForStoryboardId:@"UIPendingPostViewController"];
        NSError *err                         = nil;
        if ([ppvc prepareForPendingDisplayOfProgress:cspmp inFeed:activeFeed withError:&err]) {
            [self.navigationController pushViewController:ppvc animated:YES];
        }
        else {
            NSLog(@"CS: Failed to prepare the pending post %@ for display.  %@", cspmp.safeEntryId, [err localizedDescription]);
            [AlertManager displayFatalAlertWithLowSpaceDetectionUsingTitle:NSLocalizedString(@"Pending Post Interrupted", nil)
                                                                   andText:NSLocalizedString(@"The pending post could not be unlocked due to an unexpected problem.", nil)];
        }
    }
    [tvDetail deselectRowAtIndexPath:indexPath animated:YES];
}

@end
