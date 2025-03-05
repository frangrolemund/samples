//
//  UIFeedsOverviewAuthView.h
//  ChatSeal
//
//  Created by Francis Grolemund on 6/3/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIDynamicTypeCompliantEntity.h"

typedef enum {
    CS_FOAS_REQUEST = 0,
    CS_FOAS_NOAUTH  = 1,
    CS_FOAS_NOFEEDS = 2,
    
    CS_FOAS_HIDDEN
} ps_feeds_overview_auth_state_t;

@interface UIFeedsOverviewAuthView : UIView <UIDynamicTypeCompliantEntity>
+(NSString *) warningTextForNoFeedsInHeader:(BOOL) isHeader;
+(NSString *) warningTextForNoAuthInHeader:(BOOL) isHeader;
-(void) setAuthorizationDisplayState:(ps_feeds_overview_auth_state_t) aState andAnimation:(BOOL) animated;
-(void) disableAuthorizationButton;
-(void) updatePreferredTextWidths;
@end
