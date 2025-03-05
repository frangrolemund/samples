//
//  UITimerView.h
//  ChatSeal
//
//  Created by Francis Grolemund on 2/17/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^timerViewCompletionBlock)(void);

@interface UITimerView : UIView
-(void) setTimeout:(NSTimeInterval) tiTimeout;
-(void) setTimeout:(NSTimeInterval) tiTimeout withCompletion:(timerViewCompletionBlock) completion;
-(void) restartTimer;
-(void) haltTimerAndForceCompletion:(BOOL) forceCompletion;
@end
