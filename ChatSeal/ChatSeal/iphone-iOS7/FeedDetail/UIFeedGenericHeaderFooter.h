//
//  UIFeedGenericHeaderFooter.h
//  ChatSeal
//
//  Created by Francis Grolemund on 6/23/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIFeedGenericHeaderFooter : UIView
+(CGFloat) recommendedHeightForText:(NSString *) text andScreenWidth:(CGFloat) width;
-(id) initWithText:(NSString *) sText inColor:(UIColor *) c asHeader:(BOOL) isHeader;
-(CGFloat) recommendedHeightForScreenWidth:(CGFloat) width;
@end
