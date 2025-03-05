//
//  ChatSealFeed.h
//  ChatSeal
//
//  Created by Francis Grolemund on 3/24/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ChatSealFeedProgress.h"
#import "ChatSealPostedMessageProgress.h"
#import "ChatSealFeedLocation.h"

// - the core feed class
@class ChatSealFeedCollector;
@class UIFormattedFeedAddressView;
@class ChatSealMessageEntry;
@class ChatSealFeedType;
@interface ChatSealFeed : NSObject
+(NSDictionary *) configurationsForFeedsOfType:(NSString *) feedType withError:(NSError **) err;
+(void) openFeedAccessGateToAPIsToCurrentThread;
+(void) closeFeedAccessGateToAPIsToCurrentThread;
+(CGFloat) standardFontHeightForSelection;
+(NSString *) standardMiningFilename;
-(NSString *) typeId;
-(ChatSealFeedType *) feedType;
-(NSString *) feedId;
-(BOOL) setEnabled:(BOOL) enabled withError:(NSError **) err;
-(NSString *) userId;
-(ChatSealFeedLocation *) locationWhenUsingSeal:(NSString *) sid;
-(ChatSealFeedCollector *) collector;
-(NSString *) typeDescription;
-(NSString *) displayName;
-(NSString *) statusText;
-(NSString *) correctiveText;
-(BOOL) isInWarningState;
-(NSUInteger) numberOfMessagesProcessed;
-(NSUInteger) numberOfMessagesReceived;
-(ChatSealFeedProgress *) currentFeedProgress;
-(BOOL) isValid;
-(BOOL) isEnabled;
-(BOOL) isAuthorized;
-(BOOL) isPasswordValid;
-(BOOL) isViableMessagingTarget;
-(BOOL) isFeedServiceThrottled;
-(BOOL) isDeleted;
-(UIFormattedFeedAddressView *) addressView;
-(BOOL) postMessage:(ChatSealMessageEntry *) entry withError:(NSError **) err;
-(NSArray *) currentPostingProgress;
-(void) setPendingPostProcessingEnabled:(BOOL) enabled;
-(ChatSealPostedMessageProgress *) updatedProgressForSafeEntryId:(NSString *) safeId;
-(void) deletePendingPostForSafeEntryId:(NSString *) safeId;
-(NSString *) localizedMessagesExchangedText;
@end
