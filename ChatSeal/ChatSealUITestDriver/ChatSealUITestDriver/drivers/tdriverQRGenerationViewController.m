//
//  tdriverQRGenerationViewController.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 2/2/14.
//  Copyright (c) 2014 Francis Grolemund. All rights reserved.
//

#import "tdriverQRGenerationViewController.h"
#import "ChatSealQREncode.h"

// - constants
static NSString *TDRIVER_EC_PICKER[]   = {@"Low", @"Medium", @"Quartile", @"High", @"Automatic"};
static const NSUInteger TDRIVER_NUM_EC = sizeof(TDRIVER_EC_PICKER)/sizeof(TDRIVER_EC_PICKER[0]);
static NSString *TDRIVER_MP_PICKER[]   = {@"Column", @"Zig-Zag", @"Checkerboard", @"Row", @"Football", @"Explosion", @"Ship", @"Cross", @"Auto-compute"};
static const NSUInteger TDRIVER_NUM_MP = sizeof(TDRIVER_MP_PICKER)/sizeof(TDRIVER_MP_PICKER[0]);

// - forward declarations
@interface tdriverQRGenerationViewController (internal) <UIPickerViewDataSource, UIPickerViewDelegate>
-(void) regenerateContentAndCodeWithAnimation:(BOOL) animated;
-(void) regenerateCodeFromAttribsWithAnimation:(BOOL) animated;
@end

/**********************************
 tdriverQRGenerationViewController
 **********************************/
@implementation tdriverQRGenerationViewController
/*
 * Object attributes
 */
{
    
}
@synthesize lErrorResult;
@synthesize ivQRCode;
@synthesize tvContent;
@synthesize pvQuality;
@synthesize pvMask;

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
    [lErrorResult release];
    lErrorResult = nil;
    
    [ivQRCode release];
    ivQRCode = nil;
    
    [tvContent release];
    tvContent = nil;
    
    [pvQuality release];
    pvQuality = nil;
    
    [pvMask release];
    pvMask = nil;
    
    [super dealloc];
}

/*
 *  Configure the view.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // - configure the image view.
    ivQRCode.layer.borderColor = [[UIColor blackColor] CGColor];
    ivQRCode.layer.borderWidth = 1.0f;
    
    // - configure the two pickers.
    pvQuality.delegate = self;
    pvQuality.dataSource = self;
    [pvQuality reloadAllComponents];
    [pvQuality selectRow:TDRIVER_NUM_EC-1 inComponent:0 animated:NO];
    
    pvMask.delegate = self;
    pvMask.dataSource = self;
    [pvMask reloadAllComponents];
    [pvMask selectRow:TDRIVER_NUM_MP-1 inComponent:0 animated:NO];
    
    // - set up the first QR code
    [self regenerateContentAndCodeWithAnimation:NO];
}

-(NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return @"Generated";
            break;
        
        case 1:
            return @"Content";
            break;
            
        case 2:
            return @"Error Correction";
            break;
            
        case 3:
            return @"Masking Pattern";
            break;
            
        default:
            return nil;
            break;
    }
}

/*
 *  Regenerate the content string and the QR code along with it.
 */
-(IBAction)doRegenContent:(id)sender
{
    [self regenerateContentAndCodeWithAnimation:YES];
}

@end

/*********************************************
 tdriverQRGenerationViewController (internal)
 *********************************************/
@implementation tdriverQRGenerationViewController (internal)
/*
 *  Return the number of components in the picker view.
 */
-(NSInteger) numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

/*
 *  Return the number of rows in the given component.
 */
-(NSInteger) pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    if (pickerView == pvQuality) {
        return TDRIVER_NUM_EC;
    }
    else {
        return TDRIVER_NUM_MP;
    }
}

/*
 *  Return the title of the given row in the component.
 */
-(NSString *) pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    if (pickerView == pvQuality) {
        return TDRIVER_EC_PICKER[row];
    }
    else {
        return TDRIVER_MP_PICKER[row];
    }
}

-(void) pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    [self regenerateCodeFromAttribsWithAnimation:YES];
}

/*
 *  Regnerate the QR content as well as the image.
 */
-(void) regenerateContentAndCodeWithAnimation:(BOOL) animated
{
    // - the content is going to look a lot like the URL we intend to provide.
    //  - generate a password for communicating with this
    //    instance of the service
    static const NSUInteger PWD_LEN = 20;
    unsigned char pwdBytes[PWD_LEN];
    if (SecRandomCopyBytes(kSecRandomDefault, PWD_LEN, pwdBytes) != errSecSuccess) {
        NSLog(@"DEBUG: failed to regenerate the content.");
        return;
    }
    NSString *sPwd = @"";
    for (int i = 0; i < PWD_LEN; i++) {
        sPwd = [sPwd stringByAppendingFormat:@"%02X", (unsigned char) (pwdBytes[i])];
    }

    NSString *sURL = [NSString stringWithFormat:@"chatseal://+0E3BBAC1C365C5E83E9E1165323101CB183B2801/g?%@", sPwd];
    tvContent.text = sURL;
    [self regenerateCodeFromAttribsWithAnimation:animated];
}

/*
 *  Regenerate the active QR code.
 */
-(void) regenerateCodeFromAttribsWithAnimation:(BOOL) animated
{
    int ecSelected  = (int) [pvQuality selectedRowInComponent:0];
    if (ecSelected < 0 || ecSelected >= TDRIVER_NUM_EC-1) {
        ecSelected = CS_QRE_EC_LOW;
    }
    int mskSelected = (int) [pvMask selectedRowInComponent:0];
    if (mskSelected < 0 || mskSelected >= TDRIVER_NUM_MP-1) {
        mskSelected = CS_QRE_MP_COMPUTE;
    }
    
    NSString *sText = tvContent.text;
    if (!sText) {
        sText = @"";
    }
    
    if (animated) {
        UIView *vwSnap = [ivQRCode snapshotViewAfterScreenUpdates:NO];
        vwSnap.frame   = ivQRCode.frame;
        [ivQRCode.superview addSubview:vwSnap];
        [UIView animateWithDuration:0.5f animations:^(void) {
            vwSnap.alpha = 0.0f;
        }completion:^(BOOL finished) {
            [vwSnap removeFromSuperview];
        }];
    }
    NSError *err = nil;
    UIImage *img = [ChatSealQREncode encodeQRString:sText asVersion:CS_QRE_VERSION_AUTO andLevel:ecSelected andMask:mskSelected andTargetDimension:256.0f withError:&err];
    if (img) {
        ivQRCode.image    = img;
        lErrorResult.text = nil;
    }
    else {
        lErrorResult.text = [err localizedDescription];
        ivQRCode.image    = nil;
    }
    
}
@end
