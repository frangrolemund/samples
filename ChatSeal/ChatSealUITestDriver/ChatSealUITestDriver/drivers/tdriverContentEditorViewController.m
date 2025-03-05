//
//  tdriverContentEditorViewController.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 7/12/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "tdriverContentEditorViewController.h"
#import "UISealedMessageEditorContentViewV3.h"
#import "ChatSeal.h"

// - forward declarations
@interface tdriverContentEditorViewController (internal) <UISealedMessageEditorContentViewV3Delegate>
-(void) keyboardWillChange:(NSNotification *) notification;
-(void) resizeEditorWithDuration:(CGFloat) duration andOptions:(UIViewAnimationOptions) options;
-(void) fontUpdatedNotification;
@end

/************************************
 tdriverContentEditorViewController
 ************************************/
@implementation tdriverContentEditorViewController
/*
 *  Object attributes
 */
{
    CGFloat                            minY;
    UISealedMessageEditorContentViewV3 *contentView;
    BOOL                               animatingFrame;
    BOOL                               didAppear;
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        animatingFrame = NO;
        didAppear      = NO;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillChange:) name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillChange:) name:UIKeyboardWillHideNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fontUpdatedNotification) name:UIContentSizeCategoryDidChangeNotification object:nil];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [contentView release];
    contentView = nil;
    
    [super dealloc];
}

/*
 *  Configure the view.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    contentView                  = [[UISealedMessageEditorContentViewV3 alloc] initWithFrame:self.view.bounds];
    contentView.layer.borderColor = [[UIColor blackColor] CGColor];
    contentView.layer.borderWidth = 1.0f;
    contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    contentView.delegate         = self;
    [self.view addSubview:contentView];
    minY = -1.0f;
    [contentView setHintText:@"Type some text here."];
    
    //  DEBUG with prepopulated data if you wish.
    //  DEBUG
#if 0
    static NSString *DRIVER_MSG_LOREM = @"Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";    
    NSMutableArray *maItems = [NSMutableArray array];
    for (int i = 0, j = 0; i < 5; i++) {
//    for (int i = 0, j = 0; i < 3; i++) {
//    for (int i = 34, j = 1; i < 40; i++) {
    
        if (i % 2 == 0) {
            [maItems addObject:[NSString stringWithFormat:@"%d with some text --> %@", i, [DRIVER_MSG_LOREM substringToIndex:i*5]]];
        }
        else {
            switch (j % 4)
            {
                case 0:
                    [maItems addObject:[UIImage imageNamed:@"sample-face.jpg"]];
                    break;
                    
                case 1:
                    [maItems addObject:[UIImage imageNamed:@"simple-png.png"]];                    
                    break;
                    
                case 2:
                    [maItems addObject:[UIImage imageNamed:@"seal_sample1.jpg"]];
                    break;
                    
                case 3:
                    [maItems addObject:[UIImage imageNamed:@"seal_sample23.jpg"]];
                    break;
            }
            j++;
        }
    }
    [contentView setContentItems:maItems];
#endif
    
//    [contentView setContentItems:[NSArray arrayWithObject:@"One\nTwo\nThree"]];
    [contentView becomeFirstResponder];
    //contentView.clipsToBounds = NO;
}

-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    didAppear = YES;
}

-(void) viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    // - only do this once or we'll lose the correct value.
    if (minY < 0.0f) {
        minY = CGRectGetHeight(self.view.bounds);
    }
    
    //  DEBUG-temporary
    //contentView.frame = CGRectMake(10.0f, 10.0f, CGRectGetWidth(self.view.bounds) - 20.0f, CGRectGetHeight(self.view.bounds)/2.0f);
    //  DEBUG-temporary
}

/*
 *  Add a photo to the message.
 */
-(IBAction)doAddPhoto:(id)sender
{
    [contentView addPhotoAtCursorPosition:[UIImage imageNamed:@"sample-face.jpg"]];
}

-(void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    minY = CGRectGetHeight(self.view.bounds);
    [self resizeEditorWithDuration:duration andOptions:0];
}

@end

/**********************************************
 tdriverContentEditorViewController (internal)
 **********************************************/
@implementation tdriverContentEditorViewController (internal)

/*
 *  When the keyboard will be shown or hidden, this notification fires.
 */
-(void) keyboardWillChange:(NSNotification *) notification
{
    NSLog(@"DEBUG: keyboard will change now!");
    if (notification.userInfo) {
        NSValue *vFrame  = [notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey];
        NSNumber *nCurve = [notification.userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey];
        NSNumber *nDur   = [notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
        
        CGRect rcKBFrame = [vFrame CGRectValue];
        minY = CGRectGetHeight(self.view.bounds);
        CGRect rcIntersect = CGRectIntersection(rcKBFrame, self.view.bounds);
        if ((int) CGRectGetWidth(rcIntersect) > 0 && (int) CGRectGetHeight(rcIntersect) > 0) {
            // - the keyboard will either slide down, but also slide to the side if there isn't enough time.
            rcKBFrame        = [self.view convertRect:rcKBFrame fromView:[[UIApplication sharedApplication] keyWindow]];
            if (!vFrame) {
                return;
            }
            minY = CGRectGetMinY(rcKBFrame);
        }
        [self resizeEditorWithDuration:nDur.floatValue andOptions:nCurve.integerValue];
    }
}

-(CGFloat) expectedContentHeight
{
    // - compute the size of the scroll view based on its content size.
    CGSize szContent = contentView.contentSize;
    CGFloat height = szContent.height;
    if (height > minY) {
        height = minY;
    }
    return height;
}

/*
 *  Resize the editor.
 */
-(void) resizeEditorWithDuration:(CGFloat) duration andOptions:(UIViewAnimationOptions) options
{
    CGFloat height = [self expectedContentHeight];
    if (animatingFrame) {
        return;
    }
    
    CGRect rcTarget = CGRectMake(10.0f, minY - height, CGRectGetWidth(self.view.bounds) - 20.0f, height);
    if (!didAppear) {
        contentView.frame = rcTarget;
        return;
    }
    
    animatingFrame = YES;
    [UIView animateWithDuration:duration delay:0.0f options:options animations:^(void) {
        [contentView setFrame:rcTarget withImmediateLayout:YES];
    }completion:^(BOOL finished){
        if (!finished) {
            NSLog(@"DEBUG: cancelled!");
        }
        
        animatingFrame = NO;
        
        if ((int) [self expectedContentHeight] != (int) CGRectGetHeight(contentView.bounds) ||
            (int) CGRectGetMaxY(contentView.frame) != (int) minY) {
            [self sealedMessageEditorContentResized:contentView];
        }
    }];
}

/*
 *  This delegate method is sent when the content is resized.
 */
-(void) sealedMessageEditorContentResized:(UISealedMessageEditorContentViewV3 *)contentView
{
    [self resizeEditorWithDuration:[UISealedMessageEditorContentViewV3 recommendedSizeAnimationDuration] andOptions:0];
}

/*
 *  This notification is fired whenever the dynamic type size is modified.
 */
-(void) fontUpdatedNotification
{
    [contentView updateDynamicTypeNotificationReceived];
}

@end
