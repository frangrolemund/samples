//
//  CS_serviceRadar.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/20/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CS_service : NSObject
-(BOOL)       isLocal;
-(BOOL)       isNewUser;
-(BOOL)       isBluetooth;
-(uint32_t)   interfaceIndex;
-(NSString *) serviceName;
-(NSString *) regType;
-(NSString *) replyDomain;
-(NSDate *) browseDate;
-(void) setBrowseDate:(NSDate *) dt;
@end

@class CS_serviceRadar;
@protocol CS_serviceRadarDelegate <NSObject>
@optional
-(void) radar:(CS_serviceRadar *) radar serviceAdded:(CS_service *) service;
-(void) radar:(CS_serviceRadar *) radar serviceRemoved:(CS_service *) service;
-(void) radar:(CS_serviceRadar *) radar failedWithError:(NSError *) err;
@end

// - I have this implementing its own delegate protocol as a way to make it easy to
//   extend this class later, if I choose to.  This sort of standardizes the
//   delegate handling also, which is an added benefit.
@interface CS_serviceRadar : NSObject <CS_serviceRadarDelegate>
+(NSUInteger) servicePrefixLength;
+(NSString *) servicePrefixHasVault;
+(NSString *) servicePrefixNewUser;
-(BOOL) beginScanningWithError:(NSError **) err;
-(void) stopScanning;
-(BOOL) isOnline;

@property (nonatomic, assign) id<CS_serviceRadarDelegate> delegate;
@end
