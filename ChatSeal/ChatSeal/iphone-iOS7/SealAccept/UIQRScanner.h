//
//  UIQRScanner.h
//  ChatSeal
//
//  Created by Francis Grolemund on 2/3/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class UIQRScanner;
@protocol UIQRScannerDelegate <NSObject>
@optional
-(void) qrScannerDidStart:(UIQRScanner *) scanner;
-(void) qrScanner:(UIQRScanner *) scanner didScanCode:(NSString *) content;
-(void) qrScanner:(UIQRScanner *) scanner didFailWithError:(NSError *) err;
@end

@interface UIQRScanner : UIView <UIQRScannerDelegate>
+(BOOL) isCameraRestrictricted;
+(BOOL) isCameraAvailable;
-(BOOL) isScanningRestricted;
-(BOOL) isScanningAvailable;
-(BOOL) startScanningWithError:(NSError **) err;
-(void) stopScanning;
-(void) setQRInterpretationEnabled:(BOOL) isEnabled;

@property (nonatomic, assign) id<UIQRScannerDelegate> delegate;
@end
