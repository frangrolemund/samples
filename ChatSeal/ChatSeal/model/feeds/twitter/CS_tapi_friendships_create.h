//
//  CS_tapi_friendships_create.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeedAPI.h"

@interface CS_tapi_friendships_create : CS_twitterFeedAPI
-(void) setTargetScreenName:(NSString *) screenName;
-(NSString *) targetScreenName;
-(BOOL) didFollowFailBecauseTheyBlockedMe;
@end
