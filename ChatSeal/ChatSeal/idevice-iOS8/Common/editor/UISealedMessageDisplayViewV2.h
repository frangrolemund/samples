//
//  UISealedMessageDisplayViewV2.h
//  ChatSeal
//
//  Created by Francis Grolemund on 10/6/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIDynamicTypeCompliantEntity.h"

@interface UISealedMessageDisplayHeaderDataV2 : NSObject
@property (nonatomic, retain) NSString *author;
@property (nonatomic, retain) NSDate *creationDate;
@property (nonatomic, assign) BOOL isOwner;
@property (nonatomic, assign) BOOL isRead;
@end

//  - this protocol acts similar to the table view data source protocol.
@class ChatSealMessage;
@class UISealedMessageDisplayViewV2;
@protocol UISealedMessageDisplayViewDataSourceV2 <NSObject>
-(NSInteger) numberOfEntriesInDisplay:(UISealedMessageDisplayViewV2 *) messageDisplay;
-(NSInteger) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *) messageDisplay numberOfItemsInEntry:(NSInteger) entry;
-(id) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *) messageDisplay contentForItemAtIndex:(NSIndexPath *) index;                   //  return an NSString or a UIImage
-(BOOL) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *) messageDisplay contentIsImageAtIndex:(NSIndexPath *) index;
-(BOOL) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *) messageDisplay authorIsLocalForEntry:(NSInteger) entry;
-(void) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *) messageDisplay populateHeaderContent:(UISealedMessageDisplayHeaderDataV2 *) header forEntry:(NSInteger) entry;
@optional
-(BOOL) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *) messageDisplay itemTappedAtIndex:(NSIndexPath *) index;
-(ChatSealMessage *) messageForSealedMessageDisplay:(UISealedMessageDisplayViewV2 *) messageDisplay;
-(void) sealedMessageDisplayDidEndDragging:(UISealedMessageDisplayViewV2 *) messageDisplay willDecelerate:(BOOL) decelerate;
-(void) sealedMessageDisplayDidEndDecelerating:(UISealedMessageDisplayViewV2 *) messageDisplay;
-(void) sealedMessageDisplayDidScroll:(UISealedMessageDisplayViewV2 *) messageDisplay;
-(void) sealedMessageDisplayDidEndScrollingAnimation:(UISealedMessageDisplayViewV2 *) messageDisplay;
-(UIImage *) sealedMessageDisplay:(UISealedMessageDisplayViewV2 *) messageDisplay fastScrollingPlaceholderAtIndex:(NSIndexPath *) index;
@end

//  - a helper category for interacting with this object.
@interface NSIndexPath (UISealedMessageDisplayView)
+(NSIndexPath *) indexPathForItem:(NSInteger) item inEntry:(NSInteger) entry;
-(NSInteger) entry;
@end

// - the display view itself.
@interface UISealedMessageDisplayViewV2 : UIView  <UIDynamicTypeCompliantEntity>
+(CGFloat) fullDisplayHeightForMessageEntryContent:(NSArray *) items inCellWidth:(CGFloat) cellWidth;
-(void) appendMessage;
-(void) scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UITableViewScrollPosition) scrollPosition animated:(BOOL)animated;
-(void) setSearchText:(NSString *) searchText;
-(void) setOwnerSealForStyling:(NSString *) sid;
-(void) setOwnerBaseColor:(UIColor *) cBaseColor andHighlight:(UIColor *) cHighlight;
-(void) setBounces:(BOOL) bounces;
-(void) setContentInset:(UIEdgeInsets) insets;
-(CGPoint) contentOffset;
-(void) setContentOffset:(CGPoint) pt;
-(CGFloat) normalizedContentYOffset;
-(void) reloadData;
-(void) reloadDataWithEntryInsertions:(NSIndexSet *) isToInsert andDeletions:(NSIndexSet *) isToDelete;
-(CGRect) rectForItemAtIndexPath:(NSIndexPath *) indexPath;
-(NSInteger) topVisibleItem;
-(BOOL) isScrollingOrDragging;
-(NSRange) rangeOfVisibleContent;
-(CGRect) headerRectForEntry:(NSUInteger) entry;
-(void) setMaximumNumberOfItemsPerEntry:(NSInteger) maxItems;
-(void) prepareForContentInsertions;
@property (nonatomic, assign) id<UISealedMessageDisplayViewDataSourceV2> dataSource;
@end
