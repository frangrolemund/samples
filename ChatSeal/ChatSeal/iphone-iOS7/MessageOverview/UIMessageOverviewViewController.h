//
//  UIMessageOverviewViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 11/1/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ChatSeal.h"
#import "UIVaultFailureOverlayView.h"
#import "UIHubViewController.h"

@class UISearchScroller;
@interface UIMessageOverviewViewController : UIViewController <UIHubManagedViewController>
-(void) setNewMessage:(ChatSealMessage *) psm;
@property (nonatomic, retain) IBOutlet UISearchScroller          *ssSearchScroller;
@property (nonatomic, retain) IBOutlet UIVaultFailureOverlayView *vfoFailOverlay;
@end
