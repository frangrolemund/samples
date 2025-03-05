//
//  tdriverMessageDisplayViewController.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 7/9/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "tdriverMessageDisplayViewController.h"
#import "ChatSeal.h"
#import "UISealedMessageDisplayCellV2.h"

// - constants
static NSString *DRIVER_MSG_LOREM = @"Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";

// - forward declarations
@interface tdriverMessageDisplayViewController (internal) <UISealedMessageDisplayViewDataSourceV2>
-(int) countToAdd;
-(void) updateCount;
-(void) fontUpdatedNotification;
-(void) toggleHighlight;
-(void) addMessageContentWithCount:(NSUInteger) toAdd;
@end

/*************************************
 tdriverMessageDisplayViewController
 *************************************/
@implementation tdriverMessageDisplayViewController
/*
 *  Object attributes.
 */
{
    NSMutableArray *maNames;
    NSMutableArray *maDates;
    NSMutableArray *maMessages;
    int            imageCount;
    time_t         currentDateTime;
    int            currentName;
    BOOL           highlighted;
    UIImage        *imgOne;
    UIImage        *imgTwo;
    UIImage        *imgThree;
    UIImage        *imgPlaceholder;
    BOOL           hasAppeared;
}
@synthesize messageDisplay;
@synthesize toAddSlider;
@synthesize toAddCount;

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        maMessages = [[NSMutableArray alloc] init];
        maNames    = [[NSMutableArray alloc] init];
        maDates    = [[NSMutableArray alloc] init];
        imageCount = 0;
        hasAppeared = NO;
        currentDateTime = time(NULL) - (60 * 60 * 24 * 8);          //  start over a week ago.
        currentName = 0;
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
    [messageDisplay release];
    messageDisplay = nil;
    
    [toAddSlider release];
    toAddSlider = nil;
    
    [toAddCount release];
    toAddCount = nil;
    
    [maMessages release];
    maMessages = nil;
    
    [maNames release];
    maNames = nil;
    
    [maDates release];
    maDates = nil;
    
    [imgOne release];
    imgOne = nil;
    
    [imgTwo release];
    imgTwo = nil;
    
    [imgThree release];
    imgThree = nil;
    
    [imgPlaceholder release];
    imgPlaceholder = nil;
    
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
    
    messageDisplay.layer.borderWidth = 1.0f;
    messageDisplay.layer.borderColor = [[UIColor darkGrayColor] CGColor];
    messageDisplay.clipsToBounds     = YES;
    
    srand(32);              //  for predictability.
    [self updateCount];
    
    // - this view controller is the data source for the message display
    messageDisplay.dataSource = self;
    [messageDisplay setMaximumNumberOfItemsPerEntry:6];
    
    ChatSealColorCombo *cc = [ChatSeal sealColorsForColor:RSSC_STD_GREEN];
    [messageDisplay setOwnerBaseColor:cc.cMid andHighlight:cc.cTextHighlight];
    
    imgOne   = [[UIImage imageNamed:@"sample-face.jpg"] retain];
    imgTwo   = [[UIImage imageNamed:@"seal_sample9.jpg"] retain];
    imgThree = [[UIImage imageNamed:@"seal_sample24.jpg"] retain];
    
    UIGraphicsBeginImageContext(CGSizeMake(256.0f, 256.0f));
    [[UIColor lightGrayColor] setFill];
    UIRectFill(CGRectMake(0.0f, 0.0f, 256.0f, 256.0f));
    imgPlaceholder = [UIGraphicsGetImageFromCurrentImageContext() retain];
    UIGraphicsEndImageContext();
    
    // - large list testing
#if 1
    for (int i = 0; i < 1000; i++) {
        [self addMessageContentWithCount:3];
    }
#endif
    
    NSLog(@"DEBUG: view loaded.");
}

/*
 *  Add a new message with the current attributes.
 */
-(IBAction)doAddMessage:(id)sender
{
    NSUInteger toAdd = [self countToAdd];
    [self addMessageContentWithCount:toAdd];
    [messageDisplay appendMessage];
    [messageDisplay scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:toAdd - 1 inEntry:[maMessages count]-1] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

/*
 *  Update the count when the slider changes.
 */
-(IBAction)doChangeCount:(id)sender
{
    [self updateCount];
}

/*
 *  Test how quickly we can size a block of text.
 */
-(IBAction)doTestTextSizing:(id)sender
{
    NSString *sText = DRIVER_MSG_LOREM;
    static const NSUInteger NUM_ITER = 10000;
    
    NSLog(@"DEBUG: begining text sizing test.");
    NSTimeInterval tiBegin = [NSDate timeIntervalSinceReferenceDate];
    
    for (NSUInteger i = 0; i < NUM_ITER; i++) {
        //  NOTE: the lesson I learned here on 10/13/14 was that sizing is very dependent on the target width.  If you increase the
        //        size of the cell, there is less wrapping and the result is a much faster sizing process.  The more line breaks the
        //        slower it goes.
        [UISealedMessageDisplayCellV2 minimumCellHeightForText:sText inCellWidth:320.0f];
    }
    
    NSTimeInterval tiEnd   = [NSDate timeIntervalSinceReferenceDate];
    NSString *result       = [NSString stringWithFormat:@"DEBUG: text sizing for %u iterations took %4.2f seconds", (unsigned) NUM_ITER, tiEnd - tiBegin];
    NSLog(@"%@", result);
}

/*
 *  The view appeared.
 */
-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    NSLog(@"DEBUG: view did appear.");
    hasAppeared = YES;
}

@end


/***********************************************
 tdriverMessageDisplayViewController (internal)
 ************************************************/
@implementation tdriverMessageDisplayViewController (internal)

/*
 *  Return the count associated with the slider.
 */
-(int) countToAdd
{
    CGFloat value = toAddSlider.value;
    return (int) value;
}

/*
 *  Update the count associated with the slider.
 */
-(void) updateCount
{
    int num = [self countToAdd];
    toAddCount.text = [NSString stringWithFormat:@"%d", num];
}

/*
 *  Return the number of messages to show in the display.
 */
-(NSInteger) numberOfEntriesInDisplay:(UISealedMessageDisplayViewV2 *)messageDisplay
{
    return [maMessages count];
}

/*
 *  Every message needs at least one item.
 */
-(NSInteger) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *)messageDisplay numberOfItemsInEntry:(NSInteger)entry
{
    if (entry < [maMessages count]) {
        NSArray *arr = (NSArray *) [maMessages objectAtIndex:entry];
        return [arr count];
    }
    return 0;
}

/*
 *  Determine if the message is from us.
 */
-(BOOL) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *)messageDisplay authorIsLocalForEntry:(NSInteger)entry
{
    return (entry % 2 == 0) ? YES : NO;
}

/*
 *  Return whether the requested item is an image.
 */
-(BOOL) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *) messageDisplay contentIsImageAtIndex:(NSIndexPath *) index
{
    if (index.entry < [maMessages count]) {
        NSArray *arr = [maMessages objectAtIndex:index.entry];
        if (index.item < [arr count]) {
            id item = [arr objectAtIndex:index.item];
            if ([item isKindOfClass:[UIImage class]]) {
                return YES;
            }
        }
    }
    return NO;
}

/*
 *  Return a placeholder image for the index item when fast scrolling.
 */
-(UIImage *) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *) messageDisplay fastScrollingPlaceholderAtIndex:(NSIndexPath *) index
{
    if (index.entry < [maMessages count]) {
        NSArray *arr = [maMessages objectAtIndex:index.entry];
        if (index.item < [arr count]) {
            id item = [arr objectAtIndex:index.item];
            if ([item isKindOfClass:[UIImage class]]) {
                CGSize size = [(UIImage *) item size];
                CGFloat ar = size.width/size.height;
                if (ar > 1.0f) {
                    size.width  = imgPlaceholder.size.width;
                    size.height = size.width/ar;
                }
                else {
                    size.height = imgPlaceholder.size.height;
                    size.width  = size.height * ar;
                }
                CGImageRef ir = CGImageCreateWithImageInRect(imgPlaceholder.CGImage, CGRectMake(0.0f, 0.0f, size.width * imgPlaceholder.scale, size.height * imgPlaceholder.scale));
                UIImage *ret  = [UIImage imageWithCGImage:ir scale:imgPlaceholder.scale orientation:UIImageOrientationUp];
                CGImageRelease(ir);
                return ret;
            }
        }
    }
    return nil;
}

/*
 *  Return the content at the given index.
 */
-(id) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *)messageDisplay contentForItemAtIndex:(NSIndexPath *)index
{
    if (index.entry < [maMessages count]) {
        NSArray *arr = [maMessages objectAtIndex:index.entry];
        if (index.item < [arr count]) {
            id item = [arr objectAtIndex:index.item];
            if (hasAppeared && [item isKindOfClass:[UIImage class]]) {
                // - add a brief delay to simulate the decryption process.
                struct timespec ts;
                ts.tv_sec  = 0;
                ts.tv_nsec = (1000 * 1000 * 50);             //  50 ms.
                nanosleep(&ts, NULL);
            }
            return item;
        }
    }
    return nil;
}

/*
 *  Populate the data for the header.
 */
-(void) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *)messageDisplay populateHeaderContent:(UISealedMessageDisplayHeaderDataV2 *)header forEntry:(NSInteger)entry
{
    if (entry < [maNames count]) {
        header.isRead       = (entry % 3 == 0) ? YES : NO;
        header.isOwner      = (entry % 2 == 0) ? YES : NO;
        header.creationDate = [maDates objectAtIndex:entry];
        header.author       = [maNames objectAtIndex:entry];
    }
    
}

/*
 *  Report when taps occur.
 */
-(void) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *)md itemTappedAtIndex:(NSIndexPath *)index
{
    NSLog(@"DEBUG: item tapped at %u, %u", (unsigned) index.entry, (unsigned) index.item);
    CGRect rc = [messageDisplay rectForItemAtIndexPath:index];
    NSLog(@"DEBUG: item rect is (%4.2f, %4.2f) @ %4.2f x %4.2f", rc.origin.x, rc.origin.y, rc.size.width, rc.size.height);
    UIView *vw = [[[UIView alloc] init] autorelease];
    vw.backgroundColor = [UIColor colorWithRed:0.0f green:0.0f blue:1.0f alpha:0.25f];
    vw.frame           = rc;
    [messageDisplay addSubview:vw];
    [UIView animateWithDuration:0.25f animations:^(void) {
        vw.alpha = 0.0f;
    } completion:^(BOOL finished) {
        [vw removeFromSuperview];
    }];
}

/*
 *  This is called whenever the font typeface notification is fired.
 */
-(void) fontUpdatedNotification
{
    hasAppeared = NO;
    [messageDisplay updateDynamicTypeNotificationReceived];
}

/*
 *  Toggle highlight on/off.
 */
-(void) toggleHighlight
{
    highlighted = !highlighted;
    UIBarButtonItem *bbiHL = [[UIBarButtonItem alloc] initWithTitle:highlighted ? @"Normal" : @"Highlight"
                                                              style:UIBarButtonItemStyleBordered target:self action:@selector(toggleHighlight)];
    self.navigationItem.rightBarButtonItem = bbiHL;
    [bbiHL release];
    
    if (highlighted) {
        NSString *sBasicSearch = @"dolor in reprehenderit consequat ipsum";
        
        NSString *sDate = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterShortStyle];
        int pos = rand() % [sDate length];
        sDate = [sDate substringFromIndex:pos];
        
        sBasicSearch = [sBasicSearch stringByAppendingFormat:@" ra %@", sDate];  // add the 'ra' to match something in the name.
    
        [messageDisplay setSearchText:sBasicSearch];
    }
    else {
        [messageDisplay setSearchText:nil];
    }
}

/*
 *  This method will add a random message to the list.
 */
-(void) addMessageContentWithCount:(NSUInteger) toAdd
{
    NSString *name = nil;
    switch (currentName % 4) {
        case 0:
            name = @"Fran The Mysterious";
            break;
            
        case 1:
            name = @"MaryB";
            break;
            
        case 2:
            name = @"Megan";
            break;
            
        case 3:
            name = @"Mia";
            break;
    }
    currentName++;
    [maNames addObject:name];
    
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:currentDateTime];
    currentDateTime += (60 * 60 * 24);
    currentDateTime += ((rand() % 60) * (rand() % 60));
    [maDates addObject:date];
    
    NSMutableArray *maToAdd = [NSMutableArray array];
    for (int i = 0; i < toAdd; i++) {
        if (i % 3 == 2) {
            switch (imageCount%3) {
                case 0:
                default:
                    [maToAdd addObject:imgOne];
                    break;
                    
                case 1:
                    [maToAdd addObject:imgTwo];
                    break;
                    
                case 2:
                    [maToAdd addObject:imgThree];
                    break;
            }
            imageCount++;
        }
        else {
            int len = (int) [DRIVER_MSG_LOREM length];
            len -= 5;
//            len = 60;
            NSString *s = [DRIVER_MSG_LOREM substringToIndex:(rand() % (len/2)) + (rand() % (len/2)) + 5];
            [maToAdd addObject:s];
        }
    }
    [maMessages addObject:maToAdd];
}

@end