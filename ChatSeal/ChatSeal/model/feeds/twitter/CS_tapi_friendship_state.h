//
//  CS_tapi_friendship_state.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CS_tapi_friendship_state : NSObject <NSCoding>
+(CS_tapi_friendship_state *) stateWithConnections:(NSArray *) arrConn;
+(CS_tapi_friendship_state *) stateOfTargetFromSource:(NSDictionary *) dict;
+(CS_tapi_friendship_state *) stateWithState:(CS_tapi_friendship_state *) state;
-(BOOL) isFollowedBy;
-(BOOL) friendWantsToFollowMe;
-(BOOL) isBlockingMyAccount;
-(void) setIsBlockingMyAccount;
-(void) mergeWithLearnedFromState:(CS_tapi_friendship_state *) stateOther;
-(BOOL) isEqualToState:(CS_tapi_friendship_state *) stateOther;
-(BOOL) isReadable;
-(void) flagAsTrusted;
@property (nonatomic, assign)   BOOL isFollowing;
@property (nonatomic, assign)   BOOL hasSentFollowRequest;
@property (nonatomic, assign)   BOOL isBlocking;
@property (nonatomic, assign)   BOOL isMuting;
@property (nonatomic, assign)   BOOL isProtected;
@property (nonatomic, assign)   BOOL iAmSealOwner;
@property (nonatomic, readonly) BOOL isTrusted;
@end
