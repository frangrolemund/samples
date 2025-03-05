//
//  UISealVaultPrivacyCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 12/5/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealVaultPrivacyCell.h"

/******************************
 UISealVaultPrivacyCell
 ******************************/
@implementation UISealVaultPrivacyCell
/*
 *  Object attributes.
 */
{
    
}
@synthesize lPrivacyText;

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
    [lPrivacyText release];
    lPrivacyText = nil;
    
    [super dealloc];
}

/*
 *  Ensure the label respects dynamic type.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL)isInit
{
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lPrivacyText withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
}

@end
