#if 0
//
//  UISecureImageViewV3.m
//  ChatSeal
//
//  Created by Francis Grolemund on 11/25/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <GLKit/GLKit.h>
#import <OpenGLES/ES2/gl.h>
#import <QuartzCore/QuartzCore.h>
#import "UISecureImageViewV3.h"
#import "ChatSeal.h"
#import "UIImageGeneration.h"
#import "UISecureShaderV2.h"
#import "ChatSealWeakOperation.h"

//// - constants
//#define UISIV3_DEBUG_STOP_IMAGE_FLIPPING 0
//static const CGFloat    UISIV3_MAX_IMAGE_PXDIM = 1024.0f;
static const NSUInteger UISIV3_SEC_ARRAY_LEN   = 400 + 1;         // arbitrary, except that a larger value (less than 400) will provide more variation.  Always add one for the background.
//static const NSUInteger UISIV3_TARGET_FPS      = 60;
//static const NSUInteger UISIV3_SEEN_PER_SEC    = 22;
static const NSUInteger UISIV3_ROT_DELTAS      = UISIV3_TARGET_FPS/UISIV3_SEEN_PER_SEC;
static const CGFloat    UISIV3_ROT_PER_FRAME   = 1.0f / (CGFloat) UISIV3_ROT_DELTAS;
static const NSUInteger UISIV3_ENTROPY_LEN     = 2048;
//static const GLsizei    UISIV3_VTX_PER_RECT    = 4;
//static const NSUInteger UISIV3_NUM_GACS_SEG    = 3;
//static const NSUInteger UISIV3_BASE_SEG_CIRCLE = 17;
//static const NSUInteger UISIV3_ADD_SEG_FOR_PX  = 8;              // for every N pixels, add a new segment to the ring.
//static const CGFloat    UISIV3_RINGS_PER_IMAGE = 8.0f;
static const GLshort    UISIV3_POLY_BACKGROUND = 0;
//static const NSUInteger UISIV3_NUM_CLIP_POLYS  = 4;
//static const CGFloat    UISIV3_TIME_TO_ENABLE  = 0.5f;
static const NSUInteger UISIV3_ENTROPY_TIMEOUT = 1;

// - forward references
@interface UISecureImageViewV3 (internal)
//-(void) commonConfiguration;
//-(CGSize) imagePixelDimensions:(UIImage *) img;
//-(UIImage *) enforceMaximumImageDimension:(UIImage *) img;
//-(void) displayLinkCalled:(CADisplayLink *) sender;
//-(void) updateGLStateWithCurrentTime:(CFTimeInterval) curTime;
-(NSMutableData *) generateSecureRotationConstantsWithEntropy:(NSData *) curEntropy;
//-(BOOL) verifyShaderResourcesWithError:(NSError   **) err;
//-(BOOL) configureCoreGLWithError:(NSError **) err;
//-(GLsizei) bufferStride;
//-(BOOL) loadTexturesWithSecure:(UIImage *) imgSec andBackground:(UIImage *) imgBG;
//-(BOOL) configureImageSpecificGLForSecure:(UIImage *) imgSecure andBackground:(UIImage *) imgBG withError:(NSError **) err;
//-(void) teardownImageSpecificGL;
//-(void) teardownCoreGL;
@end

//@interface UISecureImageViewV3 (model)
//-(void) addVertex:(CGPoint) ptVertex atTextureLocation:(CGPoint) texPos withGridOffset:(CGPoint) gridOffset asIndex:(GLshort) index atLocation:(unsigned char *) ptr
// usingVertexIndex:(GLushort *) vIndex;
//-(NSArray *) addPolyRect:(CGRect) rc withTexture:(CGRect) rcTexture andGridOffset:(CGPoint) gridOffset asSecurePoly:(GLshort) polyIndex
//                inBuffer:(NSMutableData *) dBuffer withVertexIndex:(GLushort *) vIndex;
//-(NSData *) pointsForCircleAtCenter:(CGPoint) ptCenter ofRadius:(CGFloat)radius andCount:(NSUInteger) numPoints;
//-(NSUInteger) numPointsForSegments:(NSUInteger) numSegments;
-(NSData *) entropyDefinedIndexArray;
//-(void) addImageSpecificVertex:(CGPoint) ptVertex withPolyCenter:(CGPoint) ptPolyCenter asIndex:(GLshort) index atLocation:(unsigned char *) ptr usingVertexIndex:(GLushort *) vIndex;
//-(NSArray *) addPolyRingSegmentWithInnerPoints:(NSData *) dInnerPoints andOuterPoints:(NSData *) dOuterPoints startingAtIndex:(NSUInteger) firstOffset
//                                     withCount:(NSUInteger) numPoints asSecurePoly:(GLshort) polyIndex inBuffer:(NSMutableData *) mdBuffer withVertIndex:(GLushort *) vIndex;
//-(NSArray *) addPolyCircleAtCenter:(CGPoint) ptCenter withPoints:(NSData *) dPoints ofCount:(NSUInteger) numPoints inBuffer:(NSMutableData *) mdBuffer withVertexIndex:(GLushort *) vIndex;
//-(NSArray *) addAllSecurePolysInBuffer:(NSMutableData *) dBuffer withVertexIndex:(GLushort *) vIndex;
//-(void) generateSecureModel;
@end
//
//@interface UISecureImageViewV3 (draw)  <GLKViewDelegate>
//-(GLKMatrix4) baselineModelViewMatrix;
//@end

/*********************
 UISecureImageViewV3
 *********************/
@implementation UISecureImageViewV3
///*
// *  Object attributes.
// */
//{
//    EAGLContext         *context;
//    GLKView             *glView;
//    CADisplayLink       *dlRender;
//    UISecureShaderV2    *ssShader;
//    BOOL                shaderBuildFailure;
//    GLuint              vaoVertexArray;
//    GLuint              vertexBuffer;
//    GLuint              indexBuffer;
//    GLuint              blurTexName;
//    GLuint              texName;
//    NSMutableData       *mdVertexBuffer;
//    NSMutableData       *mdVertexIndexBuffer;
//    NSMutableData       *mdPolyCountsBuffer;
//    NSUInteger          endOfSecurePolys;
//    NSUInteger          numPolys;
//    CGSize              szImage;
//    NSUInteger          frameCount;
    NSMutableData       *mdSecureRotations;
    CGFloat             curRotation;
    NSMutableData       *mdEntropy;
    BOOL                entropyMalfunctioning;
    NSUInteger          entropyOffset;
    
//    BOOL                isAnimatingSecurely;
//    BOOL                requiresNewViewMatrix;
//    BOOL                isRedrawEnabled;
//    NSUInteger          lastEnabledSecurePoly;
//    NSTimeInterval      lastTime;
//    NSTimeInterval      totalElapsed;
//    BOOL                hasFirstFrame;
//    BOOL                isOnline;
}
//@synthesize delegate;

///*
// *  Initialize the object.
// */
//-(id) initWithCoder:(NSCoder *)aDecoder
//{
//    self = [super initWithCoder:aDecoder];
//    if (self) {
//        [self commonConfiguration];
//    }
//    return self;
//}
//
///*
// *  Initialize the object.
// */
//- (id)initWithFrame:(CGRect)frame
//{
//    self = [super initWithFrame:frame];
//    if (self) {
//        [self commonConfiguration];
//    }
//    return self;
//}

///*
// *  In order to break the retain cycle with the render display link
// *  we must first call this method.
// */
//-(void) prepareForRelease
//{
//    [dlRender invalidate];
//}

///*
// *  Free the object.
// */
//-(void) dealloc
//{
//    delegate = nil;
//
//    //  - free up the GL-specific resources first
//    [self teardownCoreGL];
//    [EAGLContext setCurrentContext:nil];
//    
//    // - now the more UIKit-focused ones.
//    [dlRender release];
//    dlRender = nil;
//    
//    [ssShader release];
//    ssShader = nil;
//    
//    [glView release];
//    glView = nil;
//    
//    [context release];
//    context = nil;
//    
//    [mdVertexBuffer release];
//    mdVertexBuffer = nil;

    [mdSecureRotations release];
    mdSecureRotations = nil;
    
    [mdEntropy release];
    mdEntropy = nil;
//    
//    [super dealloc];
//}

///*
// *  Assign the secure image and its background counterpart to this object.
// */
//-(BOOL) setSecureImage:(UIImage *) imgSec andBlurredBackground:(UIImage *) imgBG withError:(NSError **) err
//{
//    if (!imgSec || !imgBG) {
//        [CS_error fillError:err withCode:CSErrorInvalidArgument];
//        return NO;
//    }
//    
//    // - ensure that the two images don't exceed our maximums.
//    imgSec = [self enforceMaximumImageDimension:imgSec];
//    imgBG  = [self enforceMaximumImageDimension:imgBG];
//    
//    // - verify that the conversions occurred
//    if (!imgSec || !imgBG) {
//        [CS_error fillError:err withCode:CSErrorInvalidArgument andFailureReason:@"The secure image could not be converted to a suitable display format."];
//        return NO;
//    }
//
//    // - make sure that OpenGL is enabled
//    if (!context) {
//        if (![self configureCoreGLWithError:err]) {
//            return NO;
//        }
//    }
//    
//    // - finally, prepare the vertices and textures that will make this work.
//    if (![self configureImageSpecificGLForSecure:imgSec andBackground:imgBG withError:err]) {
//        return NO;
//    }
//    return YES;
}

///*
// *  Enable/disable the display of the secure image animation.
// */
//-(void) setSecureDisplayEnabled:(BOOL) enabled
//{
//    if (isAnimatingSecurely == enabled) {
//        return;
//    }
//    isAnimatingSecurely = enabled;
//    totalElapsed        = 0.0f;

    // - force the secure rotations to be recomputed the next time.
    [mdSecureRotations release];
    mdSecureRotations   = nil;
}

///*
// *  Lay out the content.
// */
//-(void) layoutSubviews
//{
//    [super layoutSubviews];
//    requiresNewViewMatrix = YES;
//    [self verifyShaderResourcesWithError:nil];
//}

///*
// *  Enable/disable full redraw, which completely turns off everything.
// */
//-(void) setRedrawEnabled:(BOOL) enabled
//{
//    if (isRedrawEnabled == enabled) {
//        return;
//    }
//    isRedrawEnabled = enabled;
//    hasFirstFrame   = NO;
//    
//    // - with redraw off, the final notifications won't be sent, so
//    //   make sure we set the online/offline explicitly
//    isOnline = isAnimatingSecurely;
}

@end


/******************************
 UISecureImageViewV3 (internal)
 ******************************/
@implementation UISecureImageViewV3 (internal)
///*
// *  Configure the object.
// */
//-(void) commonConfiguration
//{
//    context               = nil;
//    glView                = nil;
//    dlRender              = nil;
//    ssShader              = nil;
//    shaderBuildFailure    = NO;
//    vertexBuffer          = 0;
//    indexBuffer           = 0;
//    vaoVertexArray        = 0;
//    blurTexName           = 0;
//    texName               = 0;
//    mdVertexBuffer        = nil;
//    mdVertexIndexBuffer   = nil;
//    mdPolyCountsBuffer    = nil;
//    numPolys              = 0;
    mdSecureRotations     = nil;
    curRotation           = 0.0f;
//    frameCount            = 0;
    mdEntropy             = nil;
    entropyOffset         = 0;
    entropyMalfunctioning = NO;
//    isAnimatingSecurely   = NO;
//    requiresNewViewMatrix = YES;
//    isRedrawEnabled       = YES;
//    lastEnabledSecurePoly = 0;
//    totalElapsed          = 99999.0f;                       //  we're not animating by default, so we don't want the startup animation to fire.
//    lastTime              = 0.0f;
//    delegate              = nil;
//    hasFirstFrame         = NO;
//    isOnline              = NO;
//}

///*
// *  Compute the size of the image in pixels.
// */
//-(CGSize) imagePixelDimensions:(UIImage *) img
//{
//    CGSize sz  = img.size;
//    sz.width  *= img.scale;
//    sz.height *= img.scale;
//    return sz;
//}
//
///*
// *  In order to ensure that provided images don't exceed the limits of the video card, we'll
// *  scale them.
// */
//-(UIImage *) enforceMaximumImageDimension:(UIImage *) img
//{
//    CGSize sz       = [self imagePixelDimensions:img];
//    CGFloat scaleTo = 1.0f;
//    
//    if (sz.width > sz.height) {
//        if (sz.width <= UISIV3_MAX_IMAGE_PXDIM) {
//            return img;
//        }
//        scaleTo = UISIV3_MAX_IMAGE_PXDIM/sz.width;
//    }
//    else {
//        if (sz.height <= UISIV3_MAX_IMAGE_PXDIM) {
//            return img;
//        }
//        scaleTo = UISIV3_MAX_IMAGE_PXDIM/sz.height;
//    }
//    return [UIImageGeneration image:img scaledTo:scaleTo asOpaque:YES];
//}
//
///*
// *  Configure the fundamental OpenGL entities that permit rendering.
// */
//-(BOOL) configureCoreGLWithError:(NSError **) err
//{
//    if (context) {
//        return YES;
//    }
//    
//    // - the context will store the state.
//    context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
//    
//    // - the view will render it.
//    glView                       = [[GLKView alloc] initWithFrame:self.bounds context:context];
//    glView.enableSetNeedsDisplay = NO;
//    glView.autoresizingMask      = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
//    glView.delegate              = self;
//    [self addSubview:glView];
//    
//    // - push updates through the view as fast as we can go.
//    dlRender                     = [[CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCalled:)] retain];
//    dlRender.frameInterval       = 1;               //  we want this to go as fast as possible, everything assumes 60FPS.
//    [dlRender addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
//    
//    // - try to build the shaders
//    return [self verifyShaderResourcesWithError:err];
//}

///*
// *  Manage the updates.
// */
//-(void) displayLinkCalled:(CADisplayLink *) sender
//{
//    // - update and display the image.
//    [self updateGLStateWithCurrentTime:sender.timestamp];
//    [glView display];
//}
//
///*
// *  Perform updates to the animation state.
// */
//-(void) updateGLStateWithCurrentTime:(CFTimeInterval) curTime
//{
//    //  - update the current rotation for each item.
//    curRotation += UISIV3_ROT_PER_FRAME;
//    if (curRotation > 1.0f) {
//        curRotation -= 1.0f;
//    }
//    
//    // - only animate when we're recieving regular updates and our time basis is recent
//    if (curTime - lastTime < 1.0f) {
//        //  - when we're enabling/disabling the secure display that involves
//        //    moving the index for the last secure polygon up or down based on the
//        //    elapsed time.
//        totalElapsed       += (curTime - lastTime);
//        CGFloat pctOfTotal  = totalElapsed / UISIV3_TIME_TO_ENABLE;
//        if (pctOfTotal > 1.0f) {
//            pctOfTotal = 1.0f;
//        }
//        NSUInteger numDelta = (NSUInteger) (((CGFloat) (endOfSecurePolys - 1)) * pctOfTotal);
//        NSUInteger priorValue = lastEnabledSecurePoly;
//        if (isAnimatingSecurely) {
//            lastEnabledSecurePoly = 1 + numDelta;
//        }
//        else {
//            lastEnabledSecurePoly = endOfSecurePolys - numDelta;
//        }
//        
//        // - notify the delegate when things change
//        if (lastEnabledSecurePoly != priorValue) {
//            if (isAnimatingSecurely) {
//                if (!isOnline && lastEnabledSecurePoly == endOfSecurePolys) {
//                    isOnline = YES;
//                    if (delegate && [delegate respondsToSelector:@selector(secureImageDisplayOnline:)]) {
//                        [delegate performSelector:@selector(secureImageDisplayOnline:) withObject:self];
//                    }
//                }
//            }
//            else {
//                if (isOnline && lastEnabledSecurePoly == 1) {
//                    isOnline = NO;
//                    if (delegate && [delegate respondsToSelector:@selector(secureImageDisplayOffline:)]) {
//                        [delegate performSelector:@selector(secureImageDisplayOffline:) withObject:self];
//                    }
//                }
//            }
//        }
//    }
//    lastTime = curTime;
//}

/*
 *  Using the entropy buffer, generate secure rotation constants and return them.
 */
-(NSMutableData *) generateSecureRotationConstantsWithEntropy:(NSData *) curEntropy
{
    // - don't forget we need one for the background also, even though it will never be modified.
    NSMutableData *dRet = [NSMutableData dataWithLength:UISIV3_SEC_ARRAY_LEN * sizeof(GLfloat)];
    
    // - use the entropy array to create random starting locations for each block.
    const unsigned char *pRandom = (const unsigned char *) curEntropy.bytes;
    
    // - now create random percentages, but ensure
    //   the first one is zero so the background never moves
    GLfloat *ptr          = (GLfloat *) dRet.mutableBytes;
    ptr[0]                = 0.0f;
    for (NSUInteger i = 1; i < UISIV3_SEC_ARRAY_LEN; i++) {
        entropyOffset = (entropyOffset + 1) % UISIV3_ENTROPY_LEN;
        ptr[i] = ((GLfloat) (pRandom[entropyOffset] % UISIV3_ROT_DELTAS)) * UISIV3_ROT_PER_FRAME;
    }
    return dRet;
}

///*
// *  Ensure the shader is ready for use.
// */
//-(BOOL) verifyShaderResourcesWithError:(NSError **) err
//{
//    // - before the secure shader can be compiled, we need to have some dimension
//    CGRect bounds = self.bounds;
//    if (ssShader || !context || shaderBuildFailure || CGRectGetWidth(bounds) < 1.0f || CGRectGetHeight(bounds) < 1.0f) {
//        return !shaderBuildFailure;
//    }
//    
//    glView.frame = bounds;
//    [EAGLContext setCurrentContext:context];
//    [glView bindDrawable];
//    ssShader = [[UISecureShaderV2 alloc] initWithSecureRandomLen:UISIV3_SEC_ARRAY_LEN];
//    if (![ssShader compileAndLinkWithError:err]) {
//        [ssShader release];
//        ssShader = nil;
//        shaderBuildFailure = YES;
//        return NO;
//    }
//    return YES;
//}

///*
// *  Return the length of each item in the vertex buffer.
// */
//-(GLsizei) bufferStride
//{
//    // - each vertex will be made of the following:
//    //   GLfloat pos(x, y)
//    //   GLfloat tex(x, y)
//    //   Glfloat grid_offset(x, y)
//    //   Glfloat cell_index  (because attributes cannot be ints)
//    // - this will allow us to not only rotate them individually in the shader, but also
//    //   associate changing random values with it by cell index.
//    static const GLsizei ret = (sizeof(GLfloat) * 2) + (sizeof(GLfloat) * 2) + (sizeof(GLfloat) * 2) + sizeof(GLfloat);
//    return ret;
//}


///*
// *  Load the two textures we'll use.
// */
//-(BOOL) loadTexturesWithSecure:(UIImage *) imgSec andBackground:(UIImage *)imgBG
//{
//    // - load the blurred texture
//    NSError *err = nil;
//    GLKTextureInfo *texInfo = [GLKTextureLoader textureWithCGImage:[imgBG CGImage] options:NULL error:&err];
//    if (!texInfo) {
//        NSLog(@"CS: Failed to load a blurred secure texture for the provided image handle.  %@", [err localizedDescription]);
//        return NO;
//    }
//    
//    blurTexName = texInfo.name;
//    
//    // - load the official image
//    texInfo = [GLKTextureLoader textureWithCGImage:[imgSec CGImage] options:NULL error:&err];
//    if (!texInfo) {
//        glDeleteTextures(1, &blurTexName);
//        NSLog(@"CS: Failed to load a secure texture for the provided image handle.  %@", [err localizedDescription]);
//        return NO;
//    }
//    texName = texInfo.name;
//    
//    return YES;
//}

///*
// *  Configure all the image-specific GL resources.
// */
//-(BOOL) configureImageSpecificGLForSecure:(UIImage *) imgSec andBackground:(UIImage *) imgBG withError:(NSError **) err
//{
//    [self teardownImageSpecificGL];
//    
//    // - just a simple black background.
//    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
//    if (!context || !imgSec) {
//        [CS_error fillError:err withCode:CSErrorOpenGLRenderError andFailureReason:@"Incomplete context or resources."];
//        return NO;
//    }
//    
//    // - load the textures.
//    if (![self loadTexturesWithSecure:imgSec andBackground:imgBG]) {
//        [CS_error fillError:err withCode:CSErrorOpenGLRenderError andFailureReason:@"Failed to load the secure textures."];
//        return NO;
//    }
//    
//    // - the size of the image we care about, which will influence the display transform.
//    szImage = [self imagePixelDimensions:imgSec];
//    
//    // - enable only the features we need, disable all others.
//    glEnable(GL_BLEND);
//    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
//    glEnable(GL_CULL_FACE);
//    glFrontFace(GL_CW);         // to match the polygon winding.
//    glDisable(GL_DEPTH_TEST);
//    glDisable(GL_SCISSOR_TEST);
//    glDisable(GL_STENCIL_TEST);
//    
//    // - bind the textures
//    glActiveTexture(GL_TEXTURE0);
//    glBindTexture(GL_TEXTURE_2D, blurTexName);
//    glActiveTexture(GL_TEXTURE1);
//    glBindTexture(GL_TEXTURE_2D, texName);
//    
//    // - build a server-side vertex array bundle the describes
//    //   the polygon and how it is wired into the shader.
//    // - since we only use a single vertex array for all drawing operations
//    //   we'll bind it once and leave it where it is.
//    glGenVertexArraysOES(1, &vaoVertexArray);
//    glBindVertexArrayOES(vaoVertexArray);
//    
//    //  ...create the buffer for the polygons
//    glGenBuffers(1, &vertexBuffer);
//    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
//    
    //  ...generate the entropy array for secure processing
    mdEntropy = [[NSMutableData alloc] initWithLength:UISIV3_ENTROPY_LEN];
    unsigned char *pRandom = (unsigned char *) mdEntropy.mutableBytes;
    if (SecRandomCopyBytes(kSecRandomDefault, UISIV3_ENTROPY_LEN, (uint8_t *) pRandom) != 0) {
        if (!entropyMalfunctioning) {
            NSLog(@"CS:  The secure random generator is malfunctioning for image preview.");
            entropyMalfunctioning = YES;
        }
        // - if the secure random method fails, we still need something.
        for (NSUInteger i = 0; i < UISIV3_ENTROPY_LEN; i++) {
            *pRandom = (unsigned char) rand();
        }
    }
    
//    // ... and finally all the vertices
//    mdVertexBuffer = [[NSMutableData alloc] init];
//    @autoreleasepool {
//        [self generateSecureModel];
//    }
//    
//    //  ...and wire up the pointers.
//    glBufferData(GL_ARRAY_BUFFER, [mdVertexBuffer length], mdVertexBuffer.bytes, GL_STATIC_DRAW);
//    GLsizei commonStride = [self bufferStride];
//    glEnableVertexAttribArray(UISS_POSITION_ATTRIBUTE);
//    glVertexAttribPointer(UISS_POSITION_ATTRIBUTE, 2, GL_FLOAT, GL_FALSE, commonStride, 0);
//    
//    glEnableVertexAttribArray(UISS_TEXTURE_COORD_ATTRIBUTE);
//    glVertexAttribPointer(UISS_TEXTURE_COORD_ATTRIBUTE, 2, GL_FLOAT, GL_FALSE, commonStride, (GLvoid *) (sizeof(GLfloat) * 2));
//    
//    glEnableVertexAttribArray(UISS_OFFSET_AND_INDEX_ATTRIBUTE);         //  pack the extra content into one vec4 because int is not supported.
//    glVertexAttribPointer(UISS_OFFSET_AND_INDEX_ATTRIBUTE, 3, GL_FLOAT, GL_FALSE, commonStride, (GLvoid *) (sizeof(GLfloat) * 4));
//    
//    //  ...generate one for the index data too
//    glGenBuffers(1, &indexBuffer);
//    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
//    glBufferData(GL_ELEMENT_ARRAY_BUFFER, [mdVertexIndexBuffer length], mdVertexIndexBuffer.bytes, GL_STATIC_DRAW);
//    return YES;
//}


///*
// *  Free all image-specific GL resources.
// */
//-(void) teardownImageSpecificGL
//{
//    [EAGLContext setCurrentContext:context];
//    if (vertexBuffer) {
//        glDeleteBuffers(1, &vertexBuffer);
//        vertexBuffer = 0;
//    }
//    
//    if (indexBuffer) {
//        glDeleteBuffers(1, &indexBuffer);
//        indexBuffer = 0;
//    }
//    
//    if (vaoVertexArray) {
//        glDeleteVertexArraysOES(1, &vaoVertexArray);
//        vaoVertexArray = 0;
//    }
//    
//    [mdVertexBuffer release];
//    mdVertexBuffer = nil;
//    
//    [mdVertexIndexBuffer release];
//    mdVertexIndexBuffer = nil;
//    
//    [mdPolyCountsBuffer release];
//    mdPolyCountsBuffer = nil;
//    
//    numPolys = 0;
//    
//    if (blurTexName) {
//        glDeleteTextures(1, &blurTexName);
//        blurTexName = 0;
//    }
//    
//    if (texName) {
//        glDeleteTextures(1, &texName);
//        texName = 0;
//    }
//    
    [mdEntropy release];
    mdEntropy = nil;
//
//    szImage               = CGSizeZero;
//    frameCount            = 0;
    curRotation           = 0;
    entropyMalfunctioning = NO;
    entropyOffset         = 0;
//    numPolys              = 0;
//    endOfSecurePolys      = 0;
//    lastEnabledSecurePoly = 0;
//    totalElapsed          = 0.0;
//}
//
///*
// *  Free all the coreGL resources.
// */
//-(void) teardownCoreGL
//{
//    [EAGLContext setCurrentContext:context];
//    [self teardownImageSpecificGL];
//    [ssShader release];
//    ssShader = nil;
//}

@end

///******************************
// UISecureImageViewV3 (model)
// ******************************/
//@implementation UISecureImageViewV3 (model)
///*
// *  Add a single vertex to the buffer at the given location.
// */
//-(void) addVertex:(CGPoint) ptVertex atTextureLocation:(CGPoint) texPos withGridOffset:(CGPoint) gridOffset asIndex:(GLshort) index atLocation:(unsigned char *) ptr
// usingVertexIndex:(GLushort *) vIndex
//{
//    // - we're using unsigned short values for the indices, so don't create more than 64K of them!
//    NSAssert(*vIndex != (GLushort) -1, @"Vertex overflow.");
//    
//    // - when image flipping is temporarily disabled, assign everything to the background
//    //   index which includes no entropy.
//#if UISIV3_DEBUG_STOP_IMAGE_FLIPPING
//    index = UISIV3_POLY_BACKGROUND;
//#endif
//    
//    GLfloat x, y;
//    x = (GLfloat) ptVertex.x;
//    y = (GLfloat) ptVertex.y;
//    memcpy(ptr, &x, sizeof(x));
//    ptr += sizeof(GLfloat);
//    memcpy(ptr, &y, sizeof(y));
//    ptr += sizeof(GLfloat);
//    
//    x = (GLfloat) texPos.x;
//    y = (GLfloat) texPos.y;
//    memcpy(ptr, &x, sizeof(x));
//    ptr += sizeof(GLfloat);
//    memcpy(ptr, &y, sizeof(y));
//    ptr += sizeof(GLfloat);
//    
//    x = (GLfloat) gridOffset.x;
//    y = (GLfloat) gridOffset.y;
//    memcpy(ptr, &x, sizeof(x));
//    ptr += sizeof(GLfloat);
//    memcpy(ptr, &y, sizeof(y));
//    ptr += sizeof(GLfloat);
//    
//    GLfloat fIndex = (GLfloat) index;
//    memcpy(ptr, &fIndex, sizeof(fIndex));
//    (*vIndex)++;
//}

///*
// *  Add the vertex data necessary to create a rectangle of the given size.
// */
//-(NSArray *) addPolyRect:(CGRect) rc withTexture:(CGRect) rcTexture andGridOffset:(CGPoint) gridOffset asSecurePoly:(GLshort) polyIndex
//                inBuffer:(NSMutableData *) mdBuffer withVertexIndex:(GLushort *) vIndex
//{
//    // - size the buffer in prepraration for the data.
//    GLsizei commonStride  = [self bufferStride];
//    NSUInteger oldLen     = [mdBuffer length];
//    [mdBuffer setLength:oldLen + (UISIV3_VTX_PER_RECT * commonStride)];
//    unsigned char *ptr    = ((unsigned char *) mdBuffer.mutableBytes) + oldLen;
//    
//    GLushort beginVTX = *vIndex;
//    
//    // - we only need four vertices because they'll be reused.
//    [self addVertex:CGPointMake(CGRectGetMinX(rc), CGRectGetMinY(rc)) atTextureLocation:CGPointMake(CGRectGetMinX(rcTexture), CGRectGetMinY(rcTexture))
//     withGridOffset:gridOffset asIndex:polyIndex atLocation:ptr usingVertexIndex:vIndex];
//    ptr += commonStride;
//    [self addVertex:CGPointMake(CGRectGetMaxX(rc), CGRectGetMinY(rc)) atTextureLocation:CGPointMake(CGRectGetMaxX(rcTexture), CGRectGetMinY(rcTexture))
//     withGridOffset:gridOffset asIndex:polyIndex atLocation:ptr usingVertexIndex:vIndex];
//    ptr += commonStride;
//    [self addVertex:CGPointMake(CGRectGetMaxX(rc), CGRectGetMaxY(rc)) atTextureLocation:CGPointMake(CGRectGetMaxX(rcTexture), CGRectGetMaxY(rcTexture))
//     withGridOffset:gridOffset asIndex:polyIndex atLocation:ptr usingVertexIndex:vIndex];
//    ptr += commonStride;
//    [self addVertex:CGPointMake(CGRectGetMinX(rc), CGRectGetMaxY(rc)) atTextureLocation:CGPointMake(CGRectGetMinX(rcTexture), CGRectGetMaxY(rcTexture))
//     withGridOffset:gridOffset asIndex:polyIndex atLocation:ptr usingVertexIndex:vIndex];
//    ptr += commonStride;
//    
//    // - build the return vertex list.
//    NSMutableArray *maRet = [NSMutableArray array];
//    [maRet addObject:[NSNumber numberWithUnsignedInt:beginVTX]];
//    [maRet addObject:[NSNumber numberWithUnsignedInt:beginVTX+2]];
//    [maRet addObject:[NSNumber numberWithUnsignedInt:beginVTX+3]];
//    
//    [maRet addObject:[NSNumber numberWithUnsignedInt:beginVTX+0]];
//    [maRet addObject:[NSNumber numberWithUnsignedInt:beginVTX+1]];
//    [maRet addObject:[NSNumber numberWithUnsignedInt:beginVTX+2]];
//    return maRet;
//}

///*
// *  Returns an array of NSValue objects representing each point around
// *  a center
// */
//-(NSData *) pointsForCircleAtCenter:(CGPoint) ptCenter ofRadius:(CGFloat)radius andCount:(NSUInteger)numPoints
//{
//    NSMutableData *mdRet = [NSMutableData dataWithLength:sizeof(CGPoint) * numPoints];
//    CGPoint *ptCur       = (CGPoint *) [mdRet mutableBytes];
//    const CGFloat fullCircle = M_PI * 2.0f;
//    CGFloat radPerSegment    = fullCircle/((CGFloat)numPoints);
//    CGFloat rad              = 0.0f;
//    for (NSUInteger i = 0; i < numPoints; i++) {
//        *ptCur = CGPointMake(ptCenter.x + (radius * cos(rad)), ptCenter.y + (radius * sin(rad)));
//        ptCur++;
//        rad   += radPerSegment;
//    }
//    return mdRet;
//}

///*
// *  Segment lengths must be correct or the rings won't render correctly.
// */
//-(NSUInteger) numPointsForSegments:(NSUInteger) numSegments
//{
//    return (numSegments * UISIV3_NUM_GACS_SEG);
//}

/*
 *  Generate an array of GLshort indices into the random rotations that is derived from the
 *  entropy values.
 */
-(NSData *) entropyDefinedIndexArray
{
    const NSUInteger reqDataLen = UISIV3_SEC_ARRAY_LEN * sizeof(GLshort);
    NSAssert(reqDataLen < UISIV3_ENTROPY_LEN, @"The entropy data length is insufficient.");
    
    // - in order to not max out the list of uniforms, we're going to reuse indices in that list, but the indices will be
    //   randomly retrieved using the entropy data
    
    //  - first generate a list of values we can pull from
    //  - NOTE:  We must number from index 1 to not include the background value.
    NSMutableArray *maRemaining = [NSMutableArray array];
    for (NSUInteger i = 1; i < UISIV3_SEC_ARRAY_LEN; i++) {
        [maRemaining addObject:[NSNumber numberWithUnsignedInteger:i]];
    }
    
    // - now we're going to populate all the indices one at a time.
    NSMutableData *mdIndices        = [NSMutableData dataWithLength:reqDataLen];
    GLshort *secIndex               = (GLshort *) [mdIndices mutableBytes];
    const GLshort *sEntropyPointer  = (const GLshort *) [mdEntropy bytes];
    while ([maRemaining count]) {
        NSUInteger toRemove = ((*sEntropyPointer) % [maRemaining count]);
        sEntropyPointer++;
        NSNumber *n         = [maRemaining objectAtIndex:toRemove];
        *secIndex           = n.unsignedIntegerValue;
        secIndex++;
        [maRemaining removeObjectAtIndex:toRemove];
    }
    
    // - return the random list of indices
    return mdIndices;
}

///*
// *  Convert the given vertex into something that is appropriate for the given image dimensions and assumes the
// *  shader behavior of doing post-rotation and translation on it.
// */
//-(void) addImageSpecificVertex:(CGPoint) ptVertex withPolyCenter:(CGPoint) ptPolyCenter asIndex:(GLshort) index atLocation:(unsigned char *) ptr usingVertexIndex:(GLushort *) vIndex
//{
//    CGPoint ptTexture = CGPointMake(ptVertex.x/szImage.width, ptVertex.y/szImage.height);
//    CGPoint ptOffset  = CGPointMake(ptPolyCenter.x - (szImage.width/2.0f), ptPolyCenter.y - (szImage.height/2.0f));
//    CGPoint normVertex= CGPointMake(ptVertex.x - ptPolyCenter.x, ptVertex.y - ptPolyCenter.y);
//    [self addVertex:normVertex atTextureLocation:ptTexture withGridOffset:ptOffset asIndex:index atLocation:ptr usingVertexIndex:vIndex];
//}

///*
// *  Create a poly ring segment using the given points.
// *  - assumes the image size is set so the texture can be inferred and the bounds constrained.
// *  - returns nil if the ring segment would be clipped to the display.
// */
//-(NSArray *) addPolyRingSegmentWithInnerPoints:(NSData *) dInnerPoints andOuterPoints:(NSData *) dOuterPoints startingAtIndex:(NSUInteger) firstOffset
//                                     withCount:(NSUInteger) numPoints asSecurePoly:(GLshort) polyIndex inBuffer:(NSMutableData *) mdBuffer withVertIndex:(GLushort *) vIndex
//{
//    // - first verify that the segment is at least partially inside the view.
//    const CGPoint *ptInnerPoints = (const CGPoint *) [dInnerPoints bytes];
//    const CGPoint *ptOuterPoints = (const CGPoint *) [dOuterPoints bytes];
//    BOOL oneIn = NO;
//    for (NSUInteger i = 0; i < UISIV3_NUM_GACS_SEG+1; i++) {
//        NSUInteger idx = ((firstOffset + i) % numPoints);
//        if (ptInnerPoints[idx].x >= 0.0f && ptInnerPoints[idx].x < szImage.width &&
//            ptInnerPoints[idx].y >= 0.0f && ptInnerPoints[idx].y < szImage.height) {
//            oneIn = YES;
//            break;
//        }
//    }
//    if (!oneIn) {
//        return nil;
//    }
//    
//    // - compute the center of this polygon for rotation.
//    CGPoint ptInnerMid = ptInnerPoints[firstOffset+1];
//    CGPoint ptOuterMid = ptOuterPoints[firstOffset+2];
//    CGPoint ptCenter   = CGPointMake(ptInnerMid.x + ((ptOuterMid.x - ptInnerMid.x)/2.0f), ptInnerMid.y + ((ptOuterMid.y - ptInnerMid.y)/2.0f));
//    
//    // - now create the vertices.
//    GLsizei commonStride   = [self bufferStride];
//    NSUInteger oldLen      = [mdBuffer length];
//    NSUInteger numVertices = [self numPointsForSegments:1] + 1;
//    [mdBuffer setLength:oldLen + ((numVertices * 2) * commonStride)];
//    unsigned char *ptr    = ((unsigned char *) mdBuffer.mutableBytes) + oldLen;
//    GLushort beginVTX = *vIndex;
//    
//    for (NSUInteger i = 0; i < numVertices; i++) {
//        NSUInteger idx = ((firstOffset + i) % numPoints);
//        [self addImageSpecificVertex:ptOuterPoints[idx] withPolyCenter:ptCenter asIndex:polyIndex atLocation:ptr usingVertexIndex:vIndex];
//        ptr += commonStride;
//        [self addImageSpecificVertex:ptInnerPoints[idx] withPolyCenter:ptCenter asIndex:polyIndex atLocation:ptr usingVertexIndex:vIndex];
//        ptr += commonStride;
//    }
//    
//    // - and finally their indices
//    NSMutableArray *maRet = [NSMutableArray array];
//    for (NSUInteger i = 0; i < UISIV3_NUM_GACS_SEG;i++) {
//        // - for each point at the top, we add two tris, one with the base up
//        //   and the second with the base down
//        // - draw this on paper and label the points and it is easier to visualize
//        NSUInteger baseIndex = beginVTX + (i * 2);
//        [maRet addObject:[NSNumber numberWithUnsignedInteger:baseIndex]];
//        [maRet addObject:[NSNumber numberWithUnsignedInteger:baseIndex+2]];
//        [maRet addObject:[NSNumber numberWithUnsignedInteger:baseIndex+1]];
//        
//        [maRet addObject:[NSNumber numberWithUnsignedInteger:baseIndex+2]];
//        [maRet addObject:[NSNumber numberWithUnsignedInteger:baseIndex+3]];
//        [maRet addObject:[NSNumber numberWithUnsignedInteger:baseIndex+1]];
//    }
//    return maRet;
//}

///*
// *  Create the center circle for the concentric rings.
// *  - assumes the image size is set so the texture can be inferred.
// *  - I didn't like the way this looked when I treated it all as one polygon for the purposes
// *    of security, so I've split this into separate segments that will each be randomized.
// */
//-(NSArray *) addPolyCircleAtCenter:(CGPoint) ptCenter withPoints:(NSData *) dPoints ofCount:(NSUInteger) numPoints inBuffer:(NSMutableData *) mdBuffer withVertexIndex:(GLushort *) vIndex
//{
//    GLsizei commonStride  = [self bufferStride];
//    NSUInteger oldLen     = [mdBuffer length];
//    [mdBuffer setLength:oldLen + ((numPoints * 3) * commonStride)];         // make sure you include the center!
//    unsigned char *ptr    = ((unsigned char *) mdBuffer.mutableBytes) + oldLen;
//    
//    // - generate the vertices and indices at the same time because each slice needs
//    //   to be considered to be part of the same secure polygon.
//    const CGPoint *ptCur  = (const CGPoint *) [dPoints bytes];
//    NSMutableArray *maRet = [NSMutableArray array];
//    for (NSUInteger i = 0; i < numPoints; i++) {
//        GLushort beginVTX = *vIndex;
//        
//        // ...group a few segments together.
//        GLshort polyIndex = (i/5) + 1;
//        
//        // ...the center
//        [self addImageSpecificVertex:ptCenter withPolyCenter:ptCenter asIndex:polyIndex atLocation:ptr usingVertexIndex:vIndex];
//        ptr += commonStride;
//        
//        // ...the next two points.
//        [self addImageSpecificVertex:ptCur[i] withPolyCenter:ptCenter asIndex:polyIndex atLocation:ptr usingVertexIndex:vIndex];
//        ptr += commonStride;
//        
//        [self addImageSpecificVertex:ptCur[(i+1)%numPoints] withPolyCenter:ptCenter asIndex:polyIndex atLocation:ptr usingVertexIndex:vIndex];
//        ptr += commonStride;
//        
//        // - a pie slice with the point at the center of the circle, which is also the first
//        //   vertex
//        [maRet addObject:[NSNumber numberWithUnsignedInt:beginVTX]];
//        [maRet addObject:[NSNumber numberWithUnsignedInt:beginVTX + 1]];
//        [maRet addObject:[NSNumber numberWithUnsignedInt:beginVTX + 2]];
//        
//    }
//    return maRet;
//}

///*
// *  Add the circular polygons for the secure image model.
// *  - returns an array of polygons.
// */
//-(NSArray *) addAllSecurePolysInBuffer:(NSMutableData *) dBuffer withVertexIndex:(GLushort *) vIndex
//{
//    NSMutableArray *maAllPolys = [NSMutableArray array];
//    
    // - generate the random list of indices for the polygons
    NSData *dRandomIndices  = [self entropyDefinedIndexArray];
    const GLshort *secIndex = (const GLshort *) [dRandomIndices bytes];
    NSUInteger polyIndex    = UISIV3_POLY_BACKGROUND + 1;
//
//    // - the center of the concentric rings, and randomize it a bit to add variety
//    CGSize szQuarterWidth = CGSizeMake(szImage.width/4.0f, szImage.height/4.0f);
//    CGPoint ptCenter      = CGPointMake(szQuarterWidth.width + (rand() % (int) (szQuarterWidth.width * 2.0f)),
//                                        szQuarterWidth.height + (rand() % (int) (szQuarterWidth.height * 2.0f)));
//    
//    // - the ring width is based on the short dimension to ensure that we
//    //   get a suitable secure resolution
//    CGFloat ringWidth = 0.0f;
//    if (szImage.width > szImage.height) {
//        ringWidth = szImage.height / UISIV3_RINGS_PER_IMAGE;
//    }
//    else {
//        ringWidth = szImage.width / UISIV3_RINGS_PER_IMAGE;
//    }
//    
//    // - get the points for the center circle, which will also be used for the first ring.
//    NSUInteger numPoints = [self numPointsForSegments:UISIV3_BASE_SEG_CIRCLE];
//    NSData *dPointsOuter = [self pointsForCircleAtCenter:ptCenter ofRadius:ringWidth/2.0f andCount:numPoints];
//    
//    // - the circle at the center, which begins the series of concentric rings.
//    NSArray *arrPoly = [self addPolyCircleAtCenter:ptCenter withPoints:dPointsOuter ofCount:numPoints inBuffer:mdVertexBuffer withVertexIndex:vIndex];
//    [maAllPolys addObject:arrPoly];
//    polyIndex++;
//    
//    // - now each ring.
//    CGFloat curRadius    = ringWidth/2.0f;
//    CGFloat cutOffRadius = sqrtf((szImage.width * szImage.width) + (szImage.height * szImage.height));          //  use the corner as a reference.
//    for (;;) {
//        // - wait until we extend past the edge of the rectangle
//        if (curRadius > cutOffRadius) {
//            break;
//        }
//        
//        NSUInteger extraSegs = ((NSUInteger) curRadius + ringWidth) / UISIV3_ADD_SEG_FOR_PX;
//        numPoints            = [self numPointsForSegments:UISIV3_BASE_SEG_CIRCLE + extraSegs];
//        
//        // - now we're going to iterate on a single ring, a group at a time.
//        // - we need to generate points again for each because the outer ring dictates the quanity.
//        NSData *dPointsInner    = [self pointsForCircleAtCenter:ptCenter ofRadius:curRadius andCount:numPoints];
//        dPointsOuter            = [self pointsForCircleAtCenter:ptCenter ofRadius:curRadius + ringWidth andCount:numPoints];
//        NSUInteger ptIndex = 0;
//        for (ptIndex = 0; ptIndex < numPoints; ptIndex += UISIV3_NUM_GACS_SEG) {
//            NSArray *arrSegment = [self addPolyRingSegmentWithInnerPoints:dPointsInner
//                                                           andOuterPoints:dPointsOuter
//                                                          startingAtIndex:ptIndex
//                                                                withCount:numPoints
//                                                             asSecurePoly:secIndex[polyIndex]
//                                                                 inBuffer:mdVertexBuffer
//                                                            withVertIndex:vIndex];
//            // - the segment may not be added if it is clipped to the side of the view
//            if (arrSegment) {
//                [maAllPolys addObject:arrSegment];
//                polyIndex = (polyIndex + 1) % UISIV3_SEC_ARRAY_LEN;
//            }
//        }
//        curRadius += ringWidth;
//    }
//    
//    return maAllPolys;
//}

///*
// *  Create four polygons that will be used to clip the edges to save on the need to generate properly clipped
// *  polygons.
// */
//-(NSArray *) addAllClippingPolys:(NSMutableData *) mdBuffer withVertexIndex:(GLushort *) vIndex
//{
//    NSMutableArray *maRet = [NSMutableArray array];
//    CGFloat halfSide = 4096;
//    CGRect rcBigRect = CGRectMake(-halfSide, -halfSide, halfSide*2.0f, halfSide*2.0f);
//    NSArray *arrPoly = [self addPolyRect:rcBigRect
//                             withTexture:CGRectZero
//                           andGridOffset:CGPointMake(0.0f, -(halfSide+(szImage.height/2.0f)))
//                            asSecurePoly:UISIV3_POLY_BACKGROUND
//                                inBuffer:mdBuffer
//                         withVertexIndex:vIndex];
//    [maRet addObject:arrPoly];
//    
//    arrPoly = [self addPolyRect:rcBigRect
//                    withTexture:CGRectZero
//                  andGridOffset:CGPointMake(0.0f, halfSide + (szImage.height/2.0f))
//                   asSecurePoly:UISIV3_POLY_BACKGROUND
//                       inBuffer:mdBuffer
//                withVertexIndex:vIndex];
//    [maRet addObject:arrPoly];
//    
//    arrPoly = [self addPolyRect:rcBigRect
//                    withTexture:CGRectZero
//                  andGridOffset:CGPointMake(-(halfSide+(szImage.width/2.0f)), 0.0f)
//                   asSecurePoly:UISIV3_POLY_BACKGROUND
//                       inBuffer:mdBuffer
//                withVertexIndex:vIndex];
//    [maRet addObject:arrPoly];
//    
//    arrPoly = [self addPolyRect:rcBigRect
//                    withTexture:CGRectZero
//                  andGridOffset:CGPointMake(halfSide+(szImage.width/2.0f), 0.0f)
//                   asSecurePoly:UISIV3_POLY_BACKGROUND
//                       inBuffer:mdBuffer
//                withVertexIndex:vIndex];
//    [maRet addObject:arrPoly];
//    
//    return maRet;
//}

///*
// *  This method will generate all the polys necessary to represent the image securely.
// */
//-(void) generateSecureModel
//{
//    NSMutableArray *maAllPolys = [NSMutableArray array];
//    GLushort vertex            = 0;
//    
//    // - create the background polygon
//    NSArray *arrPoly = [self addPolyRect:CGRectMake(-szImage.width/2.0f, -szImage.height/2.0f, szImage.width, szImage.height)
//                             withTexture:CGRectMake(0.0f, 0.0f, 1.0f, 1.0f)
//                           andGridOffset:CGPointMake(0.0f, 0.0f)
//                            asSecurePoly:UISIV3_POLY_BACKGROUND
//                                inBuffer:mdVertexBuffer
//                         withVertexIndex:&vertex];
//    [maAllPolys addObject:arrPoly];

//    // - create the polygons for the secure image.
//    NSArray *circlePolys = [self addAllSecurePolysInBuffer:mdVertexBuffer withVertexIndex:&vertex];
//    [maAllPolys addObjectsFromArray:circlePolys];
//    endOfSecurePolys = [maAllPolys count];
//
//    // - finally, add four polygons that will clip the output because when there is overlap this
//    //   is easier than converting triangles at edges.
//    NSArray *clipPolys = [self addAllClippingPolys:mdVertexBuffer withVertexIndex:&vertex];
//    [maAllPolys addObjectsFromArray:clipPolys];
//    
//    // - now convert all the poly indexes into the requisite buffers to display them later.
//    // ...first count up how many indices we have to store.
//    NSUInteger numPolyIndices = 0;
//    for (NSArray *arrOnePolyIndices in maAllPolys) {
//        numPolyIndices += [arrOnePolyIndices count];
//    }
//    
//    NSLog(@"CS: The secure model has %u tris defined.", numPolyIndices/3);
//    
//    // ...size the buffer for storing the indices themselves, which will be GLushort values since
//    //    we'll likely have more than 255.
//    mdVertexIndexBuffer = [[NSMutableData alloc] initWithLength:numPolyIndices * sizeof(GLushort)];
//    GLushort *vIndexBuf = (GLushort *) [mdVertexIndexBuffer mutableBytes];
//    
//    // ...size the buffer for storing the counts, which will always be less than 255
//    mdPolyCountsBuffer = [[NSMutableData alloc] initWithLength:numPolyIndices];
//    GLubyte *pCountBuf = (GLubyte *) [mdPolyCountsBuffer mutableBytes];
//    
//    // ...iterate through the counts and indices.
//    for (NSArray *arrOnePolyIndices in maAllPolys) {
//        *pCountBuf = (GLubyte) [arrOnePolyIndices count];
//        for (NSNumber *nOneIndex in arrOnePolyIndices) {
//            *vIndexBuf = (GLushort) [nOneIndex unsignedIntegerValue];
//            vIndexBuf++;
//        }
//        pCountBuf++;
//    }
//    
//    // ...and save the number of polygons
//    numPolys = [maAllPolys count];
}

@end

///******************************
// UISecureImageViewV3 (draw)
// ******************************/
//@implementation UISecureImageViewV3 (draw)
///*
// *  Generate a modelview/projection matrix for the scene.
// */
//-(GLKMatrix4) baselineModelViewMatrix
//{
//    // - the baseline transform is a projection based on the precise pixel dimensions
//    //   of the image.
//    CGSize szBounds             = self.bounds.size;
//    GLfloat halfWidth           = szBounds.width/2.0f;
//    GLfloat halfHeight          = szBounds.height/2.0f;
//    GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(-halfWidth, halfWidth, halfHeight, -halfHeight, 1024.0f, -1024.0f);
//    
//    // - but we need to scale it to fit along the short side of the view.
//    GLfloat targetScale = szBounds.width / szImage.width;
//    if (targetScale * szImage.height > szBounds.height) {
//        targetScale = szBounds.height / szImage.height;
//    }
//    return GLKMatrix4Multiply(projectionMatrix, GLKMatrix4MakeScale(targetScale, targetScale, 1.0f));
//}
//
///*
// *  Draw a single frame.
// */
//-(void) glkView:(GLKView *)view drawInRect:(CGRect)rect
//{
//    if (!isRedrawEnabled) {
//        return;
//    }
//    
//    if ([EAGLContext currentContext] != context) {
//        [EAGLContext setCurrentContext:context];
//    }
//    
//    // - clear the background.
//    glClear(GL_COLOR_BUFFER_BIT);
//    
//    // - never try to display content if the secure shader could not be
//    //   compiled.
//    if (!ssShader || numPolys == 0) {
//        return;
//    }
//    
//    // - the same shader is used for all polys.
//    if (requiresNewViewMatrix) {
//        GLKMatrix4 matrix = [self baselineModelViewMatrix];
//        [ssShader useProgramInCurrentContextWithModelViewProjection:matrix];
//        requiresNewViewMatrix = NO;
//    }
//    
//    // - pointers to the relevant data items
//    GLubyte *pCountBuf  = (GLubyte *) [mdPolyCountsBuffer mutableBytes];
//    
//    [ssShader setClipPolyEnabled:NO];
//    
//    // - draw the background first from texture 0.
//    [ssShader setTextureUniform:0];
//    [ssShader setCurrentRotationUniform:0.0f];              //  don't rotate the background.
//    GLubyte numIndices = pCountBuf[0];
//    glDrawElements(GL_TRIANGLES, numIndices, GL_UNSIGNED_SHORT, 0);
//    
//    // - make sure that the secure constants are always in place first
//    if (!mdSecureRotations) {
//        mdSecureRotations = [[self generateSecureRotationConstantsWithEntropy:mdEntropy] retain];
//        [ssShader setSecureRandomUniform:mdSecureRotations];
//    }
//    
//    // - now draw the foreground
//    [ssShader setTextureUniform:1];
//    CGFloat assignRotation = curRotation;
//#if UISIV3_DEBUG_STOP_IMAGE_FLIPPING
//    assignRotation = 0.0f;
//#endif
//    [ssShader setCurrentRotationUniform:assignRotation];
//    NSUInteger indexOffset = 0;
//    for (NSUInteger i = 1; i < endOfSecurePolys; i++) {
//        indexOffset += numIndices;
//        numIndices = pCountBuf[i];
//        // - we may not draw every segment, but we still need to compute
//        //   the offsets for the clipping below.
//        if (i < lastEnabledSecurePoly) {
//            glDrawElements(GL_TRIANGLES, numIndices, GL_UNSIGNED_SHORT, (const void *) (indexOffset * sizeof(GLushort)));
//        }
//    }
//    
//    // - and the four clipping polygons last.
//    [ssShader setClipPolyEnabled:YES];
//    [ssShader setCurrentRotationUniform:0.0f];
//    for (NSUInteger i = endOfSecurePolys; i < numPolys; i++) {
//        indexOffset += numIndices;
//        numIndices = pCountBuf[i];
//        glDrawElements(GL_TRIANGLES, numIndices, GL_UNSIGNED_SHORT, (const void *) (indexOffset * sizeof(GLushort)));
//    }
//    
//    // - and increment the frame count
//    frameCount++;
//    
//    // - if this was the first frame, notifiy the delegate
//    if (!hasFirstFrame) {
//        hasFirstFrame = YES;
//        if (delegate && [delegate respondsToSelector:@selector(secureImageDisplayFirstFrameRendered:)]) {
//            [delegate performSelector:@selector(secureImageDisplayFirstFrameRendered:) withObject:self];
//        }
//    }
//}
@end

#endif