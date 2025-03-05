//
//  tdriverQRScanningViewController.h
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 2/3/14.
//  Copyright (c) 2014 Francis Grolemund. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIQRScanner.h"

@interface tdriverQRScanningViewController : UIViewController
@property (nonatomic, retain) IBOutlet UILabel     *lNotAvailError;
@property (nonatomic, retain) IBOutlet UILabel     *lScanOutput;
@property (nonatomic, retain) IBOutlet UIQRScanner *qrScanner;
@end
