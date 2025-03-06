//
//  RSI_error.h
//  RealSecureImage
//
//  Created by Francis Grolemund on 11/12/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonCryptor.h>

//  All errors produced by the RealSecureImage library are defined here.
extern NSString *RSIErrorDomain;

//  NOTICE: the implementation must be updated with a localized string for
//          each error added here.
typedef enum
{
    RSIErrorInvalidArgument = -1,
    RSIErrorAborted = -2,
    RSIErrorPackedDataOverflow = -3,
    RSIErrorImageOutputFailure = -4,
    RSIErrorInvalidSecureImage = -5,
    RSIErrorKeyExists = -6,
    RSIErrorKeyNotFound = -7,
    RSIErrorKeychainFailure = -8,
    RSIErrorOutOfMemory = -9,
    RSIErrorCryptoFailure = -10,
    RSIErrorInsufficientKey = -11,
    RSIErrorAuthRequired = -12,
    RSIErrorAuthFailed = -13,
    RSIErrorAppKeySaveFailure = -14,
    RSIErrorAppKeyLoadFailure = -15,
    RSIErrorFailedToWriteEncrypted = -16,
    RSIErrorFailedToReadEncrypted = -17,
    RSIErrorImageScramblingFailed = -18,
    RSIErrorSealCreationFailed = -19,
    RSIErrorFileWriteFailed = -20,
    RSIErrorSealFileReadFailed = -21,
    RSIErrorSealVersionMismatch = -22,
    RSIErrorSealLibraryFailure = -23,
    RSIErrorFileReadFailed = -25,
    RSIErrorInvalidSecureProps = -26,
    RSIErrorUnsupportedConsumerAction = -27,
    RSIErrorUnsupportedProducerAction = -28,
    RSIErrorSecurePropsVersionMismatch = -29,
    RSIErrorInvalidSeal = -30,
    RSIErrorInvalidSealedMessage = -31,
    RSIErrorUnknownPayload = -32,
    RSIErrorInvalidSealImage = -33,
    RSIErrorSealFailure = -34,
    RSIErrorBadPassword = -35,
    RSIErrorCouldNotAccessVault = -36,
    RSIErrorStaleVaultCreds = -37,
    RSIErrorPartialAppKey = -38,
    RSIErrorQROverCapacity = -39,
    RSIErrorSealFileDeletionError = -40,
    RSIErrorSealStillValid = 41,
    
} RSIErrorCode;

@interface RSI_error : NSError

+(BOOL) fillError:(NSError **) err withCode:(NSInteger) code;
+(BOOL) fillError:(NSError **) err withCode:(NSInteger) code andFailureReason:(NSString *) failCause;
+(BOOL) fillError:(NSError **) err withCode:(NSInteger) code andKeychainStatus:(OSStatus) status;
+(BOOL) fillError:(NSError **) err withCode:(NSInteger) code andCryptoStatus:(CCCryptorStatus) status;
+(BOOL) fillError:(NSError **) err withCode:(NSInteger) code andZlibError:(int) rc;

@end
