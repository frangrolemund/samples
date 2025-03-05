//
//  UIPrivacyItemTableViewCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 12/3/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIPrivacyItemTableViewCell.h"
#import "ChatSeal.h"
#import "UIPrivacyAccessoryView.h"

// - constants
static const CGFloat UIPVI_TVC_MIN_BOTTOM_PAD = 9.0f;
static const CGFloat UIPVI_TVC_MIN_PREF_WIDTH = 100;

// - forward declarations
@interface UIPrivacyItemTableViewCell (internal)
@end

/******************************
 UIPrivacyItemTableViewCell
 ******************************/
@implementation UIPrivacyItemTableViewCell
/*
 *  Object attributes.
 */
{
    BOOL     isDescriptionVisible;
    NSString *desc;
    CGFloat  descriptionBottomConstant;
}
@synthesize lTitle;
@synthesize lDescription;
@synthesize lcDescriptionBottom;

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        desc                      = nil;
        isDescriptionVisible      = NO;
        descriptionBottomConstant = 0.0f;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [lTitle release];
    lTitle = nil;
    
    [lDescription release];
    lDescription = nil;
    
    [lcDescriptionBottom release];
    lcDescriptionBottom = nil;
    
    [desc release];
    desc = nil;
    
    [super dealloc];
}

/*
 *  The cell has just been loaded.
 */
-(void) awakeFromNib
{
    [super awakeFromNib];
    self.lTitle.text                  = nil;
    self.lDescription.text            = nil;
    descriptionBottomConstant         = self.lcDescriptionBottom.constant;
    self.lcDescriptionBottom.constant = 0.0f;
    self.clipsToBounds                = YES;
    UIPrivacyAccessoryView *pav       = [[[UIPrivacyAccessoryView alloc] init] autorelease];
    [pav sizeToFit];
    self.accessoryView                = pav;
    [(UIPrivacyAccessoryView *) self.accessoryView setDisplayAsOpen:NO withAnimation:NO];
}

/*
 *  Prepare to reuse the cell.
 */
-(void) prepareForReuse
{
    [super prepareForReuse];
    [desc release];
    desc = nil;
    
    lTitle.text          = nil;
    lDescription.text    = nil;
    isDescriptionVisible = NO;
    [(UIPrivacyAccessoryView *) self.accessoryView setDisplayAsOpen:NO withAnimation:NO];
}

/*
 *  Layout the cell.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    // - this is a good time to update the preferred widths
    // - NOTE: I hate the magic number below, but I'm not sure why during some rotations we get really small
    //         cells.   If you scroll to the bottom and then rotate to landscape and back, you'll get instances of these really
    //         narrow cells, which completely hose up the preferred max layout width, which then hoses up the height calculation
    //         below.
    BOOL shouldUpdate = NO;
    CGFloat width = CGRectGetWidth(self.lTitle.frame);
    if ((int) width != (int) self.lTitle.preferredMaxLayoutWidth && width > UIPVI_TVC_MIN_PREF_WIDTH) {
        self.lTitle.preferredMaxLayoutWidth = width;
        [self.lTitle invalidateIntrinsicContentSize];
        shouldUpdate = YES;
    }
    width = CGRectGetWidth(self.lDescription.frame);
    if ((int) width != (int) self.lDescription.preferredMaxLayoutWidth && width > UIPVI_TVC_MIN_PREF_WIDTH) {
        self.lDescription.preferredMaxLayoutWidth = width;
        [self.lDescription invalidateIntrinsicContentSize];
        shouldUpdate = YES;
    }
    
    // - when we invalidate constraints, make sure we re-layout right away so that the height
    //   is computed correctly in some scenarios (mainly rotation).
    if (shouldUpdate) {
        [self layoutIfNeeded];
    }
}

/*
 *  Assign the title and description text.
 */
-(void) setTitle:(NSString *) title andDescription:(NSString *) description
{
    lTitle.text = title;
    if (desc != description) {
        [desc release];
        desc = [description retain];
    }
}

/*
 *  Display the description in the cell.
 */
-(void) setDisplayDescription:(BOOL) visible
{
    if (visible) {
        self.lDescription.text            = desc;
        lcDescriptionBottom.constant = descriptionBottomConstant;
    }
    else {
        UIView *vwSnap               = [lDescription snapshotViewAfterScreenUpdates:YES];
        vwSnap.frame                 = lDescription.frame;
        [self.contentView addSubview:vwSnap];
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime]/2.011f animations:^(void) {
            vwSnap.alpha = 0.0f;
        }completion:^(BOOL finished) {
            [vwSnap removeFromSuperview];
        }];
        lDescription.text            = nil;
        lcDescriptionBottom.constant = 0.0f;
    }
    isDescriptionVisible = YES;
    [lDescription setNeedsUpdateConstraints];
    [self setNeedsUpdateConstraints];
    
    // - this is to ensure the text is in the right place the first time we expand.
    if (visible) {
        [self setNeedsLayout];
        [self layoutIfNeeded];
    }

    [(UIPrivacyAccessoryView *) self.accessoryView setDisplayAsOpen:visible withAnimation:YES];
}

/*
 *  This method is used by prior releases before 8.0 to compute the ideal row height.
 */
-(CGFloat) recommendedHeightForRowOfWidth:(CGFloat) width
{
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        return 0.0f;
    }
    width    -= 20.0f;              //  remove the space for the accessory view.
    width    -= CGRectGetMinY(lTitle.frame);
    CGSize sz = [self.lTitle sizeThatFits:CGSizeMake(width, 1.0f)];
    CGFloat height = CGRectGetMinY(lTitle.frame) + sz.height;
    height        += CGRectGetMinY(lDescription.frame) - CGRectGetMaxY(lTitle.frame);
    if (isDescriptionVisible) {
        width  -= CGRectGetMinY(lDescription.frame) - CGRectGetMinY(lTitle.frame);
        sz      = [self.lDescription sizeThatFits:CGSizeMake(width, 1.0f)];
        height += sz.height;
        height += descriptionBottomConstant;
    }
    else {
        height += UIPVI_TVC_MIN_BOTTOM_PAD;
    }
    return height;
}

/*
 *  Manage the dynamic type sizing.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL)isInit
{
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lTitle withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:YES];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lDescription withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:YES];
}

/*
 *  Compute the right size for the cell.
 */
-(CGSize) systemLayoutSizeFittingSize:(CGSize)targetSize withHorizontalFittingPriority:(UILayoutPriority)horizontalFittingPriority verticalFittingPriority:(UILayoutPriority)verticalFittingPriority
{
    // - rotation is a big fucking mess with self-sizing cells.  There are cases where it asks for the layout size without first actually changing the dimensions of the
    //   cell, which ends up screwing me here because I need my text to push the cell upward.  If we see one of these bizarro scenarios, we need to force a quick layout
    //   so that we can get the right dimensions.
    if (targetSize.width < CGRectGetWidth(self.bounds)) {
        self.bounds = CGRectMake(0.0f, 0.0f, targetSize.width, CGRectGetHeight(self.bounds));
    }
    [self layoutIfNeeded];
    return [super systemLayoutSizeFittingSize:targetSize withHorizontalFittingPriority:horizontalFittingPriority verticalFittingPriority:verticalFittingPriority];
}

/*
 *  Return the height of the description text to the very bottom.
 */
-(CGFloat) descriptionHeight
{
    if (isDescriptionVisible) {
        return CGRectGetHeight(self.contentView.bounds) - CGRectGetMinY(self.lDescription.frame);
    }
    else {
        return 0.0f;
    }
}
@end

/**************************************
 UIPrivacyItemTableViewCell (internal)
 **************************************/
@implementation UIPrivacyItemTableViewCell (internal)
@end