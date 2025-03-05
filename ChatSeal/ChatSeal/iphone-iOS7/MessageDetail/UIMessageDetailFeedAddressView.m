//
//  UIMessageDetailFeedAddressView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 4/21/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIMessageDetailFeedAddressView.h"
#import "ChatSeal.h"
#import "UIAdvancedSelfSizingTools.h"

// - constants
static const CGFloat UIMDFA_STD_HEIGHT         = 40.0;
static const CGFloat UIMDFA_STD_BUTTON_SIDE    = CS_APP_STD_TOOL_SIDE;
static const CGFloat UIMDFA_STD_SIDE_PAD       = 15.0;
static const CGFloat UIMDFA_STD_INTER_ITEM_PAD = 8.0;

// - forward declarations
@interface UIMessageDetailFeedAddressView (internal)
-(void) commonConfiguration;
-(void) buttonPressed;
-(void) reconfigureDynamicLabelsDuringInit:(BOOL) isInit;
@end

/*******************************
 UIMessageDetailFeedAddressView
 *******************************/
@implementation UIMessageDetailFeedAddressView
/*
 *  Object attributes
 */
{
    UILabel  *lToLabel;
    UILabel  *lAddress;
    UIButton *btnUpload;
    UIView   *vwBorderContainer;
    UIView   *vwBorder;
}
@synthesize delegate;

/*
 *  Generate an upload button.
 */
+(UIButton *) standardUploadButton
{
    UIButton *btRet = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *img    = [UIImage imageNamed:@"732-cloud-upload.png"];
    img             = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [btRet setImage:img forState:UIControlStateNormal];
    btRet.bounds    = CGRectMake(0.0f, 0.0f, UIMDFA_STD_BUTTON_SIDE, UIMDFA_STD_BUTTON_SIDE);
    return btRet;
}

/*
 *  Return the distance of the padding on the sides of the address bar.
 */
+(CGFloat) standardSidePad
{
    return UIMDFA_STD_SIDE_PAD;
}

/*
 *  Return the standard address transform for the given label.
 */
+(CGAffineTransform) shearTransformForLabel:(UILabel *) l
{
    CGAffineTransform atShear    = CGAffineTransformMake(1.0, 0.0, 0.5f, 1.0, 0.0, 0.0);
    CGAffineTransform atComplete = CGAffineTransformConcat(CGAffineTransformMakeTranslation(-CGRectGetWidth(l.frame), 0.0f), atShear);
    return atComplete;
}

/*
 *  Object initialization.
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
    delegate = nil;
    
    [lToLabel release];
    lToLabel = nil;
    
    [lAddress release];
    lAddress = nil;
    
    [btnUpload release];
    btnUpload = nil;
    
    [vwBorder release];
    vwBorder = nil;
    
    [vwBorderContainer release];
    vwBorderContainer = nil;
    
    [super dealloc];
}

/*
 *  The feed address is a feed-specific name that describes the destination.
 */
-(void) setFeedAddressText:(NSString *) text withAnimation:(BOOL) animated
{
#if CHATSEAL_RUNNING_CONTRIVED_SCENARIO
    text = @"@BigDogWinston";
#endif
    // - always do an immediate layout.
    lAddress.text = text;
    [lAddress sizeToFit];
    [self setNeedsLayout];
    [self layoutIfNeeded];

    // - when we're animating, this is going to be based on reversing a simple
    //   transform.
    if (animated) {
        lAddress.alpha               = 0.0f;
        CGAffineTransform atComplete = [UIMessageDetailFeedAddressView shearTransformForLabel:lAddress];
        lAddress.transform           = atComplete;
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] * 1.25f animations:^(void) {
            lAddress.transform = CGAffineTransformIdentity;
            lAddress.alpha     = 1.0f;
        }];
    }
}

/*
 *  Compute the ideal size for this view.
 */
-(CGSize) sizeThatFits:(CGSize)size
{
    return CGSizeMake(size.width, UIMDFA_STD_HEIGHT);
}

/*
 *  Perform layout on the view.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    CGSize szMe = self.bounds.size;
    
    // - the only item we don't let size itself is the button since it must be approximately the size of the one
    //   in the standard address bar.
    btnUpload.frame           = CGRectIntegral(CGRectMake(szMe.width - UIMDFA_STD_SIDE_PAD - UIMDFA_STD_BUTTON_SIDE,
                                                          (szMe.height - UIMDFA_STD_BUTTON_SIDE)/2.0f,
                                                          UIMDFA_STD_BUTTON_SIDE, UIMDFA_STD_BUTTON_SIDE));
    
    [lToLabel sizeToFit];
    lToLabel.frame            = CGRectIntegral(CGRectMake(UIMDFA_STD_SIDE_PAD,
                                                          (szMe.height - CGRectGetHeight(lToLabel.bounds))/2.0f,
                                                          CGRectGetWidth(lToLabel.bounds), CGRectGetHeight(lToLabel.bounds)));
    
    [lAddress sizeToFit];
    CGFloat maxWidth          = CGRectGetMinX(btnUpload.frame) - UIMDFA_STD_INTER_ITEM_PAD - (CGRectGetMaxX(lToLabel.frame) + UIMDFA_STD_INTER_ITEM_PAD);
    lAddress.frame            = CGRectIntegral(CGRectMake(CGRectGetMaxX(lToLabel.frame) + UIMDFA_STD_INTER_ITEM_PAD,
                                                          CGRectGetMaxY(lToLabel.frame) - CGRectGetHeight(lAddress.bounds),
                                                          MIN(CGRectGetWidth(lAddress.bounds), maxWidth),
                                                          CGRectGetHeight(lAddress.bounds)));
    
    vwBorderContainer.frame   = CGRectMake(0.0f, szMe.height, szMe.width, 2.0f);
    vwBorder.frame            = CGRectMake(0.0f, 0.0f, szMe.width, 1.0f/[UIScreen mainScreen].scale);
}

/*
 *  The system is requesting a change to type.
 */
-(void) updateDynamicTypeNotificationReceived
{
    [self reconfigureDynamicLabelsDuringInit:NO];
}

@end

/*******************************************
 UIMessageDetailFeedAddressView (internal)
 *******************************************/
@implementation UIMessageDetailFeedAddressView (internal)
/*
 *  Initial configuration.
 */
-(void) commonConfiguration
{
    delegate = nil;
    
    self.backgroundColor = [ChatSeal defaultToolBackgroundColor];
    self.clipsToBounds   = NO;
    
    // - add the controls and visual elements.
    UIFont *fntLabels = [UIFont systemFontOfSize:14.0f];
    
    lToLabel           = [[UILabel alloc] init];
    lToLabel.font      = fntLabels;
    lToLabel.textColor = [UIColor colorWithWhite:0.55f alpha:1.0f];
    lToLabel.text      = NSLocalizedString(@"To:", nil);
    [self addSubview:lToLabel];
    
    lAddress               = [[UILabel alloc] init];
    lAddress.font          = fntLabels;
    lAddress.textColor     = [UIColor blackColor];
    lAddress.numberOfLines = 1;
    lAddress.lineBreakMode = NSLineBreakByTruncatingTail;
    [self addSubview:lAddress];
    
    btnUpload              = [[UIMessageDetailFeedAddressView standardUploadButton] retain];
    [btnUpload addTarget:self action:@selector(buttonPressed) forControlEvents:UIControlEventTouchUpInside];
    [btnUpload addTarget:self action:@selector(buttonPressed) forControlEvents:UIControlEventTouchUpOutside];
    [self addSubview:btnUpload];
    
    // ...to get that shadow looking just right, we need to have a clipping container.
    vwBorderContainer               = [[UIView alloc] init];
    vwBorderContainer.clipsToBounds = YES;
    [self addSubview:vwBorderContainer];
    
    vwBorder                     = [[UIView alloc] init];
    vwBorder.backgroundColor     = [UIColor colorWithWhite:0.78f alpha:1.0f];
    vwBorder.layer.shadowOpacity = 0.75f;
    vwBorder.layer.shadowOffset  = CGSizeMake(0.0f, 0.5f);
    vwBorder.layer.shadowRadius  = 1.0f;
    vwBorder.layer.shadowColor   = [[UIColor colorWithWhite:0.0f alpha:0.2f] CGColor];
    
    [vwBorderContainer addSubview:vwBorder];
    [self reconfigureDynamicLabelsDuringInit:YES];
}

/*
 *  The cloud button was pressed.
 */
-(void) buttonPressed
{
    if (delegate && [delegate respondsToSelector:@selector(feedAddressViewDidPressButton:)]) {
        [delegate performSelector:@selector(feedAddressViewDidPressButton:) withObject:self];
    }
}

/*
 *  Reconfigure the type in labels to be dynamic.
 */
-(void) reconfigureDynamicLabelsDuringInit:(BOOL) isInit
{
    // - this won't be useful before 8.0
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        return;
    }
    
    [UIAdvancedSelfSizingTools constrainTextLabel:lToLabel withPreferredSettingsAndTextStyle:UIFontTextStyleSubheadline duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextLabel:lAddress withPreferredSettingsAndTextStyle:UIFontTextStyleSubheadline duringInitialization:isInit];
    [self setNeedsLayout];
}
@end
