//
//  UIMessageOverviewMessageCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 11/7/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UIMessageOverviewMessageCell.h"
#import "ChatSeal.h"
#import "UINewSealCell.h"
#import "UIMessageOverviewPlaceholder.h"
#import "UISealWaxViewV2.h"

// - constants
static const CGFloat UIMOC_STD_PAD_CX     = 8.0f;
static const CGFloat UIMOC_TEXT_VPAD_PCT  = 0.1f;
static const CGFloat UIMOC_STD_PAD_CY     = 10.0f;

// - forward declarations
@interface UIMessageOverviewMessageCell (internal)
-(void) downgradeAdvancedBehavior;
-(void) setReadIndicatorForValue:(BOOL) messageIsRead;
+(NSString *) authorTextForName:(NSString *) author asMe:(BOOL) isMe andIsRead:(BOOL) isRead;
-(void) setAuthorText:(NSString *) author asMe:(BOOL) isMe;
+(NSString *) messageDateFromDate:(NSDate *) dtCreated;
-(void) setDate:(NSString *) dtCreated;
+(NSString *) synopsisTextFromContent:(NSString *) synopsis andCryptoLocked:(BOOL) isLocked;
-(void) setSynopsisText:(NSString *) synopsis andCryptoLocked:(BOOL) isLocked;
-(void) beginAnimatedChangeWithLongFade:(BOOL) useLongFade;
@end

/********************************
 UIMessageOverviewMessageCell
 ********************************/
@implementation UIMessageOverviewMessageCell
/*
 *  Object attriburtes
 */
{
    UIImageView     *ivSeal;
    UITableViewCell *tvCellTop;
    UILabel         *lAuthor;
    UILabel         *lCreateDate;
    UILabel         *lSynopsis;
    BOOL            isRead;
    BOOL            isCryptoLocked;
    UINewSealCell   *nscAdvanced;
    NSString        *sAuthor;
    BOOL            isAuthorMe;
}

/*
 *  Initialize the object.
 */
-(id) initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        isRead              = NO;
        isCryptoLocked      = NO;
        sAuthor             = nil;
        isAuthorMe          = NO;
        
        // - add a sub-cell so that we can get that disclosure indictator placed above center.
        tvCellTop                        = [[UITableViewCell alloc] initWithFrame:CGRectMake(0.0f, 0.0f, CGRectGetWidth(self.bounds), 0.0f)];
        tvCellTop.accessoryType          = UITableViewCellAccessoryDisclosureIndicator;
        tvCellTop.autoresizingMask       = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
        tvCellTop.backgroundColor        = [UIColor clearColor];
        tvCellTop.userInteractionEnabled = NO;
        [self.contentView addSubview:tvCellTop];
        [tvCellTop layoutIfNeeded];
        
        // - add the seal to the cell.
        CGFloat stdSide         = [ChatSeal standardSealSideForListDisplay];
        ivSeal                  = [[UIImageView alloc] initWithFrame:CGRectMake(self.separatorInset.left, 0.0f, stdSide, stdSide)];
        ivSeal.contentMode      = UIViewContentModeScaleAspectFit;  // so that the dimensions are precise to the standard size
        ivSeal.clipsToBounds    = NO;                               // to show the shadow
        [self.contentView addSubview:ivSeal];
        
        // - now the author
        lAuthor                           = [[UILabel alloc] init];
        lAuthor.textColor                 = [UIColor blackColor];
        lAuthor.numberOfLines             = 1;
        lAuthor.lineBreakMode             = NSLineBreakByTruncatingTail;
        lAuthor.adjustsFontSizeToFitWidth = NO;
        [self.contentView addSubview:lAuthor];
        
        // - the creation date
        lCreateDate               = [[UILabel alloc] init];
        lCreateDate.textColor     = [ChatSeal defaultSupportingTextColor];
        lCreateDate.numberOfLines = 1;
        [self.contentView addSubview:lCreateDate];
        
        // - and the synopsis
        lSynopsis                           = [[UILabel alloc] init];
        lSynopsis.textColor                 = [ChatSeal defaultSupportingTextColor];
        lSynopsis.numberOfLines             = [ChatSeal isAdvancedSelfSizingInUse] ? 3 : 2;                    //  These cells should not have unlimited capacity.
        lSynopsis.adjustsFontSizeToFitWidth = NO;
        lSynopsis.lineBreakMode             = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:lSynopsis];
        [self reconfigureLabelsForDynamicTypeDuringInit:YES];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [ivSeal release];
    ivSeal = nil;
    
    [tvCellTop release];
    tvCellTop = nil;
    
    [lAuthor release];
    lAuthor = nil;
    
    [lCreateDate release];
    lCreateDate = nil;
    
    [lSynopsis release];
    lSynopsis = nil;
    
    [sAuthor release];
    sAuthor = nil;
    
    [self downgradeAdvancedBehavior];
    
    [super dealloc];
}

/*
 *  Do initial configuration in the cell.
 */
-(void) configureWithMessage:(ChatSealMessage *) psm andAnimation:(BOOL) animated
{
    // - make sure this is just a simple display cell.
    [self downgradeAdvancedBehavior];
    
    // - the first tasks is to see if we really have anything to do here because
    //   otherwise the animation will be unnecessary and flicker for each one.
    NSString *sNewDate   = [UIMessageOverviewMessageCell messageDateFromDate:[psm creationDate]];
    NSString *sNewAuthor = [UIMessageOverviewMessageCell authorTextForName:[psm author] asMe:[psm isAuthorMe] andIsRead:[psm isRead]];
    UIImage *imgTable    = [psm sealTableImage];
    NSString *sNewSynop  = [UIMessageOverviewMessageCell synopsisTextFromContent:[psm synopsis] andCryptoLocked:[psm isLocked]];
    if (isCryptoLocked == [psm isLocked] && isRead == [psm isRead] &&
        ivSeal.image == imgTable &&
        [sNewDate isEqualToString:lCreateDate.text] &&
        [sNewAuthor isEqualToString:lAuthor.text] &&
        [sNewSynop isEqualToString:lSynopsis.text]) {
        return;
    }
    
    // - if we should animate this, start it.
    if (animated) {
        // - fade longer when we're changing the locked behavior so that it is more obvious what happened.
        [self beginAnimatedChangeWithLongFade:(isCryptoLocked != [psm isLocked]) ? YES : NO];
    }
    
    // - assign an image for the seal.
    ivSeal.image = [psm sealTableImage];
    
    // - the creation date should be descriptive, especially when it has been recent.
    [self setDate:sNewDate];
    
    // - the indicator whether the message has been read or not
    isCryptoLocked = [psm isLocked];
    isRead         = [psm isRead] || isCryptoLocked;            // don't indicate that locked messages are new.
    [self setReadIndicatorForValue:isRead || isCryptoLocked];
    
    // - the author may not exist, so we need to come up with something.
    [self setAuthorText:[psm author] asMe:[psm isAuthorMe]];
    
    // - the synopsis is the easiest one of all
    [self setSynopsisText:[psm synopsis] andCryptoLocked:isCryptoLocked];

    // - make sure layout occurs.
    [self setNeedsLayout];
}

/*
 *  This method determines if the active cell could benefit from in-place reconfiguration or whether reloading is
 *  best.
 */
-(BOOL) canUpdatesToMesageBeOptimized:(ChatSealMessage *) psm
{
    // - the syopsis is what changes the size of the cell in iOS8, so that is the metric.
    if ([ChatSeal isIOSVersionBEFORE8]) {
        return YES;
    }
    NSString *sNewSynop  = [UIMessageOverviewMessageCell synopsisTextFromContent:[psm synopsis] andCryptoLocked:[psm isLocked]];
    return [sNewSynop isEqualToString:lSynopsis.text];
}

/*
 *  Layout the items in the view.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];

    // - the way layout works here is that we're going to focus on seeing the date
    //   every time, but truncate the author when necessary.
    // - the disclosure indicator's center is used to center the date.
    // - the author's name is adjusted to be aligned along the bottom of the date
    CGRect rcTop         = [self.contentView convertRect:tvCellTop.contentView.frame fromView:tvCellTop];
    CGFloat maxX         = 0.0f;
    if (self.editing) {
        maxX = CGRectGetWidth(self.contentView.bounds) - UIMOC_STD_PAD_CX;
    }
    else {
        maxX = CGRectGetMaxX(rcTop);
    }
    CGFloat minX         = self.separatorInset.left + CGRectGetWidth(ivSeal.bounds) + UIMOC_STD_PAD_CX;
    CGFloat width        = maxX - minX - UIMOC_STD_PAD_CX;
    CGSize szAuthor      = [lAuthor sizeThatFits:CGSizeMake(width, 1.0f)];
    CGFloat heightAuthor = szAuthor.height;
    CGSize szDate        = [lCreateDate sizeThatFits:CGSizeMake(width, 1.0f)];
    lCreateDate.frame    = CGRectIntegral(CGRectMake(maxX - szDate.width,
                                                     UIMOC_STD_PAD_CY,
                                                     szDate.width,
                                                     szDate.height));
    lAuthor.frame        = CGRectIntegral(CGRectMake(minX, CGRectGetMinY(lCreateDate.frame) - 2.0f, CGRectGetMinX(lCreateDate.frame) - minX - UIMOC_STD_PAD_CX - UIMOC_STD_PAD_CX, heightAuthor));
    
    // - the synopsis sits down at the bottom right corner
    CGFloat minY       = CGRectGetMaxY(lAuthor.frame) + (CGRectGetHeight(lAuthor.bounds) * UIMOC_TEXT_VPAD_PCT);
    BOOL emptySynopsis = NO;
    if (!lSynopsis.text || lSynopsis.text.length == 0) {
        emptySynopsis  = YES;
        lSynopsis.text = @"W\nW";       // to size for the maximum height we'll allow on two lines.
    }
    CGSize szSynopsis = [lSynopsis sizeThatFits:CGSizeMake(width, 0.0f)];
    if (emptySynopsis) {
        lSynopsis.text = nil;
    }

    lSynopsis.frame   = CGRectIntegral(CGRectMake(minX, minY, szSynopsis.width, szSynopsis.height));
    tvCellTop.alpha   = self.editing ? 0.0f : 1.0f;
    
    // - place the seals, centered in the view.
    ivSeal.frame       = CGRectIntegral(CGRectMake(self.separatorInset.left, UIMOC_STD_PAD_CY, CGRectGetWidth(ivSeal.bounds), CGRectGetHeight(ivSeal.bounds)));
    nscAdvanced.center = ivSeal.center;
}

/*
 * Assign the is-read indicator for this message.
 */
-(void) setIsRead:(BOOL) messageIsRead withAnimation:(BOOL) animated
{
    if (animated) {
        [self beginAnimatedChangeWithLongFade:NO];
    }
    isRead = messageIsRead;
    [self setReadIndicatorForValue:isRead || isCryptoLocked];
    [self setAuthorText:sAuthor asMe:isAuthorMe];       // update the is-read text.
}

/*
 *  Return whether the cell is described as currently locked because of 
 *  a lack of keys.
 */
-(BOOL) isPermanentlyLocked
{
    return isCryptoLocked;
}

/*
 *  Upgrade/downgrade the seal to an item that can be unlocked/locked.
 */
-(void) configureAdvancedDisplayWithMessage:(ChatSealMessage *) psm
{
    if (psm) {
        if (nscAdvanced) {
            return;
        }
        nscAdvanced                  = [[ChatSeal sealCellForId:[psm sealId] andHeight:CGRectGetHeight(ivSeal.bounds)] retain];
        nscAdvanced.center           = ivSeal.center;
        [nscAdvanced setSealColor:psm.sealColor];
        [nscAdvanced prepareForSmallDisplay];
        [nscAdvanced setLocked:YES];
        [nscAdvanced setCenterRingVisible:YES];
        [self.contentView addSubview:nscAdvanced];
        ivSeal.hidden      = YES;
    }
    else {
        [self downgradeAdvancedBehavior];
    }
}

/*
 *  Turn the advanced display (if it is enabled) so that the seal is locked/unlocked.
 */
-(void) setLocked:(BOOL) isLocked
{
    [nscAdvanced setLocked:isLocked];
}

/*
 *  When reusing the cell, ensure that any exceptional state is discarded.
 */
-(void) prepareForReuse
{
    [super prepareForReuse];
    
    // - if the cell was advanced, make sure that is gone.
    [self downgradeAdvancedBehavior];
    
    // - when not using advanced self-sizing, this is our chance to upgrade the text.
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        [self reconfigureLabelsForDynamicTypeDuringInit:NO];
    }
    
    // - there are times we fade out the alpha
    self.alpha = 1.0f;
    
    [sAuthor release];
    sAuthor    = nil;
    isAuthorMe = NO;
}

/*
 *  Return a suitable size for this cell.
 */
-(CGSize) sizeThatFits:(CGSize)size
{
    CGSize sz = [super sizeThatFits:size];                  //  necessary to reformat text in iOS8
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        // - use dynamic cell heights without a minimum.
        sz = CGSizeZero;
    }
    [self layoutIfNeeded];
    CGFloat maxYSeal = CGRectGetMaxY(ivSeal.frame) + UIMOC_STD_PAD_CY;
    CGFloat maxYSyn  = CGRectGetMaxY(lSynopsis.frame) + UIMOC_STD_PAD_CY;
    sz.height        = MAX((MAX(maxYSeal, maxYSyn)), sz.height);
    return sz;
}

/*
 *  Draw a placeholder version of this cell with the provided content.
 */
-(void) drawStylizedVersionWithPlaceholder:(UIMessageOverviewPlaceholder *) ph
{
    CGFloat scale  = [UIScreen mainScreen].scale;
    CGSize  szView = self.bounds.size;
    
    // - we only bother drawing content if there is a placeholder, otherwise,
    //   we'll just draw the divider.
    if (ph) {
        // - fill the content so that we can get some measurements.
        NSMutableString *author = nil;
        if (ph.lenAuthor) {
            NSUInteger len = ph.lenAuthor;
            author  = [NSMutableString stringWithCapacity:len];
            for (int i = 0; i < len; i++) {
                [author appendString:@"X"];
            }
        }
        [self setAuthorText:author asMe:ph.isAuthorMe];
        
        NSMutableString *synop = nil;
        if (![ph isLocked] && ph.lenSynopsis) {
            NSUInteger len = ph.lenSynopsis;
            synop   = [NSMutableString stringWithCapacity:len];
            for (int i = 0; i < len; i++) {
                [synop appendString:@"X"];
            }
        }
        [self setSynopsisText:synop andCryptoLocked:[ph isLocked]];
        
        [self setReadIndicatorForValue:[ph isRead] || [ph isLocked]];
        
        [self setDate:nil];
        
        // - now layout the content
        [self setNeedsLayout];
        [self layoutIfNeeded];
        
        // - with the layout done, we just need to draw some stylized versions
        //   of the items.
        
        // ...the seal
        [UISealWaxViewV2 drawStylizedVersionAsColor:ph.sealColor inRect:ivSeal.frame];
        
        // ...the author's name.
        [lAuthor.textColor setFill];
        CGRect rcAuthor  = lAuthor.frame;
        CGRect rcTextRep = CGRectInset(rcAuthor, 0.0f, CGRectGetHeight(rcAuthor)/3.0f);
        UIRectFill(rcTextRep);

        //  ...the synopsis in either locked mode or standard display mode.
        [lSynopsis.textColor setFill];
        CGRect rcSynop   = lSynopsis.frame;
        if (ph.isLocked) {
            rcTextRep = CGRectInset(rcSynop, 0.0f, CGRectGetHeight(rcSynop)/4.0f);
            rcTextRep.size.width *= 0.6f;
            UIRectFill(rcTextRep);
        }
        else {
            lSynopsis.text   = @"*";
            [lSynopsis sizeToFit];
            CGFloat lineWidth = CGRectGetHeight(rcSynop)/7.0f;
            if ((int) CGRectGetHeight(lSynopsis.frame) != (int) CGRectGetHeight(rcSynop)) {
                //  draw two lines to represent two lines of text.
                rcTextRep = CGRectMake(CGRectGetMinX(rcSynop), CGRectGetMinY(rcSynop) + (lineWidth * 2.0f), CGRectGetWidth(rcSynop), lineWidth);
                UIRectFill(rcTextRep);
                rcTextRep = CGRectOffset(rcTextRep, 0.0f, (lineWidth * 3.0f));
                UIRectFill(rcTextRep);
            }
            else {
                //  only a single line.
                rcTextRep = CGRectInset(rcSynop, 0.0f, (CGRectGetHeight(rcSynop) - lineWidth)/2.0f);
                UIRectFill(rcTextRep);
            }
        }
    }
    
    // - the bottom divider is always drawn.
    [[UIColor darkGrayColor] setStroke];
    CGContextSetLineWidth(UIGraphicsGetCurrentContext(), scale);
    CGContextBeginPath(UIGraphicsGetCurrentContext());
    CGContextMoveToPoint(UIGraphicsGetCurrentContext(), 0.0f, szView.height);
    CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), szView.width, szView.height);
    CGContextStrokePath(UIGraphicsGetCurrentContext());
}

/*
 *  This is a manual cell, so we don't require a height constraint.
 */
-(BOOL) shouldCreateHeightConstraint
{
    return NO;
}

/*
 *  Make sure the sub-views are configured for dynamic type.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL)isInit
{
    [UIAdvancedSelfSizingTools constrainTextLabel:lSynopsis withPreferredSettingsAndTextStyle:UIFontTextStyleSubheadline duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextLabel:lAuthor withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextLabel:lCreateDate withPreferredSettingsAndTextStyle:UIFontTextStyleCaption1 duringInitialization:isInit];
}
@end

/****************************************
 UIMessageOverviewMessageCell (internal)
 ****************************************/
@implementation UIMessageOverviewMessageCell (internal)
/*
 *  Convert the cell back into a generic one.
 */
-(void) downgradeAdvancedBehavior
{
    [nscAdvanced removeFromSuperview];
    [nscAdvanced release];
    nscAdvanced   = nil;
    ivSeal.hidden = NO;
}

/*
 *  Turn the is-read indicator on/off.
 */
-(void) setReadIndicatorForValue:(BOOL) messageIsRead
{
    if (messageIsRead) {
        lAuthor.textColor = [UIColor blackColor];
    }
    else {
        lAuthor.textColor = [ChatSeal defaultSelectedHeaderColor];
    }
}

/*
 *  Return the baseline author name.
 */
+(NSString *) authorTextForName:(NSString *) author asMe:(BOOL) isMe andIsRead:(BOOL) isRead
{
    if (!author) {
        author = [ChatSeal ownerForAnonymousForMe:isMe];
    }
    
    return isRead ? author : [NSString stringWithFormat:@"NEW - %@", author];
}

/*
 *  Assign the author text.
 */
-(void) setAuthorText:(NSString *) author asMe:(BOOL) isMe
{
    if (!author) {
        author = [ChatSeal ownerForAnonymousForMe:isMe];
    }
    
    // - save the author text so that we can recreate it easily later.
    if (sAuthor != author) {
        [sAuthor release];
        sAuthor = [author retain];
    }
    isAuthorMe   = isMe;
    
    // - assign the content.
    [lAuthor setText:isRead ? sAuthor : [NSString stringWithFormat:@"NEW - %@", sAuthor]];
    [lAuthor sizeToFit];
    [self setNeedsLayout];
}

/*
 *  Compute a string representing the date to display in the cell.
 */
+(NSString *) messageDateFromDate:(NSDate *) dtCreated
{
    NSString *dateString = NSLocalizedString(@"No Date", nil);
    if (dtCreated) {
        NSDate *dtNow            = [NSDate date];
        NSCalendar *calendar     = [NSCalendar currentCalendar];
        NSUInteger ordDayNow     = [calendar ordinalityOfUnit:NSDayCalendarUnit inUnit:NSEraCalendarUnit forDate:dtNow];
        NSUInteger ordDayCreate  = [calendar ordinalityOfUnit:NSDayCalendarUnit inUnit:NSEraCalendarUnit forDate:dtCreated];
        NSUInteger ordWeekNow    = [calendar ordinalityOfUnit:NSWeekCalendarUnit inUnit:NSEraCalendarUnit forDate:dtNow];
        NSUInteger ordWeekCreate = [calendar ordinalityOfUnit:NSWeekCalendarUnit inUnit:NSEraCalendarUnit forDate:dtCreated];
        if (ordDayNow == ordDayCreate) {
            dateString = NSLocalizedString(@"Today", nil);
        }
        else if (ordDayNow == ordDayCreate + 1) {
            dateString = NSLocalizedString(@"Yesterday", nil);
        }
        else if (ordWeekNow == ordWeekCreate) {
            
            NSDateFormatter *df = [[[NSDateFormatter alloc] init] autorelease];
            [df setLocale:[NSLocale currentLocale]];
            [df setCalendar:[NSCalendar currentCalendar]];
            [df setDateStyle:NSDateFormatterLongStyle];
            [df setTimeStyle:NSDateFormatterNoStyle];
            [df setDateFormat:@"EEEE"];                 //  format the day of the week.
            dateString = [df stringFromDate:dtCreated];
        }
        else {
            NSDateFormatter *df = [[[NSDateFormatter alloc] init] autorelease];
            [df setLocale:[NSLocale currentLocale]];
            [df setCalendar:[NSCalendar currentCalendar]];
            [df setDateStyle:NSDateFormatterShortStyle];
            [df setTimeStyle:NSDateFormatterNoStyle];
            dateString = [df stringFromDate:dtCreated];
        }
    }
    return dateString;
}

/*
 *  Assign a date to the cell.
 */
-(void) setDate:(NSString *) dtCreated
{
    [lCreateDate setText:dtCreated];
    [lCreateDate sizeToFit];
}

/*
 *  Compute the appropriate text to display.
 */
+(NSString *) synopsisTextFromContent:(NSString *) synopsis andCryptoLocked:(BOOL) isLocked
{
    if (isLocked) {
        return NSLocalizedString(@"Locked - Seal Needed", nil);
    }
    else {
        return synopsis;
    }
}

/*
 *  Set up the synopsis.
 */
-(void) setSynopsisText:(NSString *) synopsis andCryptoLocked:(BOOL) isLocked
{
    [lSynopsis setText:[UIMessageOverviewMessageCell synopsisTextFromContent:synopsis andCryptoLocked:isLocked]];
    if (isLocked) {
        tvCellTop.hidden = YES;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    else {
        tvCellTop.hidden  = NO;
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
}

/*
 *  Begin a modification that should be animated.
 */
-(void) beginAnimatedChangeWithLongFade:(BOOL)useLongFade
{
    // - when we're animating this change, create a quick snapshot of the old first.
    // - but, we need to actually snapshot the content view because it will have a proper transparent background
    //   that shows a tap while the change animation is occurring.
    UIView *vwSnapOld                = [self.contentView snapshotViewAfterScreenUpdates:YES];
    vwSnapOld.layer.zPosition        = 2.0f;
    vwSnapOld.userInteractionEnabled = NO;          //  essential, or we can't tap it while this is animating!
    [self.contentView addSubview:vwSnapOld];
    [self.contentView bringSubviewToFront:vwSnapOld];
    lAuthor.alpha                    = 0.0f;
    lCreateDate.alpha                = 0.0f;
    lSynopsis.alpha                  = 0.0f;
    NSTimeInterval fadeDelay         = [ChatSeal standardItemFadeTime];
    if (useLongFade) {
        fadeDelay *= 2.0f;
    }
    [UIView animateWithDuration:fadeDelay animations:^(void) {
        vwSnapOld.alpha   = 0.0f;
        lAuthor.alpha     = 1.0f;
        lCreateDate.alpha = 1.0f;
        lSynopsis.alpha   = 1.0f;
    } completion:^(BOOL finished) {
        [vwSnapOld removeFromSuperview];
    }];
}
@end

