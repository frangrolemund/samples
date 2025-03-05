//
//  UIPendingPostDetailTableViewCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIPendingPostDetailTableViewCell.h"
#import "ChatSeal.h"

// - forward declarations
@interface UIPendingPostDetailTableViewCell (internal)
-(void) discardDisplayView;
@end

/*********************************
 UIPendingPostDetailTableViewCell
 *********************************/
@implementation UIPendingPostDetailTableViewCell
/*
 *  Object attributes.
 */
{
    UIView                  *displayView;
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        self.clipsToBounds = YES;
        displayView        = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [self discardDisplayView];
    [super dealloc];
}

/*
 *  Prepare to reuse the object.
 */
-(void) prepareForReuse
{
    [self discardDisplayView];
}

/*
 *  The display view is for the message display and should simply
 *  be assigned to this one.
 */
-(void) setDisplayView:(UIView *) dv withContentHeight:(CGFloat) contentHeight
{
    if (dv != displayView) {
        [self discardDisplayView];
        [dv removeFromSuperview];
        displayView               = [dv retain];
        dv.frame                  = self.contentView.bounds;
        [self.contentView addSubview:dv];
        
        // - if we're using advanced sizing, the constraints are going to influence the size of the cell.
        if ([ChatSeal isAdvancedSelfSizingInUse]) {
            displayView.translatesAutoresizingMaskIntoConstraints = NO;
            NSLayoutConstraint *cnt = [NSLayoutConstraint constraintWithItem:displayView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0f constant:contentHeight];
            cnt.priority = 999;
            [self.contentView addConstraint:cnt];
            cnt = [NSLayoutConstraint constraintWithItem:displayView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.contentView attribute:NSLayoutAttributeTop multiplier:1.0f constant:0.0f];
            [self.contentView addConstraint:cnt];
            cnt = [NSLayoutConstraint constraintWithItem:displayView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.contentView attribute:NSLayoutAttributeBottom multiplier:1.0f constant:0.0f];
            [self.contentView addConstraint:cnt];
            cnt = [NSLayoutConstraint constraintWithItem:displayView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.contentView attribute:NSLayoutAttributeLeft multiplier:1.0f constant:0.0f];
            [self.contentView addConstraint:cnt];
            cnt = [NSLayoutConstraint constraintWithItem:displayView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self.contentView attribute:NSLayoutAttributeRight multiplier:1.0f constant:0.0f];
            [self.contentView addConstraint:cnt];
        }
        else {
            displayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        }
    }
}
@end

/********************************************
 UIPendingPostDetailTableViewCell (internal)
 ********************************************/
@implementation UIPendingPostDetailTableViewCell (internal)
/*
 *  Discard the active display.
 */
-(void) discardDisplayView
{
    [displayView removeFromSuperview];
    [displayView release];
    displayView = nil;
}

@end
