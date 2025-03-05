//
//  UIFeedsOverviewPlaceholder.h
//  ChatSeal
//
//  Created by Francis Grolemund on 6/27/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UIFeedsOverviewPlaceholder : NSObject <NSCoding>
-(NSUInteger) lenName;
-(NSUInteger) lenExchanged;
+(void) saveFeedPlaceholderData;
+(NSArray *) feedPlaceholderData;
@end
