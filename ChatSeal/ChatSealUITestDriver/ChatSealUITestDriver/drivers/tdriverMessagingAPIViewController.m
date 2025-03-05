//
//  tdriverMessagingAPIViewController.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 7/26/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <AddressBookUI/AddressBookUI.h>
#import <MessageUI/MessageUI.h>
#import <Accounts/Accounts.h>
#import <Social/Social.h>
#import "tdriverMessagingAPIViewController.h"

/**********************************
 tdriverMessagingAPIViewController
 **********************************/
@implementation tdriverMessagingAPIViewController

/*
 *  Show the UI to send a text
 */
-(IBAction)doShowTextUI:(id)sender
{
    MFMessageComposeViewController *picker = [[MFMessageComposeViewController alloc] init];
 
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.persistent = YES;
    pasteboard.image = [UIImage imageNamed:@"simple-png.png"];
 
#if 0
    NSString *phoneToCall = @"sms:";
    NSString *phoneToCallEncoded = [phoneToCall stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
    NSURL *url = [[NSURL alloc] initWithString:phoneToCallEncoded];
    [[UIApplication sharedApplication] openURL:url];
#endif
    
    if([MFMessageComposeViewController canSendText]) {
   //     picker.messageComposeDelegate = self;
        picker.recipients = [NSArray arrayWithObject:@"123456789"];
        //[picker setBody:emailBody];// your recipient number or self for testing
        //picker.body = emailBody;
        NSLog(@"Picker -- %@",picker.body);
        [self presentViewController:picker animated:YES completion:^(void){
            NSLog(@"DEBUG: completed!");
        }];
        NSLog(@"SMS fired");
    }
}

/*
 *  Show the contacts selection.
 */
-(void) doShowContacts:(id)sender
{
    ABPeoplePickerNavigationController *apc = [[ABPeoplePickerNavigationController alloc] init];
    [self presentViewController:apc animated:YES completion:nil];
}

/*
 *  Test Twitter interfaces.
 */
-(IBAction)doSendImageTweet:(id)sender
{
    // - find the PNG under a different name.
    // - this is necessary because PNGs are automatically optimized when included.
    NSData *dOrig = nil;
    for (NSBundle *b in [NSBundle allBundles]) {
        NSURL *u = [b URLForResource:@"rp-social-test-orig" withExtension:@"png-alt"];
        if (u) {
            dOrig = [NSData dataWithContentsOfURL:u];
            break;
        }
    }

    if (!dOrig) {
        NSLog(@"ERROR: failed to find the source image.");
        return;
    }
        
    //  - now find the twitter account.
    ACAccountStore *as = [[ACAccountStore alloc] init];
    ACAccount *acTwitter = nil;
    for (ACAccount *ac in as.accounts) {
        if ([ac.accountType.identifier isEqualToString:ACAccountTypeIdentifierTwitter]) {
            acTwitter = ac;
            break;
        }
    }
    
    if (!acTwitter) {
        NSLog(@"ERROR: you don't have a twitter account configured.");
        return;
    }

    NSURL *u = [NSURL URLWithString:@"https://api.twitter.com/1.1/statuses/update_with_media.json"];
    SLRequest *req = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:u parameters:[NSDictionary dictionaryWithObject:@"" forKey:@"status"]];
    req.account = acTwitter;
    [req addMultipartData:dOrig withName:@"media[]" type:@"multipart/form-data" filename:@"media.png"];
    [req performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error){
        NSLog(@"DEBUG: completed the request with response = %@", urlResponse);
    }];
}

/*
 *  Scan selected feeds for tweets.
 */
-(IBAction)doScanForTweets:(id)sender
{
//    NSString *sURL = @"https://api.twitter.com/1.1/search/tweets.json?q=from:ID_AA_Carmack&since_id=360077149090222080";
//    NSString *sURL = @"https://api.twitter.com/1.1/statuses/home_timeline.json?since_id=349970013630898176";
    NSString *sURL = @"https://api.twitter.com/1.1/statuses/home_timeline.json?since_id=349970013630898176&trim_user=1&exclude_replies=1";
    NSURL *u = [NSURL URLWithString:sURL];
    
    //  - now find the twitter account.
    ACAccountStore *as = [[ACAccountStore alloc] init];
    ACAccount *acTwitter = nil;
    for (ACAccount *ac in as.accounts) {
        if ([ac.accountType.identifier isEqualToString:ACAccountTypeIdentifierTwitter]) {
            acTwitter = ac;
            break;
        }
    }
    
    if (!acTwitter) {
        NSLog(@"ERROR: you don't have a twitter account configured.");
        return;
    }
    
    SLRequest *req = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:u parameters:nil];
    req.account = acTwitter;
    [req performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error){
        NSLog(@"DEBUG: response code = %u", (unsigned) urlResponse.statusCode);
        if (responseData) {
            id obj = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:nil];
            if (obj) {
                if ([obj isKindOfClass:[NSDictionary class]]) {
                    NSLog(@"DEBUG: is dictionary.");
                }
                else if ([obj isKindOfClass:[NSArray class]]) {
                    NSLog(@"DEBUG: is array.");
                }
                NSLog(@"DEBUG: found %@", obj);
            }
        }
    }];

    
}

@end
