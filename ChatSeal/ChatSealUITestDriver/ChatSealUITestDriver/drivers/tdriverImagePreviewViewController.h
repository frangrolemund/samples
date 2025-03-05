//
//  tdriverImagePreviewViewController.h
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 4/13/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface tdriverImagePreviewViewController : UIViewController
{
    UIImage *imgCur;
    UIImageView *ivPreview;
}

+(UIViewController *) imagePreviewForImage:(UIImage *) img;
-(void) setImage:(UIImage *) img;

@property (nonatomic, retain) IBOutlet UIImageView *ivPreview;

@end
