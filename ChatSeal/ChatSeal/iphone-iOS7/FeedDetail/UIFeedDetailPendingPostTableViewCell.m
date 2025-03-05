//
//  UIFeedDetailPendingPostTableViewCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/24/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIFeedDetailPendingPostTableViewCell.h"
#import "ChatSealPostedMessageProgress.h"
#import "ChatSeal.h"
#import "ChatSealMessage.h"

// - forward declarations
@interface UIFeedDetailPendingPostTableViewCell (internal)
-(void) discardProgress;
@end

/****************************************
 UIFeedDetailPendingPostTableViewCell
 ****************************************/
@implementation UIFeedDetailPendingPostTableViewCell
/*
 *  Object attributes.
 */
{
    UIProgressView *pvProgress;
}
@synthesize ivSeal;
@synthesize lDescription;
@synthesize lcImgHeight;

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        pvProgress = nil;
    }
    return self;
}

/*
 *  This object was just loaded.
 */
-(void) awakeFromNib
{
    // - under 8.0, we're going to change our approach slightly for how we size the status line because it
    //   might become multi-line due to the self-sizing.
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        // - NOTE: this won't work under 7.1 because the automatic preferred width is not available.
        // - ALSO: this has to be done here before the layout engine begins thinking about how to size the
        //         heights, which means we need to grab item before its content contributes to
        //         the first display of the table view and its self-sizing analysis.
        self.lDescription.numberOfLines = 0;
        
        // - the seal image should be slightly larger to look good against the large text, but not
        //   too big.
        lcImgHeight.constant = 48.0f;
    }
    
    // - add a constraint so that the image stays square
    NSLayoutConstraint *constraint = [NSLayoutConstraint constraintWithItem:self.ivSeal attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.ivSeal attribute:NSLayoutAttributeHeight multiplier:1.0f constant:0.0f];
    [self.contentView addConstraint:constraint];
}


/*
 *  Free the object.
 */
-(void) dealloc
{
    [ivSeal release];
    ivSeal = nil;
    
    [lDescription release];
    lDescription = nil;
    
    [pvProgress release];
    pvProgress = nil;
    
    [lcImgHeight release];
    lcImgHeight = nil;
    
    [super dealloc];
}

/*
 *  Prepare to reuse the cell.
 */
-(void) prepareForReuse
{
    ivSeal.image      = nil;
    lDescription.text = nil;
    [self discardProgress];
}

/*
 *  Configure this item for display.
 */
-(void) reconfigureWithProgress:(ChatSealPostedMessageProgress *) prog
{
    ChatSealMessage *csm = [ChatSeal messageForId:prog.messageId];
    ivSeal.image         = csm.sealTableImage;
    lDescription.text    = prog.msgDescription;
    [self setCurrentProgress:prog.progress withAnimation:NO];
}

/*
 *  Set the progres on the item.
 */
-(void) setCurrentProgress:(double) progress withAnimation:(BOOL) animated
{
    // - don't bother showing it if there is nothing to display.
    if (progress > 0.0) {
        if ((int) progress == 1) {
            [self discardProgress];
        }
        else {
            if (!pvProgress) {
                pvProgress       = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
                CGSize sz        = [pvProgress sizeThatFits:CGSizeMake(CGRectGetWidth(self.contentView.frame), 1.0f)];
                pvProgress.frame = CGRectMake(0.0f, CGRectGetHeight(self.contentView.frame) - sz.height, sz.width, sz.height);
                pvProgress.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
                [self.contentView addSubview:pvProgress];
            }
            [pvProgress setProgress:(float) progress animated:animated];
        }
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
    UIFont *font           = [UIAdvancedSelfSizingTools constrainedFontForPreferredSettingsAndTextStyle:UIFontTextStyleBody];
    font                   = [UIFont italicSystemFontOfSize:font.pointSize];
    self.lDescription.font = font;
    [self.lDescription invalidateIntrinsicContentSize];
}
@end


/*************************************************
 UIFeedDetailPendingPostTableViewCell (internal)
 *************************************************/
@implementation UIFeedDetailPendingPostTableViewCell (internal)
/*
 *  Discard the progress bar when it is no longer useful.
 */
-(void) discardProgress
{
    // - don't retain a progress meter if it isn't going to be used right away.
    [pvProgress removeFromSuperview];
    [pvProgress release];
    pvProgress = nil;
}
@end