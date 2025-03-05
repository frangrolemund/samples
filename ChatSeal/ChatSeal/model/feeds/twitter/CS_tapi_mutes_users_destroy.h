//
//  CS_tapi_mutes_users_destroy.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/30/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeedAPI.h"

@interface CS_tapi_mutes_users_destroy : CS_twitterFeedAPI
-(void) setTargetScreenName:(NSString *) screenName;
-(NSString *) targetScreenName;
@end
