//
//  CS_twitterFeedAPI.h
//  ChatSeal
//
//  Created by Francis Grolemund on 3/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_netFeedAPI.h"

typedef enum {
    CS_TWIT_RM_GET  = 0,
    CS_TWIT_RM_POST = 1,
} ps_twit_req_method_t;

typedef enum {
    CS_TWIT_RC_UNSET        = 0,
    CS_TWIT_RC_OK           = 200,
    
    CS_TWIT_UNAUTHORIZED    = 401,
    CS_TWIT_FORBIDDEN       = 403,
    CS_TWIT_NOT_FOUND       = 404,
    CS_TWIT_TOO_MANY_LOGINS = 420,
    CS_TWIT_THROTTLED       = 429,
    CS_TWIT_RC_BAD_RESP     = 499
} ps_twit_response_code_t;

extern NSString *CS_TWITTERAPI_COMMON_TRUE;
extern NSString *CS_TWITTERAPI_COMMON_FALSE;

// NOTES:
// - only string ids are used throughout to have the greatest chance of remaining reliable.

@class ACAccount;
@class SLRequest;
@interface CS_twitterFeedAPI : CS_netFeedAPI
-(void) setCredentials:(ACAccount *) account;
-(ACAccount *) credentials;
-(NSString *) credAccountName;
-(NSURLRequest *) generateTwitterRequestForMethod:(ps_twit_req_method_t) reqMethod andParameters:(NSDictionary *) parms;
-(ps_twit_response_code_t) HTTPStatusCode;
-(void) markStatusAsGood;
-(BOOL) shouldNotAuthorizedBeInterpretedAsPasswordFailure;

+(BOOL) isChatSealValidImageURLString:(NSString *) sURL;

// - override these
-(NSURL *) resourceURL;
-(void) customizeRequest:(SLRequest *) req;
@end
