//
//  UITwitterFriendTableViewCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/21/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UITwitterFriendTableViewCell.h"
#import "ChatSealFeedFriend.h"
#import "UIFormattedFeedAddressView.h"
#import "ChatSeal.h"
#import "ChatSealFeedType.h"
#import "UIMyFriendTableViewCell.h"
#import "UIAdvancedSelfSizingTools.h"

/*****************************
 UITwitterFriendTableViewCell
 *****************************/
@implementation UITwitterFriendTableViewCell
/*
 *  Object attributes.
 */
{
    uint16_t lastFriendVersion;
}
@synthesize ivProfile;
@synthesize lFullName;
@synthesize favAddress;
@synthesize lLocation;

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        lastFriendVersion         = 0;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [ivProfile release];
    ivProfile = nil;
    
    [lFullName release];
    lFullName = nil;
    
    [lLocation release];
    lLocation = nil;
    
    [favAddress release];
    favAddress = nil;
    
    [super dealloc];
}

/*
 *  Prepare this cell to be reused.
 */
-(void) prepareForReuse
{
    [super prepareForReuse];
    
    ivProfile.image = nil;
    lFullName.text  = nil;
}

/*
 *  One-time configuration.
 */
-(void) awakeFromNib
{
    [super awakeFromNib];
    self.ivProfile.backgroundColor     = [UIColor whiteColor];
    self.ivProfile.layer.masksToBounds = YES;
    self.ivProfile.layer.cornerRadius  = 6.0f;
    [UIMyFriendTableViewCell setBorderOnProfile:self.ivProfile];
    [self.favAddress setAddressFontHeight:[ChatSealFeed standardFontHeightForSelection]];
    
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        // - under 8.0 we can get the location to wrap automatically with this approach.
        self.lLocation.numberOfLines = 0;
    }
}

/*
 *  Reconfigure this object.
 */
-(void) reconfigureWithFriend:(ChatSealFeedFriend *) feedFriend andAnimation:(BOOL) animated
{
    // - handle the animation
    if (animated && (!ivProfile.image || lastFriendVersion != feedFriend.friendVersion)) {
        UIView *vwSnap                = [self resizableSnapshotViewFromRect:self.contentView.frame afterScreenUpdates:YES withCapInsets:UIEdgeInsetsZero];
        vwSnap.userInteractionEnabled = NO;
        [self.contentView addSubview:vwSnap];
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            vwSnap.alpha = 0.0f;
        }completion:^(BOOL finished) {
            [vwSnap removeFromSuperview];
        }];
    }
    lastFriendVersion = feedFriend.friendVersion;
 
    // - update the content.
    [self.favAddress setAddressText:feedFriend.userId];
    self.lFullName.text = feedFriend.isIdentified ? feedFriend.friendNameOrDescription : NSLocalizedString(@"Waiting for Identification", nil);
    if (feedFriend.isDeleted) {
        self.ivProfile.image = [feedFriend.feedType friendDefaultProfileImage];
        self.lFullName.textColor = [UIColor darkGrayColor];
        [self.favAddress setTextColor:[UIColor lightGrayColor]];
        self.lLocation.text      = [ChatSealFeedFriend standardAccountDeletionText];
        self.lLocation.textColor = [UIColor lightGrayColor];
    }
    else {
        if (feedFriend.profileImage) {
            self.ivProfile.image = feedFriend.profileImage;
        }
        else {
            // - don't change to the default image if we had something a moment ago for this friend because
            //   that feels like a regression, visually, even though it is technically correct.  This is only
            //   intended when we're actively looking at the friend list, not as a permanent solution to showing
            //   the friend's badge because generally-speaking, correctness is more important.
            if (!self.ivProfile.image) {
                self.ivProfile.image = [feedFriend.feedType friendDefaultProfileImage];
            }
        }
        [self.favAddress setTextColor:[UIColor darkGrayColor]];
        if (feedFriend.isIdentified) {
            self.lFullName.textColor = [UIColor blackColor];
            self.lLocation.text      = feedFriend.friendLocation;
        }
        else {
            self.lFullName.textColor = [UIColor darkGrayColor];
            self.lLocation.text      = nil;
        }
        self.lLocation.textColor = [UIColor darkGrayColor];
    }
}

/*
 *  Reconfigure the cells for dynamic type.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL)isInit
{
    [favAddress updateDynamicTypeNotificationReceived];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lFullName withPreferredSettingsAndTextStyle:UIFontTextStyleBody andSizeScale:[ChatSeal superDuperBodyFontScalingFactor] andMinimumSize:1.0f
                             duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lLocation withPreferredSettingsAndTextStyle:UIFontTextStyleCaption2 duringInitialization:isInit];
}

@end
