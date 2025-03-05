//
//  UISealExpirationCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/1/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealExpirationCell.h"

/*************************
 UISealExpirationCell
 *************************/
@implementation UISealExpirationCell
@synthesize lExpirationText;
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
    [lExpirationText release];
    lExpirationText = nil;
    
    [super dealloc];
}

/*
 *  When necessary, reconfigure the labels to use proper dynamic type sizes.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL) isInit
{
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lExpirationText withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
}
@end
