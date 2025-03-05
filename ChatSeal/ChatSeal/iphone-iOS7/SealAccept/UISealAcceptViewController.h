//
//  UISealAcceptViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/17/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UISealExchangeController.h"
#import "UISealAcceptRadarView.h"

@interface UISealAcceptViewController : UIViewController <UISealExchangeFlipTarget>
@property (nonatomic, retain) IBOutlet UIView                *vwScanningControls;
@property (nonatomic, retain) IBOutlet UISealAcceptRadarView *vwRadarOverlay;
@property (nonatomic, retain) IBOutlet UILabel               *lOverview;
@property (nonatomic, retain) IBOutlet UILabel               *lTransferOverview;
@property (nonatomic, retain) IBOutlet UIProgressView        *pvTransfer;
@property (nonatomic, retain) IBOutlet UILabel               *lImporting;
@end
