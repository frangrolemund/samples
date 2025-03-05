//
//  UISealedMessageBubbleViewV2.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/10/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//


#import <QuartzCore/QuartzCore.h>
#import "UISealedMessageBubbleViewV2.h"
#import "UIImageGeneration.h"
#import "ChatSeal.h"
#import "CS_messageIndex.h"
#import "UIAdvancedSelfSizingTools.h"

// - constants
static const CGFloat UISMBV_STD_PATH_SIDE            = 40.0f;          // taken from PaintCode as the smallest frame rect that still looks good and can be scaled.
static const CGFloat UISMBV_STD_PATH_SCALE           = 1.5f;
static const CGFloat UISMBV_STD_SCALED_PATH_SIDE     = UISMBV_STD_PATH_SIDE * UISMBV_STD_PATH_SCALE;
static const UIEdgeInsets UISMBV_STD_BUBBLE_PAD      = {5.0f * UISMBV_STD_PATH_SCALE,
                                                        10.0f * UISMBV_STD_PATH_SCALE,
                                                        5.0f * UISMBV_STD_PATH_SCALE,
                                                        15.0f * UISMBV_STD_PATH_SCALE};
static const CGFloat UISMBV_STD_CORNER_RADIUS        = 9.0;
static const CGFloat UISMBV_STD_SCALED_CORNER_RADIUS = UISMBV_STD_CORNER_RADIUS * UISMBV_STD_PATH_SCALE;
static const CGSize  UISMBV_STD_MIN_SCALED_DIMS      = {35.45f * UISMBV_STD_PATH_SCALE, 26.2f * UISMBV_STD_PATH_SCALE};
static const CGFloat UISMBV_LG_FONT_CUTOFF           = 40.0f;
static const CGFloat UISMBV_BUBBLE_HORIZ_PAD         = (10.0f * UISMBV_STD_PATH_SCALE) + (15.0f * UISMBV_STD_PATH_SCALE);           //  - compiler won't let us reference the constant

// - locals
static UIImage *imgBubbleChrome[4];

// -  forward declarations
@interface UISealedMessageBubbleViewV2 (internal)
-(void) commonConfiguration;
+(UILabel *) messageLabelForText:(NSString *) text;
-(void) maskContent;
-(void) updateViewColors;
-(UIColor *) defaultTextColor;
-(void) assignDefaultTextColor;
-(void) releaseCurrentContent;
-(UIImage *) spokenMask;
+(CGFloat) imageChromeLineWidth;
+(UIImage *) imageChromeForSpoken:(BOOL) isSpoken andIsMine:(BOOL) isMine;
-(UIImage *) imageChrome;
-(NSAttributedString *) labelAttributesForBaseString:(NSString *) baseString andSearchText:(NSString *) searchText;
-(void) updateTextColorForSearchWithAnimation:(BOOL) animated;
+(UIBezierPath *) spokenPathAndReturnInsets:(UIEdgeInsets *) insets;
+(UIBezierPath *) unspokenPathAndReturnInsets:(UIEdgeInsets *) insets;
@end

/*********************************
 UISealedMessageBubbleViewV2
 *********************************/
@implementation UISealedMessageBubbleViewV2
/*
 *  Object attributes
 */
{
    BOOL        isMine;
    BOOL        isSpoken;
    UIView      *vwContent;
    UIColor     *cOwner;
    UIColor     *cOther;
    UIColor     *cOwnerText;
    UIColor     *cOtherText;
    UIColor     *cOwnerHighlight;
    UIColor     *cTheirHighlight;
    CGSize      lastSize;
    UIImageView *tapChrome;
    BOOL        isTapped;
    NSString    *currentSearchCriteria;
    BOOL        useConstrainedPreferred;
}

/*
 *  Initialize the module.
 */
+(void) initialize
{
    for (int i = 0; i < 4; i++) {
        imgBubbleChrome[i] = nil;
    }
}

/*
 *  Return the font to use for all styling.
 */
+(UIFont *) preferredBubbleFontAsConstrained:(BOOL) isConstrained
{
    if (isConstrained && [ChatSeal isAdvancedSelfSizingInUse]) {
        return [UIAdvancedSelfSizingTools constrainedFontForPreferredSettingsAndTextStyle:UIFontTextStyleBody];
    }
    else {
        return [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    }
}

/*
 *  This method returns whether the supplied font is considered a 'large'
 *  font for the purposes of display.
 */
+(BOOL) doesFontExceedLargeCutoff:(UIFont *) font
{
    if (font.lineHeight > UISMBV_LG_FONT_CUTOFF) {
        return YES;
    }
    return NO;
}

/*
 *  Return the padding insets.
 */
+(UIEdgeInsets) standardPaddingInsets
{
    return UISMBV_STD_BUBBLE_PAD;
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
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
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
    [self setContent:nil];
    [self setOwnerColor:nil andTheirColor:nil];
    [self setOwnerTextColor:nil andTheirTextColor:nil];
    [self setOwnerHighlightColor:nil andTheirHighlight:nil];
    [currentSearchCriteria release];
    currentSearchCriteria = nil;
    [super dealloc];
}

/*
 *  Set the colors in the bubble view for the background.
 */
-(void) setOwnerColor:(UIColor *) myColor andTheirColor:(UIColor *) theirColor
{
    BOOL wasUpdated = NO;
    if (myColor != cOwner) {
        [cOwner release];
        cOwner = [myColor retain];
        wasUpdated = YES;
    }
    
    if (theirColor != cOther) {
        [cOther release];
        cOther = [theirColor retain];
        wasUpdated = YES;
    }
    
    if (wasUpdated) {
        [self setNeedsLayout];
    }
}

/*
 *  Optionally set the text colors for the view.
 */
-(void) setOwnerTextColor:(UIColor *) myTextColor andTheirTextColor:(UIColor *) theirTextColor
{
    BOOL wasUpdated = NO;
    if (myTextColor != cOwnerText) {
        [cOwnerText release];
        cOwnerText = [myTextColor retain];
        wasUpdated = YES;
    }
    
    if (theirTextColor != cOtherText) {
        [cOtherText release];
        cOtherText = [theirTextColor retain];
        wasUpdated = YES;
    }
    
    if (wasUpdated) {
        [self setNeedsLayout];
    }
}

/*
 *  This method controls which side the content is aligned
 *  with.
 */
-(void) setIsMine:(BOOL) newIsMine
{
    if (isMine == newIsMine) {
        return;
    }
    
    isMine = newIsMine;
    lastSize = CGSizeZero;
    [self assignDefaultTextColor];
    [self setNeedsLayout];
}

/*
 *  Set the highlights for text in the bubble.
 */
-(void) setOwnerHighlightColor:(UIColor *) myHighlight andTheirHighlight:(UIColor *) theirHighlight
{
    if (myHighlight != cOwnerHighlight) {
        [cOwnerHighlight release];
        cOwnerHighlight = [myHighlight retain];
    }
    
    if (theirHighlight != cTheirHighlight) {
        [cTheirHighlight release];
        cTheirHighlight = [theirHighlight retain];
    }
}

/*
 *  Return whether we own this content.
 */
-(BOOL) isMine
{
    return isMine;
}

/*
 *  This method controls whether the message includes a little
 *  speech tick on the bottom side.
 */
-(void) setIsSpoken:(BOOL) newIsSpoken
{
    if (isSpoken == newIsSpoken) {
        return;
    }
    
    isSpoken = newIsSpoken;
    lastSize = CGSizeZero;
    [self setNeedsLayout];
}

/*
 *  Assign new content to the cell.
 */
-(void) setContent:(id)content
{
    if (!content) {
        [self releaseCurrentContent];
        return;
    }
    
    if ([content isKindOfClass:[NSString class]]) {
        //  - don't reallocate the content view unless we need to
        //    because that is a costly operation.
        if ([vwContent isKindOfClass:[UILabel class]]) {
            [(UILabel *) vwContent setText:(NSString *) content];
        }
        else {
            [self releaseCurrentContent];
            vwContent = [[UISealedMessageBubbleViewV2 messageLabelForText:(NSString *) content] retain];
            [self reconfigureLabelsForDynamicTypeDuringInit:YES];
            [self addSubview:vwContent];
        }
        [self assignDefaultTextColor];
    }
    else if ([content isKindOfClass:[UIImage class]]) {
        //  - don't reallocate unless we need to
        if ([vwContent isKindOfClass:[UIImageView class]]) {
            [(UIImageView *) vwContent setImage:(UIImage *) content];
        }
        else {
            [self releaseCurrentContent];
            UIImageView *ivContent    = [[UIImageView alloc] initWithImage:(UIImage *) content];
            ivContent.contentMode     = UIViewContentModeScaleAspectFill;
            vwContent                 = ivContent;
            [self addSubview:vwContent];
            
            // - because this is an image, we need tap chrome and it must be
            //   matched to the mask of this object.
            lastSize                         = CGSizeZero;
            tapChrome                        = [[UIImageView alloc] initWithFrame:ivContent.bounds];
            tapChrome.backgroundColor        = [UIColor clearColor];
            tapChrome.contentMode            = UIViewContentModeScaleToFill;
            tapChrome.autoresizingMask       = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            tapChrome.userInteractionEnabled = NO;
            [ivContent addSubview:tapChrome];
        }
        
        // - in case it was previously hidden.
        tapChrome.alpha = 1.0f;
    }
    else {
        NSAssert(NO, @"Bubble view content may only be of type NSString or UIImage.");
    }

    // - make sure the content is displayed at full alpha if it was previously not
    vwContent.alpha = 1.0f;
    
    //  - make sure the content is correctly positioned.
    [self setNeedsLayout];
}

/*
 *  Returns whether the currently active content is an image.
 */
-(BOOL) isContentAnImage
{
    return [vwContent isKindOfClass:[UIImageView class]];
}

/*
 *  Return the current content.
 */
-(id) content
{
    if ([vwContent isKindOfClass:[UILabel class]]) {
        return ((UILabel *) vwContent).text;
    }
    else if ([vwContent isKindOfClass:[UIImageView class]]) {
        return ((UIImageView *) vwContent).image;
    }
    return nil;
}

/*
 *  Lay out the contents of the cell.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    CGRect rcContent = self.bounds;
    
    //  - text is a bit more special because of the speech radius.
    if ([vwContent isKindOfClass:[UILabel class]]) {        
        CGFloat leftPad  = 0.0f;
        CGFloat rightPad = 0.0f;
        
        // - the standard pad assumes the speech tick is on the right.
        if (isMine || !isSpoken) {
            leftPad = UISMBV_STD_BUBBLE_PAD.left;
        }
        else {
            leftPad = UISMBV_STD_BUBBLE_PAD.right;
        }
        
        if (isMine && isSpoken) {
            rightPad = UISMBV_STD_BUBBLE_PAD.right;
        }
        else {
            rightPad = UISMBV_STD_BUBBLE_PAD.left;
        }
        
        rcContent = CGRectMake(CGRectGetMinX(rcContent) + leftPad,
                               CGRectGetMinY(rcContent) + UISMBV_STD_BUBBLE_PAD.top,
                               CGRectGetWidth(rcContent) - leftPad - rightPad,
                               CGRectGetHeight(rcContent) - UISMBV_STD_BUBBLE_PAD.top - UISMBV_STD_BUBBLE_PAD.bottom);
    }
    
    vwContent.frame    = CGRectIntegral(rcContent);
    [self updateViewColors];
    
    //  - only update the mask when the size of this view changes, which shouldn't be
    //    very often
    CGSize szCur = self.bounds.size;
    if ((int) szCur.width != (int) lastSize.width || (int) szCur.height != (int) lastSize.height) {
        lastSize = szCur;
        [self maskContent];
    }
}

/*
 *  Return the size that is best suited to the requested size and the enclosed content.
 */
-(CGSize) sizeThatFits:(CGSize)size
{
    CGSize ret      = CGSizeZero;
    id content      = nil;
    UILabel *lLabel = nil;
    
    // - first figure out what we're going to size.
    if ([vwContent isKindOfClass:[UILabel class]]) {
        //  - let the label describe the size it requires.
        lLabel  = (UILabel *) vwContent;
        content = lLabel.text;
    }
    else if ([vwContent isKindOfClass:[UIImageView class]]) {
        //  - in the case of images, we'll compute the dimensions ourself.
        UIImageView *iv = (UIImageView *) vwContent;
        if (iv.image) {
            content          = iv.image;
        }
    }
    
    // - there is some good content, so compute the size.
    if (content) {
        ret = [UISealedMessageBubbleViewV2 sizeThatFits:size withContent:content andLabel:lLabel andIsSpoken:isSpoken];
    }
    return ret;
}

/*
 *  Compute an appropriate size for this content.
 */
+(CGSize) sizeThatFits:(CGSize) size withContent:(id) content andIsSpoken:(BOOL) isSpoken
{
    return [UISealedMessageBubbleViewV2 sizeThatFits:size withContent:content andLabel:nil andIsSpoken:isSpoken];
}

/*
 *  Return the appropriate size given the constraints and the content.
 */
+(CGSize) sizeThatFits:(CGSize) size withContent:(id) content andLabel:(UILabel *) label andIsSpoken:(BOOL) isSpoken
{
    CGSize ret       = CGSizeZero;
    BOOL goodContent = NO;
    if ([content isKindOfClass:[NSString class]]) {
        if (!label) {
            static UILabel *lSizer = nil;
            if (!lSizer) {
                lSizer = [[UISealedMessageBubbleViewV2 messageLabelForText:nil] retain];
            }
            UIFont *fontPreferred = [UISealedMessageBubbleViewV2 preferredBubbleFontAsConstrained:NO];
            if (![lSizer.font isEqual:fontPreferred]) {
                lSizer.font = fontPreferred;
            }
            lSizer.text = (NSString *) content;
            label       = lSizer;
        }
        CGFloat targetWidth = size.width - UISMBV_BUBBLE_HORIZ_PAD;
        ret                 = [label sizeThatFits:CGSizeMake(targetWidth, 1.0f)];
        ret.width          += (UISMBV_STD_BUBBLE_PAD.left + UISMBV_STD_BUBBLE_PAD.right);
        ret.height         += (UISMBV_STD_BUBBLE_PAD.top + UISMBV_STD_BUBBLE_PAD.bottom);
        goodContent         = YES;
    }
    else if ([content isKindOfClass:[UIImage class]]) {
        CGSize szImage = [(UIImage *) content size];
        CGFloat ar     = szImage.width/szImage.height;
        
        // - avoid scenarios where an extreme aspect ratio makes the
        //   image look completely odd.
        if (ar > 4.0/3.0f) {
            ar = 4.0f/3.0f;
        }
        else if (ar < 9.0f/16.0f) {
            ar = 9.0f/16.0f;
        }
        
        // - use the longest provided dimension as a limit.
        if (ar > 1.0f) {
            ret = CGSizeMake(size.width, size.width/ar);
            
            // - but also respect the shorter of the two limits.
            if (ret.height > size.height) {
                ret.height = size.height;
                ret.width  = size.height * ar;
            }
        }
        else {
            ret = CGSizeMake(size.height * ar, size.height);
            
            // - but also respect the shorter of the two limits.
            if (ret.width > size.width) {
                ret.width  = size.width;
                ret.height = size.width/ar;
            }
        }
        goodContent = YES;
    }
    
    // - with spoken bubbles, we have a minimum size or the path gets hosed.
    if (goodContent && isSpoken) {
        ret.width  = MAX(ret.width, UISMBV_STD_MIN_SCALED_DIMS.width);
        ret.height = MAX(ret.height, UISMBV_STD_MIN_SCALED_DIMS.height);
    }
    
    return ret;
}

/*
 *  Highlight the item to indicate it was tapped.
 */
-(void) showTapped
{
    if (isTapped || [vwContent isKindOfClass:[UILabel class]]) {
        return;
    }
    isTapped            = YES;
    UIView *vw          = [[[UIView alloc] initWithFrame:self.bounds] autorelease];
    vw.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    vw.backgroundColor  = [UIColor colorWithWhite:0.0f alpha:0.3f];
    [self addSubview:vw];
    [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
        vw.alpha = 0.0f;
    }completion:^(BOOL finished) {
        isTapped = NO;
        [vw removeFromSuperview];
    }];
}

/*
 *  Assign search text to this view.
 */
-(void) setSearchText:(NSString *) searchText
{
    if (![vwContent isKindOfClass:[UILabel class]]) {
        return;
    }
    
    if (currentSearchCriteria == searchText || [currentSearchCriteria isEqualToString:searchText]) {
        return;
    }
    [currentSearchCriteria release];
    currentSearchCriteria = [searchText retain];
    [self updateTextColorForSearchWithAnimation:YES];
}

/*
 *  Request that dynamic content have its font height recomputed.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL) isInit
{
    // - this is used in all versions
    if (vwContent && [vwContent isKindOfClass:[UILabel class]]) {
        // - unlike the other cases in the app, when these items self-size, we will support up to the
        //   really big font sizes.
        UILabel *lContent = (UILabel *) vwContent;
        lContent.font     = [UISealedMessageBubbleViewV2 preferredBubbleFontAsConstrained:useConstrainedPreferred];
    }
}

/*
 *  Display this bubble in a deferred state, which will mute its chrome and stylize it until
 *  content is assigned next.
 */
-(void) setDisplayAsDeferred
{
    tapChrome.alpha = 0.0f;
    vwContent.alpha = 0.5f;
}

/*
 *  This method allows the bubble view to be optionally constrained with its font choices instead of
 *  allowing the largest possible preferred fonts.
 */
-(void) setUseConstrainedPreferredFonts:(BOOL) isEnabled
{
    useConstrainedPreferred = isEnabled;
    [self reconfigureLabelsForDynamicTypeDuringInit:NO];
}

/*
 *  This method returns whether the bubble has text that is very large and probably requires extra 
 *  horizontal space.
 */
-(BOOL) hasExcessivelyLargeText
{
    if ([vwContent isKindOfClass:[UILabel class]]) {
        return [UISealedMessageBubbleViewV2 doesFontExceedLargeCutoff:[(UILabel *) vwContent font]];
    }
    return NO;
}
@end


/***************************************
 UISealedMessageBubbleViewV2 (internal)
 ***************************************/
@implementation UISealedMessageBubbleViewV2 (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    isMine                              = YES;
    isSpoken                            = NO;
    vwContent                           = nil;
    cOwner                              = nil;
    cOther                              = nil;
    lastSize                            = CGSizeZero;
    cOwnerText                          = nil;
    cOtherText                          = nil;
    tapChrome                           = nil;
    isTapped                            = NO;
    self.layer.masksToBounds            = YES;
    currentSearchCriteria               = nil;
    useConstrainedPreferred             = NO;
    self.backgroundColor                = [UIColor clearColor];
    [self setOwnerColor:[UIColor blueColor] andTheirColor:[UIColor redColor]];
}

/*
 *  Generate a label made for texting.
 */
+(UILabel *) messageLabelForText:(NSString *)text
{
    UILabel *l        = [[UILabel alloc] init];
    l.numberOfLines   = 0;
    l.lineBreakMode   = NSLineBreakByWordWrapping;
    l.text            = text;
    l.textColor       = [UIColor blackColor];
    l.backgroundColor = [UIColor clearColor];
    return [l autorelease];
}

/*
 *  Apply an appropriate mask to the content.
 */
-(void) maskContent
{
    self.layer.mask = nil;
    if (isSpoken) {
        self.layer.cornerRadius = 0.0f;
        
        // - and use it to mask the layer.
        CALayer *l            = [[CALayer alloc] init];
        l.frame               = self.layer.bounds;
        UIImage *imgMask      = [self spokenMask];
        l.contents            = (id) [imgMask CGImage];
        CGSize szImage        = imgMask.size;
        UIEdgeInsets insets   = imgMask.alignmentRectInsets;
        CGRect rcCenter       = CGRectMake(insets.left/szImage.width, insets.top/szImage.height,
                                           (szImage.width - (insets.left + insets.right))/szImage.width,
                                           (szImage.height - (insets.top + insets.bottom))/szImage.height);
        l.contentsCenter      = rcCenter;
        l.contentsGravity     = kCAGravityResize;
        l.contentsScale       = [UIScreen mainScreen].scale;
        if (!isMine) {
            l.doubleSided     = YES;
            l.transform       = CATransform3DMakeRotation((CGFloat) M_PI, 0.0f, 1.0f, 0.0f);
        }
        self.layer.mask       = l;
        [l release];
    }
    else {
        self.layer.cornerRadius = UISMBV_STD_SCALED_CORNER_RADIUS;
    }
    
    // - when we're displaying images, we add a slight shadow to them using their tap chrome in order
    //   to make them appear more sunken in the page.
    if (tapChrome) {
        tapChrome.image = [self imageChrome];
    }
}

/*
 *  Compute a custom owner color for the gradient layer background.
 *  - the position is from 0.0f to 1.0f, with 1.0f being closest to the
 *    bottom and at the brightest the color can be.
 */
-(UIColor *) ownerColorForPosition:(CGFloat) position
{
    return [UIImageGeneration adjustColor:cOwner byHuePct:1.0f andSatPct:1.0f andBrPct:1.0f + (1.0f - position) andAlphaPct:1.0f];
}

/*
 *  The view colors are dependent on the ownership of the message.
 */
-(void) updateViewColors
{
    if ([vwContent isKindOfClass:[UILabel class]]) {
        if (isMine) {
            self.backgroundColor = cOwner;
        }
        else {
            self.backgroundColor = cOther;
        }
    }
    else {
        self.backgroundColor = [UIColor clearColor];
    }
}

/*
 *  Return the color of default text in this view.
 */
-(UIColor *) defaultTextColor
{
    return isMine ? (cOwnerText ? cOwnerText : [UIColor whiteColor]) : (cOtherText ? cOtherText : [UIColor blackColor]);
}

/*
 *  Assign the text color if the content is a label.
 */
-(void) assignDefaultTextColor
{
    if ([vwContent isKindOfClass:[UILabel class]]) {
        //  - adjust the text color.
        ((UILabel *) vwContent).textColor = [self defaultTextColor];
    }
}

/*
 *  Release the content view.
 */
-(void) releaseCurrentContent
{
    [tapChrome removeFromSuperview];
    [tapChrome release];
    tapChrome = nil;
    [vwContent removeFromSuperview];
    [vwContent release];
    vwContent = nil;
}

/*
 *  Return a handle to the spoken mask for the layers.
 *  - this mask is generated as a predictable size and must
 *    be stretched.
 *  - this mask will have the tick mark on the right side of the bubble.
 */
-(UIImage *) spokenMask
{
    static UIImage *imgMask = nil;
    
    if (!imgMask) {
        UIEdgeInsets edgeInsets = UIEdgeInsetsZero;
        UIBezierPath *bp        = [UISealedMessageBubbleViewV2 spokenPathAndReturnInsets:&edgeInsets];
        
        // - then draw the bubble.
        // ...start by creating the basic context, but use UIKit because a generic alpha mask does not respect
        //    the contents gravity and centerRect like an RGBA image does.
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(UISMBV_STD_SCALED_PATH_SIDE, UISMBV_STD_SCALED_PATH_SIDE), NO, 0.0f);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGContextSetAllowsAntialiasing(ctx, YES);
        
        [[UIColor whiteColor] setFill];
        [bp fill];
        
        imgMask = UIGraphicsGetImageFromCurrentImageContext();
        imgMask = [imgMask imageWithAlignmentRectInsets:edgeInsets];
        [imgMask retain];
        
        UIGraphicsEndImageContext();
    }
    return imgMask;
}

/*
 *  Return a standard line width for the image chrome.
 */
+(CGFloat) imageChromeLineWidth
{
    return 1.0f/[UIScreen mainScreen].scale;
}

/*
 *  The image chrome is always the same for the most part, so we'll cache our images to
 *  save on processing and memory.
 */
+(UIImage *) imageChromeForSpoken:(BOOL) isSpoken andIsMine:(BOOL) isMine
{
    // - there are four possibilities for image chrome
    int index = 0;
    if (isSpoken) {
        index++;
    }
    if (isMine) {
        index+=2;
    }
    
    UIImage *ret = imgBubbleChrome[index];
    if (ret) {
        return [[ret retain] autorelease];
    }
    
    UIEdgeInsets insets   = UIEdgeInsetsZero;
    UIBezierPath *bp      = nil;
    if (isSpoken) {
        bp = [UISealedMessageBubbleViewV2 spokenPathAndReturnInsets:&insets];
    }
    else {
        bp = [UISealedMessageBubbleViewV2 unspokenPathAndReturnInsets:&insets];
    }
    
    // - then draw the bubble.
    // ...start by creating the basic context, but use UIKit because a generic alpha mask does not respect
    //    the contents gravity and centerRect like an RGBA image does.
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(UISMBV_STD_SCALED_PATH_SIDE, UISMBV_STD_SCALED_PATH_SIDE), NO, 0.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetAllowsAntialiasing(ctx, YES);
    if (!isMine) {
        CGContextTranslateCTM(ctx, UISMBV_STD_SCALED_PATH_SIDE, 0.0f);
        CGContextScaleCTM(ctx, -1.0f, 1.0f);
        CGFloat tmp  = insets.left;
        insets.left  = insets.right;
        insets.right = tmp;
    }
    
    [[UIColor redColor] setFill];       //  debugging color.
    UIColor *shadowColor = [UIColor colorWithWhite:0.0f alpha:0.85f];
    CGContextSetShadowWithColor(ctx, CGSizeMake(0.0f, 0.0f), 1.0f, [shadowColor CGColor]);
    CGContextSetLineWidth(ctx, [self imageChromeLineWidth]);
    [[UIColor lightGrayColor] setStroke];
    [bp stroke];
    ret = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    //  - convert this into a resizable image
    ret                    = [ret resizableImageWithCapInsets:insets];
    imgBubbleChrome[index] = [ret retain];
    return [[ret retain] autorelease];
}

/*
 *  Generate image chrome that matches the current qualities of the object.
 */
-(UIImage *) imageChrome
{
    return [UISealedMessageBubbleViewV2 imageChromeForSpoken:isSpoken andIsMine:isMine];
}

/*
 *  Return an appropriate attributed string that highlights its contents based on their matches with the search content.
 */
-(NSAttributedString *) labelAttributesForBaseString:(NSString *) baseString andSearchText:(NSString *) searchText
{
    NSArray *arr = [CS_messageIndex standardStringSplitWithWhitespace:searchText andAlphaNumOnly:NO];
    
    UIColor *cBaseColor            = [self defaultTextColor];
    NSMutableAttributedString *mas = [[[NSMutableAttributedString alloc] initWithString:baseString] autorelease];
    [mas beginEditing];
    if (baseString && [baseString length]) {
        // - assign the base color first.
        NSUInteger len = [baseString length];
        [mas addAttribute:NSForegroundColorAttributeName value:cBaseColor range:NSMakeRange(0, len)];
        
        // - now search for the text items.
        for (NSString *sItem in arr) {
            NSUInteger curPos = 0;
            @try {
                while (curPos < len) {
                    NSRange r = [baseString rangeOfString:sItem options:NSCaseInsensitiveSearch range:NSMakeRange(curPos, len-curPos)];
                    if (r.location == NSNotFound) {
                        break;
                    }
                    [mas addAttribute:NSForegroundColorAttributeName value:isMine ? cOwnerHighlight : cTheirHighlight range:r];
                    curPos = r.location + r.length;
                }
            }
            @catch (NSException *exception) {
                // ignore.
            }
        }
    }
    
    [mas endEditing];
    return mas;
}

/*
 *  Assign the text colors.
 */
-(void) updateTextColorForSearchWithAnimation:(BOOL) animated
{
    // - update the content using the search text.
    UILabel *lContent = (UILabel *) vwContent;
    NSString *sText        = nil;
    if (lContent.text) {
        sText = lContent.text;
    }
    else {
        sText = lContent.attributedText.string;
    }
    
    // - animate the changes to this view.
    if (animated) {
        // - this trick with the snapshot will only work if this view is
        //   laid out and visible, but I consider that to be a reasonable
        //   expectation based on how I intend to use this.
        UIView *vwSnap = [lContent snapshotViewAfterScreenUpdates:NO];
        if (vwSnap) {
            vwSnap.center  = lContent.center;
            [self addSubview:vwSnap];
        }
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            vwSnap.alpha = 0.0f;
        } completion:^(BOOL finished) {
            [vwSnap removeFromSuperview];
        }];
    }
    
    // - we need to figure out if we're assigning or clearing it.
    if (currentSearchCriteria) {
        // - build up the attributed text with the content identified.
        lContent.attributedText = [self labelAttributesForBaseString:sText andSearchText:currentSearchCriteria];
    }
    else {
        // - when we're moving from an attributed string, just make
        //   sure it is cleared out.
        if (lContent.attributedText) {
            lContent.text           = sText;
            [self assignDefaultTextColor];
        }
    }
}

/*
 *  Allocate and return a spoken path.
 */
+(UIBezierPath *) spokenPathAndReturnInsets:(UIEdgeInsets *) insets
{
    // - just use the code straight from PaintCode, with a fixed rectangle because the idea is to get something that
    //   we can predictably scale.  Their adjustable paths make it possible to figure out the ideal sizing space based
    //   on quantities we can measure.
    
    CGRect frame = CGRectMake(0.0f, 0.0f, UISMBV_STD_PATH_SIDE, UISMBV_STD_PATH_SIDE);
    
    //// Bezier 2 Drawing
    UIBezierPath* bezier2Path = UIBezierPath.bezierPath;
    [bezier2Path moveToPoint: CGPointMake(CGRectGetMaxX(frame) - 14.91f, CGRectGetMinY(frame) + 0.74f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 10.22f, CGRectGetMinY(frame) + 2.93f) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 12.77f, CGRectGetMinY(frame) + 1.31f) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 12.05f, CGRectGetMinY(frame) + 1.66f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 7.44f, CGRectGetMinY(frame) + 5.62f) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 9.4f, CGRectGetMinY(frame) + 3.5f) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 8.27f, CGRectGetMinY(frame) + 4.39f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 5.44f, CGRectGetMinY(frame) + 9.65f) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 6.37f, CGRectGetMinY(frame) + 7.2f) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 6.06f, CGRectGetMinY(frame) + 7.8f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 4.93f, CGRectGetMinY(frame) + 12.6f) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 5.36f, CGRectGetMinY(frame) + 9.89f) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 5.05f, CGRectGetMinY(frame) + 11.06f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 4.61f, CGRectGetMaxY(frame) - 12.71f) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 4.7f, CGRectGetMinY(frame) + 15.72f) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 4.64f, CGRectGetMaxY(frame) - 13.09f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 4.5f, CGRectGetMaxY(frame) - 11.79f) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 4.57f, CGRectGetMaxY(frame) - 12.13f) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 4.57f, CGRectGetMaxY(frame) - 11.9f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 0.47f, CGRectGetMaxY(frame) - 5.67f) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 2.67f, CGRectGetMaxY(frame) - 8.92f) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 1.75f, CGRectGetMaxY(frame) - 8.0f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 0.74f, CGRectGetMaxY(frame) - 4.05f) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 0.09f, CGRectGetMaxY(frame) - 4.99f) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 0.15f, CGRectGetMaxY(frame) - 4.62f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 1.68f, CGRectGetMaxY(frame) - 3.74f) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 1.03f, CGRectGetMaxY(frame) - 3.77f) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 1.29f, CGRectGetMaxY(frame) - 3.79f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 2.64f, CGRectGetMaxY(frame) - 3.97f) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 1.99f, CGRectGetMaxY(frame) - 3.69f) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 2.34f, CGRectGetMaxY(frame) - 3.86f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 6.81f, CGRectGetMaxY(frame) - 5.16f) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 2.64f, CGRectGetMaxY(frame) - 3.97f) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 6.41f, CGRectGetMaxY(frame) - 5.29f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 7.65f, CGRectGetMaxY(frame) - 4.76f) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 7.22f, CGRectGetMaxY(frame) - 5.04f) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 7.39f, CGRectGetMaxY(frame) - 5.01f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 8.25f, CGRectGetMaxY(frame) - 4.13f) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 7.93f, CGRectGetMaxY(frame) - 4.49f) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 8.05f, CGRectGetMaxY(frame) - 4.34f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 9.75f, CGRectGetMaxY(frame) - 2.79f) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 8.64f, CGRectGetMaxY(frame) - 3.72f) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 9.29f, CGRectGetMaxY(frame) - 3.16f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 13.74f, CGRectGetMaxY(frame) - 0.7f) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 10.72f, CGRectGetMaxY(frame) - 2.14f) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 12.92f, CGRectGetMaxY(frame) - 0.91f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 17.45f, CGRectGetMaxY(frame) - 0.16f) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 14.9f, CGRectGetMaxY(frame) - 0.4f) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 15.53f, CGRectGetMaxY(frame) - 0.28f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 12.45f, CGRectGetMaxY(frame) - 0.18f) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 23.9f, CGRectGetMaxY(frame) - 0.2f) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 16.0f, CGRectGetMaxY(frame) - 0.12f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 8.9f, CGRectGetMaxY(frame) - 0.83f) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 12.2f, CGRectGetMaxY(frame) - 0.16f) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 10.62f, CGRectGetMaxY(frame) - 0.27f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 5.6f, CGRectGetMaxY(frame) - 2.5f) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 7.75f, CGRectGetMaxY(frame) - 1.2f) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 6.57f, CGRectGetMaxY(frame) - 1.84f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 1.28f, CGRectGetMaxY(frame) - 7.6f) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 3.66f, CGRectGetMaxY(frame) - 3.82f) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 2.07f, CGRectGetMaxY(frame) - 5.92f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 0.12f, CGRectGetMaxY(frame) - 14.27f) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 0.85f, CGRectGetMaxY(frame) - 8.5f) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 0.18f, CGRectGetMaxY(frame) - 12.24f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 0.28f, CGRectGetMinY(frame) + 10.83f) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 0.07f, CGRectGetMaxY(frame) - 15.59f) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 0.19f, CGRectGetMinY(frame) + 11.52f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 2.48f, CGRectGetMinY(frame) + 5.72f) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 0.53f, CGRectGetMinY(frame) + 8.98f) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 1.4f, CGRectGetMinY(frame) + 7.02f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 4.84f, CGRectGetMinY(frame) + 3.18f) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 3.14f, CGRectGetMinY(frame) + 4.92f) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 3.89f, CGRectGetMinY(frame) + 3.89f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 8.18f, CGRectGetMinY(frame) + 1.22f) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 5.83f, CGRectGetMinY(frame) + 2.45f) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 7.04f, CGRectGetMinY(frame) + 1.66f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 12.89f, CGRectGetMinY(frame) + 0.25f) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 10.35f, CGRectGetMinY(frame) + 0.37f) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 12.39f, CGRectGetMinY(frame) + 0.32f)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 14.91f, CGRectGetMinY(frame) + 0.74f) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 25.64f, CGRectGetMinY(frame) + 0.19f) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 17.31f, CGRectGetMinY(frame) + 0.36f)];
    [bezier2Path closePath];
    
    bezier2Path.lineCapStyle  = kCGLineCapRound;
    bezier2Path.lineJoinStyle = kCGLineJoinRound;
    
    // - scale the path if necessary.
    [bezier2Path applyTransform:CGAffineTransformMakeScale(UISMBV_STD_PATH_SCALE, UISMBV_STD_PATH_SCALE)];
    
    // - compute the insets, if requested, which are given in the same units as the path itself.
    if (insets) {
        // - in PaintCode, I simply measured against the standard frame frame I defined for this.
        *insets = UIEdgeInsetsMake(15.0f * UISMBV_STD_PATH_SCALE, 14.0f * UISMBV_STD_PATH_SCALE, 20.0f * UISMBV_STD_PATH_SCALE, 24.0f * UISMBV_STD_PATH_SCALE);
    }
    
    return bezier2Path;
}

/*
 *  Return a path without the chat tick.
 */
+(UIBezierPath *) unspokenPathAndReturnInsets:(UIEdgeInsets *) insets
{
    UIBezierPath *bp = [UIBezierPath bezierPath];
    
    CGFloat pathRadius    = UISMBV_STD_CORNER_RADIUS;
    CGFloat pathCenter    = UISMBV_STD_PATH_SIDE - (pathRadius * 2.0f);
    
    CGRect rcBubble       = CGRectMake(0.0f, 0.0f, UISMBV_STD_PATH_SIDE, UISMBV_STD_PATH_SIDE);
    
    // - we're going to hit four separate points around the rectangle, starting
    //   at the top left, which we actually process twice in order to use the same computation for
    //   initial positioning.
    CGFloat qtrArc   = (CGFloat) M_PI/2.0f;
    CGFloat curAngle = -qtrArc*2.0f;
    CGFloat dx       = 0.0f;
    CGFloat dy       = 0.0f;
    CGPoint ptCur    = CGPointZero;
    for (int i = 0; i < 5; i++) {
        if (i > 0) {
            [bp addArcWithCenter:CGPointMake(ptCur.x + (dx * pathRadius), ptCur.y + (dy * pathRadius)) radius:pathRadius startAngle:curAngle endAngle:curAngle + qtrArc clockwise:YES];
            curAngle += qtrArc;
        }
        
        switch (i) {
            case 0:
            case 4:
                dx = 1.0f;
                dy = 0.0f;
                ptCur = CGPointMake(CGRectGetMinX(rcBubble), CGRectGetMinY(rcBubble) + pathRadius);
                break;
                
            case 1:
                dx = 0.0f;
                dy = 1.0f;
                ptCur = CGPointMake(CGRectGetMaxX(rcBubble) - pathRadius, CGRectGetMinY(rcBubble));
                break;
                
            case 2:
                dx = -1.0f;
                dy = 0.0f;
                ptCur = CGPointMake(CGRectGetMaxX(rcBubble), CGRectGetMaxY(rcBubble) - pathRadius);
                break;
                
            case 3:
                dx = 0.0f;
                dy = -1.0f;
                ptCur = CGPointMake(CGRectGetMinX(rcBubble) + pathRadius, CGRectGetMaxY(rcBubble));
                break;
        }
        
        if (i > 0) {
            [bp addLineToPoint:CGPointMake(ptCur.x, ptCur.y)];
        }
        else {
            [bp moveToPoint:CGPointMake(ptCur.x, ptCur.y)];
        }
    }
    
    [bp applyTransform:CGAffineTransformMakeScale(UISMBV_STD_PATH_SCALE, UISMBV_STD_PATH_SCALE)];
    
    // - if insets are requested, generate them now.
    if (insets) {
        *insets = UIEdgeInsetsMake(pathRadius * UISMBV_STD_PATH_SCALE,
                                   pathRadius * UISMBV_STD_PATH_SCALE,
                                   pathRadius * UISMBV_STD_PATH_SCALE,
                                   (pathRadius + pathCenter - 1.0f) * UISMBV_STD_PATH_SCALE);
    }
    
    return bp;
}
@end
