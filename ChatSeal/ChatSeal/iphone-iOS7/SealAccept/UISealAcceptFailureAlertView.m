//
//  UISealAcceptFailureAlertView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 2/19/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealAcceptFailureAlertView.h"
#import "UISealAcceptRadarView.h"
#import "AlertManager.h"
#import "ChatSeal.h"
#import "ChatSealBaseStation.h"
#import "UIAdvancedSelfSizingTools.h"

// - constants
static const CGFloat UISAFV_VIEW_PAD      = 5.0f;
static const CGFloat UISAFV_BORDER_PAD    = 15.0f;
static const CGFloat UISAFV_TEXT_PAD      = 8.0f;
static const CGFloat UISAFV_BIG_FONT_SIZE = 20.0f;
static const CGFloat UISAFV_SM_FONT_SIZE  = 17.0f;
static const CGFloat UISAFV_QR_BORDER_PCT = 0.185f;
static const CGFloat UISAFV_QR_PAD_PCT    = 0.138f;
static const CGFloat UISAFV_QR_CORNER_PCT = 0.136f;
static const CGFloat UISAFV_QR_CORNER_PAD = 0.089f;

// - forward declarations
@interface UISealAcceptFailureAlertView (internal)
+(UIFont *) alertFontInBig:(BOOL) isBig;
-(void) commonConfiguration;
-(void) assignAlertText;
@end

@interface UIQRCornerView : UIView
@end

/******************************
 UISealAcceptFailureAlertView
 ******************************/
@implementation UISealAcceptFailureAlertView
/*
 *  Object attributes
 */
{
    BOOL           displayConnectionFailure;
    UIView         *vwContents;
    UILabel        *lTitle;
    UILabel        *lAlertMessage;
    UIQRCornerView *corners[3];
}

/*
 *  Initialize the object.
 *  - the two modes are 'Connection' and 'Transfer' failure and have slightly
 *    different types of text depending on which one is being used.
 */
-(id) initWithFrame:(CGRect)frame andAsConnectionFailure:(BOOL) isConnFailure
{
    self = [super initWithFrame:frame];
    if (self) {
        displayConnectionFailure = isConnFailure;
        [self commonConfiguration];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [lTitle release];
    lTitle = nil;
    
    [lAlertMessage release];
    lAlertMessage = nil;
    
    [vwContents release];
    vwContents = nil;
    
    for (int i = 0; i < 3; i++) {
        [corners[i] release];
        corners[i] = nil;
    }
    
    [super dealloc];
}

/*
 *  Returns whether this view is being used for connection failure display as opposed
 *  to transfer failure display.
 */
-(BOOL) isConnectionFailureDisplay
{
    return displayConnectionFailure;
}

/*
 *  Layout the content.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    CGSize szBounds     = vwContents.bounds.size;
    
    // - figure out the placement of the corners
    CGFloat cornerWidth = szBounds.width * UISAFV_QR_CORNER_PCT;
    CGFloat cornerPad   = szBounds.width * UISAFV_QR_CORNER_PAD;
    
    corners[0].frame    = CGRectIntegral(CGRectMake(cornerPad, cornerPad, cornerWidth, cornerWidth));
    corners[1].frame    = CGRectIntegral(CGRectMake(szBounds.width - cornerWidth - cornerPad, cornerPad, cornerWidth, cornerWidth));
    corners[2].frame    = CGRectIntegral(CGRectMake(cornerPad, szBounds.height - cornerWidth - cornerPad, cornerWidth, cornerWidth));
 
    // - when the title exists, the layout requires a bit more thought.
    if (lTitle) {
        [lTitle sizeToFit];
        CGFloat stdWidth    = szBounds.width - (UISAFV_BORDER_PAD * 2.0f);
        lTitle.frame        = CGRectMake(UISAFV_BORDER_PAD, UISAFV_BORDER_PAD, stdWidth , CGRectGetHeight(lTitle.bounds));
        
        CGSize szAlert      = [lAlertMessage sizeThatFits:CGSizeMake(CGRectGetWidth(lTitle.bounds), 1.0f)];
        CGFloat startY      = CGRectGetMaxY(lTitle.frame) + UISAFV_TEXT_PAD;
        lAlertMessage.frame = CGRectMake(UISAFV_BORDER_PAD, startY, stdWidth, MIN(szAlert.height, szBounds.height - UISAFV_BORDER_PAD - startY));
    }
}

@end

/****************************************
 UISealAcceptFailureAlertView (internal)
 ****************************************/
@implementation UISealAcceptFailureAlertView (internal)
/*
 *  Return the appropriate font for the given style.
 */
+(UIFont *) alertFontInBig:(BOOL) isBig
{
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        UIFont *ret = [UIAdvancedSelfSizingTools constrainedFontForPreferredSettingsAndTextStyle:UIFontTextStyleBody andSizeScale:isBig ? [ChatSeal superBodyFontScalingFactor] : 1.0f andMinHeight:isBig ? UISAFV_BIG_FONT_SIZE : UISAFV_SM_FONT_SIZE];
        if (isBig) {
            ret = [UIFont boldSystemFontOfSize:ret.pointSize];
        }
        return ret;
    }
    else {
        CGFloat fontSize = isBig ? UISAFV_BIG_FONT_SIZE : UISAFV_SM_FONT_SIZE;
        if (isBig) {
            return [UIFont boldSystemFontOfSize:fontSize];
        }
        else {
            return [UIFont systemFontOfSize:fontSize];
        }
    }
}

/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    self.backgroundColor       = [UIColor clearColor];
    
    vwContents                 = [[UIView alloc] initWithFrame:CGRectInset(self.bounds, UISAFV_VIEW_PAD, UISAFV_VIEW_PAD)];
    vwContents.clipsToBounds   = YES;
    vwContents.autoresizingMask= UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    vwContents.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.75f];
    [self addSubview:vwContents];
    
    // - I'm using these corner items as a way to accentuate the connection to the scan region behind without needing
    //   to make this view very transparent.   Too much transparency and the words will be hard to read, but I want
    //   there to be some continuity with the background.
    for (int i = 0; i < 3; i++) {
        corners[i] = [[UIQRCornerView alloc] init];
        [vwContents addSubview:corners[i]];
    }
    
    lTitle                      = nil;
    if (!displayConnectionFailure) {
        // - a transfer failure is a bit more serious and should be something that people take notice of.
        lTitle                           = [[UILabel alloc] init];
        lTitle.textColor                 = [UIColor darkGrayColor];
        lTitle.textAlignment             = NSTextAlignmentCenter;
        lTitle.font                      = [UISealAcceptFailureAlertView alertFontInBig:YES];
        lTitle.adjustsFontSizeToFitWidth = YES;
        lTitle.minimumScaleFactor        = 0.5f;
        lTitle.text                      = NSLocalizedString(@"Transfer Problem", nil);
        [vwContents addSubview:lTitle];
    }
    
    lAlertMessage                           = [[UILabel alloc] init];
    lAlertMessage.textColor                 = [UIColor darkGrayColor];
    lAlertMessage.numberOfLines             = 0;
    lAlertMessage.textAlignment             = NSTextAlignmentCenter;
    lAlertMessage.font                      = [UISealAcceptFailureAlertView alertFontInBig:NO];
    lAlertMessage.adjustsFontSizeToFitWidth = YES;
    lAlertMessage.minimumScaleFactor        = 0.5f;
    [self assignAlertText];
    [vwContents addSubview:lAlertMessage];
    
    // - when all we're showing is the alert, allow it to auto-size
    if (!lTitle) {
        lAlertMessage.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        lAlertMessage.frame            = CGRectInset(vwContents.bounds, UISAFV_BORDER_PAD, UISAFV_BORDER_PAD);
    }
}

/*
 *  Figure out the best option for alert text based on the current type of view.
 */
-(void) assignAlertText
{
    if (displayConnectionFailure) {
        if ([[ChatSeal applicationBaseStation] proximityWirelessState] == CS_BSCS_ENABLED) {
            lAlertMessage.text = NSLocalizedString(@"Make sure your friend has Wi-Fi and Bluetooth turned-on in their Settings.", nil);
        }
        else {
            lAlertMessage.text = NSLocalizedString(@"You and your friend need to turn on Wi-Fi and Bluetooth in Settings.", nil);
        }
    }
    else {
        lAlertMessage.text = [AlertManager standardErrorTextWithText:NSLocalizedString(@"Your %@ was unable to accept your friend's seal.", nil)];
    }
}
@end

/******************************
 UIQRCornerView
 ******************************/
@implementation UIQRCornerView
/*
 *  Object attributes.
 */
{
    UIView *vwInner;
}

/*
 *  Return the color to use for this object.
 */
+(UIColor *) standardColor
{
    return [UIColor colorWithWhite:0.92f alpha:1.0f];
}

/*
 *  Initialize the object.
 */
-(id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        UIColor *cStandard      = [UIQRCornerView standardColor];
        self.layer.borderColor  = [cStandard CGColor];
        self.backgroundColor    = [UIColor clearColor];
        vwInner                 = [[UIView alloc] init];
        vwInner.backgroundColor = cStandard;
        [self addSubview:vwInner];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [vwInner release];
    vwInner = nil;
    [super dealloc];
}

/*
 *  Layout the content.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    CGSize sz              = self.bounds.size;
    CGFloat borderWidth    = (sz.width * UISAFV_QR_BORDER_PCT);
    self.layer.borderWidth = borderWidth;
    
    CGFloat innerPad       = (sz.width * UISAFV_QR_PAD_PCT);
    CGFloat innerWidth     = sz.width - borderWidth - borderWidth - innerPad - innerPad;
    vwInner.frame          = CGRectIntegral(CGRectMake((sz.width - innerWidth)/2.0f, (sz.height - innerWidth)/2.0f, innerWidth, innerWidth));
}

@end
