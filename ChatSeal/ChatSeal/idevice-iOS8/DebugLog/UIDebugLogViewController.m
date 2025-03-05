//
//  UIDebugLogViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 12/14/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIDebugLogViewController.h"
#import "ChatSeal.h"
#import "UIDebugLogTableViewCell.h"

// - forward declarations
@interface UIDebugLogViewController (internal) <UITableViewDataSource, UITableViewDelegate>
-(void) updateTableInsets;
-(void) doRefresh;
@end

/**************************
 UIDebugLogViewController
 **************************/
@implementation UIDebugLogViewController
/*
 *  Object attributes
 */
{
    
}
@synthesize tvTable;

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        self.title = @"Debug Log";
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [tvTable release];
    tvTable = nil;
    
    [super dealloc];
}

/*
 *  Configure the view.
 */
-(void) viewDidLoad
{
    [super viewDidLoad];
    
    self.tvTable.rowHeight  = 66.0f;
    self.tvTable.delegate   = self;
    self.tvTable.dataSource = self;
    
    UIBarButtonItem *bbiRefresh            = [[[UIBarButtonItem alloc] initWithTitle:@"Refresh" style:UIBarButtonItemStylePlain target:self action:@selector(doRefresh)] autorelease];
    self.navigationItem.rightBarButtonItem = bbiRefresh;
}

/*
 *  Called before layout occurs.
 */
-(void) viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self updateTableInsets];
}

/*
 *  The view is about to appear.
 */
-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateTableInsets];
}

/*
 *  The view is about to rotate.
 */
-(void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self updateTableInsets];
}
@end

/*********************************
 UIDebugLogViewController (internal)
 *********************************/
@implementation UIDebugLogViewController (internal)
/*
 *  The table insets are set up to correctly display the content, considering that there are top/bottom bars.
 */
-(void) updateTableInsets
{
    CGFloat topOffset         = CGRectGetMaxY(self.navigationController.navigationBar.frame);
    CGFloat botOffset         = [[ChatSeal applicationHub] tabBarHeight];
    self.tvTable.contentInset = UIEdgeInsetsMake(topOffset, 0.0f, botOffset, 0.0f);
}

/*
 *  Refresh the content
 */
-(void) doRefresh
{
    [self.tvTable reloadData];
}

/*
 *  Return the number of sections in the table view.
 */
-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

/*
 *  Return the number of rows in the table.
 */
-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger) [ChatSeal numberOfDebugLogItems];
}

/*
 *  Return the cell for the given position.
 */
-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *sText = [ChatSeal debugLogItemAtIndeex:(NSUInteger) indexPath.row];
    if (sText) {
        UIDebugLogTableViewCell *dltvc = (UIDebugLogTableViewCell *) [self.tvTable dequeueReusableCellWithIdentifier:@"UIDebugLogTableViewCell" forIndexPath:indexPath];
        dltvc.lDebugText.text          = sText;
        return dltvc;
    }
    return nil;
}


@end
