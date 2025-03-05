//
//  UIFeedsOverviewViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 6/3/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIHubViewController.h"
#import "UIVaultFailureOverlayView.h"
#import "UIFeedsOverviewAuthView.h"
#import "UIDynamicTypeCompliantEntity.h"
#import "UITableViewWithSizeableCells.h"

@interface UIFeedsOverviewViewController : UIViewController <UIHubManagedViewController, UIDynamicTypeCompliantEntity>
-(IBAction)doAuthorize:(id)sender;
-(IBAction)doAuthorizeSharing:(id)sender;
-(IBAction)doChangeSharingState:(id)sender;
@property (nonatomic, retain) IBOutlet UITableViewWithSizeableCells *tvFeeds;
@property (nonatomic, retain) IBOutlet UIVaultFailureOverlayView    *vfoFailDisplay;
@property (nonatomic, retain) IBOutlet UIFeedsOverviewAuthView      *avFeedAuth;
@end
