//
//  CS_serviceRegistrationV2.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/20/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CS_serviceRegistrationV2;
@protocol CS_serviceRegistrationV2Delegate <NSObject>
@optional
-(void) serviceRegistrationCompleted:(CS_serviceRegistrationV2 *) service;
-(void) serviceRegistrationFailed:(CS_serviceRegistrationV2 *) service;
@end

@interface CS_serviceRegistrationV2 : NSObject
+(const char *) serviceRegType;

-(id) initWithService:(NSString *) svc andPort:(uint16_t) port;
-(BOOL) registerWithError:(NSError **) err;
-(NSString *) serviceName;
-(NSString *) dnsVerifiedServiceName;
-(BOOL) isOnline;
-(int32_t) lastDNSError;

@property (nonatomic, assign) id<CS_serviceRegistrationV2Delegate> delegate;
@end
