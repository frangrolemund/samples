//
//  CS_feedCollectorUtil.m
//  ChatSeal
//
//  Created by Francis Grolemund on 3/27/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_feedCollectorUtil.h"
#import "ChatSeal.h"

//  THREADING-NOTES:
//  - these methods are static and do not require any locking.

// - forward declarations
@interface CS_feedCollectorUtil (internal)
@end

/****************************
 CS_feedCollectorUtil
 ****************************/
@implementation CS_feedCollectorUtil
/*
 *  Save a configuration securely using the vault.
 */
+(BOOL) secureSaveConfiguration:(NSDictionary *) dict asFile:(NSURL *) uFile withError:(NSError **) err
{
    if (!uFile || !dict) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        return NO;
    }
    
    // - This is intentional to accommodate the first experience of the user.  There is
    //   really nothing that can't be recreated until they build their vault anyway.
    if (![ChatSeal hasVault]) {
        return YES;
    }
    NSData *dEncoded = nil;
    @try {
        dEncoded = [NSKeyedArchiver archivedDataWithRootObject:dict];
    }
    @catch (NSException *exception) {
        [CS_error fillError:err withCode:CSErrorArchivalError andFailureReason:[exception description]];
        return NO;
    }
    return [RealSecureImage writeVaultData:dEncoded toURL:uFile withError:err];
}

/*
 *  Load a configuration securely using the vault.
 */
+(NSDictionary *) secureLoadConfigurationFromFile:(NSURL *) uFile withError:(NSError **) err
{
    if (!uFile) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        return nil;
    }
    
    NSDictionary *dictDecoded = nil;
    RSISecureData *sdRet      = nil;
    if (![RealSecureImage readVaultURL:uFile intoData:&sdRet withError:err]) {
        return nil;
    }
    
    // - now decode.
    @try {
        NSObject *obj = [NSKeyedUnarchiver unarchiveObjectWithData:sdRet.rawData];
        if ([obj isKindOfClass:[NSDictionary class]]) {
            return (NSDictionary *) obj;
        }
        
        // - catch corruptions.
        [CS_error fillError:err withCode:CSErrorFilesystemAccessError];
        return nil;
    }
    @catch (NSException *exception) {
        [CS_error fillError:err withCode:CSErrorArchivalError andFailureReason:[exception description]];
        return nil;
    }
    return dictDecoded;
}
@end

/*******************************
 CS_feedCollectorUtil (internal)
 *******************************/
@implementation CS_feedCollectorUtil (internal)
@end
