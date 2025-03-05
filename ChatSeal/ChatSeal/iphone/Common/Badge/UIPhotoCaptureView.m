//
//  UIPhotoCaptureView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 4/11/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CVPixelBuffer.h>
#import "UIPhotoCaptureView.h"
#import "CS_error.h"
#import "ChatSeal.h"

//  - to make it easy to adjust the quality
#define UIPCV_PHOTO_QUALITY AVCaptureSessionPresetMedium

// -  forward declarations
@interface UIPhotoCaptureView (internal) <AVCaptureVideoDataOutputSampleBufferDelegate>
-(BOOL) configureCameraQuality:(AVCaptureDevice *) dev;
-(AVCaptureDevice *) cameraForFront:(BOOL) isFront;
-(void) configureCameraAttributes;
-(void) setCameraEnabled:(BOOL) enabled;
-(void) sendDelegateAnError:(NSError *) err;
-(void) sendPhotoToDelegate:(UIImage *) img;
-(void) sendCameraNotReady;
-(UIImage *) correctImage:(UIImage *) img forDeviceOrientation:(UIDeviceOrientation) io andFrontCamera:(BOOL) isFront;
-(void) configureActiveCapture:(NSNumber *) toFrontCamera;
-(BOOL) setPrimaryCamera:(BOOL)isFront andDoItNow:(BOOL) isNow;
-(void) notifyError:(NSNotification *) notification;
-(CMSampleBufferRef) lastVideoSample;
-(void) setLastVideoSample:(CMSampleBufferRef) lvs;
@end

/***********************
 UIPhotoCaptureView
 ***********************/
@implementation UIPhotoCaptureView
/*
 *  Object attributes
 */
{
    BOOL                        isCapturing;
    BOOL                        frontIsPrimary;
    BOOL                        isCameraAvailable;
    AVCaptureSession            *captureSession;
    AVCaptureVideoPreviewLayer  *layerCameraPreview;
    AVCaptureVideoDataOutput    *videoOutput;
    AVCaptureStillImageOutput   *cameraOutput;
    BOOL                        canSaveFrames;    
    CMSampleBufferRef           lastVideoSample;
    UIDeviceOrientation         sampleOrientation;
}

@synthesize delegate;

/*
 *  Initialize the view.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self configureCameraAttributes];
    }
    return self;
}

/*
 *  Initialize the view.
 */
-(id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self configureCameraAttributes];
    }
    return self;
}


/*
 *  Free the view
 */
-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    delegate = nil;
    [videoOutput setSampleBufferDelegate:nil queue:NULL];
    
    [captureSession beginConfiguration];
    
    [layerCameraPreview removeFromSuperlayer];
    [layerCameraPreview release];
    layerCameraPreview = nil;
    
    [captureSession removeOutput:videoOutput];
    [videoOutput release];
    videoOutput = nil;
    
    [captureSession removeOutput:cameraOutput];
    [cameraOutput release];
    cameraOutput = nil;
    
    [captureSession commitConfiguration];
    
    [self setLastVideoSample:NULL];
    
    [captureSession release];
    captureSession = nil;
    
    [super dealloc];
}

/*
 *  Returns whether photos can be taken with a camera.
 */
-(BOOL) isPhotoCaptureAvailable
{
    return [self isFrontCameraAvailable] | [self isBackCameraAvailable];
}

/*
 *  Returns a flag indicating if a front camera is
 *  available for photo capture.
 */
-(BOOL) isFrontCameraAvailable
{
    if ([self cameraForFront:YES]) {
        return YES;
    }
    return NO;
}

/*
 *  Returns a flag indicating if a back camera is
 *  available for photo capture.
 */
-(BOOL) isBackCameraAvailable
{
    if ([self cameraForFront:NO]) {
        return YES;
    }
    return NO;
}

/*
 *  Returns the primary camera.
 */
-(BOOL) frontCameraIsPrimary
{
    return frontIsPrimary;
}

/*
 *  Change the camera used for image capture.
 */
-(BOOL) setPrimaryCamera:(BOOL) isFront
{
    return [self setPrimaryCamera:isFront andDoItNow:NO];
}

/*
 *  Enable/disable photo capture
 */
-(void) setCaptureEnabled:(BOOL) enabled
{
    if (![self isPhotoCaptureAvailable]) {
        return;
    }
    
    //  - don't start/stop needlessly.
    if (isCapturing == enabled) {
        return;
    }
    
    [self setCameraEnabled:enabled];
}

/*
 *  Returns whether the camera is currently capturing images.
 */
-(BOOL) isCaptureEnabled
{
    return isCapturing;
}

/*
 *  If photo capture is enabled, take a photo and make it current.
 */
-(BOOL) snapPhoto
{
    if (!isCapturing) {
        return NO;
    }
    
    AVCaptureConnection *capConn = nil;
    for (AVCaptureConnection *conn in cameraOutput.connections) {
        for (AVCaptureInputPort *port in [conn inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
                capConn = conn;
                break;
            }
        }
    }
    
    //  - attempt to capture an image from the active connection.
    [cameraOutput captureStillImageAsynchronouslyFromConnection:capConn completionHandler:
     ^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
         NSError *err = nil;
         if (error) {
             [CS_error fillError:&err withCode:CSErrorPhotoCaptureFailure andFailureReason:[error localizedDescription]];
             [self sendDelegateAnError:err];
             NSLog(@"CS: Failed to capture an image from the %s camera.  %@", frontIsPrimary ? "front" : "back", [error localizedDescription]);
             return;
         }
         
         @try {
             NSData *dPhoto = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
             UIImage *imgPhoto = [UIImage imageWithData:dPhoto];
             if (imgPhoto) {
                 imgPhoto = [self correctImage:imgPhoto forDeviceOrientation:[ChatSeal currentDeviceOrientation] andFrontCamera:frontIsPrimary];
                 [self performSelectorOnMainThread:@selector(sendPhotoToDelegate:) withObject:imgPhoto waitUntilDone:NO];
             }
             else {
                 [CS_error fillError:&err withCode:CSErrorPhotoCaptureFailure andFailureReason:@"Captured photo is an invalid image."];
                 [self sendDelegateAnError:err];
                 NSLog(@"CS: Captured photo is not a valid image.");
             }
         }
         @catch (NSException *exception) {
             [CS_error fillError:&err withCode:CSErrorPhotoCaptureFailure andFailureReason:[exception description]];
             [self sendDelegateAnError:err];
             NSLog(@"CS: Failed to convert the image to JPEG format.  %@", [exception description]);
         }
     }];
    return YES;
}

/*
 *  Retrieve an image for the last recorded video sample.
 *  - this is used to produce transitions when moving between the cameras mainly.
 */
-(UIImage *) imageForLastSample
{
    if (!lastVideoSample) {
        return NULL;
    }
    
    // Create a device-dependent RGB color space.
    static CGColorSpaceRef colorSpace = NULL;
    if (!colorSpace) {
        colorSpace = CGColorSpaceCreateDeviceRGB();
        if (!colorSpace) {
            NSLog(@"CS: Failed to create a color space for video frame conversion.");
            return nil;
        }
    }
    
    //  - grab the image and begin processing it.
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(lastVideoSample);
    
    // Lock the base address of the pixel buffer.
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer.
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    
    // Get the pixel buffer width and height.
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Get the base address of the pixel buffer.
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the data size for contiguous planes of the pixel buffer.
    size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer);
    
    // Create a Quartz direct-access data provider that uses data we supply.
    CGDataProviderRef dataProvider =
    CGDataProviderCreateWithData(NULL, baseAddress, bufferSize, NULL);
    
    // Create a bitmap image from data supplied by the data provider.
    CGImageRef cgImage = CGImageCreate(width, height, 8, 32, bytesPerRow,
                                       colorSpace, kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little,
                                       dataProvider, NULL, true, kCGRenderingIntentDefault);
    CGDataProviderRelease(dataProvider);
    
    // Create and return an image object to represent the Quartz image.
    UIImage *imageFrame = nil;
    if (cgImage) {
        //  - the orientation of the camera is offset by 90 degrees counter-clockwise
        UIImageOrientation ioRet = UIImageOrientationUp;
        switch (sampleOrientation) {
            case UIDeviceOrientationPortrait:
            default:
                ioRet = frontIsPrimary ? UIImageOrientationLeftMirrored : UIImageOrientationRight;
                break;
                
            case UIDeviceOrientationLandscapeRight:
                ioRet = frontIsPrimary ? UIImageOrientationUpMirrored : UIImageOrientationDown;
                break;
                
            case UIDeviceOrientationLandscapeLeft:
                ioRet = frontIsPrimary ? UIImageOrientationDownMirrored : UIImageOrientationUp;
                break;
                
            case UIDeviceOrientationPortraitUpsideDown:
                ioRet = frontIsPrimary ? UIImageOrientationRightMirrored : UIImageOrientationLeft;
                break;
        }
        
        imageFrame = [UIImage imageWithCGImage:cgImage scale:1.0f orientation:ioRet];
        CGImageRelease(cgImage);
    }
    else {
        NSLog(@"CS: Failed to create an image from the last video frame.");
    }
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    return imageFrame;
}

/*
 *  Do precise layout of this control
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    layerCameraPreview.frame = self.bounds;
}

/*
 *  Returns whether the camera is actively working.
 */
-(BOOL) isCameraUsable
{
    return isCameraAvailable;
}

@end

/*****************************
 UIPhotoCaptureView (internal)
 *****************************/
@implementation UIPhotoCaptureView (internal)
/*
 *  Set the standard quality parameters for a camera device.
 */
-(BOOL) configureCameraQuality:(AVCaptureDevice *) dev
{
    if (!dev) {
        return YES;
    }
    
    NSError *err = nil;
    if (![dev lockForConfiguration:&err]) {
        NSLog(@"CS: Failed to configure the %s camera.  %@", [dev position] == AVCaptureDevicePositionBack ? "back" : "front", [err localizedDescription]);
        return NO;
    }
    
    //  - the philosophy here is to provide a very efficient and high-quality way of producing seal
    //    photos without overcomplicating the process.  That means that excessive controls will be minimized
    //    and as much auto-adjustment as possible will be enabled by default.
    
    //  - autofocus
    if ([dev isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
        [dev setFocusPointOfInterest:CGPointMake(0.5f, 0.5f)];
        [dev setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
    }
    
    //  - auto-exposure
    if ([dev isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
        [dev setExposurePointOfInterest:CGPointMake(0.5f, 0.5f)];
        [dev setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
    }
    
    //  - auto-flash
    if ([dev isFlashModeSupported:AVCaptureFlashModeAuto]) {
        [dev setFlashMode:AVCaptureFlashModeAuto];
    }
    
    //  - white balance
    if ([dev isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
        [dev setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
    }
    
    [dev unlockForConfiguration];
    return YES;
}

/*
 *  Return the camera for the given position.
 */
-(AVCaptureDevice *) cameraForFront:(BOOL) isFront
{
    for (AVCaptureDevice *dev in [AVCaptureDevice devices]) {
        if (![dev hasMediaType:AVMediaTypeVideo]) {
            continue;
        }
        if (!isFront && [dev position] == AVCaptureDevicePositionBack) {
            return dev;
        }
        else if (isFront && [dev position] == AVCaptureDevicePositionFront) {
            return dev;
        }
    }
    return nil;
}

/*
 *  Set up the camera support for taking photos.
 */
-(void) configureCameraAttributes
{
    //  - camera attribute configuration
    captureSession     = nil;
    layerCameraPreview = nil;
    videoOutput        = nil;
    cameraOutput       = nil;
    sampleOrientation  = UIDeviceOrientationPortrait;
    lastVideoSample    = NULL;
    canSaveFrames      = NO;
    
    //  - after the cameras are set up, their existence
    //    will be determined by these two attributes.
    frontIsPrimary              = YES;
    isCapturing                 = NO;
    isCameraAvailable           = NO;
    self.clipsToBounds          = YES;
    
    // - if we have no cameras, nothing to do.
    BOOL hasFront = NO;
    if ([self cameraForFront:YES]) {
        hasFront = YES;
    }
    
    if (!hasFront && ![self cameraForFront:NO]) {
        return;
    }
    
    //  - when there is only a back camera, the back is
    //    made primary.
    if (!hasFront) {
        frontIsPrimary = NO;
    }
    
    //  - start by creating a session
    captureSession = [[AVCaptureSession alloc] init];
    
    //  - and the preview for the content.
    //  - since mirroring isn't well supported (my front camera does not support it), we'll always
    //    apply a transform to the preview layer to ensure the output looks as it should
    AVCaptureVideoPreviewLayer *vpl = [[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession];
    vpl.videoGravity                = AVLayerVideoGravityResizeAspectFill;
    vpl.doubleSided                 = YES;
    layerCameraPreview    = vpl;
    [self.layer addSublayer:vpl];
    
    //  - the delegate to watch video
    AVCaptureVideoDataOutput *vdo     = [[AVCaptureVideoDataOutput alloc] init];
    vdo.videoSettings                 = nil;
    vdo.alwaysDiscardsLateVideoFrames = YES;
    [vdo setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    [captureSession addOutput:vdo];
    videoOutput                       = vdo;
    
    //  - and the output object.
    AVCaptureStillImageOutput *sio    = [[AVCaptureStillImageOutput alloc] init];
    sio.outputSettings                = [NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecJPEG, AVVideoCodecKey, nil];
    [captureSession addOutput:sio];
    cameraOutput                      = sio;
    
    //  - make sure we keep up with notifications about how the camera is doing.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyError:) name:AVCaptureSessionRuntimeErrorNotification object:nil];
}

/*
 *  Turn the camera on/off
 */
-(void) setCameraEnabled:(BOOL) enabled
{
    isCapturing = enabled;
    if (isCapturing) {
        [self setPrimaryCamera:frontIsPrimary andDoItNow:YES];
        [captureSession startRunning];
    }
    else {
        if (isCameraAvailable) {
            isCameraAvailable = NO;
            [self sendCameraNotReady];
        }
        [captureSession stopRunning];
    }
    [CATransaction commit];
}

/*
 *  If the delegate will receive error notifications, send one now.
 */
-(void) sendDelegateAnError:(NSError *) err
{
    if (delegate && [delegate respondsToSelector:@selector(photoView:failedWithError:)]) {
        [delegate performSelector:@selector(photoView:failedWithError:) withObject:self withObject:err];
    }
}

/*
 *  Send the delegate a captured photo.
 */
-(void) sendPhotoToDelegate:(UIImage *) img
{
    if (delegate && [delegate respondsToSelector:@selector(photoView:snappedPhoto:)]) {
        [delegate performSelector:@selector(photoView:snappedPhoto:) withObject:self withObject:img];
    }
}

/*
 *  Send a not ready notification.
 */
-(void) sendCameraNotReady
{
    if (delegate && [delegate respondsToSelector:@selector(photoViewCameraNotReady:)]) {
        [(NSObject *) delegate performSelectorOnMainThread:@selector(photoViewCameraNotReady:) withObject:self waitUntilDone:YES];
    }
}

/*
 *  The only purpose of this method is to notify the owner that the camera is available.
 */
-(void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    //  - if it is possible to save frames, do so now
    //    to improve the camera flipping experience.
    if (canSaveFrames) {
        [self setLastVideoSample:sampleBuffer];
        sampleOrientation = [ChatSeal currentDeviceOrientation];
    }
    
    //  - only notify the delegate when the availability
    //    first changes.
    if (isCameraAvailable) {
        return;
    }

    //  - notify the delegate of the change
    if (delegate && [delegate respondsToSelector:@selector(photoViewCameraReady:)]) {
        [(NSObject *) delegate performSelectorOnMainThread:@selector(photoViewCameraReady:) withObject:self waitUntilDone:NO];
    }
    isCameraAvailable = YES;
    
    //  - make sure the preview window is updated that firs time
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [CATransaction commit];
}

/*
 *  Images captured with the camera have to be adjusted to ensure the right orientation 
 *  is conveyed.
 */
-(UIImage *) correctImage:(UIImage *) img forDeviceOrientation:(UIDeviceOrientation) dio andFrontCamera:(BOOL) isFront
{
    if (!img) {
        return nil;
    }
    
    switch (dio) {
        case UIDeviceOrientationPortrait:
        default:
            img = [UIImage imageWithCGImage:[img CGImage] scale:img.scale orientation:UIImageOrientationRight];
            break;
            
        case UIDeviceOrientationLandscapeRight:
            img = [UIImage imageWithCGImage:[img CGImage] scale:img.scale orientation:isFront ? UIImageOrientationUp : UIImageOrientationDown];
            break;
            
        case UIDeviceOrientationLandscapeLeft:
            img = [UIImage imageWithCGImage:[img CGImage] scale:img.scale orientation:isFront ? UIImageOrientationDown : UIImageOrientationUp];
            break;
            
        case UIDeviceOrientationPortraitUpsideDown:
            img = [UIImage imageWithCGImage:[img CGImage] scale:img.scale orientation:UIImageOrientationLeft];
            break;
    }
    
    // - this works better with the preview when we just apply the transforms right now.
    UIGraphicsBeginImageContextWithOptions(img.size, YES, img.scale);
    [img drawAtPoint:CGPointZero];
    img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return img;
}

/*
 *  Add the appropriate device for capture.
 */
-(void) configureActiveCapture:(NSNumber *) toFrontCamera
{
    [captureSession beginConfiguration];
    
    //  - remove the old inputs.
    for (AVCaptureInput *input in captureSession.inputs) {
        [captureSession removeInput:input];
    }
    
    // - and add the new one...
    AVCaptureDevice *capDev = [self cameraForFront:[toFrontCamera boolValue]];
    if (capDev && [self configureCameraQuality:capDev]) {
        NSError *err = nil;
        AVCaptureInput *capInput = [AVCaptureDeviceInput deviceInputWithDevice:capDev error:&err];
        if (capInput) {
            [captureSession addInput:capInput];
            
            //  - make sure that the session produces the best possible image.
            if ([captureSession canSetSessionPreset:UIPCV_PHOTO_QUALITY]) {
                captureSession.sessionPreset = UIPCV_PHOTO_QUALITY;
            }

            //  - this flag is only useful with the back camera, but makes a big difference
            //    as the device is rotated.  The image gets all out of whack when it isn't
            //    applied.
            //  - I originially thought that doing this with transforms was the right choice, but
            //    that has proven problematic and produces really bad realtime effects.
            if (layerCameraPreview.connection.supportsVideoMirroring) {
                layerCameraPreview.connection.automaticallyAdjustsVideoMirroring = YES;
            }
            
            canSaveFrames = NO;
            for (NSNumber *nCurFmt in videoOutput.availableVideoCVPixelFormatTypes) {
                if ([nCurFmt intValue] == kCVPixelFormatType_32BGRA) {
                    canSaveFrames = YES;
                    videoOutput.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                                                                                      forKey:(NSString *) kCVPixelBufferPixelFormatTypeKey];
                }
            }
        }
        else {
            NSLog(@"CS: Failed to configure a capture input device.  %@", [err localizedDescription]);
            [self sendDelegateAnError:err];
        }
    }
    [captureSession commitConfiguration];
}

/*
 *  Change the primary camera used for capture.
 */
-(BOOL) setPrimaryCamera:(BOOL)isFront andDoItNow:(BOOL) isNow
{
    if (isFront) {
        if (![self isFrontCameraAvailable]) {
            return NO;
        }
    }
    else {
        if (![self isBackCameraAvailable]) {
            return NO;
        }
    }
    
    // - configure the inputs if we're capturing
    // - (but do it asynchronously to not delay things)
    if (isCapturing) {
        isCameraAvailable = NO;
        [self sendCameraNotReady];
        if (isNow) {
            [self configureActiveCapture:[NSNumber numberWithBool:isFront]];
        }
        else {
            [self performSelector:@selector(configureActiveCapture:) withObject:[NSNumber numberWithBool:isFront] afterDelay:0.1f];
        }
    }
    
    // - update the current camera flag
    frontIsPrimary = isFront;
    return YES;
}

/*
 *  This is sent when the av capture device fails asynchronously.
 */
-(void) notifyError:(NSNotification *)notification
{
    if (notification && notification.userInfo) {
        NSError *err = [notification.userInfo objectForKey:AVCaptureSessionErrorKey];
        if (!err) {
            [CS_error fillError:&err withCode:CSErrorPhotoCaptureFailure];
        }
        [self sendDelegateAnError:err];
    }
}

/*
 *  Return the last sample recovered.
 */
-(CMSampleBufferRef) lastVideoSample
{
    return lastVideoSample;
}

/*
 *  We need to handle this ourselves to make sure retention is done
 *  right.
 */
-(void) setLastVideoSample:(CMSampleBufferRef) lvs
{
    if (lastVideoSample) {
        CFRelease(lastVideoSample);
        lastVideoSample = NULL;
    }
    
    if (lvs) {
        CMSampleBufferCreateCopy(NULL, lvs, (CMSampleBufferRef *) &lastVideoSample);
    }
}

@end
