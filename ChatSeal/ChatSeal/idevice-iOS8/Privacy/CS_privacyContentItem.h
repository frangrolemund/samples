//
//  CS_privacyContentItem.h
//  ChatSeal
//
//  Created by Francis Grolemund on 12/3/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CS_privacyContentItem : NSObject
+(CS_privacyContentItem *) privacyContentWithTitle:(NSString *) title andDescription:(NSString *) desc;
-(NSString *) title;
-(NSString *) desc;
@end
