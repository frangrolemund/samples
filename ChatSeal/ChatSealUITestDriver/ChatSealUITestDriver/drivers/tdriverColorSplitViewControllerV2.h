//
//  tdriverColorSplitViewControllerV2.h
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 9/17/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

@interface tdriverColorSplitViewControllerV2 : UIViewController
-(IBAction)doChangeSlider:(id)sender;
-(IBAction)doShowTools:(id)sender;

@property (nonatomic, retain) IBOutlet UIView *vwBefore;
@property (nonatomic, retain) IBOutlet UIView *vwPart1;
@property (nonatomic, retain) IBOutlet UIView *vwPart2;
@property (nonatomic, retain) IBOutlet GLKView *glvAfter;
@property (nonatomic, retain) IBOutlet UIView *vwTarget;
@property (nonatomic, retain) IBOutlet UISlider *slColorFax;
@property (nonatomic, retain) IBOutlet UILabel  *lCFEnabled;
@end
