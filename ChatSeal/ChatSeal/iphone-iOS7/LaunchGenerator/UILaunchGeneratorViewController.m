//
//  UILaunchGeneratorViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 9/5/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UILaunchGeneratorViewController.h"
#import "ChatSeal.h"
#import "UIChatSealNavBarTitleView.h"

// - constants
static const CGFloat UILGV_STD_ICON_SIDE = 1024.0f;
static const CGFloat UILGV_STD_TGT_PCT   = 0.75f;

// - forward declarations
@interface UILaunchGeneratorViewController (internal)
@end

@interface UILaunchView : UIView
@end

/********************************
 UILaunchGeneratorViewController
 ********************************/
@implementation UILaunchGeneratorViewController
/*
 *  Object attributes.
 */
{
    
}

/*
 *  Return a view controller that can be used to generate launch images.
 */
+(UIViewController *) launchGenerator
{
    // - build an instance of this class.
    UILaunchGeneratorViewController *lgvc = [[[UILaunchGeneratorViewController alloc] init] autorelease];
    
    // - now a nav controller to display it.
    UINavigationController *nc            = [[[UINavigationController alloc] initWithRootViewController:lgvc] autorelease];
    nc.navigationBar.barStyle             = UIBarStyleDefault;
    nc.navigationBar.translucent          = NO;
    nc.navigationBar.titleTextAttributes  = [NSDictionary dictionaryWithObject:[ChatSeal defaultIconColor] forKey:NSForegroundColorAttributeName];
    
    return nc;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        // - make this look like one of the initial screens and hint at the composition.
        UIChatSealNavBarTitleView *tv    = [[[UIChatSealNavBarTitleView alloc] init] autorelease];
        tv.title                         = NSLocalizedString(@"ChatSeal", nil);
        [tv applyScramblingMask];
        [tv setMonochromeColor:[ChatSeal defaultIconColor]];
        self.navigationItem.titleView    = tv;
        
        // - FYI: this button shifts from 7.1 to 8.0 to the right slighly which makes the launch image look like crap on one of the two, depending on
        //   which generated it.
#if 0
        UIBarButtonItem *bbiAdd                 = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:nil action:nil] autorelease];
        bbiAdd.enabled                          = NO;
        self.navigationItem.rightBarButtonItem = bbiAdd;
#endif
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [super dealloc];
}

/*
 *  Load the view.
 */
-(void) loadView
{
    UILaunchView *lv = [[[UILaunchView alloc] init] autorelease];
    self.view        = lv;
}

/*
 *  The view has been loaded.
 */
-(void) viewDidLoad
{
    [super viewDidLoad];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    self.view.backgroundColor = [UIColor whiteColor];
}

@end

/*****************************************
 UILaunchGeneratorViewController (internal)
 *****************************************/
@implementation UILaunchGeneratorViewController (internal)


@end

/*************************
 UILaunchView
 *************************/
@implementation UILaunchView

/*
 *  Return the rectangle where the app icon will be drawn.
 */
-(CGRect) rcAppIcon
{
    // - we need to scale this for our current space.
    CGFloat width = (CGFloat) ceil(CGRectGetWidth(self.bounds) * UILGV_STD_TGT_PCT);
    return CGRectMake((CGRectGetWidth(self.bounds) - width)/2.0f, (CGRectGetHeight(self.bounds) - width)/2.0f, width, width);
}

/*
 *  Draw the app icon in the center of the screen.
 */
-(void) drawIcon
{
    CGContextSaveGState(UIGraphicsGetCurrentContext());
    
    // - we're just going to draw the icon image here.
    [[ChatSeal defaultIconColor] setFill];
    
    // ...this path is taken directly from PaintCode.
    UIBezierPath* shape2Path = UIBezierPath.bezierPath;
    [shape2Path moveToPoint: CGPointMake(828.94f, 801.77f)];
    [shape2Path addCurveToPoint: CGPointMake(788.66f, 726.89f) controlPoint1: CGPointMake(815.73f, 776.81f) controlPoint2: CGPointMake(801.85f, 751.85f)];
    [shape2Path addCurveToPoint: CGPointMake(781.93f, 699.26f) controlPoint1: CGPointMake(784.26f, 718.56f) controlPoint2: CGPointMake(781.93f, 709.21f)];
    [shape2Path addCurveToPoint: CGPointMake(783.71f, 684.81f) controlPoint1: CGPointMake(781.93f, 694.29f) controlPoint2: CGPointMake(782.58f, 689.44f)];
    [shape2Path addCurveToPoint: CGPointMake(795.15f, 607.85f) controlPoint1: CGPointMake(789.28f, 661.91f) controlPoint2: CGPointMake(795.15f, 636.35f)];
    [shape2Path addCurveToPoint: CGPointMake(568.1f, 358.44f) controlPoint1: CGPointMake(796.77f, 414.65f) controlPoint2: CGPointMake(644.15f, 365.22f)];
    [shape2Path addCurveToPoint: CGPointMake(499.42f, 359.22f) controlPoint1: CGPointMake(530.79f, 354.85f) controlPoint2: CGPointMake(509.4f, 357.9f)];
    [shape2Path addCurveToPoint: CGPointMake(454.64f, 405.36f) controlPoint1: CGPointMake(474.5f, 362.51f) controlPoint2: CGPointMake(454.64f, 380.16f)];
    [shape2Path addCurveToPoint: CGPointMake(501.64f, 451.69f) controlPoint1: CGPointMake(454.64f, 431.3f) controlPoint2: CGPointMake(475.7f, 450.45f)];
    [shape2Path addCurveToPoint: CGPointMake(568.1f, 453.1f) controlPoint1: CGPointMake(515.51f, 452.35f) controlPoint2: CGPointMake(536.99f, 449.16f)];
    [shape2Path addCurveToPoint: CGPointMake(701.84f, 609.58f) controlPoint1: CGPointMake(618.85f, 460.58f) controlPoint2: CGPointMake(703.02f, 484.07f)];
    [shape2Path addCurveToPoint: CGPointMake(567.48f, 774.73f) controlPoint1: CGPointMake(700.71f, 730.42f) controlPoint2: CGPointMake(619.37f, 764.3f)];
    [shape2Path addCurveToPoint: CGPointMake(503.24f, 779.91f) controlPoint1: CGPointMake(541.39f, 779.98f) controlPoint2: CGPointMake(519.67f, 781.11f)];
    [shape2Path addCurveToPoint: CGPointMake(497.33f, 779.72f) controlPoint1: CGPointMake(501.39f, 779.78f) controlPoint2: CGPointMake(499.12f, 779.62f)];
    [shape2Path addCurveToPoint: CGPointMake(492.27f, 784.88f) controlPoint1: CGPointMake(494.54f, 779.87f) controlPoint2: CGPointMake(492.27f, 782.09f)];
    [shape2Path addCurveToPoint: CGPointMake(494.22f, 788.88f) controlPoint1: CGPointMake(492.27f, 786.51f) controlPoint2: CGPointMake(493.02f, 787.97f)];
    [shape2Path addCurveToPoint: CGPointMake(512.23f, 824.91f) controlPoint1: CGPointMake(505.14f, 797.13f) controlPoint2: CGPointMake(512.23f, 810.19f)];
    [shape2Path addCurveToPoint: CGPointMake(494.23f, 860.96f) controlPoint1: CGPointMake(512.23f, 839.64f) controlPoint2: CGPointMake(505.06f, 852.58f)];
    [shape2Path addCurveToPoint: CGPointMake(492.27f, 864.96f) controlPoint1: CGPointMake(493.04f, 861.88f) controlPoint2: CGPointMake(492.27f, 863.33f)];
    [shape2Path addCurveToPoint: CGPointMake(496.99f, 870.01f) controlPoint1: CGPointMake(492.27f, 867.64f) controlPoint2: CGPointMake(494.36f, 869.81f)];
    [shape2Path addCurveToPoint: CGPointMake(567.48f, 869.7f) controlPoint1: CGPointMake(516.81f, 871.51f) controlPoint2: CGPointMake(539.02f, 872.64f)];
    [shape2Path addCurveToPoint: CGPointMake(706.5f, 812.17f) controlPoint1: CGPointMake(609.52f, 865.37f) controlPoint2: CGPointMake(662.33f, 847.07f)];
    [shape2Path addCurveToPoint: CGPointMake(732.17f, 803.53f) controlPoint1: CGPointMake(713.65f, 806.77f) controlPoint2: CGPointMake(722.53f, 803.53f)];
    [shape2Path addCurveToPoint: CGPointMake(747.06f, 806.21f) controlPoint1: CGPointMake(737.41f, 803.53f) controlPoint2: CGPointMake(742.43f, 804.48f)];
    [shape2Path addCurveToPoint: CGPointMake(805.08f, 828.54f) controlPoint1: CGPointMake(766.4f, 813.65f) controlPoint2: CGPointMake(785.74f, 821.1f)];
    [shape2Path addCurveToPoint: CGPointMake(814.8f, 829.7f) controlPoint1: CGPointMake(808.18f, 829.77f) controlPoint2: CGPointMake(811.54f, 830.16f)];
    [shape2Path addCurveToPoint: CGPointMake(825.64f, 824.32f) controlPoint1: CGPointMake(818.77f, 829.15f) controlPoint2: CGPointMake(822.59f, 827.37f)];
    [shape2Path addCurveToPoint: CGPointMake(828.94f, 801.77f) controlPoint1: CGPointMake(831.74f, 818.22f) controlPoint2: CGPointMake(832.84f, 808.99f)];
    [shape2Path closePath];
    [shape2Path moveToPoint: CGPointMake(456.25f, 247.41f)];
    [shape2Path addCurveToPoint: CGPointMake(321.89f, 408.66f) controlPoint1: CGPointMake(404.36f, 257.85f) controlPoint2: CGPointMake(323.02f, 287.82f)];
    [shape2Path addCurveToPoint: CGPointMake(456.17f, 567.82f) controlPoint1: CGPointMake(320.71f, 534.17f) controlPoint2: CGPointMake(405.42f, 560.33f)];
    [shape2Path addCurveToPoint: CGPointMake(522.63f, 569.62f) controlPoint1: CGPointMake(487.27f, 571.76f) controlPoint2: CGPointMake(508.75f, 568.96f)];
    [shape2Path addCurveToPoint: CGPointMake(569.63f, 615.95f) controlPoint1: CGPointMake(548.57f, 570.86f) controlPoint2: CGPointMake(569.63f, 590.01f)];
    [shape2Path addCurveToPoint: CGPointMake(524.85f, 662.09f) controlPoint1: CGPointMake(569.63f, 641.15f) controlPoint2: CGPointMake(549.77f, 658.8f)];
    [shape2Path addCurveToPoint: CGPointMake(456.16f, 662.48f) controlPoint1: CGPointMake(514.87f, 663.41f) controlPoint2: CGPointMake(493.48f, 666.06f)];
    [shape2Path addCurveToPoint: CGPointMake(228.58f, 410.39f) controlPoint1: CGPointMake(380.12f, 655.69f) controlPoint2: CGPointMake(226.96f, 603.59f)];
    [shape2Path addCurveToPoint: CGPointMake(456.25f, 152.44f) controlPoint1: CGPointMake(228.55f, 220.17f) controlPoint2: CGPointMake(366.8f, 161.66f)];
    [shape2Path addCurveToPoint: CGPointMake(526.74f, 152.14f) controlPoint1: CGPointMake(484.71f, 149.51f) controlPoint2: CGPointMake(506.92f, 150.63f)];
    [shape2Path addCurveToPoint: CGPointMake(531.46f, 157.18f) controlPoint1: CGPointMake(529.37f, 152.34f) controlPoint2: CGPointMake(531.46f, 154.51f)];
    [shape2Path addCurveToPoint: CGPointMake(529.5f, 161.19f) controlPoint1: CGPointMake(531.46f, 158.81f) controlPoint2: CGPointMake(530.69f, 160.26f)];
    [shape2Path addCurveToPoint: CGPointMake(511.51f, 197.23f) controlPoint1: CGPointMake(518.67f, 169.56f) controlPoint2: CGPointMake(511.51f, 182.51f)];
    [shape2Path addCurveToPoint: CGPointMake(529.51f, 233.27f) controlPoint1: CGPointMake(511.51f, 211.95f) controlPoint2: CGPointMake(518.59f, 225.02f)];
    [shape2Path addCurveToPoint: CGPointMake(531.46f, 237.26f) controlPoint1: CGPointMake(530.71f, 234.18f) controlPoint2: CGPointMake(531.46f, 235.64f)];
    [shape2Path addCurveToPoint: CGPointMake(526.4f, 242.43f) controlPoint1: CGPointMake(531.46f, 240.05f) controlPoint2: CGPointMake(529.2f, 242.28f)];
    [shape2Path addCurveToPoint: CGPointMake(520.49f, 242.23f) controlPoint1: CGPointMake(524.61f, 242.53f) controlPoint2: CGPointMake(522.34f, 242.37f)];
    [shape2Path addCurveToPoint: CGPointMake(456.25f, 247.41f) controlPoint1: CGPointMake(504.06f, 241.03f) controlPoint2: CGPointMake(482.34f, 242.16f)];
    [shape2Path closePath];
    
    // - we need to scale this for our current space.
    CGRect rcIcon = [self rcAppIcon];
    CGAffineTransform at = CGAffineTransformIdentity;
    at                   = CGAffineTransformTranslate(at, rcIcon.origin.x, rcIcon.origin.y);
    at                   = CGAffineTransformScale(at, CGRectGetWidth(rcIcon)/UILGV_STD_ICON_SIDE, CGRectGetWidth(rcIcon)/UILGV_STD_ICON_SIDE);
    [shape2Path applyTransform:at];
    
    [shape2Path fill];
    
    CGContextRestoreGState(UIGraphicsGetCurrentContext());
}

/*
 *  Draw a tagline below the icon.
 */
-(void) drawTagline
{
    CGContextSaveGState(UIGraphicsGetCurrentContext());
    
    [[ChatSeal defaultIconColor] setStroke];
    
    // - at the time I chose this tagline (9/10/14), it appeared free from Trademark issues, unlike earlier
    //   iterations.
    NSString *tag             = NSLocalizedString(@"Be Personal.", nil);
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:[UIFont fontWithName:[ChatSeal defaultAppStylizedFontNameAsWeight:CS_SF_NORMAL] size:16.0f] forKey:NSFontAttributeName];
    [dict setObject:[ChatSeal defaultIconColor] forKey:NSForegroundColorAttributeName];
    CGSize sz = [tag sizeWithAttributes:dict];
    
    CGRect rc                 = [self rcAppIcon];
    CGPoint pt                = CGPointMake(CGRectGetMaxX(rc) - sz.width + 0.0f, CGRectGetMaxY(rc) - 20.0f);
    [tag drawAtPoint:pt withAttributes:dict];
    
    CGContextRestoreGState(UIGraphicsGetCurrentContext());
}

/*
 *  Draw the custom launch image.
 */
-(void) drawRect:(CGRect)rect
{
    [self drawIcon];
    [self drawTagline];
}

@end