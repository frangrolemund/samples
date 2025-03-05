//
//  UIFeedDetailViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 6/20/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UITableViewWithSizeableCells.h"

@class ChatSealFeed;
@interface UIFeedDetailViewController : UIViewController
-(void) setActiveFeed:(ChatSealFeed *) feed;
@property (nonatomic, retain) IBOutlet UITableViewWithSizeableCells *tvDetail;
@end
