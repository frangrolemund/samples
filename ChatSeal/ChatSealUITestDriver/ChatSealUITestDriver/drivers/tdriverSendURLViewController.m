//
//  tdriverSendURLViewController.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 4/22/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import "tdriverSendURLViewController.h"

//  - forward declarations
@interface tdriverSendURLViewController (internal)

@end

/******************************
 tdriverSendURLViewController
 ******************************/
@implementation tdriverSendURLViewController

/*
 *  Send a PNG to the app.
 */
-(IBAction)doSendSimplePNG:(id)sender
{
    for (NSBundle *bun in [NSBundle allBundles]) {
        NSURL *u = [bun URLForResource:@"simple-png" withExtension:@"png"];
        if (u) {
            UIDocumentInteractionController *dic = [UIDocumentInteractionController interactionControllerWithURL:u];
            [dic retain];
            if (![dic presentOpenInMenuFromRect:self.view.bounds inView:self.view animated:YES]) {
                NSLog(@"DEBUG: failed to present custom document interaction controller.");
            }
            break;
        }
    }
}
@end


/****************************************
 tdriverSendURLViewController (internal)
 ****************************************/
@implementation tdriverSendURLViewController (internal)

@end