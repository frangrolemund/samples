//
//  tdriverSocialVerificationViewController.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 3/19/14.
//  Copyright (c) 2014 Francis Grolemund. All rights reserved.
//

#import "tdriverSocialVerificationViewController.h"
#import <RealSecureImage/RealSecureImage.h>
#import "tdriverImagePreviewViewController.h"

// - forward declarations
@interface tdriverSocialVerificationViewController (internal)
@end

/***************************************
 tdriverSocialVerificationViewController
 ***************************************/
@implementation tdriverSocialVerificationViewController
/*
 *  Object attributes.
 */
{
    
}
@synthesize ivSample;
@synthesize tfGetSample;

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
    [ivSample release];
    ivSample = nil;
    
    [tfGetSample release];
    tfGetSample = nil;
    
    [super dealloc];
}

/*
 *  Configure the object.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];

    ivSample.layer.borderColor = [[UIColor blackColor] CGColor];
    ivSample.layer.borderWidth = 1.0f;
}

/*
 *  Generate a sample image and save it.
 */
-(IBAction)doGenerate:(id)sender
{
    UIImage *imgSource = [UIImage imageNamed:@"IMG_0232.JPG"];
    if (!imgSource) {
        NSLog(@"ERROR: failed to load the source image.");
        return;
    }
    
    UIImage *imgToPack = [UIImage imageNamed:@"sample-face.jpg"];
    if (!imgToPack) {
        NSLog(@"ERROR: failed to load the test data image.");
        return;
    }
    
    NSData *dContent = UIImageJPEGRepresentation(imgToPack, 0.65f);
    NSUInteger lenContent = [dContent length];
    
    NSMutableData *mdToPack = [NSMutableData dataWithLength:lenContent + sizeof(lenContent)];
    memcpy(mdToPack.mutableBytes, &lenContent, sizeof(lenContent));
    memcpy((uint8_t * )mdToPack.mutableBytes + sizeof(lenContent), dContent.bytes, dContent.length);
    
    NSError *err = nil;
    NSData *dPackedContent = [RealSecureImage packedPNG:imgSource andData:mdToPack andError:&err];
    if (!dPackedContent) {
        NSLog(@"ERROR: Failed to pack the source image.  %@", [err localizedDescription]);
        return;
    }
    
    NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    NSString *sName = [NSString stringWithFormat:@"soc-ver-%d.png", rand()];
    u = [u URLByAppendingPathComponent:sName];
    
    if (![dPackedContent writeToURL:u atomically:YES]) {
        NSLog(@"ERROR: failed to save the file.");
        return;
    }
    
    NSLog(@"DEBUG: The packed data image is at %@ (with embedded image of length %u).", u, (unsigned) lenContent);
    UIImage *img = [UIImage imageWithData:dPackedContent];
    ivSample.image = img;
}

/*
 *  Retrieve a sample from a remote site and decode it.
 */
-(IBAction)doRetrieve:(id)sender
{
    [tfGetSample resignFirstResponder];
    NSString *sURL = tfGetSample.text;
    if (!sURL) {
        return;
    }
   
    NSLog(@"DEBUG: sending the request...");
    NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:sURL]];
    NSURLResponse *resp = nil;
    NSError *err = nil;
    NSData *d = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&err];
    if (!d) {
        NSLog(@"ERROR: Failed to download the response.   %@" , [err localizedDescription]);
        return;
    }
    
    NSLog(@"DEBUG: got a response, now we'll try to unpack.");
    NSData *dUnpacked = [RealSecureImage unpackData:d withMaxLength:0 andError:&err];
    if (!dUnpacked || [dUnpacked length] < sizeof(NSUInteger)) {
        NSLog(@"ERROR: Failed to unpack the data.  %@", [err localizedDescription]);
        return;
    }
    
    NSUInteger lenContent = 0;
    memcpy(&lenContent, dUnpacked.bytes, sizeof(lenContent));
    
    if (lenContent < dUnpacked.length - sizeof(lenContent)) {
        NSLog(@"DEBUG: the size is wrong!");
        return;
    }
    
    dUnpacked = [NSData dataWithBytes:(uint8_t *) dUnpacked.bytes + sizeof(lenContent) length:lenContent];
    UIImage *img = [UIImage imageWithData:dUnpacked];
    if (!img) {
        NSLog(@"ERROR: Not a valid image file.");
        return;
    }
    
    NSLog(@"DEBUG: looks like it is a real image.");
    
    UIViewController *vc = [tdriverImagePreviewViewController imagePreviewForImage:img];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
