//
//  UIVaultFailureOverlayView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/7/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIVaultFailureOverlayView.h"
#import "ChatSeal.h"
#import "AlertManager.h"
#import "UIImageGeneration.h"
#import "UIAdvancedSelfSizingTools.h"

// - constants
static const CGFloat UIVFO_VPAD             = 9.0f;
static const CGFloat UIVFO_BPAD             = 10.0f;
static const CGFloat UIVFO_TITLE_TEXT_PAD   = 6.0f;
static const CGFloat UIVFO_PAD_CX           = 15.0f;
static const CGFloat UIVFO_MAX_SIDE         = 256.0f;
static const CGFloat UIVFO_TGT_ALERT_WIDTH  = 260.0f;       //  assume portrait mode and take off space for the padding.
static const CGFloat UIVFO_ALERT_CORNER_RAD = 8.0f;
static const int     UIVFO_TAG_FROSTED      = 1000;
static const CGFloat UIVFO_PH_HDR_VPAD      = 8.0f;
static const CGFloat UIVFO_PH_HDR_HPAD      = 15.0f;
static const CGFloat UIVFO_PH_HDR_TEXT_HT   = 5.0f;
static const CGFloat UIVFO_PH_ACTION_HEIGHT = 44.0f;
static const CGFloat UIVFO_PH_HEADER_HEIGHT = 42.0f;
static const CGFloat UIVFO_PH_LEFT_PAD      = 20.0f;
static const CGFloat UIVFO_PH_BIG_TEXT_HT   = 5.0f;


// - forward declarations
@interface UIVaultFailureOverlayView (internal)
-(void) commonConfiguration;
-(void) buildAllContentViewsIfNecessary;
-(UIImage *) placeholderImage;
-(BOOL) useSimplifiedDisplay;
-(void) reconfigureDynamicItemsDuringInit:(BOOL) isInit;
@end

/*************************
 UIVaultFailureOverlayView
 *************************/
@implementation UIVaultFailureOverlayView
/*
 *  Object attributes.
 */
{
    BOOL        isVisible;
    UIView      *vwContent;
    UIView      *vwAlert;
    UILabel     *lTitle;
    UILabel     *lError;
    UIImageView *ivPlaceholder;
    UIImageView *ivShadow;
    BOOL        applyFrostedEffect;
    BOOL        scalePlaceholder;
}
@synthesize delegate;

/*
 *  Use this color where we'd normally use the white background for displaying screens.
 */
+(UIColor *) standardPlaceholderWhiteAlternative
{
    return [UIColor colorWithWhite:0.4f alpha:1.0f];
}

/*
 *  Return the standard height of a header.
 */
+(CGFloat) standardHeaderHeight
{
    return UIVFO_PH_HDR_VPAD + UIVFO_PH_HEADER_HEIGHT;
}

/*
 *  Draw a header at the given location.
 */
+(void) drawStandardHeaderInRect:(CGRect) rc assumingTextPct:(CGFloat) textPct
{
    [[UIVaultFailureOverlayView standardPlaceholderWhiteAlternative] setFill];
    UIRectFill(rc);
    rc = CGRectMake(UIVFO_PH_HDR_HPAD,
                    CGRectGetMaxY(rc) - (UIVFO_PH_HDR_VPAD * 2.0f) - UIVFO_PH_HDR_TEXT_HT,
                    CGRectGetWidth(rc) * textPct,
                    UIVFO_PH_HDR_TEXT_HT);
    [[UIColor lightGrayColor] setFill];
    UIRectFill(rc);
}

/*
 *  Draw a line of tool content at the given position and return the updated yPos;
 */
+(CGFloat) drawStandardToolLineAtPos:(CGFloat) yPos andWithWidth:(CGFloat) width andShowText:(BOOL) showText ofWidth:(CGFloat) textWidth
{
    if (showText) {
        CGRect rc = CGRectMake(UIVFO_PH_LEFT_PAD, yPos + (UIVFO_PH_ACTION_HEIGHT / 2.0f) - (UIVFO_PH_BIG_TEXT_HT/2.0f), textWidth, UIVFO_PH_BIG_TEXT_HT);
        [[UIColor blackColor] setFill];
        UIRectFill(rc);
    }
    
    CGFloat bottom = yPos + UIVFO_PH_ACTION_HEIGHT;
    CGContextSetLineWidth(UIGraphicsGetCurrentContext(), 0.5f);
    [[UIColor lightGrayColor] setStroke];
    CGContextBeginPath(UIGraphicsGetCurrentContext());
    CGContextMoveToPoint(UIGraphicsGetCurrentContext(), UIVFO_PH_LEFT_PAD, bottom);
    CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), width, bottom);
    CGContextStrokePath(UIGraphicsGetCurrentContext());
    return bottom;
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
    delegate = nil;
    [lTitle release];
    lTitle = nil;
    
    [lError release];
    lError = nil;
    
    [vwAlert release];
    vwAlert = nil;
    
    [ivPlaceholder release];
    ivPlaceholder = nil;
    
    [ivShadow release];
    ivShadow = nil;
    
    [vwContent release];
    vwContent = nil;
    
    [super dealloc];
}

/*
 *  Display the failure view with the given title and text.
 *  - call with nil values for the title/text for force a placeholder update while keeping the same text.
 */
-(void) showFailureWithTitle:(NSString *) title andText:(NSString *) text andAnimation:(BOOL) animated
{
    // - make sure the random content views are created.
    [self buildAllContentViewsIfNecessary];
    
    // - assign the text items, but only if they are filled so that we can recall this method
    //   to force a placeholder update
    if (title) {
        lTitle.text = title;
    }
    if (text) {
        lError.text = [AlertManager standardErrorTextWithText:text];
    }
    
    // - and the image.
    ivPlaceholder.image  = [self placeholderImage];
    ivPlaceholder.hidden = (ivPlaceholder.image ? NO : YES);
    
    // - and the shadow overlay.
    CGSize szMyBounds = self.bounds.size;
    CGFloat myAr      = szMyBounds.width/szMyBounds.height;
    if (myAr == 0.0f) {
        myAr = 1.0f;
    }
    CGFloat shadSide  = 128.0f;
    CGFloat shortDiam = 0.0f;
    if (myAr > 1.0f) {
        shortDiam = shadSide/myAr;
    }
    else {
        shortDiam = shadSide * myAr;
    }
    CGSize szImage    = CGSizeMake(shadSide, shadSide);
    UIGraphicsBeginImageContextWithOptions(szImage, NO, 0.0f);
    NSArray *arrColors     = [NSArray arrayWithObjects:(id) [UIColor colorWithWhite:1.0f alpha:0.0].CGColor, (id) [UIColor colorWithWhite:0.0f alpha:0.20f].CGColor, nil];
    CGGradientRef gradient = CGGradientCreateWithColors(NULL, (CFArrayRef) arrColors, NULL);
    CGPoint ptCenter       = CGPointMake(szImage.width/2.0f, szImage.height/2.0f);
    CGContextDrawRadialGradient(UIGraphicsGetCurrentContext(), gradient, ptCenter, 0.0f, ptCenter, shortDiam * 0.95f, kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(gradient);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    ivShadow.image = img;
    UIGraphicsEndImageContext();

    // - lay everything out to ensure it is ready to be animated.
    [self setNeedsLayout];
    [self layoutIfNeeded];
    
    // - manage the display of this view.
    if (animated) {
        if (!isVisible) {
            self.alpha  = 0.0f;
            self.hidden = NO;
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                self.alpha              = 1.0f;
            }];
        }
    }
    else {
        self.hidden             = NO;
        self.alpha              = 1.0f;
    }

    // - assign the visibility flag last.
    isVisible = YES;
}

/*
 *  Hide this view.
 */
-(void) hideFailureWithAnimation:(BOOL) animated
{
    // - manage the shift out of an error state.
    if (animated) {
        // - we're going to hide this display more slowly than we showed it because it often
        //   gets hidden during a transition from the background and the first part of the animation
        //   is lost in the initial transition of the app window.
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] * 3.0f animations:^(void) {
            self.alpha              = 0.0f;
        } completion:^(BOOL finished) {
            self.hidden         = YES;
            ivShadow.image      = nil;
            ivPlaceholder.image = nil;
        }];
    }
    else {
        self.alpha              = 0.0f;
        self.hidden             = YES;
        ivShadow.image          = nil;
        ivPlaceholder.image     = nil;
    }
    
    //- assign the visibility flag last.
    isVisible = NO;
}

/*
 *  Manage the layout tasks.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    CGSize szBounds = self.bounds.size;
    
    // - the image view is sized as large as it can be sized and maintain the
    //   aspect ratio of the image.
    if (ivPlaceholder.image) {
        CGSize szImage          = ivPlaceholder.image.size;
        CGFloat arImage         = szImage.width/szImage.height;
        CGFloat targetWidth     = szBounds.height * arImage;
        if (targetWidth > szBounds.width) {
            szImage = CGSizeMake(szBounds.width, szBounds.width/arImage);
        }
        else {
            szImage.width  = targetWidth;
            szImage.height = szBounds.height;
        }
        szImage.width           = ceilf((float)szImage.width);
        szImage.height          = ceilf((float)szImage.height);
        ivPlaceholder.bounds    = CGRectMake(0.0f, 0.0f, szImage.width, szImage.height);
        ivPlaceholder.center    = CGPointMake(szBounds.width/2.0f, szBounds.height/2.0f);
    }
    else {
        ivPlaceholder.frame = CGRectZero;
    }
    
    // - lay out the text items, but these are sized for a portrait mode display and
    //   never modified.
    [lTitle sizeToFit];
    CGSize szTitle = lTitle.bounds.size;
    CGSize szError = [lError sizeThatFits:CGSizeMake(UIVFO_TGT_ALERT_WIDTH - (UIVFO_PAD_CX * 2.0f), 1.0f)];
    CGSize szAlert = CGSizeMake(UIVFO_TGT_ALERT_WIDTH, UIVFO_VPAD + szTitle.height + szError.height + UIVFO_VPAD + UIVFO_VPAD + UIVFO_BPAD);
    vwAlert.bounds = CGRectMake(0.0f, 0.0f, szAlert.width, szAlert.height);
    vwAlert.center = CGPointMake(szBounds.width/2.0f, szBounds.height/2.0f);
    lTitle.frame   = CGRectMake(UIVFO_PAD_CX, UIVFO_VPAD, szAlert.width - (UIVFO_PAD_CX * 2.0f), szTitle.height);
    lError.frame   = CGRectMake(UIVFO_PAD_CX, CGRectGetMaxY(lTitle.frame) + UIVFO_TITLE_TEXT_PAD, szError.width, szError.height);
}

/*
 *  Returns if the current state is visible.
 */
-(BOOL) isFailureVisible
{
    return isVisible;
}

/*
 *  Return the color used at the background that is consistent with the default application compliment.
 */
+(UIColor *) complimentaryBackgroundColor
{
    return [UIImageGeneration adjustColor:[ChatSeal defaultIconColor] byHuePct:1.0f andSatPct:1.0f andBrPct:0.40f andAlphaPct:1.0f];
}

/*
 *  Turn the frosted effect on/off.
 */
-(void) setUseFrostedEffect:(BOOL) useFrosted
{
    applyFrostedEffect = useFrosted;
    if (ivPlaceholder) {
        UIView *vw = [ivPlaceholder viewWithTag:UIVFO_TAG_FROSTED];
        if (vw) {
            vw.hidden = !useFrosted;
        }
    }
}

/*
 *  Turn placeholder scaling on/off.
 */
-(void) setScalePlaceholderForEfficiency:(BOOL)enabled
{
    scalePlaceholder = enabled;
}

/*
 *  A dynamic type update was received.
 */
-(void) updateDynamicTypeNotificationReceived
{
    [self reconfigureDynamicItemsDuringInit:NO];
}

@end


/************************************
 UIVaultFailureOverlayView (internal)
 ************************************/
@implementation UIVaultFailureOverlayView (internal)
/*
 *  Configure this view.
 */
-(void) commonConfiguration
{
    isVisible           = NO;
    vwContent           = nil;
    vwAlert             = nil;
    lTitle              = nil;
    lError              = nil;
    ivPlaceholder       = nil;
    ivShadow            = nil;
    applyFrostedEffect  = YES;
    scalePlaceholder    = YES;
    [self hideFailureWithAnimation:NO];
    
    self.backgroundColor        = [ChatSeal defaultIconColor];
    self.userInteractionEnabled = NO;
}

/*
 *  We create these views on-demand to minimize the cost of using this.
 */
-(void) buildAllContentViewsIfNecessary
{
    // - already built.
    if (vwContent) {
        return;
    }
    
    // - the content is intended to hint at the app compliment, but only slightly.
    vwContent                  = [[UIView alloc] initWithFrame:self.bounds];
    vwContent.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    vwContent.backgroundColor  = [UIVaultFailureOverlayView complimentaryBackgroundColor];
    [self addSubview:vwContent];
    
    // - the placeholder image.
    ivPlaceholder                 = [[UIImageView alloc] init];
    ivPlaceholder.backgroundColor = [UIColor colorWithWhite:0.9f alpha:1.0f];
    ivPlaceholder.contentMode     = UIViewContentModeScaleAspectFill;
    [vwContent addSubview:ivPlaceholder];
    
    // - add a simple obscuring layer over the image when in simplified mode.
    if ([self useSimplifiedDisplay]) {
        UIView *vw          = [[[UIView alloc] initWithFrame:ivPlaceholder.frame] autorelease];
        vw.tag              = UIVFO_TAG_FROSTED;
        vw.backgroundColor  = [ChatSeal defaultLowChromeUltraFrostedColor];
        vw.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        if (!applyFrostedEffect) {
            vw.hidden = YES;
        }
        [ivPlaceholder addSubview:vw];
    }
    
    // the shadow goes over the placeholder.
    ivShadow                  = [[UIImageView alloc] initWithFrame:self.bounds];
    ivShadow.contentMode      = UIViewContentModeScaleAspectFill;
    ivShadow.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:ivShadow];
    
    // the alert is displayed prominently above everything.
    vwAlert                    = [[UIView alloc] init];
    vwAlert.backgroundColor    = [UIColor colorWithWhite:1.0f alpha:0.98f];
    vwAlert.layer.cornerRadius = UIVFO_ALERT_CORNER_RAD;
    vwAlert.layer.shadowOpacity = 0.25f;
    vwAlert.layer.shadowColor  = [[UIColor blackColor] CGColor];
    vwAlert.layer.shadowRadius = 2.0f;
    vwAlert.layer.shadowOffset = CGSizeMake(-0.5f, -0.5f);
    [self addSubview:vwAlert];
    
    lTitle               = [[UILabel alloc] init];
    lTitle.textColor     = [UIColor blackColor];
    lTitle.textAlignment = NSTextAlignmentCenter;
    lTitle.numberOfLines = 1;
    lTitle.font          = [UIFont boldSystemFontOfSize:19.0f];             //  consistent with the generic auth error
    [vwAlert addSubview:lTitle];
    
    lError               = [[UILabel alloc] init];
    lError.textColor     = [UIColor blackColor];
    lError.textAlignment = NSTextAlignmentCenter;
    lError.numberOfLines = 0;
    lError.font          = [UIFont systemFontOfSize:17.0f];                 // consistent with the generic auth error.
    [vwAlert addSubview:lError];
    [self reconfigureDynamicItemsDuringInit:YES];
}

/*
 *  Retrieve or compute a placeholder image for this view.
 */
-(UIImage *) placeholderImage
{
    UIImage *imgPlaceholder = nil;
    if (delegate && [delegate respondsToSelector:@selector(placeholderImageForOverlay:)]) {
        imgPlaceholder = [delegate placeholderImageForOverlay:self];
    }
    
    // ... no placeholder, then we'll hide this.
    if (!imgPlaceholder) {
        return nil;
    }

    // - now make sure the image is frosted in a way that makes sense.
    CGFloat scale = 1.0f;
    CGSize szImage = imgPlaceholder.size;
    if (scalePlaceholder && (szImage.width > UIVFO_MAX_SIDE || szImage.height > UIVFO_MAX_SIDE)) {
        if (szImage.width > szImage.height) {
            scale = UIVFO_MAX_SIDE/szImage.width;
        }
        else {
            scale = UIVFO_MAX_SIDE/szImage.height;
        }
    }
    
    if ([self useSimplifiedDisplay] || !applyFrostedEffect) {
        return [UIImageGeneration image:imgPlaceholder scaledTo:scale asOpaque:YES];
    }
    else {
        return [ChatSeal generateFrostedImageOfType:CS_FS_UNFOCUSED fromImage:imgPlaceholder atScale:scale];
    }
}

/*
 *  Split out really as a debugging tool.
 */
-(BOOL) useSimplifiedDisplay
{
    static BOOL ret = NO;
    return ret;
}

/*
 *  Reconfigure for dynamic type.
 */
-(void) reconfigureDynamicItemsDuringInit:(BOOL) isInit
{
    // - this was not common prior to 8.0
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        return;
    }
    
    [UIAdvancedSelfSizingTools constrainTextLabel:lTitle withPreferredSettingsAndTextStyle:UIFontTextStyleHeadline andMinimumSize:19.0f duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextLabel:lError withPreferredSettingsAndTextStyle:UIFontTextStyleSubheadline andMinimumSize:17.0f duringInitialization:isInit];
    [self setNeedsLayout];
}
@end