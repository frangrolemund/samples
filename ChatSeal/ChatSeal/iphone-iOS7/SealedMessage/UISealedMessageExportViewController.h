//
//  UISealedMessageExportViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 10/4/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UISealedMessageEnvelopeViewV2.h"
#import "UIMessageDetailViewControllerV2.h"
#import "UISealedMessageExportConfigData.h"

@interface UISealedMessageExportViewController : UIViewController
+(UISealedMessageExportViewController *) instantateViewControllerWithConfiguration:(UISealedMessageExportConfigData *) config;
-(IBAction)doPostMessage:(id)sender;

@property (nonatomic, retain) IBOutlet UIImageView *ivFrosted;
@property (nonatomic, retain) IBOutlet UIView *vwFrostedContainer;
@property (nonatomic, retain) IBOutlet UIView *vwContent;
@property (nonatomic, retain) IBOutlet UIView *vwGuidance;
@property (nonatomic, retain) IBOutlet UILabel *lPreparing;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *aivProgress;
@property (nonatomic, retain) IBOutlet UILabel *lSecure;
@property (nonatomic, retain) IBOutlet UILabel *lErrSpace;
@property (nonatomic, retain) IBOutlet UILabel *lErrOther;
@property (nonatomic, retain) IBOutlet NSLayoutConstraint *lcTopGuidance;
@property (nonatomic, retain) IBOutlet UIView *vwExportActions;
@property (nonatomic, retain) IBOutlet UIButton *bPostMessage;
@end
