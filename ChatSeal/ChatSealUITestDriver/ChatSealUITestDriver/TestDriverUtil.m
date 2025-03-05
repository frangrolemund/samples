//
//  TestDriverUtil.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 4/11/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <mach/mach_time.h>
#import "TestDriverUtil.h"

@implementation TestDriverUtil
/*
 *  Save a photo to the documents directory.
 */
+(void) saveJPGPhoto:(UIImage *) img asName:(NSString *) picName
{
    NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    u = [u URLByAppendingPathComponent:picName];
    
    NSData *d = UIImageJPEGRepresentation(img, 0.75f);
    if (!d || ![d writeToURL:u atomically:YES]) {
        NSLog(@"DEBUG: Failed to write the file.");
    }
}

/*
 *  Get a system absolute time value.
 */
+(uint64_t) absTime
{
    return (uint64_t) mach_absolute_time();
}

/*
 *  Convert a system absolute time into seconds.
 */
+(CGFloat) absTimeToSec:(uint64_t)abst
{
    static BOOL hasFreq = NO;
    static double frequency = 0.0f;
    
    if (!hasFreq) {
        // - mach time is a ratio describing the nanoseconds for each tick
        mach_timebase_info_data_t tbi;
        mach_timebase_info(&tbi);
        frequency = ((double) tbi.denom / (double) tbi.numer) * 1000000000.0f;
    }
    return ((double) abst/frequency);
}

@end
