//
//  UIGenericAccessButton.m
//  ChatSeal
//
//  Created by Francis Grolemund on 4/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIGenericAccessButton.h"

/****************************
 UIGenericAccessButton
 ****************************/
@implementation UIGenericAccessButton

/*
 *  Layout the button
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    // - when the state is highlighted, add a slightly darker background.
    if (self.state == UIControlStateHighlighted) {
        self.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.07f];
    }
    else {
        self.backgroundColor = [UIColor clearColor];
    }
}

@end
