//
//  ChatSealFeedProgress.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/24/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "ChatSealFeedProgress.h"
#import "CS_feedShared.h"

//  THREADING-NOTES:
//  - no locking is provided.  This object is never modified after it is created.

/*************************
 ChatSealFeedProgress
 *************************/
@implementation ChatSealFeedProgress
/*
 *  Object attributes
 */
{
    double overallProgress;
    double scanProgress;
    double postingProgress;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        // - assume we're done unless otherwise noted.
        overallProgress = 1.0f;
        scanProgress    = 1.0f;
        postingProgress = 1.0f;
    }
    return self;
}

/*
 *  Return the current completion status of the reported progress.
 */
-(BOOL) isComplete
{
    return [self checkComplete:overallProgress];
}

/*
 *  Return the overall progress.
 */
-(double) overallProgress
{
    return overallProgress;
}

/*
 *  Return whether the scanning is complete or not.
 */
-(BOOL) isScanComplete
{
    return [self checkComplete:scanProgress];
}

/*
 *  Return the scan progress.
 */
-(double) scanProgress
{
    return scanProgress;
}

/*
 *  Return whether posting is complete or not.
 */
-(BOOL) isPostingComplete
{
    return [self checkComplete:postingProgress];
}

/*
 *  Return the posting progress.
 */
-(double) postingProgress
{
    return postingProgress;
}
@end

/***********************************
 ChatSealFeedProgress (internal)
 ***********************************/
@implementation ChatSealFeedProgress (internal)
/*
 *  Assign the overall progress.
 */
-(void) setOverallProgress:(double)val
{
    overallProgress = val;
}

/*
 *  Assign the scan progress.
 */
-(void) setScanProgress:(double)val
{
    scanProgress = val;
}

/*
 *  Assign the posting progress.
 */
-(void) setPostingProgress:(double)val
{
    postingProgress = val;
}

/*
 *  Simple value completion check.
 */
-(BOOL) checkComplete:(double) val
{
    if ((int) val == 1 || val < 0.0 || val >= 1.0) {
        return YES;
    }
    return NO;
}

@end

