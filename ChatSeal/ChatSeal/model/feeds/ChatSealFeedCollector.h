//
//  ChatSealFeedCollector.h
//  ChatSeal
//
//  Created by Francis Grolemund on 3/24/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ChatSealFeedType.h"
#import "ChatSealFeed.h"

//  DESIGN NOTES:
//  - It must be assumed that anything in this module can be updated at any time and from different asynchronous and synchronous sources.
//    I considered a few different approaches and settled on using explicit synchronization primitives to accommodate that design.  Many of
//    the other areas of the app aren't so explicitly multi-threaded, but this one is and either we need to serialize everything on single threads, which
//    I think limits this design, or use lock-based synchronization.  Since the updates here are relatively infrequent from the perspective of the
//    code (think 10's instead of 10,000's), then locking appears a better choice at the moment.
//  - You cannot issue API requests outside the standard processFeedRequestsInCategory method in an effort to ensure scheduling fairness.   
//  - Make sure that you look at every level of the hierarchy and lock when making modifications!
//  - Where possible I'm going to use @synchronized instead of lock objects, but I'll adapt the approach if there are a lot of updates happening.
//  - Feeds are in-memory until a vault exists.  This is by design to not overburden the first experience with the app.
//  - Threading is a major part of feed aggregation.  These are the rules that every class in this part of the model must obey:
//      1.  Every object that can be used on more than one thread simultaneously must include internal locking.
//      2.  Generally speaking, it it usually not a good idea to hold locks between functional levels in the hierarchy if there are delegate relationships between those
//          objects because we may get locks taken in inconsistent ordering, resulting in deadlocks.  Imagine some being taken downward from collector to type and others
//          taken from type to collector, for instance.  The best solution is to only hold locks long enough to get autorelease copies of the dependencies and then make your
//          calls.  Assume a lot of small critical sections in your implementations just long enough to get access to data.
//      3.  Because many of these objects are managed via delegate, all delegate references in this codebase must be atomically maintained and ex plicitly instead of by @property.
//      4.  Delegate references are always held while the delegate is executed.
//      5.  Every implementation file (.m) must have a THREADING-NOTES comment at the top describing the specific scenarios supported by the object.
//      6.  Custom feed types and feed implementations must provide their own locking.

@class ChatSealFeedCollector;
typedef void (^psfCollectorCompletionBlock)(ChatSealFeedCollector *collector, BOOL success, NSError *err);
@interface ChatSealFeedCollector : NSObject
+(BOOL) destroyAllFeedsWithError:(NSError **) err;
+(NSURL *) feedCollectionURL;
-(BOOL) isConfigured;
-(BOOL) hasBeenAuthQueried;
-(BOOL) isAuthorized;
-(BOOL) hasAnyFeeds;
-(BOOL) isOpen;
-(void) openAndQuery:(BOOL) doQuery withCompletion:(psfCollectorCompletionBlock) completionBlock;
-(void) requeryFeedPermissionsWithCompletion:(psfCollectorCompletionBlock) completionBlock;
-(BOOL) isQueryingFeedPermissions;
-(NSArray *) availableFeedTypes;
-(ChatSealFeedType *) typeForId:(NSString *) typeId;
-(NSArray *) availableFeedsAsSortedList;
-(ChatSealFeed *) feedForId:(NSString *) feedId;
-(BOOL) refreshActiveFeedsAndAdvancePendingOperationsWithError:(NSError **) err;
-(NSString *) lastFeedRefreshResult;
-(void) close;
-(NSUInteger) numberOfPendingPostsForMessage:(NSString *) messageId;
-(void) updateFeedsForDeletedMessage:(NSString *) messageId;
-(void) restoreFriendsInLocations:(NSArray *) arrLocations;
-(void) processReceivedFeedLocations:(NSArray *) arrLocations;
@end
