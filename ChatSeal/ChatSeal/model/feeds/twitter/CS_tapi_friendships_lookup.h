//
//  CS_tapi_friendships_lookup.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/10/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeedAPI.h"
#import "CS_tapi_friendship_state.h"

@interface CS_tapi_friendships_lookup : CS_twitterFeedAPI
+(NSUInteger) maxUsersPerRequest;
-(void) setScreenNames:(NSArray *) aNames;
-(NSDictionary *) friendResultMasks;
@end
