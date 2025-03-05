//
//  tdriverFrostedViewController.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 6/19/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "tdriverFrostedViewController.h"
#import "UIImageGeneration.h"

//  - forward declarations.
@interface tdriverFrostedViewController (internal)
-(void) switchFrostingToOn:(BOOL) isOn;
@end

/****************************
 tdriverFrostedViewController
 ****************************/
@implementation tdriverFrostedViewController
/*
 *  Object attributes.
 */
{
    UIImageView *vFrosted;
}

@synthesize ivPicture;

/*
 *  Custom configuration.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    vFrosted = nil;
    vFrosted.layer.borderColor = [[UIColor blackColor] CGColor];
    vFrosted.layer.borderWidth = 2.0f;
    [self.view bringSubviewToFront:vFrosted];
    [self switchFrostingToOn:NO];
}

/*
 *  This is sent by the switch when the frosting requirement
 *  changes.
 */
-(IBAction)doChangeFrosting:(UISwitch *)sender
{
    [self switchFrostingToOn:sender.isOn];
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [ivPicture release];
    ivPicture = nil;
    
    [super dealloc];
}

@end

/**************************************
 tdriverFrostedViewController (internal)
 **************************************/
@implementation tdriverFrostedViewController (internal)
/*
 *  Save the image
 */
-(void) debugSaveImage:(UIImage *) img
{
    NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    u = [u URLByAppendingPathComponent:@"frosted.png"];
    NSData *d = UIImagePNGRepresentation(img);
    if (![d writeToURL:u atomically:YES]) {
        NSLog(@"DEBUG: failed to save the generated image.");
    }
}

/*
 *  Turn the frosted pane on/off.
 */
-(void) switchFrostingToOn:(BOOL) isOn
{
    if (vFrosted) {
        [vFrosted removeFromSuperview];
        [vFrosted release];
        vFrosted = nil;
    }
    
    if (isOn) {
        CALayer *l = ivPicture.layer.presentationLayer;
        CGImageRef ir = (CGImageRef) l.contents;
        if (ir) {
            UIImage *img = [UIImage imageWithCGImage:ir scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp];
            NSLog(@"DEBUG: begin blur");
//            img = [UIImageGeneration frostedImageFromImage:img];
//            [self debugSaveImage:img];
            NSLog(@"DEBUG: end blur");
            if (img) {
                vFrosted = [[UIImageView alloc] initWithImage:img];
                vFrosted.backgroundColor = [UIColor whiteColor];                
                vFrosted.contentMode = UIViewContentModeScaleAspectFill;
                vFrosted.frame = ivPicture.frame;
                vFrosted.clipsToBounds = YES;
                [self.view addSubview:vFrosted];
            }            
        }
        
    }
}
@end
