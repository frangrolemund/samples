//
//  UIFeedGenericHeaderFooter.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/23/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIFeedGenericHeaderFooter.h"
#import "UIGenericSizableTableViewCell.h"
#import "ChatSeal.h"

/******************************
 UIFeedGenericHeaderFooter
 ******************************/
@implementation UIFeedGenericHeaderFooter
/*
 *  Object attributes.
 */
{
    BOOL    isHeader;
    UILabel *lText;
}

/*
 *  Return the value of the horizontal pad.
 */
+(CGFloat) horizPadValue
{
    // - these values were chosen to minimize wrapping in the feed screens of the standard big blocks
    //   of text.
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        return 14.0f;
    }
    else {
        return 18.0f;
    }
}

/*
 *  Compute the height that we should make this view.
 */
+(CGFloat) recommendedHeightForText:(NSString *) text andScreenWidth:(CGFloat) width
{
    CGFloat ret                    = 0.0f;
    UIFeedGenericHeaderFooter *ghf = [[UIFeedGenericHeaderFooter alloc] initWithText:text inColor:[UIColor blackColor] asHeader:NO];
    ret                            = [ghf recommendedHeightForScreenWidth:width];
    [ghf release];
    return ret;
}

/*
 *  Reconfigure the text when it might make a difference.
 */
-(void) reconfigureTextForDynamicSizingIfNecessaryDuringInit:(BOOL) isInit
{
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        return;
    }
    [UIAdvancedSelfSizingTools constrainTextLabel:lText withPreferredSettingsAndTextStyle:UIFontTextStyleSubheadline duringInitialization:isInit];
}

/*
 *  Initialize the object.
 */
-(id) initWithText:(NSString *) sText inColor:(UIColor *) c asHeader:(BOOL) isHdr
{
    self = [super init];
    if (self) {
        isHeader                  = isHdr;
        lText                     = [[UILabel alloc] init];
        lText.text                = sText;
        lText.numberOfLines       = 0;
        lText.font                = [UIFont systemFontOfSize:16.0f];
        [self reconfigureTextForDynamicSizingIfNecessaryDuringInit:YES];
        lText.textColor           = c ? c : [ChatSeal defaultTableHeaderFooterTextColor];
        [self addSubview:lText];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [lText release];
    lText = nil;
    
    [super dealloc];
}

/*
 *  Return the dimension of the vertical padding.
 */
-(CGFloat) standardVerticalPad
{
    return lText.font.lineHeight * 0.85f;
}

/*
 *  Perform layout.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];

    CGSize szBounds = self.bounds.size;
    szBounds.width  -= ([UIFeedGenericHeaderFooter horizPadValue] * 2.0f);
    CGFloat vpad    = [self standardVerticalPad];
    CGSize sz       = [lText sizeThatFits:CGSizeMake(szBounds.width, 1.0f)];
    CGFloat topY    = 0.0f;
    if (isHeader) {
        topY = MAX(szBounds.height - vpad - sz.height, 0.0f);
    }
    else {
        topY = vpad;
    }
    lText.frame = CGRectIntegral(CGRectMake([UIFeedGenericHeaderFooter horizPadValue], topY, szBounds.width, sz.height));
    [lText layoutIfNeeded];
}

/*
 *  Return the ideal size for this content.
 */
-(CGSize) sizeThatFits:(CGSize)size
{
    if ([lText.text length] == 0) {
        return CGSizeZero;
    }
    
    [self reconfigureTextForDynamicSizingIfNecessaryDuringInit:NO];
    size.width = MAX(size.width - ([UIFeedGenericHeaderFooter horizPadValue] * 2.0f), 0.0f);
    CGSize sz  = [lText sizeThatFits:size];
    sz.height += ([self standardVerticalPad] * 2.0f);
    return sz;
}

/*
 *  Return the recommended height for this header/footer.
 */
-(CGFloat) recommendedHeightForScreenWidth:(CGFloat) width
{
    CGSize sz = [self sizeThatFits:CGSizeMake(width, 1.0f)];
    return sz.height;
}

@end
