//
//  UISealedMessageDisplayHeaderV2.h
//  ChatSeal
//
//  Created by Francis Grolemund on 10/6/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIGenericSizableTableViewHeader.h"

@interface UISealedMessageDisplayHeaderV2 : UIGenericSizableTableViewHeader
+(CGFloat) referenceHeight;
-(void) setAuthor:(NSString *) author usingColor:(UIColor *) authorColor asOwner:(BOOL) isOwner onDate:(NSDate *) date asRead:(BOOL) isRead;
-(void) setSearchText:(NSString *) searchText withHighlight:(UIColor *) cHighlight;
@end
