//
//  UISealDetailAboutCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/1/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealDetailAboutCell.h"
#import "ChatSeal.h"

/******************************
 UISealDetailAboutCell
 ******************************/
@implementation UISealDetailAboutCell
@synthesize lAboutText;

/*
 *  Free the object.
 */
-(void) dealloc
{
    [lAboutText release];
    lAboutText = nil;
    
    [super dealloc];
}

/*
 *  When necessary, reconfigure the labels to use proper dynamic type sizes.
 *  - NOTE: this custom cell is required for such a simple initial cell because the dynamic type behavior when moving from the background
 *          is highly unpredictable with the non-custom table view cells.   I think it is better to know what we're working with and control
 *          the entire experience.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL) isInit
{
    [UIAdvancedSelfSizingTools constrainTextLabel:lAboutText withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
}

@end
