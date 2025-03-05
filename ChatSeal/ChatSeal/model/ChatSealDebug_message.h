//
//  ChatSealDebug_message.h
//  ChatSeal
//
//  Created by Francis Grolemund on 11/15/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ChatSealMessage;
@interface ChatSealDebug_message : NSObject
+(void) appendRandomContentToMessage:(ChatSealMessage *) psm withNumberOfItems:(NSUInteger) numItems;
+(void) destructivelyVerifyMessagingInfrastructure;
@end
