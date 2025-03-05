//
//  CS_postedMessageDB.h
//  ChatSeal
//
//  Created by Francis Grolemund on 5/12/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CS_postedMessage.h"

//  NOTE:
//  - I obsessed with whether this should be stored on a per-feed basis for reliability, but decided that ultimately this
//    database is going to store a history of processing and probably should be central.
@class ChatSealMessageEntry;
@interface CS_postedMessageDB : NSObject
+(CS_postedMessageDB *) databaseFromURL:(NSURL *) u withError:(NSError **) err;

-(CS_postedMessage *) addPostedMessageForEntry:(ChatSealMessageEntry *) entry withError:(NSError **) err;
-(CS_postedMessage *) postedMessageForSafeEntryId:(NSString *) safeEntryId;
-(NSArray *) prepareSafeEntriesForMessageDeletion:(NSString *) messageId;
-(NSArray *) prepareSafeEntriesForSealInvalidation:(NSString *) sealId andReturningPostponed:(BOOL *) isPostponed;
-(NSArray *) safeEntriesForSealId:(NSString *) sealId;
-(void) fillPostedMessageProgressItems:(NSArray *) arr;
@end
