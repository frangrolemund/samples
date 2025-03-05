//
//  CS_tapi_user_looked_up.h
//  ChatSeal
//
//  Created by Francis Grolemund on 8/31/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CS_tapi_user_looked_up : NSObject
+(CS_tapi_user_looked_up *) userFromTapiDictionary:(NSDictionary *) dict;
@property (nonatomic, retain) NSString *screenName;
@property (nonatomic, assign) BOOL isProtected;
@property (nonatomic, retain) NSString *fullName;
@property (nonatomic, retain) NSString *location;
@property (nonatomic, retain) NSString *sProfileImage;
@end
