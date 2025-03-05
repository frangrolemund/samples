//
//  tdriverSearchScrollerViewController.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 12/8/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import "tdriverSearchScrollerViewController.h"
#import "UISearchScroller.h"
#import "UIMessageDetailFeedAddressView.h"

// - constants.
static NSString *DRV_SS_CELLNAME = @"GenericCell";

// - forward declarations
@interface tdriverSearchScrollerViewController (internal) <UITableViewDataSource, UITableViewDelegate, UISearchScrollerDelegate>
@end

/***********************************
 tdriverSearchScrollerViewController
 ***********************************/
@implementation tdriverSearchScrollerViewController
/*
 *  Object attributes.
 */
{
    UITableView                    *tvSample;
    UIMessageDetailFeedAddressView *feedAddress;
}
@synthesize ssSearchScroller;

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {

    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [ssSearchScroller release];
    ssSearchScroller = nil;
    
    [tvSample release];
    tvSample = nil;
    
    [feedAddress release];
    feedAddress = nil;
    
    [super dealloc];
}

/*
 *  This action occurs when the refresh should be killed.
 */
-(void) doAction
{
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [ssSearchScroller setRefreshCompletedWithAnimation:YES];
}

/*
 *  Configure the object.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];

    // - create the table we'll use for sample content.
    tvSample = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    [tvSample registerClass:[UITableViewCell class] forCellReuseIdentifier:DRV_SS_CELLNAME];
    tvSample.delegate            = self;
    tvSample.dataSource          = self;
    tvSample.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [ssSearchScroller setPrimaryContentView:tvSample];
    
    // - wire up the rest of the search scroller.
    ssSearchScroller.delegate = self;
    [ssSearchScroller setNavigationController:self.navigationController];
#if 1
    ssSearchScroller.descriptionLabel.text          = @"Last Updated: Dec 8, 2013 11:45 AM";
    ssSearchScroller.descriptionLabel.font          = [UIFont systemFontOfSize:14.0f];
    ssSearchScroller.descriptionLabel.textAlignment = NSTextAlignmentCenter;
    [ssSearchScroller setRefreshEnabled:YES];
#endif
    
    // ... the tools exist below the search bar itself.
    feedAddress = [[UIMessageDetailFeedAddressView alloc] init];
    CGSize szMin = [feedAddress sizeThatFits:CGSizeMake(1.0f, 1.0f)];
    tvSample.contentInset = UIEdgeInsetsMake(szMin.height, 0.0f, 0.0f, 0.0f);       // in order to get it to work well with the overlaid address bar.
    [ssSearchScroller setSearchToolsView:feedAddress];
    
    // - to test that we can complete the refresh 
    UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithTitle:@"Hide Refresh" style:UIBarButtonItemStylePlain target:self action:@selector(doAction)];
    self.navigationItem.rightBarButtonItem         = bbi;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [bbi release];
}

/*
 *  We need to notify the search scroller of animation events so that it can get the accurate nav bar dimensions.
 */
-(void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [ssSearchScroller willAnimateRotation];
}

@end


/**********************************************
 tdriverSearchScrollerViewController (internal)
 **********************************************/
@implementation tdriverSearchScrollerViewController (internal)
/*
 *  Called when the scroll view scrolls.  This should be the table.
 */
-(void) scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView == tvSample) {
        CGFloat offset = scrollView.contentOffset.y + scrollView.contentInset.top;
        if ([ssSearchScroller applyProxiedScrollOffset:CGPointMake(0.0f, offset)]) {
            // - when the search scroller uses the offset for its own scrolling,
            //   it shouldn't be applied again here because the outer scroll view
            //   is already translating the table.
            tvSample.contentOffset = CGPointMake(0.0f, -scrollView.contentInset.top);
        }
    }
}

/*
 *  After we complete our dragging operation, make sure that the search scroller stays
 *  up to date.
 */
-(void) scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate) {
        [ssSearchScroller validateContentPositionAfterProxiedScrolling];
    }
}

/*
 *  Make sure we validate also after deceleration.
 */
-(void) scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [ssSearchScroller validateContentPositionAfterProxiedScrolling];
}

/*
 *  When the user refreshes the search scroller, this method is triggered.
 */
-(void) searchScrollerRefreshTriggered:(UISearchScroller *)ss
{
    self.navigationItem.rightBarButtonItem.enabled = YES;
}

/*
 *  When search text is modified, this event is triggered.
 */
-(void) searchScroller:(UISearchScroller *) ss textWasChanged:(NSString *) searchText
{
    NSLog(@"DEBUG: search text is now %@", searchText && [searchText length] ? searchText : @"NIL");
}

/*
 *  When the search bar moves from foreground to background, this event is fired.
 */
-(void) searchScroller:(UISearchScroller *) ss didMoveToForegroundSearch:(BOOL) isForeground
{
    NSLog(@"DEBUG: search is now %s", isForeground ? "FOREGROUND" : "BACKGROUND");
}

-(BOOL) searchScroller:(UISearchScroller *)ss shouldCollapseAllAfterMoveToForeground:(BOOL)isForeground
{
    if (!isForeground && tvSample.contentOffset.y > 0.0f) {
        return YES;
    }
    return NO;
}

/*
 *  A single section.
 */
-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

/*
 *  A decent collection of content.
 */
-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 25;
}

/*
 *  Return a cell with some data.
 */
-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *tvc = [tableView dequeueReusableCellWithIdentifier:DRV_SS_CELLNAME forIndexPath:indexPath];
    if (tvc) {
        tvc.textLabel.text = [NSString stringWithFormat:@"row %u scrolling content.", (unsigned) indexPath.row];
    }
    return tvc;
}
@end