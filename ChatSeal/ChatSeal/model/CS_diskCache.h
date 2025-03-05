//
//  CS_diskCache.h
//  ChatSeal
//
//  Created by Francis Grolemund on 11/3/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CS_diskCache : NSObject
+(NSData *) cachedDataWithBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(BOOL) saveCachedData:(NSData *) dataToCache withBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(void) invalidateCacheItemWithBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(void) invalidateCacheCategory:(NSString *) category;
+(NSSet *) secureCachedBaseNamesInCategory:(NSString *) category;
+(NSObject *) secureCachedDataWithBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(BOOL) saveSecureCachedData:(NSObject *) obj withBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(UIImage *) cachedLossyImageWithBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(BOOL) saveLossyImage:(UIImage *) img withBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(void) invalidateLossyImageWithBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(BOOL) invalidateEntireCache;
+(UIImage *) cachedImageWithBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(BOOL) saveImage:(UIImage *) img withBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(void) invalidateImageWithBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(UIImage *) cachedSecureImageWithBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(BOOL) saveSecureImage:(UIImage *) img withBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(void) invalidateSecureImageWithBaseName:(NSString *) baseName andCategory:(NSString *) category;
@end
