//
//  RSI_png_scanline.h
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/10/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

//  - the point of this class is to simplify the
//    process of managing the two scanline buffers
//  - both are guaranteed to have a free pixel to
//    their left to accommodate all filtering operations.
@interface RSI_png_scanline : NSObject
-(id) initWithWidth:(NSUInteger) imageWidth;
-(void) advance;
-(void) resetHistory;

-(unsigned char *) current;
-(unsigned char *) previous;

@end
