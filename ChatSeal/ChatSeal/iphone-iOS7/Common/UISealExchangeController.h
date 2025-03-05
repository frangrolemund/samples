//
//  UISealExchangeController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/17/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

// - for configuring a given view controller
@class ChatSealIdentity;
typedef void (^sealExchangeCompletion)(BOOL hasExchangedASeal);
@interface UISealExchangeConfiguration : NSObject
@property (nonatomic, retain)   ChatSealIdentity *sealIdentity;
@property (nonatomic, assign)   BOOL              isModal;
@property (nonatomic, assign)   BOOL              isFirstTime;
@property (nonatomic, assign)   NSUInteger        sealsShared;
@property (nonatomic, assign)   NSUInteger        newSealsAccepted;
-(NSMutableDictionary *) sealsAcceptedPerHost;
-(sealExchangeCompletion) completionBlock;
@end

// - the two view controllers will adhere to this protocol.
@protocol UISealExchangeFlipTarget <NSObject>
-(void) setConfiguration:(UISealExchangeConfiguration *) config;
-(UISealExchangeConfiguration *) configuration;
-(void) doModalDone;
-(void) doSwapModes;
@end

// - and of course for quickly creating the view controllers.
@interface UISealExchangeController : NSObject
+(UIViewController *) sealShareViewControllerForIdentity:(ChatSealIdentity *) psi;
+(UIViewController *) modalSealShareViewControllerForIdentity:(ChatSealIdentity *) psi withCompletion:(sealExchangeCompletion) completionBlock;
+(UIViewController *) sealAcceptViewControllerForIdentity:(ChatSealIdentity *) psi;
+(UIViewController *) modalSealAcceptViewControllerForIdentity:(ChatSealIdentity *) psi
                                  andEnforceFirstTimeSemantics:(BOOL) firstTime
                                                withCompletion:(sealExchangeCompletion) completionBlock;
@end
