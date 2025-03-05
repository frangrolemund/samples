//
//  tdriverLongTableViewController.h
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 5/21/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol tdriverLongTableViewControllerDelegate <NSObject>
-(void) doParentAction;
@end

@interface tdriverLongTableViewController : UITableViewController
@property (nonatomic, assign) id<tdriverLongTableViewControllerDelegate> delegate;
@end
