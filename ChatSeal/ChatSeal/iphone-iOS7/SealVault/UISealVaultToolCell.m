//
//  UISealVaultToolCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/31/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealVaultToolCell.h"

#import "ChatSeal.h"
#import "ChatSealBaseStation.h"

// - constants
static const int UISVTC_TAG_TITLE   = 100;
static const int UISVTC_TAG_DETAIL  = 101;
static const CGFloat UISVTC_MIN_PAD = 20.0f;

// - forward declarations
@interface UISealVaultToolCell (internal)
-(UILabel *) lTitle;
-(UILabel *) lDetail;
-(void) applyPreferredWidthToDetailAsInit:(BOOL) isInit;
-(BOOL) hasDetailContentChangedAndReturnText:(NSString **) newDetailText withSharingPossible:(BOOL *) newIsSharePossible andDetailIsImportant:(BOOL *) newIsDetailImport;
@end

/*************************
 UISealVaultToolCell
 *************************/
@implementation UISealVaultToolCell
/*
 *  Object attributes.
 */
{
    BOOL     isSharingPossible;
    BOOL     detailIsImportant;
    NSString *detailText;
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        isSharingPossible = YES;
        detailIsImportant = NO;
        detailText        = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [detailText release];
    detailText = nil;
    
    [super dealloc];
}

/*
 *  Do one-time initialization after the cell is loaded.
 */
-(void) awakeFromNib
{
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        // - with advanced self-sizing, we have more room to spare for
        //   sizing the text so we'll avoid making it too cramped with an extra
        //   contraint.
        NSLayoutConstraint *constraint = [NSLayoutConstraint constraintWithItem:self.lDetail attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:self.lTitle attribute:NSLayoutAttributeLeft multiplier:1.0f constant:UISVTC_MIN_PAD];
        [self.contentView addConstraint:constraint];
    }
    else {
        // - under iOS7.1, the detail must only be a single line.
        self.lDetail.numberOfLines = 1;
    }
}

/*
 *  Lay out the content.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    [self applyPreferredWidthToDetailAsInit:NO];
}

/*
 *  Return whether sharing is possible in the current cell.
 */
-(BOOL) isSharingPossible
{
    return isSharingPossible;
}

/*
 *  Change the attributes in the cell to reflect the current availability
 *  of seal sharing in the system.
 */
-(void) reconfigureCellForSharingAvailabilityWithAnimation:(BOOL) animated
{
    NSString *detail    = nil;
    BOOL newIsShare     = NO;
    BOOL newisImport    = NO;
    BOOL contentChanged = [self hasDetailContentChangedAndReturnText:&detail withSharingPossible:&newIsShare andDetailIsImportant:&newisImport];
    detailIsImportant   = newisImport;
    isSharingPossible   = newIsShare;
    
    // - ok, if the content has changed, we need to modify the relevant items.
    if (contentChanged) {
        // - if animated, we need to take a quick snapshot
        if (animated) {
            UIView *vwSnap         = [self.contentView snapshotViewAfterScreenUpdates:YES];
            UIView *vwBack         = [[UIView alloc] initWithFrame:vwSnap.frame];
            vwBack.backgroundColor = [UIColor whiteColor];      // to mask transparency behind text.
            [vwBack addSubview:vwSnap];
            [self.contentView addSubview:vwBack];
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                vwBack.alpha = 0.0f;
            }completion:^(BOOL finished) {
                [vwBack removeFromSuperview];
            }];
        }
        
        // - now update the items.
        [detailText release];
        detailText = [detail retain];
        UILabel *lDetail = self.lDetail;
        lDetail.text     = detail;
        
        if (detailIsImportant) {
            lDetail.textColor = [ChatSeal defaultWarningColor];
        }
        else {
            lDetail.textColor = [ChatSeal defaultSupportingTextColor];
        }
        
        if (isSharingPossible) {
            self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        else {
            self.accessoryType = UITableViewCellAccessoryDetailButton;
        }        
    }
}

/*
 *  Prepare to reuse the cell.
 */
-(void) prepareForReuse
{
    isSharingPossible = YES;
    detailIsImportant = NO;
    [detailText release];
    detailText = nil;
    [self reconfigureLabelsForDynamicTypeDuringInit:YES];
}

/*
 *  This default implementation doesn't assign detail text.
 */
-(NSString *) detailTextForSharingIsPossible:(BOOL) isPossible withNewUsers:(NSUInteger) newUsers andVaultUsers:(NSUInteger) vaultUsers andWirelessState:(ps_bs_proximity_state_t) ps
{
    return nil;
}

/*
 *  Determine if tracking the sharing possibility is important.
 */
-(BOOL) shouldConsiderSharingPossibility
{
    return YES;
}

/*
 *  Whether or not we want the detail to be highlighted.
 */
-(BOOL) shouldDetailBeImportant
{
    return NO;
}


/*
 *  When necessary, reconfigure the labels to use proper dynamic type sizes.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL) isInit
{
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lTitle withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
    [self applyPreferredWidthToDetailAsInit:isInit];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lDetail withPreferredSettingsAndTextStyle:UIFontTextStyleCaption1 duringInitialization:isInit];
}

/*
 *  This method will determine if the detail content is different that what was assigned before.
 */
-(BOOL) hasDetailContentChanged
{
    NSString *det    = nil;
    BOOL     isShare = NO;
    BOOL     isDet   = NO;
    return [self hasDetailContentChangedAndReturnText:&det withSharingPossible:&isShare andDetailIsImportant:&isDet];
}

@end

/********************************
 UISealVaultToolCell (internal)
 ********************************/
@implementation UISealVaultToolCell (internal)
/*
 *  Return the title label.
 */
-(UILabel *) lTitle
{
    return (UILabel *) [self viewWithTag:UISVTC_TAG_TITLE];
}

/*
 *  Return the detail label.
 */
-(UILabel *) lDetail
{
    return (UILabel *) [self viewWithTag:UISVTC_TAG_DETAIL];
}

/*
 *  Figure out the preferred maximum width of the detail text if necessary.
 */
-(void) applyPreferredWidthToDetailAsInit:(BOOL) isInit
{
    // - under iOS7.1 we are restricting this to a single line.
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        return;
    }
    
    CGSize sz            = [self.lTitle sizeThatFits:CGSizeMake(CGRectGetWidth(self.contentView.bounds), 1.0f)];
    CGFloat expectedMaxX = CGRectGetMinX(self.lTitle.frame) + sz.width;
    CGFloat targetWidth  = CGRectGetWidth(self.contentView.bounds) - expectedMaxX - UISVTC_MIN_PAD;
    UILabel *lDetail     = self.lDetail;
    if ((int) lDetail.preferredMaxLayoutWidth != (int) targetWidth) {
        lDetail.preferredMaxLayoutWidth = targetWidth;
        [lDetail invalidateIntrinsicContentSize];
        
        // - the first time this occurs, we need to make sure that the height is computed correctly.
        if (isInit) {
            [self setNeedsLayout];
            [self layoutIfNeeded];
        }
    }
}

/*
 *  Figure out if content has changed and return the relevant pieces.
 */
-(BOOL) hasDetailContentChangedAndReturnText:(NSString **) newDetailText withSharingPossible:(BOOL *) newIsSharePossible andDetailIsImportant:(BOOL *) newIsDetailImport
{
    // - change the attributes associated with sharing
    BOOL canShare = NO;
    if ([ChatSeal activeSeal]) {
        canShare = YES;
    }
    
    BOOL       contentChanged = NO;
    NSUInteger newUsers       = [[ChatSeal applicationBaseStation] newUserCount];
    NSUInteger oldUsers       = [[ChatSeal applicationBaseStation] vaultReadyUserCount];
    *newIsDetailImport        = [self shouldDetailBeImportant];
    
    // - figure out if we need to update the look of this cell.
    if ([self shouldConsiderSharingPossibility]) {
        *newIsSharePossible = canShare;
        if (canShare != isSharingPossible) {
            contentChanged = YES;
        }
    }
    else {
        *newIsSharePossible = YES;
    }
    
    *newDetailText = [self detailTextForSharingIsPossible:*newIsSharePossible
                                             withNewUsers:newUsers
                                            andVaultUsers:oldUsers
                                         andWirelessState:[[ChatSeal applicationBaseStation] proximityWirelessState]];
    if (!*newDetailText != !detailText || ![*newDetailText isEqualToString:detailText]) {
        contentChanged = YES;
    }
    
    if (detailIsImportant != *newIsDetailImport) {
        contentChanged = YES;
    }
    return contentChanged;
}

@end
