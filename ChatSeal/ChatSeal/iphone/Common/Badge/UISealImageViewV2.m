//
//  UISealImageViewV2.m
//  ChatSeal
//
//  Created by Francis Grolemund on 3/21/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "UISealImageViewV2.h"
#import "ChatSeal.h"

// - constants
static const CGFloat CS_SIV2_MAX_DISPLAY_SIDE  = 1024.0f;
static CGFloat CS_SIV2_ONE_SEAL_SIDE           = -1.0f;             //  in pixels, not points, but it must look good when sized to full screen.
static const CGFloat CS_SIV2_MAX_SCALE_FACTOR  = 1.25f;             //  maximum scale adjustment to the original image.
static const CGFloat CS_SIV2_RUBBER_BAND_SCALE = 0.075f;            //  the amount of extra that can be applied under the limit.
static const CGFloat CS_SIV2_MIN_DISPLAY_SCALE = 1.0f - CS_SIV2_RUBBER_BAND_SCALE;
static const unsigned CS_SIV2_FLAGS_SCALE      = 0x01;
static const unsigned CS_SIV2_FLAGS_OFFSET     = 0x02;
static const unsigned CS_SIV2_FLAGS_ROTATE     = 0x04;
static const CGFloat CS_SIV2_NEAR_ZERO_SCALE   = 0.001f;

// - forward declarations
@interface UISealImageViewV2 (internal)
-(CGSize) imageSizeInPixels:(UIImage *) img;
-(void) configureStandardAttributes;
-(UIImage *) displayImageFromImage:(UIImage *) img;
-(CGPoint) sealToViewRelative:(CGPoint) ptSealRelative;
-(CGPoint) viewToSealRelative:(CGPoint) ptViewRelative;
-(CGFloat) realScaleForDisplayZoom:(CGFloat) displayZoom assumingViewSide:(CGFloat) viewSideInPx andSourceImageSize:(CGSize) szSource;
-(CATransform3D) transformForViewSide:(CGFloat) viewSideInPx andSourceImageSize:(CGSize) szSource andZoomLevel:(CGFloat) displayZoom andSealOffset:(CGPoint) ptOffset
                          andRotation:(CGFloat) rotation;
-(CATransform3D) transformForPreviewWithZoomLevel:(CGFloat) displayZoom andSealOffset:(CGPoint) ptOffset andRotation:(CGFloat) rotation;
-(void) sizeAndOrientImagePreviewWithZoomLevel:(CGFloat) displayZoom andSealOffset:(CGPoint) ptOffset andRotation:(CGFloat) rotation;
-(BOOL) shouldSaveAttributeChangeForGesture:(UIGestureRecognizer *) manageGesture andAttributes:(unsigned) attribs withZoomLevel:(CGFloat *) manageZoom
                                  andOffset:(CGPoint *) manageOffset andRotation:(CGFloat *) manageRotation;
-(void) handleZoomGesture;
-(void) handleDoubleTapGesture;
-(void) handlePanning;
-(void) constrainForAttributes:(unsigned) aflags andZoomLevel:(CGFloat *) displayZoom andSealOffset:(CGPoint *) ptOffset andRotation:(CGFloat *) rotation
                  withRubberband:(BOOL) allowRubberband;
-(void) handleRotation;
-(void) fillPoints:(CGPoint[4]) pts fromRect:(CGRect) rc;
-(void) fillOctagonPoints:(CGPoint [8]) pts fromRect:(CGRect) rc;
-(BOOL) isPoint:(CGPoint) pt inPolygon:(CGPoint *) polyPoints ofNumberOfPoints:(int) numPolyPts withCorrectionDelta:(CGSize *) correctDelta;
-(BOOL) doPreviewBoundsWithZoomLevel:(CGFloat) displayZoom encloseViewAtRotation:(CGFloat) rotation withOffset:(CGPoint) ptOffset andRubberband:(BOOL) allowRubberband
                 withCorrectionOffset:(CGPoint *) toCorrect;
-(CGFloat) orientationCorrectedRotationForImage:(UIImage *) img;
-(void) setSealImage:(UIImage *)img andPreviewImage:(UIImage *) previewImg;
-(void) updateVersion;
@end

/**********************
 UISealImageViewV2
 **********************/
@implementation UISealImageViewV2
/*
 *  Object attributes.
 */
{
    UIImage                     *originalSealImage;
    UIImage                     *displayImage;
    
    CGFloat                     maxZoomLevel;
    
    CALayer                     *layerImagePreview;
    CGSize                      szLastView;
    
    BOOL                        isEditing;
    UIPinchGestureRecognizer    *zoomGesture;
    BOOL                        mirrorHoriz;
    BOOL                        mirrorVert;
    CGFloat                     zoomLevel;          //  relative to the size of a standard seal
    CGPoint                     sealOffset;         //  relative to the size of a standard seal
    CGFloat                     sealRotation;
    UITapGestureRecognizer      *tapGesture;
    UIPanGestureRecognizer      *panGesture;
    UIRotationGestureRecognizer *rotGesture;
    CGFloat                     hitClipPct;
    NSUInteger                  editVersion;
}

@synthesize delegate;

/*
 *  Initialize the module.
 */
+(void) initialize
{
    // - I've been using this particular symbol everywhere and this seems like it is a much more reliable
    //   approach to upgrading it to a common, point-based definition.  I don't want to accidentally break this.
    // - I'm standardizing on a 2X dimension because we don't show the seal image at full size, but I want to reserve
    //   a little capacity if I need to later.
    CS_SIV2_ONE_SEAL_SIDE = [ChatSeal standardSealOriginalSide] * 2.0f;
}

/*
 *  Return the dimensions of a standard seal image.
 */
+(CGSize) sealImageSizeInPixels
{
    //  - This size is special because it
    //    results in a JPEG that has 21x21 DUs, which
    //    allows for just a little over 4K embedded, the minimum
    //    amount of data required by a seal.  Any more and
    //    seal generation will take a lot longer.  
    return CGSizeMake(CS_SIV2_ONE_SEAL_SIDE, CS_SIV2_ONE_SEAL_SIDE);
}

/*
 *  Initialize this object programmatically.
 */
-(id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self configureStandardAttributes];
    }
    return self;
}

/*
 *  Initialize the object from a NIB.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self configureStandardAttributes];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    delegate = nil;
    [self setEditingEnabled:NO];
    
    [self removeGestureRecognizer:zoomGesture];
    [zoomGesture release];
    zoomGesture = nil;
    
    [self removeGestureRecognizer:tapGesture];
    [tapGesture release];
    tapGesture = nil;
    
    [self removeGestureRecognizer:panGesture];
    [panGesture release];
    panGesture = nil;
    
    [self removeGestureRecognizer:rotGesture];
    [rotGesture release];
    rotGesture = nil;
    
    [layerImagePreview removeFromSuperlayer];
    [layerImagePreview release];
    layerImagePreview = nil;
    
    [displayImage release];
    displayImage = nil;
    
    [originalSealImage release];
    originalSealImage = nil;
    
    [super dealloc];
}

/*
 *  Return the best size for this control
 */
-(CGSize) sizeThatFits:(CGSize)size
{
    if (size.width < size.height) {
        return CGSizeMake(size.width, size.width);
    }
    else {
        return CGSizeMake(size.height, size.height);
    }
}

/*
 *  Perform sub-layer layout.
 */
-(void) layoutSublayersOfLayer:(CALayer *)layer
{
    [super layoutSublayersOfLayer:layer];
    if (self.layer == layer) {        
        //  - only reevaluate the size of the sub-layer when the view's size changes
        //    because this method is called when the transforms are applied and the
        //    transforms _must_ be applied after the layer's dimensions have been changed.
        CGSize szParent = self.layer.bounds.size;
        if ((int) szParent.width != (int) szLastView.width ||
            (int) szParent.height != (int) szParent.height) {            
            
            // - if there is a bounds animation occurring, first animate the preview then come
            //   back around again.
            CGFloat previewWidth = CGRectGetWidth(layerImagePreview.bounds);
            NSArray *arrKeys = [self.layer animationKeys];
            for (NSString *key in arrKeys) {
                if (([key isEqualToString:@"bounds"] || [key isEqualToString:@"bounds.size"]) && previewWidth > 1.0f) {
                    CAAnimation *animCur = [self.layer animationForKey:key];
                    [CATransaction begin];
                    
                    //  - we need to come back in later or the animations won't scale/position
                    //    correctly.
                    [CATransaction setCompletionBlock:^(void){
                        [self setNeedsLayout];
                    }];
                    
                    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"position"];
                    anim.timingFunction = animCur.timingFunction;
                    anim.duration       = animCur.duration;
                    anim.fromValue      = [NSValue valueWithCGPoint:layerImagePreview.position];
                    CGPoint ptNewPos    = CGPointMake(szParent.width/2.0f, szParent.height/2.0f);
                    anim.toValue        = [NSValue valueWithCGPoint:ptNewPos];
                    [layerImagePreview addAnimation:anim forKey:@"position"];
                    
                    CATransform3D xform = [self transformForPreviewWithZoomLevel:zoomLevel andSealOffset:sealOffset andRotation:sealRotation];
                    anim = [CABasicAnimation animationWithKeyPath:@"transform"];
                    anim.timingFunction = animCur.timingFunction;
                    anim.duration       = animCur.duration;
                    anim.fromValue      = [NSValue valueWithCATransform3D:layerImagePreview.transform];
                    anim.toValue        = [NSValue valueWithCATransform3D:xform];
                    [layerImagePreview addAnimation:anim forKey:@"transform"];
                    
                    [CATransaction begin];
                    [CATransaction setDisableActions:YES];
                    layerImagePreview.position = ptNewPos;
                    layerImagePreview.transform = xform;
                    [CATransaction commit];
            
                    [CATransaction commit];
                    return;
                }
            }

            // - don't allow any more layouts to occur.
            szLastView = szParent;
            
            //  - the preview window is always sized at 2X the size of the view and centered in it.
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            layerImagePreview.frame = CGRectMake(-szParent.width/2.0f, -szParent.height/2.0f, szParent.width * 2.0f, szParent.height * 2.0f);

            //  - apply the current transforms.
            [self sizeAndOrientImagePreviewWithZoomLevel:zoomLevel andSealOffset:sealOffset andRotation:sealRotation];
            [CATransaction commit];
        }
    }
}

/*
 *  Set the baseline image for the seal.  This image
 *  may either be way too small or way too big.  We keep a handle
 *  to it so that if a good shot is requested, then we can clip out
 *  the perfect rectangle from the original one.
 */
-(void) setSealImage:(UIImage *) img
{
    if (originalSealImage == img) {
        return;
    }
    
    UIImage *imgPreview = nil;
    
    // - to start, we need the size of the image in pixels to ensure
    //   that odd @2x images never confuse this.
    CGSize szImage = [self imageSizeInPixels:img];
    if (szImage.width > 0.0f && szImage.height > 0.0f) {                
        imgPreview = [self displayImageFromImage:img];
                
        // - if the display image is a scaled-up version of the original
        //   we'll use that for all our work.
        CGSize szDisplay = [self imageSizeInPixels:imgPreview];
        if ((imgPreview != img) &&
            (szDisplay.width > szImage.width || szDisplay.height > szImage.height)) {
            img = imgPreview;
        }
    }
    
    //  - save off the images.
    [self setSealImage:img andPreviewImage:imgPreview];
}

/*
 *  Returns whether a seal image has been set in the view.
 */
-(BOOL) hasSealImage
{
    if (originalSealImage) {
        return YES;
    }
    return NO;
}

/*
 *  Ensure that this view is configured identically to the provided view.
 */
-(void) copyAllAttributesFromSealView:(UISealImageViewV2 *) sealView
{
    if (sealView) {
        [self setSealImage:sealView->originalSealImage andPreviewImage:sealView->displayImage];
        zoomLevel    = sealView->zoomLevel;
        sealOffset   = sealView->sealOffset;
        sealRotation = sealView->sealRotation;
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [self sizeAndOrientImagePreviewWithZoomLevel:zoomLevel andSealOffset:sealOffset andRotation:sealRotation];
        [CATransaction commit];
    }
    else {
        [self setSealImage:nil andPreviewImage:nil];
    }
}

/*
 *  Enable/disable image editing.
 */
-(void) setEditingEnabled:(BOOL) enabled
{
    isEditing                   = enabled;
    zoomGesture.enabled         = enabled;
    tapGesture.enabled          = enabled;
    panGesture.enabled          = enabled;
    rotGesture.enabled          = enabled;
    self.userInteractionEnabled = enabled;
    [self sizeAndOrientImagePreviewWithZoomLevel:zoomLevel andSealOffset:sealOffset andRotation:sealRotation];
}

/*
 *  Produce an image from the control using the current editing modifications modifications that is consistent with the
 *  required dimensions of a seal.
 */
-(UIImage *) standardizedSealImage
{
    if (!originalSealImage) {
        return nil;
    }
    
    //  NOTE:  We can't use the UIImage draw API because it will auto-correct for
    //         image orientation, and our transforms are already adjusted for that.  In order
    //         to retain a unified approach to transform handling, we must use the raw Quartz APIs
    //         for drawing the image - which of course runs into the Quartz coordinate system.
    CGSize szOriginal = [self imageSizeInPixels:originalSealImage];
    if (szOriginal.width > CS_SIV2_ONE_SEAL_SIDE ||
        szOriginal.height > CS_SIV2_ONE_SEAL_SIDE) {
     
        //  - if the original image is larger than is expected, then we need to clip it
        //    to the output rectangle.
        CGRect rcTarget = CGRectMake(0.0f, 0.0f, szOriginal.width, szOriginal.height);
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(CS_SIV2_ONE_SEAL_SIDE, CS_SIV2_ONE_SEAL_SIDE), YES, 1.0f);
        
        //  - It is critical to apply the computed transforms first so that the offsets match what is found in
        //    the layer.
        //  - If you correct for Quartz before applying this transform, all of the manipulations are flipped.
        //  - REMEMBER that transforms are additive in the order in which they are processed!
        CATransform3D xform3D = [self transformForViewSide:CS_SIV2_ONE_SEAL_SIDE andSourceImageSize:szOriginal andZoomLevel:zoomLevel andSealOffset:sealOffset andRotation:sealRotation];
        CGContextConcatCTM(UIGraphicsGetCurrentContext(), CATransform3DGetAffineTransform(xform3D));
        
        //  - Now adjust for Quartz
        CGContextScaleCTM(UIGraphicsGetCurrentContext(), 1.0f, -1.0f);
        CGContextTranslateCTM(UIGraphicsGetCurrentContext(), 0.0f, -CGRectGetHeight(rcTarget));

        //  - And draw the image.
        CGContextDrawImage(UIGraphicsGetCurrentContext(), rcTarget, [originalSealImage CGImage]);
        
        UIImage *imgRet = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return imgRet;
    }
    else {
        return [[originalSealImage retain] autorelease];
    }
}

/*
 *  Set a value that is the percetage of the radius that will be used
 *  to determine whether touches are registered in the object.
 */
-(void) setHitClippingRadiusPct:(CGFloat) pct
{
    hitClipPct = pct;
}

/*
 *  Return the current hit clipping radius.
 */
-(CGFloat) hitClippingRadiusPct
{
    return hitClipPct;
}

/*
 *  Track all changes to the seal with a simple version number.
 */
-(NSUInteger) editVersion
{
    return editVersion;
}

@end


/**********************************
 UISealImageViewV2 (internal)
 **********************************/
@implementation UISealImageViewV2 (internal)

/*
 *  Seal images must deal in pixels because the number of pixels 
 *  directly influences the amount of data they can store and the speed
 *  at which a seal can be generated.
 */
-(CGSize) imageSizeInPixels:(UIImage *) img
{
    //  - use the Quartz API here to ensure that orientation adjustments aren't
    //    automatically applied.
    return CGSizeMake(CGImageGetWidth([img CGImage]), CGImageGetHeight([img CGImage]));
}

/*
 *  Regardless of the initialization path, the attributes are always the
 *  same.
 */
-(void) configureStandardAttributes
{
    szLastView           = CGSizeZero;
    editVersion          = 0;
    
    //  - when something is 'seal relative' that means that the attribute
    //    is defined relative to the size of a standard seal, which is 168x168 px.
    //  - this is important because it ensures tha the attributes produce the same
    //    effect regardless of the size of the control that displays the seal.
    maxZoomLevel         = 1.0f;
    sealRotation         = 0.0f;
    zoomLevel            = 1.0f;            //  seal-relative
    sealOffset           = CGPointZero;     //  seal-relative
    mirrorHoriz          = mirrorVert = NO;
    
    isEditing            = NO;
    originalSealImage    = nil;
    displayImage         = nil;
    self.clipsToBounds   = YES;
    hitClipPct           = 2.0f;            //  ensure that the circle's bounds are beyond the sides of this view by default.
    

    //  - NOTE: make sure you *NEVER* add a shadow to this layer or the resources expand significantly and
    //          it causes rendering bugs (layer pops in and out). 
    layerImagePreview = [[CALayer alloc] init];
    layerImagePreview.contentsGravity = kCAGravityCenter;
    layerImagePreview.contentsScale   = [UIScreen mainScreen].scale;
    layerImagePreview.bounds          = self.frame;
    layerImagePreview.doubleSided     = YES;                        //  used for presenting mirrored representations.
    
    [self.layer addSublayer:layerImagePreview];
    
    zoomGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handleZoomGesture)];
    [self addGestureRecognizer:zoomGesture];
    
    tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTapGesture)];
    tapGesture.numberOfTapsRequired = 2;
    tapGesture.numberOfTouchesRequired = 1;
    [self addGestureRecognizer:tapGesture];
    
    panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanning)];
    panGesture.maximumNumberOfTouches = 1;
    panGesture.minimumNumberOfTouches = 1;
    [self addGestureRecognizer:panGesture];
    
    rotGesture = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(handleRotation)];
    [self addGestureRecognizer:rotGesture];
}

/*
 *  Generate an appropriate-sized display image that is neither too small
 *  nor too large.
 */
-(UIImage *) displayImageFromImage:(UIImage *) img
{
    //  The biggest concern about these images is that they could
    //  be really huge if they came from the owner's photo library.  We
    //  can't show a 12MP photo in this control.  Similarly, it is
    //  possible, but unlikely that they select some sort of odd-shaped
    //  small image (1x512), in which case, we'll have to just do our
    //  best.
    //  - there are three possibilities we need to work through:
    //    1.  the image is just right for this control, meaning
    //        it doesn't need expanded or contracted.
    //    2.  the image is too big for the control, meaning we need
    //        a separate smaller display image we can use for editing.
    //    3.  the image is too small for the control, meaning we need
    //        a separate, larger display image we can use for editing.
    CGSize szImage = [self imageSizeInPixels:img];
    CGFloat arImage = szImage.width/szImage.height;
    CGSize szTarget = szImage;
    BOOL scaleUp = NO;
    BOOL scaleDown = NO;

    // - start by seeing if the image is too small. 
    if (szTarget.width < szTarget.height) {
        if (szTarget.width < CS_SIV2_ONE_SEAL_SIDE) {
            scaleUp = YES;
            szTarget = CGSizeMake(CS_SIV2_ONE_SEAL_SIDE, CS_SIV2_ONE_SEAL_SIDE/arImage);
        }
    }
    else {
        if (szTarget.height < CS_SIV2_ONE_SEAL_SIDE) {
            scaleUp = YES;
            szTarget = CGSizeMake(CS_SIV2_ONE_SEAL_SIDE*arImage, CS_SIV2_ONE_SEAL_SIDE);
        }
    }
    
    //  - now determine if the image is too big.
    //    (but make sure that we didn't produce this just now by scaling up)
    CGSize szContext = szTarget;
    BOOL smallContext = NO;
    if (szTarget.width > szTarget.height) {
        if (szTarget.width > CS_SIV2_MAX_DISPLAY_SIDE) {
            scaleDown = YES;
            szContext = CGSizeMake(CS_SIV2_MAX_DISPLAY_SIDE, CS_SIV2_MAX_DISPLAY_SIDE/arImage);
            
            //  - it is entirely possible that the generated context won't have the required
            //    minimum dimension after we create it, so make sure that minimum is enforced.
            if (szContext.height < CS_SIV2_ONE_SEAL_SIDE) {
                smallContext = YES;
                szContext.height = CS_SIV2_ONE_SEAL_SIDE;
            }
                    
            //  - if we just scaled this up, we'll need to clip instead of scaling down.
            if (!scaleUp) {
                if (smallContext) {
                    //  - the aspect ratio produced a context that didn't satisfy the
                    //    minimum requirement, so we need to scale back up
                    szTarget = CGSizeMake(szContext.height*arImage, szContext.height);
                }
                else {
                    szTarget = szContext;
                }
            }
        }
    }
    else {
        if (szTarget.height > CS_SIV2_MAX_DISPLAY_SIDE) {
            scaleDown = YES;
            szContext = CGSizeMake(CS_SIV2_MAX_DISPLAY_SIDE*arImage, CS_SIV2_MAX_DISPLAY_SIDE);
            
            //  - it is entirely possible that the generated context won't have the required
            //    minimum dimension after we create it, so make sure that minimum is enforced.
            if (szContext.width < CS_SIV2_ONE_SEAL_SIDE) {
                smallContext = YES;
                szContext.width = CS_SIV2_ONE_SEAL_SIDE;
            }
            
            //  - if we just scaled this up, we'll need to clip instead of scaling down.
            if (!scaleUp) {
                if (smallContext) {
                    //  - the aspect ratio produced a context that didn't satisfy the
                    //    minimum requirement, so we need to scale back up
                    szTarget = CGSizeMake(szContext.width, szContext.width/arImage);
                }
                else {
                    szTarget = szContext;
                }
            }
        }
    }
    
    //  - and draw if necessary
    if (scaleUp || scaleDown) {
        UIGraphicsBeginImageContextWithOptions(szContext, YES, 1.0f);
        
        // - account for the Quartz origin
        CGContextTranslateCTM(UIGraphicsGetCurrentContext(), 0.0f, szContext.height);
        CGContextScaleCTM(UIGraphicsGetCurrentContext(), 1.0f, -1.0f);
        
        //  - draw with Quartz so that no orientation adjustments are applied.
        CGRect rcTarget = CGRectMake((szContext.width-szTarget.width)/2.0f, (szContext.height-szTarget.height)/2.0f, szTarget.width, szTarget.height);
        CGContextDrawImage(UIGraphicsGetCurrentContext(), rcTarget, [img CGImage]);
        img = UIGraphicsGetImageFromCurrentImageContext();
        
        //  - and produce a sized of the same image with scaling and orientation
        img = [UIImage imageWithCGImage:[img CGImage] scale:img.scale orientation:img.imageOrientation];
        UIGraphicsEndImageContext();
    }
    
    return img;
}

/*
 *  Convert a point from view coordinates to seal coordinates
 */
-(CGPoint) viewToSealRelative:(CGPoint) ptViewRelative
{
    CGSize szView = self.bounds.size;
    CGFloat sxPerRel = CS_SIV2_ONE_SEAL_SIDE / szView.width;
    CGFloat syPerRel = CS_SIV2_ONE_SEAL_SIDE / szView.height;
    return CGPointMake(ptViewRelative.x * sxPerRel, ptViewRelative.y * syPerRel);
}

/*
 *  Convert a point from a seal-relative coordinate system to view coordinates
 */
-(CGPoint) sealToViewRelative:(CGPoint) ptSealRelative
{
    CGSize szView = self.bounds.size;
    CGFloat axPerSeal = szView.width / CS_SIV2_ONE_SEAL_SIDE;
    CGFloat ayPerSeal = szView.height / CS_SIV2_ONE_SEAL_SIDE;
    return CGPointMake(ptSealRelative.x * axPerSeal, ptSealRelative.y * ayPerSeal);
}

/*
 *  Compute the scale used to adjust the image down to the view's coordinate
 *  space.
 */
-(CGFloat) realScaleForDisplayZoom:(CGFloat) displayZoom assumingViewSide:(CGFloat) viewSideInPts andSourceImageSize:(CGSize) szSource
{
    CGFloat realScale = 1.0f;
    if (szSource.width > szSource.height) {
        //  - the short side is the height (landscape), so use that
        //    as a scaling reference.
        realScale = viewSideInPts / szSource.height;
    }
    else {
        //  - the short side is the width (portrait), so use that as
        //    a scaling reference.
        realScale = viewSideInPts / szSource.width;
    }
    
    //  - multiply the display zoom by the starting scale to get the
    //    view's scale transform value.
    realScale *= displayZoom;
    
    //  - ensure that the scale isn't too small or you'll get
    //  an error 'CGAffineTransformInvert: singular matrix'
    if (realScale < CS_SIV2_NEAR_ZERO_SCALE) {
        realScale = CS_SIV2_NEAR_ZERO_SCALE;
    }
    return realScale;
}

/*
 *  Return a transform that will convert points in the preview using the current attributes.
 *  - requires that the view side is passed.
 *  - this assumes that the view coordinate system is relative to the top corner, which is consistent 
 *    with the way that UIKit drawing is performed.
 */
-(CATransform3D) transformForViewSide:(CGFloat) viewSideInPts andSourceImageSize:(CGSize) szSource andZoomLevel:(CGFloat) displayZoom andSealOffset:(CGPoint) ptOffset
                          andRotation:(CGFloat) rotation
{
    CGFloat realScale = [self realScaleForDisplayZoom:displayZoom assumingViewSide:viewSideInPts andSourceImageSize:szSource];
    CATransform3D xform3D = CATransform3DIdentity;
    
    xform3D = CATransform3DConcat(xform3D, CATransform3DMakeTranslation(-szSource.width/2.0f, -szSource.height/2.0f, 0.0f));
    
    CATransform3D xformRotate = CATransform3DMakeRotation(rotation, 0.0f, 0.0f, 1.0f);
    if (mirrorVert || mirrorHoriz) {
        xformRotate = CATransform3DInvert(xformRotate);
    }
    
    xform3D = CATransform3DConcat(xform3D, xformRotate);
    xform3D = CATransform3DConcat(xform3D, CATransform3DMakeScale(realScale, realScale, 1.0f));
    xform3D = CATransform3DConcat(xform3D, CATransform3DMakeTranslation(viewSideInPts/2.0f, viewSideInPts/2.0f, 0.0f));

    if (mirrorHoriz) {
        xform3D = CATransform3DConcat(xform3D, CATransform3DMakeTranslation(0.0f, -viewSideInPts, 0.0f));
        xform3D = CATransform3DConcat(xform3D, CATransform3DMakeScale(1.0f, -1.0f, 1.0f));
    }
    else if (mirrorVert) {
        xform3D = CATransform3DConcat(xform3D, CATransform3DMakeTranslation(-viewSideInPts, 0.0f, 0.0f));
        xform3D = CATransform3DConcat(xform3D, CATransform3DMakeScale(-1.0f, 1.0f, 1.0f));
    }

    //  - translation always comes last
    xform3D = CATransform3DConcat(xform3D, CATransform3DMakeTranslation(ptOffset.x, ptOffset.y, 0.0f));
    
    return xform3D;
}

/*
 *  Return an appropriate 3d transform for the preview window using the given attributes.
 */
-(CATransform3D) transformForPreviewWithZoomLevel:(CGFloat) displayZoom andSealOffset:(CGPoint) ptOffset andRotation:(CGFloat) rotation
{
    if (!displayImage) {
        return CATransform3DIdentity;
    }
    
    //  - the point is always passed as seal-relative.
    ptOffset = [self sealToViewRelative:ptOffset];
    
    //  - when the contentsScale is set to the device scale, we get a 1:1 pixel from the image to
    //    output pixels when the transform scale is 1.0f.
    CGFloat displayScale = [UIScreen mainScreen].scale;
    CGFloat viewSideInPx = CGRectGetWidth(self.bounds) * displayScale;
    CGSize  szDisplay = [self imageSizeInPixels:displayImage];
    CATransform3D xformBase = CATransform3DMakeTranslation(szDisplay.width/2.0f, szDisplay.height/2.0f, 0.0f);          //  offset from top-left
    CATransform3D xformFromTopLeft = [self transformForViewSide:viewSideInPx andSourceImageSize:szDisplay andZoomLevel:displayZoom andSealOffset:ptOffset andRotation:rotation];
    CATransform3D xformBack = CATransform3DMakeTranslation(-viewSideInPx/2.0f, -viewSideInPx/2.0f, 0.0f);
    return CATransform3DConcat(CATransform3DConcat(xformBase, xformFromTopLeft), xformBack);
}

/*
 *  Make sure the image preview layer is sized according to the aspect ratio of the image.
 *  - this takes a zoom property instead of using the current zoomLevel to accommodate the pinch-relative
 *    scaling which won't be resolved until the pinch is completed.
 *  - this takes a seal-relative offset instead of using the current offset to accommodate pan-relative offsetting
 */
-(void) sizeAndOrientImagePreviewWithZoomLevel:(CGFloat) displayZoom andSealOffset:(CGPoint) ptOffset andRotation:(CGFloat) rotation
{
    if (!displayImage) {
        return;
    }
    
    //  - before applying any transforms, the position must be set to
    //    ensure that everything is relative to that point.  This is a nuance
    //    of dealing with layers because the position/frame change the transforms
    //    and vice versa instead of being independent entities.
    layerImagePreview.position  = CGPointMake(CGRectGetWidth(self.bounds)/2.0f, CGRectGetHeight(self.bounds)/2.0f);
    layerImagePreview.transform = [self transformForPreviewWithZoomLevel:displayZoom andSealOffset:ptOffset andRotation:rotation];
}

/*
 *  All attribute modifications are handled in the same way.
 *  - returns TRUE if the attribute should be updated.
 */
-(BOOL) shouldSaveAttributeChangeForGesture:(UIGestureRecognizer *) manageGesture andAttributes:(unsigned) attribs withZoomLevel:(CGFloat *) manageZoom
                                  andOffset:(CGPoint *) manageOffset andRotation:(CGFloat *) manageRotation
{
    //  - under normal circumstances, we'll allow for some minimal rubber-banding
    //    space so that the user has an idea about limits.
    CGPoint ptViewRelative = [self sealToViewRelative:*manageOffset];
    [self constrainForAttributes:attribs andZoomLevel:manageZoom andSealOffset:&ptViewRelative andRotation:manageRotation withRubberband:YES];
    *manageOffset = [self viewToSealRelative:ptViewRelative];
        
    BOOL completed = NO;
    switch (manageGesture.state) {
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged:
            // -  we'll be showing the change in a moment.
            break;
            
        case UIGestureRecognizerStateEnded:
            //  - when the gesture is done, we need to ensure that no rubber banding space
            //    remains.
            [self constrainForAttributes:attribs andZoomLevel:manageZoom andSealOffset:&ptViewRelative andRotation:manageRotation withRubberband:NO];
            *manageOffset = [self viewToSealRelative:ptViewRelative];
            completed = YES;
            break;
            
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            //  - abort and return the state back to
            //    what it currently is recorded as
            [self sizeAndOrientImagePreviewWithZoomLevel:zoomLevel andSealOffset:sealOffset andRotation:sealRotation];
            return NO;
            break;
            
        default:
        case UIGestureRecognizerStatePossible:
            //  - do nothing.
            return NO;
            break;
    }
    
    [CATransaction begin];
    [CATransaction setDisableActions:!completed];
    if (completed) {
        [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    }
    [self sizeAndOrientImagePreviewWithZoomLevel:*manageZoom andSealOffset:*manageOffset andRotation:*manageRotation];
    [CATransaction commit];
    return completed;
}

/*
 *  This method is called whenever pinch gestures are performed on the view
 *  indicating the contents should be modified.
 */
-(void) handleZoomGesture
{
    CGFloat newScale = zoomLevel - 1.0f + zoomGesture.scale;
    
    //  - we must assume that the current offset is proportional to the scale, so the new
    //    offset must follow the same proportions to retain the same centered point in the image.
    CGFloat scaleRatio = newScale / zoomLevel;
    CGPoint ptTmpOffset = CGPointMake(sealOffset.x * scaleRatio, sealOffset.y * scaleRatio);
    
    //  - all three attribute types are reevaluated when rescaling because during a scale-down, the
    //    image may not sufficiently fit any longer with the provided offset and rotation.
    if ([self shouldSaveAttributeChangeForGesture:zoomGesture andAttributes:CS_SIV2_FLAGS_SCALE | CS_SIV2_FLAGS_ROTATE | CS_SIV2_FLAGS_OFFSET withZoomLevel:&newScale
                                        andOffset:&ptTmpOffset andRotation:&sealRotation]) {
        zoomLevel = newScale;
        sealOffset = ptTmpOffset;
    }
    
    //  - always update the version when edits occur.
    [self updateVersion];
}

/*
 *  This method is called whenever someone double-taps this view, which
 *  often is just ignored unless we're zoomed-in and it is a double tap.
 */
-(void) handleDoubleTapGesture
{
    // - a double tap indicates that the zoomed-out image should be returned
    //   to its original scale.
    zoomLevel      = 1.0f;
    sealRotation   = [self orientationCorrectedRotationForImage:originalSealImage];
    sealOffset     = CGPointZero;
    [CATransaction begin];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    [self sizeAndOrientImagePreviewWithZoomLevel:zoomLevel andSealOffset:sealOffset andRotation:sealRotation];
    [CATransaction commit];
    
    //  - always update the version when edits occur.
    [self updateVersion];
}

/*
 *  This method is called whenever soemone drags within the view, attempting to 
 *  place the image.
 *  - the thing to remember that when this is called, the zoom level never changes, which means that
 *    we can consider one attribute of the image's modification at a time.
 */
-(void) handlePanning
{
    // - even though these values are in points, we'll use them as pixels
    //   inside the seal image.  
    CGPoint ptViewRelative = [panGesture translationInView:self];
    CGPoint ptCurrentSeal = [self sealToViewRelative:sealOffset];
    ptViewRelative.x += ptCurrentSeal.x;
    ptViewRelative.y += ptCurrentSeal.y;
    CGPoint ptSealRelative = [self viewToSealRelative:ptViewRelative];
    
    if ([self shouldSaveAttributeChangeForGesture:panGesture andAttributes:CS_SIV2_FLAGS_OFFSET withZoomLevel:&zoomLevel andOffset:&ptSealRelative andRotation:&sealRotation]) {
        sealOffset = ptSealRelative;
    }
    
    //  - always update the version when edits occur.
    [self updateVersion];
}

/*
 *  Ensure that the preview image is never adjusted in a way that would leave visible gaps 
 *  between it and the sides after completion.
 *  - only those attribute flags that are passed will be validated.  
 *  - the offset is assumed to be view-relative.
 */
-(void) constrainForAttributes:(unsigned) aflags andZoomLevel:(CGFloat *) displayZoom andSealOffset:(CGPoint *) ptOffset andRotation:(CGFloat *) rotation
                withRubberband:(BOOL) allowRubberband
{
    if (aflags & CS_SIV2_FLAGS_SCALE) {
        if (allowRubberband) {
            if (*displayZoom < CS_SIV2_MIN_DISPLAY_SCALE) {
                *displayZoom = CS_SIV2_MIN_DISPLAY_SCALE;
            }
        }
        else {
            if (*displayZoom < 1.0f) {
                *displayZoom = 1.0f;
            }
            else if (*displayZoom > maxZoomLevel) {
                *displayZoom = maxZoomLevel;
            }
        }
    }
    
    
    // - rotation checks don't make sense to apply unless we're doing the final
    //   constraint test without rubber banding space.  The assumption is that
    //   rubber-banding space anywhere and not related to the constant.
    if ((aflags & CS_SIV2_FLAGS_ROTATE) && !allowRubberband) {
        // - when an intersection occurs, move backwards until a good value is identified.
        if (![self doPreviewBoundsWithZoomLevel:*displayZoom encloseViewAtRotation:*rotation withOffset:*ptOffset andRubberband:NO withCorrectionOffset:nil]) {
            //  - there are two things to be careful of:
            //    1. the rotation is an aggregate of multiple rotations and not constrained to 0-2PI
            //    2. when we're close to 0 or PI, it is best to just accept those values because we know that
            //       they will always work.
            
            CGFloat before = *rotation;
            CGFloat after  = *rotation;
            CGFloat fiveDegrees = ((CGFloat) M_PI/180.0f) * 5.0f;
            
            //  - test only half the circle because we'll definitely find a good location in 180 degrees.
            //  - but do so in both directions from the current point to find the closest solution.
            BOOL isBefore = YES;
            for (int i = 0; i < 180; i+=5, isBefore = !isBefore) {
                CGFloat curVal = 0.0f;
                if (isBefore) {
                    before -= fiveDegrees;
                    curVal = before;
                }
                else {
                    after += fiveDegrees;
                    curVal = after;
                }
                
                //  - if this is close straight up or down, just accept that
                //    since we know that always works.
                CGFloat numHalfRotations = floorf((float)(curVal/(CGFloat) M_PI));
                CGFloat differential = fabsf((float)(curVal - (numHalfRotations * (CGFloat) M_PI)));
                if (differential < fiveDegrees) {
                    *rotation = (numHalfRotations * (CGFloat) M_PI);
                    break;
                }
                
                //  - a quarter rotation is also sometimes a good possibility, but
                //    is not guaranteed to work.
                CGFloat numQuarterRotations = floorf((float)(curVal/((CGFloat)M_PI/2.0f)));
                differential                = fabsf((float)(curVal - (numQuarterRotations * ((CGFloat)M_PI/2.0f))));
                if (differential < fiveDegrees) {
                    curVal = (numQuarterRotations * ((CGFloat)M_PI/2.0f));
                }
                
                //  - see if the rotation looks good otherwise.
                if ([self doPreviewBoundsWithZoomLevel:*displayZoom encloseViewAtRotation:curVal withOffset:*ptOffset andRubberband:NO withCorrectionOffset:nil]) {
                    *rotation = curVal;
                    break;
                }
            }
        }
    }    
    
    if (aflags & CS_SIV2_FLAGS_OFFSET) {
        CGPoint ptToCorrect;
        if (![self doPreviewBoundsWithZoomLevel:*displayZoom encloseViewAtRotation:*rotation withOffset:*ptOffset andRubberband:allowRubberband withCorrectionOffset:&ptToCorrect]) {
            ptOffset->x += ptToCorrect.x;
            ptOffset->y += ptToCorrect.y;
        }
    }
}

/*
 *  This method is called whenever someone tries to rotate the image.
 */
-(void) handleRotation
{
    //  - first get the difference and apply it also to the
    //    current offset so that we rotate about the center of the view,
    //    not the current offset.
    CGFloat newRotation = [rotGesture rotation];
    CGAffineTransform xform = CGAffineTransformMakeRotation(newRotation);
    CGPoint tmpOffset = CGPointApplyAffineTransform(sealOffset, xform);
    newRotation += sealRotation;
    
    if ([self shouldSaveAttributeChangeForGesture:rotGesture andAttributes:CS_SIV2_FLAGS_ROTATE | CS_SIV2_FLAGS_OFFSET withZoomLevel:&zoomLevel andOffset:&tmpOffset
                                      andRotation:&newRotation]) {
        sealRotation = newRotation;
        sealOffset   = tmpOffset;
    }
    
    //  - always update the version when edits occur.
    [self updateVersion];
}

/*
 *  Fill-in the four points from the given rectangle.
 */
-(void) fillPoints:(CGPoint[4]) pts fromRect:(CGRect) rc
{
    pts[0] = CGPointMake(CGRectGetMinX(rc), CGRectGetMinY(rc));
    pts[1] = CGPointMake(CGRectGetMaxX(rc), CGRectGetMinY(rc));
    pts[2] = CGPointMake(CGRectGetMaxX(rc), CGRectGetMaxY(rc));
    pts[3] = CGPointMake(CGRectGetMinX(rc), CGRectGetMaxY(rc));    
}

/*
 *  Fill-in an octagon using the given rectangle.
 */
-(void) fillOctagonPoints:(CGPoint [8])pts fromRect:(CGRect)rc
{
    CGFloat halfWidth = CGRectGetWidth(rc)/2.0f;
    CGFloat quarterWidth = halfWidth/2.0f;
    
    CGFloat halfHeight = CGRectGetHeight(rc)/2.0f;
    CGFloat quarterHeight = halfHeight/2.0f;
    
    CGFloat baseX = rc.origin.x;
    CGFloat baseY = rc.origin.y;
    
    pts[0] = CGPointMake(baseX + quarterWidth, baseY);
    pts[1] = CGPointMake(baseX + quarterWidth + halfWidth, baseY);
    pts[2] = CGPointMake(CGRectGetMaxX(rc), baseY + quarterHeight);
    pts[3] = CGPointMake(CGRectGetMaxX(rc), baseY + quarterHeight + halfHeight);
    pts[4] = CGPointMake(baseX + quarterWidth + halfWidth, CGRectGetMaxY(rc));
    pts[5] = CGPointMake(baseX + quarterWidth, CGRectGetMaxY(rc));
    pts[6] = CGPointMake(baseX, baseY + quarterHeight + halfHeight);
    pts[7] = CGPointMake(baseX, baseY + quarterHeight);
}

/*
 *  Compute the squared distance between two points.
 */
-(CGFloat) distanceSquaredFrom:(CGPoint) p1 toPt2:(CGPoint) p2
{
    CGFloat dx = (p1.x - p2.x);
    CGFloat dy = (p1.y - p2.y);
    return ((dx * dx) + (dy * dy));
}

/*
 *  Compute the distance from a point to a line.
 */
-(CGFloat) distanceFrom:(CGPoint) pt toLinePointOne:(CGPoint) lineP1 andToLinePointTwo:(CGPoint) lineP2
{
    CGFloat ret = [self distanceSquaredFrom:lineP1 toPt2:lineP2];
    if (ret > 0) {
        CGFloat dotP = ((pt.x - lineP1.x) * (lineP2.x - lineP1.x) + (pt.y - lineP1.y) * (lineP2.y - lineP1.y)) / ret;
        if (dotP < 0.0f) {
            ret = [self distanceSquaredFrom:pt toPt2:lineP1];
        }
        else if (dotP > 1.0f) {
            ret = [self distanceSquaredFrom:pt toPt2:lineP2];
        }
        else {
            CGPoint altPt = CGPointMake(lineP1.x + (dotP * (lineP2.x -lineP1.x)), lineP1.y + (dotP * (lineP2.y - lineP1.y)));
            ret = [self distanceSquaredFrom:pt toPt2:altPt];
        }
    }
    else {
        ret = [self distanceSquaredFrom:pt toPt2:lineP1];
    }
    
    return sqrtf((float)ret);
}

/*
 *  Return the intersection between two lines.
 */
-(CGPoint) intersectionOfLine1From:(CGPoint) p1 toLine1End:(CGPoint) p2 andLine2From:(CGPoint) p3 toLine2End:(CGPoint) p4
{
    CGFloat intersectX = ((p1.x * p2.y) - (p1.y * p2.x)) * (p3.x - p4.x);
    intersectX        -= (p1.x - p2.x) * ((p3.x * p4.y) - (p3.y * p4.x));
    
    CGFloat denom      = (p1.x - p2.x) * (p3.y - p4.y);
    denom             -= (p1.y - p2.y) * (p3.x - p4.x);
    intersectX        /= denom;
    
    CGFloat intersectY = ((p1.x * p2.y) - (p1.y * p2.x)) * (p3.y - p4.y);
    intersectY        -= (p1.y - p2.y) * ((p3.x * p4.y) - (p3.y * p4.x));
    
    denom              = (p1.x - p2.x) * (p3.y - p4.y);
    denom             -= (p1.y - p2.y) * (p3.x - p4.x);
    intersectY        /= denom;
    return CGPointMake(intersectX, intersectY);
}

/*
 *  This method will identify whether a given point is inside the provded polygon
 *  - the point array will be modified before being returned to have the list of outer points.
 *  - this is an adaptation of the Crossings Algorithm from Graphics Gems IV.
 */
-(BOOL) isPoint:(CGPoint) pt inPolygon:(CGPoint *) polyPoints ofNumberOfPoints:(int) numPolyPts withCorrectionDelta:(CGSize *) correctDelta
{
    /* ======= Crossings algorithm ============================================ */
    
    /* Shoot a test ray along +X axis.  The strategy, from MacMartin, is to
     * compare vertex Y values to the testing point's Y and quickly discard
     * edges which are entirely to one side of the test ray.
     *
     * Input 2D polygon _pgon_ with _numverts_ number of vertices and test point
     * _point_, returns 1 if inside, 0 if outside.	WINDING and CONVEX can be
     * defined for this test.
     */
    
    if (correctDelta) {
        *correctDelta = CGSizeZero;
    }
    
    BOOL inside_flag = NO;
    CGFloat closestDistance = 999999.0f;
    int     closestP1 = -1;
    int     closestP2 = -1;
    
    //  NOTE:  this has been adapted to check every line segment in order to
    //         determine the shortest distance to the polygon when the point lies outside.
    for (int p0 = 0; p0 < numPolyPts; p0++) {
        int p1 = ((p0+1) % numPolyPts);
        
        /* get test bit for above/below X axis */        
        BOOL yflag0 = (polyPoints[p0].y >= pt.y);
        BOOL yflag1 = (polyPoints[p1].y >= pt.y);
        
        CGFloat dist = [self distanceFrom:pt toLinePointOne:polyPoints[p0] andToLinePointTwo:polyPoints[p1]];
        if (dist < closestDistance) {
            closestDistance = dist;
            closestP1       = p0;
            closestP2       = p1;
        }
        
        /* check if endpoints straddle (are on opposite sides) of X axis
         * (i.e. the Y's differ); if so, +X ray could intersect this edge.
         */
        if (yflag0 != yflag1) {
            BOOL xflag0 = (polyPoints[p0].x >= pt.x); 
            
            /* check if endpoints are on same side of the Y axis (i.e. X's
             * are the same); if so, it's easy to test if edge hits or misses.
             */
            if (xflag0 == (polyPoints[p1].x >= pt.x)) {
                
                /* if edge's X values both right of the point, must hit */
                if (xflag0) {
                    inside_flag = !inside_flag;
                }
            }
            else {
                /* compute intersection of pgon segment with +X ray, note
                 * if >= point's X; if so, the ray hits it.
                 */
                if ( (polyPoints[p1].x - (polyPoints[p1].y - pt.y) *
                      (polyPoints[p0].x - polyPoints[p1].x)/(polyPoints[p0].y - polyPoints[p1].y)) >= pt.x) {
                    inside_flag = !inside_flag ;
                }
            }
        }
    }
    
    //  - when the point is outside, let's compute the intersection of a normal from this point to the line.
    if (!inside_flag) {
        //  - the normal is the inverse slope of the line.
        CGFloat dx = polyPoints[closestP1].x - polyPoints[closestP2].x;
        CGFloat dy = polyPoints[closestP1].y - polyPoints[closestP2].y;
        dx = dx * -1.0f;        
        
        //  - produce a vector from the point along the normal to the line
        CGPoint p2 = CGPointMake(pt.x + dy, pt.y + dx);
        CGPoint intersectionPt = [self intersectionOfLine1From:polyPoints[closestP1] toLine1End:polyPoints[closestP2] andLine2From:pt toLine2End:p2];
                
        if (correctDelta) {
            *correctDelta = CGSizeMake(pt.x - intersectionPt.x, pt.y - intersectionPt.y);
        }
    }
        
    return inside_flag;
}

/*
 *  Draw a debugging point
 */
-(void) debugDrawPoint:(CGPoint) pt asId:(NSString *) idKey andColor:(UIColor *) color
{
    static NSMutableDictionary *dict = nil;
    
    if (!dict) {
        dict = [[NSMutableDictionary alloc] init];
    }
    
    CALayer *l = [dict objectForKey:idKey];
    if (!color) {
        if (l) {
            [dict removeObjectForKey:idKey];
            [l removeFromSuperlayer];
        }
        return;
    }
    
    if (!l) {
        l                 = [[[CALayer alloc] init] autorelease];
        l.backgroundColor = [color CGColor];
        l.frame           = CGRectMake(0.0f, 0.0f, 5.0f, 5.0f);
        [self.layer addSublayer:l];
        [dict setObject:l forKey:idKey];
    }
    
    l.position = pt;
}

/*
 *  Simple debug routine for drawing the points in the preview pane.
 */
-(void) debugDrawPreviewPoints:(CGPoint [4]) previewPts
{
    for (int i = 0; i < 4; i++) {
        NSString *idName = [NSString stringWithFormat:@"pp%d", i];
        [self debugDrawPoint:previewPts[i] asId:idName andColor:[UIColor redColor]];
    }
}

/*
 *  Simple debug routine for drawing the points used to enforce contraints
 */
-(void) debugDrawConstraintPoints:(CGPoint [8]) conPts
{
    for (int i = 0; i < 8; i++) {
        NSString *idName = [NSString stringWithFormat:@"cp%d", i];
        [self debugDrawPoint:conPts[i] asId:idName andColor:[UIColor greenColor]];
    }
}

/*
 *  Compute whether the preview and view interset at the given rotation.
 *  - the exact edges of the collision octagon are returned here to allow
 *    the caller to decide the best course of action.
 *  - this is accomplished by determining if all the points of the collision volume are
 *    inside the preview window.  If they are, then the current attributes are OK.
 */
-(BOOL) doPreviewBoundsWithZoomLevel:(CGFloat) displayZoom encloseViewAtRotation:(CGFloat) rotation withOffset:(CGPoint) ptOffset andRubberband:(BOOL) allowRubberband
                withCorrectionOffset:(CGPoint *) toCorrect
{
    // - start by creating a bounding box that represents the pixels in the
    //   display image.
    CGSize szImage = [self imageSizeInPixels:displayImage];
    CGRect rcPreview = CGRectMake(0, 0, szImage.width/displayImage.scale, szImage.height/displayImage.scale);
    
    //  - the preview rectangle must be increased in size to ensure that collisions don't occur
    //    immediately with a scale 1.0, position (0, 0) configuration.
    rcPreview = CGRectInset(rcPreview, -0.5f, -0.5f);
 
    //  - the translation is between display pixels and view points
    CGPoint ptPreview[4];
    [self fillPoints:ptPreview fromRect:rcPreview];
    CATransform3D xform3D = [self transformForViewSide:CGRectGetWidth(self.bounds) andSourceImageSize:szImage andZoomLevel:displayZoom andSealOffset:ptOffset andRotation:rotation];
    CGAffineTransform xform = CATransform3DGetAffineTransform(xform3D);
    
    //  - now apply the transform to each point.
    for (int i = 0; i < 4; i++) {
        ptPreview[i] = CGPointApplyAffineTransform(ptPreview[i], xform);
    }
    
    //  - now the points are consistent with what a sublayer rotation will perform.
    //  - the next step is to take each edge one at a time and see if it intersects with
    //    the view's edges.
    //  - because a wax seal is being placed over this display, I'm going to test for intersection
    //    with an octagon to allow for a little of slush on the edges.
    CGPoint ptView[8];
    CGRect rcView    = self.bounds;
    if (allowRubberband) {
        rcView = CGRectInset(rcView, CGRectGetWidth(rcView) * CS_SIV2_RUBBER_BAND_SCALE, CGRectGetHeight(rcView) * CS_SIV2_RUBBER_BAND_SCALE);
    }
    [self fillOctagonPoints:ptView fromRect:rcView];
            
    //  - evaluate each point in the view volume to see
    //    if it is included entirely in the preview display
    //  - if not, adjust the preview rectangle to accommodate each one
    //    and measure the distance travelled.
    BOOL ret = YES;
    CGPoint ptFirstBefore = ptPreview[0];
    int numPts = sizeof(ptView)/sizeof(ptView[0]);
    for (int i = 0; i < numPts;) {
        CGSize correctTmp;
        if (![self isPoint:ptView[i] inPolygon:ptPreview ofNumberOfPoints:4 withCorrectionDelta:&correctTmp]) {
            //  - now we have a correction delta - use it to
            //    fix each point in the preview window
            for (int j = 0; j < 4; j++) {
                ptPreview[j].x += correctTmp.width;
                ptPreview[j].y += correctTmp.height;
            }
            
            //  - if this is the first time we encountered an invalid point, we
            //    need to start over to ensure that the move didn't invalidate
            //    prior good points
            if (ret) {
                i = 0;
            }
            
            ret = NO;
            
            //  - save on testing if the caller doesn't care about the offset.
            if (!toCorrect) {
                break;
            }
        }
        
        //  - add to the index ourselves to allow it to be reset
        //    in some situations.
        i++;
    }
        
    if (!ret) {
        //  - if the caller wants the correction vector, measure the distance travelled
        //    in the first point of the preview rectangle - which will be the distance
        //    for all of them.
        if (toCorrect) {
            *toCorrect = CGPointMake(ptPreview[0].x - ptFirstBefore.x, ptPreview[0].y - ptFirstBefore.y);
        }
    }
    return ret;
}

/*
 *  Image orientation is included in the current rotation transform.  Compute
 *  the right one now.
 */
-(CGFloat) orientationCorrectedRotationForImage:(UIImage *) img
{
    //  - auto-correct for orientation
    switch (img.imageOrientation) {
        case UIImageOrientationRight:
            return (CGFloat)M_PI/2.0f;
            break;
            
        //  - special because we invert the rotation later
        case UIImageOrientationRightMirrored:
            return (CGFloat) M_PI + ((CGFloat) M_PI/2.0f);
            break;
            
        case UIImageOrientationLeft:
            return -(CGFloat) M_PI/2.0f;
            break;

        //  - special because we invert the rotation later
        case UIImageOrientationLeftMirrored:
            return (CGFloat) M_PI - (CGFloat) M_PI/2.0f;
            break;
 
            
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            return (CGFloat) M_PI;
            break;
            
        case UIImageOrientationUp:
        case UIImageOrientationUpMirrored:
        default:
            //  do nothing
            break;
    }
    return 0.0f;
}

/*
 *  If you have both the original image and a generated preview image, you
 *  can set both and avoid a costly generation of a new preview.
 */
-(void) setSealImage:(UIImage *)img andPreviewImage:(UIImage *) previewImg
{
    //  - always reset editing when setting a new image.
    [self setEditingEnabled:NO];
    
    //  - save the images.
    if (displayImage != previewImg) {
        [displayImage release];
        displayImage = [previewImg retain];
    }
    
    if (originalSealImage != img) {
        [originalSealImage release];
        originalSealImage = [img retain];
    }
    
    // - reset the attributes of the image.
    mirrorHoriz  = mirrorVert = NO;
    if (img.imageOrientation == UIImageOrientationUpMirrored ||             // rare
        img.imageOrientation == UIImageOrientationDownMirrored) {
        mirrorVert = YES;
    }
    else if (img.imageOrientation == UIImageOrientationLeftMirrored ||      //  rare
             img.imageOrientation == UIImageOrientationRightMirrored) {
        mirrorHoriz = YES;
    }
    zoomLevel    = 1.0f;
    sealOffset   = CGPointZero;
    sealRotation = [self orientationCorrectedRotationForImage:img];
    maxZoomLevel = 1.0;
    
    //  - to compute the maximum scaling factor, we ignore the actual dimensions of
    //    the view and only consider the logical dimensions of the seal image, which is
    //    equal to its pixel dimensions.
    CGSize szImage = [self imageSizeInPixels:img];
    CGFloat smallSide = szImage.width;
    if (smallSide > szImage.height) {
        smallSide = szImage.height;
    }
    maxZoomLevel = (smallSide / CS_SIV2_ONE_SEAL_SIDE) * CS_SIV2_MAX_SCALE_FACTOR;
    if (maxZoomLevel < 1.0f) {
        maxZoomLevel = 1.0f;
    }
    
    //  - no animations when moving between images.
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    
    //  - only change the contents when the image changes.
    if (displayImage) {
        layerImagePreview.contents = (id) [displayImage CGImage];
    }
    else {
        layerImagePreview.contents = (id) NULL;
    }
    
    //  - always resize the image preview, even if there is no image.
    [self sizeAndOrientImagePreviewWithZoomLevel:zoomLevel andSealOffset:sealOffset andRotation:sealRotation];
    
    [CATransaction commit];
    
    //  - always update the version when the image changes
    [self updateVersion];
}

/*
 *  In order to allow a more precise experience, this delegate will be used to 
 *  determine if a touch is within a clipping radius and if it is not, then the touch will not be
 *  allowed.  
 */
-(BOOL) gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    //  - allow all other gesture recognizers to act normally.
    //  - also permit the zoom/rotation to work in a larger space because big
    //    banana fingers have trouble working in tight spaces.
    if (gestureRecognizer != tapGesture && gestureRecognizer != panGesture) {
        return YES;
    }
    
    //  - if any of the points are outside the boundaries of the clipping
    //    circle, then discard the gesture.
    CGPoint ptCenter = CGPointMake(CGRectGetWidth(self.bounds)/2.0f, CGRectGetHeight(self.bounds)/2.0f);
    CGPoint adjustedRadius = CGPointMake(ptCenter.x * hitClipPct, ptCenter.y * hitClipPct);
    for (NSUInteger i = 0; i < gestureRecognizer.numberOfTouches; i++) {
        CGPoint ptLoc = [gestureRecognizer locationOfTouch:i inView:self];
        CGFloat dx = ptCenter.x - ptLoc.x;
        CGFloat dy = ptCenter.y - ptLoc.y;
        CGFloat distance = sqrtf((float)((dx*dx) + (dy*dy)));
        if (distance > adjustedRadius.x || distance > adjustedRadius.y) {
            return NO;
        }
    }
    return YES;
}

/*
 *  Update the version number in the object.
 */
-(void) updateVersion
{
    editVersion++;
    if (delegate && [delegate respondsToSelector:@selector(sealImageWasModified:)]) {
        [delegate performSelector:@selector(sealImageWasModified:) withObject:self];
    }
}

@end