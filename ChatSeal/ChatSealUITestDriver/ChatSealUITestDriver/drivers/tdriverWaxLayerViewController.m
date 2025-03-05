//
//  tdriverWaxLayerViewController.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 6/14/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "tdriverWaxLayerViewController.h"
#import "UIdriverWaxView.h"

//  - forward declarations
@interface tdriverWaxLayerViewController (internal)
-(void) setLocked:(BOOL) isLocked;
-(void) setSmallSealSize:(CGFloat) pctOfMax;
@end

/*******************************
 tdriverWaxLayerViewController
 *******************************/
@implementation tdriverWaxLayerViewController
/*
 *  Object attributes.
 */
{
    UIdriverWaxView *wvBig;
    CGFloat         smallPct;
    UIdriverWaxView *wvSmall;
    UIImageView     *ivDecoy;
}
@synthesize lockedSwitch;

/*
 * Free the view.
 */
-(void) dealloc
{
    [wvBig release];
    wvBig = nil;
    
    [wvSmall release];
    wvSmall = nil;
    
    [lockedSwitch release];
    lockedSwitch = nil;
    
    [ivDecoy release];
    ivDecoy = nil;
    
    [super dealloc];
}

/*
 *  Configure the view.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    wvBig   = [[UIdriverWaxView alloc] init];
    [self.view addSubview:wvBig];
    wvSmall = [[UIdriverWaxView alloc] init];
    wvSmall.layer.borderColor = NULL;
    wvSmall.layer.borderWidth = 0.0f;
    [wvSmall prepareForSmallDisplay];
    [self.view addSubview:wvSmall];
    [self setLocked:[wvBig locked]];
    [self setSmallSealSize:0.0f];
    
    ivDecoy                   = [[UIImageView alloc] init];
    ivDecoy.contentMode       = UIViewContentModeScaleAspectFit;
    ivDecoy.layer.borderColor = [[UIColor blackColor] CGColor];
    ivDecoy.layer.borderWidth = 1.0f;
    [self.view addSubview:ivDecoy];
}

/*
 *  Do post-layout activities.
 */
-(void) viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    //  - make sure the layer stays in synch with the view.
    CGRect rc = self.view.bounds;
    CGFloat side = 0.0f;
    if (CGRectGetWidth(rc) < CGRectGetHeight(rc)) {
        side = CGRectGetWidth(rc);
    }
    else {
        side = CGRectGetHeight(rc);
    }
    
    side          *= 0.80f;
    wvBig.frame   = CGRectMake((CGRectGetWidth(rc)-side)/2.0f, (CGRectGetHeight(rc)-side)/2.0f, side, side);
    [self setSmallSealSize:smallPct];
    
    CGFloat startY = CGRectGetMaxY(wvBig.frame) + 20.0f;
    side           = CGRectGetHeight(self.view.bounds) - startY - 20.0f;
    ivDecoy.frame  = CGRectMake(CGRectGetWidth(self.view.bounds) - 20.0f - side, CGRectGetHeight(self.view.bounds) - 20.0f - side, side, side);
}

/*
 *  When the turn position is modified, this is called.
 */
-(IBAction)didChangeLocked:(id)sender
{
    [UIView animateKeyframesWithDuration:1.0f delay:0.0f options:0 animations:^(void){
        UISwitch *lockSwitch = (UISwitch *) sender;
        [self setLocked:lockSwitch.isOn];
    }completion:^(BOOL finished) {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(128.0f, 128.0f), YES, 0.0f);
        [[UIColor whiteColor] setFill];
        UIRectFill(CGRectMake(0.0f, 0.0f, 128.0f, 128.0f));
        [wvBig drawForDecoyRect:CGRectMake(0.0f, 0.0f, 128.0f, 128.0f)];
        UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        ivDecoy.image = img;
    }];
}

/*
 *  The small seal's size was adjusted.
 */
-(IBAction)didChangeSmallSeal:(id)sender
{
    UISlider *slider = (UISlider *) sender;
    [self setSmallSealSize:slider.value];
}

@end

/*****************************************
 tdriverWaxLayerViewController (internal)
 *****************************************/
@implementation tdriverWaxLayerViewController (internal)
/*
 *  Change the turn position.
 */
-(void) setLocked:(BOOL) isLocked
{
    [wvBig setLocked:isLocked];
    [wvSmall setLocked:isLocked];
    [lockedSwitch setOn:isLocked];
}

/*
 *  Change the size of the small seal.
 */
-(void) setSmallSealSize:(CGFloat) pctOfMax
{
    // - the maximum size is 64x64, although the smallest will only be 32x32.
    [UIView performWithoutAnimation:^(void) {
        CGFloat oneSide = 32 + (32.0f * pctOfMax);
        wvSmall.bounds = CGRectMake(0.0f, 0.0f, oneSide, oneSide);
        wvSmall.center = CGPointMake(CGRectGetMinX(wvBig.frame) + (oneSide/2.0f),
                                     CGRectGetMaxY(wvBig.frame) + ((CGRectGetHeight(self.view.bounds) - CGRectGetMaxY(wvBig.frame))/2.0f));
    }];
}
@end
