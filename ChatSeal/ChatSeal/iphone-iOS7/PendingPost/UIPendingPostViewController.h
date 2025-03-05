//
//  UIPendingPostViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 6/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIDynamicTypeCompliantEntity.h"
#import "UITableViewWithSizeableCells.h"

@class ChatSealPostedMessageProgress;
@class ChatSealFeed;
@interface UIPendingPostViewController : UIViewController <UIDynamicTypeCompliantEntity>
-(BOOL) prepareForPendingDisplayOfProgress:(ChatSealPostedMessageProgress *) prog inFeed:(ChatSealFeed *) feed withError:(NSError **) err;
@property (nonatomic, retain) IBOutlet UITableViewWithSizeableCells *tvDetail;
@end
