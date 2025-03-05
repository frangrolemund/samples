//
//  UIFeedAccessViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 4/28/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIFeedAccessViewController.h"
#import "ChatSeal.h"
#import "ChatSealFeedCollector.h"

// - forward declarations.
@interface UIFeedAccessViewController (internal) <UIGenericAccessViewControllerDelegate>
@end

/******************************
 UIFeedAccessViewController
 ******************************/
@implementation UIFeedAccessViewController
/*
 *  Object attributes.
 */
{
}

/*
 *  This is the title for feed access requests.
 */
+(NSString *) feedAccessTitle
{
    return NSLocalizedString(@"Permission Required", nil);
}

/*
 *  This description is the text used for requesting feed access.
 */
+(NSString *) feedAccessDescription
{
    return NSLocalizedString(@"ChatSeal will never misuse your Twitter accounts, but needs them to exchange your personal messages.", nil);
}

/*
 *  Convenience method for instantiating this view controller.
 */
+(UIGenericAccessViewController *) instantateViewControllerWithCompletion:(genericAccessCompletion) completionBlock
{
    UIGenericAccessViewController *gavc = [UIGenericAccessViewController instantateViewControllerWithAccessCompletion:completionBlock];
    UIFeedAccessViewController *favc    = [[[UIFeedAccessViewController alloc] init] autorelease];
    gavc.delegate                       = favc;
    return gavc;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
    }
    return self;
}


/*
 *  Free the object.
 */
-(void) dealloc
{
    [super dealloc];
}
@end

/******************************************
 UIFeedAccessViewController (internal)
 ******************************************/
@implementation UIFeedAccessViewController (internal)
/*
 *  Return the title string to use for the authorization request.
 */
-(NSString *) authTitle
{
    return [UIFeedAccessViewController feedAccessTitle];
}

/*
 *  Return the description string to use for the authorization request
 */
-(NSString *) authDescription
{
    return [UIFeedAccessViewController feedAccessDescription];
}

/*
 *  Return the title string to use for the locked status.
 */
-(NSString *) lockedTitle
{
    return nil;
}

/*
 *  Return the description string to use for the locked status.
 */
-(NSString *) lockedDescription
{
    return nil;
}

/*
 *  Indicates whether we should skip directly to a locked state.
 */
-(BOOL) accessViewControllerShouldShowLockedOnStartup:(UIGenericAccessViewController *)vc
{
    // - we never show the locked screen because we represent no-auth in the selection screen.
    return NO;
}

/*
 *  When the user wants to proceed with authorization, this delegate method is fired.
 */
-(void) accessViewControllerAuthContinuePressed:(UIGenericAccessViewController *)vc
{
    [[ChatSeal applicationFeedCollector] openAndQuery:YES withCompletion:^(ChatSealFeedCollector *collector, BOOL success, NSError *err) {
        if (!success) {
            NSLog(@"CS: Failed to open the collector during authorization.  %@", [err localizedDescription]);
        }
        [vc doCloseTheView];
    }];
}
@end
