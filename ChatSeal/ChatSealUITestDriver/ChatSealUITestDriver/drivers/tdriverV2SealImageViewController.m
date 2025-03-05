//
//  tdriverV2SealImageViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 3/21/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "tdriverV2SealImageViewController.h"
#import "TestDriverUtil.h"

//  - constants
static const NSUInteger TDR_SB_NUM_TEST_IMAGES = 24;

// -  forward declarations
@interface tdriverV2SealImageViewController (internal)
-(void) configureHitClipView;
-(void) killTimer;
-(void) bumpTimer;
-(void) setCurrentLibraryPicture;
@end

/*******************************
 tdriverV2SealBadgeViewController
 *******************************/
@implementation tdriverV2SealImageViewController
/*
 *  Object attributes.
 */
{
    CGFloat highClipValue;
    UIImageView *hitClipView;
    NSTimer *hideClipTimer;
}


@synthesize lTestImage;
@synthesize stepTestImage;
@synthesize siView;
@synthesize ivSnap;
@synthesize sliderClip;

/*
 *  Initialize the object.
 */
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        currentTestImage = 0;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [self killTimer];
    
    [lTestImage release];
    lTestImage = nil;
    
    [stepTestImage release];
    stepTestImage = nil;
    
    [siView release];
    siView = nil;
    
    [sliderClip release];
    sliderClip = nil;
        
    [super dealloc];
}

/*
 *  The view controller is ready for configuration.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
 
    [self configureHitClipView];
    
    highClipValue = [siView hitClippingRadiusPct];
    sliderClip.value = 1.0f;
    
    // - set up the image view
    siView.layer.borderColor = [[UIColor blackColor] CGColor];
    siView.layer.borderWidth = 1.0f;
    
    // - set up the stepper
    stepTestImage.autorepeat = NO;
    stepTestImage.wraps = NO;
    stepTestImage.value = 0.0f;
    [stepTestImage setMinimumValue:0.0f];
    [stepTestImage setMaximumValue:(TDR_SB_NUM_TEST_IMAGES-1)];
    [stepTestImage setStepValue:1.0f];

    UIImage *img = [UIImage imageNamed:@"seal_sample1.jpg"];
    if (img) {
        [self setCurrentLibraryPicture];
    }
    else {
        NSLog(@"ERROR:  Missing test driver assets.");
    }
}

/*
 *  The seals will always be square and this constraint is going to force a bounds
 *  change on the view that will exercise the layout in different ways.  This is
 *  an important one for the test case.
 */
-(void) updateViewConstraints
{
    [super updateViewConstraints];
    NSLayoutConstraint *squareC = [NSLayoutConstraint constraintWithItem:siView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:siView attribute:NSLayoutAttributeHeight multiplier:1.0f constant:0.0f];
    [self.view addConstraint:squareC];
}

/*
 *  The image should be incremented.
 */
-(IBAction)didStep:(id)sender
{
    [self setCurrentLibraryPicture];
}

/*
 *  Pull a photo from the image view.
 */
-(IBAction)doGenerate:(id)sender
{
    UIImage *img = [siView standardizedSealImage];
    [ivSnap setImage:img];
}

/*
 *  Hide the clip view.
 */
-(void) clipHideFired
{
    [self killTimer];
    [UIView animateWithDuration:0.5f animations:^(void) {
        hitClipView.alpha = 0.0f;
    }];
}

/*
 *  Modify the current hit clipping value.
 */
-(IBAction)doChangeClipping:(id)sender
{
    if (!hideClipTimer) {
        [UIView animateWithDuration:0.5f animations:^(void){
            hitClipView.alpha = 1.0f;
        }];
        hideClipTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(clipHideFired) userInfo:nil repeats:NO];
        [hideClipTimer retain];
    }
    CGFloat radius = highClipValue * sliderClip.value;
    [siView setHitClippingRadiusPct:radius];
    hitClipView.bounds = CGRectMake(0.0f, 0.0f, CGRectGetWidth(siView.bounds)*radius , CGRectGetHeight(siView.bounds)*radius);
    hitClipView.center = siView.center;    
    [self bumpTimer];
}

@end

/***********************************************
 tdriverV2SealImageViewController (internal)
 ***********************************************/
@implementation tdriverV2SealImageViewController (internal)

/*
 *  Invalidate and remove the timer.
 */
-(void) killTimer
{
    [hideClipTimer invalidate];
    [hideClipTimer release];
    hideClipTimer = nil;
}

/*
 *  Increase the time on the timer for more delay
 */
-(void) bumpTimer
{
    NSDate *d = [NSDate dateWithTimeInterval:1.0f sinceDate:[NSDate date]];
    if (hideClipTimer) {
        [hideClipTimer setFireDate:d];
    }
}

/*
 *  Create a view that shows the clipping radius.
 */
-(void) configureHitClipView
{
    //  - build and attach the view.
    hitClipView = [[UIImageView alloc] init];
    hitClipView.alpha = 0.0f;
    [self.view addSubview:hitClipView];
    
    //  - generate a circle to show the radius.
    CGSize sz = CGSizeMake(512, 512);
    UIGraphicsBeginImageContextWithOptions(sz, NO, 1.0f);
    
    CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), [[UIColor colorWithRed:0.0f green:0.0f blue:1.0f alpha:0.25f] CGColor]);
    CGContextFillEllipseInRect(UIGraphicsGetCurrentContext(), CGRectMake(0.0f, 0.0f, sz.width, sz.height));
    
    hitClipView.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
}

/*
 *  Based on the current value of the stepper, set the seal image to be a library photo.
 */
-(void) setCurrentLibraryPicture
{
    NSUInteger imgNum = (NSUInteger) stepTestImage.value;
    imgNum++;
    NSString *testName = [NSString stringWithFormat:@"seal_sample%u.jpg", (unsigned) imgNum];
    UIImage *img = [UIImage imageNamed:testName];
    if (!img) {
        NSLog(@"TEST DRIVER FAIL: Failed to load the image %@.", testName);
        return;
    }
    currentTestImage = imgNum;
    
    CGSize sealSize = [UISealImageViewV2 sealImageSizeInPixels];
    NSString *sWidth = @"in";
    NSString *sHeight = @"in";
    
    CGSize imgSize = img.size;
    imgSize.width *= img.scale;
    imgSize.height *= img.scale;
    if (imgSize.width < sealSize.width) {
        sWidth = @"lo";
    }
    else if (imgSize.width > 1024.0f) {
        sWidth = @"hi";
    }
    
    if (imgSize.height < sealSize.height) {
        sHeight = @"lo";
    }
    else if (imgSize.height > 1024.0f) {
        sHeight = @"hi";
    }
    
    NSString *scale = @"";
    if (img.scale > 1.0f) {
        scale = [NSString stringWithFormat:@"@%1.0f", img.scale];
    }
    
    NSString *szAr = [NSString stringWithFormat:@"%2.2f", imgSize.width/imgSize.height];
    
    NSString *sDesc = [NSString stringWithFormat:@"img %u%@ (%@, %@) %@ (io:%u)", (unsigned) currentTestImage, scale, sWidth, sHeight, szAr, (unsigned) img.imageOrientation];
    [lTestImage setText:sDesc];
    
    [siView setSealImage:img];
    [siView setEditingEnabled:YES];
}

@end