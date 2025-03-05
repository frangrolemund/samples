//
//  UISealDetailActiveCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/15/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealDetailActiveCell.h"
#import "ChatSeal.h"
#import "AlertManager.h"

// - forward declarations
@interface UISealDetailActiveCell (internal)
-(void) commonConfiguration;
-(void) releaseIdentity;
-(void) switchChanged:(UISwitch *) vwSwitch;
-(void) synchIdentityToSwitch;
@end

/***************************
 UISealDetailActiveCell
 ***************************/
@implementation UISealDetailActiveCell
/*
 *  Object attributes
 */
{
    ChatSealIdentity *sealIdentity;
    BOOL              wiredToSwitch;
}
@synthesize lActiveText;
@synthesize swActive;
@synthesize delegate;

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonConfiguration];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [lActiveText release];
    lActiveText = nil;
    
    [swActive release];
    swActive = nil;
    
    delegate = nil;
    [self releaseIdentity];
    [super dealloc];
}

/*
 *  Layout content.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    if (!wiredToSwitch) {
        [swActive addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        wiredToSwitch = YES;
    }
    [self synchIdentityToSwitch];
}

/*
 *  Assign the identity so that this cell can manage itself.
 */
-(void) setIdentity:(ChatSealIdentity *) psi
{
    if (sealIdentity != psi) {
        [sealIdentity release];
        sealIdentity = [psi retain];
        [self synchIdentityToSwitch];
    }
}

/*
 *  Prepare to reuse this cell.
 */
-(void) prepareForReuse
{
    [super prepareForReuse];
    [self releaseIdentity];
}

/*
 *  When necessary, reconfigure the labels to use proper dynamic type sizes.
 *  - NOTE: this custom cell is required for such a simple initial cell because the dynamic type behavior when moving from the background
 *          is highly unpredictable with the non-custom table view cells.   I think it is better to know what we're working with and control
 *          the entire experience.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL) isInit
{
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lActiveText withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
}

@end

/**********************************
 UISealDetailActiveCell (internal)
 **********************************/
@implementation UISealDetailActiveCell (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    wiredToSwitch = NO;
    sealIdentity  = nil;
    delegate      = nil;
}

/*
 *  Free the identity object.
 */
-(void) releaseIdentity
{
    [sealIdentity release];
    sealIdentity = nil;
}

/*
 *  Make sure the switch reflects the identity.
 */
-(void) synchIdentityToSwitch
{
    swActive.on = [sealIdentity isActive];
}

/*
 *  The switch has been moved.
 */
-(void) switchChanged:(UISwitch *) vwSwitch
{
    NSError *err = nil;
    if ([sealIdentity setActive:vwSwitch.on withError:&err]) {
        if (delegate && [delegate respondsToSelector:@selector(activeCellModifiedActivity:)]) {
            [delegate performSelector:@selector(activeCellModifiedActivity:) withObject:self];
        }
    }
    else {
        [swActive setOn:sealIdentity.isActive animated:YES];
        [AlertManager displayFatalAlertWithLowSpaceDetectionUsingTitle:NSLocalizedString(@"Seal Update Interrupted", nil)
                                                               andText:NSLocalizedString(@"Your %@ was unable to assign a primary chat seal due to an unexpected error.", nil)];
    }
}
@end

