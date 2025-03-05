//
//  ChatSeal.m
//  ChatSeal
//
//  Created by Francis Grolemund on 9/20/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#include <sys/utsname.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <AudioToolbox/AudioToolbox.h>
#import "AppDelegateV2.h"
#import "ChatSeal.h"
#import "UIImage+ImageEffects.h"
#import "UIPhotoCaptureView.h"
#import "UIAddPhotoSignView.h"
#import "UINewSealCell.h"
#import "CS_cacheSeal.h"
#import "CS_cacheMessage.h"
#import "UIImageGeneration.h"
#import "CS_diskCache.h"
#import "ChatSealIdentity.h"
#import "ChatSealVaultPlaceholder.h"
#import "ChatSealBaseStation.h"
#import "CS_secureTransferServer.h"
#import "ChatSealFeedCollector.h"
#import "UISealedMessageEnvelopeViewV2.h"
#import "CS_sha.h"

// - standard constants
static NSString *CS_UNSET_VAULT_PWD                 = @"`*~";
static NSString *CS_DEF_PWDSET                      = @"ReqAuth";
static NSString *CS_DEF_ACTIVESEAL                  = @"ActiveSeal";
static NSString *CS_DEF_ONEMSG                      = @"ExperiencedMessaging";
static NSString *CS_DEF_XFERSEAL                    = @"TransferredSeal";
static NSString *CS_DEF_SHAREFEEDS                  = @"ShareFeedsWithSeals";
static NSString *CS_DEF_SHOWEDFEEDWARNING           = @"ShowedFeedWarning";
static NSString *CS_DEF_RESETFEEDWARNING            = @"ResetFeedWarning";
static NSString *CS_DEF_CACHEEPOCH                  = @"CacheEpoch";
static NSString *CS_DEF_COLLFIRSTTIME               = @"CollectorFirstTimeCompleted";
static NSString *CS_DEF_HASASKEDNOTIFYPERM          = @"HasAskedForNotifyPermission";
static NSString *CS_DEF_FEED_ALERTED                = @"LastFeedAlertedState";
static const NSUInteger CS_LOW_FS_SIZE              = 1024*1024 * 5;    //  when we're below 5MB on the device, things get wonky fast.
static const NSTimeInterval CS_EXPIRE_CHECK_TIMEOUT = 60.0f * 60.0f;    //  nothing terribly extreme either way, but we'll check it from time to time.
static NSString *CS_ALERT_CATEGORY                  = @"CSAlert";
static NSString *CS_ALERT_ACTION                    = @"CSAlertView";

// - notifications
NSString *kChatSealNotifyLowStorageResolved               = @"com.realproven.csn.hasdisk";
NSString *kChatSealNotifyNetworkChange                    = @"com.realproven.csn.net.change";
NSString *kChatSealNotifyNearbyUserChange                 = @"com.realproven.csn.user.proximity";
NSString *kChatSealNotifySealTransferStatus               = @"com.realproven.csn.bs-sealxfer";
NSString *kChatSealNotifySecureURLHasChanged              = @"com.realproven.csn.bs-secureurl";
NSString *kChatSealNotifyApplicationURLUpdated            = @"com.realproven.csn.app.url";
NSString *kChatSealNotifySealInvalidated                  = @"com.realproven.csn.seal.inval";
NSString *kChatSealNotifySealArrayKey                     = @"seals";
NSString *kChatSealNotifySealImported                     = @"com.realproven.csn.seal.import";
NSString *kChatSealNotifySealRenewed                      = @"com.realproven.csn.seal.renew";
NSString *kChatSealNotifySealCreated                      = @"com.realproven.csn.seal.create";
NSString *kChatSealNotifyMessageImported                  = @"com.realproven.csn.msg.import";
NSString *kChatSealNotifyMessageImportedMessageKey        = @"msg";
NSString *kChatSealNotifyMessageImportedEntryKey          = @"entry";
NSString *kChatSealNotifyFeedTypesUpdated                 = @"com.realproven.csn.feedt.query";
NSString *kChatSealNotifyFeedRefreshCompleted             = @"com.realproven.csn.feed.refresh";
NSString *kChatSealNotifyFeedUpdate                       = @"com.realproven.csn.feed.progress";
NSString *kChatSealNotifyFeedUpdateFeedKey                = @"feed";
NSString *kChatSealNotifyFeedPostProgress                 = @"com.realproven.csn.feed.postprog";
NSString *kChatSealNotifyFeedPostProgressItemKey          = @"item";
NSString *kChatSealNotifyFriendshipsUpdated               = @"com.realproven.csn.friendsupd";
NSString *kChatSealNotifyFeedFriendshipUpdated            = @"com.realproven.csn.feed.friendupd";
NSString *kChatSealNotifyFeedFriendshipFeedKey            = @"feed";
NSString *kChatSealNotifyFeedCollectionDormant            = @"com.realproven.csn.dormant";
NSString *KChatSealNotifyFeedCollectionDormantMessagesKey = @"msgs";
NSString *kChatSealNotifyInitialStylingCompleted          = @"com.realproven.csn.init.styling.done";


// - local data
static ChatSeal *psGlobal                           = nil;
static NSOperationQueue *opQUserInterfacePopulation = nil;
static NSOperationQueue *opQVaultProcessing         = nil;
static BOOL cameraQueried                           = NO;
static BOOL hasFrontCamera                          = NO;
static BOOL hasBackCamera                           = NO;
static UIDeviceOrientation currentOrientation       = UIDeviceOrientationPortrait;
static UIImage *photoLibThumb                       = nil;
static NSInteger currentCacheEpoch                  = -1;
static ChatSealBaseStation *baseStation             = nil;
static NSURL *startupURL                            = nil;
static BOOL firstTimeExpirationCheckOccurred        = NO;
static NSUInteger alertBadgeUpdates                 = 0;
static ChatSealFeedCollector *feedCollector         = nil;
static void (^backgroundURLCompletion)(void)        = nil;
static BOOL vaultWasJustCreated                     = NO;
static NSInteger desiredApplicationBadgeValue       = 0;
static BOOL hasCompletedInitialStyling              = NO;
static NSTimeInterval tiAppStart                    = 0;
#ifdef CHATSEAL_DEBUG_LOG_TAB
static NSMutableArray *maDebugLog                   = nil;
#endif

// - forward declarations
@interface ChatSeal (internal) <UIAlertViewDelegate>
-(id) initWithNotifications;
-(void) notifyOrientationChanged:(NSNotification *) notification;
-(void) notifyWillEnterForeground:(NSNotification *) notification;
-(void) notifyWillResignActive:(NSNotification *) notification;
-(void) notifyDidBecomeActive:(NSNotification *) notification;
-(void) notifyWillTerminate:(NSNotification *) notification;
-(void) notifyInitialStylingComplete;
+(BOOL) setActiveSeal:(NSString *) sid andSkipVerification:(BOOL) skipVerify withError:(NSError **) err;
+(BOOL) resetAllUserConfiguration;
+(void) reconfigureBaseStationForBroadcast;
-(void) expirationTimer:(NSTimer *) timer;
+(void) checkForSealExpiration;
-(void) prepareToDisplayFeedShareWarningWithCompletionBlock:(void(^)(void)) completionBlock;
-(void) setFeedShareWarningCompletionBlock:(void(^)(void)) completionBlock;
+(UIColor *) highlightColorFromSealColor:(RSISecureSeal_Color_t) color;
+(BOOL) destroyAllFeedContentWithError:(NSError **) err;
@end

//  - interface into messaging
@interface ChatSealMessage (shared)
+(ChatSealMessage *) createMessageOfType:(ps_message_type_t) mtype usingSeal:(NSString *) sealId withDecoy:(UIImage *) decoy andData:(NSArray *) msgData
                           onCreationDate:(NSDate *) dtCreated andError:(NSError **) err;
+(NSArray *) messageListForSearchCriteria:(NSString *) searchString withItemIdentification:(BOOL(^)(ChatSealMessage *)) itemIdentified andError:(NSError **) err;
+(ChatSealMessage *) importMessageIntoVault:(NSData *) dMessage andSetDefaultFeed:(NSString *) feedId andReturnUserData:(NSObject **) userData withError:(NSError **) err;
+(BOOL) isPackedMessageCurrentlyKnown:(NSData *) dMessage;
+(BOOL) isPackedMessageHashCurrentlyKnown:(NSString *) sHash;
+(ChatSealMessage *) bestMessageForSeal:(NSString *) sid andAuthor:(NSString *) author;
+(ChatSealMessage *) messageForId:(NSString *) mid;
@end

//  - interface into the identity management
@interface ChatSealIdentity (shared)
+(id) identityForSealId:(NSString *) sid withError:(NSError **) err;
+(id) identityForCacheSeal:(CS_cacheSeal *) cs withError:(NSError **) err;
+(NSString *) createIdentityWithImage:(UIImage *) imgSeal andColor:(RSISecureSeal_Color_t) color andError:(NSError **) err;
+(NSString *) importIdentityWithData:(NSData *) dExported usingPassword:(NSString *) pwd andError:(NSError **) err;
+(BOOL) permanentlyDestroyIdentity:(NSString *) sealId withError:(NSError **) err;
@end

// - this macro makes it possible to quickly pull colors in frokm an app like Hues that will generate the RGB triplet.
#ifdef rgb
#undef rgb
#endif
#define rgb(r, g, b)        [UIColor colorWithRed:((float) r)/255.0f green:((float) g)/255.0f blue:((float) b)/255.0f alpha:1.0f]

/*********************
 ChatSeal
 *********************/
@implementation ChatSeal
/*
 *  Object attributes
 */
{
    BOOL handlingFeedShareAlert;
    void (^sharedFeedWarningCompletion)();
}

/*
 *  Global initialization.
 */
+(void) initialize
{
    tiAppStart = [[NSDate date] timeIntervalSinceReferenceDate];
    psGlobal   = [[ChatSeal alloc] initWithNotifications];
    
    //  - cache the most often used colors
    [ChatSeal defaultAppTintColor];
    for (RSISecureSeal_Color_t color = 0; color < RSSC_NUM_SEAL_COLORS; color++) {
        [ChatSeal primaryColorForSealColor:color];
    }
    [ChatSeal defaultSupportingTextColor];
    
    
    //  - make sure that a public/private keypair is available for
    //    the first seal.
    [RealSecureImage prepareForSealGeneration];
    
    //  - create a base station for coordinating between devices.
    baseStation = [[ChatSealBaseStation alloc] init];
    
    //  - mange feeds
    feedCollector = [[ChatSealFeedCollector alloc] init];
    
    // - under iOS8, user defaults are not deleted if the app is deleted, so we're going
    //   to ensure that they are when the vault is not present.
    if ([ChatSeal isIOSVersionGREQUAL8] && ![ChatSeal hasVault]) {
        [ChatSeal resetAllUserConfiguration];
    }
    
#ifdef CHATSEAL_DEBUG_LOG_TAB
    maDebugLog = [[NSMutableArray alloc] init];
#endif
}

/*
 *  Return the dimensions of the application window.
 */
+(CGSize) appWindowDimensions
{
    CGSize sz = [UIApplication sharedApplication].keyWindow.bounds.size;
    if (sz.width < 1.0f || sz.height < 1.0f) {
        sz = [UIScreen mainScreen].bounds.size;
    }
    if (sz.width < sz.height && UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation)) {
        CGFloat tmp = sz.width;
        sz.width    = sz.height;
        sz.height   = tmp;
    }
    return sz;
}

/*
 *  Using the application storyboard, return a handle to the
 *  view controller with the requested id.
 */
+(id) viewControllerForStoryboardId:(NSString *) sbid
{
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"CS_iphone" bundle:nil];
    if (sbid) {
        return [sb instantiateViewControllerWithIdentifier:sbid];
    }
    else {
        return [sb instantiateInitialViewController];
    }
}

/*
 *  This is the tint color for the app.
 */
+(UIColor *) defaultAppTintColor
{
    if ([[UIApplication sharedApplication] keyWindow].tintColor) {
        return [[UIApplication sharedApplication] keyWindow].tintColor;
    }
    else {
        static UIColor *cTint = nil;
        if (!cTint) {
            // - the app tint is based on the hue of the blue seal, but is intended to look
            //   somewhat subdued by comparison.
            UIColor *c = [ChatSeal primaryColorForSealColor:RSSC_STD_BLUE];
            cTint = [[UIImageGeneration adjustColor:c byHuePct:1.0f andSatPct:1.01f andBrPct:0.78f andAlphaPct:1.0f] retain];
        }
        return [[cTint retain] autorelease];
    }
}

/*
 *  Return the color of the editor background.
 */
+(UIColor *) defaultEditorBackgroundColor
{
    return [UIColor colorWithRed:0.98f green:0.98f blue:0.98f alpha:1.0f];
}

/*
 *  Return the color for extra tools.
 */
+(UIColor *) defaultToolBackgroundColor
{
    return [UIColor colorWithWhite:0.93f alpha:0.95f];
}

/*
 *  When advanced chrome is not available, this color will be used as a frosted facsimile color.
 */
+(UIColor *) defaultLowChromeFrostedColor
{
    return [UIColor colorWithRed:230.0f/255.0f green:230.0f/255.0f blue:230.0f/255.0f alpha:0.95f];
}

/*
 *  When advanced chrome is not available, this color will be used as a frosted facsimile color.
 *  - this is intended to really obscure the content when used.
 */
+(UIColor *) defaultLowChromeUltraFrostedColor
{
    return [UIColor colorWithRed:230.0f/255.0f green:230.0f/255.0f blue:230.0f/255.0f alpha:0.98f];
}

/*
 *  When advanced chome is not available, this color will be used for the standard shadow over 
 *  prior content.
 */
+(UIColor *) defaultLowChromeShadowColor
{
    return [UIColor colorWithRed:85.0f/255.0f green:85.0f/255.0f blue:85.0f/255.0f alpha:0.60f];
}

/*
 *  The dark shadow color is used in places where we want to obscure the background while we do
 *  some sort of prominent foreground operation like editing.  We want to focus the viewer's attention
 *  the foreground in a serious way.
 */
+(UIColor *) defaultLowChromeDarkShadowColor
{
    return [UIColor colorWithRed:50.0f/255.0f green:50.0f/255.0f blue:50.0f/255.0f alpha:0.60f];
}

/*
 *  Configure a label to look good with the low chrome shadow text.
 */
+(void) defaultLowChromeShadowTextLabelConfiguration:(UILabel *) l
{
    // - I'm shooting for a little glow and not a stark white, not so much that it is clear what you're seeing
    //   but enough that it pops on the low chrome and draws the eye.
    l.textColor    = [UIColor colorWithRed:252.0f/255.0f green:249.0f/255.0f blue:237.0f/255.0f alpha:1.0f];
    l.shadowColor  = [UIColor darkGrayColor];
    CGFloat scale  = [UIScreen mainScreen].scale;
    l.shadowOffset = CGSizeMake(1.0f/scale, 1.0f/scale);
}

/*
 *  This color is used to represent paper items and should be a little off white.
 */
+(UIColor *) defaultPaperColor
{
    return [UIColor colorWithWhite:0.98f alpha:1.0f];
}

/*
 *  Supporting text is intended to not dominate the display, but be available for some detail.
 */
+(UIColor *) defaultSupportingTextColor
{
    // - make sure the NIB is kept up to date with this
    static UIColor *cSupporting = nil;
    if (!cSupporting) {
        cSupporting = [[UIColor colorWithWhite:154.0f/255.0f alpha:1.0f] retain];
    }
    return [[cSupporting retain] autorelease];
}

/*
 *  When a seal is invalid, its image will be stylized with a single color.
 */
+(UIColor *) defaultInvalidSealColor
{
    return [ChatSeal defaultSupportingTextColor];
}

/*
 *  A warning color isn't intended to be a harsh slap to the face, but get some attention about an
 *  an issue.  Generally this is best in all but the most extreme cases.
 */
+(UIColor *) defaultWarningColor
{
    static UIColor *cWarning = nil;
    if (!cWarning) {
        // - this color is loosely based on the yellow seal, but it diverges a little bit from the other app colors in that it
        //   is lighter and a bit more saturated because it has to work with the red badge that appears on the tab bar.
        UIColor *c = [ChatSeal primaryColorForSealColor:RSSC_STD_YELLOW];
        cWarning   = [[UIImageGeneration adjustColor:c byHuePct:0.60f andSatPct:1.282f andBrPct:0.80f andAlphaPct:1.0f] retain];
    }
    return [[cWarning retain] autorelease];
}

/*
 *  The color when a header item is selected.
 */
+(UIColor *) defaultSelectedHeaderColor
{
    // - the number of non-seal colors should be fairly limited and not too extreme.
    return [ChatSeal defaultAppTintColor];
}

/*
 *  This color should only be sparingly used when you want to get the user's attention.
 */
+(UIColor *) defaultAppFailureColor
{
    // - there is no red seal so we sort of have to come up with something that looks good with the warning and
    //   other non-seal colors.
    return [UIColor colorWithRed:191.0f/255.0f green:68.0f/255.0f blue:60.0f/255.0f alpha:1.0f];
}

/*
 *  When using the dark shadow on the view to obscure the background, we occasionally add text on top to highlight the
 *  purpose.  This color is used with that shadow and tends to show up well.
 */
+(UIColor *) defaultDarkShadowTextCompliment
{
    return [UIColor whiteColor];
}

/*
 *  Return the color of the icon.
 */
+(UIColor *) defaultIconColor
{
    return [UIColor colorWithRed:0.254f green:0.266f blue:0.294f alpha:1.0f];
}

/*
 *  Return the tint of a switch when it is turned on.
 */
+(UIColor *) defaultSwitchOnColor
{
    // - this is fine-tuned to look like it is consistent with the other non-seal colors, but
    //   is based on the hue of the green seal color.
    UIColor *c = [ChatSeal primaryColorForSealColor:RSSC_STD_GREEN];
    return [UIImageGeneration adjustColor:c byHuePct:1.0f andSatPct:0.915f andBrPct:0.82f andAlphaPct:1.0f];
}

/*
 *  Return the color used for serious actions that must occur.
 */
+(UIColor *) defaultAppSeriousActionColor
{
    // - Apple doesn't let you customize the extreme red it uses for badges or destructive actions, probably
    //   to maintain visual consistency and to shock you into attention when it must occur.  I'm not going to break
    //   with this model, so for those things I've created myself, like a deltion button on a table cell, they must
    //   be this color as well.
    return [UIColor colorWithRed:247.0f/255.0f green:33.0f/255.0f blue:37.0f/255.0f alpha:1.0f];
}

/*
 *  This color is used for the user's chat bubble on the remote side of a conversation.
 */
+(UIColor *) defaultRemoteUserChatColor
{
    return [UIColor colorWithWhite:0.85f alpha:1.0f];
}

/*
 *  Return the text color to display header/footer content clearly.
 */
+(UIColor *) defaultTableHeaderFooterTextColor
{
    return [UIColor colorWithWhite:109.0f/255.0f alpha:1.0f];
}

/*
 *  A stylized application font appears in a few places.
 */
+(NSString *) defaultAppStylizedFontNameAsWeight:(cs_stylized_font_t) fontWeight
{
    // - this font is intended to communicate a 'real' perspective.
    switch (fontWeight) {
        case CS_SF_NORMAL:
            return @"Copperplate";
            break;
            
        case CS_SF_LIGHT:
            return @"Copperplate-Light";
            break;
            
        case CS_SF_BOLD:
            return @"Copperplate-Bold";
            break;
    }
}

/*
 *  Generate a frosted image from the provided image.
 */
+(NSOperation *) generateFrostedImageOfType:(ps_frost_style_t) ftype fromImage:(UIImage *) image withCompletion:(void (^)(UIImage *)) completionBlock
{
    return [ChatSeal generateFrostedImageOfType:ftype fromImage:image atScale:1.0f withCompletion:completionBlock];
}

/*
 *  Generate a frosted image from the given image at the provided scale.
 */
+(NSOperation *) generateFrostedImageOfType:(ps_frost_style_t) ftype fromImage:(UIImage *) image atScale:(CGFloat) scale withCompletion:(void (^)(UIImage *)) completionBlock
{
    NSBlockOperation *bo = [NSBlockOperation blockOperationWithBlock:^(void){
        UIImage *ret = [ChatSeal generateFrostedImageOfType:ftype fromImage:image atScale:scale];
        
        // - make sure the main thread is the one that receives the result
        [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
            completionBlock(ret);
        }];
    }];
    
    // - now send it to the background
    [[ChatSeal uiPopulationQueue] addOperation:bo];
    return bo;
}

/*
 *  Generate a frosted image from the provided view.
 */
+(NSOperation *) generateFrostedImageOfType:(ps_frost_style_t) ftype fromView:(UIView *) view atScale:(CGFloat) scale withCompletion:(void (^)(UIImage *)) completionBlock
{
    // - draw the content in the view and then generate the frosted image.
    UIImage *img = [UIImageGeneration imageFromView:view withScale:1.0f];
    return [ChatSeal generateFrostedImageOfType:ftype fromImage:img atScale:scale withCompletion:completionBlock];
}

/*
 *  Generate a frosted image using the provided tint color.
 */
+(NSOperation *) generateFrostedImageWithTint:(UIColor *) tintColor fromImage:(UIImage *) image withCompletion:(void (^)(UIImage *)) completionBlock
{
    NSBlockOperation *bo = [NSBlockOperation blockOperationWithBlock:^(void){
        UIImage *imgFrosted = [image applyTintEffectWithColor:tintColor];
        
        //  - and make sure the main thread is what receives it.
        [[NSOperationQueue mainQueue] addOperationWithBlock:^(void){
            completionBlock(imgFrosted);
        }];
    }];
    
    //  - now send it to the background for the blur.
    [[ChatSeal uiPopulationQueue] addOperation:bo];
    return bo;
}

/*
 *  Convert the provided image into one of the given type at the given scale.
 */
+(UIImage *) generateFrostedImageOfType:(ps_frost_style_t) ftype fromImage:(UIImage *) image atScale:(CGFloat) scale
{
    if (!image) {
        return nil;
    }
    
    image = [UIImageGeneration image:image scaledTo:scale asOpaque:YES];
    UIImage *imgFrosted = nil;
    switch (ftype) {
        case CS_FS_EXTRA_LIGHT:
            imgFrosted = [image applyExtraLightEffect];
            break;
            
        case CS_FS_LIGHT:
            imgFrosted = [image applyLightEffect];
            break;
            
        case CS_FS_DARK:
            imgFrosted = [image applyDarkEffect];
            break;
            
        case CS_FS_SECURE:
            imgFrosted = [image applyBlurWithRadius:7 tintColor:nil saturationDeltaFactor:1.0 maskImage:nil];
            break;
            
        case CS_FS_SIMPLE_BLUR:
            imgFrosted = [image applyBlurWithRadius:2 tintColor:nil saturationDeltaFactor:1.0 maskImage:nil];
            break;
            
        case CS_FS_UNFOCUSED:
            imgFrosted = [image applyBlurWithRadius:3.5 tintColor:[UIColor colorWithWhite:1.0f alpha:0.8f] saturationDeltaFactor:1.0f maskImage:nil];
            break;
    }
    return imgFrosted;
}

/*
 *  Return a seal wax layer for the given seal color.
 */
+(UISealWaxViewV2 *) sealWaxInForeground:(BOOL) isForeground andColor:(RSISecureSeal_Color_t) color
{
    ChatSealColorCombo *pscc = [ChatSeal sealColorsForColor:color];
    UISealWaxViewV2 *swv = [[UISealWaxViewV2 alloc] init];
    [swv setOuterColor:pscc.cOuter andMidColor:pscc.cMid andInnerColor:pscc.cInner];
    [swv setSealWaxValid:pscc.isValid];
    return [swv autorelease];
}

/*
 *  Returns whether there is a front camera available.
 */
+(BOOL) hasFrontCamera
{
    @synchronized (psGlobal) {
        if ([ChatSeal hasAnyCamera]) {
            return hasFrontCamera;
        }
    }
    return NO;
}

/*
 *  Returns whether a back camera is vailable.
 */
+(BOOL) hasBackCamera
{
    @synchronized (psGlobal) {
        if ([ChatSeal hasAnyCamera]) {
            return hasBackCamera;
        }
    }
    return NO;
}

/*
 *  Returns whether any camera support is available.
 */
+(BOOL) hasAnyCamera
{
    // - this check is called from a background queue during startup.
    @synchronized (psGlobal) {
        if (!cameraQueried) {
            UIPhotoCaptureView *pcv = [[UIPhotoCaptureView alloc] init];
            if ([pcv isFrontCameraAvailable]) {
                hasFrontCamera = YES;
            }
            
            if ([pcv isBackCameraAvailable]) {
                hasBackCamera = YES;
            }
            [pcv release];
            cameraQueried = YES;
        }
        return hasFrontCamera || hasBackCamera;
    }
}

/*
 *  Return the currently recorded device orientation
 *  - excludes face-up/down.
 */
+(UIDeviceOrientation) currentDeviceOrientation
{
    return currentOrientation;
}

/*
 *  Cache app content that is generated.
 */
+(void) cacheAppResources
{
    //  - because the wax throughout, we're going to generate its content
    //    synchronously to ensure there is never a case where we race starting up.
    [UISealWaxViewV2 verifyResources];
    
    //  - do these things in the background because they will finish before
    //    the storyboard is loaded and the initial view is created.
    [[ChatSeal uiPopulationQueue] addOperationWithBlock:^(void) {
        [ChatSeal hasAnyCamera];;
        [ChatSeal thumbForPhotoLibraryIfOpen:nil];
    }];
}

/*
 *  Any resources that are non-essential can be released here.
 */
+(void) clearCachedContent
{
    [UIAddPhotoSignView releaseGeneratedResources];
    [CS_cacheSeal releaseAllCachedContent];
    [CS_cacheMessage releaseAllCachedContent];
}

/*
 *  If the photo library is accessible, return the 
 */
+(void) thumbForPhotoLibraryIfOpen:(void(^)(UIImage *libThumb)) completionBlock
{
    // - if the thumb already exists, then just return it immediately.
    if (photoLibThumb) {
        if (completionBlock) {
            completionBlock(photoLibThumb);
        }
        return;
    }
    
    // - check if the photo library is open and return if it isn't.
    if ([ALAssetsLibrary authorizationStatus] != ALAuthorizationStatusAuthorized) {
        if (completionBlock) {
            completionBlock(nil);
        }
        return;
    }
    
    // - we don't yet have the thumb, so start looking for it.
    ALAssetsLibrary *alib = [[ALAssetsLibrary alloc] init];
    [alib enumerateGroupsWithTypes: ALAssetsGroupPhotoStream | ALAssetsGroupSavedPhotos | ALAssetsGroupLibrary usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        // - when we're done with the enumeration, then return the thumb.
        if (!group || *stop) {
            [alib autorelease];
            if (completionBlock) {
                completionBlock(photoLibThumb);
            }
            return;
        }
        
        // - don't save a poster for an empty group.
        if (group.numberOfAssets == 0) {
            return;
        }
        
        // - save the current poster.
        [photoLibThumb release];
        photoLibThumb = nil;
        photoLibThumb = [[UIImage imageWithCGImage:group.posterImage] retain];
        
        // - give preference to the saved photos, but if there aren't any, we'll take the
        //   photo stream or the library.
        NSNumber *n = [group valueForProperty:ALAssetsGroupPropertyType];
        if ((int) n.integerValue == ALAssetsGroupSavedPhotos) {
            *stop = YES;
        }
    } failureBlock:^(NSError *err) {
        [alib autorelease];
        NSLog(@"CS: Failed to query the asset library.  %@", [err localizedDescription]);
        if (completionBlock) {
            completionBlock(nil);
        }
    }];
}

/*
 *  Retrieve the dimension of an original seal image.
 */
+(CGFloat) standardSealOriginalSide
{
    return 190.0f;
}

/*
 *  Retrieve the dimension of a seal to be displayed in a generic list.
 */
+(CGFloat) standardSealSideForListDisplay
{
    return 50.0f;
}

/*
 *  Retrieve the dimension for an undecorated seal image for the vault list.
 */
+(CGFloat) standardSealImageSideForVaultDisplay
{
    return 64.0f;
}

/*
 *  Placeholders are used in the UI when the real content isn't available, like
 *  when the vault cannot be unlocked.
 */
+(NSURL *) standardPlaceholderDirectory
{
    NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    u        = [u URLByAppendingPathComponent:@"placeholders"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:[u path]]) {
        if (![[NSFileManager defaultManager] createDirectoryAtPath:[u path] withIntermediateDirectories:YES attributes:nil error:nil]) {
            return nil;
        }
    }
    return u;
}

/*
 *  Returns whether the collector has gone through its initial processing.
 */
+(BOOL) collectorFirstTimeCompletedFlag
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:CS_DEF_COLLFIRSTTIME];
}

/*
 *  Records in the user defaults whether the collector has been initially configured.
 */
+(void) setCollectorFirstTimeFlag:(BOOL) isFirstTime;
{
    [[NSUserDefaults standardUserDefaults] setBool:isFirstTime forKey:CS_DEF_COLLFIRSTTIME];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

/*
 *  Return the value on the application badge, which equates to the number of unread messages.
 */
+(NSInteger) applicationBadgeValue
{
    return [UIApplication sharedApplication].applicationIconBadgeNumber;
}

/*
 *  Do a quick check to see if we can set the application badge.
 */
+(BOOL) canSetApplicationBadge
{
    if ([ChatSeal isIOSVersionGREQUAL8]) {
        UIUserNotificationSettings *uns = [[UIApplication sharedApplication] currentUserNotificationSettings];
        if (uns.types & UIUserNotificationTypeBadge) {
            return YES;
        }
        return NO;
    }
    else {
        return YES;
    }
}

/*
 *  Assign a value to the application badge.
 */
+(void) setApplicationBadgeToValue:(NSInteger) value
{
    // - save off the badge value in case the system doesn't permit it to be set so
    //   that we might have a chance of setting it later.
    desiredApplicationBadgeValue = value;
    
    // - in iOS8 and above, we need permission to set the badge.  If we don't yet have it, we'll
    //   just quietly ignore this request.
    if ([ChatSeal isIOSVersionGREQUAL8]) {
        if (![ChatSeal canSetApplicationBadge]) {
            return;
        }
    }
    
    // - always make sure this happens on the main thread, but don't just assume the
    //   main operation queue should be used because this is called duriing startup and
    //   that adds an unfortunate flicker under 8.0 if you do that automatically.
    if ([[NSThread currentThread] isEqual:[NSThread mainThread]]) {
        [UIApplication sharedApplication].applicationIconBadgeNumber = value;
    }else {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
            [UIApplication sharedApplication].applicationIconBadgeNumber = value;
        }];
    }
}

/*
 *  Check if we're allowed to send alerts to the user.
 */
+(BOOL) canIssueLocalAlerts
{
    // - under iOS8, we need permission for sending alerts.
    if ([ChatSeal isIOSVersionGREQUAL8]) {
        UIUserNotificationSettings *uns = [[UIApplication sharedApplication] currentUserNotificationSettings];
        if (uns.types & UIUserNotificationTypeAlert) {
            return YES;
        }
        return NO;
    }
    else {
        return YES;
    }
}

/*
 *  Alert the user if we are allowed.
 */
+(void) issueLocalAlert:(UILocalNotification *) localNotify
{
    if (![ChatSeal canIssueLocalAlerts]) {
        return;
    }
    
    // - when sounds are disabled, make sure we don't try to send one in case the system rejects the whole
    //   thing.
    if (![ChatSeal canPlaySounds]) {
        localNotify.soundName = nil;
    }
    
    // - same with the badge.
    if (![ChatSeal canSetApplicationBadge]) {
        localNotify.applicationIconBadgeNumber = 0;
    }
    
    // - assign the proper category
    if ([ChatSeal isIOSVersionGREQUAL8]) {
        localNotify.category = CS_ALERT_CATEGORY;
    }
    
    // - for some reason under 7.1 the notification won't be shown unless we
    //   delay the presentation.
    // - under 8.1 we can present now, but I'd like to avoid two different paths here
    //   because the notifications are very hard to test reliably in conjuction with the
    //   background fetch in a real scenario.
    localNotify.fireDate = [NSDate dateWithTimeIntervalSinceNow:3];
    
    // - let the application present the alert, but make sure the main thread gets it.
    UIApplication *app = [UIApplication sharedApplication];
    if ([[NSThread currentThread] isEqual:[NSThread mainThread]]) {
        [app scheduleLocalNotification:localNotify];
    }
    else {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
            [app scheduleLocalNotification:localNotify];
        }];
    }
}

/*
 *  Check if we're allowed to play sounds for the user.
 */
+(BOOL) canPlaySounds
{
    if ([ChatSeal isIOSVersionGREQUAL8]) {
        UIUserNotificationSettings *uns = [[UIApplication sharedApplication] currentUserNotificationSettings];
        if (uns.types & UIUserNotificationTypeSound) {
            return YES;
        }
        return NO;
    }
    else {
        return YES;
    }
}

/*
 *  Returns whether we've asked for permission to notify the user.  We track this because we don't necessarily
 *  want to present the request until they know they can get something useful from us.
 */
+(BOOL) hasAskedForLocalNotificationPermission
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:CS_DEF_HASASKEDNOTIFYPERM];
}

/*
 *  Request permission to use local notifications if we haven't already.
 */
+(void) checkForLocalNotificationPermissionsIfNecesssary
{
    // - this is only necessary under iOS8
    if ([ChatSeal isIOSVersionBEFORE8]) {
        return;
    }
    
    static BOOL hasBeenAsked = NO;
    if (hasBeenAsked) {
        return;
    }
    
    // - don't do this in the background
    if (![ChatSeal isApplicationForeground]) {
        return;
    }

    UIMutableUserNotificationCategory *cat  = [[[UIMutableUserNotificationCategory alloc] init] autorelease];
    cat.identifier                          = CS_ALERT_CATEGORY;
    UIMutableUserNotificationAction *action = [[[UIMutableUserNotificationAction alloc] init] autorelease];
    action.identifier                       = CS_ALERT_ACTION;
    action.title                            = NSLocalizedString(@"View", nil);
    action.activationMode                   = UIUserNotificationActivationModeForeground;
    action.authenticationRequired           = YES;
    action.destructive                      = NO;
    [cat setActions:[NSArray arrayWithObject:action] forContext:UIUserNotificationActionContextDefault];
    [cat setActions:[NSArray arrayWithObject:action] forContext:UIUserNotificationActionContextMinimal];
    UIUserNotificationSettings *uns         = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert
                                                                                categories:[NSMutableSet setWithObject:cat]];
    [[UIApplication sharedApplication] registerUserNotificationSettings:uns];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:CS_DEF_HASASKEDNOTIFYPERM];
    
    // - don't do this again in this application cycle.
    hasBeenAsked                            = YES;
}

/*
 *  In iOS, the standard dimension for something to be touched is 44.0.  We'll use this
 *  in different places.
 */
+(CGFloat) minimumTouchableDimension
{
    return 44.0f;
}

/*
 *  When using advanced self-sizing, keep the fonts consistent with the system fonts and
 *  never let them diminish too far.
 */
+(CGFloat) minimumButtonFontSize
{
    return 18.0f;
}

/*
 *  Return the scaling factor when scaling up the UITextFontStyleBody to a slightly larger version.
 */
+(CGFloat) superBodyFontScalingFactor
{
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        return 1.10f;
    }
    else {
        return 1.0f;
    }
}

/*
 *  Return the scaling factor when scaling up the UITextFontStyleBody to a much larger version.
 */
+(CGFloat) superDuperBodyFontScalingFactor
{
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        return 1.20f;
    }
    else {
        return 1.0f;
    }
}

/*
 *  Compute the device's portrait width.
 */
+(CGFloat) portraitWidth
{
    static CGFloat portraitWidth = -1.0f;
    if (portraitWidth < 0.0f) {
        CGSize size   = [UIScreen mainScreen].bounds.size;
        portraitWidth = MIN(size.width, size.height);
    }
    return portraitWidth;
}

/*
 *  There are critical times in the app where we want to prevent ever returning to a prior
 *  cached state - mainly when seals are revoked or discarded.   This epoch value is used
 *  to ensure that anything that doesn't match is discarded immediately.  That ensures if
 *  the cache gets out of synch, either accidentally, or more likely intentionally, it is never
 *  used.
 */
+(NSInteger) cacheEpoch
{
    @synchronized (psGlobal) {
        if (currentCacheEpoch == -1) {
            currentCacheEpoch = [[NSUserDefaults standardUserDefaults] integerForKey:CS_DEF_CACHEEPOCH];
        }
        return currentCacheEpoch;
    }
}

/*
 *  Force the global cache epoch to be updated.
 */
+(void) incrementCurrentCacheEpoch
{
    @synchronized (psGlobal) {
        if (currentCacheEpoch == -1) {
            [ChatSeal cacheEpoch];
        }
        currentCacheEpoch++;
        [[NSUserDefaults standardUserDefaults] setInteger:currentCacheEpoch forKey:CS_DEF_CACHEEPOCH];
    }
}

/*
 *  Return a previously cached data item at the given base and category.
 */
+(NSData *) cachedDataWithBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    return [CS_diskCache cachedDataWithBaseName:baseName andCategory:category];
}

/*
 *  Cache a data item at the given base and category.
 */
+(BOOL) saveCachedData:(NSData *) obj withBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    return [CS_diskCache saveCachedData:obj withBaseName:baseName andCategory:category];
}

/*
 *  Invalidate a data item at the given base and category.
 */
+(void) invalidateCacheItemWithBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    [CS_diskCache invalidateCacheItemWithBaseName:baseName andCategory:category];
}

/*
 *  Invalidate an entire category.
 */
+(void) invalidateCacheCategory:(NSString *) category
{
    [CS_diskCache invalidateCacheCategory:category];
}

/*
 *  Return the list of all the cached base names in the given category.
 */
+(NSSet *) secureCachedBaseNamesInCategory:(NSString *) category
{
    return [CS_diskCache secureCachedBaseNamesInCategory:category];
}

/*
 *  Return a previously cached data item from the vault at the given base and category.
 */
+(NSObject *) secureCachedDataWithBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    return [CS_diskCache secureCachedDataWithBaseName:baseName andCategory:category];
}

/*
 *  Cache a data item securely at the given base and category.
 */
+(BOOL) saveSecureCachedData:(NSObject *) obj withBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    return [CS_diskCache saveSecureCachedData:obj withBaseName:baseName andCategory:category];
}

/*
 *  Return a cached image from the given location.
 */
+(UIImage *) cachedLossyImageWithBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    return [CS_diskCache cachedLossyImageWithBaseName:baseName andCategory:category];
}

/*
 *  Cache an image into the given location.
 */
+(BOOL) saveLossyImage:(UIImage *) img withBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    return [CS_diskCache saveLossyImage:img withBaseName:baseName andCategory:category];
}

/*
 *  Invalidate a lossy image in the cache.
 */
+(void) invalidateLossyImageWithBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    [CS_diskCache invalidateLossyImageWithBaseName:baseName andCategory:category];
}

/*
 *  Invalidate the entire cache.
 */
+(BOOL) invalidateEntireCache
{
    return [CS_diskCache invalidateEntireCache];
}

/*
 *  Return a cached image.
 */
+(UIImage *) cachedImageWithBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    return [CS_diskCache cachedImageWithBaseName:baseName andCategory:category];
}

/*
 *  Save a non-lossy image in the cache.
 */
+(BOOL) saveImage:(UIImage *) img withBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    return [CS_diskCache saveImage:img withBaseName:baseName andCategory:category];
}

/*
 *  Invalidate a non-lossy image.
 */
+(void) invalidateImageWithBaseName:(NSString *) baseName andCategory:(NSString *) category
{
    [CS_diskCache invalidateImageWithBaseName:baseName andCategory:category];
}

/*
 *  When the app is launched with a URL and it is valid, we'll allow us to jump right
 *  to the scanner.  This method returns the URL if it was set.
 */
+(NSURL *) cachedStartupURL
{
    return [[startupURL retain] autorelease];
}

/*
 *  Assign a value to the startup URL that we cache, but in the interest of avoiding needless
 *  work and possibly processing something that isn't valid, we're going to ensure it is a good
 *  secure URL before saving it.
 */
+(BOOL) setCachedStartupURL:(NSURL *) u
{
    if (![u isEqual:startupURL]) {
        if (!u || [CS_secureTransferServer isValidSecureURL:u]) {
            [startupURL release];
            startupURL = [u retain];
            if (u) {
                [[NSNotificationCenter defaultCenter] postNotificationName:kChatSealNotifyApplicationURLUpdated object:nil];
            }
            return YES;
        }
    }
    return NO;
}

/*
 *  When this app supports background sessions, save the completion handler here so that it
 *  can be called when all tasks complete.
 */
+(void) saveBackgroundSessionCompletionHandler:(void (^)()) completionHandler
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
        if (backgroundURLCompletion) {
            Block_release(backgroundURLCompletion);
            backgroundURLCompletion = nil;
        }
        
        if (completionHandler) {
            backgroundURLCompletion = Block_copy(completionHandler);
        }
    }];
}

/*
 *  If we have a previous completion handler, make sure it is executed and released.
 */
+(void) completeBackgroundSession
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
        if (!backgroundURLCompletion) {
            return;
        }
        backgroundURLCompletion();
        Block_release(backgroundURLCompletion);
        backgroundURLCompletion = nil;
    }];
}

/*
 *  Return the last collector alerted state.
 */
+(BOOL) lastFeedCollectorAlertedState
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:CS_DEF_FEED_ALERTED];
}

/*
 *  Cache the feed collector alerted state so that we can default it
 *  when we can't yet gather status.
 */
+(void) saveFeedCollectorAlertedState:(BOOL) isAlerted
{
    if (isAlerted != [ChatSeal lastFeedCollectorAlertedState]) {
        [[NSUserDefaults standardUserDefaults] setBool:isAlerted forKey:CS_DEF_FEED_ALERTED];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

/*
 *  Converting between these damned coordinate spaces with the keyboard is so inconsistent that I
 *  decided to centralize the logic here.  Apparently this is recommended by Apple for doing the
 *  keyboard frame conversions as per the one response in:
 *  http://stackoverflow.com/questions/2807339/uikeyboardboundsuserinfokey-is-deprecated-what-to-use-instead.
 */
+(CGRect) keyboardRectangle:(CGRect) rc forView:(UIView *) vwTarget
{
    UIWindow *window = [vwTarget isKindOfClass:[UIWindow class]] ? (UIWindow *) vwTarget : [vwTarget window];
    if (!window) {
        window = [[UIApplication sharedApplication] keyWindow];
    }
    return [vwTarget convertRect:[window convertRect:rc fromWindow:nil] fromView:nil];
}

/*
 *  Convert the keyboard rectangle using a notification object.
 */
+(CGRect) keyboardRectangleFromNotification:(NSNotification *) notification usingKey:(NSString *) key forView:(UIView *) vwTarget
{
    if ([key isEqualToString:UIKeyboardFrameBeginUserInfoKey] || [key isEqualToString:UIKeyboardFrameEndUserInfoKey]) {
        NSValue *v = [notification.userInfo objectForKey:key];
        if (v) {
            return [ChatSeal keyboardRectangle:[v CGRectValue] forView:vwTarget];
        }
    }
    return CGRectZero;
}

/*
 *  Return a sorted listing of all items in the directory.
 */
+(NSArray *) sortedDirectoryListForURL:(NSURL *) srcDir withError:(NSError **) err
{
    NSError *tmp = nil;
    NSArray *arrItems = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:srcDir
                                                      includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLCreationDateKey, NSURLIsDirectoryKey, nil]
                                                                         options:NSDirectoryEnumerationSkipsHiddenFiles error:&tmp];
    if (!arrItems) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:[srcDir path]]) {
            [CS_error fillError:err withCode:CSErrorFilesystemAccessError andFailureReason:[tmp localizedDescription]];
            return nil;
        }
        else {
            return [NSArray array];
        }
    }
    
    arrItems = [arrItems sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2){
        NSURL *u1 = (NSURL *) obj1;
        NSURL *u2 = (NSURL *) obj2;
        
        NSDate *d1 = nil;
        NSDate *d2 = nil;
        
        [u1 getResourceValue:&d1 forKey:NSURLCreationDateKey error:nil];
        [u2 getResourceValue:&d2 forKey:NSURLCreationDateKey error:nil];
        
        if (u1 && u2) {
            return [d1 compare:d2];
        }
        else {
            return NSOrderedSame;
        }
    }];
    
    return arrItems;
}

/*
 *  When storage gets low, this method will provide a way to detect it.
 */
+(BOOL) isLowStorageAConcern
{
    NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSDocumentationDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    BOOL ret = NO;
    if (u) {
        NSDictionary *dict = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[u path] error:nil];
        if (dict) {
            NSNumber *nSize = [dict objectForKey:NSFileSystemFreeSize];
            if (nSize && nSize.unsignedLongLongValue < CS_LOW_FS_SIZE) {
                ret = YES;
            }
        }
    }
    return ret;
}

/*
 *  Return a handle to the application hub.
 */
+(UIHubViewController *) applicationHub
{
    AppDelegateV2 *adV2 = (AppDelegateV2 *) [UIApplication sharedApplication].delegate;
    return [adV2 applicationHub];
}

/*
 *  Return an insecure hash for the given data.
 *  - these hashes are used for local storage and are not transmitted over the network unless their 
 *    validity can be confirmed through encryption.
 */
+(NSString *) insecureHashForData:(NSData *) d
{
    if (!d) {
        return nil;
    }
    
    CS_sha *sha = [CS_sha shaHash];
    [sha updateWithData:d];
    return [sha hashAsHex];
}

/*
 *  Return a safe salted version of the string.
 */
+(NSString *) safeSaltedPathString:(NSString *) s withError:(NSError **)err
{
    return [RealSecureImage safeSaltedStringAsHex:s withError:err];
}

/*
 *  Vibrate the device, if supported.  (Phone only).
 */
+(void) vibrateDeviceIfPossible
{
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

/*
 *  Copy the parameters of the given animation for a new keypath.
 */
+(CABasicAnimation *) duplicateAnimation:(CAAnimation *) anim forNewKeyPath:(NSString *) keyPath
{
    CABasicAnimation *animDup = [CABasicAnimation animationWithKeyPath:keyPath];
    animDup.timingFunction    = anim.timingFunction;
    animDup.duration          = anim.duration;
    animDup.beginTime         = anim.beginTime;
    animDup.timeOffset        = anim.timeOffset;
    animDup.speed             = anim.speed;
    return animDup;
}

/*
 *  Return the bounds change animation for the given layer if it exists.
 */
+(CAAnimation *) boundsAnimationForLayer:(CALayer *) l
{
    // - the variant of iOS will dicatate which key to use, although we' may try both.
    CAAnimation *ret    = nil;
    
    // - under iOS8, it appears this is the more common key to use.
    if ([ChatSeal isIOSVersionGREQUAL8]) {
        ret = [l animationForKey:@"bounds.size"];
    }

    // - but if we don't find it, or it is on an earlier platform, we'll fall back.
    if (!ret) {
        ret = [l animationForKey:@"bounds"];
    }
    return ret;
}

/*
 *  Duplicate the animation behavior from the given animation to adjust the given layer.
 */
+(void) duplicateBoundsFromAnimation:(CAAnimation *) anim onLayer:(CALayer *) l toTargetRect:(CGRect) rc
{
    CGRect rcBounds             = CGRectMake(0.0f, 0.0f, rc.size.width, rc.size.height);
    CGPoint ptPosition          = CGPointMake(CGRectGetMinX(rc) + (CGRectGetWidth(rc)/2.0f), CGRectGetMinY(rc) + (CGRectGetHeight(rc)/2.0f));
    CABasicAnimation *animLayer = [ChatSeal duplicateAnimation:anim forNewKeyPath:@"position"];
    if (l.presentationLayer) {
        animLayer.fromValue     = [NSValue valueWithCGPoint:((CALayer *)l.presentationLayer).position];
    }
    else {
        animLayer.fromValue     = [NSValue valueWithCGPoint:l.position];
    }
    animLayer.toValue           = [NSValue valueWithCGPoint:ptPosition];
    [l addAnimation:animLayer forKey:@"position"];
    l.position                  = ptPosition;
    
    animLayer                   = [ChatSeal duplicateAnimation:anim forNewKeyPath:@"bounds"];
    if (l.presentationLayer) {
        animLayer.fromValue     = [NSValue valueWithCGRect:((CALayer *)l.presentationLayer).bounds];
    }
    else {
        animLayer.fromValue     = [NSValue valueWithCGRect:l.bounds];
    }
    animLayer.toValue           = [NSValue valueWithCGRect:rcBounds];
    [l addAnimation:animLayer forKey:@"bounds"];
    l.bounds                    = rcBounds;
}

/*
 *  A common routine for posting seal-related notifications for a single seal.
 */
+(void) notifySealActivityByName:(NSString *) name andSeal:(NSString *) sealId
{
    // - make sure this always occurs on the main thread.
    [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
        NSDictionary *dict = [NSDictionary dictionaryWithObject:[NSArray arrayWithObject:sealId] forKey:kChatSealNotifySealArrayKey];
        [[NSNotificationCenter defaultCenter] postNotificationName:name object:self userInfo:dict];
    }];
}

/*
 *  Trigger the hub to update all the badges.
 */
+(void) updateAlertBadges
{
    @synchronized (psGlobal) {
        alertBadgeUpdates++;
    }
    
    // - make sure this always occurs outside the critical section around the identities
    //   and on the main thread.
    [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
        // - limit the number of badge updates to the last one received so that we can't
        //   accidentally pound on this and queue up a ton of them, which could happen
        //   during seal expiration.
        if (alertBadgeUpdates) {
            alertBadgeUpdates--;
            if (alertBadgeUpdates > 0) {
                return;
            }
        }
        [[ChatSeal applicationHub] updateAlertBadges];
    }];
}

/*
 *  Notify a message was imported.
 */
+(void) notifyMessageImportedWithId:(NSString *) mid andEntry:(NSUUID *) entryId
{
    // - make sure this always occurs on the main thread.
    [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
        NSMutableDictionary *mdNotify = [NSMutableDictionary dictionary];
        if (mid) {
            [mdNotify setObject:mid forKey:kChatSealNotifyMessageImportedMessageKey];
        }
        if (entryId) {
            [mdNotify setObject:entryId forKey:kChatSealNotifyMessageImportedEntryKey];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kChatSealNotifyMessageImported object:nil userInfo:mdNotify];
    }];
}

/*
 *  Post a notification that we should update friendship information.
 */
+(void) notifyFriendshipsUpdated
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
        // - the badge should be recomputed, certainly.
        [[ChatSeal applicationHub] updateFeedAlertBadge];
        [[NSNotificationCenter defaultCenter] postNotificationName:kChatSealNotifyFriendshipsUpdated object:nil userInfo:nil];
    }];
}

/*
 *  This is a quick check to see if we're running in the foreground.
 */
+(BOOL) isApplicationForeground
{
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground) {
        return YES;
    }
    return NO;
}

/*
 *  Used for conditionally adapting the behavior of a screen to older versions (ie. v7.1)
 */
+(BOOL) isIOSVersionBEFORE8
{
    static BOOL hasBeenQueried = NO;
    static BOOL isPriorValue   = NO;
    if (!hasBeenQueried) {
        if ([[[UIDevice currentDevice] systemVersion] floatValue] < 8.0f) {
            isPriorValue = YES;
        }
        hasBeenQueried = YES;
    }
    return isPriorValue;
}

/*
 *  Determine if we're running on a version >= 8.0
 */
+(BOOL) isIOSVersionGREQUAL8
{
    return ![ChatSeal isIOSVersionBEFORE8];
}

/*
 *  Whether or not to use advanced self-sizing and dynamic type content.
 */
+(BOOL) isAdvancedSelfSizingInUse
{
    // - prior to 8.0, dynamic type was a fairly limited thing, so we'll use it as
    //   it was before if we're running on 7.1.
    return [ChatSeal isIOSVersionGREQUAL8];
}

/*
 *  Save a debug log event.
 */
+(void) debugLog:(NSString *) fmt, ...
{
#ifdef CHATSEAL_DEBUG_LOG_TAB
    if (!fmt) {
        return;
    }
    va_list val;
    va_start(val, fmt);
    NSTimeInterval tiNow = [[NSDate date] timeIntervalSinceReferenceDate];
    NSString *sText = [[[NSString alloc] initWithFormat:fmt arguments:val] autorelease];
    sText           = [NSString stringWithFormat:@"+%d: %@", (int) (tiNow - tiAppStart), sText];
    @synchronized (maDebugLog) {
        [maDebugLog addObject:sText];
    }
    va_end(val);
#endif
}

/*
 *  Return the number of retained debug log items.
 */
+(NSUInteger) numberOfDebugLogItems
{
#ifdef CHATSEAL_DEBUG_LOG_TAB
    @synchronized (maDebugLog) {
        return [maDebugLog count];
    }
#else
    return 0;
#endif
}

/*
 *  Return the debug log item at the given index
 */
+(NSString *) debugLogItemAtIndeex:(NSUInteger) index
{
#ifdef CHATSEAL_DEBUG_LOG_TAB
    @synchronized (maDebugLog) {
        if (index < [maDebugLog count]) {
            return [maDebugLog objectAtIndex:index];
        }
        else {
            return @"Invalid debug log index.";
        }
    }
#else
    return nil;
#endif
}

/*
 *  The standard time to fade items in/out.
 */
+(NSTimeInterval) standardItemFadeTime
{
    return 0.5f;
}

/*
 *  The standard time to squeeze items in a list in or out.
 */
+(NSTimeInterval) standardSqueezeTime
{
    return 0.35f;
}

/*
 *  The standard time to rotate user interface elements.
 */
+(NSTimeInterval) standardRotationTime
{
    return 0.3f;
}

/*
 *  This is the standard time that it takes for a tab/toolbar to appear/disappear.
 */
+(NSTimeInterval) standardBarAppearanceTime
{
    return 0.5f;
}

/*
 *  The time it takes to lock/unlock a seal for animation.
 */
+(NSTimeInterval) standardLockDuration
{
    return 0.3f;
}

/*
 *  When we filter content, we don't want to be filtering after every keypress, but
 *  rather when the typing pauses or stops.
 */
+(NSTimeInterval) standardSearchFilterDelay
{
    return 0.75f;
}

/*
 *  When hints slide from off screen, use a standard timing for it.
 */
+(NSTimeInterval) standardHintSlideTime
{
    return 0.5f;
}

/*
 *  Create the seal vault if it hasn't been created yet.
 */
+(BOOL) initializeVaultWithError:(NSError **) err
{
    @synchronized (psGlobal) {
        NSError *tmp = nil;
        BOOL ret     = YES;
        if ([RealSecureImage hasVault]) {
            if (![[NSUserDefaults standardUserDefaults] boolForKey:CS_DEF_PWDSET]) {
                ret = [ChatSeal openVaultWithPassword:nil andError:err];
            }
        }
        else {
            if ([RealSecureImage initializeVaultWithPassword:CS_UNSET_VAULT_PWD andError:&tmp]) {
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:CS_DEF_PWDSET];
                if (![[NSUserDefaults standardUserDefaults] synchronize]) {
                    [CS_error fillError:err withCode:CSErrorVaultNotInitialized andFailureReason:[tmp localizedDescription]];
                    [ChatSeal destroyAllFeedContentWithError:nil];
                    [RealSecureImage destroyVaultWithError:nil];
                    ret = NO;
                }
                vaultWasJustCreated = YES;
            }
            else {
                [CS_error fillError:err withCode:CSErrorVaultNotInitialized andFailureReason:[tmp localizedDescription]];
                ret = NO;
            }
        }
        return ret;
    }
}

/*
 *  Open the vault with the provided password.
 *  - a password of 'nil' is shorthand for the default password.
 */
+(BOOL) openVaultWithPassword:(NSString *) pwd andError:(NSError **) err
{
    @synchronized (psGlobal) {
        if (pwd == nil) {
            pwd = CS_UNSET_VAULT_PWD;
        }
        BOOL ret = [RealSecureImage openVaultWithPassword:pwd andError:err];
        if (ret) {
            [ChatSeal openFeedsIfPossibleWithCompletion:nil];
        }
        return ret;
    }
}

/*
 *  Close the vault, if it is open.
 */
+(void) closeVault
{
    @synchronized (psGlobal) {
        [[ChatSeal applicationFeedCollector] close];
        [RealSecureImage closeVault];
    }
}

/*
 *  This completely wipes out all the content.
 */
+(BOOL) destroyAllApplicationDataWithError:(NSError **) err
{
    @synchronized (psGlobal) {
        NSLog(@"CS-ALERT: Beginning total application data destruction.");
        NSLog(@"CS: Invalidating the disk cache.");
        if (![CS_diskCache invalidateEntireCache]) {
            return NO;
        }
        
        NSLog(@"CS: Discarding the active seal.");
        if (![ChatSeal setActiveSeal:nil withError:err]) {
            return NO;
        }
        
        NSLog(@"CS: Destroying the seal vault.");
        if (![RealSecureImage destroyVaultWithError:err]) {
            return NO;
        }
        
        NSLog(@"CS: Destroying all messages.");
        if (![ChatSealMessage destroyAllMessagesWithError:err]) {
            return NO;
        }
        
        NSLog(@"CS: Destroying all feeds.");
        if (![ChatSeal destroyAllFeedContentWithError:err]) {
            return NO;
        }
        
        NSLog(@"CS: Resetting application configuration.");
        if (![ChatSeal resetAllUserConfiguration]) {
            return NO;
        }
        NSLog(@"CS-ALERT: All ChatSeal data has been discarded successfully.");
        return YES;
    }
}

/*
 *  Returns whether a vault exists.
 *  NOTE:  This is a pretty heavyweight test when the vault hasn't yet been created, so 
 *         be sure it is what you want in those scenarios or the disk will be hammered with
 *         every check.  Once the vault exists, the cost diminished significantly.
 */
+(BOOL) hasVault
{
    return [RealSecureImage hasVault];
}

/*
 *  Returns whether the vault has been opened.
 */
+(BOOL) isVaultOpen
{
    BOOL isOpen = [RealSecureImage isVaultOpen];
    return isOpen;
}

/*
 *  Attempt to open the feed collector and feed processing.
 */
+(BOOL) openFeedsIfPossibleWithCompletion:(void(^)(BOOL success))completionBlock
{
    // - configuration must occur before we can open the feeds through this path and
    //   basically implies that we've educated the person about what the purpose of the feed
    //   integration is used for.
    if (![[ChatSeal applicationFeedCollector] isConfigured]) {
        if (completionBlock) {
            completionBlock(NO);
        }
        return NO;
    }
    
    // - delay the initial query of the feed collector when there is a UI so that when we
    //   reset our privacy warnings, the request alert shouldn't display when the animations
    //   are outstanding.
    BOOL shouldQuery = YES;
    if (!hasCompletedInitialStyling && [ChatSeal isApplicationForeground]) {
        shouldQuery = NO;
    }
    
    // - already open, so don't worry about it any more.
    if ([[ChatSeal applicationFeedCollector] isOpen]) {
        if (completionBlock) {
            completionBlock(YES);
        }
    }
    else {
        [[ChatSeal applicationFeedCollector] openAndQuery:shouldQuery withCompletion:^(ChatSealFeedCollector *collector, BOOL success, NSError *errColl) {
            if (!success) {
                NSLog(@"CS: Failed to open the feed collector.  %@", [errColl localizedDescription]);
            }
            [[ChatSeal applicationHub] updateFeedAlertBadge];
            if (completionBlock) {
                completionBlock(success);
            }
        }];
    }
    return YES;
}

/*
 *  When this is a new installation, it can be useful to know if we just created a new vault.
 */
+(BOOL) wasVaultJustCreated
{
    return vaultWasJustCreated;
}

/*
 *  The UI population queue is used to wait on resources that are necessary for
 *  populating user interfaces in the app.  Since this is shared between windows
 *  it is highly advisable to keep this as clean as possible.
 */
+(NSOperationQueue *) uiPopulationQueue
{
    if (!opQUserInterfacePopulation) {
        opQUserInterfacePopulation = [[NSOperationQueue alloc] init];
        opQUserInterfacePopulation.maxConcurrentOperationCount = 2;         //  these are UI operations after all, so we don't want to overburden it.
    }
    return opQUserInterfacePopulation;
}

/*
 *  The vault operation queue is used to offload vault-related tasks.
 */
+(NSOperationQueue *) vaultOperationQueue
{
    if (!opQVaultProcessing) {
        opQVaultProcessing = [[NSOperationQueue alloc] init];
        opQVaultProcessing.maxConcurrentOperationCount = 3;
    }
    return opQVaultProcessing;
}

/*
 *  Wait for pending vault operations to complete.
 */
+(void) waitForAllVaultOperationsToComplete
{
    [[ChatSeal vaultOperationQueue] waitUntilAllOperationsAreFinished];
}

/*
 *  This method is used to determine if this user has transferred at least one seal to/from this device.
 */
+(BOOL) hasTransferredASeal
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:CS_DEF_XFERSEAL];
}

/*
 *  Returns whether there are seals in the vault.
 */
+(BOOL) hasSeals
{
    return [ChatSealIdentity hasSeals];
}

/*
 *  When a seal has been transferred, this method will update the internal state to reflect it.
 */
+(void) setSealTransferCompleteIfNecessary
{
    if (![ChatSeal hasTransferredASeal]) {
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:CS_DEF_XFERSEAL];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [ChatSeal updateAlertBadges];
    }
}

/*
 *  This flag indicates whether the app has presented the feed share warning yet.
 */
+(BOOL) hasPresentedFeedShareWarning
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:CS_DEF_RESETFEEDWARNING]) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:CS_DEF_SHOWEDFEEDWARNING];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:CS_DEF_RESETFEEDWARNING];
    }
    
    return [[NSUserDefaults standardUserDefaults] boolForKey:CS_DEF_SHOWEDFEEDWARNING];
}

/*
 *  Return the flag indicating whether we are able to share feeds during seal exchanges and messaging.
 */
+(BOOL) canShareFeedsDuringExchanges
{
    if ([ChatSeal hasPresentedFeedShareWarning]) {
        return [[NSUserDefaults standardUserDefaults] boolForKey:CS_DEF_SHAREFEEDS];
    }
    return NO;
}

/*
 *  Change the feed sharing flag on the app.
 */
+(void) setFeedsAreSharedWithSealsAsEnabled:(BOOL) enabled
{
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:CS_DEF_SHAREFEEDS];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:CS_DEF_SHOWEDFEEDWARNING];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

/*
 *  Return the standard text for the feed sharing encouragement.
 */
+(NSString *) genericFeedSharingEncouragement
{
    return NSLocalizedString(@"ChatSeal will help your friends find personal messages when you share your active feed names with them.", nil);
}

/*
 *  Display the feed share warning.
 */
+(void) displayFeedShareWarningIfNecessaryWithDescription:(BOOL) incDesc andCompletion:(void (^)()) completionBlock
{
    if ([ChatSeal hasPresentedFeedShareWarning]) {
        return;
    }
    
    [psGlobal prepareToDisplayFeedShareWarningWithCompletionBlock:completionBlock];
    UIAlertView *av = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"\"ChatSeal\" Would Like to Share Your Feed Names", nil)
                                                 message:incDesc ? [ChatSeal genericFeedSharingEncouragement] : nil
                                                delegate:psGlobal
                                       cancelButtonTitle:NSLocalizedString(@"Don't Allow", nil)
                                       otherButtonTitles:NSLocalizedString(@"OK", nil), nil];
    [av show];
    [av release];
}

/*
 *  Create a new seal for the user and make it the default.
 */
+(NSString *) createSealWithImage:(UIImage *) imgSeal andColor:(RSISecureSeal_Color_t) color andError:(NSError **) err
{
    return [ChatSeal createSealWithImage:imgSeal andColor:color andSetAsActive:YES withError:err];
}

/*
 *  Create a new seal for the user and make it the default.
 */
+(NSString *) createSealWithImage:(UIImage *) imgSeal andColor:(RSISecureSeal_Color_t) color andSetAsActive:(BOOL) makeActive withError:(NSError **) err
{
    NSError *tmp  = nil;
    NSString *sid = [ChatSealIdentity createIdentityWithImage:imgSeal andColor:color andError:err];
    if (sid && (!makeActive || [ChatSeal setActiveSeal:sid andSkipVerification:YES withError:&tmp])) {
        // - once we create a seal, make sure the base station is updated to reflect the new situation
        if (![[ChatSeal applicationBaseStation] setNewUserState:NO withError:&tmp]) {
            NSLog(@"CS: Failed to update the application base station after creating a new seal.  %@", [tmp localizedDescription]);
        }
        return sid;
    }
    else {
        [CS_error fillError:err withCode:CSErrorConfigurationFailure andFailureReason:tmp ? [tmp localizedDescription] : nil];
        return nil;
    }
}

/*
 *  Import an existing seal.
 */
+(NSString *) importSealFromData:(NSData *) dSeal withPassword:(NSString *) password andError:(NSError **) err
{
    // - this really should be synchronized because imports happen on a background thread, which could causes races with one another if
    //   one fails and then the next one immediately starts, only to find that there is no vault for it to import into.
    @synchronized (psGlobal) {
        // - if there is no vault yet, we need to initialize it.
        BOOL hasVault        = [ChatSeal hasVault];
        BOOL createdNewVault = NO;
        if (!hasVault) {
            if ([ChatSeal initializeVaultWithError:err]) {
                createdNewVault = YES;
            }
            else {
                return nil;
            }
        }
        
        // - these identities are never made active because they are non-owned seals as a rule.
        NSString *sealIdImported = [ChatSealIdentity importIdentityWithData:dSeal usingPassword:password andError:err];
        if (sealIdImported) {
            NSError *tmp = nil;
            if (![[ChatSeal applicationBaseStation] setNewUserState:NO withError:&tmp]) {
                NSLog(@"CS: Failed to update the application base station after importing a seal.  %@", [tmp localizedDescription]);
            }
        }
        else {
            if (createdNewVault) {
                NSError *tmp = nil;
                [ChatSeal destroyAllFeedContentWithError:nil];          //  just in case.
                if (![RealSecureImage destroyVaultWithError:&tmp]) {
                    NSLog(@"CS: Failed to destroy the vault after a failed import.  %@", [tmp localizedDescription]);
                    return nil;
                }
            }
        }
        return sealIdImported;
    }
}

/*
 *  Set the active seal.
 */
+(BOOL) setActiveSeal:(NSString *) sid withError:(NSError **) err
{
    @synchronized (psGlobal) {
        if ([ChatSeal setActiveSeal:sid andSkipVerification:NO withError:err]) {
            if([ChatSeal isVaultOpen]) {
                [ChatSealVaultPlaceholder saveVaultSealPlaceholderData];
            }
            return YES;
        }
        return NO;
    }
}

/*
 *  Return the seal that the user has chosen as their
 *  default.
 */
+(NSString *) activeSeal
{
    @synchronized (psGlobal) {
        return [ChatSeal activeSealWithValidation:NO];
    }
}

/*
 *  Return the seal that the user has chosen as their
 *  default and optionally validate that the seal is complete.
 */
+(NSString *) activeSealWithValidation:(BOOL) validate
{
    NSString *aSeal = nil;
    @synchronized (psGlobal) {
        aSeal = [[NSUserDefaults standardUserDefaults] stringForKey:CS_DEF_ACTIVESEAL];
    }
    CS_cacheSeal *cs = [CS_cacheSeal sealForId:aSeal];
    if (validate) {
        [cs validate];
    }
    if (aSeal && (!cs || ![cs isKnown])) {
        // - when the seal isn't in the cache, that could mean we got out of synch
        //   and the active seal needs to be reset.
        NSArray *arrAllSeals = [RealSecureImage availableSealsWithError:nil];
        if (arrAllSeals && [arrAllSeals indexOfObject:aSeal] == NSNotFound) {
            @synchronized (psGlobal) {
                [self setActiveSeal:nil andSkipVerification:YES withError:nil];
            }
            return nil;
        }
    }
    return aSeal;
}

/*
 *  Return an uninitialized new seal cell.
 */
+(UINewSealCell *) sealCellForHeight:(CGFloat) height
{
    return [[[UINewSealCell alloc] initWithFrame:CGRectMake(0.0f, 0.0f, height, height)] autorelease];
}

/*
 *  Instantiate a seal cell for the given id.
 */
+(UINewSealCell *) sealCellForId:(NSString *) sid andHeight:(CGFloat) height
{
    UINewSealCell *nsc = [ChatSeal sealCellForHeight:height];
    CS_cacheSeal *cs  = [CS_cacheSeal sealForId:sid];
    if (!cs) {
        NSLog(@"CS-ALERT: Failed to retrieve an active seal cell for id %@.", sid);
        return nil;
    }
    [nsc setSealColor:cs.color];
    
    // - use a smaller image when possible, both because it saves on RAM, but produces
    //   a better result because scaling down the original image is not very good on the fly.
    if (height < [ChatSeal standardSealImageSideForVaultDisplay]) {
        [nsc setSealImage:cs.vaultImage];
    }
    else {
        [nsc setSealImage:cs.safeImage];
    }
    return nsc;
}

/*
 *  Instantiate a cell for the current seal that can be used for animation.
 */
+(UINewSealCell *) activeSealCellOfHeight:(CGFloat) height
{
    return [ChatSeal sealCellForId:[self activeSeal] andHeight:height];
}

/*
 *  Return a list of seal ids in the system.
 */
+(NSArray *) availableSealsWithError:(NSError **) err
{
    return [RealSecureImage availableSealsWithError:err];
}

/*
 *  Return a list of all the identities in the system.
 */
+(NSArray *) availableIdentitiesWithError:(NSError **) err;
{
    //  - It is very important that the seal cache drives the identities, not the other
    //    way around because the seal cache is populated from the keychain, to the cache file and
    //    controlled by the application global cache epoch.  When the epoch is out of synch, the
    //    list is regenerated.  We don't ever want a situation where the seal list could be partially
    //    reconstructed by saving off the identity file.
    NSArray *arr = [CS_cacheSeal availableSealsWithError:err];
    if (!arr) {
        return nil;
    }
    NSMutableArray *maIdentities = [NSMutableArray array];
    for (CS_cacheSeal *cs in arr) {
        ChatSealIdentity *psi = [ChatSealIdentity identityForCacheSeal:cs withError:err];
        if (!psi) {
            return nil;
        }
        [maIdentities addObject:psi];
    }
    return maIdentities;
}

/*
 *  Return an identity for a given seal.
 */
+(ChatSealIdentity *) identityForSeal:(NSString *) sealId withError:(NSError **) err
{
    CS_cacheSeal *cs = [CS_cacheSeal sealForId:sealId];
    if (!cs) {
        [CS_error fillError:err withCode:CSErrorInvalidSeal];
        return nil;
    }
    return [ChatSealIdentity identityForCacheSeal:cs withError:err];
}

/*
 *  Return the identity for the active seal.
 */
+(ChatSealIdentity *) activeIdentityWithError:(NSError **) err
{
    NSString *activeSeal = [ChatSeal activeSeal];
    if (!activeSeal) {
        [CS_error fillError:err withCode:CSErrorNoActiveSeal];
        return nil;
    }
    return [ChatSeal identityForSeal:activeSeal withError:err];
}

/*
 *  Return the list of safe seals with their associated seal ids.  This
 *  is a potentially expensive operation, so don't use this often.
 */
+(NSDictionary *) safeSealIndexWithError:(NSError **) err
{
    if (![RealSecureImage hasVault]) {
        [CS_error fillError:err withCode:CSErrorVaultNotInitialized];
        return nil;
    }
    return [RealSecureImage safeSealIndexWithError:err];
}

/*
 *  Returns whether a seal exists in the vault.
 */
+(BOOL) sealExists:(NSString *) sid withError:(NSError **)err
{
    if (![RealSecureImage hasVault]) {
        [CS_error fillError:err withCode:CSErrorVaultNotInitialized];
        return NO;
    }
    return [RealSecureImage sealExists:sid withError:err];
}

/*
 *  Check if I own this seal.
 */
+(BOOL) sealIsOwned:(NSString *) sid
{
    CS_cacheSeal *cs = [CS_cacheSeal sealForId:sid];
    if (cs && cs.isOwned) {
        return YES;
    }
    return NO;
}

/*
 *  Retrieve a seal from the vault.
 */
+(RSISecureSeal *) sealForId:(NSString *) sid withError:(NSError **) err
{
    if (![RealSecureImage hasVault]) {
        [CS_error fillError:err withCode:CSErrorVaultNotInitialized];
        return nil;
    }
    return [RealSecureImage sealForId:sid andError:err];
}

/*
 *  Delete a seal from the vault.
 */
+(BOOL) deleteSealForId:(NSString *) sid withError:(NSError **) err
{
    NSString *activeSeal = [ChatSeal activeSeal];
    BOOL ret             = [ChatSealIdentity permanentlyDestroyIdentity:sid withError:err];
    if (ret) {
        // - if we just deleted the active seal, make sure that it is reset.
        if ([activeSeal isEqualToString:sid]) {
            [ChatSeal setActiveSeal:nil andSkipVerification:YES withError:nil];
        }
        
        // - notify any interested parties the seal is gone
        [ChatSeal notifySealActivityByName:kChatSealNotifySealInvalidated andSeal:sid];
    }
    return ret;
}

/*
 *  Return the owner for the given seal.
 */
+(NSString *) ownerNameForSeal:(NSString *) sid
{
    if ([ChatSeal isVaultOpen]) {
        return [ChatSealIdentity ownerNameForSeal:sid];
    }
    return nil;
}

/*
 *  Get the name for the current seal.
 */
+(NSString *) ownerForActiveSeal
{
    return [ChatSeal ownerNameForSeal:[ChatSeal activeSeal]];
}

/*
 *  Return the text for an anonymous seal.
 */
+(NSString *) ownerForAnonymousForMe:(BOOL)forMe
{
    return [ChatSeal ownerForAnonymousSealForMe:forMe withLongForm:YES];
}

/*
 *  Return an anonymous string designation.
 */
+(NSString *) ownerForAnonymousSealForMe:(BOOL)forMe withLongForm:(BOOL)isLongForm
{
    if (forMe) {
        if (isLongForm) {
            return NSLocalizedString(@"Me, anonymously", nil);
        }
        else {
            return NSLocalizedString(@"Me", nil);
        }
    }
    else {
        return NSLocalizedString(@"Anonymous", nil);
    }
}

/*
 *  Return the primary seal color for the given color.
 */
+(UIColor *) primaryColorForSealColor:(RSISecureSeal_Color_t) color
{
    static UIColor *cBlue   = nil;
    static UIColor *cOrange = nil;
    static UIColor *cYellow = nil;
    static UIColor *cPurple = nil;
    static UIColor *cGreen  = nil;
    
    // - NOTE:  These can never be in the white colorspace because of the way that table cell selection
    //          works.  Look for the comments in the UISealWaxView for information.
    switch (color) {
        case RSSC_STD_BLUE:
            if (!cBlue) {
                cBlue = [rgb(89, 157, 233) retain];
            }
            return [[cBlue retain] autorelease];
            break;
            
        case RSSC_STD_ORANGE:
            if (!cOrange) {
                cOrange = [rgb(235, 114, 91) retain];
            }
            return [[cOrange retain] autorelease];
            break;
            
        case RSSC_STD_YELLOW:
            if (!cYellow) {
                cYellow = [rgb(233, 166, 89) retain];
            }
            return [[cYellow retain] autorelease];
            break;
            
        case RSSC_STD_PURPLE:
            if (!cPurple) {
                cPurple = [rgb(189, 108, 221) retain];
            }
            return [[cPurple retain] autorelease];
            break;
            
        case RSSC_STD_GREEN:
            if (!cGreen) {
                cGreen = [rgb(77, 172, 84) retain];
            }
            return [[cGreen retain] autorelease];
            break;
            
        default:
            return [ChatSeal defaultSupportingTextColor];
            break;
    }
    return nil;
}

/*
 *  Return the color combinations for a given generic seal color identifier.
 */
+(ChatSealColorCombo *) sealColorsForColor:(RSISecureSeal_Color_t) color
{
    ChatSealColorCombo *pscc = [[[ChatSealColorCombo alloc] init] autorelease];
    pscc.isValid              = (color >= 0 && color < RSSC_NUM_SEAL_COLORS) ? YES : NO;

    // - every seal follows the same basic structure, except for the middle color and the highlight.
    pscc.cOuter = [ChatSeal defaultIconColor];
    pscc.cMid   = [ChatSeal primaryColorForSealColor:color];
    pscc.cInner = [UIColor colorWithRed:0.800f green:0.803f blue:0.831f alpha:1.0f];
    
    // - the text highlight colors are from the same general collection of color, but are limited to
    //   ones that look good with the source color.
    if (color == RSSC_STD_ORANGE || color == RSSC_STD_YELLOW) {
        static UIColor *cBlueHighlight = nil;
        if (!cBlueHighlight) {
            cBlueHighlight = [[ChatSeal highlightColorFromSealColor:RSSC_STD_BLUE] retain];
        }
        pscc.cTextHighlight = cBlueHighlight;
    }
    else {
        static UIColor *cYellowHighlight = nil;
        if (!cYellowHighlight) {
            cYellowHighlight = [[ChatSeal highlightColorFromSealColor:RSSC_STD_YELLOW] retain];
        }
        pscc.cTextHighlight = cYellowHighlight;
    }
    return pscc;
}

/*
 *  Using the seal id, figure out the right kind of colors to display for it.
 */
+(ChatSealColorCombo *) sealColorsForSealId:(NSString *) sealId
{
    CS_cacheSeal *cs = [CS_cacheSeal sealForId:sealId];
    if (cs && cs.color != RSSC_INVALID) {
        return [ChatSeal sealColorsForColor:cs.color];
    }
    return nil;
}

/*
 *  Return the media timing function that is used for popping seals in/out.
 */
+(CAMediaTimingFunction *) standardTimingFunctionForSealPop:(BOOL) isPopping
{
    return [CAMediaTimingFunction functionWithControlPoints:0.0f :isPopping ? 1.53f : 1.13f :0.75f :1.0f];
}

/*
 *  Return the duration for expanding a seal during pop/unpop.
 */
+(NSTimeInterval) animationDurationForSealPop:(BOOL) isPopping
{
    return isPopping ? 0.4f : ([ChatSeal standardItemFadeTime] * 1.25f);
}

/*
 *  Generate a decoy image for the active seal.
 */
+(UIImage *) standardDecoyForActiveSeal
{
    return [UISealedMessageEnvelopeViewV2 standardDecoyForActiveSeal];
}

/*
 *  Generate a decoy image for the given seal id.
 */
+(UIImage *) standardDecoyForSeal:(NSString *) sealId
{
    return [UISealedMessageEnvelopeViewV2 standardDecoyForSeal:sealId];
}

/*
 *  When the first message has been sent or received, this flag will be set to indicate that
 *  the user no longer needs the welcome screen.
 */
+(BOOL) hasExperiencedMessaging
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:CS_DEF_ONEMSG];
}

/*
 *  Set the flag indicating the user's first experience with messaging is completed.
 */
+(void) setMessageFirstExperienceIfNecessary
{
    if (![ChatSeal hasExperiencedMessaging]) {
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:CS_DEF_ONEMSG];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [ChatSeal reconfigureBaseStationForBroadcast];
    }
}

/*
 *  The compression used for saving the decoy to the message directory.
 */
+(CGFloat) standardDecoyCompression
{
    return 0.5f;
}

/*
 *  The compression used for every image archived on-disk.
 */
+(CGFloat) standardArchivedImageCompression
{
    return 0.5f;
}

/*
 *  Create a new message with the active seal.
 */
+(ChatSealMessage *) createMessageOfType:(ps_message_type_t) mtype withDecoy:(UIImage *) decoy andData:(NSArray *) msgData andError:(NSError **) err
{
    return [ChatSeal createMessageOfType:mtype usingSeal:[ChatSeal activeSeal] withDecoy:decoy andData:msgData andError:err];
}

/*
 *  Create a new message with the given seal.
 */
+(ChatSealMessage *) createMessageOfType:(ps_message_type_t) mtype usingSeal:(NSString *) sealId withDecoy:(UIImage *) decoy andData:(NSArray *) msgData andError:(NSError **) err
{
    // - assume the creation date is now.
    return [ChatSealMessage createMessageOfType:mtype usingSeal:sealId withDecoy:decoy andData:msgData onCreationDate:nil andError:err];
}

/*
 *  Return a list of all the messages in the system that match the given search criteria.
 */
+(NSArray *) messageListForSearchCriteria:(NSString *) searchString withItemIdentification:(BOOL(^)(ChatSealMessage *)) itemIdentified andError:(NSError **) err
{
    return [ChatSealMessage messageListForSearchCriteria:searchString withItemIdentification:itemIdentified andError:err];
}

/*
 *  Import a message into the vault.
 */
+(ChatSealMessage *) importMessageIntoVault:(NSData *) dMessage andSetDefaultFeed:(NSString *) feedId withError:(NSError **) err
{
    return [ChatSeal importMessageIntoVault:dMessage andSetDefaultFeed:feedId andReturnUserData:nil withError:err];
}

/*
 *  Import a message into the vault.
 */
+(ChatSealMessage *) importMessageIntoVault:(NSData *) dMessage andSetDefaultFeed:(NSString *) feedId andReturnUserData:(NSObject **) userData withError:(NSError **) err
{
    return [ChatSealMessage importMessageIntoVault:dMessage andSetDefaultFeed:feedId andReturnUserData:userData withError:err];
}

/*
 *  Determine if the given packed message is known to the vault.
 */
+(BOOL) isPackedMessageCurrentlyKnown:(NSData *) dMesage
{
    return [ChatSealMessage isPackedMessageCurrentlyKnown:dMesage];
}

/*
 *  Determine if the given packed message hash is known to the vault.
 */
+(BOOL) isPackedMessageHashCurrentlyKnown:(NSString *) sHash
{
    return [ChatSealMessage isPackedMessageHashCurrentlyKnown:sHash];
}

/*
 *  Find an existing message when creating a new message.
 */
+(ChatSealMessage *) bestMessageForSeal:(NSString *) sid andAuthor:(NSString *) author
{
    if (![ChatSeal isVaultOpen]) {
        return nil;
    }
    return [ChatSealMessage bestMessageForSeal:sid andAuthor:author];
}

/*
 *  Find the most recent existing message.
 */
+(ChatSealMessage *) mostRecentMessageForSeal:(NSString *) sid
{
    // - use an author name that won't match anonymous but is invalid so that we get the most recent one
    //   that we have.
    return [ChatSeal bestMessageForSeal:sid andAuthor:@"!~!"];
}

/*
 *  Return the message with the given id.
 */
+(ChatSealMessage *) messageForId:(NSString *) mid
{
    return [ChatSealMessage messageForId:mid];
}

/*
 *  Figure out if the act of screenshotting the given message should expire the seal.
 */
+(BOOL) checkForSealRevocationForScreenshotWhileReadingMessage:(ChatSealMessage *) psm
{
    if (!psm) {
        return NO;
    }
    
    ChatSealIdentity *ident = nil;
    NSError *err             = nil;
    ident = [psm identityWithError:&err];
    if (!ident) {
        NSLog(@"CS: Failed to retrieve the active seal identity.  %@", [err localizedDescription]);
        return NO;
    }
    
    NSString *sealId = ident.sealId;
    if ([ident checkForRevocationWithScreenshotTaken]) {        
        [ChatSealMessage permanentlyLockAllMessagesForSeal:sealId];
        [ChatSeal notifySealActivityByName:kChatSealNotifySealInvalidated andSeal:sealId];
        return YES;
    }
    return NO;
}

/*
 *  Return the inter-device secure base station.
 */
+(ChatSealBaseStation *) applicationBaseStation
{
    return [[baseStation retain] autorelease];
}

/*
 *  Return the application-wide feed collector instance.
 */
+(ChatSealFeedCollector *) applicationFeedCollector
{
    @synchronized (psGlobal) {
        if (!feedCollector) {
            feedCollector = [[ChatSealFeedCollector alloc] init];
        }
        return [[feedCollector retain] autorelease];
    }
}

/*
 *  Return the list of friends for a given feed type.
 */
+(NSArray *) friendsForFeedsOfType:(NSString *) feedType
{
    return [ChatSealIdentity friendsForFeedsOfType:feedType];
}

/*
 *  Return the friends list version number for the given feed type.
 */
+(NSUInteger) friendsListVersionForFeedsOfType:(NSString *) feedType
{
    return [ChatSealIdentity friendsListVersionForFeedsOfType:feedType];
}

/*
 *  Delete all the friends that are identified by the given locations.
 */
+(BOOL) deleteAllFriendsForFeedsInLocations:(NSArray *) arrLocs
{
    return [ChatSealIdentity deleteAllFriendsForFeedsInLocations:arrLocs];
}
@end


/*********************
 ChatSeal (internal)
 *********************/
@implementation ChatSeal (internal)

/*
 *  Initialize the global object and wire up its notifications.
 */
-(id) initWithNotifications
{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyOrientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyInitialStylingComplete) name:kChatSealNotifyInitialStylingCompleted object:nil];
        
        // - set the seal expiration timer
        NSTimer *tmExpire = [NSTimer timerWithTimeInterval:CS_EXPIRE_CHECK_TIMEOUT target:self selector:@selector(expirationTimer:) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:tmExpire forMode:NSRunLoopCommonModes];
        
        // - and the feed share warning completion
        handlingFeedShareAlert      = NO;
        sharedFeedWarningCompletion = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [self setFeedShareWarningCompletionBlock:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

/*
 *  Record the current device orientation, but exclude the odd face-up/down orientations
 *  because they generally don't help.
 */
-(void) notifyOrientationChanged:(NSNotification *) notification
{
    UIDeviceOrientation devIO = [UIDevice currentDevice].orientation;
    if (devIO != UIDeviceOrientationFaceDown &&
        devIO != UIDeviceOrientationFaceUp) {
        currentOrientation = devIO;
    }
}

/*
 * Respond to foreground changes.
 */
-(void) notifyWillEnterForeground:(NSNotification *) notification
{
    // - release the library thumb
    [photoLibThumb release];
    photoLibThumb = nil;
    
    // - requery the feeds if they are open
    [[ChatSeal applicationFeedCollector] requeryFeedPermissionsWithCompletion:nil];
    
    // - force the camera to be requried when entering the foreground again.
    @synchronized (psGlobal) {
        cameraQueried  = NO;
        hasFrontCamera = hasBackCamera = NO;
    }
}

/*
 *  The app is about to become non-active.
 *  - this is the place where the base station should be silenced since
 *    it is consuming battery power when it is active.
 */
-(void) notifyWillResignActive:(NSNotification *) notification
{
    [baseStation setBroadcastingEnabled:NO withError:nil];
    
    // - also, set the application badge if it couldn't be set before because of bad permissions.
    if ([UIApplication sharedApplication].applicationIconBadgeNumber != desiredApplicationBadgeValue) {
        [ChatSeal setApplicationBadgeToValue:desiredApplicationBadgeValue];
    }
}

/*
 *  The app has become the active one.
 *  - fire up the base station now so that we can make sure others can know of our existence.
 */
-(void) notifyDidBecomeActive:(NSNotification *) notification
{
    if (![ChatSeal hasVault] || [ChatSeal isVaultOpen]) {
        [ChatSeal reconfigureBaseStationForBroadcast];        
    }
    
    // - when the app initially comes online, we'll need to determine whether any seals
    //   have expired since we last used it.
    if (!firstTimeExpirationCheckOccurred) {
        firstTimeExpirationCheckOccurred = YES;
        [ChatSeal checkForSealExpiration];
    }
}

/*
 *  The app is about to terminate.
 */
-(void) notifyWillTerminate:(NSNotification *)notification
{
    // - I don't really want to do too much here, but in the interest of keeping
    //   peers up to date and the on-board DNS system consistent, I'm going to
    //   destroy the base station right before termination.
    [baseStation release];
    baseStation = nil;
}

/*
 *  The initial app styling has been completed.
 */
-(void) notifyInitialStylingComplete
{
    hasCompletedInitialStyling = YES;
    if ([ChatSeal isApplicationForeground] && [[ChatSeal applicationFeedCollector] isOpen] && ![[ChatSeal applicationFeedCollector] hasBeenAuthQueried]) {
        [[ChatSeal applicationFeedCollector] requeryFeedPermissionsWithCompletion:nil];
    }
}

/*
 *  Set the active seal.
 */
+(BOOL) setActiveSeal:(NSString *) sid andSkipVerification:(BOOL) skipVerify withError:(NSError **) err
{
    if (sid) {
        if (!skipVerify) {
            CS_cacheSeal *cs = [CS_cacheSeal sealForId:sid];
            if (!cs) {
                [CS_error fillError:err withCode:CSErrorInvalidSeal];
                return NO;
            }
            
            if (![cs isOwned]) {
                [CS_error fillError:err withCode:CSErrorInvalidSeal andFailureReason:@"Active seals must be owned."];
                return NO;
            }
        }
        if (![sid isEqualToString:[ChatSeal activeSeal]]) {
            //  - if secure transfer is enabled, disable it
            //    now because the current seal has changed.
            [[NSUserDefaults standardUserDefaults] setObject:sid forKey:CS_DEF_ACTIVESEAL];
        }
    }
    else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:CS_DEF_ACTIVESEAL];
    }
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    return YES;
}

/*
 *  Reset the configured options.
 */
+(BOOL) resetAllUserConfiguration
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:CS_DEF_PWDSET];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:CS_DEF_ACTIVESEAL];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:CS_DEF_ONEMSG];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:CS_DEF_XFERSEAL];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:CS_DEF_COLLFIRSTTIME];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:CS_DEF_SHAREFEEDS];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:CS_DEF_SHOWEDFEEDWARNING];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:CS_DEF_RESETFEEDWARNING];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:CS_DEF_CACHEEPOCH];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:CS_DEF_HASASKEDNOTIFYPERM];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:CS_DEF_FEED_ALERTED];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return YES;             //  synchronize returns NO if there was nothing to do.
}

/*
 *  Ensure that the base station is configured correctly for the current
 *  state of the system.
 */
+(void) reconfigureBaseStationForBroadcast
{
    NSError *err = nil;
    
    // - make sure the base station reports whether this is a new installation.
    if (![baseStation setNewUserState:![ChatSeal hasVault] withError:&err]) {
        NSLog(@"CS: The base station's new user state could not be auto-configured.  %@", [err localizedDescription]);
        return;
    }
 
    // - make sure it is on, if it isn't already.
    if (![baseStation setBroadcastingEnabled:YES withError:&err]) {
        NSLog(@"CS: The base station's broadcast auto-enablement failed.  %@", [err localizedDescription]);
    }
}

/*
 *  This timer will check for seal expirations in the local vault on a fairly broad 
 *  interval since they only expire on a daily basis.
 */
-(void) expirationTimer:(NSTimer *) timer
{
    [ChatSeal checkForSealExpiration];
}

/*
 *  Check if any of the seals in the vault have expired.
 */
+(void) checkForSealExpiration
{
    if (![ChatSeal hasVault]) {
        return;
    }
    
    NSError *err = nil;
    NSArray *arr = [ChatSeal availableIdentitiesWithError:&err];
    if (!arr) {
        NSLog(@"CS: Failed to retrieve a valid identity list.  %@", [err localizedDescription]);
        return;
    }
    
    // - check each identity to see if it has expired.
    NSMutableArray *arrExpired = [NSMutableArray array];
    for (ChatSealIdentity *psi in arr) {
        if ([psi isOwned] || [psi isInvalidated]) {
            continue;
        }
        
        NSString *sealId = psi.sealId;
        if ([psi checkForExpiration]) {
            [ChatSealMessage permanentlyLockAllMessagesForSeal:sealId];
            [arrExpired addObject:sealId];
        }
    }
    
    //  - if any seals were expired during this check, notify possible users now, but ensure it happens on the main thread.
    if ([arrExpired count]) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
            NSDictionary *dict = [NSDictionary dictionaryWithObject:arrExpired forKey:kChatSealNotifySealArrayKey];
            [[NSNotificationCenter defaultCenter] postNotificationName:kChatSealNotifySealInvalidated object:self userInfo:dict];
        }];
    }
}

/*
 *   This method gets the primary object ready to display the feed share warning.
 */
-(void) prepareToDisplayFeedShareWarningWithCompletionBlock:(void(^)(void)) completionBlock
{
    handlingFeedShareAlert = YES;
    [self setFeedShareWarningCompletionBlock:completionBlock];
}

/*
 *  Assign the completion block that will be used when the alert completes.
 */
-(void) setFeedShareWarningCompletionBlock:(void(^)(void)) completionBlock
{
    if (sharedFeedWarningCompletion != completionBlock) {
        if (sharedFeedWarningCompletion) {
            Block_release(sharedFeedWarningCompletion);
            sharedFeedWarningCompletion = nil;
        }
        if (completionBlock) {
            sharedFeedWarningCompletion = Block_copy(completionBlock);
        }
    }
}

/*
 *  When the global object is used to manage alerts, this is triggered when we click a button.
 */
-(void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (!handlingFeedShareAlert) {
        return;
    }
    
    // - ensure this happens on the main thread because the completion is likely a UI change.
    [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
        // - we're processing a feed share choice which is either "Don't Allow" = 0 or "OK" = 1.
        [ChatSeal setFeedsAreSharedWithSealsAsEnabled:(buttonIndex == 1) ? YES : NO];
        handlingFeedShareAlert = NO;
        if (sharedFeedWarningCompletion) {
            sharedFeedWarningCompletion();
        }
        [psGlobal setFeedShareWarningCompletionBlock:nil];
    }];
}

/*
 *  Build a common highlight variant from a seal color.
 */
+(UIColor *) highlightColorFromSealColor:(RSISecureSeal_Color_t) color
{
    UIColor *c = [ChatSeal primaryColorForSealColor:color];
    return [UIImageGeneration adjustColor:c byHuePct:1.0f andSatPct:1.15f andBrPct:1.15f andAlphaPct:1.0f];
}

/*
 *  Destroy feed-related content.
 */
+(BOOL) destroyAllFeedContentWithError:(NSError **)err
{
    @synchronized (psGlobal) {
        [feedCollector close];
        [feedCollector release];
        feedCollector = nil;
        if (![ChatSealFeedCollector destroyAllFeedsWithError:err]) {
            return NO;
        }
        return YES;
    }
}
@end

/**********************
 ChatSealColorCombo
 **********************/
@implementation ChatSealColorCombo
@synthesize cOuter;
@synthesize cMid;
@synthesize cInner;
@synthesize cTextHighlight;
@synthesize isValid;

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        cOuter         = nil;
        cMid           = nil;
        cInner         = nil;
        cTextHighlight = nil;
        isValid        = NO;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [cOuter release];
    cOuter = nil;
    
    [cMid release];
    cMid = nil;
    
    [cInner release];
    cInner = nil;
    
    [cTextHighlight release];
    cTextHighlight = nil;
    
    [super dealloc];
}

@end

/*********************************
 UIViewController (ChatSeal)
 *********************************/
@implementation UIViewController (ChatSeal)
/*
 *  Return an interface orientation value that is appropriate for
 *  future use.
 */
-(UIInterfaceOrientation) backwardsCompatibleInterfaceOrientation
{
    if ([ChatSeal isIOSVersionBEFORE8]) {
        return self.interfaceOrientation;
    }
    else {
        CGSize szBounds                 = self.view.bounds.size;
        UIInterfaceOrientation ioStatus = [UIApplication sharedApplication].statusBarOrientation;   // not the primary vehicle
        if (szBounds.width > szBounds.height) {
            if (ioStatus == UIInterfaceOrientationLandscapeLeft) {
                return UIInterfaceOrientationLandscapeLeft;
            }
            else {
                return UIInterfaceOrientationLandscapeRight;
            }
        }
        else {
            if (ioStatus == UIInterfaceOrientationPortraitUpsideDown) {
                return UIInterfaceOrientationPortraitUpsideDown;
            }
            else {
                return UIInterfaceOrientationPortrait;
            }
        }
    }
}
@end
