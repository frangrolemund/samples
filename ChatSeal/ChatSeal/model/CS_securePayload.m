//
//  CS_sealRequestPayload.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/23/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_securePayload.h"
#import "ChatSeal.h"
#import "ChatSealFeedCollector.h"

// - constants
static const NSUInteger CS_SRP_MIN_RANDOM   = 32;
static const NSUInteger CS_SRP_MAX_RANDOM   = 255;
static NSString         *CS_SRP_OP_GET_SEAL = @"!!PS-GET-SEAL!!";
static NSString         *CS_SRP_OP_GOT_SEAL = @"!!PSR-NEW-SEAL!!";
static NSString         *CS_SRP_OP_HAD_SEAL = @"!!PSR-HAD-SEAL!!";
static NSString         *CS_SRP_KEY_SEAL    = @"sealKey";
static NSString         *CS_SRP_KEY_NAME    = @"sealOwner";
static NSString         *CS_SRP_KEY_FEEDS   = @"feeds";
static NSUInteger       CS_SRP_MAX_FEEDS    = 10;

// - forward declarations
@interface CS_secureSealRequestPayload : NSObject
@property (nonatomic, retain) NSString *payloadOp;
@property (nonatomic, retain) NSArray  *requestorFeeds;
@end

@interface CS_securePayload (internal)
+(NSData *) payloadForOp:(NSString *) opCode andURL:(NSURL *) u withError:(NSError **) err;
+(CS_secureSealRequestPayload *) requestPayloadForData:(NSData *) payload andURL:(NSURL *) u;
+(NSArray *) myFeedLocationsIfTransferAllowedWithSeal:(NSString *) sid;
@end

/*************************
 CS_securePayload
 *************************/
@implementation CS_securePayload
/*
 *  Using the given URL, generate a payload that can request
 *  a seal.
 */
+(NSData *) sealRequestPayloadForSecureURL:(NSURL *) u withError:(NSError **) err
{
    return [CS_securePayload payloadForOp:CS_SRP_OP_GET_SEAL andURL:u withError:err];
}

/*
 *  Validate the given payload against the secure URL.
 */
+(BOOL) isSealRequestPayload:(NSData *) payload validForURL:(NSURL *) u
{
    CS_secureSealRequestPayload *rp = [CS_securePayload requestPayloadForData:payload andURL:u];
    if (rp.payloadOp && [rp.payloadOp isEqualToString:CS_SRP_OP_GET_SEAL]) {
        return YES;
    }
    return NO;
}

/*
 *  For the time being, we're going to rely on the encrypted network communication
 *  more than the encryption of the seal data during export because I don't
 *  like the idea of anything being in the clear, including the seal image itself.
 *  - I'm not calling this anything but a 'key' because I don't want to confuse
 *    the intent here.  I'm keeping the original password support in the secure image
 *    library, but effectively not using it.
 */
+(NSString *) commonExportKey
{
    return @"!~!";
}

/* 
 *  Create a data block that encapsulates a seal for transfer to another device.
 */
+(NSData *) sealTransferPayloadForSealId:(NSString *) sid withError:(NSError **) err
{
    RSISecureSeal *ss = [RealSecureImage sealForId:sid andError:err];
    if (!ss) {
        return nil;
    }
    
    // - Because the connection is already encrypted, I'm not going to use a secondary password
    //   here.  I had considered not encrypting the payload at all, but I didn't really like the idea
    //   of sending over a packed JPEG on second thought since the JPEG itself would be in the clear, even if
    //   the seal data wasn't.
    NSData *dExported = [ss exportWithPassword:[CS_securePayload commonExportKey] andError:err];
    if (!dExported) {
        return nil;
    }
    
    // - The payload is going to minimally include the seal, but can also include other attributes as well
    //   that make the experience simpler.
    NSMutableDictionary *mdPayload = [NSMutableDictionary dictionary];
    [mdPayload setObject:dExported forKey:CS_SRP_KEY_SEAL];
    
    // ...like the owner name.
    NSString *owner = [ChatSeal ownerNameForSeal:sid];
    if (owner && [owner length]) {
        [mdPayload setObject:owner forKey:CS_SRP_KEY_NAME];
    }
    
    // ...and the list of feeds.
    [mdPayload setObject:[self myFeedLocationsIfTransferAllowedWithSeal:sid] forKey:CS_SRP_KEY_FEEDS];
        
    // - now create an archive for both.
    NSData *dPayload = nil;
    @try {
        dPayload = [NSKeyedArchiver archivedDataWithRootObject:mdPayload];
    }
    @catch (NSException *exception) {
        NSLog(@"CS: Seal payload archive exception. %@", [exception description]);
        [CS_error fillError:err withCode:CSErrorSecureTransferFailed andFailureReason:@"Failed to generate a valid archive."];
        return nil;
    }
    return dPayload;
}

/*
 *  Parse a data block with the assumption it is a transferred seal.
 */
+(CS_secureSealTransferPayload *) parseSealTransferPayload:(NSData *) payload withError:(NSError **) err
{
    NSObject *obj = nil;
    @try {
        obj = [NSKeyedUnarchiver unarchiveObjectWithData:payload];
    }
    @catch (NSException *exception) {
        NSLog(@"CS: Seal payload unarchive exception. %@", [exception description]);
        obj = nil;
    }
    
    if (!obj || ![obj isKindOfClass:[NSDictionary class]]) {
        [CS_error fillError:err withCode:CSErrorIdentityTransferFailure andFailureReason:@"Failed to receive a valid archive."];
        return nil;
    }
    
    NSDictionary *dict                 = (NSDictionary *) obj;
    CS_secureSealTransferPayload *stp = [[[CS_secureSealTransferPayload alloc] init] autorelease];
    stp.sealData                       = [dict objectForKey:CS_SRP_KEY_SEAL];
    stp.sealOwner                      = [dict objectForKey:CS_SRP_KEY_NAME];
    stp.sealOwnerFeeds                 = [dict objectForKey:CS_SRP_KEY_FEEDS];
    if (!stp.sealData) {
        [CS_error fillError:err withCode:CSErrorIdentityTransferFailure andFailureReason:@"Failed to receive a valid archive."];
        return nil;
    }
    return stp;
}

/*
 *  Generate a seal receipt payload for the server and give an indication about
 *  what happened.
 */
+(NSData *) sealReceiptPayloadForSecureURL:(NSURL *) u andReplyAsNew:(BOOL) isNewSeal withError:(NSError **) err
{
    if (isNewSeal) {
        return [CS_securePayload payloadForOp:CS_SRP_OP_GOT_SEAL andURL:u withError:err];
    }
    else {
        return [CS_securePayload payloadForOp:CS_SRP_OP_HAD_SEAL andURL:u withError:err];
    }
}

/*
 *  Figure out if the seal receipt payload is valid.
 */
+(BOOL) isSealReceiptPayload:(NSData *) payload validForURL:(NSURL *) u returningIsNew:(BOOL *) isNewSeal andRequestorFeeds:(NSArray **) reqFeeds
{
    CS_secureSealRequestPayload *sp = [CS_securePayload requestPayloadForData:payload andURL:u];
    BOOL isGood                     = NO;
    if (sp.payloadOp) {
        if ([sp.payloadOp isEqualToString:CS_SRP_OP_GOT_SEAL]) {
            if (isNewSeal) {
                *isNewSeal = YES;
            }
            isGood = YES;
        }
        else if ([sp.payloadOp isEqualToString:CS_SRP_OP_HAD_SEAL]) {
            if (isNewSeal) {
                *isNewSeal = NO;
            }
            isGood = YES;
        }
        
        // - when the caller is asking for a feed list, return it if possible.
        if (reqFeeds && isGood) {
            *reqFeeds = sp.requestorFeeds;
        }
    }
    return isGood;
}
@end

/*****************************
 CS_securePayload (internal)
 *****************************/
@implementation CS_securePayload (internal)
/*
 *  Generate a new payload buffer.
 */
+(NSData *) payloadForOp:(NSString *) opCode andURL:(NSURL *) u withError:(NSError **) err
{
    if (!opCode || [opCode length] == 0) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        return nil;
    }
    
    // - the idea is to use random data plus the URL as a basis for
    //   the payload so that its structure is non-deterministic to an outsider and
    //   allows the server to ensure that it is talking with a valid client.
    NSMutableData *mdRandom = [NSMutableData dataWithLength:CS_SRP_MAX_RANDOM];
    uint8_t *randData = (uint8_t *) [mdRandom mutableBytes];
    if (SecRandomCopyBytes(kSecRandomDefault, CS_SRP_MAX_RANDOM, randData) != 0) {
        [CS_error fillError:err withCode:CSErrorSecurityFailure andFailureReason:@"Unable to generate secure random data."];
        return nil;
    }
    
    // - and get a hash of that random data plus the URL.
    @try {
        // - figure out how long the payload will be.
        NSUInteger len = *randData;
        if (len < CS_SRP_MIN_RANDOM) {
            len = CS_SRP_MIN_RANDOM;
        }
        
        // - then apply those bytes
        NSMutableData *mdRet = [NSMutableData data];
        [mdRet appendBytes:randData length:len];
        
        NSMutableData *mdHash = [NSMutableData dataWithData:mdRet];
        NSString *sURL        = [u path];
        [mdHash appendData:[sURL dataUsingEncoding:NSUTF8StringEncoding]];
        NSString *sHash       = [ChatSeal insecureHashForData:mdHash];      //  HASH-NOTE: can be insecure because the payload is encrypted.
        if (!sHash) {
            [CS_error fillError:err withCode:CSErrorSecurityFailure andFailureReason:@"Unable to securely hash the data."];
            return nil;
        }
        
        // - now append the hash with the rest of the random content.
        // - the operation tag is appended afterwards so that its exact position is never
        //   predictable.
        [mdRet appendData:[sHash dataUsingEncoding:NSUTF8StringEncoding]];
        [mdRet appendData:[opCode dataUsingEncoding:NSUTF8StringEncoding]];
        [mdRet appendData:[NSMutableData dataWithLength:4]];                //  null-pad
        
        // - add on my feeds if this is is a final opcode.
        if ([opCode isEqualToString:CS_SRP_OP_GOT_SEAL] || [opCode isEqualToString:CS_SRP_OP_HAD_SEAL]) {
            NSArray *arrFeeds = [CS_securePayload myFeedLocationsIfTransferAllowedWithSeal:nil];
            NSData *dFeeds    = [NSKeyedArchiver archivedDataWithRootObject:arrFeeds];
            uint32_t feedsLen = (uint32_t) htonl([dFeeds length]);
            [mdRet appendBytes:&feedsLen length:sizeof(feedsLen)];
            [mdRet appendData:dFeeds];
        }
        
        if (len != CS_SRP_MAX_RANDOM) {
            [mdRet appendData:[NSData dataWithBytes:randData + len length:CS_SRP_MAX_RANDOM - len]];
        }
        
        return mdRet;
    }
    @catch (NSException *exception) {
        [CS_error fillError:err withCode:CSErrorSecurityFailure andFailureReason:[exception description]];
        return nil;
    }
}

/*
 *  Return the textual opcode for the given payload.
 *  - if the payload is invalid, this method returns nil.
 */
+(CS_secureSealRequestPayload *) requestPayloadForData:(NSData *) payload andURL:(NSURL *) u
{
    if (!payload || [payload length] < CS_SRP_MAX_RANDOM || !u) {
        return nil;
    }
    
    CS_secureSealRequestPayload *srp = [[[CS_secureSealRequestPayload alloc] init] autorelease];
    @try {
        const uint8_t *reqData = (uint8_t *) [payload bytes];
        NSUInteger len = *reqData;
        if (len < CS_SRP_MIN_RANDOM) {
            len = CS_SRP_MIN_RANDOM;
        }
        
        NSMutableData *mdHash = [NSMutableData dataWithBytes:reqData length:len];
        NSString *sURL        = [u path];
        [mdHash appendData:[sURL dataUsingEncoding:NSUTF8StringEncoding]];
        NSString *sHash       = [ChatSeal insecureHashForData:mdHash];          //  HASH-NOTE: can be insecure because the payload was encrypted.
        if (!sHash) {
            return nil;
        }
        
        // - now validate the hash against what is in the payload.
        NSData *dEncodedHash = [sHash dataUsingEncoding:NSUTF8StringEncoding];
        if (len + [dEncodedHash length] > [payload length]) {
            return nil;
        }

        if (memcmp(reqData + len, dEncodedHash.bytes, dEncodedHash.length)) {
            return nil;
        }
        
        // - the hash is good, pull out the op-code.
        NSUInteger opcodeOffset = len + dEncodedHash.length;
        if (opcodeOffset >= [payload length] - 1) {
            return nil;
        }
        
        NSUInteger remainderLength = [payload length] - opcodeOffset;
        size_t lenOp               = strnlen((const char *) reqData + opcodeOffset, remainderLength);
        if (lenOp && lenOp >= remainderLength) {
            return nil;
        }
        
        NSData *dRemainder = [NSData dataWithBytes:reqData + opcodeOffset length:lenOp];
        NSString *sOpcode  = [[[NSString alloc] initWithData:dRemainder encoding:NSUTF8StringEncoding] autorelease];
        srp.payloadOp      = sOpcode;
        
        // - now grab the feeds if this is an op that supports it
        if ([srp.payloadOp isEqualToString:CS_SRP_OP_GOT_SEAL] || [srp.payloadOp isEqualToString:CS_SRP_OP_HAD_SEAL]) {
            @try {
                NSUInteger feedsOffset = opcodeOffset + lenOp + 4;
                uint32_t feedsLen      = 0;
                if ([payload length] - feedsOffset > sizeof((feedsLen))) {
                    memcpy(&feedsLen, reqData + feedsOffset, sizeof(feedsLen));
                    feedsLen           = ntohl(feedsLen);
                    if (feedsOffset + sizeof(feedsLen) + feedsLen <= [payload length]) {
                        NSData *dFeeds     = [NSData dataWithBytes:reqData + feedsOffset + sizeof(feedsLen) length:feedsLen];
                        srp.requestorFeeds = [NSKeyedUnarchiver unarchiveObjectWithData:dFeeds];
                    }
                }
            }
            @catch (NSException *exception) {
                // just ignore it.
            }
        }            
        return srp;
    }
    @catch (NSException *exception) {
        NSLog(@"CS:  Unexpected exception creating request payload.  %@", [exception description]);
        return nil;
    }
}

/*
 *  Return an array of my feed locations if that is permitted by the app settings.
 */
+(NSArray *) myFeedLocationsIfTransferAllowedWithSeal:(NSString *) sid
{
    NSMutableArray *maRet = [NSMutableArray array];
    
    // - make sure that you check that the settings allow it!
    if ([ChatSeal canShareFeedsDuringExchanges]) {
        NSArray *arrFeeds = [[ChatSeal applicationFeedCollector] availableFeedsAsSortedList];
        for (ChatSealFeed *feed in arrFeeds) {
            // - we will not share disabled feeds because it is possible that the
            //   person wants to only use a limited set of accounts, some being
            //   busines related, for example.
            if (![feed isEnabled]) {
                continue;
            }
            
            ChatSealFeedLocation *cfl = [feed locationWhenUsingSeal:sid];
            if (cfl) {
                [maRet addObject:cfl];
                
                // - I don't think one friend should be allowed to dominate this collector's workload.
                if ([maRet count] > CS_SRP_MAX_FEEDS) {
                    break;
                }
            }
        }
    }
    
    return maRet;
}
@end

/****************************
 CS_secureSealTransferPayload
 ****************************/
@implementation CS_secureSealTransferPayload
@synthesize sealData;
@synthesize sealOwner;
@synthesize sealOwnerFeeds;

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        sealData        = nil;
        sealOwner       = nil;
        sealOwnerFeeds  = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [sealData release];
    sealData = nil;
    
    [sealOwner release];
    sealOwner = nil;
    
    [sealOwnerFeeds release];
    sealOwnerFeeds = nil;
    
    [super dealloc];
}

@end

/*****************************
 CS_secureSealRequestPayload
 *****************************/
@implementation CS_secureSealRequestPayload
@synthesize payloadOp;
@synthesize requestorFeeds;

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        payloadOp      = nil;
        requestorFeeds = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [payloadOp release];
    payloadOp = nil;
    
    [requestorFeeds release];
    requestorFeeds = nil;
    
    [super dealloc];
}

@end
