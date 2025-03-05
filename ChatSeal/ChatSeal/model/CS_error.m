//
//  CS_error.m
//  ChatSeal
//
//  Created by Francis Grolemund on 2/2/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "CS_error.h"
#import <dns_sd.h>

NSString *SErrorDomain = @"SErrorDomain";

//  - forward declarations
@interface CS_error (internal)
+(NSString *) descriptionFromCode:(NSInteger) code;
@end

/************************
 CS_error
 ************************/
@implementation CS_error

/*
 *  Return an error object loaded with the specified code.
 */
+(BOOL) fillError:(NSError **) err withCode:(NSInteger) code
{
    return [CS_error fillError:err withCode:code andFailureReason:nil];
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
    NSString *s = [CS_error descriptionFromCode:code];
    if (failCause) {
        userData = [NSDictionary dictionaryWithObjectsAndKeys:s, NSLocalizedDescriptionKey, failCause, NSLocalizedFailureReasonErrorKey, nil];
    }
    else {
        userData = [NSDictionary dictionaryWithObject:s forKey:NSLocalizedDescriptionKey];
    }
    
    *err = [NSError errorWithDomain:SErrorDomain code:code userInfo:userData];
    return YES;
}

/*
 *  Return an error object loaded with the specified code and a Bonjour failure reason.
 */
+(BOOL) fillError:(NSError **) err withCode:(NSInteger) code forBonjourFailure:(int32_t) bonjourErrCode
{
    NSString *kerr = nil;
    NSString *fmt = nil;
    
    switch (bonjourErrCode) {
        case kDNSServiceErr_NoError:
            kerr = NSLocalizedString(@"No error.", nil);
            break;
            
        case kDNSServiceErr_NoSuchName:
            kerr = NSLocalizedString(@"No such name.", nil);
            break;
            
        case kDNSServiceErr_NoMemory:
            kerr = NSLocalizedString(@"No memory.", nil);
            break;
            
        case kDNSServiceErr_BadParam:
            kerr = NSLocalizedString(@"Bad parameter", nil);
            break;
            
        case kDNSServiceErr_BadReference:
            kerr = NSLocalizedString(@"Bad reference.", nil);
            break;
            
        case kDNSServiceErr_BadState:
            kerr = NSLocalizedString(@"Bad state.", nil);
            break;
            
        case kDNSServiceErr_BadFlags:
            kerr = NSLocalizedString(@"Bad flags.", nil);
            break;
            
        case kDNSServiceErr_Unsupported:
            kerr = NSLocalizedString(@"Unsupported operation.", nil);
            break;
            
        case kDNSServiceErr_NotInitialized:
            kerr = NSLocalizedString(@"Not initialized.", nil);
            break;

        case kDNSServiceErr_AlreadyRegistered:
            kerr = NSLocalizedString(@"Already registered.", nil);
            break;

        case kDNSServiceErr_NameConflict:
            kerr = NSLocalizedString(@"Name conflict.", nil);
            break;

        case kDNSServiceErr_Invalid:
            kerr = NSLocalizedString(@"Invalid.", nil);
            break;

        case kDNSServiceErr_Firewall:
            kerr = NSLocalizedString(@"Firewall failure.", nil);
            break;

        case kDNSServiceErr_Incompatible:
            kerr = NSLocalizedString(@"Incompatible.", nil);
            break;

        case kDNSServiceErr_BadInterfaceIndex:
            kerr = NSLocalizedString(@"Bad interface index.", nil);
            break;

        case kDNSServiceErr_Refused:
            kerr = NSLocalizedString(@"Operation refused.", nil);
            break;

        case kDNSServiceErr_NoSuchRecord:
            kerr = NSLocalizedString(@"No such record.", nil);
            break;

        case kDNSServiceErr_NoAuth:
            kerr = NSLocalizedString(@"No authorization.", nil);
            break;

        case kDNSServiceErr_NoSuchKey:
            kerr = NSLocalizedString(@"No such key.", nil);
            break;

        case kDNSServiceErr_NATTraversal:
            kerr = NSLocalizedString(@"NAT traversal failure.", nil);
            break;

        case kDNSServiceErr_DoubleNAT:
            kerr = NSLocalizedString(@"Double NAT failure.", nil);
            break;

        case kDNSServiceErr_BadTime:
            kerr = NSLocalizedString(@"Bad time.", nil);
            break;

        case kDNSServiceErr_BadSig:
            kerr = NSLocalizedString(@"Bad signature.", nil);
            break;

        case kDNSServiceErr_BadKey:
            kerr = NSLocalizedString(@"Bad key.", nil);
            break;

        case kDNSServiceErr_Transient:
            kerr = NSLocalizedString(@"Transient failure.", nil);
            break;

        case kDNSServiceErr_ServiceNotRunning:
            kerr = NSLocalizedString(@"Service not running.", nil);
            break;

        case kDNSServiceErr_NATPortMappingUnsupported:
            kerr = NSLocalizedString(@"NAT port mapping is unsupported.", nil);
            break;

        case kDNSServiceErr_NATPortMappingDisabled:
            kerr = NSLocalizedString(@"NAT port mapping is disabled.", nil);
            break;

        case kDNSServiceErr_NoRouter:
            kerr = NSLocalizedString(@"No router.", nil);
            break;

        case kDNSServiceErr_PollingMode:
            kerr = NSLocalizedString(@"Polling mode failure.", nil);
            break;
            
        case kDNSServiceErr_Timeout:
            kerr = NSLocalizedString(@"Timeout.", nil);
            break;
            
        case kDNSServiceErr_Unknown:
        default:
            fmt = NSLocalizedString(@"Unknown error %ld.", nil);
            kerr = [NSString stringWithFormat:fmt, bonjourErrCode];
            break;
    }
    
    if (kerr) {
        NSString *sErr = NSLocalizedString(@"Bonjour Error:  ", nil);
        sErr = [sErr stringByAppendingString:kerr];
        return [CS_error fillError:err withCode:code andFailureReason:sErr];
    }
    else {
        return [CS_error fillError:err withCode:code];
    }
}

@end

/********************************
 CS_error (internal)
 ********************************/
@implementation CS_error (internal)

/*
 *  Return a localized description for the given code.
 */
+(NSString *) descriptionFromCode:(NSInteger) code
{
    switch (code)
    {
        case CSErrorOk:
            return NSLocalizedString(@"No error.", nil);
            break;
            
        case CSErrorVaultNotInitialized:
            return NSLocalizedString(@"An error occurred while preparing the secure seal vault for operation.  All application behavior is offline.", nil);
            break;
            
        case CSErrorConfigurationFailure:
            return NSLocalizedString(@"A failure occurred while accessing the application settings.", nil);
            break;
            
        case CSErrorFilesystemAccessError:
            return NSLocalizedString(@"Unable to successfully read/write files on the device.", nil);
            break;
            
        case CSErrorInsufficientDecoyImage:
            return NSLocalizedString(@"The decoy image is insufficient to store the requested content.", nil);
            break;
            
        case CSErrorInvalidDecoyImage:
            return NSLocalizedString(@"The decoy image is invalid.", nil);
            break;
            
        case CSErrorInvalidArgument:
            return NSLocalizedString(@"Invalid argument.", nil);
            break;
            
        case CSErrorInvalidSeal:
            return NSLocalizedString(@"The seal is not sufficient to perform the requested operation.", nil);
            break;
            
        case CSErrorUnsupportedBarscan:
            return NSLocalizedString(@"An unsupported error occurred in the barcode scanner.", nil);
            break;
            
        case CSErrorBarscanFailure:
            return NSLocalizedString(@"The image did not contain a valid bar code.", nil);
            break;
            
        case CSErrorBarFormat:
            return NSLocalizedString(@"The image had an incomplete or incorrect bar code.", nil);
            break;
            
        case CSErrorAborted:
            return NSLocalizedString(@"The operation was aborted.", nil);
            break;
            
        case CSErrorNoActiveSeal:
            return NSLocalizedString(@"This device requires an active seal to begin the requested operation.", nil);
            break;
            
        case CSErrorSecureServiceNotEnabled:
            return NSLocalizedString(@"The secure transfer service is not enabled.", nil);
            break;
            
        case CSErrorSecureTransferFailed:
            return NSLocalizedString(@"The secure seal transfer failed.", nil);
            break;
            
        case CSErrorRadarFailure:
            return NSLocalizedString(@"The seal radar has failed.", nil);
            break;
            
        case CSErrorUnknownService:
            return NSLocalizedString(@"The service is not registered.", nil);
            break;
            
        case CSErrorConnectionFailure:
            return NSLocalizedString(@"A failure occurred while connecting to the remote device.", nil);
            break;
            
        case CSErrorMaliciousActivity:
            return NSLocalizedString(@"The actions of a malicious remote entity have been blocked.", nil);
            break;
            
        case CSErrorSecurityFailure:
            return NSLocalizedString(@"A required security subsystem is offline.", nil);
            break;
            
        case CSErrorPhotoCaptureFailure:
            return NSLocalizedString(@"The camera failed to successfully capture a photo.", nil);
            break;
            
        case CSErrorBadMessageStructure:
            return NSLocalizedString(@"The internal structure of the message has been corrupted.", nil);
            break;
            
        case CSErrorInvalidSecureRequest:
            return NSLocalizedString(@"The secure chat infrastructure has prevented an invalid operation.", nil);
            break;
            
        case CSErrorArchivalError:
            return NSLocalizedString(@"The message archive format is invalid.", nil);
            break;
            
        case CSErrorOpenGLRenderError:
            return NSLocalizedString(@"An unexpected OpenGL rendering error has occurred.", nil);
            break;
            
        case CSErrorBeaconFailure:
            return NSLocalizedString(@"The seal exchange beacon could not be configured.", nil);
            break;
        
        case CSErrorIdentityTransferFailure:
            return NSLocalizedString(@"The secure identity transfer has failed.", nil);
            break;
            
        case CSErrorNetworkReadFailure:
            return NSLocalizedString(@"A failure occurred while reading network data.", nil);
            break;
            
        case CSErrorNetworkWriteFailure:
            return NSLocalizedString(@"A failure occurred while writing network data.", nil);
            break;
            
        case CSErrorIdentityImportFailure:
            return NSLocalizedString(@"The shared identity could not be imported.", nil);
            break;
            
        case CSErrorIdentityCreationFailure:
            return NSLocalizedString(@"The new identity could not be created.", nil);
            break;
            
        case CSErrorQREncodingFailure:
            return NSLocalizedString(@"A suitable QR code could not be generated.", nil);
            break;
            
        case CSErrorQRCaptureFailure:
            return NSLocalizedString(@"The camera failed to support QR code scanning.", nil);
            break;
            
        case CSErrorMessageExists:
            return NSLocalizedString(@"The processed message is already in the vault.", nil);
            break;
            
        case CSErrorOperationPending:
            return NSLocalizedString(@"An additional request was made while a conflicting operation is in progress.", nil);
            break;
            
        case CSErrorFeedNotSupported:
            return NSLocalizedString(@"The feed does not support the requested operation.", nil);
            break;
            
        case CSErrorFeedLimitExceeded:
            return NSLocalizedString(@"The feed has exceeded its request capacity.", nil);
            break;
            
        case CSErrorVaultRequired:
            return NSLocalizedString(@"The secure seal vault is required for this operation.", nil);
            break;
            
        case CSErrorFeedDisabled:
            return NSLocalizedString(@"The feed does not currently permit any external activity.", nil);
            break;
            
        case CSErrorFeedCollectionNotOpen:
            return NSLocalizedString(@"The feed collection is not online.", nil);
            break;
            
        case CSErrorFeedInvalid:
            return NSLocalizedString(@"The requested feed has been deleted and is no longer available.", nil);
            break;
            
        case CSErrorStaleMessage:
            return NSLocalizedString(@"The message or one of its elements is stale.", nil);
            break;
            
        case CSErrorNotFound:
            return NSLocalizedString(@"The requested item was not found.", nil);
            break;
            
        case CSErrorFeedPasswordExpired:
            return NSLocalizedString(@"The feed password is expired.", nil);
            break;
            
        case CSErrorIncompleteFeedRequest:
            return NSLocalizedString(@"The request provided to the feed is insufficient for the operation.", nil);
            break;
            
        case CSErrorCannotLaunchTwitterApp:
            return NSLocalizedString(@"The Twitter app could not be launched.", nil);
            break;
            
        case CSErrorCannotNotLaunchAppStore:
            return NSLocalizedString(@"The app store could not be launched.", nil);
            break;
            
        default:
            return NSLocalizedString(@"Unknown error code.", nil);
            break;
    }
}

@end
