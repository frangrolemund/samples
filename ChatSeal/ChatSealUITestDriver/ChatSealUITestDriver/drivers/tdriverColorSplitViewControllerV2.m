//
//  tdriverColorSplitViewControllerV2.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 9/17/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "tdriverColorSplitViewControllerV2.h"

//  - constants
static NSString *DRV_CSV_VERSION                 = @"colorver";
static const CGFloat DRV_CFAX_VALUE_DIFF_RANGE   = 0.05f;               //  value decreases over the course of the entire resolution.
static const CGFloat DRV_CFAX_SAT_DIFF_RANGE     = 0.3f;                //  saturation decreases over the resolution also.
static const int DRV_CFAX_TAG_TOOLS = 500;
static const int DRV_CFAX_TAG_DELETE = 501;


// ***********************************
// GENERATED DATA
// - I've decided to use the name 'ColorFax' for this work because it is a facsimile of a
//   color.
// - this app is used to iterate on these data items to
//   improve the quality of the color splitting framework.
// - I haven't found a way yet to convert the colorfax value
//   table over to a simple equation so I'm using this app to generate its values by sight.
// - the colorfax resolution is a distance between the original color and its
//   facsimile.  The lower the number, the closer to the original.
// - the hue reference resolution is the number of points of reference data in a 360 degree hue spectrum.
// - the colorfax value table is a lookup table of deltas from the baseline for each sub-color's value. Their
//   magnitude is derived from the saturation and is recorded using the provided reference saturation.
// - consult journal from early Sept 2013 for details.
typedef enum
{
    PSCF_COLORFAX_NEAREST  = 0,
    
    PSCF_COLORFAX_MODERATE = 5,
    
    PSCF_COLORFAX_OBSCURE  = 9,
    
    PSCF_COLORFAX_RESOLUTION
} pscf_colorfax_resolution_t;
static const int     PSCF_HUE_REFERENCE_RESOLUTION = 20;
static const CGFloat PSCF_COLORFAX_REF_SATURATION  = 1.0f;
static const CGFloat PSCF_COLORFAX_REF_VALUE       = 1.0f;
// ***********************************

static const CGFloat DRV_CSV_MIN_SNAP_RESOLUTION = (1.0 / PSCF_HUE_REFERENCE_RESOLUTION);
static const CGFloat DRV_COLORFAX_MAX_DELTA       = (60.0/360.0);
static const CGFloat DRV_COLORFAX_MIN_DELTA       = (20.0/360.0);
static const CGFloat DRV_COLORFAX_TICK            = ((DRV_COLORFAX_MAX_DELTA - DRV_COLORFAX_MIN_DELTA) / (CGFloat) PSCF_COLORFAX_RESOLUTION);

// - this stores a single representation of one of the color triplets (primary, sub-A, sub-B)
@interface SplitColorDataPointV2 : NSObject <NSCoding>
{
    pscf_colorfax_resolution_t  cfax;
    CGFloat                     hue;
    CGFloat                     sat;
    CGFloat                     value;
    
    CGFloat                     hueSubA;
    CGFloat                     valSubA;
    
    CGFloat                     hueSubB;
    CGFloat                     valSubB;
}
+(NSUInteger) snapIdForFax:(pscf_colorfax_resolution_t) cfax andHue:(CGFloat) hue andSat:(CGFloat) sat andVal:(CGFloat) val;
-(void) setMainHue:(CGFloat) h andSaturation:(CGFloat) s andBrightness:(CGFloat) b withColorFax:(pscf_colorfax_resolution_t) cf;
-(void) setSubAHue:(CGFloat) h andBrightness:(CGFloat) b;
-(void) setSubBHue:(CGFloat) h andBrightness:(CGFloat) b;
-(NSUInteger) snapId;
@property (nonatomic, readonly) pscf_colorfax_resolution_t cfax;
@property (nonatomic, readonly) CGFloat hue;
@property (nonatomic, readonly) CGFloat sat;
@property (nonatomic, readonly) CGFloat value;
@property (nonatomic, readonly) CGFloat hueSubA;
@property (nonatomic, readonly) CGFloat valSubA;
@property (nonatomic, readonly) CGFloat hueSubB;
@property (nonatomic, readonly) CGFloat valSubB;
@end


// - forward declarations
@interface tdriverColorSplitViewControllerV2 (internal) <GLKViewDelegate, UIActionSheetDelegate>
+(CGFloat) colorDeltaForResolution:(pscf_colorfax_resolution_t) res;
-(void) configureColorStore;
-(void) updateColorSplits;
-(void) displayLinkTriggered:(CADisplayLink *) link;
-(NSURL *) archiveFilePath;
-(void) persistTimeout;
-(void) setSourceColor:(UIColor *) c;
-(void) syncUpColors;
-(NSUInteger) snapIdForCurrentColor;
-(void) updateControlsFromValuesAndSkipSource:(BOOL) skipSource;
-(void) updateNumberField:(int) field withValue:(CGFloat) value;
-(BOOL) isColorFaxEnabled;
-(BOOL) isColorFaxReferenceSaturation:(CGFloat) sat;
-(void) saveCurrentData;
-(void) doDeleteCurrent;
-(void) doSnapCurrent;
-(void) doDump;
-(void) tappedOnView;
@end


/********************************
 tdriverColorSplitViewControllerV2
 ********************************/
@implementation tdriverColorSplitViewControllerV2
/*
 *  Object attributes
 */
{
    BOOL                        isLoaded;
    EAGLContext                 *context;
    CADisplayLink               *displayLink;
    UIColor                     *srcColor;
    GLKVector4                  v4ColorA;
    CGFloat                     hueA;
    CGFloat                     valueA;
    GLKVector4                  v4ColorB;
    CGFloat                     hueB;
    CGFloat                     valueB;
    BOOL                        drawColorA;
    NSMutableDictionary         *mdSnapData;
    BOOL                        snapModified;
    NSTimer                     *saveTimer;
    UITapGestureRecognizer      *tgr;
    pscf_colorfax_resolution_t  cfResolution;
    BOOL                        incrementalSliderEnabled;
}

@synthesize vwBefore;
@synthesize vwPart1;
@synthesize vwPart2;
@synthesize glvAfter;
@synthesize vwTarget;
@synthesize slColorFax;
@synthesize lCFEnabled;

/*
 *  Intitialize the object
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        isLoaded     = NO;
        srcColor     = nil;
        hueA         = 0.5f;
        hueB         = 0.5f;
        valueA       = 1.0f;
        valueB       = 1.0f;
        drawColorA   = YES;
        snapModified = NO;
        incrementalSliderEnabled = NO;
        cfResolution = PSCF_COLORFAX_OBSCURE;
        context      = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        mdSnapData   = nil;
        [self configureColorStore];
        saveTimer    = [[NSTimer scheduledTimerWithTimeInterval:5.0f target:self selector:@selector(persistTimeout) userInfo:nil repeats:YES] retain];        
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [vwPart1 release];
    vwPart1 = nil;
    
    [vwPart2 release];
    vwPart2 = nil;
    
    [vwBefore release];
    vwBefore = nil;
    
    [glvAfter release];
    glvAfter = nil;
    
    [mdSnapData release];
    mdSnapData = nil;
    
    [saveTimer release];
    saveTimer = nil;
    
    [displayLink release];
    displayLink = nil;
    
    [tgr release];
    tgr = nil;
        
    [slColorFax release];
    slColorFax = nil;
    
    [lCFEnabled release];
    lCFEnabled = nil;
    
    [vwTarget release];
    vwTarget = nil;
    
    [super dealloc];
}

/*
 *  Configure the object.
 */
-(void) viewDidLoad
{
    [super viewDidLoad];
    
    isLoaded = YES;
    
    vwBefore.layer.borderColor = [[UIColor blackColor] CGColor];
    vwBefore.layer.borderWidth = 1.0f;
    
    vwTarget.layer.borderColor = [[UIColor blackColor] CGColor];
    vwTarget.layer.borderWidth = 1.0f;
    
    glvAfter.layer.borderColor = [[UIColor blackColor] CGColor];
    glvAfter.layer.borderWidth = 1.0f;
    
    srcColor = nil;
    v4ColorA = GLKVector4Make(0, 0, 0, 1);
    v4ColorB = GLKVector4Make(0, 0, 0, 1);
    
    // - we'll be controlling the drawing process
    glvAfter.enableSetNeedsDisplay = NO;
    glvAfter.context               = context;
    glvAfter.delegate              = self;
    
    tgr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedOnView)];
    tgr.numberOfTapsRequired = 1;
    [self.view addGestureRecognizer:tgr];
    
    displayLink = [[CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkTriggered:)] retain];
    [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    
    // - set up the colorfax range.
    slColorFax.minimumValue = 0.0f;
    slColorFax.maximumValue = PSCF_COLORFAX_OBSCURE;
    lCFEnabled.layer.borderColor = [[UIColor blackColor] CGColor];
    lCFEnabled.layer.borderWidth = 1.0f;
    lCFEnabled.layer.cornerRadius = 5.0f;
    
    // - Set up the initial color
    [self setSourceColor:[UIColor colorWithHue:0.0f saturation:1.0f brightness:0.75f alpha:1.0f]];
    
    // - and the adjustments
    [self updateControlsFromValuesAndSkipSource:NO]; 
    [self updateColorSplits];
}

/*
 *  Modify one of the many color adjustment sliders.
 */
-(void) doChangeSlider:(id)sender
{
    UISlider *slider = (UISlider *) sender;
    int index = (int) (slider.tag - 101);
    CGFloat curValue = slider.value;
    
    CGFloat comps[4];
    [srcColor getHue:&(comps[0]) saturation:&(comps[1]) brightness:&(comps[2]) alpha:&(comps[3])];
        
    if (sender == slColorFax) {
        cfResolution = (curValue / 1.0f);
        slider.value = cfResolution;            //  snap to the integer value.
        [self updateControlsFromValuesAndSkipSource:YES];
    }
    else if (index < 3) {
        int notch = (curValue / DRV_CSV_MIN_SNAP_RESOLUTION);
        curValue = ((CGFloat) notch * DRV_CSV_MIN_SNAP_RESOLUTION);
        slider.value = curValue;
        
        comps[index] = curValue;
        [srcColor release];
        srcColor = [[UIColor colorWithHue:comps[0] saturation:comps[1] brightness:comps[2] alpha:comps[3]] retain];
        
        if (index == 0 || index == 2) {
            [self updateControlsFromValuesAndSkipSource:YES];
        }
        else {
            [self syncUpColors];
        }
    }
    else {
        // - the sub-color sliders.
        if (index == 3 || index == 5) {
            curValue = trunc(curValue * 360.0f)/360.0f;
            slider.value = curValue;

            if (index == 3) {
                hueA = curValue;
            }
            else {
                hueB = curValue;
            }
        }
        else if (index == 4 || index == 6) {
            curValue = trunc(curValue * 100.0f)/100.0f;
            slider.value = curValue;
            
            if (index == 4) {
                valueA = curValue;
            }
            else {
                valueB = curValue;
            }
        }
        
        // - always save the data after a sub-color modification
        [self saveCurrentData];        
    }
    
    [self updateNumberField:index withValue:curValue];
    [self updateColorSplits];
}

/*
 *  When the view is about to disapper, halt all timing ooperations.
 */
-(void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [saveTimer invalidate];
    [displayLink invalidate];
    [self persistTimeout];
}

/*
 *  Display the tools for the user.
 *  - delete current
 *  - dump
 *  - snap
 */
-(IBAction)doShowTools:(id)sender
{
    UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:@"ColorFax Tools" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Dump Data", @"Snap Data", incrementalSliderEnabled ? @"Disable Incremental" : @"Enable Incremental", @"Delete Current", nil];
    as.tag = DRV_CFAX_TAG_TOOLS;
    [as showInView:self.view];
    [as release];
}
@end


/********************************************
 tdriverColorSplitViewControllerV2 (internal)
 ********************************************/
@implementation tdriverColorSplitViewControllerV2 (internal)

+(CGFloat) colorDeltaForResolution:(pscf_colorfax_resolution_t) res
{
    return trunc((DRV_COLORFAX_MIN_DELTA + (DRV_COLORFAX_TICK * (CGFloat) (res + 1))) * 100.0f)/100.0f;
}

/*
 *  Using the lookup tables, split a source color into its sub-colors
 */
+(void) splitSourceColor:(UIColor *) c intoHueA:(CGFloat *) hA andValueA:(CGFloat *) vA andHueB:(CGFloat *) hB andValueB:(CGFloat *) vB
         usingResolution:(pscf_colorfax_resolution_t) res
{
    // - decompose the source color into HSV
    CGFloat h, s, b, a;
    [c getHue:&h saturation:&s brightness:&b alpha:&a];
    
    CGFloat pctOfAdj = 0.0f;
    
    // - check if data exists in the lookup table, and if not, take a stab
    if (0) {
        
    }
    else {
        // - a crude approximation when data isn't populated.
        CGFloat tmp = b + 0.06f;
        if (tmp > 1.0f) {
            tmp = 1.0f;
        }
        *vA = tmp;
        tmp = b - 0.06f;
        if (tmp < 0.0f) {
            tmp = 0.0f;
        }
        *vB = tmp;
        
        // - take a stab at hues that are equidistant apart from the source.
        CGFloat delta = [tdriverColorSplitViewControllerV2 colorDeltaForResolution:res];
        delta *= (1.0f - pctOfAdj);
        *hA  = h - delta;
        if (*hA < 0.0f) {
            *hA += 1.0f;
        }
        *hB = h + delta;
        if (*hB > 1.0f) {
            *hB = *hB - 1.0f;
        }
    }        
}

/*
 *  Load up the persistent color store.
 */
-(void) configureColorStore
{
    @try {
        NSURL *u = [self archiveFilePath];
        mdSnapData = [[NSKeyedUnarchiver unarchiveObjectWithFile:[u path]] retain];
    }
    @catch (NSException *exception) {
        NSLog(@"ERROR: Failed to load the color store.  %@", [exception description]);
    }
    
    if (mdSnapData) {
    }
    else {
        mdSnapData  = [[NSMutableDictionary alloc] init];
    }
}

/*
 *  Modify the split of colors.
 */
-(void) updateColorSplits
{
    // - show the colors in the display (the GL display will be updated on each frame automatically)
    vwBefore.backgroundColor = srcColor;
    
    CGFloat h, s, b, a;
    [srcColor getHue:&h saturation:&s brightness:&b alpha:&a];
    
    // - the target color is a value-difference away from the current color based on the
    //   colorfax resolution.
    CGFloat diff = (CGFloat) cfResolution / (CGFloat) PSCF_COLORFAX_RESOLUTION;
    CGFloat targetBrightness = b - (diff * DRV_CFAX_VALUE_DIFF_RANGE);
    if (targetBrightness < 0.0f) {
        targetBrightness = 0.0f;
    }
    CGFloat targetSaturation = s - (diff * DRV_CFAX_SAT_DIFF_RANGE);
    if (targetSaturation < 0.0f) {
        targetSaturation = 0.0f;
    }
    vwTarget.backgroundColor = [UIColor colorWithHue:h saturation:targetSaturation brightness:targetBrightness alpha:1.0f];

    // - the secondary colors have the same saturation
    UIColor *c = [UIColor colorWithHue:hueA saturation:s brightness:valueA alpha:a];
    vwPart1.backgroundColor = c;
    CGFloat red, green, blue;
    [c getRed:&red green:&green blue:&blue alpha:&a];
    v4ColorA = GLKVector4Make(red, green, blue, a);
    
    c = [UIColor colorWithHue:hueB saturation:s brightness:valueB alpha:a];
    vwPart2.backgroundColor = c;
    [c getRed:&red green:&green blue:&blue alpha:&a];
    v4ColorB = GLKVector4Make(red, green, blue, a);
}

/*
 *  When the display link is fired, this method is called.
 */
-(void) displayLinkTriggered:(CADisplayLink *) link
{
    [glvAfter display];
}

/*
 *  Manage the drawing sequence.
 */
-(void) glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    if (drawColorA) {
        glClearColor(v4ColorA.r, v4ColorA.g, v4ColorA.b, v4ColorA.a);
    }
    else {
        glClearColor(v4ColorB.r, v4ColorB.g, v4ColorB.b, v4ColorB.a);
    }
    glClear(GL_COLOR_BUFFER_BIT);
    drawColorA = !drawColorA;
}

/*
 *  Return the location where we store the color archive.
 */
-(NSURL *) archiveFilePath
{
    NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    return [u URLByAppendingPathComponent:@"colorsplits.karV2"];
}

/*
 *  When this timeout is fired, we should try to write the current content
 *  to disk.
 */
-(void) persistTimeout
{
    if (snapModified) {
        NSURL *u = [self archiveFilePath];
        NSData *d = [NSKeyedArchiver archivedDataWithRootObject:mdSnapData];
        if (!d) {
            NSLog(@"ERROR: Failed to convert the snap data to an archive.!");
            return;
        }
        
        if (![d writeToURL:u atomically:YES]) {
            NSLog(@"ERROR:  Failed to archive the color data to the device.");
        }
        
        snapModified = NO;
    }    
}

/*
 *  This routine assigns the source color.
 */
-(void) setSourceColor:(UIColor *) c
{
    if (c == srcColor) {
        return;
    }
    
    [srcColor release];
    srcColor = [c retain];
    if (!c) {
        return;
    }
    
    [self syncUpColors];
    [self updateColorSplits];
}

/*
 *  Synch up the colors for the algorithm testing.
 */
-(void) syncUpColors
{
    // - we assume that the current slider positions
    //   are accurate
    NSUInteger snapId = [self snapIdForCurrentColor];
    SplitColorDataPointV2 *dp = [mdSnapData objectForKey:[NSNumber numberWithUnsignedInteger:snapId]];
    if (dp) {
        hueA         = dp.hueSubA;
        valueA       = dp.valSubA;
        hueB         = dp.hueSubB;
        valueB       = dp.valSubB;
        cfResolution = dp.cfax;
        return;
    }

    //  - if there wasn't saved data, then manufacture something.
    [tdriverColorSplitViewControllerV2 splitSourceColor:srcColor intoHueA:&hueA andValueA:&valueA andHueB:&hueB andValueB:&valueB usingResolution:cfResolution];
}

/*
 *  Return the snap id for the current color combination.
 */
-(NSUInteger) snapIdForCurrentColor
{
    UISlider *s = nil;
    CGFloat hue, sat, val;
    s = (UISlider *) [self.view viewWithTag:101];
    hue = s.value;
    s = (UISlider *) [self.view viewWithTag:102];
    sat = s.value;
    s = (UISlider *) [self.view viewWithTag:103];
    val = s.value;
    return [SplitColorDataPointV2 snapIdForFax:cfResolution andHue:hue andSat:sat andVal:val];
}

/*
 *  Update the controls from the sub-item RGB values.
 */
-(void) updateControlsFromValuesAndSkipSource:(BOOL) skipSource
{
    CGFloat comps[4];
    [srcColor getHue:&(comps[0]) saturation:&(comps[1]) brightness:&(comps[2]) alpha:&(comps[3])];
    
    for (int i = 0; i < 7; i++) {
        CGFloat curValue = 0.0f;
        if (i < 3) {
            curValue = comps[i];
        }
        else {
            switch (i)
            {
                case 3:
                    // - always synch colors before the first field is processed.
                    [self syncUpColors];
                    curValue = trunc(hueA * 100.0f)/100.0f;
                    break;
                    
                case 4:
                    curValue = valueA;
                    curValue = trunc(valueA * 100.0f)/100.0f;
                    break;
                    
                case 5:
                    curValue = trunc(hueB * 100.0f)/100.0f;
                    break;
                    
                case 6:
                    curValue = valueB;
                    curValue = trunc(valueB * 100.0f)/100.0f;
                    break;
            }
        }
        
        // - when the value must be updated, do so now.
        if (!skipSource || i > 2) {
            [self updateNumberField:i withValue:curValue];
            UISlider *slider = (UISlider *) [self.view viewWithTag:101 + i];
            
            slider.value = curValue;
        }        
    }
    
    // - set the colorfax slider last.
    slColorFax.value = cfResolution;
}

/*
 *  Change the value of the number field.
 */
-(void) updateNumberField:(int) field withValue:(CGFloat) value
{
    NSString *sVal = nil;
    if (field == 0 || field == 3 || field == 5) {
        value = value * 360.0f;     //  convert to degrees.
        sVal = [NSString stringWithFormat:@"%3.1f°", value];
    }
    else {
        CGFloat tval = trunc(value * 100.0f);
        tval /= 100.0f;
        sVal = [NSString stringWithFormat:@"%2.2f", tval];
    }
    
    UILabel *l = (UILabel *) [self.view viewWithTag:201 + field];
    if (l) {
        l.text = sVal;
    }
    
    // - turn the colorfax highlight on/off
    if (field == 1 || field == 2) {
        CGFloat newAlpha = 0.0f;
        if ([self isColorFaxEnabled]) {
            newAlpha = 1.0f;
        }
        [UIView animateWithDuration:0.5f animations:^(void){
            lCFEnabled.alpha = newAlpha;
        }];
    }
}

/*
 *  Determines if we're storing colorfax reference information.
 */
-(BOOL) isColorFaxEnabled
{
    if (!isLoaded) {
        return YES;
    }
    UISlider *sl = (UISlider *) [self.view viewWithTag:102];
    return [self isColorFaxReferenceSaturation:sl.value];
}

/*
 *  It turns out that the variation in value between the two sub-colors is greatest
 *  when the saturation is at its highest.  Because this offers the greatest precision
 *  we'll only capture ColorFax data during that time.
 */
-(BOOL) isColorFaxReferenceSaturation:(CGFloat) sat
{
    if (!isLoaded) {
        return YES;
    }

    // - force the 
    UISlider *sl = (UISlider *) [self.view viewWithTag:103];
    if (fabsf(PSCF_COLORFAX_REF_VALUE - sl.value) < DRV_CSV_MIN_SNAP_RESOLUTION &&
        fabsf(PSCF_COLORFAX_REF_SATURATION - sat) < DRV_CSV_MIN_SNAP_RESOLUTION) {
        return YES;
    }
    return NO;
}

/*
 *  Take a snapshot of the current data.
 */
-(void) saveCurrentData
{
    SplitColorDataPointV2 *dp =[[SplitColorDataPointV2 alloc] init];
    
    // - use the sliders and not the saved source color because
    //   a hue of 0.0f will be silently converted to 1.0f by the
    //   color and that will hose up our accounting here.
    UISlider *s = nil;
    CGFloat hue, sat, val;
    s = (UISlider *) [self.view viewWithTag:101];
    hue = s.value;
    s = (UISlider *) [self.view viewWithTag:102];
    sat = s.value;
    s = (UISlider *) [self.view viewWithTag:103];
    val = s.value;
    [dp setMainHue:hue andSaturation:sat andBrightness:val withColorFax:cfResolution];
    [dp setSubAHue:hueA andBrightness:valueA];
    [dp setSubBHue:hueB andBrightness:valueB];
    
    // - now store the content in our dictionary.
    NSUInteger sid = [dp snapId];
    BOOL hasPoint = NO;
    if ([mdSnapData objectForKey:[NSNumber numberWithUnsignedInteger:sid]]) {
        hasPoint = YES;
    }
    [mdSnapData setObject:dp forKey:[NSNumber numberWithUnsignedInteger:sid]];
    
    [dp release];
    
    // - set the flag so that we save on the next opportunity.
    snapModified = YES;
    
    // - update the version number
    NSInteger ver = [[NSUserDefaults standardUserDefaults] integerForKey:DRV_CSV_VERSION];
    ver++;
    [[NSUserDefaults standardUserDefaults] setInteger:ver forKey:DRV_CSV_VERSION];
}

/*
 *  Manage the actions performed in this view.
 */
-(void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (actionSheet.tag == DRV_CFAX_TAG_TOOLS) {
        switch (buttonIndex) {
            case 0:
                [self doDump];
                break;
                
            case 1:
                [self doSnapCurrent];
                break;
                
            case 2:
                incrementalSliderEnabled = !incrementalSliderEnabled;
                break;
                
            case 3:
                [self doDeleteCurrent];
                break;
        }
        
    }
    else if (actionSheet.tag == DRV_CFAX_TAG_DELETE) {
        if (buttonIndex != 0) {
            return;
        }
        NSLog(@"NOTICE:  Deleting the current color item.");
        
        NSUInteger snapId = [self snapIdForCurrentColor];
        [mdSnapData removeObjectForKey:[NSNumber numberWithUnsignedInteger:snapId]];
        snapModified = YES;
        [self syncUpColors];
        [self updateColorSplits];
        [self updateControlsFromValuesAndSkipSource:YES];
    }
}

/*
 *  Delete the current item.
 */
-(void) doDeleteCurrent
{
    UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:@"Are you sure you want to delete the current color item?" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Delete Item" otherButtonTitles:nil];
    as.tag = DRV_CFAX_TAG_DELETE;
    [as showInView:self.view];
    [as release];    
}

/*
 *  Snap a copy of the current data set.
 */
-(void) doSnapCurrent
{
    // - make sure the color file is up to date.
    [self persistTimeout];
    
    // - and make a copy
    NSURL *u = [self archiveFilePath];
    NSData *d = [NSData dataWithContentsOfURL:u];
    
    NSInteger ver = [[NSUserDefaults standardUserDefaults] integerForKey:DRV_CSV_VERSION];
    NSString *sVer = [NSString stringWithFormat:@".snap%04d", (int) ver];
    u = [u URLByAppendingPathExtension:sVer];
    if (![d writeToURL:u atomically:YES]) {
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"COLORSPLIT ERROR" message:@"Failed to take a snapshot." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [av show];
        [av release];
        return;
    }    
}

/*
 *  Dump the current data set for analysis.
 */
-(void) doDump
{
    typedef struct
    {
        CGPoint ptColorA;
        CGPoint ptColorB;
    } color_split_t;
    
    color_split_t cfaxItems[PSCF_HUE_REFERENCE_RESOLUTION];
    for (int i = 0; i < PSCF_HUE_REFERENCE_RESOLUTION; i++) {
        cfaxItems[i].ptColorA = CGPointZero;
        cfaxItems[i].ptColorB = CGPointZero;
    }
    
    for (SplitColorDataPointV2 *dp in mdSnapData.allValues) {
        if (dp.sat > (1.0f - DRV_CSV_MIN_SNAP_RESOLUTION) &&
            dp.value > (1.0f - DRV_CSV_MIN_SNAP_RESOLUTION)) {
         
            int pos = (dp.hue / DRV_CSV_MIN_SNAP_RESOLUTION);
            if (pos >= PSCF_HUE_REFERENCE_RESOLUTION) {
                continue;
            }
            cfaxItems[pos].ptColorA.x = dp.hueSubA;
            cfaxItems[pos].ptColorA.y = dp.valSubA;
            cfaxItems[pos].ptColorB.x = dp.hueSubB;
            cfaxItems[pos].ptColorB.y = dp.valSubB;
        }
    }
    
    NSString *sOut = @"";
    sOut = [sOut stringByAppendingFormat:@"typedef struct {\n"];
    sOut = [sOut stringByAppendingFormat:@"  CGPoint colorA;\n"];
    sOut = [sOut stringByAppendingFormat:@"  CGPoint colorB;\n"];
    sOut = [sOut stringByAppendingFormat:@"} ps_cfax_item_t;\n\n"];
    sOut = [sOut stringByAppendingFormat:@"static const int PSCF_HUE_REFERENCE_RESOLUTION = %d\n\n", PSCF_HUE_REFERENCE_RESOLUTION];
    
    sOut = [sOut stringByAppendingFormat:@"ps_cfax_item_t cfaxItems[PSCF_HUE_REFERENCE_RESOLUTION] = {"];
    for (int i = 0; i < PSCF_HUE_REFERENCE_RESOLUTION; i++) {
        if (i > 0) {
            sOut = [sOut stringByAppendingFormat:@",\n"];
        }
        sOut = [sOut stringByAppendingFormat:@"    {{%1.6f, %1.6f}, {%1.6f, %1.6f}}", cfaxItems[i].ptColorA.x, cfaxItems[i].ptColorA.y, cfaxItems[i].ptColorB.x, cfaxItems[i].ptColorB.y];
    }
    sOut = [sOut stringByAppendingFormat:@"\n};"];
    
    NSLog(@"DEBUG: Generated values:\n%@", sOut);
}
           
/*
 *  Process taps on the main view.
 */
-(void) tappedOnView
{
    if (!incrementalSliderEnabled) {
        return;
    }
    
    CGPoint ptLoc = [tgr locationInView:self.view];
    
    //  - figure out if we're subtracting or adding
    BOOL doSub = YES;
    int  foundId = -1;
    
    for (int i = 0; i < 7; i++) {
        UIView *vw = [self.view viewWithTag:301+i];
        if (CGRectContainsPoint(vw.frame, ptLoc)) {
            doSub = YES;
            foundId = i;
            break;
        }
        
        vw = [self.view viewWithTag:201+i];
        if (CGRectContainsPoint(vw.frame, ptLoc)) {
            doSub = NO;
            foundId = i;
            break;
        }
    }

    if (foundId == -1) {
        return;
    }

    UISlider *sl = (UISlider *) [self.view viewWithTag:101+foundId];
    CGFloat val = sl.value;
    
    CGFloat delta = .01f;
    if (foundId < 3) {
        delta = DRV_CSV_MIN_SNAP_RESOLUTION;
    }
    else if (foundId == 3 || foundId == 5) {
        delta = 1.0/360.0f;
    }
    delta += .001;
    
    if (doSub) {
        val = val - delta;
        if (val < 0.0f) {
            val = 0.0f;
        }
    }
    else {
        val = val + delta;
        if (val > 1.0f) {
            val = 1.0f;
        }
    }
    
    sl.value = val;
    [self doChangeSlider:sl];
}

@end

/**************************
 SplitColorDataPointV2
 **************************/
@implementation SplitColorDataPointV2
@synthesize cfax;
@synthesize hue;
@synthesize sat;
@synthesize value;
@synthesize hueSubA;
@synthesize valSubA;
@synthesize hueSubB;
@synthesize valSubB;

/*
 *  Generate a unique id for the given combination.
 */
+(NSUInteger) snapIdForFax:(pscf_colorfax_resolution_t) cfax andHue:(CGFloat) hue andSat:(CGFloat) sat andVal:(CGFloat) val
{
    unsigned int nH = (hue / DRV_CSV_MIN_SNAP_RESOLUTION);
    unsigned int nS = (sat / DRV_CSV_MIN_SNAP_RESOLUTION);
    unsigned int nV = (val / DRV_CSV_MIN_SNAP_RESOLUTION);
    return cfax | (nH << 8) | (nS << 16) | (nV << 24);
}

-(id) init
{
    self = [super init];
    if (self) {
        hue = sat = value = hueSubA = hueSubB = valSubA = valSubB = 0.0f;
    }
    return self;
}

/*
 *  Decode an existing item.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        cfax    = [aDecoder decodeInt32ForKey:@"cfax"];
        hue     = [aDecoder decodeFloatForKey:@"hue"];
        sat     = [aDecoder decodeFloatForKey:@"sat"];
        value   = [aDecoder decodeFloatForKey:@"val"];
        hueSubA = [aDecoder decodeFloatForKey:@"hueSubA"];
        valSubA = [aDecoder decodeFloatForKey:@"valSubA"];
        hueSubB = [aDecoder decodeFloatForKey:@"hueSubB"];
        valSubB = [aDecoder decodeFloatForKey:@"valSubB"];
    }
    return self;
}

/*
 *  Encode an item.
 */
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt32:cfax forKey:@"cfax"];
    [aCoder encodeFloat:hue     forKey:@"hue"];
    [aCoder encodeFloat:sat     forKey:@"sat"];
    [aCoder encodeFloat:value   forKey:@"val"];
    [aCoder encodeFloat:hueSubA forKey:@"hueSubA"];
    [aCoder encodeFloat:valSubA forKey:@"valSubA"];
    [aCoder encodeFloat:hueSubB forKey:@"hueSubB"];
    [aCoder encodeFloat:valSubB forKey:@"valSubB"];
}

// - don't assign from a color because 0 becomes 1.0f!
-(void) setMainHue:(CGFloat) h andSaturation:(CGFloat) s andBrightness:(CGFloat) b withColorFax:(pscf_colorfax_resolution_t) cf
{
    hue   = h;
    sat   = s;
    value = b;
    cfax  = cf;
}

-(UIColor *) color
{
    return [UIColor colorWithHue:hue saturation:sat brightness:value alpha:1.0f];
}

-(void) setSubAHue:(CGFloat) h andBrightness:(CGFloat) b
{
    hueSubA = h;
    valSubA = b;
}

-(void) setSubBHue:(CGFloat) h andBrightness:(CGFloat) b
{
    hueSubB = h;
    valSubB = b;
}

/*
 *  Return a unique id for the snapshot data.
 */
-(NSUInteger) snapId
{
    return [SplitColorDataPointV2 snapIdForFax:cfax andHue:hue andSat:sat andVal:value];
}

@end

