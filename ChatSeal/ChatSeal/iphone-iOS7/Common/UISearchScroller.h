//
//  UISearchScroller.h
//  ChatSeal
//
//  Created by Francis Grolemund on 12/8/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIDynamicTypeCompliantEntity.h"

@class UISearchScroller;
@protocol UISearchScrollerDelegate <NSObject>
@optional
-(void) searchScrollerRefreshTriggered:(UISearchScroller *) ss;
-(void) searchScroller:(UISearchScroller *) ss textWasChanged:(NSString *) searchText;
-(void) searchScroller:(UISearchScroller *) ss didMoveToForegroundSearch:(BOOL) isForeground;
-(BOOL) searchScroller:(UISearchScroller *) ss shouldCollapseAllAfterMoveToForeground:(BOOL) isForeground;
-(void) searchScrollerWillCancel:(UISearchScroller *)ss;
@end

//  NOTE:  The view controller that includes this must not auto-adjust the content insets
//         in the NIB.
@interface UISearchScroller : UIView <UIDynamicTypeCompliantEntity>
-(void) setNavigationController:(UINavigationController *) nc;
-(void) setPrimaryContentView:(UIView *) vw;
-(void) setSearchToolsView:(UIView *) vw;
-(UILabel *) descriptionLabel;
-(void) setDescription:(NSString *) text withAnimation:(BOOL) animated;
-(void) setRefreshEnabled:(BOOL) enabled;
-(void) setRefreshCompletedWithAnimation:(BOOL) animated;
-(BOOL) applyProxiedScrollOffset:(CGPoint) proxiedContentOffset;
-(void) validateContentPositionAfterProxiedScrolling;
-(void) willAnimateRotation;
-(void) closeAllSearchBarsWithAnimation:(BOOL) animated;
-(BOOL) isSearchForeground;
-(void) setActiveSearchText:(NSString *) searchText withAnimation:(BOOL) animated andBecomeFirstResponder:(BOOL) becomeFirst;
-(void) setSearchShadeExtraLightStyle:(BOOL) extraLight;
-(void) beginNavigation;
-(void) completeNavigation;
-(CGFloat) foregroundSearchBarHeight;
-(void) setDetectKeyboardResignation:(BOOL) detectionEnabled;
-(NSString *) searchText;
-(CGPoint) contentOffset;
-(void) setScrollEnabled:(BOOL) enabled;

@property (nonatomic, assign) id<UISearchScrollerDelegate> delegate;
@end
