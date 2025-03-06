    //
//  RSI_5_image_tests.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/1/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>
#import "RSI_5_image_tests.h"
#import "RealSecureImage.h"
#import "ImageLoader.h"
#import "RSI_pack.h"
#import "RSI_unpack.h"

#include "png.h"


//  - these functions are used to write PNG content to memory instead of disk
static void RSI_png_write(png_structp png_ptr, png_bytep data, png_size_t len)
{
    NSMutableData *mdOutput = (NSMutableData *) png_get_io_ptr(png_ptr);
    [mdOutput appendBytes:data length:len];
}

static void RSI_png_flush(png_structp png_ptr)
{
    //  - just a dummy function to satsify the call
}

/********************************
 RSI_5_image_tests
 ********************************/
@implementation RSI_5_image_tests

/*
 *  Simple cleanup between tests.
 */
-(void) setUp
{
    [super setUp];    
    err = nil;
    self.continueAfterFailure = NO;
}

/*
 *  Load the specified image.
 */
+(UIImage *) loadImage:(NSString *) imgFile
{
    NSArray *arr = [NSBundle allBundles];
    if (!arr) {
        NSLog(@"Failed to find a list of bundles in the test app.");
        return nil;
    }
    
    NSRange r = [imgFile rangeOfString:@"."];
    if (r.location == NSNotFound) {
        NSLog(@"Failed to find an extension in the image string %@.", imgFile);
        return nil;
    }
    
    NSString *base = [imgFile substringToIndex:r.location];
    NSString *ext = [imgFile substringFromIndex:r.location];
    
    for (int i = 0; i < [arr count]; i++) {
        NSBundle *b = [arr objectAtIndex:i];
        
        NSURL *u = [b URLForResource:base withExtension:ext];
        if (u) {
            UIImage *img = [UIImage imageWithContentsOfFile:[u path]];
            if (!img) {
                NSLog(@"Failed to load the image file from a known bundle location.");
                return nil;
            }
            return img;
        }
    }
    
    NSLog(@"Failed to load the image %@", imgFile);
    return nil;
}

/*
 *  Retrieve the container image data.
 */
-(UIImage *) loadContainerImage:(NSString *) container
{
    NSLog(@"UT-IMAGE: - loading the container image");
    
    UIImage *img = [RSI_5_image_tests loadImage:container];
    XCTAssertNotNil(img, @"Failed to load the container image %@.", container);
    
    NSUInteger maxB = [RealSecureImage maxDataForJPEGImage:img];
    XCTAssertTrue(maxB != 0, @"The container cannot store any data.");
    
    NSLog(@"UT-IMAGE: - the container can embed up to %u bytes", maxB);
    
    return img;
}

/*
 *  Retrieve the data for the internal image.
 */
-(NSData *) dataForHiddenImage:(NSString *) secret
{
    NSLog(@"UT-IMAGE: - loading the secret image's data.");

    UIImage *imgSecret = [RSI_5_image_tests loadImage:secret];
    XCTAssertNotNil(imgSecret, @"Failed to load the secret image.");
    
    NSData *d = UIImageJPEGRepresentation(imgSecret, 0.35f);
    XCTAssertNotNil(d, @"Failed to convert the image into a JPEG.");
    XCTAssertTrue([d length] > 0, @"The secret image had no content.");

    NSLog(@"UT-IMAGE: - the secret image is %u bytes long.", [d length]);
    
    return d;
}

/*
 *  Produce a packed image.
 */
-(NSData *) packImage:(UIImage *) img withData:(NSData *) d andAsJPEG:(BOOL) useJPEG
{
    NSLog(@"UT-IMAGE: - packing the container with the hidden data (%s).", useJPEG ? "JPEG" : "PNG");
    
    uint32_t len = (uint32_t) [d length];
    unsigned char buf[4];
    buf[0] = ((len >> 24) & 0xFF);
    buf[1] = ((len >> 16) & 0xFF);
    buf[2] = ((len >> 8) & 0xFF);
    buf[3] = (len & 0xFF);
    
    NSMutableData *md = [[NSMutableData alloc] initWithCapacity:[d length] + 4];
    [md appendBytes:buf length:4];
    [md appendData:d];
    NSData *packedData = nil;
    if (useJPEG) {
        packedData = [RealSecureImage packedJPEG:img withQuality:0.65 andData:md andError:&err];
    }
    else {
        packedData = [RealSecureImage packedPNG:img andData:md andError:&err];
    }
    [md release];
    XCTAssertNotNil(packedData, @"Failed to pack the input image into a %s.  %@  (Reason: %@)", useJPEG ? "JPEG" : "PNG", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-IMAGE: - The packed image is %u bytes long", [packedData length]);
    return packedData;
}


/*
 *  Save the packed image to disk and reload it to ensure the state is clean
 */
-(NSData *) saveAndReloadPackedImage:(NSData *) packedData withName:(NSString *) fname
{
    NSLog(@"UT-IMAGE: - saving the image to disk and reloading it to ensure a pristine state.");

    NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&err];
    XCTAssertNotNil(u, @"Failed to get access to the document directory.");
    u = [u URLByAppendingPathComponent:fname];
    
    BOOL ret = [packedData writeToURL:u atomically:YES];
    XCTAssertTrue(ret, @"Failed to save the image to the documnt directory.");
    
    NSData *dReloaded = [NSData dataWithContentsOfURL:u];
    XCTAssertNotNil(dReloaded, @"Failed to reload the image from the document directory.");

    NSLog(@"UT-IMAGE: - the reloaded image data is %u bytes long.", [dReloaded length]);

    return dReloaded;
}

/*
 *  Uses the reference parser to verify the image data.
 */
-(void) verifyAsImageWithReference:(NSData * ) dImg
{
    nj_result_t result = [ImageLoader unpackImageData:dImg];
    XCTAssertEqual(result, NJ_OK, @"Image did not pass the reference parser test.");
}

/*
 *  Load the image file using the standard Apple image loader.
 */
-(BOOL) verifyWithAppleLoader:(NSData *) imageData
{
    UIImage *img = [UIImage imageWithData:imageData];
    XCTAssertNotNil(img, @"Failed to load the image.");
}

/*
 *  Unpack the data
 */
-(void) unpackData:(NSData *) packedData andCompareTo:(NSData *) original withName:(NSString *) fname
{
    NSLog(@"UT-IMAGE: - unpacking the generated file and comparing it to the original secret.");
    
    NSData *secret = nil;
    secret = [RealSecureImage unpackData:packedData withMaxLength:0 andError:&err];
    XCTAssertNotNil(secret, @"Failed to unpack the image.  %@  (Reason: %@)", [err localizedDescription], [err localizedFailureReason]);

    XCTAssertTrue([secret length] > 4, @"No data was found in the image, but %u bytes were expected.", [original length]);
    uint32_t plen = 0;
    plen |= (((unsigned char *) secret.bytes)[0] << 24);
    plen |= (((unsigned char *) secret.bytes)[1] << 16);
    plen |= (((unsigned char *) secret.bytes)[2] << 8);
    plen |= ((unsigned char *) secret.bytes)[3];
    
    XCTAssertTrue(plen >= [original length] && plen <= [secret length] + 4, @"The data blocks do not match.  An invalid length value was found in the packed data.");
    secret = [NSData dataWithBytes:((unsigned char *) secret.bytes) + 4 length:plen];
    UIImage *imgTmp = [UIImage imageWithData:secret];
    imgTmp = imgTmp;
    
    BOOL ret = [RSI_common diffBytes:original withBytes:secret andTitle:@"ORIGINAL diff SECRET"];
    XCTAssertTrue(ret, @"The data blocks do not match.  Original secret is %u bytes.  Unpacked secret is %u bytes.",
                 original ? [original length] : 0,
                 secret ? [secret length] : 0);
    
    if (fname) {
        NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&err];
        XCTAssertNotNil(u, @"Failed to get access to the document directory.");
        u = [u URLByAppendingPathComponent:fname];
    
        ret = [secret writeToURL:u atomically:YES];
        XCTAssertTrue(ret, @"Failed to save the secret-image to the documnt directory.");
    }
    
    NSLog(@"UT-IMAGE: - the original secret and unpacked data match as expected.");
}

/*
 *  Verify that re-packing the image data doesn't change its hash.
 */
-(BOOL) repackData:(NSData *) packedData andAsJPEG:(BOOL) useJPEG
{
    NSLog(@"UT-IMAGE: - verifying that the image can be re-packed without changing its hash.");
    if (useJPEG) {
        [self verifyAsImageWithReference:packedData];
    }
    [self verifyWithAppleLoader:packedData];
    
    RSISecureData *dHash = [RealSecureImage hashImageData:packedData withError:&err];
    XCTAssertNotNil(dHash, @"Failed to hash the image file.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSData *dUnpacked = [RealSecureImage unpackData:packedData withMaxLength:0 andError:&err];
    XCTAssertNotNil(dUnpacked, @"Failed to unpack the image file for reference.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSUInteger len = [dUnpacked length];
    if (len > 1) {
        len--;
    }
    NSMutableData *dHidden = [NSMutableData dataWithLength:len];
    NSLog(@"UT-IMAGE: - repacking 10 times to verify the hash constancy.");
    for (int i = 0; i < 10; i++) {
        @autoreleasepool {
            for (NSUInteger n = 0; n < len; n++) {
                ((unsigned char *) [dHidden mutableBytes])[n] = (unsigned char) rand() & 0xFF;
            }
            
            NSData *repackedImage = [RealSecureImage repackData:packedData withData:dHidden andError:&err];
            XCTAssertNotNil(repackedImage, @"Failed to repack the image file for reference.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);

            if (useJPEG) {
                [self verifyAsImageWithReference:repackedImage];
            }
            [self verifyWithAppleLoader:repackedImage];
            
            RSISecureData *dNewHash = [RealSecureImage hashImageData:repackedImage withError:&err];
            XCTAssertNotNil(dNewHash, @"Failed to rehash the re-packed image file.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);

            BOOL ret = [[dNewHash rawData] isEqualToData:[dHash rawData]];
            XCTAssertTrue(ret, @"The new hash is not equal to the old hash!  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
            
            dUnpacked = [RealSecureImage unpackData:repackedImage withMaxLength:0 andError:&err];
            XCTAssertNotNil(dUnpacked, @"Failed to unpack the modified image contents.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
            
            ret = [dUnpacked length] >= [dHidden length] && !memcmp([dUnpacked bytes], [dHidden bytes], [dHidden length]);
            XCTAssertTrue(ret, @"The modified data doesn't match what was requested.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
        }
    }
    NSLog(@"UT-IMAGE: - the image was successfully repacked without destroying its color data.");
}

/*
 *  Check the behavior of image scrambling/descrambling
 */
-(void) scrambleTestSource:(UIImage *) img withScrambledName:(NSString *) scrFname andDescrambledName:(NSString *) descrFname
{
    NSLog(@"UT-IMAGE: - testing image scrambling from the source image into %@ and %@", scrFname, descrFname);
    time_t tNow = time(NULL);
    NSLog(@"UT-IMAGE: - the scrambling seed is %ld", tNow);
    srand((unsigned int) tNow);
    
    NSMutableData *mdKey = [NSMutableData dataWithLength:[RSI_SHA_SCRAMBLE SHA_LEN]];
    for (int i = 0; i < [mdKey length]; i++) {
        ((unsigned char *) mdKey.mutableBytes)[i] = rand() & 0xFF;
    }
    
    NSData *dScrambled = [RealSecureImage scrambledJPEG:img withQuality:0.5f andKey:mdKey andError:&err];
    XCTAssertNotNil(dScrambled, @"Failed to scramble the input source file.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    NSLog(@"UT-IMAGE: - the scrambled image is %u bytes long", [dScrambled length]);
    
    NSURL *uScram = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    uScram = [uScram URLByAppendingPathComponent:scrFname];
    BOOL ret = [dScrambled writeToURL:uScram atomically:YES];
    XCTAssertTrue(ret, @"Failed to write the scrambled image to disk.");

    [self verifyAsImageWithReference:dScrambled];
    [self verifyWithAppleLoader:dScrambled];
    
    NSLog(@"UT-IMAGE: - verifying that the scrambled image cannot be opened with basic unpacking.");
    NSData *unpack = [RealSecureImage unpackData:dScrambled withMaxLength:0 andError:&err];
    XCTAssertNil(unpack, @"The image was falsely unpacked.");

    NSLog(@"UT-IMAGE: - descrambling the source image.");
    RSISecureData *unScrambled = [RealSecureImage descrambledJPEG:dScrambled andKey:mdKey andError:&err];
    XCTAssertNotNil(unScrambled, @"Failed to descramble the scrambled data.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    [self verifyAsImageWithReference:[unScrambled rawData]];
    [self verifyWithAppleLoader:[unScrambled rawData]];
        
    NSURL *uDescram = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    uDescram = [uDescram URLByAppendingPathComponent:descrFname];
    ret = [[unScrambled rawData] writeToURL:uDescram atomically:YES];
    XCTAssertTrue(ret, @"Failed to write the descrambled image to disk.");
}

/*
 *  Verify that partial unpacking works as expected.
 */
-(void) partialUnpackTestWithPacked:(NSData *) packedData andSecret:(NSData *) s
{
    NSUInteger len = [s length];
    if (len < 5) {
        return;
    }
    
    NSLog(@"UT-IMAGE: - testing partial unpacking with the image data");
    len += 100;             //  test that larger values don't hose the process.
    while (len > 4) {
        @autoreleasepool {
            NSData *dUnpacked = [RealSecureImage unpackData:packedData withMaxLength:len andError:&err];
            XCTAssertNotNil(dUnpacked, @"Failed to partially unpack %u bytes from the data.", len);
            XCTAssertTrue([dUnpacked length] <= len, @"The unpacked bytes exceed their expected length.");
            
            NSUInteger toCmp = len;
            if (toCmp > [s length]) {
                toCmp = [s length];
            }
            toCmp -= 4;
            if (toCmp > 0) {
                //  - skip the length prefixed onto the data block
                int rc = memcmp((unsigned char *) dUnpacked.bytes + 4, s.bytes, toCmp);
                if (rc != 0) {
                    [RSI_common diffBytes:s withBytes:dUnpacked andTitle:@"SECRET DIFF PARTIAL UNPACKED"];
                }
                XCTAssertEqual(rc, 0, @"The packed bytes don't match the expected values.");
            }
        }
        len = len >> 1;
    }
    
    NSLog(@"UT-IMAGE: - verifying that partial packing works with a truncated file");
    NSData *trunc = [NSData dataWithBytes:[packedData bytes] length:[packedData length] >> 4];
    NSData *dUnpacked = [RealSecureImage unpackData:trunc withMaxLength:16 andError:&err];
    XCTAssertNotNil(dUnpacked, @"Failed to partially unpack the truncated image file.");
    int ret = memcmp((unsigned char *) dUnpacked.bytes + 4, s.bytes, [dUnpacked length] - 4);
    XCTAssertEqual(ret, 0, @"The partially-unpacked buffer does not equal the source.");
    
    NSLog(@"UT-IMAGE: - partial unpacking appears functional");
}

/*
 *  Base name of the provided file
 */
-(NSString *) basename:(NSString *) file
{
    if (!file) {
        return @"";
    }
    
    NSRange r = [file rangeOfString:@"."];
    if (r.location != NSNotFound) {
        file = [file substringToIndex:r.location];
    }
    return file;
}

/*
 *  Test the behavior of the packing/unpacking with the given container and secret images.
 */
-(void) testWithContainer:(NSString *) container andSecret:(NSString *) secret andAsJPEG:(BOOL) useJPEG
{
    UIImage *imgCont = [self loadContainerImage:container];
    XCTAssertNotNil(imgCont, @"Failed to load the container image.");
    
    NSData *dSecret = nil;
    if (secret) {
        dSecret = [self dataForHiddenImage:secret];
        UIImage *imgSecret = [UIImage imageWithData:dSecret];
        imgSecret = imgSecret;
    }
    else {
        dSecret = [NSData dataWithBytes:"F" length:1];
    }
    
    XCTAssertNotNil(dSecret, @"Failed to load the secret file.");
    
    NSData *packedData = [self packImage:imgCont withData:dSecret andAsJPEG:useJPEG];
    NSUInteger packedLen = [packedData length];
    if (!packedData) {
        return;
    }
    
    NSLog(@"UT-IMAGE: - checking partial image detection.");
    BOOL ret = [RealSecureImage isSupportedPackedFile:packedData];
    XCTAssertTrue(ret, @"The returned file is not supported!");
    for (NSUInteger i = 1; i < packedLen; i++) {
        NSData *d = [NSData dataWithBytes:packedData.bytes length:i];
        if ([RealSecureImage hasEnoughDataForImageTypeIdentification:d]) {
            ret = [RealSecureImage isSupportedPackedFile:d];
            XCTAssertTrue(ret, @"Failed to identify a supported packed file.");
            break;
        }
    }
    
    NSLog(@"UT-IMAGE: - verifying the generated image type");
    XCTAssertEqual(useJPEG, [RSI_unpack isImageJPEG:packedData], @"The image isn't the expected type.");
    
    NSString *sname = [NSString stringWithFormat:@"tmp-%@.%s", [self basename:container], useJPEG ? "jpg" : "png"];
    NSData *reloadedPacked = [self saveAndReloadPackedImage:packedData withName:sname];
    if (!reloadedPacked) {
        return;
    }
    
    XCTAssertEqual([reloadedPacked length], packedLen, @"The reloaded data is not the same length as it was before saving.");
    
    if (useJPEG) {
        NSLog(@"UT-IMAGE: - verifying the reloaded packed image with the reference parser");
        [self verifyAsImageWithReference:reloadedPacked];
    }
    
    NSLog(@"UT-IMAGE: - verifying the reloaded packed image with the Apple loader");
    [self verifyWithAppleLoader:reloadedPacked];
    
    if (secret) {
        sname = [NSString stringWithFormat:@"tmp-%@.%s", [self basename:secret], useJPEG ? "jpg" : "png"];
    }
    else {
        sname = nil;
    }

    [self unpackData:packedData andCompareTo:dSecret withName:sname];
    
    [self partialUnpackTestWithPacked:packedData andSecret:dSecret];
    
    [self repackData:packedData andAsJPEG:useJPEG];
    
    if (useJPEG) {
        NSString *scrName = [NSString stringWithFormat:@"scrambled-%@", container];
        NSString *descrName = [NSString stringWithFormat:@"descrambled-%@", container];
        [self scrambleTestSource:imgCont withScrambledName:scrName andDescrambledName:descrName];
    }
}

/*
 *  Test the behavior of the packing/unpacking with the given container and secret images.
 */
-(void) testWithContainer:(NSString *) container andSecret:(NSString *) secret
{
    NSLog(@"UT-IMAGE: - beginning PNG series");
    [self testWithContainer:container andSecret:secret andAsJPEG:NO];
    NSLog(@"UT-IMAGE: - beginning JPEG series");
    [self testWithContainer:container andSecret:secret andAsJPEG:YES];
}

/*
 *  Determines if the PNG type should pass a read test based on its type.  The
 *  PNGSuite has a naming convention to indicate the file purpose:
 *
 *      File naming
 *      Where possible, the test-files are 32x32 bits icons. This results in a still reasonable size of the suite even with a large number of tests. 
 *      The name of each test-file reflects the type in the following way:
 *
 *       filename:                               g04i2c08.png
 *       || ||||
 *       test feature (in this case gamma) ------+| ||||
 *       parameter of test (here gamma-value) ----+ ||||
 *       interlaced or non-interlaced --------------+|||
 *       color-type (numerical) ---------------------+||
 *       color-type (descriptive) --------------------+|
 *       bit-depth ------------------------------------+
 *
 *
 *   color-type:
 *
 *   0g - grayscale
 *   2c - rgb color
 *   3p - paletted
 *   4a - grayscale + alpha channel
 *   6a - rgb color + alpha channel
 *
 *   bit-depth:
 *
 *   01 - with color-type 0, 3
 *   02 - with color-type 0, 3
 *   04 - with color-type 0, 3
 *   08 - with color-type 0, 2, 3, 4, 6
 *   16 - with color-type 0, 2, 4, 6
 *
 *   interlacing:
 *
 *   n - non-interlaced
 *   i - interlaced
 */
-(BOOL) willPNGPass:(NSURL *) uFile
{
    //  Many of these files simply fail to be read because this PNG parser
    //  is only intended to correctly handle cover images, not process them.
    //  Since PNG is used as a container, the only files of value are RGBA
    //  files.
    NSString *s = [uFile lastPathComponent];
    const char *fname = [s UTF8String];
    
    //  - one of our samples that should be ignored
    if ([s isEqualToString:@"google.com.png"] || [s isEqualToString:@"PngSuite.png"]) {
        return YES;
    }
    
    size_t len = strlen(fname);
    if (len > 4 && !strcmp(fname+len-4, ".png") &&
        fname[len-5] == '8') {                                                  //  only 8-bit color depth is supported
        BOOL isRGBA = (fname[len-7] == 'a' && fname[len-8] == '6') ? YES : NO;
        BOOL isRGB  = (fname[len-7] == 'c' && fname[len-8] == '2') ? YES : NO;
        
        if (isRGBA || isRGB) {
            //  - if not gamma testing or a corrupted file, we should support it.
            if ((*fname != 'g' || isRGB) && *fname != 'x') {
                return YES;
            }
        }
    }

    return NO;
}

/*
 *  Verify the contents of the image have the expected test data.
 */
-(void) verifyImageAsTestData:(NSData *) dImg andSize:(CGSize) szImg andInterlaced:(BOOL) isInterlaced andHasAlpha:(BOOL) hasAlpha
{
    XCTAssertNotNil(dImg, @"The generated test PNG image cannot be nil.");
    
    [self verifyWithAppleLoader:dImg];
    
    NSString *s = [NSString stringWithFormat:@"gen-%s-%s-%dx%d.png", isInterlaced ? "i" : "n", hasAlpha ? "alpha" : "na", (int) szImg.width, (int) szImg.height];
    NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    u = [u URLByAppendingPathComponent:@"auto-gen"];
    if (isInterlaced) {
        if (hasAlpha) {
            u = [u URLByAppendingPathComponent:@"interlaced-alpha"];
        }
        else {
            u = [u URLByAppendingPathComponent:@"interlaced"];
        }
    }
    else {
        if (hasAlpha) {
            u = [u URLByAppendingPathComponent:@"non-interlaced-alpha"];
        }
        else {
            u = [u URLByAppendingPathComponent:@"non-interlaced"];
        }
    }
    [[NSFileManager defaultManager] createDirectoryAtURL:u withIntermediateDirectories:YES attributes:nil error:nil];
    u = [u URLByAppendingPathComponent:s];
    
    BOOL ret = [dImg writeToURL:u atomically:YES];
    XCTAssertTrue(ret, @"Failed to write the test image of size %dX%d.", (int) szImg.width, (int) szImg.height);
    
    CGSize szRead;
    NSData *dColorData = [RSI_unpack getPNGImageBufferFromFile:dImg returningSize:&szRead andError:&err];
    
    XCTAssertNotNil(dColorData, @"Failed to read the image data for the image of size %dX%d.  %@", (int)szImg.width, (int)szImg.height, [err localizedDescription]);
    
    XCTAssertEqual((int)szImg.width, (int)szRead.width, @"The image width was not read correctly for image of size %dX%d.", (int)szImg.width, (int)szImg.height);
    XCTAssertEqual((int)szImg.height, (int)szRead.height, @"The image height was not read correctly for image of size %dX%d.", (int)szImg.width, (int)szImg.height);
    
    int w = (int) szImg.width;
    int h = (int) szImg.height;
    
    int pos = 0;
    int pelPos = 0;
    const unsigned char *imgBuffer = (const unsigned char *) [dColorData bytes];
    for (int y = 0; y < h; y++) {
        for (int x = 0, x1 = 0; x < w; x++, x1++) {
            unsigned char r = imgBuffer[pos];
            unsigned char g = imgBuffer[pos+1];
            unsigned char b = imgBuffer[pos+2];
            unsigned char a = imgBuffer[pos+3];
            BOOL passed = NO;
            if (x == (w-1)) {
                //  should be turquoise
                passed = (r == 0 && g == 255 && b == 255 && a == 255) ? YES : NO;
                if (!passed) {
                    [RSI_common printBytes:dColorData withTitle:@"INVALID COLOR DATA"];
                }
                XCTAssertTrue(passed, @"The last column for image of size %dX%d is not turquoise as expected.", w, h);
            }
            else if (y == (h-1)) {
                //  should be magenta
                passed = (r == 255 && g == 0 && b == 255 && a == 255) ? YES : NO;
                if (!passed) {
                    [RSI_common printBytes:dColorData withTitle:@"INVALID COLOR DATA"];
                }                
                XCTAssertTrue(passed, @"The bottom row for image of size %dX%d is not magenta as expected.", w, h);
            }
            else if (x == 0) {
                //  should be yellow
                passed = (r == 255 && g == 255 && b == 0 && a == 255) ? YES : NO;
                if (!passed) {
                    [RSI_common printBytes:dColorData withTitle:@"INVALID COLOR DATA"];
                }                
                XCTAssertTrue(passed, @"The first column for image of size %dX%d is not yellow as expected.", w, h);
                
            }
            else if (y == 0) {
                //  should be blue
                passed = (r == 0 && g == 0 && b == 255 && a == 255) ? YES : NO;
                if (!passed) {
                    [RSI_common printBytes:dColorData withTitle:@"INVALID COLOR DATA"];
                }                
                XCTAssertTrue(passed, @"The first row for image of size %dX%d is not blue as expected.", w, h);
            }
            else {
                //  should be a weird value
                passed = YES;
                unsigned char testR = (unsigned char) 255-((pelPos+x1+y)&0xFF);
                unsigned char testG = (unsigned char) ((pelPos-x1)&0xFF);
                unsigned char testB = (unsigned char) 255-((y)&0xFF);
                unsigned char testA = 0xFF;
                if (r != testR ||
                    g != testG ||
                    b != testB ||
                    a != testA) {
                    passed = NO;
                }
                if (!passed) {
                    [RSI_common printBytes:dColorData withTitle:@"INVALID COLOR DATA"];
                }
                XCTAssertTrue(passed, @"The sample background for image of size %dX%d is not unusual as expected.", w, h);
            }
            
            pos += 4;
            pelPos += (hasAlpha ? 4 : 3);
        }
    }
}

/*
 *  Create a test PNG file that can be decoded later for verification purposes.
 */
-(NSData *) generateTestPNGOfSize:(CGSize) szImg andInterlaced:(BOOL) isInterlaced andIncludeAlpha:(BOOL) includeAlpha
{
    //  The goal here is to create a PNG that hits all the high points of the
    //  reader that we support.  That means one that uses each of the five
    //  filters and can be optionally interlaced.
    const unsigned char BLUE_COLOR[]      = {0x00, 0x00, 0xFF, 0xFF};
    const unsigned char YELLOW_COLOR[]    = {0xFF, 0xFF, 0x00, 0xFF};
    const unsigned char MAGENTA_COLOR[]   = {0xFF, 0x00, 0xFF, 0xFF};
    const unsigned char TURQUOISE_COLOR[] = {0x00, 0xFF, 0xFF, 0xFF};
    
    int w = szImg.width;
    int h = szImg.height;
    
    XCTAssertTrue(w > 0 && h > 0, @"Invalid image generation request.");

    //  - create the image
    NSUInteger pixelWidth = includeAlpha ? 4 : 3;
    NSMutableData *mdFullImage = [NSMutableData dataWithLength:(w * h) * pixelWidth];
    unsigned char *imgBuffer = (unsigned char *) mdFullImage.mutableBytes;
    int pos = 0;
    for (int y = 0; y < h; y++) {
        for (int x = 0, x1 = 0; x < (w*pixelWidth);x+=pixelWidth, pos+=pixelWidth, x1++) {
            if (x1 == (w-1)) {
                memcpy(&(imgBuffer[pos]), TURQUOISE_COLOR, pixelWidth);
            }
            else if (y == (h-1)) {
                memcpy(&(imgBuffer[pos]), MAGENTA_COLOR, pixelWidth);
            }
            else if (x1 == 0) {
                memcpy(&(imgBuffer[pos]), YELLOW_COLOR, pixelWidth);
            }
            else if (y == 0) {
                memcpy(&(imgBuffer[pos]), BLUE_COLOR, pixelWidth);
            }
            else {
                //  - store some crazy values in the middle to ensure that the averaging is correct
                imgBuffer[pos]   = (unsigned char) 255-((pos+x1+y)&0xFF);
                imgBuffer[pos+1] = (unsigned char) ((pos-x1)&0xFF);
                imgBuffer[pos+2] = (unsigned char) 255-((y)&0xFF);
                if (includeAlpha) {
                    imgBuffer[pos+3] = (unsigned char) 0xFF;
                }
            }
        }
    }
    
    //  - set up what we need for libpng.
    png_structp png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    XCTAssertTrue(png_ptr != NULL, @"Failed to create the PNG write handle.");
    
    png_infop info_ptr = png_create_info_struct(png_ptr);
    XCTAssertTrue(info_ptr != NULL, @"Failed to create the PNG info structure.");

    NSMutableData *mdOutput = [NSMutableData data];
    png_set_write_fn(png_ptr, (png_voidp)mdOutput, RSI_png_write, RSI_png_flush);           //  instead of png_init_io
    
    png_set_IHDR(png_ptr, info_ptr, w, h, 8,
                 includeAlpha ? PNG_COLOR_TYPE_RGB_ALPHA : PNG_COLOR_TYPE_RGB,
                 isInterlaced ? PNG_INTERLACE_ADAM7 : PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);
    png_write_info(png_ptr, info_ptr);
    
    //  - set a precise filter for each scanline so that we can
    //    check each type in our reader.
    int filter = 0;
    switch ((w*h)%5)
    {
        case 0:
            filter = PNG_FILTER_NONE;
            break;
            
        case 1:
            filter = PNG_FILTER_SUB;
            break;
            
        case 2:
            filter = PNG_FILTER_UP;
            break;
            
        case 3:
            filter = PNG_FILTER_AVG;
            break;
            
        case 4:
            filter = PNG_FILTER_PAETH;
            break;
    }
    
    png_set_filter(png_ptr, 0, filter);
    
    //  - now write each row
    int number_of_passes = 1;
    if (isInterlaced) {
        number_of_passes = png_set_interlace_handling(png_ptr);
    }

    for (int pass = 0; pass < number_of_passes; pass++) {
        pos = 0;
        for (int y = 0; y < h; y++) {
            png_write_row(png_ptr, &(imgBuffer[pos]));
            
            pos += (w * pixelWidth);
        }
    }
    
    png_write_end(png_ptr, info_ptr);
    png_destroy_write_struct(&png_ptr, &info_ptr);
    
    return mdOutput;
}

/*
 *  Verify that PNG reqad behavior is functional with Apple-generated images.
 */
-(void) testUTIMAGE_1_PNG_Basic
{
    NSLog(@"UT-IMAGE: - testing PNG read behavior with auto-generated images");
    for (int i = 1; i < 25; i++) {
        for (int j = 1; j < 25; j++) {
            CGSize szImg = CGSizeMake(i, j);
            //  - test interlaced first because they are the more complicated
            NSLog(@"UT-IMAGE: - generating interlaced image at %dX%d", i, j);
            @autoreleasepool {
                NSData *d = [self generateTestPNGOfSize:szImg andInterlaced:YES andIncludeAlpha:YES];
                [self verifyImageAsTestData:d andSize:szImg andInterlaced:YES andHasAlpha:YES];
            }
            
            //  - test non-interlaced
            NSLog(@"UT-IMAGE: - generating non-interlaced image at %dX%d", i, j);
            @autoreleasepool {
                NSData *d = [self generateTestPNGOfSize:szImg andInterlaced:NO andIncludeAlpha:YES];
                [self verifyImageAsTestData:d andSize:szImg andInterlaced:NO andHasAlpha:YES];
            }
            
            //  - test interlaced with no-alpha
            NSLog(@"UT-IMAGE: - generating interlaced image with no alpha at %dX%d", i, j);
            @autoreleasepool {
                NSData *d = [self generateTestPNGOfSize:szImg andInterlaced:YES andIncludeAlpha:NO];
                [self verifyImageAsTestData:d andSize:szImg andInterlaced:YES andHasAlpha:NO];
            }
            
            //  - test non-interlaced with no-alpha
            NSLog(@"UT-IMAGE: - generating non-interlaced image with no alpha at %dX%d", i, j);
            @autoreleasepool {
                NSData *d = [self generateTestPNGOfSize:szImg andInterlaced:NO andIncludeAlpha:NO];
                [self verifyImageAsTestData:d andSize:szImg andInterlaced:NO andHasAlpha:NO];
            }
        }
    }
    NSLog(@"UT-IMAGE: - auto-generated PNG read testing passed.");
}

/*
 *  Verify that PNG read behavior is functional with stock images
 *  - This operates simply by reading the files from the PNGSuite and
 *    expecting either success or failure from each read operation based on 
 *    what this library will support.
 */
-(void) testUTIMAGE_2_PNG_PNGSuite
{
    NSUInteger numImages = 0;
    NSLog(@"UT-IMAGE: - testing PNG read behavior with the PNGSuite image library");    
    NSArray *bundles = [NSBundle allBundles];
    for (int i = 0; i < [bundles count]; i++) {
        NSBundle *bundle = [bundles objectAtIndex:i];
        
        NSArray *allPNGs = [bundle URLsForResourcesWithExtension:@".png" subdirectory:nil];
        if (!allPNGs || [allPNGs count] == 0) {
            continue;
        }
    
        for (int j = 0; j < [allPNGs count]; j++) {
            NSURL *u = [allPNGs objectAtIndex:j];
            
            BOOL toPass = [self willPNGPass:u];
            
            @autoreleasepool {
                NSLog(@"UT-IMAGE: - %@ (%@?)", [u path], toPass ? @"PASS" : @"FAIL");
                
                NSData *dFile = [NSData dataWithContentsOfURL:u];
                XCTAssertNotNil(dFile, @"Failed to load the file.");
                
                CGSize szImage;
                NSData *fileBuffer = [RSI_unpack getPNGImageBufferFromFile:dFile returningSize:&szImage andError:&err];
                
                BOOL ret = (fileBuffer != nil) ? YES : NO;
                XCTAssertEqual(toPass, ret, @"The file did not pass the read test on index %d.  %@", j, (err ? [err localizedDescription] : @"Failed to receive an error code."));
                numImages++;
            }
        
        }

    }

    NSLog(@"UT-IMAGE: - %u images were read successfully", numImages);
}

/*
 * Verify that images that are too big are not accepted by the PNG packer.
 */
-(void) testUTIMAGE_3_PNGTooBig
{
    NSLog(@"UT-IMAGE: - testing that PNG rejects images that are too big");
    
    const char *foo = "Hello World";
    NSData *dPack = [NSData dataWithBytes:foo length:strlen(foo) + 1];

    @autoreleasepool {
        UIImage *img = [RSI_5_image_tests loadImage:@"social-d.jpg"];
        NSData *d = [RealSecureImage packedPNG:img andData:dPack andError:&err];
        XCTAssertNil(d, @"The image was packed and shouldn't have been.");
        XCTAssertEqual(err.code, RSIErrorInvalidArgument, @"The returned error was unexpected.");
    }

    @autoreleasepool {
        UIImage *img = [RSI_5_image_tests loadImage:@"serengeti-sunrise.jpg"];
        NSData *d = [RealSecureImage packedPNG:img andData:dPack andError:&err];
        XCTAssertNil(d, @"The image was packed and shouldn't have been.");
        XCTAssertEqual(err.code, RSIErrorInvalidArgument, @"The returned error was unexpected.");
    }
    
    NSLog(@"UT-IMAGE: - All images were rejected as expected.");
}

/*
 *  Test a very small image to get the basic alignment correct.
 */
-(void) testUITImage_3_PNGSuperTiny
{
    NSLog(@"UT-IMAGE: - testing that that we can write a very tiny image.");
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1.0f, 1.0f), YES, 1.0f);
    [[UIColor redColor] setFill];
    UIRectFill(CGRectMake(0.0f, 0.0f, 1.0f, 1.0f));
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    NSData *dPack = [RealSecureImage packedPNG:img andData:nil andError:&err];
    XCTAssertNotNil(dPack, @"The image could not be packed with no data.");
    XCTAssertTrue(dPack.length > 0, @"The image file is invalid.");
    
    UIImage *imgTest = [UIImage imageWithData:dPack];
    XCTAssertNotNil(imgTest, @"The image wasn't reloaded correctly.");
    
    NSData *d = [RealSecureImage unpackData:dPack withMaxLength:0 andError:&err];
    XCTAssertNotNil(d, @"Failed to unpack.");
    
    NSLog(@"UT-IMAGE: - a tiny image was saved and re-read as expected.");
}

/*
 *  Verify that packing/unpacking works with a small image.
 */
-(void) testUTIMAGE_4_Tiny
{
    NSLog(@"UT-IMAGE: - testing packing/unpacking with tiny images");
    [self testWithContainer:@"one-du-image.jpg" andSecret:nil];
}


/*
 *  Verify that packing/unpacking works with a small image.
 */
-(void) testUTIMAGE_5_Small
{
    NSLog(@"UT-IMAGE: - testing packing/unpacking with small images");
    [self testWithContainer:@"sample-square.jpg" andSecret:@"sample-secret.jpg"];
}

/*
 *  Verify that packing/unpacking works with a large image.
 */
-(void) testUTIMAGE_6_Large
{
    NSLog(@"UT-IMAGE: - testing packing/unpacking with large images");
    [self testWithContainer:@"IMG_0236.JPG" andSecret:@"IMG_0144.JPG"];
}

/*
 *  Verify that packing/unpacking works with random-sized images
 */
-(void) testUTIMAGE_7_Random
{
    NSLog(@"UT-IMAGE: - testing packing/unpacking with random images");
    @autoreleasepool {
        [self testWithContainer:@"iron-man2.jpg" andSecret:@"sample-secret.jpg"];
    }

    @autoreleasepool {
        [self testWithContainer:@"v-for-vendetta-v.jpg" andSecret:@"sample-secret.jpg"];
    }
        
    @autoreleasepool {
        [self testWithContainer:@"aynrand.jpg" andSecret:@"sample-secret.jpg"];
    }
}

/*
 *  Test that scrambling/descrambling can occur to a previously packed file.
 */
-(void) testUTIMAGE_8_PostPackScramble
{
    NSLog(@"UT-IMAGE: - testing post-pack scrambling");
    
    NSLog(@"UT-IMAGE: - packing the data");
    UIImage *img = [RSI_5_image_tests loadImage:@"sample-square.jpg"];
    NSData *dSecret = [self dataForHiddenImage:@"sample-secret.jpg"];
    
    NSData *dPacked = [RealSecureImage packedJPEG:img withQuality:0.5f andData:dSecret andError:&err];
    XCTAssertNotNil(dPacked, @"Failed to pack the test image.");

    time_t tNow = time(NULL);
    NSLog(@"UT-IMAGE: - the scrambling seed is %ld", tNow);
    srand((unsigned int) tNow);
    
    NSLog(@"UT-IMAGE: - scrambling it");    
    NSMutableData *mdKey = [NSMutableData dataWithLength:[RSI_SHA_SCRAMBLE SHA_LEN]];
    for (int i = 0; i < [mdKey length]; i++) {
        ((unsigned char *) mdKey.mutableBytes)[i] = rand() & 0xFF;
    }
    
    NSData *dScrambled = [RealSecureImage scrambledJPEG:dPacked andKey:mdKey andError:&err];
    XCTAssertNotNil(dScrambled, @"Failed to scramble the input source file.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    NSLog(@"UT-IMAGE: - the scrambled image is %u bytes long", [dScrambled length]);

    NSLog(@"UT-IMAGE: - saving the scrambled image to disk.");    
    NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    u = [u URLByAppendingPathComponent:@"post-pack-scramble.jpg"];
    BOOL ret = [dScrambled writeToURL:u atomically:YES];
    XCTAssertTrue(ret, @"Failed to writethe scrambled data to a file.");

    NSLog(@"UT-IMAGE: - verifying the scrambled image.");
    [self verifyAsImageWithReference:dScrambled];
    
    [self verifyWithAppleLoader:dScrambled];
    
    NSLog(@"UT-IMAGE: - descrambling it");
    RSISecureData *unScrambled = [RealSecureImage descrambledJPEG:dScrambled andKey:mdKey andError:&err];
    XCTAssertNotNil(unScrambled, @"Failed to descramble the input source file.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-IMAGE: - unpacking it");
    NSData *dSecretUnpacked = [RealSecureImage unpackData:[unScrambled rawData] withMaxLength:0 andError:&err];
    XCTAssertNotNil(dSecretUnpacked, @"Failed to unpack the data.");
    
    NSLog(@"UT-IMAGE: - verifying the unpacked data is equivalent to the original");
    XCTAssertTrue([dSecretUnpacked length] >= [dSecret length], @"The unpacked data is too small.");
    XCTAssertEqual(memcmp(dSecretUnpacked.bytes, dSecret.bytes, [dSecret length]), 0, @"The unpacked data differs.");
    
    NSLog(@"UT-IMAGE: - all tests completed successfully");
}

/*
 *  Verify that image hashing works as expected.
 */
-(void) testUTIMAGE_9_Hashing
{
    NSLog(@"UT-IMAGE: - beginning image hashing tests");
    CGSize szImgA = CGSizeMake(16, 16);
    CGRect rcImgA = CGRectMake(0.0f, 0.0f, szImgA.width, szImgA.height);
    CGSize szImgB = CGSizeMake(24, 24);
    CGRect rcImgB = CGRectMake(0.0f, 0.0f, szImgB.width, szImgB.height);
    
    NSLog(@"UT-IMAGE: - creating images A and B");
    UIGraphicsBeginImageContext(szImgA);
    CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), [[UIColor redColor] CGColor]);
    CGContextFillRect(UIGraphicsGetCurrentContext(), rcImgA);
    CGContextSetStrokeColorWithColor(UIGraphicsGetCurrentContext(), [[UIColor greenColor] CGColor]);
    CGContextStrokeRect(UIGraphicsGetCurrentContext(), rcImgA);
    UIImage *imgA = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    UIGraphicsBeginImageContext(szImgB);
    CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), [[UIColor orangeColor] CGColor]);
    CGContextFillRect(UIGraphicsGetCurrentContext(), rcImgB);
    CGContextSetStrokeColorWithColor(UIGraphicsGetCurrentContext(), [[UIColor purpleColor] CGColor]);
    CGContextStrokeRect(UIGraphicsGetCurrentContext(), rcImgB);
    UIImage *imgB = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    NSLog(@"UT-IMAGE: - producing packed images for hashing.");    
    NSUInteger lenData = [RSI_pack maxDataForJPEGImage:imgA];
    NSMutableData *dPackA = [NSMutableData dataWithLength:lenData];
    NSData *packedA = [RSI_pack packedJPEG:imgA withQuality:0.5f andData:dPackA andError:&err];
    XCTAssertNotNil(packedA, @"Failed to pack the data for image A.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    lenData = [RSI_pack maxDataForJPEGImage:imgB];
    NSMutableData *dPackB = [NSMutableData dataWithLength:lenData];
    NSData *packedB = [RSI_pack packedJPEG:imgB withQuality:0.5f andData:dPackB andError:&err];
    XCTAssertNotNil(packedB, @"Failed to pack the data for image B.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-IMAGE: - hashing the images.");
    RSI_securememory *hashA = [RSI_unpack hashImageData:packedA withError:&err];
    XCTAssertNotNil(hashA, @"Failed to hash image A.");
    
    RSI_securememory *hashB = [RSI_unpack hashImageData:packedB withError:&err];
    XCTAssertNotNil(hashB, @"Failed to hash image B.");
    
    NSLog(@"UT-IMAGE: - comparing the hashes (they should differ).");
    BOOL ret = [hashA isEqualToSecureData:hashB];
    XCTAssertFalse(ret, @"They were equal, but should not have been.");
    
    NSLog(@"UT-IMAGE: - rehashing the images.");
    RSI_securememory *hashA2 = [RSI_unpack hashImageData:packedA withError:&err];
    XCTAssertNotNil(hashA2, @"Failed to hash image A.");
    
    RSI_securememory *hashB2 = [RSI_unpack hashImageData:packedB withError:&err];
    XCTAssertNotNil(hashB2, @"Failed to hash image B.");
    
    NSLog(@"UT-IMAGE: - comparing the hashes to their counterparts (should be the same).");
    ret = [hashA isEqualToSecureData:hashA2] && [hashB isEqualToSecureData:hashB2];
    XCTAssertTrue(ret, @"They were not equal, but should have been.");
    
    time_t tSeed = time(NULL);
    NSLog(@"UT-IMAGE: - seeding the random number generator with %lu", tSeed);
    srand((unsigned int) tSeed);
    
    NSLog(@"UT-IMAGE: - producing packed images with alternate data");
    lenData = [RSI_pack maxDataForJPEGImage:imgA];
    dPackA = [NSMutableData dataWithLength:lenData];
    for (int i = 0; i < lenData; i++) {
        ((unsigned char *) dPackA.mutableBytes)[i] = (unsigned char) rand() & 0xFF;
    }
    packedA = [RSI_pack packedJPEG:imgA withQuality:0.5f andData:nil andError:&err];
    XCTAssertNotNil(packedA, @"Failed to pack the data for image A.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    lenData = [RSI_pack maxDataForJPEGImage:imgB];
    dPackB = [NSMutableData dataWithLength:lenData];
    for (int i = 0; i < lenData; i++) {
        ((unsigned char *) dPackB.mutableBytes)[i] = (unsigned char) rand() & 0xFF;
    }
    packedB = [RSI_pack packedJPEG:imgB withQuality:0.5f andData:dPackB andError:&err];
    XCTAssertNotNil(packedB, @"Failed to pack the data for image B.  %@ (%@)", [err localizedDescription], [err localizedFailureReason]);
    
    NSLog(@"UT-IMAGE: -  re-hashing the new images");
    hashA2 = [RSI_unpack hashImageData:packedA withError:&err];
    XCTAssertNotNil(hashA2, @"Failed to hash image A.");
    
    hashB2 = [RSI_unpack hashImageData:packedB withError:&err];
    XCTAssertNotNil(hashB2, @"Ffailed to hash image B.");
    
    NSLog(@"UT-IMAGE: - comparing the hashes to their counterparts (should still be the same, even with different embedded data).");
    ret = [hashA isEqualToSecureData:hashA2] && [hashB isEqualToSecureData:hashB2];
    XCTAssertTrue(ret, @"They were not equal, but should have been.");
}
@end
