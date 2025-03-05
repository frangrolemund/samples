//
//  CS_twitterFeedAPI.m
//  ChatSeal
//
//  Created by Francis Grolemund on 3/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

//  THREADING-NOTES:
//  - These API object instances are consistent with the threading rules defined for CS_netFeedAPI and as such
//    do not require custom internal locking.

#import <Accounts/Accounts.h>
#import <Social/Social.h>
#import "CS_twitterFeedAPI.h"
#import "ChatSeal.h"

// - externals that are used for all APIs.
NSString *CS_TWITTERAPI_COMMON_TRUE  = @"true";
NSString *CS_TWITTERAPI_COMMON_FALSE = @"false";

// - forward declarations
@interface CS_twitterFeedAPI (internal)
@end

/********************
 CS_twitterFeedAPI
 ********************/
@implementation CS_twitterFeedAPI
/*
 *  Object attributes.
 */
{
    ACAccount               *twitterAccount;
    ps_twit_response_code_t httpStatusCode;
}

/*
 *  Initialize the object.
 */
-(id) initWithCreatorHandle:(CS_netFeedCreatorDelegateHandle *)cdh inCategory:(cs_cnt_throttle_category_t)category
{
    self = [super initWithCreatorHandle:cdh inCategory:category];
    if (self) {
        twitterAccount = nil;
        httpStatusCode = CS_TWIT_RC_UNSET;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [twitterAccount release];
    twitterAccount = nil;
    
    [super dealloc];
}

/*
 *  Every request of a Twitter feed requires system-supplied credentials.
 */
-(void) setCredentials:(ACAccount *) account
{
    if (twitterAccount != account) {
        [self clearActiveRequest];
        [twitterAccount release];
        twitterAccount = [account retain];
    }
}

/*
 *  Return the active credentials for the feed.
 */
-(ACAccount *) credentials
{
    return [[twitterAccount retain] autorelease];
}

/*
 *  Return the account name for this API, usually just for debugging purposes.
 */
-(NSString *) credAccountName
{
    return [[self credentials] username];
}

/*
 *  All sub-classes need to override this method to return a URL for the service
 *  entry point.
 */
-(NSURL *) resourceURL
{
    return nil;
}

/*
 *  Determine if this particular API could have generated the given request.
 */
-(BOOL) matchesRequest:(NSURLRequest *)req
{
    // - I realize this is redundant, but my intention is that Twitter APIs most often do not match, no
    //   matter what the request URL.  That matching test is only applicable to the persistent APIs and I'm
    //   keeping those to a small subset.
    return NO;
}

/*
 *  This is a common routine for generating requests specifically for Twitter.
 */
-(NSURLRequest *) generateTwitterRequestForMethod:(ps_twit_req_method_t) reqMethod andParameters:(NSDictionary *) parms
{
    if (!parms) {
        parms = [NSDictionary dictionary];
    }
    
    SLRequestMethod slrm;
    switch (reqMethod) {
        case CS_TWIT_RM_GET:
        default:
            slrm = SLRequestMethodGET;
            break;
            
        case CS_TWIT_RM_POST:
            slrm = SLRequestMethodPOST;
            break;
    }
    
    NSURL *resU = [self resourceURL];
    if (!resU) {
        NSLog(@"CS-ALERT: Twitter API %@ is missing a resource URL.", [[self class] description]);
        return nil;
    }
    
    SLRequest *req = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:slrm URL:resU parameters:parms];
    [self customizeRequest:req];
    
    httpStatusCode   = CS_TWIT_RC_UNSET;
    return [req preparedURLRequest];
}

/*
 *  Figure out the result of the API call.
 */
-(void) completeAPIWithSessionTask:(NSURLSessionTask *) task andError:(NSError *)err
{
    [super completeAPIWithSessionTask:task andError:err];
    if ([super isAPISuccessful] &&
        task && [task.response isKindOfClass:[NSHTTPURLResponse class]]) {
        httpStatusCode = (ps_twit_response_code_t) [(NSHTTPURLResponse *) task.response statusCode];
        
#ifdef CHATSEAL_DEBUG_TWITTER_API_FREQ
        if (httpStatusCode != CS_TWIT_RC_OK) {
            NSLog(@"*** FAIL ***: TAPI --> %@ (twitter reply: %u) %@", [self description], httpStatusCode, [self resultDataConvertedFromJSON]);
        }
#endif
    }
    else {
        httpStatusCode = CS_TWIT_RC_BAD_RESP;
        
        
#ifdef CHATSEAL_DEBUG_TWITTER_API_FREQ
        NSLog(@"*** FAIL ***: TAPI --> %@ (%@)", [self description], [err localizedDescription]);
#endif
    }
}

/*
 *  Return the result of the HTTP operation.
 */
-(ps_twit_response_code_t) HTTPStatusCode
{
    return httpStatusCode;
}

/*
 *  This is generally not used except as a debugging tool because we want our status
 *  to reflect reality as a rule.
 */
-(void) markStatusAsGood
{
    httpStatusCode = CS_TWIT_RC_OK;
}

/*
 *  When an API returns a not-authorized, HTTP 401 return code, we generally assume that it is our
 *  own feed's password is bad or expired, but in some isolated cases that isn't the right assumption.
 */
-(BOOL) shouldNotAuthorizedBeInterpretedAsPasswordFailure
{
    return YES;
}

/*
 *  Returns whether this API was successfully executed.
 */
-(BOOL) isAPISuccessful
{
    if (![super isAPISuccessful] || httpStatusCode != CS_TWIT_RC_OK) {
        return NO;
    }
    return YES;
}

/*
 *  Determine if the string is valid for packing.
 */
+(BOOL) isChatSealValidImageURLString:(NSString *) sURL
{
    if (!sURL) {
        return NO;
    }
    
    // - Only PNG is supported because Twitter munges the JPG files.
    NSRange r = [[sURL lowercaseString] rangeOfString:@".png"];
    if (r.location == NSNotFound) {
        return NO;
    }
    return YES;
}

/*
 *  Add more customization to the request.
 */
-(void) customizeRequest:(SLRequest *) req
{
    req.account = twitterAccount;
}

/*
 *  Overriden so that we can periodically check that our request frequency isn't
 *  too extreme.
 */
-(NSURLRequest *) requestWithError:(NSError **)err
{
#ifdef CHATSEAL_DEBUG_TWITTER_API_FREQ
    if (![self hasActiveRequest]) {
        NSLog(@"INFO: TAPI request --> %@", [self description]);
    }
#endif
    return [super requestWithError:err];
}

/*
 *  Return a customized description.
 */
-(NSString *) description
{
    return [NSString stringWithFormat:@"%@: for %@", NSStringFromClass([self class]), [self credAccountName]];
}
@end

/****************************
 CS_twitterFeedAPI (internal)
 ****************************/
@implementation CS_twitterFeedAPI (internal)

@end
