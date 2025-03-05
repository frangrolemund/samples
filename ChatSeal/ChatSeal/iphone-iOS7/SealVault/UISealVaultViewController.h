//
//  UISealVaultViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 11/1/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIVaultFailureOverlayView.h"
#import "UIHubViewController.h"
#import "UITableViewWithSizeableCells.h"

@interface UISealVaultViewController : UIViewController <UIHubManagedViewController>
@property (nonatomic, retain) IBOutlet UITableViewWithSizeableCells *tvSeals;
@property (nonatomic, retain) IBOutlet UIVaultFailureOverlayView    *vfoFailDisplay;
@end
