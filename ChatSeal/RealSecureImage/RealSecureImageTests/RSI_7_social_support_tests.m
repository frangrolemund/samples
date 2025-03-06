//
//  RSI_7_social_support_tests.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/14/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "RSI_7_social_support_tests.h"
#import "RSI_5_image_tests.h"
#import "RealSecureImage.h"
#import "RSI_common.h"

@implementation RSI_7_social_support_tests

/*
 *  Simple prep between tests.
 */
-(void) setUp
{
    [super setUp];    
    err = nil;
    self.continueAfterFailure = NO;    
}

/*
 *  Return the data to use for embedding testing.
 */
-(NSData *) testData
{
    const char *lorem = "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";
    return [NSData dataWithBytes:lorem length:strlen(lorem)+1];
}

/*
 *  Return the filename of the test file
 */
-(NSURL *) testFileName
{
    NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    u = [u URLByAppendingPathComponent:@"rp-social-test.png"];
    return u;
}

/*
 *  Export a file to disk with embedded content.
 */
-(void) testUTSOCIAL_1_Export
{
    NSLog(@"UT-SOCIAL: - exporting a sample file to the filesystem with embedded data.");
    
    UIImage *img = [RSI_5_image_tests loadImage:@"IMG_0236.JPG"];
    XCTAssertNotNil(img, @"Failed to load the test image.");
    
    NSLog(@"UT-SOCIAL: - scaling the source image.");    
    CGSize sz = img.size;
    CGFloat pct = 200.0f / sz.width;
    sz.width = 200.0f;
    sz.height = sz.height * pct;
    UIGraphicsBeginImageContext(sz);
    [img drawInRect:CGRectMake(0.0f, 0.0f, sz.width, sz.height)];
    img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    NSData *dTest = [self testData];
    
    NSLog(@"UT-SOCIAL: - creating the embedded PNG.");
    NSData *dEmbedded = [RealSecureImage packedPNG:img andData:dTest andError:&err];
    XCTAssertNotNil(dEmbedded, @"Failed to embed the data in the test image.");
    
    NSLog(@"UT-SOCIAL: - writing the embedded PNG.");
    NSURL *uFile = [self testFileName];
    
    BOOL ret = [dEmbedded writeToURL:uFile atomically:YES];
    XCTAssertTrue(ret, @"Failed to write the embedded file to disk.");

    NSLog(@"UT-SOCIAL: - the embedded sample file has been created successfully.");
}

/*
 *  Import an on-disk file with embedded content and verify the data is accurate.
 */
-(void) testUTSOCIAL_2_Import
{
    NSLog(@"UT-SOCIAL: - importing a sample file from the filesystem with embedded data.");
    
    NSURL *uFile = [self testFileName];
    NSData *dFile = [NSData dataWithContentsOfURL:uFile];
    XCTAssertNotNil(dFile, @"Failed to load the file.");
 
    NSLog(@"UT-SOCIAL: - unpacking its contents.");
    NSData *dEmbedded = [RealSecureImage unpackData:dFile withMaxLength:0 andError:&err];
    XCTAssertNotNil(dEmbedded, @"Failed to unpack the source file.");
    
    NSLog(@"UT-SOCIAL: - verifying its contents.");
    NSData *dSecret = [self testData];
    
    XCTAssertTrue([dEmbedded length] >= [dSecret length], @"Failed to find the required length of data in the file.");
    
    int ret = memcmp(dEmbedded.bytes, dSecret.bytes, [dSecret length]);
    XCTAssertTrue(ret == 0, @"Data comparison failed.");
    
    NSData *dSubset = [NSData dataWithBytes:dEmbedded.bytes length:[dSecret length]];
    [RSI_common printBytes:dSubset withTitle:@"UT-SOCIAL: - hidden message"];
    
    NSLog(@"UT-SOCIAL: - the embedded data was located successfully.");
}

@end
