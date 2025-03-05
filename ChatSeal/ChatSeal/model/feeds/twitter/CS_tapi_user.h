//
//  CS_tapi_user.h
//  ChatSeal
//
//  Created by Francis Grolemund on 4/7/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeedAPI.h"

@class CS_tapi_user;
@protocol CS_tapi_userDelegate <NSObject>
@optional
-(void) twitterStreamAPI:(CS_tapi_user *) api didReceiveFriendsList:(NSArray *) arrFriends;
-(void) twitterStreamAPI:(CS_tapi_user *) api didFindImageTweet:(NSString *) tweetId withURL:(NSURL *) url fromUser:(NSString *) userId;
-(void) twitterStreamAPI:(CS_tapi_user *) api didDetectDeletionOfTweet:(NSString *) tweetId;
-(void) twitterStreamAPI:(CS_tapi_user *) api didFollowUser:(NSString *) userId withFriendsCount:(NSNumber *) friendsCount;
-(void) twitterStreamAPI:(CS_tapi_user *) api didUnfollowUser:(NSString *) userId withFriendsCount:(NSNumber *) friendsCount;
-(void) twitterStreamAPI:(CS_tapi_user *) api didBlockUser:(NSString *) userId withFriendsCount:(NSNumber *) friendsCount;
-(void) twitterStreamAPI:(CS_tapi_user *) api didUnblockUser:(NSString *) userId withFriendsCount:(NSNumber *) friendsCount;
@end

@interface CS_tapi_user : CS_twitterFeedAPI
@property (nonatomic, assign) id<CS_tapi_userDelegate> delegate;
-(BOOL) isReturningData;
-(NSUInteger) numberOfContentChangeEvents;
@end
