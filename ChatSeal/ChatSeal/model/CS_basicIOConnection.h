//
//  CS_basicIOConnection.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/23/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CS_basicIOConnection;
@protocol CS_basicIOConnectionDelegate <NSObject>
@optional
-(void) basicConnectionConnected:(CS_basicIOConnection *) ioConn;
-(void) basicConnectionDataRecvProgress:(CS_basicIOConnection *) ioConn ofPct:(NSNumber *) pctComplete;
-(void) basicConnectionDataSendProgress:(CS_basicIOConnection *) ioConn ofPct:(NSNumber *) pctComplete;
-(void) basicConnectionHasData:(CS_basicIOConnection *) ioConn;
-(void) basicConnectionFailed:(CS_basicIOConnection *) ioConn;
-(void) basicConnectionDisconnected:(CS_basicIOConnection *) ioConn;
@end

// - I have this implementing its own delegate protocol as a way to make it easy to
//   extend this class later, if I choose to.  This sort of standardizes the
//   delegate handling also, which is an added benefit.
@class CS_service;
@interface CS_basicIOConnection : NSObject <CS_basicIOConnectionDelegate>
+(NSUInteger) ioBlockSize;
+(NSUInteger) maximumPayload;
-(id) initWithConnectionToService:(CS_service *) svc;
-(id) initWithSocket:(int) fd;
-(id) initLocalConnectionWithPort:(uint16_t) localPort;
-(BOOL) connectWithError:(NSError **) err;
-(NSTimeInterval) timeIntervalSinceConnection;
-(BOOL) sendData:(NSData *) d withError:(NSError **) err;
-(BOOL) hasDataForRead;
-(BOOL) hasPendingIO;
-(BOOL) isConnectionOKWithError:(NSError **) err;
-(NSData *) checkForDataWithError:(NSError **) err;
-(void) disconnect;
-(BOOL) isConnected;

@property (nonatomic, assign) id<CS_basicIOConnectionDelegate> delegate;
@end
