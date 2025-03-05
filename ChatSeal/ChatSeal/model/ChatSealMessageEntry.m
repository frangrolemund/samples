//
//  ChatSealMessageEntry.m
//  ChatSeal
//
//  Created by Francis Grolemund on 5/14/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "ChatSealMessageEntry.h"
#import "ChatSeal.h"
#import "RealSecureImage/RealSecureImage.h"
#import "CS_error.h"
#import "CS_messageShared.h"
#import "CS_cacheMessage.h"
#import "UISealedMessageDisplayCellV2.h"
#import "UIAdvancedSelfSizingTools.h"

// - types
typedef uint64_t _psm_crdate_t;
typedef int16_t  _psm_size_dim_t;

// - constants
static const CGFloat  PSM_PLACEHOLDER_SD      = 128.0f;         // the max dimension of one side of a placeholder.
static const NSUInteger PSM_SIZEOF_UUID       = 16;             // this is what we expect the sizeof(uuid_t) to be from here on out since our file format depends on it.
static const NSUInteger PSM_NUM_CACHED_PACKED = 5;
static const NSUInteger PSM_NUM_UI_METRICS    = 3;
static const NSUInteger PSM_UI_METRIC_LEN     = (sizeof(_psm_size_dim_t) * PSM_NUM_UI_METRICS);

/*************************
 ChatSealMessageEntry
 *************************/
@implementation ChatSealMessageEntry
{
    CS_messageEdition  *editionLock;
    NSInteger           creationEdition;
    unsigned char       *pExistingEntry;
    NSMutableDictionary *mdNewEntry;
    NSString            *mid;
    NSURL               *msgDir;
    RSISecureSeal       *seal;
    UIImage             *imgAltDecoy;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [self clearEntry];
    [editionLock release];
    editionLock = nil;
    [super dealloc];
}

/*
 *  Return the seal used to build this message.
 */
-(RSISecureSeal *) seal
{
    RSISecureSeal *ret = nil;
    [editionLock lock];
    if ([editionLock isEqualToEdition:creationEdition]) {
        ret = [[seal retain] autorelease];
    }
    [editionLock unlock];
    return ret;
}

/*
 *  Return the date that this entry was created.
 *  - NOTE: we must memcpy, because the value may not be aligned.
 */
-(NSDate *) creationDate
{
    NSDate *ret = nil;
    [editionLock lock];
    
    if (pExistingEntry) {
        if ([editionLock isEqualToEdition:creationEdition]) {
            unsigned char *ptr = [self pCreateDate];
            if (ptr) {
                _psm_crdate_t crDate = 0;
                memcpy(&crDate, ptr, sizeof(crDate));
                ret = [NSDate dateWithTimeIntervalSince1970:crDate];
            }
        }
    }
    else {
        ret = [[[mdNewEntry objectForKey:PSM_CRDATE_KEY] retain] autorelease];
    }
    
    
    [editionLock unlock];
    return ret;
}

/*
 *  Return the name of the person who created this entry.
 */
-(NSString *) author
{
    NSString *ret = nil;
    [editionLock lock];
    
    if (pExistingEntry) {
        if ([editionLock isEqualToEdition:creationEdition]) {
            unsigned char *ptr = [self pAuthor];
            if (ptr) {
                ret = [NSString stringWithUTF8String:(const char *) ptr];
                if ([ret length] == 0) {
                    ret = nil;
                }
            }
        }
    }
    else {
        ret = [[[mdNewEntry objectForKey:PSM_OWNER_KEY] retain] autorelease];
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Return whether this entry was created by the seal owner
 *  - NOTE: we must memcpy, because the value may not be aligned.
 */
-(BOOL) isOwnerEntry
{
    BOOL ret = NO;
    [editionLock lock];
    
    if(pExistingEntry) {
        if ([editionLock isEqualToEdition:creationEdition]) {
            unsigned char *ptr = [self pFlags];
            if (ptr) {
                uint16_t flags = 0;
                memcpy(&flags, ptr, sizeof(flags));
                ret = ((flags & PSM_FLAG_SEALOWNER) ? YES : NO);
            }
        }
    }
    else {
        ret = ([mdNewEntry objectForKey:PSM_PARENT_KEY] ? NO : YES);
    }
    
    [editionLock unlock];
    return  ret;
}

/*
 *  Return the number of items in this entry.
 *  - NOTE: we must memcpy, because the value may not be aligned.
 */
-(NSUInteger) numItems
{
    NSUInteger ret = 0;
    [editionLock lock];
    
    if (pExistingEntry) {
        if ([editionLock isEqualToEdition:creationEdition]) {
            unsigned char *ptr = [self pNumItems];
            if (ptr) {
                uint16_t num = 0;
                memcpy(&num, ptr, sizeof(num));
                ret = (NSUInteger) num;
            }
        }
    }
    else {
        NSArray *arrItems = [mdNewEntry objectForKey:PSM_MSGITEMS_KEY];
        ret = [arrItems count];
    }
    
    
    [editionLock unlock];
    return ret;
}

/*
 *  Return a specific item from the object.
 */
-(id) itemAtIndex:(NSUInteger) idx withError:(NSError **) err
{
    NSObject *ret = nil;
    [editionLock lock];
    
    if (!pExistingEntry || [editionLock isEqualToEdition:creationEdition]) {
        NSObject *obj = [self linkedItemAtIndex:idx withError:err];
        if ([obj isKindOfClass:[NSNumber class]]) {
            NSURL *uFile = [ChatSealMessage fileForSecureImageIndex:[(NSNumber *) obj intValue] inDirectory:msgDir];
            ret = [ChatSealMessageEntry loadSecureImage:uFile withSeal:seal andError:err];
        }
        else {
            ret = obj;
        }
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Determine if the given item is an image or not.
 */
-(BOOL) isItemAnImageAtIndex:(NSUInteger) idx
{
    BOOL ret = NO;
    [editionLock lock];
    
    if (!pExistingEntry || [editionLock isEqualToEdition:creationEdition]) {
        NSObject *obj = [self linkedItemAtIndex:idx withError:nil];
        if (obj) {
            if ([obj isKindOfClass:[UIImage class]] || [obj isKindOfClass:[NSNumber class]]) {
                ret = YES;
            }
        }
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Return the given item as a string at the index.
 */
-(NSString *) itemAsStringAtIndex:(NSUInteger) idx
{
    NSObject *obj = [self itemAtIndex:idx withError:nil];
    if (obj && [obj isKindOfClass:[NSString class]]) {
        return (NSString *) obj;
    }
    return nil;
}

/*
 *  Return the given image item.
 */
-(UIImage *) itemAtIndex:(NSUInteger) idx asImageWithMaxSize:(CGSize) szMax andError:(NSError **) err
{
    NSObject *obj = [self itemAtIndex:idx withError:err];
    if (![obj isKindOfClass:[UIImage class]]) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument andFailureReason:@"Item is not an image at given index."];
        return nil;
    }
    
    //  - if the image is too large, then scale it.
    //  - note that passing a CGSizeZero indicates that it should never
    //    be rescaled.
    UIImage *img = (UIImage *) obj;
    CGSize curSize = img.size;
    if (szMax.width > 1.0f && szMax.height > 1.0f &&
        (curSize.width > szMax.width || curSize.height > szMax.height)) {
        CGFloat arImage = curSize.width / curSize.height;
        CGSize szNew = curSize;
        if (curSize.width > szMax.width) {
            szNew = CGSizeMake(szMax.width, szMax.width/arImage);
        }
        
        if (curSize.height > szMax.height) {
            szNew = CGSizeMake(szMax.height * arImage, szMax.height);
        }
        
        UIGraphicsBeginImageContext(szNew);
        [img drawInRect:CGRectMake(0.0f, 0.0f, szNew.width, szNew.height)];
        img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return img;
}

/*
 *  Return the cell height of the item.
 */
-(CGFloat) cellHeightForImageAtIndex:(NSUInteger) idx
{
    CGFloat ret           = -1.0;
    [editionLock lock];
    
    if ([editionLock isEqualToEdition:creationEdition]) {
        unsigned char *pItem = [self pItemAtIndex:idx withError:nil];
        if (pItem) {
            _psm_size_dim_t oneDim;
            memcpy(&oneDim, pItem, sizeof(oneDim));
            ret = oneDim;
        }
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Return the original size of the image represented by the given item.
 */
-(CGSize) imageSizeForItemAtIndex:(NSUInteger) idx
{
    CGSize ret = CGSizeMake(-1.0f, -1.0f);
    [editionLock lock];
    
    if ([editionLock isEqualToEdition:creationEdition]) {
        unsigned char *pItem = [self pItemAtIndex:idx withError:nil];
        if (pItem) {
            _psm_size_dim_t oneDim;
            pItem += sizeof(_psm_size_dim_t);           //  skip over the cell height
            memcpy(&oneDim, pItem, sizeof(oneDim));
            ret.width = (CGFloat) oneDim;
            pItem += sizeof(_psm_size_dim_t);           //  skip over the image width
            memcpy(&oneDim, pItem, sizeof(oneDim));
            ret.height = (CGFloat) oneDim;
        }
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Getting a sealed message occurs on the entry because the network pipeline can't possibly
 *  process all my messages as they are created.   Once an entry is valid, it implies a local
 *  store exists for its content, so we can create the sealed message on-demand to save on temporary
 *  storage and even the processing required to create a new one.
 */
-(NSData *) sealedMessageWithError:(NSError **) err
{
    NSData *ret  = nil;
    NSError *tmp = nil;
    
    // - use this pool to limit the lifespan of these personal items.
    @autoreleasepool {
        CS_messageEntryExport *mee = [self exportEntryWithError:err];
        if (mee) {
            ret = [[ChatSealMessageEntry buildSealedMessageFromExportedEntry:mee withError:&tmp] retain];           // escape the pool
            [tmp retain];                                                                                            // escape the pool
        }
    }
    
    [tmp autorelease];
    if (err) {
        *err = tmp;
    }
    
    return [ret autorelease];
}

/*
 *  Returns whether this was a revocation mesasge.
 */
-(BOOL) wasRevocation
{
    BOOL ret = NO;
    [editionLock lock];
    
    if(pExistingEntry) {
        if ([editionLock isEqualToEdition:creationEdition]) {
            unsigned char *ptr = [self pFlags];
            if (ptr) {
                uint16_t flags = 0;
                memcpy(&flags, ptr, sizeof(flags));
                ret = ((flags & PSM_FLAG_REVOKE) ? YES : NO);
            }
        }
    }
    else {
        ret = ([mdNewEntry objectForKey:PSM_REVOKE_KEY] ? YES : NO);
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Returns whether this entry has an alernate decoy specified.
 */
-(BOOL) hasAlternateDecoy
{
    BOOL ret = NO;
    [editionLock lock];
    
    if (imgAltDecoy) {
        ret = YES;
    }
    else {
        NSURL *u = [self alternateDecoyURL];
        ret = [[NSFileManager defaultManager] fileExistsAtPath:[u path]];
    }
    
    [editionLock unlock];
    return ret;
    
}

/*
 *  Return a unique placeholder name for the cache.
 */
-(NSString *) placeholderBaseNameForIndex:(NSUInteger) idx
{
    NSString *ret = nil;
    [editionLock lock];

    
    NSUUID *uuid = [self entryUUID];
    if (uuid) {
        NSString *s = [NSString stringWithFormat:@"%@%@%lu",mid, [uuid UUIDString], (unsigned long) idx];
        ret = [ChatSeal insecureHashForData:[s dataUsingEncoding:NSASCIIStringEncoding]];
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Return a cached placholder image for the given item or nil if an image doesn't exist.
 *  - remember that this routine will likely only ever work for one entry since we
 *    prevent multi-image entries for space reasons.
 */
-(UIImage *) imagePlaceholderAtIndex:(NSUInteger) idx
{
    UIImage *ret = nil;
    [editionLock lock];
    
    NSString *sBase = [self placeholderBaseNameForIndex:idx];
    if (sBase) {
        ret = [CS_cacheMessage imagePlaceholderForBase:sBase andMessage:mid usingSeal:seal];
        if (!ret) {
            // - NOTICE:  there is an autorelease of the img below...
            @autoreleasepool {
                NSObject *obj = [self itemAtIndex:idx withError:nil];
                if (obj && [obj isKindOfClass:[UIImage class]]) {
                    // - generate the placeholder image.
                    ret             = (UIImage *) obj;
                    
                    //  ...ensure that the image is never too small.
                    CGFloat scale  = [self placeholderScaleForImageSize:ret.size];
                    
                    // ************
                    // NOTE: The placeholder is blurred for two primary reasons:
                    //       1.  It makes it harder for a consumer to take a screenshot.  While they could open
                    //           the photo and then do it, if the no-screenshot flag is set on the seal, at least
                    //           they are locked out and only got one.
                    //       2.  It minimizes my risk as any author of potentially embarrassing photos.  If I'm in
                    //           the app, I don't want someone looking over my shoulder and seeing what I sent.  This
                    //           allows the photo to be completely obscured until I choose to look at it.
                    //       - I considered making this un-blurred for the sender and point #2 sort of dissuaded me from
                    //         that course.  I figure that if someone is using this app, they're looking for privacy, so
                    //         the blurred photo is probably a desired feature in some capacity.
                    // ************
                    ret            = [ChatSeal generateFrostedImageOfType:CS_FS_SECURE fromImage:ret atScale:scale];            //  - this generates at device scale!
                    CGSize szImage = ret.size;
                    if (ret && szImage.width > 0.0f && szImage.height > 0.0) {
                        // - and save it in the cache for next time.
                        [CS_cacheMessage saveImage:ret asPlaceholderForBase:sBase andMessage:mid usingSeal:seal];
                        [ret retain];         // escape the autorelease pool
                    }
                    else {
                        ret = nil;
                    }
                }                
            }
            [ret autorelease];
        }
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Generate a string to display the time in the entry's presentation header.
 */
+(NSString *) standardDisplayFormattedTimeForDate:(NSDate *) date
{
    return [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterShortStyle];
}

/*
 *  Generate the entire display details line given the date and author.
 */
+(NSMutableAttributedString *) standardDisplayDetailsForAuthorSuffix:(NSString *) beginString withAuthorColor:(UIColor *) authorColor andBoldFont:(UIFont *) fontBold
                                                              onDate:(NSDate *) date withTimeString:(NSString *) sTime andTimeFont:(UIFont *) timeFont
{
    NSString *sDateName = [ChatSealMessage formattedMessageEntryDate:date andAbbreviateThisWeek:YES andExcludeRedundantYear:YES];
    if (!sTime) {
        sTime = [ChatSealMessageEntry standardDisplayFormattedTimeForDate:date];
    }
    
    //  - set the text.
    NSString *fullString = beginString;
    NSUInteger authorSuffix = [fullString length];
    fullString = [fullString stringByAppendingFormat:@"%@ ", sDateName];
    NSUInteger withDay = [fullString length];
    fullString = [fullString stringByAppendingFormat:@"%@", sTime];
    
    //  - now that the text is set, we need to assign the various attributes.
    NSMutableAttributedString *mas = [[[NSMutableAttributedString alloc] initWithString:fullString] autorelease];
    [mas beginEditing];
    
    //  ... set colors first.
    NSUInteger startOfDate = 0;
    if (authorSuffix) {
        startOfDate = authorSuffix;
        [mas addAttribute:NSForegroundColorAttributeName value:authorColor range:NSMakeRange(0, startOfDate)];
    }
    [mas addAttribute:NSForegroundColorAttributeName value:[UIColor darkGrayColor] range:NSMakeRange(startOfDate, [fullString length]-startOfDate)];
    [mas addAttribute:NSForegroundColorAttributeName value:[UIColor lightGrayColor] range:NSMakeRange(withDay, [fullString length]-withDay)];
    
    //  ... now the fonts.
    if (fontBold) {
        if (authorSuffix) {
            [mas addAttribute:NSFontAttributeName value:fontBold range:NSMakeRange(0, authorSuffix)];
        }
        [mas addAttribute:NSFontAttributeName value:fontBold range:NSMakeRange(authorSuffix, [sDateName length])];
    }
    if (timeFont) {
        [mas addAttribute:NSFontAttributeName value:timeFont range:NSMakeRange(withDay, [fullString length] - withDay)];
    }
    
    [mas endEditing];
    return mas;
}

/*
 *  Return the standard secure image placholder dimension.
 */
+(CGFloat) standardPlaceholderDimension
{
    return PSM_PLACEHOLDER_SD;
}

/*
 *  Return whether this entry was read or not.
 */
-(BOOL) isRead
{
    BOOL ret = NO;
    [editionLock lock];
    
    if(pExistingEntry) {
        if ([editionLock isEqualToEdition:creationEdition]) {
            unsigned char *ptr = [self pFlags];
            if (ptr) {
                uint16_t flags = 0;
                memcpy(&flags, ptr, sizeof(flags));
                ret = ((flags & PSM_FLAG_ISREAD) ? YES : NO);
            }
        }
    }
    else {
        NSNumber *n = [mdNewEntry objectForKey:PSM_ISREAD_KEY];
        ret = (!n || [n boolValue]);
    }
    
    [editionLock unlock];
    return ret;
}

/*
 *  Return the unique message id for the entry.
 */
-(NSString *) messageId
{
    NSString *ret = nil;
    [editionLock lock];

    ret = [[mid retain] autorelease];
    
    [editionLock unlock];
    return ret;
}

/*
 *  Return the unique entry id for the entry.
 */
-(NSString *) entryId
{
    NSString *ret = nil;
    [editionLock lock];
    
    ret = [[self entryUUID] UUIDString];
    
    [editionLock unlock];
    return ret;
}

/*
 *  Return the seal id.
 */
-(NSString *) sealId
{
    NSString *ret = nil;
    [editionLock lock];
    
    ret = [seal sealId];
    
    [editionLock unlock];
    return ret;
}

/*
 *  An entry can become stale if its creation edition is out of synch with the one
 *  that created it.
 */
-(BOOL) isStale
{
    BOOL ret = NO;
    [editionLock lock];
    
    // - newly created entries are never considered stale because they
    //   don't share the common buffer with the message.
    if (pExistingEntry) {
        ret = ![editionLock isEqualToEdition:creationEdition];
    }
    
    [editionLock unlock];
    return ret;
}

@end

/*************************
 ChatSealMessageEntry (internal)
 *************************/
@implementation ChatSealMessageEntry (internal)

/*
 *  Initialize the object.
 */
-(id) initWithMessage:(NSString *) message inDirectory:(NSURL *) dir andSeal:(RSISecureSeal *) s andData:(void *) entry usingLock:(CS_messageEdition *) msgLock
{
    // - this object is writable if there is no existing entry
    self = [super init];
    if (self) {
        editionLock     = [msgLock retain];
        creationEdition = (NSInteger) -1;
        if (entry) {
            uint32_t sig = 0;
            memcpy(&sig, entry, sizeof(sig));
            if (sig != PSM_SIG_ENTRY) {
                NSLog(@"CS-ALERT: The message entry at %p has a missing signature.", entry);
                entry = NULL;
            }
            pExistingEntry = (unsigned char *) entry;
        }
        else {
            mdNewEntry = [[NSMutableDictionary alloc] init];
        }
        mid    = [message retain];
        msgDir = [dir retain];
        seal   = [s retain];
    }
    return self;
}

/*
 *  The message itself is going to force this edition to be assigned because it must
 *  occur after the buffer is re-allocated, not when the entry object is first created.
 */
-(void) assignCreationEditionFromLock
{
    creationEdition = [editionLock currentEdition];
}

/*
 * Returns the entry id as a standard UUID object.
 */
-(NSUUID *) entryUUID
{
    if (pExistingEntry) {
        if ([editionLock isEqualToEdition:creationEdition]) {
            unsigned char *ptr = [self pEntryId];
            if (ptr) {
                // - and unpack the raw id.
                uuid_t rawUUID;
                memcpy(&rawUUID, ptr, sizeof(rawUUID));
                return [[[NSUUID alloc] initWithUUIDBytes:rawUUID] autorelease];
            }
        }
        return nil;
    }
    else {
        return  [[[mdNewEntry objectForKey:PSM_ENTRYID_KEY] retain] autorelease];
    }
}

// ---------------------------------------------
// - These assignment methods are only useful for
//   a brand new entry, otherwise the entry is
//   read-only.
// - Also, the use of a dictionary for new entries
//   is to maximize message portability, although
//   we'll always store it on-disk in a more
//   compact form.
// ---------------------------------------------

/*
 *  Assign a value in the entry.
 */
-(void) setBasicValue:(NSObject *) obj inEntryWithKey:(NSString *) key
{
    if (mdNewEntry) {
        if (obj) {
            [mdNewEntry setObject:obj forKey:key];
        }
        else {
            [mdNewEntry removeObjectForKey:key];
        }
    }
}

/*
 *  Assign the message id to the payload, which is only
 *  used for on-the-wire transfers.
 */
-(void) setMessageId:(NSString *) messageId
{
    [self setBasicValue:messageId inEntryWithKey:PSM_MSGID_KEY];
}

/*
 *  Set the baseline entry id.
 */
-(void) setEntryId:(NSUUID *) entryId
{
    [self setBasicValue:entryId inEntryWithKey:PSM_ENTRYID_KEY];
}

/*
 *  Retrieve the parent id if it exists.
 */
-(NSUUID *) parentId
{
    if (pExistingEntry) {
        unsigned char *ptr = [self pParentId];
        if (ptr && *ptr) {
            // - and unpack the raw id that exists right after the flag indicating availability.
            uuid_t rawUUID;
            memcpy(&rawUUID, ptr + 1, sizeof(rawUUID));
            return [[[NSUUID alloc] initWithUUIDBytes:rawUUID] autorelease];
        }
        return nil;
    }
    else {
        return  [[[mdNewEntry objectForKey:PSM_PARENT_KEY] retain] autorelease];
    }
}

/*
 *  Set the parent id in the entry.
 */
-(void) setParentId:(NSUUID *) parentId
{
    [self setBasicValue:parentId inEntryWithKey:PSM_PARENT_KEY];
}

/*
 *   Set the items.
 */
-(void) setItems:(NSArray *) arrItems
{
    [self setBasicValue:arrItems ? [NSMutableArray arrayWithArray:arrItems] : nil inEntryWithKey:PSM_MSGITEMS_KEY];
}

/*
 *  Assign the author.
 */
-(void) setAuthor:(NSString *) author
{
    [self setBasicValue:author inEntryWithKey:PSM_OWNER_KEY];
}

/*
 *  Assign the creation date.
 */
-(void) setCreationDate:(NSDate *) createDate
{
    [self setBasicValue:createDate inEntryWithKey:PSM_CRDATE_KEY];
}

/*
 *  Label this entry as a seal revocation command.
 */
-(void) markForSealRevocation
{
    [self setBasicValue:[NSNumber numberWithBool:YES] inEntryWithKey:PSM_REVOKE_KEY];
}

/*
 *  Label the entry as is-read or not.
 */
-(void) setIsRead:(BOOL) isRead
{
    if (pExistingEntry) {
        unsigned char *ptr = [self pFlags];
        if (ptr) {
            uint16_t flags = 0;
            memcpy(&flags, ptr, sizeof(flags));
            if (isRead) {
                flags |= PSM_FLAG_ISREAD;
            }
            else {
                flags &= ~PSM_FLAG_ISREAD;
            }
            memcpy(ptr, &flags, sizeof(flags));
        }
    }
    else {
        [self setBasicValue:[NSNumber numberWithBool:isRead] inEntryWithKey:PSM_ISREAD_KEY];
    }
}

/*
 *  Return the dictionary we'll use to pack a message.
 *  - This is intended to be pulled from the on-disk storage in most cases
 *    because there is no way we can pack and send this inline when the message
 *    is generated.
 */
-(NSMutableDictionary *) sealedMessageDictionary
{
    NSString *author    = [self author];
    NSDate   *dtCreated = [self creationDate];
    NSUUID   *entryId   = [self entryUUID];
    NSUUID   *parentId  = [self parentId];
    NSUInteger numItems = [self numItems];
    if (!mid || !dtCreated || !entryId || numItems == 0) {
        return nil;
    }
    
    // - generate the dictionary on-demand because the one that
    //   could exist here might have links for the images or
    //   we may be using a raw buffer.
    NSMutableDictionary *mdRet = [NSMutableDictionary dictionary];
    [mdRet setObject:mid forKey:PSM_MSGID_KEY];
    [mdRet setObject:entryId forKey:PSM_ENTRYID_KEY];
    if (parentId) {
        [mdRet setObject:parentId forKey:PSM_PARENT_KEY];
    }
    if (author) {
        [mdRet setObject:author forKey:PSM_OWNER_KEY];
    }
    [mdRet setObject:dtCreated forKey:PSM_CRDATE_KEY];
    
    if ([self wasRevocation]) {
        [mdRet setObject:[NSNumber numberWithBool:YES] forKey:PSM_REVOKE_KEY];
    }
    
    NSMutableArray *maItems = [NSMutableArray array];
    for (NSUInteger i = 0; i < numItems; i++) {
        NSObject *obj = [self itemAtIndex:i withError:nil];
        if (!obj) {
            NSLog(@"CS-ALERT: Unexpected empty content for item %lu in message %@.", (unsigned long) i, mid);
            return nil;
        }
        [maItems addObject:obj];
    }
    [mdRet setObject:maItems forKey:PSM_MSGITEMS_KEY];
    
    // - return the dictionary for sealing the content.
    return mdRet;
}

/*
 *  Compute the scaling factor to apply to an image of the given size to generate a good placeholder.
 */
-(CGFloat) placeholderScaleForImageSize:(CGSize) szImage
{
    CGFloat scale = 0.0f;
    if (szImage.width > szImage.height) {
        scale = PSM_PLACEHOLDER_SD/szImage.height;
    }
    else {
        scale = PSM_PLACEHOLDER_SD/szImage.width;
    }
    return MIN(scale, 1.0f);
}

/*
 *  I'm a bit torn about putting knowlege of the UI into the model, but this is too significant of an item
 *  too ignore because computing the image heights for the UI is very time-intensive due to the fact that
 *  each image must be loaded from disk/decrypted to do so.  We'll be storing metrics for every image, but no
 *  text so that Dynamic Type can still be used.   In this routine, if the index refers to an image, then
 *  we'll measure it with the expectation that later we'll be storing it into the buffer.
 *  - at this stage, for this kind of optimization, I see no reason to get too puritanical about this because
 *    the fact is that this object is already influenced by how it is used since the UI metrics exist at all.
 */
-(void) measureImageForUIMetricsAtIndex:(NSUInteger) idx
{
    if (pExistingEntry) {
        return;
    }
    
    NSArray *arr = [mdNewEntry objectForKey:PSM_MSGITEMS_KEY];
    if (idx < [arr count]) {
        NSObject *obj = [arr objectAtIndex:idx];
        if (obj && [obj isKindOfClass:[UIImage class]]) {
            UIImage *img                   = (UIImage *) obj;
            
            // - these metrics are intended to reflect the _placeholder_, not the original image.   Because
            //   of that fact, we need to generate values that are consistent with what the placeholder will
            //   eventually become.
            CGSize szImage                 = img.size;

            // ...first ensure that we take into account that the image will first be rendered in device scale
            //    and then saved as JPEG, which converts to real pixels.
            szImage.width                 *= [UIScreen mainScreen].scale;
            szImage.height                *= [UIScreen mainScreen].scale;
            
            // ...now we need to respect the maximum dimensions of the placeholders
            CGFloat adjScale               = [self placeholderScaleForImageSize:szImage];
            szImage.width                  = (CGFloat) ceil(szImage.width * adjScale);
            szImage.height                 = (CGFloat) ceil(szImage.height * adjScale);
            
            // ...finally, we can get the height now because we know how this will be loaded.
            CGFloat height                 = [UISealedMessageDisplayCellV2 minimumCellHeightForImageOfSize:szImage];
            NSMutableDictionary *mdMetrics = [mdNewEntry objectForKey:PSM_IMGMETRICS_KEY];
            if (!mdMetrics) {
                mdMetrics = [NSMutableDictionary dictionary];
                [mdNewEntry setObject:mdMetrics forKey:PSM_IMGMETRICS_KEY];
            }
            
            // - we need to store the cell height, but also the original image dimensions so that we can
            //   create aspect-accurate placeholders of it later.
            NSMutableArray *maItemMetrics = [NSMutableArray arrayWithObjects:[NSNumber numberWithFloat:(float) height],
                                                                             [NSNumber numberWithFloat:(float) img.size.width],
                                                                             [NSNumber numberWithFloat:(float) img.size.height], nil];
            [mdMetrics setObject:maItemMetrics forKey:[NSNumber numberWithUnsignedInteger:idx]];
        }
    }
}

/*
 *  Save a secure image item.
 */
+(BOOL) saveSecureImage:(UIImage *) img toURL:(NSURL *) uFile withSeal:(RSISecureSeal *) seal andError:(NSError **) err
{
    //  - use an autorelease pool to not keep the image laying around for long
    BOOL ret     = NO;
    NSError *tmp = nil;
    @autoreleasepool {
        NSData *dImage = UIImageJPEGRepresentation(img, [ChatSeal standardArchivedImageCompression]);
        if (dImage) {
            NSData *dEncryptedImage = [seal encryptLocalOnlyMessage:[NSDictionary dictionaryWithObject:dImage forKey:PSM_GENERIC_KEY] withError:&tmp];
            if (dEncryptedImage) {
                if ([dEncryptedImage writeToURL:uFile atomically:YES]) {
                    ret = YES;
                }
                else {
                    [CS_error fillError:err withCode:CSErrorFilesystemAccessError andFailureReason:@"Failed to save archival image."];
                }
            }
        }
        else {
            [CS_error fillError:err withCode:CSErrorArchivalError andFailureReason:@"Failed to generate a JPEG from image data."];
        }
        
        //  - to escape the pool
        [tmp retain];
    }
    
    [tmp autorelease];
    if (err) {
        *err = tmp;
    }
    return ret;
}

/*
 *  Convert the item at the given index to an image link.
 */
-(BOOL) convertToSecureImageAtIndex:(NSUInteger) idx toLink:(int32_t) linkIndex withError:(NSError **) err
{
    NSMutableArray *arr = [mdNewEntry objectForKey:PSM_MSGITEMS_KEY];
    if (!mdNewEntry || !arr || idx >= [arr count] || ![[arr objectAtIndex:idx] isKindOfClass:[UIImage class]]) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        return NO;
    }
    
    UIImage *img = [arr objectAtIndex:idx];
    NSURL *uFile = [ChatSealMessage fileForSecureImageIndex:linkIndex inDirectory:msgDir];
    if ([ChatSealMessageEntry saveSecureImage:img toURL:uFile withSeal:seal andError:err]) {
        [arr replaceObjectAtIndex:idx withObject:[NSNumber numberWithInt:linkIndex]];
        return YES;
    }
    return NO;
}

/*
 *  Append the provided bytes onto the data buffer.
 */
+(void) appendBytes:(const void *) bytes ofLength:(NSUInteger) len ontoData:(NSMutableData *) mdBuffer
{
    NSUInteger oldLen = [mdBuffer length];
    [mdBuffer setLength:oldLen + len];
    unsigned char *start = (unsigned char *) mdBuffer.mutableBytes;
    memcpy(&(start[oldLen]), bytes, len);
}

/*
 *  Produce a packed buffer that represents the contents of this new entry.
 */
-(NSData *) convertNewEntryToBuffer
{
    if (!mdNewEntry ||
        ![mdNewEntry objectForKey:PSM_ENTRYID_KEY] ||
        ![mdNewEntry objectForKey:PSM_CRDATE_KEY] ||
        ![mdNewEntry objectForKey:PSM_MSGITEMS_KEY]) {
        return nil;
    }
    
    NSMutableData *mdRet = [NSMutableData data];
    
    //  - the data in this buffer is going to be packed, but we need
    //    to be very disciplined in order to ensure that its content
    //    follows a predictable pattern.
    //  - the order of this data favors quick identification of things that are
    //    used frequently like the entry id or the creation date and assumes extra processing
    //    to find the entry items or the author.
    
    //  - we're storing the uuid_t as raw bytes, so I need to be sure there's no reason that would
    //    change in Apple's implementation.
    if (sizeof(uuid_t) != PSM_SIZEOF_UUID) {
        NSLog(@"CS-ALERT: The UUID data type has changed its length!");
        return nil;
    }
    
    //  - the signature
    [ChatSealMessageEntry appendBytes:&PSM_SIG_ENTRY ofLength:sizeof(PSM_SIG_ENTRY) ontoData:mdRet];
    
    //  - the entry id
    NSUUID *entryId      = [mdNewEntry objectForKey:PSM_ENTRYID_KEY];
    uuid_t rawUUID;
    [entryId getUUIDBytes:rawUUID];
    [ChatSealMessageEntry appendBytes:rawUUID ofLength:sizeof(rawUUID) ontoData:mdRet];
    
    // - the creation date.
    _psm_crdate_t tCreated = 0;
    NSDate *dCreated = [mdNewEntry objectForKey:PSM_CRDATE_KEY];
    if (dCreated) {
        tCreated = (uint64_t) [dCreated timeIntervalSince1970];
    }
    [ChatSealMessageEntry appendBytes:&tCreated ofLength:sizeof(tCreated) ontoData:mdRet];
    
    //  - flags
    uint16_t flags = 0;
    if ([mdNewEntry objectForKey:PSM_REVOKE_KEY]) {
        flags |= PSM_FLAG_REVOKE;
    }
    if (![mdNewEntry objectForKey:PSM_PARENT_KEY]) {
        // - we just need to know when this entry was created
        //   by the seal owner, which this flag describes.
        flags |= PSM_FLAG_SEALOWNER;
    }
    NSNumber *nIsRead = [mdNewEntry objectForKey:PSM_ISREAD_KEY];
    if (nIsRead && [nIsRead boolValue]) {
        flags |= PSM_FLAG_ISREAD;
    }
    [ChatSealMessageEntry appendBytes:&flags ofLength:sizeof(flags) ontoData:mdRet];
    
    //  - number of items.
    uint16_t numItems = 0;
    NSArray *arr = [mdNewEntry objectForKey:PSM_MSGITEMS_KEY];
    numItems = (uint16_t) [arr count];
    [ChatSealMessageEntry appendBytes:&numItems ofLength:sizeof(numItems) ontoData:mdRet];
    
    //  - the author
    NSString *author = [mdNewEntry objectForKey:PSM_OWNER_KEY];
    if (!author) {
        author = @"";
    }
    if ([author length] > 0xFFFF) {
        author = [author substringToIndex:0xFFFF];
    }
    const char *cAuthor = [author UTF8String];
    [ChatSealMessageEntry appendBytes:cAuthor ofLength:strlen(cAuthor) + 1 ontoData:mdRet];
    
    //  - the parent id
    NSUUID *parentId        = [mdNewEntry objectForKey:PSM_PARENT_KEY];
    unsigned char hasParent = (parentId ? 1 : 0);
    [ChatSealMessageEntry appendBytes:&hasParent ofLength:sizeof(hasParent)  ontoData:mdRet];
    if (hasParent) {
        [parentId getUUIDBytes:rawUUID];
        [ChatSealMessageEntry appendBytes:rawUUID ofLength:sizeof(rawUUID) ontoData:mdRet];
    }
    
    //  - we may have computed metrics
    NSDictionary *dictMetrics = [mdNewEntry objectForKey:PSM_IMGMETRICS_KEY];
    
    //  - entry item 1..N
    for (uint32_t i = 0; i < numItems; i++) {
        CGFloat height      = -1.0f;
        CGSize  szImageDims = CGSizeMake(-1.0f, -1.0f);
        if (dictMetrics) {
            NSArray *arrMetrics = [dictMetrics objectForKey:[NSNumber numberWithUnsignedInteger:i]];
            if (arrMetrics && [arrMetrics count] == PSM_NUM_UI_METRICS) {
                NSNumber *n        = [arrMetrics objectAtIndex:0];
                height             = (CGFloat) n.floatValue;
                n                  = [arrMetrics objectAtIndex:1];
                szImageDims.width  = (CGFloat) n.floatValue;
                n                  = [arrMetrics objectAtIndex:2];
                szImageDims.height = (CGFloat) n.floatValue;
            }
        }
        
        //  - three 16-bit values will store the height of the UI element and the image dimensions once it is first used.
        _psm_size_dim_t itemDim = 0;
        itemDim = (_psm_size_dim_t) height;
        [ChatSealMessageEntry appendBytes:&itemDim ofLength:sizeof(itemDim) ontoData:mdRet];
        itemDim = (_psm_size_dim_t) szImageDims.width;
        [ChatSealMessageEntry appendBytes:&itemDim ofLength:sizeof(itemDim) ontoData:mdRet];
        itemDim = (_psm_size_dim_t) szImageDims.height;
        [ChatSealMessageEntry appendBytes:&itemDim ofLength:sizeof(itemDim) ontoData:mdRet];
        
        unsigned char isImage = 0;
        NSObject *obj = [arr objectAtIndex:i];
        if ([obj isKindOfClass:[NSNumber class]]) {
            isImage = 1;
        }
        else if (![obj isKindOfClass:[NSString class]]) {
            NSLog(@"CS: Invalid item object type in index %u.", i);
            return nil;
        }
        
        // - save the content with a type.
        [ChatSealMessageEntry appendBytes:&isImage ofLength:sizeof(isImage) ontoData:mdRet];
        if (isImage) {
            int32_t link = [(NSNumber *) obj intValue];
            [ChatSealMessageEntry appendBytes:&link ofLength:sizeof(link) ontoData:mdRet];
        }
        else {
            const char *sData = [(NSString *) obj UTF8String];
            [ChatSealMessageEntry appendBytes:sData ofLength:strlen(sData) + 1 ontoData:mdRet];
        }
    }
    return mdRet;
}

/*
 *  Return a pointer to the entry id field.
 */
-(unsigned char *) pEntryId
{
    static int offset = sizeof(uint32_t);
    if (pExistingEntry) {
        return &(pExistingEntry[offset]);
    }
    return NULL;
}

/*
 *  Return a pointer to the parent id field.
 */
-(unsigned char *) pParentId
{
    unsigned char *pAuthor = [self pAuthor];
    if (pAuthor) {
        size_t len = strlen((char *) pAuthor);
        return &(pAuthor[len+1]);
    }
    return NULL;
}

/*
 *  Return a pointer to the creation date field.
 */
-(unsigned char *) pCreateDate
{
    static int offset = sizeof(uint32_t) + sizeof(uuid_t);
    if (pExistingEntry) {
        return &(pExistingEntry[offset]);
    }
    return NULL;
}

/*
 *  Return a pointer to the author field.
 */
-(unsigned char *) pAuthor
{
    static int offset = sizeof(uint32_t) + sizeof(uuid_t) + sizeof(_psm_crdate_t) + sizeof(uint16_t) + sizeof(uint16_t);
    if (pExistingEntry) {
        return &(pExistingEntry[offset]);
    }
    return NULL;
}

/*
 *  Return a pointer to the flags field.
 */
-(unsigned char *) pFlags
{
    static int offset = sizeof(uint32_t) + sizeof(uuid_t) + sizeof(_psm_crdate_t);
    if (pExistingEntry) {
        return &(pExistingEntry[offset]);
    }
    return NULL;
}

/*
 *  Return a pointer to the number of items field.
 */
-(unsigned char *) pNumItems
{
    static int offset = sizeof(uint32_t) + sizeof(uuid_t) + sizeof(_psm_crdate_t) + sizeof(uint16_t);
    if (pExistingEntry) {
        return &(pExistingEntry[offset]);
    }
    return NULL;
}

/*
 *  Return a pointer to the list of items.
 */
-(unsigned char *) pItems
{
    if (pExistingEntry) {
        unsigned char *pParentId = [self pParentId];
        if (pParentId) {
            //  - figure out if we have to hop over a parent UUID or just
            //    its availability flag.
            if (*pParentId) {
                return pParentId + (1 + PSM_SIZEOF_UUID);
            }
            else {
                return ++pParentId;
            }
        }
    }
    return NULL;
}

/*
 *  Return the pointer to the given item.
 *  - this content is read-only, so we are good
 */
-(unsigned char *) pItemAtIndex:(NSUInteger) idx withError:(NSError **) err
{
    NSUInteger numItems = [self numItems];
    if (idx >= numItems) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument andFailureReason:@"Invalid entry item index."];
        return nil;
    }
    
    unsigned char *ptr = [self pItems];
    if (!ptr) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument andFailureReason:@"Invalid item array."];
        return nil;
    }
    
    while (idx > 0) {
        ptr += PSM_UI_METRIC_LEN;           // skip over the UI metrics
        
        unsigned char isImage = *ptr;
        ptr++;
        if (isImage) {
            ptr += sizeof(int32_t);
        }
        else {
            ptr += (strlen((char *) ptr) + 1);
        }
        idx--;
    }
    return  ptr;
}

/*
 *  This is intended to be a very quick way of grabbing the entry id from the
 *  buffer.
 */
+(NSUUID *) entryIdForData:(const unsigned char *) ptr
{
    // - verify the signature to be sure.
    if (memcmp(ptr, &PSM_SIG_ENTRY, sizeof(PSM_SIG_ENTRY))) {
        NSLog(@"CS-ALERT: The message entry at %p has a missing signature.", ptr);
        return nil;
    }
    ptr += sizeof(uint32_t);
    
    // - and unpack the raw id.
    uuid_t rawUUID;
    memcpy(&rawUUID, ptr, sizeof(rawUUID));
    return [[[NSUUID alloc] initWithUUIDBytes:rawUUID] autorelease];
}

/*
 *  Clear out the contents of this object, usually because it is invalid.
 */
-(void) clearEntry
{
    pExistingEntry = NULL;
    
    [mdNewEntry release];
    mdNewEntry = nil;
    
    [msgDir release];
    msgDir = nil;
    
    [mid release];
    mid = nil;
    
    [seal release];
    seal = nil;
    
    [imgAltDecoy release];
    imgAltDecoy = nil;
}

/*
 *  The purpose of this routine is to provide an unconverted string pointer from this
 *  message to save on the creation of an NSString object.
 */
-(const char *) UTF8StringItemAtIndex:(NSUInteger) idx
{
    unsigned char *ptr = [self pItemAtIndex:idx withError:nil];
    if (!ptr) {
        return NULL;
    }
    
    // - skip over the UI metrics
    ptr += PSM_UI_METRIC_LEN;
    
    // - if it is an image, then this won't work.
    if (*ptr) {
        return NULL;
    }
    
    // - should be a string now.
    return (const char *) (ptr + 1);
}

/*
 *  Return the bare item at the index, but don't resolve the link.
 */
-(id) linkedItemAtIndex:(NSUInteger) idx withError:(NSError **) err
{
    if (pExistingEntry) {
        unsigned char *pItem = [self pItemAtIndex:idx withError:err];
        if (pItem) {
            pItem += PSM_UI_METRIC_LEN;         // skip over UI metrics.
            unsigned char isImage = *pItem;
            pItem++;
            if (isImage) {
                int32_t link = 0;
                memcpy(&link, pItem, sizeof(link));
                return [NSNumber numberWithInt:link];
            }
            else {
                return [NSString stringWithUTF8String:(const char *) pItem];
            }
        }
        return nil;
    }
    else {
        NSArray *arr = [mdNewEntry objectForKey:PSM_MSGITEMS_KEY];
        if (arr && idx < [arr count]) {
            NSObject *obj = [arr objectAtIndex:idx];
            if ([obj isKindOfClass:[UIImage class]] ||
                [obj isKindOfClass:[NSString class]] ||
                [obj isKindOfClass:[NSNumber class]]) {
                return obj;
            }
            else {
                [CS_error fillError:err withCode:CSErrorInvalidArgument andFailureReason:@"Unexpected entry data."];
                return nil;
            }
        }
        else {
            [CS_error fillError:err withCode:CSErrorInvalidArgument andFailureReason:@"Invalid entry item index."];
            return nil;
        }
    }
}

/*
 *  If this is an entry that contains an alternate decoy image, assign that now before we append its content.
 */
-(void) setAlternateDecoy:(UIImage *) altDecoy
{
    if (imgAltDecoy != altDecoy) {
        [imgAltDecoy release];
        imgAltDecoy = [altDecoy retain];
    }
}

/*
 *  Return the alternate decoy image if one is assigned.
 */
-(UIImage *) alternateDecoyWithError:(NSError **) err
{
    if (imgAltDecoy) {
        return [[imgAltDecoy retain] autorelease];
    }
    else {
        NSURL *uDecoy = [self alternateDecoyURL];
        if (uDecoy && [[NSFileManager defaultManager] fileExistsAtPath:[uDecoy path]]) {
            return [ChatSealMessageEntry loadSecureImage:uDecoy withSeal:seal andError:err];
        }
    }
    return nil;
}

/*
 *  Return the URL of the alternate decoy.
 */
-(NSURL *) alternateDecoyURL
{
    NSUUID *uuidID = [self entryUUID];
    if (mid && uuidID && msgDir) {
        NSString *sCombined = [mid stringByAppendingString:[uuidID UUIDString]];
        NSData *d = [sCombined dataUsingEncoding:NSASCIIStringEncoding];
        NSString *sHash = [ChatSeal insecureHashForData:d];
        if (sHash) {
            return [msgDir URLByAppendingPathComponent:[NSString stringWithFormat:@"decoy-%@", sHash]];
        }
    }
    return nil;
}

/*
 *  Save the alternate decoy to disk if if is specified.
 */
-(BOOL) saveAlternateDecoyIfPresentWithError:(NSError **)err
{
    if (!imgAltDecoy) {
        return YES;
    }
    
    NSURL *uDecoy = [self alternateDecoyURL];
    if (!uDecoy) {
        [CS_error fillError:err withCode:CSErrorInvalidSecureRequest andFailureReason:@"Failed to generate a valid alternate decoy URL."];
        return NO;
    }
    return [ChatSealMessageEntry saveSecureImage:imgAltDecoy toURL:uDecoy withSeal:seal andError:err];
}

/*
 *  If there is an alternate decoy file, destory it.
 */
-(void) destroyAlternateDecoyFileIfPresent
{
    NSURL *uFile = [self alternateDecoyURL];
    if (uFile) {
        [[NSFileManager defaultManager] removeItemAtURL:uFile error:nil];
    }
}

/*
 *  Make sure that any placeholders created with this entry are discarded.
 */
-(void) discardEntryPlaceholders
{
    NSUInteger numItems = [self numItems];
    for (NSUInteger i = 0; i < numItems;i++) {
        if (![self isItemAnImageAtIndex:i]) {
            continue;
        }
        NSString *baseName = [self placeholderBaseNameForIndex:i];
        [CS_cacheMessage discardPlaceholderForBase:baseName andMessage:mid];
    }
}

/*
 *  Load a secure image URL for this entry.
 */
+(UIImage *) loadSecureImage:(NSURL *) uFile withSeal:(RSISecureSeal *) seal andError:(NSError **) err
{
    NSData *d = [NSData dataWithContentsOfURL:uFile];
    if (!d) {
        [CS_error fillError:err withCode:CSErrorFilesystemAccessError andFailureReason:@"Failed to load image file."];
        return nil;
    }
    
    //  - decrypt it.
    NSDictionary *dMessage = [seal decryptMessage:d withError:err];
    if (!dMessage) {
        return nil;
    }
    
    //  - pull the image from the decrypted data
    NSData *dImage = [dMessage objectForKey:PSM_GENERIC_KEY];
    UIImage *img = nil;
    if (!dImage || !(img = [UIImage imageWithData:dImage])) {
        [CS_error fillError:err withCode:CSErrorArchivalError andFailureReason:@"Failed to find the expected image data."];
        return nil;
    }
    return img;
}

/*
 *  The sealed message cache is a truly temporary location on disk where we can track the existing messages.
 */
+(NSURL *) sealedMessageCacheWithCreationIfNotExist:(BOOL) doCreate
{
    NSURL *uRet = [[NSFileManager defaultManager] URLForDirectory: NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    uRet        = [uRet URLByAppendingPathComponent:@"packed"];
    if (doCreate && ![[NSFileManager defaultManager] fileExistsAtPath:[uRet path]]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:[uRet path] withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return uRet;
}

/*
 *  Return a URL to use for storing the sealed message.
 */
-(NSURL *) sealedMessageEntryURL
{
    NSURL    *uDir   = [ChatSealMessageEntry sealedMessageCacheWithCreationIfNotExist:YES];
    NSString *sEntry = [[self entryUUID] UUIDString];
    NSString *sApp   = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    if (uDir && sEntry && sApp) {
        // - create a name that is appropriate but doesn't divulge the entry id.
        NSMutableData *md = [NSMutableData data];
        [md appendData:[sEntry dataUsingEncoding:NSASCIIStringEncoding]];
        [md appendData:[sApp dataUsingEncoding:NSASCIIStringEncoding]];
        NSString *hash = [ChatSeal insecureHashForData:md];
        if (hash) {
            return [uDir URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", hash]];
        }
    }
    return nil;
}

/*
 *  Save the provided message entry to disk, but make sure that the directory doesn't grow endlessly.
 */
+(void) saveSealedMessageEntry:(NSData *) dMsg intoURL:(NSURL *) uEntry
{
    NSURL *uCachedDir = [ChatSealMessageEntry sealedMessageCacheWithCreationIfNotExist:YES];
    NSError *err      = nil;
    NSArray *arrItems = [ChatSeal sortedDirectoryListForURL:uCachedDir withError:&err];
    if (!arrItems) {
        NSLog(@"CS: Failed to enumerate the sealed message cache.  %@", [err localizedDescription]);
        return;
    }
    
    NSMutableArray *maItems = [NSMutableArray arrayWithArray:arrItems];
    while ([maItems count] > PSM_NUM_CACHED_PACKED) {
        NSURL *u = [maItems objectAtIndex:0];
        if (![[NSFileManager defaultManager] removeItemAtURL:u error:&err]) {
            NSLog(@"CS: Failed to delete %@ from the sealed message cache.  %@", u, [err localizedDescription]);
            return;
        }
        [maItems removeObjectAtIndex:0];
    }
    
    if (dMsg && ![dMsg writeToURL:uEntry atomically:YES]) {
        NSLog(@"CS: Failed to write the sealed message %@.", uEntry);
    }
}

/*
 *  This is intended to be a highly-efficient way of identifying entries in the buffer.
 */
+(BOOL) entryAtLocation:(void *) entry isEqualToUUID:(uuid_t *) rawUUID
{
    if (entry) {
        unsigned char *ptr = (unsigned char *) entry;
        ptr               += sizeof(uint32_t);              //  the id in the buffer is always offset.
        if (!memcmp(ptr, rawUUID, sizeof(uuid_t))) {
            return YES;
        }
    }
    return NO;
}

/*
 *  Retrieve the necessary content to generate a packed image.
 *  - this is intended to be relatively fast to perform.
 */
-(CS_messageEntryExport *) exportEntryWithError:(NSError **) err
{
    CS_messageEntryExport *ret = [[[CS_messageEntryExport alloc] init] autorelease];
    [editionLock lock];
    
    // - because packing takes a while, we are only going to grab what we need and then release
    //   the edition lock to allow the message to continue to be used in the mean time.
    // - ensure that roles are enforced when exporting messages.
    if (!pExistingEntry || [editionLock isEqualToEdition:creationEdition]) {
        if ([self isOwnerEntry] == [seal isOwned]) {
            // - see if there is already an entry and return that to avoid a costly packing exercise.
            ret.uCachedItem     = [self sealedMessageEntryURL];
            ret.dCachedExported = [NSData dataWithContentsOfURL:ret.uCachedItem];
            if (!ret.dCachedExported || ![UIImage imageWithData:ret.dCachedExported]) {
                ret.dCachedExported = nil;
                
                // - generate a dictionary to pack into the decoy
                ret.exportedContent = [self sealedMessageDictionary];
                if (seal && ret.exportedContent) {
                    ret.seal      = seal;
                    ret.entryUUID = [self entryUUID];
                    
                    // - locate the appropriate decoy file
                    NSError *tmp = nil;
                    ret.decoy    = [self hasAlternateDecoy] ? [self alternateDecoyWithError:&tmp] : nil;
                    if (!ret.decoy) {
                        // - if the error value is set, then we failed to load and should return.
                        if (tmp != nil) {
                            if (err) {
                                *err = tmp;
                            }
                        }
                        else {
                            NSURL *uCommonDecoy = [ChatSealMessage decoyFileForMessageDirectory:msgDir];
                            ret.decoy           = [ChatSealMessageEntry loadSecureImage:uCommonDecoy withSeal:seal andError:err];
                        }
                    }
                }
                else {
                    [CS_error fillError:err withCode:CSErrorInvalidSecureRequest andFailureReason:@"The message entry is not appropriate for message sealing."];
                }
            }
        }
        else {
            [CS_error fillError:err withCode:CSErrorInvalidSeal andFailureReason:@"Invalid role for message export."];
        }
    }
    else {
        [CS_error fillError:err withCode:CSErrorStaleMessage];
    }
    
    [editionLock unlock];
    
    // - if we got everything we need, then return it now.
    if (ret.dCachedExported || (ret.seal && ret.exportedContent && ret.decoy)) {
        return ret;
    }
    return nil;
}

/*
 *  This operation may take a while so don't hold a lock while doing it.
 */
+(NSData *) buildSealedMessageFromExportedEntry:(CS_messageEntryExport *) ee withError:(NSError **)err
{
    if (ee.dCachedExported) {
        return [[ee.dCachedExported retain] autorelease];
    }
    else {
        NSData *ret = [ee.seal packRoleBasedMessage:ee.exportedContent intoImage:ee.decoy withError:err];
        if (ret) {
            // - we are always going to add this new message to the processed cache to not permit it to
            //   be downloaded since we have it already.
            NSString *sHash = [ee.seal hashPackedMessage:ret];
            if (sHash) {
                [CS_cacheMessage markMessageEntryAsProcessed:[ee.entryUUID UUIDString] withHash:sHash];
            }
            
            // - and we're going to save a copy of it in the packed message cache to minimize the cost of
            //   regeneration.
            [ChatSealMessageEntry saveSealedMessageEntry:ret intoURL:ee.uCachedItem];
        }
        return ret;
    }
}
@end
