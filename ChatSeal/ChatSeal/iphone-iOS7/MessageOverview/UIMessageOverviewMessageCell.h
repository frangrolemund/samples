//
//  UIMessageOverviewMessageCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 11/7/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ChatSeal.h"
#import "UIGenericSizableTableViewCell.h"

@class UIMessageOverviewPlaceholder;
@interface UIMessageOverviewMessageCell : UIGenericSizableTableViewCell
-(void) configureWithMessage:(ChatSealMessage *) psm andAnimation:(BOOL) animated;
-(void) setIsRead:(BOOL) messageIsRead withAnimation:(BOOL) animated;
-(BOOL) isPermanentlyLocked;
-(void) configureAdvancedDisplayWithMessage:(ChatSealMessage *) psm;
-(void) setLocked:(BOOL) isLocked;
-(void) drawStylizedVersionWithPlaceholder:(UIMessageOverviewPlaceholder *) ph;
-(BOOL) canUpdatesToMesageBeOptimized:(ChatSealMessage *) psm;
@end
