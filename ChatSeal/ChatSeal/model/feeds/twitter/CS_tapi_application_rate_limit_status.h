//
//  CS_tapi_application_rate_limit_status.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/9/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeedAPI.h"

@interface CS_tapi_application_rate_limit_status : CS_twitterFeedAPI
-(void) setResources:(NSArray *) resourceNames;
@end
