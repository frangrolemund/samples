//
//  tdriverColorSplitFns.h
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 9/8/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

typedef struct
{
    float vals[9];
} CS_adjustment_values_t;

// NOTE:  These conversions were snagged from Stack Overflow and just used
//        temporarily to see if the concept is accurate.
typedef struct {
    float h;       // angle in degrees
    float s;       // percent
    float v;       // percent
} hsv;

hsv          rgb2hsv(GLKVector4 in);
GLKVector4   hsv2rgb(hsv in);

@interface tdriverColorSplitFns : NSObject
+(UIColor *) startingColor;
+(void) splitColor:(UIColor *) c intoComponentA:(GLKVector4 *) compA andComponentB:(GLKVector4 *) compB;
+(CS_adjustment_values_t) getAdjustmentValues;
+(void) setAdjustmentValues:(CS_adjustment_values_t) vals;
@end
