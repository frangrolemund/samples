//
//  ChatSealBaseStation.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/20/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ChatSealRemoteIdentity.h"

// - types that are used with the kChatSealNotifySealTransferStatus notification.
typedef enum {
    CS_BSTS_STARTING              = 0,
    CS_BSTS_SENDING_SEAL_PROGRESS = 1,
    CS_BSTS_ABORTED               = 2,          // intentional abort
    CS_BSTS_ERROR                 = 3,
    CS_BSTS_COMPLETED_NEWUSER     = 4,
    CS_BSTS_COMPLETED_DUPLICATE   = 5
} ps_bs_transfer_state_t;

typedef enum {
    CS_BSCS_DISABLED              = 0,
    CS_BSCS_DEGRADED              = 1,
    CS_BSCS_ENABLED               = 2,
} ps_bs_proximity_state_t;

extern NSString *kChatSealNotifyKeyTransferState;
extern NSString *kChatSealNotifyKeyTransferProgress;
extern NSString *kChatSealNotifyKeyTransferError;

@interface ChatSealBaseStation : NSObject
-(BOOL) setNewUserState:(BOOL) isNewUser withError:(NSError **) err;
-(BOOL) setPromotedSeal:(NSString *) sealId withError:(NSError **) err;
-(BOOL) setBroadcastingEnabled:(BOOL) isEnabled withError:(NSError **) err;
-(BOOL) isBroadcastingSuccessfully;
-(void) setSealTransferPaused:(BOOL) isPaused;

-(NSURL *) secureSealTransferURL;                               //  NEVER broadcast this off the device except through the display!
-(BOOL) isValidSecureTransferURL:(NSURL *) url;
-(ChatSealRemoteIdentity *) connectForSecureSealTransferWithURL:(NSURL *) url andError:(NSError **) err;
-(BOOL) isSecureTransferInProgress;
-(ps_bs_proximity_state_t) proximityWirelessState;
-(BOOL) hasProximityDataForConnectionToURL:(NSURL *) url;

-(NSUInteger) newUserCount;
-(NSUInteger) vaultReadyUserCount;
@end
