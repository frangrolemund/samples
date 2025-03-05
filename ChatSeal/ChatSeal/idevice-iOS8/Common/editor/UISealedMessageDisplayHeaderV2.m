//
//  UISealedMessageDisplayHeaderV2.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/6/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealedMessageDisplayHeaderV2.h"
#import "ChatSeal.h"
#import "CS_messageIndex.h"
#import "UIAdvancedSelfSizingTools.h"

// - constants
static const CGFloat UISMDH_BORDER_PAD             = 12.0f;
static const CGFloat UISMDH_STD_PAD                = 8.0f;
static const CGFloat UISMDH_DATE_PAD               = 12.0f;
static const CGFloat UISMDH_DATE_MIN_SCALE         = 0.85f;
static const CGFloat UISMDH_DATE_MIN_SCALE_DISPLAY = UISMDH_DATE_MIN_SCALE * 1.10f;             //  needs to be a bit wider to make this work.
static const CGFloat UISMDH_FONT_SCALE             = 0.85f;

// - forward declarations
@interface UISealedMessageDisplayHeaderV2 (internal)
-(void) commonConfiguration;
-(void) updateTextForCurrentSearchCriteriaWithAnimation:(BOOL) animated;
+(UIFont *) boldHeaderFont;
+(UIFont *) timeDisplayFont;
-(void) adjustAttributes:(NSMutableAttributedString *) mas withSearchItems:(NSArray *) arrToSearch;
@end

/***********************************
 UISealedMessageDisplayHeaderV2
 ***********************************/
@implementation UISealedMessageDisplayHeaderV2
/*
 *  Object attributes.
 */
{
    UILabel    *lNewItem;
    UILabel    *lAuthor;
    UILabel    *lDetails;
    UILabel    *lShortDetails;
    NSString   *msgAuthor;
    UIColor    *msgColor;
    NSDate     *msgDate;
    BOOL       isMsgOwner;
    BOOL       isReadItem;
    NSString   *curSearchCriteria;
    UIColor    *cHighlightColor;    
}

/*
 *  Compute the height at which to size the header.
 */
+(CGFloat) referenceHeight
{
    UIFont *fnt = [UISealedMessageDisplayHeaderV2 boldHeaderFont];
    UILabel *l  = [[UILabel alloc] init];
    l.font = fnt;
    l.text = @"W";
    [l sizeToFit];
    CGFloat refHeight = l.bounds.size.height + (UISMDH_STD_PAD * 2.0f);
    [l release];
    return refHeight;
}

/*
 *  Initialize the object.
 */
-(id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonConfiguration];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [lNewItem release];
    lNewItem = nil;
    
    [lAuthor release];
    lAuthor = nil;
    
    [lDetails release];
    lDetails = nil;
    
    [lShortDetails release];
    lShortDetails = nil;
    
    [msgAuthor release];
    msgAuthor = nil;
    
    [msgColor release];
    msgColor = nil;
    
    [msgDate release];
    msgDate = nil;
    
    [curSearchCriteria release];
    curSearchCriteria = nil;
    
    [cHighlightColor release];
    cHighlightColor = nil;
    
    [super dealloc];
}

/*
 *  Assign the author and date.
 */
-(void) setAuthor:(NSString *) author usingColor:(UIColor *) authorColor asOwner:(BOOL) isOwner onDate:(NSDate *) date asRead:(BOOL) isRead
{
    if (author != msgAuthor) {
        [msgAuthor release];
        msgAuthor = [author retain];
    }
    
    if (authorColor != msgColor) {
        [msgColor release];
        msgColor = [authorColor retain];
    }
    
    if (date != msgDate) {
        [msgDate release];
        msgDate = [date retain];
    }
    
    if (!date) {
        [lAuthor setText:nil];
        [lDetails setText:nil];
        return;
    }
    
    // - I'm not going to create these every time because they aren't used as a rule.
    if (!isRead && !lNewItem) {
        lNewItem               = [[UILabel alloc] init];
        lNewItem.textAlignment = NSTextAlignmentLeft;
        lNewItem.numberOfLines = 1;
        lNewItem.textColor     = [ChatSeal defaultAppTintColor];
        [self addSubview:lNewItem];
    }
    lNewItem.text = (!isRead) ? NSLocalizedString(@"NEW", nil) : nil;
    
    isMsgOwner = isOwner;
    isReadItem = isRead;
    [self updateTextForCurrentSearchCriteriaWithAnimation:NO];
}

/*
 *  Layout the header.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    CGSize sz          = self.bounds.size;
    
    // - the idea here is to always favor the unread distinction and the
    //   author name, while omitting the date when it doesn't fit.
    if (isReadItem) {
        lNewItem.bounds = CGRectZero;
    }
    else {
        [lNewItem sizeToFit];
    }
    CGSize szItem  = lNewItem.bounds.size;
    lNewItem.frame = CGRectIntegral(CGRectMake(UISMDH_BORDER_PAD, (sz.height - szItem.height)/2.0f, CGRectGetWidth(lNewItem.bounds), szItem.height));
    
    [lAuthor sizeToFit];
    szItem = lAuthor.bounds.size;
    CGFloat offsetX = (lNewItem && !isReadItem) ? CGRectGetMaxX(lNewItem.frame) : UISMDH_BORDER_PAD;
    CGFloat remain  = sz.width - UISMDH_BORDER_PAD - offsetX;
    if (!isReadItem) {
        remain -= UISMDH_STD_PAD;
    }
    lAuthor.frame  = CGRectIntegral(CGRectMake(offsetX + (isReadItem ? 0.0f : UISMDH_STD_PAD), (sz.height - szItem.height)/2.0f, MIN(CGRectGetWidth(lAuthor.bounds), remain), szItem.height));

    // - the details will be placed at the end.
    [lDetails sizeToFit];
    szItem              = lDetails.bounds.size;
    remain              = sz.width - UISMDH_BORDER_PAD - CGRectGetMaxX(lAuthor.frame) - UISMDH_DATE_PAD;
    lShortDetails.alpha = 0.0f;
    if (remain > (szItem.width * UISMDH_DATE_MIN_SCALE_DISPLAY)) {
        lDetails.alpha      = 1.0f;
        CGFloat detailWidth = MIN(remain, szItem.width);
        lDetails.frame      = CGRectIntegral(CGRectMake(sz.width - UISMDH_DATE_PAD - detailWidth, (sz.height - szItem.height)/2.0f, detailWidth, szItem.height));
    }
    else {
        // - there isn't enough room for the full date.  Can we display something?
        if (!lShortDetails.text) {
            lShortDetails.text = [NSDateFormatter localizedStringFromDate:msgDate dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterNoStyle];
        }
        [lShortDetails sizeToFit];
        szItem = lShortDetails.bounds.size;
        if (remain > szItem.width) {
            lShortDetails.frame = CGRectIntegral(CGRectMake(sz.width - UISMDH_DATE_PAD - szItem.width, CGRectGetMaxY(lAuthor.frame) - szItem.height, szItem.width, szItem.height));
            lShortDetails.alpha = 1.0f;
        }
        lDetails.alpha = 0.0f;
    }
}
/*
 *  Assign the search text to this view.
 */
-(void) setSearchText:(NSString *)searchText withHighlight:(UIColor *)cHighlight
{
    if (cHighlightColor != cHighlight) {
        [cHighlightColor release];
        cHighlightColor = [cHighlight retain];
    }
    
    if (curSearchCriteria != searchText && ![curSearchCriteria isEqualToString:searchText]) {
        [curSearchCriteria release];
        curSearchCriteria = [searchText retain];
        [self updateTextForCurrentSearchCriteriaWithAnimation:YES];
    }
}

@end

/******************************************
 UISealedMessageDisplayHeaderV2 (internal)
 ******************************************/
@implementation UISealedMessageDisplayHeaderV2 (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    // - no content to begin with
    msgAuthor        = nil;
    msgColor         = nil;
    msgDate          = nil;
    isMsgOwner       = NO;
    
    // - the sticky headers need to be distinguished from the content.
    self.backgroundColor        = [UIColor colorWithWhite:1.0f alpha:0.95f];
    self.userInteractionEnabled = NO;
    
    //  - there is just one element and it will be an attributed string.
    lAuthor               = [[UILabel alloc] init];
    lAuthor.textAlignment = NSTextAlignmentRight;
    lAuthor.numberOfLines = 1;
    [self addSubview:lAuthor];
    lDetails                    = [[UILabel alloc] init];
    lDetails.textAlignment      = NSTextAlignmentLeft;
    lDetails.numberOfLines      = 1;
    lDetails.minimumScaleFactor = UISMDH_DATE_MIN_SCALE;                    //  we will allow it to be scaled down to allow it to be displayed partially
    lDetails.adjustsFontSizeToFitWidth = YES;
    [self addSubview:lDetails];
    lShortDetails               = [[UILabel alloc] init];
    lShortDetails.textAlignment = NSTextAlignmentLeft;
    lShortDetails.numberOfLines = 1;
    lShortDetails.textColor     = [UIColor lightGrayColor];
    lShortDetails.font          = [UISealedMessageDisplayHeaderV2 timeDisplayFont];
    [self addSubview:lShortDetails];
}


/*
 *  Update the text to match the header criteria.
 */
-(void) updateTextForCurrentSearchCriteriaWithAnimation:(BOOL) animated
{
    NSArray *arr = nil;
    if (curSearchCriteria) {
        arr = [CS_messageIndex standardStringSplitWithWhitespace:curSearchCriteria andAlphaNumOnly:NO];
    }
    
    // - animate the changes
    if (animated && self.superview) {
        CGRect rc      = self.frame;
        UIView *vwSnap = [self.superview resizableSnapshotViewFromRect:rc afterScreenUpdates:NO withCapInsets:UIEdgeInsetsZero];        // to get the background.
        vwSnap.center  = CGPointMake(CGRectGetWidth(self.bounds)/2.0f, CGRectGetHeight(self.bounds)/2.0f);
        [self addSubview:vwSnap];
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            vwSnap.alpha = 0.0f;
        }completion:^(BOOL finished) {
            [vwSnap removeFromSuperview];
        }];
    }
    
    // - retrieve the font used for presenting the content.
    UIFont *fontBold  = [UISealedMessageDisplayHeaderV2 boldHeaderFont];
    
    // - the new item is always presented the same way.
    lNewItem.font     = fontBold;
    
    // - assign the author's entry.
    if (curSearchCriteria && msgAuthor) {
        NSMutableAttributedString *mas = [[[NSMutableAttributedString alloc] initWithString:msgAuthor] autorelease];
        NSUInteger len = [msgAuthor length];
        if (len) {
            NSRange rFull = NSMakeRange(0, len);
            [mas beginEditing];
            [mas addAttribute:NSFontAttributeName value:fontBold range:rFull];
            [mas addAttribute:NSForegroundColorAttributeName value:msgColor range:rFull];
            [mas endEditing];
            [self adjustAttributes:mas withSearchItems:arr];
        }
        lAuthor.attributedText = mas;
    }
    else {
        lAuthor.font      = fontBold;
        lAuthor.textColor = msgColor;
        lAuthor.text      = msgAuthor;
    }
    
    //  - compute the text for the date/time segment and assign it
    NSMutableAttributedString *mas = [ChatSealMessageEntry standardDisplayDetailsForAuthorSuffix:@"" withAuthorColor:msgColor andBoldFont:fontBold onDate:msgDate
                                                                                  withTimeString:nil andTimeFont:[UISealedMessageDisplayHeaderV2 timeDisplayFont]];
    [self adjustAttributes:mas withSearchItems:arr];
    lDetails.attributedText = mas;
    
    // - when there isn't enough room to display the full string, present an abbreviated date, but on demand
    lShortDetails.text = nil;
}

/*
 *  Return a header font in bold.
 */
+(UIFont *) boldHeaderFont
{
    UIFont *fnt = [UIAdvancedSelfSizingTools constrainedFontForPreferredSettingsAndTextStyle:UIFontTextStyleHeadline andSizeScale:UISMDH_FONT_SCALE andMinHeight:12.0f];
    return [UIFont boldSystemFontOfSize:fnt.pointSize];
}

/*
 *  Return the proper font for displaying message entry time.
 */
+(UIFont *) timeDisplayFont
{
    return [UIAdvancedSelfSizingTools constrainedFontForPreferredSettingsAndTextStyle:UIFontTextStyleSubheadline andSizeScale:UISMDH_FONT_SCALE andMinHeight:10.0f];
}

/*
 *  Look for the search items in the attributes and adjust them to have highlights.
 */
-(void) adjustAttributes:(NSMutableAttributedString *) mas withSearchItems:(NSArray *) arrToSearch
{
    NSString *sText        = mas.string;
    NSUInteger len         = [sText length];
    if (sText && [arrToSearch count]) {
        [mas beginEditing];
        [mas addAttribute:NSBackgroundColorAttributeName value:[UIColor clearColor] range:NSMakeRange(0, len)];
        
        for (NSString *sItem in arrToSearch) {
            NSUInteger curPos = 0;
            @try {
                while (curPos < len) {
                    NSRange r = [sText rangeOfString:sItem options:NSCaseInsensitiveSearch range:NSMakeRange(curPos, len-curPos)];
                    if (r.location == NSNotFound) {
                        break;
                    }
                    [mas addAttribute:NSBackgroundColorAttributeName value:cHighlightColor range:r];
                    [mas addAttribute:NSForegroundColorAttributeName value:msgColor range:r];
                    curPos = r.location + r.length;
                }
            }
            @catch (NSException *exception) {
                //  ignore
            }
        }
        
        [mas endEditing];
    }
}
@end
