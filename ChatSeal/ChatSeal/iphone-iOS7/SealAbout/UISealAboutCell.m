//
//  UISealAboutCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/16/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealAboutCell.h"
#import "ChatSeal.h"
#import "UIGenericSizableTableViewCell.h"

// - forward declarations
@interface UISealAboutCell (internal)
@end

/***********************
 UISealAboutCell
 ***********************/
@implementation UISealAboutCell
@synthesize lDescription;
@synthesize lValue;

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
    [lDescription release];
    lDescription = nil;
    
    [lValue release];
    lValue = nil;
    
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
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lDescription withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lValue withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
}

@end

/*****************************
 UISealAboutCell (internal)
 *****************************/
@implementation UISealAboutCell (internal)
@end