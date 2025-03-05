//
//  tdriverLongTableViewController.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 5/21/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import "tdriverLongTableViewController.h"
#import "tdriverLongCollectionViewController.h"

// - constants
static const NSUInteger TDRIVER_LT_NUM_ROWS = 100;
static NSString         *TDRIVER_LT_CELL    = @"LongTableCell";

// - forward declarations.
@interface tdriverLongTableViewController (interal)
-(void) doCancel;
-(void) doParentAction;
@end

//  - basic cell
@interface UILongTableCell : UITableViewCell
@end

/************************************
 tdriverLongTableViewController
 ************************************/
@implementation tdriverLongTableViewController
@synthesize delegate;

/*
 *  Initialize the view
 */
-(id) init
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        
    }
    return self;
}

/*
 *  Configure the view.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Minimal Tabs";
    [self.tableView registerClass:[UILongTableCell class] forCellReuseIdentifier:TDRIVER_LT_CELL];

    UIBarButtonItem *bbiAction = [[UIBarButtonItem alloc] initWithTitle:@"Parent Action" style:UIBarButtonItemStyleBordered target:self action:@selector(doParentAction)];
    self.navigationItem.leftBarButtonItem = bbiAction;
    [bbiAction release];
    UIBarButtonItem *bbiCancel = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(doCancel)];
    self.navigationItem.rightBarButtonItem = bbiCancel;
    [bbiCancel release];}

/*
 *  Return the number of sections being displayed.
 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

/*
 *  Return the number of rows in the table.
 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return TDRIVER_LT_NUM_ROWS;
    }
    return 0;
}

/*
 *  Return the content for the given row.
 */
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section != 0) {
        return nil;
    }
    
    UILongTableCell *cell = [tableView dequeueReusableCellWithIdentifier:TDRIVER_LT_CELL forIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    NSString *s = [NSNumberFormatter localizedStringFromNumber:[NSNumber numberWithUnsignedInteger:indexPath.row] numberStyle:NSNumberFormatterSpellOutStyle];
    cell.textLabel.text = s;
    return cell;
}

/*
 *  Move to the next view.
 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    tdriverLongCollectionViewController *cvc = [[tdriverLongCollectionViewController alloc] init];
    [self.navigationController pushViewController:cvc animated:YES];
    [cvc release];
}

@end

/*****************************************
 tdriverLongTableViewController (internal)
 *****************************************/
@implementation tdriverLongTableViewController (internal)
/*
 *  Close the window.
 */
-(void) doCancel
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

/*
 *  Perform an action on the parent delegate if possible.
 */
-(void) doParentAction
{
    if (delegate) {
        [delegate performSelector:@selector(doParentAction)];
    }
}

@end

/************************************
 UILongTableCell
 ************************************/
@implementation UILongTableCell
/*
 *  Initialize the cell.
 */
-(id) initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    return [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
}
@end
