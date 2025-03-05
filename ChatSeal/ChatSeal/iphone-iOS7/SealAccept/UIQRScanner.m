//
//  UIQRScanner.m
//  ChatSeal
//
//  Created by Francis Grolemund on 2/3/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "UIQRScanner.h"
#import "ChatSeal.h"

// - forward declarations
@interface UIQRScanner (internal) <AVCaptureMetadataOutputObjectsDelegate>
-(void) commonConfiguration;
+(AVCaptureDevice *) backCamera;
-(BOOL) createAllSessionResourcesWithError:(NSError **) err;
-(void) releaseAllSessionResources;
-(void) notifyCaptureStarted;
-(void) notifyCaptureFailure:(NSNotification *) notification;
-(void) updateQRCaptureState;
@end

/**********************
 UIQRScanner
 **********************/
@implementation UIQRScanner
/*
 *  Object attributes
 */
{
    AVCaptureSession           *session;
    AVCaptureDevice            *devBackCamera;
    AVCaptureDeviceInput       *inputBackCamera;
    AVCaptureMetadataOutput    *scanningProcessor;
    AVCaptureVideoPreviewLayer *plVideoPreview;
    BOOL                       applyQRInterpretation;
    UIView                     *vwVideoOverlay;
}
@synthesize delegate;

/*
 *  Some regions allow camera restrictions to be employed.  This determines if they are in use.
 */
+(BOOL) isCameraRestrictricted
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    return ((status == AVAuthorizationStatusRestricted || status == AVAuthorizationStatusDenied) ? YES : NO);
#endif
}

/*
 *  Determine if the camera is available for scanning.
 */
+(BOOL) isCameraAvailable
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else
    if ([UIQRScanner isCameraRestrictricted]) {
        return NO;
    }

    if (![UIQRScanner backCamera]) {
        return NO;
    }
    return YES;
#endif
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonConfiguration];
    }
    return self;
}

/*
 *  Initialize the object.
 */
-(id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonConfiguration];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    delegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self releaseAllSessionResources];
    [vwVideoOverlay release];
    vwVideoOverlay = nil;
    [super dealloc];
}

/*
 *  When the QR scanner successfully scans a new item, report that in this delegate method.
 */
-(void) qrScanner:(UIQRScanner *) scanner didScanCode:(NSString *) content
{
    if (delegate && [delegate respondsToSelector:@selector(qrScanner:didScanCode:)]) {
        [delegate performSelector:@selector(qrScanner:didScanCode:) withObject:scanner withObject:content];
    }
}

/*
 *  Failures are reported to the delegate through this method.
 */
-(void) qrScanner:(UIQRScanner *) scanner didFailWithError:(NSError *) err
{
    if (delegate && [delegate respondsToSelector:@selector(qrScanner:didFailWithError:)]) {
        [delegate performSelector:@selector(qrScanner:didFailWithError:) withObject:scanner withObject:err];
    }
}

/*
 *  This method determines if we are able to scan with this device, which should always be the 
 *  case except with the simulator.
 */
-(BOOL) isScanningAvailable
{
    if ([UIQRScanner backCamera]) {
        return YES;
    }
    return NO;
}

/*
 *  Returns the restriction status for the camera.
 */
-(BOOL) isScanningRestricted
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else
    return (([UIQRScanner isCameraRestrictricted] || ![UIQRScanner backCamera]) ? YES : NO);
#endif
}

/*
 *  Begin scanning for QR codes.
 */
-(BOOL) startScanningWithError:(NSError **) err
{
    // - if the session doesn't yet exist, we need to create it and the
    //   different elements of the AV processing collection.
    if (!session) {
        if (![self createAllSessionResourcesWithError:err]) {
            return NO;
        }
    }
    
    [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
        vwVideoOverlay.alpha = 0.0f;
    }];
    
    [session startRunning];
    return YES;
}

/*
 *  Halt the scanning process.
 */
-(void) stopScanning
{
    [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
        vwVideoOverlay.alpha = 1.0f;
    }];
    
    [session stopRunning];
}

/*
 *  Make sure layout occurs.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    plVideoPreview.frame = CGRectMake(0.0f, 0.0f, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
    [CATransaction commit];
}

/*
 *  Turn QR interpretation on/off, which is useful for minimizing the performance impact while doing
 *  other things.
 */
-(void) setQRInterpretationEnabled:(BOOL) isEnabled
{
    applyQRInterpretation = isEnabled;
    [self updateQRCaptureState];
}

@end

/**********************
 UIQRScanner (internal)
 **********************/
@implementation UIQRScanner (internal)
/*
 *  Configure the view.
 */
-(void) commonConfiguration
{
    session               = nil;
    devBackCamera         = nil;
    inputBackCamera       = nil;
    scanningProcessor     = nil;
    plVideoPreview        = nil;
    applyQRInterpretation = YES;
    
    // - only the video display should be visible.
    self.backgroundColor = [UIColor clearColor];
    
    vwVideoOverlay                  = [[UIView alloc] initWithFrame:self.bounds];
    vwVideoOverlay.backgroundColor  = [UIColor blackColor];
    vwVideoOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:vwVideoOverlay];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyCaptureStarted) name:AVCaptureSessionDidStartRunningNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyCaptureFailure:) name:AVCaptureSessionRuntimeErrorNotification object:nil];
}

/*
 *  Return the device representing the back camera.
 */
+(AVCaptureDevice *) backCamera
{
    NSArray *arr = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *dev in arr) {
        if (dev.position == AVCaptureDevicePositionBack) {
            return dev;
        }
    }
    return nil;
}

/*
 *  Create the device and camera resources required for capture.
 */
-(BOOL) createAllSessionResourcesWithError:(NSError **) err
{
    if (session) {
        return YES;
    }
    
    devBackCamera = [[UIQRScanner backCamera] retain];
    if (!devBackCamera) {
        [CS_error fillError:err withCode:CSErrorQRCaptureFailure andFailureReason:@"Device not supported."];
        return NO;
    }
    
    session = [[AVCaptureSession alloc] init];
    
    NSError *tmp    = nil;
    inputBackCamera = [[AVCaptureDeviceInput alloc] initWithDevice:devBackCamera error:&tmp];
    if (tmp) {
        [self releaseAllSessionResources];
        [CS_error fillError:err withCode:CSErrorQRCaptureFailure andFailureReason:@"The back camera could not be accessed for scanning."];
        return NO;
    }
    
    // - attempt to make the camera easier to use
    if ([devBackCamera isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
        if ([devBackCamera lockForConfiguration:&tmp]) {
            devBackCamera.focusMode = AVCaptureFocusModeContinuousAutoFocus;
            
            if (devBackCamera.smoothAutoFocusSupported) {
                devBackCamera.smoothAutoFocusEnabled = YES;
            }

            // - don't attempt to auto-focus beyond the near stuff
            if (devBackCamera.autoFocusRangeRestrictionSupported) {
                devBackCamera.autoFocusRangeRestriction = AVCaptureAutoFocusRangeRestrictionNear;
            }
            
            [devBackCamera unlockForConfiguration];
        }
        else {
            NSLog(@"CS: Unable to lock the back camera for enhanced scanning configuration.  %@", [tmp localizedDescription]);
        }
    }
    
    [session beginConfiguration];
    [session addInput:inputBackCamera];
    
    plVideoPreview              = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    plVideoPreview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.layer insertSublayer:plVideoPreview below:vwVideoOverlay.layer];
    [session commitConfiguration];
    
    // - configure QR capture initially
    [self updateQRCaptureState];
    
    [self setNeedsLayout];
    return YES;
}

/*
 *  Release all the objects associated with the session.
 */
-(void) releaseAllSessionResources
{
    [self stopScanning];
    
    [session beginConfiguration];
    [plVideoPreview setSession:nil];
    [plVideoPreview removeFromSuperlayer];
    [plVideoPreview release];
    plVideoPreview = nil;
    
    [scanningProcessor setMetadataObjectsDelegate:nil queue:nil];
    [scanningProcessor setMetadataObjectTypes:[NSArray array]];
    [session removeOutput:scanningProcessor];
    [scanningProcessor release];
    scanningProcessor = nil;
    
    [session removeInput:inputBackCamera];
    [inputBackCamera release];
    inputBackCamera = nil;
    
    [devBackCamera release];
    devBackCamera = nil;
    [session commitConfiguration];
    
    [session release];
    session = nil;
}

/*
 *  This method is called whenever something is captured.
 */
-(void) captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    for (NSObject *obj in metadataObjects) {
        if ([obj isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) {
            AVMetadataMachineReadableCodeObject *mrco = (AVMetadataMachineReadableCodeObject *) obj;
            [self qrScanner:self didScanCode:mrco.stringValue];
        }
    }
}

/*
 *  The capture session started successfully.
 */
-(void) notifyCaptureStarted
{
    if (delegate && [delegate respondsToSelector:@selector(qrScannerDidStart:)]) {
        [delegate performSelector:@selector(qrScannerDidStart:)];
    }
}

/*
 *  A video capture failure occurred.
 */
-(void) notifyCaptureFailure:(NSNotification *) notification
{
    if (notification.userInfo) {
        NSError *err = [notification.userInfo objectForKey:AVCaptureSessionErrorKey];
        if (err) {
            [self qrScanner:self didFailWithError:err];
        }
    }
}

/*
 *  Add/remove QR capture to this object based on the activity state.
 */
-(void) updateQRCaptureState
{
    if (!session) {
        return;
    }
    
    // - safely assign the scanning processor to the session.
    [session beginConfiguration];
    if (!scanningProcessor) {
        scanningProcessor = [[AVCaptureMetadataOutput alloc] init];
        [session addOutput:scanningProcessor];
        
        [scanningProcessor setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
        [scanningProcessor setMetadataObjectTypes:[NSArray arrayWithObject:AVMetadataObjectTypeQRCode]];
    }
    
    // - turn the connections on/off to enable/disable QR interpretation.
    for (AVCaptureConnection *conn in scanningProcessor.connections) {
        conn.enabled = applyQRInterpretation;
    }
    [session commitConfiguration];
}
@end

