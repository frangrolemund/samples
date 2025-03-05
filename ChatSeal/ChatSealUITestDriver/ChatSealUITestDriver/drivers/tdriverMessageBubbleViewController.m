//
//  tdriverMessageBubbleViewController.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 7/10/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import "tdriverMessageBubbleViewController.h"
#import "ChatSeal.h"


static NSString *DRIVER_MSG_LOREM = @"Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";

// - forward declarations
@interface tdriverMessageBubbleViewController (internal)
-(void) fontUpdatedNotification;
-(void) toggleHighlight;
@end

/***************************************
 tdriverMessageBubbleViewController
 ***************************************/
@implementation tdriverMessageBubbleViewController
/*
 *  Object attributes
 */
{
    BOOL highlighted;
}

@synthesize smbvLeft;
@synthesize smbvRight;
@synthesize smbvSmall;
@synthesize smbvImage;
@synthesize smbvSmall2;
@synthesize smbvSmall3;

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
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [smbvLeft release];
    smbvLeft = nil;
    
    [smbvRight release];
    smbvRight = nil;
    
    [smbvSmall release];
    smbvSmall = nil;
    
    [smbvImage release];
    smbvImage = nil;
    
    [smbvSmall2 release];
    smbvSmall2 = nil;
    
    [smbvSmall3 release];
    smbvSmall3 = nil;
    
    [super dealloc];
}

/*
 *  Configure the object.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    highlighted = YES;
    [self toggleHighlight];
    
    ChatSealColorCombo *cc = [ChatSeal sealColorsForColor:RSSC_STD_BLUE];
    
    smbvLeft.isMine   = NO;
    smbvLeft.isSpoken = YES;
    [smbvLeft setOwnerColor:cc.cMid andTheirColor:[UIColor lightGrayColor]];
    [smbvLeft setContent:DRIVER_MSG_LOREM];
    
    [smbvRight setIsMine:YES];
    [smbvRight setIsSpoken:YES];
    [smbvRight setOwnerColor:cc.cMid andTheirColor:[UIColor lightGrayColor]];
    [smbvRight setContent:DRIVER_MSG_LOREM];
    
    [smbvSmall setIsMine:YES];
    [smbvSmall setIsSpoken:YES];
    [smbvSmall setOwnerColor:cc.cMid andTheirColor:[UIColor lightGrayColor]];
    [smbvSmall setContent:@"fhg"];
    
    [smbvImage setIsMine:YES];
    [smbvImage setIsSpoken:YES];
    [smbvImage setOwnerColor:cc.cMid andTheirColor:[UIColor lightGrayColor]];
    [smbvImage setContent:[UIImage imageNamed:@"sample-face.jpg"]];
    
    [smbvSmall2 setIsMine:NO];
    [smbvSmall2 setIsSpoken:YES];
    [smbvSmall2 setOwnerColor:cc.cMid andTheirColor:[UIColor lightGrayColor]];
    [smbvSmall2 setContent:@"This is a test."];
    
    [smbvSmall3 setIsMine:NO];
    [smbvSmall3 setIsSpoken:NO];
    [smbvSmall3 setOwnerColor:cc.cMid andTheirColor:[UIColor lightGrayColor]];
    [smbvSmall3 setContent:@"This is a test."];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fontUpdatedNotification) name:UIContentSizeCategoryDidChangeNotification object:nil];
}

@end


/***************************************
 tdriverMessageBubbleViewController (internal)
 ***************************************/
@implementation tdriverMessageBubbleViewController (internal)
-(void) fontUpdatedNotification
{
//    [smbvLeft updateDynamicTypeNotificationReceived];
//    [smbvRight updateDynamicTypeNotificationReceived];
}

/*
 *  Turn highlighting on/off.
 */
-(void) toggleHighlight
{
    highlighted = !highlighted;
    UIBarButtonItem *bbiHL = [[UIBarButtonItem alloc] initWithTitle:highlighted ? @"Normal" : @"Highlight"
                                                              style:UIBarButtonItemStyleBordered target:self action:@selector(toggleHighlight)];
    self.navigationItem.rightBarButtonItem = bbiHL;
    [bbiHL release];
    
    if (highlighted) {
        [smbvLeft setSearchText:@"dolor in reprehenderit consequat"];
        [smbvRight setSearchText:@"incididunt voluptate exercitation culpa"];
    }
    else {
        [smbvLeft setSearchText:nil];
        [smbvRight setSearchText:nil];
    }
}
@end