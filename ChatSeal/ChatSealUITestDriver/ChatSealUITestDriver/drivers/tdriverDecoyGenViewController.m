//
//  tdriverDecoyGenViewController.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 10/21/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import "tdriverDecoyGenViewController.h"
#import "ChatSeal.h"
#import "UISealedMessageEnvelopeViewV2.h"
#import "UINewSealCell.h"

// - forward declarations
@interface tdriverDecoyGenViewController (internal)
@end

/*******************************
 tdriverDecoyGenViewController
 *******************************/
@implementation tdriverDecoyGenViewController
/*
 *  Object attributes
 */
{
}
@synthesize ivDisplay;

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [ivDisplay release];
    ivDisplay = nil;
    
    [super dealloc];
}

/*
 *  Configure the view.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // - make sure the vault exists so that we can get
    //   an active seal.
    NSError *err = nil;
    if ([ChatSeal hasVault]) {
        if (![ChatSeal openVaultWithPassword:nil andError:&err]) {
            NSLog(@"DEBUG: Failed to open vault.  %@", [err localizedDescription]);
            return;
        }
    }
    else {
        NSLog(@"DEBUG: NO VAULT EXISTS!");
#if 0           //  make sure you want to do this!
        if (![ChatSeal initializeVaultWithError:&err]) {
            NSLog(@"DEBUG: Failed to init vault.  %@", [err localizedDescription]);
            return;
        }
        
        if (![ChatSeal createSealWithImage:[UIImage imageNamed:@"sample-face.jpg"] andColor:RSSC_GREEN andError:&err]) {
            NSLog(@"DEBUG: failed to create the new active seal.  %@", [err localizedDescription]);
        }
#endif
    }
    
    // - set the image.
    UIImage *img = [UISealedMessageEnvelopeViewV2 standardDecoyForActiveSeal];
    ivDisplay.image = img;
    
    // - create a reference seal image
    UINewSealCell *nsc    = [ChatSeal activeSealCellOfHeight:100.0f];
    nsc.layer.borderColor = [[UIColor blackColor] CGColor];
    nsc.layer.borderWidth = 1.0f;
    CGRect rc             = nsc.frame;
    rc.origin             = CGPointMake(10.0f, 10.0f);
    nsc.frame             = rc;
    [self.view addSubview:nsc];
}

@end


/****************************************
 tdriverDecoyGenViewController (internal)
 ****************************************/
@implementation tdriverDecoyGenViewController (internal)
@end