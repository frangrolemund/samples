//
//  tdriver_bonjourClient.h
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 12/10/14.
//  Copyright (c) 2014 Francis Grolemund. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CS_serviceRadar.h"

@class tdriver_bonjourClient;
@protocol tdriver_bonjourClientDelegate <NSObject>
-(void) testingCompletedWithClient:(tdriver_bonjourClient *) client;
@end

@interface tdriver_bonjourClient : NSObject
+(NSData *) sampleDataPayload;
+(BOOL) isPayloadValid:(NSData *) d;
-(id) initWithService:(CS_service *) svc andDelegate:(id<tdriver_bonjourClientDelegate>) d;
-(void) runTests;
-(void) stopTests;
@end
