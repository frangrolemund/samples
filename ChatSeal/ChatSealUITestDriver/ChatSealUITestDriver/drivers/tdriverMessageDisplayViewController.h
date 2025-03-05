//
//  tdriverMessageDisplayViewController.h
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 7/9/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UISealedMessageDisplayViewV2.h"

@interface tdriverMessageDisplayViewController : UIViewController

-(IBAction)doAddMessage:(id)sender;
-(IBAction)doChangeCount:(id)sender;
-(IBAction)doTestTextSizing:(id)sender;

@property (nonatomic, retain) IBOutlet UISealedMessageDisplayViewV2 *messageDisplay;
@property (nonatomic, retain) IBOutlet UISlider *toAddSlider;
@property (nonatomic, retain) IBOutlet UILabel *toAddCount;
@end
