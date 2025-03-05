//
//  UISealDetailNameCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/15/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealDetailNameCell.h"
#import "ChatSeal.h"

// - forward declarations
@interface UISealDetailNameCell (internal) <UITextFieldDelegate>
-(void) commonConfiguration;
-(void) releaseIdentity;
@end

/****************************
 UISealDetailNameCell
 ****************************/
@implementation UISealDetailNameCell
/*
 *  Object attributes
 */
{
    ChatSealIdentity *sealIdentity;
}
@synthesize tfName;

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
 *  The cell was just loaded.
 */
-(void) awakeFromNib
{
    [super awakeFromNib];
    self.tfName.keyboardType = UIKeyboardTypeAlphabet;          //  we should be writing names, not weird symbolic stuff.
}

/*
 *  Free this object.
 */
-(void) dealloc
{
    
    tfName.delegate = nil;
    [tfName release];
    tfName = nil;

    [self releaseIdentity];
    [super dealloc];
}

/*
 *  If the text field isn't wired up yet, do so now.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    if (!tfName.delegate) {
        tfName.delegate = self;
        if (sealIdentity) {
            tfName.text = [sealIdentity ownerName];
        }
        [self updateNameForActivityState];
    }
}

/*
 *  This object retains the identity so that it can
 *  modify it directly as changes occur.
 */
-(void) setIdentity:(ChatSealIdentity *) psi
{
    if (sealIdentity != psi) {
        [sealIdentity release];
        sealIdentity = [psi retain];
        if (tfName) {
            tfName.text = [sealIdentity ownerName];
        }
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
 *  Change cell color based on activity.
 */
-(void) updateNameForActivityState
{
    if (sealIdentity.isActive) {
        tfName.textColor = [ChatSeal defaultSelectedHeaderColor];
    }
    else {
        tfName.textColor = [UIColor blackColor];
    }
}

/*
 *  When necessary, reconfigure the labels to use proper dynamic type sizes.
 *  - NOTE: this custom cell is required for such a simple initial cell because the dynamic type behavior when moving from the background
 *          is highly unpredictable with the non-custom table view cells.   I think it is better to know what we're working with and control
 *          the entire experience.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL) isInit
{
    [UIAdvancedSelfSizingTools constrainTextField:self.tfName withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
}

@end

/********************************
 UISealDetailNameCell (internal)
 ********************************/
@implementation UISealDetailNameCell (internal)
/*
 *  Configure this object.
 */
-(void) commonConfiguration
{
    sealIdentity = nil;
}

/*
 *  Free the attached identity.
 */
-(void) releaseIdentity
{
    [sealIdentity release];
    sealIdentity = nil;
}

/*
 *  When this cell is done editing, ensure that we retain the updated name.
 */
-(void) textFieldDidEndEditing:(UITextField *)textField
{
    NSString *name = textField.text;
    if (![name length]) {
        name = nil;
    }
    [sealIdentity setOwnerName:name ifBeforeDate:nil];
}

/*
 *  Resign the first responder when the return key is pressed.
 */
-(BOOL) textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

@end
