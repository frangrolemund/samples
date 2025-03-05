
#if 0
//
//  tdriverColorSplitViewController.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 9/8/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

//#import <QuartzCore/QuartzCore.h>
//#import "tdriverColorSplitViewController.h"
//
////  - constants
//static NSString *DRV_CSV_VERSION                 = @"colorver";
//static const CGFloat DRV_VALUE_PRECISION         = 10000;
//static const CGFloat DRV_CFAX_VALUE_DIFF_RANGE   = 0.05f;               //  value decreases over the course of the entire resolution.
//static const CGFloat DRV_CFAX_SAT_DIFF_RANGE     = 0.3f;                //  saturation decreases over the resolution also.
//
//
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
//typedef enum
//{
//    PSCF_COLORFAX_NEAREST  = 0,
//    
//    PSCF_COLORFAX_MODERATE = 5,
//    
//    PSCF_COLORFAX_OBSCURE  = 9,
//    
//    PSCF_COLORFAX_RESOLUTION
//} pscf_colorfax_resolution_t;
//static const CGFloat PSCF_COLORFAX_MAX_DELTA       = (60.0/360.0);
//static const CGFloat PSCF_COLORFAX_MIN_DELTA       = (20.0/360.0);
//static const CGFloat PSCF_COLORFAX_TICK            = ((PSCF_COLORFAX_MAX_DELTA - PSCF_COLORFAX_MIN_DELTA) / (CGFloat) PSCF_COLORFAX_RESOLUTION);
//static const int     PSCF_HUE_REFERENCE_RESOLUTION = 20;
static const CGFloat PSCF_HUE_TICK                 = (1.0 / (CGFloat) PSCF_HUE_REFERENCE_RESOLUTION);
static const BOOL    PSCF_HAS_COLORFAX_DATA        = YES;
//static const CGFloat PSCF_COLORFAX_REF_SATURATION  = 1.0f;
static CGFloat       PSCF_COLORFAX_MAGNITUDES[PSCF_COLORFAX_RESOLUTION] = {0.20000,0.21000,-1.00000,-1.00000,-1.00000,-1.00000,-1.00000,-1.00000,-1.00000,0.18000};
static CGFloat       PSCF_COLORFAX_VALUE[PSCF_COLORFAX_RESOLUTION][PSCF_HUE_REFERENCE_RESOLUTION] = {
    { 0.15000, 0.45000, 0.90000, 0.55000, 0.00000,-0.25000,-0.10000, 0.05000, 0.10000, 0.05000,
        -0.47450,-1.00000,-0.95000,-0.35000, 0.25000, 0.75000, 0.45000,-0.00000,-0.45000,-0.20000},
    { 0.19048, 0.66667, 0.85952, 0.42857, 0.04762,-0.23810,-0.09524, 0.04762, 0.14286,-0.09524,
        -0.47619,-0.95238,-1.00000,-0.42857, 0.38095, 0.70333, 0.49476, 0.14286,-0.38095,-0.23810},
    { 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000,
        0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000},
    { 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000,
        0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000},
    { 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000,
        0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000},
    { 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000,
        0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000},
    { 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000,
        0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000},
    { 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000,
        0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000},
    { 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000,
        0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000},
    { 0.61111, 0.61111, 0.63778, 0.61111, 0.38889, 0.33333, 0.05556,-0.11111,-0.55556,-0.88889,
        -1.00000,-1.00000,-0.83333,-0.61111,-0.14500, 0.27778, 0.38889, 0.33333, 0.33333, 0.55556}};
// ***********************************

//
//static const CGFloat DRV_CSV_MIN_SNAP_RESOLUTION = (1.0 / PSCF_HUE_REFERENCE_RESOLUTION);

//// - this stores a single representation of one of the color triplets (primary, sub-A, sub-B)
//@interface SplitColorDataPoint : NSObject <NSCoding>
//{
//    pscf_colorfax_resolution_t  cfax;
//    CGFloat                     hue;
//    CGFloat                     sat;
//    CGFloat                     value;
//    
//    CGFloat                     hueSubA;
//    CGFloat                     valSubA;
//    
//    CGFloat                     hueSubB;
//    CGFloat                     valSubB;
//}
//+(NSUInteger) snapIdForFax:(pscf_colorfax_resolution_t) cfax andHue:(CGFloat) hue andSat:(CGFloat) sat andVal:(CGFloat) val;
//-(void) setMainHue:(CGFloat) h andSaturation:(CGFloat) s andBrightness:(CGFloat) b withColorFax:(pscf_colorfax_resolution_t) cf;
//-(void) setSubAHue:(CGFloat) h andBrightness:(CGFloat) b;
//-(void) setSubBHue:(CGFloat) h andBrightness:(CGFloat) b;
//-(NSUInteger) snapId;
//@property (nonatomic, readonly) pscf_colorfax_resolution_t cfax;
//@property (nonatomic, readonly) CGFloat hue;
//@property (nonatomic, readonly) CGFloat sat;
//@property (nonatomic, readonly) CGFloat value;
//@property (nonatomic, readonly) CGFloat hueSubA;
//@property (nonatomic, readonly) CGFloat valSubA;
//@property (nonatomic, readonly) CGFloat hueSubB;
//@property (nonatomic, readonly) CGFloat valSubB;
//@end

//  - forward declarations
@interface tdriverColorSplitViewController (internal) <GLKViewDelegate, UIActionSheetDelegate>
//+(CGFloat) colorDeltaForResolution:(pscf_colorfax_resolution_t) res;
//-(void) syncUpColors;
//-(void) setSourceColor:(UIColor *) c;
//-(void) displayLinkTriggered:(CADisplayLink *) link;
//-(void) updateNumberField:(int) field withValue:(CGFloat) value;
//-(void) updateControlsFromValuesAndSkipSource:(BOOL) skipSource;
//-(void) updateColorSplits;
//-(void) saveCurrentData;
-(NSURL *) archiveFilePath;
//-(void) persistTimeout;
//-(void) configureColorStore;
-(NSUInteger) snapIdForCurrentColor;
-(void) tapAdvanceHue;
-(void) tapSaveCurrent;
//-(BOOL) isColorFaxEnabled;
//-(BOOL) isColorFaxReferenceSaturation:(CGFloat) sat;
-(void) recalibrateColorFaxWithResolution:(pscf_colorfax_resolution_t) res atIndex:(int) hueIndex withValue:(CGFloat) newValue;
-(void) updateColorFaxTableWithData:(SplitColorDataPoint *) dp;
-(void) dumpColorFaxConstants;
-(void) tapValDeltaUpdate:(UITapGestureRecognizer *) gesture;
@end

/***********************************
 tdriverColorSplitViewController
 ***********************************/
@implementation tdriverColorSplitViewController
/*
 *  Object attributes.
 */
{
//    BOOL                        isLoaded;
//    EAGLContext                 *context;
//    CADisplayLink               *displayLink;
//    UIColor                     *srcColor;
//    GLKVector4                  v4ColorA;
//    CGFloat                     hueA;
//    CGFloat                     valueA;
//    GLKVector4                  v4ColorB;
//    CGFloat                     hueB;
//    CGFloat                     valueB;
//    BOOL                        drawColorA;
//    NSMutableDictionary         *mdSnapData;
//    BOOL                        snapModified;
//    NSTimer                     *saveTimer;
//    UITapGestureRecognizer      *tgr;
//    UITapGestureRecognizer      *tgr2;
//    UITapGestureRecognizer      *tgrValDelta;
//    pscf_colorfax_resolution_t  cfResolution;
}
//@synthesize vwBefore;
//@synthesize glvAfter;
//@synthesize vwPart1;
//@synthesize vwPart2;
//@synthesize vwTarget;
//@synthesize btnDeleteCur;
//@synthesize btnDumpData;
//@synthesize btnSnapshot;
//@synthesize slColorFax;
//@synthesize lCFEnabled;

/*
 *  Initialize the colorfax values if necessary.
 */
+(void) initialize
{
    // - when there is no colorfax data precompiled into this app, then
    //   initialize the table so that we can start from a good baseline.
    if (!PSCF_HAS_COLORFAX_DATA) {
        for (int i = 0; i < PSCF_COLORFAX_RESOLUTION; i++) {
            PSCF_COLORFAX_MAGNITUDES[i] = -1.0f;                        //  magnitude is never negative so this indicates nothing exists.
            
            for (int j = 0; j < PSCF_HUE_REFERENCE_RESOLUTION; j++) {
                PSCF_COLORFAX_VALUE[i][j] = 0.0f;
            }
        }
    }
}

///*
// *  Initialize the object
// */
//-(id) initWithCoder:(NSCoder *)aDecoder
//{
//    self = [super initWithCoder:aDecoder];
//    if (self) {
////        isLoaded     = NO;
////        srcColor     = nil;
////        hueA         = 0.5f;
////        hueB         = 0.5f;
////        valueA       = 1.0f;
////        valueB       = 1.0f;
////        drawColorA   = YES;
////        snapModified = NO;
////        cfResolution = PSCF_COLORFAX_OBSCURE;
////        context      = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
////        mdSnapData   = nil;
////        [self configureColorStore];
////        saveTimer    = [[NSTimer scheduledTimerWithTimeInterval:5.0f target:self selector:@selector(persistTimeout) userInfo:nil repeats:YES] retain];
//    }
//    return self;
//}

///*
// *  Free the object
// */
//-(void) dealloc
//{
////    [vwPart1 release];
////    vwPart1 = nil;
////    
////    [vwPart2 release];
////    vwPart2 = nil;
////    
////    [vwBefore release];
////    vwBefore = nil;
////    
////    [glvAfter release];
////    glvAfter = nil;
////    
////    [mdSnapData release];
////    mdSnapData = nil;
////    
////    [saveTimer release];
////    saveTimer = nil;
////    
////    [displayLink release];
////    displayLink = nil;
////    
////    [btnDeleteCur release];
////    btnDeleteCur = nil;
////    
////    [btnDumpData release];
////    btnDumpData = nil;
////    
////    [btnSnapshot release];
////    btnSnapshot = nil;
////    
////    [tgr release];
////    tgr = nil;
////    
////    [tgr2 release];
////    tgr2 = nil;
////    
////    [tgrValDelta release];
////    tgrValDelta = nil;
////    
////    [slColorFax release];
////    slColorFax = nil;
////    
////    [lCFEnabled release];
////    lCFEnabled = nil;
////    
////    [vwTarget release];
////    vwTarget = nil;
////    
////    [super dealloc];
//}

/*
 *  Configure the object.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
//    isLoaded = YES;
//    
//    vwBefore.layer.borderColor = [[UIColor blackColor] CGColor];
//    vwBefore.layer.borderWidth = 1.0f;
//    
//    vwTarget.layer.borderColor = [[UIColor blackColor] CGColor];
//    vwTarget.layer.borderWidth = 1.0f;
    
    tgr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapAdvanceHue)];
    tgr.numberOfTapsRequired = 2;
    [vwBefore addGestureRecognizer:tgr];
    
    tgr2 = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapSaveCurrent)];
    tgr2.numberOfTapsRequired = 2;
    [glvAfter addGestureRecognizer:tgr2];
    
    tgrValDelta = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapValDeltaUpdate:)];
    tgrValDelta.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:tgrValDelta];
    
//    glvAfter.layer.borderColor = [[UIColor blackColor] CGColor];
//    glvAfter.layer.borderWidth = 1.0f;
//    
//    srcColor = nil;
//    v4ColorA = GLKVector4Make(0, 0, 0, 1);
//    v4ColorB = GLKVector4Make(0, 0, 0, 1);
//    
//    // - we'll be controlling the drawing process
//    glvAfter.enableSetNeedsDisplay = NO;
//    glvAfter.context               = context;
//    glvAfter.delegate              = self;
//    
//    displayLink = [[CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkTriggered:)] retain];
//    [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
//    
//    // - set up the colorfax range.
//    slColorFax.minimumValue = 0.0f;
//    slColorFax.maximumValue = PSCF_COLORFAX_OBSCURE;
//    lCFEnabled.layer.borderColor = [[UIColor blackColor] CGColor];
//    lCFEnabled.layer.borderWidth = 1.0f;
//    lCFEnabled.layer.cornerRadius = 5.0f;
    
//    // - Set up the initial color
//    [self setSourceColor:[UIColor colorWithHue:0.0f saturation:1.0f brightness:0.75f alpha:1.0f]];
    
//    // - and the adjustments
//    [self updateControlsFromValuesAndSkipSource:NO];
//    [self updateColorSplits];
}

///*
// *  A slider is being modified.
// */
//-(IBAction)doChangeSlider:(id)sender
//{
//    UISlider *slider = (UISlider *) sender;
//    int index = slider.tag - 101;
//    CGFloat curValue = slider.value;
//    
//    if (sender == slColorFax) {
//        cfResolution = (curValue / 1.0f);
//        slider.value = cfResolution;            //  snap to the integer value.
//        [self updateControlsFromValuesAndSkipSource:YES];
//    }
//    else if (index < 3) {
//        int notch = (curValue / DRV_CSV_MIN_SNAP_RESOLUTION);
//        curValue = ((CGFloat) notch * DRV_CSV_MIN_SNAP_RESOLUTION);
//        slider.value = curValue;
//        
//        CGFloat comps[4];
//        [srcColor getHue:&(comps[0]) saturation:&(comps[1]) brightness:&(comps[2]) alpha:&(comps[3])];
//        comps[index] = curValue;
//        [srcColor release];
//        srcColor = [[UIColor colorWithHue:comps[0] saturation:comps[1] brightness:comps[2] alpha:comps[3]] retain];
//        
//        if (index == 0 || index == 2) {
//            [self updateControlsFromValuesAndSkipSource:YES];
//        }
//        else {
//            [self syncUpColors];
//        }
//    }
    else {
//        if (index == 3) {
//            curValue = (trunc(curValue * 20.0f)/20.0f);
//            slider.value = curValue;
//            CGFloat maxColorDelta = [tdriverColorSplitViewController colorDeltaForResolution:cfResolution];
//            curValue = curValue * maxColorDelta;
//            CGFloat delta = maxColorDelta + curValue;
//            
//            UISlider *slPrimaryHue = (UISlider *) [self.view viewWithTag:101];
//            hueA = slPrimaryHue.value - delta;
//            if (hueA > 1.0f) {
//                hueA -= 1.0f;
//            }
//            else if (hueA < 0.0f) {
//                hueA += 1.0f;
//            }
//        }
//        else if (index == 7) {
//            curValue = (trunc(curValue * 20.0f)/20.0f);
//            slider.value = curValue;
//            CGFloat maxColorDelta = [tdriverColorSplitViewController colorDeltaForResolution:cfResolution];
//            curValue = curValue * maxColorDelta;
//            CGFloat delta = maxColorDelta + curValue;
//            
//            UISlider *slPrimaryHue = (UISlider *) [self.view viewWithTag:101];
//            hueB = slPrimaryHue.value + delta;
//            if (hueB > 1.0f) {
//                hueB -= 1.0f;
//            }
//            else if (hueB < 0.0f) {
//                hueB += 1.0f;
//            }
//        }
//        else if (index == 4) {
//            curValue = trunc(curValue);
//            slider.value = curValue;
//            
//            // - this slider is expressed from 0-51 because we need to represent +0/-0 or the precision slider won't be able
//            //   to address 0 to -0.0099
//            if ((int) curValue == 25) {
//                curValue = -0.0f;
//            }
//            else if ((int) curValue == 26) {
//                curValue = 0.0f;
//            }
//            else if (curValue < 26) {
//                curValue = (curValue - 25.0f)/100.0f;
//            }
//            else {
//                curValue = (curValue - 26.0f)/100.0f;
//            }
//            valueA = curValue;
//            
//            // - synchronization:
//            //   my theory is that the distance between values is identical when we get the right kind of result.  In order to
//            //   ensure that, I'll manually update the value for hue B also at the same time to be the inverse of this value.
//            valueB = -valueA;
//            
//            // - the sub-precision slider is reset when the super precision slider changes.
//            [self updateNumberField:6 withValue:0.0f];
//            UISlider *slPrecA = (UISlider *) [self.view viewWithTag:107];
//            slPrecA.value = 0.0f;
//        }
//        else if (index == 6) {
//            // - this slider is a precision from 0 to 100 and represents up to ten thousandths of a point.
//            curValue = floorf(curValue);
//            CGFloat curPrec = curValue;
//            slider.value = curPrec;
//            curPrec /= DRV_VALUE_PRECISION;
//            
//            CGFloat tmp = trunc(valueA * 100.0f)/100.0f;
//            if (valueA < 0.0f) {
//                valueA = tmp - curPrec;
//            }
//            else {
//                valueA = tmp + curPrec;
//            }
//            valueB = -valueA;
//        }
//        
//        // - always save the data after a sub-color modification
//        [self saveCurrentData];
    }
//    
//    [self updateNumberField:index withValue:curValue];
//    [self updateColorSplits];
//}

/*
 *  Dump the data to the log.
 */
-(IBAction)doDumpData:(id)sender
{
    if (![mdSnapData count]) {
        NSLog(@"ERROR:  No data to dump to CSV.");
        return;
    }
    
    NSMutableArray *arr = [NSMutableArray arrayWithArray:[mdSnapData allValues]];
    [arr sortUsingComparator:^NSComparisonResult(SplitColorDataPoint *obj1, SplitColorDataPoint *obj2){
        if (obj1.sat < obj2.sat) {
            return NSOrderedAscending;
        }
        else if (fabsf(obj1.sat - obj2.sat) > 0.001f) {
            return NSOrderedDescending;
        }
        else {
            if (obj1.value < obj2.value) {
                return NSOrderedAscending;
            }
            else if (obj1.value > obj2.value) {
                return NSOrderedDescending;
            }
            else {
                if (obj1.hue < obj2.hue) {
                    return NSOrderedAscending;
                }
                else if (obj1.hue > obj2.hue) {
                    return NSOrderedDescending;
                }
                else {
                    return NSOrderedSame;
                }
            }
        }
    }];
    
    NSString *dumpHue  = @"";
    NSString *dumpHueA = @"";
    NSString *dumpHueB = @"";
    NSString *dumpVal  = @"";
    NSString *dumpValA = @"";
    NSString *dumpValB = @"";
    BOOL doDumpNow = NO;
    CGFloat curSat = -1.0f;
    for (NSUInteger i = 0; i < [arr count]; i++) {
        SplitColorDataPoint *dp = [arr objectAtIndex:i];
        curSat = dp.sat;
        
        dumpHue  = [dumpHue stringByAppendingFormat:@",%1.3f", dp.hue];
        dumpHueA = [dumpHueA stringByAppendingFormat:@",%1.3f", dp.hueSubA];
        dumpHueB = [dumpHueB stringByAppendingFormat:@",%1.3f", dp.hueSubB];
        
        dumpVal  = [dumpVal stringByAppendingFormat:@",%1.3f", dp.value];
        dumpValA  = [dumpValA stringByAppendingFormat:@",%1.3f", dp.valSubA];
        dumpValB  = [dumpValB stringByAppendingFormat:@",%1.3f", dp.valSubB];
        
        
        doDumpNow = NO;
        if (i == [arr count] - 1) {
            doDumpNow = YES;
        }
        else {
            dp = [arr objectAtIndex:i+1];
            if (fabsf(dp.sat - curSat) > 0.001f) {
                doDumpNow = YES;
            }
        }
        
        if (doDumpNow) {
            NSString *dumpData = @"";
            dumpData = [dumpData stringByAppendingFormat:@"SATURATION = %1.4f\n\n", curSat];
            dumpData = [dumpData stringByAppendingFormat:@"HUE%@\n", dumpHue];
            dumpData = [dumpData stringByAppendingFormat:@"HUE-SUB-A%@\n", dumpHueA];
            dumpData = [dumpData stringByAppendingFormat:@"HUE-SUB-B%@\n\n", dumpHueB];
            
            dumpData = [dumpData stringByAppendingFormat:@"VALUE%@\n", dumpVal];
            dumpData = [dumpData stringByAppendingFormat:@"VAL-SUB-A%@\n", dumpValA];
            dumpData = [dumpData stringByAppendingFormat:@"VAL-SUB-B%@\n", dumpValB];
            
            NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
            NSString *sFile = [NSString stringWithFormat:@"colordata-%dV2.csv", (int) (curSat * 1000)];
            u = [u URLByAppendingPathComponent:sFile];
            NSError *err = nil;
            if (![dumpData writeToURL:u atomically:YES encoding:NSASCIIStringEncoding error:&err]) {
                NSLog(@"ERROR: Failed to write %@.  %@", sFile, [err localizedDescription]);
                return;
            }
            
            dumpHue = @"";
            dumpHueA = @"";
            dumpHueB = @"";
            dumpVal  = @"";
            dumpValA = @"";
            dumpValB = @"";
        }
    }
    
    // - dump the colorfax info also.
    [self dumpColorFaxConstants];
    
    NSString *sMsg = [NSString stringWithFormat:@"%d item%s output to CSV.", [mdSnapData count], [mdSnapData count] > 1 ? "s were" : " was"];
    UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"COLORSPLIT NOTICE" message:sMsg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [av show];
    [av release];
}

///*
// *  When the view is about to disapper, halt all timing ooperations.
// */
//-(void) viewWillDisappear:(BOOL)animated
//{
//    [super viewWillDisappear:animated];
//    [saveTimer invalidate];
//    [displayLink invalidate];
//}

///*
// *  Delete the current color item and sync up the colors again.
// */
//-(IBAction)doDeleteCurrent:(id)sender
//{
//    UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:@"Are you sure you want to delete the current color item?" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Delete Item" otherButtonTitles:nil];
//    [as showInView:self.view];
//    [as release];
//}

///*
// *  Snapshot the current data file.
// */
//-(IBAction)doSnapshot:(id)sender
//{
//    // - make sure the color file is up to date.
//    [self persistTimeout];
//    
//    // - and make a copy
//    NSURL *u = [self archiveFilePath];
//    NSData *d = [NSData dataWithContentsOfURL:u];
//    
//    NSInteger ver = [[NSUserDefaults standardUserDefaults] integerForKey:DRV_CSV_VERSION];
//    NSString *sVer = [NSString stringWithFormat:@".snap%04d", ver];
//    u = [u URLByAppendingPathExtension:sVer];
//    if (![d writeToURL:u atomically:YES]) {
//        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"COLORSPLIT ERROR" message:@"Failed to take a snapshot." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
//        [av show];
//        [av release];
//        return;
//    }
//    btnSnapshot.enabled = NO;
//}

@end


/*******************************************
 tdriverColorSplitViewController (internal)
 *******************************************/
@implementation tdriverColorSplitViewController (internal)

///*
// *  Return the standard color delta for a given colorfax resolution.
// */
//+(CGFloat) colorDeltaForResolution:(pscf_colorfax_resolution_t) res
//{
//    return PSCF_COLORFAX_MIN_DELTA + (PSCF_COLORFAX_TICK * (CGFloat) (res + 1));
//}

///*
// *  Using the ColorFax algorithm, split the source color into two separate colors,
// *  assuming that the saturation is unchanged.
// */
//+(void) splitSourceColor:(UIColor *) c intoHueA:(CGFloat *) hA andValueA:(CGFloat *) vA andHueB:(CGFloat *) hB andValueB:(CGFloat *) vB
//         usingResolution:(pscf_colorfax_resolution_t) res
//{
//    // - decompose the source color into HSV
//    CGFloat h, s, b, a;
//    [c getHue:&h saturation:&s brightness:&b alpha:&a];

    // - figure out the magnitude of this set of adjustments
    CGFloat magnitude = PSCF_COLORFAX_MAGNITUDES[res];
//    CGFloat valueAdjA, valueAdjB;
//    CGFloat pctOfAdj = 0.0f;
    if (magnitude > -0.0f) {
        // - the values are computed using the lookup table because the distribution is highly
        //   dependent on the source hue and the current saturation.
        
        // - first determine the location of the source hue in the table and retrieve the
        //   value before and after
        // - since the hues are a continuous range from 0 to 360 degrees, we can use the
        //   values in the table the same way.
        int posBefore = h / PSCF_HUE_TICK;
        
        // - now determine the position of the target hue in that range
        CGFloat pctOfRange = (h - ((CGFloat) posBefore * PSCF_HUE_TICK))/PSCF_HUE_TICK;
        
        // - and manage the wrapping of hues
        if (posBefore >= PSCF_HUE_REFERENCE_RESOLUTION) {
            posBefore = 0;
        }
        int posAfter  = posBefore + 1;
        if (posAfter >= PSCF_HUE_REFERENCE_RESOLUTION) {
            posAfter = 0;
        }
        
        // - now compute the value deltas of the hue before and the hue after
        // - through my investigation I believe I found that saturation proportionally
        //   affects the value adjustment and since this app only captures at saturation = 1.0f, we
        //   can multiply by saturation as-is.
        CGFloat vDeltaBefore = PSCF_COLORFAX_VALUE[res][posBefore] * magnitude * s;
        CGFloat vDeltaAfter  = PSCF_COLORFAX_VALUE[res][posAfter] * magnitude * s;
        
        //  - interpolate between the two value deltas
        valueAdjA = valueAdjB = ((vDeltaAfter - vDeltaBefore) * pctOfRange) + vDeltaBefore;
        
        // - clamp the value changes to [0,1]
        if (b + valueAdjA > 1.0f) {
            //  when the value exeeds the maximum, we need to shift the hue
            //  in order to compensate for the fact we can't go brighter.
            CGFloat excess = 1.0f - (b + valueAdjA);
            pctOfAdj       = fabsf(excess/valueAdjA);
        }
        else if (b + valueAdjA < 0.0f) {
            valueAdjA = -b;
        }
        
        // - clamp the value changes to [0,1]
        if (b - valueAdjB > 1.0f) {
            //  when the value exeeds the maximum, we need to shift the hue
            //  in order to compensate for the fact we can't go brighter.
            CGFloat excess   = 1.0f - (b - valueAdjB);
            pctOfAdj = fabsf(excess/valueAdjB);
        }
        else if (b - valueAdjB < 0.0f) {
            valueAdjB = -b;
        }
    }
    else {
//        // - a crude approximation when data isn't populated.
//        valueAdjA = valueAdjB = 0.06f;
    }
    
//    // - with colorfax, the hues are equidistant from the source on opposite sides unless
//    //   the value gets maxed out, in which case we need to adjust everything proportionally
//    //   by the value difference.
//    CGFloat delta = [tdriverColorSplitViewController colorDeltaForResolution:res];
//    delta *= (1.0f - pctOfAdj);
//    *hA  = h - delta;
//    if (*hA < 0.0f) {
//        *hA += 1.0f;
//    }
//    *hB = h + delta;
//    if (*hB > 1.0f) {
//        *hB = *hB - 1.0f;
//    }
//    
//    // - make the final value adjustments based
//    valueAdjA *= (1.0f - pctOfAdj);
//    valueAdjB *= (1.0f - pctOfAdj);
//    
//    // - return the final value changes.
//    *vA = valueAdjA;
//    *vB = -valueAdjB;
}

///*
// *  Synch up the colors for the algorithm testing.
// */
//-(void) syncUpColors
//{
    // - if there are no current data points there is nothing to dump
    btnDumpData.enabled = ([mdSnapData count] > 0) ? YES : NO;
    
//    // - we assume that the current slider positions
//    //   are accurate
//    NSUInteger snapId = [self snapIdForCurrentColor];
//    SplitColorDataPoint *dp = [mdSnapData objectForKey:[NSNumber numberWithUnsignedInteger:snapId]];
//    if (dp) {
        btnDeleteCur.enabled = YES;
//        hueA         = dp.hueSubA;
//        valueA       = dp.valSubA;
//        hueB         = dp.hueSubB;
//        valueB       = dp.valSubB;
//        cfResolution = dp.cfax;
//        return;
//    }

    // - when there is no current item, there is nothing to delete
    btnDeleteCur.enabled = NO;
    
//    [tdriverColorSplitViewController splitSourceColor:srcColor intoHueA:&hueA andValueA:&valueA andHueB:&hueB andValueB:&valueB usingResolution:cfResolution];
//}

///*
// *  This routine assigns the source color.
// */
//-(void) setSourceColor:(UIColor *) c
//{
//    if (c == srcColor) {
//        return;
//    }
//    
//    [srcColor release];
//    srcColor = [c retain];
//    if (!c) {
//        return;
//    }
//    
//    [self syncUpColors];
//    [self updateColorSplits];
//}

///*
// *  When the display link is fired, this method is called.
// */
//-(void) displayLinkTriggered:(CADisplayLink *) link
//{
//    [glvAfter display];
//}
//
///*
// *  Manage the drawing sequence.
// */
//-(void) glkView:(GLKView *)view drawInRect:(CGRect)rect
//{
//    if (drawColorA) {
//        glClearColor(v4ColorA.r, v4ColorA.g, v4ColorA.b, v4ColorA.a);
//    }
//    else {
//        glClearColor(v4ColorB.r, v4ColorB.g, v4ColorB.b, v4ColorB.a);
//    }
//    glClear(GL_COLOR_BUFFER_BIT);
//    drawColorA = !drawColorA;
//}

///*
// *  Change the value of the number field.
// */
//-(void) updateNumberField:(int) field withValue:(CGFloat) value
//{
//    NSString *sVal = nil;
//    if (field == 0) {
//        value = value * 360.0f;     //  convert to degrees.
//        sVal = [NSString stringWithFormat:@"%3.1f°", value];
//    }
//    else if (field == 3 || field == 7) {
//        CGFloat maxColorDelta = [tdriverColorSplitViewController colorDeltaForResolution:cfResolution];
//        value = value * maxColorDelta;
//        sVal = [NSString stringWithFormat:@"%2.3f", value];
//    }
//    else if (field == 6) {
//        sVal = [NSString stringWithFormat:@"%d", (int) value];
//    }
//    else {
//        CGFloat tval = trunc(value * 100.0f);
//        tval /= 100.0f;
//        sVal = [NSString stringWithFormat:@"%2.2f", tval];
//    }
//    
//    UILabel *l = (UILabel *) [self.view viewWithTag:201 + field];
//    if (l) {
//        l.text = sVal;
//    }
//    
//    // - turn the colorfax highlight on/off
//    if (field == 1 || field == 2) {
//        CGFloat newAlpha = 0.0f;
//        if ([self isColorFaxEnabled]) {
//            newAlpha = 1.0f;
//        }
//        [UIView animateWithDuration:0.5f animations:^(void){
//            lCFEnabled.alpha = newAlpha;
//        }];
//    }
//}

///*
// *  Update the controls from the sub-item RGB values.
// */
//-(void) updateControlsFromValuesAndSkipSource:(BOOL) skipSource
//{
//    CGFloat maxColorDelta = [tdriverColorSplitViewController colorDeltaForResolution:cfResolution];
//    CGFloat comps[4];
//    [srcColor getHue:&(comps[0]) saturation:&(comps[1]) brightness:&(comps[2]) alpha:&(comps[3])];
//    
//    for (int i = 0; i < 8; i++) {
//        CGFloat curValue = 0.0f;
//        if (i < 3) {
//            if (!skipSource) {
//                curValue = comps[i];
//            }
//        }
//        else {
//            // - always sync up these colors before the first field is processed.
//            if (i == 3) {
//                [self syncUpColors];
//            }
//
//            CGFloat tmp = 0.0f;
//            switch (i)
//            {
//                case 3:
//                    tmp = hueA - comps[0];
//                    if (tmp > 0.0f) {
//                        tmp -= 1.0f;
//                    }
//                    curValue = (tmp + maxColorDelta)/maxColorDelta;
//                    curValue = (trunc(curValue * 20.0f)/20.0f);
//                    break;
//                    
//                case 4:
//                    curValue = trunc(valueA * 100.0f)/100.0f;
//                    break;
//                    
//                case 7:
//                    tmp = hueB - comps[0];
//                    if (tmp < 0.0f) {
//                        tmp += 1.0f;
//                    }
//                    curValue = (tmp - maxColorDelta)/maxColorDelta;
//                    curValue = (trunc(curValue * 20.0f)/20.0f);
                    break;
                    
//                case 6:
//                    tmp = fabsf(valueA);
//                    tmp = (tmp * 100.0f) - trunc(tmp * 100.0f);
//                    tmp *= (DRV_VALUE_PRECISION / 100.0f);
//                    curValue = tmp;
//                    break;
//            }
        }
//        
//        if (!skipSource || i > 2) {
//            [self updateNumberField:i withValue:curValue];
//            
//            UISlider *slider = (UISlider *) [self.view viewWithTag:101 + i];
            if (i == 4) {
                //  - convert to the goofy range we're using.
                curValue = trunc(curValue * 100.0f);
                if (curValue < 0.0f) {
                    curValue += 25.0f;
                }
                else {
                    curValue += 26.0f;      //  advance to the positive range
                }
            }
//            slider.value = curValue;
//        }
//    }
//
//    // - set the colorfax slider last.
//    slColorFax.value = cfResolution;
//}

///*
// *  Modify the split of colors.
// */
//-(void) updateColorSplits
//{
//    // - show the colors in the display (the GL display will be updated on each frame automatically)
//    vwBefore.backgroundColor = srcColor;
//    
//    CGFloat h, s, b, a;
//    [srcColor getHue:&h saturation:&s brightness:&b alpha:&a];
//    
//    // - the target color is a value-difference away from the current color based on the
//    //   colorfax resolution.
//    CGFloat diff = (CGFloat) cfResolution / (CGFloat) PSCF_COLORFAX_RESOLUTION;
//    CGFloat targetBrightness = b - (diff * DRV_CFAX_VALUE_DIFF_RANGE);
//    if (targetBrightness < 0.0f) {
//        targetBrightness = 0.0f;
//    }
//    CGFloat targetSaturation = s - (diff * DRV_CFAX_SAT_DIFF_RANGE);
//    if (targetSaturation < 0.0f) {
//        targetSaturation = 0.0f;
//    }
//    vwTarget.backgroundColor = [UIColor colorWithHue:h saturation:targetSaturation brightness:targetBrightness alpha:1.0f];

//    // - the secondary colors have the same saturation
//    UIColor *c = [UIColor colorWithHue:hueA saturation:s brightness:b + valueA alpha:a];
//    vwPart1.backgroundColor = c;
//    CGFloat red, green, blue;
//    [c getRed:&red green:&green blue:&blue alpha:&a];
//    v4ColorA = GLKVector4Make(red, green, blue, a);
//    
//    c = [UIColor colorWithHue:hueB saturation:s brightness:b + valueB alpha:a];
//    vwPart2.backgroundColor = c;
//    [c getRed:&red green:&green blue:&blue alpha:&a];
//    v4ColorB = GLKVector4Make(red, green, blue, a);
//}

///*
// *  Take a snapshot of the current data.
// */
//-(void) saveCurrentData
//{
//    SplitColorDataPoint *dp =[[SplitColorDataPoint alloc] init];
//    
//    // - use the sliders and not the saved source color because
//    //   a hue of 0.0f will be silently converted to 1.0f by the
//    //   color and that will hose up our accounting here.
//    UISlider *s = nil;
//    CGFloat hue, sat, val;
//    s = (UISlider *) [self.view viewWithTag:101];
//    hue = s.value;
//    s = (UISlider *) [self.view viewWithTag:102];
//    sat = s.value;
//    s = (UISlider *) [self.view viewWithTag:103];
//    val = s.value;
//    [dp setMainHue:hue andSaturation:sat andBrightness:val withColorFax:cfResolution];
//    [dp setSubAHue:hueA andBrightness:valueA];
//    [dp setSubBHue:hueB andBrightness:valueB];
//    
//    // - now store the content in our dictionary.
//    NSUInteger sid = [dp snapId];
//    BOOL hasPoint = NO;
//    if ([mdSnapData objectForKey:[NSNumber numberWithUnsignedInteger:sid]]) {
//        hasPoint = YES;
//    }
//    [mdSnapData setObject:dp forKey:[NSNumber numberWithUnsignedInteger:sid]];
//    
//    
    // - and update the colorfax table if necessary
    if ([self isColorFaxEnabled]) {
        [self updateColorFaxTableWithData:dp];
    }
    
//    [dp release];
//    
//    // - set the flag so that we save on the next opportunity.
//    snapModified = YES;
//    
//    // - update the version number
//    NSInteger ver = [[NSUserDefaults standardUserDefaults] integerForKey:DRV_CSV_VERSION];
//    ver++;
//    [[NSUserDefaults standardUserDefaults] setInteger:ver forKey:DRV_CSV_VERSION];
//    
    // ...but allow the deletion to occur too
    btnDeleteCur.enabled = YES;
    
    // ...and the dump
    btnDumpData.enabled = YES;
//}

///*
// *  Return the location where we store the color archive.
// */
//-(NSURL *) archiveFilePath
//{
//    NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
//    return [u URLByAppendingPathComponent:@"colorsplits.karV2"];
//}

///*
// *  When this timeout is fired, we should try to write the current content
// *  to disk.
// */
//-(void) persistTimeout
//{
//    if (snapModified) {
//        NSURL *u = [self archiveFilePath];
//        NSData *d = [NSKeyedArchiver archivedDataWithRootObject:mdSnapData];
//        if (!d) {
//            NSLog(@"ERROR: Failed to convert the snap data to an archive.!");
//            return;
//        }
//        
//        if (![d writeToURL:u atomically:YES]) {
//            NSLog(@"ERROR:  Failed to archive the color data to the device.");
//        }
//        
//        // - when we first save, the snapshot button is now available.
        btnSnapshot.enabled = YES;
//        snapModified = NO;
//    }
}

/*
 *  When the view is first created, we need to try to load the archive from disk.
 */
-(void) configureColorStore;
{
//    @try {
//        NSURL *u = [self archiveFilePath];
//        mdSnapData = [[NSKeyedUnarchiver unarchiveObjectWithFile:[u path]] retain];
//    }
//    @catch (NSException *exception) {
//        NSLog(@"ERROR: Failed to load the color store.  %@", [exception description]);
//    }
    
//    if (mdSnapData) {
        // - if there is data in the dictionary that hasn't yet been updated in the
        //   official inlined table here, update that now.
        for (SplitColorDataPoint *dp in mdSnapData.allValues) {
            [self updateColorFaxTableWithData:dp];
        }
//    }
//    else {
//        mdSnapData = [[NSMutableDictionary alloc] init];
//        btnSnapshot.enabled = NO;
//    }
}

///*
// *  Return the snap id for the current color combination.
// */
//-(NSUInteger) snapIdForCurrentColor
//{
//    UISlider *s = nil;
//    CGFloat hue, sat, val;
//    s = (UISlider *) [self.view viewWithTag:101];
//    hue = s.value;
//    s = (UISlider *) [self.view viewWithTag:102];
//    sat = s.value;
//    s = (UISlider *) [self.view viewWithTag:103];
//    val = s.value;
//    return [SplitColorDataPoint snapIdForFax:cfResolution andHue:hue andSat:sat andVal:val];
//}

///*
// *  The user has confirmed that the current item should be deleted.
// */
//-(void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
//{
//    if (buttonIndex != 0) {
//        return;
//    }
//    NSLog(@"NOTICE:  Deleting the current color item.");
//    
//    NSUInteger snapId = [self snapIdForCurrentColor];
//    [mdSnapData removeObjectForKey:[NSNumber numberWithUnsignedInteger:snapId]];
//    snapModified = YES;
//    [self syncUpColors];
//    [self updateColorSplits];
//    [self updateControlsFromValuesAndSkipSource:YES];

    //  delete the current colorfax item if necessary
    if ([self isColorFaxEnabled]) {
        CGFloat h,s, b, a;
        [srcColor getHue:&h saturation:&s brightness:&b alpha:&a];
        int index = h/PSCF_HUE_TICK;
        [self recalibrateColorFaxWithResolution:cfResolution atIndex:index withValue:0.0f];
    }
}

/*
 *  This is wired up the soure color to make it easier to skip through hues.
 */
-(void) tapAdvanceHue
{
    UISlider *slHue = (UISlider *) [self.view viewWithTag:101];
    slHue.value += DRV_CSV_MIN_SNAP_RESOLUTION;
    if (slHue.value > 1.0f) {
        slHue.value = 1.0f;
    }
    [self doChangeSlider:slHue];
}

/*
 *  Save the current item explicitly.
 */
-(void) tapSaveCurrent
{
    [self saveCurrentData];
    
    btnDeleteCur.enabled = YES;
    btnDumpData.enabled = YES;
}

///*
// *  Determines if we're storing colorfax reference information.
// */
//-(BOOL) isColorFaxEnabled
//{
//    if (!isLoaded) {
//        return YES;
//    }
//    UISlider *sl = (UISlider *) [self.view viewWithTag:102];
//    return [self isColorFaxReferenceSaturation:sl.value];
//}

///*
// *  It turns out that the variation in value between the two sub-colors is greatest
// *  when the saturation is at its highest.  Because this offers the greatest precision
// *  we'll only capture ColorFax data during that time.
// */
//-(BOOL) isColorFaxReferenceSaturation:(CGFloat) sat
//{
//    if (!isLoaded) {
//        return YES;
//    }
//    
//    // - because values above 0.75 will require extra adjustments, don't
//    //   allow them to contribute to colorfax data.
//    UISlider *sl = (UISlider *) [self.view viewWithTag:103];
//    if (sl.value > 0.75f) {
//        return NO;
//    }
//    
//    if (fabsf(PSCF_COLORFAX_REF_SATURATION - sat) < DRV_CSV_MIN_SNAP_RESOLUTION) {
//        return YES;
//    }
//    return NO;
//}

/*
 *  Because we have the magnitude split from the value curve, we need to always assume that the magnitudes are incorrect
 *  when changes occur.  A shift downward, for instance, should modify the entire curve if the high value was changed because
 *  we don't need that level of precision any longer.
 */
-(void) recalibrateColorFaxWithResolution:(pscf_colorfax_resolution_t) res atIndex:(int) hueIndex withValue:(CGFloat) newValue
{
    // - the table is currently calibrated to the reference magnitude, so it
    //   will be used to recreate the items' original values
    CGFloat refMag = PSCF_COLORFAX_MAGNITUDES[res];
    
    CGFloat realMag = 0.0f;
    for (int i = 0; i < PSCF_HUE_REFERENCE_RESOLUTION; i++) {
        CGFloat oldValue = 0.0f;
        if (i == hueIndex) {
            oldValue = newValue;
        }
        else {
            oldValue = PSCF_COLORFAX_VALUE[res][i];
            oldValue *= refMag;
        }
        
        // - remember that the 'value' can be negative.
        if (fabsf(oldValue) > realMag) {
            realMag = fabsf((oldValue));
        }
    }
    
    // - now adjust all the items.
    for (int i = 0; i < PSCF_HUE_REFERENCE_RESOLUTION; i++) {
        CGFloat oldValue = 0.0f;
        if (i == hueIndex) {
            oldValue = newValue;
        }
        else {
            oldValue = PSCF_COLORFAX_VALUE[res][i];
            oldValue *= refMag;
        }
        
        CGFloat newValue = oldValue/realMag;
        if (isnan(newValue)) {
            newValue = 0.0f;
        }
        PSCF_COLORFAX_VALUE[res][i] = newValue;
    }
    
    // ...and save the new magnitude
    PSCF_COLORFAX_MAGNITUDES[res] = realMag;
}

/*
 *  If the data point can contribute to colorfax processing, use it to update the
 *  value and magnitude tables.
 */
-(void) updateColorFaxTableWithData:(SplitColorDataPoint *) dp
{
    // - omit points whose data is not precise enough.
    if (![self isColorFaxReferenceSaturation:dp.sat]) {
        return;
    }
    
    // - I want to keep the magnitudes out of the colorfax table just to allow me to
    //   produce graphs that are consistent with one another.  Because this is the case,
    //   when the magnitude changes, I'll have to update all the existing items.
    
    // - the magnitude of the graph is the absolute value of sub-hue A's value.  B's is an inverse of
    //   it and doesn't need to be recorded.
    int hueIndex = dp.hue/PSCF_HUE_TICK;
    [self recalibrateColorFaxWithResolution:dp.cfax atIndex:hueIndex withValue:dp.valSubA];
}

/*
 *  Write the colorfax constants to file and the log.
 */
-(void) dumpColorFaxConstants
{
    // - the stuff we write to file is used entirely for reporting and is in CSV format
    NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    u = [u URLByAppendingPathComponent:@"colorfaxV2.csv"];
    
    NSString *sColorFaxData = @"mags";
    
    for (int i = 0; i < PSCF_COLORFAX_RESOLUTION; i++) {
        sColorFaxData = [sColorFaxData stringByAppendingFormat:@",%4.4f", PSCF_COLORFAX_MAGNITUDES[i]];
    }
    sColorFaxData = [sColorFaxData stringByAppendingString:@"\n\n"];
    
    for (int i = 0; i < PSCF_COLORFAX_RESOLUTION; i++) {
        NSString *lineNum = [NSString stringWithFormat:@"res%d", i];
        sColorFaxData = [sColorFaxData stringByAppendingString:lineNum];
        
        for (int j = 0; j < PSCF_HUE_REFERENCE_RESOLUTION; j++) {
            sColorFaxData = [sColorFaxData stringByAppendingFormat:@",%1.5f", PSCF_COLORFAX_VALUE[i][j]];
        }
        sColorFaxData = [sColorFaxData stringByAppendingString:@"\n"];
    }
    
    if (![sColorFaxData writeToURL:u atomically:YES encoding:NSASCIIStringEncoding error:nil]) {
        NSLog(@"ERROR: failed to dump the colorfax data to file.");
        return;
    }
    
    //  - now the stuff we re-import into this codebase is just dumped to log
    sColorFaxData = @"";
    sColorFaxData = [sColorFaxData stringByAppendingFormat:@"typedef enum\n"];
    sColorFaxData = [sColorFaxData stringByAppendingFormat:@"{\n"];
    sColorFaxData = [sColorFaxData stringByAppendingFormat:@"PSCF_COLORFAX_NEAREST  = %d,\n\n", PSCF_COLORFAX_NEAREST];
    sColorFaxData = [sColorFaxData stringByAppendingFormat:@"PSCF_COLORFAX_MODERATE = %d,\n\n", PSCF_COLORFAX_MODERATE];
    sColorFaxData = [sColorFaxData stringByAppendingFormat:@"PSCF_COLORFAX_OBSCURE  = %d,\n\n", PSCF_COLORFAX_OBSCURE];
    sColorFaxData = [sColorFaxData stringByAppendingFormat:@"PSCF_COLORFAX_RESOLUTION\n"];
    sColorFaxData = [sColorFaxData stringByAppendingFormat:@"} pscf_colorfax_resolution_t;\n"];
    
    sColorFaxData = [sColorFaxData stringByAppendingFormat:@"static const CGFloat PSCF_COLORFAX_MAX_DELTA       = (%3.1f/360.0);\n", PSCF_COLORFAX_MAX_DELTA * 360.0f];
    sColorFaxData = [sColorFaxData stringByAppendingFormat:@"static const CGFloat PSCF_COLORFAX_MIN_DELTA       = (%3.1f/360.0);\n", PSCF_COLORFAX_MIN_DELTA * 360.0f];
    sColorFaxData = [sColorFaxData stringByAppendingFormat:@"static const CGFloat PSCF_COLORFAX_TICK            = ((PSCF_COLORFAX_MAX_DELTA - PSCF_COLORFAX_MIN_DELTA) / (CGFloat) PSCF_COLORFAX_RESOLUTION);\n"];
    sColorFaxData = [sColorFaxData stringByAppendingFormat:@"static const int     PSCF_HUE_REFERENCE_RESOLUTION = %d;\n", PSCF_HUE_REFERENCE_RESOLUTION];
    sColorFaxData = [sColorFaxData stringByAppendingFormat:@"static const CGFloat PSCF_HUE_TICK                 = (1.0 / (CGFloat) PSCF_HUE_REFERENCE_RESOLUTION);\n"];
    sColorFaxData = [sColorFaxData stringByAppendingFormat:@"static const BOOL    PSCF_HAS_COLORFAX_DATA        = YES;\n"];
    sColorFaxData = [sColorFaxData stringByAppendingFormat:@"static const CGFloat PSCF_COLORFAX_REF_SATURATION  = 1.0f;\n"];
    
    sColorFaxData = [sColorFaxData stringByAppendingFormat:@"static CGFloat       PSCF_COLORFAX_MAGNITUDES[PSCF_COLORFAX_RESOLUTION] = {"];
    for (int i = 0; i < PSCF_COLORFAX_RESOLUTION; i++) {
        sColorFaxData = [sColorFaxData stringByAppendingFormat:@"%s%4.5f", (i > 0) ? "," : "", PSCF_COLORFAX_MAGNITUDES[i]];
    }
    sColorFaxData = [sColorFaxData stringByAppendingFormat:@"};\n"];
    
    sColorFaxData = [sColorFaxData stringByAppendingFormat:@"static CGFloat       PSCF_COLORFAX_VALUE[PSCF_COLORFAX_RESOLUTION][PSCF_HUE_REFERENCE_RESOLUTION] = {\n"];
    for (int i = 0; i < PSCF_COLORFAX_RESOLUTION; i++) {
        sColorFaxData = [sColorFaxData stringByAppendingFormat:@"%s    {", (i > 0) ? ",\n" : ""];
        for (int j = 0; j < PSCF_HUE_REFERENCE_RESOLUTION; j++) {
            const char *szSep = "";
            if (j > 0) {
                if (j == PSCF_HUE_REFERENCE_RESOLUTION / 2) {
                    szSep = ",\n     ";
                }
                else {
                    szSep = ",";
                }
            }
            sColorFaxData = [sColorFaxData stringByAppendingFormat:@"%s% 4.5f", szSep, PSCF_COLORFAX_VALUE[i][j]];
        }
        sColorFaxData = [sColorFaxData stringByAppendingFormat:@"}"];
    }
    sColorFaxData = [sColorFaxData stringByAppendingFormat:@"};\n"];
    
    u = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    u = [u URLByAppendingPathComponent:@"colorfax-codeV2.txt"];
    if (![sColorFaxData writeToURL:u atomically:YES encoding:NSASCIIStringEncoding error:nil]) {
        NSLog(@"ERROR: Failed to save the colorfax generated constants.");
        return;
    }
    
    NSLog(@"DEBUG: Colorfax code:\n%@", sColorFaxData);
    NSLog(@"DEBUG: !!!! YOU SHOULD USE THE GENERATED SOURCE FILE TO AVOID GOOFY SPACES !!!!");
}

/*
 *  Test if we're in a position where we should update the value delta incrementally.
 */
-(void) tapValDeltaUpdate:(UITapGestureRecognizer *) gesture
{
    CGPoint pt = [gesture locationInView:self.view];
    
    UILabel *lLeft  = (UILabel *) [self.view viewWithTag:300];
    UILabel *lRight = (UILabel *) [self.view viewWithTag:205];
    UISlider *slValue = (UISlider *) [self.view viewWithTag:105];
    CGFloat val = slValue.value;
    if (CGRectContainsPoint(lLeft.frame, pt)) {
        val = val - 1;
        if (val < slValue.minimumValue) {
            val = slValue.minimumValue;
        }
        slValue.value = val;
        [self doChangeSlider:slValue];
    }
    else if (CGRectContainsPoint(lRight.frame, pt)) {
        val = val + 1;
        if (val > slValue.maximumValue) {
            val = slValue.maximumValue;
        }
        slValue.value = val;
        [self doChangeSlider:slValue];
    }
}

@end

///**************************
// SplitColorDataPoint
// **************************/
//@implementation SplitColorDataPoint
//@synthesize cfax;
//@synthesize hue;
//@synthesize sat;
//@synthesize value;
//@synthesize hueSubA;
//@synthesize valSubA;
//@synthesize hueSubB;
//@synthesize valSubB;
//
///*
// *  Generate a unique id for the given combination.
// */
//+(NSUInteger) snapIdForFax:(pscf_colorfax_resolution_t) cfax andHue:(CGFloat) hue andSat:(CGFloat) sat andVal:(CGFloat) val
//{
//    unsigned int nH = (hue / DRV_CSV_MIN_SNAP_RESOLUTION);
//    unsigned int nS = (sat / DRV_CSV_MIN_SNAP_RESOLUTION);
//    unsigned int nV = (val / DRV_CSV_MIN_SNAP_RESOLUTION);
//    return cfax | (nH << 8) | (nS << 16) | (nV << 24);
//}
//
//-(id) init
//{
//    self = [super init];
//    if (self) {
//        hue = sat = value = hueSubA = hueSubB = valSubA = valSubB = 0.0f;
//    }
//    return self;
//}
//
///*
// *  Decode an existing item.
// */
//-(id) initWithCoder:(NSCoder *)aDecoder
//{
//    self = [super init];
//    if (self) {
//        cfax    = [aDecoder decodeInt32ForKey:@"cfax"];
//        hue     = [aDecoder decodeFloatForKey:@"hue"];
//        sat     = [aDecoder decodeFloatForKey:@"sat"];
//        value   = [aDecoder decodeFloatForKey:@"val"];
//        hueSubA = [aDecoder decodeFloatForKey:@"hueSubA"];
//        valSubA = [aDecoder decodeFloatForKey:@"valSubA"];
//        hueSubB = [aDecoder decodeFloatForKey:@"hueSubB"];
//        valSubB = [aDecoder decodeFloatForKey:@"valSubB"];
//    }
//    return self;
//}
//
///*
// *  Encode an item.
// */
//-(void) encodeWithCoder:(NSCoder *)aCoder
//{
//    [aCoder encodeInt32:cfax forKey:@"cfax"];
//    [aCoder encodeFloat:hue     forKey:@"hue"];
//    [aCoder encodeFloat:sat     forKey:@"sat"];
//    [aCoder encodeFloat:value   forKey:@"val"];
//    [aCoder encodeFloat:hueSubA forKey:@"hueSubA"];
//    [aCoder encodeFloat:valSubA forKey:@"valSubA"];
//    [aCoder encodeFloat:hueSubB forKey:@"hueSubB"];
//    [aCoder encodeFloat:valSubB forKey:@"valSubB"];
//}
//
//// - don't assign from a color because 0 becomes 1.0f!
//-(void) setMainHue:(CGFloat) h andSaturation:(CGFloat) s andBrightness:(CGFloat) b withColorFax:(pscf_colorfax_resolution_t) cf
//{
//    hue   = h;
//    sat   = s;
//    value = b;
//    cfax  = cf;
//}
//
//-(UIColor *) color
//{
//    return [UIColor colorWithHue:hue saturation:sat brightness:value alpha:1.0f];
//}
//
//-(void) setSubAHue:(CGFloat) h andBrightness:(CGFloat) b
//{
//    hueSubA = h;
//    valSubA = b;
//}
//
//-(void) setSubBHue:(CGFloat) h andBrightness:(CGFloat) b
//{
//    hueSubB = h;
//    valSubB = b;
//}
//
///*
// *  Return a unique id for the snapshot data.
// */
//-(NSUInteger) snapId
//{
//    return [SplitColorDataPoint snapIdForFax:cfax andHue:hue andSat:sat andVal:value];
//}
//
//@end
#endif

