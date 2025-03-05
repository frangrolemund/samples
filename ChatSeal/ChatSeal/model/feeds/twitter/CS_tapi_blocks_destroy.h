//
//  CS_tapi_blocks_destroy.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/29/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeedAPI.h"

@interface CS_tapi_blocks_destroy : CS_twitterFeedAPI
-(void) setTargetScreenName:(NSString *) screenName;
-(NSString *) targetScreenName;
@end
