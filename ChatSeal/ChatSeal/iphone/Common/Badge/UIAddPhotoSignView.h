//
//  UIAddPhotoSignView.h
//  ChatSeal
//
//  Created by Francis Grolemund on 10/3/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIDynamicTypeCompliantEntity.h"

@interface UIAddPhotoSignView : UIView <UIDynamicTypeCompliantEntity>
+(void) verifyResources;
+(void) releaseGeneratedResources;
-(void) triggerGlossEffect;
@end
