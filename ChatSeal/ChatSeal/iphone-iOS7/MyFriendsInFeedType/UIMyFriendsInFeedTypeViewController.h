//
//  UIMyFriendsInFeedTypeViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/15/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIDynamicTypeCompliantEntity.h"

@class ChatSealFeedType;
@interface UIMyFriendsInFeedTypeViewController : UIViewController <UIDynamicTypeCompliantEntity>
-(void) setFeedTypeToDisplay:(ChatSealFeedType *) ft;

@property (nonatomic, retain) IBOutlet UITableView *tvFriends;
@property (nonatomic, retain) IBOutlet UIView *vwNoFriends;
@property (nonatomic, retain) IBOutlet UILabel *lNoFriendsTitle;
@property (nonatomic, retain) IBOutlet UILabel *lNoFriendsDesc;
@end
