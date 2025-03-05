//
//  UIChatSealNavigationBar.m
//  ChatSeal
//
//  Created by Francis Grolemund on 9/10/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIChatSealNavigationBar.h"
#import "UIChatSealNavBarTitleView.h"
#import "ChatSeal.h"

// - constants
static const CGFloat UICSNB_PATH_CURVE_WIDTH_PCT = 0.14f;           //  percentage of the total width that the curve takes
static const CGFloat UICSNB_TARGET_TITLE_HEIGHT  = 29.0f;           //  important to keep it constant so that we can compute the title overlay.

// - forward declarations
@interface UIChatSealNavigationBar (internal)
-(void) commonConfiguration;
-(void) rebuildNavBarBackgroundIfNecessaryWithNavController:(UINavigationController *) nc;
+(UIBezierPath *) navbarStylePath;
-(UIBezierPath *) scaledStylePathForTargetBounds:(CGRect) rc;
-(BOOL) hasGoodBottomOffsetForPortrait:(BOOL) inPortrait;
@end

/******************************
 UIChatSealNavigationBar
 ******************************/
@implementation UIChatSealNavigationBar
/*
 *  Object attributes
 */
{
    UIView  *vwUnderlay;
    BOOL    inRebuild;
    BOOL    allowLayoutRebuilds;
    CGFloat lastGoodTitleOffsetYLandscape;
    CGFloat lastGoodTitleOffsetYPortrait;
    BOOL    shouldDiscardAfterRotation;
    BOOL    lastWasPortrait;
}

/*
 *  Inititialize the object.
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
    [vwUnderlay release];
    vwUnderlay = nil;
    
    [super dealloc];
}

/*
 *  Perform layout.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    // - we need to extend the underlay up to the status bar.
    CGRect rcFrame    = self.frame;
    CGRect rcUnderlay = CGRectMake(0.0f, -CGRectGetMinY(rcFrame), CGRectGetWidth(rcFrame), CGRectGetMinY(rcFrame) + CGRectGetHeight(rcFrame));
    vwUnderlay.frame  = rcUnderlay;
    [self sendSubviewToBack:vwUnderlay];
    
    // - rebuild the background.
    if (allowLayoutRebuilds && [self.delegate isKindOfClass:[UINavigationController class]]) {
        [self rebuildNavBarBackgroundIfNecessaryWithNavController:(UINavigationController *) self.delegate];
    }
}

/*
 *  Right after we launch, the nav bar should look like the launch image.
 */
-(void) assignLaunchCompatibleNavStyle
{
    // - assign a basic white background
    UIGraphicsBeginImageContext(CGSizeMake(1.0f, 1.0f));
    [[UIColor whiteColor] setFill];
    UIRectFill(CGRectMake(0.0f, 0.0f, 1.0f, 1.0f));
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    [self setBackgroundImage:img forBarMetrics:UIBarMetricsDefault];
    
    // - and build the scrambled title.
    UIChatSealNavBarTitleView *nbtv      = [[[UIChatSealNavBarTitleView alloc] init] autorelease];
    nbtv.title                           = self.topItem.title;
    [nbtv setMonochromeColor:[ChatSeal defaultIconColor]];
    [nbtv applyScramblingMask];
    self.topItem.titleView               = nbtv;
}

/*
 *  Assign the standard nav style.
 */
-(void) assignStandardNavStyleInsideNavigationController:(UINavigationController *) nc
{
    [self rebuildNavBarBackgroundIfNecessaryWithNavController:nc];
}

/*
 *  Allow the nav bar to rebuild itself during layouts.
 */
-(void) setLayoutRebuildEnabled:(BOOL) isEnabled
{
    allowLayoutRebuilds = isEnabled;
}

@end

/***********************************
 UIChatSealNavigationBar (internal)
 ***********************************/
@implementation UIChatSealNavigationBar (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    // - the act of rebuilding will do a layout, which gets funny when we're already in layout, but
    //   it cannot be helped because of the lackluster customization for nav bars.  This prevents
    //   recursion.
    inRebuild = NO;
    
    // - when the app first starts the initial animation of the nav bar will get hosed if we allow
    //   rebuilds during layout.
    allowLayoutRebuilds = NO;
    
    // - in iOS8 there appears to be an issue using a background image after it was previously generated.   The
    //   system ends up using the wrong one for the given position.
    shouldDiscardAfterRotation = [ChatSeal isIOSVersionGREQUAL8];
    lastWasPortrait            = NO;
    
    // - the approach of computing the title center with layout is not reliable when the nav bar is hidden, so
    //   we'll cache what we find and use that if possible.
    lastGoodTitleOffsetYLandscape = -1.0f;
    lastGoodTitleOffsetYPortrait  = -1.0f;
    
    // - when translucency is applied with a background, the background becomes much more translucent than
    //   it normally does, which ends up looking odd.  This view is intended to mask that a bit.
    vwUnderlay                        = [[UIView alloc] init];
    vwUnderlay.backgroundColor        = [UIColor colorWithWhite:1.0f alpha:0.75f];
    vwUnderlay.userInteractionEnabled = NO;
    [self addSubview:vwUnderlay];
}

/*
 *  Rebuild the background of the nav bar if it has changed dimension.
 */
-(void) rebuildNavBarBackgroundIfNecessaryWithNavController:(UINavigationController *) nc
{
    if (inRebuild) {
        return;
    }
    inRebuild = YES;
    
    // - we need to use a full image for the nav bar, not just a scalable one because the pattern needs to be precise.
    CGRect rcNavBar        = self.frame;
    CGSize szImage         = rcNavBar.size;
    szImage.height        += MAX(CGRectGetMinY(rcNavBar), 0);      // - to get the area above it for the status bar.
    
    // - figure out the right bar metrics.
    UIBarMetrics bmActive = UIBarMetricsDefault;
    BOOL inPortrait       = YES;
    if (CGRectGetWidth(nc.view.bounds) > CGRectGetHeight(nc.view.bounds)) {
        // - we're in landscape.
        if (self.topItem.prompt) {
            if ([ChatSeal isIOSVersionBEFORE8]) {
                bmActive = UIBarMetricsLandscapePhonePrompt;                
            }
            else {
                bmActive = UIBarMetricsCompactPrompt;
            }
        }
        else {
            if ([ChatSeal isIOSVersionBEFORE8]) {
                bmActive = UIBarMetricsLandscapePhone;
            }
            else {
                bmActive = UIBarMetricsCompact;
            }
        }
        inPortrait = NO;
    }
    else {
        // - we're in portrait.
        if (self.topItem.prompt) {
            bmActive = UIBarMetricsDefaultPrompt;
        }
        else {
            bmActive = UIBarMetricsDefault;
        }
    }
    
    // - because of rotation issues under iOS8, we'll regenerate whenever rotation changes.
    BOOL shouldForceGenerate = NO;
    if (shouldDiscardAfterRotation && inPortrait != lastWasPortrait) {
        shouldForceGenerate = YES;
    }
    
    // - now see if we need to even do this, which isn't necessary if an image is already assigned and of the right dimension.
    UIImage *imgCur = [self backgroundImageForBarPosition:UIBarPositionTopAttached barMetrics:bmActive];
    if (shouldForceGenerate ||
        ![self hasGoodBottomOffsetForPortrait:inPortrait] ||
        (int) imgCur.size.width != (int) szImage.width || (int) imgCur.size.height != (int) szImage.height) {
        // - first construct a path, which also sets the bottom offset.
        // ...we'll use a bezier path to get our signature look, which is intended to have a junction point right at
        //    the center of the nav bar where the title will be.
        UIBezierPath *bp = [self scaledStylePathForTargetBounds:CGRectMake(rcNavBar.origin.x, rcNavBar.origin.y,
                                                                           szImage.width, szImage.height)];
        
        // - during some layout actions, the bottom offset may not be set, so don't bother generating an image then
        if ([self hasGoodBottomOffsetForPortrait:inPortrait]) {
            // - get down to business.  We need a great background.
            UIGraphicsBeginImageContextWithOptions(szImage, YES, 0.0f);
            
            CGContextSetAllowsAntialiasing(UIGraphicsGetCurrentContext(), YES);
            
            [[UIColor whiteColor] setFill];
            UIRectFill(CGRectMake(0.0f, 0.0f, szImage.width, szImage.height));
            
            // ...finally we can draw.
            [[[ChatSeal defaultIconColor] colorWithAlphaComponent:0.15f] setFill];
            [bp fill];
            
            UIImage *imgBG = UIGraphicsGetImageFromCurrentImageContext();
            
            UIGraphicsEndImageContext();
            
            // - and assign it.
            [self setBackgroundImage:imgBG forBarPosition:UIBarPositionTopAttached barMetrics:bmActive];
            
            // - save the portrait/landscape orientation of the image..
            lastWasPortrait = inPortrait;
        }
    }
    inRebuild = NO;
}

/*
 *  This path is taken directly from PaintCode and reflects the style of the app icon in a way that allows it to fit in place around the time and interleaved
 *  with the title.
 */
+(UIBezierPath *) navbarStylePath
{
    //// Bezier 3 Drawing
    UIBezierPath* bezier3Path = UIBezierPath.bezierPath;
    [bezier3Path moveToPoint: CGPointMake(88.77f, 153.81f)];
    [bezier3Path addCurveToPoint: CGPointMake(38.14f, 95.16f) controlPoint1: CGPointMake(69.22f, 150.01f) controlPoint2: CGPointMake(38.57f, 139.11f)];
    [bezier3Path addCurveToPoint: CGPointMake(88.74f, 37.28f) controlPoint1: CGPointMake(37.7f, 49.52f) controlPoint2: CGPointMake(69.62f, 40.0f)];
    [bezier3Path addCurveToPoint: CGPointMake(113.78f, 36.62f) controlPoint1: CGPointMake(100.46f, 35.85f) controlPoint2: CGPointMake(108.55f, 36.86f)];
    [bezier3Path addCurveToPoint: CGPointMake(131.49f, 19.77f) controlPoint1: CGPointMake(123.56f, 36.17f) controlPoint2: CGPointMake(131.49f, 29.21f)];
    [bezier3Path addCurveToPoint: CGPointMake(114.62f, 2.99f) controlPoint1: CGPointMake(131.49f, 10.61f) controlPoint2: CGPointMake(124.01f, 4.19f)];
    [bezier3Path addCurveToPoint: CGPointMake(88.74f, 2.85f) controlPoint1: CGPointMake(110.86f, 2.51f) controlPoint2: CGPointMake(102.8f, 1.55f)];
    [bezier3Path addCurveToPoint: CGPointMake(2.98f, 94.53f) controlPoint1: CGPointMake(60.08f, 5.32f) controlPoint2: CGPointMake(2.37f, 24.27f)];
    [bezier3Path addCurveToPoint: CGPointMake(88.77f, 188.35f) controlPoint1: CGPointMake(2.97f, 163.71f) controlPoint2: CGPointMake(55.06f, 184.99f)];
    [bezier3Path addCurveToPoint: CGPointMake(115.33f, 188.46f) controlPoint1: CGPointMake(99.49f, 189.41f) controlPoint2: CGPointMake(107.86f, 189.0f)];
    [bezier3Path addCurveToPoint: CGPointMake(117.11f, 186.62f) controlPoint1: CGPointMake(116.32f, 188.38f) controlPoint2: CGPointMake(117.11f, 187.6f)];
    [bezier3Path addCurveToPoint: CGPointMake(116.37f, 185.17f) controlPoint1: CGPointMake(117.11f, 186.03f) controlPoint2: CGPointMake(116.82f, 185.5f)];
    [bezier3Path addCurveToPoint: CGPointMake(109.59f, 172.06f) controlPoint1: CGPointMake(112.29f, 182.12f) controlPoint2: CGPointMake(109.59f, 177.41f)];
    [bezier3Path addCurveToPoint: CGPointMake(116.37f, 158.95f) controlPoint1: CGPointMake(109.59f, 166.7f) controlPoint2: CGPointMake(112.26f, 161.95f)];
    [bezier3Path addCurveToPoint: CGPointMake(117.11f, 157.5f) controlPoint1: CGPointMake(116.83f, 158.62f) controlPoint2: CGPointMake(117.11f, 158.09f)];
    [bezier3Path addCurveToPoint: CGPointMake(115.21f, 155.62f) controlPoint1: CGPointMake(117.11f, 156.48f) controlPoint2: CGPointMake(116.26f, 155.67f)];
    [bezier3Path addCurveToPoint: CGPointMake(112.98f, 155.69f) controlPoint1: CGPointMake(114.53f, 155.58f) controlPoint2: CGPointMake(113.67f, 155.64f)];
    [bezier3Path addCurveToPoint: CGPointMake(88.77f, 153.81f) controlPoint1: CGPointMake(106.79f, 156.13f) controlPoint2: CGPointMake(98.6f, 155.72f)];
    [bezier3Path closePath];
    [bezier3Path moveToPoint: CGPointMake(253.85f, 315.6f)];
    [bezier3Path addCurveToPoint: CGPointMake(238.73f, 288.37f) controlPoint1: CGPointMake(248.89f, 306.53f) controlPoint2: CGPointMake(243.69f, 297.45f)];
    [bezier3Path addCurveToPoint: CGPointMake(236.21f, 278.32f) controlPoint1: CGPointMake(237.08f, 285.34f) controlPoint2: CGPointMake(236.21f, 281.94f)];
    [bezier3Path addCurveToPoint: CGPointMake(236.87f, 273.07f) controlPoint1: CGPointMake(236.21f, 276.51f) controlPoint2: CGPointMake(236.45f, 274.75f)];
    [bezier3Path addCurveToPoint: CGPointMake(241.17f, 245.08f) controlPoint1: CGPointMake(238.97f, 264.74f) controlPoint2: CGPointMake(241.17f, 255.44f)];
    [bezier3Path addCurveToPoint: CGPointMake(155.93f, 154.37f) controlPoint1: CGPointMake(241.78f, 174.81f) controlPoint2: CGPointMake(184.48f, 156.84f)];
    [bezier3Path addCurveToPoint: CGPointMake(130.14f, 154.65f) controlPoint1: CGPointMake(141.92f, 153.07f) controlPoint2: CGPointMake(133.89f, 154.18f)];
    [bezier3Path addCurveToPoint: CGPointMake(113.33f, 171.44f) controlPoint1: CGPointMake(120.79f, 155.85f) controlPoint2: CGPointMake(113.33f, 162.27f)];
    [bezier3Path addCurveToPoint: CGPointMake(130.98f, 188.28f) controlPoint1: CGPointMake(113.33f, 180.87f) controlPoint2: CGPointMake(121.24f, 187.83f)];
    [bezier3Path addCurveToPoint: CGPointMake(155.93f, 188.8f) controlPoint1: CGPointMake(136.19f, 188.53f) controlPoint2: CGPointMake(144.25f, 187.36f)];
    [bezier3Path addCurveToPoint: CGPointMake(206.14f, 245.71f) controlPoint1: CGPointMake(174.98f, 191.52f) controlPoint2: CGPointMake(206.58f, 200.06f)];
    [bezier3Path addCurveToPoint: CGPointMake(155.7f, 305.77f) controlPoint1: CGPointMake(205.71f, 289.65f) controlPoint2: CGPointMake(175.18f, 301.98f)];
    [bezier3Path addCurveToPoint: CGPointMake(131.58f, 307.66f) controlPoint1: CGPointMake(145.9f, 307.68f) controlPoint2: CGPointMake(137.75f, 308.09f)];
    [bezier3Path addCurveToPoint: CGPointMake(129.36f, 307.58f) controlPoint1: CGPointMake(130.89f, 307.61f) controlPoint2: CGPointMake(130.03f, 307.55f)];
    [bezier3Path addCurveToPoint: CGPointMake(127.46f, 309.46f) controlPoint1: CGPointMake(128.31f, 307.64f) controlPoint2: CGPointMake(127.46f, 308.45f)];
    [bezier3Path addCurveToPoint: CGPointMake(128.19f, 310.92f) controlPoint1: CGPointMake(127.46f, 310.05f) controlPoint2: CGPointMake(127.74f, 310.59f)];
    [bezier3Path addCurveToPoint: CGPointMake(134.95f, 324.02f) controlPoint1: CGPointMake(132.29f, 313.92f) controlPoint2: CGPointMake(134.95f, 318.67f)];
    [bezier3Path addCurveToPoint: CGPointMake(128.2f, 337.13f) controlPoint1: CGPointMake(134.95f, 329.38f) controlPoint2: CGPointMake(132.26f, 334.08f)];
    [bezier3Path addCurveToPoint: CGPointMake(127.46f, 338.59f) controlPoint1: CGPointMake(127.75f, 337.47f) controlPoint2: CGPointMake(127.46f, 337.99f)];
    [bezier3Path addCurveToPoint: CGPointMake(129.23f, 340.42f) controlPoint1: CGPointMake(127.46f, 339.56f) controlPoint2: CGPointMake(128.24f, 340.35f)];
    [bezier3Path addCurveToPoint: CGPointMake(155.7f, 340.31f) controlPoint1: CGPointMake(136.67f, 340.97f) controlPoint2: CGPointMake(145.01f, 341.38f)];
    [bezier3Path addCurveToPoint: CGPointMake(207.89f, 319.39f) controlPoint1: CGPointMake(171.48f, 338.73f) controlPoint2: CGPointMake(191.3f, 332.08f)];
    [bezier3Path addCurveToPoint: CGPointMake(217.52f, 316.24f) controlPoint1: CGPointMake(210.57f, 317.42f) controlPoint2: CGPointMake(213.91f, 316.24f)];
    [bezier3Path addCurveToPoint: CGPointMake(223.12f, 317.22f) controlPoint1: CGPointMake(219.49f, 316.24f) controlPoint2: CGPointMake(221.38f, 316.59f)];
    [bezier3Path addCurveToPoint: CGPointMake(244.9f, 325.34f) controlPoint1: CGPointMake(230.38f, 319.93f) controlPoint2: CGPointMake(237.64f, 322.63f)];
    [bezier3Path addCurveToPoint: CGPointMake(248.55f, 325.76f) controlPoint1: CGPointMake(246.06f, 325.79f) controlPoint2: CGPointMake(247.32f, 325.93f)];
    [bezier3Path addCurveToPoint: CGPointMake(252.62f, 323.81f) controlPoint1: CGPointMake(250.04f, 325.56f) controlPoint2: CGPointMake(251.47f, 324.91f)];
    [bezier3Path addCurveToPoint: CGPointMake(253.85f, 315.6f) controlPoint1: CGPointMake(254.91f, 321.59f) controlPoint2: CGPointMake(255.32f, 318.23f)];
    [bezier3Path closePath];
    
    bezier3Path.lineCapStyle  = kCGLineCapRound;
    bezier3Path.lineJoinStyle = kCGLineJoinRound;
    
    return bezier3Path;
}

/*
 *  Return a Bezier path in the style for navigation that is aligned to the center of the
 *  given rectangle.
 */
-(UIBezierPath *) scaledStylePathForTargetBounds:(CGRect) rc
{
    UIBezierPath *bp = [UIChatSealNavigationBar navbarStylePath];
    
    // ...find the scale so that it matches the height of the bar.
    CGRect rcCurve     = bp.bounds;
    CGFloat curveWidth = CGRectGetWidth(rcCurve) * UICSNB_PATH_CURVE_WIDTH_PCT;
    CGFloat scale      = UICSNB_TARGET_TITLE_HEIGHT / curveWidth;
    
    // ...figure out where the title is placed so that we can accurately underlay it with the path.
    CGFloat titleOffsetFromBottom = -1.0f;
    if (self.topItem.titleView) {
        titleOffsetFromBottom = CGRectGetHeight(self.bounds) - self.topItem.titleView.frame.origin.y;
    }
    else {
        // - we need to figure out where the title will be placed so that path can match that position
        // - the center of the title is the center of the text
        
        // - when the nav bar is hidden, the calculation below will be wrong so we'll cache the value
        //   for those times when it isn't accurate and also give us a quick way of getting it later.
        BOOL hasGoodDelegate = NO;
        BOOL isLandscape     = NO;
        if ([self.delegate isKindOfClass:[UINavigationController class]]) {
            hasGoodDelegate = YES;
            CGSize sz       = ((UINavigationController *) self.delegate).view.bounds.size;
            if (sz.width > sz.height) {
                isLandscape = YES;
                if (lastGoodTitleOffsetYLandscape > 0.0f) {
                    titleOffsetFromBottom = lastGoodTitleOffsetYLandscape;
                }
            }
            else {
                isLandscape = NO;
                if (lastGoodTitleOffsetYPortrait > 0.0f) {
                    titleOffsetFromBottom = lastGoodTitleOffsetYPortrait;
                }
            }
        }
        
        // - if the cached value couldn't produce the right value, try computing it.
        if (titleOffsetFromBottom < 1.0f) {
            // ...we need to force a layout so we can compute the center.
            UIView *vw = [[[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 5.0f, 5.0f)] autorelease];
            self.topItem.titleView = vw;
            [self layoutIfNeeded];
            if (CGRectGetMinY(vw.frame) > 0.0f) {
                // - if we weren't able to query the value because layout cannot occur yet, we need to try again.
                titleOffsetFromBottom = CGRectGetHeight(self.bounds) - vw.frame.origin.y;
            }
            self.topItem.titleView = nil;
            
            // ...save for the next time.
            if (hasGoodDelegate) {
                if (isLandscape) {
                    lastGoodTitleOffsetYLandscape = titleOffsetFromBottom;
                }
                else {
                    lastGoodTitleOffsetYPortrait = titleOffsetFromBottom;
                }
            }
        }
        
        // - small adjustment just to make it a bit more centered.
        if (isLandscape) {
            titleOffsetFromBottom -= 1.0f;
        }
        else {
            titleOffsetFromBottom -= 3.0f;
        }
    }
    
    // - now, we have a title center, and we can assume the nav bar is at the bottom of the image we intend to generate
    //   so the next step is to figure out where the title is in relation to that image.
    CGFloat titleOffsetFromCenter = ((CGRectGetHeight(rc) - titleOffsetFromBottom) - (CGRectGetHeight(rc)/2.0f));
    
    // ...now transform the path so that it is centered at the center of the nav bar.
    CGAffineTransform at = CGAffineTransformIdentity;
    CGSize szScaled      = CGSizeMake(rcCurve.size.width * scale, rcCurve.size.height * scale);
    CGFloat cx           = ((CGRectGetWidth(rc) - szScaled.width) / 2.0f);
    CGFloat cy           = ((CGRectGetHeight(rc) - szScaled.height) / 2.0f) + CGRectGetMinY(rc)/2.0f + titleOffsetFromCenter - ((curveWidth * scale)/2.0f) + 3.0f;
    at                   = CGAffineTransformTranslate(at, cx, cy);
    at                   = CGAffineTransformScale(at, scale, scale);
    [bp applyTransform:at];
    
    return bp;
}

/*
 *  Returns whether the bottom offset is good for the given orientation.
 */
-(BOOL) hasGoodBottomOffsetForPortrait:(BOOL) inPortrait
{
    if (inPortrait) {
        return (lastGoodTitleOffsetYPortrait > 0.0f ? YES : NO);
    }
    else {
        return (lastGoodTitleOffsetYLandscape > 0.0f ? YES : NO);
    }
}

@end
