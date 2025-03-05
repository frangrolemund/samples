//
//  UITwitterFriendAdjustmentNavigationController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/24/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ChatSealFeedFriend;
@class CS_tfsFriendshipAdjustment;
@interface UITwitterFriendAdjustmentNavigationController : UINavigationController
+(UITwitterFriendAdjustmentNavigationController *) modalControllerForFriend:(ChatSealFeedFriend *) feedFriend forAdjustment:(CS_tfsFriendshipAdjustment *) adj;
@end
