//
//  tdriverTabBarGenViewController.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 6/1/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "tdriverTabBarGenViewController.h"
#import "UIImageGeneration.h"

// - forward declarations
@interface tdriverTabBarGenViewController (internal)
-(void) configurePreviewWindows;
@end

/*****************************
 tdriverTabBarGenViewController
 *****************************/
@implementation tdriverTabBarGenViewController
@synthesize ivSmallPreview1;
@synthesize ivSmallPreview2;
@synthesize ivSmallPreview3;
@synthesize ivSmallPreview4;

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
    [ivSmallPreview1 release];
    ivSmallPreview1 = nil;
    
    [ivSmallPreview2 release];
    ivSmallPreview2 = nil;
    
    [ivSmallPreview3 release];
    ivSmallPreview3 = nil;
    
    [ivSmallPreview4 release];
    ivSmallPreview4 = nil;
    
    [super dealloc];
}

/*
 *  Configure the view
 */
- (void)viewDidLoad 
{
    [super viewDidLoad];
    [self configurePreviewWindows];
}

@end

/***********************************************
 tdriverTabBarGenViewController (internal)
 ***********************************************/
@implementation tdriverTabBarGenViewController (internal)
/*
 *  Generate preview images in the top windows.
 */
-(void) configurePreviewWindows
{
    ivSmallPreview1.layer.borderColor = [[UIColor blackColor] CGColor];
    ivSmallPreview1.layer.borderWidth = 1.0f;
    ivSmallPreview2.layer.borderColor = [[UIColor blackColor] CGColor];
    ivSmallPreview2.layer.borderWidth = 1.0f;
    ivSmallPreview3.layer.borderColor = [[UIColor blackColor] CGColor];
    ivSmallPreview3.layer.borderWidth = 1.0f;
    ivSmallPreview4.layer.borderColor = [[UIColor blackColor] CGColor];
    ivSmallPreview4.layer.borderWidth = 1.0f;
    
    ivSmallPreview1.image = [UIImageGeneration tabBarImageFromImage:@"190-bank.png" andTint:[UIColor redColor] andIsSelected:YES];
    ivSmallPreview2.image = [UIImageGeneration tabBarImageFromImage:@"83-calendar.png" andTint:[UIColor blueColor] andIsSelected:NO];
    ivSmallPreview3.image = [UIImageGeneration tabBarImageFromImage:@"121-landscape.png" andTint:[UIColor greenColor] andIsSelected:YES];
    ivSmallPreview4.image = [UIImageGeneration tabBarImageFromImage:@"281-crown.png" andTint:[UIColor purpleColor] andIsSelected:NO];
}
@end