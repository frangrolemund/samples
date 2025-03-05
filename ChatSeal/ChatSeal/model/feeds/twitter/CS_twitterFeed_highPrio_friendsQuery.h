//
//  CS_twitterFeed_highPrio_friendsQuery.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/26/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CS_twitterFeed_shared.h"

@interface CS_twitterFeed_highPrio_friendsQuery : NSObject  <CS_twitterFeed_highPrio_task>
+(CS_twitterFeed_highPrio_friendsQuery *) taskForFriends:(NSArray *) arrFriends;
@end
