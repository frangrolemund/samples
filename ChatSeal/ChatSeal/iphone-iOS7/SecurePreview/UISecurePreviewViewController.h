//
//  UISecurePreviewViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 11/21/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ChatSealMessage;
@interface UISecurePreviewViewController : UIViewController
-(void) setSecureImage:(UIImage *) image withPlaceholder:(UIImage *) imgPlaceholder andOwningMessage:(ChatSealMessage *) psm;
-(void) setInitialFadeEnabled:(BOOL) enabled;
@property (nonatomic, retain) IBOutlet UIImageView *ivBackground;
@end
