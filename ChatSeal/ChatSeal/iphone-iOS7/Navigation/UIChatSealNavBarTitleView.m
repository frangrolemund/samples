//
//  UIChatSealNavBarTitleView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 9/9/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIChatSealNavBarTitleView.h"
#import "ChatSeal.h"
#import "UIAlphaContext.h"

// - constants
static const CGFloat UINBTV_STD_NUM_MASK_SEGMENTS = 20.0f;

// - forward declarations
@interface UIChatSealNavBarTitleView (internal)
-(UIImage *) generateTitleImage;
-(void) buildScramblerMask;
@end

/*********************************
 UIChatSealNavBarTitleView
 *********************************/
@implementation UIChatSealNavBarTitleView
/*
 *  Object attributes.
 */
{
    CGSize      maxSize;
    BOOL        invalidateImage;
    NSString    *title;
    BOOL        titleTruncated;
    UIImageView *ivTitle;
    CGFloat     maxTextWidth;
    BOOL        requiresScramblingMask;
    CALayer     *lScramblingMask;
    UIColor     *cMonochrome;
}

/*
 *  Return the standard font for navigation bar titles.
 */
+(UIFont *) standardTitleFont
{
    return [UIFont fontWithName:[ChatSeal defaultAppStylizedFontNameAsWeight:CS_SF_NORMAL] size:21.0f];
}

/*
 *  Initialize the object.
 */
-(id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        maxSize                = CGSizeZero;
        title                  = nil;
        invalidateImage        = YES;
        titleTruncated         = NO;
        requiresScramblingMask = NO;
        cMonochrome            = nil;
        maxTextWidth           = -1.0f;
        ivTitle                = [[UIImageView alloc] init];
        ivTitle.contentMode    = UIViewContentModeCenter;
        ivTitle.clipsToBounds  = YES;
        [self addSubview:ivTitle];
        self.backgroundColor  = [UIColor clearColor];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [title release];
    title = nil;
    
    [ivTitle release];
    ivTitle = nil;
    
    [lScramblingMask release];
    lScramblingMask = nil;
    
    [cMonochrome release];
    cMonochrome = nil;
    
    [super dealloc];
}

/*
 *  Assign the title.
 */
-(void) setTitle:(NSString *)newTitle
{
    if (title != newTitle) {
        [title release];
        title           = [newTitle retain];
        invalidateImage = YES;
        [self setNeedsLayout];
    }
}

/*
 *  Retrieve the title.
 */
-(NSString *) title
{
    return [[title retain] autorelease];
}

/*
 *  Change the maximum text width.
 */
-(void) setMaxTextWidth:(CGFloat)newTW
{
    if ((int) newTW != (int) maxTextWidth) {
        if (newTW > ivTitle.image.size.width && titleTruncated) {
            invalidateImage = YES;
            [self setNeedsLayout];
        }
        maxTextWidth = newTW;
    }
}

/*
 *  Return the maximum text width.
 */
-(CGFloat) maxTextWidth
{
    return maxTextWidth;
}

/*
 *  The nav bar sends size that fits but never actually sizes this
 *  view.  We'll just save the size for computing the content inside.
 */
-(CGSize) sizeThatFits:(CGSize)size
{
    maxSize             = size;
    
    // - figure out if the image should be invalidated, which we want to avoid
    //   unless it is necessary.
    if (ivTitle.image) {
        if (ivTitle.image.size.width > size.width || titleTruncated) {
            invalidateImage = YES;
        }
    }
    else {
        invalidateImage = YES;
    }
    
    return CGSizeZero;
}

/*
 *  Perform layout.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    // - when the image is invalidated, create a new one.
    if (invalidateImage) {
        UIImage *img = [self generateTitleImage];
        ivTitle.image = img;
        if (requiresScramblingMask && !lScramblingMask) {
            [self buildScramblerMask];
        }
        invalidateImage = NO;
    }
    
    // - this view is never sized, but it is precisely oriented at the center of the
    //   nav bar, so we can use that fact to place our sub-view.
    CGSize szImage        = ivTitle.image.size;
    CGSize szBounds       = CGSizeMake(MIN(maxSize.width, szImage.width), MIN(maxSize.height, szImage.height));
    ivTitle.frame         = CGRectIntegral(CGRectMake(-szBounds.width/2.0f, (maxSize.height - szBounds.height)/2.0f - szBounds.height/2.0f, szBounds.width, szBounds.height));
    lScramblingMask.frame = ivTitle.bounds;
}

/*
 *  A scrambling mask is a simple clipping mask that is applied to the image and obscures it, almost like it is encrypted.
 */
-(void) applyScramblingMask
{
    if (!lScramblingMask) {
        requiresScramblingMask = YES;
        if (ivTitle.image) {
            [self buildScramblerMask];
        }
    }
}

/*
 *  Assign a monochrome color for rendering.
 */
-(void) setMonochromeColor:(UIColor *)newColor
{
    if (newColor != cMonochrome) {
        [cMonochrome release];
        cMonochrome = [newColor retain];
        invalidateImage = YES;
        [self setNeedsLayout];
    }
}

/*
 *  Return the current monochrome color, if set.
 */
-(UIColor *) monochromeColor
{
    return [[cMonochrome retain] autorelease];
}
@end

/***********************************
 UIChatSealNavBarTitleView (internal)
 ***********************************/
@implementation UIChatSealNavBarTitleView (internal)
/*
 *  Generate a title image.
 */
-(UIImage *) generateTitleImage
{
    if (self.title.length == 0) {
        return nil;
    }
    
    // - a common dictionary for all drawing operations.
    NSMutableDictionary *mdLight = [NSMutableDictionary dictionary];
    [mdLight setObject:[UIChatSealNavBarTitleView standardTitleFont] forKey:NSFontAttributeName];
    
    NSParagraphStyle *ps         = [NSParagraphStyle defaultParagraphStyle];
    NSMutableParagraphStyle *mps = [(NSMutableParagraphStyle *) [ps mutableCopy] autorelease];
    [mps setAlignment:NSTextAlignmentLeft];
    
    [mdLight setObject:mps forKey:NSParagraphStyleAttributeName];
    
    NSMutableDictionary *mdDark  = [NSMutableDictionary dictionaryWithDictionary:mdLight];
    
    [mdLight setObject:[UIColor whiteColor] forKey:NSForegroundColorAttributeName];
    [mdDark setObject:cMonochrome ? cMonochrome : [UIColor blackColor] forKey:NSForegroundColorAttributeName];
    
    // - attributed strings give a bit more control.
    NSMutableAttributedString *mas = [[[NSMutableAttributedString alloc] initWithString:title attributes:mdDark] autorelease];
    
    // - first compute the size for the image
    CGRect rc = [mas boundingRectWithSize:maxSize options:NSStringDrawingTruncatesLastVisibleLine context:nil];
    if (rc.size.width < 1.0f || rc.size.height < 1.0f) {
        return nil;
    }
    
    // - we've computed the bounds, which will be larger potentially, make sure that drawing always truncates
    [mps setLineBreakMode:NSLineBreakByTruncatingTail];
    
    // - make sure the rectangle is adjusted to draw correctly.
    rc.size.width     = (CGFloat) ceil(rc.size.width);
    rc.origin.x       = 0.0f;
    CGFloat oldHeight = (CGFloat) ceil(rc.size.height);
    rc.size.height    = maxSize.height;
    rc.origin.y       = (CGFloat) floor((maxSize.height - oldHeight)/2.0f);
    
    // - and determine if we truncated the text so that we can avoid recalculations.
    CGFloat maxWidth = maxSize.width;
    if (maxTextWidth > 0.0f) {
        maxWidth = MIN(maxTextWidth, maxWidth);
    }
    
    titleTruncated = NO;
    if(rc.size.width > maxWidth) {
        rc.size.width  = maxWidth;
        titleTruncated = YES;
    }
    
    // - now draw it.
    UIGraphicsBeginImageContextWithOptions(rc.size, NO, 0.0f);
    
    // - draw the dark version first because it will extend farther on the display.
    [mas setAttributes:mdDark range:NSMakeRange(0, title.length)];      //  we changed the paragraph style.
    [mas drawInRect:rc];
    
    UIImage *imgRet = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return imgRet;
}

/*
 *  Build a clipping mask that can make the text look scrambled.
 */
-(void) buildScramblerMask
{
    if (lScramblingMask) {
        return;
    }
    
    lScramblingMask                 = [[CALayer alloc] init];
    lScramblingMask.contentsScale   = [UIScreen mainScreen].scale;
    lScramblingMask.contentsGravity = kCAGravityResizeAspectFill;
    
    UIAlphaContext *ac = [UIAlphaContext contextWithSize:ivTitle.image.size];
    CGRect bounds      = ac.pxBounds;
    CGFloat barWidth   = CGRectGetWidth(bounds)/UINBTV_STD_NUM_MASK_SEGMENTS;
    
    CGContextRef ctx   = ac.context;
    
    CGContextSetFillColorWithColor(ctx, [[UIColor whiteColor] CGColor]);
    for (CGFloat cur = -(barWidth * 8.0f); cur < CGRectGetWidth(bounds); cur += (barWidth * 2.0f)) {
        CGContextFillRect(ctx, CGRectMake(cur, -(CGRectGetHeight(bounds) * 4.0f), barWidth, CGRectGetHeight(bounds) * 8.0f));
    }
    
    lScramblingMask.contents        = (id) [[ac imageMask] CGImage];
    ivTitle.layer.mask              = lScramblingMask;
}
@end
