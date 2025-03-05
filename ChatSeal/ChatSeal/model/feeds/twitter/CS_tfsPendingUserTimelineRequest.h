//
//  CS_tfsPendingUserTimelineRequest.h
//  ChatSeal
//
//  Created by Francis Grolemund on 8/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CS_tapi_tweetRange;
@interface CS_tfsPendingUserTimelineRequest : NSObject
+(CS_tfsPendingUserTimelineRequest *) requestForScreenName:(NSString *) screenName andRange:(CS_tapi_tweetRange *) range fromLocalUser:(NSString *) localUser;

@property (nonatomic, readonly) NSString           *screenName;
@property (nonatomic, readonly) CS_tapi_tweetRange *requestedRange;
@property (nonatomic, readonly) NSString           *localUser;
@end
