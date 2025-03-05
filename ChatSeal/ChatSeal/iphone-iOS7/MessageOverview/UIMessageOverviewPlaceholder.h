//
//  UIMessageOverviewPlaceholder.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/9/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ChatSeal.h"

@class ChatSealMessage;
@interface UIMessageOverviewPlaceholder : NSObject <NSCoding>
+(UIMessageOverviewPlaceholder *) placeholderForMessage:(ChatSealMessage *) psm;
-(RSISecureSeal_Color_t) sealColor;
-(NSUInteger) lenAuthor;
-(NSUInteger) lenSynopsis;
-(BOOL) isAuthorMe;
-(BOOL) isRead;
-(BOOL) isLocked;
+(void) saveVaultMessagePlaceholderData;
+(NSArray *) vaultMessagePlaceholderData;
@end
