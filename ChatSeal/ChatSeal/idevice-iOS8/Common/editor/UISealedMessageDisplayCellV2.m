//
//  UISealedMessageDisplayCellV2.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/6/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealedMessageDisplayCellV2.h"
#import "UISealedMessageBubbleViewV2.h"
#import "ChatSeal.h"

// - constants
static const CGFloat UISMDC_CELL_PAD                = 10.0f;
static const CGFloat UISMDC_FULL_HORIZ_PAD          = (UISMDC_CELL_PAD * 2.0f);
static const CGFloat UISMDC_MAX_IMAGE_WIDTH         = 150.0f;
static const CGFloat UISMDC_MIN_IMAGE_HEIGHT        = 96.0f;
static const CGFloat UISMDC_MAX_IMAGE_HEIGHT        = 125.0f;
static const CGFloat UISMDC_STD_OWNERSHIP_PAD       = 80.0f;
static const CGFloat UISMDC_WIDE_TEXT_OWNERSHIP_PAD = 30.0f;


// - forward declarations
@interface UISealedMessageDisplayCellV2 (internal)
-(void) commonConfiguration;
+(UISealedMessageBubbleViewV2 *) bubbleViewForContent:(id) content;
+(CGFloat) maximumContentWidth;
-(CGSize) bubbleSizeForCellSize:(CGSize) sz;
@end

/*****************************
 UISealedMessageDisplayCellV2
 *****************************/
@implementation UISealedMessageDisplayCellV2
/*
 *  Object attributes.
 */
{
    UISealedMessageBubbleViewV2  *bvContent;
    BOOL                         isDeferred;
}

/*
 *  Compute the cell height for the given image.
 *  - the objective is to as closely match the current bitmap resolution as possible, but
 *    not to shrink any lower than is necessary.
 */
+(CGFloat) minimumCellHeightForImage:(UIImage *) image
{
    if (!image) {
        return 0.0f;
    }
    
    return [UISealedMessageDisplayCellV2 minimumCellHeightForImageOfSize:image.size];
}

/*
 *  Return a cell height for an image of a given size.
 */
+(CGFloat) minimumCellHeightForImageOfSize:(CGSize) szImage
{
    // - compute the best option based on the
    //   aspect ratio
    CGFloat ret = szImage.height;
    if (ret < UISMDC_MIN_IMAGE_HEIGHT) {
        ret = UISMDC_MIN_IMAGE_HEIGHT;
    }
    else {
        // - the image is larger than the minimum, so we need to see if it exceeds the maximum
        if (ret > UISMDC_MAX_IMAGE_HEIGHT) {
            ret = UISMDC_MAX_IMAGE_HEIGHT;
        }
    }
    
    return ret + (UISMDC_CELL_PAD * 2.0f);
}

/*
 *  Compute the cell height for the given block of text.
 */
+(CGFloat) minimumCellHeightForText:(NSString *) text inCellWidth:(CGFloat) width
{
    if (!text) {
        return 0.0f;
    }
    
    width      -= UISMDC_FULL_HORIZ_PAD;
    width       = MIN(width, [UISealedMessageDisplayCellV2 maximumContentWidth]);
    
    // - the bubble won't extend to the edge of the cell in portrait mode to give some indication of who
    //   owns it, but we need to pad less when the text is really big or it will look squashed.
    UIFont *fnt = [UISealedMessageBubbleViewV2 preferredBubbleFontAsConstrained:NO];
    if ([UISealedMessageBubbleViewV2 doesFontExceedLargeCutoff:fnt]) {
        width  -= UISMDC_WIDE_TEXT_OWNERSHIP_PAD;
    }
    else {
        width  -= UISMDC_STD_OWNERSHIP_PAD;
    }
    CGSize sz = [UISealedMessageBubbleViewV2 sizeThatFits:CGSizeMake(MAX(width, 0.0f), 1.0f) withContent:text andIsSpoken:NO];
    return sz.height + (UISMDC_CELL_PAD * 2.0f);
}

/*
 *  A fast placeholder is important because when we are scrolling fast, we don't want to decrypt cells that
 *  aren't actually be on screen long enough to see.
 */
+(UIImage *) genericFastScrollingPlaceholderImage
{
    static UIImage *imgFast = nil;
    if (!imgFast) {
        //  - the placeholder is going to just be an image sized to something close to the maximum dimension
        //    and blurred out so that it gives the hint of something without being too definitive about
        //    it.
        CGFloat oneSide = 128.0f;
        CGSize szDims = CGSizeMake(oneSide, oneSide);
        UIGraphicsBeginImageContextWithOptions(szDims, YES, [UIScreen mainScreen].scale);
        
        [[UIColor whiteColor] setFill];
        UIRectFill(CGRectMake(0.0f, 0.0f, szDims.width, szDims.height));
        
        // - scale for PaintCode
        CGFloat paintCodeSide = 552.0f;
        CGFloat scale         = oneSide/paintCodeSide;
        CGContextScaleCTM(UIGraphicsGetCurrentContext(), scale, scale);
        
        // - taken from PaintCode
        //// Color Declarations
        UIColor* color5 = [UIColor colorWithRed: 0.196f green: 0.204f blue: 0.231f alpha: 0.75f];
        CGFloat color5HSBA[4];
        [color5 getHue: &color5HSBA[0] saturation: &color5HSBA[1] brightness: &color5HSBA[2] alpha: &color5HSBA[3]];
        
        UIColor* color7 = [UIColor colorWithHue: color5HSBA[0] saturation: color5HSBA[1] brightness: 0.3f alpha: color5HSBA[3]];
        CGFloat color7HSBA[4];
        [color7 getHue: &color7HSBA[0] saturation: &color7HSBA[1] brightness: &color7HSBA[2] alpha: &color7HSBA[3]];
        
        UIColor* color8 = [UIColor colorWithHue: color7HSBA[0] saturation: color7HSBA[1] brightness: 0.7f alpha: color7HSBA[3]];
        UIColor* color6 = [UIColor colorWithRed: 0.255f green: 0.263f blue: 0.286f alpha: 0.75f];
        
        //// Oval 12 Drawing
        UIBezierPath* oval12Path = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(-42.94f, -27.72f, 197.48f, 197.48f)];
        [color6 setFill];
        [oval12Path fill];
        
        
        //// Oval 14 Drawing
        UIBezierPath* oval14Path = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(61.38f, 343.97f, 224.06f, 226.09f)];
        [color6 setFill];
        [oval14Path fill];
        
        
        //// Oval 16 Drawing
        UIBezierPath* oval16Path = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(391.12f, 34.55f, 221.73f, 223.74f)];
        [color6 setFill];
        [oval16Path fill];
        
        
        //// Oval Drawing
        UIBezierPath* ovalPath = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(330.85f, 105.36f, 170.02f, 171.56f)];
        [color8 setFill];
        [ovalPath fill];
        
        
        //// Oval 2 Drawing
        UIBezierPath* oval2Path = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(199.04f, 318.35f, 170.02f, 171.56f)];
        [color8 setFill];
        [oval2Path fill];
        
        
        //// Oval 3 Drawing
        UIBezierPath* oval3Path = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(76.56f, 68.43f, 170.02f, 171.56f)];
        [color8 setFill];
        [oval3Path fill];
        
        
        //// Oval 4 Drawing
        UIBezierPath* oval4Path = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(420.47f, 421.58f, 224.06f, 226.09f)];
        [color6 setFill];
        [oval4Path fill];



        imgFast = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        // - finally, blur it
        imgFast = [[ChatSeal generateFrostedImageOfType:CS_FS_EXTRA_LIGHT fromImage:imgFast atScale:1.0f] retain];
    }
    return imgFast;
}

/*
 *  Return the height of the padding in the cell.
 */
+(CGFloat) verticalPaddingHeight
{
    return UISMDC_CELL_PAD;
}

/*
 *  Initialize the object.
 */
-(id) initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
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
    [bvContent release];
    bvContent = nil;
        
    [super dealloc];
}

/*
 *  Adjust the color of the bubble.
 */
-(void) setOwnerBubbleColor:(UIColor *) c
{
    [bvContent setOwnerColor:c andTheirColor:[ChatSeal defaultRemoteUserChatColor]];
}

/*
 *  Assign the colors to be used for highlights.
 */
-(void) setOwnerHighlightColor:(UIColor *) myHighlight andTheirHighlight:(UIColor *) theirHighlight
{
    [bvContent setOwnerHighlightColor:myHighlight andTheirHighlight:theirHighlight];
}

/*
 *  This method controls which side the content is aligned
 *  with.
 */
-(void) setIsMine:(BOOL) isMine
{
    [bvContent setIsMine:isMine];
    [self setNeedsLayout];
}

/*
 *  This method controls whether the message includes a little
 *  speech tick on the bottom side.
 */
-(void) setIsSpoken:(BOOL) isSpoken
{
    [bvContent setIsSpoken:isSpoken];
    [self setNeedsLayout];
}

/*
 *  Assign new content to the cell.
 *  - the idea here is if we're defered, we'll always animate the transition.
 */
-(void) setContentWithDeferredAnimation:(id) content
{
    // - when content was deferred, we're going to animate this transition.
    if (isDeferred && bvContent.content) {
        UIView *vwSnap = [self resizableSnapshotViewFromRect:self.contentView.frame afterScreenUpdates:YES withCapInsets:UIEdgeInsetsZero];
        [self.contentView addSubview:vwSnap];
        bvContent.alpha = 0.0f;
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            vwSnap.alpha    = 0.0f;
            bvContent.alpha = 1.0f;
        }completion:^(BOOL finished) {
            [vwSnap removeFromSuperview];
        }];
    }

    // - assign the new content.
    [bvContent setContent:content];
    [self setNeedsLayout];
    isDeferred = NO;
}

/*
 *  Perform layout.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    if (!bvContent) {
        return;
    }
    
    //  - adjust the content so that it is oriented correctly and
    //    sized correctly.
    CGSize szView   = self.bounds.size;
    CGSize szBubble = [self bubbleSizeForCellSize:CGSizeMake(szView.width - UISMDC_FULL_HORIZ_PAD, szView.height)];
    CGFloat centerX = 0.0f;
    //  - my notes are on the right, others' are on the left.
    if (bvContent.isMine) {
        centerX = szView.width - UISMDC_CELL_PAD - (szBubble.width/2.0f);
    }
    else {
        centerX = UISMDC_CELL_PAD + (szBubble.width/2.0f);
    }
    bvContent.frame = CGRectIntegral(CGRectMake(centerX - (szBubble.width/2.0f), (szView.height/2.0f) - (szBubble.height/2.0f), szBubble.width, szBubble.height));
}

/*
 *  Assign the search text.
 */
-(void) setSearchText:(NSString *) searchText
{
    [bvContent setSearchText:searchText];
}

/*
 *  Make sure the search text is reset between cell uses.
 */
-(void) prepareForReuse
{
    [super prepareForReuse];
    
    isDeferred = NO;
    [bvContent setSearchText:nil];
    [bvContent reconfigureLabelsForDynamicTypeDuringInit:YES];
}
/*
 *  When an item is tapped, show the tap indicator.
 */
-(void) showTapped
{
    [bvContent showTapped];
}

/*
 *  Return the frame for the bubble in this view.
 */
-(CGRect) bubbleRect
{
    return [self convertRect:bvContent.frame fromView:self.contentView];
}

/*
 *  Flags the content in the cell is deferred, which means that we wanted to wait
 *  until the table slowed down to display it.
 */
-(void) setContentIsDeferred
{
    isDeferred = YES;
    [bvContent setDisplayAsDeferred];
}

/*
 *  Returns whether the cell has deferred content.
 */
-(BOOL) hasDeferredContent
{
    return isDeferred;
}

@end

/****************************************
 UISealedMessageDisplayCellV2 (internal)
 ****************************************/
@implementation UISealedMessageDisplayCellV2 (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    self.backgroundColor                 = [UIColor clearColor];
    isDeferred                           = NO;
    bvContent                            = [[UISealedMessageDisplayCellV2 bubbleViewForContent:nil] retain];
    [self.contentView addSubview:bvContent];
}

/*
 *  Create and return a bubble view for the given content.
 */
+(UISealedMessageBubbleViewV2 *) bubbleViewForContent:(id) content
{
    UISealedMessageBubbleViewV2 *bv = [[UISealedMessageBubbleViewV2 alloc] init];
    [bv setContent:content];
    return [bv autorelease];
}

/*
 *  Return the maximum width a content bubble can be in this display.
 */
+(CGFloat) maximumContentWidth
{
    // - no matter what we do, we cannot allow a rotation to change the
    //   dimensions of the text or the table view will need to recompute all of its row heights, which
    //   will be a big problem for performance.  Therefore, we always base this on the dimension of the
    //   screen's short side, which gives us our maximum width, from which we subtract padding and get the
    //   ideal width for the text.
    static CGFloat maxContent = -1.0f;
    if (maxContent  < 0.0f) {
        maxContent    = (CGFloat) floor([ChatSeal portraitWidth] - UISMDC_FULL_HORIZ_PAD);
    }
    return maxContent;
}

/*
 *  Compute the dimensions of the bubble.
 */
-(CGSize) bubbleSizeForCellSize:(CGSize) sz
{
    CGSize szRet = CGSizeZero;
    sz.width     = MIN([UISealedMessageDisplayCellV2 maximumContentWidth], sz.width);
    if ([bvContent isContentAnImage]) {
        szRet    = [bvContent sizeThatFits:CGSizeMake(MIN(sz.width, UISMDC_MAX_IMAGE_WIDTH), sz.height - (UISMDC_CELL_PAD * 2.0f))];
    }
    else {
        // - the bubble won't extend to the edge of the cell in portrait mode to give some indication of who
        //   owns it, but we need to pad less when the text is really big or it will look squashed.
        if ([bvContent hasExcessivelyLargeText]) {
            sz.width -= UISMDC_WIDE_TEXT_OWNERSHIP_PAD;
        }
        else {
            sz.width -= UISMDC_STD_OWNERSHIP_PAD;
        }
        szRet = [bvContent sizeThatFits:sz];
    }
    return szRet;
}
@end
