//
//  CS_serviceHost.h
//  ChatSeal
//
//  Created by Francis Grolemund on 2/7/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CS_service;
@interface CS_serviceHost : NSObject
+(NSTimeInterval) hardnessInterval;
-(void) addService:(CS_service *) svc;
-(void) removeService:(CS_service *) svc;
-(CS_service *) bestServiceForConnection;
-(BOOL) isLocalHost;
-(BOOL) isNewUser;
-(NSUInteger) interfaceCount;
-(BOOL) hasWireless;
-(BOOL) hasBluetooth;
-(BOOL) isHardened;
@end
