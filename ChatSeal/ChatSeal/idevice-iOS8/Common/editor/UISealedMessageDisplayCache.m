//
//  UISealedMessageDisplayCache.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/11/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealedMessageDisplayCache.h"

// - constants
static const NSInteger UISMDC_MAX_SECTION = 100000;
static const NSUInteger UISMDC_BLOCK_SIZE = sizeof(uint32_t) * 32;

// - forward declarations
@interface UISealedMessageDisplayCache (internal)
-(uint32_t *) heightPointerForIndexPath:(NSIndexPath *) ip;
@end

/***************************
 UISealedMessageDisplayCache
 ***************************/
@implementation UISealedMessageDisplayCache
/*
 *  Object attributes.
 */
{
    NSInteger     maxRowsPerSection;
    NSMutableData *mdCache;
}

/*
 *  Initialize the object.
 */
-(id) initWithMaximumRowsPerSection:(NSInteger) maxRows
{
    self = [super init];
    if (self) {
        // - it is expected that we're going to only support a limited number of items per message, which
        //   makes it possible to use the max rows for indexing into the cache itself.
        maxRowsPerSection = maxRows;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [mdCache release];
    mdCache = nil;
    
    [super dealloc];
}

/*
 *  Clear the cached content.
 */
-(void) clearCache
{
    if (mdCache.length) {
        bzero(mdCache.mutableBytes, mdCache.length);
    }
}

/*
 *  Cache the height of a given row.
 *  - NOTE: this approach is NECESSARY because dictionaries are very expensive to use for
 *          for many items.
 */
-(void) cacheRowHeight:(CGFloat) height forIndexPath:(NSIndexPath *) ip
{
    uint32_t toCache = (uint32_t) height;
    uint32_t *ptr    = [self heightPointerForIndexPath:ip];
    if (ptr) {
        memcpy(ptr, &toCache, sizeof(uint32_t));
    }
}

/*
 *  Return a cached row height.
 */
-(CGFloat) rowHeightForIndexPath:(NSIndexPath *) ip
{
    uint32_t *ptr = [self heightPointerForIndexPath:ip];
    if (ptr && *ptr) {
        return (CGFloat) *ptr;
    }
    return -1.0f;           // invalid row height.
}

/*
 *  Set the capacity for the number of sections.
 */
-(void) setSectionCapacity:(NSUInteger) numSections
{
    [self heightPointerForIndexPath:[NSIndexPath indexPathForRow:0 inSection:(NSInteger) numSections]];
}

@end

/***************************************
 UISealedMessageDisplayCache (internal)
 ***************************************/
@implementation UISealedMessageDisplayCache (internal)
/*
 *  Return a pointer to the location where the cached height will be stored.
 *  - returns NULL when the index is invalid.
 */
-(uint32_t *) heightPointerForIndexPath:(NSIndexPath *) ip
{
    // - the cache depends on being able to quickly index into specific rows and we
    //   assume some amount of wasted space to ensure that the index is always fast to access.
    if (ip.row >= maxRowsPerSection || maxRowsPerSection == 0 || ip.section > UISMDC_MAX_SECTION) {
        NSLog(@"CS-ALERT: unexpected row index for display cache.");
        return NULL;
    }
    
    NSUInteger desiredLength   = (NSUInteger) ((ip.section + 1) * maxRowsPerSection);
    NSUInteger desiredCapacity = (desiredLength * sizeof(uint32_t));
    if ([mdCache length] < desiredCapacity) {
        desiredCapacity = desiredCapacity +  + UISMDC_BLOCK_SIZE;
        if (mdCache) {
            if (desiredCapacity > [mdCache length]) {
                [mdCache setLength:desiredCapacity];
            }
        }
        else {
            mdCache = [[NSMutableData alloc] initWithLength:desiredCapacity];
        }
    }
    return &(((uint32_t *) mdCache.mutableBytes)[(ip.section * maxRowsPerSection) + ip.row]);
}

@end
