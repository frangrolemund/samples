//
//  UIDebugLogTableViewCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 12/14/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIDebugLogTableViewCell.h"

/*************************
 UIDebugLogTableViewCell
 *************************/
@implementation UIDebugLogTableViewCell
/*
 *  Object attributes.
 */
{
    
}
@synthesize lDebugText;

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
    [lDebugText release];
    lDebugText = nil;
    
    [super dealloc];
}

/*
 *  Layout has occurred.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat curWidth = CGRectGetWidth(lDebugText.frame);
    if ((int) curWidth != (int) lDebugText.preferredMaxLayoutWidth) {
        [lDebugText setPreferredMaxLayoutWidth:curWidth];
        [lDebugText invalidateIntrinsicContentSize];
    }
}

@end
