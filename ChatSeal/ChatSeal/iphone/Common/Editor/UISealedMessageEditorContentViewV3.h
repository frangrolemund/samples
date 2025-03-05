//
//  UISealedMessageEditorContentViewV3.h
//  ChatSeal
//
//  Created by Francis Grolemund on 4/23/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UISealedMessageEnvelopeViewV2.h"
#import "UIDynamicTypeCompliantEntity.h"

@class UISealedMessageEditorContentViewV3;
@protocol UISealedMessageEditorContentViewV3Delegate <NSObject>
@optional
// - NOTE: everything in this editor is geared towards getting a setFrame in response to a content resize delegate
//         method, ideally within an animation block.   Since the editor is most often expanded in response to changes
//         we want to always animate everything the exact same way or there will be visual inconsistencies.  That means
//         that scrolling animations cannot use the defaults, but instead rely on the owner to dictate their parameters.
-(void) sealedMessageEditorContentResized:(UISealedMessageEditorContentViewV3 *) contentView;
-(void) sealedMessageEditor:(UISealedMessageEditorContentViewV3 *) contentView contentIsAvailable:(BOOL) isAvail;
-(void) sealedMessageEditor:(UISealedMessageEditorContentViewV3 *) contentView imageCountModifiedTo:(NSUInteger) numImages;
-(void) sealedMessageEditorBecameFirstResponder:(UISealedMessageEditorContentViewV3 *) contentView;
@end


@interface UISealedMessageEditorContentViewV3 : UIView <UIDynamicTypeCompliantEntity>
+(NSTimeInterval) recommendedSizeAnimationDuration;
-(void) addPhotoAtCursorPosition:(UIImage *) image;
-(NSArray *) contentItems;
-(void) setContentItems:(NSArray *) array;
-(void) setHintText:(NSString *) hintText;
-(UISealedMessageEnvelopeViewV2 *) envelopeForCurrentContentAndTargetHeight:(CGFloat) targetHeight;
-(BOOL) hasContent;
-(CGSize) contentSize;
-(void) setFrame:(CGRect)frame withImmediateLayout:(BOOL) immediateLayout;
-(NSString *) textForActiveItem;

@property (nonatomic, assign) id<UISealedMessageEditorContentViewV3Delegate> delegate;
@end
