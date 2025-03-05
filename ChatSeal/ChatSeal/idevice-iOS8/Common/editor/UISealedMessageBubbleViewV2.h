//
//  UISealedMessageBubbleViewV2.h
//  ChatSeal
//
//  Created by Francis Grolemund on 10/10/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//


#import <UIKit/UIKit.h>
#import "UIDynamicTypeCompliantEntity.h"

@interface UISealedMessageBubbleViewV2 : UIView
+(UIFont *) preferredBubbleFontAsConstrained:(BOOL) isConstrained;
+(BOOL) doesFontExceedLargeCutoff:(UIFont *) font;
+(UIEdgeInsets) standardPaddingInsets;
+(CGSize) sizeThatFits:(CGSize) size withContent:(id) content andIsSpoken:(BOOL) isSpoken;
-(void) setOwnerColor:(UIColor *) myColor andTheirColor:(UIColor *) theirColor;
-(void) setOwnerTextColor:(UIColor *) myTextColor andTheirTextColor:(UIColor *) theirTextColor;
-(void) setIsMine:(BOOL) isMine;
-(void) setOwnerHighlightColor:(UIColor *) myHighlight andTheirHighlight:(UIColor *) theirHighlight;
-(BOOL) isMine;
-(void) setIsSpoken:(BOOL) isSpoken;
-(void) setContent:(id) content;
-(id) content;
-(BOOL) isContentAnImage;
-(void) showTapped;
-(void) setSearchText:(NSString *) searchText;
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL) isInit;
-(void) setDisplayAsDeferred;
-(void) setUseConstrainedPreferredFonts:(BOOL) isEnabled;
-(BOOL) hasExcessivelyLargeText;
@end
