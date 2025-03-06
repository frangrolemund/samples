//
//  RSI_secureseal.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/31/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "RSI_secureseal.h"
#import "RSI_seal.h"
#import "RSI_error.h"
#import "RSI_secure_props.h"

// - local data
static NSMutableSet *msDeletedSeals = nil;

/****************************
 RSISecureSeal
 ****************************/
@implementation RSISecureSeal
/*
 *  Object attributes
 */
{
    RSI_appkey *creds;
    NSURL      *location;
    RSI_seal   *sealData;
}

/*
 *  Initialize the module.
 */
+(void) initialize
{
    // - These seal objects are handed out on-demand and generally not shared that much, which
    //   means you can technically have two outstanding objects for the same seal or have one outstanding
    //   when you delete it with the static method.  Because we make every attempt to fix a broken keychain
    //   (if that could even occur), it is possible that deleting a seal could have it rise again like a zombie
    //   if another object instance were writing at the same time.   To avoid that possibility, I'm keeping a
    //   set of all the seals we've deleted in this process as a quick option for identifying ones that
    //   shouldn't be used and longer.
    msDeletedSeals = [[NSMutableSet alloc] init];
}

/*
 *  Return the default number of days before a seal self-destructs.
 */
+(NSUInteger) defaultSelfDestructDays
{
    return [RSI_seal defaultSelfDestructDays];
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [creds release];
    creds = nil;
    
    [location release];
    location = nil;
    
    [sealData release];
    sealData = nil;
    
    [super dealloc];
}

/*
 *  Return the id of the seal.
 */
-(NSString *) sealId
{
    @synchronized (self) {
        return [sealData sealId];
    }
}

/*
 *  There are times that I need to be able to store a seal id on disk in
 *  unencrypted form.  In order to ensure that it is always different between
 *  devices, we'll salt that id and make it 'safe' for persistence.
 *  - not safe for network transport.
 */
-(NSString *) safeSealIdWithError:(NSError **) err
{
    @synchronized (self) {
        if (!creds || ![creds isValid]) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return nil;
        }
        
        //  - HASHING-NOTE:
        //      - I am allowing this to be an insecure hash because it is only
        //        locally stored.
        //      - ...but it should be hex because we may end up requesting it a lot and
        //           the base-64 approach is fairly costly.
        return [creds safeSaltedStringAsHex:[self sealId] withError:err];
    }
}

/*
 *  Identifies whether the person holding the seal owns it.
 */
-(BOOL) isOwned
{
    @synchronized (self) {
        if (!creds || ![creds isValid]) {
            return NO;
        }
        
        return [sealData isProducerSeal];
    }
}

/*
 *  Returns the on-disk location of the seal's full data.
 */
-(NSURL *) onDiskFile
{
    @synchronized (self) {
        @synchronized (msDeletedSeals) {
            if ([self isDeleted]) {
                return nil;
            }
        }
        return [[location retain] autorelease];
    }
}

/*
 *  Return the color of the seal.
 */
-(RSISecureSeal_Color_t) colorWithError:(NSError **) err;
{
    @synchronized (self) {
        if (!creds || ![creds isValid]) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return RSSC_INVALID;
        }
        
        return [sealData colorIdWithError:err];
    }
}


/*
 *  Set the color of the seal.
 */
-(BOOL) setColor:(RSISecureSeal_Color_t) color withError:(NSError **) err
{
    @synchronized (self) {
        if (!creds || ![creds isValid]) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return NO;
        }
        
        @synchronized (msDeletedSeals) {
            if ([self isDeleted]) {
                [RSI_error fillError:err withCode:RSIErrorInvalidSeal];
                return NO;
            }
            
            if (![sealData setColorId:color withError:err]) {
                return NO;
            }
            
            return [self synchronizeArchiveAndModifySealImage:NO withError:err];
        }
    }
}

/*
 *  Return the numbder of days until a producer seal self destructs.
 */
-(uint16_t) selfDestructTimeoutWithError:(NSError **) err
{
    @synchronized (self) {
        if (!creds || ![creds isValid]) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return 0;
        }
        
        return [sealData selfDestructTimeoutWithError:err];
    }
}

/*
 *  Assign a self destruct value to a producer seal.
 */
-(BOOL) setSelfDestruct:(uint16_t) sdInDays withError:(NSError **) err;
{
    @synchronized (self) {
        if (!creds || ![creds isValid]) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return NO;
        }
        
        @synchronized (msDeletedSeals) {
            if ([self isDeleted]) {
                [RSI_error fillError:err withCode:RSIErrorInvalidSeal];
                return NO;
            }
            
            if (![sealData setSelfDestruct:sdInDays withError:err]) {
                return NO;
            }
            
            return [self synchronizeArchiveAndModifySealImage:NO withError:err];
        }
    }
}

/*
 *  Invalidate the seal if it is expired.
 *  - the seal's symmetric key will be changed so that it won't
 *    be able to decrypt the messages any longer.
 */
-(BOOL) invalidateExpiredWithError:(NSError **) err
{
    @synchronized (self) {
        if (!creds || ![creds isValid]) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return NO;
        }
        
        @synchronized (msDeletedSeals) {
            if ([self isDeleted]) {
                [RSI_error fillError:err withCode:RSIErrorInvalidSeal];
                return NO;
            }
            
            if (![sealData invalidateExpiredSealWithError:err]) {
                return NO;
            }
            
            return [self synchronizeArchiveAndModifySealImage:YES withError:err];
        }
    }
}

/*
 *  Invalidate the seal if the snapshot-based revocation is enabled.
 *  - the seal's symmetric key will be changed so that it won't
 *    be able to decrypt the messages any longer.
 */
-(BOOL) invalidateForSnapshotWithError:(NSError **) err
{
    @synchronized (self) {
        if (!creds || ![creds isValid]) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return NO;
        }
        
        @synchronized (msDeletedSeals) {
            if ([self isDeleted]) {
                [RSI_error fillError:err withCode:RSIErrorInvalidSeal];
                return NO;
            }
            
            if (![sealData invalidateForSnapshotWithError:err]) {
                return NO;
            }
            
            return [self synchronizeArchiveAndModifySealImage:YES withError:err];
        }
    }
}

/*
 *  Unconditionally invalidate a seal.
 *  - the seal's symmetric key will be changed so that it won't be
 *    able to decrypt the messages any longer.
 */
-(BOOL) invalidateUnconditionallyWithError:(NSError **) err
{
    @synchronized (self) {
        if (!creds || ![creds isValid]) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return NO;
        }
        
        NSError *tmp = nil;
        BOOL isInvalid = [sealData isInvalidatedWithError:&tmp];
        if (tmp) {
            if (err) {
                *err = tmp;
            }
            return NO;
        }
        
        //  - only invalidate the seal and its image when it is not currently invalid,
        //    because it will continue to mangle the seal image.
        if (!isInvalid) {
            @synchronized (msDeletedSeals) {
                if ([self isDeleted]) {
                    [RSI_error fillError:err withCode:RSIErrorInvalidSeal];
                    return NO;
                }
                
                if (![sealData invalidateSealUnconditionallyWithError:err]) {
                    return NO;
                }
                
                return [self synchronizeArchiveAndModifySealImage:YES withError:err];
            }
        }
        return YES;
    }
}

/*
 *  Determine if the seal is invalidated.
 */
-(BOOL) isInvalidatedWithError:(NSError **) err
{
    @synchronized (self) {
        if (!creds || ![creds isValid]) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return NO;
        }
        return [sealData isInvalidatedWithError:err];
    }
}

/*
 *  Explicitly set an expiration date on the seal.   
 *  - This should not be used as a rule because it will allow the computed
 *    expiration date to be tampered-with on any consumer seal, which defeats 
 *    the purpose of managing it from the owner's side.
 */
-(BOOL) setExpirationDate:(NSDate *) dt withError:(NSError **) err
{
    @synchronized (self) {
        if (!creds || ![creds isValid]) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return NO;
        }
        NSLog(@"RSI-ALERT: Assigning an explicit expiration date.");
        return [sealData setExpirationDateUnconditionally:dt withError:err];
    }
}

/*
 *  Return the original seal image, unmodified. 
 */
-(NSData *) originalSealImageWithError:(NSError **) err
{
    @synchronized (self) {
        if (!creds || ![creds isValid]) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return nil;
        }
        
        NSError *tmp = nil;
        NSData *ret = nil;
        @synchronized (msDeletedSeals) {
            if ([self isDeleted]) {
                [RSI_error fillError:err withCode:RSIErrorInvalidSeal];
                return nil;
            }

            @autoreleasepool {
                RSI_securememory *secMem = nil;
                RSI_seal *seal = nil;
                if ([creds readURL:location intoData:&secMem withError:&tmp] &&
                    (seal = [[RSI_seal allocSealWithArchive:secMem.rawData andError:&tmp] autorelease])) {
                    
                    if (seal.sealImage) {
                        ret = [seal.sealImage retain];
                    }
                    else {
                        [RSI_error fillError:&tmp withCode:RSIErrorInvalidSeal andFailureReason:@"No seal image found."];
                    }
                }
                [tmp retain];
            }
        }
        
        [tmp autorelease];
        if (err) {
            *err = tmp;
        }
        return [ret autorelease];
    }
}

/*
 *  Retrieve a safe version of the seal image for display in the app.
 */
-(UIImage *) safeSealImageWithError:(NSError **) err
{
    @synchronized (self) {
        if (!creds || ![creds isValid]) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return nil;
        }
        
        NSError *tmp = nil;
        UIImage *retImg = nil;
        @autoreleasepool {
            NSData *dImage = [self originalSealImageWithError:&tmp];
            if (dImage) {
                UIImage *imgSeal = [UIImage imageWithData:dImage];
                if (imgSeal) {
                    //  - create a copy of the image by drawing it onto a second
                    //    bitmap to ensure that it is translated and the original
                    //    data is lost from the JPEG.
                    CGSize szImg = imgSeal.size;
                    UIGraphicsBeginImageContext(szImg);
                    [imgSeal drawInRect:CGRectMake(0.0f, 0.0f, szImg.width, szImg.height)];
                    [[UIColor colorWithWhite:1.0f alpha:0.1f] set];         //  add some variability where it won't be seen.
                    UIRectFrameUsingBlendMode(CGRectMake(0.0, 0.0f, szImg.width, szImg.height), kCGBlendModeNormal);
                    retImg = UIGraphicsGetImageFromCurrentImageContext();
                    [retImg retain];
                    UIGraphicsEndImageContext();
                }
                else {
                    [RSI_error fillError:&tmp withCode:RSIErrorInvalidSeal andFailureReason:@"The seal image is not valid."];
                }
            }
            [tmp retain];
        }
        
        [tmp autorelease];
        if (err) {
            *err = tmp;
        }
        
        return [retImg autorelease];
    }
}

/*
 *  Encrypt a local-only message with the seal.
 */
-(NSData *) encryptLocalOnlyMessage:(NSDictionary *) msg withError:(NSError **) err
{
    @synchronized (self) {
        if (!creds || ![creds isValid]) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return nil;
        }
        
        if (!sealData) {
            [RSI_error fillError:err withCode:RSIErrorInvalidSeal];
            return nil;
        }
        return [sealData encryptLocalOnlyMessage:msg withError:err];
    }
}

/*
 *  Encrypt a message with the highest level of authority.
 */
-(NSData *) encryptRoleBasedMessage:(NSDictionary *) msg withError:(NSError **) err
{
    @synchronized (self) {
        if (!creds || ![creds isValid]) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return nil;
        }
        
        if (!sealData) {
            [RSI_error fillError:err withCode:RSIErrorInvalidSeal];
            return nil;
        }
        return [sealData encryptRoleBasedMessage:msg withError:err];
    }
}

/*
 *  Pack and encrypt a message into an output image with the highest level of authority.
 */
-(NSData *) packRoleBasedMessage:(NSDictionary *) msg intoImage:(UIImage *) img withError:(NSError **) err
{
    @synchronized (self) {
        NSData *dEncryptedMessage = [self encryptRoleBasedMessage:msg withError:err];
        if (dEncryptedMessage) {
            return [RealSecureImage packedPNG:img andData:dEncryptedMessage andError:err];
        }
        return nil;
    }
}

/*
 *  Unpack the message, which is assumed to be stored in an image and then decrypt the result.
 */
-(NSDictionary *) unpackAndDecryptMessage:(NSData *) msg withError:(NSError **) err
{
    @synchronized (self) {
        NSData *dUnpacked = [RealSecureImage unpackData:msg withMaxLength:0 andError:err];
        if (!dUnpacked) {
            return nil;
        }
        return [self decryptMessage:dUnpacked withError:err];
    }
}

/*
 *  Hash the packed message quickly.
 */
-(NSString *) hashPackedMessage:(NSData *) msg
{
    @synchronized (self) {
        if (creds && [creds isValid] && sealData) {
            NSData *dUnpacked = [RealSecureImage unpackData:msg withMaxLength:[RSI_secure_props propertyHeaderLength] andError:nil];
            if (dUnpacked) {
                return [RSI_seal hashForEncryptedMessage:dUnpacked withError:nil];
            }
        }
        return nil;
    }
}

/*
 *  Decrypt a message encrypted with this seal.
 */
-(NSDictionary *) decryptMessage:(NSData *) dEncrypted withError:(NSError **) err
{
    @synchronized (self) {
        if (!creds || ![creds isValid]) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return nil;
        }
        
        if (!sealData) {
            [RSI_error fillError:err withCode:RSIErrorInvalidSeal];
            return nil;
        }
        return [sealData decryptMessage:dEncrypted withError:err];
    }
}

/*
 *  Export the seal 
 */
-(NSData *) exportWithPassword:(NSString *) pwd andError:(NSError **) err
{
    @synchronized (self) {
        //  - in order for this to work, we actually need to pull some of
        //    its content out of the on-disk archive that includes the
        //    image.
        if (!creds || ![creds isValid]) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return nil;
        }
        
        if (!location || !sealData) {
            [RSI_error fillError:err withCode:RSIErrorInvalidSeal];
            return nil;
        }

        NSError *tmp = nil;
        NSData *ret = nil;
        @synchronized (msDeletedSeals) {
            if ([self isDeleted]) {
                [RSI_error fillError:err withCode:RSIErrorInvalidSeal];
                return nil;
            }

            // - use an explicit autorelease pool so that the decrypted seal isn't
            //   retained in memory for very long.
            @autoreleasepool {
                RSI_securememory *sealArchive = nil;
                if ([creds readURL:location intoData:&sealArchive withError:&tmp]) {
                    RSI_seal *seal = [RSI_seal allocSealWithArchive:sealArchive.rawData andError:&tmp];
                    if (seal) {
                        ret = [seal exportSealWithPassword:pwd andError:&tmp];
                    }
                    [seal release];
                }
                [tmp retain];
                [ret retain];
            }
        }
        
        [tmp autorelease];
        if (err) {
            *err = tmp;
        }
        [ret autorelease];
        return ret;
    }
}

/*
 *  Set the snapshot invalidation behavior.
 */
-(BOOL) setInvalidateOnSnapshot:(BOOL) enabled withError:(NSError **) err
{
    @synchronized (self) {
        if (!creds || ![creds isValid]) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return NO;
        }
        
        @synchronized (msDeletedSeals) {
            if ([self isDeleted]) {
                [RSI_error fillError:err withCode:RSIErrorInvalidSeal];
                return NO;
            }

            if (![sealData setInvalidateOnSnapshot:enabled withError:err]) {
                return NO;
            }
            
            return [self synchronizeArchiveAndModifySealImage:NO withError:err];
        }
    }
}

/*
 *  Return the current snapshot invalidation behavior
 */
-(BOOL) isInvalidateOnSnapshotEnabledWithError:(NSError **) err
{
    @synchronized (self) {
        if (!creds || ![creds isValid]) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return NO;
        }
        return [sealData isInvalidateOnSnapshotEnabledWithError:err];        
    }
}

@end

/****************************
 RSISecureSeal (internal)
 ****************************/
@implementation RSISecureSeal (internal)

/*
 *  Initialize a secure seal with a basic seal.
 */
-(id) initWithCreds:(RSI_appkey *) akCreds atLocation:(NSURL *) loc withSeal:(RSI_seal *) s
{
    self = [super init];
    if (self) {
        creds    = [akCreds retain];
        location = [loc retain];
        sealData = [s retain];
    }
    return self;
}

/*
 *  Build a persistent seal in the vault.
 */
+(NSString *) createSealInVault:(NSURL *) url withAppKey:(RSI_appkey *) appkey andImage:(UIImage *) img andColor:(RSISecureSeal_Color_t) color andError:(NSError **) err
{
    NSString *sRet = nil;
    NSError *tmp   = nil;
    
    if (color < 0 || color >= RSSC_NUM_SEAL_COLORS) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
        return nil;
    }
 
    //  - operate in an autorelease pool to ensure that the archived seal data doesn't exist in RAM for very long.
    @autoreleasepool {
        //  - start by creating the basic seal.
        RSI_seal *seal = [RSI_seal allocNewSealWithImage:img andColorId:color andError:&tmp];
        if (seal) {
            //  - now attempt to save it.
            RSI_securememory *secSeal = [seal sealArchiveWithError:&tmp];
            NSURL *sealFile = [url URLByAppendingPathComponent:seal.sealId];
            if (secSeal &&
                [appkey writeData:secSeal.rawData toURL:sealFile withError:&tmp]) {
                
                //  - make sure that the seal's image isn't retained because it will
                //    be visible in memory
                [seal discardTemporaryImage];
                
                //  - it looks good, so return a seal id
                sRet = [[seal sealId] retain];
            }
            else {
                [RSI_seal deleteSealForId:[seal sealId] andError:nil];
            }
            [seal release];
        }        
        //  - to allow the error to escape this pool
        [tmp retain];
    }
    
    [tmp autorelease];
    if (err) {
        *err = tmp;
    }
    
    return [sRet autorelease];
}

/*
 *  Allocate an existing seal.
 */
+(RSISecureSeal *) sealInVault:(NSURL *) url forId:(NSString *) sealId withAppKey:(RSI_appkey *) appkey andError:(NSError **) err
{
    RSI_seal *seal = [RSI_seal allocExistingSealWithId:sealId andError:err];
    if (!seal) {
        return nil;
    }
    
    url = [url URLByAppendingPathComponent:sealId];
    RSISecureSeal *ssRet = [[RSISecureSeal alloc] initWithCreds:appkey atLocation:url withSeal:seal];
    [seal release];
    return [ssRet autorelease];
}

/*
 *  Import an existing seal into the vault.
 */
+(RSISecureSeal *) importSealIntoVault:(NSURL *) url withAppKey:(RSI_appkey *) appkey andSealData:(NSData *) sealData usingPassword:(NSString *) pwd withError:(NSError **) err
{
    RSISecureSeal *ssRet = nil;
    NSError *tmp = nil;
    
    //  - operate in an autorelease pool to ensure that the archived seal data doesn't exist in RAM for very long.
    @autoreleasepool {
        //  - start by creating the basic seal.
        RSI_seal *seal = [RSI_seal importSeal:sealData withPassword:pwd andError:&tmp];
        if (seal) {
            //  - now attempt to save it, but only if it isn't an existing producer seal because an import
            //    will destroy the original keys.
            NSURL *sealFile = [url URLByAppendingPathComponent:seal.sealId];
            if (![[NSFileManager defaultManager] fileExistsAtPath:[sealFile path]] || ![seal isProducerSeal]) {
                RSI_securememory *secSeal = [seal sealArchiveWithError:&tmp];
                if (secSeal &&
                    [appkey writeData:secSeal.rawData toURL:sealFile withError:&tmp]) {
                    
                    //  - make sure that the seal's image isn't retained because it will
                    //    be visible in memory
                    [seal discardTemporaryImage];
                    
                    //  - it looks good, so return a seal handle
                    ssRet = [[RSISecureSeal alloc] initWithCreds:appkey atLocation:sealFile withSeal:seal];
                    
                    //  - if it was previously deleted, make sure it can be used again.
                    @synchronized (msDeletedSeals) {
                        [msDeletedSeals removeObject:[seal sealId]];
                    }
                }
                else {
                    [RSI_seal deleteSealForId:[seal sealId] andError:nil];
                }
            }
            else {
                // - the seal already exists, but we should report the import was successful.
                ssRet = [[RSISecureSeal alloc] initWithCreds:appkey atLocation:sealFile withSeal:seal];
            }
        }
        //  - to allow the error to escape this pool
        [tmp retain];
    }
    
    [tmp autorelease];
    if (err) {
        *err = tmp;
    }
    
    return [ssRet autorelease];
}

/*
 *  Update the archive for the seal to ensure that any key/attribute changes are always reflected there.  
 *  - if the 'modifyImage' is passed, the seal image will also be changed to lose any data it contained,
 *    consequently making it unusable for hashing any longer.
 */
-(BOOL) synchronizeArchiveAndModifySealImage:(BOOL) modifyImage withError:(NSError **) err
{
    NSError *tmp = nil;
    BOOL    ret  = YES;
    
    //  - use an explicit autorelease pool so that objects don't remain long in memory.
    @autoreleasepool {
        RSI_appkey *appkey = (RSI_appkey *) creds;
        RSI_seal   *seal = nil;
        if (appkey && [appkey isValid]) {
            RSI_securememory *secMem = nil;
            RSI_securememory *newArchive = nil;
            if ([appkey readURL:location intoData:&secMem withError:&tmp] &&
                (seal = [[RSI_seal allocSealWithCurrentKeysAndArchive:secMem.rawData andError:&tmp] autorelease]) != nil) {
                
                //  - if we need to change the image, do so now.
                if (modifyImage) {
                    if (![seal invalidateSealImageWithError:&tmp]) {
                        ret = NO;
                    }
                }
                
                // - update the on-disk archive.
                if (ret &&
                    (!(newArchive = [seal sealArchiveWithError:&tmp]) ||
                     ![appkey writeData:newArchive.rawData toURL:location withError:&tmp])) {
                    ret = NO;
                }
            }
            else {
                ret = NO;
            }

        }else {
            [RSI_error fillError:&tmp withCode:RSIErrorStaleVaultCreds];
            ret = NO;
        }
        
        [tmp retain];
    }
    
    [tmp autorelease];
    if (err) {
        *err = tmp;
    }
    
    return ret;
}

/*
 *  Delete an existing seal from the vault.
 */
+(BOOL) deleteSealInVault:(NSURL *) url forId:(NSString *) sealId withAppKey:(RSI_appkey *) appkey andError:(NSError **) err
{
    NSError *tmp = nil;
    BOOL    ret = YES;
    
    if (![appkey isValid]) {
        [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
        return NO;
    }
    
    if (![RSI_seal sealExists:sealId withError:err]) {
        return NO;
    }
    
    //  - operate in an autorelease pool to ensure that the archived seal data doesn't exist in RAM for very long.
    @synchronized (msDeletedSeals) {
        @autoreleasepool {
            // - always delete the on-disk backup first because a seal missing from the keyring will
            //   be auto-recreated using the backup.
            NSURL *sealFile = [url URLByAppendingPathComponent:sealId];
            if ([[NSFileManager defaultManager] fileExistsAtPath:[sealFile path]]) {
                if (![[NSFileManager defaultManager] removeItemAtURL:sealFile error:&tmp]) {
                    ret = NO;
                    [RSI_error fillError:&tmp withCode:RSIErrorSealFileDeletionError andFailureReason:[tmp localizedDescription]];
                }
            }
            
            //  - then delete the seal itself.
            if (ret && ![RSI_seal deleteSealForId:sealId andError:&tmp]) {
                ret = NO;
            }
            
            // - when a seal is deleted successfully, save it so that we know it is defunct.
            if (ret) {
                [msDeletedSeals addObject:sealId];
            }
            
            [tmp retain];
        }
    }
    
    [tmp autorelease];
    if (err) {
        *err = tmp;
    }
    return ret;
}

/*
 *  Checks if this particular seal was deleted.
 *  - ASSUMES the object lock is held.
 *  - ASSUMES the deletion set lock is held.
 */
-(BOOL) isDeleted
{
    NSString *sid = [sealData sealId];
    if (!sid) {
        return YES;
    }
    
    if ([msDeletedSeals containsObject:sid]) {
        return YES;
    }
    return NO;
}

@end
