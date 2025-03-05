//
//  UISealedMessageExportGuidanceView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/25/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UISealedMessageExportGuidanceView.h"

@implementation UISealedMessageExportGuidanceView
/*
 *  When layout occurs, make sure the error labels are 
 *  adjusted with their max content width.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    // - the tags are in the NIB, of course
    const int tags[] = {0, 2, 3, 4};
    for (int i = 0; i < sizeof(tags)/sizeof(tags[0]); i++) {
        UILabel *l    = (UILabel *) [self viewWithTag:tags[i]];
        CGFloat width = CGRectGetWidth(l.bounds);
        if ((int) l.preferredMaxLayoutWidth != (int) width) {
            l.preferredMaxLayoutWidth = width;
            [self setNeedsUpdateConstraints];
        }
    }
}
@end
