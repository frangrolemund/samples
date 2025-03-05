//
//  UIMessageDetailViewControllerV2.h
//  ChatSeal
//
//  Created by Francis Grolemund on 9/23/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UISealedMessageEnvelopeViewV2.h"
#import "ChatSealMessage.h"

@class UIMessageDetailViewControllerV2;
@protocol UIMessageDetailViewControllerV2Delegate <NSObject>
@optional
-(void) messageDetail:(UIMessageDetailViewControllerV2 *) md didCompleteWithMessage:(ChatSealMessage *) message;
-(void) messageDetailShouldCancel:(UIMessageDetailViewControllerV2 *) md;
@end

@interface UIMessageDetailViewControllerV2 : UIViewController
-(id) initWithSeal:(NSString *) sealId;
-(id) initWithExistingMessage:(ChatSealMessage *) msgData andForceAppend:(BOOL) forcedAppend;
-(id) initWithExistingMessage:(ChatSealMessage *) msgData andForceAppend:(BOOL) forcedAppend withSearchText:(NSString *) searchText andBecomeFirstResponder:(BOOL) becomeFirst;
-(UISealedMessageEnvelopeViewV2 *) envelopeForCurrentState;
-(UISealedMessageEnvelopeViewV2 *) envelopeForCurrentStateWithTargetHeight:(CGFloat) targetViewHeight;

@property (nonatomic, assign) id<UIMessageDetailViewControllerV2Delegate> delegate;
@end
