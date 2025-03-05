//
//  AppDelegateV2.m
//  ChatSeal
//
//  Created by Francis Grolemund on 9/20/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "AppDelegateV2.h"
#import "ChatSeal.h"
#import "UIHubViewController.h"
#import "UIChatSealNavigationController.h"
#import "UILaunchGeneratorViewController.h"
#import "ChatSealFeedCollector.h"
#import "UIImageGeneration.h"

// - constants
typedef void (^backgroundFetchCompletion)(UIBackgroundFetchResult);
static const NSTimeInterval CS_MINIMUM_FETCH_INTERVAL = (10 * 60);      // - don't overconsume the capacity of the Twitter API.

// - locals
static BOOL isLowStorageAtBackground = NO;

/**********************
 AppDelegateV2
 **********************/
@implementation AppDelegateV2
/*
 *  Object attributes.
 */
{
    backgroundFetchCompletion fetchCompletion;
    BOOL                      hasGoneDormantOnce;
}

@synthesize window;

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        hasGoneDormantOnce = NO;
        fetchCompletion    = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [window release];
    window = nil;
    
    if (fetchCompletion) {
        Block_release(fetchCompletion);
        fetchCompletion = nil;
    }
    
    [super dealloc];
}

/*
 *  Return the hub used by the application.
 */
-(UIHubViewController *) applicationHub
{
    UINavigationController *nc    = (UINavigationController *) self.window.rootViewController;
    NSArray                *arrVC = [nc viewControllers];
    if ([arrVC count]) {
        return (UIHubViewController *) [arrVC objectAtIndex:0];
    }
    else {
        return nil;
    }
}

/*
 *  Mange pre-launch processing.
 */
-(BOOL) application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    srand((unsigned) time(NULL) + 110412);         //  seed the generic randomizer, but don't be too predictable.
    [ChatSealDebug reportStatus];
    [ChatSeal cacheAppResources];
    
    // - this is something we need to be really careful with.
#if CHATSEAL_RUNNING_CONTRIVED_SCENARIO
    [ChatSealDebug buildScreenshotScenario];
#endif
    
    // - if we previously asked for permission to notify the user and we have a vault, then
    //   we'll make sure it is updated.
    if ([ChatSeal hasVault] && [ChatSeal hasAskedForLocalNotificationPermission]) {
        [ChatSeal checkForLocalNotificationPermissionsIfNecesssary];
    }
    
    // - minor vault-related init during startup.
    if ([ChatSeal hasVault]) {
        // - when the app is starting in the background, bring the vault and collector online so that
        //   the fetch can use them in a moment.
        if (application.applicationState == UIApplicationStateBackground) {
            NSError *err = nil;
            if (![ChatSeal openVaultWithPassword:nil andError:&err]) {
                NSLog(@"CS: Failed to open the vault for background processing.  %@", [err localizedDescription]);
            }
        }
    }
    else {
        // - make sure the app badge doesn't show unread content when we reinstall
        [ChatSeal setApplicationBadgeToValue:0];
    }

    return YES;
}

#ifdef CHATSEAL_GENERATE_APP_PALETTE_IMG
/*
 *  Draw a single color swatch in the current context.
 */
-(void) debugDrawPaletteColor:(UIColor *) c inFrame:(CGRect) rcFrame asRound:(BOOL) isRound withCaption:(NSString *) caption
{
    [c setFill];
    if (isRound) {
        CGContextFillEllipseInRect(UIGraphicsGetCurrentContext(), rcFrame);
    }
    else {
        UIRectFill(rcFrame);
    }
    
    if (caption) {
        NSMutableDictionary *mdAttr = [NSMutableDictionary dictionary];
        [mdAttr setObject:[UIFont systemFontOfSize:12.0f] forKey:NSFontAttributeName];
        NSParagraphStyle *ps = [NSParagraphStyle defaultParagraphStyle];
        NSMutableParagraphStyle *mps = (NSMutableParagraphStyle *) [[ps mutableCopy] autorelease];
        mps.alignment = NSTextAlignmentCenter;
        [mdAttr setObject:mps forKey:NSParagraphStyleAttributeName];
        [mdAttr setObject:[UIColor blackColor] forKey:NSForegroundColorAttributeName];
        CGSize sz = [caption sizeWithAttributes:mdAttr];
        if (sz.width > CGRectGetWidth(rcFrame)) {
            sz.width   = CGRectGetWidth(rcFrame);
            sz.height *= 2.0f;
        }
        [caption drawInRect:CGRectMake(CGRectGetMinX(rcFrame), CGRectGetMaxY(rcFrame) + 10.0f, CGRectGetWidth(rcFrame), sz.height) withAttributes:mdAttr];
    }
}

/*
 *  This method is used to be able to take a look at all the elements in the application palette together to see how
 *  they work together.
 */
-(void) debugGenerateAppPaletteImage
{
    NSLog(@"INFO: (REMOVE) app is generating palette image.");
    CGSize szImg = CGSizeMake(512, 512);
    static const CGFloat borderPad = 25.0f;
    UIGraphicsBeginImageContextWithOptions(szImg, YES, 0.0f);
    
    [[UIColor whiteColor] setFill];
    UIRectFill(CGRectMake(0.0f, 0.0f, szImg.width, szImg.height));
    
    // - general title.
    NSString *sTitle = @"ChatSeal App Palette";
    NSMutableDictionary *mdAttr = [NSMutableDictionary dictionary];
    [mdAttr setObject:[UIFont systemFontOfSize:20.0f] forKey:NSFontAttributeName];
    [mdAttr setObject:[UIColor blackColor] forKey:NSForegroundColorAttributeName];
    CGSize sz = [sTitle sizeWithAttributes:mdAttr];
    [sTitle drawAtPoint:CGPointMake(borderPad, borderPad) withAttributes:mdAttr];
    
    CGFloat curY = borderPad + sz.height + 25.0f;
    
    // - the icon color.
    [self debugDrawPaletteColor:[ChatSeal defaultIconColor] inFrame:CGRectMake(borderPad, curY, szImg.width - (borderPad * 2.0f), 50.0f) asRound:NO withCaption:@"App Icon Color"];
    curY += 95.0f;
    
    // - now the general app colors.
    [self debugDrawPaletteColor:[ChatSeal defaultAppTintColor] inFrame:CGRectMake(borderPad, curY, 100.0f, 100.0f) asRound:NO withCaption:@"App Tint"];
    [self debugDrawPaletteColor:[ChatSeal defaultSwitchOnColor] inFrame:CGRectMake(borderPad + 115.0f, curY, 100, 100) asRound:NO withCaption:@"Switch On"];
    [self debugDrawPaletteColor:[ChatSeal defaultWarningColor] inFrame:CGRectMake(borderPad + 230.0f, curY, 100, 100) asRound:NO withCaption:@"Warning"];
    [self debugDrawPaletteColor:[ChatSeal defaultAppFailureColor] inFrame:CGRectMake(borderPad + 345.0f, curY, 100, 100) asRound:NO withCaption:@"Failure"];
    
    curY += 150.0f;
    
    // - then the seal colors.
    static NSString *sealColors[] = {@"Purple Seal", @"Orange Seal", @"Yellow Seal", @"Green Seal", @"Blue Seal"};
    NSUInteger numColors         = sizeof(sealColors)/sizeof(sealColors[0]);
    CGFloat oneSide              = (szImg.width - (borderPad * 2.0f))/numColors;
    CGFloat sealPad              = (CGFloat) ceil(oneSide * 0.2);
    oneSide                      = (CGFloat) ceil(oneSide * 0.8);
    CGFloat pos                  = borderPad;
    for (NSUInteger i = 0; i < numColors; i++) {
        ChatSealColorCombo *cc = [ChatSeal sealColorsForColor:(RSISecureSeal_Color_t) i];
        [self debugDrawPaletteColor:cc.cMid inFrame:CGRectMake(pos, curY, oneSide, oneSide) asRound:YES withCaption:sealColors[i]];
        pos += oneSide;
        pos += sealPad;
    }
    
    UIImage *imgRet = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    NSLog(@"INFO: (REMOVE) app palette image is generated. %@", imgRet);
}
#endif

/*
 *  When the feed collector goes dormant, we'll get this notification.
 */
-(void) notifyCollectionDormant:(NSNotification *) notification
{
    // - make sure we always track this to avoid races.
    hasGoneDormantOnce = YES;
    
#ifdef CHATSEAL_DEBUG_DORMANT_NOTIFY
    NSLog(@"INFO: ChatSeal collector has gone dormant.");
#endif
    // - the only purpose of this notification is to allow us to properly complete the background fetch at the moment
    if (fetchCompletion) {
        NSNumber *n     = [notification.userInfo objectForKey:KChatSealNotifyFeedCollectionDormantMessagesKey];
        NSInteger count = [ChatSeal applicationBadgeValue];     // this will be updated if anything was retrieved.
        
        // - if we got messages, this is a great time to post a local notification before we return our completion.
        if (n.unsignedIntegerValue) {
            UILocalNotification *locNotify = [[[UILocalNotification alloc] init] autorelease];
            NSString *sAlert               = nil;
            if (count == 1) {
                sAlert = NSLocalizedString(@"You have a new message.", nil);
            }
            else {
                sAlert = [NSString stringWithFormat:NSLocalizedString(@"You have %d new messages.", nil), (int) count];
            }
            locNotify.alertBody                  = sAlert;
            locNotify.hasAction                  = YES;
            locNotify.applicationIconBadgeNumber = count;
            locNotify.soundName                  = UILocalNotificationDefaultSoundName;
            [ChatSeal issueLocalAlert:locNotify];
        }
        
        // - complete the background fetch.
        fetchCompletion(n.unsignedIntegerValue ? UIBackgroundFetchResultNewData : UIBackgroundFetchResultNoData);
        Block_release(fetchCompletion);
        fetchCompletion = nil;
    }
    
    // - just remove my dormant registration because there is no more need for it.
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kChatSealNotifyFeedCollectionDormant object:nil];
}

/*
 *  Manage post-launch processing.
 */
-(BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // - save off the URL, if provided, which will allow us to open the target screen more quickly.
    NSURL *launchURL = [launchOptions objectForKey:UIApplicationLaunchOptionsURLKey];
    if (launchURL) {
        [ChatSeal setCachedStartupURL:launchURL];
    }
    
    // - register to receive the dormant notification to handle fetch completions.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyCollectionDormant:) name:kChatSealNotifyFeedCollectionDormant object:nil];
    
    // - make sure the fetch interval is set up in the application to ensure we see updates.
    [application setMinimumBackgroundFetchInterval:CS_MINIMUM_FETCH_INTERVAL];
    
    // - the status bar is disabled to begin with
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    
    // - look for how appearance attributes look together.
#ifdef CHATSEAL_GENERATE_APP_PALETTE_IMG
    [self debugGenerateAppPaletteImage];
#endif
    
    // - general appearance attributes.
    [[UISwitch appearance] setOnTintColor:[ChatSeal defaultSwitchOnColor]];
    [[UIButton appearance] setTitleColor:[ChatSeal defaultAppTintColor] forState:UIControlStateNormal];
    [[UIProgressView appearance] setProgressTintColor:[UIImageGeneration adjustColor:[ChatSeal defaultAppTintColor] byHuePct:1.0f andSatPct:1.0f andBrPct:1.25f andAlphaPct:1.0f]];
    [[UIButton appearanceWhenContainedIn:[UITableViewCell class], nil] setTitleColor:nil forState:UIControlStateNormal];
    
    // - create the initial view.
    self.window                    = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    self.window.tintColor          = [ChatSeal defaultAppTintColor];
#ifdef CHATSEAL_DEBUG_DISPLAY_LAUNCH_GENERATOR
    NSLog(@"INFO: (REMOVE) launch generator is being displayed.");
    self.window.rootViewController = [UILaunchGeneratorViewController launchGenerator];
#else 
    // ...during the upgrade to iOS8.1, I found that using an 'initial view controller' in the NIB caused the app to no longer rotate,
    //    which is why we're explicitly loading it here.
    self.window.rootViewController = [ChatSeal viewControllerForStoryboardId:@"UIChatSealNavigationController"];
#endif
    if ([self.window.rootViewController isKindOfClass:[UIChatSealNavigationController class]]) {
        [(UIChatSealNavigationController *) self.window.rootViewController setIsApplicationPrimary];
    }
    [self.window makeKeyAndVisible];
    
    return YES;
}

/*
 *  A URL was sent to the app that should be processed.
 */
-(BOOL) application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    if ([ChatSeal setCachedStartupURL:url]) {
        return YES;
    }
    return NO;
}

/*
 *  This is triggered whenever memory resources are scarce.
 */
-(void) applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    [ChatSeal clearCachedContent];
}

/*
 *  When we move to the background, see if low storage was a concern that may have been causing errors.
 */
-(void) applicationDidEnterBackground:(UIApplication *)application
{
    isLowStorageAtBackground = [ChatSeal isLowStorageAConcern];
}

/*
 *  When we move back into the foreground, see if low storage is now addressed and notify any interested
 *  parties.
 */
-(void) applicationWillEnterForeground:(UIApplication *)application
{
    if (isLowStorageAtBackground) {
        if (![ChatSeal isLowStorageAConcern]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kChatSealNotifyLowStorageResolved object:self];
        }
        isLowStorageAtBackground = NO;
    }
}

/*
 *  When the app is launched again to complete background downloads, this method is issued.
 */
-(void) application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler
{
    // - the rest of the app will just start up and fire up the feeds, so we don't have to do anything except save off the completion handler.
    [ChatSeal saveBackgroundSessionCompletionHandler:completionHandler];
}

/*
 *  A background fetch opportunity has been presented.
 */
-(void) application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    // - only if the collector is open by this point will we continue.  It may not open if there are problems.
    if ([[ChatSeal applicationFeedCollector] isOpen]) {
        // - if the collector is already dormant, then there was nothing to do.
        if (hasGoneDormantOnce) {
            completionHandler(UIBackgroundFetchResultNoData);
            return;
        }

        // ...otherwise, we'll wait for the notification to determine what to do about completion.
        fetchCompletion = Block_copy(completionHandler);
    }
    else {
        // - when there is no vault, we're not going to report ourselves as having failed, we just didn't get
        //   a shot yet.
        completionHandler(([ChatSeal hasVault] && [[ChatSeal applicationFeedCollector] isConfigured]) ? UIBackgroundFetchResultFailed : UIBackgroundFetchResultNoData);
    }
}

@end
