//
//  UISealVaultCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 12/24/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UISealVaultCell.h"
#import "UISealVaultSimpleSealView.h"
#import "ChatSeal.h"
#import "ChatSealIdentity.h"
#import "UISealWaxViewV2.h"
#import "ChatSealVaultPlaceholder.h"
#import "UIImageGeneration.h"

// - constants
static const CGFloat UISVC_OWNER_SIZE  = 20.0f;  // in font points.
static const CGFloat UISVC_PH_LEFT_PAD = 20.0f;
static const CGFloat UISVC_PH_BOT_PAD  = 17.0f;
static const CGFloat UISVC_PH_TOP_PAD  = 11.0f;
static const CGFloat UISVC_PH_TITLE_HT = 40.0f;
static const CGFloat UISVC_PH_SUBHD_HT = 6.0f;
static const CGFloat UISVC_PH_SUBHD_WD = 130.0f;
static const CGFloat UISVC_PH_DET_DIAM = 24.0f;
static const CGFloat UISVC_PH_RT_PAD   = 33.0f;

// - forward declarations
@interface UISealVaultCell (internal)
-(void) setSentVisible:(BOOL) isVisible;
-(void) setRecvVisible:(BOOL) isVisible;
-(void) updateTitleForActiveStateWithIdentity:(ChatSealIdentity *) psi withAnimation:(BOOL) animated;
-(void) drawSubHeaderPlaceholderAtPosition:(CGPoint) pt inColor:(UIColor *) c;
-(BOOL) shouldDisplayActiveTitleForIdentity:(ChatSealIdentity *) psi;
-(void) applyPreferredWidthToStatusAsInit:(BOOL) isInit;
-(void) sizeExpiredLabelFontAsInit:(BOOL) isInit;
-(void) assignOwnerFontBasedOnContentWithIdentity:(ChatSealIdentity *) psi andAsInit:(BOOL) isInit;
@end

/******************
 UISealVaultCell
 ******************/
@implementation UISealVaultCell
/*
 *  Object attributes.
 */
{
    BOOL                      activeOnSelection;
    BOOL                      currentTitleActiveOn;
    UILabel                   *lExpired;
    
    // - prior values to track changes
    NSUInteger                curSent;
    NSUInteger                curRecv;
    BOOL                      curExpired;
    BOOL                      curRevoked;
}
@synthesize lOwnerName;
@synthesize svSeal;
@synthesize lActivityTitle;
@synthesize lSentCount;
@synthesize lSentLabel;
@synthesize lRecvCount;
@synthesize lRecvLabel;
@synthesize lUnused;
@synthesize lStatus;

/*
 *  Add the seal vault cell registration from the common NIB for the given table and id.
 */
+(void) registerCellForTable:(UITableView *) tv forCellReuseIdentifier:(NSString *) cellId
{
    UINib *nib = [UINib nibWithNibName:@"UISealVaultCell" bundle:nil];
    [tv registerNib:nib forCellReuseIdentifier:cellId];
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        activeOnSelection    = NO;
        currentTitleActiveOn = NO;
        
        // - set the defaults for the current data
        curSent              = (NSUInteger) -1;
        curRecv              = (NSUInteger) -1;
        curExpired           = NO;
        curRevoked           = NO;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [lOwnerName release];
    lOwnerName = nil;
    
    [svSeal release];
    svSeal = nil;
    
    [lActivityTitle release];
    lActivityTitle = nil;
    
    [lSentCount release];
    lSentCount = nil;
    
    [lSentLabel release];
    lSentLabel = nil;
    
    [lRecvCount release];
    lRecvCount = nil;
    
    [lRecvLabel release];
    lRecvLabel = nil;
    
    [lStatus release];
    lStatus = nil;
    
    [lUnused release];
    lUnused = nil;
    
    [lExpired release];
    lExpired = nil;
    
    [super dealloc];
}

/*
 *  Prepare to reuse the cell.
 */
-(void) prepareForReuse
{
    [super prepareForReuse];

    // - occasionally, we delete cells slightly differently so make
    //   sure the transforms are reset.
    self.alpha = 1.0f;
    
    // - no need to save the image.
    [self.svSeal setSealColor:RSSC_INVALID withImage:nil];
    self.lStatus.text         = nil;
    self.lOwnerName.text      = nil;
    currentTitleActiveOn = NO;
    
    // - discard revoked/expired.
    [lExpired removeFromSuperview];
    [lExpired release];
    lExpired = nil;
    curExpired = curRevoked = NO;
}

/*
 *  Configure the cell with the given identity.
 */
-(void) configureCellWithIdentity:(ChatSealIdentity *) psi andShowDisclosureIndicator:(BOOL) showDisclosure
{
    // - turn selection behavior on/off
    if (psi.isOwned) {
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        self.accessoryType  = showDisclosure ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    }
    else {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.accessoryType  = UITableViewCellAccessoryNone;
    }
    
    // - set the basic stats
    [self updateStatsWithIdentity:psi andAnimation:NO];

    // - and give it some color.
    [self.svSeal setSealColor:[psi color] withImage:psi.vaultImage];
}

/*
 *  Assign the stats in the object, but assume the seal design hasn't changed.
 *  - all of the updates occur at the end, and only if there is something different.
 */
-(void) updateStatsWithIdentity:(ChatSealIdentity *) psi andAnimation:(BOOL) animated
{
    BOOL performUpdate = NO;
    
    // - assign the name.
    NSString *sName = [psi ownerName];
    if (!sName) {
        sName = [ChatSeal ownerForAnonymousSealForMe:[psi isOwned] withLongForm:YES];
    }
    if (![sName isEqualToString:[self.lOwnerName text]] ||
        currentTitleActiveOn != [self shouldDisplayActiveTitleForIdentity:psi]) {
        performUpdate = YES;
    }
    
    // - now the counts
    NSUInteger nSent = psi.sentCount;
    NSUInteger nRecv = psi.recvCount;
    if (nSent != curSent) {
        curSent       = nSent;
        performUpdate = YES;
    }
    if (nRecv != curRecv) {
        curRecv       = nRecv;
        performUpdate = YES;
    }
    
    // - the status
    BOOL isWarnStatus = NO;
    NSString *sStatus = nil;
    sStatus = [psi computedStatusTextAndDisplayAsWarning:&isWarnStatus];
    if ((sStatus || self.lStatus.text) && ![sStatus isEqualToString:[self.lStatus text]]) {
        performUpdate = YES;
    }
    
    // - revoked/expired.
    if (![psi isOwned]) {
        if (curRevoked != [psi isRevoked]) {
            curRevoked    = [psi isRevoked];
            performUpdate = YES;
        }
        if (curExpired != [psi isExpired]) {
            curExpired    = [psi isExpired];
            performUpdate = YES;
        }
    }
    
    // - only do the update if necessary to avoid the needless relayout hit.
    if (performUpdate) {
        // - if animated, first take a disposable snapshot and start its fading.
        if (animated) {
            UIView *vwSnap             = [self.contentView snapshotViewAfterScreenUpdates:YES];
            UIView *vwSnapBack         = [[[UIView alloc] initWithFrame:vwSnap.bounds] autorelease];
            vwSnapBack.backgroundColor = [UIColor whiteColor];
            [vwSnapBack addSubview:vwSnap];             //  to eliminate transparent regions.
            [self.contentView addSubview:vwSnapBack];
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                vwSnapBack.alpha = 0.0f;
            } completion:^(BOOL finished) {
                [vwSnapBack removeFromSuperview];
            }];
        }
        
        self.lOwnerName.text = sName;
    
        // - the color/font of the owner is based on content.
        [self updateTitleForActiveStateWithIdentity:psi withAnimation:NO];
        
        // - depending on the seal style, we may not show the counts.
        if (curSent || curRecv) {
            self.lUnused.hidden = YES;
            [self setSentVisible:YES];
            self.lSentCount.text = [NSString stringWithFormat:@"%lu", (unsigned long) curSent];
            self.lRecvCount.text = [NSString stringWithFormat:@"%lu", (unsigned long) curRecv];
            if ([psi isOwned] && curRecv == 0) {
                [self setRecvVisible:NO];
            }
            else {
                [self setRecvVisible:YES];
            }
        }
        else {
            [self setSentVisible:NO];
            [self setRecvVisible:NO];
            self.lUnused.hidden = NO;
        }
        
        // - assign the status text.
        self.lStatus.text      = sStatus;
        self.lStatus.textColor = isWarnStatus ? [ChatSeal defaultWarningColor] : ([psi isOwned] ? [self.lStatus tintColor] : [UIColor blackColor]);
        
        // - and finally expired/revoked.
        if (curExpired || curRevoked) {
            if (!lExpired) {
                // - the intent with this overlay is to be distinctive but not push the bounds of the design
                //   aesthetic too much.  I want it to be obvious when a seal is not available.
                lExpired              = [[UILabel alloc] init];
                [self sizeExpiredLabelFontAsInit:YES];
                lExpired.textColor    = [[ChatSeal defaultAppFailureColor] colorWithAlphaComponent:0.95f];
                lExpired.shadowColor  = [UIColor whiteColor];
                lExpired.shadowOffset = CGSizeMake(-1.0f, -1.0f);
                [self.contentView addSubview:lExpired];
            }
            lExpired.hidden = NO;
            if (curRevoked) {
                lExpired.text = NSLocalizedString(@"REVOKED", nil);
            }
            else if (curExpired) {
                lExpired.text = NSLocalizedString(@"EXPIRED", nil);
            }
        }
        else {
            lExpired.hidden = YES;
            lExpired.text   = nil;
        }
        [self setNeedsLayout];
    }
}

/*
 *  This flag indicates whether the active seal distinction (the colorized name) occurs during basic selection.
 */
-(void) setActiveSealDisplayOnSelection:(BOOL) enabled
{
    activeOnSelection = enabled;
    [self updateTitleForActiveStateWithIdentity:nil withAnimation:NO];
}

/*
 *  Detect selection changes.
 */
-(void) setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    [self updateTitleForActiveStateWithIdentity:nil withAnimation:animated];
}

/*
 *  Draw a stylized placeholder image for this cell.
 *  - we're going to create a rough approximation here because it is defined
 *    in the NIB and I'm not keen on the idea of trying to load it from there and 
 *    apply constraints and so on just to create a simple placeholder image.
 *  - I was thinking about it and I don't think I'm going to put the revoked/expired
 *    text over the placeholder because I think that may give too much information.
 */
-(void) drawStylizedVersionWithPlaceholder:(ChatSealVaultPlaceholder *) ph
{
    if (ph) {
        // - compute the diameter of the seal and draw it.
        CGFloat diam = CGRectGetHeight(self.frame) - UISVC_PH_TITLE_HT - UISVC_PH_BOT_PAD;
        [UISealWaxViewV2 drawStylizedVersionAsColor:ph.sealColor inRect:CGRectMake(UISVC_PH_LEFT_PAD, UISVC_PH_TITLE_HT, diam, diam)];
        
        // - now figure out how large to make the title and draw it.
        UILabel *l      = [[[UILabel alloc] init] autorelease];
        l.numberOfLines = 1;
        l.font     = [UIFont systemFontOfSize:20.0f];
        if (ph.lenOwner) {
            NSMutableString *ms = [NSMutableString stringWithString:@""];
            NSUInteger len      = ph.lenOwner;
            for (NSUInteger i = 0; i < len; i++) {
                [ms appendString:@"X"];
            }
            l.text = ms;
        }
        else {
            l.text = [ChatSeal ownerForAnonymousSealForMe:ph.isMine withLongForm:YES];
        }
        [l sizeToFit];
        if (ph.isActive) {
            [[ChatSeal defaultSelectedHeaderColor] setFill];
        }
        else {
            [[UIColor blackColor] setFill];
        }

        CGFloat width              = CGRectGetWidth(l.frame);
        CGFloat maxWidthBeforeSide = CGRectGetWidth(self.frame) * 0.6f;
        if (width > maxWidthBeforeSide) {
            width = maxWidthBeforeSide;
        }
        CGRect rcFill = CGRectMake(UISVC_PH_LEFT_PAD, UISVC_PH_TOP_PAD, width, UISVC_PH_TITLE_HT * 0.15f);
        UIRectFill(rcFill);
        
        //  - now we need the 'Personal Messages' sub-header
        CGFloat startOfSubHeaders = UISVC_PH_LEFT_PAD + diam + (UISVC_PH_LEFT_PAD/2.0f);
        [self drawSubHeaderPlaceholderAtPosition:CGPointMake(startOfSubHeaders, UISVC_PH_TITLE_HT) inColor:[UIColor blackColor]];
        
        //  - if status is important, draw that also.
        if (ph.lenStatus) {
            UIColor *cStatus = nil;
            if (ph.isWarnStatus) {
                cStatus = [ChatSeal defaultWarningColor];
            }
            else {
                cStatus = self.tintColor;
            }
            [self drawSubHeaderPlaceholderAtPosition:CGPointMake(startOfSubHeaders, CGRectGetHeight(self.frame) - UISVC_PH_BOT_PAD - UISVC_PH_SUBHD_HT) inColor:cStatus];
        }
        
        // - for my seals, draw an impression of the detail indicator
        if (ph.isMine) {
            CGContextSetLineWidth(UIGraphicsGetCurrentContext(), 1.0f);
            [self.tintColor setStroke];
            CGContextStrokeEllipseInRect(UIGraphicsGetCurrentContext(),
                                         CGRectMake(CGRectGetWidth(self.frame) - UISVC_PH_RT_PAD - UISVC_PH_DET_DIAM,
                                                    CGRectGetHeight(self.frame)/2.0f - UISVC_PH_DET_DIAM/2.0f,
                                                    UISVC_PH_DET_DIAM, UISVC_PH_DET_DIAM));
        }
    }
    
    // - draw the divider on the bottom regardless of whether there is content.
    [[UIColor lightGrayColor] setStroke];
    CGContextBeginPath(UIGraphicsGetCurrentContext());
    CGContextMoveToPoint(UIGraphicsGetCurrentContext(), UISVC_PH_LEFT_PAD, CGRectGetMaxY(self.frame));
    CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), CGRectGetMaxX(self.frame), CGRectGetMaxY(self.frame));
    CGContextStrokePath(UIGraphicsGetCurrentContext());
}

/*
 *  The cell height here should be the same as in the NIB, but this is used for placeholder generation.
 */
+(CGFloat) standardCellHeight
{
    return 139.0f;
}

/*
 *  Layout the content.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    [self applyPreferredWidthToStatusAsInit:NO];
    
    // - most layout is done with auto-layout execpt when we need to add the revoked/expired tag to this
    //   item.
    if (lExpired) {
        [lExpired sizeToFit];
        lExpired.transform = CGAffineTransformMakeRotation(-(CGFloat)M_PI/7.0f);
        CGRect rc          = lExpired.bounds;
        lExpired.center    = CGPointMake(CGRectGetMinX(self.lStatus.frame) + (CGRectGetWidth(rc)/2.0f), CGRectGetMinY(lRecvCount.frame) - CGRectGetHeight(rc)/2.0f);
    }
}

/*
 *  When necessary, reconfigure the labels to use proper dynamic type sizes.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL) isInit
{
    // - the owner font is sort of special because it changes its form based on the type of seal.
    [self assignOwnerFontBasedOnContentWithIdentity:nil andAsInit:isInit];
    
    // - these text items are pretty standard.
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lActivityTitle withPreferredSettingsAndTextStyle:UIFontTextStyleSubheadline duringInitialization:isInit];
    UIFont *fontCount    = [UIAdvancedSelfSizingTools constrainedFontForPreferredSettingsAndTextStyle:UIFontTextStyleSubheadline];
    fontCount            = [UIFont boldSystemFontOfSize:fontCount.pointSize];
    self.lSentCount.font = fontCount;
    [self.lSentCount invalidateIntrinsicContentSize];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lSentLabel withPreferredSettingsAndTextStyle:UIFontTextStyleSubheadline duringInitialization:isInit];
    
    self.lRecvCount.font = fontCount;
    [self.lRecvCount invalidateIntrinsicContentSize];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lRecvLabel withPreferredSettingsAndTextStyle:UIFontTextStyleSubheadline duringInitialization:isInit];
    
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lUnused withPreferredSettingsAndTextStyle:UIFontTextStyleFootnote duringInitialization:isInit];
    
    [self applyPreferredWidthToStatusAsInit:isInit];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lStatus withPreferredSettingsAndTextStyle:UIFontTextStyleFootnote duringInitialization:isInit];
    
    // - if an expired label exists, make sure it is updated also.
    [self sizeExpiredLabelFontAsInit:isInit];
}

/*
 *  Determine if the given identity would change what is displayed in the cell.
 */
-(BOOL) doesCellContentChangeWithIdentity:(ChatSealIdentity *) psi
{
    // - the counts...
    if (psi.sentCount != curSent) {
        return YES;
    }
    if (psi.recvCount != curRecv) {
        return YES;
    }
    
    // - the name...
    NSString *sName = [psi ownerName];
    if (!sName) {
        sName = [ChatSeal ownerForAnonymousSealForMe:[psi isOwned] withLongForm:YES];
    }
    if (![sName isEqualToString:[self.lOwnerName text]] ||
        currentTitleActiveOn != [self shouldDisplayActiveTitleForIdentity:psi]) {
        return YES;
    }
    
    // - the status...
    BOOL isWarnStatus = NO;
    NSString *sStatus = nil;
    sStatus = [psi computedStatusTextAndDisplayAsWarning:&isWarnStatus];
    if ((sStatus || self.lStatus.text) && ![sStatus isEqualToString:[self.lStatus text]]) {
        return YES;
    }
    
    // - revoked/expired...
    if (![psi isOwned]) {
        if (curRevoked != [psi isRevoked] || curExpired != [psi isExpired]) {
            return YES;
        }
    }
    
    // - nothing is going to change.
    return NO;
}
@end

/**************************
 UISealVaultCell (internal)
 **************************/
@implementation UISealVaultCell (internal)
/*
 *  Show/hide the sent count.
 */
-(void) setSentVisible:(BOOL) isVisible
{
    self.lSentCount.hidden = !isVisible;
    self.lSentLabel.hidden = !isVisible;
}

/*
 *  Show/hide the recv count.
 */
-(void) setRecvVisible:(BOOL) isVisible
{
    lRecvCount.hidden = !isVisible;
    lRecvLabel.hidden = !isVisible;
}

/*
 *  Update the active distinction on the title based on the style used.
 */
-(void) updateTitleForActiveStateWithIdentity:(ChatSealIdentity *) psi withAnimation:(BOOL)animated
{
    // - determine the activity state.
    currentTitleActiveOn = [self shouldDisplayActiveTitleForIdentity:psi];
    
    // - if this is animated and we're more carefully managing selection, animate the transition of this text.
    if (animated && activeOnSelection) {
        UIView *vwSnap                = [self resizableSnapshotViewFromRect:self.lOwnerName.frame afterScreenUpdates:YES withCapInsets:UIEdgeInsetsZero];
        vwSnap.userInteractionEnabled = NO;
        vwSnap.frame                  = self.lOwnerName.frame;
        [self.contentView addSubview:vwSnap];
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            vwSnap.alpha = 0.0f;
        }completion:^(BOOL finished) {
            [vwSnap removeFromSuperview];
        }];
    }
    
    // - adjust the font/color accordingly.
    [self assignOwnerFontBasedOnContentWithIdentity:psi andAsInit:NO];
}

/*
 *  Draw a placeholder for the subheader.
 */
-(void) drawSubHeaderPlaceholderAtPosition:(CGPoint) pt inColor:(UIColor *) c
{
    [c setFill];
    UIRectFill(CGRectMake(pt.x, pt.y, UISVC_PH_SUBHD_WD, UISVC_PH_SUBHD_HT));
}

/*
 *  Figure out if the title should display as an active title.
 */
-(BOOL) shouldDisplayActiveTitleForIdentity:(ChatSealIdentity *) psi
{
    NSString *sActiveId = [ChatSeal activeSeal];
    BOOL     isActive   = NO;
    if (activeOnSelection) {
        isActive = self.selected;
    }
    else {
        if (psi) {
            isActive = [sActiveId isEqualToString:[psi sealId]];
        }
        else {
            isActive = currentTitleActiveOn;
        }
    }
    return isActive;
}

/*
 *  Figure out the preferred maximum width of the status text if necessary.
 */
-(void) applyPreferredWidthToStatusAsInit:(BOOL)isInit
{
    CGFloat targetWidth  = CGRectGetWidth(self.contentView.bounds) - CGRectGetMinX(self.lStatus.frame);
    if ((int) self.lStatus.preferredMaxLayoutWidth != (int) targetWidth) {
        self.lStatus.preferredMaxLayoutWidth = targetWidth;
        [self.lStatus invalidateIntrinsicContentSize];
        
        // - the first time this occurs, we need to make sure that the height is computed correctly.
        if (isInit) {
            [self setNeedsLayout];
            [self layoutIfNeeded];
        }
    }
}

/*
 *  Adjust the size of the expired label.
 */
-(void) sizeExpiredLabelFontAsInit:(BOOL) isInit
{
    // - nothing being flagged, don't worry about this then.
    if (!lExpired) {
        return;
    }
    
    // - now we're going to build a good font for expired.
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        UIFont *fntBaseline = [UIAdvancedSelfSizingTools constrainedFontForPreferredSettingsAndTextStyle:UIFontTextStyleBody];
        lExpired.font = [UIFont fontWithName:[ChatSeal defaultAppStylizedFontNameAsWeight:CS_SF_BOLD] size:fntBaseline.pointSize * 1.75f];
        [self setNeedsLayout];
    }
    else {
        if (isInit) {
            lExpired.font = [UIFont fontWithName:[ChatSeal defaultAppStylizedFontNameAsWeight:CS_SF_BOLD] size:30.0f];
            [self setNeedsLayout];
        }
    }
}

/*
 *  Modify the owner font based on what kind of cell this is.
 */
-(void) assignOwnerFontBasedOnContentWithIdentity:(ChatSealIdentity *) psi andAsInit:(BOOL) isInit
{
    UIFont *fontBaseline = nil;
    
    // - set up for advanced sizing adjustments.
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        fontBaseline = [UIAdvancedSelfSizingTools constrainedFontForPreferredSettingsAndTextStyle:UIFontTextStyleBody andSizeScale:[ChatSeal superDuperBodyFontScalingFactor] andMinHeight:0.0f];
    }
    
    UIFont *newOwnerFont = nil;
    if (currentTitleActiveOn) {
        self.lOwnerName.textColor = [ChatSeal defaultSelectedHeaderColor];
        newOwnerFont              = [UIFont boldSystemFontOfSize:[ChatSeal isAdvancedSelfSizingInUse] ? fontBaseline.pointSize : UISVC_OWNER_SIZE];
    }
    else {
        if (psi || activeOnSelection) {
            self.lOwnerName.textColor = [UIColor blackColor];
            if (activeOnSelection || [psi isOwned]) {
                newOwnerFont = [ChatSeal isAdvancedSelfSizingInUse] ? fontBaseline : [UIFont systemFontOfSize:UISVC_OWNER_SIZE];
            }
            else if (psi) {
                newOwnerFont = [UIFont italicSystemFontOfSize:[ChatSeal isAdvancedSelfSizingInUse] ? fontBaseline.pointSize : UISVC_OWNER_SIZE];
            }
        }
    }
    
    // - if the font is different then let's assign it.
    if (newOwnerFont &&
        (![newOwnerFont.fontName isEqualToString:self.lOwnerName.font.fontName] || (int) newOwnerFont.pointSize != (int) self.lOwnerName.font.pointSize)) {
        self.lOwnerName.font = newOwnerFont;
        [self.lOwnerName invalidateIntrinsicContentSize];
    }
}
@end
