//
//  CS_messageShared.h
//  ChatSeal
//
//  Created by Francis Grolemund on 5/14/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.

#import <Foundation/Foundation.h>

#import "ChatSealMessage.h"
#import "ChatSealMessageEntry.h"
#import "CS_messageEntryExport.h"

extern NSString *PSM_GENERIC_KEY;
extern NSString *PSM_MSGID_KEY;
extern NSString *PSM_MSGITEMS_KEY;
extern NSString *PSM_OWNER_KEY;
extern NSString *PSM_CRDATE_KEY;
extern NSString *PSM_ENTRYID_KEY;
extern NSString *PSM_PARENT_KEY;
extern NSString *PSM_REVOKE_KEY;
extern NSString *PSM_ISREAD_KEY;
extern NSString *PSM_IMGMETRICS_KEY;
extern NSString *PSM_USERDATA_KEY;

extern const uint32_t PSM_FLAG_ISREAD;
extern const uint32_t PSM_FLAG_REVOKE;
extern const uint32_t PSM_FLAG_SEALOWNER;

extern const uint32_t PSM_SIG_ENTRY;

@interface ChatSealMessage (shared)
+(NSURL *) decoyFileForMessageDirectory:(NSURL *) msgDir;
+(NSURL *) fileForSecureImageIndex:(int32_t) idx inDirectory:(NSURL *) uDir;
@end

// - allow for safe usage of the message buffer by the entries
//   and to handle synchronization between multiple threads.
@interface CS_messageEdition : NSObject
-(void) lock;
-(void) unlock;

-(void) incrementEdition;
-(NSInteger) currentEdition;
-(BOOL) isEqualToEdition:(NSInteger) edition;
@end

// - coordinate between the message and the entry
@interface ChatSealMessageEntry (internal)
-(id) initWithMessage:(NSString *) message inDirectory:(NSURL *) dir andSeal:(RSISecureSeal *) s andData:(void *) entry usingLock:(CS_messageEdition *) msgLock;
-(void) assignCreationEditionFromLock;
-(NSUUID *) entryUUID;
-(void) setMessageId:(NSString *) messageId;
-(void) setEntryId:(NSUUID *) entryId;
-(NSUUID *) parentId;
-(void) setParentId:(NSUUID *) parentId;
-(void) setItems:(NSArray *) arrItems;
-(void) setAuthor:(NSString *) author;
-(void) setCreationDate:(NSDate *) createDate;
-(void) markForSealRevocation;
-(void) setIsRead:(BOOL) isRead;
-(NSMutableDictionary *) sealedMessageDictionary;
-(CGFloat) placeholderScaleForImageSize:(CGSize) szImage;
-(void) measureImageForUIMetricsAtIndex:(NSUInteger) idx;
+(BOOL) saveSecureImage:(UIImage *) img toURL:(NSURL *) uFile withSeal:(RSISecureSeal *) seal andError:(NSError **) err;
-(BOOL) convertToSecureImageAtIndex:(NSUInteger) idx toLink:(int32_t) linkIndex withError:(NSError **) err;
+(void) appendBytes:(const void *) bytes ofLength:(NSUInteger) len ontoData:(NSMutableData *) mdBuffer;
-(NSData *) convertNewEntryToBuffer;
-(unsigned char *) pEntryId;
-(unsigned char *) pParentId;
-(unsigned char *) pCreateDate;
-(unsigned char *) pAuthor;
-(unsigned char *) pFlags;
-(unsigned char *) pNumItems;
-(unsigned char *) pItems;
-(unsigned char *) pItemAtIndex:(NSUInteger) idx withError:(NSError **) err;
+(NSUUID *) entryIdForData:(const unsigned char *) ptr;
-(void) clearEntry;
-(const char *) UTF8StringItemAtIndex:(NSUInteger) idx;
-(id) linkedItemAtIndex:(NSUInteger) idx withError:(NSError **) err;
-(void) setAlternateDecoy:(UIImage *) altDecoy;
-(UIImage *) alternateDecoyWithError:(NSError **) err;
-(NSURL *) alternateDecoyURL;
-(BOOL) saveAlternateDecoyIfPresentWithError:(NSError **) err;
-(void) destroyAlternateDecoyFileIfPresent;
+(UIImage *) loadSecureImage:(NSURL *) uFile withSeal:(RSISecureSeal *) seal andError:(NSError **) err;
-(void) discardEntryPlaceholders;
+(NSURL *) sealedMessageCacheWithCreationIfNotExist:(BOOL) doCreate;
-(NSURL *) sealedMessageEntryURL;
+(void) saveSealedMessageEntry:(NSData *) dMsg intoURL:(NSURL *) uEntry;
+(BOOL) entryAtLocation:(void *) entry isEqualToUUID:(uuid_t *) rawUUID;
-(CS_messageEntryExport *) exportEntryWithError:(NSError **) err;
+(NSData *) buildSealedMessageFromExportedEntry:(CS_messageEntryExport *) ee withError:(NSError **) err;
@end
