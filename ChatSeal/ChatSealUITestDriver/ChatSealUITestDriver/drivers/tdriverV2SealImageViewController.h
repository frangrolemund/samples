//
//  tdriverV2SealImageViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 3/21/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UISealImageViewV2.h"

@interface tdriverV2SealImageViewController : UIViewController
{
    UILabel           *lTestImage;
    UIStepper         *stepTestImage;
    UISealImageViewV2 *siView;
    UIImageView       *ivSnap;
    
    NSUInteger        currentTestImage;    
}

-(IBAction)didStep:(id)sender;
-(IBAction)doGenerate:(id)sender;
-(IBAction)doChangeClipping:(id)sender;

@property (nonatomic, retain) IBOutlet UILabel *lTestImage;
@property (nonatomic, retain) IBOutlet UIStepper *stepTestImage;
@property (nonatomic, retain) IBOutlet UISealImageViewV2 *siView;
@property (nonatomic, retain) IBOutlet UIImageView *ivSnap;
@property (nonatomic, retain) IBOutlet UISlider *sliderClip;

@end
