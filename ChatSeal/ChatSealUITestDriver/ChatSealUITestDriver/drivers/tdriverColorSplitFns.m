//
//  tdriverColorSplitFns.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 9/8/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import "tdriverColorSplitFns.h"

static CS_adjustment_values_t adjustmentValues = {{0.19f, 0.75f, 0.22f,            //  the 3 percentages to cut the colors on
                                                   1.25f, 1.25f, 1.25f,            //  the brightness adjustments for color A
                                                   1.19f, 1.19f, 1.19f}};           //  the brightness adjustments for color B

hsv rgb2hsv(GLKVector4 in)
{
    hsv         out;
    double      min, max, delta;
    
    min = in.r < in.g ? in.r : in.g;
    min = min  < in.b ? min  : in.b;
    
    max = in.r > in.g ? in.r : in.g;
    max = max  > in.b ? max  : in.b;
    
    out.v = max;                                // v
    delta = max - min;
    if( max > 0.0 ) {
        out.s = (delta / max);                  // s
    } else {
        // r = g = b = 0                        // s = 0, v is undefined
        out.s = 0.0;
        out.h = NAN;                            // its now undefined
        return out;
    }
    if( in.r >= max )                           // > is bogus, just keeps compilor happy
        out.h = ( in.g - in.b ) / delta;        // between yellow & magenta
    else
        if( in.g >= max )
            out.h = 2.0 + ( in.b - in.r ) / delta;  // between cyan & yellow
        else
            out.h = 4.0 + ( in.r - in.g ) / delta;  // between magenta & cyan
    
    out.h *= 60.0;                              // degrees
    
    if( out.h < 0.0 )
        out.h += 360.0;
    
    return out;
}


GLKVector4 hsv2rgb(hsv in)
{
    double      hh, p, q, t, ff;
    long        i;
    GLKVector4  out;
    out.a = 1.0f;
    
    if(in.s <= 0.0) {       // < is bogus, just shuts up warnings
        out.r = in.v;
        out.g = in.v;
        out.b = in.v;
        return out;
    }
    hh = in.h;
    if(hh >= 360.0) hh = 0.0;
    hh /= 60.0;
    i = (long)hh;
    ff = hh - i;
    p = in.v * (1.0 - in.s);
    q = in.v * (1.0 - (in.s * ff));
    t = in.v * (1.0 - (in.s * (1.0 - ff)));
    
    switch(i) {
        case 0:
            out.r = in.v;
            out.g = t;
            out.b = p;
            break;
        case 1:
            out.r = q;
            out.g = in.v;
            out.b = p;
            break;
        case 2:
            out.r = p;
            out.g = in.v;
            out.b = t;
            break;
            
        case 3:
            out.r = p;
            out.g = q;
            out.b = in.v;
            break;
        case 4:
            out.r = t;
            out.g = p;
            out.b = in.v;
            break;
        case 5:
        default:
            out.r = in.v;
            out.g = p;
            out.b = q;
            break;
    }
    return out;     
}

#define clampto1(_x) ((_x) = ((_x) < 0.0f ? 0.0f : ((_x) > 1.0f ? 1.0f : (_x))))

@implementation tdriverColorSplitFns
+(UIColor *) startingColor
{
    //return [UIColor colorWithRed:1.0f green:0.576f blue:0.2f alpha:1.0f];
    return [UIColor colorWithRed:0.15 green:0.53f blue:0.35f alpha:1.0f];
}

/*
 *  Return the current adjustment values.
 */
+(CS_adjustment_values_t) getAdjustmentValues
{
    return adjustmentValues;
}

/*
 *  Assign the current adjustment values.
 */
+(void) setAdjustmentValues:(CS_adjustment_values_t) vals
{
    adjustmentValues = vals;
}


+(void) splitColor:(UIColor *) srcColor intoComponentA:(GLKVector4 *) compA andComponentB:(GLKVector4 *) compB
{
    CGFloat r, g, b, a;
    
    //  - if we can't break it down, then it is in a different color
    //    space (generally white) and there is nothing to be done.
    if (![srcColor getRed:&r green:&g blue:&b alpha:&a]) {
        *compA = GLKVector4Make(0.0f, 0.0f, 0.0f, 1.0f);
        *compB = GLKVector4Make(1.0f, 0.0f, 0.0f, 1.0f);
        return;
    }
    
    //  - break down the color into two components.
    GLKVector4 rgbA = GLKVector4Make(r, g, b, a);
    GLKVector4 rgbB = GLKVector4Make(r, g, b, a);
    
    rgbA.r *= adjustmentValues.vals[0];
    rgbA.r *= adjustmentValues.vals[3];
    clampto1(rgbA.r);
    rgbA.g *= adjustmentValues.vals[1];
    rgbA.g *= adjustmentValues.vals[4];
    clampto1(rgbA.g);
    rgbA.b *= adjustmentValues.vals[2];
    rgbA.b *= adjustmentValues.vals[5];
    clampto1(rgbA.b);
    
    rgbB.r *= (1.0 - adjustmentValues.vals[0]);
    rgbB.r *= adjustmentValues.vals[6];
    clampto1(rgbB.r);
    rgbB.g *= (1.0 - adjustmentValues.vals[1]);
    rgbB.g *= adjustmentValues.vals[7];
    clampto1(rgbB.g);
    rgbB.b *= (1.0 - adjustmentValues.vals[2]);
    rgbB.b *= adjustmentValues.vals[8];
    clampto1(rgbB.b);
    
    
    hsv hsvA = rgb2hsv(rgbA);
    hsv hsvB = rgb2hsv(rgbB);
    
    NSLog(@"DEBUG: the values are (%4.2f, %4.2f)", hsvA.v, hsvB.v);
    
    // - move back into RGB
    *compA = rgbA;
    *compB = rgbB;
}

@end
