//
//  CS_twitterFeed_highPrio_friendValidate.h
//  ChatSeal
//
//  Created by Francis Grolemund on 9/1/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CS_twitterFeed_shared.h"

typedef void (^cs_tfhp_validateCompletion)(CS_tapi_user_looked_up *result);

@interface CS_twitterFeed_highPrio_friendValidate : NSObject <CS_twitterFeed_highPrio_task>
+(CS_twitterFeed_highPrio_friendValidate *) taskForFriend:(NSString *) myFriend withCompletion:(cs_tfhp_validateCompletion) completionBlock;
@end
