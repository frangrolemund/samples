//
//  CS_tapi_account_verify_credentials.h
//  ChatSeal
//
//  Created by Francis Grolemund on 8/12/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twitterFeedAPI.h"

@interface CS_tapi_account_verify_credentials : CS_twitterFeedAPI
-(void) parseNumericIdStr:(NSString **) numericIdStr andFriendsCount:(NSNumber **) friendsCount;
@end
