//
//  CS_diskCache.m
//  ChatSeal
//
//  Created by Francis Grolemund on 11/3/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "CS_diskCache.h"
#import "ChatSeal.h"

// - constants
static const NSUInteger CS_DC_VERSION            = 1;             // increment this to automatically invalidate old content.
static NSString *CS_DC_LOSSY_EXT                 = @"jpg";
static const CGFloat CS_DC_LOSSY_QUALITY         = 0.75f;
static NSString *CS_DC_CACHE_EXT                 = @"cache";
static NSString *CS_DC_ITEM_KEY                  = @"cacheItem";
static NSString *CS_DC_VER_KEY                   = @"cacheVersion";
static NSString *CS_DC_ID_KEY                    = @"cacheId";
static NSString *CS_DC_ID_NAME                   = @"RealCacheItem";
static NSString *CS_DC_NOLOSSY_EXT               = @"png";
static NSString *CS_DC_DOUBLE_RES                = @"@2x";
static NSMutableDictionary *mdKnownCategoryPaths = nil;

// - forward declarations
@interface CS_diskCache (internal)
+(NSURL *) rootCacheDirectory;
+(NSURL *) cacheURLForCategory:(NSString *) category;
+(NSURL *) cacheURLForCategory:(NSString *) category andBaseName:(NSString *) baseName;
+(NSURL *) cacheURLForCategory:(NSString *) category andBaseName:(NSString *) baseName andExtension:(NSString *) ext;
+(void) invalidateCacheItemWithBaseName:(NSString *)baseName andCategory:(NSString *)category andExtension:(NSString *) ext;
+(void) invalidateCacheItem:(NSURL *) itemURL;
+(BOOL) cacheWriteData:(NSData *) d toURL:(NSURL *) u;
+(NSData *) cacheItemToStandardArchive:(NSObject *) obj;
+(NSObject *) standardArchiveToCacheItem:(NSData *) archive;
+(BOOL) saveCachedArchive:(NSData *) dArchive withBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(void) handleCacheFailureToURL:(NSURL *) u;
+(UIImage *) cachedImageWithBaseName:(NSString *)baseName andCategory:(NSString *)category andExtension:(NSString *) ext;
+(void) invalidateAllImageVariantsWithBaseName:(NSString *)baseName andCategory:(NSString *)category andExtension:(NSString *) ext;
+(NSSet *) cachedBaseNamesInCategory:(NSString *) category withExtension:(NSString *) ext;
@end


/***********************
 CS_diskCache
 ***********************/
@implementation CS_diskCache
/*
 *  Initialize the module.
 */
+(void) initialize
{
    mdKnownCategoryPaths = [[NSMutableDictionary alloc] init];
}

/*
 *  Return a previously cached data item at the given base and category.
 */
+(NSData *) cachedDataWithBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    NSURL *u = [CS_diskCache cacheURLForCategory:category andBaseName:baseName];
    if (u) {
        return [NSData dataWithContentsOfURL:u options:NSDataReadingUncached error:nil];
    }
    return nil;
}

/*
 *  Cache a data item at the given base and category.
 */
+(BOOL) saveCachedData:(NSData *) dataToCache withBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    if (!dataToCache) {
        return NO;
    }
    return [CS_diskCache saveCachedArchive:dataToCache withBaseName:baseName andCategory:category];
}

/*
 *  Invalidate a data item at the given base and category.
 */
+(void) invalidateCacheItemWithBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    [CS_diskCache invalidateCacheItemWithBaseName:baseName andCategory:category andExtension:CS_DC_CACHE_EXT];
}

/*
 *  Invalidate an entire category.
 */
+(void) invalidateCacheCategory:(NSString *) category
{
    if (!category) {
        return;
    }
    
    NSURL *u = [CS_diskCache cacheURLForCategory:category];
    if (u) {
        [CS_diskCache invalidateCacheItem:u];
        @synchronized (mdKnownCategoryPaths) {
            [mdKnownCategoryPaths removeObjectForKey:category];
        }
    }
}

/*
 *  The purpose of this method is to make it possible to enumerate the whole list of cached items in the given
 *  category.
 */
+(NSSet *) secureCachedBaseNamesInCategory:(NSString *) category
{
    return [self cachedBaseNamesInCategory:category withExtension:CS_DC_CACHE_EXT];
}

/*
 *  Return a previously cached data item from the vault at the given base and category.
 */
+(NSObject *) secureCachedDataWithBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    NSURL *u = [CS_diskCache cacheURLForCategory:category andBaseName:baseName];
    if (u) {
        RSISecureData *secD = nil;
        if ([RealSecureImage readVaultURL:u intoData:&secD withError:nil]) {
            NSObject *obj = [CS_diskCache standardArchiveToCacheItem:secD.rawData];
            if (obj) {
                return obj;
            }
            
            //  - when the item is invalid or old, we're going to just delete it.
            NSLog(@"CS: The archive data at %@ is invalid.", [u path]);
            [[NSFileManager defaultManager] removeItemAtURL:u error:nil];
        }
    }
    return nil;
}

/*
 *  Cache a data item securely at the given base and category.
 */
+(BOOL) saveSecureCachedData:(NSObject *) obj withBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    if (!obj) {
        return NO;
    }
    
    NSData *d = [CS_diskCache cacheItemToStandardArchive:obj];
    if (d) {
        NSURL *u = [CS_diskCache cacheURLForCategory:category andBaseName:baseName];
        if (u) {
            if ([RealSecureImage writeVaultData:d toURL:u withError:nil]) {
                return YES;
            }
            [CS_diskCache handleCacheFailureToURL:u];
        }
    }
    return NO;
}

/*
 *  Return a cached image from the given location.
 */
+(UIImage *) cachedLossyImageWithBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    return [CS_diskCache cachedImageWithBaseName:baseName andCategory:category andExtension:CS_DC_LOSSY_EXT];
}

/*
 *  Cache an image into the given location.
 */
+(BOOL) saveLossyImage:(UIImage *) img withBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    if (!img) {
        return NO;
    }
    
    NSData *d = UIImageJPEGRepresentation(img, CS_DC_LOSSY_QUALITY);
    if (d) {
        if (img.scale > 1.0f) {
            baseName = [baseName stringByAppendingString:CS_DC_DOUBLE_RES];
        }
        NSURL *u = [CS_diskCache cacheURLForCategory:category andBaseName:baseName andExtension:CS_DC_LOSSY_EXT];
        return [CS_diskCache cacheWriteData:d toURL:u];
    }
    return NO;
}

/*
 *  Invalidate an existing lossy image.
 */
+(void) invalidateLossyImageWithBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    [CS_diskCache invalidateAllImageVariantsWithBaseName:baseName andCategory:category andExtension:CS_DC_LOSSY_EXT];
}


/*
 *  Return a cached image from the given location.
 */
+(UIImage *) cachedImageWithBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    return [CS_diskCache cachedImageWithBaseName:baseName andCategory:category andExtension:CS_DC_NOLOSSY_EXT];
}

/*
 *  Cache an image into the given location.
 */
+(BOOL) saveImage:(UIImage *) img withBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    if (!img) {
        return NO;
    }
    
    NSData *d = UIImagePNGRepresentation(img);
    if (d) {
        if (img.scale > 1.0f) {
            baseName = [baseName stringByAppendingString:CS_DC_DOUBLE_RES];
        }
        NSURL *u = [CS_diskCache cacheURLForCategory:category andBaseName:baseName andExtension:CS_DC_NOLOSSY_EXT];
        return [CS_diskCache cacheWriteData:d toURL:u];
    }
    return NO;
}

/*
 *  Invalidate an existing lossy image.
 */
+(void) invalidateImageWithBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    [CS_diskCache invalidateAllImageVariantsWithBaseName:baseName andCategory:category andExtension:CS_DC_NOLOSSY_EXT];
}

/*
 *  Discard the entire disk cache.
 */
+(BOOL) invalidateEntireCache
{
    NSURL *u = [CS_diskCache rootCacheDirectory];
    if (u) {
        NSError *err = nil;
        if ([[NSFileManager defaultManager] fileExistsAtPath:[u path]]) {
            if (![[NSFileManager defaultManager] removeItemAtURL:u error:&err]) {
                NSLog(@"CS: Failed to remove the disk cache.  %@", [err localizedDescription]);
                return NO;
            }
        }
    }
    return YES;
}

/*
 *  Return a cached secure image.
 */
+(UIImage *) cachedSecureImageWithBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    NSObject *obj = [CS_diskCache secureCachedDataWithBaseName:baseName andCategory:category];
    if (obj && [obj isKindOfClass:[NSData class]]) {
        return [UIImage imageWithData:(NSData *) obj];
    }
    return nil;
}

/*
 *  Save an image securely.
 */
+(BOOL) saveSecureImage:(UIImage *) img withBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    NSData *d = UIImagePNGRepresentation(img);
    if (d) {
        return [CS_diskCache saveSecureCachedData:d withBaseName:baseName andCategory:category];
    }
    return NO;
}

/*
 *  Invalidate a cached secure image.
 */
+(void) invalidateSecureImageWithBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    [CS_diskCache invalidateCacheItemWithBaseName:baseName andCategory:category];
}

@end

/***********************
 CS_diskCache (internal)
 ***********************/
@implementation CS_diskCache (internal)
/*
 *  Return the cache root for the app.
 */
+(NSURL *) rootCacheDirectory
{
    static NSURL *rootCache = nil;
    if (!rootCache) {
        NSError *err = nil;
        NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&err];
        if (!u) {
            NSLog(@"CS:  Failed to retrieve a cache directory root.  %@", [err localizedDescription]);
            return nil;
        }
        rootCache = [[u URLByAppendingPathComponent:@"ChatSeal"] retain];
    }
    return [[rootCache retain] autorelease];
}

/*
 *  Generate and return a cache directory for the given category.
 */
+(NSURL *) cacheURLForCategory:(NSString *) category
{
    // - bacause the cache is hit constantly and manufacturing URLs is crazy slow, we're going
    //   to do it only when we absolutely need to.
    NSString *sPath = nil;
    @synchronized (mdKnownCategoryPaths) {
        sPath = [[[mdKnownCategoryPaths objectForKey:category] retain] autorelease];
    }
    
    BOOL doesExist = YES;
    if (!sPath) {
        NSURL *u = [CS_diskCache rootCacheDirectory];
        if (!u) {
            return nil;
        }
        
        // - I'm explicitly splitting and recombining these to
        //   ensure that they are precisely constructed because the category
        //   can have sub-directories.
        NSArray *arr = [category componentsSeparatedByString:@"/"];
        sPath        = [u path];
        for (NSString *comp in arr) {
            sPath = [sPath stringByAppendingString:@"/"];
            sPath = [sPath stringByAppendingString:comp];
        }
        doesExist = NO;
    }
    
    NSError *err = nil;
    NSURL *u     = [NSURL fileURLWithPath:sPath isDirectory:YES];
    if (!doesExist) {
        if (![[NSFileManager defaultManager] fileExistsAtPath:[u path]]) {
            if (![[NSFileManager defaultManager] createDirectoryAtPath:[u path] withIntermediateDirectories:YES attributes:nil error:&err]) {
                NSLog(@"PS  Failed to create a cache directory at %@.  %@", [u path], [err localizedDescription]);
                return nil;
            }
        }
        
        @synchronized (mdKnownCategoryPaths) {
            [mdKnownCategoryPaths setObject:sPath forKey:category];
        }
    }
    return u;
}

/*
 *  Return a URL for the given specification.
 */
+(NSURL *) cacheURLForCategory:(NSString *) category andBaseName:(NSString *) baseName
{
    return [CS_diskCache cacheURLForCategory:category andBaseName:baseName andExtension:CS_DC_CACHE_EXT];
}

/*
 *  Return a URL for the given specification.
 */
+(NSURL *) cacheURLForCategory:(NSString *) category andBaseName:(NSString *) baseName andExtension:(NSString *) ext
{
    if (!category || !baseName || !ext) {
        return nil;
    }
    
    NSURL *u = [CS_diskCache cacheURLForCategory:category];
    if (u) {
        NSString *sFile = [NSString stringWithFormat:@"%@/%@.%@", [u path], baseName, ext];
        u = [NSURL fileURLWithPath:sFile isDirectory:NO];
    }
    return u;
}

/*
 *  Invalidate a specific item.
 */
+(void) invalidateCacheItemWithBaseName:(NSString *)baseName andCategory:(NSString *)category andExtension:(NSString *) ext
{
    NSURL *u = [CS_diskCache cacheURLForCategory:category andBaseName:baseName andExtension:ext];
    if (u) {
        [CS_diskCache invalidateCacheItem:u];
    }
}

/*
 *  Delete the item at the given URL.
 */
+(void) invalidateCacheItem:(NSURL *) itemURL
{
    NSError *err = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:[itemURL path]] &&
        ![[NSFileManager defaultManager] removeItemAtURL:itemURL error:&err]) {
        NSLog(@"CS:  Failed to invalidate the cached item at %@.  %@", itemURL, [err localizedDescription]);
    }
}

/*
 *  Write cache data with the required semantics of success or nothing should exist.
 */
+(BOOL) cacheWriteData:(NSData *) d toURL:(NSURL *) u
{
    if (u) {
        if ([d writeToURL:u atomically:YES]) {
            return YES;
        }
        [CS_diskCache handleCacheFailureToURL:u];
    }
    return NO;
}

/*
 *  Convert an object to a standard versioned cache archive.
 */
+(NSData *) cacheItemToStandardArchive:(NSObject *) obj
{
    if (!obj) {
        return nil;
    }
    
    // - create the standard archive contents
    NSMutableDictionary *mdCache = [NSMutableDictionary dictionary];
    [mdCache setObject:CS_DC_ID_NAME forKey:CS_DC_ID_KEY];
    [mdCache setObject:[NSNumber numberWithUnsignedInteger:CS_DC_VERSION] forKey:CS_DC_VER_KEY];
    [mdCache setObject:obj forKey:CS_DC_ITEM_KEY];
    
    // - now archive it.
    NSData *dRet = nil;
    @try {
        dRet = [NSKeyedArchiver archivedDataWithRootObject:mdCache];
    }
    @catch (NSException *exception) {
        NSLog(@"CS:  The disk cache archive generated an exception.  %@", [exception description]);
    }
    return dRet;
}

/*
 *  Convert a cache archive back to an item.
 */
+(NSObject *) standardArchiveToCacheItem:(NSData *) archive
{
    NSObject *obj = nil;
    @try {
        obj = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
    }
    @catch (NSException *exception) {
        NSLog(@"CS:  The disk cache archive caused an exception.  %@", [exception description]);
    }
    if (obj && [obj isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *) obj;
        NSObject *objId    = nil;
        NSObject *objVer   = nil;
        NSObject *objItem  = nil;
        if ((objId   = [dict objectForKey:CS_DC_ID_KEY]) &&
            (objVer  = [dict objectForKey:CS_DC_VER_KEY]) &&
            (objItem = [dict objectForKey:CS_DC_ITEM_KEY])) {
            if ([objId isKindOfClass:[NSString class]] &&
                [(NSString *) objId isEqualToString:CS_DC_ID_NAME] &&
                [objVer isKindOfClass:[NSNumber class]] &&
                ((NSNumber *) objVer).unsignedIntegerValue == CS_DC_VERSION) {
                return objItem;
            }
        }
    }
    return nil;
}

/*
 *  Save a cached archive to disk.
 */
+(BOOL) saveCachedArchive:(NSData *) dArchive withBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    NSURL *u = [CS_diskCache cacheURLForCategory:category andBaseName:baseName];
    if (u) {
        return [CS_diskCache cacheWriteData:dArchive toURL:u];
    }
    return NO;
}

/*
 *  When WRITING content to the cache, any failure should be sent through here.
 */
+(void) handleCacheFailureToURL:(NSURL *) u
{
    // - when we get a cache failure, it is important to delete the prior content because
    //   we know that it is stale
    if ([[NSFileManager defaultManager] fileExistsAtPath:[u path]]) {
        NSLog(@"CS:  Cache write failure, auto-deleting old content.");
    }
    [[NSFileManager defaultManager] removeItemAtURL:u error:nil];           // unconditional because I'm not 100% sure fileExists works when we get full space scenarios.
}

/*
 *  Return an image cached at the given location.
 */
+(UIImage *) cachedImageWithBaseName:(NSString *)baseName andCategory:(NSString *)category andExtension:(NSString *) ext
{
    NSURL *u = [CS_diskCache cacheURLForCategory:category andBaseName:baseName andExtension:ext];
    if (u) {
        return [UIImage imageWithContentsOfFile:[u path]];
    }
    return nil;
}

/*
 *  Ensure the different resolution variants are invalidated.
 */
+(void) invalidateAllImageVariantsWithBaseName:(NSString *)baseName andCategory:(NSString *)category andExtension:(NSString *) ext
{
    [CS_diskCache invalidateCacheItemWithBaseName:baseName andCategory:category andExtension:ext];
    baseName = [baseName stringByAppendingString:CS_DC_DOUBLE_RES];
    [CS_diskCache invalidateCacheItemWithBaseName:baseName andCategory:category andExtension:ext];
}

/*
 *  Return the list of base names in the given category in the cache.
 */
+(NSSet *) cachedBaseNamesInCategory:(NSString *) category withExtension:(NSString *) ext
{
    NSMutableSet *msCurrent = [NSMutableSet set];
    NSURL *u                = [CS_diskCache cacheURLForCategory:category];
    NSArray *arrItems       = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:u includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLIsDirectoryKey, NSURLPathKey, nil] options:NSDirectoryEnumerationSkipsSubdirectoryDescendants error:nil];
    for (NSURL *uOneCached in arrItems) {
        NSNumber *nIsDir = nil;
        if (![uOneCached getResourceValue:&nIsDir forKey:NSURLIsDirectoryKey error:nil] || [nIsDir boolValue]) {
            continue;
        }
        NSString *path = nil;
        if (![uOneCached getResourceValue:&path forKey:NSURLPathKey error:nil]) {
            continue;
        }
        
        if (ext) {
            NSRange r = [path rangeOfString:ext];
            if (r.location == NSNotFound && r.location > 0) {
                continue;
            }
            path = [path substringToIndex:r.location - 1];
        }
        
        // - save off the item without the extension.
        [msCurrent addObject:[path lastPathComponent]];
    }
    return msCurrent;
}

@end
