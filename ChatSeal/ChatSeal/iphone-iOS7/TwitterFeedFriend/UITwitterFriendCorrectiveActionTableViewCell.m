//
//  UITwitterFriendCorrectiveActionTableViewCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UITwitterFriendCorrectiveActionTableViewCell.h"
#import "UIAdvancedSelfSizingTools.h"
#import "ChatSeal.h"

/********************************************
 UITwitterFriendCorrectiveActionTableViewCell
 ********************************************/
@implementation UITwitterFriendCorrectiveActionTableViewCell
/*
 *  Object attributes.
 */
{
    
}
@synthesize bCorrectiveAction;

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
 *  Free the Object
 */
-(void) dealloc
{
    [bCorrectiveAction release];
    bCorrectiveAction = nil;
    
    [super dealloc];
}

/*
 *  Reconfigure for dynamic type.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL)isInit
{
    [UIAdvancedSelfSizingTools constrainTextButton:self.bCorrectiveAction withPreferredSettingsAndTextStyle:UIFontTextStyleBody andMinimumSize:[ChatSeal minimumButtonFontSize]
                              duringInitialization:isInit];
}

@end
