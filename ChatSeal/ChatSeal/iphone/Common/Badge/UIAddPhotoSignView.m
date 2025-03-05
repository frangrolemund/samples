//
//  UIAddPhotoSignView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/3/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "UIAddPhotoSignView.h"
#import "ChatSeal.h"
#import "UIAdvancedSelfSizingTools.h"

//  - local data
static UIImage *imgGeneratedForeground     = nil;
static UIImage *imgGeneratedGloss          = nil;
static int     lastFontHeight              = -1;

// - forward declarations
@interface UIAddPhotoSignView (internal)
+(UIImage *) generateImageWithColor:(UIColor *) color;
+(UIImage *) foregroundImage;
+(UIImage *) glossImage;
+(UIFont *) imageFont;
@end

/**********************
 UIAddPhotoSignView
 **********************/
@implementation UIAddPhotoSignView
/*
 *  Object attributes.
 */
{
    UIImageView *ivCrown;
    UIImageView *ivGloss;
}

/*
 *  Initialize the class.
 */
+(void) initialize
{
    [UIAddPhotoSignView verifyResources];
}

/*
 *  Verify that the required crown resources are generated.
 */
+(void) verifyResources
{
    [UIAddPhotoSignView foregroundImage];
    [UIAddPhotoSignView glossImage];
}

/*
 *  Since we generate a crown image dynamically, release it when requested since
 *  it really isn't frequently useful.
 */
+(void) releaseGeneratedResources
{
    [imgGeneratedForeground release];
    imgGeneratedForeground = nil;
    
    [imgGeneratedGloss release];
    imgGeneratedGloss = nil;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        self.backgroundColor     = [UIColor clearColor];
        ivCrown                  = [[UIImageView alloc] initWithFrame:self.bounds];
        ivCrown.contentMode      = UIViewContentModeScaleAspectFill;
        ivCrown.image            = [UIAddPhotoSignView foregroundImage];
        [self addSubview:ivCrown];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [ivCrown release];
    ivCrown = nil;
    
    [ivGloss release];
    ivGloss = nil;
    
    [super dealloc];
}

/*
 *  Perform layout.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    CGSize sz      = self.bounds.size;
    CGSize szCrown = ivCrown.image.size;
    if (szCrown.width > sz.width) {
        CGFloat ar = szCrown.width/szCrown.height;
        szCrown    = CGSizeMake(sz.width, sz.width/ar);
    }
    ivCrown.frame = CGRectIntegral(CGRectMake((sz.width - szCrown.width)/2.0f, (sz.height - szCrown.height)/2.0f, szCrown.width, szCrown.height));
    ivGloss.frame = ivCrown.frame;
}

/*
 *  Display a gloss effect on the crown.
 */
-(void) triggerGlossEffect
{
    if (!ivGloss) {
        ivGloss                   = [[UIImageView alloc] initWithFrame:self.bounds];
        ivGloss.contentMode       = UIViewContentModeScaleAspectFill;
        ivGloss.image             = [UIAddPhotoSignView glossImage];
        [self addSubview:ivGloss];
        
        CAGradientLayer *glossMask = [[CAGradientLayer alloc] init];
        glossMask.contentsScale    = [UIScreen mainScreen].scale;
        glossMask.colors           = [NSArray arrayWithObjects:(id) [[UIColor colorWithWhite:0.0f alpha:0.0f] CGColor],
                                                               (id) [[UIColor colorWithWhite:1.0f alpha:0.55f] CGColor],
                                                               (id) [[UIColor colorWithWhite:0.0f alpha:0.0f] CGColor], nil];
        glossMask.locations        = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0.0f], [NSNumber numberWithFloat:0.5f], [NSNumber numberWithFloat:1.0f], nil];
        glossMask.position         = CGPointMake(CGRectGetWidth(ivGloss.bounds)/2.0f, CGRectGetHeight(ivGloss.bounds)/2.0f);
        ivGloss.layer.mask         = glossMask;
        [glossMask release];
    }
    
    //  - resize the gloss mask by random amount
    ivGloss.layer.mask.bounds      = CGRectMake(0.0f, 0.0f, 60.0f + (rand() % 30), 320.0f);
    
    //  - animate the gloss.
    ivGloss.layer.mask.hidden = NO;
    [CATransaction begin];
    [CATransaction setAnimationDuration:1.5f];
    [CATransaction setCompletionBlock:^(void){
        ivGloss.layer.mask.hidden = YES;
    }];
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"transform"];
    anim.fromValue         = [NSValue valueWithCATransform3D:CATransform3DMakeTranslation(-CGRectGetWidth(self.bounds), 0.0f, 0.0f)];
    CATransform3D target   = CATransform3DMakeTranslation(CGRectGetWidth(self.bounds) * 1.5f, 0.0f, 0.0f);
    anim.toValue           = [NSValue valueWithCATransform3D:target];
    [ivGloss.layer.mask addAnimation:anim forKey:@"transform"];
    ivGloss.layer.mask.transform = target;
    [CATransaction commit];
}

/*
 *  This object has been asked to update its dynamic type.
 */
-(void) updateDynamicTypeNotificationReceived
{
    // - not supported prior to iOS8
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        return;
    }
    
    // - multiple on-screen views use the common resources so don't update
    //   them needlessly.
    UIFont *font = [UIAddPhotoSignView imageFont];
    if ((int) font.pointSize != lastFontHeight) {
        [UIAddPhotoSignView releaseGeneratedResources];
    }
    
    // - snapshot what we have before we rebuild the text.
    UIView *vwSnap                = [self snapshotViewAfterScreenUpdates:YES];
    vwSnap.userInteractionEnabled = NO;
    [self addSubview:vwSnap];
    [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
        vwSnap.alpha = 0.0f;
    }completion:^(BOOL finished) {
        [vwSnap removeFromSuperview];
    }];
    
    // - now rebuild the text and re-layout the view.
    ivCrown.image = [UIAddPhotoSignView foregroundImage];
    if (ivGloss) {
        ivGloss.image = [UIAddPhotoSignView glossImage];
    }
    [self setNeedsLayout];
}
@end

/*****************************
 UIAddPhotoSignView (internal)
 *****************************/
@implementation UIAddPhotoSignView (internal)
/*
 * Generate a sign image and return it.
 */
+(UIImage *) generateImageWithColor:(UIColor *) color
{
    // - figure out how big the text is supposed to be.
    NSString* textContent = NSLocalizedString(@"Choose Photo", nil);
    NSMutableParagraphStyle* textStyle = [[[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
    [textStyle setAlignment: NSTextAlignmentCenter];
    UIFont *imageFont = [UIAddPhotoSignView imageFont];
    lastFontHeight    = (int) imageFont.pointSize;
    NSDictionary *textFontAttributes = @{NSFontAttributeName:imageFont, NSForegroundColorAttributeName: color, NSParagraphStyleAttributeName: textStyle};
    CGSize szText   = [textContent sizeWithAttributes:textFontAttributes];
    
    // - now size it precisely.
    szText          = CGSizeMake(ceilf((float)szText.width), ceilf((float)szText.height));
    UIGraphicsBeginImageContextWithOptions(szText, NO, 0.0f);
    [textContent drawInRect:CGRectMake(0.0f, 0.0f, szText.width, szText.height) withAttributes:textFontAttributes];
    UIImage *ret = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return ret;
}

/*
 *  Return the generated foreground image.
 */
+(UIImage *) foregroundImage
{
    if (!imgGeneratedForeground) {
        imgGeneratedForeground = [[UIAddPhotoSignView generateImageWithColor:[ChatSeal defaultAppTintColor]] retain];
    }
    return [[imgGeneratedForeground retain] autorelease];
}

/*
 *  Generate the gloss image.
 */
+(UIImage *) glossImage
{
    if (!imgGeneratedGloss) {
        imgGeneratedGloss = [[UIAddPhotoSignView generateImageWithColor:[UIColor colorWithRed: 0.984f green: 0.933f blue: 0.483f alpha: 1.0f]] retain];
    }
    return [[imgGeneratedGloss retain] autorelease];
}

/*
 *  Return the font used for images.
 */
+(UIFont *) imageFont
{
    UIFont *imageFont = nil;
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        imageFont = [UIAdvancedSelfSizingTools constrainedFontForPreferredSettingsAndTextStyle:UIFontTextStyleBody andSizeScale:1.0f andMinHeight:[ChatSeal minimumButtonFontSize]];
    }
    else {
        imageFont = [UIFont systemFontOfSize: [ChatSeal minimumButtonFontSize]];
    }
    return imageFont;
}

@end

