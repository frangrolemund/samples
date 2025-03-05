//
//  UIdriverWaxView.h
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 8/14/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIdriverWaxView : UIView
-(void) setLocked:(BOOL) isLocked;
-(BOOL) locked;
-(void) prepareForSmallDisplay;
-(void) drawForDecoyRect:(CGRect) rc;
@end
