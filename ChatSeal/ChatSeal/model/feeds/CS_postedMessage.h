//
//  CS_postedMessage.h
//  ChatSeal
//
//  Created by Francis Grolemund on 5/12/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ChatSealMessageEntry;
@interface CS_postedMessage : NSObject
+(CS_postedMessage *) postedMessageForEntry:(ChatSealMessageEntry *) entry withError:(NSError **) err;

-(NSString *) safeEntryId;
-(NSString *) entryId;
-(NSString *) messageId;
-(NSString *) sealId;
-(BOOL) isSealOwned;
@end
