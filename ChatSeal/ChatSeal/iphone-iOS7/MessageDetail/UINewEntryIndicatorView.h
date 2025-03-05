//
//  UINewEntryIndicatorView.h
//  ChatSeal
//
//  Created by Francis Grolemund on 6/5/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class UINewEntryIndicatorView;
@protocol UINewEntryIndicatorViewDelegate <NSObject>
@optional
-(void) newEntryIndicatorWasTapped:(UINewEntryIndicatorView *) iv;
@end

@interface UINewEntryIndicatorView : UIView
-(id) initWithOrientationAsUp:(BOOL) isUp;
-(void) setNewEntryCount:(NSUInteger) count withAnimation:(BOOL) animated;
-(void) setIndicatorVisible:(BOOL) visible withAnimation:(BOOL) animated;
@property (nonatomic, assign) id<UINewEntryIndicatorViewDelegate> delegate;
@end
