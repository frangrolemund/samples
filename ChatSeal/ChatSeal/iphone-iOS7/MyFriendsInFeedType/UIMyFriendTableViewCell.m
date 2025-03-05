//
//  UIMyFriendTableViewCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/15/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIMyFriendTableViewCell.h"
#import "ChatSeal.h"
#import "ChatSealFeedType.h"
#import "ChatSealFeedFriend.h"

// - forward declarations
@interface UIMyFriendTableViewCell (internal)
@end

/************************
 UIMyFriendTableViewCell
 ************************/
@implementation UIMyFriendTableViewCell
/*
 *  Object attributes.
 */
{
    
}
@synthesize ivFriendProfile;
@synthesize lFriendName;
@synthesize lConnectionStatus;
@synthesize lTrusted;

/*
 *  Return a border color to put around the profile.
 */
+(void) setBorderOnProfile:(UIImageView *) ivProfile
{
    ivProfile.layer.borderColor = [[UIColor colorWithWhite:0.85f alpha:1.0f] CGColor];
    ivProfile.layer.borderWidth = 1.0f/[UIScreen mainScreen].scale;
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [ivFriendProfile release];
    ivFriendProfile = nil;
    
    [lFriendName release];
    lFriendName = nil;
    
    [lConnectionStatus release];
    lConnectionStatus = nil;
    
    [lTrusted release];
    lTrusted = nil;
    
    [super dealloc];
}

/*
 *  Perform layout.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat width = CGRectGetWidth(lConnectionStatus.frame);
    if ((int) lConnectionStatus.preferredMaxLayoutWidth != (int) width) {
        lConnectionStatus.preferredMaxLayoutWidth = width;
        [lConnectionStatus invalidateIntrinsicContentSize];
    }
}

/*
 *  Configure this cell.
 */
-(void) configureWithFriend:(ChatSealFeedFriend *) feedFriend andAnimation:(BOOL) animated
{
    // - cleaner fade-in.
    if (animated && self.superview) {
        UIView *vwSnap = [self resizableSnapshotViewFromRect:self.contentView.frame afterScreenUpdates:YES withCapInsets:UIEdgeInsetsZero];
        vwSnap.userInteractionEnabled = NO;
        [self.contentView addSubview:vwSnap];
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            vwSnap.alpha = 0.0f;
        }completion:^(BOOL finished) {
            [vwSnap removeFromSuperview];
        }];
    }
    
    // - assign the content
    self.lFriendName.text = [feedFriend friendNameOrDescription];
    if (feedFriend.isDeleted) {
        self.lFriendName.textColor       = [UIColor darkGrayColor];
        self.lConnectionStatus.text      = [ChatSealFeedFriend standardAccountDeletionText];
        self.lConnectionStatus.textColor = [UIColor lightGrayColor];
        self.ivFriendProfile.image       = [feedFriend.feedType friendDefaultProfileImage];
        self.accessoryType               = UITableViewCellAccessoryNone;
    }
    else {
        if (feedFriend.isBroken) {
            self.lConnectionStatus.textColor = [ChatSeal defaultWarningColor];
        }
        else {
            self.lConnectionStatus.textColor = [UIColor lightGrayColor];
        }
        
        self.lFriendName.textColor  = [UIColor blackColor];
        self.lConnectionStatus.text = feedFriend.friendDetailDescription ? feedFriend.friendDetailDescription : NSLocalizedString(@"Connections are strong.", nil);
        
        if (feedFriend.profileImage) {
            self.ivFriendProfile.image = feedFriend.profileImage;
        }
        else {
            // - don't change to the default image if we had something a moment ago for this friend because
            //   that feels like a regression, visually, even though it is technically correct.  This is only
            //   intended when we're actively looking at the friend list, not as a permanent solution to showing
            //   the friend's badge because generally-speaking, correctness is more important.
            if (!self.ivFriendProfile.image) {
                self.ivFriendProfile.image = [feedFriend.feedType friendDefaultProfileImage];
            }
        }
        self.accessoryType = feedFriend.isIdentified ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    }
    
    self.ivFriendProfile.clipsToBounds      = YES;
    self.ivFriendProfile.layer.cornerRadius = 4.0f;
    self.lTrusted.text                      = feedFriend.isTrusted ? NSLocalizedString(@"TRUSTED", nil) : nil;
    self.lTrusted.hidden                    = !feedFriend.isTrusted;
    [UIMyFriendTableViewCell setBorderOnProfile:self.ivFriendProfile];
}

/*
 *  Prepare to reuse this cell
 */
-(void) prepareForReuse
{
    [super prepareForReuse];
    self.lFriendName.text       = nil;
    self.lConnectionStatus.text = nil;
    self.ivFriendProfile.image  = nil;
    self.lTrusted.hidden        = YES;
}

/*
 *  When necessary, reconfigure the labels to use proper dynamic type sizes.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL) isInit
{
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lFriendName withPreferredSettingsAndTextStyle:UIFontTextStyleSubheadline duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.lConnectionStatus withPreferredSettingsAndTextStyle:UIFontTextStyleCaption1 duringInitialization:isInit];
}

@end

/**********************************
 UIMyFriendTableViewCell (internal)
 **********************************/
@implementation UIMyFriendTableViewCell (internal)

@end
