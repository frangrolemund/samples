//
//  UIGenericSizableTableViewCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 9/30/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIGenericSizableTableViewCell.h"
#import "ChatSeal.h"

// - forward declarations
@interface UIGenericSizableTableViewCell (internal)
-(void) _base_commonConfiguration;
-(void) checkForReconfigureLabelsForDynamicTypeDuringInit:(BOOL) isInit;
@end

/***********************************
 UIGenericSizableTableViewCell
 ***********************************/
@implementation UIGenericSizableTableViewCell
/*
 *  Object attributes.
 */
{
    BOOL hasBeenInitiallySized;    
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self _base_commonConfiguration];
    }
    return self;
}

/*
 *  Initialize the object.
 */
-(id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self _base_commonConfiguration];
    }
    return self;
}

/*
 *  When this cell is moving to a new superview,
 */
-(void) willMoveToSuperview:(UIView *)newSuperview
{
    [super willMoveToSuperview:newSuperview];

    // - because of the way that layout is performed, we'll do
    //   one more round here.
    if (!hasBeenInitiallySized && !self.superview && newSuperview) {
        [self checkForReconfigureLabelsForDynamicTypeDuringInit:YES];
        hasBeenInitiallySized = YES;
    }
}

/*
 *  A dynamic type notification has been received.
 */
-(void) updateDynamicTypeNotificationReceived
{
    [self checkForReconfigureLabelsForDynamicTypeDuringInit:NO];
}

/*
 *  This method is called by the table view to size a cell with autolayout.
 */
-(CGSize) systemLayoutSizeFittingSize:(CGSize)targetSize withHorizontalFittingPriority:(UILayoutPriority)horizontalFittingPriority verticalFittingPriority:(UILayoutPriority)verticalFittingPriority
{
    // - the self sizing code uses this method to compute the height of the content, but for some content - like
    //   multi-line labels that adjsut their height, we need to be sure the fonts are updated _before_ the height
    //   is computed or the layout will lag behind the dimensions.
    [self checkForReconfigureLabelsForDynamicTypeDuringInit:!hasBeenInitiallySized];
    return [super systemLayoutSizeFittingSize:targetSize withHorizontalFittingPriority:horizontalFittingPriority verticalFittingPriority:verticalFittingPriority];
}

/*
 *  This method is called by the table view to size a cell with manual layout.
 */
-(CGSize) sizeThatFits:(CGSize)size
{
    // - the self sizing code uses this method to compute the height of the content, but for some content - like
    //   multi-line labels that adjsut their height, we need to be sure the fonts are updated _before_ the height
    //   is computed or the layout will lag behind the dimensions.
    [self checkForReconfigureLabelsForDynamicTypeDuringInit:!hasBeenInitiallySized];
    return [super sizeThatFits:size];
}

/*
 *  We're going to reuse this cell.
 */
-(void) prepareForReuse
{
    [super prepareForReuse];
    
    // - make sure it is styled before it is used again
    hasBeenInitiallySized = NO;
}
@end

/*******************************************
 UIGenericSizableTableViewCell (internal)
 *******************************************/
@implementation UIGenericSizableTableViewCell (internal)
/*
 *  Configure the cell.
 */
-(void) _base_commonConfiguration
{
    hasBeenInitiallySized = NO;
    
    // - when we're using advanced self-sizing and the cell is not using manual layout.
    if ([ChatSeal isAdvancedSelfSizingInUse] && (![self respondsToSelector:@selector(shouldCreateHeightConstraint)] || [self shouldCreateHeightConstraint])) {
        // - never allow the cell to diminish below a touchable height.
        NSLayoutConstraint *constraint = [NSLayoutConstraint constraintWithItem:self.contentView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0f constant:[ChatSeal minimumTouchableDimension]];
        [self addConstraint:constraint];
    }
}

/*
 *  When necessary, reconfigure the labels to use proper dynamic type sizes.
 */
-(void) checkForReconfigureLabelsForDynamicTypeDuringInit:(BOOL) isInit
{
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        return;
    }
    
    // - if this isn't a time when sizing needs to be adjusted, just ignore
    if (hasBeenInitiallySized && ![UIAdvancedSelfSizingTools isInSizeChangeNotification]) {
        return;
    }
    
    // - when the custom protocol is implemented use that one for reconfiguration, otherwise,
    //   we'll just assume this is a standard cell.
    if ([self respondsToSelector:@selector(reconfigureLabelsForDynamicTypeDuringInit:)]) {
        [self reconfigureLabelsForDynamicTypeDuringInit:isInit];
    }
    else {
        [UIAdvancedSelfSizingTools constrainTextLabel:self.textLabel withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
        [UIAdvancedSelfSizingTools constrainTextLabel:self.detailTextLabel withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
    }
}
@end