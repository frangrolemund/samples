//
//  UIGenericAccessViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 4/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIDynamicTypeCompliantEntity.h"

typedef void (^genericAccessCompletion)();

@class UIGenericAccessViewController;
@protocol UIGenericAccessViewControllerDelegate <NSObject>
-(NSString *) authTitle;
-(NSString *) authDescription;
-(NSString *) lockedTitle;
-(NSString *) lockedDescription;
@optional
-(void) accessViewControllerAuthContinuePressed:(UIGenericAccessViewController *) vc;
-(BOOL) accessViewControllerShouldShowLockedOnStartup:(UIGenericAccessViewController *) vc;
@end


// - this view controller will have to be configured separately.
@interface UIGenericAccessViewController : UIViewController <UIDynamicTypeCompliantEntity>
+(UIGenericAccessViewController *) instantateViewControllerWithAccessCompletion:(genericAccessCompletion) completionBlock;
-(void) flipToLocked;
-(IBAction)doCloseTheView;
-(IBAction)doAuthorize;

// - NOTE: this is a retained delegate because I'm really intending that generic objects provide the access logic.
@property (nonatomic, retain) id<UIGenericAccessViewControllerDelegate> delegate;

@property (nonatomic, retain) IBOutlet UILabel *lAuthTitle;
@property (nonatomic, retain) IBOutlet UILabel *lAuthDesc;
@property (nonatomic, retain) IBOutlet UILabel *lLockedTitle;
@property (nonatomic, retain) IBOutlet UILabel *lLockedDesc;

@property (nonatomic, retain) IBOutlet UIView *vwShadow;
@property (nonatomic, retain) IBOutlet UIView *vwAuthorize;
@property (nonatomic, retain) IBOutlet UIView *vwLocked;

@property (nonatomic, retain) IBOutlet UIImageView *ivAdvAuth;
@property (nonatomic, retain) IBOutlet UIImageView *ivAdvLock;

@property (nonatomic, retain) IBOutlet UIButton *bAuthorize;
@property (nonatomic, retain) IBOutlet UIButton *bOK;
@end
