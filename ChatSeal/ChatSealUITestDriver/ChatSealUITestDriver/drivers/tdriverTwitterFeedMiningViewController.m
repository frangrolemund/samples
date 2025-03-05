//
//  tdriverTwitterFeedMiningViewController.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 3/21/14.
//  Copyright (c) 2014 Francis Grolemund. All rights reserved.
//

#import "tdriverTwitterFeedMiningViewController.h"
#import <Accounts/Accounts.h>
#import <Social/Social.h>

// - forward declarations
@interface tdriverTwitterFeedMiningViewController (internal)
-(void) beginTwitterConnection;
-(void) verifyUserForId:(NSNumber *) nUserId;
@end

// - session-related tasks.
@interface tdriverTwitterFeedMiningViewController (session) <NSURLSessionDataDelegate, NSURLSessionDelegate>
@end

/***************************************
 tdriverTwitterFeedMiningViewController
 ***************************************/
@implementation tdriverTwitterFeedMiningViewController
/*
 *  Object attributes
 */
{
    ACAccountStore *asGlobal;
    NSURLSession *session;
    NSURLSessionDataTask *twitterTask;
}
@synthesize bConnectToTwitter;

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        asGlobal    = nil;
        session     = nil;
        twitterTask = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [bConnectToTwitter release];
    bConnectToTwitter = nil;
    
    [asGlobal release];
    asGlobal = nil;
    
    [session release];
    session = nil;
    
    [twitterTask release];
    twitterTask = nil;
    
    [super dealloc];
}

/*
 *  Configure the object.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
}

-(void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [session invalidateAndCancel];
}

/*
 *  Connect to Twitter.
 */
-(IBAction)doConnectToTwitter:(id)sender
{
    NSLog(@"DEBUG: start connection.");
    
    if (!asGlobal) {
        asGlobal = [[ACAccountStore alloc] init];
    }
    
    ACAccountType *atTwitter = [asGlobal accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    [asGlobal requestAccessToAccountsWithType:atTwitter options:nil completion:^(BOOL granted, NSError *err) {
        if (!granted) {
            if (err) {
                NSLog(@"DEBUG: no twitter access error is %@", [err localizedDescription]);
            }
            return;
        }
        [self performSelectorOnMainThread:@selector(beginTwitterConnection) withObject:nil waitUntilDone:NO];
    }];
}
@end

/*************************************************
 tdriverTwitterFeedMiningViewController (internal)
 *************************************************/
@implementation tdriverTwitterFeedMiningViewController (internal)
/*
 *  Start connecting to Twitter.
 */
-(void) beginTwitterConnection
{
    if (twitterTask) {
        return;
    }
    
    ACAccountType *atTwitter = [asGlobal accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    NSArray *arrAccounts = [asGlobal accountsWithAccountType:atTwitter];
    ACAccount *curA = [arrAccounts lastObject];
    if (!curA) {
        NSLog(@"ERROR: no accounts!");
        return;
    }

    NSDictionary *dictParm = nil;
//    dictParm = [NSDictionary dictionaryWithObject:@"Fran" forKey:@"track"];
    SLRequest *req = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET
                                                  URL:[NSURL URLWithString:@"https://userstream.twitter.com/1.1/user.json"] parameters:dictParm];
    req.account = curA;
    
    
    NSURLRequest *preparedRequest = [req preparedURLRequest];
    NSDictionary *dictAlHeader = [preparedRequest allHTTPHeaderFields];
    NSLog(@"DEBUG: all header items --> %@", dictAlHeader);
    
    if (!session) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 60;
        config.timeoutIntervalForResource = 60 * 10.0f;
        session = [[NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil] retain];
    }

    twitterTask = [[session dataTaskWithRequest:preparedRequest] retain];
    [twitterTask resume];
}

/*
 *  Make a REST call to check on the user to just posted.
 */
-(void) verifyUserForId:(NSString *) sScreenName
{
    ACAccountType *atTwitter = [asGlobal accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    NSArray *arrAccounts = [asGlobal accountsWithAccountType:atTwitter];
    ACAccount *curA = [arrAccounts lastObject];
    if (!curA) {
        NSLog(@"ERROR: no accounts!");
        return;
    }

    NSDictionary *dictParm = nil;
    dictParm = [NSDictionary dictionaryWithObject:sScreenName forKey:@"screen_name"];
    SLRequest *req = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET
                                                  URL:[NSURL URLWithString:@"https://api.twitter.com/1.1/users/show.json"] parameters:dictParm];
    req.account = curA;

    NSURLRequest *preparedRequest = [req preparedURLRequest];
    
    NSURLResponse *resp = nil;
    NSError *err = nil;
    NSData *dResponse = [NSURLConnection sendSynchronousRequest:preparedRequest returningResponse:&resp error:&err];
    if (dResponse && [dResponse length]) {
        id ret = [NSJSONSerialization JSONObjectWithData:dResponse options:0 error:nil];
        NSLog(@"DEBUG: response is %@", ret);
    }
    else {
        NSLog(@"DEBUG: FAILED TO VERIFY THE USER.");
    }
}
@end

/*************************************************
 tdriverTwitterFeedMiningViewController (session)
 *************************************************/
@implementation tdriverTwitterFeedMiningViewController (session)
-(void) URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error
{
    NSLog(@"DEBUG: session became invalid!");
}

-(void) URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    NSLog(@"DEBUG: finish events for background session!  DO SOMETHING!");
}

-(void) URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    NSLog(@"DEBUG: received data of length %lu", (unsigned long) [data length]);
    if (data && data.length) {
        id ret = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (!ret) {
            return;
        }
        if ([ret isKindOfClass:[NSArray class]]) {
            NSArray *arr = (NSArray *) ret;
            NSLog(@"DEBUG: data -> %@", arr);
        }
        else if ([ret isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *) ret;
            NSLog(@"DEBUG: data --> %@", dict);
            
            NSDictionary *dUser = [dict objectForKey:@"user"];
            if (dUser) {
                NSString *sScreenName = [dUser objectForKey:@"screen_name"];
                if (sScreenName) {
                    [self performSelectorOnMainThread:@selector(verifyUserForId:) withObject:sScreenName waitUntilDone:NO];
                }
            }
        }
    }
}

-(void) URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    NSLog(@"DEBUG: session task completed.");
}

@end
