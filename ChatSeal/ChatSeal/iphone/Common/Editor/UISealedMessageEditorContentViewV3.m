//
//  UISealedMessageEditorContentViewV3.m
//  ChatSeal
//
//  Created by Francis Grolemund on 4/23/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealedMessageEditorContentViewV3.h"
#import "UISealedMessageEditorContentCell.h"
#import "ChatSeal.h"

// - types
typedef enum
{
    UISME_SCROLL_TOP = 0,
    UISME_SCROLL_TOP_FLEX,
    UISME_SCROLL_BOT,
    UISME_SCROLL_BOT_FLEX
} uisme_scroll_position_t;

typedef void (^smeCompletionBlock)(void);

// - constants
static const NSUInteger UISME_NO_ACTIVE_ITEM   = (NSUInteger) -1;

// - forward declarations
@interface UISealedMessageEditorContentViewV3 (internal)
-(void) commonConfiguration;
-(UISealedMessageEditorContentCell *) reusableCell;
-(UISealedMessageEditorContentCell *) insertNewContentCellAtIndex:(NSUInteger) index;
-(UISealedMessageEditorContentCell *) insertNewContentCellAtIndex:(NSUInteger) index withContent:(id) content withAnimation:(BOOL) animated;
-(UISealedMessageEditorContentCell *) appendNewContentCell;
-(void) updateCellIndices;
-(void) saveReusableCellForLater:(UISealedMessageEditorContentCell *) reusableCell;
-(void) sendImageCountUpdate;
-(void) resizeCellToEditor:(UISealedMessageEditorContentCell *) cell ofWidth:(CGFloat) width;
-(void) resizeCellToEditor:(UISealedMessageEditorContentCell *)cell;
-(void) setContentHeight:(CGFloat) contentHeight andAllowSmaller:(BOOL) allowSmaller;
-(void) setContentHeightFromTotalHeight;
-(NSUInteger) effectiveCurrentContentItem;
-(UISealedMessageEditorContentCell *) currentContentCell;
-(void) setScrollCompletion:(smeCompletionBlock) newCB;
-(void) scrollToItem:(NSUInteger) index withAnimation:(BOOL) animated andCompletion:(smeCompletionBlock) completionBlock;
-(void) scrollToItem:(NSUInteger) index andPosition:(uisme_scroll_position_t) scrollPos withAnimation:(BOOL) animated andCompletion:(smeCompletionBlock) completionBlock;
-(void) overrideContentOffset:(CGPoint) contentOffset withAnimation:(BOOL) animated andCompletion:(smeCompletionBlock) completionBlock;
-(NSUInteger) firstVisibleCell;
-(void) addPhotoAtCursorPositionIndirect:(UIImage *) image;
-(void) deleteContentCellAtIndex:(NSUInteger) index;
-(void) mergeContentAroundIndex:(NSUInteger) index;
-(void) deleteContentCellAndAutomergeAtIndex:(NSUInteger) index;
-(void) evaluateContentAvailabilityAfterCellAvail:(BOOL) cellIsAvail;
-(void) resizeAllContentForWidth:(CGFloat) width;
@end

@interface UISealedMessageEditorContentViewV3 (cell) <UISealedMessageEditorContentCellDelegate>
@end

@interface UISealedMessageEditorContentViewV3 (stdDelegates) <UIScrollViewDelegate>
-(void) completeScrollingWithStandardProcessing;
@end

/***********************************
 UISealedMessageEditorContentViewV3
 ***********************************/
@implementation UISealedMessageEditorContentViewV3
/*
 *  Object attributes
 */
{
    NSUInteger              currentContentItem;
    NSUInteger              lastActiveContentItem;
    NSMutableArray          *maContentCells;
    NSMutableArray          *maReusableCells;
    
    UIScrollView            *svEditor;
    UIView                  *vwCellContainer;
    CGSize                  lastDimensions;
    CGFloat                 actualContentHeight;    
    
    smeCompletionBlock      scrollCompletion;
    BOOL                    forceFullCellLayout;
    
    UILabel                 *lHintText;
    
    BOOL                    isContentBeingResized;
}
@synthesize delegate;

/*
 *  Use this duration if possible to apply changes to the view size so that internal and external animations
 *  remain generally in-synch.
 *  - For the most part, many of the animations here were tied to the owning view's direction assuming it
 *    either did the layout or set the frame within an animation block.  There are two exceptions that I didn't
 *    think were worth getting overly wound up about - the merging and splitting of the content in here.  In those
 *    cases, I use internal animation blocks that will look best if you use this duration outside the view also.
 */
+(NSTimeInterval) recommendedSizeAnimationDuration
{
    return [UISealedMessageEditorContentCell recommendedSizeAnimationDuration];
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
 *  Free the object.
 */
-(void) dealloc
{
    delegate = nil;
    [self setScrollCompletion:nil];
    
    [maContentCells release];
    maContentCells = nil;
    
    [maReusableCells release];
    maReusableCells = nil;
    
    [vwCellContainer release];
    vwCellContainer = nil;
    
    svEditor.delegate = nil;
    [svEditor release];
    svEditor = nil;
    
    [lHintText release];
    lHintText = nil;
    
    [super dealloc];
}

/*
 *  Add a photo into the content at the current cursor location.
 */
-(void) addPhotoAtCursorPosition:(UIImage *) image
{
    // - make sure the current selection is visible before adding the photo
    [self scrollToItem:currentContentItem withAnimation:YES andCompletion:^(void){
        [self addPhotoAtCursorPositionIndirect:image];
    }];
}

/*
 *  Return all the edited content items.
 */
-(NSArray *) contentItems
{
    // - the content is tracked inside the views that manage it.
    NSMutableArray *maRet = [NSMutableArray array];
    for (UISealedMessageEditorContentCell *cell in maContentCells) {
        NSObject *obj = cell.content;
        if (obj) {
            [maRet addObject:obj];
        }
    }
    return maRet;
}

/*
 *  Assign the editor content items.  This is expected to be an
 *  array of NSString and UIImage objects.
 */
-(void) setContentItems:(NSArray *) array
{
    // - first discard all the current cells.
    for (UISealedMessageEditorContentCell *cell in maContentCells) {
        [self saveReusableCellForLater:cell];
    }
    [maContentCells removeAllObjects];
    
    // - sanity validation so that we never test goofy scenarios.
    // - this control is designed to produce arrays of a specific format
    //   and so we'll assume they are provided as well.
    for (NSUInteger i = 0; i < [array count]; i++) {
        NSObject *obj = [array objectAtIndex:i];
        if (![obj isKindOfClass:[NSString class]] &&
            ![obj isKindOfClass:[UIImage class]]) {
            NSAssert(NO, @"Invalid content item passed to the content view at index %lu.", (unsigned long) i);
            return;
        }
        
        // - verify that two strings are not passed next to each other.
        if (i > 0 && [obj isKindOfClass:[NSString class]] && [[array objectAtIndex:i-1] isKindOfClass:[NSString class]]) {
            NSAssert(NO, @"Strings must be combined in sequence at indexes %lu and %lu", (unsigned long) i-1, (unsigned long) i);
            return;
        }
    }

    // - create all the cells that we're going to display.
    for (NSObject *obj in array) {
        UISealedMessageEditorContentCell *cell = [self appendNewContentCell];
        [cell setContent:obj withAnimation:NO];
    }
    
    // - ensure there is always at least one
    BOOL hasItems = YES;
    if ([maContentCells count] == 0) {
        currentContentItem = UISME_NO_ACTIVE_ITEM;
        hasItems           = NO;
        [self appendNewContentCell];
    }
    else {
        currentContentItem = [maContentCells count] - 1;
    }
    lHintText.alpha = hasItems ? 0.0f : 1.0f;

    // - ensure we get a chance to update the overall layout
    actualContentHeight = 0.0f;
    lastDimensions      = CGSizeZero;
    [self setNeedsLayout];
    
    // - notify the delegate of any developments.
    if (self.delegate && [self.delegate respondsToSelector:@selector(sealedMessageEditor:contentIsAvailable:)]) {
        [(id<UISealedMessageEditorContentViewV3Delegate>)self.delegate sealedMessageEditor:self contentIsAvailable:hasItems];
    }
    [self sendImageCountUpdate];
}

/*
 *  The hint text is shown when there is no entered data.
 */
-(void) setHintText:(NSString *) hintText
{
    if (!lHintText) {
        lHintText                 = [[UILabel alloc] init];
        lHintText.font            = [UIFont systemFontOfSize:17.0f];
        lHintText.textColor       = [UIColor lightGrayColor];
        lHintText.numberOfLines   = 1;
        lHintText.textAlignment   = NSTextAlignmentLeft;
        lHintText.backgroundColor = [UIColor clearColor];
        [self addSubview:lHintText];
    }
    lHintText.text = hintText;
    [lHintText sizeToFit];
    [self setNeedsLayout];
}

/*
 *  Return an envelope view for the current content and aligned where it needs to be based on the requested
 *  display offset.
 *  - the returned view is specified in terms of local coordinates.
 */
-(UISealedMessageEnvelopeViewV2 *) envelopeForCurrentContentAndTargetHeight:(CGFloat) targetHeight
{
    if (![maContentCells count]) {
        return nil;
    }
    
    // - create the envelope itself.
    UISealedMessageEnvelopeViewV2 *envelope = [[[UISealedMessageEnvelopeViewV2 alloc] initWithWidth:CGRectGetWidth(self.bounds)
                                                                                   andMaximumHeight:targetHeight] autorelease];
    // - since our messages have limited items, we're going to include all
    //   of them in the envelope so that when it is resized (especially in landscape), the obscured content
    //   is visible and reassures the user that their content is being passed-along.
    for (NSUInteger i = 0; i < [maContentCells count]; i++) {
        UISealedMessageEditorContentCell *cell = [maContentCells objectAtIndex:i];
        CGRect   rcContentFrame                = [cell contentFrame];
        rcContentFrame.origin                  = cell.frame.origin;
        
        // - include the content offset within the scroll view
        rcContentFrame          = CGRectOffset(rcContentFrame, 0.0f, -svEditor.contentOffset.y);
        
        // - add the cell to the envelope as a bubble.
        [envelope addBubbleContent:cell.content fromCellInFrame:rcContentFrame];
    }
    return envelope;
}

/*
 *  This method will determine if there is active content.
 */
-(BOOL) hasContent
{
    for (UISealedMessageEditorContentCell *cell in maContentCells) {
        if ([cell hasContent]) {
            return YES;
        }
    }
    return NO;
}

/*
 *  Return the size of the content in this scrolling view.
 */
-(CGSize) contentSize
{
    // - generally speaking we always use the true size of the editor's content
    //   as a metric, but when the edited content is diminishing because it is being
    //   deleted, we want to wait on the caller to force a scroll event to occur before
    //   adjusting the excess.
    if (actualContentHeight > CGRectGetHeight(self.bounds)) {
        return svEditor.contentSize;
    }
    else {
        return CGSizeMake(svEditor.contentSize.width, MIN(actualContentHeight, svEditor.contentSize.height));
    }
}

/*
 *  Whenever a dynamic type change occurs, the receiver should call this method to
 *  ensure that everything is updated here with the new font sizes.
 */
-(void) updateDynamicTypeNotificationReceived
{
    // - notify all the visible cells of the layout change
    for (UISealedMessageEditorContentCell *cell in maContentCells) {
        cell.delegate = nil;
        [cell updateDynamicTypeNotificationReceived];
        [self resizeCellToEditor:cell];
        cell.delegate = self;
    }
    
    // - notify all the reusable cells of the layout change
    for (UISealedMessageEditorContentCell *cell in maReusableCells) {
        [cell updateDynamicTypeNotificationReceived];
        [self resizeCellToEditor:cell];
    }
    
    // - handle the layout now.
    forceFullCellLayout = YES;
    [self setNeedsLayout];
    [self setContentHeightFromTotalHeight];
}

/*
 *  Perform layout of the content.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    CGSize szCurDimensions = self.bounds.size;
    
    BOOL widthChanged = NO;
    if ((int) szCurDimensions.width != (int) lastDimensions.width) {
        widthChanged = YES;
    }
    
    BOOL heightChanged = NO;
    if ((int) szCurDimensions.height != (int) lastDimensions.height) {
        heightChanged = YES;
    }
    lastDimensions = szCurDimensions;
    
    // - if the width has changed, we'll need to recompute all the dimensions of the cells.
    if (widthChanged || forceFullCellLayout) {
        [self resizeAllContentForWidth:szCurDimensions.width];
    }
    
    // - now update the cell container
    vwCellContainer.frame = CGRectMake(1.0f, 0.0f, szCurDimensions.width, svEditor.contentSize.height);
    
    // - and lay out the cells.
    CGFloat tmp = 0.0f;
    for (UISealedMessageEditorContentCell *cell in maContentCells) {
        CGRect rcFrame = CGRectIntegral(CGRectMake(0.0f, tmp, CGRectGetWidth(cell.bounds), CGRectGetHeight(cell.bounds)));
        if (!isContentBeingResized || cell.index <= currentContentItem) {
            [UIView performWithoutAnimation:^(void) {
                cell.frame = rcFrame;
            }];
        }
        else {
            [UIView animateWithDuration:[UISealedMessageEditorContentViewV3 recommendedSizeAnimationDuration] animations:^(void) {
                cell.frame = rcFrame;
            }];
        }
        tmp           += CGRectGetHeight(rcFrame);
    }
    
    // - ensure the caret is visible, but only if we're not resizing, because that
    //   will hose up the resizing animation.
    // - NOTE: when we're shrinking this view's content area, this scrollToItem request
    //   is what will eventually force the content to be trimmed, so this call is important
    //   to eventually keeping the content in synch with the scroller, but it had to be delayed
    //   in order to allow the scrolling animation to first complete.
    if (!heightChanged) {
        [self scrollToItem:currentContentItem withAnimation:NO andCompletion:^(void) {
            // - don't do this if we relinquished first responder previously.
            if (currentContentItem != UISME_NO_ACTIVE_ITEM) {
                [[self currentContentCell] becomeFirstResponder];
            }
        }];
    }
    
    // - reposition the hint text.
    UISealedMessageEditorContentCell *cc = [maContentCells firstObject];
    if (cc) {
        CGFloat bottomY = MIN(CGRectGetMaxY(cc.frame), CGRectGetHeight(self.bounds));
        lHintText.frame  = CGRectIntegral(CGRectMake(0.0f, bottomY - CGRectGetHeight(lHintText.bounds), CGRectGetWidth(lHintText.bounds), CGRectGetHeight(lHintText.bounds)));
    }
}

/*
 *  Indicates whether this view can become first responder
 */
-(BOOL) canBecomeFirstResponder
{
    return YES;
}

/*
 *  Return my first responder status.
 */
-(BOOL) isFirstResponder
{
    // - we can't use the last item because it doesn't make sense in this context, so don't
    //   call currentContentCell.
    NSUInteger idx = (currentContentItem != UISME_NO_ACTIVE_ITEM ? currentContentItem : lastActiveContentItem);
    if (idx < [maContentCells count]) {
        UISealedMessageEditorContentCell *cell = [maContentCells objectAtIndex:idx];
        if ([cell isFirstResponder]) {
            return YES;
        }
    }
    return NO;
}

/*
 *  Resign first responder status.
 */
-(BOOL) resignFirstResponder
{
    [super resignFirstResponder];
    
    for (UISealedMessageEditorContentCell *cell in maContentCells) {
        [cell resignFirstResponder];
    }
    currentContentItem    = UISME_NO_ACTIVE_ITEM;
    return YES;
}

/*
 *  Acquire first responder status.
 */
-(BOOL) becomeFirstResponder
{
    if (currentContentItem == UISME_NO_ACTIVE_ITEM) {
        if (lastActiveContentItem == UISME_NO_ACTIVE_ITEM) {
            currentContentItem = [self firstVisibleCell];
        }
        else {
            currentContentItem = lastActiveContentItem;
            lastActiveContentItem = UISME_NO_ACTIVE_ITEM;
        }
    }
    
    if (currentContentItem < [maContentCells count]) {
        UISealedMessageEditorContentCell *cell = [maContentCells objectAtIndex:currentContentItem];
        [cell becomeFirstResponder];
        return YES;
    }
    else {
        return NO;
    }
}

/*
 *  When the frame is set, we're going to do an immediate layout so that animations
 *  surrounding this modification (which is common) are propagated into the layout
 *  and scrolling actions.
 */
-(void) setFrame:(CGRect)frame withImmediateLayout:(BOOL) immediateLayout
{
    [super setFrame:frame];
    if (immediateLayout) {
        [self setNeedsLayout];
        [self layoutIfNeeded];
    }
}

/*
 *  Figure out the ideal size for this editor.
 */
-(CGSize) sizeThatFits:(CGSize)size
{
    id<UISealedMessageEditorContentViewV3Delegate> tmpDelegate = self.delegate;
    self.delegate                                              = nil;
    [self resizeAllContentForWidth:size.width];
    self.delegate                                              = tmpDelegate;
    return CGSizeMake(size.width, svEditor.contentSize.height);                     //  before first layout, the width may be very small, but the height will be accurate.
}

/*
 *  Return the text for the item with focus.
 */
-(NSString *) textForActiveItem
{
    UISealedMessageEditorContentCell *cell = [self currentContentCell];
    if ([cell hasContent]) {
        NSObject *obj = [cell content];
        if ([obj isKindOfClass:[NSString class]]) {
            return (NSString *) obj;
        }
    }
    return nil;
}

@end

/**********************************
 UISealedMessageEditorContentViewV3
 **********************************/
@implementation UISealedMessageEditorContentViewV3 (internal)
/*
 *  Configure and initialize the object.
 */
-(void) commonConfiguration
{
    //  - make sure we receive all the delegate notifications from the parent
    delegate              = nil;
    scrollCompletion      = nil;
    forceFullCellLayout   = NO;
    isContentBeingResized = NO;
    
    // - don't assume we have a current content item
    currentContentItem    = UISME_NO_ACTIVE_ITEM;
    lastActiveContentItem = UISME_NO_ACTIVE_ITEM;
        
    // - after I got farther into this project, I realized that we'd never have the same
    //   requirements as a standard collection view with unlimited cells so I'm holding
    //   every cell I create, which should always be a maximum of 3 in the current design since
    //   it never really makes sense to do allow more than what can be reasonably stored into
    //   the packed image.
    maContentCells = [[NSMutableArray alloc] init];
    
    // - we will, however reuse cells because it takes some time to create each one.
    maReusableCells = [[NSMutableArray alloc] init];
    
    // - I decided to embed, rather than inherit from the scroll view because I see no reason to
    //   give the caller access to scroll-related methods or delegate notifications.
    svEditor                                = [[UIScrollView alloc] initWithFrame:self.bounds];
    svEditor.alwaysBounceHorizontal         = NO;
    svEditor.alwaysBounceVertical           = YES;
    svEditor.indicatorStyle                 = UIScrollViewIndicatorStyleDefault;
    svEditor.showsHorizontalScrollIndicator = NO;
    svEditor.showsVerticalScrollIndicator   = YES;
    svEditor.scrollsToTop                   = NO;
    svEditor.autoresizingMask               = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    svEditor.delegate                       = self;
    [self addSubview:svEditor];
    
    // - in order to make sure the scroll bars are not clipped, we'll
    //   put all the cells into a single sub-view that acts as a
    //   container at one z position.
    vwCellContainer = [[UIView alloc] init];
    vwCellContainer.backgroundColor = [UIColor clearColor];
    [svEditor addSubview:vwCellContainer];
            
    // - the content view is not something we can see through.
    self.backgroundColor = [ChatSeal defaultEditorBackgroundColor];
    self.clipsToBounds   = YES;
    
    // - initialize the first content item
    [self setContentItems:nil];
}

/*
 *  Either create or return a reusable cell for inclusion in the content window.
 */
-(UISealedMessageEditorContentCell *) reusableCell
{
    UISealedMessageEditorContentCell *smcc = nil;
    if ([maReusableCells count]) {
        smcc = [[maReusableCells lastObject] retain];
        [maReusableCells removeLastObject];
    }
    else {
        smcc = [[UISealedMessageEditorContentCell alloc] init];
    }
    [smcc setInvalid];              //  to ensure the delegate is not used until we're ready.
    smcc.hidden   = NO;             //  if it was hidden during a deletion earlier.
    smcc.delegate = self;
    return [smcc autorelease];
}

/*
 *  Insert a new cell to the internal array and container.
 */
-(UISealedMessageEditorContentCell *) insertNewContentCellAtIndex:(NSUInteger) index
{
    UISealedMessageEditorContentCell *cell = [self reusableCell];
    if (index >= [maContentCells count]) {
        [maContentCells addObject:cell];
    }
    else {
        [maContentCells insertObject:cell atIndex:index];
    }
    [vwCellContainer addSubview:cell];
    for (NSUInteger i = index; i < [maContentCells count]; i++) {
        UISealedMessageEditorContentCell *newTopCell = [maContentCells objectAtIndex:i];
        [vwCellContainer bringSubviewToFront:newTopCell];
    }
    forceFullCellLayout = YES;
    [self updateCellIndices];
    [self setNeedsLayout];
    return cell;
}

/*
 *  Insert a cell at the given index.
 */
-(UISealedMessageEditorContentCell *) insertNewContentCellAtIndex:(NSUInteger) index withContent:(id) content withAnimation:(BOOL) animated
{
    //  - first update the backing store.
    if (!content) {
        content = @"";
    }
    
    UISealedMessageEditorContentCell *smcc = [self insertNewContentCellAtIndex:index];
    id<UISealedMessageEditorContentCellDelegate> tmpDelegate = smcc.delegate;
    smcc.delegate = nil;
    [smcc setContent:content withAnimation:animated];
    smcc.delegate = tmpDelegate;
    return smcc;
}

/*
 *  Append a new content cell at the end of the list.
 */
-(UISealedMessageEditorContentCell *) appendNewContentCell
{
    return [self insertNewContentCellAtIndex:[maContentCells count]];
}

/*
 *  Tracking the index with each cell actually makes it easier to identify them
 *  later when updates roll in.
 */
-(void) updateCellIndices
{
    for (NSUInteger i = 0; i < [maContentCells count]; i++) {
        UISealedMessageEditorContentCell *cell = [maContentCells objectAtIndex:i];
        cell.index                             = (NSInteger) i;
    }
}

/*
 *  Save a reusable cell for display later on.
 */
-(void) saveReusableCellForLater:(UISealedMessageEditorContentCell *) reusableCell
{
    [reusableCell removeFromSuperview];
    [reusableCell setInvalid];
    reusableCell.delegate = nil;
    [reusableCell setImage:nil];                //  so we don't save anything in RAM
    [maReusableCells addObject:reusableCell];
}

/*
 *  If the delegate responds to image count updates, we need to recount all the images in the message and
 *  let it know that they have changed.
 */
-(void) sendImageCountUpdate
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(sealedMessageEditor:imageCountModifiedTo:)]) {
        NSUInteger count = 0;
        for (UISealedMessageEditorContentCell *cell in maContentCells) {
            if ([cell.content isKindOfClass:[UIImage class]]) {
                count++;
            }
        }
        [(id<UISealedMessageEditorContentViewV3Delegate>) self.delegate sealedMessageEditor:self imageCountModifiedTo:count];
    }
}

/*
 *  Resize the cell so that it will be sufficient to be displayed in the full editor.
 */
-(void) resizeCellToEditor:(UISealedMessageEditorContentCell *) cell ofWidth:(CGFloat) width;
{
    CGSize sz   = [cell sizeThatFits:CGSizeMake(width, 1.0f)];
    cell.bounds = CGRectMake(0.0f, 0.0f, sz.width, sz.height);
}

/*
 *  Resize the given cell so that it looks good within the editor.
 */
-(void) resizeCellToEditor:(UISealedMessageEditorContentCell *)cell
{
    [self resizeCellToEditor:cell ofWidth:CGRectGetWidth(self.bounds)];
}

/*
 *  Assign a height to the content region of the scrollview.
 *  - because setting the content size can cause immediate jumps in the offset,
 *    we're going to generally restrict it until the scroll offset reaches a location
 *    where the extra is obscured.
 */
-(void) setContentHeight:(CGFloat) contentHeight andAllowSmaller:(BOOL) allowSmaller
{    
    // - most of the time, we don't want to show the abrupt size adjustment when we delete
    //   content in the editor.  Instead, we'll wait until the scrolling animation completes
    //   to make that final change.
    actualContentHeight    = contentHeight;
    BOOL adjustContentSize = YES;
    if (contentHeight < self.contentSize.height && self.contentSize.height > CGRectGetHeight(self.bounds)) {
        if (svEditor.contentOffset.y + CGRectGetHeight(self.bounds) > contentHeight &&
            !allowSmaller) {
            adjustContentSize = NO;
        }
    }

    if (adjustContentSize) {
        svEditor.contentSize  = CGSizeMake(CGRectGetWidth(self.bounds), contentHeight);
    }
    
    //  - notify the delegate of the resize if it is listening.
    static BOOL notifyingDelegate = NO;
    if (notifyingDelegate) {
        return;
    }
    notifyingDelegate = YES;
    if (self.delegate &&
        [(id<UISealedMessageEditorContentViewV3Delegate>) self.delegate respondsToSelector:@selector(sealedMessageEditorContentResized:)]) {
        [self.delegate performSelector:@selector(sealedMessageEditorContentResized:) withObject:self];
    }
    notifyingDelegate = NO;
}

/*
 *  Using the recorded cell heights, update the overall content height of the view.
 */
-(void) setContentHeightFromTotalHeight
{
    CGFloat total = 0.0f;
    for (UISealedMessageEditorContentCell *cell in maContentCells) {
        total += CGRectGetHeight(cell.bounds);
    }
    [self setContentHeight:total andAllowSmaller:NO];
}

/*
 *  Compute the effective current item.
 */
-(NSUInteger) effectiveCurrentContentItem
{
    return (NSUInteger) (currentContentItem != UISME_NO_ACTIVE_ITEM) ? currentContentItem : lastActiveContentItem;
}

/*
 *  Return the current visible content cell.
 */
-(UISealedMessageEditorContentCell *) currentContentCell
{
    NSUInteger cellIndex = [self effectiveCurrentContentItem];
    if (cellIndex < [maContentCells count]) {
        return (UISealedMessageEditorContentCell *) [[[maContentCells objectAtIndex:cellIndex] retain] autorelease];
    }
    return nil;
}

/*
 *  Save the scroll completion block.
 *  - this is necessary because scrolling is often an aggregate of many movements that do not have a clear final state from
 *    an animation transaction perspective.
 */
-(void) setScrollCompletion:(smeCompletionBlock) newCB
{
    if (scrollCompletion != newCB) {
        if (scrollCompletion && newCB) {
            // - there is a pending scroll completion block so we need to ensure it
            //   gets executed
            [self completeScrollingWithStandardProcessing];
        }
        Block_release(scrollCompletion);
        scrollCompletion = nil;
        
        if (newCB) {
            scrollCompletion = Block_copy(newCB);
        }
    }
}

/*
 *  Scroll to the given item, optionaly executing the provided completion block.
 */
-(void) scrollToItem:(NSUInteger) index withAnimation:(BOOL) animated andCompletion:(smeCompletionBlock) completionBlock
{
    // - compute the first visible cell.
    NSUInteger firstVisibleCell = [self firstVisibleCell];
    
    // - this version intentionally doesn't force precision if the item is already visible
    //   because that would get a bit annoying if you were trying to work while that was happening.
    uisme_scroll_position_t scrollPos = UISME_SCROLL_TOP;
    if (index < firstVisibleCell) {
        scrollPos = UISME_SCROLL_TOP_FLEX;
    }
    else if (actualContentHeight < svEditor.contentSize.height) {
        scrollPos = UISME_SCROLL_BOT;
    }
    else {
        scrollPos = UISME_SCROLL_BOT_FLEX;
    }
    [self scrollToItem:index andPosition:scrollPos withAnimation:animated andCompletion:completionBlock];
}

/*
 *  Scroll to a specific item in the view.
 */
-(void) scrollToItem:(NSUInteger) index andPosition:(uisme_scroll_position_t) scrollPos withAnimation:(BOOL) animated andCompletion:(smeCompletionBlock) completionBlock
{
    if (![maContentCells count]) {
        return;
    }
    
    if (index >= [maContentCells count]) {
        index = [maContentCells count] - 1;
    }
    
    //  - first figure out where the item begins
    UISealedMessageEditorContentCell *cell = [maContentCells objectAtIndex:index];
    CGFloat ypos                           = CGRectGetMinY(cell.frame);
    
    // - now we need to compute the exact position of the caret
    CGRect rcCaret = [cell caretRectangeAtSelection];
    ypos += CGRectGetMinY(rcCaret);
    if (scrollPos == UISME_SCROLL_BOT || scrollPos == UISME_SCROLL_BOT_FLEX) {
        ypos += CGRectGetHeight(rcCaret);
    }
    
    // - convert that position into an offset
    CGFloat offset = ceilf((float) ypos);
    if (scrollPos == UISME_SCROLL_BOT || scrollPos == UISME_SCROLL_BOT_FLEX) {
        offset -= CGRectGetHeight(self.bounds);
    }
    
    CGFloat maxOffset = svEditor.contentSize.height - CGRectGetHeight(self.bounds);
    if (offset > maxOffset) {
        offset = maxOffset;
    }
    
    if (offset < 0.0f) {
        offset = 0.0f;
    }
    
    // - if the current item is already visible, don't scroll, but still make sure
    //   the completion block executes
    if ((scrollPos == UISME_SCROLL_TOP_FLEX && offset >= svEditor.contentOffset.y) ||
        (scrollPos == UISME_SCROLL_BOT_FLEX && offset <= svEditor.contentOffset.y) ||
        (int) offset == (int) svEditor.contentOffset.y) {
        if (completionBlock) {
            completionBlock();
        }
    }
    else {
        // - we need to track the completion block explicitly because scrolling animation
        //   is not just one but many animations combined and will complete after the first.
        [self overrideContentOffset:CGPointMake(0.0f, offset) withAnimation:animated andCompletion:completionBlock];
    }
}

/*
 *  In order to know when I'm explicitly calling setContentOffset over the implicit crap
 *  done by the scroll view at different times, this method will be my one entrypoint
 *  into setting the offset and bypassing the gate around it.
 */
-(void) overrideContentOffset:(CGPoint) contentOffset withAnimation:(BOOL) animated andCompletion:(smeCompletionBlock) completionBlock
{
    if (contentOffset.y < 0.0f) {
        contentOffset.y = 0.0f;
    }
    
    // - always save the completion block no matter how it is executed because
    //   either the transaction will complete it here or the scroll view delegate will
    //   execute it.
    [self setScrollCompletion:completionBlock];

    // - if the owner of this view is animating, then this will be done without animation, if we're doing it
    //   for internal work, then the delegate will end up firing and allowing us to finish later.
    [CATransaction begin];
    if (!animated) {
        [CATransaction setCompletionBlock:^(void) {
            [self completeScrollingWithStandardProcessing];
        }];
    }
    [svEditor setContentOffset:contentOffset animated:animated];
    [CATransaction commit];
}

/*
 *  Return the first visible cell in the scroll view.
 */
-(NSUInteger) firstVisibleCell
{
    CGPoint pt                  = svEditor.contentOffset;
    NSUInteger firstVisibleCell = 0;
    for (UISealedMessageEditorContentCell *cell in maContentCells) {
        if (pt.y >= CGRectGetMinY(cell.frame) && pt.y <= CGRectGetMaxY(cell.frame)) {
            break;
        }
        firstVisibleCell++;
    }
    return firstVisibleCell;
}

/*
 *  The basic addPhoto method may need to scroll before actually doing the work,
 *  which means that we'd need to do the splitting later in some cases.  This
 *  indirect method does the actual work.
 *  - this assumes that the current item is in the visible set when it is called.
 */
-(void) addPhotoAtCursorPositionIndirect:(UIImage *) image
{
    UISealedMessageEditorContentCell *smcc = nil;
    
    // - use the effective content item so that we can accurately track where the cursor is even
    //   when the keyboard is hidden.
    NSUInteger effectiveContentItem = [self effectiveCurrentContentItem];
    
    // - when there isn't a current item, we'll just add to the end
    if (effectiveContentItem >= [maContentCells count]) {
        smcc = [self appendNewContentCell];
        [smcc setImage:image];
        currentContentItem = [maContentCells count] - 1;
    }
    else {
        // - otherwise, we'll have to be a little smarter about how it gets inserted.
        smcc = [self currentContentCell];
        if (!smcc) {
            return;
        }
        
        smec_insertion_point_t ipoint = [smcc currentInsertionPoint];
        
        // - depending on the insertion point, we'll either reuse the existing cell or insert new cells.
        
        // ... for 'all', it is a simple replacement.
        if (ipoint == SMECI_ALL) {
            [smcc setImage:image withAnimation:YES];
        }
        
        //  ... for 'begin', we need to insert before the current cell.
        //  ... for 'end', we need to insert after the current cell.
        else if (ipoint == SMECI_BEGIN || ipoint == SMECI_END) {
            // - first remove any text that is selected
            [smcc removeSelectedText];
            
            //  - check if the cell ends with a newline because that
            //   should be removed
            if (ipoint == SMECI_END) {
                id content = [smcc content];
                if ([content isKindOfClass:[NSString class]]) {
                    NSString *s = (NSString *) content;
                    if ([s length] > 0 && s.UTF8String[s.length-1] == '\n') {
                        s = [s substringToIndex:s.length-1];
                        
                        //  - do this carefully to not force a competing animation.
                        smcc.delegate = nil;
                        [smcc setText:s];
                        smcc.delegate = self;
                    }
                }
            }
            
            if (ipoint == SMECI_END) {
                currentContentItem++;
            }
            
            //  - insert the new cell
            smcc = [self insertNewContentCellAtIndex:currentContentItem withContent:image withAnimation:YES];
        }
        
        //  ... for 'middle', we need to split the cell in half and
        //      create an image cell between the two.
        else if (ipoint == SMECI_MIDDLE) {
            NSString *remainder = [smcc splitCellAndReturnRemainder];
            if (remainder && [remainder length]) {
                const char *c = remainder.UTF8String;
                if (*c == '\n' || *c == ' ') {
                    remainder = [remainder substringFromIndex:1];
                }
            }
            
            CGSize szWasSplit = [smcc sizeThatFits:CGSizeMake(CGRectGetWidth(self.bounds), 1.0f)];            
            
            // - now insert the image
            NSUInteger nextCurrentContentItem = currentContentItem + 1;
            UISealedMessageEditorContentCell *cell = [self insertNewContentCellAtIndex:currentContentItem+1 withContent:image withAnimation:YES];
            [cell becomeFirstResponder];
            currentContentItem = nextCurrentContentItem;
            
            // - place the image right under the content for now so that it looks like it is pushing
            //   the text apart
            [self resizeCellToEditor:cell];
            CGFloat imgCellHeight = CGRectGetHeight(cell.bounds);
            cell.frame            = CGRectMake(CGRectGetMinX(smcc.frame), CGRectGetMinY(smcc.frame) + szWasSplit.height, CGRectGetWidth(cell.bounds), imgCellHeight);
            
            // - now insert the remainder
            UISealedMessageEditorContentCell *cellRem = [self insertNewContentCellAtIndex:currentContentItem+1 withContent:remainder withAnimation:NO];
            [self resizeCellToEditor:cellRem];
            
            //  - in order to provide the smoothest transition, we're going to create a dummy cell that can animate with the remainder
            //    until it is fully in position.  The remainder will be hidden during this time.
            UISealedMessageEditorContentCell *dummyCell = [self reusableCell];
            dummyCell.delegate = nil;
            dummyCell.bounds   = CGRectMake(0.0f, 0.0f, CGRectGetWidth(self.bounds), 1.0f);
            [dummyCell setText:remainder];
            [dummyCell useMergeMode];
            [dummyCell sizeToFit];
            CGFloat midX              = CGRectGetWidth(self.bounds)/2.0f + 1.0f;
            CGFloat halfDummy         = (CGRectGetHeight(dummyCell.bounds)/2.0f);
            dummyCell.center          = CGPointMake(midX, CGRectGetMaxY(smcc.frame) - halfDummy);
            dummyCell.layer.zPosition = cell.layer.zPosition;
            [self addSubview:dummyCell];
            
            CGFloat remainderMaxY = CGRectGetMinY(smcc.frame) + szWasSplit.height + imgCellHeight + CGRectGetHeight(cellRem.bounds);
            cellRem.hidden = YES;
            [UIView animateWithDuration:[UISealedMessageEditorContentViewV3 recommendedSizeAnimationDuration] animations:^(void){
                dummyCell.center = CGPointMake(midX, remainderMaxY - halfDummy);
            } completion:^(BOOL finished){
                cellRem.hidden = NO;
                [dummyCell removeFromSuperview];            //  don't save this because it was used for merging.
            }];
        }
    }
    
    // - ensure the cell is resized
    [self resizeCellToEditor:smcc];
    
    // - and that it is first responder
    [smcc becomeFirstResponder];
    
    // - ensure the content height is adjusted
    [self setContentHeightFromTotalHeight];
    
    // - update the delegate of availaibility
    [self evaluateContentAvailabilityAfterCellAvail:YES];
    
    // - and image availability
    [self sendImageCountUpdate];    
}

/*
 *  Manage cell deletion.
 */
-(void) deleteContentCellAtIndex:(NSUInteger) index
{
    if (index < [maContentCells count]) {
        UISealedMessageEditorContentCell *cell = [maContentCells objectAtIndex:index];
        
        // - make sure first responder status is retained for this editor.
        BOOL moveFromAfter                              = NO;
        UISealedMessageEditorContentCell *cellNewActive = nil;
        NSUInteger effectiveCurrentItem                 = [self effectiveCurrentContentItem];
        if (index == effectiveCurrentItem) {
            NSUInteger newCurrent = effectiveCurrentItem;
            if (newCurrent > 0) {
                newCurrent--;
                moveFromAfter = YES;
            }
            else if ([maContentCells count] == 0) {
                newCurrent = UISME_NO_ACTIVE_ITEM;
            }
            else {
                newCurrent++;
            }
            
            // - update the first responder before we delete anything.
            if (newCurrent != UISME_NO_ACTIVE_ITEM) {
                cellNewActive          = [maContentCells objectAtIndex:newCurrent];
                cellNewActive.delegate = nil;
                [cellNewActive becomeFirstResponder];
                cellNewActive.delegate = self;
                if (moveFromAfter && [cellNewActive.content isKindOfClass:[NSString class]]) {
                    [cellNewActive setCurrentSelection:NSMakeRange([(NSString *) cellNewActive.content length], 0)];
                }
                else {
                    [cellNewActive setCurrentSelection:NSMakeRange(0, 0)];
                }
            }
        }
        
        // - detach and delete the cell.
        [self saveReusableCellForLater:cell];
        [maContentCells removeObjectAtIndex:index];
        [self updateCellIndices];
        [self setNeedsLayout];
        
        // - update the current content item because the new
        //   active cell will have an adjusted index now.
        if (cellNewActive) {
            currentContentItem = (NSUInteger) cellNewActive.index;
        }
        
        // - and make sure the visual elements are preserved.
        [self setContentHeightFromTotalHeight];
    }
}

/*
 *  Assumes the given index is a cell with text on either side and that all three
 *  are visible.  Only should be used from deleteContentCellAndAutomergeAtIndex:
 */
-(void) mergeContentAroundIndex:(NSUInteger) index
{
    if (index == 0 || index >= [maContentCells count]-1) {
        NSLog(@"CS-ALERT: Invalid secure cell merge request.");
        return;
    }
    
    // - first figure out what we plan to merge.
    UISealedMessageEditorContentCell *cellBefore = [maContentCells objectAtIndex:index-1];
    UISealedMessageEditorContentCell *cellAfter  = [maContentCells objectAtIndex:index+1];
    
    if (![cellBefore.content isKindOfClass:[NSString class]] ||
        ![cellAfter.content isKindOfClass:[NSString class]]) {
        NSLog(@"CS-ALERT: Attempt to merge non-string data in secure editor.");
        return;
    }

    NSString *sBefore        = (NSString *) cellBefore.content;
    NSString *sAfter         = (NSString *) cellAfter.content;
    NSString *sMergedContent = [NSString stringWithFormat:@"%@\n%@", sBefore, sAfter];
    
    // - now generate a dummy cells that can be used to animate the transition
    UISealedMessageEditorContentCell *dummyCellBefore = [self reusableCell];
    dummyCellBefore.delegate                          = nil;
    [dummyCellBefore setText:sBefore];
    dummyCellBefore.frame                             = cellBefore.frame;
    dummyCellBefore.layer.zPosition                   = cellBefore.layer.zPosition;
    [vwCellContainer addSubview:dummyCellBefore];
    
    UISealedMessageEditorContentCell *dummyCellAfter = [self reusableCell];
    dummyCellAfter.delegate                          = nil;
    [dummyCellAfter setText:sAfter];
    [dummyCellAfter useMergeMode];
    [self resizeCellToEditor:dummyCellAfter];
    dummyCellAfter.layer.zPosition = cellAfter.layer.zPosition;
    CGFloat halfDummy = CGRectGetHeight(dummyCellAfter.bounds)/2.0f;
    dummyCellAfter.center = CGPointMake(cellAfter.center.x, CGRectGetMaxY(cellAfter.frame) - halfDummy);
    [vwCellContainer addSubview:dummyCellAfter];
    
    // - the before cell will become the primary one in a moment.
    CGFloat maxYBefore = CGRectGetMaxY(cellBefore.frame);
    cellBefore.delegate = nil;
    [cellBefore setContent:sMergedContent withAnimation:NO];
    [self resizeCellToEditor:cellBefore];
    [cellBefore setCurrentSelection:NSMakeRange([sBefore length], 0)];
    cellBefore.delegate = self;
    
    cellBefore.alpha = 0.0f;
    [UIView animateWithDuration:[UISealedMessageEditorContentViewV3 recommendedSizeAnimationDuration] animations:^(void){
        dummyCellAfter.center = CGPointMake(dummyCellAfter.center.x, maxYBefore + halfDummy);
    } completion:^(BOOL finished){
        cellBefore.alpha = 1.0;        
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            dummyCellBefore.alpha = 0.0f;
            dummyCellAfter.alpha  = 0.0f;
        } completion:^(BOOL finished2) {
            [dummyCellBefore removeFromSuperview];
            [dummyCellAfter removeFromSuperview];
        }];
    }];
    
    // - delete the cells that are going away, but make sure we delete from the end to the front
    //   to keep the indices accurate.
    [self deleteContentCellAtIndex:index+1];
    [self deleteContentCellAtIndex:index];
    
    // - ensure the content height is adjusted
    [self setContentHeightFromTotalHeight];
}

/*
 *  Delete the cell at the given index, but also handle merges between
 *  adjacent cells as well.
 */
-(void) deleteContentCellAndAutomergeAtIndex:(NSUInteger) index
{
    // - check if we need to automerge
    BOOL automerge = NO;
    if (index > 0 && index < [maContentCells count]-1) {
        // - when there is text on either side of the cell being deleted, we need to merge
        if ([((UISealedMessageEditorContentCell *)[maContentCells objectAtIndex:index-1]).content isKindOfClass:[NSString class]] &&
            [((UISealedMessageEditorContentCell *)[maContentCells objectAtIndex:index+1]).content isKindOfClass:[NSString class]]) {
            automerge = YES;
        }
    }
    
    // - when not automerging, do it immediately and leave since automerge is more
    //   complicated.
    if (!automerge) {
        [self deleteContentCellAtIndex:index];
        return;
    }
    
    //  - begin automerging by assuming that we're going to want to watch it happen.
    //  - this is never called from a place where it would happen invisibly.
    currentContentItem = index-1;
    [self scrollToItem:index-1 andPosition:UISME_SCROLL_TOP_FLEX withAnimation:YES andCompletion:^(void) {
        [self mergeContentAroundIndex:index];
    }];
}
/*
 *  When the availability of any one cell changes, check to see if we need to
 *  notify the owner of this view.
 */
-(void) evaluateContentAvailabilityAfterCellAvail:(BOOL) cellIsAvail
{
    if ([maContentCells count] == 1) {
        //  - show/hide the hint text
        if (cellIsAvail) {
            lHintText.alpha = 0.0f;
        }
        else {
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void){
                lHintText.alpha = 1.0f;
            }];
        }
        
        //  - notify the delegate
        if (self.delegate && [self.delegate respondsToSelector:@selector(sealedMessageEditor:contentIsAvailable:)]) {
            [(id<UISealedMessageEditorContentViewV3Delegate>)self.delegate sealedMessageEditor:self contentIsAvailable:cellIsAvail];
        }
    }
}

/*
 *  Adjust all the cells in the editor for the given width and update the content size.
 */
-(void) resizeAllContentForWidth:(CGFloat) width
{
    for (UISealedMessageEditorContentCell *cell in maContentCells) {
        [self resizeCellToEditor:cell ofWidth:width];
    }
    
    // - ensure that the content items and the overall content size are adjusted.
    [self setContentHeightFromTotalHeight];
}
@end

/******************************************
 UISealedMessageEditorContentViewV3 (cell)
 ******************************************/
@implementation UISealedMessageEditorContentViewV3 (cell)
/*
 *  When input focus changes, this is fired, so we can record which is the current cell.
 */
-(void) sealedMessageCellBecameFirstResponder:(UISealedMessageEditorContentCell *)cell
{
    if (cell) {
        BOOL becameFirst      = (currentContentItem == UISME_NO_ACTIVE_ITEM) ? YES : NO;
        currentContentItem    = (NSUInteger) cell.index;
        lastActiveContentItem = UISME_NO_ACTIVE_ITEM;
        if (becameFirst) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(sealedMessageEditorBecameFirstResponder:)]) {
                [(id<UISealedMessageEditorContentViewV3Delegate>)self.delegate performSelector:@selector(sealedMessageEditorBecameFirstResponder:) withObject:self];
            }
        }
    }
}

/*
 *  We need to accurately track first responder status.
 */
-(void) sealedMessageCellLostFirstResponder:(UISealedMessageEditorContentCell *)cell
{
    // - when the whole view loses first responder status we don't want to retain the current cell, but
    //   this is fired _after_ the first responder changes to a new cell.
    if (cell && cell.index == currentContentItem) {
        lastActiveContentItem = currentContentItem;
        currentContentItem    = UISME_NO_ACTIVE_ITEM;
    }
}

/*
 *  When cell sizes change, this method is called.
 */
-(void) sealedMessageCellContentResized:(UISealedMessageEditorContentCell *)cell
{
    // - in some very specific circumstances (like resizing the active cell with content below) we may
    //   want those cells below the active one to animate into their final position and not move immediately.
    isContentBeingResized = YES;
    
    [self resizeCellToEditor:cell];
    [self setNeedsLayout];
    [self setContentHeightFromTotalHeight];
    
    // - resizing is complete.
    isContentBeingResized = NO;
}

/*
 *  Add text to an image cell, which should insert a new cell or move to the following cell depending on the current configuration.
 */
-(void) sealedMessageCell:(UISealedMessageEditorContentCell *)sealedCell contentLimitReachedWithText:(NSString *)text
{
    //  - if the text is a newline, then just convert it into an empty string because
    //    the intent is to move to the next cell, not move and add a newline
    if (text && [text length] > 0 && ((const char *) text.UTF8String)[0] == '\n') {
        text = @"";
    }
    
    // - now make sure the current cell is usable.
    if (sealedCell.index == currentContentItem && sealedCell.index < [maContentCells count]) {
        //  - always begin by scrolling the insertion point into view.
        [self scrollToItem:currentContentItem withAnimation:YES andCompletion:^(void){
            // - check if there is text immediately afterward, in which case we need
            //   to prepend to that.
            if (sealedCell.index < [maContentCells count] - 1 &&
                [((UISealedMessageEditorContentCell *) [maContentCells objectAtIndex:(NSUInteger) sealedCell.index+1]).content isKindOfClass:[NSString class]]) {
                
                // - the next cell is a string, so we'll insert into that.
                currentContentItem++;
                
                //  - insert into the next cell
                UISealedMessageEditorContentCell *curCell = [self currentContentCell];
                if (curCell) {
                    id content = curCell.content;
                    if ([content isKindOfClass:[NSString class]]) {
                        curCell.currentSelection = NSMakeRange(0, 0);
                        [curCell becomeFirstResponder];
                        [curCell setText:[text stringByAppendingString:content]];
                        curCell.currentSelection = NSMakeRange([text length], 0);
                        
                        // - scroll now to the new item we just added
                        [self scrollToItem:currentContentItem withAnimation:YES andCompletion:nil];
                    }
                }
            }
            else {
                //  - create a new text cell.
                currentContentItem++;
                UISealedMessageEditorContentCell *newCell = [self insertNewContentCellAtIndex:currentContentItem withContent:text withAnimation:YES];
                if (newCell) {
                    [self resizeCellToEditor:newCell];
                    [newCell becomeFirstResponder];
                    [self setContentHeightFromTotalHeight];
                }
            }
        }];
    }
}
/*
 *  The user is attempting to delete the image from the cell, so manage that.
 */
-(void) sealedMessageCellImageDeletionRequest:(UISealedMessageEditorContentCell *)cell
{
    //  - after the image is removed, we'll evaluate the remaining text field
    //    to see if it makes sense.
    NSUInteger index = (NSUInteger) cell.index;               //  save in case it gets invalidated while changing content
    
    //  - when this cell is immediately before or after a text block, we need to delete it
    //    because it is now the equivalent of text.
    BOOL shouldDelete = NO;
    
    if (index > 0) {
        UISealedMessageEditorContentCell *cellBefore = [maContentCells objectAtIndex:index-1];
        if ([cellBefore.content isKindOfClass:[NSString class]]) {
            shouldDelete = YES;
        }
    }
    if (index + 1 < [maContentCells count]) {
        UISealedMessageEditorContentCell *cellAfter = [maContentCells objectAtIndex:index+1];
        if ([cellAfter.content isKindOfClass:[NSString class]]) {
            shouldDelete = YES;
        }
    }
    
    [CATransaction begin];
    [CATransaction setCompletionBlock:^(void) {
        // - now that the item is diminished, we can think about the deletion if necessary.
        if (shouldDelete) {
            [self deleteContentCellAndAutomergeAtIndex:index];
        }
    }];

    // - the act of setting this text will fire the delegate and cause a view resize, which is what we
    //   want because it will allow the final elements of deletion to be completed after the image
    //   goes away.
    [cell setText:nil withAnimation:YES];
    
    [CATransaction commit];
    
    // - update the delegate for availability
    [self evaluateContentAvailabilityAfterCellAvail:NO];
    
    // - and the image count too
    [self sendImageCountUpdate];
}

/*
 *  Check when tapping the image and build a text cell if the image is in the first cell.
 */
-(BOOL) sealedMessageCellAllowFocusChangeWhenTappingImage:(UISealedMessageEditorContentCell *)cell
{
    if (cell.index > 0 || cell.index != currentContentItem) {
        return YES;
    }
    
    //  - we're tapping the first cell, create text before it.
    UISealedMessageEditorContentCell *newCell = [self insertNewContentCellAtIndex:0 withContent:@"" withAnimation:NO];
    if (newCell) {
        [self resizeCellToEditor:newCell];
        [newCell becomeFirstResponder];
        [self setContentHeightFromTotalHeight];
    }
    return NO;
}

/*
 *  When all the content in a cell is deleted and the user is trying to delete more, we may need to
 *  delete the cell.
 */
-(void) sealedMessageCellBackspaceFromFront:(UISealedMessageEditorContentCell *)cell
{
    // - don't delete the last cell, but allow items after the first to be removed.
    if ([maContentCells count] > 1 && cell.index == currentContentItem) {
        id content = cell.content;
        if ([content isKindOfClass:[NSString class]] && [(NSString *) content length] > 0) {
            if (currentContentItem > 0 &&
                [((UISealedMessageEditorContentCell *)[maContentCells objectAtIndex:currentContentItem-1]).content isKindOfClass:[UIImage class]]) {
                // - quick check to delete a leading newline because it doesn't make sense
                //   visually and we probably added it earlier
                NSString *s = (NSString *) content;
                if ([s length] && ((char *) s.UTF8String)[0] == '\n') {
                    s = [s substringFromIndex:1];
                    [cell setText:s];
                }
                
                // - now move up to the prior item, which is an image.
                currentContentItem--;
                [self scrollToItem:currentContentItem withAnimation:YES andCompletion:^(void) {
                    [[self currentContentCell] becomeFirstResponder];
                }];
            }
        }
        else {
            [self deleteContentCellAndAutomergeAtIndex:(NSUInteger) cell.index];
        }
    }
}

/*
 *  This notification is sent when a cell's content changes from all available to unavailable or vice versa
 *  through manual editing.  Changes to the text or image are not reported.
 */
-(void) sealedMessageCell:(UISealedMessageEditorContentCell *)cell contentIsAvailable:(BOOL)isAvail
{
    [self evaluateContentAvailabilityAfterCellAvail:isAvail];
}

@end

/***************************************************
 UISealedMessageEditorContentViewV3 (stdDelegates)
 ***************************************************/
@implementation UISealedMessageEditorContentViewV3 (stdDelegates)
/*
 *  When scrolling completes, this method is called, either when we do the processing ourselves
 *  or when the scroll view animates it.
 */
-(void) completeScrollingWithStandardProcessing
{
    // - because of the need to keep the animations consistent for all adjustments to the
    //   frame of this view, we will wait until the frame has been changed to
    if (actualContentHeight < self.contentSize.height) {
        CGFloat maxY  = svEditor.contentOffset.y + CGRectGetHeight(self.bounds);
        CGFloat delta = svEditor.contentSize.height - maxY;
        if (delta > 0) {
            CGFloat newVal = maxY;
            if (newVal < actualContentHeight) {
                newVal = actualContentHeight;
            }
            CGFloat oldActual = actualContentHeight;
            [self setContentHeight:newVal andAllowSmaller:YES];
            actualContentHeight = oldActual;
        }
    }
    
    // - if a scroll completion block is present and the item we care about is available,
    //   run the block.
    if (scrollCompletion) {
        //  - we need to disconnect the block so that we don't
        //    get recursive executions.
        smeCompletionBlock tmp = scrollCompletion;
        scrollCompletion = nil;
        tmp();
        Block_release(tmp);
    }
}

/*
 *  When the scroll view manages its own animation, this method is called upon completion.
 */
-(void) scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    [self completeScrollingWithStandardProcessing];
}
@end