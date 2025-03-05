//
//  UIColorWatcherView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 2/24/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIColorWatcherView.h"

/*********************
 UIColorWatcherView
 *********************/
@implementation UIColorWatcherView
/*
 *  Whenever this item is used in a table view cell, the table view cell actually
 *  changes to a white color space during selection, but that ends up looking odd
 *  as it flips over.   This check will prevent that colorspace animation from
 *  occurring.
 */
-(void) setBackgroundColor:(UIColor *)backgroundColor
{
    if (backgroundColor != nil) {
        CGColorSpaceRef csr = CGColorGetColorSpace(backgroundColor.CGColor);
        if (csr) {
            if (CGColorSpaceGetModel(csr) == kCGColorSpaceModelMonochrome) {
                return;
            }
        }
    }
    [super setBackgroundColor:backgroundColor];
}
@end
