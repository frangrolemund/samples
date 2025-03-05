//
//  UIFeedOverviewTableViewCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/3/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIFeedsOverviewTableViewCell.h"
#import "ChatSealFeedCollector.h"
#import "UIFormattedFeedAddressView.h"
#import "ChatSeal.h"
#import "UIFeedsOverviewPlaceholder.h"

// - forward declarations
@interface UIFeedsOverviewTableViewCell (internal)
-(void) commonConfiguration;
-(void) reconfigureExchangeCountForFeed:(ChatSealFeed *) feed;
@end

/*******************************
 UIFeedOverviewTableViewCell
 *******************************/
@implementation UIFeedsOverviewTableViewCell
/*
 *  Object attributes.
 */
{
    UIFormattedFeedAddressView *fav;
    BOOL                       isBeingAnimated;
    BOOL                       lastDisplayWasActiveProgress;
}
@synthesize vwFeedAddressContainer;
@synthesize lExchangeCount;
@synthesize lStatus;
@synthesize pvProgress;

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
 *  This object was just loaded.
 */
-(void) awakeFromNib
{
    // - under 8.0, we're going to change our approach slightly for how we size the status line because it
    //   might become multi-line due to the self-sizing.
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        // - NOTE: this won't work under 7.1 because the automatic preferred width is not available.
        // - ALSO: this has to be done here before the layout engine begins thinking about how to size the
        //         heights, which means we need to grab item before its content contributes to
        //         the first display of the table view and its self-sizing analysis.
        self.lStatus.numberOfLines = 0;
        self.lExchangeCount.numberOfLines = 0;
    }
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [vwFeedAddressContainer release];
    vwFeedAddressContainer = nil;
    
    [lExchangeCount release];
    lExchangeCount = nil;
    
    [lStatus release];
    lStatus = nil;
    
    [pvProgress release];
    pvProgress = nil;
    
    [super dealloc];
}

/*
 *  Get ready to reuse the cell.
 */
-(void) prepareForReuse
{
    [fav removeFromSuperview];
    [fav release];
    fav = nil;
}

/*
 *  Reconfigure the cell using the specified feed.
 */
-(void) reconfigureCellWithFeed:(ChatSealFeed *) feed withAnimation:(BOOL) animated
{
    if (!feed) {
        return;
    }
    
    // - get the active progress on the feed so that we can figure out whether to reflect it.
    ChatSealFeedProgress *prog = [feed currentFeedProgress];
    
    // - the animation is special in this cell and isn't something that often needs explicit animation control because
    //   of how these different fields are used.
    // - therefore, we compute when animation is probably a good idea.
    BOOL newIsEnabled    = [feed isEnabled];
    NSString *sNewStatus = nil;
    BOOL feedIsOk        = NO;
    BOOL hasReqdWork     = NO;
    if (!newIsEnabled && !prog.isPostingComplete) {
        hasReqdWork = YES;
        if ([feed isDeleted]) {
            sNewStatus  = NSLocalizedString(@"Feed is deleted with pending posts.", nil);
        }
        else {
            sNewStatus  = NSLocalizedString(@"Feed is off with pending posts.", nil);
        }
    }
    else {
        sNewStatus = [feed statusText];
    }
    if (!sNewStatus) {
        feedIsOk   = YES;
        if (!prog.isComplete) {
            BOOL bPosting  = ![prog isPostingComplete];
            BOOL bScanning = ![prog isScanComplete];
            if (bPosting && bScanning) {
                NSString *sFmt = NSLocalizedString(@"%d%% posted, %d%% scanned", nil);
                sNewStatus     = [NSString stringWithFormat:sFmt, (int) (prog.postingProgress * 100.0), (int) (prog.scanProgress * 100.0)];
            }
            else if (bPosting) {
                NSString *sFmt = NSLocalizedString(@"%d%% posted", nil);
                sNewStatus     = [NSString stringWithFormat:sFmt, (int) (prog.postingProgress * 100.0)];
            }
            else {
                NSString *sFmt = NSLocalizedString(@"%d%% scanned", nil);
                sNewStatus     = [NSString stringWithFormat:sFmt, (int) (prog.scanProgress * 100.0)];
            }
        }
        else {
            // - in the prior releases where the cell height was fixed, we want the exchange count to still
            //   exist next to the address.
            if (![ChatSeal isAdvancedSelfSizingInUse]) {
                sNewStatus = @" ";
            }
        }
    }   
    
    BOOL curDisplayIsActiveProgress = (feedIsOk && !prog.isComplete);
    
    // - when we're just changing the progress, we won't do animations because fading doesn't make
    //   sense.
    if (curDisplayIsActiveProgress && lastDisplayWasActiveProgress) {
        animated = NO;
    }
    
    // - apply animation when necessary.
    if (animated && !isBeingAnimated) {
        UIView *vwSnap                = [self snapshotViewAfterScreenUpdates:YES];
        vwSnap.userInteractionEnabled = NO;
        [self addSubview:vwSnap];
        isBeingAnimated = YES;
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            vwSnap.alpha = 0.0f;
        } completion:^(BOOL finished) {
            [vwSnap removeFromSuperview];
            isBeingAnimated = NO;
        }];
    }
    
    // - and the exchange count
    [self reconfigureExchangeCountForFeed:feed];
    
    // - and the status.
    lStatus.text = sNewStatus;
    if (![feed isInWarningState]) {
        lStatus.textColor = [UIColor darkGrayColor];
    }
    else {
        if (newIsEnabled || hasReqdWork) {
            lStatus.textColor = [ChatSeal defaultWarningColor];
        }
        else {
            lStatus.textColor = [UIColor lightGrayColor];
        }
    }
    
    // - and the progress.
    if (prog.isComplete || !newIsEnabled) {
        pvProgress.hidden = YES;
    }
    else {
        pvProgress.hidden = NO;
        [pvProgress setProgress:(float) prog.overallProgress animated:lastDisplayWasActiveProgress ? animated : NO];
    }
    
    // - when we don't yet have an address, configure that once.
    if (!fav) {
        fav = [[feed addressView] retain];
        [fav setAddressFontHeight:[ChatSealFeed standardFontHeightForSelection]];
        fav.translatesAutoresizingMaskIntoConstraints = NO;
        [vwFeedAddressContainer addSubview:fav];
        NSLayoutConstraint *lc = [NSLayoutConstraint constraintWithItem:fav attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:vwFeedAddressContainer attribute:NSLayoutAttributeTop multiplier:1.0f constant:0.0f];
        [vwFeedAddressContainer addConstraint:lc];
        lc = [NSLayoutConstraint constraintWithItem:fav attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:vwFeedAddressContainer attribute:NSLayoutAttributeBottom multiplier:1.0f constant:0.0f];
        [vwFeedAddressContainer addConstraint:lc];
        lc = [NSLayoutConstraint constraintWithItem:fav attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:vwFeedAddressContainer attribute:NSLayoutAttributeLeft multiplier:1.0f constant:0.0f];
        [vwFeedAddressContainer addConstraint:lc];
        lc = [NSLayoutConstraint constraintWithItem:fav attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:vwFeedAddressContainer attribute:NSLayoutAttributeRight multiplier:1.0f constant:0.0f];
        [vwFeedAddressContainer addConstraint:lc];
        
        // - make sure that the two captions are lined up with the address.
        NSLayoutConstraint *constraintIndent = [NSLayoutConstraint constraintWithItem:self.lExchangeCount attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:fav.addressLabel attribute:NSLayoutAttributeLeft multiplier:1.0f constant:0.0f];
        [self.contentView addConstraint:constraintIndent];
        [self updateConstraintsIfNeeded];
        [self layoutIfNeeded];
    }
    
    // - configure the address colors.
    vwFeedAddressContainer.backgroundColor = [UIColor clearColor];
    [fav setTextColor:newIsEnabled ? [UIColor blackColor] : [UIColor lightGrayColor]];

    // - update the last state.
    lastDisplayWasActiveProgress = curDisplayIsActiveProgress;
}

/*
 *  This method will draw a simple version of this cell that can be used for displaying a vault failure overlay.
 */
-(void) drawStylizedVersionWithPlaceholder:(UIFeedsOverviewPlaceholder *) ph
{
    CGFloat scale  = [UIScreen mainScreen].scale;
    CGSize  szView = self.bounds.size;
    
    // - we only bother drawing content if there is a placeholder, otherwise,
    //   we'll just draw the divider.
    if (ph) {
        // - fill the content so that we can get some measurements.
        NSMutableString *owner = nil;
        if (ph.lenName) {
            NSUInteger len = ph.lenName;
            owner  = [NSMutableString stringWithCapacity:len];
            for (int i = 0; i < len; i++) {
                [owner appendString:@"X"];
            }
        }
        
        NSMutableString *exchanged = nil;
        if (ph.lenExchanged) {
            NSUInteger len = ph.lenExchanged + ([@" messages exchanged." length]);
            exchanged      = [NSMutableString stringWithCapacity:len];
            for (int i = 0; i < len; i++) {
                [exchanged appendString:@"X"];
            }
        }

        // - we're just going to approximate this because the layout is pretty simplistic.
        [[UIColor colorWithRed:79.0f/255.0f green:136.0f/255.0f blue:176.0f/255.0f alpha:1.0f] setFill];  //  add a little color to it to imply a feed type (darker Twitter color)
        CGRect rcBadge = CGRectMake(8.0f, 8.0f, szView.height / 3.0f, szView.height / 3.0f);
        CGContextFillEllipseInRect(UIGraphicsGetCurrentContext(), rcBadge);
        
       [[UIColor colorWithWhite:0.2f alpha:1.0f] setFill]; 
        UILabel *l       = [[UILabel alloc] init];
        
        // ...draw the feed name.
        l.font           = [UIFont systemFontOfSize:[ChatSealFeed standardFontHeightForSelection]];
        l.text           = owner;
        [l sizeToFit];
        CGSize sz        = l.bounds.size;
        CGFloat maxWidth = szView.width - CGRectGetMaxX(rcBadge) - 16.0f;
        if (sz.width > maxWidth) {
            sz.width = maxWidth;
        }
        CGRect rcText = CGRectMake(CGRectGetMaxX(rcBadge) + 8.0f, CGRectGetMinY(rcBadge) + 4.0f, sz.width, sz.height);
        UIRectFill(rcText);
        
        // ...and the exchange count.
        [[UIColor darkGrayColor] setFill];
        l.font          = [UIFont systemFontOfSize:19.0f];
        l.text          = exchanged;
        [l sizeToFit];
        sz = l.bounds.size;
        CGFloat minY     = CGRectGetMinY(rcBadge) + 40.0f;
        maxWidth = szView.width - minY - 16.0f;
        if (sz.width > maxWidth) {
            sz.width = maxWidth;
        }
        UIRectFill(CGRectMake(minY, MAX(CGRectGetMaxY(rcText), CGRectGetMaxY(rcBadge)) + 8.0f, sz.width, sz.height));
                
        [l release];
    }
    
    // - the bottom divider is always drawn.
    [[UIColor blackColor] setStroke];
    CGContextSetLineWidth(UIGraphicsGetCurrentContext(), scale);
    CGContextBeginPath(UIGraphicsGetCurrentContext());
    CGContextMoveToPoint(UIGraphicsGetCurrentContext(), 0.0f, szView.height);
    CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), szView.width, szView.height);
    CGContextStrokePath(UIGraphicsGetCurrentContext());
}

/*
 *  Adjust the content in the cell to support dynamic type.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL)isInit
{
    [fav updateDynamicTypeNotificationReceived];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lExchangeCount withPreferredSettingsAndTextStyle:UIFontTextStyleSubheadline duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lStatus withPreferredSettingsAndTextStyle:UIFontTextStyleCaption2 duringInitialization:isInit];
}
@end

/**************************************
 UIFeedOverviewTableViewCell (internal)
 **************************************/
@implementation UIFeedsOverviewTableViewCell (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    fav                          = nil;
    isBeingAnimated              = NO;
    lastDisplayWasActiveProgress = NO;
}

/*
 *  The exchange count is an attributed string, so figure out the best option for displaying it
 *  here.
 */
-(void) reconfigureExchangeCountForFeed:(ChatSealFeed *) feed
{
    UIColor             *cText     = nil;
    if ([feed isEnabled]) {
        cText  = [UIColor darkGrayColor];
    }
    else {
        cText  = [UIColor lightGrayColor];
    }
    
    NSString *sFullString = [feed localizedMessagesExchangedText];
    
    // - create the basic string.
    NSMutableAttributedString *mas = [[[NSMutableAttributedString alloc] initWithString:sFullString] autorelease];
    
    // - now assign the attributes.
    [mas beginEditing];
    NSMutableDictionary *mdAttrib = [NSMutableDictionary dictionary];
    [mdAttrib setObject:self.lExchangeCount.font forKey:NSFontAttributeName];
    [mdAttrib setObject:cText forKey:NSForegroundColorAttributeName];
    [mas setAttributes:mdAttrib range:NSMakeRange(0, [sFullString length])];
    [mas endEditing];
    lExchangeCount.attributedText = mas;
}
@end
