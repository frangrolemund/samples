//
//  CS_twitterFeed_highPrio_follow.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CS_twitterFeed_shared.h"

@interface CS_twitterFeed_highPrio_follow : NSObject <CS_twitterFeed_highPrioPersist_task>
+(CS_twitterFeed_highPrio_follow *) taskForFriend:(NSString *) myFriend;
@end
