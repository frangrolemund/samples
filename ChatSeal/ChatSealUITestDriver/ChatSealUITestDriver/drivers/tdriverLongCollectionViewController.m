//
//  tdriverLongCollectionViewController.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 5/21/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import "tdriverLongCollectionViewController.h"

// - constants
static const NSInteger DRIVER_LCV_NUM_ITEMS = 300;

// -  forward declarations
@interface tdriverLongCollectionViewController (internal)
-(void) doCancel;
@end

/***********************************
 tdriverLongCollectionViewController
 ***********************************/
@implementation tdriverLongCollectionViewController

/*
 *  Initialize the collection view
 */
-(id) init
{
    UICollectionViewFlowLayout *fl = [[UICollectionViewFlowLayout alloc] init];
    fl.itemSize                = CGSizeMake(75.0f, 75.0f);
    fl.minimumLineSpacing      = 2.0f;
    fl.minimumInteritemSpacing = 2.0f;
    self = [super initWithCollectionViewLayout:fl];
    [fl release];
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

    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"BasicCell"];
    
    UIBarButtonItem *bbiCancel = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(doCancel)];
    self.navigationItem.rightBarButtonItem = bbiCancel;
    [bbiCancel release];
}

/*
 *  The number of sections in the collection.
 */
-(NSInteger) numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

/*
 *  The number of items in the section.
 */
-(NSInteger) collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (section == 0) {
        return DRIVER_LCV_NUM_ITEMS;
    }
    return 0;
}

/*
 *  Return a cell for the given position.
 */
-(UICollectionViewCell *) collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    int colorComp = (int) (indexPath.item / 100);
    int remainder = (indexPath.item % 100) + 1;
    CGFloat mainValue = 0.5 + (0.5 *((CGFloat) remainder / (CGFloat) 100));
    
    UIColor *c = nil;
    switch (colorComp) {
        default:
        case 0:
            c = [UIColor colorWithRed:mainValue green:0.0f blue:0.0f alpha:mainValue];
            break;
            
        case 1:
            c = [UIColor colorWithRed:0.0f green:mainValue blue:0.0f alpha:mainValue];
            break;
            
        case 2:
            c = [UIColor colorWithRed:0.0f green:0.0f blue:mainValue alpha:mainValue];
            break;
    }
    
    UICollectionViewCell *cvc = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"BasicCell" forIndexPath:indexPath];
    cvc.backgroundColor = c;
    return cvc;
}

@end

/**********************************************
 tdriverLongCollectionViewController (internal)
 **********************************************/
@implementation tdriverLongCollectionViewController (internal)

/*
 *  Close the view.
 */
-(void) doCancel
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
