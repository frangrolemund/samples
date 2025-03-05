//
//  UISealSelectionViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/2/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIVaultFailureOverlayView.h"
#import "UITableViewWithSizeableCells.h"

typedef void (^sealSelectionCompleted)(BOOL hasActiveSeal);

@interface UISealSelectionViewController : UIViewController
+(BOOL) selectionIsPossibleWithError:(NSError **) err;
+(UIViewController *) viewControllerWithSelectionCompletionBlock:(sealSelectionCompleted) completionBlock;
+(UIViewController *) viewControllerForMessageSealSelection:(BOOL) isForSealingMessages withSelectionCompletionBlock:(sealSelectionCompleted) completionBlock;

-(IBAction)doCancel:(id)sender;
-(IBAction)doAddNewSeal:(id)sender;
-(IBAction)doUseThisSeal:(id)sender;
-(IBAction)doEdit:(id)sender;

@property (nonatomic, retain) IBOutlet UIBarButtonItem              *bbiUseThisSeal;
@property (nonatomic, retain) IBOutlet UIBarButtonItem              *bbiEdit;
@property (nonatomic, retain) IBOutlet UIBarButtonItem              *bbiNewSeal;
@property (nonatomic, retain) IBOutlet UITableViewWithSizeableCells *tvSeals;
@property (nonatomic, retain) IBOutlet UIVaultFailureOverlayView    *vfoErrorDisplay;
@end
