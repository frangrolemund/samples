//
//  UIFeedsOverviewSharingTableViewCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/2/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIFeedsOverviewSharingTableViewCell.h"
#import "ChatSeal.h"

/************************************
 UIFeedsOverviewSharingTableViewCell
 ************************************/
@implementation UIFeedsOverviewSharingTableViewCell
/*
 *  Object attributes
 */
{
    
}
@synthesize lShareText;
@synthesize swSharing;
@synthesize bAuthorize;

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
    [lShareText release];
    lShareText = nil;
    
    [swSharing release];
    swSharing = nil;
    
    [bAuthorize release];
    bAuthorize = nil;
    [super dealloc];
}


/*
 *  When necessary, reconfigure the labels to use proper dynamic type sizes.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL) isInit
{
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lShareText withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextButton:self.bAuthorize withPreferredSettingsAndTextStyle:UIFontTextStyleSubheadline duringInitialization:isInit];
}

/*
 *  Reconfigure the state of the controls based on how things are shared.
 */
-(void) reconfigureSharingState
{
    if ([ChatSeal hasPresentedFeedShareWarning]) {
        swSharing.hidden   = NO;
        swSharing.enabled  = YES;
        [swSharing setOn:[ChatSeal canShareFeedsDuringExchanges]];
        bAuthorize.hidden  = YES;
        bAuthorize.enabled = NO;
    }
    else {
        swSharing.hidden   = YES;
        swSharing.enabled  = NO;
        [swSharing setOn:NO];
        bAuthorize.hidden  = NO;
        bAuthorize.enabled = YES;
    }
}
@end
