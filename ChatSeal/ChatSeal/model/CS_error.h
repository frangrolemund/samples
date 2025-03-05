//
//  CS_error.h
//  ChatSeal
//
//  Created by Francis Grolemund on 2/2/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

//  All errors produced by the RealSecureImage library are defined here.
extern NSString *SErrorDomain;

//  NOTICE: the implementation must be updated with a localized string for
//          each error added here.
typedef enum
{
    CSErrorOk                      = 0,
    CSErrorVaultNotInitialized     = -1,
    CSErrorConfigurationFailure    = -2,
    CSErrorFilesystemAccessError   = -3,
    CSErrorInsufficientDecoyImage  = -4,
    CSErrorInvalidDecoyImage       = -5,
    CSErrorInvalidArgument         = -6,
    CSErrorArchivalError           = -7,
    CSErrorInvalidSeal             = -8,
    CSErrorUnsupportedBarscan      = -9,
    CSErrorBarscanFailure          = -10,
    CSErrorBarFormat               = -11,
    CSErrorAborted                 = -12,
    CSErrorNoActiveSeal            = -13,
    CSErrorSecureServiceNotEnabled = -14,
    CSErrorSecureTransferFailed    = -15,
    CSErrorRadarFailure            = -16,
    CSErrorUnknownService          = -17,
    CSErrorConnectionFailure       = -18,
    CSErrorMaliciousActivity       = -19,
    CSErrorSecurityFailure         = -20,
    CSErrorInvalidSecureRequest    = -21,
    CSErrorPhotoCaptureFailure     = -22,
    CSErrorBadMessageStructure     = -23,
    CSErrorOpenGLRenderError       = -24,
    CSErrorBeaconFailure           = -25,
    CSErrorIdentityTransferFailure = -26,
    CSErrorNetworkReadFailure      = -27,
    CSErrorNetworkWriteFailure     = -28,
    CSErrorIdentityImportFailure   = -29,
    CSErrorIdentityCreationFailure = -30,
    CSErrorQREncodingFailure       = -31,
    CSErrorQRCaptureFailure        = -32,
    CSErrorMessageExists           = -33,
    CSErrorOperationPending        = -34,
    CSErrorFeedNotSupported        = -35,
    CSErrorFeedLimitExceeded       = -36,
    CSErrorVaultRequired           = -37,
    CSErrorFeedDisabled            = -38,
    CSErrorFeedCollectionNotOpen   = -39,
    CSErrorFeedInvalid             = -40,
    CSErrorStaleMessage            = -41,
    CSErrorNotFound                = -42,
    CSErrorFeedPasswordExpired     = -43,
    CSErrorIncompleteFeedRequest   = -44,
    CSErrorCannotLaunchTwitterApp  = -45,
    CSErrorCannotNotLaunchAppStore = -46,
    
} SErrorCode;

@interface CS_error : NSError

+(BOOL) fillError:(NSError **) err withCode:(NSInteger) code;
+(BOOL) fillError:(NSError **) err withCode:(NSInteger) code andFailureReason:(NSString *) failCause;
+(BOOL) fillError:(NSError **) err withCode:(NSInteger) code forBonjourFailure:(int32_t) bonjourErrCode;
@end
