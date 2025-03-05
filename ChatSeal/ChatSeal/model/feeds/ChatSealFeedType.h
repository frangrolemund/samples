//
//  ChatSealFeedType.h
//  ChatSeal
//
//  Created by Francis Grolemund on 3/24/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ChatSealFeed.h"
#import "ChatSealFeedFriend.h"

extern NSString *kChatSealFeedTypeTwitter;

typedef enum {
    CSFT_FS_NONE   = 0,             // - no friendships to manage.
    CSFT_FS_REFINE = 1,             // - refine allows you to see or modify existing friendships.
    CSFT_FS_BROKEN,                 // - broken means that we must deal with it or friends will not be able to communicate with us.
} csft_friendship_state_t;

//  - the core class
@class UIFriendManagementViewController;
@class UIFriendAdditionViewController;
@interface ChatSealFeedType : NSObject
+(NSURL *) feedTypeURL;
+(NSString *) friendProfilesCacheCategory;
-(BOOL) hasMinimumImplementation;
-(NSString *) description;                                                          //  - description of the feed.
-(NSString *) typeId;                                                               //  - string identifier for the feed.
-(NSString *) typeHostName;                                                         //  - a single host that can be used a reachability target.
-(BOOL) isManagedBySettings;                                                        //  - if the feed is configured exclusively in the Settings app.
-(BOOL) isAuthorized;                                                               //  - for feeds managed in settings, this indicates whether permissions are sufficient to use it.
-(void) refreshAuthorizationWithCompletion:(void (^)(void)) completionBlock;        //  - when authorization checks are required, do so now.
-(NSArray *) feeds;                                                                 //  - the feeds managed by this type.
-(NSDate *) lastRefresh;
-(csft_friendship_state_t) friendshipState;                                         //  - whether this collection of feeds is adequately connected to my friends.
-(NSArray *) feedFriends;                                                           //  - instances of ChatSealFeedFriend for all friends of this type
-(NSString *) friendsDisplayTitle;                                                  //  - title for the screen showing my friends in this type.
-(UIImage *) friendDefaultProfileImage;                                             //  - an image to use when there is nothing special defined for this friend.
-(BOOL) ignoreFriendByAccountId:(NSString *) acctId;                                //  - don't encourage a friendship with this person.
-(void) restoreFriendsAccountIds:(NSArray *) arrFriends;                            //  - stop ignoring one or more friends.
-(UIFriendManagementViewController *) friendManagementViewController;               //  - any friend we return must be able to be managed.
-(BOOL) canAddFriendsManually;                                                      //  - the user is allowed to add friends.
-(UIFriendAdditionViewController *) friendAdditionViewController;                   //  - if we can add friends, return a view controller that can manage it.
@end
