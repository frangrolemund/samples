//
//  UIPendingPostDiscardTableViewCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/26/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIPendingPostDiscardTableViewCell.h"
#import "ChatSeal.h"

/************************************
 UIPendingPostDiscardTableViewCell
 ************************************/
@implementation UIPendingPostDiscardTableViewCell
/*
 *  Object attributes
 */
{
}
@synthesize lDiscard;

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
    [lDiscard release];
    lDiscard = nil;
    
    [super dealloc];
}

/*
 *  One-time configuration.
 */
-(void) awakeFromNib
{
    // - just make sure the color stays in synch with the official source.
    lDiscard.textColor = [ChatSeal defaultAppSeriousActionColor];
}

/*
 *  When necessary, reconfigure the labels to use proper dynamic type sizes.
 *  - NOTE: this custom cell is required for such a simple initial cell because the dynamic type behavior when moving from the background
 *          is highly unpredictable with the non-custom table view cells.   I think it is better to know what we're working with and control
 *          the entire experience.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL) isInit
{
    // - this has to resemble a button so we never want it to get too small.
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lDiscard withPreferredSettingsAndTextStyle:UIFontTextStyleBody andMinimumSize:[ChatSeal minimumButtonFontSize] duringInitialization:isInit];
}
@end
