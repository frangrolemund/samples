//
//  UIImageGeneration.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/1/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "UIImageGeneration.h"
#import "UIAlphaContext.h"
#import "ChatSeal.h"

// - constants
static const CGFloat UIG_STD_ALPHA_BG           = 0.35f;
static const CGFloat UIG_STD_ALPHA_SELECTED     = 1.0f;
static const CGFloat UIG_STD_LOW_DISABLED_MIN   = .30f;

// - forward declarations
@interface UIImageGeneration (internal)
+(BOOL) clipToImage:(UIImage *) img intoTargetSize:(CGSize) szTarget returningImageRect:(CGRect *) rcImageRect;
@end


/*************************
 UIImageGeneration
 *************************/
@implementation UIImageGeneration

/*
 *  Generate an image for use in a tab bar using the given source image file and 
 *  tint color.
 */
+(UIImage *) tabBarImageFromImage:(NSString *) imageNamed andTint:(UIColor *) c andIsSelected:(BOOL) isSelected
{
    UIImage *img = [UIImage imageNamed:imageNamed];
    if (!img) {
        return nil;
    }
 
    UIImage *ret = nil;
    
    CGSize shadowOffset;
    if (isSelected) {
        shadowOffset = CGSizeMake(0.0f, 2.0f);
    }
    else {
        shadowOffset = CGSizeMake(0.0f, -1.0f);
    }
    
    //  - figure out how the image should be expanded to accommodate a shadow
    CGSize szImage = img.size;
    CGFloat absShadW = fabsf((float)(shadowOffset.width));
    CGFloat absShadH = fabsf((float)(shadowOffset.height));
    szImage.width += (2.0f + (absShadW * 2.0f));
    szImage.height += (2.0f + (absShadH * 2.0f));
    
    //  - start by inverting the source image into a mask that encompasses only it.
    //  - inversion requires a mask of the mask.
    UIImage *imageMask = [UIAlphaContext maskForImage:img];
    imageMask = [UIAlphaContext maskForImage:imageMask];
    
    //  - create the resulting bitmap, which is going to be larger to accommodate the shadow
    UIGraphicsBeginImageContextWithOptions(szImage, NO, img.scale);
    CGContextTranslateCTM(UIGraphicsGetCurrentContext(), 0.0f, szImage.height);
    CGContextScaleCTM(UIGraphicsGetCurrentContext(), 1.0f, -1.0f);
    
    CGRect rcImage = CGRectMake(0.0f, 0.0f, szImage.width, szImage.height);
    if (UIGraphicsGetCurrentContext() == NULL) {
        NSLog(@"CS: NULL CONTEXT at %s:%d.", __FILE__, __LINE__);
    }    
    CGContextSaveGState(UIGraphicsGetCurrentContext());
    CGContextSetShadowWithColor(UIGraphicsGetCurrentContext(), shadowOffset, 1.0f, [[UIColor colorWithRed:0.10f green:0.10f blue:0.10f alpha:1.0f] CGColor]);
    
    // - a transparency layer ensures the shadow is applied along the icon's edges
    CGContextBeginTransparencyLayer(UIGraphicsGetCurrentContext(), NULL);
    [UIImageGeneration clipToImage:imageMask intoTargetSize:szImage returningImageRect:nil];
    
    // - first draw the simple white background.
    [[UIColor whiteColor] set];
    UIRectFill(rcImage);
    
    // - now apply the tint color over it
    [[c colorWithAlphaComponent:UIG_STD_ALPHA_BG] set];
    UIRectFillUsingBlendMode(rcImage, kCGBlendModeNormal);
    
    // - now if it is selected, create the selection highlight.
    if (isSelected) {
        CGContextTranslateCTM(UIGraphicsGetCurrentContext(), 0.0f, -CGRectGetHeight(rcImage)*0.65f);
        CGContextRotateCTM(UIGraphicsGetCurrentContext(), (13.0f/180.0f) * (CGFloat) M_PI);
        [[c colorWithAlphaComponent:UIG_STD_ALPHA_SELECTED] set];
        rcImage = CGRectInset(rcImage, -CGRectGetWidth(rcImage), 0.0f);
        UIRectFillUsingBlendMode(rcImage, kCGBlendModeNormal);
    }
    
    CGContextEndTransparencyLayer(UIGraphicsGetCurrentContext());
    CGContextRestoreGState(UIGraphicsGetCurrentContext());
        
    ret = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return ret;
}

/*
 *  Create a screenshot from the given view.
 */
+(UIImage *) imageFromView:(UIView *) view withScale:(CGFloat) scale
{
    if (!view) {
        return nil;
    }
    
    CGSize sz = view.bounds.size;
    if (sz.width < 1.0f || sz.height < 1.0f) {
        return nil;
    }
    
    //  - first grab the shot
    CGRect rcBounds = CGRectMake(0.0f, 0.0f, CGRectGetWidth(view.bounds), CGRectGetHeight(view.bounds));
    UIGraphicsBeginImageContextWithOptions(rcBounds.size, YES, 0.0f);
    
    // ...fill the background with white because these are generally used for making frosted
    //    transitions and we don't want clipped content to be pure black.
    [[UIColor whiteColor] setFill];
    UIRectFill(rcBounds);
    
    [view drawViewHierarchyInRect:rcBounds afterScreenUpdates:YES];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // - and scale it if necessary.
    img = [UIImageGeneration image:img scaledTo:scale asOpaque:YES];
    
    // - return the result.
    return img;
}

/*
 *  This method is used to manufacture new colors in the same palette as existing ones.
 */
+(UIColor *) adjustColor:(UIColor *) color byHuePct:(CGFloat) huePct andSatPct:(CGFloat) satPct andBrPct:(CGFloat) brPct andAlphaPct:(CGFloat) alphaPct
{
    CGFloat hue = 0.0f, sat = 0.0f, bright = 0.0f, alpha = 0.0f;
    if (color) {
        if ([color getHue:&hue saturation:&sat brightness:&bright alpha:&alpha]) {
            hue    = fminf((float)(hue * huePct), 1.0f);
            sat    = fminf((float)(sat * satPct), 1.0f);
            bright = fminf((float)(bright * brPct), 1.0f);
            alpha  = fminf((float)(alpha * alphaPct), 1.0f);

            return [UIColor colorWithHue:hue saturation:sat brightness:bright alpha:alpha];
        }
        else {
            CGFloat r, g, b, a;
            if ([color getRed:&r green:&g blue:&b alpha:&a]) {
                r = fminf((float)(r * satPct), 1.0f);
                g = fminf((float)(r * satPct), 1.0f);
                b = fminf((float)(r * satPct), 1.0f);
                a = fminf((float)(r * alphaPct), 1.0f);
                return [UIColor colorWithRed:r green:g blue:b alpha:a];
            }
            else {
                CGFloat w;
                if ([color getWhite:&w alpha:&a]) {
                    w = fminf((float)(w * satPct * brPct), 1.0f);
                    a = fminf((float)(a * alphaPct), 1.0f);
                    return [UIColor colorWithWhite:w alpha:a];
                }
            }
        }
    }
    return color;
}

/*
 *  Scale the given image explicitly.
 */
+(UIImage *) image:(UIImage *) srcImage scaledTo:(CGFloat) scale asOpaque:(BOOL) isOpaque
{
    if (!srcImage) {
        return nil;
    }
    
    CGSize size = srcImage.size;
    size.width  = ceilf((float)(size.width * scale));
    size.height = ceilf((float)(size.height * scale));
    
    // - nothing to do, so just return.
    if ((int) size.width  == (int) srcImage.size.width &&
        (int) size.height == (int) srcImage.size.height) {
        return  srcImage;
    }
    
    UIGraphicsBeginImageContextWithOptions(size, isOpaque, srcImage.scale);
    [srcImage drawInRect:CGRectMake(0.0f, 0.0f, size.width, size.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    UIImage *imgRet = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return imgRet;
}

/*
 *  This is a convenience function for generating round rectangles.
 *  - this assumes we're working in pixels.
 */
+(void) addRoundRect:(CGRect) rc toContext:(CGContextRef) ctx withCornerRadius:(CGFloat) radius
{    
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
            CGContextAddArc(ctx, ptCur.x + (dx * radius), ptCur.y + (dy * radius), radius, curAngle, curAngle + qtrArc, 0);
            curAngle += qtrArc;
        }
        
        switch (i) {
            case 0:
            case 4:
                dx = 1.0f;
                dy = 0.0f;
                ptCur = CGPointMake(CGRectGetMinX(rc), CGRectGetMinY(rc) + radius);
                break;
                
            case 1:
                dx = 0.0f;
                dy = 1.0f;
                ptCur = CGPointMake(CGRectGetMaxX(rc) - radius, CGRectGetMinY(rc));
                break;
                
            case 2:
                dx = -1.0f;
                dy = 0.0f;
                ptCur = CGPointMake(CGRectGetMaxX(rc), CGRectGetMaxY(rc) - radius);
                break;
                
            case 3:
                dx = 0.0f;
                dy = -1.0f;
                ptCur = CGPointMake(CGRectGetMinX(rc) + radius, CGRectGetMaxY(rc));
                break;
        }
        
        if (i > 0) {
            CGContextAddLineToPoint(ctx, ptCur.x, ptCur.y);
        }
        else {
            CGContextMoveToPoint(ctx, ptCur.x, ptCur.y);
        }
    }
}

/*
 *  Create a standard disabled color from the color.
 */
+(UIColor *) disabledColorFromColor:(UIColor *) c
{
    // - if the color is really dark (think pure black), then
    //   we actually lighten it to show a disabled state.
    CGFloat cc1, cc2, cc3, a;
    if (![c getRed:&cc1 green:&cc2 blue:&cc3 alpha:&a] &&
         [c getWhite:&cc1 alpha:&a] &&
        cc1 < UIG_STD_LOW_DISABLED_MIN) {
        c = [UIColor colorWithWhite:UIG_STD_LOW_DISABLED_MIN alpha:a];
    }
    return [UIImageGeneration adjustColor:c byHuePct:1.0f andSatPct:0.85f andBrPct:0.75f andAlphaPct:1.0f];
}

/*
 *  Create a standard highlighted color from the source.
 */
+(UIColor *) highlightedColorFromColor:(UIColor *) c
{
    return [UIImageGeneration adjustColor:c byHuePct:1.0f andSatPct:1.0f andBrPct:1.25f andAlphaPct:1.0f];
}

/*
 *  Generate a button icon image when requested.
 */
+(UIImage *) iconImageFromImage:(UIImage *) img inColor:(UIColor *) color withShadow:(UIColor *) shadowColor;
{
    // - first make sure the image is a bit bigger so that
    //   the shadows are not clipped.
    CGSize sz = img.size;
    CGFloat scale = img.scale;
    CGSize szNew = CGSizeMake(sz.width + 2.0f, sz.height + 2.0f);
    UIGraphicsBeginImageContextWithOptions(szNew, NO, scale);
    [img drawInRect:CGRectMake((szNew.width - sz.width)/2.0f, (szNew.height - sz.height)/2.0f, sz.width, sz.height)];
    img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // - generate a mask from it.
    img = [UIAlphaContext maskForImage:img];
    
    // - ...but a reversed image mask.
    img = [UIAlphaContext maskForImage:img];
    
    if (!img) {
        return nil;
    }
    
    // - now create a new image masking out the image color
    UIGraphicsBeginImageContextWithOptions(szNew, NO, scale);
    CGContextTranslateCTM(UIGraphicsGetCurrentContext(), 0.0f, szNew.height);
    CGContextScaleCTM(UIGraphicsGetCurrentContext(), 1.0f, -1.0f);
    
    if (shadowColor) {
        CGContextSetShadowWithColor(UIGraphicsGetCurrentContext(), CGSizeMake(0.0f, -1.0f), 2.0f, [shadowColor CGColor]);
    }
    
    CGContextBeginTransparencyLayer(UIGraphicsGetCurrentContext(), 0);
    CGContextClipToMask(UIGraphicsGetCurrentContext(), CGRectMake(0.0f, 0.0f, szNew.width, szNew.height), img.CGImage);
    CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), [color CGColor]);
    CGContextFillRect(UIGraphicsGetCurrentContext(), CGRectMake(0.0f, 0.0f, szNew.width, szNew.height));
    CGContextEndTransparencyLayer(UIGraphicsGetCurrentContext());
    
    img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

/*
 *  Draw a an image with a radial gradient emanating from the center.
 */
+(void) simpleRadialGradientImageOfHeight:(CGFloat) height withColor:(UIColor *) color andEndColor:(UIColor *) endColor withStartRadius:(CGFloat) startRadius
                             andEndRadius:(CGFloat) endRadius
{
    // - create the gradient
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    NSArray *arrColors = [NSArray arrayWithObjects:(id) [color CGColor], (id) [endColor CGColor] , nil];
    CGGradientRef gradient = CGGradientCreateWithColors(cs, (CFArrayRef) arrColors, NULL);
    CGColorSpaceRelease(cs);
    
    //  - and draw the rings.
    CGPoint startPoint = CGPointMake(height/2.0f, height/2.0f);
    CGContextDrawRadialGradient(UIGraphicsGetCurrentContext(), gradient, startPoint, startRadius, startPoint, endRadius, kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(gradient);
}

@end


/**********************************
 UIImageGeneration (internal)
 **********************************/
@implementation UIImageGeneration (internal)

/*
 *  Clip the current context to the given image in the target rectangle.
 */
+(BOOL) clipToImage:(UIImage *) img intoTargetSize:(CGSize) szTarget returningImageRect:(CGRect *) rcImageRect
{
    CGSize szImage = img.size;
    
    // - figure out precisely where the clipping should occur if the image is smaller than the target.
    CGRect rcImage;
    if (szTarget.width > szImage.width || szTarget.height > szImage.height) {
        rcImage = CGRectMake((szTarget.width - szImage.width)/2.0f, (szTarget.height - szImage.height)/2.0f, szImage.width, szImage.height);
    }
    else {
        rcImage = CGRectMake(0.0f, 0.0f, szTarget.width, szTarget.height);
    }
    
    CGContextClipToMask(UIGraphicsGetCurrentContext(), rcImage, [img CGImage]);
    
    if (rcImageRect) {
        *rcImageRect = rcImage;
    }    
    
    return YES;
}

@end