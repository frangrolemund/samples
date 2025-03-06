//
//  RSI_5_image_tests.h
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/1/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface RSI_5_image_tests : XCTestCase
{
    @private
    NSError *err;
}

+(UIImage *) loadImage:(NSString *) imgFile;

@end
