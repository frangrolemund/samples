//
//  CS_tapi_statuses_update_with_media.m
//  ChatSeal
//
//  Created by Francis Grolemund on 5/19/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Social/Social.h>
#import "CS_tapi_statuses_update_with_media.h"
#import "CS_feedTypeTwitter.h"
#import "ChatSeal.h"

//  THREADING-NOTES:
//  - This API is used on both the main thread for extracting from the stream and on the background thread where it is executed,
//    so locking is provided, unlike most other API instances.

// - constants
static NSString *S_TAPI_UWM_SAFE_ENTRY_HEADER = @"X-seid";

// - forward declarations
@interface CS_tapi_statuses_update_with_media (internal) <NSStreamDelegate>
@end

/***********************************
 CS_tapi_statuses_update_with_media
 REF: https://dev.twitter.com/docs/api/1.1/post/statuses/update_with_media
 NOTES:
 - the 'possibly_sensitive' argument is not used because we don't want to assume anything about the content and it is encrypted after all.
 - the 'lat' argument is not used because I don't want to compromise the privacy of the user.
 - the 'long' argument is not used because I don't want to compromise the privacy of the user.
 - the 'place_id' argument is not used because I don't want to compromise the privacy of the user. 
 - the 'display_coordinates' argument is not used because I don't want to compromise the privacy of the user.
 ***********************************/
@implementation CS_tapi_statuses_update_with_media
/*
 *  Object attributes.
 */
{
    NSString        *safeEntryId;
    NSString        *tweetText;
    NSData          *dPostData;
    NSString        *replyTweetId;
    NSString        *replyScreenName;
    
    // - preparation data
    BOOL            isPreparationComplete;
    NSURLRequest    *reqOriginal;
    NSMutableData   *mdPreparedBody;
    
    // - return data
    NSString    *tweetId;
    NSUInteger  mediaRemaining;
    time_t      mediaResetTime;
}

/*
 *  Initialize the object.
 */
-(id) initWithCreatorHandle:(CS_netFeedCreatorDelegateHandle *)cdh inCategory:(cs_cnt_throttle_category_t)category
{
    self = [super initWithCreatorHandle:cdh inCategory:category];
    if (self) {
        safeEntryId           = nil;
        tweetText             = nil;
        dPostData             = nil;
        replyTweetId          = nil;
        replyScreenName       = nil;
        tweetId               = nil;
        mediaRemaining        = 0;
        mediaResetTime        = 0;
        isPreparationComplete = NO;
        reqOriginal           = nil;
        mdPreparedBody        = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [self abortRequestPreparation];
    [super dealloc];
}

/*
 *  Return the service entrypoint.
 */
-(NSURL *) resourceURL
{
    return [NSURL URLWithString:@"https://api.twitter.com/1.1/statuses/update_with_media.json"];
}

/*
 *  Determine if this API is the same type as what generated the provided the request.
 */
-(BOOL) matchesRequest:(NSURLRequest *)req
{
    if ([req.URL isEqual:[self resourceURL]]) {
        return YES;
    }
    return NO;
}

/*
 *  When we rebuild the API, this will allow us to ensure the safe id is recreated.
 */
-(void) configureWithExistingRequest:(NSURLRequest *)req
{
    if (!safeEntryId) {
        safeEntryId = [[req.allHTTPHeaderFields objectForKey:S_TAPI_UWM_SAFE_ENTRY_HEADER] retain];
    }
}

/*
 *  Assign the image we're going to post to the feed.
 */
-(BOOL) setPostAsSafeEntry:(NSString *) seid withImagePNGData:(NSData *) dToPost andTweetText:(NSString *) text
{
    @synchronized (self) {
        if (safeEntryId != seid) {
            [safeEntryId release];
            safeEntryId = [seid retain];
        }
        
        if (dPostData != dToPost) {
            [self clearActiveRequest];
            [dPostData release];
            dPostData = [dToPost retain];
        }
        
        if (tweetText != text) {
            [tweetText release];
            tweetText = [text retain];
        }
        
        return (seid && dToPost ? YES : NO);
    }
}

/*
 *  This method is used to flag this tweet as a reply to an original one.  If the original
 *  tweet doesn't exist, then a new tweet will be added.
 */
-(BOOL) markAsReplyToTweet:(NSString *) origTweetId fromUser:(NSString *) screenName
{
    // - we do allow nil to be passed-in here to allow the API to be explicitly marked as a non-reply
    //   scenario in the same way.
    if (origTweetId != replyTweetId) {
        [replyTweetId release];
        replyTweetId = [origTweetId retain];
    }
    
    if (screenName != replyScreenName) {
        [replyScreenName release];
        replyScreenName = [screenName retain];
    }
    return YES;
}

/*
 *  Because this request adds multi-part form data, we need to add the image to the request object.
 */
-(void) customizeRequest:(SLRequest *)req
{
    [super customizeRequest:req];
    if (safeEntryId && dPostData) {
        NSString *sFile = [NSString stringWithFormat:@"%@.png", safeEntryId];
        [req addMultipartData:dPostData withName:@"media[]" type:@"image/png" filename:sFile];
    }
}

/*
 *  In order for this to work for upload, we need a request that has a standard HTTP body as opposed to one
 *  that has an HTTPBodyStream because we need to first persist the body.  Social requests only generate
 *  a stream, which requires we convert it to a body in order to build the right kind of request.
 */
-(BOOL) prepareToGenerateRequest
{
    @synchronized (self) {
        // - we need something to post.
        if (!safeEntryId || !dPostData || reqOriginal || isPreparationComplete) {
            return NO;
        }
        
        [reqOriginal release];
        reqOriginal = nil;
        
        NSMutableDictionary *mdParms = [NSMutableDictionary dictionary];
        [mdParms setObject:@"multipart/form-data" forKey:@"Content-Type"];
        if ([replyScreenName length]) {
            // ... when we reply, it is best to put the header on the line after the reply name to keep the header
            //     legible in the mentions feed. 
            [mdParms setObject:[NSString stringWithFormat:@"@%@,\n%@", replyScreenName, tweetText ? tweetText : @""] forKey:@"status"];
            
            // - if the reply tweet id is provided, then this will be an official reply, not just
            //   a casual mention.
            if ([replyTweetId length]) {
                [mdParms setObject:replyTweetId forKey:@"in_reply_to_status_id"];
            }
        }
        else {
            [mdParms setObject:tweetText ? tweetText : @"" forKey:@"status"];
        }
        
        // NOTE: the Twitter generation method should issue the customize request method above before
        //       generating anything.
        
        reqOriginal = [[super generateTwitterRequestForMethod:CS_TWIT_RM_POST andParameters:mdParms] retain];
        if (!reqOriginal || (!reqOriginal.HTTPBodyStream && !reqOriginal.HTTPBody)) {
            [reqOriginal release];
            reqOriginal = nil;
            return NO;
        }
        
        // - if the social framework generated a body, then use it, otherwise, we'll need to build one.
        if (reqOriginal.HTTPBody) {
            isPreparationComplete = YES;
        }
        else {
            // - open up the stream and extract all the data using the main runloop.
            [reqOriginal.HTTPBodyStream setDelegate:self];
            [reqOriginal.HTTPBodyStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
            [reqOriginal.HTTPBodyStream open];
        }
    }
    return YES;
}

/*
 *  Indicates whether we've finished preparing the payload of the request for upload.
 */
-(BOOL) isPreparedToGenerateRequest
{
    @synchronized (self) {
        return isPreparationComplete;
    }
}

/*
 *  Because we are scheduling this stream in the main run loop, we need to be careful that
 *  we disconnect the stream completely and avoid cases where events lie around on that queue
 *  too long.
 */
-(void) abortRequestPreparation
{
    @synchronized (self) {
        [safeEntryId release];
        safeEntryId = nil;
        
        [tweetId release];
        tweetId = nil;
        
        [tweetText release];
        tweetText = nil;
                
        [dPostData release];
        dPostData = nil;
        
        [replyTweetId release];
        replyTweetId = nil;
        
        [replyScreenName release];
        replyScreenName = nil;
        
        [reqOriginal.HTTPBodyStream close];
        [reqOriginal.HTTPBodyStream setDelegate:nil];
        [reqOriginal release];
        reqOriginal = nil;
        
        [mdPreparedBody release];
        mdPreparedBody = nil;
        
        isPreparationComplete = NO;
    }
}

/*
 *  Return the tweet id for the posted item.
 */
-(NSString *) postedTweetId
{
    @synchronized (self) {
        return [[tweetId retain] autorelease];
    }
}

/*
 *  Return the number of items remaining that may be posted before the reset time.
 */
-(NSUInteger) mediaRateLimitRemaining
{
    @synchronized (self) {
        return mediaRemaining;
    }
}

/*
 *  Return the UTC time when the media rate limit will be reset.
 */
-(time_t) mediaRateLimitResetTime
{
    @synchronized (self) {
        return mediaResetTime;
    }
}

/*
 *  Return the safe entry id for this item.
 */
-(NSString *) safeEntryId
{
    @synchronized (self) {
        return [[safeEntryId retain] autorelease];
    }
}

/*
 *  Uplooad requests require that we overrid the request id so that
 *  they can be tracked through that exchange and the persistent file
 *  deleted when they are done.
 */
-(NSString *) requestId
{
    return [self safeEntryId];
}

/*
 *  Determine if the user has exceeded their daily upload limit.
 */
-(BOOL) isOverDailyUploadLimit
{
    @synchronized (self) {
        // - this is an important item to track.
        if ([self HTTPStatusCode] == CS_TWIT_FORBIDDEN) {
            return YES;
        }
        return NO;
    }
}

/*
 *  Use the supplied parameters to build a new request for the caller.
 */
-(NSURLRequest *) generateRequestWithError:(NSError **)err
{
    @synchronized (self) {
        // - we need something to post.
        if (!isPreparationComplete) {
            return nil;
        }
        
        // - we always append the safe entry to the header to ensure we
        //   can find this again after a restart.
        NSMutableURLRequest *mur = (NSMutableURLRequest *) [[reqOriginal mutableCopy] autorelease];
        if (safeEntryId) {
            [mur addValue:safeEntryId forHTTPHeaderField:S_TAPI_UWM_SAFE_ENTRY_HEADER];
        }
        
        // - when there is no body yet defined, build one with the content extracted
        //   from the stream.
        if (!mur.HTTPBody) {
            mur.HTTPBodyStream = nil;
            mur.HTTPBody       = mdPreparedBody;
        }
        
        return mur;
    }
}

/*
 *  The API was completed, so this is a good time to save off the relevant data.
 */
-(void) completeAPIWithSessionTask:(NSURLSessionTask *)task andError:(NSError *)err
{
    @synchronized (self) {
        [super completeAPIWithSessionTask:task andError:err];
        
        // - parse out the response headers if they exist.
        NSDictionary *dictResponse = ((NSHTTPURLResponse *) task.response).allHeaderFields;
        if (dictResponse) {
            NSObject *objMediaRemaining = [dictResponse objectForKey:@"X-MediaRateLimit-Remaining"];
            if (objMediaRemaining) {
                NSScanner *scanner = [NSScanner scannerWithString:(NSString *) objMediaRemaining];
                int tmp            = 0;
                if ([scanner scanInt:&tmp]) {
                    mediaRemaining = (NSUInteger) tmp;
                }
            }
            
            NSObject *objReset = [dictResponse objectForKey:@"X-MediaRateLimit-Reset"];
            if (objReset) {
                NSScanner *scanner     = [NSScanner scannerWithString:(NSString *) objReset];
                unsigned long long tmp = 0;
                if ([scanner scanUnsignedLongLong:&tmp]) {
                    mediaResetTime = (time_t) tmp;
                }
            }
        }
        
        // - figure out the id of the Tweet for tracking if we're successful.
        if (![self isAPISuccessful]) {
            return;
        }
        
        NSObject *obj = [self resultDataConvertedFromJSON];
        if (![obj isKindOfClass:[NSDictionary class]]) {
            return;
        }
        
        NSDictionary *dictRet = (NSDictionary *) obj;
        tweetId               = [[dictRet objectForKey:@"id_str"] retain];
        if (!tweetId) {
            NSNumber *nTweet = [dictRet objectForKey:@"id"];
            if (!nTweet) {
                return;
            }
            tweetId = [[NSString alloc] initWithFormat:@"%@", nTweet];
        }        
    }
}
@end

/**********************************************
 CS_tapi_statuses_update_with_media (internal)
 **********************************************/
@implementation CS_tapi_statuses_update_with_media (internal)
/*
 *  We need to read the manufactured HTTPBody as a stream before we can persist it to disk from
 *  these Social APIs.
 */
-(void) stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    // - keep in mind that this is an NSInputStream instance and is happening on the main thread!
    @synchronized (self) {
        switch (eventCode) {
            case NSStreamEventNone:
            case NSStreamEventOpenCompleted:
            case NSStreamEventHasSpaceAvailable:
                // - do nothing for these.
                break;
                
            case NSStreamEventErrorOccurred:
                NSLog(@"CS: An error occurred during Twitter upload preparation.");
                // - fall-through-
                
            case NSStreamEventEndEncountered:
                [reqOriginal.HTTPBodyStream close];
                [reqOriginal.HTTPBodyStream setDelegate:nil];
                isPreparationComplete = YES;
                [self notifyPreparationCompleted];
                break;
                
            case NSStreamEventHasBytesAvailable:
                while ([reqOriginal.HTTPBodyStream hasBytesAvailable]) {
                    uint8_t buf[1024];
                    NSInteger ret = [reqOriginal.HTTPBodyStream read:buf maxLength:sizeof(buf)];
                    if (ret > 0) {
                        if (!mdPreparedBody) {
                            mdPreparedBody = [[NSMutableData alloc] init];
                        }
                        [mdPreparedBody appendBytes:buf length:(NSUInteger) ret];
                    }
                    else {
                        break;
                    }
                }
                break;
        }
    }
}
@end
