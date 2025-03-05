//
//  UIMessageDetailViewControllerV2.m
//  ChatSeal
//
//  Created by Francis Grolemund on 9/23/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <MobileCoreServices/MobileCoreServices.h>
#import "UIMessageDetailViewControllerV2.h"
#import "UIMessageDetailToolView.h"
#import "ChatSeal.h"
#import "UIPhotoLibraryAccessViewController.h"
#import "UISealedMessageExportViewController.h"
#import "UIImage+ImageEffects.h"
#import "UINewSealViewController.h"
#import "UIImageGeneration.h"
#import "UISealedMessageDisplayViewV2.h"
#import "UIFakeKeyboardV2.h"
#import "AlertManager.h"
#import "UISecurePreviewViewController.h"
#import "ChatSealWeakOperation.h"
#import "UIChatSealNavigationController.h"
#import "UIChatSealNavigationInteractiveTransition.h"
#import "UIHubMessageDetailAnimationController.h"
#import "UISearchScroller.h"
#import "UIMessageOverviewViewController.h"
#import "UIHubViewController.h"
#import "UISealSelectionViewController.h"
#import "UIDynamicTypeCompliantEntity.h"
#import "UIMessageDetailFeedAddressView.h"
#import "UIFeedSelectionViewController.h"
#import "ChatSealFeedCollector.h"
#import "UINewEntryIndicatorView.h"
#import "UISealedMessageDisplayCellV2.h"

// - constants
static const CGFloat    UIMDV_MAX_EMBEDDED_SIDE            = 640.0f;        // (pixels)  I've chosen this based on the width of a Retina display in portrait mode.
static const CGFloat    UIMDV_MAX_EMBEDDED_AREA            = UIMDV_MAX_EMBEDDED_SIDE * UIMDV_MAX_EMBEDDED_SIDE;
static const CGFloat    UIMDV_STD_INDICATOR_PAD_CX         = 8.0f;
static const CGFloat    UIMDV_STD_INDICATOR_PAD_CY         = 8.0f;
static const CGFloat    UIMDV_STD_EXTRA_BEFORE_VISIBLE_CY  = 8.0f;

// - forward declarations
@interface UIMessageDetailViewControllerV2 (internal) <UIMessageDetailToolViewDelegate, UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIChatSealCustomNavTransitionDelegate, UIDynamicTypeCompliantEntity, UIMessageDetailFeedAddressViewDelegate, UINewEntryIndicatorViewDelegate>
-(void) doCancel;
-(UIMessageDetailToolView *) buildStandardToolsWithStandardHint;
-(CGFloat) viewMaximumYForEditor;
-(CGFloat) expectedToolsHeightForViewDimensions:(CGSize) viewDims;
-(void) resizeEditorWithDuration:(NSTimeInterval) duration andCurve:(UIViewAnimationCurve) curve andForceLayout:(BOOL) forceLayout;
-(CGFloat) editToolsMinYForRect:(CGRect) rcEditTools;
-(void) positionEditToolsForViewDimensions:(CGSize) viewDims andForceLayout:(BOOL) forceLayout;
-(void) prepareForModalDialogWithResignWait:(BOOL) waitResign andCompletion:(void(^)(void)) completionBlock;
-(void) prepareForModalDismissal;
-(void) completeSealSelectionAndExport:(BOOL) doExport;
-(void) setStandardHintTextForTools:(UIMessageDetailToolView *) tools;
-(void) scaleAndAddPhotoToMessage:(UIImage *) image;
-(void) doTakePicture;
-(void) doUseExistingPhoto;
-(void) showStandardPhotoSelection;
-(void) keyboardWillShow:(NSNotification *) notification;
-(void) keyboardWillHide:(NSNotification *) notification;
-(void) keyboardDidShow:(NSNotification *) notification;
-(void) keyboardDidHide:(NSNotification *) notification;
-(void) processMovingKeyboardNotification:(NSNotification *) notification toVisible:(BOOL) isVisible andResize:(BOOL) resize;
-(void) processFinishMovingKeyboardNotification;
-(void) exportMessageWithCurrentSeal;
-(void) setViewChangesForPreviewTransition:(BOOL) toPreview;
-(UIMessageOverviewViewController *) overviewViewController;
-(void) killFilterTimer;
-(void) notifyScreenshotTaken;
-(void) notifySealInvalidated:(NSNotification *) notification;
-(void) completeSealInvalidation;
-(void) setFeed:(ChatSealFeed *) feed withAnimation:(BOOL)animated;
-(void) doChangeAddress;
-(void) notifyFeedsModified;
-(void) updateMessageEntryCount;
-(BOOL) isDevicePortrait;
-(void) tryToDefaultTheFeed;
-(void) notifyMessageImported:(NSNotification *) notification;
-(void) completeMessageImportProcessing;
-(void) updateNewEntryIndicatorsWithAnimation:(BOOL) animated;
-(void) layoutBottomIndicator;
-(NSRange) rangeOfTrulyVisibleMessageContent;
-(void) becomeFirstResponderWithGlideProxySupport:(BOOL) useGlideProxy;
@end

// - shared declarations
@interface UIMessageDetailViewControllerV2 (shared)
-(void) completedExportAbortReturn;
-(void) recalibrateToolbarWithViewDimensions:(CGSize) viewDims;
-(void) updateKeyboardEffectImage;
-(void) prepareForSecurePreviewTransitionToThisView:(BOOL) toThisView;
-(void) addKeyframesForSecurePreviewTransitionToThisView:(BOOL) toThisView;
-(void) prepareForMessageDeliveryWithDimensions:(CGSize) viewDims;
-(void) displayRecentlyDeliveredLastEntry;
-(CGPoint) envelopeOrigin;
+(void) configureProxyTextView:(UITextView *) tv withText:(NSString *) text;
@end

// - message display declarations
@interface UIMessageDetailViewControllerV2 (messageDisplay) <UISealedMessageDisplayViewDataSourceV2>
-(ChatSealMessageEntry *) entryForIndex:(NSInteger) entry;
-(void) cancelDetailOperation;
-(void) scheduleDetailOperation:(NSBlockOperation *) op;
@end

//  - search declarations.
@interface UIMessageDetailViewControllerV2 (search) <UISearchScrollerDelegate>
-(void) resetCurrentSearchWithAnimation;
-(void) deferredFilter;
-(void) applyCurrentSearchFilterWithAnimation:(BOOL) animated;
@end

//  - for moving back to the overview.
@interface UIMessageOverviewViewController (detailTransition)
-(void) closeSearch;
-(void) showSearchIfNotVisible;
@end

//  - for moving back to the overview.
@interface UIMessageDetailViewControllerV2 (overviewTransition)
-(void) completedOverviewReturnTransition;
@end

/******************************
 UIMessageDetailViewController
 ******************************/
@implementation UIMessageDetailViewControllerV2
/*
 *  Object attributes.
 */
{
    NSString                                   *preferredSeal;
    ChatSealMessage                            *msgExisting;
    BOOL                                       forcedAppend;
    BOOL                                       isRotating;
    CGFloat                                    editorMaximumYValue;
    UIMessageDetailToolView                    *editTools;
    BOOL                                       wasEditing;
    BOOL                                       hasAppeared;
    BOOL                                       ignoreKeyboardNotifications;
    UITextView                                 *tvGlideProxy;
    UIView                                     *vwToolGlider;
    BOOL                                       shouldUseGlideProxyForKeyboard;
    UISealedMessageDisplayViewV2               *vwMessageDisplay;
    BOOL                                       requiresReturnMask;
    NSIndexPath                                *ipTapped;
    NSBlockOperation                           *boPrepareDetail;
    UIChatSealNavigationInteractiveTransition *interactiveController;
    UISearchScroller                           *ssSearchScroller;
    BOOL                                       searchBecomeFirst;
    NSString                                   *currentSearchCriteria;
    UIView                                     *vwKeyboardSnapshot;
    NSTimer                                    *tmFilter;
    BOOL                                       sealWasSelectedBeforeDelivery;
    BOOL                                       isSealInvalidated;
    UIMessageDetailFeedAddressView             *feedAddress;
    ChatSealFeed                               *activeFeed;
    NSUInteger                                 numberOfMessageEntries;
    BOOL                                       messageListUpdatePending;
    UINewEntryIndicatorView                    *topNewIndicator;
    UINewEntryIndicatorView                    *botNewIndicator;
    BOOL                                       isKeyboardVisible;
    BOOL                                       exportWhenKeyboardIsDisplayed;
}
@synthesize delegate;

/*
 *  Initialize the module.
 */
+(void) initialize
{
    // - make sure the placeholder exists.
    [UISealedMessageDisplayCellV2 genericFastScrollingPlaceholderImage];
}

/*
 *  Initialize the object.
 */
-(id) initWithSeal:(NSString *) sealId andExistingMessage:(ChatSealMessage *) msgData andForceAppend:(BOOL) append withSearchText:(NSString *) searchText
                                  andBecomeFirstResponder:(BOOL) becomeFirst
{
    self = [super init];
    if (self) {
        preferredSeal                             = [sealId retain];
        msgExisting                               = [msgData retain];
        [self updateMessageEntryCount];
        [msgExisting pinSecureContent:nil];                 //  this already happened before this view was displayed so this will simply prevent a premature release.
        isRotating                                = NO;
        wasEditing                                = NO;
        hasAppeared                               = NO;
        editorMaximumYValue                       = -1.0f;
        editTools                                 = nil;
        ignoreKeyboardNotifications               = NO;
        requiresReturnMask                        = NO;
        forcedAppend                              = append;
        ipTapped                                  = nil;
        boPrepareDetail                           = nil;
        interactiveController                     = nil;
        vwKeyboardSnapshot                        = nil;
        tmFilter                                  = nil;
        searchBecomeFirst                         = append ? NO : becomeFirst;
        currentSearchCriteria                     = [searchText retain];
        sealWasSelectedBeforeDelivery             = NO;
        self.automaticallyAdjustsScrollViewInsets = NO;
        isSealInvalidated                         = NO;
        feedAddress                               = nil;
        activeFeed                                = nil;
        messageListUpdatePending                  = NO;
        topNewIndicator                           = nil;
        botNewIndicator                           = nil;
        isKeyboardVisible                         = NO;
        shouldUseGlideProxyForKeyboard            = NO;
        exportWhenKeyboardIsDisplayed             = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidHide:) name:UIKeyboardDidHideNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyScreenshotTaken) name:UIApplicationUserDidTakeScreenshotNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifySealInvalidated:) name:kChatSealNotifySealInvalidated object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyFeedsModified) name:kChatSealNotifyFeedTypesUpdated object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyMessageImported:) name:kChatSealNotifyMessageImported object:nil];
    }
    return self;
}

/*
 *  Initialize the object.
 */
-(id) initWithSeal:(NSString *) sealId
{
    return [self initWithSeal:sealId andExistingMessage:nil andForceAppend:NO withSearchText:nil andBecomeFirstResponder:NO];
}

/*
 *  Initialize the object.
 */
-(id) initWithExistingMessage:(ChatSealMessage *) msgData andForceAppend:(BOOL) append
{
    return [self initWithSeal:nil andExistingMessage:msgData andForceAppend:append withSearchText:nil andBecomeFirstResponder:NO];
}

/*
 *  Initialize the object.
 */
-(id) initWithExistingMessage:(ChatSealMessage *) msgData andForceAppend:(BOOL) append withSearchText:(NSString *) searchText andBecomeFirstResponder:(BOOL) becomeFirst
{
    return [self initWithSeal:nil andExistingMessage:msgData andForceAppend:append withSearchText:searchText andBecomeFirstResponder:becomeFirst];
}

/*
 *  Destroy the object.
 */
-(void) dealloc
{
    [self killFilterTimer];
    [self cancelDetailOperation];
    [UIFakeKeyboardV2 setKeyboardMaskingEnabled:NO];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    delegate = nil;
    
    [preferredSeal release];
    preferredSeal = nil;
    
    [msgExisting unpinSecureContent];
    [msgExisting release];
    msgExisting = nil;
    
    [editTools release];
    editTools = nil;
    
    [tvGlideProxy release];
    tvGlideProxy = nil;
    
    [vwToolGlider release];
    vwToolGlider = nil;
    
    [vwMessageDisplay release];
    vwMessageDisplay = nil;
    
    [ipTapped release];
    ipTapped = nil;
    
    [interactiveController release];
    interactiveController = nil;
    
    [ssSearchScroller release];
    ssSearchScroller = nil;
    
    [currentSearchCriteria release];
    currentSearchCriteria = nil;
    
    [vwKeyboardSnapshot release];
    vwKeyboardSnapshot = nil;
    
    [feedAddress release];
    feedAddress = nil;
    
    [activeFeed release];
    activeFeed = nil;
    
    topNewIndicator.delegate = nil;
    [topNewIndicator release];
    topNewIndicator = nil;
 
    botNewIndicator.delegate = nil;
    [botNewIndicator release];
    botNewIndicator = nil;
    
    [super dealloc];
}

/*
 *  Configure the view.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // - configure the navigation items.
    self.navigationItem.backBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Message", nil) style:UIBarButtonItemStylePlain target:nil action:nil] autorelease];
    if (!msgExisting || forcedAppend) {
        UIBarButtonItem *bbiRight = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(doCancel)];
        self.navigationItem.rightBarButtonItem = bbiRight;
        [bbiRight release];
    }
    
    // - and the title
    if (msgExisting) {
        NSString *author = [ChatSeal ownerNameForSeal:msgExisting.sealId];
        if (!author) {
            author = [ChatSeal ownerForAnonymousForMe:[msgExisting isAuthorMe]];
        }
        self.title = author;
    }
    else {
        self.title = NSLocalizedString(@"New Message", nil);
    }
    
    // - instantiate a custom interactive controller so we can disable the gesture during
    //   transitions.
    interactiveController = [[UIChatSealNavigationInteractiveTransition alloc] initWithViewController:self];
    [interactiveController setAllowTransitionToStart:NO];
    
    // - the search scroller always exists because it needs to minimally hold the address bar for feeds.
    ssSearchScroller = [[UISearchScroller alloc] initWithFrame:self.view.bounds];
    ssSearchScroller.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [ssSearchScroller setNavigationController:self.navigationController];
    [ssSearchScroller setRefreshEnabled:NO];
    [ssSearchScroller setSearchShadeExtraLightStyle:YES];
    ssSearchScroller.delegate = self;
    [self.view addSubview:ssSearchScroller];
    
    // - the feed address bar displays where the message is headed.
    feedAddress          = [[UIMessageDetailFeedAddressView alloc] init];
    feedAddress.delegate = self;
    [feedAddress sizeToFit];
    [ssSearchScroller setSearchToolsView:feedAddress];
    
    // - message display is only useful when we actually have a message.
    if (msgExisting) {
        // - create the message display view
        vwMessageDisplay = [[UISealedMessageDisplayViewV2 alloc] init];
        [vwMessageDisplay setMaximumNumberOfItemsPerEntry:3];               //  there can be at most a block of text, followed by an image, followed by another block of text.
        vwMessageDisplay.backgroundColor = [UIColor whiteColor];
        vwMessageDisplay.dataSource = self;
        
        // - and a view to allow for searching.
        [ssSearchScroller setScrollEnabled:YES];
        [ssSearchScroller setPrimaryContentView:vwMessageDisplay];
        if (currentSearchCriteria) {
            if (searchBecomeFirst) {
                requiresReturnMask          = YES;
                ignoreKeyboardNotifications = YES;
                editorMaximumYValue         = CGRectGetHeight(self.view.bounds) - [UIFakeKeyboardV2 keyboardSize].height;
            }
            [ssSearchScroller setActiveSearchText:currentSearchCriteria withAnimation:NO andBecomeFirstResponder:searchBecomeFirst];
            [vwMessageDisplay setSearchText:currentSearchCriteria];
        }
    }
    else {
        [ssSearchScroller setScrollEnabled:NO];
    }
    
    //  - the edit tools include two buttons and the editor itself.
    editTools = [[self buildStandardToolsWithStandardHint] retain];
    [self.view addSubview:editTools];
    
    // - make a consistent background color
    self.view.backgroundColor = [ChatSeal defaultEditorBackgroundColor];
    
    // - these controls are used to facilitate really smooth animation when
    //   presenting the keyboard during a transition because the durations
    //   are not accurate then.
    tvGlideProxy                      = [[UITextView alloc] initWithFrame:CGRectMake(-500.0f, -500.0f, 0.0f, 0.0f)];
    tvGlideProxy.scrollsToTop         = NO;
    tvGlideProxy.backgroundColor      = [UIColor yellowColor];
    vwToolGlider                      = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 0.0f, 0.0f)];
    vwToolGlider.backgroundColor      = [UIColor clearColor];
    tvGlideProxy.inputAccessoryView   = vwToolGlider;
    [self.view addSubview:tvGlideProxy];
    
    // - when no message was sent in, the tools should become first responder.
    if (!msgExisting || forcedAppend) {
        CGSize szBounds                = self.view.bounds.size;
        if ([ChatSeal isIOSVersionBEFORE8]) {
            // - when we start in landscape, it isn't rotated yet, but it needs to be right for the
            //   edit tools sizing to be correct.
            if (UIInterfaceOrientationIsLandscape([self backwardsCompatibleInterfaceOrientation])) {
                szBounds = CGSizeMake(szBounds.height, szBounds.width);
            }
        }
        CGSize sz                      = [editTools sizeThatFits:CGSizeMake(szBounds.width, 1.0f)];
        [UIView performWithoutAnimation:^(void) {
            [editTools setFrame:CGRectMake(0.0f, szBounds.height - sz.height, sz.width, sz.height) withImmediateLayout:YES];
        }];
        
        // - this is generally a modal scenario, so we need the glide proxy
        [self becomeFirstResponderWithGlideProxySupport:YES];
    }
    
    // - assign the active feed
    [self setFeed:nil withAnimation:NO];
    
    // - message display is colorized based on the seal in use.
    [vwMessageDisplay setOwnerSealForStyling:preferredSeal ? preferredSeal : [msgExisting sealId]];
}

/*
 *  Track when rotations are occurring.
 */
-(void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    isRotating = YES;
}

/*
 *  Update the location of the editor and overlay when rotations occur.
 */
-(void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    // - make sure the search scroller is adjusted.
    [ssSearchScroller willAnimateRotation];

    // - this exists for the times when the keyboard is not visible and the tools need to be adjusted for a different orientation.
    editorMaximumYValue = CGRectGetHeight(self.view.bounds);
    [editTools prepareForRotation];
    [self resizeEditorWithDuration:duration andCurve:UIViewAnimationCurveEaseOut andForceLayout:NO];
}

/*
 * Track when rotations are occurring.
 */
-(void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    isRotating = NO;
}

/*
 *  Layout will occur, so position the sub-views.
 */
-(void) viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    // - only do this once or we'll lose the correct value.
    if (editorMaximumYValue < 0.0f) {
        editorMaximumYValue = [self viewMaximumYForEditor];
    }
    
    // - make sure the tools are correctly positioned, which is really
    //   not relevant when the keyboard is visible, but is important when it isn't.
    // - if this happens during a rotation, it will generate snapshot warnings when
    //   the message detail's content insets are adjusted.  The snapshot warnings are happening as a
    //   byproduct of something in UIKit that isn't ready yet in the display's collection view.  Fortunately, the
    //   willAnimate method is going to position the tools in a moment, so this is an extraneous call
    //   anyway.
    if (!isRotating) {
        [self positionEditToolsForViewDimensions:self.view.bounds.size andForceLayout:NO];
    }
}

/*
 *  Layout has occurred.
 */
-(void) viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    if (!hasAppeared) {
        // - ensure that the last item is displayed in the message.+
        if (msgExisting) {
            // - make sure layout proceeds the scroll-to request because otherwise the
            //   content offset is going to be reset with the frame resize that follows later.
            [ssSearchScroller setNeedsLayout];
            [ssSearchScroller layoutIfNeeded];
            
            // - scroll to either the first new entry or the last item, whichever comes
            //   first.
            // - it is possible that if we receive an entry out of order, as a response, we might
            //   see the new entry earlier than the end of the thread.
            if (numberOfMessageEntries > 0) {
                NSUInteger scrollToItem   = (NSUInteger) numberOfMessageEntries-1;
                ChatSealMessageEntry *me = nil;
                if (![msgExisting isRead]) {
                    for (NSUInteger i = 0; i < numberOfMessageEntries; i++) {
                        me = [msgExisting entryForIndex:i withError:nil];
                        if (me && ![me isRead]) {
                            scrollToItem = i;
                            break;
                        }
                    }
                }
                
                me = [msgExisting entryForIndex:scrollToItem withError:nil];
                if (me) {
                    NSUInteger numItems = [me numItems];
                    if (numItems) {
                        [vwMessageDisplay scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:(NSInteger) numItems-1 inEntry:(NSInteger) scrollToItem]
                                                 atScrollPosition:UITableViewScrollPositionNone animated:NO];
                    }
                }
            }
        }
    }
}

/*
 *  In order to avoid a retain loop, cancel the pending operation before disappearing.
 */
-(void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self cancelDetailOperation];
    
    // - under iOS8, the keyboard isn't dismissed until after returning from the view controller, but
    //   we want to manage that ourselves.
    // - this only happens during a new mesage creation experience
    if ([ChatSeal isIOSVersionGREQUAL8] && !self.presentedViewController) {
        ignoreKeyboardNotifications = YES;
        [editTools resignFirstResponder];
        [tvGlideProxy resignFirstResponder];
    }
}

/*
 *  When the view has disappeared, don't use the interactive controller any longer.
 */
-(void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self killFilterTimer];
    [interactiveController setAllowTransitionToStart:NO];
}

/*
 *  Track first appearance to know when to begin processing delegate notifications.
 */
-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    ignoreKeyboardNotifications = NO;       //  when returning from a transition, only watch the keyboard when it is complete.
    [interactiveController setAllowTransitionToStart:YES];

    if (!hasAppeared) {
        if ([ssSearchScroller isSearchForeground]) {
            [ssSearchScroller completeNavigation];            
        }
        [self tryToDefaultTheFeed];
        hasAppeared = YES;
        [self updateNewEntryIndicatorsWithAnimation:animated];
    }
    
    // - when the seal is invalidated, we need to close this view.
    if (isSealInvalidated) {
        [self performSelector:@selector(completeSealInvalidation) withObject:nil afterDelay:0.25f];
    }
}

/*
 *  Return an envelope object that represents the visual state of the message.
 */
-(UISealedMessageEnvelopeViewV2 *) envelopeForCurrentState
{
    return [self envelopeForCurrentStateWithTargetHeight:CGRectGetHeight(self.view.bounds)];
}

/*
 *  Return an envelope object that represents the visual state of the message.
 */
-(UISealedMessageEnvelopeViewV2 *) envelopeForCurrentStateWithTargetHeight:(CGFloat) targetViewHeight
{
    UISealedMessageEnvelopeViewV2 *envelope = [editTools envelopeForCurrentContentAndTargetHeight:targetViewHeight];
    CGRect                        rcEnv     = envelope.frame;
    rcEnv.origin                            = [self envelopeOrigin];
    envelope.frame                          = CGRectIntegral(rcEnv);
    return envelope;
}

@end


/*****************************************
 UIMessageDetailViewControllerV2 (internal)
 *****************************************/
@implementation UIMessageDetailViewControllerV2 (internal)
/*
 *  Manage the cancel operation.
 */
-(void) doCancel
{
    if (delegate && [delegate respondsToSelector:@selector(messageDetailShouldCancel:)]) {
        [delegate performSelector:@selector(messageDetailShouldCancel:) withObject:self];
    }
}

/*
 *  Build the toolbar.
 */
-(UIMessageDetailToolView *) buildStandardToolsWithStandardHint
{
    UIMessageDetailToolView *tvTmp = [[UIMessageDetailToolView alloc] init];
    tvTmp.delegate                 = self;
    [self setStandardHintTextForTools:tvTmp];
    return [tvTmp autorelease];
}

/*
 *  Return the maximum y location for the editor if there is no keyboard.
 */
-(CGFloat) viewMaximumYForEditor
{
    return CGRectGetHeight(self.view.bounds);
}

/*
 *  Compute the size of the tools based on how much space remains up
 *  to a maximum of the visible height of the window and how much
 *  space the scroll view requires.
 */
-(CGFloat) expectedToolsHeightForViewDimensions:(CGSize) viewDims
{
    CGFloat maximumHeightOfTools = editorMaximumYValue;
    
    //  - when the nav bar is translucent, we're going to stop short of
    //    moving under it
    if (self.navigationController.navigationBar.translucent) {
        if ([ssSearchScroller isSearchForeground]) {
            CGRect rcDisplay = [self.view convertRect:vwMessageDisplay.frame fromView:ssSearchScroller];
            maximumHeightOfTools -= CGRectGetMinY(rcDisplay);
        }
        else {
            maximumHeightOfTools -= CGRectGetMaxY(self.navigationController.navigationBar.frame);
        }
    }
    
    // - subtract the address bar if we're in portrait mode because there is more real-estate with which
    //   to display it.
    if ([self isDevicePortrait]) {
        maximumHeightOfTools -= CGRectGetHeight(feedAddress.frame);
    }
    
    // - compute the size of the tools based on the size of the content
    CGSize szContent = [editTools sizeThatFits:CGSizeMake(viewDims.width, 1.0f)];
    CGFloat height = szContent.height;
    if (height > maximumHeightOfTools) {
        height = maximumHeightOfTools;
    }
    return height;
}

/*
 *  Reposition the editor based on its dimensions and the current location of the keyboard.
 */
-(void) resizeEditorWithDuration:(NSTimeInterval) duration andCurve:(UIViewAnimationCurve) curve andForceLayout:(BOOL) forceLayout
{
    // - during rotatation, using the classic APIs will result in immediate changes to the frame of the view,
    //   completely ignoring the requested timing.   I found that animation blocks appear to do the right
    //   thing, however.  I'm still not entirely clear only why this is the case.
    if (isRotating) {
        [UIView animateWithDuration:duration delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^(void) {
            [self positionEditToolsForViewDimensions:self.view.bounds.size andForceLayout:NO];
        } completion:nil];
    }
    else {
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:duration];
        [UIView setAnimationCurve:curve];
        [UIView setAnimationBeginsFromCurrentState:YES];
        [self positionEditToolsForViewDimensions:self.view.bounds.size andForceLayout:YES];
        
        // - apparently calling these methods during the initial presentation of the keyboard will hose up the
        //   return transition back from a modal display.  Since it is really only useful to force layout changes during
        //   a content change, I think this should be fine to be selective.
        if (forceLayout) {
            [editTools setNeedsLayout];             //  force the editor to be in synch.
            [editTools layoutIfNeeded];
        }
        [UIView commitAnimations];
    }
}

/*
 *  Figure out the correct minimum Y value for edit tools of the given rectangle.
 */
-(CGFloat) editToolsMinYForRect:(CGRect) rcEditTools
{
    CGFloat ret = 0.0f;
    if (editTools.superview == vwToolGlider) {
        ret = editorMaximumYValue - CGRectGetHeight(rcEditTools);
    }
    else {
        ret = CGRectGetMinY(rcEditTools);
    }
    return ret;
}

/*
 *  Reposition the tools.
 *  - it is usually not a good idea to force layout changes because many things like rotations require a short
 *    duration.   Forcing a layout can be useful to get the right animation in very specialized scenarios, like during
 *    the tools resizing as content changes.   Use the flag sparingly.
 */
-(void) positionEditToolsForViewDimensions:(CGSize) viewDims andForceLayout:(BOOL)forceLayout
{
    //  - figure out how tall to make the tools and
    //    adjust them.
    CGFloat height  = [self expectedToolsHeightForViewDimensions:viewDims];
    CGRect rcEditTools = CGRectMake(0.0f, -height, viewDims.width, height);
    if (editTools.superview != vwToolGlider) {
        rcEditTools = CGRectOffset(rcEditTools, 0.0f, editorMaximumYValue);
    }
    
    // - compute where the edit tools will be on the screen so that we can set the correct content inset, but keep in mind they might be attached to the glide
    //   proxy.
    CGFloat editMinY = [self editToolsMinYForRect:rcEditTools];
    
    // ...because landscape mode really cuts into our visible content region, we merge the address into the tools if the text extends into the existing address bar.
    if ((editMinY + [editTools reservedHeightForAddress]) < CGRectGetMaxY(feedAddress.frame) && ![self isDevicePortrait]) {
        feedAddress.alpha    = 0.0f;
        BOOL isInAddressMode = [editTools addressDisplayEnabled];
        [editTools setDisplayAddressEnabled:YES];
        
        // - if we weren't yet in address mode, the expected height will be different now that we've turned it on
        if (!isInAddressMode) {
            height                  = [self expectedToolsHeightForViewDimensions:viewDims];
            rcEditTools.origin.y   -= (height - rcEditTools.size.height);
            rcEditTools.size.height = height;
            editMinY                = [self editToolsMinYForRect:rcEditTools];
            CGFloat editYPos = 0.0f;
            if (editTools.superview == vwToolGlider) {
                editYPos = -height;
            }
            else {
                editYPos = editMinY;
            }
            rcEditTools = CGRectMake(0.0f, editYPos, viewDims.width, height);
        }
    }
    else {
        feedAddress.alpha = 1.0f;
        [editTools setDisplayAddressEnabled:NO];
    }
    
    [editTools setFrame:rcEditTools withImmediateLayout:forceLayout];
    [vwMessageDisplay setContentInset:UIEdgeInsetsMake(CGRectGetHeight(feedAddress.frame), 0.0f, CGRectGetHeight(self.view.bounds) - editMinY, 0.0f)];
    [self layoutBottomIndicator];
    [self updateNewEntryIndicatorsWithAnimation:YES];
}

/*
 *  This call is made before a sub-dialog is shown.
 */
-(void) prepareForModalDialogWithResignWait:(BOOL) waitResign andCompletion:(void(^)(void)) completionBlock
{
    // - save first responder so that we can recover it when we return.
    wasEditing = [editTools isFirstResponder];
    
    // - there are times where the modal dialog is complex enough that it is best to wait until the keyboard retracts completely
    //   before we present it.   For example, the 'new seal' screen will hiccup during presentation if we don't wait.
    if (waitResign) {
        [CATransaction begin];
        [CATransaction setCompletionBlock:completionBlock];
        wasEditing = [editTools isFirstResponder];
        [editTools resignFirstResponder];
        [CATransaction commit];
    }
    else {
        [editTools resignFirstResponder];
        if (completionBlock) {
            completionBlock();
        }
    }
}

/*
 *  This call is made right before dismissing a sub-dialog.
 */
-(void) prepareForModalDismissal
{
    // - reclaim first responder status.
    if (wasEditing) {
        // - always a modal scenario, so use the proxy.
        [self becomeFirstResponderWithGlideProxySupport:YES];
    }
    wasEditing = NO;
}

/*
 *  Returns whether we have access to the camera.
 */
-(BOOL) hasCamera
{
    return [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
}

/*
 *  The user pressed the camera on the tool view.
 */
-(void) toolViewCameraPressed:(UIMessageDetailToolView *)toolView
{
    // - check for minimal photo access.
    BOOL camAvail = [self hasCamera];
    BOOL isOpen   = [UIPhotoLibraryAccessViewController photoLibraryIsOpen] || ![UIPhotoLibraryAccessViewController photoLibraryAccessHasBeenRequested];
    if (!camAvail && !isOpen) {
        UIAlertView *av = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Photos Restricted", nil) message:NSLocalizedString(@"You can add a photo after you modify Settings to allow ChatSeal to use the camera or Photo Library.", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil] autorelease];
        [av show];
        return;
    }

    // - figure out what to display.
    if (camAvail && isOpen) {
        UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:nil delegate:self
                                               cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                          destructiveButtonTitle:nil
                                               otherButtonTitles:NSLocalizedString(@"Take Photo", nil), NSLocalizedString(@"Choose Existing", nil), nil];
        [as showInView:self.view];
        [as release];
    }
    else if (camAvail) {
        // - only camera, so nothing to ask.
        [self doTakePicture];
    }
    else {
        // - only photo library, so nothing to ask
        [self doUseExistingPhoto];
    }
}

/*
 *  Manage the photo selection action sheet.
 */
-(void) actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if ([self hasCamera]) {
        if (buttonIndex == 0) {
            [self doTakePicture];
        }
        else if (buttonIndex == 1) {
            [self doUseExistingPhoto];
        }
    }
    else {
        if (buttonIndex == 0) {
            [self doUseExistingPhoto];
        }
    }
}

/*
 *  After displaying the new seal/selection dialogs, we will clean up with the same approach in each.
 */
-(void) completeSealSelectionAndExport:(BOOL) doExport
{
    // - in order to get a great transition, we need to export after the keyboard is shown completely again.
    if (doExport && wasEditing && isKeyboardVisible) {
        exportWhenKeyboardIsDisplayed = YES;
        doExport                      = NO;
    }
    
    [self prepareForModalDismissal];
    [self dismissViewControllerAnimated:YES completion:^(void) {
        if (doExport) {
            // - export after dismissal is complete so that the nav controller is
            //   consistent.
            [self performSelectorOnMainThread:@selector(exportMessageWithCurrentSeal) withObject:nil waitUntilDone:NO];
        }
    }];
}

/*
 *  The user pressed the 'Seal It!' button.
 */
-(void) toolViewSealItPressed:(UIMessageDetailToolView *)toolView
{
    // - don't allow the seal-it to be pressed while we're mid-transition.
    if (exportWhenKeyboardIsDisplayed) {
        return;
    }
    
    // - determine if a seal exists for processing.
    BOOL hasAnActiveSeal = NO;
    if ((msgExisting && [msgExisting sealId]) || preferredSeal) {
        hasAnActiveSeal = YES;
    }
    else {
        if ([ChatSeal hasVault]) {
            // - I thought about the possibility that the user defaults are incomplete somehow, but
            //   since we allow the person to have multiple seals, the worst thing that can occur here
            //   is they create a new seal.  I don't prefer that outcome if the defaults aren't up to date,
            //   but the alternative is to try to pick from the exsiting list of seals and that seems less than
            //   ideal since the choice of which seal is used is going to determine who can read the message.
            if ([ChatSeal activeSealWithValidation:YES]) {
                hasAnActiveSeal = YES;
            }
        }
    }

    // - if there is a seal ready, use that, otherwise, we'll have to create/select one.
    if (hasAnActiveSeal) {
        [self exportMessageWithCurrentSeal];
    }
    else {
        // - there is no active seal.  If we have others, we can select one, otherwise, we'll
        //   need to create a new seal first.
        NSError *err           = nil;
        BOOL selectionPossible = [UISealSelectionViewController selectionIsPossibleWithError:&err];
        [self prepareForModalDialogWithResignWait:!selectionPossible andCompletion:^(void){
            UIViewController *vc  = nil;
            if (selectionPossible) {
                vc = [UISealSelectionViewController viewControllerWithSelectionCompletionBlock:^(BOOL hasActiveSeal) {
                    if (hasActiveSeal) {
                        sealWasSelectedBeforeDelivery = YES;
                    }
                    [self completeSealSelectionAndExport:hasActiveSeal];
                }];
            }
            else {
                // - when an error occurs while trying to determine if selection is possible, we'll
                //   report it.
                if (err) {
                    NSLog(@"CS:  Failed to detect seal selection state.  %@", [err localizedDescription]);
                    [AlertManager displayFatalAlertWithLowSpaceDetectionUsingTitle:NSLocalizedString(@"New Message Interrupted", nil)
                                                                           andText:NSLocalizedString(@"Your %@ was unable to open your seal vault.", nil)];
                    return;
                }
                
                // - no error, so just create a seal and be done.
                vc = [UINewSealViewController viewControllerWithCreationCompletionBlock:^(BOOL isCancelled, NSString *sealId) {
                    [self completeSealSelectionAndExport:(!isCancelled && sealId) ? YES : NO];
                }];
            }
            [self presentViewController:vc animated:YES completion:nil];
        }];
    }
}

/*
 *  When the editor needs a size adjustment, this method will be called.
 */
-(void) toolViewContentSizeChanged:(UIMessageDetailToolView *) toolView
{
    if (!hasAppeared || isRotating) {
        return;
    }
    [self resizeEditorWithDuration:[UIMessageDetailToolView recommendedSizeAnimationDuration] andCurve:UIViewAnimationCurveEaseOut andForceLayout:YES];
}

/*
 *  Assign a hint to the tools.
 */
-(void) setStandardHintTextForTools:(UIMessageDetailToolView *) tools
{
    if (msgExisting) {
        if (![msgExisting isAuthorMe]) {
            [tools setHintText:NSLocalizedString(@"A Personal Reply", nil)];
        }
    }
    else {
        [tools setHintText:NSLocalizedString(@"A Personal Message", nil)];
    }
}

/*
 *  This notification is fired whenever the size of dynamic type changes.
 */
-(void) updateDynamicTypeNotificationReceived
{
    [editTools updateDynamicTypeNotificationReceived];
    [vwMessageDisplay updateDynamicTypeNotificationReceived];
    [ssSearchScroller updateDynamicTypeNotificationReceived];
    [feedAddress updateDynamicTypeNotificationReceived];
}

/*
 *  Whenever a photo needs to be added to the message, send it through here to 
 *  ensure that it respects the maximums for message inclusion.
 */
-(void) scaleAndAddPhotoToMessage:(UIImage *) image
{
    if (!image) {
        NSLog(@"CS:  No photo provided to message insertion method.");
        return;
    }
    
    // - I experimented with using the JPEG compression quality to determine a reasonable scale,
    //   but the fact that the image is scrambled, I'm not sure we can infer anything about the compression, so
    //   the dimensions seem a bit better of a metric since they will produce fairly consistent results
    //   more often than an estimate based on the colors of the image at the moment.
    // - the maximum data is computed based on an area algorithm (number-of-pixels X storage-per-pixel), so I'm going
    //   to try to maximize the image quality, even for odd-shaped images, by working off a maximum area.
    CGFloat curArea = image.size.width * image.size.height * image.scale;
    if (curArea > UIMDV_MAX_EMBEDDED_AREA) {
        CGFloat aveSide = sqrtf((float) curArea);
        image           = [UIImageGeneration image:image scaledTo:UIMDV_MAX_EMBEDDED_SIDE/aveSide asOpaque:YES];
    }
    [editTools insertPhotoInMessage:image];
}

/*
 *  When the user requests to take a picture with the camera, this method is called.
 */
-(void) doTakePicture
{
    // - the camera view controller always shows the status bar, even over the controls, which
    //   doesn't make sense.
    [self prepareForModalDialogWithResignWait:NO andCompletion:^(void) {
        // - only display the image picker after we've lost focus completely.
        UIImagePickerController *ipc = [[UIImagePickerController alloc] init];
        ipc.sourceType               = UIImagePickerControllerSourceTypeCamera;
        ipc.mediaTypes               = [NSArray arrayWithObject:(NSString *) kUTTypeImage];
        ipc.allowsEditing            = NO;
        ipc.showsCameraControls      = YES;
        ipc.delegate                 = self;
        
        [self presentViewController:ipc animated:YES completion:^(void) {
            [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
        }];
    }];
}

/*
 *  A photo was taken/chosen.
 */
-(void) imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    // - get the image they took/chose.
    UIImage *img = [info objectForKey:UIImagePickerControllerEditedImage];
    if (!img) {
        img = [info objectForKey:UIImagePickerControllerOriginalImage];
    }
    
    // - when we pick a photo but were not editing and there is no real content in the editor view yet, then
    //   we'll pretend that we need to become first responder first.
    NSArray *arr = [editTools currentMessageContents];
    if (!wasEditing) {
        if ([arr count] == 1) {
            NSObject *obj = [arr lastObject];
            if ([obj isKindOfClass:[NSString class]] && [(NSString *) obj length] == 0) {
                wasEditing = YES;
            }
        }
    }
    
    // - get the tool view back into editing position.
    [self prepareForModalDismissal];
    
    // - and dismiss this controller.
    [self dismissViewControllerAnimated:YES completion:^(void) {
        // - particularly under iOS7.1, if this image is added too quickly, we'll find that the re-presentation of
        //   the keyboard will introduce an unfortunate animation during this image insertion process.
        [self performSelector:@selector(scaleAndAddPhotoToMessage:) withObject:img afterDelay:0.15f];
    }];
    
    // - make sure the status bar comes back.
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
}

/*
 *  No photo selected.
 */
-(void) imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [CATransaction begin];
    [CATransaction setCompletionBlock:^(void) {
        [self prepareForModalDismissal];
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
    [CATransaction commit];
}

/*
 *  When the user wants to use a photo from their library, this method is called.
 */
-(void) doUseExistingPhoto
{
    [self prepareForModalDialogWithResignWait:NO andCompletion:^(void) {
        //  - ony display what we need after we've lost focus completely.
        if ([UIPhotoLibraryAccessViewController photoLibraryIsOpen]) {
            [self showStandardPhotoSelection];
        }
        else if (![UIPhotoLibraryAccessViewController photoLibraryAccessHasBeenRequested]) {
            [UIPhotoLibraryAccessViewController requestPhotoLibraryAccessWithCompletion:^(BOOL isAuthorized) {
                if (isAuthorized) {
                    [self showStandardPhotoSelection];
                }
            }];
        }
        else{
            UIAlertView *av = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Photos Restricted", nil) message:NSLocalizedString(@"You can add a photo after you modify Settings to allow ChatSeal to use the Photo Library.", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil] autorelease];
            [av show];
        }
    }];
}

/*
 *  Display the image picker with the attributes we require here.
 */
-(void) showStandardPhotoSelection
{
    UIImagePickerController *ipc = [[UIImagePickerController alloc] init];
    ipc.allowsEditing            = NO;
    ipc.sourceType               = UIImagePickerControllerSourceTypePhotoLibrary;
    ipc.delegate                 = self;
    [self presentViewController:ipc animated:YES completion:nil];
}

/*
 *  The keyboard will be displayed.
 */
-(void) keyboardWillShow:(NSNotification *) notification
{
    [self processMovingKeyboardNotification:notification toVisible:YES andResize:YES];
}

/*
 *  The keyboard will hide.
 */
-(void) keyboardWillHide:(NSNotification *) notification
{
    [self processMovingKeyboardNotification:notification toVisible:NO andResize:!isRotating];
}

/*
 *  When the keyboard is displayed, hide the fake one if it exists.
 */
-(void) keyboardDidShow:(NSNotification *) notification
{
    // - finish up the movement.
    [self processFinishMovingKeyboardNotification];
    
    // - make sure the mask is removed once the keyboard is shown upon return.
    if (requiresReturnMask && (hasAppeared || [ChatSeal isIOSVersionBEFORE8])) {
        if (!ignoreKeyboardNotifications || currentSearchCriteria) {
            [UIFakeKeyboardV2 setKeyboardMaskingEnabled:NO];
        }
        requiresReturnMask = NO;
    }
    
    // - make sure that the fake keyboard snapshot is discarded if it exists.
    [self completedOverviewReturnTransition];
    
    // - if we need to drive an export now, do so.
    if (exportWhenKeyboardIsDisplayed && !self.presentedViewController) {
        exportWhenKeyboardIsDisplayed = NO;
        [self exportMessageWithCurrentSeal];
    }
}

/*
 *  Finish the keyboard movement.
 */
-(void) keyboardDidHide:(NSNotification *) notification
{
    [self processFinishMovingKeyboardNotification];
}

/*
 *  Process a keyboard notification where the keyboard is showing/hiding itself.
 */
-(void) processMovingKeyboardNotification:(NSNotification *) notification toVisible:(BOOL) isVisible andResize:(BOOL) resize
{
    // - always keep track of the overall visibility.
    isKeyboardVisible = isVisible;
    
    // - during the transition to/from the export view, we need to ensure that the keyboard notification doesn't cause the
    //   content to be resized in the middle of the animation.  This flag will control that experience.
    if (ignoreKeyboardNotifications) {
        return;
    }
    
    if (notification.userInfo) {
        NSNumber *nCurve = [notification.userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey];
        NSNumber *nDur   = [notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
        
        editorMaximumYValue = [self viewMaximumYForEditor];
        if (isVisible) {
            CGRect rcKBFrame = [ChatSeal keyboardRectangleFromNotification:notification usingKey:UIKeyboardFrameEndUserInfoKey forView:self.view];
            editorMaximumYValue -= CGRectGetHeight(rcKBFrame);
        }
        else if (vwKeyboardSnapshot) {
            editorMaximumYValue = CGRectGetMinY(vwKeyboardSnapshot.frame);
        }
        
        // - we don't always resize to avoid competing animations.
        if (resize) {
            // - if the tools are already where they need to be, don't do anything because we'll get extra notifications when we flip first responders.
            if ((int) editorMaximumYValue == CGRectGetMaxY(editTools.frame)) {
                return;
            }

            // - the glide proxy is a trick to allow tools to animate smoothly with the keyboard when it is being presented immediately when
            //   the screen is displayed or when a sub-dialog is dismissed.  In those scenarios the animation will be off if we use the
            //   notification parameters directly.
            if (shouldUseGlideProxyForKeyboard && editTools.superview != vwToolGlider) {
                ignoreKeyboardNotifications = YES;
                [vwToolGlider addSubview:editTools];
                [UIView performWithoutAnimation:^(void) {
                    editTools.frame = CGRectMake(0.0f, -CGRectGetHeight(editTools.frame), CGRectGetWidth(self.view.bounds), CGRectGetHeight(editTools.frame));
                }];
                ignoreKeyboardNotifications = NO;
                NSString *activeText = [editTools textForActiveItem];
                [UIMessageDetailViewControllerV2 configureProxyTextView:tvGlideProxy withText:activeText];
                [tvGlideProxy becomeFirstResponder];
            }
            
            // - always size the edit tools.
            [self resizeEditorWithDuration:nDur.floatValue andCurve:nCurve.integerValue andForceLayout:NO];
        }
    }
}



/*
 *  When the keyboard has stopped moving, do what we need to do to get the edit tools back in place.
 */
-(void) processFinishMovingKeyboardNotification
{
    // - don't process this.
    if (ignoreKeyboardNotifications || editTools.superview != vwToolGlider) {
        return;
    }
    
    // - when the glide proxy is first responder, we need to detach the edit tools
    //   and make them first responder.
    // - in order to convert from the proxy to the tools, we need to fill in the space behind the tools that are attached to the keyboard, which hasn't had a chance
    //   to be drawn yet if this is the first presentation of the view
    UIView *vwSnap = [editTools snapshotViewAfterScreenUpdates:NO];
    [self.view addSubview:vwSnap];
    vwSnap.frame             = CGRectMake(0.0f, editorMaximumYValue - CGRectGetHeight(vwSnap.bounds), CGRectGetWidth(vwSnap.bounds), CGRectGetHeight(vwSnap.bounds));
    
    // - if we just switch now, there will be a flicker because the display hasn't been updated, wait one run loop cycle for that to occur.
    [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode beforeDate: [NSDate date]];
    
    // - now swap the first responder and remove the snapshot.
    [self.view addSubview:editTools];
    [self positionEditToolsForViewDimensions:self.view.bounds.size andForceLayout:NO];
    if ([tvGlideProxy isFirstResponder]) {
        [self becomeFirstResponderWithGlideProxySupport:NO];
    }
    [vwSnap removeFromSuperview];
    shouldUseGlideProxyForKeyboard = NO;
}

/*
 *  Send the active message to the export window.
 */
-(void) exportMessageWithCurrentSeal
{
    // - this should honestly never happen, but I need to be sure.
    if (!activeFeed) {
        return;
    }

    // - when sealing, it doesn't make sense to have search bars displayed, but
    //   we can't allow the normal reload process to run because it will race with
    //   the coming export
    if ([ssSearchScroller isSearchForeground]) {
        // ...because the search scroller plays with the nav bar, if we hide the nav bar, we need
        //    to transfer first responder status somewhere else or the custom transition will be
        //    interrupted in a bad way and lock up.
        if ([ssSearchScroller isFirstResponder]) {
            [self becomeFirstResponderWithGlideProxySupport:NO];
        }
        [self resetCurrentSearchWithAnimation];
        [ssSearchScroller closeAllSearchBarsWithAnimation:YES];
    }
    
    // - create the export dialog.
    UISealedMessageExportConfigData *config = [[[UISealedMessageExportConfigData alloc] init] autorelease];
    config.caller                           = self;
    config.items                            = [editTools currentMessageContents];
    config.targetFeed                       = activeFeed;
    config.delegate                         = delegate;
    config.preferredSealId                  = preferredSeal;
    config.message                          = msgExisting;
    config.messageType                      = PSMT_GENERIC;
    config.keyboardIsVisible                = [editTools isFirstResponder] || [tvGlideProxy isFirstResponder];
    if (config.keyboardIsVisible) {
        config.detailActiveItem             = [editTools textForActiveItem];        
    }
    
    // - when we just selected a seal, attempt to find a current message for it so that we don't
    //   create new ones needlessly.
    if (!msgExisting && sealWasSelectedBeforeDelivery) {
        ChatSealMessage *psm = [ChatSeal mostRecentMessageForSeal:[ChatSeal activeSeal]];
        config.message        = psm;
    }
    
    // - before moving over, update and present the fake keyboard to achieve
    //   a cleaner animation.
    if (config.keyboardIsVisible) {
        [self updateKeyboardEffectImage];
        [UIFakeKeyboardV2 forceAKeyboardSnapshotUpdate];            // to catch subtle changes to the keyboard like mode changes.
        [UIFakeKeyboardV2 setKeyboardMaskingEnabled:YES];
    }
    
    UISealedMessageExportViewController *vc = [UISealedMessageExportViewController instantateViewControllerWithConfiguration:config];
    ignoreKeyboardNotifications             = YES;      //  this must happen so that the animation doesn't get messed up, especially when there is a lot of text.
    [editTools resignFirstResponder];                   //  do it here or the nav controller will retain that state.
    [self.navigationController pushViewController:vc animated:YES];
}

/*
 *  Modify this view's content so that it reflects the proper state for a transition to/from the image preview screen.
 */
-(void) setViewChangesForPreviewTransition:(BOOL) toPreview
{
    if (toPreview) {
        if (!ipTapped) {
            return;
        }
        
        //  - all transforms on the display view are relative to that view's center, so we need to
        //  figure out how much to transform the image rectangle from that position to its center.
        CGRect rc = [vwMessageDisplay rectForItemAtIndexPath:ipTapped];
        if (CGRectGetWidth(rc) < 1.0f || CGRectGetHeight(rc) < 1.0f) {
            return;
        }
        
        // - now we're going to build a transform that can zoom into it.
        CGAffineTransform transform = CGAffineTransformIdentity;
        
        // ...adjust by the scroll offset first so that we retain the adjustment made by the scroll view.
        CGFloat scrollOffset        = CGRectGetMinY(vwMessageDisplay.frame) - ssSearchScroller.contentOffset.y;
        transform                   = CGAffineTransformTranslate(transform, 0.0f, -scrollOffset/2.0f);
        
        // ...get the basic dimensions of the screen
        CGSize szView   = self.view.bounds.size;
        
        // ...and zoom-in so that it fits the display.
        CGFloat scaleByX = szView.width / CGRectGetWidth(rc);
        CGFloat scaleByY = szView.height / CGRectGetHeight(rc);
        CGFloat toScale  = (scaleByX > scaleByY) ? scaleByY : scaleByX;
        transform = CGAffineTransformScale(transform, toScale, toScale);
        
        CGPoint displayCenter = CGPointMake((CGRectGetWidth(vwMessageDisplay.bounds)/2.0f),
                                            (CGRectGetHeight(vwMessageDisplay.bounds)/2.0f));
        
        // ...and center-in on that item, assuming the nav bar won't allow content under it.
        transform                  = CGAffineTransformTranslate(transform,
                                                                displayCenter.x - (CGRectGetMinX(rc) + (CGRectGetWidth(rc)/2.0f)),
                                                                displayCenter.y - (CGRectGetMinY(rc) + (CGRectGetHeight(rc)/2.0f)));
        
        // - adjust the z position also so that it overlays the search scroller tools.
        vwMessageDisplay.transform       = transform;
        vwMessageDisplay.layer.zPosition = 1000.0f;
        
        // - and hide the tools
        editTools.alpha = 0.0f;
    }
    else {
        // - remove the transform
        vwMessageDisplay.transform       = CGAffineTransformIdentity;
        vwMessageDisplay.layer.zPosition = 0.0f;
        
        // - show the tools
        editTools.alpha = 1.0f;
    }
}

/*
 *  Return the animation controller for custom transitions.
 */
-(id<UIChatSealNavItemAnimatedTransitioning>) navItemInController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC
{
    // - when moving back to the hub, we want a custom animation.
    if (operation == UINavigationControllerOperationPop && [toVC isKindOfClass:[UIHubViewController class]]) {
        return [[[UIHubMessageDetailAnimationController alloc] initWithInteractiveController:interactiveController] autorelease];
    }
    // - just perform the default animation.
    return nil;
}

/*
 *  Return the prior view controller if it was set.
 */
-(UIMessageOverviewViewController *) overviewViewController
{
    if (self.navigationController) {
        NSArray *arr = [self.navigationController viewControllers];
        if ([arr count] > 1) {
            UIViewController *vc = [arr objectAtIndex:0];
            if ([vc isKindOfClass:[UIHubViewController class]]) {
                vc = [(UIHubViewController *) vc currentViewController];
                if ([vc isKindOfClass:[UIMessageOverviewViewController class]]) {
                    return (UIMessageOverviewViewController *) vc;
                }
            }
        }
    }
    return nil;
}

/*
 *  We're about to go back to the overview.
 */
-(void) navigationWillPopThisViewController
{
    // - just make sure the async filter is discarded when moving back
    [self killFilterTimer];
    
    // - when we're not editing an existing message, or this is modal
    //   we aren't going to adjust the overview's search state.
    if (!msgExisting || delegate) {
        return;
    }
    
    //  - employ the fake keyboard so that we can get a clean return transition.
    if ([ssSearchScroller isFirstResponder] || [editTools isFirstResponder]) {
        [ssSearchScroller setDetectKeyboardResignation:NO];
        requiresReturnMask       = YES;
        [UIFakeKeyboardV2 setKeyboardMaskingEnabled:YES];
        vwKeyboardSnapshot       = [[UIFakeKeyboardV2 keyboardSnapshot] retain];
        vwKeyboardSnapshot.frame = CGRectOffset(vwKeyboardSnapshot.frame, 0.0f, CGRectGetHeight(self.view.bounds) - CGRectGetHeight(vwKeyboardSnapshot.bounds));
        [self.view addSubview:vwKeyboardSnapshot];

        // - before we came to this view, the keyboard was dismissed in the former view, so
        //   we can simply hide the fake keyboard now.
        [UIFakeKeyboardV2 setKeyboardVisible:NO];
    }

    // - apply the changes to search in the prior view.
    if ([ssSearchScroller isSearchForeground]) {
        [ssSearchScroller beginNavigation];
        [[self overviewViewController] showSearchIfNotVisible];
    }
    else {
        [[self overviewViewController] closeSearch];
    }
}

/*
 *  Make sure the filter timer doesn't fire any more.
 */
-(void) killFilterTimer
{
    [tmFilter invalidate];
    [tmFilter release];
    tmFilter = nil;
}

/*
 *  This notification is fired when a screenshot is taken.
 */
-(void) notifyScreenshotTaken
{
    // - when there is a modal view controller in front of this one, there is no
    //   need to protect the person.
    // - when this view is not active because the nav stack is pushed on top of it
    //   there is also no need for this guy to process it.
    if (self.presentedViewController || !self.view.superview) {
        return;
    }
    [ChatSeal checkForSealRevocationForScreenshotWhileReadingMessage:msgExisting];
}

/*
 *  When a seal is invalidated, we will get this notification and can check to see
 *  if it is the one we're currently looking at.
 */
-(void) notifySealInvalidated:(NSNotification *) notification
{
    // - no message?, then it must be ours.
    if (!msgExisting) {
        return;
    }
    
    // - check the identity and make sure that it isn't owned by us.
    ChatSealIdentity *ident = [msgExisting identityWithError:nil];
    if (!ident) {
        return;
    }
    
    // - now compare the seal ids and ignore if it isn't this seal.
    NSArray *arr = [notification.userInfo objectForKey:kChatSealNotifySealArrayKey];
    if (!arr || ![arr containsObject:ident.sealId]) {
        return;
    }
    
    isSealInvalidated = YES;
    
    // - if this view is visible, then close it right now.
    if (!self.presentedViewController && self.view.superview) {
        [self completeSealInvalidation];
    }
}

/*
 *  Seal invalidation requires that we pop this view controller and go back to the message list.
 */
-(void) completeSealInvalidation
{
    if (!msgExisting) {
        return;
    }
    [self.navigationController popViewControllerAnimated:YES];
    isSealInvalidated = NO;
}

/*
 *  When the tool view becomes first responder, we may want to retract the search tools
 *  because they don't make sense when they aren't prominent.
 */
-(void) toolViewBecameFirstResponder:(UIMessageDetailToolView *)toolView
{
    if (![ssSearchScroller isSearchForeground]) {
        [ssSearchScroller closeAllSearchBarsWithAnimation:YES];
    }
}

/*
 *  Assign the text for display feed addresses.
 */
-(void) setFeed:(ChatSealFeed *) feed withAnimation:(BOOL)animated
{
    if (feed != activeFeed) {
        [activeFeed release];
        activeFeed = [feed retain];
        
        NSString *sDisplay = [feed displayName];
        [feedAddress setFeedAddressText:sDisplay withAnimation:animated];
        [editTools setAddressText:sDisplay withAnimation:animated];
    }
    
    // - the ability to 'seal-it' is based on whether there is content and
    //   whether the address is assigned.
    [editTools setSealItButtonEnabled:feed ? YES : NO];
}

/*
 *  The feed address bar had its button pressed.
 */
-(void) feedAddressViewDidPressButton:(UIMessageDetailFeedAddressView *)addressView
{
    [self doChangeAddress];
}

/*
 *  The tool view had its address button pressed.
 */
-(void) toolViewAddressPressed:(UIMessageDetailToolView *) toolView
{
    [self doChangeAddress];
}

/*
 *  The address button was pressed.
 */
-(void) doChangeAddress
{
    UIViewController *vc = [UIFeedSelectionViewController viewControllerWithActiveFeed:activeFeed andSelectionCompletionBlock:^(ChatSealFeed *feed) {
        if (feed) {
            [self setFeed:feed withAnimation:NO];
        }
        [self prepareForModalDismissal];
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
    
    // - prepare for the modal dialog and then show it.
    [self prepareForModalDialogWithResignWait:NO andCompletion:^(void) {
        [self presentViewController:vc animated:YES completion:nil];
    }];
}

/*
 *  Detect feed updates so that we can update the address bar accordingly.
 */
-(void) notifyFeedsModified
{
    if (activeFeed && (![activeFeed isValid] || ![activeFeed isAuthorized])) {
        [self setFeed:nil withAnimation:YES];
    }
}

/*
 *  We only ever work from a cached message entry count because there is a scenario where upon return from the export
 *  view (after delivery) we get into a scenario where the collection requests the section count but doesn't update its list of cells, which
 *  I'm going to assume occurs because this view isn't yet visible.  In any case, that causes everything to be out of synch.  In order
 *  to avoid that goofy scenario, we're only ever recording the entry count at very precise times when this view is visible.
 */
-(void) updateMessageEntryCount
{
    NSError *err         = nil;
    NSInteger numEntries = [msgExisting numEntriesWithError:&err];
    if (numEntries >= 0) {
        numberOfMessageEntries = (NSUInteger) numEntries;
    }
    else {
        NSLog(@"CS:  Failed to retrieve message thread detail for message %@.  %@", [msgExisting messageId], [err localizedDescription]);
    }
}

/*
 *  When positioning the edit tools, we need to consider the current orientation of the device (not the view controller) in order
 *  to apply the right dimensions during restricted space scenarios (like landscape).
 */
-(BOOL) isDevicePortrait
{
    UIDeviceOrientation devIO = [UIDevice currentDevice].orientation;
    if (devIO == UIDeviceOrientationUnknown) {
        UIInterfaceOrientation io = [UIApplication sharedApplication].statusBarOrientation;
        return UIInterfaceOrientationIsPortrait(io);
    }
    else {
        return UIDeviceOrientationIsPortrait(devIO);
    }
}

/*
 *  When we first open this message, this our opportunity to assign the feed automatically in order to avoid needless choices when
 *  people are posting to their friends.   The less the better.
 */
-(void) tryToDefaultTheFeed
{
    NSString *feedId         = nil;
    ChatSealIdentity *ident = nil;
    if (msgExisting) {
        feedId = msgExisting.defaultFeedForMessage;
    }
    else {
        NSString *sid = preferredSeal ? preferredSeal : [ChatSeal activeSeal];
        if (sid) {
            ident  = [ChatSeal identityForSeal:sid withError:nil];
            feedId = ident.defaultFeed;
        }
    }
    
#if CHATSEAL_RUNNING_CONTRIVED_SCENARIO
    NSArray *arr = [[ChatSeal applicationFeedCollector] availableFeedsAsSortedList];
    if (arr.count) {
        ChatSealFeed *feed = [arr firstObject];
        feedId             = feed.feedId;
    }
#endif
    
    // - if we have a feed id, then attempt to load the default
    if (feedId) {
        ChatSealFeed *feed = [[ChatSeal applicationFeedCollector] feedForId:feedId];
        if (feed && [feed isViableMessagingTarget]) {
            [self setFeed:feed withAnimation:YES];
        }
        else {
            // - if we didn't find the feed, unset the defaults because they are no longer useful.
            [msgExisting setDefaultFeedForMessage:nil];
            [ident setDefaultFeed:nil];
        }
    }
    
}

/*
 *  When a message is imported, we need to make sure the message list gets updated.
 */
-(void) notifyMessageImported:(NSNotification *) notification
{
    if (msgExisting) {
        NSString *mid = [notification.userInfo objectForKey:kChatSealNotifyMessageImportedMessageKey];
        if (mid && [mid isEqualToString:msgExisting.messageId]) {
            messageListUpdatePending = YES;
            [self completeMessageImportProcessing];
        }        
    }
}

/*
 *  When we get a chance, after scrolling is completed, we must display any new messages that just arrived.
 */
-(void) completeMessageImportProcessing
{
    // - if we're still moving don't do this now because it will
    //   disrupt the display.
    if (!messageListUpdatePending || [vwMessageDisplay isScrollingOrDragging]) {
        return;
    }
    
    // - when there is search text, let's assume that the person wants to
    //   continue to see what they were looking at before.
    if (!currentSearchCriteria) {
        [self applyCurrentSearchFilterWithAnimation:YES];
    }
    messageListUpdatePending = NO;
}

/*
 *  The new entry indicators are shown whenever new message items exist and give an idea where those new things are
 *  and provide a quick-tap path to seeing that stuff.
 */
-(void) updateNewEntryIndicatorsWithAnimation:(BOOL) animated
{
    if (!msgExisting || !hasAppeared) {
        return;
    }
    
    // - figure out if there are any new items in this message.
    NSIndexSet *isNewItems = [msgExisting unreadItems];
    if (!isNewItems) {
        [topNewIndicator setIndicatorVisible:NO withAnimation:animated];
        [botNewIndicator setIndicatorVisible:NO withAnimation:animated];
        return;
    }
    
    // - there are new items, so we need to make sure that we set up the
    //   indicators efficiently.
    if (!topNewIndicator) {
        topNewIndicator       = [[UINewEntryIndicatorView alloc] initWithOrientationAsUp:YES];
        [topNewIndicator sizeToFit];
        topNewIndicator.frame = CGRectOffset(topNewIndicator.bounds,
                                             UIMDV_STD_INDICATOR_PAD_CX,
                                             UIMDV_STD_INDICATOR_PAD_CY + CGRectGetHeight(feedAddress.bounds));     // always in the same location.
        if (animated) {
            [topNewIndicator setIndicatorVisible:NO withAnimation:NO];
        }
        topNewIndicator.delegate = self;
        [vwMessageDisplay addSubview:topNewIndicator];
    }
    
    if (!botNewIndicator) {
        botNewIndicator = [[UINewEntryIndicatorView alloc] initWithOrientationAsUp:NO];
        [botNewIndicator sizeToFit];
        [self layoutBottomIndicator];
        if (animated) {
            [botNewIndicator setIndicatorVisible:NO withAnimation:NO];
        }
        botNewIndicator.delegate = self;
        [vwMessageDisplay addSubview:botNewIndicator];
    }
    
    // - figure out what we can see
    NSRange r              = [self rangeOfTrulyVisibleMessageContent];
    NSUInteger countBefore = 0;
    NSUInteger countAfter  = 0;
    if (r.location != NSNotFound) {
        if (r.location > 0) {
            countBefore = [isNewItems countOfIndexesInRange:NSMakeRange(0, r.location)];
        }
        NSInteger  numEntries  = [msgExisting numEntriesWithError:nil];
        NSUInteger lastVisible = r.location + r.length;
        if (lastVisible < numEntries) {
            countAfter = [isNewItems countOfIndexesInRange:NSMakeRange(lastVisible, (NSUInteger) numEntries - (NSUInteger) lastVisible)];
        }
    }
    
    BOOL topVisible = (!isKeyboardVisible && (countBefore > 0) ? YES : NO);
    BOOL botVisible = (!isKeyboardVisible && (countAfter > 0) ? YES : NO);
    
    // - update the indicators last.
    if (countBefore) {
        [topNewIndicator setNewEntryCount:countBefore withAnimation:animated];
    }
    if (countAfter) {
        [botNewIndicator setNewEntryCount:countAfter withAnimation:animated];
    }
    [topNewIndicator setIndicatorVisible:topVisible withAnimation:animated];
    [botNewIndicator setIndicatorVisible:botVisible withAnimation:animated];
}

/*
 *  Position the bottom indicator according to the requirements of the display.
 */
-(void) layoutBottomIndicator
{
    // - place the bottom indicator right above where the tools are.
    CGFloat toolsTopY     = CGRectGetMinY(editTools.frame);
    botNewIndicator.frame = CGRectMake(UIMDV_STD_INDICATOR_PAD_CX,
                                       toolsTopY - UIMDV_STD_INDICATOR_PAD_CY - CGRectGetHeight(botNewIndicator.bounds) - CGRectGetMinY(vwMessageDisplay.frame),
                                       CGRectGetWidth(botNewIndicator.bounds),
                                       CGRectGetHeight(botNewIndicator.bounds));
}

/*
 *  Return the range of visible items in the message display.
 */
-(NSRange) rangeOfTrulyVisibleMessageContent
{
    // - the problem with using just this value is that it doesn't take into account
    //   the fact that the tools may be obscuring some of it, which causes a problem if we're
    //   using this to decide on whether to show the new indicator.
    NSRange r = [vwMessageDisplay rangeOfVisibleContent];
    
    // - adjust this range so that it omits the items obscured by the tools.
    while (r.location != NSNotFound && r.length > 0) {
        NSUInteger lastIndex = r.location + r.length - 1;
        CGRect rcHdr         = [vwMessageDisplay headerRectForEntry:lastIndex];
        
        // - now convert over to this view.
        rcHdr                = [self.view convertRect:rcHdr fromView:vwMessageDisplay];
        rcHdr                = CGRectOffset(rcHdr, 0.0f, -vwMessageDisplay.contentOffset.y);
        if (CGRectGetMinY(rcHdr) + UIMDV_STD_EXTRA_BEFORE_VISIBLE_CY < CGRectGetMinY(editTools.frame)) {
            break;
        }
        
        r.length--;
        if (r.length == 0) {
            r.location = NSNotFound;
        }
    }
    
    // - return whatever is left over.
    return r;
}

/*
 *  When a new entry indicator is tapped, this method is issued.
 */
-(void) newEntryIndicatorWasTapped:(UINewEntryIndicatorView *)iv
{
    NSRange r              = [self rangeOfTrulyVisibleMessageContent];
    NSIndexSet *isNewItems = [msgExisting unreadItems];
    if (!isNewItems || r.location == NSNotFound) {
        return;
    }
    
    // - now we have the current visible range and the list of items in the index.
    if (iv == topNewIndicator) {
        NSUInteger prevBefore = [isNewItems indexLessThanIndex:r.location];
        if (prevBefore != NSNotFound) {
            [vwMessageDisplay scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:0 inEntry:(NSInteger) prevBefore]
                                     atScrollPosition:UITableViewScrollPositionTop animated:YES];
        }
    }
    else {
        NSUInteger nextAfter = [isNewItems indexGreaterThanOrEqualToIndex:r.location + r.length];
        if (nextAfter != NSNotFound) {
            [vwMessageDisplay scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:0 inEntry:(NSInteger) nextAfter]
                                     atScrollPosition:UITableViewScrollPositionBottom animated:YES];
        }
    }
}

/*
 *  The glide proxy is a trick that I use to get smooth animation in two very specific scenarios.
 *  - when presenting the keyboard during first display of this view
 *  - when re-presenting the keyboard after returning from a modal sub-dialog.
 */
-(void) becomeFirstResponderWithGlideProxySupport:(BOOL) useGlideProxy
{
    // - the glide proxy is necessary because in some cases the NSNotification parameters are not sufficient to describe
    //   the animation path.  It is usually when my animation starts during a modal transition.
    if (useGlideProxy) {
        shouldUseGlideProxyForKeyboard = YES;
    }
    [editTools becomeFirstResponder];
}
@end

/*****************************************
 UIMessageDetailViewControllerV2 (shared)
 *****************************************/
@implementation UIMessageDetailViewControllerV2 (shared)
/*
 *  Right before we return to this view from the sealed message export view, this method
 *  will be called to offer a chance to recover the keyboard cleanly.
 */
-(void) completedExportAbortReturn
{
    requiresReturnMask = YES;
    [UIFakeKeyboardV2 setKeyboardVisible:YES];
    [self becomeFirstResponderWithGlideProxySupport:NO];
}

/*
 *  This method is called before a return animation begins so that the edit tools are
 *  positioned where the keyboard will be.
 *  - use the provided view dimensions because this occurs when this view is not in the hierarchy any longer and
 *    responds to rotations.
 */
-(void) recalibrateToolbarWithViewDimensions:(CGSize) viewDims
{
    CGSize szKeyboard   = [UIFakeKeyboardV2 keyboardSize];
    CGFloat oldMaxY     = editorMaximumYValue;
    editorMaximumYValue = viewDims.height - szKeyboard.height;
    
    // - we need a complete re-layout of all the sub-views in order to ensure that the
    //   tools are positioned according to the requirements of the text.
    [UIView performWithoutAnimation:^(void){
        self.view.bounds = CGRectMake(0.0f, 0.0f, viewDims.width, viewDims.height);
        [self.view layoutIfNeeded];
        if ((int) oldMaxY != (int) editorMaximumYValue) {
            [self positionEditToolsForViewDimensions:viewDims andForceLayout:YES];
        }
    }];
}

/*
 *  Re-compute the keyboard's background frosted image.
 */
-(void) updateKeyboardEffectImage
{
    [UIFakeKeyboardV2 updateKeyboardEffectFromView:vwMessageDisplay];
}

/*
 *  Before we return to this view for a transition, make sure the transform is correct.
 */
-(void) prepareForSecurePreviewTransitionToThisView:(BOOL) toThisView
{
    if (!toThisView) {
        return;
    }
    [self setViewChangesForPreviewTransition:NO];
    editorMaximumYValue = CGRectGetHeight(self.view.bounds);
    [self positionEditToolsForViewDimensions:self.view.bounds.size andForceLayout:YES];
    [vwMessageDisplay layoutIfNeeded];
    [vwMessageDisplay scrollToItemAtIndexPath:ipTapped atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
    [self setViewChangesForPreviewTransition:YES];
}

/*
 *  Create the keyframes for moving to/from this view during a secure preview transition.
 */
-(void) addKeyframesForSecurePreviewTransitionToThisView:(BOOL) toThisView
{
    // - add keyframes to zoom into the image we're going to preview
    CGFloat duration = 0.75f;
    CGFloat start    = 0.0f;
    if (toThisView) {
        start = 0.25f;
    }
    else {
        start = 0.0f;
    }
    [UIView addKeyframeWithRelativeStartTime:start relativeDuration:duration animations:^(void) {
        [self setViewChangesForPreviewTransition:!toThisView];
    }];
}

/*
 *  Prepare to return without using a keyboard.
 */
-(void) prepareForMessageDeliveryWithDimensions:(CGSize) viewDims
{
    [editTools setMessageContents:nil];
    editorMaximumYValue = viewDims.height;
    
    // - we need a complete re-layout of all the sub-views in order to ensure that the
    //   tools are positioned according to the requirements of the text.
    [UIView performWithoutAnimation:^(void){
        self.view.bounds = CGRectMake(0.0f, 0.0f, viewDims.width, viewDims.height);
        [self.view layoutIfNeeded];
        [self positionEditToolsForViewDimensions:viewDims andForceLayout:YES];
    }];
}

/*
 *  After a message entry is delivered, we need to add it to the view and scroll it.
 */
-(void) displayRecentlyDeliveredLastEntry
{
    if (!msgExisting) {
        return;
    }
    
    [self updateMessageEntryCount];
    NSError *err              = nil;
    ChatSealMessageEntry *me = nil;
    if (numberOfMessageEntries < 1 || !(me = [msgExisting entryForIndex:(NSUInteger) numberOfMessageEntries-1 withError:&err])) {
        NSLog(@"CS:  Failed to retrieve the number of message entries.  %@", [err localizedDescription]);
        [AlertManager displayFatalAlertWithLowSpaceDetectionUsingTitle:NSLocalizedString(@"New Message Interrupted", nil)
                                                               andText:NSLocalizedString(@"Your %@ was unable to reopen your delivered message.", nil)];
        return;
    }
    
    [vwMessageDisplay appendMessage];
    [vwMessageDisplay scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:(NSInteger)[me numItems]-1 inSection:(NSInteger)numberOfMessageEntries-1]
                             atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

/*
 *  Return the origin of the envelope.
 */
-(CGPoint) envelopeOrigin
{
    CGPoint ptBaseOffset = [editTools baseEnvelopeOffset];
    ptBaseOffset.x      += CGRectGetMinX(editTools.frame);
    ptBaseOffset.y      += CGRectGetMinY(editTools.frame);

    ptBaseOffset.x      = (CGFloat) floor(ptBaseOffset.x);
    ptBaseOffset.y      = (CGFloat) floor(ptBaseOffset.y);
    return ptBaseOffset;
}

/*
 *  We use proxies in this view and in the export view to hold onto the keyboard, but they
 *  need to have similar text to what is being edited in order to not have their shift key and/or
 *  predictive content change between the two views.
 */
+(void) configureProxyTextView:(UITextView *) tv withText:(NSString *) text
{
    if (text.length) {
        text        = [@"X " stringByAppendingString:text];             // so the shift key remains the same.
        tv.text = text;                                                 // so the predictive text on the keyboard matches.
        [tv setSelectedRange:NSMakeRange(2, text.length - 2)];
    }
    else {
        tv.text = nil;
    }
}
@end

/************************************************
 UIMessageDetailViewControllerV2 (messageDisplay)
 ************************************************/
@implementation UIMessageDetailViewControllerV2 (messageDisplay)
/*
 *  Return the number of messages in the display.
 */
-(NSInteger) numberOfEntriesInDisplay:(UISealedMessageDisplayViewV2 *)messageDisplay
{
    return (NSInteger) numberOfMessageEntries;
}

/*
 *  This general-puropose routine returns a message entry if possible and handles
 *  errors consistently.
 */
-(ChatSealMessageEntry *) entryForIndex:(NSInteger) entry
{
    ChatSealMessageEntry *meRet = nil;
    if (msgExisting) {
        NSError *err = nil;
        meRet        = [msgExisting entryForIndex:(NSUInteger) entry withError:&err];
        if (!meRet) {
            NSLog(@"CS:  Failed to retrieve the message entry %@:%lu.  %@", [msgExisting messageId], (unsigned long) entry, [err localizedDescription]);
        }
    }
    return meRet;
}

/*
 *  Return the number of items in the given message.
 */
-(NSInteger) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *)messageDisplay numberOfItemsInEntry:(NSInteger)entry
{
    NSInteger ret = 0;
    if (msgExisting) {
        ChatSealMessageEntry *me = [self entryForIndex:entry];
        if (me) {
            ret = (NSInteger) [me numItems];
        }
    }
    return ret;
}

/*
 *  Determine the author of this entry is using this device.
 */
-(BOOL) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *)messageDisplay authorIsLocalForEntry:(NSInteger)entry
{
    BOOL ret = NO;
    if (msgExisting) {
        ChatSealMessageEntry *me = [self entryForIndex:entry];
        if (me) {
            ret = ([me isOwnerEntry] == [msgExisting isAuthorMe]);
        }
    }
    return ret;
}

/*
 *  Return whether the given item is an image, which allows the message display to 
 *  optimize the sizing and display.
 */
-(BOOL) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *)messageDisplay contentIsImageAtIndex:(NSIndexPath *)index
{
    if (msgExisting) {
        ChatSealMessageEntry *me = [self entryForIndex:index.entry];
        if (me) {
            return [me isItemAnImageAtIndex:(NSUInteger) index.item];
        }
    }
    return NO;
}

/*
 *  Return a placeholder image when we're scolling fast.
 */
-(UIImage *) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *)messageDisplay fastScrollingPlaceholderAtIndex:(NSIndexPath *)index
{
    // - the idea here is to provide something that can be used when we're scrolling really fast and it won't really be seen.
    ChatSealMessageEntry *me = [self entryForIndex:[index entry]];
    if (me) {
        CGSize szImage = [me imageSizeForItemAtIndex:(NSUInteger) [index item]];
        if (szImage.width > 0.0f && szImage.height > 0.0f) {
            CGFloat ar = szImage.width/szImage.height;
            
            // - the aspect ratio of the image is important if we're going to return something that resembles its dimensions.
            // - now we can cut one out of the one we have lying around just for this purpose.
            UIImage *img = [UISealedMessageDisplayCellV2 genericFastScrollingPlaceholderImage];
            CGSize sz    = img.size;
            if (ar > 1.0f) {
                sz.height = sz.width/ar;
            }
            else {
                sz.width  = sz.height * ar;
            }
            
            // - before we send anything to the Cocoa layer, make sure that the scale is applied.
            sz.width     *= img.scale;
            sz.height    *= img.scale;
            CGImageRef ir = CGImageCreateWithImageInRect(img.CGImage, CGRectMake(0.0f, 0.0f, (CGFloat) floor(sz.width), (CGFloat) floor(sz.height)));
            UIImage *ret  = [UIImage imageWithCGImage:ir scale:img.scale orientation:img.imageOrientation];
            CGImageRelease(ir);
            return ret;
        }
    }
    return nil;
}

/*
 *  Return the data for the given message.
 *  - NSString or UIImage.
 */
-(id) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *)messageDisplay contentForItemAtIndex:(NSIndexPath *)index
{
    id content = nil;
    if (msgExisting) {
        ChatSealMessageEntry *me = [self entryForIndex:index.entry];
        if (me) {
            NSError *err = nil;
            if ([me isItemAnImageAtIndex:(NSUInteger) index.item]) {
                content = [me imagePlaceholderAtIndex:(NSUInteger) index.item];
                if (!content) {
                    [CS_error fillError:&err withCode:CSErrorArchivalError];
                }
            }
            else {
                content = [me itemAtIndex:(NSUInteger) index.item withError:&err];
            }
            if (!content) {
                NSLog(@"CS:  Failed to load the content at %@:%lu.  %@", [msgExisting messageId], (unsigned long) index.item, [err localizedDescription]);
            }
        }
    }
    return content;
}

/*
 *  Populate all the header content at one time.
 */
-(void) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *)messageDisplay populateHeaderContent:(UISealedMessageDisplayHeaderDataV2 *)header forEntry:(NSInteger)entry
{
    if (msgExisting) {
        ChatSealMessageEntry *me = [self entryForIndex:entry];
        if (me) {
            header.author       = [ChatSealMessage standardDisplayHeaderAuthorForMessage:msgExisting andEntry:me withActiveAuthorName:msgExisting ? self.title : nil];
            header.creationDate = [me creationDate];
            header.isRead       = [me isRead];
            header.isOwner      = [me isOwnerEntry];
        }
    }
}

/*
 *  Return the active message.
 */
-(ChatSealMessage *) messageForSealedMessageDisplay:(UISealedMessageDisplayViewV2 *)messageDisplay
{
    return msgExisting;
}

/*
 *  Cancel the pending detail operation.
 */
-(void) cancelDetailOperation
{
    [boPrepareDetail cancel];
    [boPrepareDetail release];
    boPrepareDetail = nil;
}

-(void) scheduleDetailOperation:(NSBlockOperation *) op
{
    if (boPrepareDetail != op) {
        [self cancelDetailOperation];
        boPrepareDetail = [op retain];
        [[ChatSeal uiPopulationQueue] addOperation:op];
    }
}

/*
 *  Indicates that the item was tapped at the given index.
 *  - return YES if the item should proceed with a tapped animation.
 */
-(BOOL) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *)messageDisplay itemTappedAtIndex:(NSIndexPath *)index
{
    if (!msgExisting || !index) {
        return NO;
    }
    
    ChatSealMessageEntry *me = [self entryForIndex:index.entry];
    if (!me) {
        return NO;
    }
    
    if (![me isItemAnImageAtIndex:(NSUInteger) index.item]) {
        return NO;
    }
    
    // - make sure the keyboard is gone.
    [editTools resignFirstResponder];

    // - after the tap is complete, begin showing it, but only after it has had a chance to be retrieved.
    ChatSealWeakOperation *wop = [ChatSealWeakOperation weakOperationWrapper];
    NSBlockOperation *boTapped = [NSBlockOperation blockOperationWithBlock:^(void) {
        NSError *err = nil;
        UIImage *img = [me itemAtIndex:(NSUInteger) index.item withError:&err];
        UIImage *imgPlaceholder = [me imagePlaceholderAtIndex:(NSUInteger) index.item];

        // - if this operation was cancelled, just abort and do nothing.
        if ([wop isCancelled]) {
            return;
        }
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
            if (img && imgPlaceholder) {
                // - we got it, so open the preview screen.
                [ipTapped release];             // save this for the animation.
                ipTapped = [index retain];
                
                UISecurePreviewViewController *secP = (UISecurePreviewViewController *) [ChatSeal viewControllerForStoryboardId:@"UISecurePreviewViewController"];
                [secP setSecureImage:img withPlaceholder:imgPlaceholder andOwningMessage:msgExisting];
                [self.navigationController pushViewController:secP animated:YES];
            }
            else {
                if (img) {
                    NSLog(@"CS: Failed to retrieve a placeholder image for preview.");
                }
                else {
                    NSLog(@"CS: Failed to retrieve the image at %lu:%lu in message %@.  %@", (unsigned long) index.entry, (unsigned long) index.item,
                          msgExisting.messageId, [err localizedDescription]);
                }
                [AlertManager displayFatalAlertWithLowSpaceDetectionUsingTitle:NSLocalizedString(@"Image Decryption Interrupted", nil)
                                                                       andText:NSLocalizedString(@"Your %@ was unable to decrypt your secure image.", nil)];
            }
        }];
    }];
    [wop setOperation:boTapped];
    [self scheduleDetailOperation:boTapped];
    return YES;
}

/*
 *  Called when the scroll view scrolls.  This should be the table.
 */
-(void) sealedMessageDisplayDidScroll:(UISealedMessageDisplayViewV2 *)messageDisplay
{
    CGFloat offset = vwMessageDisplay.contentOffset.y;
    if ([ssSearchScroller applyProxiedScrollOffset:CGPointMake(0.0f, offset)]) {
        // - when the search scroller uses the offset for its own scrolling,
        //   it shouldn't be applied again here because the outer scroll view
        //   is already translating the table.
        vwMessageDisplay.contentOffset = CGPointMake(0.0f, 0.0f);
    }
    [self updateNewEntryIndicatorsWithAnimation:YES];
}

/*
 *  After we complete our dragging operation, make sure that the search scroller stays
 *  up to date.
 */
-(void) sealedMessageDisplayDidEndDragging:(UISealedMessageDisplayViewV2 *)messageDisplay willDecelerate:(BOOL)decelerate
{
    if (!decelerate) {
        [ssSearchScroller validateContentPositionAfterProxiedScrolling];
    }
}

/*
 *  Make sure we validate also after deceleration.
 */
-(void) sealedMessageDisplayDidEndDecelerating:(UISealedMessageDisplayViewV2 *)messageDisplay
{
    [ssSearchScroller validateContentPositionAfterProxiedScrolling];
    [self completeMessageImportProcessing];
}

/*
 *  Scrolling animations are done.
 */
-(void) sealedMessageDisplayDidEndScrollingAnimation:(UISealedMessageDisplayViewV2 *)messageDisplay
{
    [self completeMessageImportProcessing];
    [self updateNewEntryIndicatorsWithAnimation:YES];
}

@end

/*****************************************
 UIMessageDetailViewControllerV2 (search)
 *****************************************/
@implementation UIMessageDetailViewControllerV2 (search)
/*
 *  Reset the search criteria if set.
 */
-(void) resetCurrentSearchWithAnimation
{
    if (currentSearchCriteria) {
        [vwMessageDisplay prepareForContentInsertions];
        [self killFilterTimer];
        [currentSearchCriteria release];
        currentSearchCriteria = nil;
        [self applyCurrentSearchFilterWithAnimation:YES];
    }
}

/*
 *  Detect when the search bar changes its foreground state.
 */
-(void) searchScroller:(UISearchScroller *)ss didMoveToForegroundSearch:(BOOL)isForeground
{
    if (!isForeground) {
        [self resetCurrentSearchWithAnimation];
    }
}

/*
 *  Apply a filter after some period of time.
 */
-(void) deferredFilter
{
    [vwMessageDisplay prepareForContentInsertions];
    [self killFilterTimer];
    [self applyCurrentSearchFilterWithAnimation:YES];
}

/*
 *  The search scroller is about to cancel the active search.
 */
-(void) searchScrollerWillCancel:(UISearchScroller *)ss
{
    [vwMessageDisplay prepareForContentInsertions];
}

/*
 *  When search text is modified, this event is triggered.
 */
-(void) searchScroller:(UISearchScroller *) ss textWasChanged:(NSString *) searchText
{
    // - don't distinguish between nil and empty string.
    if ([searchText length] == 0) {
        searchText = nil;
    }
    
    // - only if the text has changed will we reapply the filter.
    if (searchText == currentSearchCriteria ||
        [searchText isEqualToString:currentSearchCriteria]) {
        return;
    }
    [currentSearchCriteria release];
    currentSearchCriteria = [searchText retain];
    
    // - set up the timer because we don't want to change the filter on every character.
    if (tmFilter) {
        [tmFilter setFireDate:[NSDate dateWithTimeIntervalSinceNow:[ChatSeal standardSearchFilterDelay]]];
    }
    else {
        tmFilter = [[NSTimer scheduledTimerWithTimeInterval:[ChatSeal standardSearchFilterDelay] target:self selector:@selector(deferredFilter) userInfo:nil repeats:NO] retain];
    }
}

/*
 *  When the search bar is moved to the background, we may want to dismiss it entirely.
 */
-(BOOL) searchScroller:(UISearchScroller *)ss shouldCollapseAllAfterMoveToForeground:(BOOL)isForeground
{
    if (!isForeground && vwMessageDisplay.contentOffset.y > 0.0f) {
        return YES;
    }
    return NO;
}

/*
 *  Apply the search filter to the content.
 */
-(void) applyCurrentSearchFilterWithAnimation:(BOOL) animated
{
    if (!msgExisting) {
        return;
    }
    
    // - first figure out what the current list of content looks like.
    NSMutableArray *maCurrent = nil;
    if (animated) {
        maCurrent            = [NSMutableArray array];
        for (NSUInteger entry = 0; entry < numberOfMessageEntries; entry++) {
            psm_entry_id_t eid = [msgExisting filterAwareEntryIdForIndex:entry];
            [maCurrent addObject:[NSNumber numberWithInt:(int) eid]];
        }
    }
    
    // - figure out what is visible so that we can restore it.
    NSInteger topVisible  = [vwMessageDisplay topVisibleItem];
    psm_entry_id_t realId = [msgExisting filterAwareEntryIdForIndex:(NSUInteger) topVisible];
    
    // - apply the new search criteria
    [msgExisting applyFilter:currentSearchCriteria];
    [vwMessageDisplay setSearchText:currentSearchCriteria];
    NSInteger adjustedIndex = [msgExisting indexForFilterAwareEntryId:realId];
    [self updateMessageEntryCount];
    
    // - and modify the display.
    if (animated) {
        // - build the insertion/deletion arrays.
        NSMutableIndexSet *isToInsert = [NSMutableIndexSet indexSet];
        NSMutableIndexSet *isToDelete = [NSMutableIndexSet indexSet];
        
        NSInteger oldIdx = 0;
        NSInteger newIdx = 0;
        for (;;) {
            // - figure out what is available.
            psm_entry_id_t entryOld = -1;
            if (oldIdx < [maCurrent count]) {
                NSNumber *n = [maCurrent objectAtIndex:(NSUInteger) oldIdx];
                entryOld    = [n intValue];
            }
            psm_entry_id_t entryNew = -1;
            if (newIdx < numberOfMessageEntries) {
                entryNew = [msgExisting filterAwareEntryIdForIndex:(NSUInteger) newIdx];
            }
            
            // - we're out of content.
            if (entryOld == -1 && entryNew == -1) {
                break;
            }
            
            //  - if the entries are identical, there is nothing to be done and
            //    the check is quick.
            if (entryOld == entryNew) {
                oldIdx++;
                newIdx++;
                continue;
            }
            
            if (entryOld != -1 && (entryNew == -1 || entryOld < entryNew)) {
                [isToDelete addIndex:(NSUInteger) oldIdx];
                oldIdx++;
                continue;
            }
            
            // - otherwise, we can assume this is an insertion.
            [isToInsert addIndex:(NSUInteger) newIdx];
            newIdx++;
        }
        
        // - and adjust the content
        if ([isToInsert count] > 0 || [isToDelete count] > 0) {
            [vwMessageDisplay reloadDataWithEntryInsertions:isToInsert andDeletions:isToDelete];
            if ([isToInsert count] && ![isToDelete count]) {
                adjustedIndex = -1;
            }
        }
    }
    else {
        [vwMessageDisplay reloadData];
    }
    
    // - when the item we were looking at is still available, make sure it stays visible.
    if (adjustedIndex >= 0) {
        [vwMessageDisplay scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:adjustedIndex] atScrollPosition:UITableViewScrollPositionNone animated:animated];
    }

    // - the new entry indicator depends on where we are in the display.
    [self updateNewEntryIndicatorsWithAnimation:animated];
}

@end

/****************************************************
 UIMessageDetailViewControllerV2 (overviewTransition)
 ****************************************************/
@implementation UIMessageDetailViewControllerV2 (overviewTransition)
/*
 *  Complete the transition tasks.
 */
-(void) completedOverviewReturnTransition
{
    if (vwKeyboardSnapshot) {
        [UIFakeKeyboardV2 setKeyboardMaskingEnabled:NO];
        [vwKeyboardSnapshot removeFromSuperview];
        [vwKeyboardSnapshot release];
        vwKeyboardSnapshot = nil;
        [ssSearchScroller setDetectKeyboardResignation:YES];
    }
}
@end
