//
//  UISealedMessageEditorContentCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 7/12/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIDynamicTypeCompliantEntity.h"

@class UISealedMessageEditorContentCell;
@protocol UISealedMessageEditorContentCellDelegate <NSObject>
@optional
-(void) sealedMessageCell:(UISealedMessageEditorContentCell *) cell contentLimitReachedWithText:(NSString *) text;              //  adding a character or text to a cell with an image
-(void) sealedMessageCellBackspaceFromFront:(UISealedMessageEditorContentCell *) cell;                                          //  the backspace is pressed at the front of the cell.
-(void) sealedMessageCellContentResized:(UISealedMessageEditorContentCell *) cell;                                              //  when modifications require cell height changes.
-(void) sealedMessageCellBecameFirstResponder:(UISealedMessageEditorContentCell *) cell;
-(void) sealedMessageCellLostFirstResponder:(UISealedMessageEditorContentCell *) cell;
-(void) sealedMessageCellImageDeletionRequest:(UISealedMessageEditorContentCell *) cell;                                        //  the user wants to delete the image in the cell.
-(BOOL) sealedMessageCellAllowFocusChangeWhenTappingImage:(UISealedMessageEditorContentCell *) cell;                            //  the user tapped the image on the cell.
-(void) sealedMessageCell:(UISealedMessageEditorContentCell *) cell contentIsAvailable:(BOOL) isAvail;                          //  content availability changes.
@end

typedef enum {
    SMECI_BEGIN = 0,
    SMECI_MIDDLE,
    SMECI_END,
    SMECI_ALL           //  all text will be replaced.
} smec_insertion_point_t;

@interface UISealedMessageEditorContentCell : UIView <UIDynamicTypeCompliantEntity>
+(CGFloat) minimumTextHeight;
+(NSTimeInterval) recommendedSizeAnimationDuration;
-(void) setImage:(UIImage *) img;
-(void) setImage:(UIImage *) img withAnimation:(BOOL) animated;
-(void) setText:(NSString *) text;
-(void) setText:(NSString *) text withAnimation:(BOOL) animated;
-(id) content;
-(BOOL) hasContent;
-(void) setContent:(id) content withAnimation:(BOOL) animated;
-(smec_insertion_point_t) currentInsertionPoint;
-(void) removeSelectedText;
-(NSString *) splitCellAndReturnRemainder;
-(void) setInvalid;
-(BOOL) isValid;
-(NSRange) currentSelection;
-(void) setCurrentSelection:(NSRange) selRange;
-(void) useMergeMode;
-(CGRect) caretRectangeAtSelection;
-(void) replaceSelectionWithText:(NSString *) text;
-(void) prepareForDeletion;
-(CGRect) contentFrame;
-(UIEdgeInsets) textContainerInset;

@property (nonatomic, assign) NSInteger index;
@property (nonatomic, assign) id<UISealedMessageEditorContentCellDelegate> delegate;
@end
