//
//  CS_secureConnection.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/23/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CS_basicIOConnection.h"

@class CS_secureConnection;
@protocol CS_secureConnectionDelegate <NSObject>
@optional
-(void) secureConnectionConnected:(CS_secureConnection *) ioConn;
-(void) secureConnectionDataRecvProgress:(CS_secureConnection *) ioConn ofPct:(NSNumber *) pctComplete;
-(void) secureConnectionDataSendProgress:(CS_secureConnection *) ioConn ofPct:(NSNumber *) pctComplete;
-(void) secureConnectionHasData:(CS_secureConnection *) ioConn;
-(void) secureConnectionFailed:(CS_secureConnection *) ioConn;
-(void) secureConnectionDisconnected:(CS_secureConnection *) ioConn;
@end

// - I have this implementing its own delegate protocol as a way to make it easy to
//   extend this class later, if I choose to.  This sort of standardizes the
//   delegate handling also, which is an added benefit.
@interface CS_secureConnection : NSObject <CS_secureConnectionDelegate>
-(NSTimeInterval) timeIntervalSinceConnection;
-(BOOL) connectWithError:(NSError **) err;
-(BOOL) isConnectionOKWithError:(NSError **) err;
-(BOOL) sendData:(NSData *) d withError:(NSError **) err;
-(BOOL) hasDataForRead;
-(BOOL) hasPendingIO;
-(NSData *) checkForDataWithError:(NSError **) err;
-(BOOL) isConnected;
-(void) disconnect;

@property (nonatomic, assign) id<CS_secureConnectionDelegate> delegate;
@end
