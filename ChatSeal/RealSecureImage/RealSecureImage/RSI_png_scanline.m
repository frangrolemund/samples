//
//  RSI_png_scanline.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/10/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "RSI_png_scanline.h"


/*****************************
 RSI_png_scanline
 *****************************/
@implementation RSI_png_scanline
/*
 *  Object attributes.
 */
{
    NSMutableData *mdScanLine1;
    NSMutableData *mdScanLine2;
    
    unsigned char *curScanLine;
    unsigned char *prevScanLine;
}

/*
 *  Initialize the object.
 */
-(id) initWithWidth:(NSUInteger) imageWidth
{
    self = [super init];
    if (self) {
        NSUInteger scanBufLen = ((imageWidth + 7) & ~(NSUInteger)0x07) + 1;
        mdScanLine1           = [[NSMutableData alloc] initWithLength:(scanBufLen << 2)];
        curScanLine           = (unsigned char *) [mdScanLine1 mutableBytes];
        mdScanLine2           = [[NSMutableData alloc] initWithLength:(scanBufLen << 2)];
        prevScanLine          = (unsigned char *) [mdScanLine2 mutableBytes];
    }
    return self;
}

/*
 *  Free the object
 */
-(void) dealloc
{
    curScanLine = NULL;
    prevScanLine = NULL;
    
    [mdScanLine1 release];
    mdScanLine1 = nil;
    
    [mdScanLine2 release];
    mdScanLine2 = nil;
    
    [super dealloc];
}

/*
 *  Advance to the next scanline
 */
-(void) advance
{
    unsigned char *tmp = prevScanLine;
    prevScanLine = curScanLine;
    curScanLine = tmp;
}

/*
 *  Interlaced PNG files erase the previous scanline between passes.
 */
-(void) resetHistory
{
    memset(prevScanLine, 0, [mdScanLine1 length]);
}

/*
 *  Returns the address of the empty pixel in the current scanline.
 */
-(unsigned char *) current
{
    return curScanLine;
}

/*
 *  Returns the address of the empty pixel in the previous scanline.
 */
-(unsigned char *) previous
{
    return prevScanLine;
}


@end
