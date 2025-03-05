//
//  UISealedMessageEnvelopeViewV2.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/5/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "UISealedMessageEnvelopeViewV2.h"
#import "UISealedMessageBubbleViewV2.h"
#import "ChatSeal.h"
#import "UISealedMessageEnvelopeFoldView.h"
#import "UITransformView.h"
#import "UINewSealCell.h"
#import "ChatSealFeed.h"
#import "UISealedMessageDisplayCellV2.h"

// - constants
static const CGFloat UISME_STD_ENVELOPE_PAD_PCT      = 0.0543f;
static const CGFloat UISME_STD_ENV_HEIGHT_BASIS      = 10.19f;
static const CGFloat UISME_STD_ENV_WIDTH_BASIS       = 14.734f;
static const CGFloat UISME_STD_ENV_FLAPH_BASIS       = 3.157f;
static const CGFloat UISME_STD_ENV_SEAL_BASIS        = UISME_STD_ENV_FLAPH_BASIS;
static const CGFloat UISME_STD_ENV_CLIP_BASIS        = UISME_STD_ENV_FLAPH_BASIS * 0.75f;
static const CGFloat UISME_STD_ENV_FULL_HEIGHT_BASIS = (UISME_STD_ENV_FLAPH_BASIS + UISME_STD_ENV_HEIGHT_BASIS + UISME_STD_ENV_HEIGHT_BASIS);
static const CGFloat UISME_STD_ENV_FLAP_PCT          = UISME_STD_ENV_FLAPH_BASIS / UISME_STD_ENV_FULL_HEIGHT_BASIS;
static const CGFloat UISME_STD_ENV_SECTION_PCT       = UISME_STD_ENV_HEIGHT_BASIS / UISME_STD_ENV_FULL_HEIGHT_BASIS;
static const CGFloat UISME_STD_ENV_SEAL_PCT          = UISME_STD_ENV_SEAL_BASIS / UISME_STD_ENV_FULL_HEIGHT_BASIS;
static const CGFloat UISME_STD_ENV_CLIP_PCT          = UISME_STD_ENV_CLIP_BASIS / UISME_STD_ENV_FULL_HEIGHT_BASIS;
static const CGFloat UISME_STD_ENV_FLAP_FOLDED_PCT   = UISME_STD_ENV_FLAPH_BASIS / UISME_STD_ENV_HEIGHT_BASIS;
static const CGFloat UISME_STD_ENV_SEAL_FOLDED_PCT   = UISME_STD_ENV_SEAL_BASIS / UISME_STD_ENV_HEIGHT_BASIS;
static const CGFloat UISME_STD_SHADOW_RADIUS         = 2.0f;
static const CGFloat UISME_STD_TOP_MARGIN            = 0.05f;
static const CGFloat UISME_STD_SIDE_MARGIN           = 0.05f;
static const CGFloat UISME_STD_ITEM_VPAD             = 0.02f;
static const CGFloat UISME_MIN_SHORT_SCALE           = 0.50f;                       // items that are short and fit within the full range
static const CGFloat UISME_STD_SHADOW_OFFSET         = 0.75f;
static const CGFloat UISME_STD_SHADOW_INTENDED_H     = 404.0f;
static const CGFloat UISME_STD_CLIP_FADE_END         = 0.25f;
static const CGSize  UISME_STD_DECOY_DIMS            = {721.0f, 500.0f};            //  this size was chosen to fit within the larger Twitter dims and give a good envelope look.
static const CGSize  UISME_STD_TWITTER_DIMS          = {1024.0f, 576.0f};           //  Twitter apparently likes this dimension to avoid clipping. (supports about 660K of data)
static const CGFloat UISME_STD_DECOY_INSET           = 5.0f;
static const CGFloat UISME_STD_PROMO_PAD             = 0.025f;
static const int     UISME_STD_BUBBLE_BASE_TAG       = 9999;

// - forward declarations
@interface UISealedMessageEnvelopeViewV2 (internal)
-(void) applyStandardShadowAttributesToView:(UIView *) vw forIntendedEnvelopeHeight:(CGFloat) intendedHeight;
-(void) commonConfiguration;
-(CGFloat) shadowScaleForIntendedHeight:(CGFloat) intendedHeight;
-(BOOL) layoutSpeechPositionsAndReturnClippingForOriginal:(BOOL) isOriginalState;
-(CGRect) rectForViewCenteredAt:(CGPoint) pt withMaximumDimensions:(CGSize) maxDims;
-(void) sizeViewCenteredAt:(CGPoint) pt withMaximumDimensions:(CGSize) maxDims;
-(void) computeFlapHeight:(CGFloat *) flapH andMiddleHeight:(CGFloat *) midH andBottomHeight:(CGFloat *) botH fromTotalHeight:(CGFloat) totalHeight;
-(void) sizeFoldedViewCenteredAt:(CGPoint) pt withMaximumDimensions:(CGSize) maxDims;
-(void) layoutSealPosition;
-(UISealedMessageBubbleViewV2 *) bubbleViewForContent:(id) content fromCellInFrame:(CGRect) rcCellFrame;
@end

// - a simple view that clips content behind it in a gradient.
@interface UIPaperClipping : UIView
@end

/********************************
 UISealedMessageEnvelopeViewV2
 ********************************/
@implementation UISealedMessageEnvelopeViewV2
/*
 *  Object attributes.
 */
{
    UIEdgeInsets                    bubblePadding;
    CGFloat                         maxContentWidth;
    CGFloat                         maxContentHeight;
    NSMutableArray                  *maContentViews;
    UIView                          *vwBackdrop;
    UIView                          *vwContent;
    UIView                          *vwSnapshotContainer;
    CGRect                          rcOriginal;
    UITransformView                 *tvFoldHost;
    UISealedMessageEnvelopeFoldView *folds[3];
    UINewSealCell                   *sealView;
    UIPaperClipping                 *vwPaperClipping;
}

/*
 *  Generate a decoy image using the standard dimensions and the active seal.
 */
+(UIImage *) standardDecoyForActiveSeal
{
    return [UISealedMessageEnvelopeViewV2 standardDecoyForSeal:[ChatSeal activeSeal]];
}

/*
 *  Return a decoy for the given seal in the vault.
 */
+(UIImage *) standardDecoyForSeal:(NSString *) sealId
{
    // - create a decoy using the standard dimensions that provide sufficient storage for
    //   all scenarios.
    CGRect rcBounds = CGRectMake(0.0f, 0.0f, UISME_STD_DECOY_DIMS.width, UISME_STD_DECOY_DIMS.height);
    CGFloat flapH  = floorf((float)(CGRectGetHeight(rcBounds) * UISME_STD_ENV_FLAP_FOLDED_PCT));
    
    //   ... on Twitter, the decoy will be clipped unless we make it a square with the decoy itself in the middle.
    CGSize szImage  = UISME_STD_TWITTER_DIMS;
    UIGraphicsBeginImageContextWithOptions(szImage, NO, 1.0f);
    
    //   ... we need an off-white background because when we pack the data, it will be obvious because we use 2 bits from each
    //       of the color components and that lightens the output.
    [[UIColor colorWithWhite:1.0f alpha:1.0f] setFill];
    UIRectFill(CGRectMake(0.0f, 0.0f, szImage.width, szImage.height));
    
    //   ... center the envelope in the decoy image
    CGContextTranslateCTM(UIGraphicsGetCurrentContext(), (szImage.width-UISME_STD_DECOY_DIMS.width)/2.0f, (szImage.height-UISME_STD_DECOY_DIMS.height)/2.0f);
    
    //   ... the envelope background, which will be somewhat off white to allow it to look decent on an all-white screen.
    [[ChatSeal defaultPaperColor] setFill];
    
    //   ... set the background to pure white
    CGContextSaveGState(UIGraphicsGetCurrentContext());
    CGContextSetShadowWithColor(UIGraphicsGetCurrentContext(), CGSizeMake(0.5f, 0.5f), 2.5f, [[UIColor colorWithWhite:0.0f alpha:0.8f]CGColor]);
    UIRectFill(CGRectInset(rcBounds, UISME_STD_DECOY_INSET, UISME_STD_DECOY_INSET));
    CGContextRestoreGState(UIGraphicsGetCurrentContext());
    
    //   ... and draw the flap
    CGContextSaveGState(UIGraphicsGetCurrentContext());
    CGContextSetShadow(UIGraphicsGetCurrentContext(), CGSizeMake(0.0f, 1.0f), 2.0f);
    UIRectClip(CGRectMake(0.0f, flapH, CGRectGetWidth(rcBounds), CGRectGetHeight(rcBounds)));
    UIRectFillUsingBlendMode(CGRectInset(CGRectMake(0.0f, 0.0f, CGRectGetWidth(rcBounds), flapH), UISME_STD_DECOY_INSET, 0.0f), kCGBlendModeNormal);
    CGContextRestoreGState(UIGraphicsGetCurrentContext());
    
    //   ... and the seal over the flap
    CGFloat sealH      = floorf((float)(CGRectGetHeight(rcBounds) * UISME_STD_ENV_SEAL_FOLDED_PCT));
    CGRect  rcSeal     = CGRectIntegral(CGRectMake((CGRectGetWidth(rcBounds) / 2.0f) - (sealH/2.0f), flapH - (sealH/2.0f), sealH, sealH));
    UINewSealCell *nsc = [ChatSeal sealCellForId:sealId andHeight:sealH];
    [nsc setLocked:YES];
    [nsc drawCellForDecoyInRect:rcSeal];
    
    //   ... the promotional text in the lower right.
    NSMutableDictionary *dictAttribs = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                        [UIFont fontWithName:[ChatSeal defaultAppStylizedFontNameAsWeight:CS_SF_LIGHT] size:25.0f], NSFontAttributeName,
                                        [UIColor colorWithWhite:0.65f alpha:1.0f], NSForegroundColorAttributeName,
                                        nil];
    NSAttributedString *aString = [[[NSAttributedString alloc] initWithString:@"ChatSeal Personal" attributes:dictAttribs] autorelease];
    CGSize szPromo              = [aString size];
    CGSize promoPad             = CGSizeMake(UISME_STD_DECOY_DIMS.width * UISME_STD_PROMO_PAD, UISME_STD_DECOY_DIMS.height * UISME_STD_PROMO_PAD);
    [aString drawAtPoint:CGPointMake(CGRectGetWidth(rcBounds) - szPromo.width - UISME_STD_DECOY_INSET - promoPad.width, CGRectGetHeight(rcBounds) - szPromo.height - UISME_STD_DECOY_INSET - promoPad.height)];
    
    // - return the generated image.
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

/*
 *  Return the base offset for any new envelope.
 */
+(CGPoint) baseOffsetForWidth:(CGFloat) width
{
    UIEdgeInsets bubbleInsets = [UISealedMessageBubbleViewV2 standardPaddingInsets];
    CGFloat padWidth          = width * UISME_STD_ENVELOPE_PAD_PCT;
    return CGPointMake(-(padWidth + bubbleInsets.left), -padWidth);
}

/*
 *  Initialize the object.
 */
-(id) initWithWidth:(CGFloat) width andMaximumHeight:(CGFloat) maxHeight
{
    bubblePadding             = [UISealedMessageBubbleViewV2 standardPaddingInsets];
    maxContentWidth           = width;
    maxContentHeight          = maxHeight;
    CGPoint ptOffset          = [UISealedMessageEnvelopeViewV2 baseOffsetForWidth:width];
    CGFloat trueWidth         = width + (CGFloat) ((fabs(ptOffset.y) + bubblePadding.left) * 2.0f);
    self = [super initWithFrame:CGRectMake(ptOffset.x, ptOffset.y, trueWidth, 1.0f)];
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
    [maContentViews release];
    maContentViews = nil;
    
    [vwBackdrop release];
    vwBackdrop = nil;
    
    [vwContent release];
    vwContent = nil;
    
    for (int i = 0; i < 3; i++) {
        [folds[i] release];
        folds[i] = nil;
    }
    
    [vwSnapshotContainer release];
    vwSnapshotContainer = nil;
    
    [tvFoldHost release];
    tvFoldHost = nil;
    
    [sealView release];
    sealView = nil;
    
    [vwPaperClipping release];
    vwPaperClipping = nil;
    
    [super dealloc];
}

/*
 *  Add a new content item to the envelope using the provided frame as a reference to where
 *  its content belongs.
 */
-(void) addBubbleContent:(id) content fromCellInFrame:(CGRect) rcCellFrame
{
    UISealedMessageBubbleViewV2 *bv = [self bubbleViewForContent:content fromCellInFrame:rcCellFrame];
    if (!bv) {
        return;
    }
    
    // - add the new bubble to this view.
    int commonTag = UISME_STD_BUBBLE_BASE_TAG + (int) [maContentViews count];
    bv.tag        = commonTag;
    [vwContent addSubview:bv];
    
    //  - add the new one to the list we're tracking.
    [maContentViews addObject:bv];
    
    // - now, we need an exact duplicate that can be used for snapshotting while the
    //   transition animation is proceeding.
    // - the view being snapshotted cannot be modified at all during that process or
    //   it introduces extra delays into the navigation transition animation while it
    //   recomputes the changes.
    bv = [self bubbleViewForContent:content fromCellInFrame:rcCellFrame];
    if (bv) {
        bv.tag = commonTag;
        [vwSnapshotContainer addSubview:bv];
    }
}

/*
 *  Set a new frame for the view.
 */
-(void) setFrame:(CGRect)frame
{
    [super setFrame:frame];
    if (!self.superview) {
        // - save the original state until this becomes parented
        rcOriginal = frame;
    }
}

/*
 *  Before any movement APIs are issued, this should be called to acquire the split sub-views with the content.
 */
-(void) prepareForAnimationWithMaximumDimensions:(CGSize) maxDims usingSeal:(NSString *) sealId
{
    //  - don't ever re-run this.
    if (folds[0]) {
        return;
    }
    
    // - NOTE:
    //   - achieving the right look with shadows as these segments are folded requires some careful coordination.
    //   - the middle flap has to be at the back with the bottom over it and the top over both, but in order to
    //     achive good shadows, the middle has to be above everything to start.
    //   - as the top flap is animated, it will be adjusted over top the middle and bottom so that it covers both
    //     when the fold completes.
    //   - also, the hierachy in the fold itself is also very delicate and requires some care.  I noticed that the clipping in some
    //     cases requires more extreme z positioning to work.
    //   - this is unfortunately something that required a lot of tweaking to make it appear reasonable.  There is some science here but
    //     to avoid clipping at the wrong times, minor adjustments exist everywhere these folds are in play.
    
    // - NOTE-2:
    //   - on 3/14/14, I discovered that the navigation transition animation was drifting a bit during each sequence of
    //     folding the envelope.  Strangely enough it would eventually get to a point where it accumulated the drift values over
    //     time, getting longer and longer.  I discovered that the snapshotting process below was the cause because I was snapshotting
    //     the content as it was being animated.   This apparently is not a good idea.
    //   - to address this problem, I created a separate view for the speech bubbles that can be snapshot independently of the
    //     content.  The only time we ever change that 'snapshot view' is right now and forever after leave it alone. This is unfortunately
    //     necessary in order to get the folds to be right as we're in the process of animating this envelope.
    //   - at the moment I consider this to be a reasonable compromise in order to retain a layout/display approach to drawing the bubbles
    //     in the snapshot as opposed to maybe rendering them inline somehow.   There should be a limited number of them anyway since we only
    //     allow a maximum of 3.
    
    ChatSealColorCombo *cc = [ChatSeal sealColorsForSealId:sealId];
    
    // - the bubble should match the style that will be seen in the chat window later, which is always the seal color because
    //   when I send a message, I want it to always be on the right in the seal color..
    UIColor *cBubble       = cc.cMid;
    
    // - first grab a snapshot of the content.
    [UIView performWithoutAnimation:^(void){
        [self moveToAspectAccuratePaperCenteredAt:CGPointZero withMaximumDimensions:maxDims withPush:YES];
        
        // - we need to size the snapshot view and ensure that the visible and snapshot-ready bubble views
        //   match identically.
        vwSnapshotContainer.frame = CGRectOffset(vwContent.bounds, 5000.0f, 5000.0f);          //  make sure it is off screen.
        for (UISealedMessageBubbleViewV2 *bv in maContentViews) {
            UISealedMessageBubbleViewV2 *bvOther = (UISealedMessageBubbleViewV2 *) [vwSnapshotContainer viewWithTag:bv.tag];
            bvOther.transform = bv.transform;
            [bv setOwnerColor:cBubble andTheirColor:nil];
            [bvOther setOwnerColor:cBubble andTheirColor:nil];
        }
    }];
    UIView *vw = [vwSnapshotContainer snapshotViewAfterScreenUpdates:YES];
    
    // - now split this into the 3 folds.
    CGFloat height = CGRectGetHeight(vw.bounds);
    CGFloat flapH, midH, botH;
    [self computeFlapHeight:&flapH andMiddleHeight:&midH andBottomHeight:&botH fromTotalHeight:height];
    
    CGFloat width  = CGRectGetWidth(vw.bounds);
    CGRect rcFlap  = CGRectMake(0.0f, 0.0f, width, flapH);
    CGRect rcBot   = CGRectMake(0.0f, height - midH, width, midH);
    
    // ... the top flap
    UIView *vwSnap             = [vw resizableSnapshotViewFromRect:rcFlap afterScreenUpdates:NO withCapInsets:UIEdgeInsetsZero];
    folds[0]                   = [[UISealedMessageEnvelopeFoldView alloc] initWithContentView:vwSnap withTopShadow:YES andBottomShadow:YES];
    folds[0].layer.zPosition   = -201.0f;                              // the flap always starts behind so that the shadows look right before rotation
    folds[0].layer.anchorPoint = CGPointMake(0.5f, 1.0f);              // attach at the bottom and rotate there.
    CGPoint ptTmp              = folds[0].center;
    ptTmp.y                   += (CGRectGetHeight(folds[0].bounds)/2.0f);
    folds[0].center            = ptTmp;
    
    // ... the middle section, which doesn't turn
    vwSnap         = [vw resizableSnapshotViewFromRect:CGRectMake(0.0f, CGRectGetMaxY(rcFlap), width, height - flapH - botH)
                                    afterScreenUpdates:NO withCapInsets:UIEdgeInsetsZero];
    folds[1]       = [[UISealedMessageEnvelopeFoldView alloc] initWithContentView:vwSnap withTopShadow:YES andBottomShadow:YES];
    folds[1].frame = CGRectOffset(folds[1].frame, 0.0f, CGRectGetHeight(rcFlap));
    folds[1].layer.zPosition   = -100.0f;                             // the middle flap must always remain at the back.
    
    // ... the bottom flap
    vwSnap                     = [vw resizableSnapshotViewFromRect:rcBot afterScreenUpdates:NO withCapInsets:UIEdgeInsetsZero];
    folds[2]                   = [[UISealedMessageEnvelopeFoldView alloc] initWithContentView:vwSnap withTopShadow:NO andBottomShadow:YES];
    folds[2].frame             = CGRectOffset(folds[2].frame, 0.0f, CGRectGetHeight(rcFlap) + CGRectGetHeight(folds[1].frame));
    folds[2].layer.zPosition   = 50.0f;                               // the flap always remains in the middle so that the shadows look right before rotation.
    folds[2].layer.anchorPoint = CGPointMake(0.5f, 0.01f);            // attach at the top and rotate there (use a slight offset to avoid clipping artifacts at the edge during folding)
    ptTmp                      = folds[2].center;
    ptTmp.y                   -= (CGRectGetHeight(folds[2].bounds)/2.0f);
    folds[2].center            = ptTmp;
    
    //  - only the bottom flap can have perspective applied to it or it will be difficult to resolve
    //    the clipping between it and the middle view.
    //  - if the z positions are close to avoid a gap at the top, then the bottom flap will clip odd during the close.
    //  - if the z positions are far apar to avoid the odd clip behavior, then there will be a gap at the top.
    //  -  ... I haven't figured out a standard way to address this, but by applying perspective to the bottom, it is most obvious
    //     anyway and the effect is achieved.
    CATransform3D perspective        = CATransform3DIdentity;
    perspective.m34                  = -1.0f/8000.0f;
    folds[2].layer.sublayerTransform = perspective;
    
    // - add the views to the fold host to ensure that they are always positioned
    //   in the right locations relative to one another.
    for (int i = 0; i < 3; i++) {
        [tvFoldHost addSubview:folds[i]];
        folds[i].alpha = 0.0f;
        [self applyStandardShadowAttributesToView:folds[i].backdropShadowView forIntendedEnvelopeHeight:height];
    }
    
    // - make sure the identity is fully cached before trying to create the seal
    if (![ChatSeal identityForSeal:sealId withError:nil]) {
        [[ChatSeal vaultOperationQueue] waitUntilAllOperationsAreFinished];
    }
    
    // - create the seal view.
    // - note, in order to ensure that the seal always looks great, we're going to actually allocate a larger seal than
    sealView                  = [[ChatSeal sealCellForId:sealId andHeight:ceilf((float)(maxDims.height * UISME_STD_ENV_SEAL_PCT))] retain];
    [sealView setLocked:NO];
    sealView.alpha            = 0.0f;
    sealView.layer.zPosition  = 200.0f;
    [sealView prepareForSmallDisplay];
    [tvFoldHost addSubview:sealView];
    [self layoutSealPosition];
    [sealView layoutIfNeeded];              //  this is necessary to ensure that we don't get an extra layout during animation.
}

/*
 *  Move to where the envelope was originally positioned.
 */
-(void) moveToOriginalState
{
    self.frame = rcOriginal;
    
    // - lay out all the items one by one for this state.
    [self layoutSpeechPositionsAndReturnClippingForOriginal:YES];
    vwBackdrop.alpha      = 0.0f;
    vwPaperClipping.alpha = 0.0f;
}

/*
 *  Move the view so that it represents an piece of paper centered at the given location.
 */
-(void) moveToAspectAccuratePaperCenteredAt:(CGPoint) pt withMaximumDimensions:(CGSize) maxDims withPush:(BOOL) isPush
{
    // - position the view.
    [self sizeViewCenteredAt:pt withMaximumDimensions:maxDims];
    
    // - as this envelope is being initially presented, we need
    //   to show the backdrop
    if (isPush) {
        vwBackdrop.alpha = 1.0f;
    }
    
    // - lay out all the items one by one for this state.
    if ([self layoutSpeechPositionsAndReturnClippingForOriginal:NO]) {
        // - if the bottom is clipped, we need to create a clipping region to imply that more exists without a
        //   harsh transition.
        if (!vwPaperClipping) {
            CGSize szBounds    = self.bounds.size;
            CGFloat clipHeight = ceilf((float)(szBounds.height * UISME_STD_ENV_CLIP_PCT));
            vwPaperClipping = [[UIPaperClipping alloc] initWithFrame:CGRectMake(0.0f, szBounds.height - clipHeight, szBounds.width, clipHeight)];
            [vwContent addSubview:vwPaperClipping];
            [vwContent bringSubviewToFront:vwPaperClipping];
            [vwPaperClipping release];
        }
        vwPaperClipping.alpha = 1.0f;
    }
    [self applyStandardShadowAttributesToView:vwBackdrop forIntendedEnvelopeHeight:CGRectGetHeight(self.bounds)];
    
    // - ensure the folds are restored
    folds[0].layer.transform = CATransform3DIdentity;
    folds[1].layer.transform = CATransform3DIdentity;
    folds[2].layer.transform = CATransform3DIdentity;
    
    // - make sure the different folds have shadows hidden
    for (int i = 0; i < 3; i++) {
        [folds[i] setFoldingShadowVisible:NO withTopEdgeShadow:NO];
    }
}

/*
 *  Show/hide the fake paper folds.
 */
-(void) setFakePaperFoldsVisible:(BOOL) isVisible
{
    // - since this will be used with keyframe animation, we can't use the hidden flag or
    //   it won't be animated correctly.
    for (int i = 0; i < 3; i++) {
        folds[i].alpha = (isVisible ? 1.0f : 0.0f);
    }
    vwContent.alpha  = (isVisible ? 0.0f : 1.0f);
    
    // - I'm swapping shadows here to give more precision with how they are presented.
    // - each fold has its own precisely-clipped shadow view that animates with it.
    vwBackdrop.alpha = (isVisible ? 0.0f : 1.0f);
    for (int i = 0; i < 3; i++) {
        [folds[i] setBackdropShadowVisible:isVisible];
    }
}

/*
 *  Move the view into a folded envelope.
 */
-(void) moveToFoldedEnvelopeCenteredAt:(CGPoint) pt withMaximumDimensions:(CGSize) maxDims
{
    // - ensure this view is sized accurately.
    [self sizeFoldedViewCenteredAt:pt withMaximumDimensions:maxDims];
    
    // - make sure the different folds have shadows applied
    for (int i = 0; i < 3; i++) {
        [folds[i] setFoldingShadowVisible:YES withTopEdgeShadow:(i == 0)];
    }
    
    // - hide the seal
    sealView.alpha = 0.0f;
}

/*
 *  Show/hide the seal that we'll lock with.
 */
-(void) moveToSealVisible:(BOOL) isVisible
{
    sealView.alpha = (isVisible ? 1.0f : 0.0f);
}

/*
 *  Move the view into an envelope where the seal has locked it.
 */
-(void) moveToSealLocked:(BOOL) isLocked centeredAt:(CGPoint) pt withMaximumDimensions:(CGSize) maxDims
{
    [self sizeFoldedViewCenteredAt:pt withMaximumDimensions:maxDims];
    [sealView setLocked:isLocked];
}

/*
 *  Determine if the point is inside the seal icon for tapping purposes.
 */
-(BOOL) isPointInSealIcon:(CGPoint) pt
{
    if (CGRectContainsPoint(sealView.frame, pt)) {
        return YES;
    }
    return NO;
}

/*
 *  When the seal icon is tapped we're going to obscure it a bit so the person knows it occurred.
 */
-(void) sealIconTapped
{
    UIView *vw            = [[[UIView alloc] initWithFrame:sealView.bounds] autorelease];
    vw.backgroundColor    = [UIColor colorWithWhite:0.0f alpha:0.3f];
    vw.layer.cornerRadius = CGRectGetHeight(vw.bounds)/2.0f;
    vw.alpha              = 1.0f;
    [sealView addSubview:vw];
    [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void){
        vw.alpha = 0.0f;
    }completion:^(BOOL finished){
        [vw removeFromSuperview];
    }];
}

/*
 *  Since all the other move-to transforms occur as an aggregate of actions, this will ensure that
 *  the required set necessary to produce a locked envelope are performed.
 */
-(void) moveToFinalStateWithAllRequiredTransformsCenteredAt:(CGPoint) pt withMaximumDimensions:(CGSize) maxDims
{
    [self moveToOriginalState];
    [self moveToAspectAccuratePaperCenteredAt:pt withMaximumDimensions:maxDims withPush:YES];
    [self setFakePaperFoldsVisible:YES];
    [self moveToFoldedEnvelopeCenteredAt:pt withMaximumDimensions:maxDims];
    [self moveToSealVisible:YES];
    [self moveToSealLocked:YES centeredAt:pt withMaximumDimensions:maxDims];
}

/*
 *  When the envelope is completely displayed, we can safely discard the 
 *  snapshot bubble views.
 */
-(void) completeEnvelopeTransitionDisplay
{
    [vwSnapshotContainer removeFromSuperview];
    [vwSnapshotContainer release];
    vwSnapshotContainer = nil;
}

/*
 *  Update the origin of the envelope in its unfolded form.
 */
-(void) modifyEnvelopeOrigin:(CGPoint) pt
{
    rcOriginal.origin = pt;
}

@end

/****************************************
 UISealedMessageEnvelopeViewV2 (internal)
 ****************************************/
@implementation UISealedMessageEnvelopeViewV2 (internal)

/*
 *  Change the shadow attributes on the view to follow a standard appearance.
 */
-(void) applyStandardShadowAttributesToView:(UIView *) vw forIntendedEnvelopeHeight:(CGFloat) intendedHeight
{
    vw.layer.shadowColor     = [[UIColor colorWithWhite:0.0f alpha:0.7f] CGColor];
    CGFloat shadowScale      = [self shadowScaleForIntendedHeight:intendedHeight];
    CGSize targetShadow      = CGSizeMake(UISME_STD_SHADOW_OFFSET * shadowScale, UISME_STD_SHADOW_OFFSET * shadowScale);
    vw.layer.shadowOffset    = targetShadow;
    vw.layer.shadowRadius    = UISME_STD_SHADOW_RADIUS;
    vw.layer.shadowOpacity   = 1.0f;
}

/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    rcOriginal                 = CGRectZero;
    maContentViews             = [[NSMutableArray alloc] init];
    self.clipsToBounds         = NO;
    self.backgroundColor       = [UIColor clearColor];
    folds[0]                   = folds[1] = folds[2] = nil;
    sealView                   = nil;
    vwPaperClipping            = nil;
    
    // - the backdrop is to just show the paper color, but is not
    //   visible by default and will be displayed after the full view is visible to
    //   get the right kind of fade-in effect for the sub-views.
    vwBackdrop                       = [[UIView alloc] initWithFrame:self.bounds];
    vwBackdrop.autoresizingMask      = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    vwBackdrop.backgroundColor       = [ChatSeal defaultPaperColor];
    vwBackdrop.alpha                 = 0.0;
    vwBackdrop.layer.zPosition       = -250.0f;
    [self applyStandardShadowAttributesToView:vwBackdrop forIntendedEnvelopeHeight:0.0f];
    [self addSubview:vwBackdrop];
    
    // - if we don't use a content view, then clipping would also clip our shadow
    vwContent                  = [[UIView alloc] initWithFrame:self.bounds];
    vwContent.clipsToBounds    = YES;
    vwContent.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:vwContent];
    
    // - when snapshotting the bubble content, we must never change the enclosing view or the
    //   renderer will have to update it during the animation, which ends up introducing odd drifts
    //   in the keyframe sequence.  This view will never be changed once it is first configured.
    vwSnapshotContainer               = [[UIView alloc] initWithFrame:self.bounds];
    vwSnapshotContainer.clipsToBounds = YES;
    [self addSubview:vwSnapshotContainer];
    
    // - in order to get good animation while folding the paper, all of those items need to be part
    //   of a transform layer-backed view.
    // - this view will also have perspective applied for effect.
    tvFoldHost                         = [[UITransformView alloc] initWithFrame:CGRectZero];
    [self addSubview:tvFoldHost];
}

/*
 *  The shadow dimensions are defined based on a specific height and it is best to scale them as
 *  the height changes.
 */
-(CGFloat) shadowScaleForIntendedHeight:(CGFloat) intendedHeight
{
    return intendedHeight/UISME_STD_SHADOW_INTENDED_H;
}

/*
 *  Carefully layout the speech bubbles for presentation and return the clipping state at the bottom.
 */
-(BOOL) layoutSpeechPositionsAndReturnClippingForOriginal:(BOOL) isOriginalState
{
    BOOL bottomIsClipped = NO;
    
    CGFloat maxWidth = 0.0f;
    for (UISealedMessageBubbleViewV2 *bv in maContentViews) {
        bv.transform = CGAffineTransformIdentity;
        CGFloat tmp = CGRectGetWidth(bv.bounds);
        if (tmp > maxWidth) {
            maxWidth = tmp;
        }
    }
    
    if (!isOriginalState) {
        // - the margins will be used to decide on the sizing
        CGSize szView        = self.bounds.size;
        CGFloat topMargin    = szView.height * UISME_STD_TOP_MARGIN;
        CGFloat sideMargin   = szView.width * UISME_STD_SIDE_MARGIN;
        CGFloat vpad         = szView.height * UISME_STD_ITEM_VPAD;
        CGFloat contentWidth = szView.width - (sideMargin * 2.0f);
        CGFloat scaleBy      = 0.0f;
        
        // - we can never clip on the sides so for very long items, we need to be sure that
        //   they will at least fit into the content region between the left and right borders.
        // - when items are very small, ie 'Hello', we are going to scale down by a bit, but not
        //   by a proportional amount because it serves no purpose to have to disappear on the page.
        if (maxWidth > contentWidth) {
            scaleBy = contentWidth/maxWidth;
        }
        else {
            scaleBy = UISME_MIN_SHORT_SCALE;
        }
        
        // - now lay out all the content, aligned with the left margin, starting after the top margin,
        //   and extending as low as necessary.
        CGFloat curYPos = topMargin;
        for (UISealedMessageBubbleViewV2 *bv in maContentViews) {
            CGPoint ptCurCenter  = bv.center;
            CGFloat targetHeight = CGRectGetHeight(bv.bounds) * scaleBy;
            CGFloat targetWidth  = CGRectGetWidth(bv.bounds) * scaleBy;
            CGPoint ptNewCenter  = CGPointMake(sideMargin + (targetWidth / 2.0f), curYPos + (targetHeight / 2.0f));
            
            bv.transform = CGAffineTransformConcat(CGAffineTransformMakeScale(scaleBy, scaleBy),
                                                   CGAffineTransformMakeTranslation(ptNewCenter.x - ptCurCenter.x, ptNewCenter.y - ptCurCenter.y));
            
            curYPos += targetHeight;
            curYPos += vpad;
        }
        
        // - when the item position exceeds the height, we'll add a simple clipping indicator later.
        if (curYPos > szView.height) {
            bottomIsClipped = YES;
        }
    }
    
    return bottomIsClipped;
}

/*
 *  Compute the frame rect of the full view centered at the given point with the provided maximum dimensions.
 */
-(CGRect) rectForViewCenteredAt:(CGPoint) pt withMaximumDimensions:(CGSize) maxDims
{
    //  - given the maximum bounds, compute the largest piece of paper that can fit into that space
    //    while maintaining the target aspect ratio for the piece of paper that folds into the envelope.
    //  - the total height is the height of the flap plus two sides that will be folded.
    CGFloat targetAR      = UISME_STD_ENV_WIDTH_BASIS / (UISME_STD_ENV_FLAPH_BASIS + UISME_STD_ENV_HEIGHT_BASIS + UISME_STD_ENV_HEIGHT_BASIS);
    CGSize szTargetBounds = CGSizeMake(maxDims.height * targetAR, maxDims.height);
    if (szTargetBounds.width > maxDims.width) {
        szTargetBounds    = CGSizeMake(maxDims.width, maxDims.width / targetAR);
    }
    
    // - this view needs to animate to its final position and size.
    CGRect rcTarget = CGRectMake(pt.x - (szTargetBounds.width/2.0f), pt.y - (szTargetBounds.height/2.0f), szTargetBounds.width, szTargetBounds.height);
    rcTarget        = CGRectIntegral(rcTarget);
    return rcTarget;
}

/*
 *  Position the view according to the requested layout.
 */
-(void) sizeViewCenteredAt:(CGPoint) pt withMaximumDimensions:(CGSize) maxDims
{
    CGRect rcTarget = [self rectForViewCenteredAt:pt withMaximumDimensions:maxDims];
    self.frame      = rcTarget;
}

/*
 *  Figure out how big to make each of the three folds in the envelope based on the total height.
 *  - the middle is the key fold because it dictates the size of the whole thing, so we'll use
 *    that as the dominant size when rounding.
 */
-(void) computeFlapHeight:(CGFloat *) flapH andMiddleHeight:(CGFloat *) midH andBottomHeight:(CGFloat *) botH fromTotalHeight:(CGFloat) totalHeight
{
    *flapH       = (CGFloat) ceil(totalHeight * UISME_STD_ENV_FLAP_PCT);
    CGFloat secH = (CGFloat) ceil(totalHeight * UISME_STD_ENV_SECTION_PCT);
    CGFloat remH = totalHeight - *flapH - secH;
    if (secH > remH) {
        *midH = secH;
        *botH = remH;
    }
    else {
        *midH = remH;
        *botH = secH;
    }
}

/*
 *  When the view is folded, it will be smaller.
 */
-(void) sizeFoldedViewCenteredAt:(CGPoint) pt withMaximumDimensions:(CGSize) maxDims
{
    // - first get the large size.
    CGRect rcTarget = [self rectForViewCenteredAt:pt withMaximumDimensions:maxDims];
    
    // - now figure out how big the envelope should be, which will be determined by the middle section, which is
    //   what will be left over after computing everything else.
    CGFloat height = CGRectGetHeight(rcTarget);
    CGFloat flapH, midH, botH;
    [self computeFlapHeight:&flapH andMiddleHeight:&midH andBottomHeight:&botH fromTotalHeight:height];
    CGFloat width   = CGRectGetWidth(rcTarget);
    CGRect rcParent = CGRectMake(0.0f, 0.0f, width, midH);
    self.frame      = CGRectOffset(rcParent, pt.x - (CGRectGetWidth(rcParent)/2.0f), pt.y - (CGRectGetHeight(rcParent)/2.0f));
    
    // - size and orient the folds
    // - we explicitly size the folds instead of using a scale transform to avoid
    //   scaling the shadow on the fold, which will cause a visual hiccup during rotations.
    for (int i = 0; i < 3; i++) {
        folds[i].layer.transform = CATransform3DIdentity;
    }
    folds[0].frame           = CGRectMake(0.0f, 0.0f, width, flapH);
    folds[1].frame           = CGRectMake(0.0f, flapH, width, midH);
    folds[2].frame           = CGRectMake(0.0f, flapH + midH, width, botH);
    
    // - because these are folded, we're going to apply transforms to achieve that so that
    //   reverse is as simple as removing the transform.
    folds[0].layer.transform = CATransform3DConcat(CATransform3DMakeRotation((CGFloat) M_PI, 1.0f, 0.0f, 0.0f), CATransform3DMakeTranslation(0.0f, -flapH, 300.0f));
    folds[1].layer.transform = CATransform3DMakeTranslation(0.0f, -flapH, 0.0f);
    folds[2].layer.transform = CATransform3DConcat(CATransform3DMakeRotation((CGFloat) -M_PI, 1.0f, 0.0f, 0.0f), CATransform3DMakeTranslation(0.0f, -flapH - (midH - botH), 0.0f));
    
    // - scale and transform the seal
    sealView.transform = CGAffineTransformIdentity;
    CGPoint ptBefore   = sealView.center;
    CGFloat scale      = CGRectGetHeight(folds[0].bounds)/CGRectGetHeight(sealView.bounds);
    sealView.transform = CGAffineTransformConcat(CGAffineTransformMakeScale(scale, scale), CGAffineTransformMakeTranslation((width/2.0f) - ptBefore.x, flapH - ptBefore.y));
}

/*
 *  Change the size/location of the seal.
 */
-(void) layoutSealPosition
{
    CGRect rcFlap   = folds[0].frame;
    sealView.center = CGPointMake(CGRectGetMinX(rcFlap) + CGRectGetWidth(rcFlap)/2.0f, CGRectGetMaxY(rcFlap));
}

/*
 *  Allocate a new bubble view for the given content and frame.
 */
-(UISealedMessageBubbleViewV2 *) bubbleViewForContent:(id) content fromCellInFrame:(CGRect) rcCellFrame
{
    
    // - create the new speech bubble and set its dimensions.
    UISealedMessageBubbleViewV2 *bv = [[[UISealedMessageBubbleViewV2 alloc] init] autorelease];
    [bv setUseConstrainedPreferredFonts:YES];           // because they have to match the edit view's maximum size.
    [bv setOwnerTextColor:[UIColor whiteColor] andTheirTextColor:nil];
    [bv setIsMine:YES];
    [bv setIsSpoken:NO];
    [bv setContent:content];
    
    CGFloat padWidth = maxContentWidth * UISME_STD_ENVELOPE_PAD_PCT;
    
    //  figure out the position of the cell and use that to place the text
    if ([content isKindOfClass:[UIImage class]]) {
        // - normally bubble views are much larger, but we'll keep them
        //   small during sealing to retain their basic properties.
        bv.frame         = CGRectMake(padWidth + bubblePadding.left + CGRectGetMinX(rcCellFrame),
                                      [UISealedMessageDisplayCellV2 verticalPaddingHeight] + CGRectGetMinY(rcCellFrame) + padWidth,
                                      CGRectGetWidth(rcCellFrame),
                                      CGRectGetHeight(rcCellFrame));
    }
    else {
        // - the maximum width of the bubble has to consider its text frame and the padding it will
        //   add or it won't line up.
        CGFloat bubbleTextWidth = CGRectGetWidth(rcCellFrame);
        bubbleTextWidth        += bubblePadding.left + bubblePadding.right;
        CGSize szBubble         = [bv sizeThatFits:CGSizeMake(bubbleTextWidth, 1.0f)];
        bv.frame                = CGRectMake(padWidth, CGRectGetMinY(rcCellFrame) + padWidth, szBubble.width, szBubble.height);
    }
    
    // - force a layout right now so that it doesn't animate during the transition.
    [bv layoutIfNeeded];
    
    // - size and possibly position the view as content is added, up to the maximum allowed by the view.
    CGFloat curHeight = CGRectGetHeight(self.bounds);
    CGPoint bCenter = self.center;
    if (curHeight < maxContentHeight) {
        CGFloat targetHeight = curHeight;
        if (CGRectGetMaxY(bv.frame) > curHeight) {
            //  - size downward, up to the maximum
            targetHeight = CGRectGetMaxY(bv.frame) + padWidth;
            if (targetHeight > maxContentHeight) {
                targetHeight = maxContentHeight;
            }
            
            // - move the center of this view in the direction of expansion
            CGFloat delta = targetHeight - curHeight;
            bCenter = CGPointMake(bCenter.x, bCenter.y + (delta / 2.0f));
        }
        
        // - adjust the size of the view to the new target
        self.bounds = CGRectMake(0.0f, 0.0f, CGRectGetWidth(self.bounds), targetHeight);
        
        // - set the new center last because the bounds change would overwrite it.
        self.center = bCenter;
    }
    
    return bv;
}
@end

/*************************
 UIPaperClipping
 *************************/
@implementation UIPaperClipping
/*
 *  Return the class for the background
 */
+(Class) layerClass
{
    return [CAGradientLayer class];
}

/*
 *  Initialize this class.
 */
-(id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        CAGradientLayer *gl = (CAGradientLayer *) self.layer;
        gl.colors     = [NSArray arrayWithObjects:(id) [[UIColor colorWithWhite:1.0f alpha:0.0f] CGColor],
                                                  (id) [[UIColor colorWithWhite:1.0f alpha:0.5f] CGColor],
                                                  (id) [[UIColor colorWithWhite:1.0f alpha:1.0f] CGColor], nil];
        gl.locations  = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0.0f], [NSNumber numberWithFloat:UISME_STD_CLIP_FADE_END], [NSNumber numberWithFloat:1.0f], nil];
        gl.startPoint = CGPointMake(0.5f, 0.0f);
        gl.endPoint   = CGPointMake(0.5, 1.0f);
    }
    return self;
}

@end
