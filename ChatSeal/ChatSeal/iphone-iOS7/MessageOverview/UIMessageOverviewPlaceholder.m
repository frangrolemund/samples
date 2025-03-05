//
//  UIMessageOverviewPlaceholder.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/9/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIMessageOverviewPlaceholder.h"
#import "ChatSeal.h"

//  - constants
static NSString *UIMOP_KEY_SEALCOLOR    = @"sc";
static NSString *UIMOP_KEY_LENAUTHOR    = @"la";
static NSString *UIMOP_KEY_LENSYNOP     = @"ls";
static NSString *UIMOP_KEY_AUTHME       = @"am";
static NSString *UIMOP_KEY_ISREAD       = @"ir";
static NSString *UIMOP_KEY_ISLOCKED     = @"il";
static const int UIMOP_MAX_PLACEHOLDERS = 10;           // only enough for a screenful of data.

//  - forward declarations
@interface UIMessageOverviewPlaceholder (internal)
+(NSURL *) placeholderDirectory;
-(id) initWithMessage:(ChatSealMessage *) psm;
@end

/*****************************
 UIMessageOverviewPlaceholder
 *****************************/
@implementation UIMessageOverviewPlaceholder
/*
 *  Object attributes.
 */
{
    RSISecureSeal_Color_t sealColor;
    NSUInteger            lenAuthor;
    NSUInteger            lenSynopsis;
    BOOL                  isAuthorMe;
    BOOL                  isRead;
    BOOL                  isLocked;
}

/*
 *  Return a placeholder initialized for the given message.
 */
+(UIMessageOverviewPlaceholder *) placeholderForMessage:(ChatSealMessage *) psm
{
    return [[[UIMessageOverviewPlaceholder alloc] initWithMessage:psm] autorelease];
}

/*
 *  Initialize the object using the supplied decoder.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [self init];
    if (self) {
        if ([aDecoder containsValueForKey:UIMOP_KEY_SEALCOLOR]) {
            sealColor = (RSISecureSeal_Color_t) [aDecoder decodeIntegerForKey:UIMOP_KEY_SEALCOLOR];
        }
        else {
            sealColor = RSSC_INVALID;
        }
        lenAuthor   = (NSUInteger) [aDecoder decodeIntegerForKey:UIMOP_KEY_LENAUTHOR];
        lenSynopsis = (NSUInteger) [aDecoder decodeIntegerForKey:UIMOP_KEY_LENSYNOP];
        isAuthorMe  = [aDecoder decodeBoolForKey:UIMOP_KEY_AUTHME];
        isRead      = [aDecoder decodeBoolForKey:UIMOP_KEY_ISREAD];
        isLocked    = [aDecoder decodeBoolForKey:UIMOP_KEY_ISLOCKED];
    }
    return self;
}

/*
 *  Free the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        sealColor   = RSSC_INVALID;
        lenAuthor   = 0;
        lenSynopsis = 0;
        isAuthorMe  = NO;
        isRead      = YES;
        isLocked    = YES;
    }
    return self;
}

/*
 *  Encode the object.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInteger:sealColor forKey:UIMOP_KEY_SEALCOLOR];
    [aCoder encodeInteger:(NSInteger) lenAuthor forKey:UIMOP_KEY_LENAUTHOR];
    [aCoder encodeInteger:(NSInteger) lenSynopsis forKey:UIMOP_KEY_LENSYNOP];
    [aCoder encodeBool:isAuthorMe forKey:UIMOP_KEY_AUTHME];
    [aCoder encodeBool:isRead forKey:UIMOP_KEY_ISREAD];
    [aCoder encodeBool:isLocked forKey:UIMOP_KEY_ISLOCKED];
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [super dealloc];
}

/*
 *  Return the stored seal color.
 */
-(RSISecureSeal_Color_t) sealColor
{
    return sealColor;
}

/*
 *  Return the length of the author name.
 */
-(NSUInteger) lenAuthor
{
    return lenAuthor;
}

/*
 *  Return the length of the synopsis.
 */
-(NSUInteger) lenSynopsis
{
    return lenSynopsis;
}

/*
 *  Return whether I am the author.
 */
-(BOOL) isAuthorMe
{
    return isAuthorMe;
}

/*
 *  Return whether this has been read.
 */
-(BOOL) isRead
{
    return isRead;
}

/*
 *  Return whether this is locked.
 */
-(BOOL) isLocked
{
    return isLocked;
}

/*
 *  Save abbreviated, insecure copies of message data that can be used to recreate a 
 *  stylized version of the overview later when the vault is inaccessible.
 */
+(void) saveVaultMessagePlaceholderData
{
    // - retrieve the list of active messages, assuming we're showing all of them.
    NSError *err = nil;
    NSArray *arr = [ChatSeal messageListForSearchCriteria:nil withItemIdentification:nil andError:&err];
    if (!arr) {
        NSLog(@"CS:  Failed to retrieve a list of messages for saving placeholder data.  %@", [err localizedDescription]);
        arr = [NSArray array];
    }
    
    // - now convert the first N messages into placeholders, which are just items that can be used to recreate
    //   a stylized impression of the content, but no real data appears.
    NSMutableArray *maPlaceholders = [NSMutableArray array];
    for (NSUInteger i = 0; i < [arr count] && i < UIMOP_MAX_PLACEHOLDERS; i++) {
        ChatSealMessage *psm              = [arr objectAtIndex:i];
        UIMessageOverviewPlaceholder *moph = [UIMessageOverviewPlaceholder placeholderForMessage:psm];
        [maPlaceholders addObject:moph];
    }
    
    //  - now save this array to disk, and it can be unencrypted because there is nothing significant in these
    //    items.
    NSURL *uPH = [UIMessageOverviewPlaceholder placeholderDirectory];
    NSData *d  = [NSKeyedArchiver archivedDataWithRootObject:maPlaceholders];
    if (d) {
        if (![d writeToURL:uPH atomically:YES]) {
            NSLog(@"CS:  Failed to save message overview placeholder content.");
        }
    }
}

/*
 *  Return the list of active message placeholders.
 */
+(NSArray *) vaultMessagePlaceholderData
{
    // - load the placeholder data from disk.
    NSURL *u      = [UIMessageOverviewPlaceholder placeholderDirectory];
    NSObject *obj = [NSKeyedUnarchiver unarchiveObjectWithFile:[u path]];
    NSArray  *aPH = nil;
    if (obj && [obj isKindOfClass:[NSArray class]]) {
        aPH = (NSArray *) obj;
    }
    else {
        aPH = [NSArray array];
    }
    return aPH;
}

@end


/***************************************
 UIMessageOverviewPlaceholder (internal)
 ***************************************/
@implementation UIMessageOverviewPlaceholder (internal)
/*
 *  Return the URL for storing placeholders.
 */
+(NSURL *) placeholderDirectory
{
    NSURL *u = [ChatSeal standardPlaceholderDirectory];
    return [u URLByAppendingPathComponent:@"m_ph"];
}

/*
 *  Initialize the placeholder based on an existing message.
 */
-(id) initWithMessage:(ChatSealMessage *) psm
{
    self = [self init];
    if (self) {
        if (psm) {
            sealColor   = psm.sealColor;
            lenAuthor   = [psm.author length];
            lenSynopsis = [psm.synopsis length];
            isAuthorMe  = [psm isAuthorMe];
            isRead      = [psm isRead];
            isLocked    = [psm isLocked];
        }
    }
    return self;
}
@end
