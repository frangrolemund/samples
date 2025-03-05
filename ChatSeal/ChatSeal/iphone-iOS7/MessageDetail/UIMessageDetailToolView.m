
//
//  UIMessageDetailToolView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 9/23/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "UIMessageDetailToolView.h"
#import "ChatSeal.h"
#import "UISealedMessageEditorContentViewV3.h"
#import "UIMessageDetailFeedAddressView.h"

// - constants
static const CGFloat UIMDT_STD_PAD        = 5.0f;
static const CGFloat UIMDT_STD_CORNER_RAD = 5.0f;
static const CGFloat UIMDT_HALF_CORNER    = UIMDT_STD_CORNER_RAD / 2.0f;
static const CGSize  UIMDT_CAM_SIZE       = {CS_APP_STD_TOOL_SIDE, 22.0f};                 // - the height needs to maintain the same aspect ratio.
static const CGFloat UIMDT_STD_ADDR_FONT  = 14.0f;

// - forward declarations
@interface UIMessageDetailToolView (internal) <UISealedMessageEditorContentViewV3Delegate>
-(void) commonConfiguration;
-(void) updateBackgroundIfNeeded;
-(void) doCamera;
-(void) doSealIt;
-(void) doAddress;
-(void) sizeEditorToCurrentDimensions;
-(void) buildAddressElementsIfNeeded;
-(void) positionToLabel:(UILabel *) l;
-(void) positionAddressLabel:(UILabel *) l;
-(void) positionUploadButton:(UIButton *) b;
@end

/**********************
 UIMessageDetailToolView
 **********************/
@implementation UIMessageDetailToolView
/*
 *  Object attributes.
 */
{
    UIButton                           *bCamera;
    UIView                             *vwEditContainer;
    UISealedMessageEditorContentViewV3 *editor;
    UIButton                           *bSealIt;
    BOOL                               hasBackground;
    BOOL                               showCamera;
    CGFloat                            maxButtonsPlusPad;
    UIView                             *vwDivider;
    CGSize                             contentSize;
    BOOL                               canSealItBeEnabled;
    BOOL                               inAddressMode;
    UILabel                            *lToLabel;
    UILabel                            *lAddress;
    UIButton                           *btnUpload;
}
@synthesize delegate;

/*
 *  Use this duration if possible to apply changes to the view size so that internal and external animations
 *  remain generally in-synch.
 */
+(NSTimeInterval) recommendedSizeAnimationDuration
{
    return [UISealedMessageEditorContentViewV3 recommendedSizeAnimationDuration];
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
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
    [bCamera release];
    bCamera = nil;
    
    [vwEditContainer release];
    vwEditContainer = nil;
    
    editor.delegate = nil;
    [editor release];
    editor = nil;
    
    [bSealIt release];
    bSealIt = nil;
    
    [vwDivider release];
    vwDivider = nil;
    
    [lToLabel release];
    lToLabel = nil;
    
    [lAddress release];
    lAddress = nil;
    
    [btnUpload release];
    btnUpload = nil;
    
    [super dealloc];
}

/*
 *  Find a size for the view.
 */
-(CGSize) sizeThatFits:(CGSize)size
{
    CGFloat nonEditContentWidth = (UIMDT_STD_PAD * 2.0f);                             // pads on the ends
    nonEditContentWidth        += CGRectGetWidth(bCamera.bounds);
    nonEditContentWidth        += ((UIMDT_STD_PAD + UIMDT_STD_CORNER_RAD) * 2.0f);    // pads on the sides of the edit region.
    nonEditContentWidth        += CGRectGetWidth(bSealIt.bounds);
    
    // - get the size of the text region either as it will be
    //   or as it is right now.
    if (contentSize.width < 0.0f) {
        contentSize = [editor sizeThatFits:CGSizeMake(size.width - nonEditContentWidth, 1.0f)];
    }
    CGSize sz = contentSize;
    
    CGFloat extraForAddress = [self reservedHeightForAddress];
    
    // - the required height includes what is minimally necessary
    //   to fit all the content or the buttons.
    // - we're only using one corner radius to really pad the bottom so that the cursor isn't
    //   mashed against it.
    sz.height += (UIMDT_STD_PAD + UIMDT_STD_PAD + extraForAddress + UIMDT_STD_CORNER_RAD);
    if (sz.height < maxButtonsPlusPad) {
        sz.height = maxButtonsPlusPad;
    }
    if (inAddressMode) {
        sz.height += 6.0f;
    }
    
    // - we always return the requested width here so it isn't clipped on the sides of the screen.
    sz.width = size.width;
    return sz;
}

/*
 *  Perform sub-view layout.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    CGSize szView = self.bounds.size;
    
    //  when we're showing the address, the top margin requires it.
    lToLabel.alpha  = inAddressMode ? 1.0f : 0.0f;
    lAddress.alpha  = inAddressMode ? 1.0f : 0.0f;
    btnUpload.alpha = inAddressMode ? 1.0f : 0.0f;
    
    CGFloat leftX = UIMDT_STD_PAD;
    CGFloat tmpY = szView.height - UIMDT_STD_PAD - UIMDT_HALF_CORNER - UIMDT_CAM_SIZE.height;
    if (showCamera) {
        bCamera.frame = CGRectIntegral(CGRectMake(leftX, tmpY, UIMDT_CAM_SIZE.width, UIMDT_CAM_SIZE.height));
        leftX        += UIMDT_CAM_SIZE.width;
        leftX        += UIMDT_STD_PAD;
    }
    else {
        //  the camera is off-screen to the left.
        bCamera.frame = CGRectIntegral(CGRectMake(-CGRectGetWidth(bCamera.bounds) - UIMDT_STD_PAD, tmpY, UIMDT_CAM_SIZE.width, UIMDT_CAM_SIZE.height));
    }
    
    // - the seal-it button is off to the right and positioned based on where the camera is.
    CGFloat rightX = szView.width - CGRectGetWidth(bSealIt.bounds) - UIMDT_STD_PAD;
    tmpY          += UIMDT_CAM_SIZE.height/2.0f;          //  center the seal-it with the camera button.
    tmpY          -= CGRectGetHeight(bSealIt.bounds)/2.0f;
    bSealIt.frame  = CGRectIntegral(CGRectMake(rightX, tmpY, CGRectGetWidth(bSealIt.bounds), CGRectGetHeight(bSealIt.bounds)));
    rightX        -= UIMDT_STD_PAD;
    
    // - the edit container is stuck right in the middle.
    CGFloat reservedForAddress = [self reservedHeightForAddress];
    vwEditContainer.frame      = CGRectIntegral(CGRectMake(leftX, UIMDT_STD_PAD + reservedForAddress, rightX - leftX, szView.height - (UIMDT_STD_PAD * 2.0f) - reservedForAddress));
    [self sizeEditorToCurrentDimensions];
    
    // - the divider is only one pixel high.
    vwDivider.frame = CGRectMake(0.0f, 0.0f, szView.width, 1/[UIScreen mainScreen].scale);
    
    // - lay out the address fields because they are inferred from the others.
    [self positionToLabel:lToLabel];
    [self positionAddressLabel:lAddress];
    [self positionUploadButton:btnUpload];
}

/*
 *  Become the first responder.
 */
-(BOOL) becomeFirstResponder
{
    return [editor becomeFirstResponder];
}

/*
 *  Returns the first responder status.
 */
-(BOOL) isFirstResponder
{
    return [editor isFirstResponder];
}

/*
 *  Resign first responder status.
 */
-(BOOL) resignFirstResponder
{
    [super resignFirstResponder];
    return [editor resignFirstResponder];
}

/*
 *  Assign hint text to the editor.
 */
-(void) setHintText:(NSString *) hintText
{
    [editor setHintText:hintText];
}

/*
 *  Insert an image into the message at the current cursor position.
 */
-(void) insertPhotoInMessage:(UIImage *) image
{
    [editor addPhotoAtCursorPosition:image];
}

/*
 *  Return the current message contents.
 */
-(NSArray *) currentMessageContents
{
    return [editor contentItems];
}

/*
 *  When the dynamic type in the system is updated, make sure the editor
 *  responds to it.
 */
-(void) updateDynamicTypeNotificationReceived
{
    [editor updateDynamicTypeNotificationReceived];
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

/*
 *  Assign the contents to the editor.
 */
-(void) setMessageContents:(NSArray *) arrContents
{
    [editor setContentItems:arrContents];
}

/*
 *  This offset is the base that is applied by the tools, indpendent of what is provided by the caller.
 */
-(CGPoint) baseEnvelopeOffset
{
    CGPoint ptEnvOffset = [UISealedMessageEnvelopeViewV2 baseOffsetForWidth:CGRectGetWidth(editor.bounds)];
    return CGPointMake(ptEnvOffset.x + editor.frame.origin.x + vwEditContainer.frame.origin.x,
                       ptEnvOffset.y + editor.frame.origin.y + vwEditContainer.frame.origin.y);
}

/*
 *  Create and return an envelope representation based on the current content.
 */
-(UISealedMessageEnvelopeViewV2 *) envelopeForCurrentContentAndTargetHeight:(CGFloat) targetHeight
{
    UISealedMessageEnvelopeViewV2 *envelope = [editor envelopeForCurrentContentAndTargetHeight:targetHeight];
    
    //  - convert the envelope to a frame relative to this, but don't use convertRect:fromView!
    //  - the UIKit conversion will include the contentOffset, which we do not want.
    CGRect rcFrame   = envelope.frame;
    CGPoint ptOffset = [self baseEnvelopeOffset];
    rcFrame          = CGRectOffset(rcFrame, ptOffset.x, ptOffset.y);
    envelope.frame   = CGRectIntegral(rcFrame);
    return envelope;
}

/*
 *  Enable/disable the seal-it button.
 */
-(void) setSealItButtonEnabled:(BOOL) isEnabled
{
    canSealItBeEnabled = isEnabled;
    bSealIt.enabled    = (isEnabled && [editor hasContent]);
}

/*
 *  Returns whether content exists in the view.
 */
-(BOOL) hasContent
{
    return [editor hasContent];
}

/*
 *  When the frame is set, we're going to do an immediate layout so that animations
 *  surrounding this modification (which is common) are propagated into the layout
 *  and scrolling actions.
 */
-(void) setFrame:(CGRect)frame withImmediateLayout:(BOOL)immediateLayout
{
    [super setFrame:frame];
    if (immediateLayout) {
        [self setNeedsLayout];
        [self layoutIfNeeded];
        [editor layoutIfNeeded];
    }
}

/*
 *  In landscape mode, we're going to have the tool view take over for the address bar when it is high-enough on
 *  the screen.  This will allow this screen to show more content and minimize visual clutter.
 */
-(void) setDisplayAddressEnabled:(BOOL) enabled
{
    if (inAddressMode != enabled) {
        [self buildAddressElementsIfNeeded];
        inAddressMode = enabled;
        [self setNeedsLayout];
    }
}

/*
 *  Return the correct state of the tool view whether it is in address display mode.
 */
-(BOOL) addressDisplayEnabled
{
    return inAddressMode;
}

/*
 *  Assign the text to show when this is displaying the address.
 */
-(void) setAddressText:(NSString *) text withAnimation:(BOOL) animated
{
    [self buildAddressElementsIfNeeded];
    lAddress.text = text;
    [lAddress sizeToFit];
    [self setNeedsLayout];
    [self layoutIfNeeded];
    
    if (animated) {
        lAddress.alpha               = 0.0f;
        CGAffineTransform atComplete = [UIMessageDetailFeedAddressView shearTransformForLabel:lAddress];
        lAddress.transform           = atComplete;
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] * 1.25f animations:^(void) {
            lAddress.transform = CGAffineTransformIdentity;
            lAddress.alpha     = 1.0f;
        }];
    }
}


/*
 *  When the address should be displayed, we'll reserve a bit extra for it.
 */
-(CGFloat) reservedHeightForAddress
{
    if (inAddressMode) {
        return MAX(CGRectGetHeight(lToLabel.bounds), CGRectGetHeight(lAddress.bounds));
    }
    return 0.0f;
}

/*
 *  Right before the tools are rotated, we need to make sure the content size is recomputed because
 *  nothing will trigger a content size update until a modification occurs later.
 */
-(void) prepareForRotation
{
    contentSize = CGSizeMake(-1.0f, -1.0f);
}

/*
 *  Return the text for the active text field.
 */
-(NSString *) textForActiveItem
{
    return [editor textForActiveItem];
}
@end

/***********************************
 UIMessageDetailToolView (internal)
 ***********************************/
@implementation UIMessageDetailToolView (internal)
/*
 *  Configure the view.
 */
-(void) commonConfiguration
{
    canSealItBeEnabled = YES;
    hasBackground      = NO;
    showCamera         = YES;
    inAddressMode      = NO;
    contentSize        = CGSizeMake(-1.0f, -1.0f);
    [self updateBackgroundIfNeeded];

    // - create the sub-controls.
    bCamera          = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
    UIImage *imgNorm = [UIImage imageNamed:@"714-camera.png"];
    UIImage *imgSel  = [UIImage imageNamed:@"714-camera-selected.png"];
    bCamera.bounds   = CGRectMake(0.0f, 0.0f, UIMDT_CAM_SIZE.width, UIMDT_CAM_SIZE.height);
    [bCamera setImage:imgNorm forState:UIControlStateNormal];
    [bCamera setImage:imgSel forState:UIControlStateHighlighted];
    [bCamera setImage:imgSel forState:UIControlStateSelected];
    [bCamera addTarget:self action:@selector(doCamera) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:bCamera];
    maxButtonsPlusPad = CGRectGetHeight(bCamera.bounds);
    maxButtonsPlusPad += UIMDT_HALF_CORNER;                  // the camera is shifted up a bit.
    
    // - the text region is auto-resized because it has to stay away from the rounded corners.
    editor = [[UISealedMessageEditorContentViewV3 alloc] init];
    editor.delegate = self;
    
    UIColor *toolBorderColor = [UIColor colorWithRed:199.0f/255.0f green:199.0f/255.0f blue:204.0f/255.0f alpha:1.0f];
    vwEditContainer                    = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, (UIMDT_STD_CORNER_RAD * 2.0) + 1.0f, (UIMDT_STD_CORNER_RAD * 2.0f) + CGRectGetHeight(editor.bounds))];
    vwEditContainer.backgroundColor    = [ChatSeal defaultEditorBackgroundColor];
    vwEditContainer.layer.borderColor  = [toolBorderColor CGColor];
    vwEditContainer.layer.borderWidth  = 0.5f;
    vwEditContainer.layer.cornerRadius = UIMDT_STD_CORNER_RAD;
    vwEditContainer.clipsToBounds      = YES;
    [self addSubview:vwEditContainer];

    editor.frame            = CGRectMake(UIMDT_STD_CORNER_RAD, UIMDT_STD_CORNER_RAD, 1.0f, 1.0f);
    [vwEditContainer addSubview:editor];
    
    bSealIt = [[UIButton buttonWithType:UIButtonTypeSystem] retain];
    bSealIt.titleLabel.font = [UIFont boldSystemFontOfSize:17.0f];
    [bSealIt setTitle:NSLocalizedString(@"Seal It", nil) forState:UIControlStateNormal];
    [bSealIt setTitleColor:[UIColor darkGrayColor] forState:UIControlStateDisabled];
    CGSize szSealIt = bSealIt.titleLabel.intrinsicContentSize;
    bSealIt.bounds  = CGRectMake(0.0f, 0.0f, szSealIt.width, szSealIt.height);
    [bSealIt addTarget:self action:@selector(doSealIt) forControlEvents:UIControlEventTouchUpInside];
    bSealIt.enabled = NO;
    [self addSubview:bSealIt];
    if (CGRectGetHeight(bSealIt.titleLabel.bounds) > maxButtonsPlusPad) {           // position based on the actual height of the text, not the button.
        maxButtonsPlusPad = CGRectGetHeight(bSealIt.titleLabel.bounds);
    }
    maxButtonsPlusPad += (UIMDT_STD_PAD * 2.0f);
    
    vwDivider                 = [[UIView alloc] init];
    vwDivider.backgroundColor = toolBorderColor;
    [self addSubview:vwDivider];
}

/*
 *  Update the background coloring if required.
 */
-(void) updateBackgroundIfNeeded
{
    // - this is a placeholder for possible blurring work later.
    if (hasBackground) {
        return;
    }
    self.backgroundColor = [ChatSeal defaultToolBackgroundColor];
    hasBackground        = YES;
}

/*
 *  The camera was pressed.
 */
-(void) doCamera
{
    if (delegate && [delegate respondsToSelector:@selector(toolViewCameraPressed:)]) {
        [delegate performSelector:@selector(toolViewCameraPressed:) withObject:self];
    }
}

/*
 *  The seal-it button was pressed.
 */
-(void) doSealIt
{
    if (delegate && [delegate respondsToSelector:@selector(toolViewSealItPressed:)]) {
        [delegate performSelector:@selector(toolViewSealItPressed:) withObject:self];
    }
}

-(void) doAddress
{
    if (delegate && [delegate respondsToSelector:@selector(toolViewAddressPressed:)]) {
        [delegate performSelector:@selector(toolViewAddressPressed:) withObject:self];
    }
}

/*
 *  When the content region is resized, this is called.
 */
-(void) sealedMessageEditorContentResized:(UISealedMessageEditorContentViewV3 *) contentView
{
    contentSize = contentView.contentSize;
    if (delegate && [delegate respondsToSelector:@selector(toolViewContentSizeChanged:)]) {
        [delegate performSelector:@selector(toolViewContentSizeChanged:) withObject:self];
    }
}

/*
 *  Enable/disable the Seal-It button automatically.
 */
-(void) sealedMessageEditor:(UISealedMessageEditorContentViewV3 *)contentView contentIsAvailable:(BOOL)isAvail
{
    bSealIt.enabled = isAvail && canSealItBeEnabled;
}

/*
 *  The height of the editor will influence how its scroll offsets are recomputed during content changes,
 *  so we need to adjust it periodically based on events other than the explicit layoutSubViews.
 */
-(void) sizeEditorToCurrentDimensions
{
    // - the assumption is that the buttons are already placed, which allows us to compute the width of the
    //   editor.  The height will be based on what fits naturally.
    CGFloat leftX  = CGRectGetMaxX(bCamera.frame) + UIMDT_STD_PAD + UIMDT_STD_CORNER_RAD;
    CGFloat rightX = CGRectGetMinX(bSealIt.frame) - UIMDT_STD_PAD - UIMDT_STD_CORNER_RAD;
    
    CGFloat maxHeight = CGRectGetHeight(self.bounds) - UIMDT_STD_CORNER_RAD - (UIMDT_STD_PAD * 2.0f) - [self reservedHeightForAddress];
    editor.frame = CGRectIntegral(CGRectMake(UIMDT_STD_CORNER_RAD, 0.0f, rightX - leftX, maxHeight));
}

/*
 *  When the number of images in the editor changes, update the presence of the camera button.
 */
-(void) sealedMessageEditor:(UISealedMessageEditorContentViewV3 *)contentView imageCountModifiedTo:(NSUInteger)numImages
{
    BOOL animateUpdate = NO;
    if (numImages) {
        if (showCamera) {
            showCamera    = NO;
            animateUpdate = YES;
        }
    }
    else {
        if (!showCamera) {
            showCamera    = YES;
            animateUpdate = YES;
        }
    }
    
    // - when changes occur that require a shift in the button, do that now.
    if (animateUpdate) {
        bCamera.enabled = showCamera;
        [UIView animateWithDuration:[ChatSeal standardSqueezeTime] * 2.0f animations:^(void){
            [self layoutSubviews];
        }];
    }
}

/*
 *  Notify the delegate of the first responder change.
 */
-(void) sealedMessageEditorBecameFirstResponder:(UISealedMessageEditorContentViewV3 *)contentView
{
    if (delegate && [delegate respondsToSelector:@selector(toolViewBecameFirstResponder:)]) {
        [delegate performSelector:@selector(toolViewBecameFirstResponder:) withObject:self];
    }
}


/*
 *  Construct the address elements.
 */
-(void) buildAddressElementsIfNeeded
{
    [UIView performWithoutAnimation:^(void) {
        if (!lToLabel) {
            lToLabel               = [[UILabel alloc] init];
            lToLabel.font          = [UIFont systemFontOfSize:UIMDT_STD_ADDR_FONT];
            lToLabel.textColor     = [UIColor colorWithWhite:0.55f alpha:1.0f];
            lToLabel.text          = NSLocalizedString(@"To:", nil);
            lToLabel.alpha         = inAddressMode ? 1.0f : 0.0f;
            [lToLabel sizeToFit];
            [self positionToLabel:lToLabel];
            [self addSubview:lToLabel];
        }
        
        if (!lAddress) {
            lAddress               = [[UILabel alloc] init];
            lAddress.font          = [UIFont systemFontOfSize:UIMDT_STD_ADDR_FONT];
            lAddress.textColor     = [UIColor blackColor];
            lAddress.numberOfLines = 1;
            lAddress.lineBreakMode = NSLineBreakByTruncatingTail;
            lAddress.alpha         = inAddressMode ? 1.0f : 0.0f;
            [self positionAddressLabel:lAddress];
            [self addSubview:lAddress];
        }
        
        if (!btnUpload) {
            btnUpload              = [[UIMessageDetailFeedAddressView standardUploadButton] retain];
            btnUpload.alpha        = inAddressMode ? 1.0f : 0.0f;
            [btnUpload addTarget:self action:@selector(doAddress) forControlEvents:UIControlEventTouchUpInside];
            [btnUpload addTarget:self action:@selector(doAddress) forControlEvents:UIControlEventTouchUpOutside];
            [self positionUploadButton:btnUpload];
            [self addSubview:btnUpload];
        }
    }];
}

/*
 *  Assign a position to the given label for displaying the 'To:' description.
 */
-(void) positionToLabel:(UILabel *) l
{
    CGSize szSize = [l sizeThatFits:CGSizeMake(256.0f, 1.0f)];
    l.frame       = CGRectIntegral(CGRectMake(CGRectGetMinX(vwEditContainer.frame) - (showCamera ? CGRectGetWidth(lToLabel.frame) : 0.0f),
                                        UIMDT_STD_PAD/2.0f,
                                        szSize.width, szSize.height));
}

/*
 *  Assign a position to the given label for displaying an address.
 */
-(void) positionAddressLabel:(UILabel *) l
{
    CGFloat startX   = CGRectGetMaxX(lToLabel.frame) + 6.0f;
    CGFloat maxWidth = CGRectGetMaxX(vwEditContainer.frame) - startX;
    CGSize szSize    = [l sizeThatFits:CGSizeMake(maxWidth, 1.0f)];
    l.frame          = CGRectIntegral(CGRectMake(startX, lToLabel.center.y - (szSize.height/2.0f), MIN(szSize.width, maxWidth), szSize.height));
}

/*
 *  Assign a position to the upload button.
 */
-(void) positionUploadButton:(UIButton *) b
{
    CGFloat buttonY   = CGRectGetMinY(lToLabel.frame) + UIMDT_STD_PAD/2.0f;
    CGFloat btnHeight = CGRectGetHeight(b.frame);
    if (buttonY + btnHeight > CGRectGetMinY(bSealIt.frame)) {
        buttonY = MAX(CGRectGetMinY(bSealIt.frame) - UIMDT_STD_PAD - btnHeight, 0.0f);
    }
    
    b.frame = CGRectIntegral(CGRectMake(CGRectGetWidth(self.bounds) - [UIMessageDetailFeedAddressView standardSidePad]  - CGRectGetWidth(b.frame),
                                        buttonY,
                                        CGRectGetWidth(b.bounds), CGRectGetHeight(b.bounds)));
}

@end