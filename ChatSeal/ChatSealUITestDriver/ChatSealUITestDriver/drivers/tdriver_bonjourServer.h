//
//  tdriver_bonjourServer.h
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 12/9/14.
//  Copyright (c) 2014 Francis Grolemund. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface tdriver_bonjourServer : NSObject
-(id) initWithServiceName:(NSString *) name;
-(void) close;
@end
