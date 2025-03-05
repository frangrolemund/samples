//
//  CS_tweetTrackingDB.h
//  ChatSeal
//
//  Created by Francis Grolemund on 5/27/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CS_candidateTweetContext : NSObject <NSCoding>
+(CS_candidateTweetContext *) contextForScreenName:(NSString *) screenName andPhoto:(NSURL *) url andProvenUseful:(BOOL) isUseful;
@property (nonatomic, retain) NSString *screenName;
@property (nonatomic, retain) NSURL *photoURL;
@property (nonatomic, assign) BOOL isProvenUseful;
@end

@interface CS_tweetTrackingDB : NSObject <NSCoding>
+(NSUInteger) maxCandidateTweets;
-(void) setTweet:(NSString *) tweetId asPendingWithContext:(NSObject *) ctx;
-(void) setTweetAsCompleted:(NSString *) tweetId;
-(BOOL) flagTweet:(NSString *) tweetId asCandidateFromFriend:(NSString *) screenName withPhoto:(NSURL *) photo andProvenUseful:(BOOL) isUseful andForceIt:(BOOL) forceFlag;
-(NSDictionary *) allCandidates;
-(BOOL) isTweetTracked:(NSString *) tweetId;
-(BOOL) isTweetCompleted:(NSString *) tweetId;
-(NSObject *) contextForPendingTweet:(NSString *) tweetId;
-(NSUInteger) count;
-(void) untrackTweet:(NSString *) tweetId;
-(void) deletePendingTweetsWithContext:(NSObject *) ctx;
@end
