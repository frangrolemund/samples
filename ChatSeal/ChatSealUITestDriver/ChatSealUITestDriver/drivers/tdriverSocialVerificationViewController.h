//
//  tdriverSocialVerificationViewController.h
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 3/19/14.
//  Copyright (c) 2014 Francis Grolemund. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface tdriverSocialVerificationViewController : UIViewController
-(IBAction)doGenerate:(id)sender;
-(IBAction)doRetrieve:(id)sender;
@property (nonatomic, retain) IBOutlet UIImageView *ivSample;
@property (nonatomic, retain) IBOutlet UITextField *tfGetSample;
@end
