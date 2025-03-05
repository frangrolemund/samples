//
//  UIPendingPostStatusTableViewCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIPendingPostStatusTableViewCell.h"
#import "ChatSealPostedMessageProgress.h"

/*********************************
 UIPendingPostStatusTableViewCell
 *********************************/
@implementation UIPendingPostStatusTableViewCell
/*
 *  Object attributes.
 */
{
}
@synthesize lStatus;
@synthesize lDesc;

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
    [lStatus release];
    lStatus = nil;
    
    [lDesc release];
    lDesc = nil;
    
    [super dealloc];
}

/*
 *  Change the status content.
 */
-(void) refreshFromProgress:(ChatSealPostedMessageProgress *) prog
{
    NSString *lText = nil;
    if (prog) {
        if (prog.hasStarted) {
            if (prog.isCompleted) {
                lText = NSLocalizedString(@"Completed", nil);
            }
            else {
                int val = (int) (prog.progress * 100.0);
                lText   = [NSString stringWithFormat:@"%d%%", val];
            }
        }
        else {
            lText = NSLocalizedString(@"Not Started", nil);
        }
    }
    else {
        lText = NSLocalizedString(@"Deleted", nil);
    }
    lStatus.text = lText;
}

/*
 *  When necessary, reconfigure the labels to use proper dynamic type sizes.
 *  - NOTE: this custom cell is required for such a simple initial cell because the dynamic type behavior when moving from the background
 *          is highly unpredictable with the non-custom table view cells.   I think it is better to know what we're working with and control
 *          the entire experience.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL) isInit
{
    // - this has to resemble a button so we never want it to get too small.
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lDesc withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lStatus withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
}

@end
