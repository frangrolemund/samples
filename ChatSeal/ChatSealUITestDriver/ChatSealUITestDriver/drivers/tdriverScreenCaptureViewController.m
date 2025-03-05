//
//  tdriverScreenCaptureViewController.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 6/19/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "tdriverScreenCaptureViewController.h"
#import "tdriverImagePreviewViewController.h"
#import "UIImageGeneration.h"
#import "UISealWaxViewV2.h"
#import "TestDriverUtil.h"

// - forward declarations
@interface tdriverScreenCaptureViewController (internal) <UITableViewDataSource, UITableViewDelegate>
-(void) doScreenshot;
@end

/***********************************
 tdriverScreenCaptureViewController
 ***********************************/
@implementation tdriverScreenCaptureViewController
/*
 *  Object attributes
 */
{
    UISealWaxViewV2 *waxLayerOutside;
    UISealWaxViewV2 *waxLayerInside;
}

@synthesize vwSubView;

/*
 *  Configure the view.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UITableView *tv = (UITableView *) [self.view viewWithTag:99];
    tv.layer.borderColor = [[UIColor blackColor] CGColor];
    tv.layer.borderWidth = 1.0f;
    tv.delegate = self;
    tv.dataSource = self;
    
    UIBarButtonItem *bbiRight = [[UIBarButtonItem alloc] initWithTitle:@"Screenshot" style:UIBarButtonItemStylePlain target:self action:@selector(doScreenshot)];
    self.navigationItem.rightBarButtonItem = bbiRight;
    [bbiRight release];
    
    waxLayerInside = [[UISealWaxViewV2 alloc] init];
    [waxLayerInside setOuterColor:[UIColor redColor] andMidColor:[UIColor redColor] andInnerColor:[UIColor blueColor]];
    [vwSubView addSubview:waxLayerInside];
    
    waxLayerOutside = [[UISealWaxViewV2 alloc] init];
    [waxLayerOutside setOuterColor:[UIColor purpleColor] andMidColor:[UIColor orangeColor] andInnerColor:[UIColor blackColor]];
    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat waxWidth = width * 0.4f;
    waxLayerOutside.frame = CGRectMake(width - (waxWidth * 1.1), 10, waxWidth, waxWidth);
    [self.view addSubview:waxLayerOutside];
}
    

/*
 *  Free the object.
 */
-(void) dealloc
{
    [vwSubView release];
    vwSubView = nil;
    
    [waxLayerInside release];
    waxLayerInside = nil;
    
    [super dealloc];
}

-(void) viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CGSize sz = vwSubView.bounds.size;
    if (sz.width > sz.height) {
        sz.width = sz.height;
    }
    else {
        sz.height = sz.width;
    }
    waxLayerInside.bounds = CGRectMake(0.0f, 0.0f, sz.width, sz.height);
    waxLayerInside.center = CGPointMake(CGRectGetWidth(vwSubView.bounds)/2.0f, CGRectGetHeight(vwSubView.bounds)/2.0f);
}

@end

/********************************************
 tdriverScreenCaptureViewController (internal)
 ********************************************/
@implementation tdriverScreenCaptureViewController (internal)
/*
 *  Take a screen shot and display it.
 */
-(void) doScreenshot
{
    UIImage *img = [UIImageGeneration imageFromView:self.view withScale:1.0f];
    [TestDriverUtil saveJPGPhoto:img asName:@"screenshot-file.jpg"];
    
    UIViewController *vc = [tdriverImagePreviewViewController imagePreviewForImage:img];
    [self.navigationController pushViewController:vc animated:YES];
}

/*
 *  Only one section in the table.
 */
-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

/*
 * Add a number of rows we can scroll.
 */
-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 15;
}

-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *tvc = [tableView dequeueReusableCellWithIdentifier:@"FakeCell" forIndexPath:indexPath];
    tvc.textLabel.text = [NSString stringWithFormat:@"--%u--", (unsigned) indexPath.row];
    return tvc;
}
@end