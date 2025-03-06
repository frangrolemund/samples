//
//  RSI_appkey.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 12/7/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import <CommonCrypto/CommonDigest.h>
#import "RSI_appkey.h"
#import "RSI_error.h"
#import "RSI_symcrypt.h"
#import "RSI_common.h"
#import "RSI_secure_props.h"

//  - static variables
static NSString *APP_PASSWORD_TAG = @"app.pwd";
static NSString *APP_KEY          = @"app.key";
static NSString *SALT_KEY         = @"gs.key";

//  - forward declarations
@interface RSI_appkey (internal)
-(BOOL) validatePasswordInKeychain:(RSI_securememory *) hash withError:(NSError **) err;
+(NSMutableDictionary *) buildPasswordDictionary;
-(BOOL) createNewKeyWithHash:(RSI_securememory *) pHash withError:(NSError **) err;
-(BOOL) authenticateWithHash:(RSI_securememory *) pHash withError:(NSError **) err;
-(BOOL) addPasswordToKeychain:(RSI_securememory *) pHash withError:(NSError **) err;
-(BOOL) createVaultSaltWithError:(NSError **) err;
+(BOOL) deletePasswordFromKeychainWithError:(NSError **) err;
-(RSI_SHA1 *) safeSaltedHash:(NSString *) source withError:(NSError **) err;
@end

/**************************
 RSI_appkey
 **************************/
@implementation RSI_appkey
/*
 *  Object attributes.
 */
{
    BOOL            valid;
    time_t          contextMade;
    int             keyRefCt;
    RSI_symcrypt    *cachedKey;
    RSI_symcrypt    *safeSalt;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        valid       = YES;
        keyRefCt    = 0;
        contextMade = 0;
        cachedKey   = nil;
        safeSalt    = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [cachedKey release];
    cachedKey = nil;
    
    [safeSalt release];
    safeSalt = nil;
    
    [super dealloc];
}

/*
 *  Determine if an application key exists
 */
+(BOOL) isInstalled
{
    //  - since this symmetric key is essential to the security model, ensure
    //    all temporary objects are completely gone.
    @autoreleasepool {
        RSI_symcrypt *symk = [RSI_symcrypt allocExistingKeyForType:CSSM_ALGID_SYM_GLOBAL andTag:APP_KEY withError:nil];
        if (symk) {
            [symk release];
            return YES;
        }
        return NO;
    }
}

/*
 *  Return the length of a safe salted string.
 */
+(NSUInteger) lengthOfSafeSaltedStringAsHex:(BOOL) asHex
{
    if (asHex) {
        return [RSI_SHA1 SHA_LEN] * 2;
    }
    else {
        return [RSI_SHA1 SHA_B64_STRING_LEN];
    }
}

/*
 *  The indication whether these credentials are usable is whether
 *  the location is populated.  Credential invalidation allows an
 *  app key to be safely shared without concern for credentials being
 *  used past their expiration.
 */
-(void) invalidateCredentials
{
    @synchronized (self) {
        valid = NO;
    }
}

/*
 *  Returns whether the credentials are still good.
 */
-(BOOL) isValid
{
    @synchronized (self) {
        return valid;
    }
}

/*
 *  Delete the key and its associated password.
 */
-(BOOL) destroyAllKeyDataWithError:(NSError **) err
{
    @synchronized (self) {
        if (!valid) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return NO;
        }
     
        [self invalidateCredentials];
        return [RSI_appkey destroyKeychainContentsWithError:err];
    }
}

/*
 *  Create a new key, which assumes the old one doesn't exist.
 */
-(BOOL) createNewKeyWithPassword:(NSString *) password withError:(NSError **) err
{
    @synchronized (self) {
        if (!valid) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return NO;
        }
        
        //  There are a lot of autorelease objects created, so I'll manage their
        //  expansion here with a dedicated pool.
        BOOL ret = YES;
        NSError *tmp = nil;
        @autoreleasepool {
            //  - create a hash, which is the only thing we'll store
            RSI_securememory *pHash = [RSI_symcrypt hashFromPassword:password];
            if (pHash) {
                ret = [self createNewKeyWithHash:pHash withError:&tmp];
            }
            else {
                [RSI_error fillError:&tmp withCode:RSIErrorAuthFailed andFailureReason:@"Hash not generated."];
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
}

/*
 *  Validate the user's credentials.
 */
-(BOOL) authenticateWithPassword:(NSString *) password withError:(NSError **) err
{
    @synchronized (self) {
        if (!valid) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return NO;
        }
        
        //  There are a lot of autorelease objects created, so I'll manage their
        //  expansion here with a dedicated pool.
        BOOL ret = YES;
        NSError *tmp = nil;
        @autoreleasepool {
            //  - create a hash, which is the only thing we'll store
            RSI_securememory *pHash = [RSI_symcrypt hashFromPassword:password];
            if (pHash) {
                //  - to prevent the error code from disappearing, we need to
                //    retain it one more time before leaving this pool's scope.
                ret = [self authenticateWithHash:pHash withError:&tmp];
            }
            else {
                [RSI_error fillError:&tmp withCode:RSIErrorAuthFailed andFailureReason:@"Hash not generated."];
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
}

/*
 *  Change the password for the application key.
 */
-(BOOL) changePasswordFrom:(NSString *) password toNewPassword:(NSString *) newpass withError:(NSError **) err
{
    @synchronized (self) {
        if (!valid) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return NO;
        }
        
        //  There are a lot of autorelease objects created, so I'll manage their
        //  expansion here with a dedicated pool.
        BOOL ret = YES;
        NSError *tmp = nil;
        @autoreleasepool {
            RSI_securememory *pHash = [RSI_symcrypt hashFromPassword:password];
            RSI_securememory *pNewHash = [RSI_symcrypt hashFromPassword:newpass];
            
            //  - first validate the existing password
            if (pHash && pNewHash) {
                if ([self validatePasswordInKeychain:pHash withError:&tmp]) {
                    //  - start by finding the existing password entry and its attributes
                    NSMutableDictionary *mdPwdQuery = [RSI_appkey buildPasswordDictionary];
                    [mdPwdQuery setObject:kSecMatchLimitOne forKey:kSecMatchLimit];
                    [mdPwdQuery setObject:[NSNumber numberWithBool:YES] forKey:kSecReturnAttributes];
                    
                    NSDictionary *dictCurrent = nil;
                    OSStatus status = 0;
                    [RSI_common RDLOCK_KEYCHAIN];
                    status = SecItemCopyMatching((CFDictionaryRef) mdPwdQuery, (CFTypeRef *) &dictCurrent);
                    [RSI_common UNLOCK_KEYCHAIN];
                    if (status == errSecSuccess) {
                        //  - ensure that the query class is completely up to date.
                        mdPwdQuery = [NSMutableDictionary dictionaryWithDictionary:dictCurrent];
                        [mdPwdQuery setObject:kSecClassGenericPassword forKey:kSecClass];
                        
                        //  - now update the entry with the given attributes
                        NSMutableDictionary *mdToChange = [RSI_appkey buildPasswordDictionary];
                        [mdToChange removeObjectForKey:kSecClass];          //  not used for updates
                        [mdToChange setObject:pNewHash.rawData forKey:kSecValueData];
                        [RSI_common WRLOCK_KEYCHAIN];
                        status = SecItemUpdate((CFDictionaryRef) mdPwdQuery, (CFDictionaryRef) mdToChange);
                        [RSI_common UNLOCK_KEYCHAIN];
                        if (status != errSecSuccess) {
                            [RSI_error fillError:&tmp withCode:RSIErrorKeychainFailure andKeychainStatus:status];
                            ret = NO;
                        }
                    }
                    else {
                        [RSI_error fillError:&tmp withCode:RSIErrorKeychainFailure andKeychainStatus:status];
                        ret = NO;
                    }
                    
                    // - SecItemCopyMatching allocates its return value.
                    if (dictCurrent) {
                        CFRelease((CFTypeRef *) dictCurrent);
                    }
                }
                else {
                    ret = NO;
                }
            }
            else {
                [RSI_error fillError:&tmp withCode:RSIErrorAuthFailed andFailureReason:@"Hash not generated."];
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
}

/*
 *  Because loading the key from the chain can potentially consume a lot
 *  of time if it is done for every one of a large number of requests, 
 *  a key context makes the data survive longer.  
 */
-(BOOL) startKeyContextWithError:(NSError **) err
{
    @synchronized (self) {
        if (!valid) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return NO;
        }
        
        keyRefCt++;
        if (cachedKey) {
            //  - if the context is used for too long, delete it
            //    and start over.  That could indicate either a
            //    long process or a leaked reference.
            if (time(NULL) - contextMade < 5) {
                return YES;
            }
            
            [cachedKey release];
            cachedKey = nil;
        }
        
        cachedKey = [RSI_symcrypt allocExistingKeyForType:CSSM_ALGID_SYM_GLOBAL andTag:APP_KEY withError:err];
        if (!cachedKey) {
            keyRefCt--;
            return NO;
        }
        
        contextMade = time(NULL);
        return YES;
    }
}

/*
 *  Complete a key context.
 */
-(BOOL) endKeyContextWithError:(NSError **) err
{
    @synchronized (self) {
        if (!valid) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return NO;
        }
        
        keyRefCt--;
        if (keyRefCt <= 0) {
            [cachedKey release];
            cachedKey = nil;
            contextMade = 0;
            keyRefCt = 0;
        }
        return YES;
    }
}

/*
 *  Delete all keychain elements related to the application key.
 */
+(BOOL) destroyKeychainContentsWithError:(NSError **) err
{
    if (![RSI_appkey deletePasswordFromKeychainWithError:err]) {
        return NO;
    }
    
    [RSI_symcrypt deleteKeyWithType:CSSM_ALGID_SYM_GLOBAL andTag:APP_KEY withError:nil];
    [RSI_symcrypt deleteKeyWithType:CSSM_ALGID_SALT andTag:SALT_KEY withError:nil];
    return YES;
}

/*
 *  Using the application key, encrypt and write data to disk.
 */
-(BOOL) writeData:(NSData *) sourceData toURL:(NSURL *) url withError:(NSError **) err
{
    @synchronized (self) {
        BOOL ret = YES;
        if (!valid) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return NO;
        }
        
        if (![self startKeyContextWithError:err]) {
            return NO;
        }
        
        NSError *tmp = nil;
        @autoreleasepool {
            NSData *dEncrypted = [RSI_secure_props encryptWithData:sourceData forType:RSI_SECPROP_APP andVersion:RSI_SECURE_VERSION usingKey:cachedKey withError:&tmp];
            if (dEncrypted) {
                if (![dEncrypted writeToURL:url atomically:YES]) {
                    ret = NO;
                    [RSI_error fillError:&tmp withCode:RSIErrorFailedToWriteEncrypted];
                }
            }
            else {
                ret = NO;
            }
            
            if (![self endKeyContextWithError:ret ? &tmp : nil]) {
                ret = NO;
            }
            
            //  - to allow it to survive the end of the autorelease pool.
            [tmp retain];
        }
        
        [tmp autorelease];
        if (err) {
            *err = tmp;
        }
        
        return ret;
    }
}

/*
 *  Using the application key, read and decrypt data from disk.
 */
-(BOOL) readURL:(NSURL *) url intoData:(RSI_securememory **) destData withError:(NSError **) err
{
    @synchronized (self) {
        BOOL ret = YES;
        RSI_securememory *smRet = nil;
        
        if (!valid) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return NO;
        }
        
        if (![self startKeyContextWithError:err]) {
            return NO;
        }
        
        NSError *tmp = nil;
        @autoreleasepool {
            NSMutableData *mdEncrypted = [NSMutableData dataWithContentsOfURL:url];
            if (mdEncrypted) {
                smRet = [RSI_secure_props decryptIntoData:mdEncrypted forType:RSI_SECPROP_APP andVersion:RSI_SECURE_VERSION usingKey:cachedKey withError:&tmp];
                [smRet retain];
            }
            else {
                [RSI_error fillError:&tmp withCode:RSIErrorFailedToReadEncrypted];
                ret = NO;
            }
            
            if (![self endKeyContextWithError:ret ? &tmp : nil]) {
                ret = NO;
            }
            
            [tmp retain];
        }
        
        [tmp autorelease];
        if (err) {
            *err = tmp;
        }
        
        [smRet autorelease];
        if (destData) {
            *destData = smRet;
        }
        
        return ret;
    }
}

/*
 *  There are some strings in the app that I want to make unique per vault instance so that
 *  they can be persisted without becoming predictable between different devices.   The
 *  seal-id is one example.  This method will return a salted version of the same string
 *  using a vault-unique value.
 */
-(NSString *) safeSaltedStringAsHex:(NSString *) source withError:(NSError **) err
{
    RSI_SHA1 *hash = [self safeSaltedHash:source withError:err];
    if (!hash) {
        return nil;
    }
    
    // - to improve economy even further, we're using base-64 for this, which saves us 5 bytes
    //   over the hex version.
    return [hash stringHash];
}

/*
 *  There are some strings in the app that I want to make unique per vault instance so that
 *  they can be persisted without becoming predictable between different devices.   The
 *  seal-id is one example.  This method will return a salted version of the same string
 *  using a vault-unique value.
 */
-(NSString *) safeSaltedStringAsBase64:(NSString *) source withError:(NSError **) err
{
    RSI_SHA1 *hash = [self safeSaltedHash:source withError:err];
    if (!hash) {
        return nil;
    }
    
    // - to improve economy even further, we're using base-64 for this, which saves us 5 bytes
    //   over the hex version.
    return [hash base64StringHash];
}

@end


/**************************
 RSI_appkey  (internal)
 **************************/
@implementation RSI_appkey (internal)

/*
 *  Check if the password matches the keychain value.
 */
-(BOOL) validatePasswordInKeychain:(RSI_securememory *) hash withError:(NSError **) err
{
    NSMutableDictionary *mdPwd = [RSI_appkey buildPasswordDictionary];
    [mdPwd setObject:kSecMatchLimitOne forKey:kSecMatchLimit];
    
    NSData *dPwd = nil;
    [mdPwd setObject:[NSNumber numberWithBool:YES] forKey:kSecReturnData];
    [RSI_common RDLOCK_KEYCHAIN];
    OSStatus status = SecItemCopyMatching((CFDictionaryRef) mdPwd, (CFTypeRef *) &dPwd);
    [RSI_common UNLOCK_KEYCHAIN];
    if (status == 0) {
        if (dPwd) {
            BOOL isGood = [hash.rawData isEqualToData:dPwd];
            CFRelease((CFTypeRef *) dPwd);                      // - SecItemCopyMatching allocates its return value.
            if (!isGood) {
                [RSI_error fillError:err withCode:RSIErrorAuthFailed];
            }
            return isGood;
        }
        [RSI_error fillError:err withCode:RSIErrorAuthFailed];
    }
    else if (status == errSecItemNotFound) {
        [RSI_error fillError:err withCode:RSIErrorKeyNotFound];
    }
    else {
        [RSI_error fillError:err withCode:RSIErrorKeychainFailure andKeychainStatus:status];
    }
    return NO;
}

/*
 *  Build an appropriate dictionary for accessing the app password
 */
+(NSMutableDictionary *) buildPasswordDictionary
{
    NSMutableDictionary *mdPwd = [NSMutableDictionary dictionary];
    [mdPwd setObject:kSecClassGenericPassword forKey:kSecClass];
    NSData *pTag = [APP_PASSWORD_TAG dataUsingEncoding:NSUTF8StringEncoding];
    [mdPwd setObject:pTag forKey:kSecAttrGeneric];
    return mdPwd;
}

/*
 *  Attempt to create a new key with the given hash as a password.
 */
-(BOOL) createNewKeyWithHash:(RSI_securememory *) pHash withError:(NSError **) err
{
    RSI_symcrypt *appKey = [RSI_symcrypt allocNewKeyForLabel:APP_KEY andType:CSSM_ALGID_SYM_GLOBAL andTag:APP_KEY withError:err];
    if (!appKey) {
        return NO;
    }
    [appKey release];
    
    //  - and finally add the password to the keychain
    if (![self addPasswordToKeychain:pHash withError:err] ||
        ![self createVaultSaltWithError:err]) {
        NSLog(@"RSI: Failed to assign the application password.");
        if (![RSI_symcrypt deleteKeyWithType:CSSM_ALGID_SYM_GLOBAL andTag:APP_KEY withError:nil]) {
            NSLog(@"RSI: Failed to delete the application security key.");
        }
        return NO;
    }
    return YES;    
}

/*
 *  The password hash was already created, so use it for authentication.
 */
-(BOOL) authenticateWithHash:(RSI_securememory *) pHash withError:(NSError **) err
{
    NSError *errTmp = nil;
    RSI_symcrypt *appKey = nil;
    
    //  - first check the keychain, which acts as a safe cache of the credentials
    //  - when it exists, this should be a very quick test.
    if ([self validatePasswordInKeychain:pHash withError:&errTmp]) {
        appKey = [RSI_symcrypt allocExistingKeyForType:CSSM_ALGID_SYM_GLOBAL andTag:APP_KEY withError:err];
        if (appKey) {
            [appKey release];
            safeSalt = [RSI_symcrypt allocExistingKeyForType:CSSM_ALGID_SALT andTag:SALT_KEY withError:err];
            if (safeSalt) {
                return YES;
            }
        }
    }
    
    //  - if the password didn't match the keychain, rule out everything except it not
    //    being there
    if (errTmp.code != RSIErrorKeyNotFound) {
        if (err) {
            *err = errTmp;
        }
        return NO;
    }
    
    //  - Just in case, we need to see if an application symmetric key exists, which
    //    means the password is gone, but the key is there, which in theory could be some sort of
    //    hack to gain access.  Sadly, that should invalidate the vault to be safe.  If they
    //    backed up to iTunes, this should not be an issue.
    appKey = [RSI_symcrypt allocExistingKeyForType:CSSM_ALGID_SYM_GLOBAL andTag:APP_KEY withError:nil];
    if (appKey) {
        [appKey release];
        [RSI_error fillError:err withCode:RSIErrorPartialAppKey andFailureReason:@"Missing password entry in keychain."];
        return NO;
    }
    
    //  - create a new key
    [RSI_appkey destroyKeychainContentsWithError:nil];
    return [self createNewKeyWithHash:pHash withError:err];
}


/*
 *  Add the hashed password to the keychain for future use.
 */
-(BOOL) addPasswordToKeychain:(RSI_securememory *) pHash withError:(NSError **) err
{
    if (![RSI_appkey deletePasswordFromKeychainWithError:err]) {
        return NO;
    }
    
    NSMutableDictionary *mdPwd = [RSI_appkey buildPasswordDictionary];
    [mdPwd setObject:pHash.rawData forKey:kSecValueData];
    
    OSStatus status = 0;
    [RSI_common WRLOCK_KEYCHAIN];
    status = SecItemAdd((CFDictionaryRef) mdPwd, NULL);
    [RSI_common UNLOCK_KEYCHAIN];
    if (status != errSecSuccess) {
        [RSI_error fillError:err withCode:RSIErrorKeychainFailure andKeychainStatus:status];
        return NO;
    }
    
    return YES;
}

/*
 *  Create the salt used for safe securing the vault.
 */
-(BOOL) createVaultSaltWithError:(NSError **) err
{
    if (!valid) {
        [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
        return NO;
    }
    safeSalt = [RSI_symcrypt allocNewKeyForLabel:SALT_KEY andType:CSSM_ALGID_SALT andTag:SALT_KEY withError:err];
    return (safeSalt ? YES : NO);
}

/*
 *  Delete the keychain instance of the password.
 */
+(BOOL) deletePasswordFromKeychainWithError:(NSError **) err
{
    NSDictionary *dict = [RSI_appkey buildPasswordDictionary];
    [RSI_common WRLOCK_KEYCHAIN];
    OSStatus status = SecItemDelete((CFDictionaryRef) dict);
    [RSI_common UNLOCK_KEYCHAIN];
    if (status != errSecSuccess &&
        status != errSecItemNotFound) {
        [RSI_error fillError:err withCode:RSIErrorKeychainFailure andKeychainStatus:status];
        return NO;
    }
    return YES;
}

/*
 *  Return a SHA hash for managing safe salting.
 */
-(RSI_SHA1 *) safeSaltedHash:(NSString *) source withError:(NSError **) err
{
    @synchronized (self) {
        if (!source) {
            [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
            return nil;
        }
        if (!valid || !safeSalt) {
            [RSI_error fillError:err withCode:RSIErrorStaleVaultCreds];
            return nil;
        }
        
        //  HASHING-NOTE:
        //      - safe salted strings are only used locally so economy here is best.  We'll
        //        only use SHA-1 for this purpose.
        RSI_SHA1 *hash = [[[RSI_SHA1 alloc] init] autorelease];
        [hash update:[source UTF8String] withLength:[source length]];
        static const char *extra = "RSI_appkey:1104";
        [hash update:extra withLength:strlen(extra)];
        [hash updateWithData:safeSalt.key.rawData];
        
        return hash;
    }
}
@end

