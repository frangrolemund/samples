//
//  UITimer.m
//  ChatSeal
//
//  Created by Francis Grolemund on 2/6/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UITimer.h"

// - forward declarations
@interface UITimer (internal)
-(void) timerFired:(NSTimer *) t;
@end

/*********************
 UITimer
 *********************/
@implementation UITimer
/*
 *  Object attributes
 */
{
    NSTimer *timer;
    id      callerTarget;
    SEL     callerSelector;
}

/*
 *  Allocate and return a new timer on the stack.
 */
+ (UITimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)seconds target:(id)target selector:(SEL)aSelector userInfo:(id)userInfo repeats:(BOOL)repeats
{
    UITimer *tm = [[[UITimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:seconds]
                                            interval:seconds
                                              target:target
                                            selector:aSelector
                                            userInfo:userInfo
                                             repeats:repeats] autorelease];
    return tm;
}

/*
 *  Initialize the object.
 */
-(id) initWithFireDate:(NSDate *)date interval:(NSTimeInterval)seconds target:(id)target selector:(SEL)aSelector userInfo:(id)userInfo repeats:(BOOL)repeats
{
    self = [super init];
    if (self) {
        callerTarget   = target;
        callerSelector = aSelector;
        timer          = [[NSTimer alloc] initWithFireDate:date interval:seconds target:self selector:@selector(timerFired:) userInfo:userInfo repeats:repeats];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [timer release];
    timer = nil;
    
    [super dealloc];
}

/*
 *  Assign a new fire date.
 */
- (void)setFireDate:(NSDate *)date
{
    [timer setFireDate:date];
}

/*
 *  Invalidate the timer.
 */
-(void) invalidate
{
    [timer invalidate];
}

/*
 *  Return the user info provided for the timer.
 */
-(id) userInfo
{
    return [timer userInfo];
}
@end

/*********************
 UITimer (internal)
 *********************/
@implementation UITimer (internal)
/*
 *  This method is executed when the timer fires.
 */
-(void) timerFired:(NSTimer *) t
{
    [callerTarget performSelectorOnMainThread:callerSelector withObject:self waitUntilDone:YES];
}
@end
