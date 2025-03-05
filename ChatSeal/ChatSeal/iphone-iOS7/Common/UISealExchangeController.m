//
//  UISealExchangeController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/17/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealExchangeController.h"
#import "ChatSeal.h"
#import "UIChatSealNavigationController.h"
#import "UISealShareViewController.h"
#import "UISealAcceptViewController.h"

// - forward declarations
@interface UISealExchangeConfiguration (internal)
+(UISealExchangeConfiguration *) configurationForIdentity:(ChatSealIdentity *) psi;
-(void) setCompletionBlock:(sealExchangeCompletion) cb;
@end

// - shared declarations
@interface UISealExchangeController (shared)
+(UIViewController *) sealShareViewControllerForConfiguration:(UISealExchangeConfiguration *) config;
+(UIViewController *) sealAcceptViewControllerForConfiguration:(UISealExchangeConfiguration *) config;
+(void) prepareForExchangeTargetDisplay:(UIViewController<UISealExchangeFlipTarget> *) vc asScanner:(BOOL) isScanning andAssumeMultiUse:(BOOL) multiUse;
+(void) completeExchangeNavigationAfterDidAppearForController:(UIViewController<UISealExchangeFlipTarget> *) vc;
+(void) setSealTransferStateForViewController:(UIViewController<UISealExchangeFlipTarget> *) vc asEnabled:(BOOL) isEnabled;
+(void) reconfigureExchangeTargetDisplay:(UIViewController<UISealExchangeFlipTarget> *) vc asScanner:(BOOL) isScanning andAssumeMultiUse:(BOOL) multiUse;
@end

/*****************************
 UISealExchangeController
 *****************************/
@implementation UISealExchangeController
/*
 *  Return a seal sharing view controller for the given identity.
 */
+(UIViewController *) sealShareViewControllerForIdentity:(ChatSealIdentity *) psi
{
    UISealExchangeConfiguration *config = [UISealExchangeConfiguration configurationForIdentity:psi];
    return [UISealExchangeController sealShareViewControllerForConfiguration:config];
}

/*
 *  Return a seal sharing view controller that can be displayed modally for the given identity.
 */
+(UIViewController *) modalSealShareViewControllerForIdentity:(ChatSealIdentity *) psi withCompletion:(sealExchangeCompletion) completionBlock
{
    UISealExchangeConfiguration *config = [UISealExchangeConfiguration configurationForIdentity:psi];
    config.isModal                      = YES;
    [config setCompletionBlock:completionBlock];
    UIViewController *ssvc              = [UISealExchangeController sealShareViewControllerForConfiguration:config];
    UINavigationController *nc          = [[[UIChatSealNavigationController alloc] initWithRootViewController:ssvc] autorelease];
    return nc;
}

/*
 *  Return a seal accept view controller for the given identity.
 */
+(UIViewController *) sealAcceptViewControllerForIdentity:(ChatSealIdentity *) psi
{
    UISealExchangeConfiguration *config = [UISealExchangeConfiguration configurationForIdentity:psi];
    return [UISealExchangeController sealAcceptViewControllerForConfiguration:config];
}

/*
 *  Return a seal accept view controller that can be displayed modally for a given identity.
 */
+(UIViewController *) modalSealAcceptViewControllerForIdentity:(ChatSealIdentity *) psi
                                  andEnforceFirstTimeSemantics:(BOOL) firstTime
                                                withCompletion:(sealExchangeCompletion) completionBlock
{
    UISealExchangeConfiguration *config = [UISealExchangeConfiguration configurationForIdentity:psi];
    config.isModal                      = YES;
    config.isFirstTime                  = firstTime;
    [config setCompletionBlock:completionBlock];
    UIViewController *savc              = [UISealExchangeController sealAcceptViewControllerForConfiguration:config];
    UINavigationController *nc          = [[[UIChatSealNavigationController alloc] initWithRootViewController:savc] autorelease];
    return nc;
}
@end

/**********************************
 UISealExchangeController (shared)
 **********************************/
@implementation UISealExchangeController (shared)
/*
 *  Instantiate a common share controller.
 */
+(UIViewController *) sealShareViewControllerForConfiguration:(UISealExchangeConfiguration *) config
{
    UISealShareViewController *ssvc = (UISealShareViewController *) [ChatSeal viewControllerForStoryboardId:@"UISealShareViewController"];
    [ssvc setConfiguration:config];
    return ssvc;
}

/*
 *  Instantiate a common accept controller.
 */
+(UIViewController *) sealAcceptViewControllerForConfiguration:(UISealExchangeConfiguration *) config
{
    UISealAcceptViewController *savc = (UISealAcceptViewController *) [ChatSeal viewControllerForStoryboardId:@"UISealAcceptViewController"];
    [savc setConfiguration:config];
    return savc;
}

/*
 *  When the exchange target is loaded, we may need to do some extra common configuration.
 */
+(void) prepareForExchangeTargetDisplay:(UIViewController<UISealExchangeFlipTarget> *) vc asScanner:(BOOL) isScanning andAssumeMultiUse:(BOOL) multiUse
{
    UISealExchangeConfiguration *config = [vc configuration];
    
    // - swapping beetween share/accept is possible if this isn't a new user experience because we don't
    //   want to overcomplicate that first time for them.
    if (!config.isFirstTime) {
        UIBarButtonItem *bbiSwap = [[[UIBarButtonItem alloc] initWithTitle:isScanning ? NSLocalizedString(@"Share", nil) : NSLocalizedString(@"Accept", nil)
                                                                     style:UIBarButtonItemStylePlain target:vc action:@selector(doSwapModes)] autorelease]; 
        // - the swap button goes on the right when we're in a standard navigation stack or on the left when
        //   this view is acting modally.
        if (config.isModal) {
            if (vc.navigationItem.leftBarButtonItem) {
                [vc.navigationItem setLeftBarButtonItem:bbiSwap animated:YES];
            }
            else {
                vc.navigationItem.leftBarButtonItem = bbiSwap;
            }
        }
        else {
            if (vc.navigationItem.rightBarButtonItem) {
                [vc.navigationItem setRightBarButtonItem:bbiSwap animated:YES];
            }
            else {
                vc.navigationItem.rightBarButtonItem = bbiSwap;
            }
        }
    }

    // - when working modally, use a common done button and make sure the back button is hidden because we will never go back.
    if (config.isModal) {
        vc.navigationItem.hidesBackButton    = YES;
        UIBarButtonItem *bbiDone             = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:multiUse ? UIBarButtonSystemItemDone : UIBarButtonSystemItemCancel
                                                                                              target:vc action:@selector(doModalDone)] autorelease];
        if (vc.navigationItem.rightBarButtonItem) {
            [vc.navigationItem setRightBarButtonItem:bbiDone animated:YES];
        }
        else {
            vc.navigationItem.rightBarButtonItem = bbiDone;
        }
    }
}

/*
 *  This is used in rare scenarios to re-create the nav buttons.
 */
+(void) reconfigureExchangeTargetDisplay:(UIViewController<UISealExchangeFlipTarget> *) vc asScanner:(BOOL) isScanning andAssumeMultiUse:(BOOL) multiUse
{
    [UISealExchangeController prepareForExchangeTargetDisplay:vc asScanner:isScanning andAssumeMultiUse:multiUse];
}

/*
 *  After one of the seal exchange views completes its navigation, we need to ensure that moving back
 *  goes to the prior view controller, not the prior exchange view controller.
 */
+(void) completeExchangeNavigationAfterDidAppearForController:(UIViewController<UISealExchangeFlipTarget> *) vc
{
    NSArray *arrExisting = vc.navigationController.viewControllers;
    if ([arrExisting count] > 1) {
        NSMutableArray *maViewControllers = [NSMutableArray array];
        for (UIViewController *vcNavItem in arrExisting) {
            if (([vcNavItem isKindOfClass:[UISealShareViewController class]] || [vcNavItem isKindOfClass:[UISealAcceptViewController class]]) &&
                vcNavItem != vc) {
                continue;
            }
            [maViewControllers addObject:vcNavItem];
        }
        [vc.navigationController setViewControllers:maViewControllers animated:NO];
        
        // - create a back button that can be used for the next target
        if ([maViewControllers count] > 1) {
            UIViewController *vcPrior = (UIViewController *) [maViewControllers objectAtIndex:[maViewControllers count] - 2];
            NSString *title           = vcPrior.navigationItem.title;
            if (vcPrior.navigationItem.backBarButtonItem) {
                title = vcPrior.navigationItem.backBarButtonItem.title;
            }
            UIBarButtonItem *bbiBack            = [[[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStylePlain target:nil action:nil] autorelease];
            vc.navigationItem.backBarButtonItem = bbiBack;
        }
    }
}

/*
 *  While we're transferring a seal, the view controller is not permitted to swap modes.  This is more of a protection against accidentally tapping that
 *  button with your finger than anything.
 */
+(void) setSealTransferStateForViewController:(UIViewController<UISealExchangeFlipTarget> *) vc asEnabled:(BOOL) isEnabled
{
    UISealExchangeConfiguration *config = [vc configuration];
    if (config.isModal) {
        vc.navigationItem.leftBarButtonItem.enabled = isEnabled;
    }
    else {
        vc.navigationItem.rightBarButtonItem.enabled = isEnabled;
    }
}

/*
 *  When we're in the final phase of seal transfer during import, we don't want to permit return navigation because that may screw up
 *  the experience.
 */
+(void) setPreventReturnNavigationForViewController:(UIViewController<UISealExchangeFlipTarget> *) vc asEnabled:(BOOL) isEnabled
{
    // - it isn't possible to disable the back button, so we'll just disable the whole bar.
    [vc.navigationController.navigationBar setUserInteractionEnabled:isEnabled];
}
@end

/******************************
 UISealExchangeConfiguration
 ******************************/
@implementation UISealExchangeConfiguration
/*
 *  Object attributes
 */
{
    sealExchangeCompletion completionBlock;
    NSMutableDictionary    *mdSealsAccepted;
}
@synthesize sealIdentity;
@synthesize isModal;
@synthesize isFirstTime;
@synthesize sealsShared;
@synthesize newSealsAccepted;

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        sealIdentity     = nil;
        isModal          = NO;
        isFirstTime      = NO;
        completionBlock  = nil;
        sealsShared      = 0;
        newSealsAccepted = 0;
        mdSealsAccepted  = [[NSMutableDictionary alloc] init];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [sealIdentity release];
    sealIdentity = nil;
    
    [mdSealsAccepted release];
    mdSealsAccepted = nil;
    
    [self setCompletionBlock:nil];
    
    [super dealloc];
}

/*
 *  Return the completion block if it is assigned.
 */
-(sealExchangeCompletion) completionBlock
{
    return completionBlock;
}

/*
 *  The exchange configuration associates the service host with each seal we accept so that
 *  we can avoid re-querying the same remote device even if the URL changes.
 */
-(NSMutableDictionary *) sealsAcceptedPerHost
{
    return [[mdSealsAccepted retain] autorelease];
}

@end

/**************************************
 UISealExchangeConfiguration (internal)
 **************************************/
@implementation UISealExchangeConfiguration (internal)
/*
 *  Quickly create a configuration and return it.
 */
+(UISealExchangeConfiguration *) configurationForIdentity:(ChatSealIdentity *)psi
{
    UISealExchangeConfiguration *sec = [[[UISealExchangeConfiguration alloc] init] autorelease];
    if (!psi) {
        NSError *err = nil;
        psi = [ChatSeal activeIdentityWithError:&err];
    }
    sec.sealIdentity = psi;
    return sec;
}

/*
 *  Assign the completion block.
 */
-(void) setCompletionBlock:(sealExchangeCompletion) cb
{
    if (completionBlock != cb) {
        Block_release(completionBlock);
        completionBlock = Block_copy(cb);
    }
}
@end
