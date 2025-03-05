//
//  tdriverMsgIndexViewController.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 11/5/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <mach/mach_time.h>
#import "tdriverMsgIndexViewController.h"
#import "UISearchItemCell.h"
#import "CS_messageIndex.h"

// - constants
static const NSUInteger     DRV_IDX_NUM_SAMPLES = 100;
static const NSTimeInterval DRV_SEARCH_DELAY    = 0.5f;

// - forward declarations
@interface tdriverMsgIndexViewController (internal) <UISearchItemCellDelegate, UIActionSheetDelegate>
+(uint64_t) absTime;
+(CGFloat) absTimeToSec:(uint64_t)abst;
+(NSURL *) urlForCacheDirectory;
-(void) clearCurrentData;
-(void) repopulateData;
-(UISearchItemCell *) currentSearchCell;
-(void) beginSearchFired;
@end

/*****************************
 tdriverMsgIndexViewController
 *****************************/
@implementation tdriverMsgIndexViewController
/*
 *  Object attributes.
 */
{
    NSMutableArray          *maSaltItems;
    NSMutableArray          *maOriginalItems;
    NSMutableArray          *maFilteredItems;
    NSTimer                 *tmBeginSearch;
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        tmBeginSearch   = nil;
        maSaltItems     = [[NSMutableArray alloc] init];
        maOriginalItems = [[NSMutableArray alloc] init];
        maFilteredItems = [[NSMutableArray alloc] init];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [maSaltItems release];
    maSaltItems = nil;
    
    [maOriginalItems release];
    maOriginalItems = nil;
    
    [maFilteredItems release];
    maFilteredItems = nil;
    
    [super dealloc];
}

/*
 *  Configure the object.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // - remove the existing cache because it will be regenerated.
    [self clearCurrentData];
}

/*
 *  Make sure the timer is removed when the view is about to go or 
 *  we'll never get released.
 */
-(void) viewWillDisappear:(BOOL)animated
{
    [tmBeginSearch invalidate];
    [tmBeginSearch release];
    tmBeginSearch = nil;
}

/*
 *  Return the number of sections in the table.
 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

/*
 *  Return the number of rows in the given section.
 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return 1;
    }
    else {
        return [maFilteredItems count];
    }
}

/*
 *  Return the cell for the row at the given location.
 */
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *searchCellIdentifier = @"UISearchItemCell";
    static NSString *contentCellIdentifier = @"ContentCell";
    UITableViewCell *cell = nil;
    if (indexPath.section == 0) {
        cell = [tableView dequeueReusableCellWithIdentifier:searchCellIdentifier forIndexPath:indexPath];
        [(UISearchItemCell *) cell setDelegate:self];
    }
    else {
        cell = [tableView dequeueReusableCellWithIdentifier:contentCellIdentifier];
        if (indexPath.row < [maFilteredItems count]) {
            NSString *s = [maFilteredItems objectAtIndex:indexPath.row];
            cell.textLabel.text = s;
        }
    }
    
    return cell;
}

/*
 *  The populate data tool item was clicked.
 */
-(IBAction)doPopulateData:(id)sender
{
    if ([maOriginalItems count]) {
        UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:@"The existing sample data will be destroyed." delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Re-create the Data" otherButtonTitles:nil];
        [as showInView:self.view];
    }
    else {
        [self repopulateData];
    }
}

@end

// - these are some test strings.
static const NSUInteger NUM_SRC_TEXT = 10;
static NSString *sample_string[NUM_SRC_TEXT] = {
    @"Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
    @"Here are my rules: what can be done with one substance must never be done with another. No two materials are alike. No two sites on earth are alike. No two buildings have the same purpose. The purpose, the site, the material determine the shape. Nothing can be reasonable or beautiful unless it's made by one central idea, and the idea sets every detail. A building is alive, like a man. Its integrity is to follow its own truth, its one single theme, and to serve its own single purpose. A man doesn't borrow pieces of his body. A building doesn't borrow hunks of its soul. Its maker gives it the soul and every wall, window and stairway to express it.",
    @"I would give the greatest sunset in the world for one sight of New York's skyline. Particularly when one can't see the details. Just the shapes. The shapes and the thought that made them. The sky over New York and the will of man made visible. What other religion do we need? And then people tell me about pilgrimages to some dank pesthole in a jungle where they go to do homage to a crumbling temple, to a leering stone monster with a pot belly, created by some leprous savage. Is it beauty and genius they want to see? Do they seek a sense of the sublime? Let them come to New York, stand on the shore of the Hudson, look and kneel. When I see the city from my window--no, I don't feel how small I am--but I feel that if a war came to threaten this, I would like to throw myself into space, over the city, and protect these buildings with my body.",
    @"He had always wanted to write music, and he could give no other identity to the thing he sought. If you want to know what it is, he told himself, listen to the first phrases of Tchaikovsky's First Concerto--or to the last movement of Rachmaninoff's Second. Men have not found the words for it nor the deed nor the thought, but they have found the music. Let me see that in one single act of man on earth. Let me see it made real. Let me see the answer to the promise of that music. Not servants nor those served; not altars and immolations; but the final, the fulfilled, innocent of pain. Don't help me or serve me, but let me see it once, because I need it.",
    @"Thousands of years ago, the first man discovered how to make fire. He was probably burned at the stake he had taught his brothers to light. He was considered an evildoer who had dealt with a demon mankind dreaded. But thereafter men had fire to keep them warm, to cook their food, to light their caves. He had left them a gift they had not conceived and he had lifted darkness off the earth. Centuries later, the first man invented the wheel. He was probably torn on the rack he had taught his brothers to build. He was considered a transgressor who ventured into forbidden territory. But thereafter, men could travel past any horizon. He had left them a gift they had not conceived and he had opened the roads of the world.",
    @"Man cannot survive except through the use of his mind. He comes on earth unarmed. His brain is his only weapon. Animals obtain food by force. Man has no claws, no fangs, no horns, no great strength of muscle. He must plant his food or hunt it. To plant, he needs a process of thought. To hunt, he needs weapons, and to make weapons--a process of thought. From this simplest necessity to the highest religious abstraction, from the wheel to the skyscraper, everything we are and everything we have comes from a single attribute of man--the function of his reasoning mind.",
    @"Every form has its own meaning. Every man creates his meaning and form and goal. Why is it so important--what others have done? Why does it become sacred by the mere fact of not being your own? Why is anyone and everyone right--so long as it's not yourself? Why does the number of those others take the place of truth? Why is truth made a mere matter of arithmetic--and only of addition at that? Why is everything twisted out of all sense to fit everything else? There must be some reason. I don't know. I've never known it. I'd like to understand.",
    @"You have been called selfish for the courage of acting on your own judgement and bearing sole responsibility for your own life. You have been called arrogant for your independent mind. You have been called cruel for your unyielding integrity. You have been calle anti social for the vision that made you venture upon undiscovered roads.",
    @"Do not let your fire go out, spark by irreplaceable spark in the hopeless swamps of the not-quite, the not-yet, and the not-at-all. Do not let the hero in your soul perish in lonely frustration for the life you deserved and have never been able to reach. The world you desire can be won. It exists.. it is real.. it is possible.. it's yours.",
    @"Contradictions do not exist. Whenever you think that you are facing a contradiction, check your premises. You will find that one of them is wrong."
};


/****************************************
 tdriverMsgIndexViewController (internal)
 ****************************************/
@implementation tdriverMsgIndexViewController (internal)

/*
 *  Get a system absolute time value.
 */
+(uint64_t) absTime
{
    return (uint64_t) mach_absolute_time();
}

/*
 *  Convert a system absolute time into seconds.
 */
+(CGFloat) absTimeToSec:(uint64_t)abst
{
    static BOOL hasFreq = NO;
    static double frequency = 0.0f;
    
    if (!hasFreq) {
        // - mach time is a ratio describing the nanoseconds for each tick
        mach_timebase_info_data_t tbi;
        mach_timebase_info(&tbi);
        frequency = ((double) tbi.denom / (double) tbi.numer) * 1000000000.0f;
    }
    return ((double) abst/frequency);
}

/*
 *  Return the cache location.
 */
+(NSURL *) urlForCacheDirectory
{
    NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    u = [u URLByAppendingPathComponent:@"index-samples"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:[u path]]) {
        if (![[NSFileManager defaultManager] createDirectoryAtPath:[u path] withIntermediateDirectories:YES attributes:nil error:nil]) {
            NSLog(@"ERROR: Failed to create the cache directory.");
            u = nil;
        }
    }
    return u;
}

/*
 *  Release the current content.
 */
-(void) clearCurrentData
{
    [maSaltItems removeAllObjects];
    [maOriginalItems removeAllObjects];
    [maFilteredItems removeAllObjects];
    
    NSURL *u = [tdriverMsgIndexViewController urlForCacheDirectory];
    [[NSFileManager defaultManager] removeItemAtURL:u error:nil];
    
    [[self currentSearchCell] setSearchText:nil];
}

/*
 *  When the repopulate sheet is clicked, this will receive the results.
 */
-(void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0) {
        [self repopulateData];
    }
}

/*
 *  Repopulate the background data.
 */
-(void) repopulateData
{
    [self clearCurrentData];
    
    // - first create the samples.
    for (NSUInteger i = 0; i < DRV_IDX_NUM_SAMPLES; i++) {
        int idx = i % NUM_SRC_TEXT;
        [maOriginalItems addObject:sample_string[idx]];
        [maSaltItems addObject:[NSString stringWithFormat:@"item%u",(unsigned) i]];
    }
    [maFilteredItems addObjectsFromArray:maOriginalItems];
    [self.tableView reloadData];
    
    // - now index them all to disk.
    NSLog(@"DEBUG: Beginning index generation.");
    NSURL *u = [tdriverMsgIndexViewController urlForCacheDirectory];
    uint64_t startTime = [tdriverMsgIndexViewController absTime];
    for (NSUInteger i = 0; i < DRV_IDX_NUM_SAMPLES; i++) {
        NSString *s = [maOriginalItems objectAtIndex:i];
        CS_messageIndex *mi = [[CS_messageIndex alloc] init];
        [mi appendContentToIndex:s];
        NSString *salt = [maSaltItems objectAtIndex:i];
        if (![mi generateIndexWithSalt:salt]) {
            NSLog(@"ERROR: failed to generate the index at %u.", (unsigned) i);
            [self clearCurrentData];
            return;
        }
        NSData *dGenerated = [mi indexData];
        NSString *sFile = [NSString stringWithFormat:@"msg%d.index", (int) i];
        NSURL *uFile = [u URLByAppendingPathComponent:sFile];
        if (![dGenerated writeToURL:uFile atomically:YES]) {
            NSLog(@"ERROR: Failed to write the cache file at %u.", (unsigned) i);
            [self clearCurrentData];
            return;
        }
        [mi release];
    }
    uint64_t endTime = [tdriverMsgIndexViewController absTime];
    CGFloat totTime = [tdriverMsgIndexViewController absTimeToSec:endTime - startTime];
    CGFloat aveTime = [tdriverMsgIndexViewController absTimeToSec:(endTime - startTime)/DRV_IDX_NUM_SAMPLES];
    NSLog(@"DEBUG: Completed index generation (total = %4.4fs, ave = %4.4fs).", totTime, aveTime);
}

/*
 *  The search bar's value was modified.
 */
-(void) searchValueModified:(NSString *)searchValue
{
    if ([maOriginalItems count] == 0) {
        return;
    }
    
    if (!tmBeginSearch) {
        tmBeginSearch = [[NSTimer scheduledTimerWithTimeInterval:DRV_SEARCH_DELAY target:self selector:@selector(beginSearchFired) userInfo:nil repeats:NO] retain];
    }
    [tmBeginSearch setFireDate:[NSDate dateWithTimeIntervalSinceNow:DRV_SEARCH_DELAY]];
}

/*
 *  Retrieve the search bar
 */
-(UISearchItemCell *) currentSearchCell
{
    return (UISearchItemCell *) [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
}

/*
 *  Start the search process.
 */
-(void) beginSearchFired
{
    NSString *sToSearch = [[self currentSearchCell] searchText];
    [maFilteredItems removeAllObjects];
    if (!sToSearch || [sToSearch length] == 0) {
        [maFilteredItems addObjectsFromArray:maOriginalItems];
    }
    else {
        NSLog(@"DEBUG: Beginning filtering of content.");
        uint64_t startTime = [tdriverMsgIndexViewController absTime];
        NSURL *u = [tdriverMsgIndexViewController urlForCacheDirectory];
        for (NSUInteger i = 0; i < [maOriginalItems count]; i++) {
            NSString *salt = [maSaltItems objectAtIndex:i];
            NSString *content = [maOriginalItems objectAtIndex:i];
            
            @autoreleasepool {
                NSString *sFile = [NSString stringWithFormat:@"msg%d.index", (int) i];
                NSURL *uFile    = [u URLByAppendingPathComponent:sFile];
                NSData *dFile   = [NSData dataWithContentsOfFile:[uFile path] options:NSDataReadingMappedIfSafe error:nil];
                if (!dFile) {
                    NSLog(@"ERROR:  Failed to load the index at position %u.", (unsigned) i);
                    return;
                }
                
                CS_messageIndex *mi = [[CS_messageIndex alloc] initWithIndexData:dFile];
                if ([mi matchesString:sToSearch usingSalt:salt]) {
                    [maFilteredItems addObject:content];
                }
                [mi release];
            }
        }
        
        uint64_t endTime = [tdriverMsgIndexViewController absTime];
        CGFloat totTime = [tdriverMsgIndexViewController absTimeToSec:endTime - startTime];
        CGFloat aveTime = [tdriverMsgIndexViewController absTimeToSec:(endTime - startTime)/DRV_IDX_NUM_SAMPLES];
        NSLog(@"DEBUG: Completed content filtering (total = %4.4fs, ave = %4.4fs).", totTime, aveTime);
        NSLog(@"DEBUG: Filtered content has %u of %u items.", (unsigned) [maFilteredItems count], (unsigned) [maOriginalItems count]);
    }
    
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
    [tmBeginSearch invalidate];
    [tmBeginSearch release];
    tmBeginSearch = nil;
}
@end