//
//  UINewSealFlowLayout.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/6/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UINewSealFlowLayout.h"

/******************************
 UINewSealFlowLayout
 ******************************/
@implementation UINewSealFlowLayout

-(id) init
{
    self = [super init];
    if (self) {
        self.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    }
    return self;
}

/*
 *  Force cells to be centered in the view.
 *  - the hardest part about this particular method is what happens when the velocity is near zero and the proposed offset
 *    is the same as the current offset.  In that case, we need to be smarter because it isn't possible to know which way the
 *    user is scrolling and we must just try to center the view.
 */
-(CGPoint) targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset withScrollingVelocity:(CGPoint)velocity
{
    //  - figure out which cells are visible
    CGRect rcCurVisible = self.collectionView.bounds;           //  includes the content offset.
    NSArray *arrVisible = [self layoutAttributesForElementsInRect:rcCurVisible];
    CGPoint ptVisibleCenter = CGPointMake(rcCurVisible.origin.x + (CGRectGetWidth(rcCurVisible)/2.0f), rcCurVisible.origin.y + (CGRectGetWidth(rcCurVisible)/2.0f));
    
    // - now determine the items closest to the center of the view.
    UICollectionViewLayoutAttributes *targetItemLeft  = nil;
    UICollectionViewLayoutAttributes *targetItemRight = nil;
    for (UICollectionViewLayoutAttributes *attrib in arrVisible) {
        if (attrib.center.x < ptVisibleCenter.x) {
            if (!targetItemLeft || (ptVisibleCenter.x - attrib.center.x) < (ptVisibleCenter.x - targetItemLeft.center.x)) {
                targetItemLeft = attrib;
            }
        }
        else {
            if (!targetItemRight || (attrib.center.x - ptVisibleCenter.x) < (targetItemRight.center.x - ptVisibleCenter.x)) {
                targetItemRight = attrib;
            }
            
        }
    }

    // - if no targets were found, then return the suggested offset
    if (!targetItemRight && !targetItemLeft) {
        NSLog(@"CS:  Unexpected scroll target missing in seal collection.");
        return proposedContentOffset;
    }
    
    // - figure out the proper center of the view.
    CGPoint ptViewCenter = CGPointZero;
    if ([self.collectionView.delegate respondsToSelector:@selector(workingCenterOfView)]) {
        ptViewCenter = [(id<UICollectionViewDelegateSealFlowLayout>)self.collectionView.delegate workingCenterOfView];
    }
    else {
        ptViewCenter = CGPointMake((CGRectGetWidth(self.collectionView.bounds)/2.0f), (CGRectGetHeight(self.collectionView.bounds)/2.0f));
    }
    
    //  - and compute the offset
    CGPoint ptRet    = CGPointZero;
    BOOL    hasDecel = YES;
    if (fabsl(velocity.x) < 0.25f || fabsl(CGRectGetMinX(rcCurVisible) - proposedContentOffset.x) < 1.0f) {
        hasDecel = NO;
        if (!targetItemRight ||
            (targetItemLeft && fabsl(targetItemLeft.center.x - ptVisibleCenter.x) < fabsl(targetItemRight.center.x - ptVisibleCenter.x))) {
            ptRet = CGPointMake(targetItemLeft.center.x - ptViewCenter.x, 0.0f);
        }
        else {
            ptRet = CGPointMake(targetItemRight.center.x - ptViewCenter.x, 0.0f);
        }
    }
    else if (!targetItemLeft || (proposedContentOffset.x > CGRectGetMinX(rcCurVisible) && targetItemRight)) {
        ptRet = CGPointMake(targetItemRight.center.x - ptViewCenter.x, 0.0f);
    }
    else {
        ptRet = CGPointMake(targetItemLeft.center.x - ptViewCenter.x, 0.0f);
    }
    
    if (hasDecel) {
        return ptRet;
    }
    else {
        // - when the velocity is too small, the scroll view will take too long to
        //   return to a steady state, so we'll use the standard animation to pull it off.
        UICollectionView *cv = self.collectionView;
        [[NSOperationQueue mainQueue] addOperation:[NSBlockOperation blockOperationWithBlock:^(void) {
            [cv setContentOffset:ptRet animated:YES];
        }]];
        return proposedContentOffset;
    }
}
@end
