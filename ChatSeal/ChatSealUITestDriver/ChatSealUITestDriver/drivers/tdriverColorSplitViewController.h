//
//  tdriverColorSplitViewController.h
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 9/8/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

@interface tdriverColorSplitViewController : UIViewController
-(IBAction)doChangeSlider:(id)sender;
-(IBAction)doDumpData:(id)sender;
-(IBAction)doDeleteCurrent:(id)sender;
-(IBAction)doSnapshot:(id)sender;

@property (nonatomic, retain) IBOutlet UIView *vwBefore;
@property (nonatomic, retain) IBOutlet UIView *vwPart1;
@property (nonatomic, retain) IBOutlet UIView *vwPart2;
@property (nonatomic, retain) IBOutlet GLKView *glvAfter;
@property (nonatomic, retain) IBOutlet UIButton *btnDeleteCur;
@property (nonatomic, retain) IBOutlet UIButton *btnDumpData;
@property (nonatomic, retain) IBOutlet UIButton *btnSnapshot;
@property (nonatomic, retain) IBOutlet UISlider *slColorFax;
@property (nonatomic, retain) IBOutlet UILabel  *lCFEnabled;
@end
