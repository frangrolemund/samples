//
//  CS_twmFeedOwner_miningStats.h
//  ChatSeal
//
//  Created by Francis Grolemund on 8/8/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_twmGenericUser_miningStats.h"

@interface CS_twmFeedOwner_miningStats : CS_twmGenericUser_miningStats
-(BOOL) performMiningRequestsUsingFeed:(CS_twitterFeed *)feed asForwardRequest:(BOOL) isForward;
@end
