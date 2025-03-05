//
//  tdriverWaxLayerViewController.h
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 6/14/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface tdriverWaxLayerViewController : UIViewController
-(IBAction)didChangeLocked:(id)sender;
-(IBAction)didChangeSmallSeal:(id)sender;
@property (nonatomic, retain) IBOutlet UISwitch *lockedSwitch;
@end
