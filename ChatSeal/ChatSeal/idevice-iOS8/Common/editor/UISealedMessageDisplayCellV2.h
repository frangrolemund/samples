//
//  UISealedMessageDisplayCellV2.h
//  ChatSeal
//
//  Created by Francis Grolemund on 10/6/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UISealedMessageDisplayCellV2 : UITableViewCell
+(CGFloat) minimumCellHeightForImage:(UIImage *) image;
+(CGFloat) minimumCellHeightForImageOfSize:(CGSize) szImage;
+(CGFloat) minimumCellHeightForText:(NSString *) text inCellWidth:(CGFloat) width;
+(UIImage *) genericFastScrollingPlaceholderImage;
+(CGFloat) verticalPaddingHeight;
-(void) setOwnerBubbleColor:(UIColor *) c;
-(void) setOwnerHighlightColor:(UIColor *) myHighlight andTheirHighlight:(UIColor *) theirHighlight;
-(void) setIsMine:(BOOL) isMine;
-(void) setIsSpoken:(BOOL) isSpoken;
-(void) setContentWithDeferredAnimation:(id) content;
-(void) setSearchText:(NSString *) searchText;
-(void) showTapped;
-(CGRect) bubbleRect;
-(void) setContentIsDeferred;
-(BOOL) hasDeferredContent;
@end
