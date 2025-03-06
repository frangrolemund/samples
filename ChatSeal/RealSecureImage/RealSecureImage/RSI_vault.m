//
//  RSI_vault.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 1/31/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "RSI_vault.h"
#import "RSI_error.h"
#import "RSI_seal.h"
#import "RSI_appkey.h"
#import "RSI_secureseal.h"
#import "RSI_common.h"

//  - constants
static NSString *RSI_VAULT_TEST_KEY = @"rsi-vver";

//  - local variables
static NSObject       *synchVault     = nil;
static NSURL          *vaultDirectory = nil;
static RSI_appkey     *appkey         = nil;
static NSMutableArray *maSealList     = nil;

//  - forward declarations
@interface RSI_vault (internal)
+(NSURL *) vaultDirectoryWithError:(NSError **) err;
+(NSURL *) vaultExternalFilesDirectoryWithError:(NSError **) err;
+(BOOL) validateVaultContentsWithError:(NSError **) err;
+(BOOL) basicHasVault;
+(RSI_appkey *) currentAppkey;
@end

/*****************************
 RSI_vault
 *****************************/
@implementation RSI_vault
/*
 *  Initialize the vault module.
 */
+(void) initialize
{
    // - this object is used to synchronize changes to the other
    //   local variables only.
    synchVault = [[NSObject alloc] init];
    
    // - the vault directory needs only to be generated once.
    NSError *tmp = nil;
    NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:&tmp];
    if (u) {
        vaultDirectory = [[u URLByAppendingPathComponent:@"vault"] retain];
    }
    else {
        NSLog(@"RSI: Failed to construct a valid vault directory name.  %@", [tmp localizedDescription]);
    }
}

/*
 *  Return a secure hash salted with the application key.
 */
+(NSString *) safeSaltedStringAsHex:(NSString *) source withError:(NSError **) err
{
    // - don't use the big lock because the app key is itself thread-safe.
    RSI_appkey *akCur = [RSI_vault currentAppkey];
    if (akCur) {
        return [akCur safeSaltedStringAsHex:source withError:err];
    }
    else {
        [RSI_error fillError: err withCode:RSIErrorAuthRequired];
        return nil;
    }
}

/*
 *  Return a secure hash salted with the application key.
 */
+(NSString *) safeSaltedStringAsBase64:(NSString *) source withError:(NSError **) err
{
    // - don't use the big lock because the app key is itself thread-safe.
    RSI_appkey *akCur = [RSI_vault currentAppkey];
    if (akCur) {
        return [akCur safeSaltedStringAsBase64:source withError:err];
    }
    else {
        [RSI_error fillError: err withCode:RSIErrorAuthRequired];
        return nil;
    }
}

/*
 *  Return the length of a safe salted string.
 */
+(NSUInteger) lengthOfSafeSaltedStringAsHex:(BOOL) asHex
{
    return [RSI_appkey lengthOfSafeSaltedStringAsHex:asHex];
}

/*
 *  If the vault is open, that is authenticated, close it from further access.
 */
+(void) closeVault
{
    @synchronized (synchVault) {
        //  - no more need for computation if the vault won't
        //    allow us to create seals.
        [RSI_seal stopAsyncCompute];
        
        //  - make sure that the credentials are invalidated
        //    in case there are outstanding references inside
        //    RSISecureSeal instances.
        [appkey invalidateCredentials];
        
        [maSealList release];
        maSealList = nil;
        
        [appkey release];
        appkey = nil;        
    }
}

/*
 *  Destroys an existing vault
 */
+(BOOL) destroyVaultWithError:(NSError **) err
{
    @synchronized (synchVault) {
        [RSI_vault closeVault];
        
        NSURL *u = [RSI_vault vaultDirectoryWithError:err];
        if (!u) {
            return NO;
        }
        
        if (![RSI_seal deleteAllSealsWithError:err]) {
            return NO;
        }
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:[u path]]) {
            NSError *tmp = nil;
            if (![[NSFileManager defaultManager] removeItemAtURL:u error:&tmp]) {
                [RSI_error fillError:err withCode:RSIErrorCouldNotAccessVault andFailureReason:[tmp localizedDescription]];
                return NO;
            }
        }
        
        return [RSI_appkey destroyKeychainContentsWithError:err];
    }
}

/*
 *  Determines if a seal vault exists on the device.
 */
+(BOOL) hasVault
{
    //  NOTE:  This method is a potentially VERY DANGEROUS test to make because a lot of
    //         decisions about vault behavior are made with this flag.   For example, if I don't
    //         find a vault, I will likely create one.  The danger is that the flag is wrong because
    //         of all the factors that contribute to it.  The system becomes very unpredictable in
    //         low storage scenarios.
    //         Therefore, I'm going to do some additional tests to really be sure when I believe the
    //         vault isn't there.
    
    @synchronized (synchVault) {
        // - The basic test, which means the directory and the app key are available.  This should remain
        //   fast for existing vaults.
        if ([RSI_vault basicHasVault]) {
            return YES;
        }
        
        // - It is possible that a low storage scenario is preventing us from accessing the keychain or even
        //   enumerating the disk, so I need to be very sure that essential features still work.
        // - The twist here is is if they do not work, we are going to assume that this test cannot be made
        //   safely and assume the vault is there.
        NSMutableData *mdTestData = [NSMutableData dataWithLength:128];
        if (SecRandomCopyBytes(kSecRandomDefault, mdTestData.length, (uint8_t *) mdTestData.mutableBytes) != 0) {
            // - failure, assume the vault exists for safety.
            return YES;
        }
        
        NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
        if (!u) {
            // - failure, assume the vault exists for safety.
            return YES;
        }
        
        u = [u URLByAppendingPathComponent:RSI_VAULT_TEST_KEY];
        if (![mdTestData writeToURL:u atomically:YES]) {
            // - failure, assume the vault exists for safety.
            return YES;
        }
        
        NSData *dRead = [NSData dataWithContentsOfURL:u];
        if (!dRead || ![dRead isEqualToData:mdTestData]) {
            // - failure, assume the vault exists for safety.
            return YES;
        }
        [[NSFileManager defaultManager] removeItemAtURL:u error:nil];
        
        [RSI_symcrypt deleteKeyWithType:CSSM_ALGID_VAULT_VERIFY andTag:RSI_VAULT_TEST_KEY withError:nil];
        RSI_symcrypt *sk = [[RSI_symcrypt allocNewKeyForLabel:RSI_VAULT_TEST_KEY andType:CSSM_ALGID_VAULT_VERIFY andTag:RSI_VAULT_TEST_KEY withError:nil] autorelease];
        if (!sk) {
            // - failure, assume the vault exists for safety.
            return YES;
        }
        RSI_symcrypt *skExist = [[RSI_symcrypt allocExistingKeyForType:CSSM_ALGID_VAULT_VERIFY andTag:RSI_VAULT_TEST_KEY withError:nil] autorelease];
        if (!skExist || ![sk.key.rawData isEqualToData:skExist.key.rawData]) {
            // - failure, assume the vault exists for safety.
            return YES;
        }
        [RSI_symcrypt deleteKeyWithType:CSSM_ALGID_VAULT_VERIFY andTag:RSI_VAULT_TEST_KEY withError:nil];
        
        // - the last test is the basic one again, just to be sure the first failure wasn't a fluke.
        return [RSI_vault basicHasVault];
    }
}

/*
 *  Authenticate with an existing vault.
 */
+(BOOL) openVaultWithPassword:(NSString *) pwd andError:(NSError **) err
{
    @synchronized (synchVault) {
        [RSI_vault closeVault];
        if (!pwd || [pwd length] < 1) {
            [RSI_error fillError:err withCode:RSIErrorAuthFailed];
            return NO;
        }
        
        if (![RSI_appkey isInstalled]) {
            [RSI_error fillError:err withCode:RSIErrorAuthFailed andFailureReason:@"Vault does not exist."];
            return NO;
        }
        
        appkey = [[RSI_appkey alloc] init];
        if (![appkey authenticateWithPassword:pwd withError:err]) {
            [appkey release];
            appkey = nil;
            return NO;
        }
        
        if (![RSI_vault validateVaultContentsWithError:err]) {
            return NO;
        }
        
        [RSI_seal prepareForSealGeneration];
        return YES;
    }
}

/*
 *  Creates a new vault, overwriting any existing one.
 */
+(BOOL) initializeVaultWithPassword:(NSString *) pwd andError:(NSError **) err
{
    @synchronized (synchVault) {
        //  - vaults must have a password
        if (!pwd || [pwd length] < 1) {
            [RSI_error fillError:err withCode:RSIErrorInvalidArgument];
            return NO;
        }
        
        //  - make sure any existing vault is completely gone first.
        if (![RSI_vault destroyVaultWithError:err]) {
            return NO;
        }
        
        //  - create the new vault directory.
        NSURL *u = [RSI_vault vaultDirectoryWithError:err];
        if (!u) {
            return NO;
        }
        
        NSError *tmp = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:[u path] withIntermediateDirectories:YES attributes:nil error:&tmp]) {
            [RSI_error fillError:err withCode:RSIErrorCouldNotAccessVault andFailureReason:[tmp localizedDescription]];
            return NO;
        }
        
        // - we can use the creation method because the vault was completely
        //   destroyed above.  There is no need to do the costly lookup.
        appkey = [[RSI_appkey alloc] init];
        if (![appkey createNewKeyWithPassword:pwd withError:err]) {
            [appkey release];
            appkey = nil;
            return NO;
        }
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:[u path]]) {
            [RSI_error fillError:err withCode:RSIErrorCouldNotAccessVault andFailureReason:@"Creation failed."];
            return NO;
        }
        
        [RSI_seal prepareForSealGeneration];
        return YES;
    }
}

/*
 *  Modify the vault's password.
 */
+(BOOL) changeVaultPassword:(NSString *) pwdFrom toPassword:(NSString *) pwdTo andError:(NSError **) err
{
    @synchronized (synchVault) {
        if (![RSI_vault openVaultWithPassword:pwdFrom andError:err]) {
            return NO;
        }
        
        if (![appkey changePasswordFrom:pwdFrom toNewPassword:pwdTo withError:err]) {
            [RSI_vault closeVault];
            return NO;
        }
        return YES;
    }
}

/*
 *  Determines if the user has been authenticated.
 */
+(BOOL) isOpen
{
    @synchronized (synchVault) {
        if (appkey) {
            return YES;
        }
        return NO;
    }
}

/*
 *  Create a new persistent seal from the supplied image and return it to the caller.
 */
+(NSString *) createSealWithImage:(UIImage *) img andColor:(RSISecureSeal_Color_t) color andError:(NSError **) err
{
    @synchronized (synchVault) {
        if (![RSI_vault isOpen]) {
            [RSI_error fillError:err withCode:RSIErrorAuthRequired];
            return nil;
        }
        
        NSURL *u = [RSI_vault vaultDirectoryWithError:err];
        if (!u) {
            return nil;
        }
        
        NSString *sNew = [RSISecureSeal createSealInVault:u withAppKey:appkey andImage:img andColor:color andError:err];
        if (sNew) {
            if (maSealList) {
                [maSealList addObject:sNew];
            }
            else {
                [RSI_vault availableSealsWithError:nil];
            }
        }
        return sNew;
    }
}

/*
 *  Import an existing seal into the vault.
 */
+(RSISecureSeal *) importSeal:(NSData *) sealData usingPassword:(NSString *) pwd withError:(NSError **) err
{
    @synchronized (synchVault) {
        if (![RSI_vault isOpen]) {
            [RSI_error fillError:err withCode:RSIErrorAuthRequired];
            return nil;
        }
        
        NSURL *u = [RSI_vault vaultDirectoryWithError:err];
        if (!u) {
            return nil;
        }
        
        RSISecureSeal *ssImported = [RSISecureSeal importSealIntoVault:u withAppKey:appkey andSealData:sealData usingPassword:pwd withError:err];
        if (ssImported) {
            if (maSealList) {
                if (![maSealList containsObject:[ssImported sealId]]) {
                    [maSealList addObject:[ssImported sealId]];
                }
            }
            else {
                [RSI_vault availableSealsWithError:nil];
            }
        }
        return ssImported;
    }
}

/*
 *  Return a list of all the installed seals.
 */
+(NSArray *) availableSealsWithError:(NSError **) err
{
    @synchronized (synchVault) {
        if (![RSI_vault isOpen]) {
            [RSI_error fillError:err withCode:RSIErrorAuthRequired];
            return nil;
        }
        
        if (!maSealList) {
            NSArray *curSeals = [RSI_seal availableSealsWithError:err];
            if (curSeals) {
                maSealList = [[NSMutableArray alloc] initWithArray:curSeals];
            }
        }
        
        return [NSArray arrayWithArray:maSealList];        
    }
}

/*
 *  Return the list of safe seals.
 */
+(NSDictionary *) safeSealIndexWithError:(NSError **) err
{
    // - no need to do broad synchronization here because all of the
    //   dependent codepaths are thread-safe.
    NSArray *arrSeals = [RSI_vault availableSealsWithError:err];
    if (!arrSeals) {
        return nil;
    }
    
    NSMutableDictionary *mdRet = [NSMutableDictionary dictionary];
    RSI_appkey *akCur          = [RSI_vault currentAppkey];
    for (NSString *sid in arrSeals) {
        NSString *ssid = [akCur safeSaltedStringAsHex:sid withError:err];
        if (!ssid) {
            return nil;
        }
        [mdRet setObject:sid forKey:ssid];
    }
    return mdRet;
}

/*
 *  Allocate a handle to an existing seal from the vault.
 */
+(RSISecureSeal *) sealForId:(NSString *) sealId andError:(NSError **) err
{
    @synchronized (synchVault) {
        if (![RSI_vault isOpen]) {
            [RSI_error fillError:err withCode:RSIErrorAuthRequired];
            return nil;
        }
        
        NSURL *u = [RSI_vault vaultDirectoryWithError:err];
        if (!u) {
            return nil;
        }
        
        return [RSISecureSeal sealInVault:u forId:sealId withAppKey:appkey andError:err];
    }
}

/*
 *  A simple test to see if the seal exists in the vault.
 */
+(BOOL) sealExists:(NSString *) sealId withError:(NSError **) err
{
    @synchronized (synchVault) {
        if (!maSealList) {
            if (![RSI_vault availableSealsWithError:err]) {
                return NO;
            }
        }
        
        for (NSUInteger i = 0; i < [maSealList count]; i++) {
            NSString *sidCompare = [maSealList objectAtIndex:i];
            if ([sidCompare isEqualToString:sealId]) {
                return YES;
            }
        }
        
        [RSI_error fillError:err withCode:RSIErrorInvalidSeal];
        return NO;
    }
}

/*
 *  Write data securely to the vault.
 */
+(BOOL) writeData:(NSData *) sourceData toFile:(NSString *) fName withError:(NSError **) err;
{
    // - no need for broad locking because the dependent codepaths are thread safe.
    NSURL *uTarget = [RSI_vault absoluteURLForFile:fName withError:err];
    if (!uTarget) {
        return NO;
    }
    
    return [RSI_vault writeData:sourceData toURL:uTarget withError:err];
}

/*
 *  Write data securely to the vault
 */
+(BOOL) writeData:(NSData *) sourceData toURL:(NSURL *) url withError:(NSError **) err
{
    // - no need for broad locking because the dependent codepaths are thread safe.
    if (![RSI_vault isOpen]) {
        [RSI_error fillError:err withCode:RSIErrorAuthRequired];
        return NO;
    }
    
    RSI_appkey *akCur = [RSI_vault currentAppkey];
    return [akCur writeData:sourceData toURL:url withError:err];
}

/*
 *  Read data securely from the vault.
 */
+(BOOL) readFile:(NSString *) fName intoData:(RSISecureData **) destData withError:(NSError **) err;
{
    // - no need for broad locking because the dependent codepaths are thread safe.
    NSURL *uSource = [RSI_vault absoluteURLForFile:fName withError:err];
    if (!uSource) {
        return NO;
    }
    
    return [RSI_vault readURL:uSource intoData:destData withError:err];
}

/*
 *  Read data securely from the vault.
 */
+(BOOL) readURL:(NSURL *) url intoData:(RSISecureData **) destData withError:(NSError **) err
{
    // - no need for broad locking because the dependent codepaths are thread safe.
    if (![RSI_vault isOpen]) {
        [RSI_error fillError:err withCode:RSIErrorAuthRequired];
        return NO;
    }

    RSI_securememory *secmem = nil;
    RSI_appkey *akCur        = [RSI_vault currentAppkey];
    if (![akCur readURL:url intoData:&secmem withError:err]) {
        return NO;
    }
    
    if (destData) {
        *destData = [secmem convertToSecureData];
    }
    return YES;
}

/*
 *  Return an absolute path name for a vault file.
 */
+(NSURL *) absoluteURLForFile:(NSString *) fName withError:(NSError **) err
{
    // - ensure that generating that external files directory only occurs once.
    @synchronized (synchVault) {
        NSURL *uFile = [RSI_vault vaultExternalFilesDirectoryWithError:err];
        if (!uFile) {
            return nil;
        }
        return [uFile URLByAppendingPathComponent:fName];
    }
}

/*
 *  Delete a seal from the vault.
 */
+(BOOL) deleteSeal:(NSString *) sealId withError:(NSError **) err
{
    @synchronized (synchVault) {
        if (![RSI_vault isOpen]) {
            [RSI_error fillError:err withCode:RSIErrorAuthRequired];
            return NO;
        }
        
        NSURL *u = [RSI_vault vaultDirectoryWithError:err];
        if (!u) {
            return NO;
        }
        
        if (![RSISecureSeal deleteSealInVault:u forId:sealId withAppKey:appkey andError:err]) {
            return NO;
        }
        
        if (maSealList) {
            [maSealList removeObject:sealId];
        }
        return YES;
    }
}

/*
 *  Get ready for seal generation by making sure the expensive keys are created.
 */
+(void) prepareForSealGeneration
{
    @synchronized (synchVault) {
        [RSI_seal prepareForSealGeneration];
    }
}

@end


/*****************************
 RSI_vault (internal)
 *****************************/
@implementation RSI_vault (internal)
/*
 *  The vault requires an on-disk cache.
 */
+(NSURL *) vaultDirectoryWithError:(NSError **) err
{
    if (vaultDirectory) {
        return [[vaultDirectory retain] autorelease];
    }
    else {
        [RSI_error fillError:err withCode:RSIErrorCouldNotAccessVault andFailureReason:@"Unexpected empty vault directory URL."];
        return nil;
    }
}

/*
 *  Any files that an external entity requests be stored in the vault.
 */
+(NSURL *) vaultExternalFilesDirectoryWithError:(NSError **) err
{
    NSURL *url = [RSI_vault vaultDirectoryWithError:err];
    if (!url) {
        return nil;
    }
    
    url = [url URLByAppendingPathComponent:@"files"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:[url path]]) {
        NSError *tmp = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:[url path] withIntermediateDirectories:YES attributes:nil error:&tmp]) {
            [RSI_error fillError:err withCode:RSIErrorCouldNotAccessVault andFailureReason:[tmp localizedDescription]];
            return nil;
        }
    }
    return url;
}

/*
 *  When opening the vault, we will ensure that all the seals are 
 *  installed in the keychain, which could happen if the 
 *  person moved to a new device.
 */
+(BOOL) validateVaultContentsWithError:(NSError **) err
{
    NSURL *uVault = [RSI_vault vaultDirectoryWithError:err];
    if (!uVault) {
        return NO;
    }
    
    if (!appkey) {
        [RSI_error fillError:err withCode:RSIErrorInvalidArgument andFailureReason:@"Validation called without context."];
        return NO;
    }
    
    NSError *tmp = nil;
    NSArray *arr = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:uVault includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLNameKey, NSURLPathKey, nil] options:0 error:&tmp];
    if (!arr) {
        [RSI_error fillError:err withCode:RSIErrorCouldNotAccessVault andFailureReason:[tmp localizedDescription]];
        return NO;
    }
    
    //  - iterate over each element on disk and pull it into the keychain if it
    //    doesn't already exist.
    for (NSUInteger i = 0; i < [arr count]; i++) {
        NSURL *u = [arr objectAtIndex:i];
        BOOL isDir = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:[u path] isDirectory:&isDir] && isDir) {
            continue;
        }
        
        NSString *sName = [u lastPathComponent];
        if ([sName length] != [RSI_SHA_SEAL SHA_B64_STRING_LEN]) {
            continue;
        }

        if ([RSI_seal sealExists:sName withError:&tmp]) {
            continue;
        }

        //  - if anything happened other than 'key not found', abort
        if (tmp) {
            [RSI_error fillError:err withCode:RSIErrorCouldNotAccessVault andFailureReason:[tmp localizedDescription]];
            return NO;
        }

        //  - the key doesn't exist, so port it into the keychain.
        //  - I'm allowing errors here because I don't know if there are possibilities for
        //    temporary keychain outages.
        @autoreleasepool {
            RSI_securememory *secMem = nil;
            if ([appkey readURL:u intoData:&secMem withError:nil]) {
                RSI_seal *s = [RSI_seal allocSealWithArchive:secMem.rawData andError:nil];
                if (!s) {
                    NSLog(@"RSI: unsupported seal archive: %@", sName);
                }
                [s release];
            }
            else {
                //  - I was tempted to error out here, but I'm going to
                //    allow the app to continue since this scenario is very
                //    rare and there isn't a good solution for addressing the problem.
                //  - It is possible that the next run (after a device reboot) could
                //    address any number of the issues that occurred with the keychain.
                NSLog(@"RSI: seal read failure: %@", sName);
            }
        }
    }

    return YES;
}

/*
 *  This is the basic test for the vault, which is intended to be fast for most scenarios.
 */
+(BOOL) basicHasVault
{
    // - these two criteria are really what defines a vault: directory and app key.   Everything
    //   else is derived from these.
    NSURL *u = [RSI_vault vaultDirectoryWithError:nil];
    if (u && [[NSFileManager defaultManager] fileExistsAtPath:[u path]] && [RSI_appkey isInstalled]) {
        return YES;
    }
    return NO;
}

/*
 *  Because the app key could disappear while it is being used, this method allows us to safely
 *  get a quick autorelease handle to it.
 */
+(RSI_appkey *) currentAppkey
{
    @synchronized (synchVault) {
        return [[appkey retain] autorelease];
    }
}

@end

