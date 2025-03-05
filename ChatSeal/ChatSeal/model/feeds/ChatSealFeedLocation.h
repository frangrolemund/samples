//
//  ChatSealFeedLocation.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/1/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


//  NOTE: The purpose of this object is to definitively describe a feed across network boundaries, as opposed
//        to just using a simple feed id which can track down one of my own locally.
@interface ChatSealFeedLocation : NSObject <NSCoding>
+(ChatSealFeedLocation *) locationForType:(NSString *) feedType andAccount:(NSString *) feedAccount;
@property (nonatomic, retain) NSString           *feedAccount;
@property (nonatomic, retain) NSString           *feedType;
@property (nonatomic, retain) NSObject<NSCoding> *customContext;  //  specific to each feed type.
@end
