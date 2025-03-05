//
//  ChatSealDebug.m
//  ChatSeal
//
//  Created by Francis Grolemund on 5/2/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "ChatSeal.h"
#import "ChatSealDebug.h"
#import "UIImageGeneration.h"
#import "ChatSealDebug_message.h"
#import "ChatSealDebug_basic_networking.h"
#import "ChatSealDebug_seal_networking.h"
#import "ChatSealDebug_feed_throttle.h"
#import "ChatSealDebug_tweetTrackingDB.h"
#import "ChatSealDebug_twitter_mining_history.h"
#import "ChatSealDebug_tweetText.h"
#import "ChatSealDebug_contrivedScenario.h"

#ifdef CHATSEAL_DEBUGGING_ROUTINES
#import <AssetsLibrary/AssetsLibrary.h>
#endif

/************************
 ChatSealDebug
 ************************/
@implementation ChatSealDebug
/*
 *  Report the current status of the debugging module.
 */
+(void) reportStatus
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSLog(@"INFO: (REMOVE) CHATSEAL DEBUGGING ROUTINES ARE PRESENT.");
    #ifdef CHATSEAL_DEBUG_DONT_POST_MESSAGES
        NSLog(@"INFO: (REMOVE) message posting is disabled for debugging.");
    #endif
    [ChatSeal debugLog:@"Starting the application debug log."];
#endif
}

/*
 *  Convert an asset orientation to an image orientation
 */
#ifdef CHATSEAL_DEBUGGING_ROUTINES
+(UIImageOrientation) imageOrientationFromAssetOrientation:(ALAssetOrientation) orient
{
    switch (orient) {
        case ALAssetOrientationUp:
        default:
            return UIImageOrientationUp;
            break;
            
        case ALAssetOrientationDown:
            return UIImageOrientationDown;
            break;
            
        case ALAssetOrientationLeft:
            return UIImageOrientationLeft;
            break;
            
        case ALAssetOrientationRight:
            return UIImageOrientationRight;
            break;
            
        case ALAssetOrientationUpMirrored:
            return UIImageOrientationUpMirrored;
            break;
            
        case ALAssetOrientationDownMirrored:
            return UIImageOrientationDownMirrored;
            break;
            
        case ALAssetOrientationLeftMirrored:
            return UIImageOrientationLeftMirrored;
            break;
            
        case ALAssetOrientationRightMirrored:
            return UIImageOrientationRightMirrored;
            break;
    }
}
#endif

/*
 *  Save an image to disk.
 */
+(BOOL) saveImage:(UIImage *) image withBaseName:(NSString *) base
{
#ifdef CHATSEAL_DEBUGGING_ROUTINES
    NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    NSString *file = [NSString stringWithFormat:@"%@.png", base];
    u = [u URLByAppendingPathComponent:file];
    NSData *d = UIImagePNGRepresentation(image);
    if ([d writeToURL:u atomically:YES]) {
        return YES;
    }
#endif
    //  - when not in debug mode, always return NO to maybe signal that this shouldn't be used.
    return NO;
}

/*
 *  Build a test message with appended data.
 */
+(void) appendRandomContentToMessage:(ChatSealMessage *) psm withNumberOfItems:(NSUInteger) numItems
{
    [ChatSealDebug_message appendRandomContentToMessage:psm withNumberOfItems:numItems];
}

/*
 *  Verify the messaging infrastructure for correctness, but all existing content
 *  will be destroyed.
 */
+(void) destructivelyVerifyMessagingInfrastructure
{
    [ChatSealDebug_message destructivelyVerifyMessagingInfrastructure];
}

/*
 *  Test that basic networking behavior is functional.
 */
+(void) beginBasicNetworkingTesting
{
    [ChatSealDebug_basic_networking beginBasicNetworkingTesting];
}

/*
 *  Test the seal exchange framework in the app.
 */
+(void) beginSealExchangeTesting
{
    [ChatSealDebug_seal_networking beginSealExchangeTesting];
}

/*
 *  Test that feed throttling works as expected.
 */
+(void) beginFeedThrottleTesting
{
    [ChatSealDebug_feed_throttle beginFeedThrottleTesting];
}

/*
 *  Test that the tweet tracking database can remain accurate through modifications.
 */
+(void) beginTweetTrackingTesting
{
    [ChatSealDebug_tweetTrackingDB beginTweetTrackingTesting];
}

/*
 *  Test that the mining history integrates information correctly.
 */
+(void) beginTwitterMiningHistoryTesting
{
    [ChatSealDebug_twitter_mining_history beginTwitterMiningHistoryTesting];
}

/*
 *  Test that the tweet text filtering behaves correctly and minimizes the chance of exposure.
 */
+(void) beginTweetTextTesting
{
    [ChatSealDebug_tweetText beginTweetTextTesting];
}

/*
 *  Begin building the scenario for taking screen shots.
 */
+(void) buildScreenshotScenario
{
    [ChatSealDebug_contrivedScenario buildScreenshotScenario];
}
@end

