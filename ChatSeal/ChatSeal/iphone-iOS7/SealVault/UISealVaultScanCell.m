//
//  UISealVaultScanCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 12/24/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UISealVaultScanCell.h"

/***********************
 UISealVaultScanCell
 ***********************/
@implementation UISealVaultScanCell
/*
 *  Compute the text for the scanning cell.
 */
-(NSString *) detailTextForSharingIsPossible:(BOOL) isPossible withNewUsers:(NSUInteger) newUsers andVaultUsers:(NSUInteger) vaultUsers andWirelessState:(ps_bs_proximity_state_t) ps
{
    NSString *ret = nil;
    
    if (vaultUsers) {
        if (vaultUsers > 1) {
            ret = NSLocalizedString(@"Seals are Near", nil);
        }
        else {
            ret = NSLocalizedString(@"A Seal is Near", nil);
        }
    }
    else {
        if (ps == CS_BSCS_ENABLED) {
            ret = NSLocalizedString(@"No Seals are Near", nil);
        }
        else if (ps == CS_BSCS_DEGRADED) {
            ret = NSLocalizedString(@"Bluetooth Only", nil);
        }
        else {
            ret = NSLocalizedString(@"No Wireless", nil);
        }
    }
    return ret;
}

/*
 *  This cell doesn't need to consider sharing viability to be used.
 */
-(BOOL) shouldConsiderSharingPossibility
{
    return NO;
}
@end