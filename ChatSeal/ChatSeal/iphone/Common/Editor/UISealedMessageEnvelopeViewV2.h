//
//  UISealedMessageEnvelopeViewV2.h
//  ChatSeal
//
//  Created by Francis Grolemund on 10/5/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ChatSealFeed;
@interface UISealedMessageEnvelopeViewV2 : UIView
+(UIImage *) standardDecoyForActiveSeal;
+(UIImage *) standardDecoyForSeal:(NSString *) sealId;
+(CGPoint) baseOffsetForWidth:(CGFloat) width;
-(id) initWithWidth:(CGFloat) width andMaximumHeight:(CGFloat) maxHeight;
-(void) addBubbleContent:(id) content fromCellInFrame:(CGRect) rcCellFrame;

// - positioning methods
-(void) prepareForAnimationWithMaximumDimensions:(CGSize) maxDims usingSeal:(NSString *) sealId;
-(void) moveToOriginalState;
-(void) moveToAspectAccuratePaperCenteredAt:(CGPoint) pt withMaximumDimensions:(CGSize) maxDims withPush:(BOOL) isPush;
-(void) setFakePaperFoldsVisible:(BOOL) isVisible;
-(void) moveToFoldedEnvelopeCenteredAt:(CGPoint) pt withMaximumDimensions:(CGSize) maxDims;
-(void) moveToSealVisible:(BOOL) isVisible;
-(void) moveToSealLocked:(BOOL) isLocked centeredAt:(CGPoint) pt withMaximumDimensions:(CGSize) maxDims;
-(BOOL) isPointInSealIcon:(CGPoint) pt;
-(void) sealIconTapped;
-(void) moveToFinalStateWithAllRequiredTransformsCenteredAt:(CGPoint) pt withMaximumDimensions:(CGSize) maxDims;
-(void) completeEnvelopeTransitionDisplay;
-(void) modifyEnvelopeOrigin:(CGPoint) pt;
@end
