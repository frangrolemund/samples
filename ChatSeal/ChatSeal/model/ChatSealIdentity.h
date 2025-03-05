//
//  ChatSealIdentity.h
//  ChatSeal
//
//  Created by Francis Grolemund on 12/26/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RealSecureImage/RealSecureImage.h"

@class ChatSealFeedLocation;
@interface ChatSealIdentityFriend : NSObject
@property (nonatomic, readonly) ChatSealFeedLocation *location;
@property (nonatomic, readonly) BOOL isSealOwnerInRelationship;
@end

@interface ChatSealIdentity : NSObject
+(NSString *) ownerNameForSeal:(NSString *) sealId;
+(void) sortIdentityArrayForDisplay:(NSMutableArray *) maIdents;
+(NSArray *) friendsForFeedsOfType:(NSString *) feedType;
+(NSUInteger) friendsListVersionForFeedsOfType:(NSString *) feedType;
+(BOOL) deleteAllFriendsForFeedsInLocations:(NSArray *) arrLocations;
+(BOOL) hasSeals;

// - seal-related attributes.
-(NSString *) sealId;
-(NSString *) safeSealId;
-(BOOL) isKnown;
-(BOOL) isOwned;
-(RSISecureSeal_Color_t) color;
-(UIImage *) safeImage;
-(UIImage *) tableImage;
-(UIImage *) vaultImage;
-(NSString *) computedStatusTextAndDisplayAsWarning:(BOOL *) isWarning;
-(BOOL) isExpirationWarningVisible;
-(NSUInteger) sealExpirationTimoutInDaysWithError:(NSError **) err;
-(BOOL) setExpirationTimeoutInDays:(NSUInteger) days withError:(NSError **) err;
-(BOOL) isInvalidated;
-(BOOL) isExpired;
-(BOOL) isRevoked;
-(BOOL) checkForRevocationWithScreenshotTaken;
-(BOOL) checkForExpiration;
-(BOOL) isRevocationOnScreenshotEnabledWithError:(NSError **) err;
-(BOOL) setRevokeOnScreenshotEnabled:(BOOL) enabled withError:(NSError **) err;
-(BOOL) canBeInvalidatedByState;

// - inferred attributes or statistics associated with this identity.
-(BOOL) isActive;
-(BOOL) setActive:(BOOL) enabled withError:(NSError **) err;
-(NSDate *) dateCreated;
-(NSString *) ownerName;
-(BOOL) setOwnerName:(NSString *) name ifBeforeDate:(NSDate *) dt;
-(void) incrementSentCount;
-(void) addToSentCount:(NSUInteger) addCount;
-(void) incrementRecvCount;
-(void) addToRecvCount:(NSUInteger) addCount;
-(void) incrementSealGivenCount;
-(void) markSealWasReSharedWithAFriend;
-(NSUInteger) totalUsageCount;
-(NSUInteger) sentCount;
-(NSUInteger) recvCount;
-(NSUInteger) sealGivenCount;
-(NSUInteger) screenshotsTaken;
-(NSDate *) nextExpirationDate;
-(void) setDefaultFeed:(NSString *) feedId;
-(NSString *) defaultFeed;
-(NSArray *) feedPostingHistory;
-(void) updateFriendFeedLocations:(NSArray *) arrLocations;
-(NSArray *) friendFeedLocations;
@end
