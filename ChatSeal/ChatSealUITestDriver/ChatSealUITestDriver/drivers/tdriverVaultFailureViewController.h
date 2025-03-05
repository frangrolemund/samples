//
//  tdriverVaultFailureViewController.h
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 1/8/14.
//  Copyright (c) 2014 Francis Grolemund. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIVaultFailureOverlayView.h"

@interface tdriverVaultFailureViewController : UIViewController

@property (nonatomic, retain) IBOutlet UIVaultFailureOverlayView *vfoErrorOverlay;
@end
