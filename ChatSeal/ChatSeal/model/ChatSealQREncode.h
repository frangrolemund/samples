//
//  ChatSealQREncode.h
//  ChatSeal
//
//  Created by Francis Grolemund on 2/2/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

#define CS_QRE_VERSION_AUTO 0
#define CS_QRE_MIN_VERSION  1
#define CS_QRE_MAX_VERSION 40

typedef enum {
    CS_QRE_EC_LOW  = 0,                  //  low
    CS_QRE_EC_MED  = 1,                  //  medium
    CS_QRE_EC_QUT  = 2,                  //  quartile
    CS_QRE_EC_HI   = 3,                  //  high
    CS_QRE_EC_AUTO = CS_QRE_EC_LOW       //  automatic
} ps_qre_error_correction_t;

//   - I just tried to come up with something based on the
///    masking patterns displayed in Wikipedia.
typedef enum {
    CS_QRE_MP_COMPUTE = -1,     //  compute the mask
    CS_QRE_MP_COL     = 0,      //  column
    CS_QRE_MP_ZIG     = 1,      //  zig-zag
    CS_QRE_MP_CHK     = 2,      //  checkerboard
    CS_QRE_MP_ROW     = 3,      //  row
    CS_QRE_MP_FB      = 4,      //  football
    CS_QRE_MP_EXP     = 5,      //  explosion
    CS_QRE_MP_SHP     = 6,      //  ship
    CS_QRE_MP_CRS     = 7       //  cross
} ps_qre_masking_pattern_t;

@interface ChatSealQREncode : NSObject
+(UIImage *) encodeQRString:(NSString *) toEncode
                  asVersion:(NSUInteger) version                        //  use CS_QRE_VERSOIN_AUTO under normal circumstances.
                   andLevel:(ps_qre_error_correction_t) level
                    andMask:(ps_qre_masking_pattern_t) mask             //  use CS_QRE_MP_COMPUTE under normal circumstances
         andTargetDimension:(CGFloat) targetDimension
                  withError:(NSError **) err;
@end
