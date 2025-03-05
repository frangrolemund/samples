//
//  UINewSealViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/3/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "UINewSealViewController.h"
#import "UINewSealCell.h"
#import "UINewSealFlowLayout.h"
#import "AlertManager.h"
#import "ChatSeal.h"
#import "UICleanCameraButtonV2.h"
#import "UIImageGeneration.h"
#import "UIPhotoLibraryAccessViewController.h"
#import "UIDynamicTypeCompliantEntity.h"
#import "UIAdvancedSelfSizingTools.h"

// - constants
static const CGFloat UINSVC_BASE_GLOSS_TIME = 3.0f;
static const CGFloat UINSVC_GLOSS_ADJ       = 3.0f;
static const CGFloat UINSVC_TARGET_SIDE_PAD = 8.0f;
static const CGFloat UINSVC_PAD_PCT         = 35.0f/320.0f;             //  based on a classic device width.

// -  forward declarations
@interface UINewSealViewController (internal) <UICollectionViewDataSource, UICollectionViewDelegateSealFlowLayout, UINewSealBackdropViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDynamicTypeCompliantEntity>
-(void) setCompletionBlock:(sealCreationCompleted) cblock;
-(void) setNewSealActiveFlag:(BOOL) makeActive;
-(void) assignCurrentItemUponScrollCompletion;
-(void) setNewSealImage:(UIImage *) image withAnimation:(BOOL) animated;
-(void) transferSealAttributesFromBackdrop;
-(void) completeWithSid:(NSString *) sid;
-(void) setCameraMode:(BOOL) isCameraMode;
-(void) hideAllCellDecorations;
-(void) showDecorationForIndex:(NSIndexPath *) indexPath;
-(void) finishSealCreationWithId:(NSString *) sealId andHadVault:(BOOL) hadVault andError:(NSError *) err;
-(void) spawnSealCreationWithHadVault:(BOOL) hadVault;
-(void) finishVaultCreationWithResult:(BOOL) retVal andError:(NSError *) err;
-(void) spawnVaultCreationOperation;
-(void) doCreate:(id)sender;
-(void) doDone:(id) sender;
-(void) setEditModeEnabled:(BOOL) toEditMode withAnimation:(BOOL) animated;
-(void) updateToolButtonStatesForEnabled:(BOOL) isEnabled;
-(void) fadeInEditShade;
-(void) gestureTapped:(UITapGestureRecognizer *) gesture;
-(void) showCurrentSealInCell:(BOOL) visible;
-(void) updateSnapButtonForCurrentState;
-(void) notifyRotated;
-(void) updateElementsForRotation;
-(CGFloat) elementRotationForOrientation:(UIDeviceOrientation) orient;
-(void) showDefaultPhotoSelectionWithCompletion:(void (^)(void)) presentationCompletion;
-(void) advanceGlossTimeout;
-(void) glossTimeout;
-(UINewSealCell *) currentSealCell;
-(void) notifyDidBackground;
-(void) notifyForeground;
-(void) updatePhotoLibraryButton;
-(void) setAnimatedTurnForCell:(UINewSealCell *) nsc andLocked:(BOOL) isLocked;
-(void) setCreationStateEnabled:(BOOL) creationEnabled;
-(void) reconfigureDynamicTypeDuringInit:(BOOL) isInit;
@end

/***************************
 UINewSealViewController
 ***************************/
@implementation UINewSealViewController 
/*
 *  Object attributes.
 */
{
    sealCreationCompleted       completionBlock;
    NSInteger                   currentSealStyle;
    BOOL                        isEditing;
    UITapGestureRecognizer      *grTapped;
    NSUInteger                  lastEditedVersion;
    BOOL                        hasAppeared;
    BOOL                        isCameraRestricted;
    BOOL                        isEditReady;
    BOOL                        autoEnableCamera;
    UIDeviceOrientation         currentOrientation;
    UIDeviceOrientation         uiElementOrientation;
    UIDeviceOrientation         sealCollectionOrientation;
    UIDeviceOrientation         activeCellOrientation;
    UIImage                     *minimalSealImage;
    BOOL                        ignoreDoneButton;
    BOOL                        creationStarted;
    BOOL                        showGloss;
    NSTimer                     *glossTimer;
    BOOL                        makeNewSealActive;
    BOOL                        isDismissing;
}

@synthesize sealDisplayView;
@synthesize toolView;
@synthesize description;
@synthesize editDescription;
@synthesize backdrop;
@synthesize sealCollection;
@synthesize addPhotoButton;
@synthesize flipCameraButton;
@synthesize snapPhotoButton;
@synthesize vwEditShade;
@synthesize backdropSideConstraint;
@synthesize bottomToolConstraint;

/*
 *  Initialize and return a seal creation dialog.
 */
+(UIViewController *) viewControllerWithCreationCompletionBlock:(sealCreationCompleted) completionBlock andAutomaticallyMakeActive:(BOOL) makeActive
{
    UINavigationController *nc = (UINavigationController *) [ChatSeal viewControllerForStoryboardId:@"UINewSealNavigationController"];
    if (nc) {
        UINewSealViewController *nsvc = (UINewSealViewController *) nc.topViewController;
        [nsvc setCompletionBlock:completionBlock];
        [nsvc setNewSealActiveFlag:makeActive];
    }
    return nc;
}

/*
 *  Initialize and return a seal creation dialog.
 */
+(UIViewController *) viewControllerWithCreationCompletionBlock:(sealCreationCompleted) completionBlock
{
    return [UINewSealViewController viewControllerWithCreationCompletionBlock:completionBlock andAutomaticallyMakeActive:YES];
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        completionBlock             = nil;
        currentSealStyle            = RSSC_DEFAULT;
        isEditing                   = NO;
        lastEditedVersion           = (NSUInteger)-1;
        hasAppeared                 = NO;
        isCameraRestricted          = NO;
        isEditReady                 = NO;
        autoEnableCamera            = NO;
        currentOrientation          = UIDeviceOrientationUnknown;
        uiElementOrientation        = UIDeviceOrientationUnknown;
        sealCollectionOrientation   = UIDeviceOrientationUnknown;
        activeCellOrientation       = UIDeviceOrientationUnknown;
        minimalSealImage            = nil;
        ignoreDoneButton            = NO;
        creationStarted             = NO;
        showGloss                   = NO;
        makeNewSealActive           = YES;
        isDismissing                = NO;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyRotated) name:UIDeviceOrientationDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyDidBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    backdrop.delegate = nil;
    [self setCompletionBlock:nil];
        
    [description release];
    description = nil;
    
    [editDescription release];
    editDescription = nil;
    
    [backdrop release];
    backdrop = nil;
    
    [sealCollection release];
    sealCollection = nil;
    
    [addPhotoButton release];
    addPhotoButton = nil;
    
    [flipCameraButton release];
    flipCameraButton = nil;
    
    [snapPhotoButton release];
    snapPhotoButton = nil;
    
    [vwEditShade release];
    vwEditShade = nil;
    
    [sealDisplayView release];
    sealDisplayView = nil;
    
    [toolView release];
    toolView = nil;
    
    [grTapped release];
    grTapped = nil;
    
    [bottomToolConstraint release];
    bottomToolConstraint = nil;
    
    [minimalSealImage release];
    minimalSealImage = nil;
    
    [backdropSideConstraint release];
    backdropSideConstraint = nil;
    
    [glossTimer release];
    glossTimer = nil;
    
    [super dealloc];
}

/*
 *  Return the padding for the seal on the sides of the screen.
 */
+(CGFloat) sealPad
{
    // - in order to maintain a consistent amount of seal reveal on either side
    //   of the screen, we're computing this based on the device width.
    return (CGFloat) floor([ChatSeal portraitWidth] * UINSVC_PAD_PCT);
}

/*
 *  Configure the object.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];

    //  - wire up the collection
    sealCollection.delegate = self;
    sealCollection.dataSource = self;
    UINewSealFlowLayout *nsfl = [[UINewSealFlowLayout alloc] init];
    
    // - in order for this to look good on all devices, some with wider screens, we're going to compute
    //   the ideal backdrop now and assign it before we start.
    CGFloat oneSide                 = (CGFloat) floor([ChatSeal portraitWidth]) - ([UINewSealViewController sealPad] * 2.0f);
    backdropSideConstraint.constant = oneSide;
    [nsfl setItemSize:CGSizeMake(oneSide, oneSide)];
    CGFloat viewWidth = CGRectGetWidth(self.view.bounds);
    [nsfl setSectionInset:UIEdgeInsetsMake(0.0f, (viewWidth-oneSide)/2.0f, 0.0f, (viewWidth-oneSide)/2.0f)];
    [sealCollection setCollectionViewLayout:nsfl animated:NO];
    [nsfl release];
    sealCollection.bounds = CGRectMake(0.0f, 0.0f, viewWidth, oneSide);
    [sealCollection setDefaultItem:[NSIndexPath indexPathForItem:currentSealStyle inSection:0]];
    
    //  - add the gesture for entering edit mode
    grTapped = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(gestureTapped:)];
    grTapped.numberOfTapsRequired    = 1;
    grTapped.numberOfTouchesRequired = 1;
    [self.view addGestureRecognizer:grTapped];

    //  - turn off editing by default
    [self setEditModeEnabled:NO withAnimation:NO];
    
    //  - force the backdrop to configure itself
    backdrop.delegate = self;
    [backdrop setSealImage:nil];
    [backdrop setNoPhotoVisible:NO withAnimation:NO];
    
    // - make sure all elements are rotation-accurate.
    [self notifyRotated];
    
    // - and try to get the best image possible for the photo library
    [self updatePhotoLibraryButton];
    
    // - the edit shade is a consistent color throughout.
    vwEditShade.backgroundColor = [ChatSeal defaultLowChromeDarkShadowColor];
    [ChatSeal defaultLowChromeShadowTextLabelConfiguration:editDescription];
    
    // - reconfigure labels for dynamic type if necessary.
    [self reconfigureDynamicTypeDuringInit:YES];
}

/*
 *  The only modifyable constraints are involved with showing/hiding the tools.
 */
-(void) updateViewConstraints
{
    [super updateViewConstraints];
    
    CGFloat height = CGRectGetHeight(toolView.bounds);
    if (isEditing) {
        bottomToolConstraint.constant = 0.0f;
    }
    else {
        bottomToolConstraint.constant = height;
    }
}

/*
 *  Cancel seal creation.
 */
-(IBAction)doCancel:(id)sender
{
    [self completeWithSid:nil];
}

/*
 *  Add a photo to the seal from the photo library.
 */
-(IBAction)doAddPhoto:(id)sender
{
    // - I originally was showing more explanation when accessing their photo library, but it feels like overkill.
    if ([UIPhotoLibraryAccessViewController photoLibraryIsOpen]) {
        [self showDefaultPhotoSelectionWithCompletion:nil];
    }
    else if (![UIPhotoLibraryAccessViewController photoLibraryAccessHasBeenRequested]) {
        [UIPhotoLibraryAccessViewController requestPhotoLibraryAccessWithCompletion:^(BOOL isAuthorized) {
            if (isAuthorized) {
                [self showDefaultPhotoSelectionWithCompletion:nil];
            }
        }];
    }
    else {
        UIAlertView *av = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Photos Restricted", nil) message:NSLocalizedString(@"You can design your seal after you modify Settings to allow ChatSeal to use your Photo Library.", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil] autorelease];
        [av show];
        return;
    }
}

/*
 *  Flip to the other camera.
 */
-(IBAction)doFlipCamera:(id)sender
{
    [backdrop flipCamera];
}

/*
 *  When the camera is enabled, snap a photo and set it in the seal.
 */
-(IBAction)doSnapPhoto:(id)sender
{
    if ([backdrop isCameraActive]) {
        [backdrop snapPhoto];
    }
    else {
        [self setCameraMode:YES];
        [self updateSnapButtonForCurrentState];
    }
}

/*
 *  Turn the gloss timer on when we're appearing again.
 */
-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // - prepare to show the gloss on the seal before it has a photo.
    if (!glossTimer) {
        glossTimer = [[NSTimer scheduledTimerWithTimeInterval:UINSVC_BASE_GLOSS_TIME target:self selector:@selector(glossTimeout) userInfo:nil repeats:YES] retain];
    }
    
    // - get ready for generating a seal and ensure the public keys are ready.
    if (!hasAppeared) {
        [RealSecureImage prepareForSealGeneration];
    }
}

/*
 *  Ensure that we aren't trying to generate transitions
 *  until the view has been presented to make it open faster.
 */
-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // - make sure that the backdrop knows that it can begin
    [backdrop viewDidAppear];
    
    // - this is a one-time appearance exercise, we don't
    //   need to do this when returning from a modal dialog.
    if (!hasAppeared) {
        isCameraRestricted = ![ChatSeal hasAnyCamera];
        [self updateToolButtonStatesForEnabled:NO];

        [CATransaction begin];
        for (UINewSealCell *nsc in sealCollection.visibleCells) {
            if (nsc.sealColor == currentSealStyle) {
                [self setAnimatedTurnForCell:nsc andLocked:NO];
            }
            else {
                [nsc setAllContentsVisible:YES withAnimation:YES];
            }
        }
        [CATransaction commit];
        
        // - and slowly show the directive to add a photo
        [CATransaction begin];
        [CATransaction setCompletionBlock:^(void){
            isEditReady = YES;
        }];
        for (UINewSealCell *nsc in sealCollection.visibleCells) {
            [nsc setNoPhotoVisible:YES withAnimation:YES];
        }
        [CATransaction commit];            
    }
    hasAppeared = YES;
    showGloss   = YES;
}

/*
 *  The view is about to disappear.
 */
-(void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [glossTimer invalidate];
    [glossTimer release];
    glossTimer = nil;
}

/*
 *  When the view disappears (usually because of modal events) let us know.
 */
-(void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // - make sure the backdrop knows.
    [backdrop viewDidDisappear];
}

/*
 *  Layout has occurred.
 */
-(void) viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    // - update the preferred max layout width if needed for the two text items.
    CGFloat preferredWidth = CGRectGetWidth(self.view.bounds) - (UINSVC_TARGET_SIDE_PAD * 2.0f);
    if ((int) preferredWidth != (int) self.description.preferredMaxLayoutWidth) {
        self.description.preferredMaxLayoutWidth     = preferredWidth;
        [self.description invalidateIntrinsicContentSize];
        self.editDescription.preferredMaxLayoutWidth = preferredWidth;
        [self.editDescription invalidateIntrinsicContentSize];
    }
}

@end

/**********************************
 UINewSealViewController (internal)
 **********************************/
@implementation UINewSealViewController (internal)
/*
 *  Set the completion block to execute in the object when buttons are pressed.
 */
-(void) setCompletionBlock:(sealCreationCompleted) cblock
{
    if (cblock != completionBlock) {
        if (completionBlock) {
            Block_release(completionBlock);
            completionBlock = nil;
        }
        
        if (cblock) {
            completionBlock = Block_copy(cblock);
        }
    }
}

/*
 *  Control whether this screen will automatically make a new seal active when it is created.
 */
-(void) setNewSealActiveFlag:(BOOL) makeActive
{
    makeNewSealActive = makeActive;
}

/*
 *  The number of sections in the collection that shows the different seal designs.
 */
-(NSInteger) numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

/*
 *  The number of ites in the given section.
 */
-(NSInteger) collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return RSSC_NUM_SEAL_COLORS;
}

/*
 *  Return a cell for the given index in the seal view.
 */
-(UICollectionViewCell *) collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UINewSealCell *nsc = (UINewSealCell *) [collectionView dequeueReusableCellWithReuseIdentifier:@"NewSealCell" forIndexPath:indexPath];
    [nsc setCenterRotation:[self elementRotationForOrientation:currentOrientation]];
    [nsc setNoPhotoVisible:hasAppeared withAnimation:NO];
    [nsc configureSealImageFromView:backdrop.sealImageView];
    [nsc setSealColor:(RSISecureSeal_Color_t) indexPath.item];
    BOOL isScrolling = [sealCollection isDragging] || [sealCollection isDecelerating];
    if (!isScrolling && indexPath.item == currentSealStyle) {
        [nsc setLocked:!hasAppeared];
        [nsc setAllContentsVisible:YES withAnimation:hasAppeared];
    }
    else {
        [nsc setLocked:YES];
        [nsc setAllContentsVisible:hasAppeared withAnimation:hasAppeared];
    }
    
    return nsc;
}


/*
 *  When the collection begins dragging, we want to hide the cells' seals
 *  in favor of the backdrop.
 */
-(void) scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [self hideAllCellDecorations];
    backdrop.alpha = 0.0f;
    showGloss      = NO;
}

/*
 *  Change the value of the current item based on the current content offset.
 */
-(void) assignCurrentItemUponScrollCompletion
{
    CGPoint ptToTest;
    backdrop.alpha = 1.0f;
    if (UIInterfaceOrientationIsPortrait(self.backwardsCompatibleInterfaceOrientation)) {
        ptToTest = CGPointMake(sealCollection.contentOffset.x + CGRectGetWidth(sealCollection.bounds)/2.0f,
                               CGRectGetHeight(sealCollection.bounds)/2.0f);
    }
    else {
        ptToTest = CGPointMake(CGRectGetWidth(sealCollection.bounds)/2.0f,
                               sealCollection.contentOffset.y + CGRectGetHeight(sealCollection.bounds)/2.0f);
    }
    NSIndexPath *ip = [sealCollection indexPathForItemAtPoint:ptToTest];
    if (ip) {
        currentSealStyle = ip.item;
        [self showDecorationForIndex:ip];
    }
    
    [self transferSealAttributesFromBackdrop];
    [self advanceGlossTimeout];         //  so it doesn't fire immediately.
    showGloss = YES;
}

/*
 *  When the collection is done scrolling from user interaction, update the current item.
 */
-(void) scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self assignCurrentItemUponScrollCompletion];
}

/*
 *  When the collection is done being animated by us, update the current item.
 */
-(void) scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    // - make sure this happens outside the animation completion block.
    [self performSelectorOnMainThread:@selector(assignCurrentItemUponScrollCompletion) withObject:nil waitUntilDone:NO];
}

/*
 *  This method is used by the layout to determine how the center items and allows some
 *  customization with the special case for the translucent title bar.
 */
-(CGPoint) workingCenterOfView
{
    CGPoint ptCenter = CGPointMake(CGRectGetWidth(sealCollection.bounds)/2.0f, CGRectGetHeight(sealCollection.bounds)/2.0f);
    if (UIInterfaceOrientationIsLandscape(self.backwardsCompatibleInterfaceOrientation)) {
        ptCenter.y += (CGRectGetHeight(self.navigationController.navigationBar.bounds) / 2.0f);
    }
    return ptCenter;
}

/*
 *  Assign the seal image in this view.
 */
-(void) setNewSealImage:(UIImage *) image withAnimation:(BOOL) animated
{
    // - the backdrop holds the original image and generates the
    //   preview image we use for all others.
    [backdrop setSealImage:image withAnimation:animated];
    [self setCameraMode:NO];
    [self updateToolButtonStatesForEnabled:isEditing];
    [self updateSnapButtonForCurrentState];
}

/*
 *  Copy attributes from the backdrop to the visible cells or from the cells to the backdrop.
 */
-(void) transferSealAttributesFromBackdrop
{
    for (UINewSealCell *nsc in sealCollection.visibleCells) {
        [nsc configureSealImageFromView:backdrop.sealImageView];
    }
}

/*
 *  Close the view via the completion block, passing a sid.
 */
-(void) completeWithSid:(NSString *) sid
{
    isDismissing = YES;
    if (completionBlock) {
        completionBlock(sid ? NO : YES, sid);
        [self setCompletionBlock:nil];          //  to ensure that the retain cycle is broken with the parent.
    }
    else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

/*
 *  Change the mode of the view.
 */
-(void) setCameraMode:(BOOL) isCameraMode
{
    //  - we're simply going to show/hide the
    //    camera related buttons depending on the mode.
    if (isCameraRestricted) {
        isCameraMode = NO;
    }
    
    if (isCameraMode) {
        [backdrop switchToCamera];
    }
    else {
        [backdrop switchToSealWithCompletion:nil];
    }
    
    [self updateToolButtonStatesForEnabled:isEditing];
}

/*
 *  Animate the decorations on the cell to hidden.
 */
-(void) hideAllCellDecorations
{
    for (UINewSealCell *cell in sealCollection.visibleCells) {
        [self setAnimatedTurnForCell:cell andLocked:YES];
    }
}

/*
 *  Animate the decoration on the cell to visible.
 */
-(void) showDecorationForIndex:(NSIndexPath *) indexPath
{
    UINewSealCell *nsc = (UINewSealCell *) [sealCollection cellForItemAtIndexPath:indexPath];
    if (nsc) {
        [self setAnimatedTurnForCell:nsc andLocked:NO];
    }    
}

/*
 *  Initiate seal creation.
 *  - the value passed indicates whether the vault was available when this started.
 */
-(void) spawnSealCreationWithHadVault:(BOOL) hadVault
{
    NSLog(@"CS: Starting seal creation.");    
    // - I'm going to have a backup plan here in case for some reason we were unable to
    //   create the minimal image when the extended view contracted.  That shouldn't be the
    //   case, but there isn't an error presented there.
    UIImage *img = minimalSealImage;
    if (!img) {
        img = [backdrop generateMinimalSealImage];
    }
    
    NSBlockOperation *bo = [NSBlockOperation blockOperationWithBlock:^(void){
        NSError *err  = nil;
        NSString *sid = [ChatSeal createSealWithImage:img andColor:(RSISecureSeal_Color_t) currentSealStyle andSetAsActive:makeNewSealActive withError:&err];
        [[NSOperationQueue mainQueue] addOperationWithBlock:^(void){
            [self finishSealCreationWithId:sid andHadVault:hadVault andError:err];
        }];        
    }];
    [[ChatSeal vaultOperationQueue] addOperation:bo];
}

/*
 *  When the seal creation attempt has completed, this method will be called
 *  to make a decision about next steps.
 */
-(void) finishSealCreationWithId:(NSString *) sealId andHadVault:(BOOL) hadVault andError:(NSError *) err
{
    if (sealId) {
        NSLog(@"CS: Seal created successfully.");        
        [self completeWithSid:sealId];
    }
    else {
        // - if there was no vault previously, remove it now so that things like tabs aren't
        //   created until we have a seal to display.
        if (!hadVault) {
            [ChatSeal destroyAllApplicationDataWithError:nil];
        }
        NSLog(@"CS: Failed to create new seal.  %@", [err localizedDescription]);
        [AlertManager displayFatalAlertWithLowSpaceDetectionUsingTitle:NSLocalizedString(@"Seal Creation Interrupted", nil)
                                                               andText:NSLocalizedString(@"Your %@ is unable to secure your new seal.", nil)];
        [self setCreationStateEnabled:NO];
    }
}

/*
 *  Initiate the vault creation
 */
-(void) spawnVaultCreationOperation
{
    NSBlockOperation *bo = [NSBlockOperation blockOperationWithBlock:^(void){
        NSLog(@"CS: Initializing the seal vault for the first time.");
        NSError *err = nil;
        BOOL ret = [ChatSeal initializeVaultWithError:&err];
        if (ret) {
            NSLog(@"CS: The seal vault is now online.");
        }        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^(void){
            [self finishVaultCreationWithResult:ret andError:err];
        }];
    }];
    [[ChatSeal vaultOperationQueue] addOperation:bo];
}

/*
 *  When the vault creation attempt has completed, this method will be called to make a decision
 *  about the next steps.
 */
-(void) finishVaultCreationWithResult:(BOOL) retVal andError:(NSError *) err
{
    if (retVal) {
        [self spawnSealCreationWithHadVault:NO];
    }
    else {
        [ChatSeal destroyAllApplicationDataWithError:nil];
        NSLog(@"CS: Failed to initialize the seal vault.  %@", [err localizedDescription]);
        [AlertManager displayFatalAlertWithLowSpaceDetectionUsingTitle:NSLocalizedString(@"Seal Creation Interrupted", nil)
                                                               andText:NSLocalizedString(@"Your %@ is unable to build a secure Seal Vault.", nil)];
        [self setCreationStateEnabled:NO];
    }    
}

/*
 *  Complete seal creation.
 */
-(void) doCreate:(id)sender
{
    // - disable the window while we're in the process of creating the content.
    [self setCreationStateEnabled:YES];
    
    // - begin working on the seal.
    BOOL hasVault = [ChatSeal hasVault];
    if (hasVault) {
        [self spawnSealCreationWithHadVault:YES];
    }
    else {
        [self spawnVaultCreationOperation];
    }
    
    // - fade out the non-primary seals so they don't have to be drawn during
    //   the view dismissal animation.
    for (UINewSealCell *nsc in sealCollection.visibleCells) {
        if (nsc.sealColor != currentSealStyle) {
            //  - fade the peripheral views
            [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void) {
                nsc.alpha = 0.0f;
            }completion:^(BOOL finished){
                nsc.hidden = YES;
            }];
        }
    }
}

/*
 *  Exit edit mode.
 */
-(void) doDone:(id) sender
{
    if (ignoreDoneButton) {
        return;
    }
    
    // - figure out if the camera should be auto-enabled when we edit again.
    autoEnableCamera = NO;
    if (![backdrop hasSealImage] && [backdrop isCameraActive] && [backdrop isCameraUsable]) {
        autoEnableCamera = YES;
    }
    
    // - if the camera is on, turn it off before retracting so that
    //   the fade of the edit shade is consistent in all cases
    if ([backdrop isCameraActive]) {
        [backdrop switchToSealWithCompletion:^(void) {
            [self setEditModeEnabled:NO withAnimation:YES];
        }];
    }
    else {
        [self setEditModeEnabled:NO withAnimation:YES];
    }
}

/*
 *  Turn edit mode on/off.
 */
-(void) setEditModeEnabled:(BOOL) toEditMode withAnimation:(BOOL) animated
{
    [CATransaction begin];
    
    // - make sure that all the cells reflect the contents of the backup view.
    if (!toEditMode) {
        [self transferSealAttributesFromBackdrop];
    }
        
    // - start/stop the gesture recognizer
    grTapped.enabled = !toEditMode;
    
    // - create the button that will complete the process
    void(^createNavButton)(void) = ^(void) {
        UIBarButtonItem *bbiRight = nil;
        if (toEditMode) {
            bbiRight = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doDone:)];
        }
        else {
            bbiRight = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Create", nil) style:UIBarButtonItemStylePlain target:self action:@selector(doCreate:)];
            if (![backdrop hasSealImage]) {
                bbiRight.enabled = NO;
            }
        }
        [self.navigationItem setRightBarButtonItem:bbiRight animated:animated];
        [bbiRight release];        
    };
    
    // -  show/hide the tools and frosted glass
    void (^visChanges)(void) = ^(void) {
        description.alpha     = (toEditMode ? 0.0f : 1.0f);
        editDescription.alpha = (toEditMode ? 1.0f : 0.0f);
        vwEditShade.alpha       = 0.0f;
    };
    
    if (animated) {
        [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:visChanges];
    }
    else {
       visChanges();
    }
    
    backdrop.alpha = 1.0f;
    
    // ...when retracting the backdrop, if there is no image, the animation of the text change will flicker if we do it up front.
    BOOL didShowSealBeforeAnimation = NO;
    if (!hasAppeared || [backdrop hasSealImage] || toEditMode) {
        [self showCurrentSealInCell:!toEditMode];
        didShowSealBeforeAnimation = YES;
    }
    
    // - save the state
    isEditing = toEditMode;
    
    // - find the current cell
    UINewSealCell *curCell = [self currentSealCell];
    if (hasAppeared) {
        [self.navigationItem.rightBarButtonItem setEnabled:NO];
        if (toEditMode) {
            [curCell setCenterRingVisible:NO];
        }
        [backdrop setExtendedView:toEditMode withAnimation:animated andCompletion:^(void){
            if (toEditMode) {
                [sealDisplayView bringSubviewToFront:backdrop];
            }
            else {
                [sealDisplayView sendSubviewToBack:backdrop];
            }
            
            createNavButton();
            
            // - turn the shadow back on
            if (!toEditMode) {
                [self advanceGlossTimeout];
                [UIView animateWithDuration:[ChatSeal standardItemFadeTime] delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^(void){
                    [curCell setCenterRingVisible:YES];
                    // - if we didn't show the seal, do so now.
                    if (!didShowSealBeforeAnimation) {
                        [self showCurrentSealInCell:YES];
                    }
                }completion:nil];
            }
            
            // - when we're moving out of edit mode and there is an image, regenerate the
            //   minimal seal image so that seal creation is a bit faster.
            // - this should be done when the nav button is enabled
            if (!toEditMode && [backdrop hasSealImage]) {
                NSUInteger curVersion = backdrop.sealImageView.editVersion;
                if (!minimalSealImage || lastEditedVersion != curVersion) {
                    [minimalSealImage release];
                    minimalSealImage = nil;
                    minimalSealImage = [[backdrop generateMinimalSealImage] retain];
                    lastEditedVersion = curVersion;
                }
            }
            
            [UIView animateWithDuration:[ChatSeal standardBarAppearanceTime] animations:^(void){
                [self updateViewConstraints];
                [self.view layoutIfNeeded];
            } completion:^(BOOL finished) {
                //  - turn the camera on/off depending on the mode.
                BOOL useCamera = toEditMode && autoEnableCamera;
                [self setCameraMode:useCamera];
                if (isEditing && !useCamera) {
                    [self updateToolButtonStatesForEnabled:YES];
                }
                [self updateSnapButtonForCurrentState];
                if (!toEditMode) {
                    [self updateElementsForRotation];
                }
                
                // - turn gloss on/off
                showGloss = !toEditMode;
            }];
        }];
    }
    else {
        // - just create the nav button immediately the first time we run this.
        createNavButton();
    }
    
    // - enable/disable the collection
    sealCollection.scrollEnabled = !toEditMode;
    
    // - always turn off the buttons initially
    [self updateToolButtonStatesForEnabled:NO];
    
    [CATransaction commit];
}

/*
 *  Update the visibility of the buttons.
 */
-(void) updateToolButtonStatesForEnabled:(BOOL)isEnabled
{
    BOOL hasPhotoLib = [UIPhotoLibraryAccessViewController photoLibraryIsOpen] || ![UIPhotoLibraryAccessViewController photoLibraryAccessHasBeenRequested];
    BOOL hasFlip     = (!isCameraRestricted && [ChatSeal hasFrontCamera] && [ChatSeal hasBackCamera]);
    BOOL camOn       = [backdrop isCameraUsable];
    BOOL camOverride = ![backdrop isCameraActive] || camOn;
    [(UICleanCameraButtonV2 *) snapPhotoButton setUnavailableMaskEnabled:isCameraRestricted];
    
    [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void){
        addPhotoButton.alpha     = (hasPhotoLib ? 1.0f : 0.0f);
        addPhotoButton.enabled   = hasPhotoLib && camOverride && isEnabled;
        flipCameraButton.alpha   = (hasFlip ? 1.0f : 0.0f);
        flipCameraButton.enabled = hasFlip && camOn && isEnabled;
        snapPhotoButton.enabled  = !isCameraRestricted && camOverride && isEnabled;
    }];
}

/*
 *  Show the edit shade with a fade-in effect.
 */
-(void) fadeInEditShade
{
    [UIView animateWithDuration:[ChatSeal standardItemFadeTime] animations:^(void){
        vwEditShade.alpha = 1.0f;
    }];
}

/*
 *  This event is called whenever we tap inside the view.
 */
-(void) gestureTapped:(UITapGestureRecognizer *) gesture
{
    if (!isEditReady || isEditing) {
        return;
    }
    
    // - make sure we have at least minimal access to photos.
    if (([UIPhotoLibraryAccessViewController photoLibraryAccessHasBeenRequested] && ![UIPhotoLibraryAccessViewController photoLibraryIsOpen]) && ![ChatSeal hasAnyCamera]) {
        UIAlertView *av = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Photos Restricted", nil) message:NSLocalizedString(@"You can design your seal after you modify Settings to allow ChatSeal to use your camera or Photo Library.", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil] autorelease];
        [av show];
        return;
    }
    
    CGPoint ptLoc = [gesture locationOfTouch:0 inView:self.view];
    ptLoc = [self.view convertPoint:ptLoc toView:sealCollection];
    NSIndexPath *ip = [sealCollection indexPathForItemAtPoint:ptLoc];
    if (ip) {
        CGPoint center = [self workingCenterOfView];
        center.x += sealCollection.contentOffset.x;
        center.y += sealCollection.contentOffset.y;
        CGFloat diam = [UISealWaxViewV2 centerDiameterFromRect:self.backdrop.bounds];
        CGRect rc = CGRectMake(center.x - (diam/2.0f), center.y - (diam/2.0f), diam, diam);
        if (CGRectContainsPoint(rc, ptLoc)) {
            [self setEditModeEnabled:YES withAnimation:YES];
            [self fadeInEditShade];
        }
    }
}

/*
 *  Show/hide the current seal in the active cell.
 */
-(void) showCurrentSealInCell:(BOOL) visible
{
    [[self currentSealCell] setSealImageVisible:visible];
}

/*
 *  This method is called when the backdrop's camera comes online.
 */
-(void) backdropViewCameraReady:(UINewSealBackdropView *)pv
{
    [self updateToolButtonStatesForEnabled:isEditing];
}

/*
 *  This method is called when the backdrop's camera is offline.
 */
-(void) backdropViewCameraNotReady:(UINewSealBackdropView *)pv
{
    [self updateToolButtonStatesForEnabled:isEditing];
}

/*
 *  This method is called when the backdrop snaps a photo with the camera.
 */
-(void) backdropView:(UINewSealBackdropView *)pv snappedPhoto:(UIImage *)img
{
    if (img) {
        // - when retrieving a photo from the front camera, reverse the auto-correction
        //   performed by the camera device because it is jarring to have a self-portrait
        //   flip itself after seeing it.
        if ([backdrop isFrontCameraActive]) {
            UIGraphicsBeginImageContextWithOptions(img.size, YES, img.scale);
            CGContextTranslateCTM(UIGraphicsGetCurrentContext(), img.size.width, 0.0f);
            CGContextScaleCTM(UIGraphicsGetCurrentContext(), -1.0f, 1.0f);
            [img drawAtPoint:CGPointZero];
            img = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
        
        // - animate the transition when we're upside down because we never show the seal image upside down.
        [self setNewSealImage:img withAnimation:([ChatSeal currentDeviceOrientation] == UIDeviceOrientationPortraitUpsideDown) ? YES : NO];
        [self updateSnapButtonForCurrentState];
    }
}

/*
 *  When a camera error occurs in the backdrop, this method is called.
 */
-(void) backdropView:(UINewSealBackdropView *)pv cameraFailedWithError:(NSError *)err
{
    NSLog(@"CS:  New seal backdrop error.  %@", [err localizedDescription]);
    
    NSString *sError = nil;
    if ([ChatSeal isLowStorageAConcern]) {
        sError = [NSString stringWithFormat:NSLocalizedString(@"Your %@'s camera is malfunctioning, possibly due to low storage, and will be disabled.", nil), [[UIDevice currentDevice] model]];
    }
    else {
        sError = [NSString stringWithFormat:NSLocalizedString(@"Your %@'s camera is malfunctioning and will be disabled.", nil), [[UIDevice currentDevice] model]];
    }
    
    [AlertManager displayErrorAlertWithTitle:@"Camera is Offline" andText:sError];
    isCameraRestricted = YES;
    [self setCameraMode:NO];
}

/*
 *  The snap button changes based on whether we use it to switch to the camera or 
 *  take a photo.
 */
-(void) updateSnapButtonForCurrentState
{
    //  - in restricted mode, the default behavior is just fine.
    if (isCameraRestricted) {
        return;
    }
    
    if ([backdrop isCameraActive]) {
        [(UICleanCameraButtonV2 *) snapPhotoButton setCameraActive:NO];
    }
    else {
        [(UICleanCameraButtonV2 *) snapPhotoButton setCameraActive:YES];
    }
}

/*
 *  Track the rotation of the device manually since we've disabled the view controller's basic behavior.
 */
-(void) notifyRotated
{
    currentOrientation = [ChatSeal currentDeviceOrientation];
    [self updateElementsForRotation];
}

/*
 *  Return the rotation value for the specified device orientation.
 */
-(CGFloat) elementRotationForOrientation:(UIDeviceOrientation) orient
{
    CGFloat rotation = 0.0f;
    switch (orient) {
        case UIDeviceOrientationPortrait:
        case UIDeviceOrientationPortraitUpsideDown:
        default:
            rotation = 0.0f;
            break;
            
        case UIDeviceOrientationLandscapeLeft:
            rotation = ((CGFloat) M_PI/2.0f);
            break;
            
        case UIDeviceOrientationLandscapeRight:
            rotation = -((CGFloat) M_PI/2.0f);
            break;
    }
    return rotation;
}

/*
 *  Using the current rotation, updates the elements in the window.
 */
-(void) updateElementsForRotation
{
    CGFloat rotation = [self elementRotationForOrientation:currentOrientation];
    
    // - first adjust the controls that are visible in edit mode.
    if (uiElementOrientation != currentOrientation) {
        [backdrop setDisplayRotation:rotation withAnimation:YES];

        // - animate the layer-specific items.
        [UIView animateWithDuration:[ChatSeal standardRotationTime] delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^(void){
            CGAffineTransform at       = CGAffineTransformMakeRotation(rotation);
            snapPhotoButton.transform  = at;
            flipCameraButton.transform = at;
            addPhotoButton.transform   = at;
        } completion:nil];
        uiElementOrientation       = currentOrientation;
    }

    // - the seal collection must be updated a little differently because if we're editing,
    //   we cannot force the frosted glass to regenerate, so we'll only rotate the center
    //   when editing and then rotate the rest upon completion.
    if (isEditing) {
        if (activeCellOrientation != currentOrientation) {
            // - update the rotation in the currently visible cell so that
            //   when we contract the editor, the images line up.
            [[self currentSealCell] setCenterRotation:rotation];
            activeCellOrientation = currentOrientation;
        }
    }
    else {
        if (sealCollectionOrientation != currentOrientation) {
            [UIView animateWithDuration:[ChatSeal standardRotationTime] delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
                for (UINewSealCell *nsc in sealCollection.visibleCells) {
                    [nsc setCenterRotation:rotation];
                }
            } completion:nil];
        }
        sealCollectionOrientation = activeCellOrientation = currentOrientation;
    }
}

/*
 *  Display the photo selection dialog.
 */
-(void) showDefaultPhotoSelectionWithCompletion:(void (^)(void)) presentationCompletion
{
    UIImagePickerController *ipc = [[UIImagePickerController alloc] init];
    ipc.allowsEditing            = NO;
    ipc.sourceType               = UIImagePickerControllerSourceTypePhotoLibrary;
    ipc.delegate                 = self;
    [self presentViewController:ipc animated:YES completion:presentationCompletion];
}

/*
 *  Dismiss the image picker.
 */
-(void) imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

/*
 *  When an image is chosen, dismiss the picker and set th eimage.
 */
-(void) imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    // - get the image they chose.
    UIImage *img = [info objectForKey:UIImagePickerControllerEditedImage];
    if (!img) {
        img = [info objectForKey:UIImagePickerControllerOriginalImage];
    }
    
    // - dismiss the picker and assign the new seal image.
    [self dismissViewControllerAnimated:YES completion:^(void){
        // - we don't want to allow the person to exit edit mode until the image
        //   is presented, but to disable it outright will draw the eye away from
        //   its transition.  This boolean will control whether it functions.
        ignoreDoneButton = YES;
        [CATransaction begin];
        [CATransaction setCompletionBlock:^(void){
            ignoreDoneButton = NO;
        }];
        [self setNewSealImage:img withAnimation:YES];
        [CATransaction commit];
    }];
}

/*
 *  Set the timeout for the gloss timer to be some random time in the future.
 */
-(void) advanceGlossTimeout
{
    // - adjust the timeout for the next run
    CGFloat rDiff = ((CGFloat)(rand()%100)/100.0f);
    [glossTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:UINSVC_BASE_GLOSS_TIME + (rDiff * UINSVC_GLOSS_ADJ)]];
}

/*
 *  Display gloss if applicable.
 */
-(void) glossTimeout
{
    [self advanceGlossTimeout];
    if (!showGloss || [backdrop hasSealImage]) {
        return;
    }
    
    // - trigger the gloss effect in the current cell.
    [[self currentSealCell] triggerGlossEffect];
}

/*
 *  Return the current cell.
 */
-(UINewSealCell *) currentSealCell
{
    return (UINewSealCell *) [sealCollection cellForItemAtIndexPath:[NSIndexPath indexPathForItem:currentSealStyle inSection:0]];
}

/*
 *  We entered the background.
 */
-(void) notifyDidBackground
{
    // - the backdrop needs to discard its AV handles now because if we change the Restrictions, they will
    //   cause an assertion when they are released.
    [backdrop prepareForBackground];
}

/*
 *  Watch the foreground events to update the toolbar icon.
 */
-(void) notifyForeground
{
    // - I learned elsewhere that the AV foundation responds to a foreground notification also, so if
    //   we try to reload the camera now, it may have stale content until the runloop is clear.  This
    //   becomes important if we're turning off camera restrictions, for example.didT
    [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
        [self updatePhotoLibraryButton];
        
        // - always allow the backdrop to get back to business after moving to the foreground.
        [backdrop resumeForeground];
        
        // - make sure the buttons still make sense.
        BOOL newIsRestricted = ![ChatSeal hasAnyCamera];
        if (newIsRestricted != isCameraRestricted) {
            isCameraRestricted = newIsRestricted;
            if (isCameraRestricted && ![UIPhotoLibraryAccessViewController photoLibraryIsOpen] && isEditing) {
                [self setEditModeEnabled:NO withAnimation:YES];
            }
        }
        
        // - force a reset of buttons states after we know all the new
        //   camera availability information.
        [self updateToolButtonStatesForEnabled:isEditing];
        [self updateSnapButtonForCurrentState];
    }];
}

/*
 *  Where possible, use a real photo for the photo library button.
 */
-(void) updatePhotoLibraryButton
{
    [ChatSeal thumbForPhotoLibraryIfOpen:^(UIImage *thumb) {
        UIImage *img = nil;
        if (thumb) {
            img = [thumb imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        }
        else {
            img = [UIImage imageNamed:@"705-photos.png"];
        }
        [addPhotoButton setImage:img forState:UIControlStateNormal];
    }];
    
    // - add a slight border
    addPhotoButton.layer.borderWidth = 1.0f/[UIScreen mainScreen].scale;
    addPhotoButton.layer.borderColor = [[UIColor colorWithWhite:0.6f alpha:0.4f] CGColor];
}

/*
 *  Animate a turn position change.
 */
-(void) setAnimatedTurnForCell:(UINewSealCell *) nsc andLocked:(BOOL)isLocked
{
    [UIView animateWithDuration:[ChatSeal standardRotationTime] delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut animations:^(void){
        [nsc setLocked:isLocked];
    }completion:nil];
}

/*
 *  Turn the creation behavior on/off
 */
-(void) setCreationStateEnabled:(BOOL) creationEnabled
{
    creationStarted                       = creationEnabled;
    [[self.navigationItem leftBarButtonItem] setEnabled:!creationEnabled];
    [[self.navigationItem rightBarButtonItem] setEnabled:!creationEnabled];
    sealCollection.userInteractionEnabled = !creationEnabled;
    backdrop.userInteractionEnabled       = !creationEnabled;
    backdrop.hidden                       = creationEnabled;
}

/*
 *  The dynamic type in the app should be adjusted.
 */
-(void) updateDynamicTypeNotificationReceived
{
    [self reconfigureDynamicTypeDuringInit:NO];
}

/*
 *  Reconfigure the dynamic type in this view.
 */
-(void) reconfigureDynamicTypeDuringInit:(BOOL) isInit
{
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        return;
    }
    
    [UIAdvancedSelfSizingTools constrainTextLabel:self.description withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextLabel:self.editDescription withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
    
    // - update the placeholder text in the cells and the backdrop
    [backdrop updateDynamicTypeNotificationReceived];
    for (UINewSealCell *nsc in sealCollection.visibleCells) {
        [nsc updateDynamicTypeNotificationReceived];
    }
}
@end