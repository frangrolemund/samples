//
//  TestDriverUtil.h
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 4/11/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TestDriverUtil : NSObject
+(void) saveJPGPhoto:(UIImage *) img asName:(NSString *) picName;
+(uint64_t) absTime;
+(CGFloat) absTimeToSec:(uint64_t) abst;
@end
