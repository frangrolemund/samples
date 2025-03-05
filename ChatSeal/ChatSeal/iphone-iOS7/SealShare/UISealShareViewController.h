//
//  UISealShareViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/17/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UISealExchangeController.h"
#import "UISealShareDisplayView.h"
#import "UISealShareQRView.h"
#import "UISealShareTransferStatusView.h"

@interface UISealShareViewController : UIViewController <UISealExchangeFlipTarget>
@property (nonatomic, retain) IBOutlet UIView                        *vwTopLayoutContainer;
@property (nonatomic, retain) IBOutlet NSLayoutConstraint            *lcTopContraint;
@property (nonatomic, retain) IBOutlet UISealShareDisplayView        *ssqSealContainer;
@property (nonatomic, retain) IBOutlet UIView                        *vwScanningShade;
@property (nonatomic, retain) IBOutlet UILabel                       *lScanningInstructions;
@property (nonatomic, retain) IBOutlet UILabel                       *lFirstTimeInstructions;
@property (nonatomic, retain) IBOutlet UISealShareQRView             *qrQRDisplay;
@property (nonatomic, retain) IBOutlet UISealShareTransferStatusView *sstStatusView;
@property (nonatomic, retain) IBOutlet NSLayoutConstraint            *lcSealWidth;
@end
