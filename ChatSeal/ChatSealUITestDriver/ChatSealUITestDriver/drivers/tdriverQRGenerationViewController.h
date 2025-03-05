//
//  tdriverQRGenerationViewController.h
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 2/2/14.
//  Copyright (c) 2014 Francis Grolemund. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface tdriverQRGenerationViewController : UITableViewController

-(IBAction)doRegenContent:(id)sender;

@property (nonatomic, retain) IBOutlet UILabel      *lErrorResult;
@property (nonatomic, retain) IBOutlet UIImageView  *ivQRCode;
@property (nonatomic, retain) IBOutlet UITextView   *tvContent;
@property (nonatomic, retain) IBOutlet UIPickerView *pvQuality;
@property (nonatomic, retain) IBOutlet UIPickerView *pvMask;
@end
