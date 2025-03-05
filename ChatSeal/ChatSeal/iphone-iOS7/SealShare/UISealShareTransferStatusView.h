//
//  UISealShareTransferStatusView.h
//  ChatSeal
//
//  Created by Francis Grolemund on 2/27/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIDynamicTypeCompliantEntity.h"

@interface UISealShareTransferStatusView : UIView <UIDynamicTypeCompliantEntity>
-(void) setPreferredMaxLayoutWidth:(CGFloat) maxLayoutWidth;
-(CGFloat) preferredMaxLayoutWidth;
-(void) setTransferStatus:(NSString *) status withAnimation:(BOOL) animated;
@end
