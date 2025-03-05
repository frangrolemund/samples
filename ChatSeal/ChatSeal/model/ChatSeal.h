//
//  ChatSeal.h
//  ChatSeal
//
//  Created by Francis Grolemund on 9/20/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RealSecureImage/RealSecureImage.h"
#import "UISealWaxViewV2.h"
#import "ChatSealMessage.h"
#import "CS_error.h"
#import "UIHubViewController.h"
#import "ChatSealIdentity.h"

#import "ChatSealDebug.h"

#define CS_APP_ENCRYPTION_VERSION            1

//  - custom types
typedef enum {
    CS_FS_EXTRA_LIGHT = 0,
    CS_FS_LIGHT       = 1,
    CS_FS_DARK        = 2,
    CS_FS_SECURE      = 3,
    CS_FS_SIMPLE_BLUR = 4,
    CS_FS_UNFOCUSED   = 5
} ps_frost_style_t;

typedef enum {
    CS_SF_NORMAL = 0,
    CS_SF_LIGHT,
    CS_SF_BOLD
} cs_stylized_font_t;

// - constants
#define CS_APP_STD_TOOL_SIDE 35.0f

// - notifications
extern NSString *kChatSealNotifyLowStorageResolved;
extern NSString *kChatSealNotifyNetworkChange;
extern NSString *kChatSealNotifyNearbyUserChange;
extern NSString *kChatSealNotifySealTransferStatus;
extern NSString *kChatSealNotifySecureURLHasChanged;
extern NSString *kChatSealNotifyApplicationURLUpdated;
extern NSString *kChatSealNotifySealInvalidated;
extern NSString *kChatSealNotifySealArrayKey;
extern NSString *kChatSealNotifySealImported;
extern NSString *kChatSealNotifySealRenewed;
extern NSString *kChatSealNotifySealCreated;
extern NSString *kChatSealNotifyMessageImported;
extern NSString *kChatSealNotifyMessageImportedMessageKey;
extern NSString *kChatSealNotifyMessageImportedEntryKey;
extern NSString *kChatSealNotifyFeedTypesUpdated;
extern NSString *kChatSealNotifyFeedRefreshCompleted;
extern NSString *kChatSealNotifyFeedUpdate;
extern NSString *kChatSealNotifyFeedUpdateFeedKey;
extern NSString *kChatSealNotifyFeedPostProgress;
extern NSString *kChatSealNotifyFeedPostProgressItemKey;
extern NSString *kChatSealNotifyFriendshipsUpdated;
extern NSString *kChatSealNotifyFeedFriendshipUpdated;
extern NSString *kChatSealNotifyFeedFriendshipFeedKey;
extern NSString *kChatSealNotifyFeedCollectionDormant;
extern NSString *KChatSealNotifyFeedCollectionDormantMessagesKey;
extern NSString *kChatSealNotifyInitialStylingCompleted;

//  - forward declarations
@class UINewSealCell;
@class ChatSealBaseStation;
@class ChatSealFeedCollector;

// - for retrieving seal color information
@interface ChatSealColorCombo : NSObject
@property (nonatomic, retain) UIColor *cOuter;
@property (nonatomic, retain) UIColor *cMid;
@property (nonatomic, retain) UIColor *cInner;
@property (nonatomic, retain) UIColor *cTextHighlight;
@property (nonatomic, assign) BOOL isValid;
@end

// - custom upgrades to the view controller
@interface UIViewController (ChatSeal)
-(UIInterfaceOrientation) backwardsCompatibleInterfaceOrientation;
@end

//  - The purpose of this class is to implement an intersection
//    between the different model-related items in the app.
@interface ChatSeal : NSObject

//  - resources
+(CGSize) appWindowDimensions;
+(id) viewControllerForStoryboardId:(NSString *) sbid;
+(UIColor *) defaultAppTintColor;
+(UIColor *) defaultEditorBackgroundColor;
+(UIColor *) defaultToolBackgroundColor;
+(UIColor *) defaultLowChromeFrostedColor;
+(UIColor *) defaultLowChromeUltraFrostedColor;
+(UIColor *) defaultLowChromeShadowColor;
+(UIColor *) defaultLowChromeDarkShadowColor;
+(UIColor *) defaultPaperColor;
+(UIColor *) defaultSupportingTextColor;
+(UIColor *) defaultInvalidSealColor;
+(UIColor *) defaultWarningColor;
+(UIColor *) defaultSelectedHeaderColor;
+(UIColor *) defaultAppFailureColor;
+(UIColor *) defaultDarkShadowTextCompliment;
+(UIColor *) defaultIconColor;
+(UIColor *) defaultSwitchOnColor;
+(UIColor *) defaultAppSeriousActionColor;
+(UIColor *) defaultRemoteUserChatColor;
+(UIColor *) defaultTableHeaderFooterTextColor;
+(void) defaultLowChromeShadowTextLabelConfiguration:(UILabel *) l;
+(NSString *) defaultAppStylizedFontNameAsWeight:(cs_stylized_font_t) fontWeight;
+(NSOperation *) generateFrostedImageOfType:(ps_frost_style_t) ftype fromImage:(UIImage *) image withCompletion:(void (^)(UIImage *)) completionBlock;
+(NSOperation *) generateFrostedImageOfType:(ps_frost_style_t) ftype fromImage:(UIImage *) image atScale:(CGFloat) scale withCompletion:(void (^)(UIImage *)) completionBlock;
+(NSOperation *) generateFrostedImageOfType:(ps_frost_style_t) ftype fromView:(UIView *) view atScale:(CGFloat) scale withCompletion:(void (^)(UIImage *)) completionBlock;
+(NSOperation *) generateFrostedImageWithTint:(UIColor *) tintColor fromImage:(UIImage *) image withCompletion:(void (^)(UIImage *)) completionBlock;
+(UIImage *) generateFrostedImageOfType:(ps_frost_style_t) ftype fromImage:(UIImage *) image atScale:(CGFloat) scale;
+(UISealWaxViewV2 *) sealWaxInForeground:(BOOL) isForeground andColor:(RSISecureSeal_Color_t) color;
+(BOOL) hasFrontCamera;
+(BOOL) hasBackCamera;
+(BOOL) hasAnyCamera;
+(UIDeviceOrientation) currentDeviceOrientation;
+(void) cacheAppResources;
+(void) clearCachedContent;
+(void) thumbForPhotoLibraryIfOpen:(void(^)(UIImage *libThumb)) completionBlock;
+(CGFloat) standardSealOriginalSide;
+(CGFloat) standardSealSideForListDisplay;
+(CGFloat) standardSealImageSideForVaultDisplay;
+(NSURL *) standardPlaceholderDirectory;
+(BOOL) collectorFirstTimeCompletedFlag;
+(void) setCollectorFirstTimeFlag:(BOOL) isFirstTime;
+(NSInteger) applicationBadgeValue;
+(BOOL) canSetApplicationBadge;
+(void) setApplicationBadgeToValue:(NSInteger) value;
+(BOOL) canIssueLocalAlerts;
+(void) issueLocalAlert:(UILocalNotification *) localNotify;
+(BOOL) canPlaySounds;
+(BOOL) hasAskedForLocalNotificationPermission;
+(void) checkForLocalNotificationPermissionsIfNecesssary;
+(CGFloat) minimumTouchableDimension;
+(CGFloat) minimumButtonFontSize;
+(CGFloat) superBodyFontScalingFactor;
+(CGFloat) superDuperBodyFontScalingFactor;
+(CGFloat) portraitWidth;

// - caching
+(NSInteger) cacheEpoch;
+(void) incrementCurrentCacheEpoch;
+(NSData *) cachedDataWithBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(BOOL) saveCachedData:(NSData *) obj withBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(void) invalidateCacheItemWithBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(void) invalidateCacheCategory:(NSString *) category;
+(NSSet *) secureCachedBaseNamesInCategory:(NSString *) category;
+(NSObject *) secureCachedDataWithBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(BOOL) saveSecureCachedData:(NSObject *) obj withBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(UIImage *) cachedLossyImageWithBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(BOOL) saveLossyImage:(UIImage *) img withBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(void) invalidateLossyImageWithBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(BOOL) invalidateEntireCache;
+(UIImage *) cachedImageWithBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(BOOL) saveImage:(UIImage *) img withBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(void) invalidateImageWithBaseName:(NSString *) baseName andCategory:(NSString *) category;
+(NSURL *) cachedStartupURL;
+(BOOL) setCachedStartupURL:(NSURL *) u;
+(void) saveBackgroundSessionCompletionHandler:(void (^)()) completionHandler;
+(void) completeBackgroundSession;
+(BOOL) lastFeedCollectorAlertedState;
+(void) saveFeedCollectorAlertedState:(BOOL) isAlerted;

//  - utilities
+(CGRect) keyboardRectangle:(CGRect) rc forView:(UIView *) vwTarget;
+(CGRect) keyboardRectangleFromNotification:(NSNotification *) notification usingKey:(NSString *) key forView:(UIView *) vwTarget;
+(NSArray *) sortedDirectoryListForURL:(NSURL *) srcDir withError:(NSError **) err;
+(BOOL) isLowStorageAConcern;
+(UIHubViewController *) applicationHub;
+(NSString *) insecureHashForData:(NSData *) d;
+(NSString *) safeSaltedPathString:(NSString *) s withError:(NSError **)err;
+(void) vibrateDeviceIfPossible;
+(CABasicAnimation *) duplicateAnimation:(CAAnimation *) anim forNewKeyPath:(NSString *) keyPath;
+(CAAnimation *) boundsAnimationForLayer:(CALayer *) l;
+(void) duplicateBoundsFromAnimation:(CAAnimation *) anim onLayer:(CALayer *) l toTargetRect:(CGRect) rc;
+(void) notifySealActivityByName:(NSString *) name andSeal:(NSString *) sealId;
+(void) updateAlertBadges;
+(void) notifyMessageImportedWithId:(NSString *) mid andEntry:(NSUUID *) entryId;
+(void) notifyFriendshipsUpdated;
+(BOOL) isApplicationForeground;
+(BOOL) isIOSVersionBEFORE8;
+(BOOL) isIOSVersionGREQUAL8;
+(BOOL) isAdvancedSelfSizingInUse;
+(void) debugLog:(NSString *) fmt, ...;
+(NSUInteger) numberOfDebugLogItems;
+(NSString *) debugLogItemAtIndeex:(NSUInteger) index;

//  - timing
+(NSTimeInterval) standardItemFadeTime;
+(NSTimeInterval) standardSqueezeTime;
+(NSTimeInterval) standardRotationTime;
+(NSTimeInterval) standardBarAppearanceTime;
+(NSTimeInterval) standardLockDuration;
+(NSTimeInterval) standardSearchFilterDelay;
+(NSTimeInterval) standardHintSlideTime;

//  - app-synchronized activites
+(BOOL) initializeVaultWithError:(NSError **) err;
+(BOOL) openVaultWithPassword:(NSString *) pwd andError:(NSError **) err;
+(void) closeVault;
+(BOOL) destroyAllApplicationDataWithError:(NSError **) err;
+(BOOL) hasVault;
+(BOOL) isVaultOpen;
+(BOOL) openFeedsIfPossibleWithCompletion:(void(^)(BOOL success))completionBlock;
+(BOOL) wasVaultJustCreated;

//  - parallelism
+(NSOperationQueue *) uiPopulationQueue;
+(NSOperationQueue *) vaultOperationQueue;
+(void) waitForAllVaultOperationsToComplete;

//  - seal-related activities
+(BOOL) hasTransferredASeal;
+(BOOL) hasSeals;
+(void) setSealTransferCompleteIfNecessary;
+(BOOL) hasPresentedFeedShareWarning;
+(BOOL) canShareFeedsDuringExchanges;
+(void) setFeedsAreSharedWithSealsAsEnabled:(BOOL) enabled;
+(NSString *) genericFeedSharingEncouragement;
+(void) displayFeedShareWarningIfNecessaryWithDescription:(BOOL) incDesc andCompletion:(void (^)()) completionBlock;
+(NSString *) createSealWithImage:(UIImage *) imgSeal andColor:(RSISecureSeal_Color_t) color andError:(NSError **) err;
+(NSString *) createSealWithImage:(UIImage *) imgSeal andColor:(RSISecureSeal_Color_t) color andSetAsActive:(BOOL) makeActive withError:(NSError **) err;
+(NSString *) importSealFromData:(NSData *) dSeal withPassword:(NSString *) password andError:(NSError **) err;
+(NSString *) ownerNameForSeal:(NSString *) sid;
+(NSString *) ownerForActiveSeal;
+(NSString *) ownerForAnonymousForMe:(BOOL) forMe;
+(NSString *) ownerForAnonymousSealForMe:(BOOL) forMe withLongForm:(BOOL) isLongForm;
+(BOOL) setActiveSeal:(NSString *) sid withError:(NSError **) err;
+(NSString *) activeSeal;
+(NSString *) activeSealWithValidation:(BOOL) validate;
+(UINewSealCell *) sealCellForHeight:(CGFloat) height;
+(UINewSealCell *) sealCellForId:(NSString *) sid andHeight:(CGFloat) height;
+(UINewSealCell *) activeSealCellOfHeight:(CGFloat) height;
+(NSArray *) availableSealsWithError:(NSError **) err;
+(NSArray *) availableIdentitiesWithError:(NSError **) err;
+(ChatSealIdentity *) identityForSeal:(NSString *) sealId withError:(NSError **) err;
+(ChatSealIdentity *) activeIdentityWithError:(NSError **) err;
+(NSDictionary *) safeSealIndexWithError:(NSError **) err;
+(BOOL) sealExists:(NSString *) sid withError:(NSError **)err;
+(BOOL) sealIsOwned:(NSString *) sid;
+(RSISecureSeal *) sealForId:(NSString *) sid withError:(NSError **) err;
+(BOOL) deleteSealForId:(NSString *) sid withError:(NSError **) err;
+(UIColor *) primaryColorForSealColor:(RSISecureSeal_Color_t) color;
+(ChatSealColorCombo *) sealColorsForColor:(RSISecureSeal_Color_t) color;
+(ChatSealColorCombo *) sealColorsForSealId:(NSString *) sealId;
+(CAMediaTimingFunction *) standardTimingFunctionForSealPop:(BOOL) isPopping;
+(NSTimeInterval) animationDurationForSealPop:(BOOL) isPopping;
+(UIImage *) standardDecoyForActiveSeal;
+(UIImage *) standardDecoyForSeal:(NSString *) sealId;
+(NSArray *) friendsForFeedsOfType:(NSString *) feedType;
+(NSUInteger) friendsListVersionForFeedsOfType:(NSString *) feedType;
+(BOOL) deleteAllFriendsForFeedsInLocations:(NSArray *) arrLocs;

//  - messaging
+(BOOL) hasExperiencedMessaging;
+(void) setMessageFirstExperienceIfNecessary;
+(CGFloat) standardDecoyCompression;
+(CGFloat) standardArchivedImageCompression;
+(ChatSealMessage *) createMessageOfType:(ps_message_type_t) mtype withDecoy:(UIImage *) decoy andData:(NSArray *) msgData andError:(NSError **) err;
+(ChatSealMessage *) createMessageOfType:(ps_message_type_t) mtype usingSeal:(NSString *) sealId withDecoy:(UIImage *) decoy andData:(NSArray *) msgData andError:(NSError **) err;
+(NSArray *) messageListForSearchCriteria:(NSString *) searchString withItemIdentification:(BOOL(^)(ChatSealMessage *)) itemIdentified andError:(NSError **) err;
+(ChatSealMessage *) importMessageIntoVault:(NSData *) dMessage andSetDefaultFeed:(NSString *) feedId withError:(NSError **) err;
+(ChatSealMessage *) importMessageIntoVault:(NSData *) dMessage andSetDefaultFeed:(NSString *) feedId andReturnUserData:(NSObject **) userData withError:(NSError **) err;
+(BOOL) isPackedMessageCurrentlyKnown:(NSData *) dMesage;
+(BOOL) isPackedMessageHashCurrentlyKnown:(NSString *) sHash;
+(ChatSealMessage *) bestMessageForSeal:(NSString *) sid andAuthor:(NSString *) author;
+(ChatSealMessage *) mostRecentMessageForSeal:(NSString *) sid;
+(ChatSealMessage *) messageForId:(NSString *) mid;
+(BOOL) checkForSealRevocationForScreenshotWhileReadingMessage:(ChatSealMessage *) psm;

//  - secure communication
+(ChatSealBaseStation *) applicationBaseStation;

//  - feeds
+(ChatSealFeedCollector *) applicationFeedCollector;
@end
