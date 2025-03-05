//
//  UISealVaultToolCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/31/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ChatSealBaseStation.h"
#import "UIGenericSizableTableViewCell.h"

@interface UISealVaultToolCell : UIGenericSizableTableViewCell
-(void) reconfigureCellForSharingAvailabilityWithAnimation:(BOOL) animated;
-(BOOL) isSharingPossible;
-(NSString *) detailTextForSharingIsPossible:(BOOL) isPossible withNewUsers:(NSUInteger) newUsers andVaultUsers:(NSUInteger) vaultUsers andWirelessState:(ps_bs_proximity_state_t) ps;
-(BOOL) shouldConsiderSharingPossibility;
-(BOOL) shouldDetailBeImportant;
-(BOOL) hasDetailContentChanged;
@end
