//
//  UISealVaultSimpleSealView.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/2/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ChatSeal.h"

@interface UISealVaultSimpleSealView : UIView
-(void) setSealColor:(RSISecureSeal_Color_t) color withImage:(UIImage *) image;
@end
