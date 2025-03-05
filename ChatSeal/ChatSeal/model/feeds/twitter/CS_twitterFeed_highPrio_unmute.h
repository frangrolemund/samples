//
//  CS_twitterFeed_highPrio_unmute.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/30/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CS_twitterFeed_shared.h"

@interface CS_twitterFeed_highPrio_unmute : NSObject <CS_twitterFeed_highPrioPersist_task>
+(CS_twitterFeed_highPrio_unmute *) taskForFriend:(NSString *) myFriend;
@end
