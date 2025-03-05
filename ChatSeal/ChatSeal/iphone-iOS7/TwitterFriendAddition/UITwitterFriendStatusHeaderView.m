//
//  UITwitterFriendStatusHeaderView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/30/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UITwitterFriendStatusHeaderView.h"
#import "ChatSeal.h"
#import "UIAdvancedSelfSizingTools.h"

// - constants
static const CGFloat UITFSH_STD_TOP_PAD     = 16.0f;
static const CGFloat UITFSH_STD_BOT_PAD_PCT = 0.25f;
static const CGFloat UITFSH_STD_LEFT_PAD    = 16.0f;
static const CGFloat UITFSH_STD_MID_PAD     = 12.0f;
static const CGFloat UITFSH_STD_PAD         = 20.0f;

// - forward declarations
@interface UITwitterFriendStatusHeaderView (internal)
+(UILabel *) standardStatusLabel;
@end

/**************************************
 UITwitterFriendStatusHeaderView
 **************************************/
@implementation UITwitterFriendStatusHeaderView
/*
 *  Object attributes.
 */
{
    UILabel                 *lStatus;
    UIActivityIndicatorView *aivStatus;
}

/*
 *  We're only storing a limited amount of text here.
 */
+(CGFloat) headerHeight
{
    static CGFloat cachedHeight = -1.0f;
    if (cachedHeight < 0.0f) {
        UILabel *l     = [self standardStatusLabel];
        CGFloat height = l.font.lineHeight;
        
        UIActivityIndicatorView *aiv = [[[UIActivityIndicatorView alloc] init] autorelease];
        [aiv sizeToFit];
        
        height = MAX(height, CGRectGetHeight(aiv.frame));
        height += UITFSH_STD_TOP_PAD + (height * UITFSH_STD_BOT_PAD_PCT);
        
        // - don't cache the height when we use self-sizing.
        if ([ChatSeal isAdvancedSelfSizingInUse]) {
            return height;
        }
        cachedHeight = height;
    }
    
    return cachedHeight;
}

/*
 *  Initialize the header.
 */
-(id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        lStatus                    = [[UITwitterFriendStatusHeaderView standardStatusLabel] retain];
        lStatus.alpha              = 0.0f;
        [self addSubview:lStatus];
        aivStatus                  = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        aivStatus.hidesWhenStopped = YES;
        [self addSubview:aivStatus];
        [aivStatus sizeToFit];
    }
    return self;
}

/*
 *  Free the header.
 */
-(void) dealloc
{
    [lStatus release];
    lStatus = nil;
    
    [aivStatus release];
    aivStatus = nil;
    
    [super dealloc];
}

/*
 *  Perform layout.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];

    [lStatus sizeToFit];
    lStatus.frame    = CGRectIntegral(CGRectMake(UITFSH_STD_LEFT_PAD, UITFSH_STD_TOP_PAD,
                                      MIN(CGRectGetWidth(lStatus.bounds), CGRectGetWidth(self.bounds) - UITFSH_STD_PAD - CGRectGetWidth(aivStatus.frame) - UITFSH_STD_MID_PAD - UITFSH_STD_LEFT_PAD),
                                      CGRectGetHeight(self.bounds) - UITFSH_STD_TOP_PAD - (lStatus.font.lineHeight * UITFSH_STD_BOT_PAD_PCT)));
    
    aivStatus.center = CGPointMake(CGRectGetMaxX(lStatus.frame) + UITFSH_STD_MID_PAD + (CGRectGetWidth(aivStatus.bounds)/2.0f),
                                   CGRectGetMaxY(lStatus.frame) - (CGRectGetHeight(aivStatus.bounds)/2.0f));
}

/*
 *  Start the spinner animation.
 */
-(void) startAnimating
{
    [aivStatus startAnimating];
}

/*
 *  Stop the spinner animation.
 */
-(void) stopAnimating
{
    [aivStatus stopAnimating];
}

/*
 *  Change the text in the status field.
 */
-(void) setStatusText:(NSString *) text inColor:(UIColor *) c
{
    if (text) {
        lStatus.textColor = c;
        lStatus.text      = text;
        [self setNeedsLayout];
        [self layoutIfNeeded];
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            lStatus.alpha = 1.0f;
        }];
    }
    else {
        if (lStatus.text) {
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                lStatus.alpha = 0.0f;
            }completion:^(BOOL finished) {
                lStatus.text = nil;
            }];
        }
    }
}

@end

/*******************************************
 UITwitterFriendStatusHeaderView (internal)
 *******************************************/
@implementation UITwitterFriendStatusHeaderView (internal)

/*
 *  Return a label for displaying status.
 */
+(UILabel *) standardStatusLabel
{
    UILabel *lRet = [[[UILabel alloc] init] autorelease];
    lRet.font     = [UIFont systemFontOfSize:16.0f];
    [UIAdvancedSelfSizingTools constrainTextLabel:lRet withPreferredSettingsAndTextStyle:UIFontTextStyleSubheadline duringInitialization:YES];
    return lRet;
}
@end
