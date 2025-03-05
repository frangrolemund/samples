//
//  ChatSealVaultPlaceholder.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/14/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "ChatSealVaultPlaceholder.h"
#import "ChatSeal.h"

// - constants
static NSString *PSVP_KEY_ISACTIVE    = @"ia";
static NSString *PSVP_KEY_SEALCOLOR   = @"sc";
static NSString *PSVP_KEY_LENOWNER    = @"lo";
static NSString *PSVP_KEY_ISMINE      = @"im";
static NSString *PSVP_KEY_LENSTATUS   = @"ls";
static NSString *PSVP_KEY_WARNSTATUS  = @"ws";
static int      PSVP_MAX_PLACEHOLDERS = 10;

// - forward declarations
@interface ChatSealVaultPlaceholder (internal)
+(NSURL *) placeholderDirectory;
-(id) initWithIdentity:(ChatSealIdentity *) identity;
@end

/**************************
 ChatSealVaultPlaceholder
 **************************/
@implementation ChatSealVaultPlaceholder
/*
 *  Object attributes.
 */
{
    BOOL                  isMine;
    BOOL                  isActive;
    RSISecureSeal_Color_t sealColor;
    NSUInteger            lenOwner;
    NSUInteger            lenStatus;
    BOOL                  isWarnStatus;
}

/*
 *  Return a new placeholder object for the given identity.
 */
+(ChatSealVaultPlaceholder *) placeholderForIdentity:(ChatSealIdentity *) identity
{
    return [[[ChatSealVaultPlaceholder alloc] initWithIdentity:identity] autorelease];
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        isMine       = NO;
        isActive     = NO;
        sealColor    = RSSC_INVALID;
        lenOwner     = 0;
        lenStatus    = 0;
        isWarnStatus = NO;
    }
    return self;
}

/*
 *  Initialize the object from a decoder.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [self init];
    if (self) {
        isMine   = [aDecoder decodeBoolForKey:PSVP_KEY_ISMINE];
        isActive = [aDecoder decodeBoolForKey:PSVP_KEY_ISACTIVE];
        if ([aDecoder containsValueForKey:PSVP_KEY_SEALCOLOR]) {
            sealColor = (RSISecureSeal_Color_t) [aDecoder decodeIntegerForKey:PSVP_KEY_SEALCOLOR];
        }
        else {
            sealColor = RSSC_INVALID;
        }
        lenOwner     = (NSUInteger) [aDecoder decodeIntegerForKey:PSVP_KEY_LENOWNER];
        lenStatus    = (NSUInteger) [aDecoder decodeIntegerForKey:PSVP_KEY_LENSTATUS];
        isWarnStatus = [aDecoder decodeBoolForKey:PSVP_KEY_WARNSTATUS];
    }
    return self;
}

/*
 *  Save off this object.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeBool:isMine forKey:PSVP_KEY_ISMINE];
    [aCoder encodeBool:isActive forKey:PSVP_KEY_ISACTIVE];
    [aCoder encodeInteger:sealColor forKey:PSVP_KEY_SEALCOLOR];
    [aCoder encodeInteger:(NSInteger) lenOwner forKey:PSVP_KEY_LENOWNER];
    [aCoder encodeInteger:(NSInteger) lenStatus forKey:PSVP_KEY_LENSTATUS];
    [aCoder encodeBool:isWarnStatus forKey:PSVP_KEY_WARNSTATUS];
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [super dealloc];
}

/*
 *  The purpose of this method is to update the active data base of vault placeholder
 *  information.
 */
+(void) saveVaultSealPlaceholderData
{
    NSError *err              = nil;
    NSArray *arrAllIdentities = [ChatSeal availableIdentitiesWithError:&err];
    if (!arrAllIdentities) {
        NSLog(@"CS: Failed to retrieve a list of valid identities for saving seal placeholder data.  %@", [err localizedDescription]);
        arrAllIdentities = [NSArray array];
    }
    
    // - this has to be sorted in the same way the seals are sorted.
    NSMutableArray *maIdents = [NSMutableArray arrayWithArray:arrAllIdentities];
    [ChatSealIdentity sortIdentityArrayForDisplay:maIdents];
    
    // - now convert the first N seals into placeholders, which are just items that can be used to recreate
    //   a stylized impression of the content, but no real data appears.
    NSMutableArray *maPlaceholders = [NSMutableArray array];
    for (NSUInteger i = 0; i < [maIdents count] && i < PSVP_MAX_PLACEHOLDERS; i++) {
        ChatSealIdentity *psi = [maIdents objectAtIndex:i];
        ChatSealVaultPlaceholder *svp = [ChatSealVaultPlaceholder placeholderForIdentity:psi];
        [maPlaceholders addObject:svp];
    }
    
    //  - now save this array to disk, and it can be unencrypted because there is nothing significant in these
    //    items.
    NSURL *uPH = [ChatSealVaultPlaceholder placeholderDirectory];
    NSData *d  = [NSKeyedArchiver archivedDataWithRootObject:maPlaceholders];
    if (d) {
        if (![d writeToURL:uPH atomically:YES]) {
            NSLog(@"CS: Failed to save message overview placeholder content.");
        }
    }
}

/*
 *  Return the saved vault placeholder data.
 */
+(NSArray *) vaultSealPlaceholderData
{
    // - load the placeholder data from disk.
    NSURL *u      = [ChatSealVaultPlaceholder placeholderDirectory];
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

/*
 *  Return whether this is my seal.
 */
-(BOOL) isMine
{
    return isMine;
}

/*
 *  Return whether this seal is active.
 */
-(BOOL) isActive
{
    return isActive;
}

/*
 *  Return the seal color.
 */
-(RSISecureSeal_Color_t) sealColor
{
    return sealColor;
}

/*
 *  Return the length of the owner name.
 */
-(NSUInteger) lenOwner
{
    return lenOwner;
}

/*
 *  Return the length in characters of the status.
 */
-(NSUInteger) lenStatus
{
    return lenStatus;
}

/*
 *  Return whether the status should be displayed as a warning.
 */
-(BOOL) isWarnStatus
{
    return isWarnStatus;
}

@end

/*************************************
 ChatSealVaultPlaceholder (internal)
 *************************************/
@implementation ChatSealVaultPlaceholder (internal)
/*
 *  Return the URL for storing placeholders.
 */
+(NSURL *) placeholderDirectory
{
    NSURL *u = [ChatSeal standardPlaceholderDirectory];
    return [u URLByAppendingPathComponent:@"s_ph"];
}

/*
 *  Initialize the placeholder object.
 */
-(id) initWithIdentity:(ChatSealIdentity *) identity
{
    self = [self init];
    if (self) {
        NSString *active = [ChatSeal activeSeal];
        isMine           = identity.isOwned;
        isActive         = [active isEqualToString:identity.sealId];
        sealColor        = identity.color;
        lenOwner         = [identity.ownerName length];
        lenStatus        = [[identity computedStatusTextAndDisplayAsWarning:&isWarnStatus] length];
    }
    return self;
}
@end