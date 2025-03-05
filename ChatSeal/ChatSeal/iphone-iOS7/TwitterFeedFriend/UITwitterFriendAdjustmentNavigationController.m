//
//  UITwitterFriendAdjustmentNavigationController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/24/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UITwitterFriendAdjustmentNavigationController.h"
#import "UITwitterFriendAdjustmentViewController.h"
#import "ChatSeal.h"
#import "ChatSealFeedFriend.h"
#import "CS_tfsFriendshipAdjustment.h"

// - forward declarations
@interface UITwitterFriendAdjustmentNavigationController (internal)
-(void) setFeedFriend:(ChatSealFeedFriend *) ff andAdjustment:(CS_tfsFriendshipAdjustment *) adj;
@end

/**********************************************
 UITwitterFriendAdjustmentNavigationController
 **********************************************/
@implementation UITwitterFriendAdjustmentNavigationController
/*
 *  Object attributes.
 */
{
    ChatSealFeedFriend         *feedFriend;
    CS_tfsFriendshipAdjustment *friendAdjustment;
}

/*
 *  Instantiate a new navigation controller.
 */
+(UITwitterFriendAdjustmentNavigationController *) modalControllerForFriend:(ChatSealFeedFriend *) feedFriend forAdjustment:(CS_tfsFriendshipAdjustment *) adj
{
    UITwitterFriendAdjustmentNavigationController *tanc = (UITwitterFriendAdjustmentNavigationController *) [ChatSeal viewControllerForStoryboardId:@"UITwitterFriendAdjustmentNavigationController"];
    [tanc setFeedFriend:feedFriend andAdjustment:adj];
    return tanc;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [feedFriend release];
    feedFriend = nil;
    
    [friendAdjustment release];
    friendAdjustment = nil;
    
    [super dealloc];
}

/*
 *  The view was loaded.
 */
-(void) viewDidLoad
{
    [super viewDidLoad];
    
    // - take this opportunity to assign the friend/adjustment in the real view.
    UITwitterFriendAdjustmentViewController *tfc = (UITwitterFriendAdjustmentViewController *) self.topViewController;
    [tfc setFriend:feedFriend withAdjustment:friendAdjustment];
}
@end

/*********************************************************
 UITwitterFriendAdjustmentNavigationController (internal)
 *********************************************************/
@implementation UITwitterFriendAdjustmentNavigationController (internal)
/*
 *  Assign the feed friend and adjustment that will be assigned when the view is loaded.
 */
-(void) setFeedFriend:(ChatSealFeedFriend *) ff andAdjustment:(CS_tfsFriendshipAdjustment *) adj
{
    if (ff != feedFriend) {
        [feedFriend release];
        feedFriend = [ff retain];
    }
    
    if (adj != friendAdjustment) {
        [friendAdjustment release];
        friendAdjustment = [adj retain];
    }
}
@end
