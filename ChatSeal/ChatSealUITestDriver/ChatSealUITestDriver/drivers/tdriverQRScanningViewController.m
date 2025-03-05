//
//  tdriverQRScanningViewController.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 2/3/14.
//  Copyright (c) 2014 Francis Grolemund. All rights reserved.
//

#import "tdriverQRScanningViewController.h"

// - constants
static const NSTimeInterval TDRIVER_SCAN_DISPLAY_TIME = 0.75f;

// - forward declarations
@interface tdriverQRScanningViewController (internal) <UIQRScannerDelegate>
-(void) hideScanExpired;
-(void) discardScanTimer;
@end

/*******************************
 tdriverQRScanningViewController
 *******************************/
@implementation tdriverQRScanningViewController
/*
 *  Object attributes.
 */
{
    BOOL        hasScanner;
    NSTimer     *tmHideScanTimer;
}
@synthesize lNotAvailError;
@synthesize qrScanner;
@synthesize lScanOutput;

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        hasScanner = NO;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [tmHideScanTimer release];
    tmHideScanTimer = nil;
    
    [lNotAvailError release];
    lNotAvailError = nil;
    
    [lScanOutput release];
    lScanOutput = nil;
    
    qrScanner.delegate = nil;
    [qrScanner release];
    qrScanner = nil;
    
    [super dealloc];
}

/*
 *  Configure the view.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    lScanOutput.alpha = 0.0f;
    if ([qrScanner isScanningAvailable]) {
        hasScanner = YES;
        qrScanner.delegate = self;
    }
    else {
        lNotAvailError.hidden = NO;
        qrScanner.hidden      = YES;
    }
}

/*
 *  When this view has appeared, turn on scanning.
 */
-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (hasScanner) {
        NSError *err = nil;
        if (![qrScanner startScanningWithError:&err]) {
            NSLog(@"ERROR:  Failed to start scanning.  %@", [err localizedDescription]);
        }
    }
}

/*
 *  The view is about to disappear.
 */
-(void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self discardScanTimer];
    [qrScanner stopScanning];
}

@end


/******************************************
 tdriverQRScanningViewController (internal)
 ******************************************/
@implementation tdriverQRScanningViewController (internal)
/*
 *  This delegate method is called when a successful scan is completed.
 */
-(void) qrScanner:(UIQRScanner *)scanner didScanCode:(NSString *)content
{
    lScanOutput.text = content;
    [UIView animateWithDuration:0.5f animations:^(void) {
        lScanOutput.alpha = 1.0f;
    }];
    if (tmHideScanTimer) {
        [tmHideScanTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:TDRIVER_SCAN_DISPLAY_TIME]];
    }
    else {
        tmHideScanTimer = [[NSTimer timerWithTimeInterval:TDRIVER_SCAN_DISPLAY_TIME target:self selector:@selector(hideScanExpired) userInfo:nil repeats:NO] retain];
        [[NSRunLoop mainRunLoop] addTimer:tmHideScanTimer forMode:NSRunLoopCommonModes];
    }
}

/*
 *  This delegate method is called when an error occurs during the capture process.
 */
-(void) qrScanner:(UIQRScanner *)scanner didFailWithError:(NSError *)err
{
    NSLog(@"ERROR: The QR Scanner failed!  %@", [err localizedDescription]);
}

/*
 *  Free the scan timer.
 */
-(void) discardScanTimer
{
    [tmHideScanTimer invalidate];
    [tmHideScanTimer release];
    tmHideScanTimer = nil;
}

/*
 *  When the hide scan timer expires, this is triggered.
 */
-(void) hideScanExpired
{
    [self discardScanTimer];
    [UIView animateWithDuration:0.5f animations:^(void) {
        lScanOutput.alpha = 0.0f;
    }];
}
@end
