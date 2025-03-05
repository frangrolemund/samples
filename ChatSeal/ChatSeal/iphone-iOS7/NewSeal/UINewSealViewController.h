//
//  UINewSealViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 6/3/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UINewSealBackdropView.h"
#import "UINewSealCollectionView.h"


typedef void (^sealCreationCompleted)(BOOL isCancelled, NSString *sealId);

@interface UINewSealViewController : UIViewController
+(UIViewController *) viewControllerWithCreationCompletionBlock:(sealCreationCompleted) completionBlock;
+(UIViewController *) viewControllerWithCreationCompletionBlock:(sealCreationCompleted) completionBlock andAutomaticallyMakeActive:(BOOL) makeActive;
-(IBAction)doCancel:(id)sender;
-(IBAction)doAddPhoto:(id)sender;
-(IBAction)doFlipCamera:(id)sender;
-(IBAction)doSnapPhoto:(id)sender;

@property (nonatomic, retain) IBOutlet UIView                  *sealDisplayView;
@property (nonatomic, retain) IBOutlet UIView                  *toolView;
@property (nonatomic, retain) IBOutlet UILabel                 *description;
@property (nonatomic, retain) IBOutlet UILabel                 *editDescription;
@property (nonatomic, retain) IBOutlet UIView                  *vwEditShade;
@property (nonatomic, retain) IBOutlet UINewSealBackdropView   *backdrop;
@property (nonatomic, retain) IBOutlet UINewSealCollectionView *sealCollection;
@property (nonatomic, retain) IBOutlet UIButton                *addPhotoButton;
@property (nonatomic, retain) IBOutlet UIButton                *flipCameraButton;
@property (nonatomic, retain) IBOutlet UIButton                *snapPhotoButton;
@property (nonatomic, retain) IBOutlet NSLayoutConstraint      *backdropSideConstraint;
@property (nonatomic, retain) IBOutlet NSLayoutConstraint      *bottomToolConstraint;
@end
