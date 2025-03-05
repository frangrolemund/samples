//
//  ChatSealFeedFriend.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/15/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ChatSealFeedFriend;
@protocol ChatSealFeedFriendDelegate <NSObject>
-(UIImage *) profileImageForFriend:(ChatSealFeedFriend *) feedFriend withContext:(NSObject *) ctx;
@end

@class ChatSealFeedType;
@interface ChatSealFeedFriend : NSObject
+(ChatSealFeedFriend *) friendForFeedType:(ChatSealFeedType *) ft andUserId:(NSString *) userId forDelegate:(id<ChatSealFeedFriendDelegate>) delegate withContext:(NSObject *) ctx;
+(ChatSealFeedFriend *) debugFriendWithUserId:(NSString *) userId andName:(NSString *) name andFriendVersion:(uint16_t) version;
+(NSString *) standardAccountDeletionText;
-(void) assignContentFromEquivalentFriend:(ChatSealFeedFriend *) friendData;
@property (nonatomic, readonly) ChatSealFeedType *feedType;
@property (nonatomic, readonly) NSString         *userId;
@property (nonatomic, retain) NSString           *friendNameOrDescription;
@property (nonatomic, retain) NSString           *friendDetailDescription;
@property (nonatomic, retain) NSString           *friendLocation;
@property (nonatomic, readonly) UIImage          *profileImage;
@property (nonatomic, assign) BOOL               isBroken;
@property (nonatomic, assign) BOOL               isDeleted;
@property (nonatomic, assign) BOOL               isIdentified;
@property (nonatomic, assign) BOOL               isTrusted;
@property (nonatomic, assign) uint16_t           friendVersion;
@end
