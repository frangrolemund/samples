//
//  UIPrivacyOverviewTableViewCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 12/3/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIPrivacyOverviewTableViewCell.h"
#import "UIAdvancedSelfSizingTools.h"
#import "ChatSeal.h"

/**********************************
 UIPrivacyOverviewTableViewCell
 **********************************/
@implementation UIPrivacyOverviewTableViewCell
/*
 *  Object attributes.
 */
{
    
}
@synthesize ivLogo;
@synthesize lTitle;
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
    [ivLogo release];
    ivLogo = nil;
    
    [lTitle release];
    lTitle = nil;
    
    [lDesc release];
    lDesc = nil;
    
    [super dealloc];
}

/*
 *  The cell was just loaded.
 */
-(void) awakeFromNib
{
    [super awakeFromNib];
    self.ivLogo.clipsToBounds      = YES;
    self.ivLogo.layer.borderWidth  = 0.5f;
    self.ivLogo.layer.borderColor  = [[UIColor colorWithWhite:0.85f alpha:1.0f] CGColor];
    self.ivLogo.layer.cornerRadius = 8.0f;
}

/*
 *  Layout the cell.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat width = CGRectGetWidth(self.bounds) - CGRectGetMinX(self.lDesc.frame) - 10.0f;
    if (width > 0.0f && (int) width != (int) self.lDesc.preferredMaxLayoutWidth) {
        self.lDesc.preferredMaxLayoutWidth = width;
        [self.lDesc invalidateIntrinsicContentSize];
        [self setNeedsLayout];
        [self layoutIfNeeded];
    }
}

/*
 *  Manage the dynamic type sizing.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL)isInit
{
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lTitle withPreferredSettingsAndTextStyle:UIFontTextStyleBody andSizeScale:[ChatSeal superDuperBodyFontScalingFactor] andMinimumSize:0.0f duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lDesc withPreferredSettingsAndTextStyle:UIFontTextStyleSubheadline duringInitialization:YES];
}

/*
 *  Return the optimal size for this cell.
 */
-(CGSize) systemLayoutSizeFittingSize:(CGSize)targetSize withHorizontalFittingPriority:(UILayoutPriority)horizontalFittingPriority verticalFittingPriority:(UILayoutPriority)verticalFittingPriority
{
    // - get one last layout in so that our constraints are updated if necessary.
    // - NOTE: This is to address a really irritating rotation problem where the right bounds
    //         aren't used for computing the layout size.   It is really unclear what the right behavior is here
    //         and as of 8.1 the self-sizing feature is half-baked.
    if ((int) CGRectGetWidth(self.contentView.bounds) != (int) CGRectGetWidth(self.bounds)) {
        [self layoutIfNeeded];
    }
    
    return [super systemLayoutSizeFittingSize:targetSize withHorizontalFittingPriority:horizontalFittingPriority verticalFittingPriority:verticalFittingPriority];
}

@end
