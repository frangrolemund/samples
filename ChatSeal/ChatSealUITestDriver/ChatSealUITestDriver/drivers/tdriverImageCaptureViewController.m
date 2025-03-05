//
//  tdriverImageCaptureViewController.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 4/11/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "tdriverImageCaptureViewController.h"
#import "tdriverImagePreviewViewController.h"
#import "TestDriverUtil.h"

// -  forward declarations
@interface tdriverImageCaptureViewController (internal) <UIPhotoCaptureViewDelegate>
@end

/***************************************
 tdriverImageCaptureViewController
 ***************************************/
@implementation tdriverImageCaptureViewController
@synthesize pcView;
@synthesize lNotAvail;
@synthesize bFlip;
@synthesize bSnap;

/*
 *  Initialize the view
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        
    }
    return self;
}

/*
 *  Free the object
 */
-(void) dealloc
{
    pcView.delegate = nil;
    [pcView release];
    pcView = nil;
    
    [super dealloc];
}

/*
 *  Perform configuration after the view is loaded.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //  - enable/disable camera support based on the
    //  capabilities of the view.
    if (![pcView isPhotoCaptureAvailable]) {
        bFlip.userInteractionEnabled = NO;
        bFlip.hidden = YES;
        
        bSnap.userInteractionEnabled = NO;
        bSnap.hidden = YES;
        
        lNotAvail.hidden = NO;
        return;
    }
    
    //  - it looks like the camera works.
    pcView.delegate = self;
    [pcView setCaptureEnabled:YES];
}

/*
 *  Flip the camera.
 */
-(IBAction)doFlip:(id)sender
{
    if ([pcView isPhotoCaptureAvailable]) {
        UIImage *img = [pcView imageForLastSample];
        [TestDriverUtil saveJPGPhoto:img asName:@"flip-sample.jpg"];
    }
    if (![pcView setPrimaryCamera:![pcView frontCameraIsPrimary]]) {
        NSLog(@"DEBUG: failed to flip cameras.");
    }
}

/*
 *  Snap a photo.
 */
-(IBAction)doSnap:(id)sender
{
    if ([pcView isPhotoCaptureAvailable]) {
        UIImage *img = [pcView imageForLastSample];
        [TestDriverUtil saveJPGPhoto:img asName:@"snap-sample.jpg"];
    }
    if (![pcView snapPhoto]) {
        NSLog(@"DEBUG: failed to snap a photo.");
    }
}

/*
 *  Turn off rotations to test that the camera layer does the right thing when rotated.
 */
-(BOOL) shouldAutorotate
{
    return NO;
}

-(void) viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    CGRect rcView = pcView.frame;
    CGFloat shortSide = 0.0f;
    if (rcView.size.width < rcView.size.height) {
        shortSide = rcView.size.width;
    }
    else {
        shortSide = rcView.size.height;
    }
    
    pcView.layer.cornerRadius = shortSide/2.0f;
}

@end

/***************************************
 tdriverImageCaptureViewController (internal)
 ***************************************/
@implementation tdriverImageCaptureViewController (internal)

/*
 *  This method is triggered when the camera is not ready.
 */
-(void) photoViewCameraNotReady:(UIPhotoCaptureView *) pv
{
    NSLog(@"DEBUG: camera not ready.");
    bFlip.userInteractionEnabled = NO;
    bSnap.userInteractionEnabled = NO;
}

/*
 *  This method is triggered when the camera is ready.
 */
-(void) photoViewCameraReady:(UIPhotoCaptureView *) pv
{
    NSLog(@"DEBUG: camera ready.");
    bFlip.userInteractionEnabled = YES;
    bSnap.userInteractionEnabled = YES;
}

/*
 *  This method is triggered when a photo is taken with the camera.
 */
-(void) photoView:(UIPhotoCaptureView *) pv snappedPhoto:(UIImage *) img
{
    [TestDriverUtil saveJPGPhoto:img asName:@"snapped-photo.jpg"];
    
    UIViewController *vc = [tdriverImagePreviewViewController imagePreviewForImage:img];
    [self.navigationController pushViewController:vc animated:YES];
}

/*
 *  This method is triggered when an error occurs.
 */
-(void) photoView:(UIPhotoCaptureView *) pv failedWithError:(NSError *) err
{
    NSLog(@"DEBUG: the photo capture view failed.  %@", [err localizedDescription]);    
}


@end