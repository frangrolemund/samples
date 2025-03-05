//
//  CS_tapi_users_show.h
//  ChatSeal
//
//  Created by Francis Grolemund on 8/30/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeedAPI.h"
#import "CS_tapi_user_looked_up.h"

@interface CS_tapi_users_show : CS_twitterFeedAPI
-(void) setScreenName:(NSString *) name;
-(NSString *) screenName;
-(CS_tapi_user_looked_up *) resultDataAsUserInfo;
@end
