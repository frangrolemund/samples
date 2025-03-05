//
//  UITwitterLocalFeedTableViewCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/23/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UITwitterLocalFeedTableViewCell.h"
#import "ChatSeal.h"
#import "ChatSealFeed.h"
#import "CS_tfsFriendshipAdjustment.h"

// - constants
static const CGFloat UITWLFT_STD_PAD = 8.0f;

// - forward declarations
@interface UITwitterLocalFeedTableViewCell (internal)
-(void) applyPreferredWidthToDetail;
@end

/***********************************
 UITwitterLocalFeedTableViewCell
 ***********************************/
@implementation UITwitterLocalFeedTableViewCell
/*
 *  Object attributes.
 */
{
    BOOL wasEnabled;
}
@synthesize favAddress;
@synthesize lStatus;
@synthesize bAction;
@synthesize delegate;

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        wasEnabled = YES;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    delegate = nil;
    [favAddress release];
    favAddress = nil;
    
    [lStatus release];
    lStatus = nil;
    
    [bAction release];
    bAction = nil;
    
    [super dealloc];
}

/*
 *  One-time initialization.
 */
-(void) awakeFromNib
{
    [super awakeFromNib];
    [self.favAddress setAddressFontHeight:[ChatSealFeed standardFontHeightForSelection]];
    if ([ChatSeal isAdvancedSelfSizingInUse]){
        NSLayoutConstraint *lc = [NSLayoutConstraint constraintWithItem:self.lStatus attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.favAddress.addressLabel attribute:NSLayoutAttributeLeft multiplier:1.0f constant:0.0f];
        [self.contentView addConstraint:lc];
    }
    else {
        // - make sure the preferred width is set before the first layout.
        [self.bAction setTitle:@"" forState:UIControlStateNormal];
        [self applyPreferredWidthToDetail];
    }
}

/*
 *  Prepare to reuse the cell.
 */
-(void) prepareForReuse
{
    [super prepareForReuse];
    delegate = nil;
}

/*
 *  Perform layout.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    [self applyPreferredWidthToDetail];
}

/*
 *  The action button was tapped.
 */
-(IBAction)doFeedAction:(id)sender
{
    if (delegate) {
        [delegate performSelector:@selector(twitterLocalFeedCellActionWasPressed:) withObject:self];
    }
}

/*
 *  Reconfigure the cell.
 */
-(void) reconfigureWithFriendshipAdjustment:(CS_tfsFriendshipAdjustment *) adj forFriend:(ChatSealFeedFriend *) feedFriend andAnimation:(BOOL) animated
{
    // - animate if necessary, but avoid animating the address field when nothing changed there.
    if (animated) {
        CGRect rcToSnap               = self.contentView.frame;
        if (favAddress.addressLabel.text && wasEnabled == adj.isFeedEnabled) {
            rcToSnap                      = CGRectOffset(rcToSnap, 0.0f, CGRectGetMaxY(self.favAddress.frame));
            rcToSnap.size.height         -= CGRectGetMinY(rcToSnap);
        }
        UIView *vwSnap                = [self resizableSnapshotViewFromRect:rcToSnap afterScreenUpdates:YES withCapInsets:UIEdgeInsetsZero];
        vwSnap.userInteractionEnabled = NO;
        vwSnap.center                 = CGPointMake(CGRectGetWidth(self.contentView.bounds)/2.0f, CGRectGetHeight(self.contentView.bounds) - (CGRectGetHeight(rcToSnap)/2.0f));
        [self.contentView addSubview:vwSnap];
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            vwSnap.alpha = 0.0f;
        }completion:^(BOOL finished) {
            [vwSnap removeFromSuperview];
        }];
    }
    wasEnabled = adj.isFeedEnabled;
    
    // - now set it up.
    [self.favAddress setAddressText:adj.screenName];
    [self.favAddress setTextColor:wasEnabled ? [UIColor blackColor] : [UIColor lightGrayColor]];
    
    self.lStatus.text = adj.statusText;
    if (adj.isWarning) {
        self.lStatus.textColor = [ChatSeal defaultWarningColor];
    }
    else {
        self.lStatus.textColor = [UIColor lightGrayColor];
    }
    
    self.accessoryType = adj.hasDetailToDisplay ? UITableViewCellAccessoryDetailButton : UITableViewCellAccessoryNone;
    if (!adj.hasDetailToDisplay && adj.hasCorrectiveAction) {
        [self.bAction setTitle:[adj correctiveButtonTextForFriend:feedFriend] forState:UIControlStateNormal];
        self.bAction.enabled         = YES;
        self.bAction.hidden          = NO;
    }
    else {
        [self.bAction setTitle:@"" forState:UIControlStateNormal];
        self.bAction.enabled         = NO;
        self.bAction.hidden          = YES;
    }
    [self setNeedsLayout];
}

/*
 *  Respond to dynamic type changes.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL)isInit
{
    [favAddress updateDynamicTypeNotificationReceived];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lStatus withPreferredSettingsAndTextStyle:UIFontTextStyleCaption2 duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextButton:self.bAction withPreferredSettingsAndTextStyle:UIFontTextStyleSubheadline duringInitialization:isInit];
    [self applyPreferredWidthToDetail];
}

@end

/******************************************
 UITwitterLocalFeedTableViewCell (internal)
 ******************************************/
@implementation UITwitterLocalFeedTableViewCell (internal)
/*
 *  Figure out the preferred maximum width of the detail text if necessary.
 */
-(void) applyPreferredWidthToDetail
{
    CGSize szBounds       = self.contentView.bounds.size;
    CGSize sz             = CGSizeZero;
    NSString *buttonTitle = [self.bAction titleForState:UIControlStateNormal];
    if (buttonTitle.length) {
        sz = [self.bAction sizeThatFits:CGSizeMake(szBounds.width, 1.0f)];
        sz.width += UITWLFT_STD_PAD;
    }
    CGFloat expectedMaxX = szBounds.width - UITWLFT_STD_PAD - sz.width;
    CGFloat targetWidth  = expectedMaxX - CGRectGetMinX(self.lStatus.frame);
    if ((int) self.lStatus.preferredMaxLayoutWidth != (int) targetWidth) {
        self.lStatus.preferredMaxLayoutWidth = targetWidth;
        [self.lStatus invalidateIntrinsicContentSize];
        [self setNeedsLayout];
        [self layoutIfNeeded];
    }
}
@end
