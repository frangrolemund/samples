//
//  RSI_1_file_tests.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 12/31/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import "RSI_1_file_tests.h"
#import "RSI_file.h"
#import "RSI_zlib_file.h"
#import "RSI_common.h"

@implementation RSI_1_file_tests

/*
 *  Basic initialization
 */
-(void) setUp
{
    [super setUp];    
    err = nil;
    self.continueAfterFailure = NO;    
}

/*
 *  Read from a file.
 */
-(void) testUTFILE_1_Read
{
    NSLog(@"UT-FILE: - starting read unit tests.");
    
    time_t tSeed = time(NULL);
    NSLog(@"UT-FILE: - seeding the random number generator with %lu", tSeed);
    srand((unsigned int) tSeed);
    
    //  - create a random buffer
    NSMutableData *mdInput = [NSMutableData dataWithLength:0xFFFF];
    for (int i = 0; i < 0xFFFF; i++) {
        ((unsigned char *) [mdInput mutableBytes])[i] = (rand() & 0xFF);
    }
    
    NSUInteger len = [mdInput length];
    NSMutableData *mdFullBuffer = [NSMutableData dataWithLength:len];
    NSMutableData *mdReadData = [NSMutableData dataWithLength:100];
    
    //  iterate over the contents of the file many times using random bit
    //  lengths to establish if the code works as advertised.
    static int RSI_READ_ITER = 1000;
    BOOL ret = YES;
    NSLog(@"UT-FILE: - performing %d iterations.", RSI_READ_ITER);
    for (int n = 0; n < RSI_READ_ITER; n++) {
        NSUInteger numBits = len << 3;
        memset(mdFullBuffer.mutableBytes, 0, len);
        
        if ((n / 100) > 0 && (n % 100) == 0) {
            NSLog(@"UT-FILE: - completed %d iterations", n);
        }
        
        RSI_file *fInput = [[RSI_file alloc] initForReadWithData:mdInput];
        NSUInteger curIndex = 0;
        NSUInteger bitNum = 0;
        
        while (numBits) {
            ret = [fInput isEOF];
            XCTAssertFalse(ret, @"Unexpected EOF encountered (iteration %d).", n);
            
            NSUInteger toGrab = rand() % 24 + 1;
            if (toGrab > numBits) {
                toGrab = numBits;
            }
            
            //  use both a peek/seek and an integrated read
            if (rand() % 100 < 50) {
                if (toGrab == 16 && rand() % 100 < 50) {
                    uint16_t oneW = 0;
                    ret = [fInput peekw:&oneW];
                    XCTAssertTrue(ret, @"UT-FILE: Error: failed to peekw with %d bits remaining (iteration %d).", numBits, n);
                    
                    ((unsigned char *) mdReadData.mutableBytes)[0] = oneW >> 8;
                    ((unsigned char *) mdReadData.mutableBytes)[1] = oneW & 0xFF;
                }
                else {
                    XCTAssertTrue([fInput peekBits:toGrab intoBuffer:mdReadData.mutableBytes ofLength:toGrab], @"UT-FILE: Error: failed to peek %d bits with %d remaining (iteration %d).", toGrab, numBits, n);
                }
                
                ret = [fInput seekBits:toGrab];
                XCTAssertTrue(ret, @"UT-FILE: Error: failed to seek %d bits with %d remaining (iteration %d).", toGrab, numBits, n);
            }
            else {
                //  - use the word read once in a while.
                if (toGrab == 16 && rand() % 100 < 50) {
                    uint16_t oneW = 0;
                    ret = [fInput getw:&oneW];
                    XCTAssertTrue(ret, @"UT-FILE: Error: failed to getw with %d bits remaining (iteration %d).", numBits, n);
                    
                    ((unsigned char *) mdReadData.mutableBytes)[0] = oneW >> 8;
                    ((unsigned char *) mdReadData.mutableBytes)[1] = oneW & 0xFF;
                }
                else {
                    ret = [fInput readBits:toGrab intoBuffer:mdReadData.mutableBytes ofLength:toGrab];
                    XCTAssertTrue(ret, @"UT-FILE: Error: failed to read %d bits with %d remaining (iteration %d).", toGrab, numBits, n);
                }
            }
            
            numBits -= toGrab;
            
            //  - now carefully put the bits into the output buffer.
            for (int j = 0; j < toGrab; j++) {
                int byte = j >> 3;
                int bit = (j & 0x7);
                
                unsigned char bval = ((unsigned char *) mdReadData.bytes)[byte] & (1 << (7 - bit)) ? 1 : 0;
                ((unsigned char *) mdFullBuffer.mutableBytes)[curIndex] |= (bval << (7 - bitNum));
                
                bitNum++;
                if (bitNum > 7) {
                    curIndex++;
                    bitNum = 0;
                }
            }
        }
        
        ret = [fInput isEOF];
        XCTAssertTrue(ret, @"UT-FILE: not EOF as expected (iteration %d).", n);
        
        uint16_t oneMore = 0;
        ret = [fInput getw:&oneMore];
        XCTAssertFalse(ret, @"UT-FILE: retrieved one more word when we did not expect it (iteration %d).", n);
        
        [fInput release];
        
        //  compare the results
        ret = [mdFullBuffer isEqualToData:mdInput];
        XCTAssertTrue(ret, @"UT-FILE: Error: buffers do not match (iteration %d)!", n);
    }
    
    NSLog(@"UT-FILE: - completed read unit tests.");
}

/*
 *  Do a couple simple write tests using the given strategy.
 */
-(void) verifyWriteWithStrategy:(RSI_compression_strategy_e) strategy
{
    NSLog(@"UT-FILE: - strategy-%d tests", strategy);
    
    @autoreleasepool {
        NSMutableData *mdBuffer = [NSMutableData dataWithLength:0xFFFF];
        
        NSLog(@"UT-FILE: - compressing a simple text string");
        RSI_zlib_file *zlWrite = [[[RSI_zlib_file alloc] initForWriteWithLevel: RSI_CL_BEST andWindowBits:15 andStategy:strategy withError:&err] autorelease];
        XCTAssertNotNil(zlWrite, @"Failed to create a compressed output stream.  %@", [err localizedDescription]);
        
        const char *SAMPLE_TEXT = "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";
        
        size_t len = strlen(SAMPLE_TEXT) + 1;
        int i = 0;
 
        while (i < len) {
            size_t toAdd = (rand() % 5) + 1;
            
            if (i+toAdd > len) {
                toAdd = len - i;
            }
            
            BOOL ret = [zlWrite writeToOutput:(const unsigned char *) &(SAMPLE_TEXT[i]) withLength:toAdd];
            XCTAssertTrue(ret, @"Failed to write text to the compressed output stream.");
            i+=toAdd;
        }
                               
        NSData *dCompressed = [zlWrite fileData];
        XCTAssertNotNil(dCompressed, @"Failed to retrieve compressed data from the output stream.");
        NSLog(@"UT-FILE: - string of length %d was compressed to length %u.", len, [dCompressed length]);
                               
        RSI_zlib_file *zlRead = [[[RSI_zlib_file alloc] initForReadWithData:dCompressed andError:&err] autorelease];
        XCTAssertNotNil(zlRead, @"Failed to open the compressed output stream.  %@", [err localizedDescription]);

        BOOL ret = [zlRead readBytes:len intoBuffer:mdBuffer.mutableBytes ofLength:[mdBuffer length]];
        XCTAssertTrue(ret, @"Failed to read from the compressed text stream.");
        
        XCTAssertEqual(strncmp(mdBuffer.bytes, SAMPLE_TEXT, len), 0, @"Failed to identify the same string after compression.");
        NSLog(@"UT-FILE: - simple text was decompressed successfully.");
        
        const int NUM_ITER = 256;
        NSMutableData *mdOrig = [NSMutableData dataWithLength:2048];
        RSI_SHA256 *shaLast = [[[RSI_SHA256 alloc] init] autorelease];
        RSI_SHA256 *shaCur  = [[[RSI_SHA256 alloc] init] autorelease];
        NSLog(@"UT-FILE: - compressing random blobs of data %d times.", NUM_ITER);
        for (int i = 0; i < NUM_ITER; i++) {
            RSI_SHA256 *tSHA = shaCur;
            shaCur           = shaLast;
            shaLast          = tSHA;
            
            //  - first generate the sample content
            for (int j = 0; j < i + 1024; j++) {
                unsigned char val = (rand() & 0xFF);
                ((unsigned char *)mdOrig.mutableBytes)[j] = val;
            }
            
            [shaCur reset];
            [shaCur update:mdOrig.bytes withLength:i+1024];
            RSI_securememory *smCur  = [shaCur hash];
            RSI_securememory *smLast = [shaLast hash];
        
            
            ret = [smCur isEqualToSecureData:smLast];
            XCTAssertFalse(ret, @"The current and previous buffers are not different as expected.");
            
            //  - then compress it.
            zlWrite = [[[RSI_zlib_file alloc] initForWriteWithLevel: RSI_CL_BEST andWindowBits:15 andStategy:strategy withError:&err] autorelease];
            XCTAssertNotNil(zlWrite, @"Failed to create a compressed output stream for iteration %d.  %@", i, [err localizedDescription]);
        
            ret = [zlWrite writeToOutput:mdOrig.bytes withLength:i + 1024];
            XCTAssertTrue(ret, @"Failed to write text to the compressed output stream for iteration %d.", i);
            
            NSData *dCompressed = [zlWrite fileData];
            XCTAssertNotNil(dCompressed, @"Failed to retrieve compressed data from the output stream for iteration %d.", i);
            
            //  - then read it
            zlRead = [[[RSI_zlib_file alloc] initForReadWithData:dCompressed andError:&err] autorelease];
            XCTAssertNotNil(zlRead, @"Failed to open the compressed output stream for iteration %d.  %@", i, [err localizedDescription]);
            
            ret = [zlRead readBytes:(i+1024) intoBuffer:mdBuffer.mutableBytes ofLength:[mdBuffer length]];
            XCTAssertTrue(ret, @"Failed to read from the compressed text stream for iteration %d.", i);
            
            //  - and verify it.
            XCTAssertEqual(memcmp(mdBuffer.bytes, mdOrig.bytes, i + 1024), 0, @"Failed to verify the sample data from iteration %d.", i);            
        }
        NSLog(@"UT-FILE: - all random blobs were compressed and verified");        
    }
}

/*
 *  Verify that compression/decompression works.
 */
-(void) testUTFILE_2_Compression
{
    NSLog(@"UT-FILE: - starting compressed file unit tests");
    
    time_t tNow = time(NULL);
    NSLog(@"UT-FILE: - using seed %lu", tNow);
    srand((unsigned int) tNow);

    [self verifyWriteWithStrategy:RSI_CS_DEFAULT];
    [self verifyWriteWithStrategy:RSI_CS_FILTERED];
    [self verifyWriteWithStrategy:RSI_CS_FIXED];
    [self verifyWriteWithStrategy:RSI_CS_HUFFMAN];
    [self verifyWriteWithStrategy:RSI_CS_RLE];
    
    NSLog(@"UT-FILE: - completed compression unit tests.");
}

/*
 *  Verify compression performance.
 */
-(void) testUTFILE_3_CompressionPerf
{
    NSLog(@"UT-FILE: - starting compressed file performance tests");
    
    NSLog(@"UT-FILE: - creating a compressed file");
    RSI_zlib_file *zfile = [[[RSI_zlib_file alloc] initForWriteWithLevel:RSI_CL_BEST andWindowBits:15 andStategy:RSI_CS_DEFAULT withError:&err] autorelease];
    XCTAssertNotNil(zfile, @"Failed to create the compressed file.  %@", [err localizedDescription]);
    
    NSUInteger targetLength = (1024 * 1024 * 100);
    NSUInteger curLength = 0;
    NSMutableData *sampleData = [NSMutableData dataWithLength:1024*1024];
    SecRandomCopyBytes(kSecRandomDefault, [sampleData length], sampleData.mutableBytes);
    
    NSUInteger curPos = 0;
    NSUInteger sampleLen = [sampleData length] / sizeof(uint32_t);
    uint32_t *samplePtr = (uint32_t *) [sampleData bytes];
    
    NSLog(@"UT-FILE: - writing a bunch of random bits to the file (about %uMB worth).", targetLength/(1024*1024));
    while (curLength < targetLength) {
        uint32_t sample = samplePtr[curPos];
        uint32_t toWrite = (sample & ((1<<5)-1))+1;
        BOOL ret = [zfile writeBits:sample ofLength:toWrite];
        XCTAssertTrue(ret, @"Failed to write to the output file.");
        curLength += toWrite;
        
        curPos++;
        if (curPos >= sampleLen) {
            curPos = 0;
        }
    }
    
    NSData *dResult = [zfile fileData];
    XCTAssertNotNil(dResult, @"Failed to get a result file.");
    XCTAssertTrue([dResult length] > 0, @"The result file is too small.");
    NSLog(@"UT-FILE: - the compressed file had %u bytes at %2.2f%% the size of original", [dResult length], ((CGFloat)[dResult length]/(CGFloat)targetLength)*100.0f);
    
    NSLog(@"UT-FILE: - completed compression performance tests.");
}

@end
