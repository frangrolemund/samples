//
//  ImageLoader.h
//
//  Created by Francis Grolemund on 11/9/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum _nj_result {
    NJ_OK = 0,        // no error, decoding successful
    NJ_NO_JPEG,       // not a JPEG file
    NJ_UNSUPPORTED,   // unsupported format
    NJ_OUT_OF_MEM,    // out of memory
    NJ_INTERNAL_ERR,  // internal error
    NJ_SYNTAX_ERROR,  // syntax error
    __NJ_FINISHED,    // used internally, will never be reported
} nj_result_t;

@interface ImageLoader : NSObject

+(nj_result_t) unpackImageData:(NSData *) jpegImage;

@end
