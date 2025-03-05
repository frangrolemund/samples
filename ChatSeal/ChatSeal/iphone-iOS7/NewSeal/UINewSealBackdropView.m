//
//  UINewSealBackdropView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/3/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UINewSealBackdropView.h"
#import "UIPhotoCaptureView.h"
#import "ChatSeal.h"
#import "UIImageGeneration.h"

//  - constants
static const CGFloat            UINSB_STD_SCREENSHOT_SCALE    = 0.15f;
static const CGFloat            UINSB_STD_SNAP_TIME           = 0.45f;
static const ps_frost_style_t   UINSB_STD_FROST_STYLE         = CS_FS_SIMPLE_BLUR;
static const CGFloat            UINSB_STD_MAX_SIDE            = 1024.0f;

// - make sure we can configure the superview
@interface UISealClippingContainer (internal)
-(void) configure;
@end

// - forward declarations
@interface UINewSealBackdropView (internal) <UIPhotoCaptureViewDelegate, UISealImageViewV2Delegate>
-(void) configure;
-(void) setPhotoCaptureVisible:(BOOL) isVisible;
-(NSOperation *) opFrom;
-(void) setOpFrom:(NSOperation *) op;
-(NSOperation *) opTo;
-(void) setOpTo:(NSOperation *) op;
-(void) snapFromTransitionImageAsAsync:(BOOL) async;
-(void) setFromTransitionImage:(UIImage *) image asAsync:(BOOL) async;
-(void) transitionToImage:(UIImage *) image asAsync:(BOOL) async withCompletion:(void(^)(void)) completionBlock;
-(void) setEditingEnabled:(BOOL) isEditing;
-(CGFloat) scaleForTransitionOfImage:(UIImage *) img;
-(void) transitionTimerCheck;
-(void) snapFromTransitionFromCamera;
-(void) beginTransitioning;
-(void) midTransition;
-(void) endTransitioning;
-(void) buildCameraIfNecessary;
@end

/******************************
 UINewSealBackdropView
 ******************************/
@implementation UINewSealBackdropView
/*
 *  Object attributes
 */
{
    UIPhotoCaptureView  *camera;
    BOOL                firstCameraUse;
    BOOL                usingCamera;
    UIImageView         *fromTransition;
    UIImageView         *toTransition;
    NSOperation         *opFrom;
    NSOperation         *opTo;
    BOOL                isExtending;
    BOOL                isTransitioning;
    NSTimer             *transitionTimer;
    NSUInteger          lastEditVersion;
    BOOL                isSnappingFromImage;
    BOOL                hasAppearedOnce;
    UIView              *vwSnapFlash;
}

@synthesize delegate;

/*
 *  Free the object.
 */
-(void) dealloc
{
    self.sealImageView.delegate = nil;
    delegate = nil;
    [self setOpFrom:nil];
    [self setOpTo:nil];
    
    [camera setCaptureEnabled:NO];
    camera.delegate = nil;
    [camera release];
    camera = nil;
    
    [fromTransition release];
    fromTransition = nil;
    
    [toTransition release];
    toTransition = nil;
    
    [vwSnapFlash release];
    vwSnapFlash = nil;
    
    [super dealloc];
}

/*
 *  Assign the original seal image to the view.
 */
-(void) setSealImage:(UIImage *) image withAnimation:(BOOL) animated
{
    void(^transitionWork)(void) = ^(void) {
        [super setSealImage:image];
        [camera setCaptureEnabled:NO];
        usingCamera = NO;
        [self setPhotoCaptureVisible:NO];
        [self setEditingEnabled:image ? YES : NO];
    };
    
    // - we don't want to allow ridiculous-sized seal images because that will blow our memory, so
    //   whatever we get we must optionally scale down.
    // - seal images with background transparency need to be applied to a white background
    //   because all of our design assumes the seals will be shown on white.  Transparent seals
    //   will mess with that.
    if (image) {
        CGSize szNewImage = image.size;
        if (szNewImage.width > UINSB_STD_MAX_SIDE || szNewImage.height > UINSB_STD_MAX_SIDE) {
            CGFloat bigger     = MAX(szNewImage.width, szNewImage.height);
            CGFloat scale      = UINSB_STD_MAX_SIDE/bigger;
            szNewImage.width  *= scale;
            szNewImage.height *= scale;
        }
        
        UIGraphicsBeginImageContextWithOptions(szNewImage, YES, image.scale);
        [[UIColor whiteColor] setFill];
        UIRectFill(CGRectMake(0.0f, 0.0f, szNewImage.width, szNewImage.height));
        [image drawInRect:CGRectMake(0.0f, 0.0f, szNewImage.width, szNewImage.height)];
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    
    // - don't animate if there's really not much changing.
    if ((!image && ![self hasSealImage]) || !animated) {
        [self beginTransitioning];
        transitionWork();
        [self midTransition];
        [self endTransitioning];
    }
    else {
        // - make sure the image is scaled because we don't need a huge
        //   transition image.     
        [self transitionToImage:image asAsync:YES withCompletion:transitionWork];
    }
}

/*
 *  Returns whether a seal image exists in the backdrop.
 */
-(BOOL) hasSealImage
{
    return [self.sealImageView hasSealImage];
}

/*
 *  Return a properly-sized seal image generated from the input.
 */
-(UIImage *) generateMinimalSealImage
{
    return [self.sealImageView standardizedSealImage];
}

/*
 *  This method indicates whether a camera exists for taking photos.
 */
-(BOOL) hasCameraSupport
{
    return [camera isPhotoCaptureAvailable];
}

/*
 *  This method indicates whether the camera can be flipped.
 */
-(BOOL) canFlipCamera
{
    return [camera isFrontCameraAvailable] && [camera isBackCameraAvailable];
}

/*
 *  Flip to the other camera.
 */
-(void) flipCamera
{
    if (!usingCamera || isExtending) {
        return;
    }
    
    [self beginTransitioning];
    toTransition.image = nil;
    [camera setCaptureEnabled:NO];
    [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void){
        fromTransition.alpha = 1.0f;
    } completion:^(BOOL finished){
        [camera setPrimaryCamera:![camera frontCameraIsPrimary]];
        [camera setCaptureEnabled:YES];
    }];
}

/*
 *  When the camera is enabled, this method will take a photo.
 */
-(void) snapPhoto
{
    if (isTransitioning) {
        return;
    }
    
    [UIView animateWithDuration:UINSB_STD_SNAP_TIME delay:0.0f options:UIViewAnimationOptionCurveEaseIn animations:^(void) {
        vwSnapFlash.alpha = 1.0f;
    } completion:nil];
    
    [camera snapPhoto];
}

/*
 *  If the camera is available, this method will show it.
 */
-(void) switchToCamera
{
    if (![camera isPhotoCaptureAvailable] || [camera isCaptureEnabled]) {
        return;
    }
    
    //  - figure out the best way to switch over.
    BOOL useFront = NO;
    if (firstCameraUse) {
        firstCameraUse = NO;
        useFront = YES;
    }
        
    //  - if the backdrop is being animated, don't
    //    show the camera until that completes.
    usingCamera = YES;
    if (isExtending) {
        return;
    }

    //  - the transition is very efficient - basically show the
    //    from transition, show the camera and then fade the from transition
    [self beginTransitioning];
    toTransition.image = nil;
    [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void){
        fromTransition.alpha = 1.0f;
    } completion:^(BOOL finished){
        [self midTransition];
        
        //  - and do the setup
        //  - when the camera comes online, we'll complete the process.
        //  - turning on camera capture is completely synchronous, so it is
        //    best to do it once the from-transition view is visible.
        [camera setPrimaryCamera:useFront ? YES : [camera frontCameraIsPrimary]];
        [camera setCaptureEnabled:YES];
    }];
}

/*
 *  Indicates whether the camera is in use.
 */
-(BOOL) isCameraActive
{
    return usingCamera;
}

/*
 *  Indicates whether the camera is actually displaying content.
 */
-(BOOL) isCameraUsable
{
    return [camera isCameraUsable];
}

/*
 *  Move over to the seal display.
 */
-(void) switchToSealWithCompletion:(void(^)())completionBlock
{
    if (!usingCamera) {
        return;
    }
    
    [camera setCaptureEnabled:NO];
    usingCamera = NO;
    
    //  - when not already transitioning, ease into the seal display.
    if (!isTransitioning) {
        // - moving to the seal should fade the seal's contents
        [self snapFromTransitionImageAsAsync:NO];
        
        // - begin the transition.
        [self beginTransitioning];
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            fromTransition.alpha = 1.0f;
        } completion:^(BOOL finished){
            [self midTransition];
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                fromTransition.alpha = 0.0f;
            } completion:^(BOOL finished2){
                if (completionBlock) {
                    completionBlock();
                }
                [self endTransitioning];
            }];
        }];
    }
}

/*
 *  Shift into an extended view for the backdrop.
 *  - we hook this so that we can coordinate the presentation of the camera with the extended view 
 *    becoming visible.
 */
-(void) setExtendedView:(BOOL)isExtended withAnimation:(BOOL)isAnimated andCompletion:(void (^)(void))completionBlock
{
    // - common behavior regardless of which direction.
    void (^superExtension)(void) = ^(void) {
        [super setExtendedView:isExtended withAnimation:isAnimated andCompletion:^(void){
            if (completionBlock) {
                completionBlock();
            }
            
            isExtending = NO;
            
            //  - if the view was extending while the camera was being
            //    configured, switch over now.
            if (usingCamera && ![camera isCaptureEnabled]) {
                [self switchToCamera];
            }            
        }];
    };
    
    //  Either extend or contract.
    if (isExtended) {
        isExtending = YES;
        superExtension();
    }
    else {
        superExtension();
    }
}

/*
 *  Turn the timer on/off based on parentage because we need to ensure
 *  that it doesn't hold a reference to this view.
 */
- (void)willMoveToSuperview:(UIView *)newSuperview
{
    [super willMoveToSuperview:newSuperview];
    
    if (newSuperview) {
        if (!transitionTimer) {
            //  - this timer ensures we always have a good 'from-transition' image
            transitionTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(transitionTimerCheck) userInfo:nil repeats:YES] retain];
        }
    }
    else {
        [transitionTimer invalidate];
        [transitionTimer release];
        transitionTimer = nil;
    }
}

/*
 *  This is called by the primary view controller when the overall view has appeared
 */
-(void) viewDidAppear
{
    // - do some one-time setup that is slightly expensive and will delay the
    //   window opening.
    if (!hasAppearedOnce) {
        //  - create the camera.
        [self buildCameraIfNecessary];
        hasAppearedOnce = YES;
    }
    
    // - if the camera was previously enabled, reenable it.
    if (usingCamera) {
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void){
            fromTransition.alpha = 1.0f;
        } completion:^(BOOL finished){
            [camera setCaptureEnabled:YES];
        }];
    }
}

/*
 *  This is called by the primary view when the overall view has disappeared.
 */
-(void) viewDidDisappear
{
    // - disable the camera when we disappear to save on 
    if (usingCamera) {
        [camera setCaptureEnabled:NO];
        [self snapFromTransitionFromCamera];
    }
}

/*
 *  Rotate the elements in this view to keep them in synch with the person
 *  using the device.
 */
-(void) setDisplayRotation:(CGFloat) rotation withAnimation:(BOOL) animated
{   
    CGAffineTransform atRotate = CGAffineTransformMakeRotation(rotation);
    
    // - transform the main display views in the backdrop to match the rotation.
    void (^transformWork)(void) = ^(void) {
        fromTransition.transform     = atRotate;
        toTransition.transform       = atRotate;
        self.sealImageView.transform = atRotate;
        self.addPhotoView.transform  = atRotate;
    };
    
    // - the camera manages its own transform, so don't apply one to it.
    camera.transform = CGAffineTransformIdentity;
    if (animated) {
        [UIView animateWithDuration:[ChatSeal standardRotationTime] delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:transformWork completion:nil];
    }
    else {
        transformWork();
    }
}

/*
 *  Returns whether the front camera is the primary one.
 */
-(BOOL) isFrontCameraActive
{
    return [self isCameraActive] && [camera frontCameraIsPrimary];
}

/*
 *  We need to get ready to go into the background.
 */
-(void) prepareForBackground
{
    // - NOTE: I learned there is an assertion that fires in the AV library when
    //         restrictions are changed with outstanding handles and they are then
    //         released.   In order to prevent this kind of madness, I'm going
    //         always discard the camera when moving to the background.
    camera.delegate = nil;
    [camera setCaptureEnabled:NO];
    [camera removeFromSuperview];
    [camera release];
    camera = nil;
    usingCamera = NO;
}

/*
 *  We just entered the foreground.
 */
-(void) resumeForeground
{
    [self buildCameraIfNecessary];
    if (self.sealImageView.hidden) {
        camera.hidden = NO;
    }
}
@end

/**********************************
 UINewSealBackdropView (internal)
 **********************************/
@implementation UINewSealBackdropView (internal)
/*
 *  Configure the view.
 */
-(void) configure
{
    [super configure];
    
    delegate                    = nil;
    firstCameraUse              = YES;
    usingCamera                 = NO;
    isExtending                 = NO;
    isTransitioning             = NO;
    self.sealImageView.delegate = self;
    lastEditVersion             = 0;
    isSnappingFromImage         = NO;
    hasAppearedOnce             = NO;
    self.backgroundColor        = [UIColor clearColor];
             
    //  - the 'to-transition' has to be before the from in the hierarchy so that we
    //    always fade out of the 'from' and into the 'to' and then into the real content.
    toTransition = [[UIImageView alloc] initWithFrame:self.contentView.bounds];
    toTransition.backgroundColor = [UIColor clearColor];
    toTransition.alpha = 0.0f;
    toTransition.contentMode = UIViewContentModeScaleAspectFill;
    toTransition.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.contentView addSubview:toTransition];
    
    fromTransition = [[UIImageView alloc] initWithFrame:self.contentView.bounds];
    fromTransition.backgroundColor = [UIColor clearColor];
    fromTransition.alpha = 0.0f;
    fromTransition.contentMode = UIViewContentModeScaleAspectFill;
    fromTransition.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.contentView addSubview:fromTransition];
    
    // - the snapflash view is used as a visual indicator when the photo is taken.
    vwSnapFlash = [[UIView alloc] initWithFrame:self.contentView.bounds];
    vwSnapFlash.autoresizingMask       = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;    
    vwSnapFlash.backgroundColor        = [UIColor colorWithWhite:1.0f alpha:0.25f];
    vwSnapFlash.alpha                  = 0.0f;
    vwSnapFlash.userInteractionEnabled = NO;
    [self.contentView addSubview:vwSnapFlash];
    
    [self setPhotoCaptureVisible:NO];
}

/*
 *  Show/hide the dependent views.
 */
-(void) setPhotoCaptureVisible:(BOOL) isVisible
{
    //  - brute force for now.
    camera.hidden             = !isVisible;
    camera.alpha              = isVisible ? 1.0f : 0.0f;
    self.sealImageView.hidden = isVisible;
}

/*
 *  This method is called when a photo capture failure occurs.
 */
-(void) photoView:(UIPhotoCaptureView *)pv failedWithError:(NSError *)err
{
    if (delegate && [delegate respondsToSelector:@selector(backdropView:cameraFailedWithError:)]) {
        [delegate performSelector:@selector(backdropView:cameraFailedWithError:) withObject:self withObject:err];
    }
}

/*
 *  This method is called when a photo is taken.
 */
-(void) photoView:(UIPhotoCaptureView *)pv snappedPhoto:(UIImage *)img
{
    [UIView animateWithDuration:UINSB_STD_SNAP_TIME delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
        vwSnapFlash.alpha = 0.0f;
    } completion:nil];
    
    if (delegate && [delegate respondsToSelector:@selector(backdropView:snappedPhoto:)]) {
        [delegate performSelector:@selector(backdropView:snappedPhoto:) withObject:self withObject:img];
    }
}

/*
 *  This method is called when the camera is temporarily unavailable.
 */
-(void) photoViewCameraNotReady:(UIPhotoCaptureView *)pv
{
    if (delegate && [delegate respondsToSelector:@selector(backdropViewCameraNotReady:)]) {
        [delegate performSelector:@selector(backdropViewCameraNotReady:) withObject:self];
    }
}

/*
 *  This method is called when the camera is ready to take a photo.
 */
-(void) photoViewCameraReady:(UIPhotoCaptureView *)pv
{
    // - just fade out the from transition.
    [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void){
        fromTransition.alpha = 0.0f;
    } completion:^(BOOL finished){
        fromTransition.image = nil;
        [self endTransitioning];
    }];
    
    // - attempt to save the first image for next time.
    [self snapFromTransitionFromCamera];

    // - let the delegate know what happened.
    if (delegate && [delegate respondsToSelector:@selector(backdropViewCameraReady:)]) {
        [delegate performSelector:@selector(backdropViewCameraReady:) withObject:self];
    }
}

/*
 *  Return the current from-transition operation.
 */
-(NSOperation *) opFrom
{
    return [[opFrom retain] autorelease];
}

/*
 *  Set a new from-transition operation.
 */
-(void) setOpFrom:(NSOperation *) op
{
    if (opFrom != op) {
        [opFrom cancel];
        [opFrom release];
        opFrom = [op retain];
    }
}

/*
 *  Return the current to-transition operation.
 */
-(NSOperation *) opTo
{
    return [[opTo retain] autorelease];
}

/*
 *  Set a new to-transition operation.
 */
-(void) setOpTo:(NSOperation *) op
{  
    if (opTo != op) {
        [opTo cancel];
        [opTo release];
        opTo = [op retain];
    }
}

/*
 *  Snap an image to use in the 'from' transition.
 */
-(void) snapFromTransitionImageAsAsync:(BOOL) async
{
    if (isSnappingFromImage || (opFrom && ![opFrom isCancelled])) {
        return;
    }
    
    if (CGRectGetWidth(self.contentView.bounds) < 1.0f || CGRectGetHeight(self.contentView.bounds) < 1.0f) {
        return;
    }
    
    isSnappingFromImage = YES;
    
    fromTransition.hidden = YES;
    toTransition.hidden   = YES;
    BOOL camHidden = camera.hidden;
    camera.hidden         = YES;
    
    UIImage *image = nil;
    if ([self hasSealImage]) {
        BOOL sealImageHidden      = self.sealImageView.hidden;
        self.sealImageView.hidden = NO;
        image                     = [UIImageGeneration imageFromView:self.sealImageView withScale:UINSB_STD_SCREENSHOT_SCALE];
        self.sealImageView.hidden = sealImageHidden;
    }
    else {
        image = [UIImageGeneration imageFromView:self.contentView withScale:UINSB_STD_SCREENSHOT_SCALE];
    }
    
    fromTransition.hidden = NO;
    toTransition.hidden   = NO;
    camera.hidden         = camHidden;
        
    [self setFromTransitionImage:image asAsync:async];
    isSnappingFromImage = NO;
}

/*
 *  Assign an image to use in the 'from' transition.
 */
-(void) setFromTransitionImage:(UIImage *) image asAsync:(BOOL) async
{
    CGFloat scale = [self scaleForTransitionOfImage:image];
    if (async) {
        // - don't overburden this process.
        if (self.opFrom && ![self.opFrom isCancelled]) {
            return;
        }
        
        self.opFrom = nil;
        self.opFrom = [ChatSeal generateFrostedImageOfType:UINSB_STD_FROST_STYLE
                                                    fromImage:image
                                                      atScale:scale
                                               withCompletion:^(UIImage *imgFrosted){
                                                     if (imgFrosted) {
                                                         if (!isTransitioning) {
                                                             fromTransition.image = imgFrosted;
                                                         }
                                                     }
                                                     self.opFrom = nil;
                                                 }];
    }
    else {
        image = [ChatSeal generateFrostedImageOfType:UINSB_STD_FROST_STYLE fromImage:image atScale:scale];
        if (image) {
            fromTransition.image = image;
        }
    }
}

/*
 *  Animate a transition between one image and the next.
 */
-(void) transitionToImage:(UIImage *) image asAsync:(BOOL) async withCompletion:(void(^)(void)) completionBlock
{
    //  - these transitions are really murky, and intentionally so.  First we're going to fade into the from transition
    //    view since that is alredy done.  Then we'll generate the to-image and fade into the to-transition view, while fading
    //    away from the from-transition view.  Then we'll fade out the to-image view to hopefully show the result underneath.
    [self beginTransitioning];
    NSTimeInterval fadeTime    = [ChatSeal standardItemFadeTime];
    toTransition.image         = nil;
    toTransition.alpha         = 0.0f;
    
    BOOL fullTransition        = [self hasSealImage];
    
    // - the last step of image transition
    void(^finalizeTransition)() = ^(){
        //  - fade out of the 'from' transition and into the 'to' transition.
        [UIView animateWithDuration:fadeTime animations:^(void){
            fromTransition.alpha = 0.0f;
        }];
        
        if (completionBlock) {
            completionBlock();
        }
        
        // - this has to occur after the completion block here.
        [self midTransition];
        
        [UIView animateWithDuration:fadeTime * 2.5f animations:^(void){
            toTransition.alpha = 0.0f;
        } completion:^(BOOL finished){
            fromTransition.image = toTransition.image;
            toTransition.image = nil;
            [self endTransitioning];
            self.opTo = nil;
        }];
    };
    
    // - whether async or not, we'll be processing the image.
    void(^processFrostedImage)(UIImage *imageFrosted) = ^(UIImage *imageFrosted) {
        toTransition.image = imageFrosted;
        if (fullTransition) {
            toTransition.alpha = 1.0f;
            finalizeTransition();
        }
        else {
            [UIView animateWithDuration:fadeTime animations:^(void) {
                toTransition.alpha = 1.0f;
            } completion:^(BOOL finished) {
                finalizeTransition();
            }];
        }
    };
    
    //  - whether we are moving from the starting transition image or not, the
    //    behavior is the same.
    CGFloat scale = [self scaleForTransitionOfImage:image];
    void(^fadeToTransition)(BOOL finished) = ^(BOOL finished) {
        self.opTo = nil;
        if (async) {
            self.opTo = [ChatSeal generateFrostedImageOfType:UINSB_STD_FROST_STYLE fromImage:image atScale:scale withCompletion:processFrostedImage];
        }
        else {
            UIImage *img = [ChatSeal generateFrostedImageOfType:UINSB_STD_FROST_STYLE fromImage:image atScale:scale];
            processFrostedImage(img);
        }
    };
    
    //  - initiate the process.
    if (fullTransition) {
        [UIView animateWithDuration:fadeTime * 2 animations:^(void) {
            fromTransition.alpha = 1.0f;
        } completion:fadeToTransition];
    }
    else {
        fadeToTransition(YES);
    }
}

/*
 *  Turn editing on/off in the seal image view.
 */
-(void) setEditingEnabled:(BOOL) isEditing
{
    [self.sealImageView setEditingEnabled:isEditing];
}

/*
 *  Return a scale that is appropriate to scale the given image for transition purposes.
 */
-(CGFloat) scaleForTransitionOfImage:(UIImage *) img
{
    // - the idea is to get an image that ends up looking pretty good but isn't too
    //   big that it slows the blurring process down.
    CGFloat imageLongSide = img.size.width;
    if (imageLongSide < img.size.height) {
        imageLongSide = img.size.height;
    }
    imageLongSide *= img.scale;
    if (imageLongSide < 1.0f) {
        return 1.0f;
    }
    
    //  ...this view is always a square, so the minimum dimension on the screen is reasonable.
    CGFloat screenShortSide = self.bounds.size.width;
    if (screenShortSide > self.bounds.size.height) {
        screenShortSide = self.bounds.size.height;
    }
    screenShortSide *= [UIScreen mainScreen].scale;
    
    //  ...just accomodate something that is nearly the dimension of the screen
    CGFloat scale = ((screenShortSide * UINSB_STD_SCREENSHOT_SCALE)/imageLongSide);
    if (scale > 1.0f) {
        scale = 1.0f;
    }
    return scale;
}

/*
 *  Whenever the seal image is changed, this method fires.
 */
-(void) sealImageWasModified:(UISealImageViewV2 *)siv
{
    // - don't check for transitions when we're in the middle of modifications.
    [transitionTimer setFireDate:[NSDate dateWithTimeInterval:1.0f sinceDate:[NSDate date]]];
}

/*
 *  Ensure that modifications to the seal force updates to the transitions.
 */
-(void) transitionTimerCheck
{
    if (!transitionTimer || isExtending || ![self isExtended]) {
        return;
    }

    // - if we're using video, always grab a frame
    if (usingCamera) {
        // - only grab frames when the video is on.
        if ([camera isCameraUsable]) {
            [self snapFromTransitionFromCamera];
        }
    }
    else {
        // - otherwise, use the edit version as a metric.
        NSUInteger curEditVersion = self.sealImageView.editVersion;
        if (curEditVersion != lastEditVersion) {
            [self snapFromTransitionImageAsAsync:YES];
            lastEditVersion = curEditVersion;
        }
    }
}

/*
 *  Grab an image from the camera and use it for a from-transition.
 */
-(void) snapFromTransitionFromCamera
{
    UIImage *img = [camera imageForLastSample];
    if (img) {
        // - make an immediate copy because that image will
        //   disappear in a moment and can't be sent to a background queue.
        UIGraphicsBeginImageContextWithOptions(img.size, YES, img.scale);
        [img drawAtPoint:CGPointZero];
        UIImage *imgConverted = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        [self setFromTransitionImage:imgConverted asAsync:YES];
    }
}

/*
 *  Start transitioning between two states.
 */
-(void) beginTransitioning
{
    isTransitioning = YES;
}

/*
 *  This part of the transition occurs
 *  when the fromTransition view is fully visible.
 */
-(void) midTransition
{
    [self setPhotoCaptureVisible:usingCamera];
}

/*
 *  Complete a transition.
 */
-(void) endTransitioning
{
    isTransitioning = NO;
}

/*
 *  Build and configure the camera if it isn't already configured.
 */
-(void) buildCameraIfNecessary
{
    if (camera) {
        return;
    }
    
    camera                  = [[UIPhotoCaptureView alloc] initWithFrame:self.contentView.bounds];
    camera.hidden           = YES;
    camera.frame            = self.contentView.bounds;
    camera.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    camera.delegate         = self;
    [self.contentView insertSubview:camera belowSubview:fromTransition];
    
    // - always default to using the front camera first to encourage
    //   taking self-portraits.
    if ([camera isPhotoCaptureAvailable]) {
        [camera setPrimaryCamera:[camera isFrontCameraAvailable]];
    }
}
@end