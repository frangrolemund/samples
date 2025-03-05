//
//  CS_feedCollectorUtil.h
//  ChatSeal
//
//  Created by Francis Grolemund on 3/27/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CS_feedCollectorUtil : NSObject
+(BOOL) secureSaveConfiguration:(NSDictionary *) dict asFile:(NSURL *) url withError:(NSError **) err;
+(NSDictionary *) secureLoadConfigurationFromFile:(NSURL *) url withError:(NSError **) err;
@end
