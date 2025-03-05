//
//  UISealDetailInactiveCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/15/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealDetailInactiveCell.h"
#import "ChatSeal.h"

/***************************
 UISealDetailInactiveCell
 ***************************/
@implementation UISealDetailInactiveCell
/*
 *  Object attributes.
 */
{
}
@synthesize lInactiveText;

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
    [lInactiveText release];
    lInactiveText = nil;
    
    [super dealloc];
}

/*
 *  Use the provided identity to configure this seal.
 */
-(void) setIdentity:(ChatSealIdentity *) psi
{
    NSUInteger numDays   = [psi sealExpirationTimoutInDaysWithError:nil];
    NSString *sToDisplay = nil;
    if (numDays == 1) {
        sToDisplay = NSLocalizedString(@"When Inactive for 1 Day.", nil);
    }
    else {
        sToDisplay = [NSString stringWithFormat:NSLocalizedString(@"When Inactive for %u Days.", nil), numDays];
    }
    self.lInactiveText.text = sToDisplay;
}

/*
 *  When necessary, reconfigure the labels to use proper dynamic type sizes.
 *  - NOTE: this custom cell is required for such a simple initial cell because the dynamic type behavior when moving from the background
 *          is highly unpredictable with the non-custom table view cells.   I think it is better to know what we're working with and control
 *          the entire experience.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL) isInit
{
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lInactiveText withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
}

@end
