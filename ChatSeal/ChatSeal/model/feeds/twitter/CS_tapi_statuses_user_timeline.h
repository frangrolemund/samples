//
//  CS_tapi_statuses_user_timeline.h
//  ChatSeal
//
//  Created by Francis Grolemund on 8/6/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tapi_statuses_timeline_base.h"

@interface CS_tapi_statuses_user_timeline : CS_tapi_statuses_timeline_base
-(void) setScreenName:(NSString *) screenName;
-(NSString *) screenName;
@end
