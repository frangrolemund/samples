//
//  CS_serviceResolved.h
//  ChatSeal
//
//  Created by Francis Grolemund on 2/10/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CS_serviceResolved;
@protocol CS_serviceResolvedDelegate <NSObject>
@optional
-(void) serviceResolutionSucceeded:(CS_serviceResolved *) resolve;
-(void) serviceResolutionFailed:(CS_serviceResolved *) resolve withError:(NSError *) err;
@end

@interface CS_serviceResolved : NSObject <CS_serviceResolvedDelegate>
+(CS_serviceResolved *) resolveWithService:(NSString *) name andRegType:(NSString *) regType andDomain:(NSString *) domain asBluetooth:(BOOL) blueTooth
                                  withIndex:(uint32_t) index;
-(id) initWithService:(NSString *) name andRegType:(NSString *) regType andDomain:(NSString *) domain asBluetooth:(BOOL) blueTooth withIndex:(uint32_t) index;
-(BOOL) beginResolutionWithError:(NSError **) err;
-(void) stopResolution;

-(NSString *) serviceName;
-(NSString *) serviceRegType;
-(NSString *) serviceDomain;
-(NSString *) serviceHost;
-(uint16_t) servicePort;
-(uint32_t) interfaceIndex;
-(BOOL) isBluetooth;

@property (nonatomic, assign) id<CS_serviceResolvedDelegate> delegate;
@end
