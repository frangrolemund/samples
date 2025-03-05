//
//  tdriverVaultFailureViewController.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 1/8/14.
//  Copyright (c) 2014 Francis Grolemund. All rights reserved.
//

#import "tdriverVaultFailureViewController.h"
#import "ChatSeal.h"

// - forward declarations
@interface tdriverVaultFailureViewController (internal) <UIVaultFailureOverlayViewDelegate>
-(void) toggleErrorState;
@end

/**********************************
 tdriverVaultFailureViewController
 **********************************/
@implementation tdriverVaultFailureViewController
/*
 *  Object attributes.
 */
{
    BOOL isShowingError;
}
@synthesize vfoErrorOverlay;

/*
 *  Free the object.
 */
-(void) dealloc
{
    vfoErrorOverlay.delegate = nil;
    [vfoErrorOverlay release];
    vfoErrorOverlay = nil;
    
    [super dealloc];
}

/*
 *  Configure the view.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    isShowingError = YES;
    vfoErrorOverlay.delegate = self;
    [self toggleErrorState];

    // - reference for alert look and feel.
#if 0
    UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Seals Unavailable" message:@"Your iPhone was unable to open your vault to access your seal list.  Please try this again the next time you restart your device." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [av show];
    [av release];
#endif
}

/*
 *  Manage the rotation while in error mode.
 */
-(void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    if (isShowingError) {
        // - force the overlay to requst a new placeholder.
        isShowingError = NO;
        [self toggleErrorState];
    }
}
@end


/*********************************************
 tdriverVaultFailureViewController (internal)
 *********************************************/
@implementation tdriverVaultFailureViewController (internal)
/*
 *  Switch between error states.
 */
-(void) toggleErrorState
{
    UIBarButtonItem *bbiRight = nil;
    if (isShowingError) {
        [vfoErrorOverlay hideFailureWithAnimation:YES];
        bbiRight = [[[UIBarButtonItem alloc] initWithTitle:@"Show" style:UIBarButtonItemStyleBordered target:self action:@selector(toggleErrorState)] autorelease];
    }
    else {
        [vfoErrorOverlay showFailureWithTitle:@"Seals Unavailable" andText:@"Your %@ was unable to open the vault to access your seal list." andAnimation:YES];
        bbiRight = [[[UIBarButtonItem alloc] initWithTitle:@"Hide" style:UIBarButtonItemStyleBordered target:self action:@selector(toggleErrorState)] autorelease];
    }
    isShowingError = !isShowingError;
    self.navigationItem.rightBarButtonItem = bbiRight;
}

/*
 *  Generate a placeholder to represent a vault failure.
 */
+(UIImage *) generateVaultFailurePlaceholderOfSize:(CGSize) szPlaceholder withInsets:(UIEdgeInsets) insets andContext:(NSObject *)ctx
{
    CGSize szMe = [ChatSeal appWindowDimensions];
    UIGraphicsBeginImageContextWithOptions(szMe, YES, 0.0f);
    
    //  - basic background.
    [[UIColor whiteColor] setFill];
    UIRectFill(CGRectMake(0.0f, 0.0f, szMe.width, szMe.height));
    
    //  - now some content.
    int numSegs       = 7;
    CGFloat segHeight = szMe.height/numSegs;
    for (int i = 0; i < numSegs; i++) {
        CGFloat pad  = segHeight / 5.0f;
        CGFloat diam = segHeight - (pad * 2.0f);
        
        CGFloat yOffset = (CGFloat) i * segHeight;
        CGFloat xOffset = pad;
        
        UIColor *cDot = nil;
        switch (i) {
            case 0:
                cDot = [UIColor redColor];
                break;
                
            case 1:
                cDot = [UIColor blueColor];
                break;
                
            case 2:
                cDot = [UIColor greenColor];
                break;
                
            case 3:
                cDot = [UIColor lightGrayColor];
                break;
                
            case 4:
                cDot = [UIColor orangeColor];
                break;
                
            case 5:
                cDot = [UIColor purpleColor];
                break;
                
            case 6:
                cDot = [UIColor yellowColor];
                break;
        }
        
        [cDot setFill];
        CGContextFillEllipseInRect(UIGraphicsGetCurrentContext(), CGRectMake(xOffset, yOffset + pad, diam, diam));
        
        if (i < 6) {
            CGContextSetLineWidth(UIGraphicsGetCurrentContext(), 1.0f/[UIScreen mainScreen].scale);
            [[UIColor darkGrayColor] setStroke];
            CGContextBeginPath(UIGraphicsGetCurrentContext());
            CGContextMoveToPoint(UIGraphicsGetCurrentContext(), 0.0f, yOffset + segHeight);
            CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), szMe.width, yOffset + segHeight);
            CGContextStrokePath(UIGraphicsGetCurrentContext());
        }
    }
    
    UIImage *imgRet = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return imgRet;
}

/*
 *  Create a sample placeholder image.
 */
-(UIImage *) placeholderImageForOverlay:(UIVaultFailureOverlayView *)overlay
{
    return [tdriverVaultFailureViewController generateVaultFailurePlaceholderOfSize:self.view.bounds.size withInsets:UIEdgeInsetsZero andContext:nil];
}
@end