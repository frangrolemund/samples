//
//  CS_secureTransferServer.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/22/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CS_secureTransferServer : NSObject
+(NSString *) secureProtocolName;

-(id) initWithService:(NSString *) service forSealId:(NSString *) sid;
-(BOOL) startSecureTransferWithError:(NSError **) err;
-(BOOL) isOnline;
-(void) stopAllSecureTransfer;
-(uint16_t) port;
-(NSURL *) secureURL;
-(BOOL) isSecureTransferInProgress;
+(BOOL) isValidSecureURL:(NSURL *) url;
-(void) setTransferHandlingPaused:(BOOL) isPaused;
@end
