//
//  UIPrivacyViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 12/3/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UITableViewWithSizeableCells.h"

@interface UIPrivacyViewController : UIViewController
+(void) displayPrivacyNoticeFromViewController:(UIViewController *) vc asModal:(BOOL) isModal;
@property (nonatomic, retain) IBOutlet UITableViewWithSizeableCells *tvContent;
@end
