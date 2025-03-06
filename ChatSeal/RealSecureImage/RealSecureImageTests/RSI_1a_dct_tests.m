//
//  RSI_1a_dct_tests.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/2/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "RSI_1a_dct_tests.h"
#import "RSI_common.h"
#import "RSI_pack.h"
#import "RSI_jpeg.h"

//  - taken from the Wikipedia entry to allow for easy verification of
//    even the simplest one.
static du_t RSI_1a_DCT_DU = {-76, -73, -67, -62, -58, -67, -64, -55,
                             -65, -69, -73, -38, -19, -43, -59, -56,
                             -66, -69, -60, -15,  16,  -24, -62, -55,
                             -65, -70, -57, -6,  26,  -22, -58, -59,
                             -61, -67, -60, -24, -2,  -40, -60, -58,
                             -49, -63, -68, -58, -51, -60, -70, -53,
                             -43, -57, -64, -69, -73, -67, -63, -45,
                             -41, -49, -59, -60, -63, -52, -50, -34
};

@implementation RSI_1a_dct_tests

/*
 *  Basic initialization
 */
-(void) setUp
{
    [super setUp];    
    self.continueAfterFailure = NO;    
}

/*
 *  Verify that the DCTs all produce the same results.
 */
-(void) testUTDCT_1_Baseline
{
    NSLog(@"UT-FDCT: - verifying that the various DCT implementations are equivalent.");
    quant_table_t qtStd;
    memset(&qtStd, 1, sizeof(qtStd));
    
    du_t duBaseline, duColRow, duFast;
    for (int i = 0; i < 64; i++) {
        duBaseline[i] = RSI_1a_DCT_DU[i];
        duColRow[i]   = RSI_1a_DCT_DU[i];
        duFast[i]     = RSI_1a_DCT_DU[i];
    }
    
    [JPEG_pack FDCTBaseline:duBaseline withQuant:qtStd];
    [JPEG_pack FDCTColumnsAndRows:duColRow withQuant:qtStd];
    [JPEG_pack FDCTPracticalFast:duFast withQuant:qtStd];
    
    for (int i = 0; i < 64; i++) {
        BOOL ret = abs(duBaseline[i] - duColRow[i]) < 2 && abs(duBaseline[i] - duFast[i]) < 2;
        XCTAssertTrue(ret, @"Old and new FDCT do not match.");
    }
    
    NSLog(@"UT-FDCT: - the three FDCT implementations are equivalent.");
}

/*
 *  Performance testing of the fast DCT algorithm.
 */
-(void) testUTDCT_2_Perf
{
    NSLog(@"UT-FDCT: - measuring fast DCT performance.");
    quant_table_t qtStd;
    memset(&qtStd, 1, sizeof(qtStd));
    
    du_t duNew;
    for (int i = 0; i < 2000000; i++) {
        memcpy(duNew, RSI_1a_DCT_DU, sizeof(RSI_1a_DCT_DU));
        [JPEG_pack FDCTPracticalFast:duNew withQuant:qtStd];
    }
}

@end
