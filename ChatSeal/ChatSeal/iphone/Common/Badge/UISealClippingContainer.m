//
//  UISealClippingContainer.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/12/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "UISealClippingContainer.h"
#import "UISealWaxViewV2.h"
#import "ChatSeal.h"
#import "UIAddPhotoSignView.h"

// - constants
static const CGFloat UINSB_CONTENT_CLIP_RADIUS  = 0.79f;            //  the percentage of the radius used to recognize gestures.
static const CGFloat UINSB_ADD_PHOTO_PCT        = 0.75f;

// - forward declarations
@interface UISealClippingContainer (internal)
-(void) configure;
-(CGRect) contentFrameForExtended:(BOOL) extendDisplay;
-(CGFloat) zIndexForExtended:(BOOL) extendDisplay;
-(void) setBorderForExtended:(BOOL) extendDisplay;
-(void) updateSealImagePlaceholderWithAnimation:(BOOL) animated;
-(void) updateLabelDimensions;
@end

/**************************
 UISealClippingContainer
 - provide a unform scheme for
   precise wax clipping.
 **************************/
@implementation UISealClippingContainer
/*
 *  Object attributes
 */
{
    CGSize             szLastDims;
    BOOL               isExtended;
    UIView             *contentView;
    UISealImageViewV2  *sealView;
    UIImageView        *ivSimple;
    UIAddPhotoSignView *vwAddPhoto;
    BOOL               isNoPhotoVisible;
    BOOL               isSimpleDisplay;
}

/*
 *  Initialize the object
 */
-(id) init
{
    self = [super init];
    if (self) {
        [self configure];
    }
    return self;
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self configure];
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
        [self configure];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [vwAddPhoto release];
    vwAddPhoto = nil;
    
    [sealView release];
    sealView = nil;
    
    [contentView release];
    contentView = nil;
    
    [ivSimple release];
    ivSimple = nil;
    
    [super dealloc];
}

/*
 *  Perform sub-view layout.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];

    CGSize curDims = self.bounds.size;
    if ((int) curDims.width != (int) szLastDims.width ||
        (int) curDims.height != (int) szLastDims.height) {
        szLastDims = curDims;
        
        //  - the content view is what contains the
        //    camera and image views and is sized
        //    to precisely to the known bounds of the
        //    wax around it.
        CGRect rc                      = [self contentFrameForExtended:isExtended];
        contentView.frame              = CGRectIntegral(rc);
        contentView.layer.cornerRadius = CGRectGetHeight(rc)/2.0f;
        self.layer.zPosition           = [self zIndexForExtended:isExtended];
        [self setBorderForExtended:isExtended];
        [self updateLabelDimensions];
    }
}

/*
 *  Return the seal image view contained in this container.
 */
-(UISealImageViewV2 *) sealImageView
{
    return [[sealView retain] autorelease];
}

/*
 *  Using the known dimensions of the inside of the wax border, clip the 
 *  seal image's hit testing accordingly.
 */
-(void) hitClipToInsideWax
{
    [sealView setHitClippingRadiusPct:UINSB_CONTENT_CLIP_RADIUS];
}

/*
 *  Return the content view for this container.
 */
-(UIView *) contentView
{
    return [[contentView retain] autorelease];
}

/*
 *  Return the view used to prompt for adding a photo.
 */
-(UIView *) addPhotoView
{
    return [[vwAddPhoto retain] autorelease];
}

/*
 *  Change the view style.
 */
-(void) setExtendedView:(BOOL) extendDisplay withAnimation:(BOOL) isAnimated andCompletion:(void(^)(void))completionBlock
{
    if (isSimpleDisplay) {
        NSLog(@"CS-ALERT: extended view is not available when using simple display seal clipping.");
        return;
    }
    
    isExtended = extendDisplay;
    
    // - we're going to add a little to the completion routine.
    void (^customCompletion)(void) = ^(void) {
        [self setNoPhotoVisible:isNoPhotoVisible && !extendDisplay withAnimation:isAnimated];
        if (completionBlock) {
            completionBlock();
        }
    };
    
    //  - if animating, we have to do this slowly
    if (isAnimated) {
        NSTimeInterval animDuration = [ChatSeal animationDurationForSealPop:extendDisplay];
        CGRect rc = [self contentFrameForExtended:extendDisplay];
        CGFloat curZIndex = self.layer.zPosition;
        if (curZIndex < 1.0f) {
            //  - so that it always overlays the wax layers.
            curZIndex = 1.0f;
        }
        CGFloat newZIndex = [self zIndexForExtended:extendDisplay];
        CGRect rcBounds = CGRectMake(0.0f, 0.0f, CGRectGetWidth(rc), CGRectGetHeight(rc));
        CAMediaTimingFunction *popTiming = [ChatSeal standardTimingFunctionForSealPop:extendDisplay];
        [UIView animateWithDuration:animDuration animations:^(void){
            [CATransaction begin];
            [CATransaction setCompletionBlock:customCompletion];
            [CATransaction setAnimationDuration:animDuration];
            [CATransaction setAnimationTimingFunction:popTiming];
            
            CABasicAnimation *ba = [CABasicAnimation animationWithKeyPath:@"zPosition"];
            [ba setFromValue:[NSNumber numberWithFloat:(float) curZIndex]];
            [ba setToValue:[NSNumber numberWithFloat:(float) newZIndex]];
            [self.layer addAnimation:ba forKey:@"zPosition"];
            self.layer.zPosition = newZIndex;
            
            ba = [CABasicAnimation animationWithKeyPath:@"cornerRadius"];
            CGFloat radius = CGRectGetHeight(rc)/2.0f;
            [ba setFromValue:[NSNumber numberWithFloat:(float) self.contentView.layer.cornerRadius]];
            [ba setToValue:[NSNumber numberWithFloat:(float) radius]];
            [self.contentView.layer addAnimation:ba forKey:@"cornerRadius"];
            self.contentView.layer.cornerRadius = radius;
            
            ba = [CABasicAnimation animationWithKeyPath:@"bounds"];
            [ba setToValue:[NSValue valueWithCGRect:rcBounds]];
            [self.contentView.layer addAnimation:ba forKey:@"bounds"];
            self.contentView.bounds = rcBounds;
            
            [self updateLabelDimensions];
            
            [CATransaction commit];
        }];
    }
    else {
        // ...otherwise, rush it through.
        szLastDims = CGSizeZero;
        [self setNeedsLayout];
        [self layoutIfNeeded];
        [self updateLabelDimensions];
        customCompletion();
    }
    [self setBorderForExtended:extendDisplay];
}

/*
 *  Return the current extended mode state.
 */
-(BOOL) isExtended
{
    return isExtended;
}

/*
 *  Configure the seal image view using another.
 */
-(void) copyAllAttributesFromSealView:(UISealImageViewV2 *) otherSealView
{
    [sealView copyAllAttributesFromSealView:otherSealView];
    [self updateSealImagePlaceholderWithAnimation:YES];
}

/*
 *  Set the seal image in the seal view.
 */
-(void) setSealImage:(UIImage *) image
{
    if (isSimpleDisplay) {
        ivSimple.image = image;
    }
    else {
        [sealView setSealImage:image];
        [self updateSealImagePlaceholderWithAnimation:YES];
    }
}

/*
 *  Return the current seal image.
 */
-(UIImage *) sealImage
{
    if (isSimpleDisplay) {
        return ivSimple.image;
    }
    else {
        return [sealView standardizedSealImage];
    }
}

/*
 *  Show/hide the no-photo text.
 */
-(void) setNoPhotoVisible:(BOOL) isVisible withAnimation:(BOOL) animated
{
    CGFloat alpha = isVisible ? 1.0f : 0.0f;
    isNoPhotoVisible = isVisible;
    if (animated) {
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void){
            vwAddPhoto.alpha = alpha;
        }];
    }
    else {
        vwAddPhoto.alpha = alpha;
    }
}

/*
 *  Animate the gloss effect on the crown.
 */
-(void) triggerGlossEffect
{
    [vwAddPhoto triggerGlossEffect];
}

/*
 *  A dynamic type update was received.
 */
-(void) updateDynamicTypeNotificationReceived
{
    [vwAddPhoto updateDynamicTypeNotificationReceived];
}

/*
 *  Occasionally we want to coordinate the resize of this container with
 *  a different animation that is already in progress.
 */
-(void) coordinateSizingWithBoundsAnimation:(CAAnimation *) anim
{
    // - now the corner radius.
    if (contentView.layer.presentationLayer) {
        CABasicAnimation *animCorner = [ChatSeal duplicateAnimation:anim forNewKeyPath:@"cornerRadius"];
        animCorner.fromValue         = [NSNumber numberWithFloat:(float)((CALayer *)contentView.layer.presentationLayer).cornerRadius];
        animCorner.toValue           = [NSNumber numberWithFloat:(float) contentView.layer.cornerRadius];
        [contentView.layer addAnimation:animCorner forKey:@"cornerRadius"];
    }
}

/*
 *  Convert the content in this view to use a simple display approach, which involves only
 *  an image view and no editing features.
 */
-(void) convertToSimpleDisplay
{
    if (isSimpleDisplay) {
        return;
    }
    
    // - we don't allow extended views with simple display.
    if (isExtended) {
        [self setExtendedView:NO withAnimation:NO andCompletion:nil];
    }
    
    isSimpleDisplay = YES;

    // - create the new view.
    ivSimple                  = [[UIImageView alloc] initWithFrame:sealView.frame];
    ivSimple.image            = [sealView standardizedSealImage];
    ivSimple.contentMode      = UIViewContentModeScaleAspectFill;
    ivSimple.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [contentView addSubview:ivSimple];
    
    // - remove the ones we don't need any longer.
    [sealView removeFromSuperview];
    [sealView release];
    sealView = nil;
    
    [vwAddPhoto removeFromSuperview];
    [vwAddPhoto release];
    vwAddPhoto = nil;
}

@end


/**********************************
 UISealClippingContainer (internal)
 **********************************/
@implementation UISealClippingContainer (internal)
/*
 *  Configure the attributes of the view.
 */
-(void) configure
{
    szLastDims       = CGSizeZero;
    isExtended       = NO;
    isNoPhotoVisible = YES;
    isSimpleDisplay  = NO;
    vwAddPhoto       = nil;
    sealView         = nil;
    ivSimple         = nil;
    
    //  - make sure the view is transparent.
    self.backgroundColor               = [UIColor clearColor];
    
    //  - now configure the view that holds the controls
    CGRect rcFullBounds = CGRectMake(0.0f, 0.0f, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
    contentView = [[UIView alloc] initWithFrame:rcFullBounds];
    contentView.backgroundColor = [UIColor whiteColor];
    contentView.clipsToBounds = YES;
    [self addSubview:contentView];
    
    // - make it slightly larger to ensure that the wax always overlays the edge
    CGRect rcImage = CGRectInset(rcFullBounds, -1.0f, -1.0f);
    
    // - the add photo label is used to indicate that a photo should be chosen.
    vwAddPhoto = [[UIAddPhotoSignView alloc] init];
    [contentView addSubview:vwAddPhoto];
    [self updateLabelDimensions];
    
    //  - the seal view is used as the primary location for
    //    storing assets in the new seal view.
    sealView = [[UISealImageViewV2 alloc] initWithFrame:rcImage];
    sealView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [contentView addSubview:sealView];
}

/*
 *  Change the content frame's dimensions.
 */
-(CGRect) contentFrameForExtended:(BOOL) extendDisplay
{
    CGRect rc = self.bounds;
    CGFloat diam = 0.0f;
    if (extendDisplay) {
        diam = CGRectGetWidth(rc);
    }
    else {
        diam = [UISealWaxViewV2 centerDiameterFromRect:rc] - 2.0f;
    }
    return CGRectMake(CGRectGetWidth(rc)/2.0f - (diam/2.0f), CGRectGetHeight(rc)/2.0f - (diam/2.0f), diam, diam);
}

/*
 *  Return a proper z-index based on the extended state.
 */
-(CGFloat) zIndexForExtended:(BOOL) extendDisplay
{
    if (extendDisplay) {
        return 100.0f;
    }
    else {
        return 0.0f;
    }
}

/*
 *  Set the size of the border based on whether we're in extended mode.
 */
-(void) setBorderForExtended:(BOOL) extendDisplay
{
    if (extendDisplay) {
        contentView.layer.borderColor = [[UIColor colorWithRed:0.65f green:0.65f blue:0.65f alpha:0.70f] CGColor];
        contentView.layer.borderWidth = 2.0f;
    }
    else {
        contentView.layer.borderColor = NULL;
        contentView.layer.borderWidth = 0.0f;
    }
}

/*
 *  Update the placeholder depending on whether the seal image is visible.
 */
-(void) updateSealImagePlaceholderWithAnimation:(BOOL) animated
{
    void (^updateValues)(void) = ^(void) {
        if (sealView.hasSealImage || !isNoPhotoVisible) {
            vwAddPhoto.alpha = 0.0f;
        }
        else {
            vwAddPhoto.alpha = 1.0f;
        }
    };
    
    if (animated) {
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:updateValues];
    }
    else {
        updateValues();
    }
}

/*
 *  Make sure the label is sized appropriately.
 */
-(void) updateLabelDimensions
{
    CGRect rc = self.contentView.bounds;
    CGFloat width = CGRectGetWidth(rc) * UINSB_ADD_PHOTO_PCT;
    vwAddPhoto.bounds = CGRectMake(0.0f, 0.0f, width, width);
    vwAddPhoto.center = CGPointMake(CGRectGetWidth(rc)/2.0f, CGRectGetHeight(rc)/2.0f);
}

@end