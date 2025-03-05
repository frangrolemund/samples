//
//  AlertManager.h
//  ChatSeal
//
//  Created by Francis Grolemund on 4/24/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AlertManager : NSObject
+(UIAlertView *) displayErrorAlertWithTitle:(NSString *) title andText:(NSString *) text;
+(UIAlertView *) displayErrorAlertWithTitle:(NSString *) title andText:(NSString *) text andDelegate:(id<UIAlertViewDelegate>) delegate;
+(void) displayFatalAlertWithLowSpaceDetectionUsingTitle:(NSString *) title andText:(NSString *) text;
+(NSString *) standardErrorTextWithText:(NSString *) text;
+(NSString *) standardLowStorageMessage;
@end
