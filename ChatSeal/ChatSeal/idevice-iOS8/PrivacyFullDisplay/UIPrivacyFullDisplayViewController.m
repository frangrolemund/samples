//
//  UIPrivacyFullDisplayViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 12/3/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIPrivacyFullDisplayViewController.h"
#import "ChatSeal.h"
#import "AlertManager.h"

// - forward declarations
@interface UIPrivacyFullDisplayViewController (internal) <UIWebViewDelegate>
-(NSURL *) urlForPrivacyPDF;
-(void) doExport;
@end

/***********************************
 UIPrivacyFullDisplayViewController
 ***********************************/
@implementation UIPrivacyFullDisplayViewController
/*
 *  Object attributes.
 */
{
    
}
@synthesize wvPreview;
@synthesize aiActivity;

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [wvPreview release];
    wvPreview = nil;
    
    [aiActivity release];
    aiActivity = nil;
    
    [super dealloc];
}

/*
 *  Configure the view.
 */
-(void) viewDidLoad
{
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"Privacy Policy", nil);
    
    // - set up the export option.
    UIBarButtonItem *bbiExport             = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(doExport)] autorelease];
    bbiExport.enabled                      = NO;
    self.navigationItem.rightBarButtonItem = bbiExport;
    
    // - load the PDF
    NSURL *url            = [self urlForPrivacyPDF];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    wvPreview.alpha       = 0.0f;
    wvPreview.delegate    = self;
    [aiActivity startAnimating];
    [wvPreview loadRequest:request];
}
@end

/*******************************************
 UIPrivacyFullDisplayViewController (internal)
 *******************************************/
@implementation UIPrivacyFullDisplayViewController (internal)

/*
 *  The web view finished.
 */
-(void) webViewDidFinishLoad:(UIWebView *)webView
{
    [self.navigationItem.rightBarButtonItem setEnabled:YES];
    [aiActivity stopAnimating];
    [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
        wvPreview.alpha = 1.0f;
    }];
}

/*
 *  Show an error when the load fails.
 */
-(void) webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [aiActivity stopAnimating];
    [AlertManager displayErrorAlertWithTitle:NSLocalizedString(@"Privacy Policy", nil) andText:@"There was a problem loading the privacy policy.  Please consult https://realproven.com/chatseal-privacy/ for the most up to date version."];
}

/*
 *  Return the URL for the full privacy policy.
 */
-(NSURL *) urlForPrivacyPDF
{
    return [[NSBundle mainBundle] URLForResource:@"chatseal-privacy" withExtension:@"pdf"];
}

/*
 *  Export the PDF.
 */
-(void) doExport
{
    NSURL *u                      = [self urlForPrivacyPDF];
    NSData *d                     = [NSData dataWithContentsOfURL:u];
    if (!d) {
        [AlertManager displayErrorAlertWithTitle:NSLocalizedString(@"Export Interrupted", nil) andText:@"The privacy policy file could not be loaded."];
        return;
    }
    UIActivityViewController *aiv = [[[UIActivityViewController alloc] initWithActivityItems:[NSArray arrayWithObject:d] applicationActivities:nil] autorelease];
    aiv.excludedActivityTypes     = [NSArray arrayWithObjects:UIActivityTypePostToFacebook, UIActivityTypePostToTwitter, UIActivityTypePostToWeibo, UIActivityTypeAssignToContact, UIActivityTypePostToFlickr, UIActivityTypePostToVimeo, UIActivityTypePostToTencentWeibo, nil];
    [self presentViewController:aiv animated:YES completion:nil];
}

@end
