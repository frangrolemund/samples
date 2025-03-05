//
//  UITwitterFriendStatusHeaderView.h
//  ChatSeal
//
//  Created by Francis Grolemund on 8/30/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UITwitterFriendStatusHeaderView : UIView
+(CGFloat) headerHeight;
-(void) startAnimating;
-(void) stopAnimating;
-(void) setStatusText:(NSString *) text inColor:(UIColor *) c;
@end
