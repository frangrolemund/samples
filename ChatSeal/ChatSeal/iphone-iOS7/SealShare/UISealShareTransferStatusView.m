//
//  UISealShareTransferStatusView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 2/27/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealShareTransferStatusView.h"
#import "ChatSeal.h"
#import "UIAdvancedSelfSizingTools.h"

// - constants
static const CGFloat UISSTS_STD_PAD = 8.0f;

// - forward declarations
@interface UISealShareTransferStatusView (internal)
-(void) commonConfiguration;
-(void) reconfigureDynamicLabelsForInit:(BOOL) isInit;
@end

/*******************************
 UISealShareTransferStatusView
 *******************************/
@implementation UISealShareTransferStatusView
/*
 *  Object attributes.
 */
{
    UILabel                  *lStatusText;
    UIActivityIndicatorView  *aivWorking;
}

/*
 *  Initialize this object.
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
    [lStatusText release];
    lStatusText = nil;
    
    [aivWorking release];
    aivWorking = nil;
    
    [super dealloc];
}

/*
 *  Lay out the content in this view.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    CGSize szBounds = self.bounds.size;
    
    // - now by figure out how big the text will be.
    CGSize szTarget        = lStatusText.intrinsicContentSize;
    CGFloat activityHeight = CGRectGetHeight(aivWorking.bounds);
    lStatusText.frame = CGRectIntegral(CGRectMake((szBounds.width - (szTarget.width + CGRectGetWidth(aivWorking.bounds)))/2.0f,
                                                  szTarget.height > activityHeight ? 0.0f : (activityHeight - szTarget.height)/2.0f,
                                                  szTarget.width, szTarget.height));
    CGFloat statusOffset = lStatusText.font.lineHeight + lStatusText.font.descender;
    aivWorking.frame     = CGRectIntegral(CGRectMake(CGRectGetMaxX(lStatusText.frame) + UISSTS_STD_PAD,
                                                     MAX(statusOffset - CGRectGetHeight(aivWorking.frame) + 4.0f, 0.0f),
                                                     CGRectGetWidth(aivWorking.frame), CGRectGetHeight(aivWorking.frame)));
}

/*
 *  Return the size of the content in this view.
 */
-(CGSize) intrinsicContentSize
{
    [lStatusText sizeToFit];
    [aivWorking sizeToFit];
    CGSize szRet = CGSizeMake(ceilf((float)(CGRectGetWidth(lStatusText.bounds) + UISSTS_STD_PAD + CGRectGetWidth(aivWorking.bounds))),
                              ceilf((float)(MAX(CGRectGetHeight(lStatusText.bounds), CGRectGetHeight(aivWorking.bounds)))));
    return szRet;
}

/*
 *  Assign the transfer status text and animate the change, if necessary.
 */
-(void) setTransferStatus:(NSString *) status withAnimation:(BOOL) animated
{
    // - update the text.
    if (animated) {
        if (lStatusText.text) {
            UIView *vwSnap = [lStatusText snapshotViewAfterScreenUpdates:YES];
            vwSnap.frame   = lStatusText.frame;
            [self addSubview:vwSnap];
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                vwSnap.alpha = 0.0f;
            }completion:^(BOOL finished) {
                [vwSnap removeFromSuperview];
            }];
            lStatusText.text = status;
            [self invalidateIntrinsicContentSize];
        }
        else {
            lStatusText.alpha = 0.0f;
            lStatusText.text  = status;
            [UIView performWithoutAnimation:^(void) {
                [self setNeedsLayout];
                [self layoutIfNeeded];
            }];
            [self invalidateIntrinsicContentSize];
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                lStatusText.alpha = 1.0f;
            }];
        }
    }
    else {
        lStatusText.text = status;
        [self invalidateIntrinsicContentSize];
    }
    
    // - start/stop the spinner.
    if (status) {
        [aivWorking startAnimating];
    }
    else {
        [aivWorking stopAnimating];
    }
}

/*
 *  Update dynamic type in this view.
 */
-(void) updateDynamicTypeNotificationReceived
{
    [self reconfigureDynamicLabelsForInit:NO];
}

/*
 *  Set the preferred max layout width of this view.
 */
-(void) setPreferredMaxLayoutWidth:(CGFloat) maxLayoutWidth
{
    lStatusText.preferredMaxLayoutWidth = maxLayoutWidth - CGRectGetWidth(aivWorking.frame) - UISSTS_STD_PAD;
}

/*
 *  Return the preferred max layout width.
 */
-(CGFloat) preferredMaxLayoutWidth
{
    return lStatusText.preferredMaxLayoutWidth + CGRectGetWidth(aivWorking.frame) - UISSTS_STD_PAD;
}

@end

/****************************************
 UISealShareTransferStatusView (internal)
 ****************************************/
@implementation UISealShareTransferStatusView (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    self.clipsToBounds                             = YES;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor                           = [UIColor clearColor];
    
    lStatusText                                    = [[UILabel alloc] init];
    lStatusText.font                               = [UIFont systemFontOfSize:17.0f];
    lStatusText.textColor                          = [UIColor blackColor];
    lStatusText.textAlignment                      = NSTextAlignmentCenter;
    [self addSubview:lStatusText];
    
    aivWorking                                     = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    aivWorking.hidesWhenStopped                    = YES;
    [aivWorking sizeToFit];
    [self addSubview:aivWorking];
    
    // - set up dynamic type if necessary.
    [self reconfigureDynamicLabelsForInit:YES];
}

/*
 *  Reconfigure the labels for dynamic type.
 */
-(void) reconfigureDynamicLabelsForInit:(BOOL) isInit
{
    // - not supported under iOS7
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        return;
    }
    
    // - we need to be able to move to a second line if necessary.
    if (isInit) {
        lStatusText.numberOfLines = 0;
    }
    
    [UIAdvancedSelfSizingTools constrainTextLabel:lStatusText withPreferredSettingsAndTextStyle:UIFontTextStyleBody andMinimumSize:1.0f duringInitialization:isInit];
    [self invalidateIntrinsicContentSize];
}
@end
