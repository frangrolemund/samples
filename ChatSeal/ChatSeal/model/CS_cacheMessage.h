//
//  CS_cacheMessage.h
//  ChatSeal
//
//  Created by Francis Grolemund on 10/23/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ChatSeal.h"
#import "CS_cacheSeal.h"

@interface CS_cacheMessage : NSObject
+(void) releaseAllCachedContent;
+(NSArray *) messageList;
+(NSUInteger) messageCount;
+(NSArray *) messageItemList;
+(CS_cacheMessage *) messageForId:(NSString *) mid;
+(void) markMessageEntryAsProcessed:(NSString *) entryId withHash:(NSString *) msgHash;
+(NSString *) processedMessageEntryForHash:(NSString *) msgHash;
+(BOOL) hasProcessedMessageEntry:(NSString *) entryId;
+(void) discardProcessedMessageEntry:(NSString *) entryId;
+(UIImage *) imagePlaceholderForBase:(NSString *) baseName andMessage:(NSString *) mid usingSeal:(RSISecureSeal *) seal;
+(void) saveImage:(UIImage *) img asPlaceholderForBase:(NSString *) baseName andMessage:(NSString *) mid usingSeal:(RSISecureSeal *) seal;
+(void) discardPlaceholderForBase:(NSString *) baseName andMessage:(NSString *) mid;

-(NSString *) messageId;
-(CS_cacheSeal *) seal;
-(NSDate *) dateCreated;
-(NSString *) synopsis;
-(NSString *) indexSalt;
-(BOOL) isRead;
-(NSString *) author;
-(NSString *) defaultFeed;
@end
