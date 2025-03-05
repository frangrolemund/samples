//
//  CS_tfsFriendshipAdjustment.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/22/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CS_tfsMessagingDeficiency;
@class ChatSealFeed;
@class ChatSealFeedFriend;
@interface CS_tfsFriendshipAdjustment : NSObject
-(id) initWithDeficiency:(CS_tfsMessagingDeficiency *) def forLocalFeed:(ChatSealFeed *) feed;
-(BOOL) reflectsTheSameFeedAs:(CS_tfsFriendshipAdjustment *) faOther;
-(BOOL) recommendsTheSameAdjustmentAs:(CS_tfsFriendshipAdjustment *) faOther;
-(BOOL) isFeedEnabled;
-(NSString *) screenName;
-(NSString *) statusText;
-(BOOL) isWarning;
-(void) setCanBenefitFromRegularUpdates:(BOOL) forceUpdates;
-(BOOL) canBenefitFromRegularUpdates;
-(BOOL) hasDetailToDisplay;
-(NSString *) correctiveTextForFriend:(ChatSealFeedFriend *) feedFriend;
-(BOOL) hasCorrectiveAction;
-(NSString *) correctiveButtonTextForFriend:(ChatSealFeedFriend *) feedFriend;
-(CS_tfsFriendshipAdjustment *) highestPriorityAdjustmentForFriend:(ChatSealFeedFriend *) feedFriend;
-(NSString *) descriptiveNameForFeedFriend:(ChatSealFeedFriend *) feedFriend;

-(BOOL) applyAdjustmentForFriend:(NSString *) screenName withError:(NSError **) err;
-(void) requestConnectionUpdateForFriend:(ChatSealFeedFriend *) feedFriend;
-(void) cancelConnectionUpdateForFriend:(ChatSealFeedFriend *) feedFriend;
@end
