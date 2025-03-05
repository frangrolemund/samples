//
//  UISealShareQRView.h
//  ChatSeal
//
//  Created by Francis Grolemund on 2/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UISealShareQRView : UIView
+(NSTimeInterval) timeUntilFadeBeginsForMakingVisible:(BOOL) willBeVisible;
-(void) setQRCodeVisible:(BOOL) isVisible withAnimation:(BOOL) animated;
-(void) regenerateQRCode;
@end
