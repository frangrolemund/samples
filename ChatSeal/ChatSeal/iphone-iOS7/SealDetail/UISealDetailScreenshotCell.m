//
//  UISealDetailScreenshotCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/16/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealDetailScreenshotCell.h"
#import "ChatSeal.h"

/****************************
 UISealDetailScreenshotCell
 ****************************/
@implementation UISealDetailScreenshotCell
/*
 *  Object attributes
 */
{
    BOOL isEnabled;
}
@synthesize lAfterScreenShot;
@synthesize lScreenShotEnabled;

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        isEnabled = NO;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [lAfterScreenShot release];
    lAfterScreenShot = nil;
    
    [lScreenShotEnabled release];
    lScreenShotEnabled = nil;
    
    [super dealloc];
}

/*
 *  Assign the identity and set the flag.
 */
-(void) setIdentity:(ChatSealIdentity *) psi
{
    isEnabled = [psi isRevocationOnScreenshotEnabledWithError:nil];
    [self setNeedsLayout];
}

/*
 *  Perform layout activities.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    NSString *sEnabled = nil;
    if (isEnabled) {
        sEnabled = NSLocalizedString(@"ON", nil);
    }
    else {
        sEnabled = NSLocalizedString(@"OFF", nil);
    }
    lScreenShotEnabled.text = sEnabled;
}

/*
 *  When necessary, reconfigure the labels to use proper dynamic type sizes.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL) isInit
{
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lAfterScreenShot withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lScreenShotEnabled withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
}

@end
