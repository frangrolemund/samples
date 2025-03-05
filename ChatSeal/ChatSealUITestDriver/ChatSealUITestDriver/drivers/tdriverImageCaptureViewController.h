//
//  tdriverImageCaptureViewController.h
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 4/11/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIPhotoCaptureView.h"

@interface tdriverImageCaptureViewController : UIViewController
{
    UIPhotoCaptureView *pcView;
    UILabel            *lNotAvail;
    UIButton           *bFlip;
    UIButton           *bSnap;
}

-(IBAction)doFlip:(id)sender;
-(IBAction)doSnap:(id)sender;

@property (nonatomic, retain) IBOutlet UIPhotoCaptureView *pcView;
@property (nonatomic, retain) IBOutlet UILabel *lNotAvail;
@property (nonatomic, retain) IBOutlet UIButton *bFlip;
@property (nonatomic, retain) IBOutlet UIButton *bSnap;
@end
