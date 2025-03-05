//
//  ChatSealVaultPlaceholder.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/14/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <RealSecureImage/RealSecureImage.h>

@class ChatSealIdentity;
@interface ChatSealVaultPlaceholder : NSObject <NSCoding>
+(ChatSealVaultPlaceholder *) placeholderForIdentity:(ChatSealIdentity *) identity;
+(void) saveVaultSealPlaceholderData;
+(NSArray *) vaultSealPlaceholderData;

-(BOOL) isMine;
-(BOOL) isActive;
-(RSISecureSeal_Color_t) sealColor;
-(NSUInteger) lenOwner;
-(NSUInteger) lenStatus;
-(BOOL) isWarnStatus;
@end

