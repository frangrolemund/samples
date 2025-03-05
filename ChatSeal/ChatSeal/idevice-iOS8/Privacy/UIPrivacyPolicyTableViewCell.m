//
//  UIPrivacyPolicyTableViewCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 12/3/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIPrivacyPolicyTableViewCell.h"

/****************************
 UIPrivacyPolicyTableViewCell
 ****************************/
@implementation UIPrivacyPolicyTableViewCell
/*
 *  Object attributes.
 */
{
    
}
@synthesize lText;

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
    [lText release];
    lText = nil;
    
    [super dealloc];
}


/*
 *  Manage the dynamic type sizing.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL)isInit
{
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lText withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:YES];
}

@end
