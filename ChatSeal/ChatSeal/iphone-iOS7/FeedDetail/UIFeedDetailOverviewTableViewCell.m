//
//  UIFeedDetailOverviewTableViewCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/20/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIFeedDetailOverviewTableViewCell.h"
#import "UIFormattedFeedAddressView.h"
#import "ChatSeal.h"
#import "ChatSealFeedCollector.h"
#import "AlertManager.h"

// - forward declarations
@interface UIFeedDetailOverviewTableViewCell (internal)
-(void) commonConfiguration;
-(void) discardAddress;
@end

/*********************************
 UIFeedDetailOverviewTableViewCell
 *********************************/
@implementation UIFeedDetailOverviewTableViewCell
/*
 *  Object attributes.
 */
{
    ChatSealFeed               *activeFeed;
    UIFormattedFeedAddressView *fav;
}
@synthesize vwFeedAddressContainer;
@synthesize swEnable;

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
    [vwFeedAddressContainer release];
    vwFeedAddressContainer = nil;
    
    [swEnable release];
    swEnable = nil;
    
    [self discardAddress];
    
    [activeFeed release];
    activeFeed = nil;
    
    [super dealloc];
}

/*
 *  Prepare to reuse this cell.
 */
-(void) prepareForReuse
{
    [self discardAddress];
}

/*
 *  Reconfigure the cell content.
 */
-(void) reconfigureCellWithFeed:(ChatSealFeed *) feed withAnimation:(BOOL) animated
{
    // - save off the feed as necessary.
    if (feed != activeFeed) {
        [self discardAddress];
        [activeFeed release];
        activeFeed = [feed retain];
    }
    
    // - don't bother if the main content is unchanged
    if (activeFeed.isEnabled == swEnable.on && fav) {
        return;
    }
        
    // - animate if necessary.
    if (animated) {
        UIView *vwSnap                = [self resizableSnapshotViewFromRect:self.contentView.frame afterScreenUpdates:NO withCapInsets:UIEdgeInsetsZero];
        vwSnap.userInteractionEnabled = NO;
        [self.contentView addSubview:vwSnap];
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            vwSnap.alpha = 0.0f;
        } completion:^(BOOL finished) {
            [vwSnap removeFromSuperview];
        }];
    }
    
    // - when we don't yet have an address, configure that once.
    if (!fav) {
        vwFeedAddressContainer.backgroundColor = [UIColor clearColor];
        fav = [[activeFeed addressView] retain];
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
    }
    
    // - set up the text colors and assign the active text.
    swEnable.enabled = [activeFeed isValid] && ![activeFeed isDeleted];
    [swEnable setOn:activeFeed.isEnabled && [activeFeed isValid] animated:NO];
    if (![activeFeed isEnabled] && [activeFeed isValid]) {
        [fav setTextColor:[UIColor lightGrayColor]];
    }
    else {
        [fav setTextColor:[UIColor blackColor]];
    }
}

/*
 *  The enablement switch was changed.
 */
-(IBAction)doSwitchEnable:(id)sender
{
    UISwitch *enableSwitch = (UISwitch *) sender;
    if (!activeFeed || activeFeed.isEnabled == enableSwitch.on) {
        return;
    }
    
    NSError *err = nil;
    BOOL wantValue = enableSwitch.on;
    if (![activeFeed setEnabled:wantValue withError:&err]) {
        [enableSwitch setOn:!wantValue animated:YES];
        NSString *sDesc = nil;
        if (wantValue) {
            sDesc = NSLocalizedString(@"A failure occurred while enabling your feed.", nil);
        }
        else {
            sDesc = NSLocalizedString(@"A failure occurred while disabling your feed.", nil);
        }
        [AlertManager displayFatalAlertWithLowSpaceDetectionUsingTitle:NSLocalizedString(@"Unable to Modify Feed", nil) andText:sDesc];
        return;
    }
}

/*
 *  When necessary, reconfigure the labels to use proper dynamic type sizes.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL) isInit
{
    [fav updateDynamicTypeNotificationReceived];
}

@end

/********************************************
 UIFeedDetailOverviewTableViewCell (internal)
 ********************************************/
@implementation UIFeedDetailOverviewTableViewCell (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    activeFeed = nil;
}

/*
 *  Remove the current address.
 */
-(void) discardAddress
{
    [fav removeFromSuperview];
    [fav release];
    fav = nil;
}
@end