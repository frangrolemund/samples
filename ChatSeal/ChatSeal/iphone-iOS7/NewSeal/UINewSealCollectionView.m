//
//  UINewSealCollectionView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/6/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UINewSealCollectionView.h"
#import "UISealClippingContainer.h"

/************************
 UINewSealCollectionView
 ************************/
@implementation UINewSealCollectionView
/*
 *  Object attributes
 */
{
    NSIndexPath *ipDefault;
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        ipDefault = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [ipDefault release];
    ipDefault = nil;
    
    [super dealloc];
}

/*
 *  Assign a default item to the view to populate after it is first loaded.
 *  - this is necessary because the view's size isn't set until after the
 *    layout occurs in the superview.
 */
-(void) setDefaultItem:(NSIndexPath *)indexPath
{
    if (ipDefault != indexPath) {
        [ipDefault release];
        ipDefault = [indexPath retain];
    }
}

/*
 *  Perform layout in the view.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    if (ipDefault) {
        [self scrollToItemAtIndexPath:ipDefault atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:NO];
        [ipDefault release];
        ipDefault = nil;
    }
}

@end
