//
//  UISealAcceptFailureAlertView.h
//  ChatSeal
//
//  Created by Francis Grolemund on 2/19/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UITimerView.h"

@interface UISealAcceptFailureAlertView : UITimerView
-(id) initWithFrame:(CGRect)frame andAsConnectionFailure:(BOOL) isConnFailure;
-(BOOL) isConnectionFailureDisplay;
@end
