//
//  UIFakeKeyboardV2.h
//  ChatSeal
//
//  Created by Francis Grolemund on 10/30/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UIFakeKeyboardV2 : NSObject
+(void) setKeyboardMaskingEnabled:(BOOL) isEnabled;
+(void) updateKeyboardEffectFromView:(UIView *) vw;
+(UIImage *) currentKeyboardEffectImage;
+(void) setKeyboardVisible:(BOOL) isVisible;
+(CGSize) keyboardSize;
+(BOOL) verifySnapshotIsReady;
+(UIView *) keyboardSnapshot;
+(void) forceAKeyboardSnapshotUpdate;
@end
