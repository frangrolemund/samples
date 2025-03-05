//
//  UITimer.h
//  ChatSeal
//
//  Created by Francis Grolemund on 2/6/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

// - the point of this is to give the NSTimer an object to
//   attach itself to so that the timer doesn't prevent a
//   another container object from being destroyed due to the
//   retain loop.
@interface UITimer : NSObject
+ (UITimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)seconds target:(id)target selector:(SEL)aSelector userInfo:(id)userInfo repeats:(BOOL)repeats;
-(id) initWithFireDate:(NSDate *)date interval:(NSTimeInterval)seconds target:(id)target selector:(SEL)aSelector userInfo:(id)userInfo repeats:(BOOL)repeats;
-(void) setFireDate:(NSDate *)date;
-(void) invalidate;
-(id) userInfo;
@end
