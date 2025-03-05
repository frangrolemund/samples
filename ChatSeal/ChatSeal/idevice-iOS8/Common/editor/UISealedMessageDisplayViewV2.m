//
//  UISealedMessageDisplayViewV2.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/6/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealedMessageDisplayViewV2.h"
#import "UITableViewWithSizeableCells.h"
#import "UISealedMessageDisplayCellV2.h"
#import "ChatSeal.h"
#import "UIImageGeneration.h"
#import "UISealedMessageDisplayHeaderV2.h"
#import "UISealedMessageBubbleViewV2.h"
#import "UISealedMessageDisplayCache.h"

// - constants
static NSString       *UISMDV_CELL_NAME        = @"SealedMessageCell";
static CGFloat        UISMDV_HEADER_RESET      = -1.0f;
static NSTimeInterval UISMDV_FAST_SCROLL_RESET = -1.0f;

// - forward declarations
@interface UISealedMessageDisplayViewV2 (internal)
-(void) commonConfiguration;
-(void) updateVisibleCellSearchCriteria;
-(void) killTimer;
-(void) bumpTimerAndCreateIfNotExist:(BOOL) createIt;
-(CGFloat) rowHeightForIndexPath:(NSIndexPath *) indexPath;
-(BOOL) isFastScrolling;
@end

@interface UISealedMessageDisplayViewV2 (table) <UITableViewDataSource, UITableViewWithSizeableCellsDelegate>
-(void) checkForDeferredContentToRefresh;
@end

/*******************************
 UISealedMessageDisplayViewV2
 *******************************/
@implementation UISealedMessageDisplayViewV2
/*
 *  Object attributes.
 */
{
    UITableViewWithSizeableCells        *messageDisplay;
    UIColor                             *cOwnerBaseColor;
    UIColor                             *cOwnerTextHighlight;
    NSInteger                           lastMessageCount;
    CGFloat                             headerReferenceHeight;
    NSTimer                             *tmApplyCurrentSearchText;
    NSString                            *sCurrentSearchCriteria;
    UISealedMessageDisplayCache         *mdcCache;
    BOOL                                cachePrimed;
    BOOL                                shouldCacheRows;
    NSMutableDictionary                 *mdHeaderViews;
    NSTimeInterval                      tiLastFastScrollCheck;
    CGFloat                             posYLastFastScrollCheck;
    BOOL                                animatedScrolling;
    BOOL                                hasScrolled;
    BOOL                                hasFastScrollDeferredImages;
}
@synthesize dataSource;

/*
 *  Compute a height that will completely display the given entry.
 */
+(CGFloat) fullDisplayHeightForMessageEntryContent:(NSArray *) items inCellWidth:(CGFloat) cellWidth
{
    CGFloat ret = 0.0f;
    
    // - first compute the header.
    ret = [UISealedMessageDisplayHeaderV2 referenceHeight];
    
    // - now the content.
    for (id content in items) {
        if ([content isKindOfClass:[NSString class]]) {
            ret += [UISealedMessageDisplayCellV2 minimumCellHeightForText:(NSString *) content inCellWidth:cellWidth];
        }
        else if ([content isKindOfClass:[UIImage class]]) {
            ret += [UISealedMessageDisplayCellV2 minimumCellHeightForImage:(UIImage *) content];
        }
    }
    
    // - and return the result.
    return ret;
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
    dataSource                = nil;
    
    [self killTimer];
    
    messageDisplay.dataSource = nil;
    messageDisplay.delegate   = nil;
    [messageDisplay release];
    messageDisplay = nil;
    
    [cOwnerBaseColor release];
    cOwnerBaseColor = nil;
    
    [cOwnerTextHighlight release];
    cOwnerTextHighlight = nil;
    
    [sCurrentSearchCriteria release];
    sCurrentSearchCriteria = nil;
    
    [mdcCache release];
    mdcCache = nil;
    
    [mdHeaderViews release];
    mdHeaderViews = nil;
    
    [super dealloc];
}

/*
 *  When we remove this view from the hierarchy, we need to make sure
 *  the timer is removed from the run loop.
 */
-(void) removeFromSuperview
{
    [self killTimer];
    [super removeFromSuperview];
}

/*
 *  Turn the bouncing effect on/off in this view.
 */
-(void) setBounces:(BOOL) bounces
{
    messageDisplay.bounces = bounces;
}

/*
 *  Assign insets to the message display view.
 */
-(void) setContentInset:(UIEdgeInsets) insets
{
    messageDisplay.contentInset = insets;
}

/*
 *  Return the current offset of the message.
 */
-(CGPoint) contentOffset
{
    return messageDisplay.contentOffset;
}

/*
 *  Return the content Y offset adjusted for any applicable insets.
 */
-(CGFloat) normalizedContentYOffset
{
    return messageDisplay.contentInset.top + messageDisplay.contentOffset.y;
}

/*
 *  Set the content offset on the display view.
 */
-(void) setContentOffset:(CGPoint) pt
{
    messageDisplay.contentOffset = pt;
}

/*
 *  Add a single message onto the end of this thread.
 */
-(void) appendMessage
{
    [messageDisplay insertSections:[NSIndexSet indexSetWithIndex:(NSUInteger) lastMessageCount] withRowAnimation:UITableViewRowAnimationNone];
}

/*
 *  Scroll to a specific location.
 */
-(void) scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UITableViewScrollPosition) scrollPosition animated:(BOOL)animated
{
    if (animated) {
        animatedScrolling = YES;
    }
    [messageDisplay scrollToRowAtIndexPath:indexPath atScrollPosition:scrollPosition animated:animated];
}

/*
 *  Assign search text to this view to have the items highlighted.
 */
-(void) setSearchText:(NSString *) searchText
{
    if (sCurrentSearchCriteria != searchText && ![sCurrentSearchCriteria isEqualToString:searchText]) {
        [sCurrentSearchCriteria release];
        sCurrentSearchCriteria = [searchText retain];
        if (messageDisplay.isDecelerating || messageDisplay.isDragging) {
            [self bumpTimerAndCreateIfNotExist:YES];
        }
        else {
            [self updateVisibleCellSearchCriteria];
        }
    }
}

/*
 *  When the typeface of the system font changes size, adapt the contents of this view.
 */
-(void) updateDynamicTypeNotificationReceived
{
    if (shouldCacheRows) {
        [mdcCache clearCache];
        headerReferenceHeight = UISMDV_HEADER_RESET;
        
        // - because we're not using self-sizing, the base class doesn't offer much to help us here.
        if ([ChatSeal isAdvancedSelfSizingInUse]) {
            [messageDisplay reloadRowsAtIndexPaths:messageDisplay.indexPathsForVisibleRows withRowAnimation:UITableViewRowAnimationFade];
        }
        else {
            // - headers aren't automatically reloaded under iOS7.1
            [messageDisplay reloadData];
        }
    }
}

/*
 *  Styling in this view is performed using the seal id to retrieve colors that look good.
 */
-(void) setOwnerSealForStyling:(NSString *) sid
{
    ChatSealColorCombo *ccStyling = [ChatSeal sealColorsForSealId:sid];
    
    // - set up the colors we'll use.
    UIColor *cBase = nil;
    UIColor *cHL   = nil;
    if (ccStyling) {
        cBase = ccStyling.cMid;
        cHL   = ccStyling.cTextHighlight;
    }
    else {
        cBase = [ChatSeal defaultRemoteUserChatColor];
        cHL   = [ChatSeal primaryColorForSealColor:RSSC_STD_YELLOW];
    }
    
    // - now save the colors
    [self setOwnerBaseColor:cBase andHighlight:cHL];
}

/*
 *  Change the colors used by the view.
 */
-(void) setOwnerBaseColor:(UIColor *) cBaseColor andHighlight:(UIColor *) cHighlight
{
    // - now save the colors
    if (cBaseColor != cOwnerBaseColor) {
        [cOwnerBaseColor release];
        cOwnerBaseColor = [cBaseColor retain];
    }
    
    if (cHighlight != cOwnerTextHighlight) {
        [cOwnerTextHighlight release];
        cOwnerTextHighlight = [cHighlight retain];
    }
}

/*
 *  Reload the content in the display.
 */
-(void) reloadData
{
    [mdcCache clearCache];
    [messageDisplay reloadData];
}

/*
 *  Reload content in the view according to the supplied index paths.
 */
-(void) reloadDataWithEntryInsertions:(NSIndexSet *) isToInsert andDeletions:(NSIndexSet *) isToDelete
{
    // - the cached heights will not longer be valid because the indices are going to change.
    [mdcCache clearCache];
    
    // - update all the content
    [messageDisplay beginUpdates];
    if (isToDelete.count) {
        [messageDisplay deleteSections:isToDelete withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    if (isToInsert.count) {
        [messageDisplay insertSections:isToInsert withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    [messageDisplay endUpdates];
}

/*
 *  Return the precise rectangle dimensions of the item at the given index path.
 */
-(CGRect) rectForItemAtIndexPath:(NSIndexPath *) indexPath
{
    NSObject *objCell = [messageDisplay cellForRowAtIndexPath:indexPath];
    if (!objCell || ![objCell isKindOfClass:[UISealedMessageDisplayCellV2 class]]) {
        return CGRectZero;
    }
    
    CGRect rc = [(UISealedMessageDisplayCellV2 *) objCell bubbleRect];
    rc        = [messageDisplay convertRect:rc fromView:(UISealedMessageDisplayCellV2 *) objCell];
    rc        = [self convertRect:rc fromView:messageDisplay];
    return rc;
}

/*
 *  Return the index of the top active item.
 */
-(NSInteger) topVisibleItem
{
    NSArray *arr  = [messageDisplay indexPathsForVisibleRows];
    NSInteger ret = -1;
    for (NSIndexPath *ip in arr) {
        if (ret == -1 || ip.section < ret) {
            ret = ip.section;
        }
    }
    return ret;
}

/*
 *  Returns an indication of whether there is movement in the
 *  display.
 */
-(BOOL) isScrollingOrDragging
{
    return messageDisplay.isDecelerating || messageDisplay.isDragging;
}

/*
 *  Return the range of indices for all the visible items.
 */
-(NSRange) rangeOfVisibleContent
{
    // - keep in mind these may be returned out of order...
    NSRange ret           = NSMakeRange(NSNotFound, 0);
    NSArray *arr          = [messageDisplay indexPathsForVisibleRows];
    NSInteger highest     = -1;
    NSInteger lowest      = 999999;
    for (NSIndexPath *ip in arr) {
        if (ip.section > highest) {
            highest = ip.section;
        }
        if (ip.section < lowest) {
            lowest = ip.section;
        }
    }
    
    // - if there was something in the display array, return that range now.
    if (lowest >= 0 && highest >= 0) {
        ret = NSMakeRange((NSUInteger) lowest, (NSUInteger) (highest - lowest + 1));
    }
    
    return  ret;
}

/*
 *  Return the rectangle for the header identified by the given item or RectNull
 */
-(CGRect) headerRectForEntry:(NSUInteger) entry
{
    UISealedMessageDisplayHeaderV2 *smdh = [mdHeaderViews objectForKey:[NSNumber numberWithInteger:(NSInteger) entry]];
    if (smdh) {
        return smdh.frame;
    }
    return CGRectNull;
}

/*
 *  Keep the background color of the message display view in synch so that
 *  we can get non-transparent shots of the header views for fade animations on
 *  the search text.
 */
-(void) setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    [messageDisplay setBackgroundColor:backgroundColor];
}

/*
 *  This method will assign the maximum number of items that any one entry can store 
 *  in order to allow us to efficienty set up the cache for content.
 */
-(void) setMaximumNumberOfItemsPerEntry:(NSInteger) maxItems
{
    if (shouldCacheRows) {
        if (mdcCache || !maxItems) {
            NSLog(@"CS-ALERT: Invalid message display cache configuration.");
        }
        else {
            mdcCache = [[UISealedMessageDisplayCache alloc] initWithMaximumRowsPerSection:maxItems];
        }
    }
}

/*
 *  The message display generally assumes we only add content, but in cases where we must insert, like 
 *  when applying a search filter, it is important that we don't use cached row content until it is recomputed.
 */
-(void) prepareForContentInsertions
{
    if (shouldCacheRows) {
        [mdcCache clearCache];
    }
}
@end

/****************************************
 UISealedMessageDisplayViewV2 (internal)
 ****************************************/
@implementation UISealedMessageDisplayViewV2 (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    cOwnerBaseColor             = nil;
    cOwnerTextHighlight         = nil;
    lastMessageCount            = 0;
    headerReferenceHeight       = UISMDV_HEADER_RESET;
    tmApplyCurrentSearchText    = nil;
    sCurrentSearchCriteria      = nil;
    mdcCache                    = nil;
    cachePrimed                 = NO;
    mdHeaderViews               = [[NSMutableDictionary alloc] init];
    tiLastFastScrollCheck       = UISMDV_FAST_SCROLL_RESET;
    posYLastFastScrollCheck     = 0.0f;
    animatedScrolling           = NO;
    hasScrolled                 = NO;
    hasFastScrollDeferredImages = NO;
    
    // - NOTE: I played with the estimated row heights for this table in a bunch of different ways, but
    //         really just discovered that unless the estimates are pretty damn close, the scrolling will get
    //         wonky in a few different scenarios.  One is scrolling to the bottom quickly, another is scrolling
    //         up after auto-scrolling to the bottom.  There are lots of jitters an hiccups that occur and aren't very clean.  For
    //         this kind of text that is very much dynamically sized, I've not yet come up with a good solution to get
    //         a clean display.  Therefore, I'm going to go with the classic approach of computing all the row heights up front, which
    //         unfortunately is going to cause problems when there is a lot of content.
    shouldCacheRows          = YES;
    
    // - the main control here is a table that displays the different elements of the message.
    // - NOTE: I went through a horrible odyssey on 10/11/14-10/13/14 trying to get self-sizing to work.  The short answer is that using the
    //         self sizing creates crappy scrolling artifacts and it is really tough to quickly size text.  Therefore only using very minor
    //         features (just the stationary touch) in this sizeable cell table view and my cells here aren't self-sizeable.
    messageDisplay = [[UITableViewWithSizeableCells alloc] initWithFrame:self.bounds andConfigureForSelfSizing:!shouldCacheRows];
    messageDisplay.scrollEnabled                  = YES;
    messageDisplay.alwaysBounceVertical           = YES;
    messageDisplay.showsVerticalScrollIndicator   = YES;
    messageDisplay.alwaysBounceHorizontal         = NO;
    messageDisplay.showsHorizontalScrollIndicator = NO;
    messageDisplay.allowsSelection                = NO;
    messageDisplay.backgroundColor                = [UIColor whiteColor];
    messageDisplay.autoresizingMask               = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    messageDisplay.clipsToBounds                  = NO;   // so that zoom-in doesn't clip the cell.
    messageDisplay.keyboardDismissMode            = UIScrollViewKeyboardDismissModeOnDrag;
    messageDisplay.separatorStyle                 = UITableViewCellSeparatorStyleNone;
    messageDisplay.dataSource                     = self;
    messageDisplay.delegate                       = self;
    [messageDisplay registerClass:[UISealedMessageDisplayCellV2 class] forCellReuseIdentifier:UISMDV_CELL_NAME];
    [self addSubview:messageDisplay];
}

/*
 *  This method is executed from the timer to update all the visible items' search
 *  criteria so that we show the highlighted items.
 */
-(void) updateVisibleCellSearchCriteria
{
    [self killTimer];
    for (NSIndexPath *ip in messageDisplay.indexPathsForVisibleRows) {
        // - update the cell.
        UISealedMessageDisplayCellV2 *cell = (UISealedMessageDisplayCellV2 *) [messageDisplay cellForRowAtIndexPath:ip];
        [cell setSearchText:sCurrentSearchCriteria];
    }
    
    // - update the headers
    for (UISealedMessageDisplayHeaderV2 *hdr in mdHeaderViews.allValues) {
        [hdr setSearchText:sCurrentSearchCriteria withHighlight:cOwnerTextHighlight];
    }
}

/*
 *  Make sure the timer is going to fire after some period of time.
 */
-(void) bumpTimerAndCreateIfNotExist:(BOOL) createIt
{
    if (tmApplyCurrentSearchText) {
        [tmApplyCurrentSearchText setFireDate:[NSDate dateWithTimeIntervalSinceNow:[ChatSeal standardSearchFilterDelay]]];
    }
    else {
        if (createIt) {
            tmApplyCurrentSearchText = [[NSTimer timerWithTimeInterval:[ChatSeal standardSearchFilterDelay] target:self selector:@selector(updateVisibleCellSearchCriteria) userInfo:nil repeats:NO] retain];
            [[NSRunLoop mainRunLoop] addTimer:tmApplyCurrentSearchText forMode:NSRunLoopCommonModes];
        }
    }
}

/*
 *  Kill off the active timer.
 */
-(void) killTimer
{
    [tmApplyCurrentSearchText invalidate];
    [tmApplyCurrentSearchText release];
    tmApplyCurrentSearchText = nil;
}

/*
 *  Return the row height for the given index path and use an estimate for it if it is available.
 */
-(CGFloat) rowHeightForIndexPath:(NSIndexPath *) indexPath
{
    // - this is inherently costly, especially for a long list of items.  In order to offset
    //   the cost of doing a rotation, for example, we're going to attempt to cache the data.
    // - NOTE: when we do not use estimated heights, the table itself will cache the row heights
    //         until a rotation occurs.
    CGFloat cachedHeight = [mdcCache rowHeightForIndexPath:indexPath];
    if (cachedHeight > 0.0f) {
        return cachedHeight;
    }
    
    // - not caching rows is only really possible under iOS8.0 and later although this
    //   is not recommended at the moment.
    if (!shouldCacheRows) {
        return UITableViewAutomaticDimension;
    }
    
    // - not in the cache.
    CGFloat ret = -1.0f;
    if (dataSource) {
        // - for images, we'll try to get the cached value instead of computing it because
        //   each one requires decryption to get the basic dimensions
        if ([dataSource sealedMessageDisplay:self contentIsImageAtIndex:indexPath]) {
            ChatSealMessage *psm = nil;
            if ([dataSource respondsToSelector:@selector(messageForSealedMessageDisplay:)]) {
                psm = [dataSource messageForSealedMessageDisplay:self];
                if (psm) {
                    ChatSealMessageEntry *me = [psm entryForIndex:(NSUInteger) [indexPath section] withError:nil];
                    if (me) {
                        ret = [me cellHeightForImageAtIndex:(NSUInteger) [indexPath row]];
                    }
                }
            }
        }
        
        // - we're going to have to grab the content and compute the value.
        if (ret < 0.0f) {
            id content = [dataSource sealedMessageDisplay:self contentForItemAtIndex:indexPath];
            if ([content isKindOfClass:[NSString class]]) {
                ret = [UISealedMessageDisplayCellV2 minimumCellHeightForText:(NSString *) content inCellWidth:CGRectGetWidth(self.bounds)];
            }
            else if ([content isKindOfClass:[UIImage class]]) {
                ret = [UISealedMessageDisplayCellV2 minimumCellHeightForImage:(UIImage *) content];
            }
            else {
                NSAssert(NO, @"The returned content for the item %ld in message %ld is invalid.", (long) indexPath.item, (long) indexPath.entry);
            }
        }
        
        // - save the cached item when it was generated successfully.
        if (ret > 0.0f) {
            ret = (CGFloat) floor(ret);
            [mdcCache cacheRowHeight:ret forIndexPath:indexPath];
        }
    }
    
    return ret;
}

/*
 *  This method will compute whether we're scrolling too fast to reasonably be able to see the content, which gives us an 
 *  opportunity to optimize the display path.
 */
-(BOOL) isFastScrolling
{
    // - figure out if we're fast scrolling by seeing how much has changed since the
    //   last time we checked.
    // - determining if we're programmatically scrolling requires two pieces of information,
    //   namely that we intended to animate a transition and that the transition actually started, because
    //   otherwise we have no way of knowing if the table view decided to not move anywhere because the row
    //   already satisfies the requested behavior.
    BOOL ret = NO;
    if ([self isScrollingOrDragging] || (animatedScrolling && hasScrolled)) {
        NSTimeInterval tiCur = [NSDate timeIntervalSinceReferenceDate];
        if (tiLastFastScrollCheck > 0.0f) {
            CGFloat rate = (CGFloat) fabs((messageDisplay.contentOffset.y - posYLastFastScrollCheck)/(tiCur - tiLastFastScrollCheck));
            if (rate > (CGRectGetHeight(messageDisplay.frame) * 6.0f)) {        // - base the fact on how much of the content is being pushed fast
                ret = YES;
            }
        }
        tiLastFastScrollCheck   = tiCur;
        posYLastFastScrollCheck = messageDisplay.contentOffset.y;
    }
    else {
        tiLastFastScrollCheck   = UISMDV_FAST_SCROLL_RESET;
        posYLastFastScrollCheck = 0.0f;
        animatedScrolling       = NO;
        hasScrolled             = NO;
    }
    return ret;
}

@end

/**************************************
 UISealedMessageDisplayViewV2 (table)
 **************************************/
@implementation UISealedMessageDisplayViewV2 (table)
/*
 *  Return the number of sections in the table.
 */
-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    // - each section corresponds to a single entry in the message thread with one or more sub-items.
    NSInteger numMessages = 0;
    if (dataSource) {
        numMessages = [dataSource numberOfEntriesInDisplay:self];
        if (shouldCacheRows) {
            if (!cachePrimed) {
                cachePrimed = YES;
                if (mdcCache) {
                    [mdcCache setSectionCapacity:(NSUInteger) numMessages];
                }
                else {
                    NSLog(@"CS-ALERT: cache configuration has not been performed for message display.");
                    
                }
            }
        }
    }
    lastMessageCount = numMessages;    
    return numMessages;
}

/*
 *  Return the number of items in the given section.
 */
-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (dataSource) {
        return [dataSource sealedMessageDisplay:self numberOfItemsInEntry:section];
    }
    return 0;
}

/*
 *  Return the cell at the given index.
 */
-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UISealedMessageDisplayCellV2 *smdc = [tableView dequeueReusableCellWithIdentifier:UISMDV_CELL_NAME forIndexPath:indexPath];
    [smdc setOwnerBubbleColor:cOwnerBaseColor];
    [smdc setOwnerHighlightColor:cOwnerTextHighlight andTheirHighlight:[ChatSeal primaryColorForSealColor:RSSC_STD_YELLOW]];
    if (dataSource) {
        BOOL isMine = [dataSource sealedMessageDisplay:self authorIsLocalForEntry:indexPath.entry];
        [smdc setIsMine:isMine];
        
        NSInteger numItems = [messageDisplay numberOfRowsInSection:indexPath.entry];
        BOOL isSpoken = NO;
        if (numItems && indexPath.item == (numItems-1)) {
            isSpoken = YES;
        }
        [smdc setIsSpoken:isSpoken];
        
        // - now figure out what we're going to show.
        id content = nil;
        BOOL isImage = NO;
        if (dataSource) {
            isImage = [dataSource sealedMessageDisplay:self contentIsImageAtIndex:indexPath];
        }
        
        // - if we're moving fast and this is an image cell and we want to use placeholders for the images, we will
        //   request one now that can be used instead of the actual image, which may take a while to load.
        BOOL cellWasDeferred = NO;
        if (isImage && [self isFastScrolling] && [dataSource respondsToSelector:@selector(sealedMessageDisplay:fastScrollingPlaceholderAtIndex:)]) {
            // - NOTE: we expect the delegate to return an image with the same aspect ratio as the real one.
            content                     = [dataSource sealedMessageDisplay:self fastScrollingPlaceholderAtIndex:indexPath];
            hasFastScrollDeferredImages = YES;
            cellWasDeferred             = YES;
        }
        else {
            content  = [dataSource sealedMessageDisplay:self contentForItemAtIndex:indexPath];
        }
        
        // - assign the content
        [UIView performWithoutAnimation:^(void) {
            [smdc setContentWithDeferredAnimation:content];
        }];
        
        // - we have to flag it as deferred _after_ setting the content or it won't take hold.
        if (cellWasDeferred) {
            [smdc setContentIsDeferred];
        }
        
        // - when there is search text, we need to make sure that it gets assigned later.
        if (sCurrentSearchCriteria) {
            [self bumpTimerAndCreateIfNotExist:YES];
        }
    }
    else {
        [smdc setContentWithDeferredAnimation:nil];
    }
    
    return smdc;
}

/*
 *  Return the height of the given row in the view.
 */
-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self rowHeightForIndexPath:indexPath];
}

/*
 *  Return the header for the given section.
 */
-(UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UISealedMessageDisplayHeaderV2 *smdh = [[[UISealedMessageDisplayHeaderV2 alloc] init] autorelease];
    if (dataSource) {
        UISealedMessageDisplayHeaderDataV2 *dhd = [[[UISealedMessageDisplayHeaderDataV2 alloc] init] autorelease];
        [dataSource sealedMessageDisplay:self populateHeaderContent:dhd forEntry:section];
        UIColor *cDarkOwner = [UIColor blackColor];
        if (cOwnerBaseColor) {
            cDarkOwner = [UIImageGeneration adjustColor:cOwnerBaseColor byHuePct:1.0f andSatPct:1.0f andBrPct:0.55f andAlphaPct:1.0f];
        }
        [smdh setAuthor:dhd.author usingColor:cDarkOwner asOwner:dhd.isOwner onDate:dhd.creationDate asRead:dhd.isRead];
                
        // - when there is search text, we need to make sure it gets assigned later.
        if (sCurrentSearchCriteria) {
            [self bumpTimerAndCreateIfNotExist:YES];
        }
    }
    [mdHeaderViews setObject:smdh forKey:[NSNumber numberWithInteger:section]];
    return smdh;
}

/*
 *  Return the height for the given header.
 */
-(CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    // - the headers aren't intended to differ even when that is feasible because they are only ever one line of text.
    if (headerReferenceHeight < 0.0f) {
        headerReferenceHeight = [UISealedMessageDisplayHeaderV2 referenceHeight];
    }
    return headerReferenceHeight;
}

/*
 *  This is called when the scrolling occurs.
 */
-(void) scrollViewDidScroll:(UIScrollView *)scrollView
{
    // - there is no good way to know if a scrollToRow decided to not
    //   do anything because the row was already in position, so we're going
    //   to use two flags to determine that fact.  If we're animating scrolling and
    //   the scroll did occur, we can assume that it is moving.
    if (animatedScrolling) {
        hasScrolled = YES;
    }
    [self bumpTimerAndCreateIfNotExist:NO];
    if (dataSource && [dataSource respondsToSelector:@selector(sealedMessageDisplayDidScroll:)]) {
        [dataSource sealedMessageDisplayDidScroll:self];
    }
}

/*
 *  Called when dragging is completed.
 */
-(void) scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (dataSource && [dataSource respondsToSelector:@selector(sealedMessageDisplayDidEndDragging:willDecelerate:)]) {
        [dataSource sealedMessageDisplayDidEndDragging:self willDecelerate:decelerate];
    }
}

/*
 *  When we are scrolling too fast to see the content, we may need to refresh a few items when
 *  the animation stops.
 */
-(void) checkForDeferredContentToRefresh
{
    // - if we were previously fast scrolling and we're done with it, then see if we need to reload
    //   the content for the visible cells.
    if (hasFastScrollDeferredImages && ![self isFastScrolling]) {
        hasFastScrollDeferredImages = NO;
        for (NSIndexPath *ip in messageDisplay.indexPathsForVisibleRows) {
            UISealedMessageDisplayCellV2 *cell = (UISealedMessageDisplayCellV2 *) [messageDisplay cellForRowAtIndexPath:ip];
            if (![cell hasDeferredContent]) {
                continue;
            }
            
            // - this cell has deferred content, which means we need to reload it.
            id content  = [dataSource sealedMessageDisplay:self contentForItemAtIndex:ip];
            [cell setContentWithDeferredAnimation:content];
        }
    }
}

/*
 *  The scrolling animation was completed.
 */
-(void) scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    animatedScrolling = NO;
    if (dataSource && [dataSource respondsToSelector:@selector(sealedMessageDisplayDidEndScrollingAnimation:)]) {
        [dataSource sealedMessageDisplayDidEndScrollingAnimation:self];
    }
    [self checkForDeferredContentToRefresh];
}

/*
 *  Called when deceleration is completed
 */
-(void) scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (dataSource && [dataSource respondsToSelector:@selector(sealedMessageDisplayDidEndDecelerating:)]) {
        [dataSource sealedMessageDisplayDidEndDecelerating:self];
    }
    [self checkForDeferredContentToRefresh];
}

/*
 *  The table view has started receiving touches.
 */
-(void) tableView:(UITableView *)tableView stationaryTouchesBegan:(NSSet *)touches
{
    // - don't process tapped events with a lot of touches.
    if (touches.count > 1) {
        return;
    }
    
    if (dataSource && [dataSource respondsToSelector:@selector(sealedMessageDisplay:itemTappedAtIndex:)]) {
        UITouch *touch = [touches anyObject];
        if ([touch.view isKindOfClass:[UISealedMessageBubbleViewV2 class]]) {
            CGPoint ptLoc = [touch locationInView:messageDisplay];
            NSIndexPath *ip = [messageDisplay  indexPathForRowAtPoint:ptLoc];
            if (ip) {
                // - the last test is to make sure that we're not allowing a tap of an item that is obscured by the header.
                // - NOTE: the headerViewForSection method returns nothing, which is why we need to store this.po
                UIView *hdr  = [mdHeaderViews objectForKey:[NSNumber numberWithInteger:ip.section]];
                CGRect rcRow = [messageDisplay rectForRowAtIndexPath:ip];
                if (CGRectGetMaxY(rcRow) - CGRectGetMaxY(hdr.frame) > [ChatSeal minimumTouchableDimension]) {
                    if ([(NSObject *) dataSource performSelector:@selector(sealedMessageDisplay:itemTappedAtIndex:) withObject:self withObject:ip]) {
                        NSObject *objCell = [messageDisplay cellForRowAtIndexPath:ip];
                        if (objCell && [objCell isKindOfClass:[UISealedMessageDisplayCellV2 class]]) {
                            [(UISealedMessageDisplayCellV2 *) objCell showTapped];
                        }
                    }
                }
            }
        }
    }
}

/*
 *  The table view is gonig to finish displaying a custom header.
 */
-(void) tableView:(UITableView *)tableView didEndDisplayingHeaderView:(UIView *)view forSection:(NSInteger)section
{
    [mdHeaderViews removeObjectForKey:[NSNumber numberWithInteger:section]];
}
@end

/**************************************
 NSIndexPath (UISealedMessageDisplayView)
 **************************************/
@implementation NSIndexPath (UISealedMessageDisplayView)
/*
 *  Create a new index path.
 */
+(NSIndexPath *) indexPathForItem:(NSInteger) item inEntry:(NSInteger) entry
{
    return [NSIndexPath indexPathForItem:item inSection:entry];
}

/*
 *  Return the entry index.
 */
-(NSInteger) entry
{
    return self.section;
}
@end

/**********************************
 UISealedMessageDisplayHeaderDataV2
 *********************************/
@implementation UISealedMessageDisplayHeaderDataV2
@synthesize author;
@synthesize creationDate;
@synthesize isOwner;
@synthesize isRead;

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        author       = nil;
        creationDate = nil;
        isOwner      = NO;
        isRead       = NO;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [author release];
    author = nil;
    
    [creationDate release];
    creationDate = nil;
    
    [super dealloc];
}
@end

