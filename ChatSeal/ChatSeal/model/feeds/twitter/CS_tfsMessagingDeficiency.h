//
//  CS_tfsMessagingDeficiency.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/16/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CS_tfsUserData;
@class CS_tapi_friendship_state;
@interface CS_tfsMessagingDeficiency : NSObject <NSCoding>
+(CS_tfsMessagingDeficiency *) deficiencyFromUser:(CS_tfsUserData *) localUser toUserWithState:(CS_tapi_friendship_state *) fs;
+(CS_tfsMessagingDeficiency *) unionOfDeficiency:(CS_tfsMessagingDeficiency *) d1 withDeficiency:(CS_tfsMessagingDeficiency *) d2;
+(CS_tfsMessagingDeficiency *) deficiencyForAllFeedsDisabled;
+(CS_tfsMessagingDeficiency *) deficiencyForUnqueriedFriend;

// - these methods are intentionally designed to only return YES when there is a health issue so that
//   any code that references a nil friendship health assumes a healthy state by default, which is what
//   this friendship code does as a rule to avoid complaining about things that are indeterminate.
-(BOOL) isEqualToDeficiency:(CS_tfsMessagingDeficiency *) other;
-(BOOL) isSubOptimal;
-(BOOL) isBroken;

-(BOOL) isUnqueried;
-(BOOL) isSendRestricted;                       //  doesn't necessarily mean that sending cannot occur, just that it may not happen efficiently.
-(BOOL) isRecvRestricted;                       //  ...same for receiving.
-(BOOL) isWaitingForFollowAccept;               //  we're waiting for this friend to accept our follow
-(BOOL) isMuting;                               //  this friend's account is muted.
-(BOOL) isNotFollowingProtectedSealOwner;       //  they are the seal owner in this relationship, have their account protected and we're not following them.
-(BOOL) isProtectedWithFriendRequest;           //  our account is protected and this friend is trying to connect with us.
-(BOOL) isBlocked;                              //  this friend's account is explicitly blocked.
-(BOOL) isFriendProtected;                      //  this friend has a protected account
-(BOOL) isBlockingMyAccount;                    //  they are blocking me.
-(BOOL) allFeedsAreDisabled;                    //  when there is no way to reach this friend because all feeds are disabled.
-(BOOL) iAmProtectedSealOwnerAndTheyNoFollow;   //  my account is protected, I've shared a seal and they are not following me.
-(NSString *) shortDescription;
-(void) reset;
@end
