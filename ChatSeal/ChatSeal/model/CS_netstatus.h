//
//  CS_netstatus.h
//  ChatSeal
//
//  Created by Francis Grolemund on 3/5/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CS_netstatus;
@protocol CS_netstatusDelegate <NSObject>
@optional
-(void) netStatusChanged:(CS_netstatus *) netStatus;
@end

@interface CS_netstatus : NSObject <CS_netstatusDelegate>
-(id) initForLocalWifiOnly:(BOOL) watchLocalWifi;
-(BOOL) startStatusQuery;
-(void) haltStatusQuery;
-(BOOL) hasConnectivity;

@property (nonatomic, assign) id<CS_netstatusDelegate> delegate;
@end
