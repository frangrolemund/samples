//
//  UITwitterFriendAddButtonTableViewCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/30/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UITwitterFriendAddButtonTableViewCell.h"
#import "ChatSeal.h"

// - constants
static const CGFloat UITFAB_STD_VPAD = 4.0f;

// - forward declarations
@interface UITwitterFriendAddButtonTableViewCell (internal)
-(void) buttonPressed;
@end

/**************************************
 UITwitterFriendAddButtonTableViewCell
 **************************************/
@implementation UITwitterFriendAddButtonTableViewCell
/*
 *  Object attributes.
 */
{
    UIButton *bAddFriend;
}
@synthesize delegate;

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        bAddFriend                      = [[UIButton buttonWithType:UIButtonTypeSystem] retain];
        bAddFriend.frame                = self.contentView.bounds;
        bAddFriend.autoresizingMask     = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        bAddFriend.titleLabel.font      = [UIFont systemFontOfSize:17];
        bAddFriend.titleLabel.textColor = [ChatSeal defaultAppTintColor];
        [bAddFriend setTitle:NSLocalizedString(@"Watch My Friend", nil) forState:UIControlStateNormal];
        [bAddFriend addTarget:self action:@selector(buttonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:bAddFriend];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    delegate = nil;
    [bAddFriend release];
    bAddFriend = nil;
    
    [super dealloc];
}

/*
 *  Enable/disable the button.
 */
-(void) setEnabled:(BOOL) enabled
{
    [bAddFriend setEnabled:enabled];
}

/*
 *  Return a size that fits the given size.
 */
-(CGSize) sizeThatFits:(CGSize)size
{
    // - force the dynnamic update to be triggered.
    [super sizeThatFits:size];
    
    // - now figure out how much space the button needs.
    CGSize szRet    = CGSizeMake(size.width, 1.0f);
    CGSize szButton = [bAddFriend sizeThatFits:szRet];
    szRet.height    = MAX(szRet.height, szButton.height);
    szRet.height    += (UITFAB_STD_VPAD * 2.0f);
    szRet.height    = MAX(szRet.height, [ChatSeal minimumTouchableDimension]);
    return szRet;
}
/*
 *  Don't automatically create the cell height constraint.
 */
-(BOOL) shouldCreateHeightConstraint
{
    return NO;
}

/*
 *  When necessary, reconfigure the labels to use proper dynamic type sizes.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL) isInit
{
    [UIAdvancedSelfSizingTools constrainTextButton:bAddFriend withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
}

@end

/**********************************************
 UITwitterFriendAddButtonTableViewCell (internal)
 **********************************************/
@implementation UITwitterFriendAddButtonTableViewCell (internal)
/*
 *  The button was pressed.
 */
-(void) buttonPressed
{
    if (delegate) {
        [delegate performSelector:@selector(twitterFriendAddButtonPressed:) withObject:self];
    }
}

@end
