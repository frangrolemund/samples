//
//  UIPhotoLibraryAccessViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 9/27/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <AssetsLibrary/AssetsLibrary.h>
#import <QuartzCore/QuartzCore.h>
#import "UIPhotoLibraryAccessViewController.h"
#import "ChatSeal.h"

// - forward declarations
@interface UIPhotoLibraryAccessViewController (internal)
+(ALAuthorizationStatus) currentAuthStatus;
@end

/**********************************
 UIPhotoLibraryAccessViewController
 **********************************/
@implementation UIPhotoLibraryAccessViewController
/*
 *  Object attributes.
 */
{
}

/*
 *  Determine if we've asked the user yet to use the photo library.
 */
+(BOOL) photoLibraryAccessHasBeenRequested
{
    if ([UIPhotoLibraryAccessViewController currentAuthStatus] == ALAuthorizationStatusNotDetermined) {
        return NO;
    }
    return YES;
}

/*
 *  This method will determine if the photo library can be accessed without problems.
 */
+(BOOL) photoLibraryIsOpen
{
    return ([UIPhotoLibraryAccessViewController currentAuthStatus] == ALAuthorizationStatusAuthorized);
}

/*
 *  Request access to the photo library.
 */
+(void) requestPhotoLibraryAccessWithCompletion:(photoLibraryAccessCompletionBlock) completionBlock
{
    ALAssetsLibrary *alib = [[ALAssetsLibrary alloc] init];
    [alib enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        if (!group && *stop) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
                [alib autorelease];
                completionBlock(YES);
            }];
        }
        *stop = YES;
    } failureBlock:^(NSError *err){
        [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
            [alib autorelease];
            completionBlock(NO);
        }];
    }];
}
@end


/*********************************************
 UIPhotoLibraryAccessViewController (internal)
 *********************************************/
@implementation UIPhotoLibraryAccessViewController (internal)
/*
 *  Return the asset library authorization status.
 */
+(ALAuthorizationStatus) currentAuthStatus
{
    ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
    return status;
}
@end
