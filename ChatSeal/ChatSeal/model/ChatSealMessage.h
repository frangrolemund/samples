//
//  ChatSealMessage.h
//  ChatSeal
//
//  Created by Francis Grolemund on 2/15/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RealSecureImage/RealSecureImage.h"
#import "ChatSealMessageEntry.h"

//  - every message that is sent has a type to quickly
//    identify it.
typedef enum
{
    PSMT_GENERIC,               //  standard message with data.
    PSMT_REVOKE,                //  revoke the seal from anyone who reads this message
} ps_message_type_t;

typedef NSInteger psm_entry_id_t;

@class ChatSealIdentity;
@interface ChatSealMessage : NSObject
+(BOOL) destroyAllMessagesWithError:(NSError **) err;
+(NSString *) formattedMessageEntryDate:(NSDate *) dt andAbbreviateThisWeek:(BOOL) abbreviateThisWeek andExcludeRedundantYear:(BOOL) excludeYear;
+(void) permanentlyLockAllMessagesForSeal:(NSString *) sealId;
+(NSUInteger) countOfMessagesForSeal:(NSString *) sealId;
+(void) discardSealedMessageCache;
+(void) recacheMessagesForSeal:(RSISecureSeal *) ss;
+(void) recacheMessagesForSealId:(NSString *) sid;
+(NSString *) standardDisplayHeaderAuthorForMessage:(ChatSealMessage *) csm andEntry:(ChatSealMessageEntry *) me withActiveAuthorName:(NSString *) activeAuthor;

-(BOOL) hasSealWithError:(NSError **) err;
-(NSDate *) creationDate;
-(RSISecureSeal_Color_t) sealColor;
-(NSString *) author;
-(BOOL) isAuthorMe;
-(NSString *) synopsis;
-(BOOL) isNew;
-(BOOL) isRead;
-(BOOL) setIsRead:(BOOL) newIsRead withError:(NSError **) err;
-(UIImage *) sealTableImage;
-(BOOL) isLocked;
-(NSString *) sealId;
-(ChatSealIdentity *) identityWithError:(NSError **) err;
-(void) setIsBeingDisplayed;
-(NSIndexSet *) unreadItems;

-(NSURL *) messageDirectory;
-(NSString *) messageId;
-(ChatSealMessageEntry *) addNewEntryOfType:(ps_message_type_t) msgType withContents:(NSArray *) msgData onCreationDate:(NSDate *) dtCreated andError:(NSError **) err;
-(ChatSealMessageEntry *) addNewEntryOfType:(ps_message_type_t) msgType withContents:(NSArray *) msgData andDecoy:(UIImage *) decoy onCreationDate:(NSDate *) dtCreated andError:(NSError **) err;
-(ChatSealMessageEntry *) importRemoteEntryWithContents:(NSArray *) msgData asAuthor:(NSString *) author onCreationDate:(NSDate *) dtCreated withError:(NSError **) err;
-(NSInteger) numEntriesWithError:(NSError **) err;
-(ChatSealMessageEntry *) entryForIndex:(NSUInteger) idx withError:(NSError **) err;
-(ChatSealMessageEntry *) entryForId:(NSString *) entryId withError:(NSError **) err;
-(NSData *) sealedMessageForEntryId:(NSString *) entryId includingUserData:(NSObject *) objUser withError:(NSError **) err;
-(BOOL) destroyEntry:(ChatSealMessageEntry *) entry withError:(NSError **) err;
-(BOOL) destroyEntryAtIndex:(NSUInteger) idx withError:(NSError **) err;
-(BOOL) destroyMessageWithError:(NSError **) err;
-(BOOL) destroyNewMessageWithError:(NSError **) err;
-(BOOL) messageMatchesSearchCriteria:(NSString *) searchCriteria;
-(BOOL) pinSecureContent:(NSError **) err;
-(void) unpinSecureContent;
-(BOOL) verifyMessageStructureWithError:(NSError **) err;
-(psm_entry_id_t) filterAwareEntryIdForIndex:(NSUInteger) idx;
-(NSInteger) indexForFilterAwareEntryId:(psm_entry_id_t) entryId;
-(void) applyFilter:(NSString *) searchFilter;
-(BOOL) performBlockUnderMessageLock:(BOOL (^)(NSError **err)) messageProtectedBlock withError:(NSError **) err;
-(void) setDefaultFeedForMessage:(NSString *) feedId;
-(NSString *) defaultFeedForMessage;
@end