//
//  CS_basicServer.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CS_basicServer;
@class CS_basicIOConnection;
@protocol CS_basicServerDelegate <NSObject>
@optional
-(BOOL) shouldCheckForNewConnectionsInServer:(CS_basicServer *) server;
-(BOOL) shouldAllowConnectionFromClientInServer:(CS_basicServer *) server;
-(void) connectionReceived:(CS_basicIOConnection *) conn inServer:(CS_basicServer *) server;
-(void) acceptProcessingCompletedInServer:(CS_basicServer *) server;
@end

// - I have this implementing its own delegate protocol as a way to make it easy to
//   extend this class later, if I choose to.  This sort of standardizes the
//   delegate handling also, which is an added benefit.
@interface CS_basicServer : NSObject <CS_basicServerDelegate>
-(id) initWithPort:(uint16_t) port;
-(BOOL) startServerWithError:(NSError **) err;
-(uint16_t) serverPort;
-(void) stopServer;

@property (nonatomic, assign) id<CS_basicServerDelegate> delegate;
@end
