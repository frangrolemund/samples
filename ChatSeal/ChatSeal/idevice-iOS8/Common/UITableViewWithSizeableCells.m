//
//  UITableViewWithSizeableCells.m
//  ChatSeal
//
//  Created by Francis Grolemund on 9/30/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UITableViewWithSizeableCells.h"
#import "UIGenericSizableTableViewHeader.h"
#import "ChatSeal.h"
#import "UIAdvancedSelfSizingTools.h"

// - constants
static const NSTimeInterval UITVSC_HIGHLIGHT_TIMEOUT = 0.25f;

// - forward declarations.
@interface UITableViewWithSizeableCells (internal)
-(void) commonConfigurationWithSelfSizing:(BOOL) useSelfSizing;
-(void) notifyContentSizeChanged;
-(void) saveHighlightTimeoutReference;
-(NSTimeInterval) highlightTimeInterval;
@end

/*********************************
 UITableViewWithSizeableCells
 *********************************/
@implementation UITableViewWithSizeableCells
/*
 *  Object attributes.
 */
{
    BOOL            areAdvancedSizingFeaturesAvailable;
    BOOL            inSizingNotification;
    UITableView     *tvEmpty;
    NSTimeInterval  tiHighlight;
    BOOL            lockLayoutActions;
}

/*
 *  Initialize this object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonConfigurationWithSelfSizing:YES];
    }
    return self;
}

/*
 *  Initialize the object.
 */
-(id) initWithFrame:(CGRect)frame style:(UITableViewStyle)style andConfigureForSelfSizing:(BOOL) useSelfSizing
{
    self = [super initWithFrame:frame style:style];
    if (self) {
        [self commonConfigurationWithSelfSizing:useSelfSizing];
    }
    return self;
}

/*
 *  Initialize this object.
 */
-(id) initWithFrame:(CGRect)frame style:(UITableViewStyle)style
{
    return [self initWithFrame:frame style:style andConfigureForSelfSizing:YES];
}

/*
 *  Initialize the object.
 */
-(id) initWithFrame:(CGRect) frame andConfigureForSelfSizing:(BOOL) useSelfSizing
{
    return [self initWithFrame:frame style:UITableViewStylePlain andConfigureForSelfSizing:useSelfSizing];
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [tvEmpty release];
    tvEmpty = nil;
    
    [super dealloc];
}

/*
 *  Layout the view.
 */
-(void) layoutSubviews
{
    // - if we're locked don't allow layout of any kind to occur because it reorganzies
    //   the cells automatically before we return from a nav push.
    if (lockLayoutActions) {
        return;
    }
    
    [super layoutSubviews];
    
    // - end the current notification, if we were in one.
    if (inSizingNotification) {
        inSizingNotification = NO;
        [UIAdvancedSelfSizingTools completeSizeChangeSequence];
    }
}

/*
 *  Touches occurred in this view.
 */
-(void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    // - only send this on to the delegate
    if (!self.isDecelerating || !self.isDragging) {
        if ([self.delegate respondsToSelector:@selector(tableView:stationaryTouchesBegan:)]) {
            [self.delegate performSelector:@selector(tableView:stationaryTouchesBegan:) withObject:self withObject:touches];
        }
    }
    [super touchesBegan:touches withEvent:event];
}

/*
 *  Self-sizing cells make the table look like crap when there are no rows.  The height of the rows end up being a goofy minimum that
 *  has no relation to the content that will eventually be in there.  This method allows the creation of an overlay that can
 *  be used temporarily.
 */
-(void) showEmptyTableOverlayWithRowHeight:(CGFloat) rowHeight andAnimation:(BOOL) animated
{
    if (tvEmpty || ![ChatSeal isAdvancedSelfSizingInUse]) {
        return;
    }
    
    // - first create a table that we can use to overlay our own.
    tvEmpty                  = [[UITableView alloc] initWithFrame:self.bounds style:self.style];
    tvEmpty.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tvEmpty.bounces          = self.bounces;
    tvEmpty.contentInset     = self.contentInset;
    tvEmpty.separatorInset   = self.separatorInset;
    tvEmpty.separatorStyle   = self.separatorStyle;
    tvEmpty.rowHeight        = rowHeight;
    tvEmpty.backgroundColor  = [UIColor whiteColor];
    tvEmpty.layer.zPosition  = 10.0f;
    
    // - now add
    self.separatorStyle      = UITableViewCellSeparatorStyleNone;
    [self addSubview:tvEmpty];
    if (animated) {
        tvEmpty.alpha            = 0.0f;
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            tvEmpty.alpha = 1.0f;
        }];
    }
}

/*
 *  Hide the empty table overlay.
 */
-(void) hideEmptyTableOverlayWithAnimation:(BOOL)animated
{
    if (tvEmpty) {
        self.separatorStyle = tvEmpty.separatorStyle;
        [tvEmpty removeFromSuperview];
        [tvEmpty release];
        tvEmpty = nil;
    }
}

/*
 *  Set the content offset.
 */
-(void) setContentOffset:(CGPoint)contentOffset
{
    // - when we've been locked, the content offset cannot be modified.
    if (lockLayoutActions) {
        return;
    }
    
    [super setContentOffset:contentOffset];
    [self saveHighlightTimeoutReference];
}

/*
 *  Set the content offset with optional animation.
 */
-(void) setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated
{
    // - when we've been locked, the content offset cannot be modified.
    if (lockLayoutActions) {
        return;
    }
    
    [super setContentOffset:contentOffset animated:animated];
    [self saveHighlightTimeoutReference];
}

/*
 *  Assign a content size to the table.
 */
-(void) setContentSize:(CGSize)contentSize
{
    if (lockLayoutActions) {
        return;
    }
    [super setContentSize:contentSize];
}

/*
 *  Returns whether it is a good idea to allow cell highlighting now.
 */
-(BOOL) shouldPermitHighlight
{
    return [self shouldPermitHighlightAndUseTimer:YES];
}

/*
 *  Returns whether it is a good idea to allow cell highlighting now.
 */
-(BOOL) shouldPermitHighlightAndUseTimer:(BOOL) useTimer
{
    if (self.isDecelerating || self.isDragging) {
        return NO;
    }
    
    if (useTimer && [self highlightTimeInterval] - tiHighlight < UITVSC_HIGHLIGHT_TIMEOUT) {
        return NO;
    }
    
    return YES;
}

/*
 *  There is a bug in iOS8 that causes tables with resizable cells to get reset during
 *  nav transitions.  This method will allow the tables to remain where they are so that 
 *  they don't get reset.
 */
-(void) prepareForNavigationPush
{
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        return;
    }
    lockLayoutActions = YES;
}

/*
 *  The parent view controller has appeared.
 */
-(void) parentViewControllerDidDisappear
{
    lockLayoutActions = NO;
}
@end

/****************************************
 UITableViewWithSizeableCells (internal)
 ****************************************/
@implementation UITableViewWithSizeableCells (internal)
/*
 *  Configure this object.
 */
-(void) commonConfigurationWithSelfSizing:(BOOL) useSelfSizing
{
    areAdvancedSizingFeaturesAvailable = [ChatSeal isAdvancedSelfSizingInUse];
    inSizingNotification               = NO;
    tvEmpty                            = nil;
    tiHighlight                        = 0;
    lockLayoutActions                  = NO;
    
    //  - when we're using advanced table sizing, make sure we know about all updates to the dynamic content.
    if (areAdvancedSizingFeaturesAvailable) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyContentSizeChanged) name: UIContentSizeCategoryDidChangeNotification object:nil];
        
        // - NOTE: we must use this self-sizing flag because once the table view gets that value set, it apparently flags itself as self-sizing and
        //   even if we set it back, it retains that behavior.
        if (useSelfSizing) {
            // - if the estimated height is not set along with the automatic row height, we will get strange
            //   self-sizing behavior!
            self.estimatedRowHeight = [ChatSeal minimumTouchableDimension];
            self.rowHeight          = UITableViewAutomaticDimension;
        }
    }
}

/*
 *  When the content size changes, make sure all cells are updated.
 */
-(void) notifyContentSizeChanged
{
    //  NOTE: when I first did this work, I was updating the visible cells one by one, but didn't realize that
    //        implicitly caused a relayout before the visible cells were returned.  We cannot
    //        try to find those cells through that mechanism.
    
    // - update the overall header if it is configured.
    if ([self.tableHeaderView isKindOfClass:[UIGenericSizableTableViewHeader class]]) {
        UIGenericSizableTableViewHeader *header = (UIGenericSizableTableViewHeader *) self.tableHeaderView;
        [header updateDynamicTypeNotificationReceived];
        CGSize sz                               = [header sizeThatFits:CGSizeMake(CGRectGetWidth(self.bounds), 1.0f)];
        header.frame                            = CGRectMake(0.0f, 0.0f, sz.width, sz.height);
        self.tableHeaderView                    = nil;
        self.tableHeaderView                    = header;            //  force a resize
    }
    
    // - let the delegate know if it cares.
    if ([self.delegate conformsToProtocol:@protocol(UITableViewWithSizeableCellsDelegate)] &&
        [self.delegate respondsToSelector:@selector(tableViewNotifyContentSizeChanged:)]) {
        [self.delegate performSelector:@selector(tableViewNotifyContentSizeChanged:) withObject:self];
    }
    
    // - from now until layout, we'll be 'inside' the sizing notification so that the generic sizable cells
    //   can avoid costly recomputations of the fonts
    inSizingNotification = YES;
    [UIAdvancedSelfSizingTools startSizeChangeSequence];
}

/*
 *  Save a time for computing whether it is wise to highlight items.
 */
-(void) saveHighlightTimeoutReference
{
    tiHighlight = [self highlightTimeInterval];
}

/*
 *  Return the type of time interval used for computing the highlight rules.
 */
-(NSTimeInterval) highlightTimeInterval
{
    return [[NSDate date] timeIntervalSinceReferenceDate];
}

@end