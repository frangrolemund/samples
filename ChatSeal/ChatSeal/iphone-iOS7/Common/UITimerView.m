//
//  UITimerView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 2/17/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UITimerView.h"

// - forward declarations.
@interface UITimerView (internal)
-(void) commonConfiguration;
-(void) timerFired:(NSTimer *) timer;
-(void) discardTimer;
-(void) discardCompletion;
@end

/********************
 UITimerView
 ********************/
@implementation UITimerView
/*
 *  Object attributes.
 */
{
    NSTimeInterval           tiFirePeriod;
    NSTimer                  *tmTimer;
    timerViewCompletionBlock completionBlock;
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonConfiguration];
    }
    return self;
}

/*
 *  Initialize the object.
 */
-(id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonConfiguration];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [self discardTimer];
    [self discardCompletion];
    
    [super dealloc];
}

/*
 *  When detaching this view, make sure its timer is
 *  discarded.
 */
-(void) willMoveToSuperview:(UIView *)newSuperview
{
    if (newSuperview == nil) {
        [self discardTimer];
        [self discardCompletion];
    }
}

/*
 *  Change the timeout on this view, but retain the existing completion block.
 */
-(void) setTimeout:(NSTimeInterval) tiTimeout
{
    [self setTimeout:tiTimeout withCompletion:completionBlock];
}

/*
 *  Assign a timeout to this view with a requested completion block when it fires.
 */
-(void) setTimeout:(NSTimeInterval) tiTimeout withCompletion:(timerViewCompletionBlock) cb
{
    [self discardTimer];
    tiFirePeriod = tiTimeout;
    if (cb != completionBlock) {
        [self discardCompletion];
        completionBlock = Block_copy(cb);
    }
}

/*
 *  Start the timer to be running from now til its fire date or refresh an active timer.
 */
-(void) restartTimer
{
    if (tmTimer) {
        [tmTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:tiFirePeriod]];
    }
    else {
        tmTimer = [[NSTimer timerWithTimeInterval:tiFirePeriod target:self selector:@selector(timerFired:) userInfo:nil repeats:NO] retain];
        [[NSRunLoop mainRunLoop] addTimer:tmTimer forMode:NSRunLoopCommonModes];
    }
}

/*
 *  Stop the timer.
 */
-(void) haltTimerAndForceCompletion:(BOOL) forceCompletion
{
    if (tmTimer && forceCompletion) {
        [self timerFired:tmTimer];
    }
    else {
        [self discardTimer];
    }
}
@end


/***********************
 UITimerView (internal)
 ***********************/
@implementation UITimerView (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    tmTimer         = nil;
    tiFirePeriod    = 1.0f;
    completionBlock = nil;
}

/*
 *  The timer in this object has fired and we need to deal with it.
 */
-(void) timerFired:(NSTimer *)timer
{
    [self discardTimer];
    if (completionBlock) {
        completionBlock();
    }
}

/*
 *  Make sure the timer is fully released and detached from the run loop.
 */
-(void) discardTimer
{
    [tmTimer invalidate];
    [tmTimer release];
    tmTimer = nil;
}

/*
 *  Discard the current completion block.
 */
-(void) discardCompletion
{
    if (completionBlock) {
        Block_release(completionBlock);
        completionBlock = nil;
    }
}
@end
