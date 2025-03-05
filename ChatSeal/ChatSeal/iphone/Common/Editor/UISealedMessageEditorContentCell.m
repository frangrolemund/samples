//
//  UISealedMessageEditorContentCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/12/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "UISealedMessageEditorContentCell.h"
#import "UISealedMessageDisplayCellV2.h"
#import "UISealedMessageBubbleViewV2.h"
#import "ChatSeal.h"
#import "UIAdvancedSelfSizingTools.h"

// - constants
static const CGFloat UISMEC_STD_CELL_PADDING = 5.0f;

// - locals
static NSMutableDictionary *mdImageFontLookup = nil;
static CGFloat minHeight                      = -1.0f;
static UITextView *tvSizer                    = nil;            //  to overcome a weird visual glitch when using sizeThatFits

// - forward declarations
@interface UISealedMessageEditorContentCell (internal) <UITextViewDelegate>
+(UITextView *) standardTextView;
-(void) commonConfiguration;
-(void) evaluateContentDimensions:(BOOL) withDelegateNotification;
-(void) evaluateContentDimensionsForWidth:(CGFloat)width andDelegateNotification:(BOOL) delegateNotification;
+(UIFont *) fontToMatchImageOfHeight:(CGFloat) imageHeight;
+(UIFont *) preferredEditingFont;
@end

@interface UITextViewWithoutOffset : UITextView
@end

/************************************
 UISealedMessageEditorContentCell
 ************************************/
@implementation UISealedMessageEditorContentCell
/*
 *  Object attributes
 */
{
    UITextView                  *tvContent;
    CGFloat                     tvUsefulHeight;
    UISealedMessageBubbleViewV2 *bvImage;
    BOOL                        styleTransition;
    BOOL                        useMergeMode;
    BOOL                        shouldBeFirst;
    CGFloat                     xOffsetForFlush;
}
@synthesize index;
@synthesize delegate;

/*
 *  It is entirely possible that a text field has no content, in which case, it
 *  is sized to zero.  Make sure that doesn't happen.
 */
+(CGFloat) minimumTextHeight
{
    if (minHeight < 0.0f) {
        // - we must use a text field to get its internal padding.
        UITextField *tf = [[[UITextField alloc] init] autorelease];
        tf.borderStyle  = UITextBorderStyleNone;
        tf.font         = [UISealedMessageEditorContentCell preferredEditingFont];
        tf.text         = @"W";                                                             //  a large character to provide plenty of room.
        [tf sizeToFit];
        minHeight = CGRectGetHeight(tf.bounds);
    }
    return minHeight;
}

/*
 *  Use this duration if possible to apply changes to the view size so that internal and external animations
 *  remain generally in-synch.
 */
+(NSTimeInterval) recommendedSizeAnimationDuration
{
    return [ChatSeal standardSqueezeTime];
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
 *  Free the object
 */
-(void) dealloc
{
    delegate = nil;
    
    tvContent.delegate = nil;
    [tvContent release];
    tvContent = nil;
    
    [bvImage removeFromSuperview];
    [bvImage release];
    bvImage = nil;
    
    [super dealloc];
}

/*
 *  Set the current content as an image.
 */
-(void) setImage:(UIImage *) img
{
    [self setImage:img withAnimation:NO];
}

/*
 *  Set the current content as an image.
 */
-(void) setImage:(UIImage *) img withAnimation:(BOOL) animated
{
    tvContent.text  = nil;
    BOOL wasCreated = NO;
    if (img) {
        self.clipsToBounds = YES;
        if (!bvImage) {
            bvImage                  = [[UISealedMessageBubbleViewV2 alloc] init];
            bvImage.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self addSubview:bvImage];
            wasCreated = YES;
        }
        [bvImage setContent:img];
        
        CGRect rcTextBoundsBefore = tvContent.bounds;
        [self evaluateContentDimensions:YES];
        
        //  - if we're creating a new image view, its animation must be performed after
        //    the content dimensions are computed
        if (wasCreated && animated) {
            bvImage.alpha = 0.0f;
            CGRect rcBefore      = bvImage.frame;
            CGRect rcHidden      = CGRectOffset(rcBefore, -CGRectGetWidth(rcBefore), 0.0f);
            rcHidden.size.height = 0.0f;                //  - the view is currently small and is being expanded.
            bvImage.frame        = rcHidden;
            CGRect rcText        = tvContent.frame;
            tvContent.frame      = CGRectMake(CGRectGetWidth(self.bounds) - CGRectGetWidth(rcTextBoundsBefore), 0.0f, CGRectGetWidth(rcTextBoundsBefore), CGRectGetHeight(rcTextBoundsBefore));
            styleTransition      = YES;
            [UIView animateWithDuration:[UISealedMessageEditorContentCell recommendedSizeAnimationDuration] animations:^(void){
                bvImage.alpha   = 1.0f;
                bvImage.frame   = rcBefore;
                tvContent.frame = rcText;
            } completion:^(BOOL finished){
                if (shouldBeFirst) {
                    [tvContent becomeFirstResponder];
                }
                styleTransition    = NO;
            }];
        }
        
        // - it never makes sense to scroll next to the image.
        tvContent.scrollEnabled = NO;
    }
    else {
        // - when there is no image, prepare this view for text instead.
        [self setText:nil];
    }
}

/*
 *  Set the current content as text.
 */
-(void) setText:(NSString *) text
{
    [self setText:text withAnimation:NO];
}

/*
 *  Set the current content as text.
 */
-(void) setText:(NSString *) text withAnimation:(BOOL) animated
{
    UIView *bvToDestroy = nil;
    UIFont *fntBefore = nil;
    
    self.clipsToBounds = NO;            // otherwise we won't see the spelling suggestions.
    if (bvImage) {
        bvToDestroy    = bvImage;
        [bvImage release];
        bvImage        = nil;
        fntBefore      = tvContent.font;
        tvContent.font = [UISealedMessageEditorContentCell preferredEditingFont];
        [tvContent sizeToFit];
    }
    tvContent.text = text;
    
    // - in order to get size updates, we need to have scrolling enabled in the text view
    tvContent.scrollEnabled = YES;
    
    CGRect rcTextFrameBefore = tvContent.frame;
    [self evaluateContentDimensions:YES];
    
    // - when we're destroying an existing image, it must be done last after the content dimensions
    //   are computed.
    if (bvToDestroy) {
        UITextView *tvDummy = nil;
        BOOL iAmFirst = [tvContent isFirstResponder];
        if (animated && iAmFirst) {
            tvDummy = [UISealedMessageEditorContentCell standardTextView];
        }
        void (^completeDestruction)(BOOL finished) = ^(BOOL finished) {
            [bvToDestroy removeFromSuperview];
            self.clipsToBounds = NO;
            if (shouldBeFirst) {
                shouldBeFirst = [tvContent becomeFirstResponder];
            }
            [tvDummy removeFromSuperview];          //  just let it go away since it isn't needed any longer.
            styleTransition    = NO;            
        };
        
        // - when animating this transition,
        //   build a fake field that can hold the larger caret temporarily as the
        //   view is shrunk.
        if (animated && iAmFirst) {
            tvDummy.font          = fntBefore;
            tvDummy.frame         = rcTextFrameBefore;
            tvDummy.delegate      = self;
            [self addSubview:tvDummy];
            [tvDummy becomeFirstResponder];
            styleTransition       = YES;
            self.clipsToBounds    = YES;
            [UIView animateWithDuration:[UISealedMessageEditorContentCell recommendedSizeAnimationDuration] animations:^(void){
                bvToDestroy.alpha    = 0.0f;
                CGRect rcHidden      = CGRectMake(0.0f, CGRectGetHeight(tvContent.bounds)/2.0f, 0.0f, 0.0f);
                bvToDestroy.frame    = rcHidden;
                tvDummy.frame        = tvContent.frame;
            }completion:completeDestruction];
        }
        else {
            completeDestruction(YES);
        }        
    }
}

/*
 *  Return the current content in the cell.
 */
-(id) content
{
    if (bvImage) {
        return bvImage.content;
    }
    else {
        return tvContent.text;
    }
}

/*
 *  Returns whether there is content available in the cell.
 */
-(BOOL) hasContent
{
    if (bvImage) {
        return YES;
    }
    else {
        return [tvContent.text length] > 0 ? YES : NO;
    }
}

/*
 *  Assign the content to the cell.
 */
-(void) setContent:(id) content withAnimation:(BOOL) animated
{
    if ([content isKindOfClass:[UIImage class]]) {
        [self setImage:content withAnimation:animated];
    }
    else if (!content || [content isKindOfClass:[NSString class]]) {
        [self setText:content withAnimation:animated];
    }
}

/*
 *  Allow the owner to see if this cell is first responder.
 */
-(BOOL) isFirstResponder
{
    if (styleTransition) {
        return shouldBeFirst;
    }
    else {
        return [tvContent isFirstResponder];
    }
}

/*
 *  Become the first responder
 */
-(BOOL) becomeFirstResponder
{
    if (styleTransition && bvImage) {
        shouldBeFirst = YES;
        return YES;
    }
    shouldBeFirst = [tvContent becomeFirstResponder];
    return shouldBeFirst;
}

/*
 *  Relinquish first responder status.
 */
-(BOOL) resignFirstResponder
{
    [super resignFirstResponder];
    shouldBeFirst = NO;
    for (UIView *vw in self.subviews) {
        if ([vw isFirstResponder]) {
            [vw resignFirstResponder];
            break;
        }
    }
    return YES;
}

/*
 *  Compute a size that accurately reflects the required content size.
 */
-(CGSize) sizeThatFits:(CGSize)size
{
    [self evaluateContentDimensionsForWidth:size.width andDelegateNotification:NO];
    CGFloat addPadding = 0.0f;
    if (bvImage) {
        addPadding = UISMEC_STD_CELL_PADDING;
    }
    return CGSizeMake(ceilf((float)size.width), ceilf((float)(CGRectGetMinY(tvContent.frame) + tvUsefulHeight + addPadding)));
}

/*
 *  This method is used to determine where content will be inserted based on the current cursor location
 *  and selection.
 */
-(smec_insertion_point_t) currentInsertionPoint
{
    //  - when the image view is enabled, we always assume that
    //    they want to insert after it.
    if (bvImage) {
        return SMECI_END;
    }
    
    NSRange r = tvContent.selectedRange;
    NSString *tContent = tvContent.text;
    if (!tContent || (r.location == 0 && r.length == [tContent length])) {
        return SMECI_ALL;
    }
    
    if (r.location == 0) {
        return SMECI_BEGIN;
    }
    else if (NSMaxRange(r) == [tContent length]) {
        return SMECI_END;
    }
    else {
        return SMECI_MIDDLE;
    }
}

/*
 *  When text is selected and we insert an image, the intention is to replace that text
 *  with the image, so we'll use this method to delete it.
 */
-(void) removeSelectedText
{
    if (bvImage) {
        return;
    }
    
    NSRange rSelection = tvContent.selectedRange;
    if (rSelection.length > 0) {
        NSString *t = tvContent.text;
        if (rSelection.location < [t length] && NSMaxRange(rSelection) <= [t length]) {
            NSString *sBefore = @"";
            if (rSelection.location > 0) {
                sBefore = [t substringToIndex:rSelection.location];
            }
            
            NSString *sAfter = @"";
            if (NSMaxRange(rSelection) < [t length]) {
                sAfter = [t substringFromIndex:NSMaxRange(rSelection)];
            }
            
            tvContent.text          = [sBefore stringByAppendingString:sAfter];
            tvContent.selectedRange = NSMakeRange(rSelection.location, 0);
        }
    }
}

/*
 *  Whereever the current insertion point is, delete the remainder and return it.
 */
-(NSString *) splitCellAndReturnRemainder
{
    if (bvImage) {
        return @"";
    }
    
    // - make sure we're working with just an insertion point.
    [self removeSelectedText];
    
    NSRange rSelected = tvContent.selectedRange;
    NSString *fullStr = tvContent.text;
    
    if (rSelected.location < [fullStr length] && NSMaxRange(rSelected) <= [fullStr length]) {
        NSString *sBefore = [fullStr substringToIndex:rSelected.location];
        NSString *sAfter  = [fullStr substringFromIndex:rSelected.location];
        tvContent.text    = sBefore;
        return sAfter;
    }
    else {
        return @"";
    }
}

/*
 *  Make the cell invalid.
 */
-(void) setInvalid
{
    index           = -1;
    shouldBeFirst   = NO;
    styleTransition = NO;
}

/*
 *  Check if the cell is valid.
 */
-(BOOL) isValid
{
    if (index >= 0) {
        return YES;
    }
    return NO;
}

/*
 *  Return the block of selected text or just the cursor position from the text view.
 */
-(NSRange) currentSelection
{
    return tvContent.selectedRange;
}

/*
 *  Assign the current selection range to the cell's text view.
 */
-(void) setCurrentSelection:(NSRange) selRange
{
    if (NSMaxRange(selRange) <= [tvContent.text length]) {
        tvContent.selectedRange = selRange;
    }
}

/*
 *  When the cell is touched, make sure it becomes first responder.
 */
-(void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    
    // - when the image is present, give the caller a chance to prevent the
    //   focus change, which is a special scenario.
    if (bvImage) {
        for (UITouch *t in touches) {
            if (t.view == bvImage) {
                if ([self isValid] &&
                    delegate && [delegate respondsToSelector:@selector(sealedMessageCellAllowFocusChangeWhenTappingImage:)]) {
                    if (![delegate sealedMessageCellAllowFocusChangeWhenTappingImage:self]) {
                        return;
                    }
                }
                break;
            }
        }
    }
    
    [self becomeFirstResponder];
}

/*
 *  When layout events occur, make sure the content dimensions are recomputed.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    [self evaluateContentDimensions:NO];
}

/*
 *  Merge mode is a special case that will prepare a cell to be used for merge animations.  
 *  It will not be useful for anything else after merge is complete and is intended only as 
 *  a visual transition item.
 *  - merging requires precise spacing between adjacent items so the text view will be 
 *    aligned along the top right where its caret begins.
 */
-(void) useMergeMode
{
    if ([self isValid]) {
        return;
    }
    useMergeMode       = YES;
    tvContent.editable = NO;
    self.clipsToBounds = YES;
    [self evaluateContentDimensions:NO];
}

/*
 *  Return the rectangle for the caret at the current point of selection.
 */
-(CGRect) caretRectangeAtSelection
{
    UITextRange *tr = tvContent.selectedTextRange;
    if (tr) {
        return [tvContent caretRectForPosition:tr.end];
    }
    else {
        return [tvContent caretRectForPosition:tvContent.endOfDocument];
    }
}

/*
 *  Replace the content in the current selection
 */
-(void) replaceSelectionWithText:(NSString *) text
{
    [tvContent replaceRange:tvContent.selectedTextRange withText:text];
}

/*
 *  Prepare a cell to be removed from the parent.
 */
-(void) prepareForDeletion
{
    // - we turn on clipping so that the underlying text view doesn't momentarily
    //   obscure the following cell.
    self.clipsToBounds = YES;
}

/*
 *  Return the frame for the content in the cell.
 */
-(CGRect) contentFrame
{
    if (bvImage) {
        return bvImage.frame;
    }
    else {
        return tvContent.frame;
    }
}

/*
 *  Whenever a dynamic type notification is received by the parent view, it
 *  should be passed-along so that this cell can respond to it.
 */
-(void) updateDynamicTypeNotificationReceived
{
    // - force a recomputation.
    minHeight = -1.0f;
    
    // - the sizer cannot be used again until it is regenerated with a new font.
    [tvSizer release];
    tvSizer = nil;
    
    // - when there is no image, that means this is entirely text
    if (!bvImage) {
        UITextView *tvOld  = tvContent;
        tvOld.delegate     = nil;
        tvContent          = [[UISealedMessageEditorContentCell standardTextView] retain];
        tvContent.delegate = self;
        [self addSubview:tvContent];
        
        // - assign the prior text.
        [self setText:tvOld.text withAnimation:NO];        
        
        // - make sure the first responder status is preserved
        tvContent.selectedRange = tvOld.selectedRange;
        if (shouldBeFirst) {
            [tvContent becomeFirstResponder];
        }
        
        tvContent.alpha = 0.0f;
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void){
            tvContent.alpha = 1.0f;
            tvOld.alpha     = 0.0f;
        }completion:^(BOOL finished){
            [tvOld removeFromSuperview];
            [tvOld release];
        }];
    }
}

/*
 *  Return the inset for the text container.
 */
-(UIEdgeInsets) textContainerInset
{
    return tvContent.textContainerInset;
}

@end


/********************************************
 UISealedMessageEditorContentCell (internal)
 ********************************************/
@implementation UISealedMessageEditorContentCell (internal)

/*
 *  Return a text view configured as it would be initially.
 */
+(UITextView *) standardTextView
{
    UITextView *tvRet            = [[UITextViewWithoutOffset alloc] init];
    tvRet.font                   = [UISealedMessageEditorContentCell preferredEditingFont];
    tvRet.bounces                = NO;
    tvRet.autocapitalizationType = UITextAutocapitalizationTypeSentences;
    tvRet.autocorrectionType     = UITextAutocorrectionTypeDefault;
    tvRet.backgroundColor        = [ChatSeal defaultEditorBackgroundColor];
    return [tvRet autorelease];
}

/*
 *  Configure the view.
 */
-(void) commonConfiguration
{
    [self setInvalid];
    delegate               = nil;
    tvUsefulHeight         = 0.0;
    styleTransition        = NO;
    useMergeMode           = NO;
    shouldBeFirst          = NO;
    
    self.backgroundColor   = [UIColor clearColor];
    
    //  - the text view always exists because we need a way to interact with
    //    this view.
    tvContent               = [[UISealedMessageEditorContentCell standardTextView] retain];
    tvContent.scrollsToTop  = NO;
    tvContent.delegate      = self;
    [self addSubview:tvContent];
    
    //  - the text view adds left padding that we want to ignore and this
    //    will allow us to grab that distance.
    tvContent.text = @"W";
    CGPoint pt = [tvContent.layoutManager locationForGlyphAtIndex:0];
    tvContent.text = @"";
    xOffsetForFlush = -pt.x;
    if (isinf(xOffsetForFlush)) {
        xOffsetForFlush = 0.0f;
    }
    
    //  - default to text mode.
    [self setText:nil];
}

/*
 *  Check if the content size has changed and notify the delegate accordingly.
 */
-(void) evaluateContentDimensions:(BOOL) withDelegateNotification
{
    [self evaluateContentDimensionsForWidth:CGRectGetWidth(self.bounds) andDelegateNotification:withDelegateNotification];
}

/*
 *  Check if the content size has changed and notify the delegate accordingly.
 */
-(void) evaluateContentDimensionsForWidth:(CGFloat)width andDelegateNotification:(BOOL) delegateNotification
{
    CGSize szCurContent = tvContent.bounds.size;
    
    // - animations are intended to be performed at the editor level because sizing of these items
    //   isn't something that the person is supposed to see.  The editor is supposed to animate the size of the
    //   container around them, but we don't want to see the items themselves expanding.
    [UIView performWithoutAnimation:^(void) {
        // - if the image view exists, that will require the two views
        //   placed side-by-side, otherwise the edit view alone takes up available
        //   space.
        if (bvImage && bvImage.content) {
            bvImage.hidden = NO;
            
            //  - use the display cell to compute the size so that we can retain a consistent
            //    look between the two.
            CGFloat imageSize = [UISealedMessageDisplayCellV2 minimumCellHeightForImage:(UIImage *) bvImage.content];
            CGSize szCurImage = [bvImage sizeThatFits:CGSizeMake(imageSize, imageSize)];
            tvUsefulHeight    = szCurImage.height;
            bvImage.frame     = CGRectMake(0.0f, UISMEC_STD_CELL_PADDING, szCurImage.width, szCurImage.height);
            CGFloat editBeginX = szCurImage.width;
            tvContent.frame   = CGRectMake(editBeginX, UISMEC_STD_CELL_PADDING, width - editBeginX, szCurImage.height);
            
            //  - figure out the font size for the text view to match
            tvContent.font = [UISealedMessageEditorContentCell fontToMatchImageOfHeight:szCurImage.height];
        }
        else {
            if (!tvSizer) {
                tvSizer = [[UISealedMessageEditorContentCell standardTextView] retain];
            }
            bvImage.hidden = YES;           //  - if its image is set to nil.
            if (!tvContent.text) {
                tvContent.text = @"";
            }
            CGFloat minH      = [UISealedMessageEditorContentCell minimumTextHeight];
            
            // - NOTE: using the content view that we have in this cell will cause a strange shift of the caret when done in
            //   response to a textChanged delegate event, so I'm using a separate text view for that to avoid issues.
            tvSizer.attributedText = tvContent.attributedText;
            CGSize  szContent      = [tvSizer sizeThatFits:CGSizeMake(width - xOffsetForFlush, 1.0f)];
            CGFloat height         = szContent.height - tvContent.textContainerInset.bottom;                  //  to ensure that only inter-cell spacing, not the bottom border, is included.
            CGFloat yOffset        = 0.0f;
            if (useMergeMode) {
                yOffset = -tvContent.textContainerInset.top;
            }
            if (height < [UISealedMessageEditorContentCell minimumTextHeight]) {
                height = [UISealedMessageEditorContentCell minimumTextHeight];
            }
            tvUsefulHeight = height;
            height         += minH;            //  make the text view larger so that it isn't bouncing around when we change lines.
            
            CGRect rcFrame  = CGRectMake(xOffsetForFlush, yOffset, width - xOffsetForFlush, height);
            tvContent.frame = rcFrame;
        }
    }];
    
    //  - notify the delegate if things change
    if (delegateNotification &&
        [self isValid] &&
        ((int) szCurContent.width != (int) CGRectGetWidth(tvContent.bounds) ||
         (int) szCurContent.height != (int) CGRectGetHeight(tvContent.bounds))) {
            if (delegate && [delegate respondsToSelector:@selector(sealedMessageCellContentResized:)]) {
                [delegate performSelector:@selector(sealedMessageCellContentResized:) withObject:self];
            }
    }
}

/*
 *  Return a font that is suitable for display with the image.
 */
+(UIFont *) fontToMatchImageOfHeight:(CGFloat) imageHeight
{
    if (!mdImageFontLookup) {
        mdImageFontLookup = [[NSMutableDictionary alloc] init];
    }
    
    // - computing these point sizes is a costly operation so we'll cache
    //   the results.
    UIFont *fntWorking = [UISealedMessageEditorContentCell preferredEditingFont];
    int lastGoodPointSize = (int) fntWorking.pointSize;
    for (int i = 0; i < 512; i++) {
        NSNumber *n = [mdImageFontLookup objectForKey:[NSNumber numberWithInt:lastGoodPointSize]];
        if (!n) {
            fntWorking    = [fntWorking fontWithSize:lastGoodPointSize];
            CGSize szFont = [@"WWW" sizeWithAttributes:[NSDictionary dictionaryWithObject:fntWorking forKey:NSFontAttributeName]];
            n             = [NSNumber numberWithFloat:(float)(szFont.height)];
            [mdImageFontLookup setObject:n forKey:[NSNumber numberWithInt:lastGoodPointSize]];
        }
        if (n.floatValue > imageHeight) {
            break;
        }
        lastGoodPointSize++;
    }
    return [fntWorking fontWithSize:lastGoodPointSize];
}

/*
 *  Get a font for editing.
 */
+(UIFont *) preferredEditingFont
{
    // - this font cannot ever be the really huge preferred font sizes under iOS8 because
    //   the editor will not have enough room with the keyboard.
    return [UIAdvancedSelfSizingTools constrainedFontForPreferredSettingsAndTextStyle:UIFontTextStyleBody];
}

/*
 *  This method is triggered when any content changes and is a good time to evaluate
 *  its size.
 */
-(void) textViewDidChange:(UITextView *)textView
{
    [self evaluateContentDimensions:YES];
}

/*
 *  When editing begins, this is called.
 */
-(BOOL) textViewShouldBeginEditing:(UITextView *)textView
{
    shouldBeFirst = YES;
    if ([self isValid] &&
        delegate && [delegate respondsToSelector:@selector(sealedMessageCellBecameFirstResponder:)]) {
        [delegate performSelector:@selector(sealedMessageCellBecameFirstResponder:) withObject:self];
    }
    return YES;
}

/*
 *  Ensure that the text view records the loss of first responder status.
 */
-(BOOL) textViewShouldEndEditing:(UITextView *)textView
{
    // - I left this in here with nothing because my first inclination was to hook it
    //   and track the first responder status, but that would be a mistake since
    //   this is fired when executing a cell transition and we shouldn't lose first
    //   responder status during that time.
    return YES;
}

/*
 *  Track when editing ends.
 */
-(void) textViewDidEndEditing:(UITextView *)textView
{
    if ([self isValid] &&
        delegate && [delegate respondsToSelector:@selector(sealedMessageCellLostFirstResponder:)]) {
        [delegate performSelector:@selector(sealedMessageCellLostFirstResponder:) withObject:self];
    }
}

/*
 *  Hook this method so that we can know when we're deleting the last of the text in the field.
 */
-(BOOL) textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    //  - don't allow text modifications while we're transitioning the style of the cell.
    if (styleTransition) {
        return NO;
    }
    
    // - if the text in the cell is gone, this is a special case that may require custom deletion.
    if ([text length] == 0 && range.location == 0 && range.length == 0) {
        // - when we have an image, we'll convert back over to a text-only field.
        if (bvImage) {
            if ([self isValid] &&
                delegate && [delegate respondsToSelector:@selector(sealedMessageCellImageDeletionRequest:)]) {
                [delegate performSelector:@selector(sealedMessageCellImageDeletionRequest:) withObject:self];
            }
        }
        else {
            if ([self isValid] &&
                delegate && [delegate respondsToSelector:@selector(sealedMessageCellBackspaceFromFront:)]) {
                [delegate performSelector:@selector(sealedMessageCellBackspaceFromFront:) withObject:self];
            }
        }
        return NO;
    }
    
    //  - otherwise, prevent text from being added when we're in image mode.
    if (bvImage) {
        if ([self isValid] &&
            delegate && [delegate respondsToSelector:@selector(sealedMessageCell:contentLimitReachedWithText:)]) {
            [delegate performSelector:@selector(sealedMessageCell:contentLimitReachedWithText:) withObject:self withObject:text];
        }
        return  NO;
    }
    else {
        //  check if this is going to modify content availability
        NSString *curText = tvContent.text;
        BOOL hasText      = ([tvContent.text length] > 0) ? YES : NO;
        if (!curText) {
            curText = @"";
        }
        curText           = [curText stringByReplacingCharactersInRange:range withString:text];
        BOOL newHasText   = ([curText length] > 0 ? YES : NO);
        if (hasText != newHasText) {
            if (delegate && [delegate respondsToSelector:@selector(sealedMessageCell:contentIsAvailable:)]) {
                [delegate sealedMessageCell:self contentIsAvailable:newHasText];
            }
        }
        return YES;
    }
}

@end

/**************************************
 UITextViewWithoutOffset
 **************************************/
@implementation UITextViewWithoutOffset

/*
 *  The text view under iOS8 adjusts the content offset when moving to new lines, but that
 *  causes problems for the display.  We never use its scrolling features, so we're not going to worry about
 *  that.
 */
-(void) setContentOffset:(CGPoint)contentOffset
{
    [super setContentOffset:CGPointZero];
}

/*
 *  The text view under iOS8 adjusts the content offset when moving to new lines, but that
 *  causes problems for the display.  We never use its scrolling features, so we're not going to worry about
 *  that.
 */
-(void) setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated
{
    [super setContentOffset:CGPointZero animated:animated];
}
@end