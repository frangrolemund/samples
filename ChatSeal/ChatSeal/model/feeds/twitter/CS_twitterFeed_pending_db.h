//
//  CS_twitterFeed_pending_db.h
//  ChatSeal
//
//  Created by Francis Grolemund on 6/2/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CS_tweetPending : NSObject <NSCoding>
-(NSString *) tweetId;
-(NSURL *) photoURL;
-(BOOL) isConfirmed;
-(BOOL) isBeingProcessed;
-(void) setIsBeingProcessed:(BOOL) isProc;
-(BOOL) shouldDelayProcessing;
-(NSString *) screenName;                   //  NOTE: this may not be provided and should be considered unreliable for accurate message identification.
-(BOOL) hasPreviouslyFailedProcessing;
@end

@class CS_tapi_statuses_lookup;
@interface CS_twitterFeed_pending_db : NSObject
-(BOOL) openFromURL:(NSURL *) u withError:(NSError **) err;
-(BOOL) addPendingTweet:(NSString *) tweetId forScreenName:(NSString *) screenName withEmbeddedPhoto:(NSURL *) uPhoto andDelayUntil:(NSDate *) dt;
-(CS_tweetPending *) pendingForTweet:(NSString *) tweetId;
-(CS_tweetPending *) nextPendingTweetWithPhotoAsConfirmed:(BOOL) isConfirmed;
-(NSArray *) pendingTweetIdsWithoutPhotosAndMaxCount:(NSUInteger) count;
-(void) abortPendingTweetPhotoLookups:(NSArray *) arrTweetIds;
-(BOOL) completePendingTweetPhotoLookupsWithAPI:(CS_tapi_statuses_lookup *) api andReturnInvalid:(NSArray **) arrInvalidTweets;
-(void) setTweetIsConfirmedUseful:(NSString *) tweetId;
-(void) discardPendingTweet:(NSString *) tweetId;
-(void) save;
-(NSArray *) allPending;
-(BOOL) hasHighPriorityPendingNotProcessing;
-(void) markPendingTweetFailedAndAllowProcessing:(NSString *) tweetId;
-(NSArray *) extractPendingItemsWithFullIdentification:(BOOL) fullyIdentified;
-(void) addPendingItemsForProcessing:(NSArray *) arrPending;
@end
