//
//  CS_twitterFeed_download.m
//  ChatSeal
//
//  Created by Francis Grolemund on 5/31/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeed_shared.h"

//  THREADING-NOTES:
//  - internal locking is provided.

/****************************
 CS_twitterFeed (download)
 ****************************/
@implementation CS_twitterFeed (download)
/*
 *  Perform download processing.
 */
-(BOOL) processFeedRequestsForDownload
{
    //  !!REMEMBER!!
    //  - The only time to ever return NO from this method is when the request was throttled.
    
    // - always begin by checking our pending list.
    if (![self tryToProcessPendingInCategory:CS_CNT_THROTTLE_DOWNLOAD]) {
        return NO;
    }
    
    return YES;
}

/*
 *  When a download request completes, this method is issued.
 */
-(void) completeFeedRequestForDownload:(CS_twitterFeedAPI *)api
{
    // - finish off the completed APIs.
    if ([self tryToCompletePendingWithAPI:api]) {
        return;
    }
}
@end

