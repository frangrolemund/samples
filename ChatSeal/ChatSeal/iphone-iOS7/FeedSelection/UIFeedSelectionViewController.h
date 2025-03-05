//
//  UIFeedSelectionViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 4/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIDynamicTypeCompliantEntity.h"
#import "UITableViewWithSizeableCells.h"

@class ChatSealFeed;
typedef void (^feedSelectionCompleted)(ChatSealFeed *feed);

@interface UIFeedSelectionViewController : UIViewController <UIDynamicTypeCompliantEntity>
+(UIViewController *) viewControllerWithActiveFeed:(ChatSealFeed *) activeFeed andSelectionCompletionBlock:(feedSelectionCompleted) completionBlock;

-(IBAction)doCancel:(id)sender;

@property (nonatomic, retain) IBOutlet UITableViewWithSizeableCells *tvFeeds;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *bbiCancel;
@property (nonatomic, retain) IBOutlet UIView *vwNoFeedsOverlay;
@property (nonatomic, retain) IBOutlet UILabel *lNoFeedsTitle;
@property (nonatomic, retain) IBOutlet UILabel *lNoFeedsDescription;
@end
