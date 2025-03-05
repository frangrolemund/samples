//
//  UIFeedsOverviewAuthView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/3/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIFeedsOverviewAuthView.h"
#import "UIFeedAccessViewController.h"
#import "ChatSeal.h"
#import "UIAdvancedSelfSizingTools.h"

static NSInteger UIFOAV_TAG_AUTH_TITLE  = 101;
static NSInteger UIFOAV_TAG_AUTH_DESC   = 102;
static NSInteger UIFOAV_TAG_AUTH_BUTTON = 103;
static NSInteger UIFOAV_TAG_DENY_TITLE  = 201;
static NSInteger UIFOAV_TAG_DENY_DESC   = 202;

// - forward declarations
@interface UIFeedsOverviewAuthView (internal)
-(void) commonConfiguration;
-(void) setDenyTextForState:(ps_feeds_overview_auth_state_t) state;
-(void) reconfigureSelfSizingItemsAsInit:(BOOL) isInit;
@end

/****************************
 UIFeedsOverviewAuthView
 ****************************/
@implementation UIFeedsOverviewAuthView
/*
 *  Object attributes
 */
{
    UIView                         *vwAuthorize;
    UIView                         *vwDeny;
    ps_feeds_overview_auth_state_t curDisplayState;
}

/*
 *  Return the standard warning text for a 'no feeds' warning.
 */
+(NSString *) warningTextForNoFeedsInHeader:(BOOL) isHeader
{
    if (isHeader) {
        return NSLocalizedString(@"No Feeds", nil);
    }
    else {
        return NSLocalizedString(@"Add a new Twitter account in Settings to exchange personal messages.", nil);
    }
}

/*
 *  Return the standard warning text for a 'no auth' warning.
 */
+(NSString *) warningTextForNoAuthInHeader:(BOOL) isHeader
{
    if (isHeader) {
        return NSLocalizedString(@"Permission Required", nil);
    }
    else {
        return NSLocalizedString(@"Allow ChatSeal to use your Twitter accounts in Settings to exchange personal messages.", nil);
    }
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
    [vwAuthorize release];
    vwAuthorize = nil;
    
    [vwDeny release];
    vwDeny = nil;
    
    [super dealloc];
}

/*
 *  Display the authorization view.
 */
-(void) setAuthorizationDisplayState:(ps_feeds_overview_auth_state_t) aState andAnimation:(BOOL) animated
{
    if (aState == curDisplayState) {
        return;
    }
    
    if (aState == CS_FOAS_HIDDEN) {
        // - we are going to hide the full display.
        if (animated) {
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                self.alpha = 0.0f;
            }completion:^(BOOL finished) {
                self.hidden = YES;
            }];
        }
        else {
            self.alpha  = 0.0f;
            self.hidden = YES;
        }
    }
    else {
        // - the question is whether we're animating a change from hidden to visible or
        //   between sub-states.
        
        // - first see if we need to animate a change from one to the next.
        if (curDisplayState != CS_FOAS_HIDDEN && animated) {
            UIView *vwSnap                = [self snapshotViewAfterScreenUpdates:YES];
            vwSnap.userInteractionEnabled = NO;
            [self addSubview:vwSnap];
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                vwSnap.alpha = 0.0f;
            }completion:^(BOOL finished) {
                [vwSnap removeFromSuperview];
            }];
        }
        
        // - set the text on the labels
        [self setDenyTextForState:aState];
        
        // - show the appropriate sub-dialog
        vwAuthorize.alpha = (aState == CS_FOAS_REQUEST) ? 1.0f : 0.0f;
        vwDeny.alpha      = (aState == CS_FOAS_NOAUTH || aState == CS_FOAS_NOFEEDS) ? 1.0f : 0.0f;
        
        // - we may need to fade-in the full view.
        if (curDisplayState == CS_FOAS_HIDDEN) {
            if (animated) {
                self.alpha  = 0.0f;
                self.hidden = NO;
                [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                    self.alpha = 1.0f;
                }];
            }
            else {
                self.alpha = 1.0f;
                self.hidden = NO;
            }
        }
    }
    
    curDisplayState = aState;
}

/*
 *  Disable the authorization button so it can no longer be used.
 */
-(void) disableAuthorizationButton
{
    [(UIButton *) [vwAuthorize viewWithTag:103] setEnabled:NO];
}

/*
 *  The caller will issue this from time to time to make sure the prefererd text widths are 
 *  kept synchronized with their dimensions.
 */
-(void) updatePreferredTextWidths
{
    // - make sure that the auth-sub-views are updated.
    [vwAuthorize layoutIfNeeded];
    [vwDeny layoutIfNeeded];
    
    // - now make sure that the text items have accurate preferreed widths.
    int textItems[] = {101, 102, 201, 202};
    BOOL doLayout   = NO;
    for (int i = 0; i < sizeof(textItems)/sizeof(textItems[0]); i++) {
        NSObject *obj = [self viewWithTag:textItems[i]];
        if ([obj isKindOfClass:[UILabel class]]) {
            UILabel *l = (UILabel *) obj;
            CGFloat width = CGRectGetWidth(l.bounds);
            if ((int) width != (int) l.preferredMaxLayoutWidth) {
                doLayout                  = YES;
                l.preferredMaxLayoutWidth = width;
                [l setNeedsLayout];
            }
        }
    }
    
    // - make sure everything is laid out again with the new preferred widths.
    if (doLayout) {
        [self setNeedsLayout];
        [self.superview layoutIfNeeded];
    }
}

/*
 *  A dynamic type update has occurred.
 */
-(void) updateDynamicTypeNotificationReceived
{
    [self reconfigureSelfSizingItemsAsInit:NO];
}
@end

/***********************************
 UIFeedsOverviewAuthView (internal)
 ***********************************/
@implementation UIFeedsOverviewAuthView (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    // - get handles to the two primary views so that they're easily accessed later.
    vwAuthorize = [[self viewWithTag:100] retain];
    vwDeny      = [[self viewWithTag:200] retain];
    
    // - the NIB has this hidden by default and we'll just reinforce that idea
    //   here.
    curDisplayState = CS_FOAS_HIDDEN;
    self.backgroundColor = [UIColor whiteColor];
    self.hidden          = YES;
    self.alpha           = 0.0f;
    
    // - set up the text that doesn't change, which for now is the Twitter access text.
    [self reconfigureSelfSizingItemsAsInit:YES];
    UILabel *l = (UILabel *) [vwAuthorize viewWithTag:UIFOAV_TAG_AUTH_TITLE];
    l.text     = [UIFeedAccessViewController feedAccessTitle];
    l          = (UILabel *) [vwAuthorize viewWithTag:UIFOAV_TAG_AUTH_DESC];
    l.text     = [UIFeedAccessViewController feedAccessDescription];
}

/*
 *  Assign the specific deny text in this view for the given state.
 */
-(void) setDenyTextForState:(ps_feeds_overview_auth_state_t) state
{
    UILabel *lTitle = (UILabel *) [vwDeny viewWithTag:UIFOAV_TAG_DENY_TITLE];
    UILabel *lDesc  = (UILabel *) [vwDeny viewWithTag:UIFOAV_TAG_DENY_DESC];
    if (state == CS_FOAS_NOAUTH) {
        lTitle.text = [UIFeedsOverviewAuthView warningTextForNoAuthInHeader:YES];
        lDesc.text  = [UIFeedsOverviewAuthView warningTextForNoAuthInHeader:NO];
    }
    else if (state == CS_FOAS_NOFEEDS) {
        lTitle.text = [UIFeedsOverviewAuthView warningTextForNoFeedsInHeader:YES];
        lDesc.text  = [UIFeedsOverviewAuthView warningTextForNoFeedsInHeader:NO];
    }
}

/*
 *  Reconfigure the dynamic type in the items in this view.
 */
-(void) reconfigureSelfSizingItemsAsInit:(BOOL) isInit
{
    // - not supported before v8.0
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        return;
    }    
    [UIAdvancedSelfSizingTools constrainAlertLabel:(UILabel *) [self viewWithTag:UIFOAV_TAG_AUTH_TITLE] asHeader:YES duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainAlertLabel:(UILabel *) [self viewWithTag:UIFOAV_TAG_AUTH_DESC] asHeader:NO duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainAlertButton:(UIButton *) [self viewWithTag:UIFOAV_TAG_AUTH_BUTTON] duringInitialization:isInit];
    
    [UIAdvancedSelfSizingTools constrainAlertLabel:(UILabel *) [self viewWithTag:UIFOAV_TAG_DENY_TITLE] asHeader:YES duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainAlertLabel:(UILabel *) [self viewWithTag:UIFOAV_TAG_DENY_DESC] asHeader:NO duringInitialization:isInit];
}
@end