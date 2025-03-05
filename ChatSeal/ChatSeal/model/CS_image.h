//
//  CS_image.h
//  ChatSeal
//
//  Created by Francis Grolemund on 4/28/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CS_image : NSObject
+(UIImage *) loadPNGImmediatelyAtPath:(NSString *) path withError:(NSError **) err;
+(UIImage *) loadJPGImmediatelyAtPath:(NSString *) path withError:(NSError **) err;
+(UIImage *) loadJPGImmediatelyWithData:(NSData *) data withError:(NSError **) err;

+(NSData *) imageToRawFormat:(UIImage *) img withError:(NSError **) err;
+(UIImage *) rawFormatToImage:(NSData *) dImage withError:(NSError **) err;

+(UIImage *) imageScaledToMaximumPoints:(CGFloat) maxDimension forSource:(UIImage *) img;
+(UIImage *) threadSafeImageScaledToMaximumPoints:(CGFloat) maxDimension forSourcePath:(NSString *) imgPath;
+(UIImage *) tableReadyUIScaledImage:(UIImage *) img;
+(UIImage *) collectionReadyUIScaledImage:(UIImage *) img;
@end
