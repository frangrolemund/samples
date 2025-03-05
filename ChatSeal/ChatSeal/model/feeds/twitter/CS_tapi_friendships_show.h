//
//  CS_tapi_friendships_show.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeedAPI.h"
#import "CS_tapi_friendship_state.h"

@interface CS_tapi_friendships_show : CS_twitterFeedAPI
-(void) setSourceScreenName:(NSString *) screenName;
-(void) setTargetScreenName:(NSString *) screenName;
-(NSString *) targetScreenName;
-(CS_tapi_friendship_state *) resultTargetState;
@end
