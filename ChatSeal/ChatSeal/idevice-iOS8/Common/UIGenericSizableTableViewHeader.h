//
//  UIGenericSizableTableViewHeader.h
//  ChatSeal
//
//  Created by Francis Grolemund on 10/1/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIDynamicTypeCompliantEntity.h"

@interface UIGenericSizableTableViewHeader : UIView <UIDynamicTypeCompliantEntity>
-(id) initWithText:(NSString *) headerText;
@end
