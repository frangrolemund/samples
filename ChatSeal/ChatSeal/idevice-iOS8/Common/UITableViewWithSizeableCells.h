//
//  UITableViewWithSizeableCells.h
//  ChatSeal
//
//  Created by Francis Grolemund on 9/30/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIDynamicTypeCompliantEntity.h"                //  - cells that implement this will be automatically notified.

@protocol UITableViewWithSizeableCellsDelegate <UITableViewDelegate>
@optional
-(void) tableViewNotifyContentSizeChanged:(UITableView *) tableView;
-(void) tableView:(UITableView *) tableView stationaryTouchesBegan:(NSSet *) touches;
@end

@interface UITableViewWithSizeableCells : UITableView
-(id) initWithFrame:(CGRect) frame andConfigureForSelfSizing:(BOOL) useSelfSizing;
-(void) showEmptyTableOverlayWithRowHeight:(CGFloat) rowHeight andAnimation:(BOOL) animated;
-(void) hideEmptyTableOverlayWithAnimation:(BOOL) animated;
-(BOOL) shouldPermitHighlight;
-(BOOL) shouldPermitHighlightAndUseTimer:(BOOL) useTimer;
-(void) prepareForNavigationPush;
-(void) parentViewControllerDidDisappear;
@end
