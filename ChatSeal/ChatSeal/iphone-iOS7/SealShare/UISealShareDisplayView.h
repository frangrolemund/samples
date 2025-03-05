//
//  UISealShareDisplayView.h
//  ChatSeal
//
//  Created by Francis Grolemund on 2/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ChatSealIdentity;
@interface UISealShareDisplayView : UIView
-(void) setIdentity:(ChatSealIdentity *) identity;
-(void) setLocked:(BOOL) isLocked;
@end
