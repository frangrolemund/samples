//
//  UIFeedSelectionTableViewCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 4/30/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIFeedSelectionTableViewCell.h"
#import "ChatSeal.h"
#import "ChatSealFeed.h"
#import "UIFormattedTwitterFeedAddressView.h"
#import "UIFeedsOverviewTableViewCell.h"

// - constants
static const CGFloat UIFSTV_STD_STATUS_HEIGHT = 14.0f;              //  match the status in the feed overview table cell.

// - forward declarations
@interface UIFeedSelectionTableViewCell (internal)
+(UIEdgeInsets) standardInsets;
-(void) setTitleColorForCurrentContent;
-(void) releaseCurrentAddress;
-(UIEdgeInsets) myInsets;
@end

/****************************
 UIFeedSelectionTableViewCell
 ****************************/
@implementation UIFeedSelectionTableViewCell
/*
 *  Object attributes.
 */
{
    BOOL                        isActive;
    BOOL                        isGoodForSelection;
    UIFormattedFeedAddressView  *ffavAddress;
    NSString                    *lastFeedType;
    UILabel                     *lStatusDisplay;
}

/*
 *  All selection cells have the same height.
 */
+(CGFloat) standardRowHeight
{
    return 64.0f;
}

/*
 *  Initialize the object.
 */
-(id) initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        isGoodForSelection  = NO;
        
        lStatusDisplay                 = [[UILabel alloc] init];
        lStatusDisplay.backgroundColor = [UIColor whiteColor];
        lStatusDisplay.font            = [UIFont systemFontOfSize:UIFSTV_STD_STATUS_HEIGHT];
        [self.contentView addSubview:lStatusDisplay];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [lStatusDisplay release];
    lStatusDisplay = nil;
    
    [self releaseCurrentAddress];
    
    [super dealloc];
}

/*
 *  Prepare to reuse this cell for another purpose.
 */
-(void) prepareForReuse
{
    [super prepareForReuse];
    [self releaseCurrentAddress];
    lStatusDisplay.text = nil;
    isActive            = NO;
}

/*
 *  Use the feed to specify the content in the cell.
 */
-(void) reconfigureCellWithFeed:(ChatSealFeed *) feed withAnimation:(BOOL) animated
{
    // - we may very well get more updates than we need, so we aren't going to change anything
    //   unless something actually changed.
    NSString *status   = [feed statusText];
    BOOL curIsGood     = [feed isViableMessagingTarget];
    NSString *feedType = [feed typeId];
    if ([feedType isEqualToString:lastFeedType] &&
        curIsGood == isGoodForSelection &&
        [status isEqualToString:lStatusDisplay.text]) {
        return;
    }
    
    // - Ok, something is different, so start changing the items.
    if (animated) {
        UIView *vwSnap                = [self.contentView snapshotViewAfterScreenUpdates:YES];
        vwSnap.userInteractionEnabled = NO;         //  essential or we'll get a tap-delay during the animation.
        [self.contentView addSubview:vwSnap];
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            vwSnap.alpha = 0.0f;
        }completion:^(BOOL finished) {
            [vwSnap removeFromSuperview];
        }];
    }
    
    isGoodForSelection = curIsGood;
    if (![feedType isEqualToString:lastFeedType]) {
        [self releaseCurrentAddress];
        lastFeedType = [feedType retain];
        ffavAddress  = [[feed addressView] retain];
        [ffavAddress setAddressFontHeight:[ChatSealFeed standardFontHeightForSelection]];
        [self.contentView addSubview:ffavAddress];
    }
    [self setTitleColorForCurrentContent];
    
    // - set the status text color
    if ([feed isInWarningState]) {
        if ([feed isEnabled]) {
            lStatusDisplay.textColor = [ChatSeal defaultWarningColor];
        }
        else {
            lStatusDisplay.textColor = [UIColor lightGrayColor];
        }
    }
    else {
        lStatusDisplay.textColor = [UIColor darkGrayColor];        
    }
    
    // - set the status text.
    if (!status) {
        status = [feed localizedMessagesExchangedText];
    }
    lStatusDisplay.text = status;
}

/*
 *  Lay out the content.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    CGSize sz           = self.contentView.bounds.size;
    UIEdgeInsets insets = [self myInsets];
    if (insets.top + insets.bottom > sz.height) {
        return;
    }
    
    CGRect rcHeader   = CGRectIntegral(CGRectMake(insets.left, insets.top, sz.width - (insets.left + insets.right), 21.0f));
    [lStatusDisplay sizeToFit];
    CGRect rcFooter   = CGRectMake(insets.left, CGRectGetMaxY(rcHeader) + 3.0f, sz.width - (insets.left + insets.right), CGRectGetHeight(lStatusDisplay.bounds));
    
    ffavAddress.frame = rcHeader;
    
    [ffavAddress layoutIfNeeded];
    CGFloat offset       = CGRectGetMinX(ffavAddress.addressLabel.frame) + 2.0f;
    rcFooter.origin.x   += offset;
    rcFooter.size.width -= offset;
    lStatusDisplay.frame = rcFooter;
}

/*
 *  This convenience flag allows us to quickly check if the cell is acceptable for a feed target.
 */
-(BOOL) isGoodForSelection
{
    return isGoodForSelection;
}

/*
 *  In cases where there is already a feed selected, we want to display it a little differently to
 *  highlight it.
 */
-(void) setActiveFeedEnabled:(BOOL) isEnabled
{
    isActive = isEnabled;
    [self setTitleColorForCurrentContent];
}

/*
 *  Adjust the content in the cell to support dynamic type.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL)isInit
{
    [ffavAddress updateDynamicTypeNotificationReceived];
    [UIAdvancedSelfSizingTools constrainTextLabel:lStatusDisplay withPreferredSettingsAndTextStyle:UIFontTextStyleSubheadline duringInitialization:isInit];
    [self setNeedsLayout];
}

/*
 *  Don't automatically create the cell height constraint.
 */
-(BOOL) shouldCreateHeightConstraint
{
    return NO;
}

/*
 *  Return the required size of the cell.
 */
-(CGSize) sizeThatFits:(CGSize)size
{
    [super sizeThatFits:size];          //  force a reconfig.
    [self layoutIfNeeded];
    CGFloat maxY = CGRectGetMaxY(lStatusDisplay.frame);
    return CGSizeMake(size.width, maxY + [self myInsets].bottom);
}

@end

/***************************************
 UIFeedSelectionTableViewCell (internal)
 ***************************************/
@implementation UIFeedSelectionTableViewCell (internal)
/*
 *  The insets are used to lay out content in this cell.
 */
+(UIEdgeInsets) standardInsets
{
    return UIEdgeInsetsMake(8.0f, 20.0f, 8.0f, 20.0f);
}

/*
 *  Return edge insets that make sense.
 */
-(UIEdgeInsets) myInsets
{
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        // - when we're using advanced sizing, we'll pad based on the font.
        CGFloat height = lStatusDisplay.font.lineHeight;
        return UIEdgeInsetsMake(height/2.0f, 20.0f, height, 20.0f);
    }
    else {
        return [UIFeedSelectionTableViewCell standardInsets];
    }
}

/*
 *  Assign the title color.
 */
-(void) setTitleColorForCurrentContent
{
    if (isGoodForSelection) {
        if (isActive) {
            [ffavAddress setTextColor:[ChatSeal defaultSelectedHeaderColor]];
        }
        else {
            [ffavAddress setTextColor:[UIColor blackColor]];
        }
    }
    else {
        [ffavAddress setTextColor:[UIColor lightGrayColor]];
    }
}

/*
 *  Release the current address content.
 */
-(void) releaseCurrentAddress
{
    [ffavAddress removeFromSuperview];
    [ffavAddress release];
    ffavAddress = nil;
    
    [lastFeedType release];
    lastFeedType = nil;
}
@end

