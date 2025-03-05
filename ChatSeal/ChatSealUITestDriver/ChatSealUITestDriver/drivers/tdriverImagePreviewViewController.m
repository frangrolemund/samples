//
//  tdriverImagePreviewViewController.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 4/13/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import "tdriverImagePreviewViewController.h"

//  - forward declarations
@interface tdriverImagePreviewViewController (internal)
@end

/**********************************
 tdriverImagePreviewViewController
 *********************************/
@implementation tdriverImagePreviewViewController
@synthesize ivPreview;

/*
 *  Instantiate an image preview controller for the given image.
 */
+(UIViewController *) imagePreviewForImage:(UIImage *) img
{
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"iOS7StoryBoard_iPhone" bundle:nil];
    tdriverImagePreviewViewController *ipvc = [sb instantiateViewControllerWithIdentifier:@"tdriverImagePreviewViewController"];
    [ipvc setImage:img];
    return ipvc;
}

/*
 *  Initialize the view
 */
- (id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        
    }
    return self;
}

/*
 *  Free the view.
 */
-(void) dealloc
{
    [imgCur release];
    imgCur = nil;
    
    [ivPreview release];
    ivPreview = nil;
    
    [super dealloc];
}

/*
 *  Configure the view.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    [ivPreview setImage:imgCur];
}

/*
 *  Set the image in the view.
 */
-(void) setImage:(UIImage *) img
{
    if (img) {
        NSLog(@"PREVIEW: Image orientation is %u", (unsigned) img.imageOrientation);
        NSLog(@"PREVIEW: Image size is %.0fx%.0f", img.size.width, img.size.height);
    }
    
    if (imgCur != img) {
        [imgCur release];
        imgCur = [img retain];
    }
    [ivPreview setImage:img];
}

@end


/*********************************************
 tdriverImagePreviewViewController (internal)
 *********************************************/
@implementation tdriverImagePreviewViewController (internal)

@end