//
//  UISealVaultGiveCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 12/24/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UISealVaultGiveCell.h"
#import "ChatSeal.h"

/*********************
 UISealVaultGiveCell
 *********************/
@implementation UISealVaultGiveCell
/*
 *  Compute the text for the sharing cell.
 */
-(NSString *) detailTextForSharingIsPossible:(BOOL) isPossible withNewUsers:(NSUInteger) newUsers andVaultUsers:(NSUInteger) vaultUsers andWirelessState:(ps_bs_proximity_state_t) ps
{
    NSString *ret = nil;
    if (isPossible) {
        if (newUsers || vaultUsers) {
            if (newUsers + vaultUsers > 1) {
                ret = NSLocalizedString(@"Others are Near", nil);
            }
            else {
                ret = NSLocalizedString(@"Someone is Near", nil);
            }
        }
        else {
            if (ps == CS_BSCS_ENABLED) {
                ret = NSLocalizedString(@"Move Near a Friend", nil);
            }
            else if (ps == CS_BSCS_DEGRADED) {
                ret = NSLocalizedString(@"Bluetooth Only", nil);
            }
            else {
                ret = NSLocalizedString(@"No Wireless", nil);
            }
        }
    }
    else {
        ret = NSLocalizedString(@"Choose One", nil);
    }
    return ret;
}

/*
 *  Highlight when we should transfer our seal because it only happens when we wrote a message but didn't
 *  give a seal to a friend.
 */
-(BOOL) shouldDetailBeImportant
{
    return ![ChatSeal hasTransferredASeal];
}

@end
