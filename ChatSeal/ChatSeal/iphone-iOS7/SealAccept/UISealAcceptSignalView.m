//
//  UISealAcceptSignalView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 2/17/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealAcceptSignalView.h"
#import "ChatSeal.h"
#import "ChatSealBaseStation.h"
#import "UIImageGeneration.h"
#import "UIAdvancedSelfSizingTools.h"

// - constants
static const CGFloat        UISASV_STD_SLINE_FONT_SIZE  = 17.0f;
static const CGFloat        UISASV_STD_BIG_FONT_SIZE    = 20.0f;
static const CGFloat        UISASV_STD_STD_FONT_SIZE    = 17.0f;

// - forward declarations
@interface UISealAcceptSignalView (internal)
-(NSAttributedString *) attributedString:(NSString *) s inBigFontSize:(BOOL) isBig andIsBold:(BOOL) isBold;
-(void) commonConfiguration;
+(UIFont *) standardSingleLineFont;
@end

/**********************
 UISealAcceptSignalView
 **********************/
@implementation UISealAcceptSignalView
/*
 *  Object attributes.
 */
{
    UILabel     *lSignalText;
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
 *  Free the object.
 */
-(void) dealloc
{
    [lSignalText release];
    lSignalText = nil;
    
    [super dealloc];
}

/*
 *  Determine if this signal is equal to another.
 */
-(BOOL) isEqualToSignal:(UISealAcceptSignalView *) otherView
{
    if (!otherView || !otherView->lSignalText) {
        return NO;
    }
    return [lSignalText.text isEqualToString:otherView->lSignalText.text];
}

@end

/*********************************
 UISealAcceptSignalView (internal)
 *********************************/
@implementation UISealAcceptSignalView (internal)
/*
 *  Return an attributed string formatted as requested.
 */
-(NSAttributedString *) attributedString:(NSString *) s inBigFontSize:(BOOL) isBig andIsBold:(BOOL) isBold
{
    UIFont *font     = nil;
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        font = [UIAdvancedSelfSizingTools constrainedFontForPreferredSettingsAndTextStyle:UIFontTextStyleBody andSizeScale:isBig ? [ChatSeal superBodyFontScalingFactor] : 1.0f andMinHeight:1.0f];
        if (isBold) {
            font = [UIFont boldSystemFontOfSize:font.pointSize];
        }
    }
    else {
        CGFloat fontSize = isBig ? UISASV_STD_BIG_FONT_SIZE : UISASV_STD_STD_FONT_SIZE;
        if (isBold) {
            font = [UIFont boldSystemFontOfSize:fontSize];
        }
        else {
            font = [UIFont systemFontOfSize:fontSize];
        }
    }
    return [[[NSAttributedString alloc] initWithString:s attributes:[NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName]] autorelease];
}

/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    self.backgroundColor = [UIColor clearColor];
    
    // - I'm using a simple label to store the text or attributed text simply because
    //   it can be easily converted to debug it later, it retains the text elements and makes
    //   drawing pretty simple.
    lSignalText                  = [[UILabel alloc] initWithFrame:self.bounds];
    lSignalText.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    lSignalText.textAlignment    = NSTextAlignmentCenter;
    lSignalText.textColor        = [UIColor colorWithWhite:0.9f alpha:0.8f];
    [self addSubview:lSignalText];
    
    // - when this view is much wider than it is tall, it is being viewed on a portrait
    //   screen, so we're going to format a single line instead of two
    CGSize szBounds      = self.bounds.size;
    BOOL isBottomAligned = NO;
    if (szBounds.height * 2.0f < szBounds.width) {
        isBottomAligned                       = YES;
        lSignalText.numberOfLines             = 1;
        lSignalText.minimumScaleFactor        = 0.5f;
        lSignalText.adjustsFontSizeToFitWidth = YES;
    }
    else {
        // - when it is side-aligned, we're going to format the text a bit differently
        //   to get better quality.
        lSignalText.numberOfLines = 3;
    }
    
    // - now figure out what kind of text to display and how best to format it.
    NSUInteger numSealsNear = [[ChatSeal applicationBaseStation] vaultReadyUserCount];
    if (numSealsNear) {
        if (isBottomAligned) {
            lSignalText.text = NSLocalizedString(@"Seals are Near", nil);
            lSignalText.font = [UISealAcceptSignalView standardSingleLineFont];
        }
        else {
            NSMutableAttributedString *mas = [[NSMutableAttributedString alloc] init];
            NSString *sFmt                 = NSLocalizedString(@"Seals\n", nil);
            [mas appendAttributedString:[self attributedString:sFmt inBigFontSize:YES andIsBold:YES]];
            [mas appendAttributedString:[self attributedString:NSLocalizedString(@"are Near", nil) inBigFontSize:NO andIsBold:NO]];
            lSignalText.attributedText = mas;
            [mas release];
        }
    }
    else {
        ps_bs_proximity_state_t wirelessState = [[ChatSeal applicationBaseStation] proximityWirelessState];
        if (wirelessState == CS_BSCS_ENABLED) {
            if (isBottomAligned) {
                lSignalText.text = NSLocalizedString(@"No Seals are Near", nil);
                lSignalText.font = [UISealAcceptSignalView standardSingleLineFont];
            }
            else {
                NSMutableAttributedString *mas = [[NSMutableAttributedString alloc] init];
                [mas appendAttributedString:[self attributedString:NSLocalizedString(@"No Seals\n", nil) inBigFontSize:YES andIsBold:YES]];
                [mas appendAttributedString:[self attributedString:NSLocalizedString(@"are Near", nil) inBigFontSize:NO andIsBold:NO]];
                lSignalText.attributedText = mas;
                [mas release];
            }
        }
        else {
            // - with degraded wireless, we're not going to use attributed text even when left-aligned because
            //   two sizes doesn't make sense.
            if (wirelessState == CS_BSCS_DEGRADED) {
                if (isBottomAligned) {
                    lSignalText.text = NSLocalizedString(@"Bluetooth Wireless Only", nil);
                }
                else {
                    lSignalText.text = NSLocalizedString(@"Bluetooth\nWireless\nOnly", nil);
                }
            }
            else {
                if (isBottomAligned) {
                    lSignalText.text = NSLocalizedString(@"No Wireless Available", nil);
                }
                else {
                    lSignalText.text = NSLocalizedString(@"No Wireless\nAvailable", nil);
                }
            }
            
            // - only one size is necessary.  This looks good in both orientations.
            lSignalText.font = [UISealAcceptSignalView standardSingleLineFont];
        }
    }
}

/*
 *  Return a font for displaying the signal in a single line.
 */
+(UIFont *) standardSingleLineFont
{
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        return [UIAdvancedSelfSizingTools constrainedFontForPreferredSettingsAndTextStyle:UIFontTextStyleBody];
    }
    else {
        return [UIFont systemFontOfSize:UISASV_STD_SLINE_FONT_SIZE];
    }
}
@end
