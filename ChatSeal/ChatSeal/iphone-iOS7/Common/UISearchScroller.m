//
//  UISearchScroller.m
//  ChatSeal
//
//  Created by Francis Grolemund on 12/8/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UISearchScroller.h"
#import "UIPSRefreshView.h"
#import "ChatSeal.h"
#import "UIImageGeneration.h"
#import "UIAdvancedSelfSizingTools.h"

// - constants
static const CGFloat    UISS_STD_REFRESH_PAD         = 10.0f;
static const CGFloat    UISS_MIN_NAV_ADJ             = 12.0f;           // - this is used when in search mode to reliably exist right below the status bar.
static const CGFloat    UISS_DESC_PAD                = 8.0f;
static const NSUInteger UISS_MAX_SEARCH_LEN          = 64;
static const CGFloat    UISS_STD_SEARCH_FIELD_HEIGHT = 28.0f;

// - types
typedef enum {
    SSVS_CONTENT = 0,
    SSVS_SEARCH,
    SSVS_REFRESH
} _ss_visible_state_t;

// - locals
static UIImage *imgSearchBackground = nil;

// - forward declarations
@interface UISearchScroller (internal) <UIScrollViewDelegate>
-(void) commonConfiguration;
-(CGFloat) barHeight;
-(void) checkForStateChange;
-(void) updateCurrentInsetsWithAnimation:(BOOL) animated;
-(void) layoutScrollerItemsWithFrameResize:(BOOL) resizeScrollerFrame;
-(void) resetSearchText;
-(UIColor *) shadeColorIfExtraLight:(BOOL) extraLight;
-(void) setNavigationBarHidden:(BOOL) hidden animated:(BOOL)animated;
-(BOOL) navigationBarHiddenRealOrSimulated;
+(UIImage *) defaultSearchBackground;
-(void) reconfigureDynamicTextDuringInit:(BOOL) isInit;
@end

@interface UISearchScroller (search) <UISearchBarDelegate>
-(void) transformNavBarOffscreen;
-(void) transformNavBarToOrigin;
-(void) performSearchTransitionToForeground:(BOOL) isForeground;
-(void) completeSearchTransitionToForeground:(BOOL) isForeground;
-(void) moveSearchIntoForeground:(BOOL) isForeground withAnimation:(BOOL) animated;
-(BOOL) isSearchingWithContent;
@end

/********************
 UISearchScroller
 ********************/
@implementation UISearchScroller
/*
 *  Object attributes
 */
{
    UIScrollView           *svScroller;
    UINavigationController *ncOwner;
    UIView                 *vwSearchBackground;
    UISearchBar            *sbSearch;
    UIView                 *vwContent;
    UIView                 *vwSearchTools;
    UILabel                *lDescription;
    UIPSRefreshView        *refreshView;
    _ss_visible_state_t    visibleState;
    BOOL                   didProxyScroll;
    BOOL                   isSearching;
    UIView                 *vwSearchShade;
    BOOL                   inSearchTransition;
    BOOL                   extraLightSearchShade;
    UIView                 *vwSeparator;
    BOOL                   detectFirstResponderChanges;
}
@synthesize delegate;

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
 *  Free the object.
 */
-(void) dealloc
{
    delegate = nil;
    
    [vwContent release];
    vwContent = nil;
    
    [vwSearchTools release];
    vwSearchTools = nil;
    
    [lDescription release];
    lDescription = nil;
    
    [sbSearch release];
    sbSearch = nil;
    
    [vwSearchBackground release];
    vwSearchBackground = nil;
    
    [svScroller release];
    svScroller = nil;
    
    [vwSearchShade release];
    vwSearchShade = nil;
    
    [refreshView release];
    refreshView = nil;
    
    [vwSeparator release];
    vwSeparator = nil;
    
    [super dealloc];
}

/*
 *  The navigation controller is saved so we can correctly position
 *  the content and search bar.
 */
-(void) setNavigationController:(UINavigationController *) nc
{
    // - notice that is is assignment only!
    if (nc != ncOwner) {
        ncOwner = nc;
        [self setNeedsLayout];
    }
}

/*
 *  The primary content view is displayed beneath the search bar.
 */
-(void) setPrimaryContentView:(UIView *) vw
{
    if (vw != vwContent) {
        [vwContent removeFromSuperview];
        [vwContent release];
        vwContent       = [vw retain];
        vwContent.frame = self.bounds;          //  just temporary, but things like tables may need to the width to compute cell heights.
        [svScroller addSubview:vwContent];
        [svScroller sendSubviewToBack:vwContent];
    }
}

/*
 *  The search tools view is a special view that is always placed under the search 
 *  bar, but never retracts under the top, regardless of what the content is doing.
 */
-(void) setSearchToolsView:(UIView *) vw
{
    if (vw != vwSearchTools) {
        [vwSearchTools removeFromSuperview];
        [vwSearchTools release];
        vwSearchTools = [vw retain];
        [svScroller addSubview:vwSearchTools];
        [svScroller bringSubviewToFront:vwSearchTools];
    }
}

/*
 *  The label used to include a description to the search bar.
 */
-(UILabel *) descriptionLabel
{
    if (!lDescription) {
        lDescription               = [[UILabel alloc] initWithFrame:CGRectZero];
        lDescription.font          = [UIFont systemFontOfSize:14.0f];
        lDescription.textAlignment = NSTextAlignmentCenter;
        lDescription.numberOfLines = 0;
        [svScroller addSubview:lDescription];
        [self reconfigureDynamicTextDuringInit:YES];
    }
    return [[lDescription retain] autorelease];
}

/*
 *  Assign a new description to the label.
 */
-(void) setDescription:(NSString *) text withAnimation:(BOOL) animated
{
    if (animated && [ChatSeal isApplicationForeground]) {
        UIView *vwSnap = [svScroller resizableSnapshotViewFromRect:lDescription.frame afterScreenUpdates:NO withCapInsets:UIEdgeInsetsZero];
        vwSnap.frame   = lDescription.frame;
        [svScroller addSubview:vwSnap];
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
            vwSnap.alpha = 0.0f;
        } completion:^(BOOL finished) {
            [vwSnap removeFromSuperview];
        }];
    }
    [self descriptionLabel].text = text;
}

/*
 *  Add a refresh indicator to the scroll view.
 */
-(void) setRefreshEnabled:(BOOL)enabled
{
    if (enabled) {
        if (!refreshView) {
            refreshView = [[UIPSRefreshView alloc] init];
            [refreshView sizeToFit];
            [svScroller addSubview:refreshView];
        }
    }
    else {
        [refreshView removeFromSuperview];
        [refreshView release];
        refreshView = nil;
    }
}

/*
 *  When refresh is done, the owner of this view may complete it
 *  with this method, which ensures it is hidden again.
 */
-(void) setRefreshCompletedWithAnimation:(BOOL) animated
{
    if (visibleState != SSVS_CONTENT) {
        visibleState = SSVS_SEARCH;
        [self updateCurrentInsetsWithAnimation:animated];
    }
}

/*
 *  Layout the scroll view content.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    [self layoutScrollerItemsWithFrameResize:YES];
}

/*
 *  In order to coordinate the scrolling of the search scroller with the content
 *  view, we can optionally allow it to force changes in this scroll view's offset.
 *  - this method will return a flag indicating whether the offset was applied
 *    to the scroll view successfully, which allows the caller to more carefully
 *    coordinate itself with this scroll view and move this one first before its own.
 *  - NOTE: remember that positive content offsets indicate that the scroll view is being
 *    pushed upwards to show content later in the sequence.
 */
-(BOOL) applyProxiedScrollOffset:(CGPoint) proxiedContentOffset
{
    // - the only time this makes sense is when the visible state was in some other
    //   position because otherwise we want an explict state change request.
    if (![self isSearchingWithContent] && visibleState != SSVS_CONTENT) {
        // - the way we'll apply these content offsets is by adjusting the insets because
        //   we don't want the outer scroll view to re-adjust the values after we shift them
        //   in small increments.  This is due to the fact that is an independent component and not
        //   locked in place by the current drag touch.
        
        // ...because the caller is going to lock their offset in place if we return a successful value here
        //    we're going to keep adding onto the current inset as this will only ever
        //    be called in small increments at a time.
        CGFloat barHeight   = [self barHeight];
        CGFloat minInsetY = barHeight - CGRectGetMinY(vwContent.frame);
        CGFloat curInsetY = svScroller.contentInset.top;
        if (curInsetY > minInsetY && (curInsetY < barHeight || proxiedContentOffset.y > 0.0f)) {
            CGFloat newInsetY = curInsetY - proxiedContentOffset.y;
            if (newInsetY < minInsetY) {
                newInsetY = minInsetY;
            }
            else if (newInsetY > barHeight) {
                newInsetY = barHeight;
            }
            
            svScroller.contentInset  = UIEdgeInsetsMake(newInsetY, 0.0f, 0.0f, 0.0f);
            svScroller.contentOffset = CGPointMake(0.0, -newInsetY);
            
            didProxyScroll = YES;
            return YES;
        }
    }
    return NO;
}

/*
 *  When the content view scrolls this view by proxy, we want to be sure we do the final inset adjustments
 *  because there isn't an explicit scrollViewDidEndDragging event for this view.
 */
-(void) validateContentPositionAfterProxiedScrolling
{
    if (didProxyScroll) {
        _ss_visible_state_t curState = visibleState;
        [self checkForStateChange];
        if (visibleState > SSVS_CONTENT && curState == visibleState) {
            visibleState = SSVS_CONTENT;
            [self updateCurrentInsetsWithAnimation:YES];
        }
        didProxyScroll = NO;
    }
}

/*
 *  When we're about the animate during a rotation, the insets are going to need to be adjusted because
 *  that is the only time the nav bar is accurate during that rotation experience.
 */
-(void) willAnimateRotation
{
    // - this requires a complete relayout because when the insets are adjusted, then
    //   the size of the content view is adjusted (mainly by height).
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

/*
 *  Force all search bars to be closed.
 */
-(void) closeAllSearchBarsWithAnimation:(BOOL) animated
{
    if (visibleState == SSVS_CONTENT) {
        return;
    }
    
    visibleState  = SSVS_CONTENT;
    [self resetSearchText];
    if (isSearching) {
        [sbSearch resignFirstResponder];
        [self moveSearchIntoForeground:NO withAnimation:animated];
    }
    else {
        [self updateCurrentInsetsWithAnimation:animated];
    }
}

/*
 *  Returns whether the search bar is in the foreground position.
 */
-(BOOL) isSearchForeground
{
    return isSearching;
}

/*
 *  When this view resigns, it is really the search view that must be resigned.
 */
-(BOOL) resignFirstResponder
{
    [super resignFirstResponder];
    return [sbSearch resignFirstResponder];
}

/*
 *  Returns the first responder state as necessary.
 */
-(BOOL) isFirstResponder
{
    return [sbSearch isFirstResponder];
}

/*
 *  Become first responder.
 */
-(BOOL) becomeFirstResponder
{
    return [sbSearch becomeFirstResponder];
}

/*
 *  Assign search text to this view and move the search bar to the foreground.
 */
-(void) setActiveSearchText:(NSString *) searchText withAnimation:(BOOL) animated andBecomeFirstResponder:(BOOL) becomeFirst
{
    if (searchText) {
        visibleState = SSVS_SEARCH;
        sbSearch.text = searchText;
        if (!isSearching) {
            [self moveSearchIntoForeground:YES withAnimation:animated];
            if (becomeFirst) {
                [sbSearch becomeFirstResponder];
            }
        }
    }
    else {
        [self resetSearchText];
    }
}

/*
 *  Turn on/off the behavior that creates a search shade when actively searching for content.
 */
-(void) setSearchShadeExtraLightStyle:(BOOL) extraLight
{
    extraLightSearchShade = extraLight;
    if (vwSearchShade) {
        vwSearchShade.backgroundColor = [self shadeColorIfExtraLight:extraLight];
    }
}

/*
 *  Prepare to navigate to a new view controller, which manages the nav bar
 *  when we're in foreground search mode.
 */
-(void) beginNavigation
{
    [self setNavigationBarHidden:NO animated:NO];
    if (isSearching) {
        [self transformNavBarOffscreen];
    }
}

/*
 *  Finish up navigation to a new view controller when we're in foreground search mode.
 */
-(void) completeNavigation
{
    if (isSearching) {
        [self transformNavBarToOrigin];
    }
    [self setNavigationBarHidden:isSearching animated:NO];
}

/*
 *  Return the height of the foreground search
 */
-(CGFloat) foregroundSearchBarHeight
{
    if (isSearching) {
        return CGRectGetMaxY(vwSearchBackground.frame) + svScroller.contentInset.top;
    }
    else {
        return -1.0f;
    }
}

/*
 *  Detect when the first responder status changes.
 */
-(void) setDetectKeyboardResignation:(BOOL) detectionEnabled
{
    detectFirstResponderChanges = detectionEnabled;
}

/*
 *  Return the active search text.
 */
-(NSString *) searchText
{
    return sbSearch.text;
}

/*
 *  Return the current content offset.
 */
-(CGPoint) contentOffset
{
    return svScroller.contentOffset;
}

/*
 *  Turn scrolling on/off, which may be useful if we can't yet use the search behavior.
 */
-(void) setScrollEnabled:(BOOL) enabled
{
    svScroller.scrollEnabled = enabled;
}

/*
 *  Update dynamic type if necessary.
 */
-(void) updateDynamicTypeNotificationReceived
{
    [self reconfigureDynamicTextDuringInit:NO];
}

@end

/***************************
 UISearchScroller (internal)
 ***************************/
@implementation UISearchScroller (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    visibleState                              = SSVS_CONTENT;
    didProxyScroll                            = NO;
    isSearching                               = NO;
    inSearchTransition                        = NO;
    extraLightSearchShade                     = NO;
    detectFirstResponderChanges               = YES;
    self.clipsToBounds                        = NO;             //  so that zoom-in doesn't clip
    
    // - create the scroll view.
    svScroller                                = [[UIScrollView alloc] initWithFrame:self.bounds];
    svScroller.backgroundColor                = [UIColor colorWithWhite:0.94f alpha:1.0f];
    svScroller.scrollEnabled                  = YES;
    svScroller.showsHorizontalScrollIndicator = NO;
    svScroller.showsVerticalScrollIndicator   = NO;
    svScroller.alwaysBounceVertical           = YES;
    svScroller.scrollsToTop                   = NO;
    svScroller.delegate                       = self;
    svScroller.keyboardDismissMode            = UIScrollViewKeyboardDismissModeOnDrag;
    svScroller.clipsToBounds                  = NO;             //  so that zoom-in doesn't clip
    [self addSubview:svScroller];
    
    // - create the background of the search bar with its standard color, but this
    //   one is something we can control.
    vwSearchBackground = [[UIView alloc] init];
    vwSearchBackground.backgroundColor = [UIColor colorWithRed:201.0f/255.0f green:201.0f/255.0f blue:206.0f/255.0f alpha:1.0f];
    vwSearchBackground.layer.zPosition = 10.0f;
    [svScroller addSubview:vwSearchBackground];
    
    // - create the search bar, which is a minimum requirement
    sbSearch                          = [[UISearchBar alloc] init];
    sbSearch.translucent              = YES;
    sbSearch.searchBarStyle           = UISearchBarStyleMinimal;    // must be minimal because prominent includes an inconvenient border on top.
    sbSearch.autocapitalizationType   = UITextAutocapitalizationTypeNone;
    sbSearch.autocorrectionType       = UITextAutocorrectionTypeNo;
    sbSearch.spellCheckingType        = UITextSpellCheckingTypeNo;
    sbSearch.keyboardType             = UIKeyboardTypeDefault;
    sbSearch.showsScopeBar            = NO;
    sbSearch.showsSearchResultsButton = NO;
    sbSearch.placeholder              = NSLocalizedString(@"Search", nil);
    sbSearch.delegate                 = self;
    sbSearch.layer.zPosition          = 20.0f;
    [sbSearch setSearchFieldBackgroundImage:[UISearchScroller defaultSearchBackground] forState:UIControlStateNormal];
    sbSearch.searchTextPositionAdjustment = UIOffsetMake(8.0f, 0.0f);
    [svScroller addSubview:sbSearch];
    
    // - the separator is intended to offset the search from the content and must be barely noticeable.
    vwSeparator                       = [[UIView alloc] init];
    vwSeparator.backgroundColor       = [UIColor colorWithWhite:0.7f alpha:1.0f];
    vwSeparator.layer.zPosition       = 30.0f;
    [svScroller addSubview:vwSeparator];
    [self reconfigureDynamicTextDuringInit:YES];
}

/*
 *  Return the height of the navigation bar.
 */
-(CGFloat) barHeight
{
    if (ncOwner) {
        // - the nav bar needs to be measured in relation to the
        //   status bar and if it is hidden, that value is unknown.
        BOOL rehide = NO;
        if (ncOwner.navigationBarHidden) {
            [self setNavigationBarHidden:NO animated:NO];
            rehide = YES;
        }
        CGRect rcFrame = ncOwner.navigationBar.frame;
        if (rehide) {
            [self setNavigationBarHidden:YES animated:NO];
        }
        
        // - we need to undo the transform here.
        rcFrame = CGRectApplyAffineTransform(rcFrame, CGAffineTransformInvert(ncOwner.navigationBar.transform));
        if ((int) CGRectGetMinY(rcFrame) == 0) {
            // - when returning from a modal dialog and the orientation was changed, the status bar will not yet be included
            //   in the dimensions of this nav bar, which is a problem.   This very special case will ensure that the
            //   status bar gets added-in so that the address bar can be in the correct location.
            rcFrame = CGRectOffset(rcFrame, 0.0f, CGRectGetHeight([[UIApplication sharedApplication] statusBarFrame]));
        }
        return CGRectGetMaxY(rcFrame);
    }
    else {
        return 0.0f;
    }
}

/*
 *  Respond to the action of scrolling the view.
 */
-(void) scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (![self isSearchingWithContent]) {
        [self checkForStateChange];
    }
}

/*
 *  Check if the current offset implies a different section should be the primary one.
 */
-(void) checkForStateChange
{
    //  - dragging down results in a negative content offset, so that is the value we'll compare to.
    CGFloat curPos               = svScroller.contentOffset.y;
    _ss_visible_state_t oldState = visibleState;
    CGFloat barHeight            = [self barHeight];
    visibleState                 = SSVS_CONTENT;
    
    CGFloat testPos = CGRectGetMinY(sbSearch.frame) + (CGRectGetHeight(sbSearch.frame)/2.0f) - curPos;
    if (testPos > barHeight) {
        visibleState = SSVS_SEARCH;
    }
    
    if (refreshView) {
        if (CGRectGetMinY(refreshView.frame) - UISS_STD_REFRESH_PAD - curPos > barHeight) {
            visibleState = SSVS_REFRESH;
        }
    }
    
    // - only adjust the insets when an actual change occurs.
    if (visibleState != oldState) {
        if (visibleState == SSVS_REFRESH) {
            if (delegate && [delegate respondsToSelector:@selector(searchScrollerRefreshTriggered:)]) {
                [delegate performSelector:@selector(searchScrollerRefreshTriggered:) withObject:self];
            }
        }
        [self updateCurrentInsetsWithAnimation:YES];
    }
}

/*
 *  The insets are used to show the hidden content in the scroll bar and animate them cleanly
 *  between transitions.
 */
-(void) updateCurrentInsetsWithAnimation:(BOOL) animated
{
    CGFloat visibleTop   = 0.0f;
    CGFloat barHeight    = [self barHeight];
    switch (visibleState) {
        case SSVS_CONTENT:
            if (vwContent) {
                visibleTop = CGRectGetMinY(vwContent.frame);
            }
            else if (vwSearchTools) {
                visibleTop = CGRectGetMinY(vwSearchTools.frame);
            }
            else {
                visibleTop = CGRectGetMaxX(sbSearch.frame);
            }
            break;
            
        case SSVS_SEARCH:
            // - show only the top of the description or search bar
            if (isSearching) {
                CGFloat completeHeight = MAX(barHeight, CGRectGetHeight(sbSearch.frame) + UISS_MIN_NAV_ADJ);
                visibleTop             = CGRectGetMaxY(sbSearch.frame) - completeHeight;
            }
            else {
                if (lDescription) {
                    visibleTop = CGRectGetMinY(lDescription.frame);
                }
                else {
                    visibleTop = CGRectGetMinY(sbSearch.frame);
                }
            }
            break;
            
        case SSVS_REFRESH:
            //  - show everything.
            visibleTop = 0.0f;
            break;
    }
    
    // - modify the insets, possibly with animation.
    if (isSearching) {
        barHeight = 0.0f;
    }
    UIEdgeInsets targetInset = UIEdgeInsetsMake(barHeight - visibleTop, 0.0f, 0.0f, 0.0f);
    if (animated) {
        [UIView animateWithDuration:0.75f delay:0.0f usingSpringWithDamping:0.85f initialSpringVelocity:0.0f options:0 animations:^(void) {
            svScroller.contentInset = targetInset;
        }completion:nil];
    }
    else {
        svScroller.contentInset = targetInset;
    }
    
    // - it is possible the refresh view may have been still running when we quickly shifted, so make
    //   sure it is disabled.
    [refreshView setRefreshCompletionPercentage:0.0f];
    
    // - with the custom nav bar, the text for search description can be seen behind the status bar, so we'll hide that.
    if (CGRectGetMaxY(lDescription.frame) + svScroller.contentInset.top < barHeight/2.0f) {
        lDescription.hidden = YES;
    }
    else {
        if (lDescription.hidden) {
            lDescription.hidden = NO;
            if (animated) {
                lDescription.alpha  = 0.0f;
                [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                    lDescription.alpha = 1.0f;
                }];
            }
        }
    }
}

/*
 *  This scroll view never responds to the navigation bar tap.
 */
-(BOOL) scrollViewShouldScrollToTop:(UIScrollView *)scrollView
{
    return NO;
}

/*
 *  Do layout for the items, but sometimes we don't want to resize the scroller frame
 *  because it implicitly sets the content offset.
 */
-(void) layoutScrollerItemsWithFrameResize:(BOOL) resizeScrollerFrame
{
    // - don't allow extra layout events while we're shifting between foreground search because
    //   it messes up the animation.
    if (inSearchTransition) {
        return;
    }
    
    // - the layout is really quite straightforward.  We're just stacking the items vertically
    //   with a little padding around the refresh control if it exists.
    CGFloat curYOffset = 0.0f;
    CGSize szCurBounds = self.bounds.size;
    if (resizeScrollerFrame) {
        svScroller.frame   = CGRectMake(0.0f, 0.0f, szCurBounds.width, szCurBounds.height);
    }
    
    if (refreshView) {
        curYOffset         = UISS_STD_REFRESH_PAD;
        CGFloat height     = CGRectGetHeight(refreshView.bounds);
        refreshView.center = CGPointMake(szCurBounds.width/2.0f, curYOffset + (height / 2.0f));
        curYOffset        += (height + UISS_STD_REFRESH_PAD);
    }
    
    if (lDescription) {
        CGSize sz          = [lDescription sizeThatFits:CGSizeMake(szCurBounds.width, 1.0f)];
        sz.height         += UISS_DESC_PAD;
        lDescription.frame = CGRectMake(0.0f, curYOffset, szCurBounds.width, sz.height);
        curYOffset        += sz.height;
    }
    
    [sbSearch sizeToFit];
    CGFloat height           = CGRectGetHeight(sbSearch.bounds);
    CGFloat minBarHeight     = MAX([self barHeight], height + UISS_MIN_NAV_ADJ);
    if (curYOffset + height < minBarHeight) {
        curYOffset = minBarHeight - height;
    }
    sbSearch.frame           = CGRectMake(0.0f, curYOffset, szCurBounds.width, height);
    CGRect rcBackground      = sbSearch.frame;
    if (isSearching) {
        rcBackground = CGRectMake(0.0f, 0.0f, CGRectGetWidth(rcBackground), CGRectGetMaxY(rcBackground));
    }
    vwSearchBackground.frame = rcBackground;
    CGFloat onePx            = 1.0f/[UIScreen mainScreen].scale;
    vwSeparator.frame        = CGRectMake(0.0f, CGRectGetMaxY(sbSearch.frame) - onePx, szCurBounds.width, onePx);
    curYOffset              += height;

    // ...note, the search tools are intentionally place over top the content because more often than not, we want
    // the scroller to show content sliding under the tools, or at least make that possible.
    if (vwSearchTools) {
        CGSize szTools      = [vwSearchTools sizeThatFits:CGSizeMake(szCurBounds.width, 1.0f)];
        vwSearchTools.frame = CGRectMake(0.0f, curYOffset, szTools.width, szTools.height);
    }

    vwContent.frame     = CGRectMake(0.0f, curYOffset, szCurBounds.width, szCurBounds.height - [self barHeight]);
    vwSearchShade.frame = vwContent.frame;
    
    // - make sure the insets match the requirements of the new layout.
    [self updateCurrentInsetsWithAnimation:NO];
}

/*
 *  When we're scrolling we need to know if the refresh region is visible so that
 *  we can update that control's percentage complete.
 */
-(void) scrollViewDidScroll:(UIScrollView *)scrollView
{
    // - make sure the refresh view is updated when visible.
    if (refreshView) {
        CGFloat maxY        = CGRectGetMaxY(refreshView.frame) + UISS_STD_REFRESH_PAD;
        CGFloat curOffset   = svScroller.contentOffset.y;
        CGFloat barHeight   = [self barHeight];
        if (maxY - curOffset > barHeight) {
            CGFloat overhang    = (maxY - curOffset) - barHeight;
            CGFloat pctComplete = 0.0f;
            pctComplete         = overhang/maxY;
            [refreshView setRefreshCompletionPercentage:pctComplete];
        }
    }
    
    // - if the search bar is in the foreground, we have to prevent downward bouncing because
    //   that destroys the illusion of it taking over the title bar.
    if ([self isSearchingWithContent]) {
        svScroller.contentOffset = CGPointMake(0.0f, -svScroller.contentInset.top);
    }

    // - when we're at the bottom of the content, if we push up any more, the tools will
    //   be pushed under the nav bar, which isn't what we want.   The goal is to keep them
    //   locked in place at the top of the screen, so we'll adjust their position dynamically.
    if (vwSearchTools && vwContent) {
        CGFloat adjustedOffset = CGRectGetMinY(vwContent.frame) - scrollView.contentOffset.y - [self barHeight];
        if (adjustedOffset < 0.0f) {
            vwSearchTools.transform = CGAffineTransformMakeTranslation(0.0f, -adjustedOffset);
        }
        else {
            vwSearchTools.transform = CGAffineTransformIdentity;
        }
    }
}

/*
 *  Clear out the active search text.
 */
-(void) resetSearchText
{
    sbSearch.text = nil;
    [self searchBar:sbSearch textDidChange:nil];
}

/*
 *  Return one of the two different shade options.
 */
-(UIColor *) shadeColorIfExtraLight:(BOOL) extraLight
{
    CGFloat alpha = extraLight ? 0.05f : 0.2f;
    return [UIColor colorWithRed:85.0f/255.0f green:85.0f/255.0f blue:85.0f/255.0f alpha:alpha];
}

/*
 *  Returns whether the navigation bar is hidden officially with the nav bar API or
 *  by translating it, which achieves the same purpose.
 */
-(BOOL) navigationBarHiddenRealOrSimulated
{
    if (ncOwner.navigationBarHidden) {
        return YES;
    }
    
    if (ncOwner.navigationBar && !CGAffineTransformEqualToTransform(ncOwner.navigationBar.transform, CGAffineTransformIdentity)) {
        return YES;
    }
    return NO;
}

/*
 *  Generate a background image that we can use for the search bar's text field.
 */
+(UIImage *) defaultSearchBackground
{
    // - this is necessary because the prominent style adds a border around the search bar, which hoses up any merger of it with
    //   the rest of our layout here, so we use minimal and explicitly define the background to get the right effect.
    // - the default text background is slightly transparent, which looks like shit with a custom background behind everything.
    if (!imgSearchBackground) {
        CGSize szImg = CGSizeMake(12.0f, UISS_STD_SEARCH_FIELD_HEIGHT);
        UIGraphicsBeginImageContextWithOptions(szImg, NO, 0.0f);
        [[UIColor whiteColor] setFill];
        CGContextBeginPath(UIGraphicsGetCurrentContext());
        [UIImageGeneration addRoundRect:CGRectMake(0.0f, 0.0f, szImg.width, szImg.height) toContext:UIGraphicsGetCurrentContext() withCornerRadius:5.0f];
        CGContextFillPath(UIGraphicsGetCurrentContext());
        UIImage *imgBG      = UIGraphicsGetImageFromCurrentImageContext();
        imgSearchBackground = [[imgBG resizableImageWithCapInsets:UIEdgeInsetsMake(5.0f, 5.0f, 5.0f, 5.0f)] retain];
        UIGraphicsEndImageContext();
    }
    return [[imgSearchBackground retain] autorelease];
}

/*
 *  This will only manage the bar if it isn't already in the correct orientation.
 */
-(void) setNavigationBarHidden:(BOOL) hidden animated:(BOOL)animated
{
    if (ncOwner.navigationBarHidden != hidden) {
        [ncOwner setNavigationBarHidden:hidden animated:animated];
    }
}

/*
 *  Change the dynamic type in the different text items as necessary.
 */
-(void) reconfigureDynamicTextDuringInit:(BOOL) isInit
{
    // - this wasn't common prior to 8.0
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        return;
    }
    
    // - always update the label.
    [UIAdvancedSelfSizingTools constrainTextLabel:lDescription withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
    
    //  when we're done initializing, this means that the hub sent a general notification.
    if (!isInit) {
        // - there is a note in UIAppearance that indicates that the way to force an appearance update is to remove a view from its superview and then
        //   to put it back.  Our main priority here is to ensure that no delegate notifications are issued while this is happening to avoid
        //   extra changes to the owning view controller.
        BOOL isFirst = [sbSearch isFirstResponder];
        sbSearch.delegate = nil;
        [sbSearch removeFromSuperview];
        [svScroller addSubview:sbSearch];
        if (isFirst) {
            [sbSearch becomeFirstResponder];
        }
        sbSearch.delegate = self;
    }
    [self setNeedsLayout];
}
@end

/***********************
 UISearchScroller (search)
 ***********************/
@implementation UISearchScroller (search)
/*
 *  Apply a transform to the nav bar to make sure it is offscreen.
 */
-(void) transformNavBarOffscreen
{
    ncOwner.navigationBar.transform = CGAffineTransformMakeTranslation(0.0f, -[self barHeight]);
}

/*
 *  Remove all transforms to the nav bar.
 */
-(void) transformNavBarToOrigin
{
    ncOwner.navigationBar.transform = CGAffineTransformIdentity;
}

/*
 *  Move the search bar to/from the foreground.
 */
-(void) performSearchTransitionToForeground:(BOOL) isForeground
{
    if (isForeground) {
        [self transformNavBarOffscreen];
    }
    else {
        [self transformNavBarToOrigin];
    }
    [self layoutScrollerItemsWithFrameResize:NO];
    inSearchTransition = YES;
    lDescription.alpha = isForeground ? 0.0f : 1.0f;
}

/*
 *  Finish up the search bar transition.
 */
-(void) completeSearchTransitionToForeground:(BOOL) isForeground
{
    inSearchTransition = NO;

    // - make sure that the transform is removed from the nav bar so
    //   that it will respond correctly to rotations later.
    [self transformNavBarToOrigin];
    [self setNavigationBarHidden:isForeground animated:NO];
    
    // - notify the delegate upon completion.
    if (delegate && [delegate respondsToSelector:@selector(searchScroller:didMoveToForegroundSearch:)]) {
        [delegate searchScroller:self didMoveToForegroundSearch:isForeground];
    }
}

/*
 *  Change the focus on the search bar based on whether it is being used.
 */
-(void) moveSearchIntoForeground:(BOOL) isForeground withAnimation:(BOOL) animated
{
    if (isSearching == isForeground) {
        return;
    }
    isSearching = isForeground;
    
    // - allow the user to cancel searching
    [sbSearch setShowsCancelButton:isForeground animated:animated];
    
    // - when we are moving search to the background, we may want to collapse all
    //   the search bars because they no longer make sense in the context of the
    //   content.
    if (delegate && [delegate respondsToSelector:@selector(searchScroller:shouldCollapseAllAfterMoveToForeground:)]) {
        if ([delegate searchScroller:self shouldCollapseAllAfterMoveToForeground:isForeground]) {
            visibleState = SSVS_CONTENT;
        }
    }
    
    // - transition in/out of the search behavior.
    // - but animate only when the navigation bar state doesn't match the intended transition
    //   because across two separate screens we may get this call twice when the nav bar is already
    //   in the correct position.
    // - we need to disable scrolling when search is foreground so that the internal table can bounce in response
    //   to dragging.
    svScroller.scrollEnabled = !isForeground;
    if (animated && [self navigationBarHiddenRealOrSimulated] != isForeground) {
        // - when we're moving from foreground search to background,
        //   the nav bar is now off screen and must be slid back into place with
        //   the coordinated animation.
        if (!isForeground) {
            [self setNavigationBarHidden:NO animated:NO];
            [self transformNavBarOffscreen];
        }
        
        // - animate the search transition.
        [UIView animateWithDuration:0.6f delay:0.0f usingSpringWithDamping:0.8f initialSpringVelocity:0.0f options:0 animations:^(void) {
            [self performSearchTransitionToForeground:isForeground];
        }completion:^(BOOL finished) {
            [self completeSearchTransitionToForeground:isForeground];
        }];
    }
    else {
        [self performSearchTransitionToForeground:isForeground];
        [self completeSearchTransitionToForeground:isForeground];
    }
    
    // - animate the shade separately.
    if (isForeground) {
        vwSearchShade                        = [[UIView alloc] initWithFrame:vwContent.frame];
        vwSearchShade.backgroundColor        = [self shadeColorIfExtraLight:extraLightSearchShade];
        vwSearchShade.userInteractionEnabled = NO;
        vwSearchShade.alpha                  = animated ? 0.0f : 1.0f;
        [svScroller addSubview:vwSearchShade];
        if (animated) {
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                vwSearchShade.alpha = 1.0f;
            }];
        }
    }
    else {
        UIView *vwShadeTmp = vwSearchShade;
        vwSearchShade      = nil;
        if (animated) {
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                vwShadeTmp.alpha = 0.0f;
            } completion:^(BOOL finished) {
                [vwShadeTmp removeFromSuperview];
                [vwShadeTmp release];
            }];
        }
        else {
            [vwShadeTmp removeFromSuperview];
            [vwShadeTmp release];
        }
    }
}

/*
 *  Detect when the search bar became first responder.
 */
-(void) searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    if (detectFirstResponderChanges) {
        // - make sure the visible state is search only because refresh mode doesn't make sense.
        visibleState = SSVS_SEARCH;
        [self moveSearchIntoForeground:YES withAnimation:YES];
    }
}

/*
 *  The user cancelled search.
 */
-(void) searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    if (delegate && [delegate respondsToSelector:@selector(searchScrollerWillCancel:)]) {
        [delegate performSelector:@selector(searchScrollerWillCancel:) withObject:self];
    }
    [self resetSearchText];
    [sbSearch resignFirstResponder];
}

/*
 *  Detect when the search bar dismisses first responder status.
 */
-(void) searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    if (detectFirstResponderChanges && ![self isSearchingWithContent]) {
        [self moveSearchIntoForeground:NO withAnimation:YES];
    }
}

/*
 *  Forward changes in the search text onto the owner of this view.
 */
-(void) searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    if (delegate && [delegate respondsToSelector:@selector(searchScroller:textWasChanged:)]) {
        [(NSObject *) delegate performSelector:@selector(searchScroller:textWasChanged:) withObject:self withObject:searchText];
    }
}

/*
 *  Return whether there is content in the search bar.
 */
-(BOOL) isSearchingWithContent
{
    if (isSearching && [sbSearch.text length]) {
        return YES;
    }
    return NO;
}

/*
 *  Limit the quantity of text that can be added to the search text.
 */
-(BOOL) searchBar:(UISearchBar *)searchBar shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    NSString *sCur = sbSearch.text;
    if (!sCur) {
        sCur = @"";
    }
    @try {
        NSString *sNew = [sCur stringByReplacingCharactersInRange:range withString:text];
        if ([sNew length] > UISS_MAX_SEARCH_LEN) {
            return NO;
        }
    }
    @catch (NSException *exception) {
        return NO;
    }
    return YES;
}
@end
