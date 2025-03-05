//
//  CS_sealRequestPayload.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/23/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CS_secureSealTransferPayload : NSObject
@property (nonatomic, retain) NSData   *sealData;
@property (nonatomic, retain) NSString *sealOwner;
@property (nonatomic, retain) NSArray  *sealOwnerFeeds;
@end

@interface CS_securePayload : NSObject
+(NSData *) sealRequestPayloadForSecureURL:(NSURL *) u withError:(NSError **) err;
+(BOOL) isSealRequestPayload:(NSData *) payload validForURL:(NSURL *) u;
+(NSString *) commonExportKey;
+(NSData *) sealTransferPayloadForSealId:(NSString *) sid withError:(NSError **) err;
+(CS_secureSealTransferPayload *) parseSealTransferPayload:(NSData *) payload withError:(NSError **) err;
+(NSData *) sealReceiptPayloadForSecureURL:(NSURL *) u andReplyAsNew:(BOOL) isNewSeal withError:(NSError **) err;
+(BOOL) isSealReceiptPayload:(NSData *) payload validForURL:(NSURL *) u returningIsNew:(BOOL *) isNewSeal andRequestorFeeds:(NSArray **) reqFeeds;
@end
