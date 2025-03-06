//
//  RSI_error.m
//  RealSecureImage
//
//  Created by Francis Grolemund on 11/12/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import <zlib.h>
#import "RSI_error.h"

NSString *RSIErrorDomain = @"RSIErrorDomain";

//  - forward declarations
@interface RSI_error (internal)
+(NSString *) descriptionFromCode:(NSInteger) code;
@end

/************************
 RSI_error
 ************************/
@implementation RSI_error

/*
 *  Return an error object loaded with the specified code.
 */
+(BOOL) fillError:(NSError **) err withCode:(NSInteger) code
{
    return [RSI_error fillError:err withCode:code andFailureReason:nil];
}

/*
 *  Return an error object loaded with the specified code and failure reason.
 */
+(BOOL) fillError:(NSError **) err withCode:(NSInteger) code andFailureReason:(NSString *) failCause
{
    if (!err) {
        return NO;
    }
    
    NSDictionary *userData = nil;
    NSString *s = [RSI_error descriptionFromCode:code];
    if (failCause) {
        userData = [NSDictionary dictionaryWithObjectsAndKeys:s, NSLocalizedDescriptionKey, failCause, NSLocalizedFailureReasonErrorKey, nil];
    }
    else {
        userData = [NSDictionary dictionaryWithObject:s forKey:NSLocalizedDescriptionKey];
    }
    
    *err = [NSError errorWithDomain:RSIErrorDomain code:code userInfo:userData];
    return YES;
}

/*
 *  Return an error object filled with the specified code and keychain-specific code text in the extended description.
 */
+(BOOL) fillError:(NSError **) err withCode:(NSInteger) code andKeychainStatus:(OSStatus) status
{
    NSString *kerr = nil;
    NSString *fmt = nil;
    
    switch (status) {
        case errSecSuccess:
            kerr = NSLocalizedString(@"No error.", nil);
            break;
            
        case errSecUnimplemented:
            kerr = NSLocalizedString(@"Function or operation not implemented.", nil);
            break;
            
        case errSecParam:
            kerr = NSLocalizedString(@"One or more parameters passed to the function were not valid.", nil);            
            break;
            
        case errSecAllocate:
            kerr = NSLocalizedString(@"Failed to allocate memory.", nil);
            break;
            
        case errSecNotAvailable:
            kerr = NSLocalizedString(@"No trust results are available.", nil);                         
            break;
            
        case errSecAuthFailed:
            kerr = NSLocalizedString(@"Authorization/Authentication failed.", nil);
            break;
            
        case errSecDuplicateItem:
            kerr = NSLocalizedString(@"The item already exists.", nil);            
            break;
            
        case errSecItemNotFound:
            kerr = NSLocalizedString(@"The item cannot be found.", nil);                        
            break;
            
        case errSecInteractionNotAllowed:
            kerr = NSLocalizedString(@"Interaction with the Security Server is not allowed.", nil);                                    
            break;
            
        case errSecDecode:
            kerr = NSLocalizedString(@"Unable to decode the provided data.", nil);                                                
            break;
            
        default:
            fmt = NSLocalizedString(@"Unknown keychain error: %ld.", nil);
            kerr = [NSString stringWithFormat:fmt, status];
            break;
    }
    
    if (kerr) {
        return [RSI_error fillError:err withCode:code andFailureReason:kerr];
    }
    else {
        return [RSI_error fillError:err withCode:code];
    }
}

/*
 *  Return an error object filled with the specified code and crypto-specific code text in the extended description.
 */
+(BOOL) fillError:(NSError **) err withCode:(NSInteger) code andCryptoStatus:(CCCryptorStatus) status
{
    NSString *kerr = nil;
    NSString *fmt = nil;

    switch (status) {
        case kCCSuccess:
            kerr = NSLocalizedString(@"No error.", nil);
            break;
            
        case kCCParamError:
            kerr = NSLocalizedString(@"Invalid parameter.", nil);
            break;

        case kCCBufferTooSmall:
            kerr = NSLocalizedString(@"The supplied buffer is too small.", nil);
            break;
            
        case kCCMemoryFailure:
            kerr = NSLocalizedString(@"Out of memory.", nil);
            break;
            
        case kCCAlignmentError:
            kerr = NSLocalizedString(@"Alignment error.", nil);
            break;
            
        case kCCDecodeError:
            kerr = NSLocalizedString(@"Decode error.", nil);
            break;
            
        case kCCUnimplemented:
            kerr = NSLocalizedString(@"Unimplemented feature.", nil);
            break;
            
        case kCCOverflow:
            kerr = NSLocalizedString(@"Overflow error.", nil);
            break;
            
        default:
            fmt = NSLocalizedString(@"Unknown crypto error: %ld.", nil);
            kerr = [NSString stringWithFormat:fmt, status];
            break;
    }
    
    if (kerr) {
        return [RSI_error fillError:err withCode:code andFailureReason:kerr];
    }
    else {
        return [RSI_error fillError:err withCode:code];
    }
}

/*
 *  Return an error object filled with the specified code and zlib-specific code text in the extended description.
 */
+(BOOL) fillError:(NSError **) err withCode:(NSInteger) code andZlibError:(int) rc
{
    NSString *kerr = nil;
    NSString *fmt = nil;
    
    switch (rc) {
        case Z_OK:
            kerr = NSLocalizedString(@"No compression error.", nil);
            break;
            
        case Z_STREAM_END:
            kerr = NSLocalizedString(@"End of compression stream.", nil);
            break;
            
        case Z_NEED_DICT:
            kerr = NSLocalizedString(@"A preset zlib dictionary is required.", nil);
            break;
            
        case Z_ERRNO:
            kerr = NSLocalizedString(@"Compressed file operation error.", nil);
            break;
            
        case Z_STREAM_ERROR:
            kerr = NSLocalizedString(@"Compressed stream error.", nil);
            break;
            
        case Z_DATA_ERROR:
            kerr = NSLocalizedString(@"Compressed data format error.", nil);
            break;
            
        case Z_MEM_ERROR:
            kerr = NSLocalizedString(@"Memory allocation failure for compression operation.", nil);
            break;
            
        case Z_BUF_ERROR:
            kerr = NSLocalizedString(@"Compressed stream buffer error.", nil);
            break;
            
        case Z_VERSION_ERROR:
            kerr = NSLocalizedString(@"The compression library is incompatible with your request.", nil);            
            break;
            
        default:
            fmt = NSLocalizedString(@"Unknown compression error: %ld.", nil);
            kerr = [NSString stringWithFormat:fmt, rc];
            break;
    }
    
    if (kerr) {
        return [RSI_error fillError:err withCode:code andFailureReason:kerr];
    }
    else {
        return [RSI_error fillError:err withCode:code];
    }
}

@end

/********************************
 RSI_error (internal)
 ********************************/
@implementation RSI_error (internal)

/*
 *  Return a localized description for the given code.
 */
+(NSString *) descriptionFromCode:(NSInteger) code
{
    switch (code)
    {
        case RSIErrorInvalidArgument:
            return NSLocalizedString(@"Invalid program arguments were passed to an internal function.", nil);
            break;
            
        case RSIErrorAborted:
            return NSLocalizedString(@"The operation has been aborted.", nil);
            break;
            
        case RSIErrorPackedDataOverflow:
            return NSLocalizedString(@"The supplied data exceeds the capacity of the container image.", nil);
            break;
            
        case RSIErrorImageOutputFailure:
            return NSLocalizedString(@"An error occurred while writing the image output file.", nil);
            break;
            
        case RSIErrorInvalidSecureImage:
            return NSLocalizedString(@"The image is not a valid secure image file.", nil);
            break;
            
        case RSIErrorKeyExists:
            return NSLocalizedString(@"The encryption key already exists.", nil);
            break;
            
        case RSIErrorKeyNotFound:
            return NSLocalizedString(@"The requested encryption key could not be found in the keychain.", nil);
            break;
            
        case RSIErrorKeychainFailure:
            return NSLocalizedString(@"The application keychain could not be accessed.", nil);
            break;
            
        case RSIErrorOutOfMemory:
            return NSLocalizedString(@"Out of memory.", nil);
            break;
            
        case RSIErrorCryptoFailure:
            return NSLocalizedString(@"An internal cryptography failure has occcurred.", nil);
            break;
            
        case RSIErrorInsufficientKey:
            return NSLocalizedString(@"The provided key is insufficient for the requested task.", nil);
            break;
            
        case RSIErrorAuthRequired:
            return NSLocalizedString(@"Authentication is required.", nil);
            break;
            
        case RSIErrorAuthFailed:
            return NSLocalizedString(@"Authentication failed.", nil);
            break;
            
        case RSIErrorAppKeySaveFailure:
            return NSLocalizedString(@"An error occurred while saving the application security credentials.", nil);
            break;
            
        case RSIErrorAppKeyLoadFailure:
            return NSLocalizedString(@"An error occurred while reading the application security credentials.", nil);
            break;
            
        case RSIErrorFailedToWriteEncrypted:
            return NSLocalizedString(@"An error occurred while writing an encrypted file.", nil);
            break;
            
        case RSIErrorFailedToReadEncrypted:
            return NSLocalizedString(@"An error occurred while reading an encrypted file.", nil);            
            break;
            
        case RSIErrorImageScramblingFailed:
            return NSLocalizedString(@"An error occurred while scrambling the source image.", nil);
            break;
            
        case RSIErrorSealCreationFailed:
            return NSLocalizedString(@"An error occurred while creating a new seal.", nil);
            break;
            
        case RSIErrorFileWriteFailed:
            return NSLocalizedString(@"An error occurred while writing a file to disk.", nil);
            break;
            
        case RSIErrorSealFileReadFailed:
            return NSLocalizedString(@"An error occurred while reading the seal file.", nil);
            break;
            
        case RSIErrorSealVersionMismatch:
            return NSLocalizedString(@"The seal file is an unsupported version.", nil);
            break;
            
        case RSIErrorSealLibraryFailure:
            return NSLocalizedString(@"An error occurred while accessing the seal library.", nil);
            break;
            
        case RSIErrorFileReadFailed:
            return NSLocalizedString(@"An error occurred while reading the input file.", nil);
            break;
            
        case RSIErrorInvalidSecureProps:
            return NSLocalizedString(@"The secure property data format is invalid.", nil);
            break;
            
        case RSIErrorUnsupportedConsumerAction:
            return NSLocalizedString(@"The requested secure operation is not supported with consumer seals.", nil);
            break;
            
        case RSIErrorUnsupportedProducerAction:
            return NSLocalizedString(@"The requested secure operation is not supported with producer seals.", nil);
            break;
            
        case RSIErrorSecurePropsVersionMismatch:
            return NSLocalizedString(@"The secure property list type or version was invalid.", nil);
            break;
            
        case RSIErrorInvalidSeal:
            return NSLocalizedString(@"The seal is not valid.", nil);
            break;
            
        case RSIErrorInvalidSealedMessage:
            return NSLocalizedString(@"The message is not valid sealed content.", nil);
            break;
            
        case RSIErrorUnknownPayload:
            return NSLocalizedString(@"There is no compatible seal for the provided data.", nil);
            break;
            
        case RSIErrorInvalidSealImage:
            return NSLocalizedString(@"The provided image is insufficient for seal creation.", nil);
            break;
            
        case RSIErrorSealFailure:
            return NSLocalizedString(@"The seal operation failed.", nil);
            break;
            
        case RSIErrorBadPassword:
            return NSLocalizedString(@"The password is invalid.", nil);
            break;
            
        case RSIErrorCouldNotAccessVault:
            return NSLocalizedString(@"The on-disk seal vault could not be accessed.", nil);
            break;
            
        case RSIErrorStaleVaultCreds:
            return NSLocalizedString(@"The vault credentials are stale and cannot be used.", nil);
            break;
            
        case RSIErrorPartialAppKey:
            return NSLocalizedString(@"The vault encryption credentials are only partially available.", nil);
            break;
            
        case RSIErrorQROverCapacity:
            return NSLocalizedString(@"The requested data is too large for a single QR code.", nil);
            break;
            
        case RSIErrorSealFileDeletionError:
            return NSLocalizedString(@"An error occurred while deleting the seal file.", nil);
            break;
            
        case RSIErrorSealStillValid:
            return NSLocalizedString(@"The seal is still valid.", nil);
            break;
            
        default:
            return NSLocalizedString(@"Unknown error code.", nil);
            break;
    }
}

@end