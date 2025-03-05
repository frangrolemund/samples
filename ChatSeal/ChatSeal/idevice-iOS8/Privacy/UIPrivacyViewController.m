//
//  UIPrivacyViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 12/3/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIPrivacyViewController.h"
#import "UIChatSealNavigationController.h"
#import "ChatSeal.h"
#import "CS_privacyContentItem.h"
#import "UIPrivacyOverviewTableViewCell.h"
#import "UIPrivacyItemTableViewCell.h"
#import "UIPrivacyPolicyTableViewCell.h"
#import "UIPrivacyFullDisplayViewController.h"
#import "UITableViewWithSizeableCells.h"

// - constants
typedef enum {
    UIPVC_SEC_OVERVIEW = 0,
    UIPVC_SEC_CONTENT  = 1,
    UIPVC_SEC_FULL     = 2,
    
    UIPVC_SEC_COUNT
    
} uipvc_section_t;

typedef void (^scrollCompletionBlock)(void);

// - forward declarations
@interface UIPrivacyViewController (internal)
-(void) setIsModal:(BOOL) isModal;
-(void) doCancel;
-(void) loadPolicyDescriptions;
-(void) setScrollCompletionBlock:(scrollCompletionBlock) cb;
@end

@interface UIPrivacyViewController (table) <UITableViewDataSource, UITableViewDelegate>
@end

/**************************
 UIPrivacyViewController
 **************************/
@implementation UIPrivacyViewController
/*
 *  Object attributes
 */
{
    BOOL                    isModal;
    NSMutableArray          *maPrivacyItems;
    NSInteger               activeItem;
    scrollCompletionBlock   sCompletion;
}
@synthesize tvContent;

/*
 *  Display the privacy notice in a way that makes sense.
 */
+(void) displayPrivacyNoticeFromViewController:(UIViewController *) vc asModal:(BOOL) isModal
{
    UIPrivacyViewController *pvc = (UIPrivacyViewController *) [ChatSeal viewControllerForStoryboardId:@"UIPrivacyViewController"];
    if (isModal) {
        [pvc setIsModal:YES];
        UIChatSealNavigationController *nc = [[[UIChatSealNavigationController alloc] initWithRootViewController:pvc] autorelease];
        [vc presentViewController:nc animated:YES completion:nil];
    }
    else {
        [pvc setIsModal:NO];
        [vc.navigationController pushViewController:pvc animated:YES];
    }
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        isModal        = NO;
        self.title     = NSLocalizedString(@"Privacy", nil);
        maPrivacyItems = [[NSMutableArray alloc] init];
        activeItem     = -1;
        sCompletion    = nil;
        [self loadPolicyDescriptions];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [self setScrollCompletionBlock:nil];
    
    [tvContent release];
    tvContent = nil;
    
    [maPrivacyItems release];
    maPrivacyItems = nil;
    
    [super dealloc];
}

/*
 *  Configure the view.
 */
-(void) viewDidLoad
{
    [super viewDidLoad];
    
    // - make sure a cancel button exists when we're modal.
    if (isModal) {
        UIBarButtonItem *bbiCancel             = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(doCancel)] autorelease];
        self.navigationItem.rightBarButtonItem = bbiCancel;
    }
    
    // - set up the table.
    self.tvContent.dataSource = self;
    self.tvContent.delegate   = self;
}

/*
 *  The view has disappeared.
 */
-(void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self.tvContent parentViewControllerDidDisappear];
}

@end

/*********************************
 UIPrivacyViewController (internal)
 *********************************/
@implementation UIPrivacyViewController (internal)
/*
 *  Assign the modal flag to the view controller.
 */
-(void) setIsModal:(BOOL) m
{
    isModal = m;
}

/*
 *  The cancel button was pressed.
 */
-(void) doCancel
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

/*
 *  Load up the titles and descriptions for the various policy items.
 */
-(void) loadPolicyDescriptions
{
    [maPrivacyItems addObject:[CS_privacyContentItem privacyContentWithTitle:NSLocalizedString(@"How private is ChatSeal?", nil)
                                                              andDescription:NSLocalizedString(@"Although ChatSeal was engineered to use strong encryption and information-hiding technologies, there is no such thing as absolute privacy with any security product.  When in doubt, experience your most personal moments without the use of technology.", nil)]];
    [maPrivacyItems addObject:[CS_privacyContentItem privacyContentWithTitle:NSLocalizedString(@"Does RealProven, LLC know I'm using ChatSeal?", nil)
                                                              andDescription:NSLocalizedString(@"No, we only have the data on app sales numbers and general usage, provided by Apple.  ChatSeal never contacts RealProven for any reason whatsoever.  Not even once.", nil)]];
    [maPrivacyItems addObject:[CS_privacyContentItem privacyContentWithTitle:NSLocalizedString(@"How is my personal information used?", nil)
                                                              andDescription:NSLocalizedString(@"ChatSeal only uses your information to support messaging with your friends.  It never collects, analyzes or sends that information to anyone without your knowledge.", nil)]];
    [maPrivacyItems addObject:[CS_privacyContentItem privacyContentWithTitle:NSLocalizedString(@"Am I personally identifiable with ChatSeal?", nil)
                                                              andDescription:NSLocalizedString(@"None of your personally identifiable information is ever included in your seals or messages without your knowledge.  However, when you send a sealed message over Twitter, others may know that you are communicating and possibly who you are communicating with, even though they cannot read what you send.", nil)]];
    [maPrivacyItems addObject:[CS_privacyContentItem privacyContentWithTitle:NSLocalizedString(@"How are my personal messages posted on Twitter?", nil)
                                                              andDescription:NSLocalizedString(@"Every message you and your friends exchange is encrypted, stored inside a photo, and then posted on your public Twitter feed.  Only those people with your seal will be able to retrieve the encrypted content from inside the photo and read your personal message.", nil)]];
    [maPrivacyItems addObject:[CS_privacyContentItem privacyContentWithTitle:NSLocalizedString(@"Does ChatSeal share my data with third-parties?", nil)
                                                              andDescription:NSLocalizedString(@"No, ChatSeal uses third-parties, like Twitter, only as a service for storing your encrypted messages.   None of your personal information is ever provided to these services for identification or analytics.", nil)]];
    [maPrivacyItems addObject:[CS_privacyContentItem privacyContentWithTitle:NSLocalizedString(@"What is sent over the network?", nil)
                                                              andDescription:NSLocalizedString(@"ChatSeal only sends data over encrypted network connections, and even then only exchanges seals and provides secure messaging on your behalf.  It never sends anything to anyone, including RealProven, LLC, for any other purpose.", nil)]];
    [maPrivacyItems addObject:[CS_privacyContentItem privacyContentWithTitle:NSLocalizedString(@"What kinds of personal data are accessed?", nil)
                                                              andDescription:NSLocalizedString(@"ChatSeal uses your Twitter accounts, local networking settings, photo library, camera, and the history of messages you send with it.  Please consult the full policy for more information.", nil)]];
    [maPrivacyItems addObject:[CS_privacyContentItem privacyContentWithTitle:NSLocalizedString(@"How is my data retained?", nil)
                                                              andDescription:NSLocalizedString(@"Your personal data is fully encrypted and only accessible on your device and the devices of friends who you communicate with.  Nothing that can be read by others is stored anywhere else.  If you delete your messages and your seals expire, your messages will be permanently locked.", nil)]];
}

/*
 *  Save the completion block for when scrolling stops.
 */
-(void) setScrollCompletionBlock:(scrollCompletionBlock) cb
{
    if (cb != sCompletion) {
        if (sCompletion) {
            Block_release(sCompletion);
            sCompletion = nil;
        }
        if (cb) {
            sCompletion = Block_copy(cb);
        }
    }
}
@end

/********************************
 UIPrivacyViewController (table)
 ********************************/
@implementation UIPrivacyViewController (table)
/*
 *  Return the number of sections in the table view.
 */
-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return UIPVC_SEC_COUNT;
}

/*
 *  Return the number of rows in each section.
 */
-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == UIPVC_SEC_OVERVIEW) {
        return 1;
    }
    else if (section == UIPVC_SEC_CONTENT) {
        return (NSInteger) [maPrivacyItems count];
    }
    else if (section == UIPVC_SEC_FULL) {
        return 1;
    }
    return 0;
}

/*
 *  Get the height for a given section/row.
 */
-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        return UITableViewAutomaticDimension;
    }
    else {
        // - the first and last sections are simply hard-coded heights.
        if (indexPath.section == UIPVC_SEC_OVERVIEW) {
            if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation)) {
                return 94.0f;
            }
            else {
                return 116.0f;
            }
        }
        else if (indexPath.section == UIPVC_SEC_FULL) {
            return [ChatSeal minimumTouchableDimension];
        }
        
        // - the actual content section is a bit more complicated.  I need to size that
        //   based on what is showing and what is needed for each title.
        UIPrivacyItemTableViewCell *pio = (UIPrivacyItemTableViewCell *) [tvContent dequeueReusableCellWithIdentifier:@"UIPrivacyItemTableViewCell"];
        CS_privacyContentItem *pci = [maPrivacyItems objectAtIndex:(NSUInteger) indexPath.row];
        [pio setTitle:pci.title andDescription:pci.desc];
        if (activeItem == indexPath.row) {
            [pio setDisplayDescription:YES];
        }        
        return [pio recommendedHeightForRowOfWidth:CGRectGetWidth(tableView.frame)];
    }
    return 0.0f;
}

/*
 *  Return a cell for a particular row.
 */
-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == UIPVC_SEC_OVERVIEW) {
        UIPrivacyOverviewTableViewCell *poc = (UIPrivacyOverviewTableViewCell *) [tableView dequeueReusableCellWithIdentifier:@"UIPrivacyOverviewTableViewCell" forIndexPath:indexPath];
        return poc;
    }
    else if (indexPath.section == UIPVC_SEC_CONTENT) {
        if (indexPath.row < [maPrivacyItems count]) {
            UIPrivacyItemTableViewCell *pio = (UIPrivacyItemTableViewCell *) [tableView dequeueReusableCellWithIdentifier:@"UIPrivacyItemTableViewCell" forIndexPath:indexPath];
            CS_privacyContentItem *pci = [maPrivacyItems objectAtIndex:(NSUInteger) indexPath.row];
            [pio setTitle:pci.title andDescription:pci.desc];
            if (activeItem == indexPath.row) {
                [pio setDisplayDescription:YES];
            }
            return pio;
        }
    }
    else if (indexPath.section == UIPVC_SEC_FULL) {
        UIPrivacyPolicyTableViewCell *ppc = (UIPrivacyPolicyTableViewCell *) [tableView dequeueReusableCellWithIdentifier:@"UIPrivacyPolicyTableViewCell" forIndexPath:indexPath];
        return ppc;
    }
    return nil;
}

/*
 *  Generally highlighting, but take this opportunity to expand the content cells if necessary.
 */
-(BOOL) tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    // - figure out if selection should go ahead.
    if (indexPath.section == UIPVC_SEC_FULL) {
        return YES;
    }
    
    if (![(UITableViewWithSizeableCells *) tvContent shouldPermitHighlight]) {
        return NO;
    }
    
    // - figure out if we need to deselect an item.
    UIPrivacyItemTableViewCell *cToDeselect = nil;
    NSInteger lastActive         = activeItem;
    if (activeItem != -1) {
        cToDeselect  = (UIPrivacyItemTableViewCell *) [self.tvContent cellForRowAtIndexPath:[NSIndexPath indexPathForRow:activeItem inSection:UIPVC_SEC_CONTENT]];
        activeItem = -1;
    }
    
    // - get the new item if necessary.
    UIPrivacyItemTableViewCell *cToSelect = nil;
    if (indexPath.section == UIPVC_SEC_CONTENT && lastActive != indexPath.row) {
        cToSelect  = (UIPrivacyItemTableViewCell *) [self.tvContent cellForRowAtIndexPath:indexPath];
        activeItem = indexPath.row;
    }
    
    // - do both under one animation block.
    if (cToDeselect || cToSelect) {
        // - we'll use a block so that it works whether we have to scroll first or not.
        scrollCompletionBlock updateTable = ^(void) {
            [self.tvContent beginUpdates];
            [cToDeselect setDisplayDescription:NO];
            [cToSelect setDisplayDescription:YES];
            [self.tvContent endUpdates];            
        };
        
        // - determine if we should scroll the view first.
        CGFloat descHeight     = [cToDeselect descriptionHeight];
        CGFloat contentOffsetY = tvContent.contentOffset.y;
        CGFloat contentHeight  = tvContent.contentSize.height - descHeight;
        CGFloat visibleHeight  = contentHeight - tvContent.contentOffset.y + 8.0f;
        if (!cToSelect && cToDeselect && contentOffsetY > 0.0f && visibleHeight < CGRectGetHeight(tvContent.bounds)) {
            CGFloat toScroll = MIN(contentOffsetY, CGRectGetHeight(tvContent.bounds) - visibleHeight);
            [self setScrollCompletionBlock:updateTable];
            [self.tvContent setContentOffset:CGPointMake(0.0f, contentOffsetY - toScroll) animated:YES];
        }
        else {
            updateTable();
            if (cToSelect) {
                [self.tvContent scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionNone animated:YES];
            }
        }
    }
    
    return NO;
}

/*
 *  A row was selected (should only be the full privacy policy row).
 */
-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == UIPVC_SEC_FULL) {
        UIPrivacyFullDisplayViewController *pfd = (UIPrivacyFullDisplayViewController *) [ChatSeal viewControllerForStoryboardId:@"UIPrivacyFullDisplayViewController"];
        [tvContent prepareForNavigationPush];
        [self.navigationController pushViewController:pfd animated:YES];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

/*
 *  The scrolling animation is complete.
 */
-(void) scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    if (sCompletion) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
            sCompletion();
            [self setScrollCompletionBlock:nil];
        }];
    }
}
@end