//
//  UIFeedAccessViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 4/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIGenericAccessViewController.h"

@interface UIFeedAccessViewController : NSObject
+(NSString *) feedAccessTitle;
+(NSString *) feedAccessDescription;
+(UIGenericAccessViewController *) instantateViewControllerWithCompletion:(genericAccessCompletion) completionBlock;
@end
