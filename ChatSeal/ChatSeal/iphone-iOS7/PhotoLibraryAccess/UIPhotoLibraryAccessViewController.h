//
//  UIPhotoLibraryAccessViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 9/27/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^photoLibraryAccessCompletionBlock)(BOOL isAuthorized);

@interface UIPhotoLibraryAccessViewController : NSObject
+(BOOL) photoLibraryAccessHasBeenRequested;
+(BOOL) photoLibraryIsOpen;
+(void) requestPhotoLibraryAccessWithCompletion:(photoLibraryAccessCompletionBlock) completionBlock;
@end
