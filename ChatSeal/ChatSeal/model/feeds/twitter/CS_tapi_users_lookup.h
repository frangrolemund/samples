//
//  CS_tapi_users_lookup.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/8/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeedAPI.h"
#import "CS_tapi_user_looked_up.h"

@interface CS_tapi_users_lookup : CS_twitterFeedAPI
+(NSUInteger) maxUsersPerRequest;
-(void) setScreenNames:(NSArray *) aNames;
-(NSArray *) screenNames;
-(NSArray *) resultDataUserDefinitions;
@end
