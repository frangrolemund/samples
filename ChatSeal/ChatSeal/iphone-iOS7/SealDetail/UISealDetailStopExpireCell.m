//
//  UISealDetailStopExpireCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 12/8/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealDetailStopExpireCell.h"
#import "UIAdvancedSelfSizingTools.h"
#import "ChatSeal.h"

@implementation UISealDetailStopExpireCell
/*
 *  Object attributes
 */
{
    
}
@synthesize bSendIt;

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
    [bSendIt release];
    bSendIt = nil;
    
    [super dealloc];
}

/*
 *  Respond to dynamic type updates.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL)isInit
{
    [UIAdvancedSelfSizingTools constrainTextButton:self.bSendIt withPreferredSettingsAndTextStyle:UIFontTextStyleBody andMinimumSize:[ChatSeal minimumButtonFontSize] duringInitialization:isInit];
}
@end
